extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1;push_error(message)
func run() -> void:
	var game: Node3D=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.session_paused=false
	game.tutorial_active=false
	game.daily_report_pending=false
	game.customer_waiting=false
	for name in ["tutorial_panel","daily_report_panel","pause_overlay","sale_panel","grow_panel","plant_direct_panel","bagging_panel","storage_panel","dealer_storage_panel","supply_inventory_panel","system_control_panel","trim_panel","bag_minigame_panel","peephole_panel"]:
		var panel=game.get(name)
		if panel!=null:panel.hide()
	game.visit_timer.stop()
	var n: Node3D=game.neighborhood
	n._arrive_outside()
	var opportunity: RefCounted=n.property_opportunity
	game.property_offer_unlocked=false
	opportunity.show_details()
	check(not opportunity.is_open(),"House details remain locked before Rod's offer")
	game.property_offer_unlocked=true
	game.camera.position=Vector3(35,1.64,4.8)
	game.camera.look_at(Vector3(35,1.3,3))
	var cash: float=game.cash
	var equipment: int=game.grow_tent_count
	n._use_map_door("HouseEntrance")
	check(opportunity.is_open() and game._any_modal_open(),"House entrance opens modal property details")
	check(not n.get_node("HouseEntrance").opened,"Viewing details does not open the house")
	opportunity.begin_tour()
	await create_timer(0.5).timeout
	check(opportunity.touring and not opportunity.is_open() and n.get_node("HouseEntrance").opened,"Tour opens real door without teleport")
	check(game.camera.position.distance_to(Vector3(35,1.64,4.8))<0.01,"Tour keeps player position")
	for point in [Vector3(30,1.64,0),Vector3(27,1.64,-9),Vector3(40,1.64,-10),Vector3(40,1.64,0),Vector3(32,1.64,-9),Vector3(36,1.64,-9)]:
		game.camera.position=point
		for i in range(21):opportunity.update(0.1)
	check(opportunity.visited().size()==6 and bool(game.property_opportunity_state.get("inspection_complete",false)),"Six room inspection complete")
	opportunity.end_tour()
	game._save_game()
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	check(data.property_opportunity_state.rooms.size()==6,"Tour progress saved with career")
	game.property_opportunity_state={}
	game._load_game()
	check(opportunity.visited().size()==6,"Tour progress restored")
	check(game.cash==cash and game.grow_tent_count==equipment,"Tour does not charge cash or award equipment")
	game.property_opportunity_state={"rooms":["living","bad", "living"]}
	check(opportunity.visited()==["living"],"Old/corrupt room IDs sanitized")
	game.property_opportunity_state={}
	opportunity.touring=true
	game.session_paused=true
	game.camera.position=Vector3(30,1.64,0)
	for i in range(30):opportunity.update(0.1)
	check(opportunity.visited().is_empty(),"Paused game does not advance inspection")
	game.session_paused=false
	opportunity.end_tour()
	if OS.get_cmdline_user_args().has("--capture"):
		root.size=Vector2i(420,800)
		game.camera.position=Vector3(35,1.64,5)
		opportunity.show_details()
		for i in range(6):
			game.session_paused=false
			game.pause_overlay.hide()
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/workspace/scratch/05254e9fc6fb/property83-portrait.png")
		root.size=Vector2i(900,420)
		for i in range(6):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/workspace/scratch/05254e9fc6fb/property83-landscape.png")
	print("Property .83 checks: ",failures," failures")
	quit(1 if failures else 0)
