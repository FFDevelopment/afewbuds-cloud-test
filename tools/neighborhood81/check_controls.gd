extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func ready_game(game: Node3D) -> void:
	game.session_paused=false
	game.tutorial_active=false
	game.daily_report_pending=false
	game.customer_waiting=false
	for name in ["tutorial_panel","daily_report_panel","pause_overlay","sale_panel","grow_panel","plant_direct_panel","bagging_panel","storage_panel","dealer_storage_panel","supply_inventory_panel","system_control_panel","trim_panel","bag_minigame_panel","peephole_panel"]:
		var panel=game.get(name)
		if panel!=null: panel.hide()
	game.visit_timer.stop()
	game.neighborhood._arrive_outside()
func run() -> void:
	var game: Node3D=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	ready_game(game)
	var n: Node3D=game.neighborhood
	var controls: RefCounted=n.house_controls
	n.map_obstacles.clear(); n._collect_map_colliders(n)
	check(controls.switches.size()==9,"Eight room switches and separate house grow panel")
	check(controls.switches.grow_lights.lamps.is_empty(),"House starts without grow equipment regardless of apartment tents")
	check(n.find_children("GrowTent*","MeshInstance3D",false,false).is_empty(),"No preview tents in unupgraded house")
	var normals := {"living":Vector3.LEFT,"packing":Vector3.RIGHT,"entry_hall":Vector3.FORWARD,"cross_hall":Vector3.FORWARD,"kitchen":Vector3.FORWARD,"bathroom":Vector3.FORWARD,"bedroom":Vector3.FORWARD,"grow":Vector3.FORWARD}
	for id in normals:
		var at: Vector3=controls.switches[id].at
		game.camera.position=at+normals[id]
		game.camera.position.y=1.64
		game.camera.look_at(at)
		check(n._walkable(game.camera.position),"Switch approach clear: "+id)
		check(controls.nearby()=="switch_"+id,"Correct room maps to switch: "+id)
		var before := {}
		for other in normals: before[other]=controls.switches[other].lamp.visible
		var point: Vector2=game.camera.unproject_position(at)
		n.tap_distance=0
		n._tap(point)
		check(controls.switches[id].lamp.visible,"First tap does not toggle room light")
		n._tap(point)
		check(not controls.switches[id].lamp.visible,"Double tap toggles intended room light: "+id)
		for extra in controls.switches[id].extra: check(not extra.lamp.visible,"Hall switch controls every hall fixture")
		for other in normals:
			if other!=id: check(controls.switches[other].lamp.visible==before[other],"Room switch does not alter other room: "+id+"/"+other)
		controls.use("switch_"+id)
	for id in controls.shades:
		if id=="ApartmentBlind": continue
		var spec: Dictionary=controls.shades[id]
		var inward := Vector3.FORWARD if id=="PackingFrontBlind" else (Vector3.BACK if id=="GrowRearShade" else Vector3.LEFT)
		game.camera.position=spec.at+inward*1.0
		game.camera.position.y=1.64
		game.camera.look_at(spec.at)
		check(n._walkable(game.camera.position),"Shade approach clear: "+id)
		check(controls.nearby()=="shade_"+id,"Shade reachable from correct room: "+id)
		var point: Vector2=game.camera.unproject_position(spec.at)
		n.tap_distance=0
		n._tap(point); n._tap(point)
		await create_timer(0.45).timeout
		check(not spec.closed and spec.node.scale.y<0.06,"Double tap raises covering: "+id)
		n.tap_distance=60
		n._tap(point); n._tap(point)
		check(not spec.closed,"Look swipes do not toggle covering")
		game.camera.position=spec.at-inward*1.0
		game.camera.look_at(spec.at)
		check(controls.nearby().is_empty(),"Covering cannot be operated outside: "+id)
		game.camera.position=spec.at+inward
		game.camera.position.y=1.64
		game.camera.look_at(spec.at)
		controls.use("shade_"+id)
		await create_timer(0.45).timeout
		check(spec.closed and absf(spec.node.scale.y-1)<0.01,"Covering closes again: "+id)
	game.camera.position=Vector3(39.76,1.64,-9.1)
	game.camera.look_at(controls.switches.grow_lights.at)
	check(controls.nearby()=="switch_grow_lights","House grow panel has clear approach")
	controls.use("switch_grow_lights")
	check(game.status_label.text.contains("No house grow equipment"),"Service panel explains uninstalled equipment")
	game.camera.position=Vector3(43.8,1.64,-10.7)
	game.camera.look_at(controls.shades.GrowSideShade.at)
	controls.use("shade_GrowSideShade")
	await create_timer(0.45).timeout
	game.camera.position=Vector3(42.25,1.64,-8.14)
	game.camera.look_at(controls.switches.grow.at)
	controls.use("switch_grow")
	var apartment: Dictionary=controls.shades.ApartmentBlind
	game.camera.position=Vector3(-3.62,1.64,4.8)
	game.camera.look_at(apartment.at)
	n._process(0.016)
	check(controls.nearby()=="shade_ApartmentBlind","Apartment blind reachable from inside")
	check(not apartment.closed,"Apartment blind initially open for real outdoor view")
	check(game.window_sun_disc==null and game.living_window_glass==null,"Fake sun and sky pane removed")
	check(not n._walkable(Vector3(-3.62,1.64,5.99)),"Real apartment window remains collidable")
	var apartment_point: Vector2=game.camera.unproject_position(apartment.at)
	n.tap_distance=0
	n._tap(apartment_point); n._tap(apartment_point)
	await create_timer(0.45).timeout
	check(apartment.closed,"Double tap closes apartment blinds")
	controls.use("shade_ApartmentBlind")
	await create_timer(0.45).timeout
	check(not apartment.closed,"Apartment blinds open again")
	game.camera.position=Vector3(-3.62,1.64,7.2)
	game.camera.look_at(apartment.at)
	check(controls.nearby().is_empty(),"Apartment blind cannot be used from outside")
	game._save_game()
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	check(saved.house_control_state.grow==false and saved.house_control_state.GrowSideShade==false,"Light and shade state saved with actual career")
	game.queue_free()
	await process_frame
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	ready_game(game)
	controls=game.neighborhood.house_controls
	check(not controls.switches.grow.lamp.visible and not controls.shades.GrowSideShade.closed,"Actual scene reload restores light and shade state")
	check(not controls.shades.ApartmentBlind.closed,"Reload restores apartment covering state")
	if OS.get_cmdline_user_args().has("--capture"):
		controls._set_light("grow",true)
		root.size=Vector2i(1280,800)
		game.camera.position=Vector3(41,1.64,-9)
		game.camera.look_at(Vector3(41,1.6,-13))
		for i in range(6): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/workspace/scratch/05254e9fc6fb/review/house79-grow.png")
		game.camera.position=Vector3(-3.62,1.64,4.8)
		game.camera.look_at(controls.shades.ApartmentBlind.at)
		for i in range(6): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/workspace/scratch/05254e9fc6fb/review/apartment79-window.png")
	print("House .79 checks: ",failures," failures; per-room switches, double tapping, shade open/close and inside-only reach, clear approaches, empty grow room, separate service panel, actual save/reload")
	quit(1 if failures else 0)
