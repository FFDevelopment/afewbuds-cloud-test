extends Node
var chapter:RefCounted
var equipment_world:Node
var portfolio_property:=""
var delivery_property:="backpack"
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
var placement_panel:PanelContainer
var placement_hint:Label
var place_button:Button
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
 equipment_world=load("res://scripts/equipment_world.gd").new();add_child(equipment_world);equipment_world.setup(self)
 layer=CanvasLayer.new();layer.layer=31;add_child(layer)
 panel=PanelContainer.new();panel.add_theme_stylebox_override("panel",inventory.ui_style("111713","617651"));layer.add_child(panel)
 var outer:=VBoxContainer.new();panel.add_child(outer)
 hint=inventory.label("FURNITURE",outer,20)
 var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(290,180);scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true;outer.add_child(scroll)
 list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
 inventory.button("Close / cancel placement",close,outer)
 ghost=MeshInstance3D.new();ghost.mesh=BoxMesh.new();ghost.set_meta("no_collision",true);host.add_child(ghost);ghost.hide()
 placement_panel=PanelContainer.new();placement_panel.add_theme_stylebox_override("panel",inventory.ui_style("111713","617651"));layer.add_child(placement_panel)
 var placement_box:=VBoxContainer.new();placement_panel.add_child(placement_box)
 placement_hint=inventory.label("Walk and look to position furniture",placement_box,16)
 placement_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var row:=HBoxContainer.new();placement_box.add_child(row)
 inventory.button("Rotate",rotate_item,row)
 place_button=inventory.button("Place",confirm,row,true)
 inventory.button("Cancel",close,row)
 placement_panel.hide()
 panel.hide()
 rod_button=inventory.button("Talk to Rod",func():
  if rod!=null and host.camera.global_position.distance_to(rod.global_position+Vector3.UP)<3.0 and chapter.meet_rod():rod.hide(),layer,true)
 rod_button.hide()
func is_open() -> bool:return panel.visible or is_placing()
func is_placing() -> bool:return not selected.is_empty() and editing_camera
func blocks_movement() -> bool:return panel.visible
func over_controls(p:Vector2) -> bool:return placement_panel.visible and placement_panel.get_global_rect().has_point(p)
func restore_camera() -> void:
 editing_camera=false
 placement_panel.hide()
func close() -> void:
 restore_camera()
 selected="";panel.hide();ghost.hide()
 if host.get("fp_player")!=null and not host.session_paused:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func clear() -> void:
 for child in list.get_children():list.remove_child(child);child.queue_free()
func inside(property_id:String) -> bool:
 return model.controlled(property_id) and host.neighborhood.location_ops.placement_room(property_id,host.camera.global_position)!=""
func open_property(property_id:String) -> void:
 open();portfolio_property=property_id;render_list()
func pickup(id:String) -> void:
 if not inside(str(model.state.items[id].get("property",""))):hint.text="Enter this property before picking up furniture.";return
 if model.pack(id):render_list()
 else:hint.text=model.error
func toggle_lock(id:String) -> void:
 if not inside(str(model.state.items[id].get("property",""))):hint.text="Enter this property before changing furniture.";return
 model.lock(id,not bool(model.state.items[id].get("locked",false)));render_list()
func open() -> void:
 portfolio_property=""
 if host.phone_open:host._toggle_phone()
 if host.neighborhood.location_ops.is_open():host.neighborhood.location_ops.close()
 panel.show();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;selected="";ghost.hide();render_list()
