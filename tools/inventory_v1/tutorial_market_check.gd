extends SceneTree
var game:Node3D
var inv:Node
var ops:RefCounted
var failures:=0
var checks:=0
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;push_error("FAIL: "+message)
 else:print("PASS: ",message)
func stand(id:String):
 game.camera.position=inv.POSITIONS[id]+Vector3(0,.34,2)
 game.camera.look_at(inv.POSITIONS[id])
func empty_bag():
 game.location_state.carried_seeds={};game.location_state.carried_fertilizer=0
 game.location_state.property_storage=[];inv.state.backpack={}
func run():
 var desktop:bool=ResourceLoader.exists("res://prototype/apartment.tscn")
 game=load("res://prototype/apartment.tscn" if desktop else "res://scenes/main.tscn").instantiate();root.add_child(game)
 for i in 12:await process_frame
 game.set_process(false);game.neighborhood.set_process(false)
 if desktop:game.fp_player.set_physics_process(false)
 else:game.neighborhood.physics_body.set_physics_process(false)
 for timer in game.find_children("*","Timer",true,false):timer.stop()
 game.session_paused=false;game.tutorial_active=false;game.daily_report_pending=false;game.customer_waiting=false
 game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide();game.phone_open=false;game.phone_panel.hide()
 inv=game.inventory_system;inv.set_process(false);ops=game.neighborhood.location_ops
 inv.ensure_state();inv.state.backpack_level=1;empty_bag()
 game.location_state.pickup_seeds={};game.location_state.pickup_fertilizer=0;game.location_state.deliveries={}
 game.location_state.active_property="apartment";game.location_state.operation_contents_property="apartment"
 var strain:String="Purple Dream"
 game.cash=10000;game.grower_level=99
 var guide=inv.guide
 guide.state.active=false;guide.state.step=0;guide.state.events={};guide.state.completed=false
 guide.start()
 check(game._guide_protects_plants() and game._simulation_blocked(),"Guide protects the day and plants while learning")
 if desktop:
  var controls=root.get_node("DesktopInput");controls.controller_active=true
  check("D-pad Up" in guide.controls() and "D-pad Right" in guide.controls(),"PC guide uses current controller phone and backpack bindings")
  controls.controller_active=false
  check("mouse" in guide.controls(),"PC guide changes to keyboard and mouse instructions")
 else:check("joystick" in guide.controls() and "bottom-right" in guide.controls(),"Mobile guide explains touch movement and interaction")
 game.camera.position+=Vector3(4,0,0);guide._process(0)
 game.phone_open=true;guide._process(0);game.phone_open=false
 inv.open_backpack();guide._process(0);inv.close()
 check(int(guide.state.step)==3,"Movement, Phone and Backpack advance through actual actions")
 game._tutorial_record("harvest",0,strain)
 ops.order_seed(strain);ops.order_fertilizer()
 check(int(guide.state.step)==6,"Harvest and market purchases advance the guide")
 stand("market:orders")
 var cash_before:int=game.cash
 inv.collect_all()
 check(int(guide.state.step)==7 and game.cash==cash_before,"Collect All advances pickup without a second charge")
 game.plant_slots[0]=game._empty_plant_slot();game._plant_seed(0,strain);game._water_plant(0);game._fertilize_plant(0)
 check(int(guide.state.step)==10,"Real carried-seed planting, watering and fertilizer advance tutorial")
 game._tutorial_record("trim",-1,strain);game._tutorial_record("bag",-1,strain)
 game.bagged_inventory={strain:3};stand("apartment:packing")
 inv.transfer("apartment:packing","backpack","product|"+strain,3)
 stand("apartment:storage");inv.transfer("backpack","apartment:storage","product|"+strain,1)
 game.camera.position=Vector3(3,1.64,4.35);game.camera.look_at(ops.APT_PC);ops.computer("apartment");guide._process(0);ops.close()
 check(int(guide.state.step)==15 and not game._guide_protects_plants(),"Guide resumes the day for the customer-sale lesson")
 guide.record("sale")
 check(bool(guide.state.completed) and not bool(guide.state.active),"Sale completes the guide")
 game._save_game()
 var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
 check(bool(saved.location_state.first_day_guide.completed),"Guide completion persists across reloads")
 guide.start();guide.skip_step();guide.skip()
 check(int(guide.state.step)==1 and not bool(guide.state.active) and not game._guide_protects_plants(),"Guide supports skipping and resuming without blocking gameplay")
 empty_bag();inv.state.backpack_level=1;game.location_state.deliveries={}
 game.location_state.carried_fertilizer=34;game.location_state.pickup_seeds={strain:50};game.location_state.pickup_fertilizer=5
 var equipment:String="Grow Supply Shelf II"
 game.location_state.deliveries[equipment]={"property":"apartment","paid":180,"collected":false}
 stand("market:orders");cash_before=game.cash
 var collected:Dictionary=inv.collect_all()
 check(collected.collected==50 and game.location_state.carried_seeds[strain]==50,"Collect All fills the last pound with 50 seeds")
 check(game.location_state.pickup_fertilizer==5 and not inv.delivery_carried(equipment),"Overweight fertilizer and equipment stay in paid pickup")
 check(inv.backpack_weight()<=inv.backpack_limit() and game.cash==cash_before,"Collect All never exceeds backpack weight or charges again")
 collected=inv.collect_all()
 check(collected.collected==0 and game.location_state.pickup_fertilizer==5,"Repeated Collect All cannot duplicate full-backpack orders")
 game._save_game();saved=JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
 check(saved.location_state.pickup_fertilizer==5 and saved.location_state.deliveries.has(equipment),"Uncollected paid orders persist")
 empty_bag();stand("apartment:storage")
 check(not bool(inv.collect_all().ok),"Collect All requires returning to the market")
 stand("market:orders");collected=inv.collect_all()
 check(collected.remaining==0 and game.location_state.carried_fertilizer==5 and inv.delivery_carried(equipment),"Returning with space collects leftovers and preserves equipment receipt")
 check(game.cash==cash_before,"Returning for leftovers does not charge again")
 empty_bag();game.location_state.deliveries={};game.location_state.carried_fertilizer=34;game.location_state.carried_seeds={strain:25};game.location_state.pickup_seeds={strain:50}
 collected=inv.collect_all()
 check(collected.collected==25 and game.location_state.pickup_seeds[strain]==25,"Collect All can split a seed stack to fit remaining half-pound")
 ops.market();var pictures:int=ops.ui.body.find_children("*","TextureRect",true,false).size()
 check(pictures>=3,"Market categories show inventory artwork")
 ops.seeds();check(ops.ui.body.find_children("*","TextureRect",true,false).size()>0,"Seed offers use image cards")
 ops.supplies();check(ops.ui.body.find_children("*","TextureRect",true,false).size()==1,"Supplies has a fertilizer pack card")
 ops.equipment();check(ops.ui.body.find_children("*","TextureRect",true,false).size()>0,"Upgrades use image cards")
 ops.close();game.queue_free();await process_frame
 print("TUTORIAL_MARKET_TEST_RESULT: ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
