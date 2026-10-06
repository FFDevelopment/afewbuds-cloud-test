extends SceneTree
func _initialize() -> void:call_deferred("run")
func hide_ui(node:Node) -> void:
	if node is Control or node is CanvasLayer:node.hide()
	for child in node.get_children():hide_ui(child)
func run() -> void:
	assert(OS.get_user_data_dir().contains("AFB Character Fit Validation"))
	var output:=OS.get_cmdline_user_args()[0];DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,800)
	var game:Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	var world:Node3D=game.neighborhood;game.set_process(false);world.set_process(false);game._cancel_camera_view_tween()
	for timer in game.find_children("*","Timer",true,false):timer.stop()
	game.session_paused=false;game.tutorial_active=false;game.daily_report_pending=false;game.customer_waiting=false
	game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide();world.active=true
	game.game_time_minutes=720;game._update_day_night_visuals();world.weather.update(0)
	game.sun_light.hide();game.camera.environment=world.outdoor_environment
	var seats=world.bench_seating
	for i in range(seats.benches.size()):
		var b:Dictionary=seats.benches[i]
		game.camera.position=b.at+Basis(Vector3.UP,b.facing)*Vector3(0,world.WALK_EYE_HEIGHT,-1.05)
		world._interact();world._process(.016)
		for frame in range(8):game.session_paused=false;await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("bench_%d_seated.png"%i))
		seats.stand()
	game.camera.position=Vector3(-1.8,world.WALK_EYE_HEIGHT,1.9);world._interact();world._process(.016)
	for frame in range(8):game.session_paused=false;await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("couch_seated.png"))
	world._interact()
	var rod:Node3D=world.location_ops.crew.character_instance("Rod");root.add_child(rod)
	world.location_ops.crew.seated_pose(rod,true)
	rod.position=Vector3(121.8,-.00021849,-5.4);rod.rotation.y=-PI/2
	game.camera.environment=world.outdoor_environment
	game.camera.position=Vector3(125,2,-2.8);game.camera.look_at(Vector3(121.8,1,-5.4))
	for frame in range(10):hide_ui(game);game.session_paused=false;await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("bench_character_reference.png"))
	rod.free();game.queue_free();await process_frame;quit()
