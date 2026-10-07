extends SceneTree
func _initialize() -> void:call_deferred("run")
func hide_ui(node:Node) -> void:
	if node is Control or node is CanvasLayer:node.hide()
	for child in node.get_children():hide_ui(child)
func run() -> void:
	assert(OS.get_user_data_dir().contains("AFB Character Fit Validation"))
	var output:=OS.get_cmdline_user_args()[0];DirAccess.make_dir_recursive_absolute(output);root.size=Vector2i(1600,1000)
	var game:Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	var world:Node3D=game.neighborhood;var station:Node3D=world.police_station
	game.set_process(false);world.set_process(false);game._cancel_camera_view_tween()
	for timer in game.find_children("*","Timer",true,false):timer.stop()
	game.game_time_minutes=720;game._update_day_night_visuals();world.weather.update(0)
	game.sun_light.hide();game.camera.environment=world.outdoor_environment
	var shots:Array=[
		{"id":"frame_inside","pos":station.point(5.8,2.16,26.8),"look":station.point(5.8,2.35,28)},
		{"id":"frame_outside","pos":station.point(6.4,2.16,29.5),"look":station.point(5.7,2.3,28)},
		{"id":"slab_corner","pos":Vector3(175,3.52,9),"look":Vector3(172.95,3.52,6.8)},
		{"id":"public_driveway","pos":Vector3(188.5,2.16,17),"look":Vector3(188.5,.6,0)},
		{"id":"patrol_driveway","pos":Vector3(161.5,2.16,-18),"look":Vector3(161.5,.6,-29)},
		{"id":"accessible_sign","pos":Vector3(184.7,2.16,3.5),"look":Vector3(178.4,2,3.5)},
		{"id":"public_parking","pos":Vector3(198,12,17),"look":Vector3(187,0,-4)},
		{"id":"residences","pos":Vector3(177,4,17),"look":Vector3(177,2.5,29)},
		{"id":"bark","pos":Vector3(120.2,2.16,-8.5),"look":Vector3(120.2,2,-11)},
		{"id":"restroom","pos":station.point(21,2.16,25.8),"look":station.point(22,1.7,22)},
		{"id":"district","pos":Vector3(165,65,50),"look":Vector3(161,0,-3),"size":82},
		{"id":"front","pos":Vector3(158,3.0,19),"look":Vector3(161,3.2,7)},
		{"id":"patrol_parking","pos":Vector3(177,11,-36),"look":Vector3(161,1,-26)},
		{"id":"ground_floor","pos":Vector3(161,50,18),"look":Vector3(161,0,-4),"size":32,"floor":0},
		{"id":"upper_floor","pos":Vector3(161,54,18),"look":Vector3(161,3.6,-4),"size":32,"floor":1},
		{"id":"lobby","pos":station.point(11.2,2.16,27),"look":station.point(10,1.4,22)},
		{"id":"booking","pos":station.point(13,2.16,18.7),"look":station.point(5,1.3,16.5)},
		{"id":"holding","pos":station.point(16.5,2.16,4.5),"look":station.point(22,1.2,3)},
		{"id":"stairs","pos":station.point(21.5,2.16,21),"look":station.point(21.5,4.2,12.8)},
		{"id":"upper_office","pos":station.point(17.6,5.76,17.5),"look":station.point(12,4.8,24)},
		{"id":"briefing","pos":station.point(7.7,5.76,9.7),"look":station.point(4.5,4.8,4)}
	]
	for shot in shots:
		for child in station.get_children():
			if child is Node3D:child.visible=not shot.has("floor") or child.get_meta("station_floor",0)==shot.floor
		game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL if shot.has("size") else Camera3D.PROJECTION_PERSPECTIVE
		game.camera.size=shot.get("size",30.0);game.camera.fov=74
		game.camera.position=shot.pos;game.camera.look_at(shot.look)
		for frame in range(10):game.session_paused=false;hide_ui(game);await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(shot.id+".png"));print("CAPTURE ",shot.id)
	game.queue_free();await process_frame;quit()
