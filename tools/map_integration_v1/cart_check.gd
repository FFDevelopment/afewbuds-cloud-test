extends SceneTree
var failures:=0
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
 if not ok:failures+=1;push_error(message)
 else:print("PASS ",message)
func run():
 var desktop:=ResourceLoader.exists("res://prototype/apartment.tscn")
 if root.has_node("AFBCloud"):await root.get_node("AFBCloud").prepare(true)
 var game=load("res://prototype/apartment.tscn" if desktop else "res://scenes/main.tscn").instantiate();root.add_child(game)
 for i in 3:await process_frame
 game.set_process(false);game.neighborhood.set_process(false)
 var player=game.fp_player if desktop else game.neighborhood.physics_body;player.set_physics_process(false)
 game.tutorial_active=false;game.session_paused=false;game.daily_report_pending=false
 var inv=game.inventory_system;inv.set_process(false);var cart=inv.furniture.cart
 game.camera.global_position=Vector3(0,2,0);game.cash=10000
 cart.state().clear();cart.add("seed|Street Green",10);cart.add("fertilizer",8);cart.add("item|tent_2",2)
 var expected:int=10*12+8*45+2*480
 check(cart.total()==expected and cart.count()==20,"Mixed cart quantities and total match prices")
 var before:Dictionary=inv.contents("market:orders").duplicate(true)
 game.cash=expected-1;var failed:Dictionary=cart.checkout()
 check(not failed.ok and game.cash==expected-1 and cart.count()==20 and inv.contents("market:orders")==before,"Insufficient cash charges nothing and retains entire cart")
 game.cash=10000;var result:Dictionary=cart.checkout()
 check(result.ok and game.cash==10000-expected and cart.state().is_empty(),"One checkout charges exact total and clears cart")
 check(int(inv.contents("market:orders").get("seed|Street Green",0))==int(before.get("seed|Street Green",0))+10,"All ordered seeds wait at checkout")
 check(int(inv.contents("market:orders").get("fertilizer",0))==int(before.get("fertilizer",0))+40,"Fertilizer packs expand to five uses each")
 var furniture_count:=0
 for key in inv.contents("market:orders"):
  if str(key).begins_with("furniture|"):furniture_count+=1
 check(furniture_count==2,"Equipment order creates two distinct owned tents")
 var cash_before:int=game.cash;check(not cart.checkout().ok and game.cash==cash_before,"Repeated checkout cannot double charge")
 game.camera.global_position=inv.POSITIONS["market:orders"]
 var collected:Dictionary=inv.collect_all()
 check(collected.ok and collected.remaining>0 and inv.backpack_weight()<=inv.backpack_limit(),"Collect what fits; overweight remainder stays paid at market")
 var pending:Dictionary=inv.contents("market:orders").duplicate(true)
 game.location_state=JSON.parse_string(JSON.stringify(game.location_state));inv.furniture.model.setup(game)
 check(inv.contents("market:orders")==pending,"Reload preserves every uncollected paid item")
 cart.add("fertilizer",2);game.location_state=JSON.parse_string(JSON.stringify(game.location_state))
 check(cart.count()==2,"Unpaid cart survives save reload")
 cart.show()
 check(inv.furniture.list.find_children("*","SpinBox",true,false).size()==1,"Cart exposes editable quantity")
 cart.state().clear();cart.state()["seed|Solar Frost"]=1;game.grower_level=1
 var locked:Dictionary=cart.checkout()
 check(not locked.ok and str(locked.reason).contains("Level"),"Checkout explains a locked seed requirement")
 print("MARKET_CART_RESULT: ","PASS" if failures==0 else "FAIL")
 game.queue_free();await process_frame;quit(1 if failures else 0)
