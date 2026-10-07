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

func _rebuild_physics_obstacles() -> void:
	if physics_obstacle_root==null:return
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

'''
    assert 'func _build_controls() -> void:' in source
    source=source.replace('func _build_controls() -> void:',physics_helpers+'func _build_controls() -> void:',1)

    source=source.replace(
        '\thost.camera.position.y=WALK_EYE_HEIGHT\n\thost.camera.fov=78.0\n',
        '\thost.camera.position.y=WALK_EYE_HEIGHT\n\thost.camera.fov=78.0\n\t_sync_physics_from_camera()\n\tphysics_body.enabled=true\n',1)

    source=source.replace(
        'func end_walk() -> void:\n\tif not active: return\n\tactive=false\n',
        'func end_walk() -> void:\n\tif not active: return\n\tactive=false\n\t_stop_physics_walk()\n',1)

    source=source.replace(
        '\t\t_collect_map_colliders(self)\n\t\tcollision_timer=0.3\n',
        '\t\t_collect_map_colliders(self)\n\t\t_rebuild_physics_obstacles()\n\t\tcollision_timer=0.3\n',1)

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
		var step:Vector3=Basis(Vector3.UP,host.camera.rotation.y)*Vector3(movement.x,0,movement.y)*minf(delta,.05)*3.4
		var station_now:bool=police_station!=null and police_station.covers(host.camera.global_position)
		var station_next:bool=police_station!=null and police_station.covers(host.camera.global_position+step)
		if station_now or station_next:
			_stop_physics_walk()
			var local:Vector3=host.camera.position-ORIGIN
			var next:=local+Vector3(step.x,0,0)
			if _walkable(next):local=next
			next=local+Vector3(0,0,step.z)
			if _walkable(next):local=next
			local.y=(police_station.eye_height(ORIGIN+local) if police_station!=null and police_station.covers(ORIGIN+local) else WALK_EYE_HEIGHT)-ORIGIN.y
			host.camera.position=ORIGIN+local
			_sync_physics_from_camera()
		else:
			physics_body.enabled=true
			physics_body.drive(movement,host.camera.rotation.y)
			_sync_camera_from_physics()
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
        'if node==door_pivot:return','3D PHYSICS TEST','_sync_physics_from_camera()'
    ]:
        assert required in source,required
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
    updated=[]
    for n,b,f in entries:
        updated.append([n,neighborhood.encode() if n=='scripts/neighborhood.gd' else b,f])
    updated.append(['scripts/mobile_physics_player.gd',(HERE/'mobile_physics_player.gd').read_bytes(),0])

    built=east.pack.rebuild(baseline,fb,updated)
    after={n:b for n,b,f in east.pack.parse(built)[1]}
    changed=[n for n in before if before[n]!=after[n]]
    assert changed==['scripts/neighborhood.gd'],changed
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
    loader=re.sub(r'patch\.json\?v=\d+','patch.json?v=1',loader)
    (ROOT/'shared/afb-runtime-mobile-3d-v1.js').write_text(loader,newline='\n')

    release='0.7.9-beta.19-cloudtest.99-mobile3d.1'
    index=(ROOT/'index.html').read_text()
    index=index.replace('kobi-v1','mobile-3d-v1').replace('AFB_RUNTIME_KOBI_V1','AFB_RUNTIME_MOBILE_3D_V1')
    index=re.sub(r'afb-runtime-mobile-3d-v1\.js\?v=\d+','afb-runtime-mobile-3d-v1.js?v=1',index)
    index=re.sub(r'0\.7\.9-beta\.19-cloudtest\.(?:98-kobi|99-mobile3d)\.\d+',release,index)
    index=re.sub(r'"fileSizes":\{[^}]*\\}',f'"fileSizes":{{"index-mobile-3d-v1.pck":{len(built)},"index.wasm":{(ROOT/"index.wasm").stat().st_size}}}',index,count=1)
    index=index.replace('</title>',' · MOBILE 3D TEST</title>',1)
    (ROOT/'index.html').write_text(index,newline='\n')

    version=json.loads((ROOT/'version.json').read_text())
    version['release_id']=release
    version['mobile_3d_movement']={
        'branch':'experiment/mobile-3d-movement',
        'player':'CharacterBody3D capsule',
        'input':'existing touch joystick + drag look',
        'physics':'gravity, floor snap, real StaticBody3D obstacle proxies',
        'police_station':'retains proven floor-aware station movement in this first migration pass',
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