func render_list() -> void:
 restore_camera();clear();hint.text="FURNITURE & EQUIPMENT" if portfolio_property.is_empty() else portfolio_property.to_upper()+" · FURNITURE"
 inventory.label("Empty and unlock equipment before picking it up. Packed items go into your backpack with their upgrades intact.",list)
 for id in model.state.items:
  var e:Dictionary=model.state.items[id]
  if not portfolio_property.is_empty() and e.get("property","") not in [portfolio_property,"backpack"]:continue
  inventory.label(model.item_name(id)+" · "+str(e.get("property","backpack")).capitalize(),list)
  var reason:String=model.empty_reason(id)
  if not reason.is_empty():inventory.label(reason,list,13)
  var row:=HBoxContainer.new();list.add_child(row)
  if e.get("property","") in model.ROOMS:
   inventory.button("Unlock" if e.get("locked",false) else "Lock",toggle_lock.bind(id),row).disabled=not inside(str(e.property))
   inventory.button("Move",begin.bind(id),row).disabled=not inside(str(e.property)) or bool(e.get("locked",false)) or not reason.is_empty()
   inventory.button("Pick up",pickup.bind(id),row).disabled=not inside(str(e.property)) or bool(e.get("locked",false)) or not reason.is_empty()
  elif e.get("property","")=="backpack":inventory.button("Place",begin.bind(id),row).disabled=not (inside(portfolio_property) if not portfolio_property.is_empty() else (inside("apartment") or inside("house")))
  var upgrade:String=model.next_upgrade(id)
  if not upgrade.is_empty() and e.get("property","") in ["apartment","house","backpack"]:
   inventory.button(model.upgrade_label(id),func():
    if model.upgrade(id):render_list()
    else:hint.text=model.error,list).disabled=not reason.is_empty()
func shop(shop_id:String) -> void:
 open();clear();hint.text="CENTRAL MARKET / "+shop_id.to_upper()
 inventory.label("Buy packed items or order a box to a property's curb. Select packed items in Backpack to place them.",list)
 var choices:=HBoxContainer.new();list.add_child(choices)
 for destination in ["backpack","apartment","house"]:
  if destination!="backpack" and not model.controlled(destination):continue
  inventory.button(("✓ " if delivery_property==destination else "")+destination.capitalize(),func():delivery_property=destination;shop(shop_id),choices)
 for sku in model.CATALOG:
  var item:Dictionary=model.CATALOG[sku]
  if item.shop!=shop_id:continue
  inventory.label("%s · $%d · %d lb"%[item.name,model.price_for(sku),item.get("weight",8)],list,18)
  if model.is_tent({"sku":sku}):inventory.label("%d plants · grow rooms only"%item.plants,list,14)
  inventory.button("Buy / order",func():
   var id:String=model.own(sku,delivery_property)
   if id.is_empty():hint.text=model.error
   else:shop(shop_id);hint.text="Packed item added to backpack." if delivery_property=="backpack" else "Delivery ready at the "+delivery_property+" curb.",list).disabled=host.cash<model.price_for(sku)
 inventory.button("Back to market",func():close();host.neighborhood.location_ops.market(),list)
 inventory.button("Sell packed equipment",sell_menu,list)
func sell_menu() -> void:
 open();clear();hint.text="MARKET BUYBACK · 50% OF EQUIPMENT VALUE"
 for id in model.state.items:
  if model.state.items[id].get("property","")!="backpack":continue
  inventory.button("Sell %s · $%d"%[model.item_name(id),model.resale(id)],func():
   if model.sell(id):sell_menu()
   else:hint.text=model.error,list)
func begin(id:String) -> void:
 restore_camera()
 placement_camera=host.camera.global_transform
 selected=id
 property=portfolio_property if not portfolio_property.is_empty() else ("house" if inside("house") else "apartment")
 if not inside(property):hint.text="Enter a property you hold before arranging furniture.";selected="";return
 var e:Dictionary=model.state.items[id]
 if e.get("property","") not in [property,"backpack"]:hint.text="Pick up this item at its property first.";selected="";return
 if not model.empty_reason(id).is_empty():hint.text=model.empty_reason(id);selected="";return
 editing_camera=true
 point=host.camera.global_position-host.camera.global_basis.z*2.0;point.y=0
 point.x=snappedf(point.x,.25);point.z=snappedf(point.z,.25);yaw=0
 if e.get("property","")==property and e.has("position"):
  point=Vector3(e.position[0],0,e.position[2]);yaw=int(e.yaw)
 panel.hide();placement_panel.show()
 if host.get("fp_player")!=null:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
 aim();preview()
func rotate_item() -> void:
 yaw=posmod(yaw+90,360);preview()
