extends Node
var chapter:RefCounted
var rod:Node3D
var rod_button:Button
var tick_timer:=0.0
var host:Node3D
var inventory:Node
var model:RefCounted
var layer:CanvasLayer
var panel:PanelContainer
var list:VBoxContainer
var hint:Label
var placement_camera:=Transform3D.IDENTITY
var editing_camera:=false
var selected:=""
var property:="apartment"
var point:=Vector3.ZERO
var yaw:=0
var ghost:MeshInstance3D
var rendered:Dictionary={}
var originals:Dictionary={}
var stamp:=""
var known_tent_count:=-1
func setup(owner:Node3D,inv:Node) -> void:
 host=owner;inventory=inv
 model=load("res://scripts/property_furniture.gd").new();model.setup(host)
 chapter=load("res://scripts/chapter_five.gd").new();chapter.setup(host,model)
 layer=CanvasLayer.new();layer.layer=31;add_child(layer)
 panel=PanelContainer.new();panel.add_theme_stylebox_override("panel",inventory.ui_style("111713","617651"));layer.add_child(panel)
 var outer:=VBoxContainer.new();panel.add_child(outer)
 hint=inventory.label("FURNITURE",outer,20)
 var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(290,180);scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true;outer.add_child(scroll)
 list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
 inventory.button("Close / cancel placement",close,outer)
 ghost=MeshInstance3D.new();ghost.mesh=BoxMesh.new();ghost.set_meta("no_collision",true);host.add_child(ghost);ghost.hide()
 panel.hide()
 rod_button=inventory.button("Talk to Rod",func():
  if rod!=null and host.camera.global_position.distance_to(rod.global_position+Vector3.UP)<3.0 and chapter.meet_rod():rod.hide(),layer,true)
 rod_button.hide()
func is_open() -> bool:return panel.visible
func restore_camera() -> void:
 if editing_camera:host.camera.global_transform=placement_camera;editing_camera=false
func close() -> void:
 restore_camera()
 selected="";panel.hide();ghost.hide()
 if host.get("fp_player")!=null and not host.session_paused:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func clear() -> void:
 for child in list.get_children():list.remove_child(child);child.queue_free()
func open() -> void:
 if host.phone_open:host._toggle_phone()
 if host.neighborhood.location_ops.is_open():host.neighborhood.location_ops.close()
 panel.show();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;selected="";ghost.hide();render_list()
func render_list() -> void:
 restore_camera()
 clear();hint.text="FURNITURE / PROPERTY STORAGE"
 inventory.label("Purchased furniture remains yours when packed. Unlock to move; placement locks it again.",list)
 for id in model.state.items:
  var e:Dictionary=model.state.items[id]
  inventory.label(str(model.CATALOG[e.sku].name)+" - "+str(e.get("property","storage")).capitalize(),list)
  var row:=HBoxContainer.new();list.add_child(row)
  inventory.button("Unlock" if e.get("locked",false) else "Lock",func():model.lock(id,not bool(e.get("locked",false)));render_list(),row)
  inventory.button("Place / move",begin.bind(id),row).disabled=bool(e.get("locked",false))
  inventory.button("Pack",func():
   if model.pack(id):render_list()
   else:hint.text=model.error,row).disabled=bool(e.get("locked",false))
func shop(shop_id:String) -> void:
 open();clear();hint.text="UPGRADES / GROW TENTS" if shop_id=="grow" else "CENTRAL MARKET / FURNITURE"
 for sku in model.CATALOG:
  var item:Dictionary=model.CATALOG[sku]
  if item.shop!=shop_id:continue
  inventory.label("%s - $%d"%[item.name,model.price_for(sku)],list,19)
  inventory.label("Grow rooms only. Three plant slots." if sku=="grow_tent" else "Place in any usable room. Delivered to Property Storage.",list)
  inventory.button("Buy "+str(item.name),func():
   var id:String=model.own(sku)
   if id.is_empty():hint.text=model.error
   else:shop(shop_id);hint.text="Purchased - available in Property Storage.",list).disabled=host.cash<model.price_for(sku)
 if shop_id=="grow":
  inventory.button("Back to Upgrades",func():close();host.neighborhood.location_ops.equipment(),list)
 else:
  inventory.button("Back to Central Market",func():close();host.neighborhood.location_ops.market(),list)
