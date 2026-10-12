extends SceneTree
## One saved inventory per property, multiple independent storage assets.
## Run against the actual desktop and phone runtime, not a mocked sum.
var checks:int=0
var failures:int=0
func check(condition:bool,message:String)->void:
 checks+=1
 if condition:print("PASS ",message)
 else:failures+=1;push_error("MULTI_STORAGE FAIL: "+message)
func _initialize()->void:call_deferred("run")
func run()->void:
 var desktop:bool=ResourceLoader.exists("res://prototype/apartment.tscn")
 var scene:PackedScene=load("res://prototype/apartment.tscn" if desktop else "res://scenes/main.tscn")
 var game:Node3D=scene.instantiate()
 root.add_child(game)
 for i in 18:await process_frame
 game.set_process(false);game.neighborhood.set_process(false)
 if desktop:game.fp_player.set_physics_process(false)
 else:game.neighborhood.physics_body.set_physics_process(false)
 for timer in game.find_children("*","Timer",true,false):timer.stop()
 game.tutorial_active=false;game.tutorial_seen=true
 game.session_paused=false;game.daily_report_pending=false
 game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide()
 game.apartment_rent_state.lease_active=true
 game.property_opportunity_state={"acquired":true,"agreement_signed":true,"agreement":"purchase","relocated":true,"first_entry":true}
 game.cash=50000
 var inv:Node=game.inventory_system
 var model:RefCounted=inv.furniture.model
 check(inv.operation()=="apartment","Existing apartment is current property on first login")
 var primary:String="apartment:storage"
 var secondary:String="apartment:storage@fixture_apartment_extra"
 model.state.items["fixture_apartment_extra"]={"sku":"storage_2","property":"apartment","position":[-3,0,2.2],"yaw":0,"locked":true,"container":secondary,"paid":360,"upgrades":{}}
 inv.state.containers[secondary]={"product|Street Green":27,"product|Purple Dream":4}
 game._ensure_product_exists("Street Green")
 game.products["Street Green"]["reserved"]=0
 game.products["Street Green"]["listed"]=false
 inv.set_amount(primary,"product|Street Green",12)
 inv.set_amount(primary,"product|Purple Dream",0)
 inv.set_amount("backpack","product|Street Green",0)
 check(inv.storage_ids("apartment").size()==2,"Two placed apartment storage units recognized")
 check(inv.storage_stock("apartment","Street Green")==39,"Listing stock combines 12g primary and 27g secondary")
 check(inv.storage_stock("apartment")==43,"All strains aggregate once per actual storage unit")
 check(game._total_stored_stock()==43,"Gameplay total includes purchased storage unit, not just original shelf")
 check(game._storage_capacity()==inv.capacity(primary,"product|Street Green")+inv.capacity(secondary,"product|Street Green"),"Multiple storage capacities add without overfilling an individual shelf")
 game._set_reserved("Street Green",6)
 check(game._available_amount("Street Green")==33,"6g reservation applies once across 39g property stock")
 check(inv.available(secondary,"product|Street Green")==27,"Extra shelf remains physically accessible while total available exceeds its stock")
 game._build_products_local()
 var found_label:bool=false
 var found_limit:bool=false
 for label in game.phone_list.find_children("*","Label",true,false):
  if label.text.contains("39g stored") and label.text.contains("33g available"):found_label=true
 for field in game.phone_list.find_children("*","SpinBox",true,false):
  if is_equal_approx(field.max_value,39.0) and is_equal_approx(field.value,6.0):found_limit=true
 check(found_label,"Phone lists 39g total and 33g available, not the primary 12g")
 check(found_limit,"Phone reservation control accepts the total property stock")
 game._set_product_listed("Street Green",true)
 check(bool(game.products["Street Green"].listed),"Product can be listed from combined storage")
 check(game._consume_player_sale_stock("Street Green",20),"Player sale consumes one order across both storage units")
 check(inv.storage_stock("apartment","Street Green")==19 and int(inv.contents(primary).get("product|Street Green",0))==0,"Primary emptied and remaining 19g stays in extra shelf")
 check(int(inv.contents(secondary).get("product|Street Green",0))==19 and game._available_amount("Street Green")==13,"Remaining secondary stock respects existing reservation")
 check(not game._consume_player_sale_stock("Street Green",14) and inv.storage_stock("apartment","Street Green")==19,"Oversale rejected without partial inventory debit")
 check(inv.available(secondary,"product|Street Green")==13,"Removing reserved product through the secondary shelf is blocked")
 game.products["Street Green"]["listed"]=false
 game._set_product_listed("Street Green",true)
 check(bool(game.products["Street Green"].listed),"Listing remains possible with no grams in the primary storage")
 var primary_space:int=inv.free_space(primary,"product|Street Green")
 var deposit:int=primary_space+10
 check(inv.put_storage("apartment","Street Green",deposit),"Manufactured product can deposit into combined installed storage capacity")
 check(int(inv.contents(primary).get("product|Street Green",0))==inv.capacity(primary,"product|Street Green"),"Additional grams fill first shelf only up to its physical limit")
 check(inv.storage_stock("apartment","Street Green")==19+deposit and int(inv.contents(secondary).get("product|Street Green",0))==29,"Overflow from first shelf is deposited into second shelf exactly once")
 # House is independent and remote calls must not mutate apartment's active adapter.
 var house_primary:String="house:storage"
 var house_extra:String="house:storage@fixture_house_extra"
 model.state.items["fixture_house_storage"]={"sku":"storage_1","property":"house","position":[43.2,0,-3.1],"yaw":0,"locked":true,"container":house_primary,"paid":140,"upgrades":{}}
 model.state.items["fixture_house_extra"]={"sku":"storage_3","property":"house","position":[42.0,0,-2.0],"yaw":0,"locked":true,"container":house_extra,"paid":900,"upgrades":{}}
 inv.state.containers[house_primary]={"product|Street Green":7}
 inv.state.containers[house_extra]={"product|Street Green":15}
 inv.state.product_metadata={"house":{"Street Green":{"stock":0,"reserved":4,"listed":true,"price":14}}}
 check(inv.storage_stock("house","Street Green")==22 and inv.storage_available("house","Street Green")==18,"Remote house listing sees both house units, minus house-only reserves")
 check(inv.storage_stock("apartment","Street Green")==19+deposit and game._available_amount("Street Green")==13+deposit,"Apartment totals stay separate from house storage")
 check(inv.take_storage("house","Street Green",18) and inv.storage_stock("house","Street Green")==4,"Remote property debit spans house shelves without affecting apartment")
 check(not inv.take_storage("house","Street Green",1),"Reserved house grams cannot be spent")
 check(inv.storage_stock("apartment","Street Green")==19+deposit,"Remote house sale never subtracts apartment stock")
 var overview:int=game.neighborhood.location_ops.computer_stock_total("apartment","storage","product|")
 check(overview==game._total_stored_stock(),"Property overview stock includes all apartment storage units")
 var snapshot:Dictionary=JSON.parse_string(JSON.stringify(game.location_state))
 check(int(snapshot.container_inventory.containers[secondary].get("product|Street Green",0))==29,"Secondary storage contents survive JSON serialization")
 check(int(snapshot.container_inventory.containers[house_extra].get("product|Street Green",0))>=0,"House extra shelf persists in its own container record")
 game.queue_free()
 for i in 4:await process_frame
 print("MULTI_STORAGE_RESULT: "+("PASS" if failures==0 else "FAIL")+" checks="+str(checks)+" failures="+str(failures))
 quit(1 if failures>0 else 0)
