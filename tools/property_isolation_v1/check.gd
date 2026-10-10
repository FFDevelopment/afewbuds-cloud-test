extends SceneTree
var failures:=0
var checks:=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 checks+=1
 if ok:print("PASS ",label)
 else:failures+=1;push_error(label)
func run():
 var desktop:=ResourceLoader.exists("res://prototype/apartment.tscn")
 var game=load("res://prototype/apartment.tscn" if desktop else "res://scenes/main.tscn").instantiate();root.add_child(game)
 for i in 20:await process_frame
 game.set_process(false);game.neighborhood.set_process(false)
 if desktop:game.fp_player.set_physics_process(false)
 else:game.neighborhood.physics_body.set_physics_process(false)
 for timer in game.find_children("*","Timer",true,false):timer.stop()
 game.gameplay_ready=true;game.tutorial_active=false;game.session_paused=false;game.daily_report_pending=false
 game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide()
 var inv=game.inventory_system;inv.set_process(false);inv.guide.state.active=false;inv.guide.state.completed=true
 inv.furniture.set_process(false)
 var model=inv.furniture.model
 var property=game.neighborhood.property_opportunity
 game.property_offer_unlocked=true;game.property_opportunity_state={"acquired":true,"agreement_signed":true,"agreement":"purchase"}
 game.location_state.active_property="apartment"
 var original_items:String=JSON.stringify(model.state.items)
 property.confirm_relocation(false)
 check(game.location_state.active_property=="apartment" and bool(game.property_opportunity_state.relocated),"Keep apartment option opens the house without making it primary")
 check(inv.operation()=="apartment" and JSON.stringify(model.state.items)==original_items,"Opening a second property does not move equipment or change stock ownership")
 inv.furniture.equipment_world.sync()
 game.property_opportunity_state.relocated=false
 property.confirm_relocation(true)
 check(game.location_state.active_property=="house" and inv.operation()=="apartment","Making house primary does not reassign apartment inventory")
 inv.furniture.equipment_world.sync()
 var house_items:=0
 for e in model.state.items.values():
  if e.get("property","")=="house":house_items+=1
 check(house_items==0,"New house starts without free furniture or stations")
 check(JSON.stringify(model.state.items)==original_items,"House acquisition and world sync preserve apartment furniture")
 game.cash=50000
 var computer_parts:=0
 var visible_templates:=0
 for node in game.neighborhood.get_children():
  if node.get_meta("equipment_template_group","")=="house_computer":
   computer_parts+=1
   if node.visible:visible_templates+=1
 check(computer_parts>100 and visible_templates==0,"Every original house computer part is captured and hidden")
 var orphan_tags:=0
 for node in game.neighborhood.get_children():
  if node is Label3D and node.text in [inv.title("house:packing"),inv.title("house:storage"),inv.title("house:supply"),inv.title("house:dealer")]:orphan_tags+=1
 check(orphan_tags==0,"Empty house has no floating station labels")
 var placement_tent:String=model.own("tent_1")
 inv.furniture.open_property("apartment");inv.furniture.close()
 game.camera.global_position=Vector3(41.8,1.64,-10)
 inv.open_backpack();inv.place_backpack_item(placement_tent)
 check(inv.furniture.is_placing() and inv.furniture.property=="house" and not inv.is_open(),"Backpack placement uses current house despite previously browsing apartment")
 for near_wall in [Vector3(39.35,0,-10),Vector3(40.45,0,-13.2)]:
  inv.furniture.point=near_wall;inv.furniture.yaw=0
  check(inv.furniture.obstacle().is_empty(),"House tent can place near wall at "+str(near_wall)+": "+inv.furniture.obstacle())
 for stair_edge in [Vector3(44.25,0,-10),Vector3(41.8,0,-13.2),Vector3(43.5,0,-7.8)]:
  inv.furniture.point=stair_edge
  check(not inv.furniture.obstacle().is_empty(),"Stair opening and rails stay clear: "+str(stair_edge))
 check(not model.validate(placement_tent,"house",Vector3(38.9,0,-10),0).is_empty(),"Tent still cannot cross the grow-room wall")
 inv.furniture.close()
 inv.furniture.open_property("house");inv.furniture.close()
 game.camera.global_position=Vector3(0,1.64,-7)
 inv.open_backpack();inv.place_backpack_item(placement_tent)
 check(inv.furniture.is_placing() and inv.furniture.property=="apartment","Backpack placement switches to the apartment without using Real Estate")
 inv.furniture.close()
 game.camera.global_position=Vector3(0,1.64,15)
 inv.open_backpack();inv.place_backpack_item(placement_tent)
 check(not inv.furniture.is_placing() and inv.is_open() and inv.notice.text.contains("Enter a property"),"Outdoor placement keeps backpack open and explains the restriction")
 inv.close();model.state.items.erase(placement_tent)
 for spec in [["bench_1",Vector3(41.2,0,-3.58)],["shelf_1",Vector3(43.5,0,-9.1)],["storage_1",Vector3(43.5,0,-1.2)]]:
  var id:String=model.own(spec[0],"house")
  check(not id.is_empty() and model.state.items[id].property=="house:delivery" and not model.state.items[id].has("position"),"House order waits at curb: "+spec[0])
  game.camera.global_position=model.CURBS.house+Vector3.UP*1.64
  check(inv.transfer("house:delivery","backpack","furniture|"+id,1).ok,"Collect house delivery into backpack: "+spec[0])
  check(model.place(id,"house",spec[1],0),"Place purchased house station: "+spec[0]+" "+model.error)
 var portable:String=model.own("dining_chair","backpack")
 check(not portable.is_empty() and model.place(portable,"house",Vector3(28,0,-2),0),"Backpack purchase can be placed in owned house")
 model.lock(portable,false)
 check(model.pack(portable),"Empty furniture can return to backpack")
 check(model.place(portable,"apartment",Vector3(1,0,2),0),"Same backpack item can be placed in owned apartment")
 inv.furniture.equipment_world.sync()
 var editor=inv.furniture
 model.lock(portable,false)
 game.camera.global_position=Vector3(0,1.64,15)
 editor.open_property("apartment");editor.begin(portable)
 check(not editor.is_placing(),"Outdoor furniture placement is blocked")
 editor.pickup(portable)
 check(model.state.items[portable].property=="apartment","Remote furniture pickup is blocked")
 game.camera.global_position=Vector3(28,1.64,0)
 editor.open_property("apartment");editor.begin(portable)
 check(not editor.is_placing(),"House visit cannot arrange apartment furniture")
 editor.open_property("house")
 check(editor.hint.text.contains("HOUSE"),"Real Estate opens the selected property furniture list")
 editor.close()
 var computer_id:String=model.own("computer")
 check(model.place(computer_id,"house",Vector3(30,0,1),0),"Backpack computer placed in house")
 editor.sync_world()
 var desk_meshes:Array=editor.equipment_world.rendered[computer_id].find_children("*","MeshInstance3D",true,false)
 var textured_parts:=0
 for mesh in desk_meshes:
  var material=mesh.get_active_material(0)
  if material is BaseMaterial3D and material.albedo_texture!=null:textured_parts+=1
 check(desk_meshes.size()>100 and textured_parts>0,"Purchased computer retains complete textured desk assembly")
 editor.selected=computer_id;editor.build_preview()
 check(editor.preview_model.find_children("*","MeshInstance3D",true,false).size()==desk_meshes.size(),"Computer placement preview matches complete placed model")
 check(editor.preview_model.find_children("*","CollisionObject3D",true,false).is_empty(),"Detailed placement preview cannot block placement")
 editor.clear_preview();editor.selected=""
 var saved_camera:Transform3D=game.camera.global_transform
 game.camera.global_position=Vector3(30,1.2,2.8);game.camera.look_at(Vector3(30,.8,1))
 editor.start_layout("house")
 check(editor.layout_focus==computer_id and not editor.layout_move.disabled,"Walk-around layout selects the complete desk")
 if desktop:
  var input=root.get_node("DesktopInput")
  var toggle:=InputEventKey.new();toggle.keycode=KEY_TAB;toggle.pressed=true
  check(editor.handle_placement_input(toggle) and editor.controls_active and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Tab releases cursor for furniture controls")
  check(editor.blocks_movement() and input.menu_root()==editor.layout_panel,"Furniture controls pause movement and expose correct toolbar")
  var selected_before:String=editor.layout_focus
  editor.refresh_layout()
  check(editor.layout_focus==selected_before,"Cursor mode preserves selected furniture")
  var back:=InputEventJoypadButton.new();back.button_index=JOY_BUTTON_B;back.pressed=true
  check(editor.handle_placement_input(back) and not editor.controls_active and editor.layout_mode,"Controller B returns to camera without closing layout")
  var pad_toggle:=InputEventJoypadButton.new();pad_toggle.button_index=JOY_BUTTON_Y;pad_toggle.pressed=true
  input._input(pad_toggle)
  check(editor.controls_active and input.menu_controls().size()==4,"Controller Y exposes all four furniture actions")
  editor.layout_move.grab_focus()
  var right:=InputEventJoypadButton.new();right.button_index=JOY_BUTTON_DPAD_RIGHT;right.pressed=true
  input._input(right)
  check(root.gui_get_focus_owner()==editor.layout_pickup,"D-pad navigates from Move to Pick up")
  editor.layout_move.grab_focus()
  var accept:=InputEventJoypadButton.new();accept.button_index=JOY_BUTTON_A;accept.pressed=true
  input._input(accept)
  check(editor.is_placing() and not editor.controls_active,"Controller A activates focused Move and returns to aiming")
  editor.handle_placement_input(toggle)
  check(input.menu_root()==editor.placement_panel,"Placement controls expose Rotate Place and Cancel")
  editor.handle_placement_input(back)
  editor.cancel_placement()
 editor.layout_move_item()
 check(editor.is_placing() and editor.layout_mode,"Layout move enters placement without reopening phone")
 editor.cancel_placement()
 check(editor.layout_mode and editor.layout_panel.visible and not editor.is_placing(),"Cancel placement returns to walk-around layout")
 editor.close()
 var stash_id:String=model.own("storage_5")
 game.camera.global_position=Vector3(41,1.5,-11);game.camera.look_at(Vector3(38.6,1.5,-11))
 editor.begin(stash_id);editor.snap_stash_to_wall()
 check(editor.wall_found and editor.obstacle().is_empty(),"Hidden stash snaps flush to a clear house wall: "+editor.obstacle())
 editor.wall_found=false
 check(not editor.obstacle().is_empty(),"Hidden stash cannot be placed on an empty floor")
 editor.close();model.state.items.erase(stash_id);game.camera.global_transform=saved_camera
 var computer_area:Node=editor.equipment_world.rendered[computer_id].find_children("*","Area3D",true,false)[0]
 check(computer_area.get_meta("equipment_container")=="house:computer","Computer interaction belongs to its placed property")
 game.camera.global_position=Vector3(30,1.64,0)
 var operation_before_computer:String=inv.operation()
 game.neighborhood.location_ops.computer("house")
 check(game.neighborhood.location_ops.computer_context=="house" and inv.operation()==operation_before_computer and game.neighborhood.location_ops.management_app=="","Computer opens property information without silently changing inventory or opening a second management interface")
 var computer_ops=game.neighborhood.location_ops
 var computer_crew=computer_ops.crew
 var existing_hire:bool=game.packing_employee_hired
 var existing_active:bool=game.packing_employee_active
 game.packing_employee_hired=true;game.packing_employee_active=true
 var worker_name:String=game._critical_production_sender()
 check(computer_ops.computer_staff_names("apartment").has(worker_name) and not computer_ops.computer_staff_names("house").has(worker_name),"Apartment worker does not automatically appear on house computer roster")
 computer_ops.manage("employees")
 var house_employees:Array[String]=[]
 for node in computer_ops.ui.body.find_children("*","Label",true,false):
  house_employees.append(node.text)
 check(" ".join(PackedStringArray(house_employees)).contains("No workers are assigned to this property"),"House employee page starts with empty local crew, not apartment staff")
 computer_ops.manage("business")
 var house_labels:Array[String]=[]
 for node in computer_ops.ui.body.find_children("*","Label",true,false):house_labels.append(node.text)
 check(" ".join(PackedStringArray(house_labels)).contains("HOUSE AT A GLANCE") and not " ".join(PackedStringArray(house_labels)).contains("APARTMENT STOREFRONT"),"House business dashboard shows its own operation instead of apartment storefront")
 check(computer_ops.computer_stock_total("house","storage","product|")==0 or computer_ops.computer_stock_total("house","storage","product|")==int(inv.contents("house:storage").get("product|Purple Dream",0)),"House business stock reads house-only storage")
 game.location_state.staff_assignments[worker_name]="house"
 check(computer_ops.computer_staff_names("house").has(worker_name) and not computer_ops.computer_staff_names("apartment").has(worker_name),"Per-property worker roster changes without creating a duplicate")
 game.location_state.staff_assignments[worker_name]="apartment"
 check(computer_ops.computer_staff_names("apartment").has(worker_name) and not computer_ops.computer_staff_names("house").has(worker_name),"Moving worker back restores separate apartment roster")
 game.packing_employee_hired=existing_hire;game.packing_employee_active=existing_active
 game.neighborhood.location_ops.close()
 model.lock(computer_id,false);model.pack(computer_id)
 check(model.place(computer_id,"apartment",Vector3(-1,0,0),0),"Packed computer can move to apartment")
 editor.sync_world()
 computer_area=editor.equipment_world.rendered[computer_id].find_children("*","Area3D",true,false)[0]
 check(computer_area.get_meta("equipment_container")=="apartment:computer","Moved computer changes its property association")
 game.camera.global_position=Vector3(-1,1.64,1)
 game.neighborhood.location_ops.computer("apartment")
 check(inv.operation()=="apartment","Apartment computer selects apartment inventory")
 game.neighborhood.location_ops.close()
 for i in range(game.plant_slots.size()):game.plant_slots[i]=game._empty_plant_slot()
 var strain:String="Purple Dream"
 inv.set_amount("apartment:packing","raw|"+strain,30)
 inv.set_amount("apartment:packing","trimmed|"+strain,0)
 inv.set_amount("apartment:packing","product|"+strain,0)
 inv.set_amount("apartment:storage","product|"+strain,4)
 inv.set_amount("house:packing","raw|"+strain,77)
 inv.set_amount("house:packing","trimmed|"+strain,0)
 inv.set_amount("house:packing","product|"+strain,0)
 inv.set_amount("house:storage","product|"+strain,13)
 # Reproduce an already-relocated beta save whose legacy adapters belong to the house.
 inv.activate_adapters("house")
 var house_before:Dictionary=inv.contents("house:packing").duplicate(true)
 game.packing_employee_hired=true;game.packing_employee_active=true;game.production_worker_arrested=false
 game.production_worker_pending_action="trim";game.production_worker_pending_slot=-1;game.production_worker_pending_strain=strain
 game._execute_production_worker_action()
 check(int(inv.contents("apartment:packing").get("trimmed|"+strain,0))>0,"Apartment worker trims apartment batches after the house is acquired")
 check(inv.contents("house:packing")==house_before and inv.operation()=="house","Apartment worker does not consume or deposit house batches; adapter is restored")
 game.production_worker_pending_action="bag";game.production_worker_pending_strain=strain
 game._execute_production_worker_action()
 var packed:int=int(inv.contents("apartment:packing").get("product|"+strain,0))
 check(packed>0 and inv.contents("house:packing")==house_before,"Apartment bagging stays on its apartment bench")
 game.production_worker_pending_action="store";game.production_worker_pending_strain=strain
 game._execute_production_worker_action()
 check(int(inv.contents("apartment:storage").get("product|"+strain,0))>4 and int(inv.contents("house:storage").get("product|"+strain,0))==13,"Apartment worker stocks only apartment storage")
 # Manual work also stays with the explicitly selected station.
 var packing=inv.packing
 packing.station_id="house:packing";packing.strain=strain;packing.amount=5
 var apartment_before:Dictionary=inv.contents("apartment:packing").duplicate(true)
 packing.commit_trim()
 check(int(inv.contents("house:packing").get("trimmed|"+strain,0))==5 and inv.contents("apartment:packing")==apartment_before,"Manual trimming at house bench cannot alter apartment bench")
 model.state.items["isolation_house_tent"]={"sku":"tent_1","property":"house","position":[41.8,0,-12],"yaw":0,"upgrades":{},"condition":100}
 inv.furniture.equipment_world.sync()
 var house_slot:int=int(model.state.items.isolation_house_tent.slots[0])
 game.plant_slots[house_slot]=game._empty_plant_slot()
 game.plant_slots[house_slot].stage=1;game.plant_slots[house_slot].strain=strain;game.plant_slots[house_slot].water=0;game.plant_slots[house_slot].fertilizer=0
 var house_grow=game.neighborhood.house_controls
 var grow_status:Dictionary=house_grow.grow_snapshot()
 check(int(grow_status.tents)==1 and int(grow_status.capacity)==1 and int(grow_status.active)==1 and int(grow_status.dry)==1,"House grow panel reads placed tent, assigned pot and dry plant")
 check(house_grow.title("switch_grow_lights").contains("1 TENT"),"House panel no longer reports missing equipment when house tent is installed")
 check(house_grow.grow_panel_label!=null and house_grow.grow_panel_label.text.contains("PLANTS 1/1"),"House wall grow panel displays live 1/1 plant count")
 # The wall status must track live water/health changes without reopening it.
 game.neighborhood.location_ops.update(.6)
 check(house_grow.grow_panel_label.text.contains("DRY 1"),"House panel polls current dry plant status")
 game.plant_slots[house_slot].water=95
 game.neighborhood.location_ops.update(.6)
 check(house_grow.grow_panel_label.text.contains("DRY 0"),"House panel removes dry warning after watering without player interaction")
 game.plant_slots[house_slot].water=0
 game.neighborhood.location_ops.update(.6)
 check(house_grow.grow_panel_label.text.contains("DRY 1"),"House panel restores dry warning if crop dries again")
 var apartment_light_before:bool=game.grow_lights_on
 var house_light_before:bool=bool(game.house_control_state.get("grow_lights",false))
 var house_growth_before:float=float(model.growth_settings(house_slot,game._plant_growth_settings(false,house_slot),false).light_factor)
 check(house_grow.toggle_house_grow_lights(),"House panel can turn installed house tent lighting on or off")
 var house_light_after:bool=bool(game.house_control_state.get("grow_lights",false))
 var house_growth_after:float=float(model.growth_settings(house_slot,game._plant_growth_settings(false,house_slot),false).light_factor)
 check(house_light_before!=house_light_after and game.grow_lights_on==apartment_light_before,"House grow light switch changes house lighting without touching apartment")
 check(absf(house_growth_after-house_growth_before)>.05,"House plant growth reacts to actual house light state")
 var house_bulb=inv.furniture.equipment_world.rendered["isolation_house_tent"].get_node_or_null("GrowEquipmentVisual/GrowBeam")
 check(house_bulb!=null and house_bulb.visible==house_light_after,"Placed house tent's real light follows house grow panel switch")
 # Independently installed ventilation: no unit means no house air toggle or
 # growth benefit, even if apartment ventilation happens to be turned on.
 var apartment_vent_before:bool=game.ventilation_on
 var apartment_power_before:float=game.neighborhood.location_ops._apartment_power_rate()
 check(not bool(house_grow.grow_snapshot().ventilation) and not house_grow.toggle_house_ventilation(),"House ventilation reports not installed and refuses to turn on with no physical unit")
 model.state.items["isolation_house_vent"]={"sku":"ventilation","property":"backpack","locked":false,"condition":100,"upgrades":{}}
 check(model.place("isolation_house_vent","house",Vector3(43.8,0,-11.2),0),"Place separate ventilation unit in the house grow room: "+model.error)
 inv.furniture.equipment_world.sync()
 var installed_air:Dictionary=house_grow.grow_snapshot()
 check(bool(installed_air.ventilation) and not bool(installed_air.ventilation_on),"House control panel detects placed ventilation but starts with it switched off")
 check(house_grow.grow_panel_label.text.contains("AIR OFF"),"House wall panel shows installed but off ventilation")
 var fan_growth_off:float=float(model.growth_settings(house_slot,game._plant_growth_settings(false,house_slot),false).ventilation_factor)
 var fan_rate_off:float=model.utility_power("house")
 check(house_grow.toggle_house_ventilation(),"House wall panel can start its own installed ventilation")
 var fan_growth_on:float=float(model.growth_settings(house_slot,game._plant_growth_settings(false,house_slot),false).ventilation_factor)
 var fan_rate_on:float=model.utility_power("house")
 check(bool(house_grow.grow_snapshot().ventilation_on) and house_grow.grow_panel_label.text.contains("AIR ON"),"House panel displays actively running ventilation")
 check(fan_growth_on>fan_growth_off and fan_rate_on>fan_rate_off,"House fan improves house crop growth and adds only house utility cost while running")
 check(game.ventilation_on==apartment_vent_before and absf(game.neighborhood.location_ops._apartment_power_rate()-apartment_power_before)<.0001,"House ventilation does not change apartment ventilation or power")
 check(house_grow.toggle_house_ventilation() and not bool(house_grow.grow_snapshot().ventilation_on),"House ventilation can turn off independently")
 model.state.items["isolation_house_vent"].property="backpack"
 model.state.items["isolation_house_vent"].erase("position")
 inv.furniture.equipment_world.sync()
 check(not bool(house_grow.grow_snapshot().ventilation) and not bool(house_grow.grow_snapshot().ventilation_on),"Packing the house ventilation unit instantly removes it from live grow panel")
 check(absf(model.utility_power("house")-fan_rate_off)<.0001,"Packed ventilation no longer consumes house electricity")
 model.state.items.erase("isolation_house_vent")
 model.state.items["isolation_house_tent"].property="backpack"
 house_grow.refresh_grow_panel()
 check(int(house_grow.grow_snapshot().tents)==0 and house_grow.title("switch_grow_lights").contains("NO TENTS"),"Picking up house tent leaves zero installed tents on panel")
 check(not house_grow.toggle_house_grow_lights(),"House panel refuses light toggles without an installed tent")
 model.state.items["isolation_house_tent"].property="house"
 inv.furniture.equipment_world.sync()
 game.production_worker_pending_action="";game.production_worker_pending_slot=-1
 game._assign_production_worker_task()
 check(game.production_worker_pending_slot!=house_slot,"Apartment worker never selects an unattended house plant")
 inv.set_amount("apartment:supply","fertilizer",3);inv.set_amount("house:supply","fertilizer",2);inv.set_amount("backpack","fertilizer",0)
 inv.activate_adapters("apartment")
 game._fertilize_plant(house_slot)
 check(int(inv.contents("house:supply").get("fertilizer",0))==1 and int(inv.contents("apartment:supply").get("fertilizer",0))==3,"House plant uses house fertilizer without borrowing apartment supplies")
 inv.activate_adapters("house")
 var apartment_stock:Dictionary=inv.contents("apartment:storage").duplicate(true)
 var house_stock:Dictionary=inv.contents("house:storage").duplicate(true)
 game._save_game()
 var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
 check(int(saved.location_state.container_inventory.containers["apartment:storage"].get("product|"+strain,0))==int(apartment_stock.get("product|"+strain,0)),"Inactive property inventory is persisted separately in the save")
 inv.activate_adapters("apartment");inv.activate_adapters("house")
 check(inv.contents("apartment:storage")==apartment_stock and inv.contents("house:storage")==house_stock,"Repeated property access neither duplicates nor moves stock")
 game._load_game();inv.ensure_state();model.setup(game)
 check(int(inv.contents("apartment:storage").get("product|"+strain,0))==int(apartment_stock.get("product|"+strain,0)) and int(inv.contents("house:storage").get("product|"+strain,0))==13,"Loading the saved career preserves both independent property inventories")
 if desktop:
  property.overlay.hide();property.tour_bar.hide();game.phone_panel.hide();game.phone_open=false
  game.camera.global_position=Vector3(41.2,1.64,-1.7);game.camera.look_at(Vector3(41.2,1.64,-3.58))
  game.fp_player.position=Vector3(41.2,0,-1.7)
  for i in 3:await physics_frame
  game._update_target()
  check(not game.fp_prompt.text.is_empty(),"House bench has a desktop interaction prompt at standing eye height")
  game._use_target()
  check(inv.is_open() and inv.container_kind(inv.container_id)=="packing","Desktop interact opens the house bench inventory")
 # Free management buttons first: their signal Callables retain the
 # computer's RefCounted controller even after the test SceneTree is destroyed.
 computer_ops.close()
 for container in [computer_ops.ui.body,computer_ops.ui.footer]:
  for child in container.get_children():child.queue_free()
 await process_frame
 computer_ops=null;computer_crew=null
 game.queue_free();await process_frame
 print("PROPERTY_ISOLATION_RESULT: ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