func aim() -> void:
 var origin:Vector3=host.camera.global_position
 var forward:Vector3=-host.camera.global_basis.z
 var flat:=Vector3(forward.x,0,forward.z).normalized()
 # Keep large items beyond the player, without moving or zooming the camera.
 var size:Vector3=model.size_of(selected,yaw)
 var nearest:float=maxf(1.5,maxf(size.x,size.z)*.5+.8)
 var distance:float=3.25
 if forward.y<-.05:distance=origin.y / -forward.y * Vector2(forward.x,forward.z).length()
 distance=clampf(distance,nearest,5.5)
 point=origin+flat*distance;point.y=0
 point.x=snappedf(point.x,.25);point.z=snappedf(point.z,.25)
func handle_placement_input(event:InputEvent) -> bool:
 if not is_placing() or host.session_paused:return false
 if not event.is_pressed() or event.is_echo():return false
 var desktop:Node=host.get_node_or_null("/root/DesktopInput")
 var accept:bool=desktop.pressed(event,"interact") if desktop!=null else event is InputEventKey and event.keycode==KEY_E
 var cancel:bool=desktop.is_back(event) if desktop!=null else event is InputEventKey and event.keycode==KEY_ESCAPE
 if event is InputEventJoypadButton:
  accept=accept or event.button_index==JOY_BUTTON_A
  cancel=cancel or event.button_index==JOY_BUTTON_B
 if cancel:close();return true
 if accept:confirm();return true
 if (event is InputEventKey and event.keycode==KEY_R) or (event is InputEventJoypadButton and event.button_index==JOY_BUTTON_RIGHT_SHOULDER):rotate_item();return true
 # Opening another activity would strand the preview or interact through it.
 if desktop!=null:
  for action in ["phone","backpack","visitor","tour"]:
   if desktop.pressed(event,action):return true
 elif event is InputEventKey and event.keycode in [KEY_P,KEY_I]:return true
 return false
func obstacle() -> String:
 if not inside(property):return "Enter this property before placing furniture."
 var problem:String=model.validate(selected,property,point,yaw)
 if not problem.is_empty():return problem
 var size:Vector3=model.size_of(selected,yaw)
 var box:=AABB(point+Vector3(-size.x/2,.08,-size.z/2),Vector3(size.x,size.y-.08,size.z))
 if box.grow(.35).has_point(Vector3(host.camera.global_position.x,.5,host.camera.global_position.z)):return "Leave room for yourself to stand."
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
 placement_hint.text=hint.text+"\nWalk / look to aim | R / RB: rotate | E / A: place" if host.get("fp_player")!=null else hint.text+"\nMove with joystick; drag to aim"
 place_button.disabled=not problem.is_empty()
 var mat:=StandardMaterial3D.new();mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.albedo_color=Color(0.3,.9,.4,.35) if problem.is_empty() else Color(1,.25,.2,.35)
 ghost.material_override=mat;ghost.show()
func confirm() -> void:
 if selected.is_empty():return
 var problem:=obstacle()
 if not problem.is_empty():preview();return
 if model.place(selected,property,point,yaw):close()
 else:hint.text=model.error
func _process(_delta:float) -> void:
 if host==null:return
 if is_placing():
  if not host.session_paused:aim();preview()
  var screen:Vector2=host.get_viewport().get_visible_rect().size
  placement_panel.size=Vector2(minf(440,screen.x-24),0)
  placement_panel.position=Vector2((screen.x-placement_panel.size.x)/2,80)
 elif panel.visible:
  var screen:Vector2=host.get_viewport().get_visible_rect().size
  panel.size=Vector2(minf(360,screen.x-24),minf(540,screen.y-96))
  panel.position=Vector2(12,72)
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
 if equipment_world!=null:equipment_world.sync()
