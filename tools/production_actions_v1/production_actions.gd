extends Node3D
# Task-driven presentation only. The host remains the sole inventory writer.
const Rig=preload("res://scripts/production_rig.gd")
var host:Node3D
var model:Node3D
var rig:Node3D
var player:AnimationPlayer
var active:=""
var scissors:Node3D
var moving_blade:MeshInstance3D
var bag:Node3D
var bud:MeshInstance3D
var tray:MeshInstance3D
var display:Label3D
var prior_display:=""
static func duration(action:String)->float:
 return {"trim":4.0,"bag":6.0,"harvest":4.5}.get(action,.95)
static func station(host_node:Node3D)->Node3D:
 var inv=host_node.inventory_system
 if inv==null or inv.furniture==null:return null
 var id:String=inv.furniture.model.primary(inv.worker_property(),"packing")
 return inv.furniture.equipment_world.rendered.get(id)
static func bounds_in(root:Node3D,mesh:MeshInstance3D)->AABB:
 return root.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
static func surface(root:Node3D)->MeshInstance3D:
 for key in ["BenchTop","TableTop"]:
  var n=root.find_child(key,true,false)
  if n is MeshInstance3D:return n
 for n in root.get_children():
  if n is MeshInstance3D and n.mesh is BoxMesh and n.mesh.size.x>1.0 and n.mesh.size.y<.2:return n
 return null
static func front(root:Node3D)->Vector3:
 var readout:Node3D=root.find_child("PackingScaleText",true,false)
 if readout!=null:
  var normal:Vector3=root.global_basis.inverse()*readout.global_basis.z
  return Vector3(0,0,-1 if normal.z<0 else 1)
 return Vector3.BACK
static func target(host_node:Node3D,action:String,slot:int)->Variant:
 if action=="harvest" and slot>=0 and slot<host_node.plant_visuals.size():
  var p:Node3D=host_node.plant_visuals[slot]
  var direction:=Vector3.BACK
  var floor_y:float=p.global_position.y
  var inv=host_node.inventory_system
  if inv!=null and inv.furniture!=null:
   var id:String=inv.furniture.model.item_for_slot(slot)
   var tent:Node3D=inv.furniture.equipment_world.rendered.get(id)
   if tent!=null:direction=tent.global_basis.z.normalized();floor_y=tent.global_position.y
  return Vector3(p.global_position.x,floor_y,p.global_position.z)+direction*.75
 if action not in ["trim","bag"]:return null
 var root:=station(host_node)
 if root==null:return null
 var top:=surface(root)
 if top==null:return null
 var box:=bounds_in(root,top)
 var x:=box.get_center().x
 var named=root.find_child("TrimTray" if action=="trim" else "ScalePlatform",true,false)
 if named is Node3D:x=root.to_local(named.global_position).x
 return root.to_global(Vector3(x,0,box.position.z-.30 if front(root).z<0 else box.end.z+.30))
func setup(owner_host:Node3D,character:Node3D):
 host=owner_host;model=character
 player=model.find_children("*","AnimationPlayer",true,false)[0]
 rig=Rig.new();rig.sk=model.find_children("*","Skeleton3D",true,false)[0];rig.sk.add_child(rig)
 scissors=Node3D.new();rig.add_child(scissors)
 box(scissors,Vector3(0,0,-.035),Vector3(.012,.008,.09),"c1cbcb")
 moving_blade=box(scissors,Vector3(.014,0,-.035),Vector3(.012,.008,.09),"c1cbcb")
 for x in [-.016,.016]:
  var ring:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=.009;torus.outer_radius=.014;torus.rings=12;torus.ring_segments=6;ring.mesh=torus;ring.position=Vector3(x,0,.02);scissors.add_child(ring)
 bag=Node3D.new();rig.add_child(bag);box(bag,Vector3.ZERO,Vector3(.073,.095,.012),"b7c9b5");box(bag,Vector3(0,.035,0),Vector3(.075,.005,.014),"41633f")
 bud=box(rig,Vector3.ZERO,Vector3(.035,.05,.035),"6a904d");bud.mesh=SphereMesh.new();bud.mesh.radius=.021;bud.mesh.height=.055
 tray=box(rig,Vector3.ZERO,Vector3(.24,.035,.18),"47564a")
 hide_props()
func box(parent:Node3D,at:Vector3,size:Vector3,color:String)->MeshInstance3D:
 var n:=MeshInstance3D.new();n.mesh=BoxMesh.new();n.mesh.size=size;n.position=at
 var mat:=StandardMaterial3D.new();mat.albedo_color=Color(color);mat.roughness=.7;n.material_override=mat;parent.add_child(n);return n
func hide_props():
 for n in [scissors,bag,bud,tray]:
  if n!=null:n.hide()
func stop():
 if active.is_empty():return
 active="";hide_props();rig.sk.clear_bones_global_pose_override()
 for bone in rig.sk.get_bone_count():rig.sk.set_bone_pose_rotation(bone,Quaternion.IDENTITY)
 if is_instance_valid(display):display.text=prior_display
 display=null;player.play("idle");player.advance(0)
