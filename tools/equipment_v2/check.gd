extends SceneTree
var failures:=0
var checks:=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
 else:print("PASS ",label)
func run():
 var desktop:=ResourceLoader.exists("res://prototype/apartment.tscn")
 var game=load("res://prototype/apartment.tscn" if desktop else "res://scenes/main.tscn").instantiate();root.add_child(game)
 for i in range(20):await process_frame
 game.set_process(false);game.neighborhood.set_process(false)
 if desktop:game.fp_player.set_physics_process(false)
 else:game.neighborhood.physics_body.set_physics_process(false)
 for timer in game.find_children("*","Timer",true,false):timer.stop()
 game.tutorial_active=false;game.session_paused=false;game.daily_report_pending=false
 game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide()
 var inv=game.inventory_system;inv.set_process(false);inv.guide.state.active=false;inv.guide.state.completed=true
 var editor=inv.furniture;editor.set_process(false)
 var m=editor.model
 game.cash=50000;game.property_opportunity_state={"acquired":true,"first_entry":true,"relocated":true}
 var original_slots:Array=game.plant_slots.duplicate(true)
 var original_count:int=m.state.items.size()
 m.setup(game)
 check(m.state.items.size()==original_count and game.plant_slots==original_slots,"Reload migration preserves items and plant contents")
 check(m.state.items.has("legacy_packing") and m.state.items.has("legacy_tent_0"),"Existing station and starter tent become owned items")
 for i in range(game.plant_slots.size()):game.plant_slots[i]=game._empty_plant_slot()
 game.packing_employee_active=false;game.production_worker_pending_action=""
 m.lock("legacy_tent_0",false)
 game.plant_slots[0].stage=0
 check(not m.pack("legacy_tent_0"),"Growing plant blocks pickup")
 check(not m.place("legacy_tent_0","house",Vector3(41.8,0,-12),0),"Growing plant blocks direct move")
 game.plant_slots[0].stage=3
 check(not m.pack("legacy_tent_0"),"Mature unharvested plant blocks pickup")
 game.plant_slots[0]=game._empty_plant_slot();game.plant_slots[0].dead=true
 check(not m.pack("legacy_tent_0"),"Dead plant must be cleared")
 game.plant_slots[0]=game._empty_plant_slot()
 var before:Dictionary=inv.contents("backpack")
 check(m.pack("legacy_tent_0"),"Empty unlocked tent packs")
 check(inv.contents("backpack").get("furniture|legacy_tent_0",0)==1,"Packed tent is a backpack item")
 check(not m.can_plant(0),"Packed tent cannot accept planting")
 check(not m.pack("legacy_tent_0"),"Repeated pickup cannot duplicate item")
 check(m.place("legacy_tent_0","house",Vector3(41.8,0,-12),0),"Packed tent places in house grow room")
 check(not inv.contents("backpack").has("furniture|legacy_tent_0"),"Placement consumes the backpack view exactly once")
 check(m.slot_property(0)=="house","Plant ownership follows its tent")
 var counts:Array=[]
 for sku in ["tent_1","tent_2","grow_tent","tent_4"]:
  var id:String=m.own(sku,"house")
  check(not id.is_empty(),"Order "+sku)
  counts.append(m.state.items[id].slots.size())
 check(counts==[1,2,3,4],"Four tent sizes allocate independent 1/2/3/4 plant slots")
 check(game.plant_slots.size()>9,"Plants are no longer capped at three fixed tents")
 var delivery:Dictionary=inv.contents("house:delivery")
 check(delivery.size()==4,"Orders are assigned to selected property's delivery box")
 var item:String=delivery.keys()[0]
 game.camera.global_position=Vector3.ZERO
 check(not inv.transfer("house:delivery","backpack",item,1).ok,"Delivery cannot be collected remotely")
 game.camera.global_position=m.CURBS.house+Vector3.UP*2.16
 check(inv.transfer("house:delivery","backpack",item,1).ok,"Delivery box transfers item to backpack at curb")
 check(not inv.transfer("house:delivery","backpack",item,1).ok,"Delivery cannot be collected twice")
 var carried:String=item.get_slice("|",1)
 check(not m.place(carried,"house",Vector3(28,0,-2),0),"Tents still reject non-grow rooms")
 inv.state.backpack["fertilizer"]=999 # carried fertilizer is separately authoritative
 game.location_state.carried_fertilizer=999
 var cash:int=game.cash
 check(m.own("tent_1").is_empty() and game.cash==cash,"Overweight purchase refuses without charging")
 inv.state.backpack.erase("fertilizer");game.location_state.carried_fertilizer=0
 game.camera.global_position=inv.POSITIONS["market:orders"]
 cash=game.cash;var quote:int=m.resale(carried)
 check(m.sell(carried) and game.cash==cash+quote,"Market pays the displayed resale value")
 check(not m.sell(carried) and game.cash==cash+quote,"Repeated resale cannot duplicate money")
 var bench:String="legacy_packing";m.lock(bench,false)
 game.untrimmed_inventory={"Street Green":12};game.trimmed_inventory={"Street Green":5};game.bagged_inventory={"Street Green":2}
 check(not m.pack(bench) and "12g" in m.error and "5g" in m.error,"Stock safety lists raw, trimmed and packaged contents")
 check(not m.upgrade(bench),"Equipment cannot upgrade over existing stock")
 game.untrimmed_inventory={};game.trimmed_inventory={};game.bagged_inventory={}
 inv.packing.active=true
 check(not m.pack(bench),"Active processing blocks pickup even when counters are empty")
 inv.packing.active=false
 var previous:String=m.state.items[bench].sku
 check(m.upgrade(bench) and m.state.items[bench].sku!=previous,"Empty equipment upgrades by item identity")
 var upgraded:String=m.state.items[bench].sku
 check(m.pack(bench),"Upgraded empty bench packs")
 check(m.state.items[bench].sku==upgraded and m.state.items[bench].upgrades.size()==1,"Packed equipment preserves upgrades")
 check(m.place(bench,"house",Vector3(40,0,-2),0),"Upgraded station places in new property")
 editor.sync_world()
 check(inv.all_positions().has("house:packing"),"Station interaction follows placed location")
 game.camera.global_position=Vector3(40,2.16,0)
 check(inv.reachable("house:packing"),"Moved station is reachable at its new position")
 inv.set_amount("house:packing","raw|Street Green",10)
 m.lock(bench,false)
 check(not m.pack(bench),"Inactive property's stock also blocks pickup")
 inv.open_container("house:packing");inv.packing.start("raw|Street Green")
 check(inv.packing.active,"Physical packing works at a moved non-primary-property bench")
 if inv.packing.active:
  inv.packing.selected=0;inv.packing.use_selected();inv.packing.selected=1
  for i in range(10):inv.packing.use_selected()
 check(inv.contents("house:packing").get("trimmed|Street Green",0)==10,"Processing preserves stock in correct property")
 inv.close()
 var saved_items:Dictionary=m.state.items.duplicate(true);var saved_plants:Array=game.plant_slots.duplicate(true)
 m.setup(game);editor.sync_world()
 check(m.state.items==saved_items and game.plant_slots==saved_plants,"Item IDs, upgrades, deliveries and plants survive reload")
 var slots:Array=m.state.items.legacy_tent_0.slots
 check(slots==[0,1,2],"Legacy plants retain their original indices")
 print("EQUIPMENT_V2_RESULT: ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
 game.queue_free();await process_frame;quit(0 if failures==0 else 1)
