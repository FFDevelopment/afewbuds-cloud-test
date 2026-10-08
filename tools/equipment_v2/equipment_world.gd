extends Node
var editor:Node
var host:Node3D
var model:RefCounted
var originals:Dictionary={}
var rendered:Dictionary={}
var stamp:=""
var seated_id:=""
func setup(owner:Node) -> void:
 editor=owner;host=editor.host;model=editor.model
 capture()
 sync()
func group_for(node:Node) -> String:
 var n:=str(node.name)
 if n.begins_with("Tent") or n.begins_with("ExpansionTent") or n.begins_with("GrowLight") or n.begins_with("GrowSlot"):return "tent"
 if n=="AFBLoveseat":return "sofa"
 if n.begins_with("ApartmentComputer"):return "computer"
 if n.begins_with("FloorLamp"):return "floor_lamp"
 if n.begins_with("Bench") or n.begins_with("Packing") or n.begins_with("Scale") or n.begins_with("TrayRim") or n.begins_with("TrimTray") or n.begins_with("Baggie") or n.begins_with("HeatSealer"):return "packing"
 if node==host.supply_shelf_ref:return "supply"
 if n.begins_with("Locker") or n.begins_with("PremiumDealer"):return "dealer"
 if n.begins_with("Storage") or n.begins_with("Shelf") or n.begins_with("HiddenStash"):return "storage"
 return ""
func capture() -> void:
 capture_house()
 for node in host.get_children():
  if not node is Node3D or originals.has(node.get_instance_id()):continue
  var group:=group_for(node)
  if group.is_empty():continue
  originals[node.get_instance_id()]={"node":node,"group":group,"transform":node.transform,"visible":node.visible}
  node.set_meta("equipment_legacy",true)
  if group=="floor_lamp" and not model.state.get("lamp_migrated",false):
   model.state.items["legacy_floor_lamp"]={"sku":"floor_lamp","property":"apartment","position":[-3.78,0,3.35],"yaw":0,"locked":true,"legacy_group":"floor_lamp","paid":85,"condition":100,"upgrades":{}}
   model.state.lamp_migrated=true
  if group=="computer" and not model.state.get("computer_migrated",false):
   model.state.items["legacy_computer"]={"sku":"computer","property":"apartment","position":[4.15,0,4.35],"yaw":0,"locked":true,"legacy_group":"computer","paid":550,"condition":100,"upgrades":{}}
   model.state.computer_migrated=true
func hide_original(node:Node3D) -> void:
 node.hide();node.set_meta("no_collision",true)
 for body in node.find_children("*","CollisionObject3D",true,false):body.collision_layer=0
