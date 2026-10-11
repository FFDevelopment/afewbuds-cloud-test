extends SceneTree
## Public beta regression: preserve existing career stock while restoring
## the approved bench, property curbside cart delivery and backpack upgrades.
var failures:=0
var checks:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,note:String)->void:
 checks+=1
 if not ok:failures+=1;push_error("TESTER_SHOP_HOTFIX FAIL: "+note)
func text_matches(parent:Node,needle:String)->bool:
 for item in parent.find_children("*","Label",true,false):
  if needle.to_upper() in str((item as Label).text).to_upper():return true
 for item in parent.find_children("*","Button",true,false):
  if needle.to_upper() in str((item as Button).text).to_upper():return true
 return false
func run()->void:
 var desktop:bool=ResourceLoader.exists("res://prototype/apartment.tscn")
 if get_root().has_node("AFBCloud"):await root.get_node("AFBCloud").prepare(true)
 var game:Node3D=load("res://prototype/apartment.tscn" if desktop else "res://scenes/main.tscn").instantiate()
 root.add_child(game)
 for i in 10:await process_frame
 game.set_process(false);game.neighborhood.set_process(false)
 var player:CharacterBody3D=game.fp_player if desktop else game.neighborhood.physics_body
 player.set_physics_process(false)
 for timer in game.find_children("*","Timer",true,false):timer.stop()
 game.tutorial_active=false;game.daily_report_pending=false;game.session_paused=false
 game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide()
 var inv:Node=game.inventory_system
 inv.set_process(false)
 inv.furniture.set_process(false)
 var ops:RefCounted=game.neighborhood.location_ops
 var model:RefCounted=inv.furniture.model
 var cart:RefCounted=inv.furniture.cart
 game.property_opportunity_state={"acquired":true,"agreement_signed":true,"agreement":"purchase","relocated":true}
 game.apartment_rent_state.lease_active=true
 game.apartment_rent_state.balance=0
 game.cash=50000
 game.location_state.carried_seeds={}
 game.location_state.carried_fertilizer=0
 game.location_state.property_storage=[]
 inv.state.backpack={}
 inv.state.backpack_level=2
 var saved_stock:Dictionary=game.location_state.get("container_inventory",{}).get("containers",{}).duplicate(true)
 check(inv.backpack_limit()==55*inv.POUND and inv.BACKPACK_PRICES==[250,750,1750],"Existing backpack Level 2 and price ladder are unchanged")
 var phone_ui:=VBoxContainer.new()
 game.add_child(phone_ui)
 load("res://scripts/shop_upgrade_catalog.gd").phone(game,phone_ui)
 check(text_matches(phone_ui,"NEXT BACKPACK LEVEL 3") and text_matches(phone_ui,"Packing Benches") and text_matches(phone_ui,"Grow Tents"),"Phone Shop upgrades page displays capacity and equipment tiers")
 check(game.cash==50000 and int(inv.state.backpack_level)==2,"Browsing Phone Shop never charges money or changes backpack level")
 phone_ui.free()
 game.camera.global_position=inv.POSITIONS["market:orders"]
 ops.equipment()
 check(text_matches(ops.ui.body,"UPGRADE BACKPACK TO LEVEL 3") and text_matches(ops.ui.body,"80 lb"),"Market Upgrades restores backpack purchase control")
 var money:int=game.cash
 check(inv.upgrade_backpack(2) and game.cash==money-750 and int(inv.state.backpack_level)==3,"Purchase charges exactly once and advances backpack level")
 check(not inv.upgrade_backpack(2) and int(inv.state.backpack_level)==3,"Old/stale purchase cannot duplicate")
 ops.close()
 check(model.controlled("house"),"House ownership authorizes a property delivery")
 cart.state().clear()
 game.location_state["market_cart_delivery_v1"]="market:orders"
 check(cart.destination()=="market:orders","Old careers continue using Market Pickup by default")
 cart.set_quantity("item|bench_1",1)
 cart.set_quantity("seed|Street Green",2)
 check(cart.delivery_allowed("house"),"Owned house is an eligible curbside destination")
 game.location_state["market_cart_delivery_v1"]="house"
 var expected:int=int(cart.total())
 money=game.cash
 var before_seed:int=int(inv.contents("market:orders").get("seed|Street Green",0))
 var before_apartment:Dictionary=inv.contents("apartment:packing").duplicate(true)
 var purchased:Dictionary=cart.checkout()
 check(purchased.ok and game.cash==money-expected and cart.state().is_empty(),"Mixed order commits one payment at the displayed price")
 check(int(inv.contents("market:orders").get("seed|Street Green",0))+int(inv.contents("backpack").get("seed|Street Green",0))==before_seed+2,"Seed orders stay in market-pickup flow, with automatic collection only when physically at checkout")
 check(inv.contents("apartment:packing")==before_apartment and inv.state.containers==saved_stock,"House delivery never moves existing apartment stock")
 var delivery_items:Dictionary=inv.contents("house:delivery")
 var delivered_id:String=""
 for item in delivery_items:
  if str(item).begins_with("furniture|"):delivered_id=str(item).get_slice("|",1)
 check(not delivered_id.is_empty(),"Purchased packing bench is at the HOUSE delivery curb")
 check(inv.all_positions().has("house:delivery"),"Delivery crate has real house curb pickup point")
 check(model.state.items.has(delivered_id) and model.state.items[delivered_id].sku=="bench_1","Delivery retains the exact approved bench SKU")
 game.camera.global_position=Vector3(-2,2,7.2)
 check(not inv.transfer("house:delivery","backpack","furniture|"+delivered_id,1).ok,"Cannot remotely collect a house delivery")
 game.camera.global_position=model.CURBS["house"]+Vector3.UP*1.2
 var transfer:Dictionary=inv.transfer("house:delivery","backpack","furniture|"+delivered_id,1)
 check(transfer.ok and model.state.items[delivered_id].property=="backpack","House delivery is collected exactly once by visiting its curb")
 check(not inv.transfer("house:delivery","backpack","furniture|"+delivered_id,1).ok,"Second collection cannot duplicate a delivered bench")
 # Validate the full approved visual assembly on a purchased non-legacy bench.
 model.state.items[delivered_id]["property"]="house"
 model.state.items[delivered_id]["position"]=[41.1,0,-3.45]
 model.state.items[delivered_id]["yaw"]=0
 inv.furniture.equipment_world.sync()
 var render:Node=inv.furniture.equipment_world.rendered.get(delivered_id)
 check(render!=null and render.find_child("ApprovedPackingBenchModel",true,false)!=null,"Bought house bench uses finished apartment bench assembly")
 for prop in ["TrimTray","ScaleBody","ScaleDisplay","BaggieBox","BenchJarGlass"]:
  check(render!=null and render.find_child(prop,true,false)!=null,"Original packing station detail restored: "+prop)
 check(FileAccess.get_file_as_string("res://scripts/container_inventory.gd").contains("host._start_trim_minigame") and FileAccess.get_file_as_string("res://scripts/container_inventory.gd").contains("host._start_bag_minigame"),"All bought benches retain original drag-to-trim and drag-to-bag minigames")
 var persisted:Variant=JSON.parse_string(JSON.stringify(game.location_state))
 check(int(persisted.container_inventory.backpack_level)==3 and persisted.furniture_v1.items[delivered_id].sku=="bench_1","Purchase and delivery survive existing career JSON save format")
 # Level I purchase flow and individual in-place tent lighting upgrade.
 check(model.market_available("bench_1") and model.market_available("tent_4") and not model.market_available("bench_2") and not model.market_available("storage_5"),"Market only sells Level I equipment; tent size remains a separate choice")
 check(not str(cart.quote("item|bench_3").reason).is_empty(),"Stale high-tier cart cannot silently bypass the upgrade path")
 var shop_ui:Node=inv.furniture
 shop_ui.shop("equipment")
 check(text_matches(shop_ui.list,"Packing Bench I") and not text_matches(shop_ui.list,"Packing Bench III"),"On-site equipment shop shows starter tier only")
 shop_ui.close()
 var led_id:String="test_owned_tent_led"
 model.state.items[led_id]={"sku":"tent_1","property":"house","position":[41.8,0,-11.2],"yaw":0,"locked":true,"quality":1,"paid":240,"upgrades":{}}
 model.ensure_slots()
 var led_slot:int=int(model.state.items[led_id].slots[0])
 var previous_plant:Dictionary=game.plant_slots[led_slot].duplicate(true)
 game.plant_slots[led_slot].stage=1
 game.plant_slots[led_slot].dead=false
 var led_cash:int=game.cash
 check(model.upgrade(led_id) and int(model.state.items[led_id].quality)==2 and game.cash==led_cash-320,"Live crop stays planted while its own tent receives the $320 LED retrofit")
 check(int(game.plant_slots[led_slot].get("stage",-1))==1,"Installing LEDs does not reset or remove a live crop")
 inv.furniture.sync_world()
 var led_visual:Node=inv.furniture.equipment_world.rendered.get(led_id)
 check(led_visual!=null and led_visual.find_child("LEDDriver",true,false)!=null and led_visual.find_child("BasicLightReflector",true,false)==null,"Paid LED upgrade swaps the real tent light model")
 check(not model.upgrade(led_id) and game.cash==led_cash-320,"LED retrofit cannot be charged twice on the same tent")
 game.plant_slots[led_slot]=previous_plant
 model.state.items.erase(led_id)
 var flush_a:String="test_nearby_a"
 var flush_b:String="test_nearby_b"
 model.state.items[flush_a]={"sku":"coffee_table","property":"house","position":[28.7,0,-0.5],"yaw":0,"locked":false,"paid":95,"upgrades":{}}
 model.state.items[flush_b]={"sku":"coffee_table","property":"backpack","locked":false,"paid":95,"upgrades":{}}
 check(model.validate(flush_b,"house",Vector3(29.8,0,-.5),0).is_empty(),"Neighboring furniture fits flush without artificial padding")
 check(not model.validate(flush_b,"house",Vector3(29.6,0,-.5),0).is_empty(),"Actual 20cm overlapping footprints are blocked")
 check(model.validate(flush_b,"house",Vector3(25.95,0,-1.2),0).is_empty(),"Furniture can sit with its bounding edge on the wall-side room boundary")
 check(not model.validate(flush_b,"house",Vector3(25.70,0,-1.2),0).is_empty(),"Furniture crossing a structural room boundary remains blocked")
 model.state.items.erase(flush_a)
 model.state.items.erase(flush_b)
 game.queue_free()
 for i in 5:await process_frame
 print("TESTER_SHOP_HOTFIX_RESULT: "+("PASS" if failures==0 else "FAIL")+" checks="+str(checks))
 quit(1 if failures else 0)
