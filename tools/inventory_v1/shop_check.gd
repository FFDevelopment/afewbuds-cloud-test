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
 check(inv.backpack_limit()==35*inv.POUND,"Starter backpack holds 35 lb")
 check(inv.unit_weight("product|Purple Dream")==inv.GRAM and inv.unit_weight("raw|Purple Dream")==inv.GRAM,"Packaged and unpackaged product weigh exactly one gram per gram")
 check(inv.weight_text(inv.unit_weight("seed|sample"))=="0.02 lb","Seeds weigh 0.02 lb each")
 check(5*inv.unit_weight("fertilizer")==5*inv.POUND,"Pack of five fertilizer weighs five pounds total")
 game.cash=10000;game.grower_level=10;game.apartment_rent_state.lease_active=true;game.apartment_rent_state.balance=0
 var seed:String=game.SEED_ORDER[0]
 var shelf_before:int=int(game.seed_inventory.get(seed,0))
 for i in 4:ops.order_seed(seed)
 var paid_cash:int=game.cash
 stand("market:orders");ops.pickup()
 check(inv.is_open() and inv.container_id=="market:orders" and inv.columns.get_child_count()==2,"Checkout opens orders and backpack with the same transfer interface")
 check(int(game.location_state.carried_seeds.get(seed,0))==0,"Opening pickup does not silently move all orders")
 inv.select_item("market:orders","seed|"+seed);inv.quantity.value=2;inv.commit_selection()
 check(game.location_state.carried_seeds[seed]==2 and game.location_state.pickup_seeds[seed]==2,"Collect chosen quantity into backpack; remainder stays at shop")
 check(game.cash==paid_cash and int(game.seed_inventory.get(seed,0))==shelf_before,"Pickup neither charges again nor deposits at the property")
 inv.commit_selection()
 check(game.location_state.carried_seeds[seed]==2,"Repeated collection submission cannot duplicate an order")
 check(inv.backpack_weight()==2*inv.unit_weight("seed|"+seed),"Seed quantities contribute exact item weight")
 check(not inv.transfer("backpack","market:orders","seed|"+seed,1).ok,"Paid pickup is not an unrestricted item disposal or refund container")
 inv.close();empty_bag()
 var fit:int=int(inv.backpack_limit()/inv.unit_weight("fertilizer"))
 game.location_state.carried_fertilizer=fit
 var remaining:int=inv.backpack_limit()-inv.backpack_weight()
 inv.state.backpack["product|Purple Dream"]=int(remaining/inv.unit_weight("product|Purple Dream"))
 check(inv.free_space("backpack","seed|"+seed)==0,"One shared weight budget includes all carried item types")
 check(not inv.transfer("market:orders","backpack","seed|"+seed,1).ok and game.location_state.pickup_seeds[seed]==2,"Overweight pickup keeps the paid order at the shop")
 var old_cash:int=game.cash;var old_fert:int=game.location_state.carried_fertilizer
 ops.fertilizer()
 check(game.cash==old_cash and game.location_state.carried_fertilizer==old_fert,"A fertilizer pack that cannot fit is not charged or partially purchased")
 stand("apartment:storage");inv.set_amount("apartment:storage","cash",25)
 var mass:int=inv.backpack_weight()
 check(inv.transfer("apartment:storage","backpack","cash",25).ok and inv.backpack_weight()==mass,"Cash can be taken into a full backpack without adding weight")
 game.location_state.carried_fertilizer+=1
 inv.ensure_state()
 check(inv.backpack_weight()>inv.backpack_limit() and game.location_state.carried_fertilizer==old_fert+1,"Legacy overweight inventory is preserved")
 stand("apartment:supply");game.fertilizer_units=0
 check(inv.transfer("backpack","apartment:supply","fertilizer",1).ok,"Overweight players can unload items")
 empty_bag();stand("market:orders");ops.market()
 var labels:Array=[]
 for button in ops.ui.body.find_children("*","Button",true,false):labels.append(button.text)
 check(labels.any(func(t):return "PACK OF 5" in t) and not labels.any(func(t):return "USES" in t),"Shop sells a pack of five fertilizer, not uses")
 old_cash=game.cash;ops.fertilizer()
 check(game.location_state.carried_fertilizer==5 and game.cash==old_cash-45,"Direct pack purchase adds five fertilizer to backpack exactly once")
 old_cash=game.cash
 check(inv.upgrade_backpack(1) and inv.state.backpack_level==2 and game.cash==old_cash-inv.BACKPACK_PRICES[0],"Checkout upgrade increases capacity and charges its displayed price")
 check(not inv.upgrade_backpack(1),"Stale upgrade button cannot buy another tier")
 stand("apartment:supply")
 check(not inv.upgrade_backpack(2),"Backpack upgrades cannot be bought remotely")
 empty_bag();stand("market:orders");game.supply_shelf_level=1
 var equipment:String="Grow Supply Shelf II"
 ops.order_equipment(equipment);paid_cash=game.cash
 check(inv.contents("market:orders").get("delivery|"+equipment)==1 and not inv.delivery_carried(equipment),"New paid equipment waits at shop pickup")
 game.camera.position=Vector3(3,1.64,4.35);game.camera.look_at(ops.APT_PC)
 ops.install(equipment)
 check(game.supply_shelf_level==1 and game.location_state.deliveries.has(equipment),"Computer cannot install equipment still at the shop")
 stand("market:orders")
 check(inv.transfer("market:orders","backpack","delivery|"+equipment,1).ok and inv.delivery_carried(equipment),"Paid equipment transfers into backpack with its receipt intact")
 stand("apartment:storage")
 check(inv.transfer("backpack","apartment:storage","delivery|"+equipment,1).ok and not inv.delivery_carried(equipment),"Uninstalled paid equipment can be stored without losing ownership")
 check(inv.transfer("apartment:storage","backpack","delivery|"+equipment,1).ok,"Stored paid equipment can be taken back")
 game.camera.position=Vector3(3,1.64,4.35);game.camera.look_at(ops.APT_PC)
 ops.install(equipment)
 check(game.supply_shelf_level==2 and not game.location_state.deliveries.has(equipment) and game.cash==paid_cash,"Installing carried equipment consumes it without a second charge")
 ops.manage("inventory");labels=[]
 for button in ops.ui.body.find_children("*","Button",true,false):labels.append(button.text)
 check(not labels.any(func(t):return "DEPOSIT" in t or "SUPPLIES: USE" in t),"Computer has no obsolete deposit-inventory controls")
 ops.close();game._save_game()
 var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
 check(int(saved.location_state.container_inventory.backpack_level)==2,"Backpack upgrade persists in the preview save")
 game.queue_free()
 for i in 3:await process_frame
 print("SHOP_INVENTORY_TEST_RESULT: ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