func sync() -> void:
 capture()
 for original in originals.values():hide_original(original.node)
 for name in ["FP_Bench","FP_Storage","FP_Locker","FP_Supply","FP_ApartmentComputer","FP_HouseComputer","FP_Couch"]:
  var target:Node=host.get_node_or_null(name)
  if target is CollisionObject3D:target.collision_layer=0
 if host.floor_lamp_light_ref!=null:host.floor_lamp_light_ref.hide()
 measure_templates()
 model.ensure_slots()
 while host.plant_visuals.size()<host.plant_slots.size():
  var plant:Node3D=host._create_stylized_plant(Vector3.ZERO)
  host._attach_plant_hit_area(plant,host.plant_visuals.size());host.plant_visuals.append(plant)
 var next_stamp:=JSON.stringify(model.state.items)
 if next_stamp!=stamp:
  stamp=next_stamp
  for node in rendered.values():node.free()
  rendered.clear()
  for id in model.state.items:
   var e:Dictionary=model.state.items[id]
   if str(e.get("property","")).ends_with(":delivery"):
    var root:=Node3D.new();host.add_child(root);rendered[id]=root
    root.position=model.CURBS[e.property.get_slice(":",0)]+Vector3(float(rendered.size()%3)*.55,0,0)
    editor.piece(root,id,Vector3(0,.4,0),Vector3(.5,.8,.5),"a78359")
    label(root,"DELIVERY\n"+model.item_name(id),Vector3(0,1.1,0));interaction(root,id,e.property,Vector3(.65,1,.65));continue
   if e.get("property","") not in model.ROOMS or not e.has("position"):continue
   var root:=Node3D.new();root.name="Owned_"+id;root.set_meta("equipment_id",id);host.add_child(root);rendered[id]=root
   root.position=Vector3(e.position[0],0,e.position[2]);root.rotation.y=deg_to_rad(float(e.get("yaw",0)))
   if model.is_tent(e):tent(root,id)
   elif not clone_legacy(root,id,e):editor.build_prop(root,id,e.sku)
   if not model.station_kind(id).is_empty():
    label(root,model.item_name(id),Vector3(0,model.size_of(id).y+.2,0))
    interaction(root,id,model.container_of(id),model.size_of(id))
   elif e.sku=="computer":interaction(root,id,e.property+":computer",model.size_of(id))
   elif e.sku in ["sofa","armchair","dining_chair"]:
    interaction(root,id,"seat",model.size_of(id))
   elif e.sku=="floor_lamp":interaction(root,id,"lamp",model.size_of(id))
   if e.sku in ["floor_lamp","grow_light"]:
    var light:=OmniLight3D.new();light.name="ItemLight";light.position=Vector3(0,1.7,0);light.omni_range=4.6;light.light_energy=.8;light.light_color=Color("ffd2a0") if e.sku=="floor_lamp" else Color("daf7df");root.add_child(light)
 for id in rendered:
  var light:Node3D=rendered[id].get_node_or_null("ItemLight")
  if light!=null:light.visible=host.floor_lamp_on if model.state.items[id].sku=="floor_lamp" else host.grow_lights_on
 for i in range(host.plant_visuals.size()):
  var plant:Node3D=host.plant_visuals[i]
  var id:String=model.item_for_slot(i)
  var placed:bool=not id.is_empty() and model.can_plant(i)
  plant.visible=placed
  plant.set_meta("no_collision",true);plant.set_meta("equipment_id",id);plant.set_meta("furniture_id",id)
  for body in plant.find_children("*","CollisionObject3D",true,false):body.collision_layer=(8 if body is Area3D else 1) if placed else 0
  if not placed:continue
  var e:Dictionary=model.state.items[id];var slots:Array=e.slots
  var width:float=model.size_of(id).x
  var x:float=(float(slots.find(i))-(slots.size()-1)*.5)*(width-.35)/slots.size()
  plant.global_transform=Transform3D(Basis(Vector3.UP,deg_to_rad(float(e.get("yaw",0)))),Vector3(e.position[0],0,e.position[2]))*Transform3D(Basis.IDENTITY,Vector3(x,.26,0))
 sync_levels()
func clone_legacy(root:Node3D,id:String,e:Dictionary) -> bool:
 var group:String=e.get("legacy_group","")
 if group.is_empty() or e.get("upgrades",{}).size()>0:return false
 var nodes:Array=[]
 for record in originals.values():
  if record.group==group and record.visible:nodes.append(record)
 if nodes.is_empty():return false
 # Keep existing meshes and materials, translated as one item from their original anchor.
 var anchor:Vector3=editor.inventory.POSITIONS.get("apartment:"+group,Vector3(-2.4,0,3.2));anchor.y=0
 if e.has("visual_anchor"):anchor=Vector3(e.visual_anchor[0],0,e.visual_anchor[2])
 var undo_rotation:=Basis(Vector3.UP,-PI/2) if group in ["packing","supply","storage","dealer"] else Basis.IDENTITY
 for record in nodes:
  var copy:Node3D=record.node.duplicate()
  for body in copy.find_children("*","CollisionObject3D",true,false):body.free()
  copy.set_meta("equipment_legacy",false);copy.set_meta("equipment_id",id);copy.set_meta("furniture_id",id)
  root.add_child(copy);copy.transform=Transform3D(undo_rotation,Vector3.ZERO)*Transform3D(Basis.IDENTITY,-anchor)*record.transform;copy.show()
  colliders(copy,id)
 return true
func colliders(node:Node,id:String) -> void:
 if node is MeshInstance3D and node.mesh!=null:
  node.set_meta("no_collision",true);node.set_meta("furniture_id",id)
  var box:AABB=node.get_aabb()
  if box.size.y>=.12 and maxf(box.size.x,box.size.z)>=.3:
   var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=4;node.add_child(body)
   var shape:=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=box.size;shape.position=box.get_center();body.add_child(shape)
 for child in node.get_children():
  if not child is CollisionObject3D:colliders(child,id)