func begin(id:String) -> void:
 restore_camera()
 placement_camera=host.camera.global_transform
 selected=id
 property="house" if host.neighborhood.location_ops.placement_room("house",host.camera.global_position)!="" else "apartment"
 if not model.controlled(property):hint.text="Enter a property you hold before arranging furniture.";selected="";return
 var e:Dictionary=model.state.items[id]
 if model.live(id):hint.text="Harvest or clear the plants before moving this tent.";selected="";return
 editing_camera=true
 point=host.camera.global_position-host.camera.global_basis.z*2.0;point.y=0
 point.x=snappedf(point.x,.25);point.z=snappedf(point.z,.25);yaw=0
 if e.get("property","")==property and e.has("position"):
  point=Vector3(e.position[0],0,e.position[2]);yaw=int(e.yaw)
 clear()
 inventory.label("Move the preview in 0.25 m steps. Green is valid. Keep doors and walking routes clear.",list)
 var controls:=GridContainer.new();controls.columns=3;list.add_child(controls)
 for axis in [["Left",Vector3(-.25,0,0)],["Right",Vector3(.25,0,0)],["Forward",Vector3(0,0,-.25)],["Back",Vector3(0,0,.25)]]:
  inventory.button(axis[0],func():point+=axis[1];preview(),controls)
 inventory.button("Rotate 90 degrees",func():yaw=posmod(yaw+90,360);preview(),controls)
 inventory.button("Place and lock",confirm,controls,true)
 inventory.button("Back to furniture",func():selected="";ghost.hide();render_list(),list)
 preview()
func obstacle() -> String:
 var problem:String=model.validate(selected,property,point,yaw)
 if not problem.is_empty():return problem
 var size:Vector3=model.size_of(selected,yaw)
 var box:=AABB(point+Vector3(-size.x/2,.08,-size.z/2),Vector3(size.x,size.y-.08,size.z))
 if box.grow(.35).has_point(Vector3(placement_camera.origin.x,.5,placement_camera.origin.z)):return "Leave room for yourself to stand."
 var shape:=BoxShape3D.new();shape.size=box.size
 var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform=Transform3D(Basis.IDENTITY,box.get_center());query.collision_mask=1
 var excluded:Array[RID]=[]
 for body in host.find_children("*","CollisionObject3D",true,false):
  var node:Node=body
  while node!=null and node!=host:
   var own_piece:bool=str(node.get_meta("furniture_id",""))==selected
   if originals.has(node.get_instance_id()):own_piece=own_piece or int(str(originals[node.get_instance_id()].id).trim_prefix("legacy_tent_"))==int(model.state.items[selected].get("legacy_slot",-1))
   if own_piece:excluded.append(body.get_rid());break
   node=node.get_parent()
 query.exclude=excluded
 if not host.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return "Clear the existing furniture, fixture or doorway first."
 for mesh in host.find_children("*","MeshInstance3D",true,false):
  if mesh==ghost or not mesh.is_visible_in_tree() or not mesh.mesh is BoxMesh or mesh.get_meta("no_collision",false):continue
  if mesh.get_meta("furniture_id","")==selected:continue
  if originals.has(mesh.get_instance_id()):
   var original_slot:int=int(str(originals[mesh.get_instance_id()].id).trim_prefix("legacy_tent_"))
   if original_slot==int(model.state.items[selected].get("legacy_slot",-1)):continue
  var bounds:AABB=mesh.global_transform*mesh.get_aabb()
  if bounds.size.y<.12 or maxf(bounds.size.x,bounds.size.z)<.3:continue
  if box.intersects(bounds):return "Clear the existing furniture or fixture first."
 return ""
