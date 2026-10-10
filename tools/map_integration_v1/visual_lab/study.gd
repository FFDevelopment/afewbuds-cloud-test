extends Node
var game: Node3D
var preview_mode := true
var fire_escape: Node3D
var solid_details:Array[StaticBody3D]=[]
var detail: Node3D
var revised := true
var mobile := false
var dusk := false
var viewpoint := 0
var changes: Array[Dictionary] = []
var hidden_originals: Array[Node3D] = []
var proportions: Array[Dictionary] = []
const UPPER_FLOOR_BASE := 4.4
const UPPER_STORY_HEIGHT := 3.5
const ROOFLINE := UPPER_FLOOR_BASE + UPPER_STORY_HEIGHT * 2.0
var label: Label
var surfaces: Dictionary = {}
var views := [Vector3(7,0.12,21),Vector3(21,0.12,13),Vector3(-2,0.12,3.5),Vector3(14,0.12,-18),Vector3(2,0.12,0),Vector3(93,0.12,19),Vector3(176,0.12,19),Vector3(35,0.12,17),Vector3(29,0.12,-2),Vector3(43.3,-3.7,-6.8),Vector3(0,11.7,3)]
var targets := [Vector3(0,3,3),Vector3(16,2.3,2),Vector3(2,1.7,-1),Vector3(6.5,5.5,-2),Vector3(-1,2,6),Vector3(89,3,0),Vector3(162,3,-2),Vector3(35,2.8,-3),Vector3(29.2,1.8,3),Vector3(33,-2,-5),Vector3(5.7,12,-7)]
func surface(hex: String, finish: int) -> ShaderMaterial:
 var key := hex+str(finish)
 if surfaces.has(key): return surfaces[key]
 var m := ShaderMaterial.new()
 m.shader=load("res://visual_lab/surface.gdshader")
 if finish==7:
  # Hip roofs are authored as single-sided sheets; preserve underside visibility.
  m.shader=m.shader.duplicate()
  m.shader.code=m.shader.code.replace("specular_schlick_ggx;","specular_schlick_ggx, cull_disabled;")
 m.set_shader_parameter("tint",Color(hex));m.set_shader_parameter("finish",finish)
 surfaces[key]=m
 return m
func plain(hex: String, metallic: float=0.0) -> StandardMaterial3D:
 var m := StandardMaterial3D.new()
 m.albedo_color=Color(hex);m.roughness=.75;m.metallic=metallic
 return m
