"""Build an isolated cloud-test runtime that uses a CharacterBody3D for phone/web walking."""
from pathlib import Path
import argparse,base64,difflib,hashlib,importlib.util,json,re
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent

def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    m=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m

east=module('east_builder',ROOT/'tools/east_expansion_v1/build.py')

def patch_neighborhood(source:str) -> str:
    source=source.replace(
        'var couch_stand := Vector3.ZERO\n',
        '''var couch_stand := Vector3.ZERO
var physics_body: CharacterBody3D
var physics_obstacle_root: Node3D
var physics_door_body: StaticBody3D
var physics_door_shape: CollisionShape3D
var physics_obstacle_signature := ""
var stamina_bar: ProgressBar
var stamina_text: Label
var physics_ready := false
const PHYSICS_MAP:=Rect2(-32,-36,233,75)
''',1)
    assert 'var physics_body: CharacterBody3D' in source

    source=source.replace(
        '\t_build_block()\n\tweather=',
        '\t_build_block()\n\t_build_physics_walk()\n\tweather=',1)
    assert source.count('_build_physics_walk()')>=1

    physics_helpers=r'''
func _build_physics_walk() -> void:
	if physics_body!=null:return
	physics_body=load("res://scripts/mobile_physics_player.gd").new()
	physics_body.name="MobilePhysicsPlayer"
	add_child(physics_body)
	physics_obstacle_root=Node3D.new()
	physics_obstacle_root.name="MobilePhysicsObstacles"
	add_child(physics_obstacle_root)
	var ground:=StaticBody3D.new()
	ground.name="MobilePhysicsGround"
	ground.collision_layer=1
	ground.collision_mask=4
	var collision:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(PHYSICS_MAP.size.x,.10,PHYSICS_MAP.size.y)
	collision.shape=box
	collision.position=Vector3(PHYSICS_MAP.get_center().x,-.05,PHYSICS_MAP.get_center().y)
	ground.add_child(collision)
	add_child(ground)
	physics_door_body=StaticBody3D.new()
	physics_door_body.name="MobilePhysicsApartmentDoor"
	physics_door_body.collision_layer=1
	physics_door_body.collision_mask=4
	physics_door_shape=CollisionShape3D.new()
	var door_box:=BoxShape3D.new()
	door_box.size=Vector3(1.88,2.96,.14)
	physics_door_shape.shape=door_box
	physics_door_shape.position=Vector3(0,1.48,5.84)
	physics_door_body.add_child(physics_door_shape)
	add_child(physics_door_body)
	_set_physics_door_closed(not door_open)
	_sync_physics_from_camera()
	physics_ready=true

func _set_physics_door_closed(solid:bool) -> void:
	if physics_door_shape!=null:physics_door_shape.set_deferred("disabled",not solid)

func _physics_rect(source:Rect2,shrink:float) -> void:
	if physics_obstacle_root==null:return
	var rect:=source.grow(-shrink)
	if rect.size.x<=.03 or rect.size.y<=.03:return
	var body:=StaticBody3D.new()
	body.collision_layer=1
	body.collision_mask=4
	var collision:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(rect.size.x,2.70,rect.size.y)
	collision.shape=box
	collision.position=Vector3(rect.get_center().x,1.35,rect.get_center().y)
	body.add_child(collision)
	physics_obstacle_root.add_child(body)

func _apartment_shell_rect(rect:Rect2) -> bool:
	var c:=rect.get_center()
	return c.distance_to(Vector2(0,-2.1))<.35 and rect.size.x>10.0 and rect.size.y>16.0

func _physics_signature() -> String:
	# Rect arrays are deterministic for a given world state. Avoid rebuilding
	# dozens of StaticBody3D nodes every collision scan when nothing changed.
	return str(obstacles)+"|"+str(map_obstacles)+"|"+str(interior_obstacles)

func _rebuild_physics_obstacles(force:bool=false) -> void:
	if physics_obstacle_root==null:return
	var signature:=_physics_signature()
	if not force and signature==physics_obstacle_signature:return
	physics_obstacle_signature=signature
	for child in physics_obstacle_root.get_children():child.free()
	for rect in obstacles:
		if _apartment_shell_rect(rect):continue
		_physics_rect(rect,ScalePolicy.BODY_RADIUS)
	for rect in map_obstacles:_physics_rect(rect,ScalePolicy.BODY_RADIUS)
	for rect in interior_obstacles:_physics_rect(rect,.20)

func _sync_physics_from_camera() -> void:
	if physics_body==null:return
	physics_body.global_position=host.camera.global_position-Vector3.UP*WALK_EYE_HEIGHT
	physics_body.velocity=Vector3.ZERO

func _sync_camera_from_physics() -> void:
	if physics_body==null:return
	host.camera.global_position=physics_body.global_position+Vector3.UP*WALK_EYE_HEIGHT

func _stop_physics_walk() -> void:
	if physics_body!=null:physics_body.stop()

func _update_stamina_hud() -> void:
	if stamina_bar==null or stamina_text==null or physics_body==null:return
	stamina_bar.value=physics_body.stamina
	var show_bar:bool=active and (physics_body.is_sprinting or physics_body.stamina<physics_body.STAMINA_MAX-.1)
	stamina_bar.visible=show_bar
	stamina_text.visible=show_bar
	if show_bar:
		stamina_text.text="SPRINTING" if physics_body.is_sprinting else ("EXHAUSTED" if physics_body.exhausted else "STAMINA")

'''
    assert 'func _build_controls() -> void:' in source
    source=source.replace('func _build_controls() -> void:',physics_helpers+'func _build_controls() -> void:',1)

    source=source.replace(
        '\tcontrols.add_child(action)\n\tcontrols.hide()\n\tmobile_hud=load("res://scripts/mobile_hud.gd").new();mobile_hud.setup(self)\n',
        '''\tcontrols.add_child(action)
\tstamina_bar=ProgressBar.new()
\tstamina_bar.name="SprintStamina"
\tstamina_bar.min_value=0
\tstamina_bar.max_value=100
\tstamina_bar.value=100
\tstamina_bar.show_percentage=false
\tstamina_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
\tstamina_bar.anchor_left=.5
\tstamina_bar.anchor_right=.5
\tstamina_bar.anchor_top=1.0
\tstamina_bar.anchor_bottom=1.0
\tstamina_bar.offset_left=-108
\tstamina_bar.offset_right=108
\tstamina_bar.offset_top=-76
\tstamina_bar.offset_bottom=-56
\tvar stamina_bg:=StyleBoxFlat.new()
\tstamina_bg.bg_color=Color("102019")
\tstamina_bg.border_color=Color("4c7257")
\tstamina_bg.set_border_width_all(2)
\tstamina_bg.set_corner_radius_all(8)
\tvar stamina_fill:=StyleBoxFlat.new()
\tstamina_fill.bg_color=Color("7fcf88")
\tstamina_fill.set_corner_radius_all(6)
\tstamina_bar.add_theme_stylebox_override("background",stamina_bg)
\tstamina_bar.add_theme_stylebox_override("fill",stamina_fill)
\tcontrols.add_child(stamina_bar)
\tstamina_text=Label.new()
\tstamina_text.mouse_filter=Control.MOUSE_FILTER_IGNORE
\tstamina_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
\tstamina_text.add_theme_font_size_override("font_size",13)
\tstamina_text.add_theme_color_override("font_color",Color("e8f4e7"))
\tstamina_text.anchor_left=.5
\tstamina_text.anchor_right=.5
\tstamina_text.anchor_top=1.0
\tstamina_text.anchor_bottom=1.0
\tstamina_text.offset_left=-108
\tstamina_text.offset_right=108
\tstamina_text.offset_top=-101
\tstamina_text.offset_bottom=-78
\tcontrols.add_child(stamina_text)
\tstamina_bar.hide()
\tstamina_text.hide()
\tcontrols.hide()
\tmobile_hud=load("res://scripts/mobile_hud.gd").new();mobile_hud.setup(self)
''',1)

    source=source.replace(
        '\thost.camera.position.y=WALK_EYE_HEIGHT\n\thost.camera.fov=78.0\n',
        '\thost.camera.position.y=WALK_EYE_HEIGHT\n\thost.camera.fov=78.0\n\t_sync_physics_from_camera()\n\tphysics_body.enabled=true\n',1)

    source=source.replace(
        'func end_walk() -> void:\n\tif not active: return\n\tactive=false\n',
        'func end_walk() -> void:\n\tif not active: return\n\tactive=false\n\t_stop_physics_walk()\n',1)

    source=source.replace(
        '\t\t_collect_map_colliders(self)\n\t\tcollision_timer=0.3\n',
        '\t\t_collect_map_colliders(self)\n\t\t_rebuild_physics_obstacles()\n\t\tcollision_timer=0.3\n',1)

    # The visual door may be rotated open, but the legacy scanner turns its
    # axis-aligned bounds back into a blocker. Exclude it and use one dedicated
    # physics leaf that is solid only while the apartment door is closed.
    source=source.replace(
        'if node==door_pivot and (door_busy or door_pass_through):return',
        'if node==door_pivot:return',1)
    source=source.replace(
        'func _collect_map_colliders(node: Node) -> void:\n',
        'func _collect_map_colliders(node: Node) -> void:\n\tif node==physics_obstacle_root or node==physics_body or node==physics_door_body or node==police_station:return\n',1)
    source=source.replace(
        '\tdoor_busy=true;door_pass_through=true;collision_timer=0.0\n\tdoor_open=not door_open\n',
        '\tdoor_busy=true;door_pass_through=true;collision_timer=0.0\n\t_set_physics_door_closed(false)\n\tdoor_open=not door_open\n',1)
    source=source.replace(
        '\ttween.finished.connect(func():door_busy=false;_refresh_apartment_door_collision())',
        '\ttween.finished.connect(func():door_busy=false;_refresh_apartment_door_collision();_set_physics_door_closed(not door_open))',1)

    source=source.replace(
        '\tif blocked:\n\t\tpointer=-99\n\t\tpad.release()\n\t\treturn\n',
        '\tif blocked:\n\t\tpointer=-99\n\t\tpad.release()\n\t\t_stop_physics_walk()\n\t\treturn\n',1)

    start=source.index('\tvar turn:=float(Input.is_physical_key_pressed(KEY_LEFT))')
    end=source.index('\thost.view_label.text="Apartment" if _indoors(host.camera.position) else "Neighborhood"',start)
    movement=r'''	var turn:=float(Input.is_physical_key_pressed(KEY_LEFT))-float(Input.is_physical_key_pressed(KEY_RIGHT))
	host.camera.rotation.y+=turn*delta*1.65
	var movement: Vector2=pad.value
	movement+=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	movement=movement.limit_length(1.0)
	if bench_seating.seated>=0:
		if movement.length()>0.15:
			if bench_seating.stand():_sync_physics_from_camera()
		if bench_seating.seated>=0:movement=Vector2.ZERO
	if couch_seated:
		if movement.length()>0.15:_toggle_couch()
		else:movement=Vector2.ZERO
	if not couch_seated and bench_seating.seated<0:
		var mobile_sprint:bool=pad.value.length()>=.92 and pad.value.y<=-.72
		var keyboard_sprint:bool=Input.is_physical_key_pressed(KEY_SHIFT) and movement.y<-.35
		physics_body.drive(movement,host.camera.rotation.y,mobile_sprint or keyboard_sprint)
		_sync_camera_from_physics()
	_update_stamina_hud()
'''
    source=source[:start]+movement+source[end:]

    source=source.replace(
        'host.status_label.text="Relaxing on the couch. Move to stand up." if couch_seated else "Back on your feet."\n',
        'host.status_label.text="Relaxing on the couch. Move to stand up." if couch_seated else "Back on your feet."\n\tif physics_ready and not couch_seated:_sync_physics_from_camera()\n',1)

    source=source.replace(
        'host.status_label.text="Walk through the open doorway. You can close the door from either side."',
        'host.status_label.text="3D PHYSICS TEST · Use the left stick to walk and drag the world to look."',1)

    for required in [
        'MobilePhysicsPlayer','_rebuild_physics_obstacles()','physics_body.drive',
        'MobilePhysicsApartmentDoor','_set_physics_door_closed(false)',
        'physics_obstacle_signature','_physics_signature()',
        'if node==door_pivot:return','node==physics_obstacle_root','node==police_station',
        'physics_body.drive(movement,host.camera.rotation.y,mobile_sprint or keyboard_sprint)',
        'SprintStamina','_update_stamina_hud()',
        '3D PHYSICS TEST','_sync_physics_from_camera()'
    ]:
        assert required in source,required
    return source