func preview() -> void:
 if selected.is_empty():return
 ghost.mesh.size=model.size_of(selected,yaw);ghost.position=point+Vector3.UP*ghost.mesh.size.y/2
 var problem:=obstacle();hint.text="Ready to place" if problem.is_empty() else problem
 var mat:=StandardMaterial3D.new();mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.albedo_color=Color(0.3,.9,.4,.35) if problem.is_empty() else Color(1,.25,.2,.35)
 ghost.material_override=mat;ghost.show()
func confirm() -> void:
 if selected.is_empty():return
 var problem:=obstacle()
 if not problem.is_empty():hint.text=problem;return
 if model.place(selected,property,point,yaw):selected="";ghost.hide();render_list()
 else:hint.text=model.error
func _process(_delta:float) -> void:
 if host==null:return
 if is_open():
  if editing_camera and not selected.is_empty():
   var eye:Vector3=point+Vector3(0,2.8,2)
   for room in model.ROOMS[property].values():
    if room.has_point(Vector2(point.x,point.z)):
     eye.x=clampf(eye.x,room.position.x+.2,room.end.x-.2);eye.z=clampf(eye.z,room.position.y+.2,room.end.y-.2);break
   host.camera.global_position=eye;host.camera.look_at(point+Vector3.UP*.35)
  var screen:Vector2=host.get_viewport().get_visible_rect().size
  panel.size=Vector2(minf(360,screen.x-24),minf(360 if not selected.is_empty() else 540,screen.y-96))
  panel.position=Vector2(12,screen.y-panel.size.y-12 if screen.x<650 and not selected.is_empty() else 72)
 sync_world()
 tick_timer+=_delta
 if tick_timer>=.5:
  tick_timer=0;chapter.tick()
  if chapter.stage()==5 and chapter.started() and rod==null:
   rod=host.neighborhood.location_ops.crew.character_instance("Rod");host.add_child(rod);rod.position=Vector3(29,0,0)
  var nearby:bool=rod!=null and not chapter.complete() and host.camera.global_position.distance_to(rod.global_position+Vector3.UP)<3.0
  rod_button.visible=nearby and not host._any_modal_open() and not host.session_paused
  rod_button.position=host.get_viewport().get_visible_rect().size-Vector2(220,90)
func tent_id(node:Node) -> String:
 var n:=str(node.name)
 if n.begins_with("ExpansionTent2"):return "legacy_tent_1"
 if n.begins_with("ExpansionTent3"):return "legacy_tent_2"
 if n.begins_with("Tent") or n.begins_with("GrowLightFixture") or n.begins_with("GrowLightGlow") or n.begins_with("GrowLightHang"):return "legacy_tent_0"
 return ""