func tent(root:Node3D,id:String) -> void:
 var s:Vector3=model.size_of(id)
 editor.piece(root,id,Vector3(0,s.y*.5,-s.z*.5+.04),Vector3(s.x,s.y,.08),"191c23")
 for side in [-1,1]:
  editor.piece(root,id,Vector3(side*(s.x*.5-.04),s.y*.5,0),Vector3(.08,s.y,s.z),"20232c")
  editor.piece(root,id,Vector3(side*(s.x*.5-.06),s.y*.5,s.z*.5-.06),Vector3(.06,s.y,.06),"5a6770")
 editor.piece(root,id,Vector3(0,s.y-.04,0),Vector3(s.x,.08,s.z),"232833")
 editor.piece(root,id,Vector3(0,.2,0),Vector3(s.x-.14,.08,s.z-.12),"353441")
 editor.piece(root,id,Vector3(0,s.y-.3,0),Vector3(s.x*.75,.05,.3),"d7f5d7")
 label(root,model.item_name(id),Vector3(0,s.y+.12,0))
func label(root:Node3D,text:String,position:Vector3) -> void:
 var caption:=Label3D.new();caption.text=text;caption.font_size=24;caption.pixel_size=.004;caption.position=position;caption.billboard=BaseMaterial3D.BILLBOARD_ENABLED;root.add_child(caption)
func sync_levels() -> void:
 model.record_progress()
 var property:String=editor.inventory.operation()
 for pair in [["packing","bagging_level"],["supply","supply_shelf_level"],["storage","storage_level"],["dealer","dealer_locker_level"]]:
  var id:String=model.primary(property,pair[0])
  host.set(pair[1],int(model.CATALOG[model.state.items[id].sku].get("tier",1)) if not id.is_empty() else 0)
 host.grow_tent_count=model.tent_count()
 host.auto_water_unlocked=false;host.ventilation_installed=false
 for e in model.state.items.values():
  if e.get("property","")!=property:continue
  if e.sku=="water_kit":host.auto_water_unlocked=true
  if e.sku=="ventilation":host.ventilation_installed=true

func capture_house() -> void:
 if not model.controlled("house"):return
 if not model.state.has("decor_migrated"):model.state["decor_migrated"]={}
 var bundles={
  "house_computer":["computer",Vector3(26.35,0,1.65)],"house_sofa":["sofa",Vector3(29.2,0,-3.6)],"house_coffee":["coffee_table",Vector3(29.2,0,-1.8)],
  "house_dining":["dining_table",Vector3(28.3,0,-9.4)],"house_bed":["bed",Vector3(36.5,0,-11.4)],
  "house_wardrobe":["wardrobe",Vector3(34.85,0,-8.6)],"house_tv":["tv_console",Vector3(29.2,0,2.2)],
  "house_packing":["bench_1",Vector3(41.2,0,-4.2)],"house_supply":["shelf_1",Vector3(44.25,0,-9.1)],
  "house_storage":["storage_1",Vector3(44.35,0,-3.2)],"house_dealer":["dealer_1",Vector3(38,0,-4.25)],
  "house_fridge":["fridge",Vector3(29.6,0,-7.7)],
  "house_chair_0":["dining_chair",Vector3(27.7,0,-10.5)],"house_chair_1":["dining_chair",Vector3(28.9,0,-10.5)],
  "house_chair_2":["dining_chair",Vector3(27.7,0,-8.3)],"house_chair_3":["dining_chair",Vector3(28.9,0,-8.3)]}
 for node in host.neighborhood.get_children():
  if not node is Node3D or originals.has(node.get_instance_id()):continue
  if node.global_position.x<25 or node.global_position.x>45 or node.global_position.z< -14 or node.global_position.z>3:continue
  var n:=str(node.get_meta("fit_part",node.name));var group:=""
  if n.begins_with("HouseComputer"):group="house_computer"
  elif n.begins_with("HouseFittedCouch"):group="house_sofa"
  elif n.begins_with("BedFrame") or n.begins_with("Mattress") or n.begins_with("Blanket") or n.begins_with("Pillow"):group="house_bed"
  elif n.begins_with("Wardrobe"):group="house_wardrobe"
  elif n.begins_with("Fridge"):group="house_fridge"
  elif n.begins_with("Chair") and node.position.x>25 and node.position.z<-7:
   group="house_chair_"+str((1 if node.position.x>28 else 0)+(2 if node.position.z>-9 else 0))
  elif n.begins_with("TV"):group="house_tv"
  elif n.begins_with("PackingCabinet"):group="house_dealer"
  elif n.begins_with("PackingScale") or n.begins_with("ScaleDisplay") or n.begins_with("PackingJar"):group="house_packing"
  elif n.begins_with("Table"):
   group="house_packing" if node.position.x>37 else ("house_dining" if node.position.z<-7 else "house_coffee")
  elif n.begins_with("Shelf"):
   group="house_supply" if node.position.z<-7 else "house_storage"
  if group.is_empty():continue
  originals[node.get_instance_id()]={"node":node,"group":group,"transform":node.global_transform,"visible":node.visible}
  node.set_meta("equipment_legacy",true)
  if not model.state.decor_migrated.has(group):
   var spec:Array=bundles[group];var at:Vector3=spec[1];var sku:String=spec[0]
   var kind:String=model.CATALOG[sku].get("kind","")
   model.state.items[group]={"sku":sku,"property":"house","position":[at.x,0,at.z],"visual_anchor":[at.x,0,at.z],"yaw":0,"locked":true,"legacy_group":group,"paid":model.CATALOG[sku].price,"upgrades":{},"condition":100}
   if not kind.is_empty():
    var primary:String=model.primary("house",kind)
    model.state.items[group].container="house:"+kind if primary.is_empty() else "house:"+kind+"@"+group
    if not editor.inventory.state.containers.has(model.state.items[group].container):editor.inventory.state.containers[model.state.items[group].container]={}
   model.state.decor_migrated[group]=true