func piece(root:Node3D,id:String,pos:Vector3,size:Vector3,color:String) -> void:
 var mesh:=MeshInstance3D.new();mesh.mesh=BoxMesh.new();mesh.mesh.size=size
 var mat:=StandardMaterial3D.new();mat.albedo_color=Color(color);mat.roughness=.8;mesh.material_override=mat
 mesh.position=pos;mesh.set_meta("furniture_id",id);mesh.set_meta("no_collision",true);root.add_child(mesh)
 var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=4;mesh.add_child(body)
 var shape:=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=size;body.add_child(shape)
func build_prop(root:Node3D,id:String,sku:String) -> void:
 var s:Vector3=model.size_of(id)
 if sku.begins_with("bench_"):
  piece(root,id,Vector3(0,s.y-.08,0),Vector3(s.x,.12,s.z),"92744d")
  for x in [-1,1]:
   for z in [-1,1]:piece(root,id,Vector3(x*(s.x/2-.1),s.y/2, z*(s.z/2-.1)),Vector3(.08,s.y,.08),"384344")
  piece(root,id,Vector3(-.35,s.y,.05),Vector3(.4,.08,.35),"a5afad")
  piece(root,id,Vector3(.35,s.y,.05),Vector3(.35,.06,.25),"465246")
 elif sku.begins_with("shelf_") or sku.begins_with("storage_") or sku.begins_with("dealer_"):
  for x in [-1,1]:piece(root,id,Vector3(x*(s.x/2-.04),s.y/2,0),Vector3(.08,s.y,s.z),"354443")
  for i in range(4):piece(root,id,Vector3(0,.1+i*(s.y-.15)/3,0),Vector3(s.x,.07,s.z),"82917c")
  piece(root,id,Vector3(0,s.y/2,-s.z/2+.03),Vector3(s.x,s.y,.06),"263231")
 elif sku=="fridge":
  piece(root,id,Vector3(0,s.y/2,0),s,"909e99")
  piece(root,id,Vector3(0,s.y*.66,s.z*.5+.015),Vector3(s.x,.035,.025),"344440")
  piece(root,id,Vector3(s.x*.3,s.y*.45,s.z*.5+.06),Vector3(.045,.45,.08),"d2dad3")
 elif sku=="tv_console":
  piece(root,id,Vector3(0,.3,0),Vector3(s.x,.6,s.z),"586a52")
  piece(root,id,Vector3(0,1.25,0),Vector3(s.x*.9,1,.08),"162c28")
 elif sku=="dining_chair":
  piece(root,id,Vector3(0,.5,0),Vector3(.65,.12,.65),"74836d")
  piece(root,id,Vector3(0,.3,0),Vector3(.35,.55,.35),"465340")
  piece(root,id,Vector3(0,.85,-.27),Vector3(.65,.7,.08),"74836d")
 elif sku in ["floor_lamp","grow_light"]:
  piece(root,id,Vector3(0,.05,0),Vector3(.45,.1,.45),"394444")
  piece(root,id,Vector3(0,s.y/2,0),Vector3(.06,s.y,.06),"64716b")
  piece(root,id,Vector3(0,s.y-.1,0),Vector3(.5,.15,.45),"e9e7c9")
 elif sku=="computer":
  piece(root,id,Vector3(0,.85,0),Vector3(s.x,.1,s.z),"8b7353")
  for x in [-1,1]:piece(root,id,Vector3(x*.6,.4,0),Vector3(.08,.8,.65),"344440")
  piece(root,id,Vector3(0,1.2,-.15),Vector3(.85,.5,.06),"285d44")
 elif sku in ["water_kit","ventilation"]:
  piece(root,id,Vector3(0,s.y/2,0),s,"526466")
  piece(root,id,Vector3(0,s.y*.6,s.z/2),Vector3(s.x*.6,s.y*.4,.025),"253532")
 elif sku in ["coffee_table","dining_table"]:
  piece(root,id,Vector3(0,s.y-.04,0),Vector3(s.x,.08,s.z),"98734d")
  for x in [-1,1]:
   for z in [-1,1]:piece(root,id,Vector3(x*(s.x/2-.08),(s.y-.08)/2,z*(s.z/2-.08)),Vector3(.07,s.y-.08,.07),"313b36")
 elif sku in ["bookcase","wardrobe"]:
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