func sync_world() -> void:
 if known_tent_count!=host.grow_tent_count:
  model.setup(host);known_tent_count=host.grow_tent_count
 # Capture before moving. Existing detailed meshes and upgrades are reused intact.
 for child in host.get_children():
  if not child is Node3D:continue
  var id:=tent_id(child)
  if not id.is_empty() and not originals.has(child.get_instance_id()):
   originals[child.get_instance_id()]={"node":child,"transform":child.transform,"id":id}
 for i in range(host.plant_visuals.size()):
  var plant:Node3D=host.plant_visuals[i]
  if not originals.has(plant.get_instance_id()):originals[plant.get_instance_id()]={"node":plant,"transform":plant.transform,"id":"legacy_tent_%d"%(i/3)}
 for e in originals.values():
  var entry:Dictionary={}
  for candidate in model.state.items.values():
   if int(candidate.get("legacy_slot",-1))==int(str(e.id).trim_prefix("legacy_tent_")):entry=candidate;break
  if entry.is_empty():continue
  var ob:Node3D=e.node
  var prop:String=entry.get("property","legacy")
  if prop=="legacy":continue
  ob.visible=prop!="storage"
  for collider in ob.find_children("*","CollisionObject3D",true,false):
   if not collider.has_meta("furniture_collision_layer"):collider.set_meta("furniture_collision_layer",collider.collision_layer)
   collider.collision_layer=0 if prop=="storage" else int(collider.get_meta("furniture_collision_layer"))
  if prop=="storage":continue
  var slot:int=int(entry.legacy_slot)
  var origin:=Vector3(0 if slot==0 else (-3.2 if slot==1 else 3.2),0,-9.14 if slot==0 else -9.28)
  var pos:=Vector3(entry.position[0],entry.position[1],entry.position[2])
  ob.transform=Transform3D(Basis(Vector3.UP,deg_to_rad(float(entry.yaw))),pos)*Transform3D(Basis.IDENTITY,-origin)*e.transform
 var next_stamp:=JSON.stringify(model.state.items)
 if next_stamp==stamp:return
 stamp=next_stamp
 for node in rendered.values():node.queue_free()
 rendered.clear()
 for id in model.state.items:
  var entry:Dictionary=model.state.items[id]
  if entry.sku=="grow_tent" or not entry.has("position") or entry.property=="storage":continue
  var root:=Node3D.new();host.add_child(root);rendered[id]=root
  root.position=Vector3(entry.position[0],0,entry.position[2]);root.rotation.y=deg_to_rad(float(entry.yaw))
  build_prop(root,id,str(entry.sku))
func piece(root:Node3D,id:String,pos:Vector3,size:Vector3,color:String) -> void:
 var mesh:=MeshInstance3D.new();mesh.mesh=BoxMesh.new();mesh.mesh.size=size
 var mat:=StandardMaterial3D.new();mat.albedo_color=Color(color);mat.roughness=.8;mesh.material_override=mat
 mesh.position=pos;mesh.set_meta("furniture_id",id);mesh.set_meta("no_collision",true);root.add_child(mesh)
 var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=4;mesh.add_child(body)
 var shape:=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=size;body.add_child(shape)
func build_prop(root:Node3D,id:String,sku:String) -> void:
 var s:Vector3=model.size_of(id)
 if sku in ["coffee_table","dining_table"]:
  piece(root,id,Vector3(0,s.y-.04,0),Vector3(s.x,.08,s.z),"98734d")
  for x in [-1,1]:
   for z in [-1,1]:piece(root,id,Vector3(x*(s.x/2-.08),(s.y-.08)/2,z*(s.z/2-.08)),Vector3(.07,s.y-.08,.07),"313b36")
 elif sku=="bookcase":
  for x in [-1,1]:piece(root,id,Vector3(x*(s.x/2-.035),s.y/2,0),Vector3(.07,s.y,s.z),"846345")
  for shelf in range(5):piece(root,id,Vector3(0,.07+shelf*.44,0),Vector3(s.x,.06,s.z),"a38260")
  piece(root,id,Vector3(0,s.y/2,-s.z/2+.015),Vector3(s.x,s.y,.03),"68513c")
 elif sku=="bed":
  piece(root,id,Vector3(0,.2,0),Vector3(s.x,.4,s.z),"735740")
  piece(root,id,Vector3(0,.5,0),Vector3(s.x-.08,.25,s.z-.08),"879681")
  for x in [-.36,.36]:piece(root,id,Vector3(x,.66,-.7),Vector3(.6,.1,.4),"eee5ce")
 else:
  piece(root,id,Vector3(0,.32,0),Vector3(s.x,.4,s.z),"435b57")
  piece(root,id,Vector3(0,s.y/2,-s.z/2+.12),Vector3(s.x,s.y,.24),"526b64")
  for x in [-1,1]:piece(root,id,Vector3(x*(s.x/2-.1),.52,0),Vector3(.2,.45,s.z),"354b46")
