extends SceneTree
# Run against either extracted validation project; output is a command-line path.
func _initialize() -> void:call_deferred("run")
func hide_ui(node: Node) -> void:
	if node is CanvasLayer or node is Control:node.hide()
	for child in node.get_children():hide_ui(child)
func run() -> void:
	assert(OS.get_user_data_dir().contains("AFB Character Fit Validation"))
	var output:=OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,800)
	var game:Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.set_process(false);game.neighborhood.set_process(false)
	game._cancel_camera_view_tween()
	game.session_paused=false;game.tutorial_active=false;game.daily_report_pending=false
	for timer in game.find_children("*","Timer",true,false):timer.stop()
	game.game_time_minutes=720;game.main_ceiling_light_on=true;game._update_day_night_visuals()
	var world:Node3D=game.neighborhood
	world.weather.update(0)
	game.sun_light.hide()
	var rod:Node3D=world.location_ops.crew.character_instance("Rod");root.add_child(rod)
	var malik:Node3D=world.location_ops.crew.character_instance("Malik");root.add_child(malik)
	game.camera.fov=72
	for shot in [
		{"id":"street","pos":Vector3(24,2.7,20),"look":Vector3(31,1.8,10),"rod":Vector3(29,0,12),"malik":Vector3(30,0,12),"apartment":false},
		{"id":"house_living","pos":Vector3(32,2.16,.5),"look":Vector3(29,1,-3.5),"rod":Vector3(29.695,0,-3.565),"malik":Vector3(28.705,0,-3.565),"apartment":false,"seated":true},
		{"id":"house_kitchen","pos":Vector3(30.8,2.16,-8),"look":Vector3(28.4,1.2,-12),"rod":Vector3(30,0,-12.4),"malik":Vector3(27,0,-11.8),"apartment":false},
		{"id":"apartment_kitchen","pos":Vector3(-.5,2.16,.6),"look":Vector3(2.5,1.3,-3.3),"rod":Vector3(.7,0,-3),"malik":Vector3(3.2,0,-2.2),"apartment":true},
		{"id":"apartment_couch","pos":Vector3(1.8,1.7,-.6),"look":Vector3(-2.28,1,2.6),"rod":Vector3(-2.775,0,3.035),"malik":Vector3(-1.785,0,3.035),"apartment":true,"seated":true}
	]:
		rod.position=shot.rod;malik.position=shot.malik
		rod.rotation.y=PI if shot.id=="house_living" else 0.0;malik.rotation.y=rod.rotation.y
		world.location_ops.crew.seated_pose(rod,shot.get("seated",false));world.location_ops.crew.seated_pose(malik,shot.get("seated",false))
		game.camera.position=shot.pos;game.camera.look_at(shot.look)
		game.camera.environment=game.world_environment_ref if shot.apartment else world.outdoor_environment
		for i in range(15):
			game.session_paused=false;hide_ui(game);await process_frame
		await RenderingServer.frame_post_draw
		var target:=output.path_join(shot.id+".png")
		assert(root.get_texture().get_image().save_png(target)==OK)
		print("CAPTURE ",target)
	rod.queue_free();malik.queue_free();game.queue_free();await process_frame;quit()