def patch_station(source:str) -> str:
    if 'func build_physics() -> void:' in source:
        return source
    # Floor slabs are structural thickness, so lower walls must terminate at
    # the slab underside rather than continuing through to its top surface.
    source=source.replace(
        'var xs:Array[float]=[0,span];var ys:Array[float]=[0,STORY]',
        'var wall_height:float=STORY\n\tif floor_index==0 and id.begins_with("Stair"):wall_height=STORY-.20\n\telif floor_index==1:wall_height=STORY-.23\n\tvar xs:Array[float]=[0,span];var ys:Array[float]=[0,wall_height]',1)
    # The final tread meets the top landing cleanly; its decorative nosing was
    # the only stair trim extending above/through the upstairs floor edge.
    source=source.replace(
        '\t\tpart("StairNosing",21.5,h+.009,20.5-i*.35,Vector3(4.6,.018,.035),"bfc4c1",false)',
        '\t\tif i<19:part("StairNosing",21.5,h+.009,20.5-i*.35,Vector3(4.6,.018,.035),"bfc4c1",false)',1)
    source=source.replace(
        '\tflush()\n\nfunc ground_rooms() -> void:',
        '\tflush()\n\tbuild_physics()\n\nfunc ground_rooms() -> void:',1)
    physics=r'''
func build_physics() -> void:
	if has_node("StationStructure"):return
	var body:=StaticBody3D.new()
	body.name="StationStructure"
	body.collision_layer=1
	body.collision_mask=4
	add_child(body)
	for bounds in colliders:add_box_collision(body,bounds)
	for entry in parts:
		if entry.id in ["GroundFloor","UpperFloorWest","UpperFloorNorth","UpperFloorSouth","TopLanding","Roof"]:
			add_box_collision(body,entry.bounds)
	# Continuous ramp under the visible treads: the same capsule walks both
	# floors without camera-height teleporting or per-step collision chatter.
	var ramp:=ConvexPolygonShape3D.new()
	var vertices:=PackedVector3Array()
	for x in [19.2,23.8]:
		vertices.append(point(x,-.1,20.5));vertices.append(point(x,0,20.5))
		vertices.append(point(x,-.1,13.5));vertices.append(point(x,STORY,13.5))
	ramp.points=vertices
	var ramp_shape:=CollisionShape3D.new()
	ramp_shape.name="StairRamp"
	ramp_shape.shape=ramp
	body.add_child(ramp_shape)

func add_box_collision(body:StaticBody3D,bounds:AABB) -> void:
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=bounds.size
	collision.shape=shape
	collision.position=bounds.get_center()
	body.add_child(collision)

'''
    source=source.replace('func covers(at:Vector3) -> bool:',physics+'func covers(at:Vector3) -> bool:',1)
    assert 'StationStructure' in source and 'StairRamp' in source
    return source

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--output-dir',required=True)
    args=ap.parse_args()
    out=Path(args.output_dir).resolve()
    out.mkdir(parents=True,exist_ok=True)

    baseline=east.fit.read_recipe(ROOT/'runtime/kobi-v1.patch.json')
    expected='bbc788e5d4dd19b59af7dd2824f34943361d901d08ae5b5c25f8e7c6b9a75410'
    assert hashlib.sha256(baseline).hexdigest()==expected
    fb,entries=east.pack.parse(baseline)
    before={n:b for n,b,f in entries}

    neighborhood=patch_neighborhood(before['scripts/neighborhood.gd'].decode())
    station=patch_station((ROOT/'tools/police_station_v1/station.gd').read_text())
    door=(HERE/'interior_door_physics.gd').read_bytes()
    replacements={
        'scripts/neighborhood.gd':neighborhood.encode(),
        'scripts/police_station.gd':station.encode(),
        'scripts/interior_door.gd':door,
    }
    updated=[]
    for n,b,f in entries:
        updated.append([n,replacements.get(n,b),f])
    updated.append(['scripts/mobile_physics_player.gd',(HERE/'mobile_physics_player.gd').read_bytes(),0])

    built=east.pack.rebuild(baseline,fb,updated)
    after={n:b for n,b,f in east.pack.parse(built)[1]}
    changed=[n for n in before if before[n]!=after[n]]
    assert changed==['scripts/interior_door.gd','scripts/neighborhood.gd','scripts/police_station.gd'],changed
    assert 'scripts/mobile_physics_player.gd' in after

    (out/'candidate.pck').write_bytes(built)
    east.fit.extract(updated,out/'candidate','AFB Mobile 3D Movement Candidate')

    base=(ROOT/'index-cloudtest10.pck').read_bytes()
    source={n:(o,s) for n,o,s in east.directory(base)}
    segments=[]
    def add(data):
        if data:segments.append(['data',base64.b64encode(data).decode()])
    def copy(offset,size):
        if size:segments.append(['copy',offset,size])
    add(built[:fb]);cursor=fb
    assets=[
        'assets/characters/Kobi.glb','assets/characters/Kobi_BaseColor.png',
        'assets/characters/Malik.glb','assets/characters/Rod.glb',
        'assets/characters/Malik_BaseColor.png','assets/characters/Rod_BaseColor.png',
        'assets/furniture/walnut.png'
    ]
    for name,offset,size in east.directory(built):
        if offset>cursor:
            assert not any(built[cursor:offset]);segments.append(['zero',offset-cursor])
        data=built[offset:offset+size]
        if name in assets:
            segments.append(['asset',name+'?v=mobile-3d-v1',size,hashlib.sha256(data).hexdigest()])
        elif name in source:
            oldoff,oldsize=source[name];previous=base[oldoff:oldoff+oldsize]
            if data==previous:
                copy(oldoff,oldsize)
            elif name=='scripts/main.gd':
                a=previous.splitlines(keepends=True);b=data.splitlines(keepends=True);offsets=[0]
                for line in a:offsets.append(offsets[-1]+len(line))
                for op,l,r,x,y in difflib.SequenceMatcher(None,a,b,autojunk=False).get_opcodes():
                    if op=='equal':copy(oldoff+offsets[l],offsets[r]-offsets[l])
                    elif op in ['replace','insert']:add(b''.join(b[x:y]))
            else:
                add(data)
        else:
            add(data)
        cursor=offset+size
    add(built[cursor:])

    recipe={
        'format':'afb-pack-delta-1',
        'base_url':'index-cloudtest10.pck?build=63',
        'base_size':len(base),
        'base_sha256':hashlib.sha256(base).hexdigest(),
        'target_size':len(built),
        'target_sha256':hashlib.sha256(built).hexdigest(),
        'segments':segments
    }
    recipe_path=ROOT/'runtime/mobile-3d-v1.patch.json'
    recipe_path.write_text(json.dumps(recipe,separators=(',',':'))+'\n',newline='\n')
    assert east.fit.read_recipe(recipe_path)==built

    loader=(ROOT/'shared/afb-runtime-kobi-v1.js').read_text()
    loader=loader.replace('kobi-v1','mobile-3d-v1').replace('AFB_RUNTIME_KOBI_V1','AFB_RUNTIME_MOBILE_3D_V1')
    loader=re.sub(r'patch\.json\?v=\d+','patch.json?v=7',loader)
    (ROOT/'shared/afb-runtime-mobile-3d-v1.js').write_text(loader,newline='\n')

    release='0.7.9-beta.19-cloudtest.99-mobile3d.7'
    index=(ROOT/'index.html').read_text()
    index=index.replace('kobi-v1','mobile-3d-v1').replace('AFB_RUNTIME_KOBI_V1','AFB_RUNTIME_MOBILE_3D_V1')
    index=re.sub(r'afb-runtime-mobile-3d-v1\.js\?v=\d+','afb-runtime-mobile-3d-v1.js?v=7',index)
    index=re.sub(r'0\.7\.9-beta\.19-cloudtest\.(?:98-kobi|99-mobile3d)\.\d+',release,index)
    index=re.sub(r'"fileSizes":\{[^}]*\\}',f'"fileSizes":{{"index-mobile-3d-v1.pck":{len(built)},"index.wasm":{(ROOT/"index.wasm").stat().st_size}}}',index,count=1)
    index=index.replace('</title>',' · MOBILE 3D TEST</title>',1)
    (ROOT/'index.html').write_text(index,newline='\n')

    version=json.loads((ROOT/'version.json').read_text())
    version['release_id']=release
    version['mobile_3d_movement']={
        'branch':'experiment/mobile-3d-movement',
        'player':'CharacterBody3D capsule',
        'input':'touch joystick + drag look; full forward stick sprints; Shift+forward sprints on keyboard',
        'physics':'gravity, floor snap, cached StaticBody3D world proxies, physical doors and police stair ramp',
        'police_station':'clean floor closure; side-door widths match scaled apertures; jamb/header trim sits inside openings; wall-base trim is surface-mounted',
        'sprint':'5.4 m/s with shared 100-point stamina, drain/recovery/exhaustion and HUD label SPRINTING',
        'save_schema':'unchanged'
    }
    version['runtime_delivery']='SHA-256-verified mobile-3d-v1 delta over .98-kobi.1'
    (ROOT/'version.json').write_text(json.dumps(version,indent=2)+'\n',newline='\n')
    (ROOT/'BUILD_VERSION.txt').write_text(
        'AFewBuds Cloud Test\nGame build: 0.7.9-beta.19\nWeb release: '+release+
        '\nRuntime: Experimental mobile CharacterBody3D movement on .98-kobi.1\n',newline='\n')

    receipt={
        'baseline_sha256':expected,
        'target_sha256':hashlib.sha256(built).hexdigest(),
        'target_bytes':len(built),
        'changed_existing_entries':changed,
        'added_entries':['scripts/mobile_physics_player.gd'],
        'unchanged_entries':len(before)-len(changed),
        'reconstruction_verified':True
    }
    (HERE/'build_receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',newline='\n')
    print(json.dumps(receipt))

if __name__=='__main__':main()
