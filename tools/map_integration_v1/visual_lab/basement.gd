extends Node3D
# Walkable art-lab expansion with player-placed house equipment.
const HOLE=Rect2(41.15,-13.6,3.5,5.3)
const FLOOR=-3.8
var study:Node
var lights:Array[Light3D]=[]
var cut_count=0
var fixtures:Array[MeshInstance3D]=[]
var room_lights_on=true
func block(at:Vector3,size:Vector3,mat:Material,solid:bool=true)->MeshInstance3D:
 var n=MeshInstance3D.new();var mesh=BoxMesh.new();mesh.size=size;n.mesh=mesh;n.position=at;n.material_override=mat;n.layers=3;add_child(n)
 if solid:
  if size.y>2.0 and minf(size.x,size.z)<.3:n.set_meta("wall_mount_surface",true)
  var body=StaticBody3D.new();body.collision_layer=1;body.collision_mask=4
  var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=size;shape.shape=box;body.add_child(shape);n.add_child(body)
 return n
func portions(rect:Rect2)->Array[Rect2]:
 if not rect.intersects(HOLE):return [rect]
 var h=rect.intersection(HOLE);var result:Array[Rect2]=[]
 for r in [Rect2(rect.position,Vector2(h.position.x-rect.position.x,rect.size.y)),Rect2(Vector2(h.end.x,rect.position.y),Vector2(rect.end.x-h.end.x,rect.size.y)),Rect2(Vector2(h.position.x,rect.position.y),Vector2(h.size.x,h.position.y-rect.position.y)),Rect2(Vector2(h.position.x,h.end.y),Vector2(h.size.x,rect.end.y-h.end.y))]:
  if r.size.x>.001 and r.size.y>.001:result.append(r)
 return result
func cut_slab(at:Vector3,size:Vector3,mat:Material,solid:bool)->void:
 for r in portions(Rect2(Vector2(at.x-size.x/2,at.z-size.z/2),Vector2(size.x,size.z))):
  block(Vector3(r.get_center().x,at.y,r.get_center().y),Vector3(r.size.x,size.y,r.size.y),mat,solid)