func sync():
 var task:String=host.production_worker_pending_action
 var worker:Node3D=host.production_worker_node
 if not host.neighborhood.location_ops.crew.shop.production_allowed() or not host.packing_employee_active or not host.packing_employee_hired or host.production_worker_arrested or host.lay_low_active or task not in ["trim","bag","harvest"] or worker.global_position.distance_to(host.production_worker_target_position)>.16:
  stop();return
 if host._simulation_blocked():return
 if active!=task:
  stop();active=task;player.play("idle");player.advance(0);player.pause()
 hide_props();rig.action="pack";rig.clock=host.production_worker_action_dwell
 var t:=clampf(rig.clock/duration(task),0,1)
 var facing:Vector3
 var station_root:=station(host)
 if task=="harvest":
  var slot:int=host.production_worker_pending_slot
  if slot<0 or slot>=host.plant_visuals.size():stop();return
  facing=host.plant_visuals[slot].global_position
 else:
  if station_root==null:stop();return
  facing=worker.global_position-station_root.global_basis*front(station_root)
 facing.y=worker.global_position.y
 if worker.global_position.distance_to(facing)>.01:worker.look_at(facing,Vector3.UP)
 var working:=Vector3(0,1.13,-.34)
 if task!="harvest":
  var mesh:=surface(station_root)
  if mesh!=null:
   var top:=bounds_in(station_root,mesh)
   var point:=station_root.to_local(worker.global_position);point.y=top.end.y+.08;point.z=top.position.z+.10 if front(station_root).z<0 else top.end.z-.10
   working=rig.sk.to_local(station_root.to_global(point))
  var contact_mesh:MeshInstance3D=station_root.find_child("TrimTray" if task=="trim" else "ScalePlatform",true,false)
  if contact_mesh!=null:
   var contact:=bounds_in(station_root,contact_mesh)
   var near:=contact.get_center();near.y=contact.end.y+.015;near.z=contact.position.z+.04 if front(station_root).z<0 else contact.end.z-.04
   working=rig.sk.to_local(station_root.to_global(near))
 else:
  var plant:Node3D=host.plant_visuals[host.production_worker_pending_slot]
  var canopy:Node3D=plant.get_node_or_null("Canopy")
  var reach_point:=plant.global_position+Vector3(0,1.35,0)
  if canopy!=null:reach_point=canopy.global_position+Vector3(0,.35,0)
  working=rig.sk.to_local(reach_point)
 # Lean into the task, then return before the inventory completion boundary.
 var envelope:=smoothstep(0,.15,t)*(1-smoothstep(.86,1,t))
 rig.sk.set_bone_pose_rotation(rig.sk.find_bone("Spine"),Quaternion(Vector3.RIGHT,-.14*envelope))
 rig.sk.set_bone_pose_rotation(rig.sk.find_bone("Head"),Quaternion(Vector3.RIGHT,-.14*envelope))
 rig.sk.force_update_all_bone_transforms()
 var l:=working+Vector3(.08,.09,.05);var r:=working+Vector3(-.07,.10,.06)
 if task=="trim":
  r+=Vector3(.018*sin(t*TAU*3),.008*sin(t*TAU*6),0);scissors.show();bud.show()
  moving_blade.rotation.y=.35*(.5+.5*sin(t*TAU*10))
 elif task=="bag":
  bag.show();bud.visible=t<.62
  l=Vector3(.12,1.17,-.26)
  r=working+Vector3(0,.035,.035) if t<.40 else l+Vector3(-.03,.09,0)
  if t>.65:r=l+Vector3(lerpf(-.07,.025,smoothstep(.65,.85,t)),0,0)
  if t>.85:l=l.lerp(working+Vector3(.18,.01,.02),smoothstep(.85,1,t))
  update_scale(station_root,t)
 else:
  scissors.visible=t>.12 and t<.70;bud.visible=t>.52;tray.hide()
  moving_blade.rotation.y=.35*(.5+.5*sin(t*TAU*7))
  if t>.55:
   l=l.lerp(Vector3(.24,.94,-.04),smoothstep(.55,.85,t));r=r.lerp(Vector3(-.20,.95,-.08),smoothstep(.55,.85,t))
 # Clamp requested wrist targets to the physical chain, never stretch bones.
 for side in ["L","R"]:
  var shoulder:Vector3=rig.sk.get_bone_global_pose(rig.sk.find_bone("Shoulder_"+side)).origin
  var p:Vector3=l if side=="L" else r
  p=shoulder+(p-shoulder).limit_length(.44)
  var rest:=Vector3(.24 if side=="L" else -.24,.94,-.04)
  rig.pack_hand(side,rest.lerp(p,envelope))
 scissors.position=rig.grip("R");bag.position=rig.bag_pinch()-Vector3(.0365,.018,0)
 bud.position=rig.bag_pinch() if task!="bag" else rig.grip("R")-Vector3(0,.015,.03)
 if task=="bag" and t>=.18 and t<.40:bud.position=working
 if envelope<.05:hide_props()
func update_scale(root:Node3D,t:float):
 if not is_instance_valid(display):
  display=root.find_child("PackingScaleText",true,false)
  if display==null:return
  prior_display=display.text
 var inv=host.inventory_system
 var station_id:String=inv.furniture.model.container_of(inv.furniture.model.primary(inv.worker_property(),"packing"))
 var stock:Dictionary=inv.contents(station_id)
 var grams:=mini(host.PRODUCTION_WORKER_BATCH_SIZE,int(stock.get("trimmed|"+host.production_worker_pending_strain,0)))
 display.text="%.2f g" % (grams if t>=.18 and t<.40 else 0)

func _exit_tree():
 if is_instance_valid(display):display.text=prior_display