func measure_templates() -> void:
 for id in model.state.items:
  var e:Dictionary=model.state.items[id]
  if not e.has("legacy_group") or e.get("template_measured",false):continue
  var combined:=AABB();var found:=false
  for record in originals.values():
   if record.group!=e.legacy_group or not record.visible:continue
   var meshes:Array=[]
   if record.node is MeshInstance3D:meshes.append(record.node)
   meshes.append_array(record.node.find_children("*","MeshInstance3D",true,false))
   for mesh in meshes:
    if mesh.mesh==null:continue
    var box:AABB=mesh.global_transform*mesh.get_aabb()
    combined=combined.merge(box) if found else box;found=true
  if not found:continue
  var center:Vector3=combined.get_center()
  e.visual_anchor=[center.x,0,center.z]
  if e.get("property","")==("house" if str(e.legacy_group).begins_with("house_") else "apartment"):e.position=[center.x,0,center.z]
  var size:Vector3=combined.size
  if int(e.get("yaw",0))%180==90:size=Vector3(size.z,size.y,size.x)
  e.size_override=[size.x,maxf(.2,combined.end.y),size.z]
  e.template_measured=true

func interaction(root:Node3D,id:String,container:String,size:Vector3) -> void:
 var area:=Area3D.new();area.collision_layer=16;area.collision_mask=0
 area.set_meta("interaction_id","equipment_container");area.set_meta("equipment_container",container);area.set_meta("furniture_id",id)
 var shape:=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(size.x+.1,maxf(1.2,size.y),size.z+.1);shape.position.y=shape.shape.size.y/2
 area.add_child(shape);root.add_child(area)

func nearby_seat() -> String:
 var nearest:="";var distance:=2.0
 for id in model.state.items:
  var e:Dictionary=model.state.items[id]
  if e.sku not in ["sofa","armchair","dining_chair"] or e.get("property","") not in model.ROOMS or not e.has("position"):continue
  var at:=Vector3(e.position[0],host.camera.global_position.y,e.position[2])
  var gap:float=host.camera.global_position.distance_to(at)
  if gap<distance:nearest=id;distance=gap
 return nearest
func seat_eye() -> Vector3:
 seated_id=nearby_seat()
 if seated_id.is_empty():return host.camera.global_position
 var e:Dictionary=model.state.items[seated_id]
 var at:=Vector3(e.position[0],0,e.position[2]);var yaw:float=deg_to_rad(float(e.get("yaw",0)))
 if e.get("legacy_group","")=="sofa":at+=Vector3(.5072,0,-.035).rotated(Vector3.UP,yaw)
 return host.neighborhood.bench_seating.eyes(at,yaw,load("res://scripts/scale_policy.gd").SEAT_HEIGHT)
func toggle_lamp() -> void:
 host.floor_lamp_on=not host.floor_lamp_on;host._update_day_night_visuals();host._save_game();sync()