func box(at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
 var n := MeshInstance3D.new();var mesh := BoxMesh.new();mesh.size=size
 n.mesh=mesh;n.material_override=mat;n.position=at;detail.add_child(n)
 return n
func solid_box(at:Vector3,size:Vector3,mat:Material)->MeshInstance3D:
 var n=box(at,size,mat)
 var body=StaticBody3D.new();body.collision_layer=1;body.collision_mask=4
 var shape=CollisionShape3D.new();var collision=BoxShape3D.new();collision.size=size;shape.shape=collision;body.add_child(shape);n.add_child(body);solid_details.append(body)
 return n
func pipe(a: Vector3,b: Vector3,radius: float,mat: Material) -> void:
 var n := MeshInstance3D.new();var mesh := CylinderMesh.new()
 mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=a.distance_to(b);mesh.radial_segments=10
 n.mesh=mesh;n.material_override=mat;n.position=(a+b)*.5;detail.add_child(n)
 var direction: Vector3=(b-a).normalized()
 if absf(direction.dot(Vector3.UP))<.99:
  n.quaternion=Quaternion(Vector3.UP,direction)
func sign_text(value: String, at: Vector3, size: float, color: Color) -> void:
 var t := Label3D.new();t.text=value;t.position=at;t.pixel_size=size;t.font_size=64
 t.modulate=color;t.outline_size=0;t.no_depth_test=false;detail.add_child(t)
func replace(n: MeshInstance3D,m: Material) -> void:
 changes.append({"node":n,"before":n.material_override,"after":m})
 n.material_override=m
func rebalance_apartment(world: Node3D) -> void:
 # Ground floor remains unchanged. Give each upper floor 3.5 m and full-height windows.
 for node in world.get_children():
  if not node is MeshInstance3D:continue
  var title := str(node.name)
  var before: Transform3D=node.transform
  var changed := false
  if title=="ApartmentUpper":
   node.position.y=UPPER_FLOOR_BASE+UPPER_STORY_HEIGHT
   node.scale.y=(UPPER_STORY_HEIGHT*2.0)/node.mesh.size.y
   changed=true
  elif title=="ApartmentUpperRoof":
   node.position.y=ROOFLINE+.1
   changed=true
  elif title.begins_with("Window") and node.position.y>4.4 and node.position.x>=-5.5 and node.position.x<=5.5 and node.position.z>=-10.7 and node.position.z<=6.5:
   var row := 0 if node.position.y<8.0 else 1
   var old_center := 6.44+row*3.24
   var new_center := UPPER_FLOOR_BASE+row*UPPER_STORY_HEIGHT+1.8
   node.position.y=new_center+(node.position.y-old_center)*1.2
   node.scale.y*=1.2
   node.set_meta("visual_lab_floor",row+2)
   changed=true
  if changed:proportions.append({"node":node,"before":before,"after":node.transform})
func material_pass(world: Node3D) -> void:
 # Use semantic names, authored surface metadata and geometry together.
 # Never identify a facade by its name alone: interior plaster linings share prefixes.
 for n in world.get_children():
  if not n is MeshInstance3D:continue
  var title := str(n.name)
  var part := str(n.get_meta("fit_part",""))
  var mat: Material=n.material_override
  var tile := int(mat.get_meta("lab_tile",-99)) if mat else -99
  var color := str(mat.get_meta("lab_color","")) if mat else ""
  var box_mesh := n.mesh as BoxMesh
  var low: bool = box_mesh!=null and n.position.y<.05 and box_mesh.size.y<=.31
  if mat is StandardMaterial3D and mat.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:
   continue # Preserve real glazing; never replace it with an opaque facade material.
  if title.contains("Plaster"):
   replace(n,surface("afa593",3))
  elif title.begins_with("ApartmentUpper") and not title.contains("Roof") or title.begins_with("ApartmentBrick") or title.begins_with("ApartmentWindowBrick"):
   replace(n,surface("8c5944",0))
  elif title.begins_with("TreeBed"):
   replace(n,surface("4a4032",5))
  elif title.begins_with("HouseLawn"):
   replace(n,surface("526740",6))
  elif low and tile==5 and box_mesh.size.x>30.0:
   replace(n,surface("827b69",4))
  elif low and (tile==2 or title.contains("Sidewalk") or title.contains("SideWalk") or title.contains("Paving") or title.contains("Courtyard") or title=="HousePath" or title.begins_with("EntrancePath")):
   replace(n,surface("88877e",1))
  elif low and (tile==1 or tile==3 or title.contains("Street") or title.contains("Alley") or title.contains("Parking")) and not title.contains("Line"):
   replace(n,surface("343b3c",2))
  elif title.contains("Curb") or (box_mesh!=null and n.position.y<.2 and color=="c8c4b9"):
   replace(n,surface("a5a393",8))
  elif title.contains("Roof"):
   replace(n,surface("505454",7))
  elif title.contains("Foundation"):
   replace(n,surface("8c8778",8))
  elif part in ["ShopFront","ShopWest","ShopEast","ShopRear"]:
   replace(n,surface("82624c",0))
  elif part in ["HouseFront","HouseSide","HouseRear"]:
   replace(n,surface("8d6853",0))
  elif title.begins_with("GarageBrick"):
   replace(n,surface("89634e",0))
  elif title.begins_with("RearBuilding") or title.begins_with("OppositeBuilding") or title.begins_with("OuterHouse") or title.begins_with("EastResidence"):
   replace(n,surface("80715e" if n.position.x>100 else "89634e",0))
  elif title.contains("WindowFrame") or title.contains("WindowSill") or title.contains("EntryTrim") or title.contains("EntryLintel"):
   replace(n,surface("b4aa94",8))
  elif title.contains("Ceiling"):
   replace(n,surface("c4bfb0",3))
  elif title.contains("Floor") and box_mesh!=null and tile!=6:
   replace(n,surface("918b7b",1))
  # Full-height windows centered within each 3.5 m background story.
  if title.begins_with("Window") and n.position.y>0.5 and (n.position.x< -15 or n.position.x>54 or n.position.z< -23 or n.position.z>26):
   var before:Transform3D=n.transform
   var row := roundi((n.position.y-2.04)/3.5)
   var center := 2.04+row*3.5
   n.position.y=center+(n.position.y-center)*1.15
   n.scale.y*=1.15
   # Tangential width scales together with the mullion, glass and sill.
   if box_mesh.size.x>box_mesh.size.z:n.scale.x*=1.15
   else:n.scale.z*=1.15
   proportions.append({"node":n,"before":before,"after":n.transform})
 var wall_names := ["LeftWall","RightWall","RearWall","PartitionLeft","PartitionRight","PartitionHeader","FrontWall","FrontWallL","FrontWallR","FrontWallHeader","FrontWindowLeft","FrontWindowRight","FrontWindowBottom","FrontWindowTop"]
 for n in game.get_children():
  if not n is MeshInstance3D:continue
  var title := str(n.name)
  if title in wall_names:replace(n,surface("b1a793",3))
  elif title.contains("Baseboard") or title.begins_with("GrowDoorFrame") or title.begins_with("EntryJamb") or title.begins_with("EntryHead") or title.begins_with("EntryStop"):
   replace(n,surface("c9c0ab",8))
  elif title in ["MainCeiling","GrowRoomCeiling"]:replace(n,surface("c6c1b5",3))
  elif title=="GrowRoomFloor":replace(n,surface("707774",1))
func wood_material(floorboards:bool=false,existing:bool=false)->ShaderMaterial:
 var m=ShaderMaterial.new();m.shader=load("res://visual_lab/wood.gdshader")
 m.set_shader_parameter("tint",Color("8b7e6b" if floorboards or existing else "716453"))
 m.set_shader_parameter("floor_boards",floorboards);m.set_shader_parameter("existing_boards",existing)
 return m
func wood_pass()->void:
 var floor_mat=wood_material(true);var door_mat=wood_material();var plank_mat=wood_material(false,true)
 for n in game.find_children("*","MeshInstance3D",true,false):
  var mat:Material=n.material_override
  if mat==null and n.mesh!=null and n.mesh.get_surface_count()>0:mat=n.mesh.surface_get_material(0)
  var tile:int=int(mat.get_meta("lab_tile",-99)) if mat else -99
  var textured_wood:bool=mat is StandardMaterial3D and mat.albedo_texture!=null and mat.albedo_texture.resource_path.ends_with("walnut.png")
  if str(n.name)=="MainFloorPlanks":replace(n,plank_mat)
  elif str(n.name) in ["HouseFloor","MainFloor"]:replace(n,floor_mat)
  elif tile==6 or textured_wood:replace(n,door_mat)
func landing_apartment_door(y:float,z:float,unit:String)->void:
 var root=Node3D.new();root.name="LandingApartment"+unit;root.position=Vector3(5.1,y,z);detail.add_child(root)
 root.set_meta("visual_entrance_only",true)
 var frame=surface("b4aa94",8);var leaf=wood_material();var hardware=plain("a69f86",.65)
 # Local +X faces the east-side fire escape. Keep the frame inside the landing width.
 var parts=[
  ["Recess",Vector3(.025,1.38,0),Vector3(.05,2.76,1.04),plain("252d2a")],
  ["DoorLeaf",Vector3(.065,1.37,0),Vector3(.055,2.68,.86),leaf],
  ["UpperPanel",Vector3(.102,1.93,0),Vector3(.025,.95,.63),leaf],
  ["LowerPanel",Vector3(.102,.73,0),Vector3(.025,.88,.63),leaf],
  ["LeftJamb",Vector3(.085,1.40,-.485),Vector3(.16,2.8,.09),frame],
  ["RightJamb",Vector3(.085,1.40,.485),Vector3(.16,2.8,.09),frame],
  ["Lintel",Vector3(.085,2.83,0),Vector3(.17,.12,1.1),frame],
  ["Threshold",Vector3(.13,.025,0),Vector3(.26,.05,1.04),frame],
  ["HandlePlate",Vector3(.115,1.27,.30),Vector3(.025,.23,.075),hardware],
  ["Handle",Vector3(.16,1.28,.24),Vector3(.085,.04,.17),hardware],
  ["UnitPlaque",Vector3(.115,2.43,0),Vector3(.025,.16,.30),plain("283e3e",.3)]
 ]
 for spec in parts:
  var n=box(spec[1],spec[2],spec[3]);n.name=spec[0];n.reparent(root,false)
 var number=Label3D.new();number.name="UnitNumber";number.text=unit;number.font_size=48;number.pixel_size=.0018
 number.position=Vector3(.132,2.43,0);number.rotation.y=PI/2;number.modulate=Color("e7deca");number.outline_size=0;root.add_child(number)
 # Replace only window parts that overlap this closed entrance, avoiding a door over glass.
 for n in game.neighborhood.get_children():
  if not n is MeshInstance3D or not str(n.name).begins_with("Window"):continue
  if n.position.x<5.1 or n.position.x>5.5:continue
  var bounds:AABB=n.global_transform*n.get_aabb()
  if bounds.position.y<y+2.9 and bounds.end.y>y and bounds.position.z<z+.56 and bounds.end.z>z-.56:
   hidden_originals.append(n)
func setup(host: Node3D) -> void:
 game=host
 process_priority=100
 detail=Node3D.new();detail.name="StreetStudyDetails";game.add_child(detail)
 var world: Node3D=game.neighborhood
 rebalance_apartment(world)
 for n in world.get_children():
  if (n is Label3D and n.text=="CENTRAL MARKET") or str(n.name)=="ShopAwning":hidden_originals.append(n)
 material_pass(world)
 wood_pass()
 var stone:=surface("9c9281",8)
 var dark:=plain("283e3e",.3)
 var cream:=plain("c7bca5")
 # Close the original 10 cm house eave gap and give both roof sheets a soffit.
 var house_soffit:=box(Vector3(35,3.54,-5.5),Vector3(20.8,.18,17.8),stone)
 house_soffit.name="HouseEaveSoffit";house_soffit.layers=2
 var porch_soffit:=box(Vector3(35,3.36,4.1),Vector3(5.2,.12,3.6),stone)
 porch_soffit.name="HousePorchSoffit";porch_soffit.layers=2
 # Layered cornice and masonry bands, preserving the real door/window openings.
 for level in [4.35,UPPER_FLOOR_BASE+UPPER_STORY_HEIGHT,ROOFLINE-.04]:
  box(Vector3(0,level,6.24),Vector3(10.65,.22,.46),stone)
  for x in [-5.25,5.25]:
   if x>0 and level<ROOFLINE-1:
    var door_z:float=-7.4 if level<5 else 2.2
    for span in [Vector2(-10.5,door_z-.60),Vector2(door_z+.60,6.3)]:
     box(Vector3(x,level,(span.x+span.y)*.5),Vector3(.32,.22,span.y-span.x),stone)
   else:box(Vector3(x,level,-2.1),Vector3(.32,.22,16.8),stone)
 for x in [-5.02,5.02]:
  box(Vector3(x,2.15,6.23),Vector3(.32,4.3,.26),stone)
  box(Vector3(x,(UPPER_FLOOR_BASE+ROOFLINE)*.5,6.23),Vector3(.32,ROOFLINE-UPPER_FLOOR_BASE,.26),stone)
 for x in [-3.05,3.05]:box(Vector3(x,.32,6.24),Vector3(3.95,.58,.24),stone)
 # Entrance canopy with metal ties, transom and address plaque.
 box(Vector3(0,3.35,7.1),Vector3(2.8,.16,1.65),dark)
 for x in [-1.15,1.15]:pipe(Vector3(x,3.38,7.73),Vector3(x,4.05,6.22),.025,dark)
 box(Vector3(1.7,2.45,6.27),Vector3(.55,.72,.12),dark)
 sign_text("12",Vector3(1.7,2.46,6.35),.006,Color("e3d1a5"))
 # Downpipes, gutter and a side fire escape. Detail stays outside walkable interiors.
 for x in [-4.88,4.88]:pipe(Vector3(x,.1,6.39),Vector3(x,ROOFLINE-.15,6.39),.065,dark)
 box(Vector3(0,ROOFLINE+.02,6.35),Vector3(10.45,.14,.18),dark)
 fire_escape=load("res://visual_lab/fire_escape.gd").new()
 fire_escape.name="ConnectedFireEscape"
 detail.add_child(fire_escape)
 fire_escape.build(dark,ROOFLINE+.2)
 landing_apartment_door(4.4,-7.4,"201")
 landing_apartment_door(7.9,2.2,"301")
 # Central Market: deep sign fascia and fabric awning.
 box(Vector3(17,3.3,6.22),Vector3(10.15,.55,.24),dark)
 sign_text("CENTRAL  MARKET",Vector3(17,3.32,6.38),.0085,Color("eddfbe"))
 for i in range(20):
  var n:=box(Vector3(12.25+i*.5,2.62,6.88),Vector3(.5,.075,1.45),dark if i%2==0 else cream)
  n.rotation_degrees.x=12
  box(Vector3(12.25+i*.5,2.35,7.57),Vector3(.5,.25,.065),dark if i%2==0 else cream)
 for x in [12.12,21.88]:box(Vector3(x,1.35,6.25),Vector3(.2,2.65,.27),stone)
 # Crates, low planters and a notice board provide small-scale street detail.
 for x in [-4.25,4.25]:
  var pot=solid_box(Vector3(x,.28,6.8),Vector3(1,.55,.65),surface("75674f",3));pot.name="FrontPlanterLeft" if x<0 else "FrontPlanterRight"
  box(Vector3(x,.57,6.8),Vector3(.88,.05,.54),plain("3b3024"))
  for j in range(5):
   var n:=MeshInstance3D.new();var mesh:=SphereMesh.new();mesh.radius=.22;mesh.height=.45
   mesh.radial_segments=10;mesh.rings=5;n.mesh=mesh;n.material_override=plain("657b47")
   n.position=Vector3(x-.34+j*.17,.74,6.8);detail.add_child(n)
 solid_box(Vector3(11.15,1.4,5.9),Vector3(.12,1.15,1.2),dark)
 for z in [5.4,6.4]:solid_box(Vector3(11.15,.75,z),Vector3(.09,1.5,.09),dark)
 for x in [12.35,17,21.65]:pipe(Vector3(x,2.95,6.08),Vector3(x,2.48,7.5),.035,dark)
 for z in [-7,-5.8]:
  solid_box(Vector3(9.65,.35,z),Vector3(.9,.7,.9),surface("8a7352",3))
  for y in [.1,.3,.5,.68]:box(Vector3(9.65,y,z+.46),Vector3(.92,.035,.04),dark)
 # Interior crown trim and a warm, shaded lamp fill.
 for x in [-4.84,4.84]:box(Vector3(x,4.02,1),Vector3(.16,.18,9.8),cream)
 for z in [-3.85,5.85]:box(Vector3(0,4.02,z),Vector3(9.8,.18,.16),cream)
 var glow:=OmniLight3D.new();glow.position=Vector3(.1,3.55,.95);glow.light_color=Color("ffcf96")
 glow.light_energy=.55;glow.omni_range=7;glow.shadow_enabled=false;detail.add_child(glow)
 var canvas:=CanvasLayer.new();canvas.layer=110;add_child(canvas)
 var panel:=PanelContainer.new();panel.position=Vector2(18,110);canvas.add_child(panel)
 var style:=StyleBoxFlat.new();style.bg_color=Color(.035,.065,.07,.9);style.content_margin_left=16;style.content_margin_right=16;style.content_margin_top=12;style.content_margin_bottom=12
 panel.add_theme_stylebox_override("panel",style)
 label=Label.new();label.add_theme_font_size_override("font_size",16);panel.add_child(label)
 var basement=load("res://visual_lab/basement.gd").new();basement.name="BasementExpansion";game.add_child(basement);basement.setup(self)
 if preview_mode:
  game._resume_gameplay()
  goto_view(0)
 apply_look()
func goto_view(index: int) -> void:
 viewpoint=index%views.size()
 game.fp_player.position=views[viewpoint];game.fp_player.velocity=Vector3.ZERO
 game.camera.global_position=views[viewpoint]+Vector3.UP*game.fp_player.EYE_HEIGHT
 game.camera.look_at(targets[viewpoint])
 game.fp_player.yaw=game.camera.rotation.y;game.fp_player.pitch=game.camera.rotation.x
func apply_look() -> void:
 detail.visible=revised
 fire_escape.set_collision_active(revised)
 for body in solid_details:body.collision_layer=1 if revised else 0
 for n in hidden_originals:n.visible=not revised
 for item in proportions:item.node.transform=item.after if revised else item.before
 for change in changes:change.node.material_override=change.after if revised else change.before
 var env: Environment=game.neighborhood.outdoor_environment
 env.tonemap_mode=Environment.TONE_MAPPER_FILMIC if revised else Environment.TONE_MAPPER_LINEAR
 env.adjustment_enabled=revised
 env.adjustment_saturation=.92;env.adjustment_contrast=1.0;env.adjustment_brightness=.96
 game.neighborhood.outdoor_sun.directional_shadow_max_distance=45 if mobile else 85
 game.neighborhood.outdoor_sun.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL if mobile else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
 get_viewport().msaa_3d=Viewport.MSAA_DISABLED if mobile else Viewport.MSAA_2X
func _process(_delta: float) -> void:
 if game==null:return
 game.game_time_minutes=17*60+20 if dusk else 14*60
 if revised:
  var env: Environment=game.neighborhood.outdoor_environment
  env.ambient_light_energy=.28 if dusk else .32
  game.neighborhood.outdoor_sun.light_energy=.48 if dusk else .52
  game.neighborhood.outdoor_sun.light_color=Color("ffd1a1") if dusk else Color("fff0d6")
 label.text="AFB  /  VISUAL LAB 01.10  —  "+("REVISED" if revised else "ORIGINAL")+"\nF6 Compare   F7 "+("Light" if mobile else "Desktop")+" preset   F8 Time   F9 Viewpoint\nWASD Move   Mouse Look   E Interact   Esc Pause\nLocal test career  •  "+str(Engine.get_frames_per_second())+" FPS"
func _input(event: InputEvent) -> void:
 if not event is InputEventKey or not event.pressed or event.echo:return
 match event.physical_keycode:
  KEY_F6:revised=not revised;apply_look()
  KEY_F7:mobile=not mobile;apply_look()
  KEY_F8:dusk=not dusk
  KEY_F9:goto_view(viewpoint+1)
