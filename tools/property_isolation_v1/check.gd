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
 var computer_area:Node=editor.equipment_world.rendered[computer_id].find_children("*","Area3D",true,false)[0]
 check(computer_area.get_meta("equipment_container")=="house:computer","Computer interaction belongs to its placed property")
 game.camera.global_position=Vector3(30,1.64,0)
 game.neighborhood.location_ops.computer("house")
 check(game.neighborhood.location_ops.computer_context=="house" and inv.operation()=="house","House computer selects house inventory")
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
 game.queue_free();await process_frame
 print("PROPERTY_ISOLATION_RESULT: ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