func setup(owner_study:Node)->void:
 study=owner_study
 var game=study.game
 register_basement_room(game)
 var concrete=study.surface("777b72",1);var wall=study.surface("a4aa9b",3);var steel=study.plain("344746",.3)
 # Cut actual meshes and existing colliders at the stair opening, including the map ground.
 for n in game.neighborhood.get_children():
  if not n is MeshInstance3D or not n.mesh is BoxMesh:continue
  var size:Vector3=n.mesh.size*n.scale
  if n.position.y>.08 or n.position.y<-.4 or size.y>.4:continue
  var rect=Rect2(Vector2(n.position.x-size.x/2,n.position.z-size.z/2),Vector2(size.x,size.z))
  if not rect.intersects(HOLE):continue
  var solid=not n.find_children("*","StaticBody3D",true,false).is_empty()
  cut_slab(n.position,size,n.material_override,solid)
  n.hide();n.set_meta("basement_cut",true);cut_count+=1
  for body in n.find_children("*","StaticBody3D",true,false):body.collision_layer=0
 var ground=game.neighborhood.get_node("MobilePhysicsGround")
 ground.collision_layer=0
 var rect:Rect2=game.neighborhood.PHYSICS_MAP
 for r in portions(rect):
  var body=StaticBody3D.new();body.collision_layer=1;body.collision_mask=4
  var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(r.size.x,.1,r.size.y);shape.shape=box;shape.position=Vector3(r.get_center().x,-.05,r.get_center().y);body.add_child(shape);add_child(body)
 block(Vector3(35.4,FLOOR-.1,-6.15),Vector3(19,.2,15.5),concrete)
 cut_slab(Vector3(35.4,-.4,-6.15),Vector3(19,.16,15.5),wall,false)
 for x in [26,44.8]:block(Vector3(x,-2.1,-6.15),Vector3(.2,3.4,15.5),wall)
 for z in [-13.8,1.5]:block(Vector3(35.4,-2.1,z),Vector3(19,3.4,.2),wall)
 # Smooth collision ramp under visible treads, with handrails on both sides.
 var stairs=load("res://visual_lab/fire_escape.gd").new();add_child(stairs);stairs.metal=steel
 stairs.flight(42,-3.8,-1.9,-8.3,-12.4)
 stairs.flight(43.8,-1.9,0,-12.4,-8.3)
 block(Vector3(42.9,-1.97,-13),Vector3(3.5,.14,1.2),steel)
 for x in [41.15,44.65]:
  stairs.guard(Vector3(x,0,-13.6),Vector3(x,0,-8.3))
  stairs.guard(Vector3(x,-1.9,-13.6),Vector3(x,-1.9,-12.4))
 stairs.guard(Vector3(41.15,0,-13.6),Vector3(44.65,0,-13.6))
 stairs.guard(Vector3(41.15,0,-8.3),Vector3(42.95,0,-8.3))
 stairs.guard(Vector3(41.15,-1.9,-13.6),Vector3(44.65,-1.9,-13.6))
 # Keep the floor clear for player-placed tents.
 for x in [28.2,32.4,36.6,39.8]:
  var fixture=block(Vector3(x,-.6,-6.7),Vector3(.22,.08,9.6),study.plain("e4e8da"),false)
  for z in [-10.8,-2.6]:block(Vector3(x,-.52,z),Vector3(.06,.08,.06),steel,false)
  fixtures.append(fixture)
  var mat=fixture.material_override;mat.emission_enabled=true;mat.emission=Color("e4e8da");mat.emission_energy_multiplier=.6
  var light=SpotLight3D.new();light.position=Vector3(x,-.7,-6.7);light.rotation_degrees.x=-90;light.spot_range=14;light.spot_angle=75;light.light_energy=1.6;light.light_color=Color("edf2df");light.shadow_enabled=true;add_child(light);lights.append(light)
 block(Vector3(30,FLOOR+.95,.8),Vector3(6,.12,1),study.surface("85755c",8))
 for x in [27.3,32.7]:block(Vector3(x,FLOOR+.45,.8),Vector3(.15,.9,.8),steel)
 for x in [38,40]:
  var n=MeshInstance3D.new();var cyl=CylinderMesh.new();cyl.top_radius=.65;cyl.bottom_radius=.65;cyl.height=1.8;n.mesh=cyl;n.position=Vector3(x,FLOOR+.9,.5);n.material_override=study.plain("697e73");add_child(n)
  var body=StaticBody3D.new();var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(1.3,1.8,1.3);shape.shape=box;body.add_child(shape);n.add_child(body)
 set_room_lights(bool(game.house_control_state.get("basement_room_light",true)))
func set_room_lights(on:bool)->void:
 room_lights_on=on
 for light in lights:light.visible=on
 for fixture in fixtures:fixture.material_override.emission_energy_multiplier=.6 if on else 0.0
 study.game.house_control_state["basement_room_light"]=on
 study.game.neighborhood.house_controls.states["basement_room_light"]=on
func _unhandled_input(event:InputEvent)->void:
 if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_B:
  if study.game.neighborhood.physics_body.position.y<-.5:
   if not study.game._any_modal_open():
    set_room_lights(not room_lights_on)
    study.game._save_game()

func register_basement_room(game:Node)->void:
 var registry=game.inventory_system.furniture.model.registry
 if not registry.has_method("set_room_height"):return
 var record:Dictionary=registry.state.properties["house"]
 # Add one room to the existing house, retaining all ownership and service IDs.
 record.rooms["basement_grow"]=[26.3,-13.5,14.2,13.0]
 if not record.has("room_uses"):record["room_uses"]={}
 record.room_uses["basement_grow"]="grow"
 registry.set_room_height("house","basement_grow",-3.9,-.3)
 for room in record.rooms:
  if room!="basement_grow" and not record.get("room_heights",{}).has(room):
   registry.set_room_height("house",room,-.3,4.4)
