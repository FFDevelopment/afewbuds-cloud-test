extends SceneTree
var failures := 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures+=1;push_error(message)
func run() -> void:
	var game: Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.session_paused=false;game.tutorial_active=false;game.daily_report_pending=false;game.customer_waiting=false
	for name in ["tutorial_panel","daily_report_panel","pause_overlay","sale_panel","grow_panel","plant_direct_panel","bagging_panel","storage_panel","dealer_storage_panel","supply_inventory_panel","system_control_panel","trim_panel","bag_minigame_panel","peephole_panel"]:
		var panel=game.get(name)
		if panel!=null:panel.hide()
	game.visit_timer.stop();game.cash=10000;game.grower_level=10
	var n: Node3D=game.neighborhood;var ops: RefCounted=n.location_ops
	n._arrive_outside()
	check(int(game.apartment_rent_state.next_due)==game.game_day+14 and ops.balance()==0,"Existing/new career starts with fourteen-day rent grace")
	var due: int=int(game.apartment_rent_state.next_due)
	game.game_day=due-1;ops.update(0);check(ops.balance()==0,"No early rent charge")
	game.game_day=due;ops.update(0);ops.update(0);check(ops.balance()==600 and int(game.apartment_rent_state.next_due)==due+14,"Rent accrues exactly once per due date")
	var cash: int=game.cash;ops.pay_rent();ops.pay_rent();check(game.cash==cash-600 and ops.balance()==0,"Rent payment cannot double-charge")
	game.game_day=due+14;ops.update(0);check(ops.balance()==600,"Second fourteen-day cycle")
	var seed: String=game.SEED_ORDER[0];var owned: int=int(game.seed_inventory.get(seed,0));cash=game.cash
	game._buy_seed(seed)
	check(int(game.seed_inventory.get(seed,0))==owned and int(game.location_state.pickup_seeds.get(seed,0))==1,"Phone seed order waits at market")
	check(game.cash==cash-int(game.seed_catalog[seed].cost),"Seed order charges once")
	ops.pickup();check(int(game.location_state.pickup_seeds.get(seed,0))==1,"Remote pickup rejected")
	game.camera.position=Vector3(14,1.64,5);game.camera.look_at(ops.CHECKOUT)
	check(ops.target()=="market_checkout","Checkout reachable")
	ops.pickup();check(int(game.location_state.carried_seeds.get(seed,0))==1 and int(game.seed_inventory.get(seed,0))==owned,"Pickup goes to carried inventory")
	var fert: int=game.fertilizer_units;cash=game.cash;ops.fertilizer()
	check(game.fertilizer_units==fert and int(game.location_state.carried_fertilizer)==5 and game.cash==cash-45,"Market fertilizer carried, not auto-delivered")
	cash=game.cash;game._buy_supply("Fertilizer Pack");check(game.cash==cash and game.fertilizer_units==fert,"Regular phone fertilizer buying blocked")
	var upgrade := "Grow Supply Shelf II";cash=game.cash;ops.order_equipment(upgrade)
	check(game.supply_shelf_level==1 and game.location_state.deliveries.has(upgrade),"Paid equipment waits for installation")
	check(game.cash==cash-int(game.supply_catalog[upgrade].cost),"Equipment charged once")
	ops.order_equipment(upgrade);check(game.cash==cash-int(game.supply_catalog[upgrade].cost),"Duplicate equipment order rejected")
	var dealer_level: int=game.dealer_locker_level
	ops.order_dealer()
	var dealer_name: String="Dealer Storage "+game._roman(dealer_level+1)
	check(game.dealer_locker_level==dealer_level and game.location_state.deliveries.has(dealer_name),"Dealer storage waits for installation")
	game.camera.position=Vector3(3,1.64,4.35);game.camera.look_at(ops.APT_PC)
	check(ops.target()=="apartment_computer","Apartment computer reachable")
	cash=game.cash;ops.install(upgrade)
	check(game.supply_shelf_level==2 and not game.location_state.deliveries.has(upgrade) and game.cash==cash,"Computer installs paid equipment without second charge")
	cash=game.cash;ops.install(dealer_name)
	check(game.dealer_locker_level==dealer_level+1 and game.cash==cash,"Dealer storage installs without double charge")
	ops.deposit();check(int(game.seed_inventory.get(seed,0))==owned+1 and game.fertilizer_units==fert+5,"Supplies deposited at active apartment")
	ops.deposit();check(int(game.seed_inventory.get(seed,0))==owned+1,"Deposit cannot duplicate seeds")
	game.location_state.carried_seeds[seed]=2
	game.seed_inventory[seed]=game._supply_seed_capacity()
	ops.deposit();check(int(game.location_state.carried_seeds[seed])==2,"Full shelf leaves carried seeds intact")
	game.cash=0;ops.pay_rent();check(ops.balance()==600,"Insufficient cash does not erase rent")
	ops.close();game._save_game()
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	check(data.has("location_state") and data.has("apartment_rent_state"),"Commerce and rent saved with career")
	game.location_state={};game.apartment_rent_state={};game._load_game()
	check(ops.balance()==600 and game.location_state.has("carried_seeds"),"Commerce and rent reload")
	game.game_day+=4;ops.update(0)
	check(ops.rent_overdue() and not ops.eligible("Grow Supply Shelf III"),"Overdue rent holds new equipment orders")
	game.game_day-=4
	# Both the visible phone tile and stale direct navigation must be removed.
	ops.close();game.phone_current_app="business";game._refresh_phone()
	check(game.phone_current_app=="business","Business phone category remains accessible")
	game._open_phone_app("bills");check(game.phone_current_app=="bills" and game._phone_parent_app("bills")=="business","Bills opens and returns to Business")
	var business_tiles: Array[String]=[]
	game.phone_current_app="business";game._refresh_phone()
	for node in game.phone_list.find_children("*","Button",true,false):business_tiles.append(node.text)
	check(business_tiles.any(func(t):return "BILLS" in t),"Business includes Bills")
	check(not business_tiles.any(func(t):return "EMPLOYEES" in t or "UPGRADES" in t),"Business does not duplicate computer management")
	game.phone_open=false;game.phone_panel.hide()
	var desk: MeshInstance3D=game.get_node("ApartmentComputerDesk")
	var bench: MeshInstance3D=game.get_node("BenchTop")
	check(not (desk.global_transform*desk.get_aabb()).intersects(bench.global_transform*bench.get_aabb()),"Computer desk clears packaging bench")
	check(desk.position.z-0.55>bench.position.z+1.76+1.0,"Clear gap between desk and packaging bench")
	var original_list: VBoxContainer=game.phone_list
	for app in ["business","employees","products","genetics","upgrades","bills"]:
		ops.manage(app)
		check(ops.is_open() and not game.phone_open and game.phone_list==original_list,"Management stays in computer panel: "+app)
		ops.close()
	ops.computer("apartment")
	check(ops.management_app=="business","Computer opens complete original Business interface")
	var apps: Array[String]=[]
	for button in ops.ui.body.find_children("*","Button",true,false):
		if button.has_meta("phone_app"):apps.append(str(button.get_meta("phone_app")))
	for app in ["bills","employees","upgrades","products","genetics"]:check(apps.has(app),"Computer Business category: "+app)
	game._open_phone_app("employees")
	check(ops.management_app=="employees" and not game.phone_open,"Original tile navigates inside computer")
	ops.close()
	game.camera.position=Vector3(27.7,1.64,1.65);game.camera.look_at(ops.HOUSE_PC)
	check(ops.target()=="house_computer","House computer reachable")
	ops.computer("house");check(ops.is_open() and not game.location_state.house.has("equipment"),"House computer preview does not activate production")
	ops.close()
	if OS.get_cmdline_user_args().has("--capture"):
		root.size=Vector2i(1280,800);game.camera.position=Vector3(0.8,2.25,3.4);game.camera.look_at(Vector3(4,1,3.1))
		for i in range(6):game.session_paused=false;game.pause_overlay.hide();await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/workspace/scratch/05254e9fc6fb/layout87.png")
		root.size=Vector2i(420,800);game.camera.position=Vector3(14,1.64,5);game.camera.look_at(ops.CHECKOUT);ops.market()
		for i in range(6):game.session_paused=false;game.pause_overlay.hide();await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/workspace/scratch/05254e9fc6fb/market87.png")
		game.camera.position=Vector3(3,1.64,4.35);game.camera.look_at(ops.APT_PC);ops.computer("apartment")
		for i in range(6):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/workspace/scratch/05254e9fc6fb/computer87.png")
		ops.manage("bills")
		for i in range(6):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/workspace/scratch/05254e9fc6fb/rent87.png")
	print("Commerce/rent .87 checks: ",failures," failures")
	quit(1 if failures else 0)
