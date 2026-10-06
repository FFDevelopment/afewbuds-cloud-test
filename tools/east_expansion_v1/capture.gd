extends SceneTree
func _initialize() -> void:call_deferred("run")
func hide_ui(node:Node) -> void:
	if node is Control or node is CanvasLayer:node.hide()
	for child in node.get_children():hide_ui(child)
func run() -> void:
	assert(OS.get_user_data_dir().contains("AFB Character Fit Validation"))
	var output:=OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output);root.size=Vector2i(1600,1000)
	var game:Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process(false);game.neighborhood.set_process(false);game._cancel_camera_view_tween()
	for timer in game.find_children("*","Timer",true,false):timer.stop()
	game.game_time_minutes=720;game._update_day_night_visuals();game.neighborhood.weather.update(0)
	game.sun_light.hide();game.camera.environment=game.neighborhood.outdoor_environment
	var rod:Node3D=game.neighborhood.location_ops.crew.character_instance("Rod");root.add_child(rod)
	for shot in [
		{"id":"hub_tree_soil","pos":Vector3(17,3.5,15),"look":Vector3(10,.4,10.5),"ortho":false,"rod":Vector3(13,0,8.6)},
		{"id":"east_tree_soil","pos":Vector3(98,3.5,14.5),"look":Vector3(92,.4,10.5),"ortho":false,"rod":Vector3(90,0,8.6)},
		{"id":"whole_neighborhood","pos":Vector3(52.5,105,65),"look":Vector3(52.5,0,0),"ortho":true,"size":118.0,"rod":Vector3(125.5,0,-1.6)},
		{"id":"east_overview","pos":Vector3(111,62,43),"look":Vector3(106,0,-2),"ortho":true,"size":79.0,"rod":Vector3(125.5,0,-1.6)},
		{"id":"park","pos":Vector3(125.5,2.16,8.5),"look":Vector3(125.5,1.5,-4),"ortho":false,"rod":Vector3(122,0,-1.2)},
		{"id":"residential_street","pos":Vector3(106,2.16,12),"look":Vector3(84,3,3),"ortho":false,"rod":Vector3(100,0,8.6)},
		{"id":"rear_lane","pos":Vector3(105,2.16,-19),"look":Vector3(83,1.7,-16.7),"ortho":false,"rod":Vector3(87,0,-16.3)},
		{"id":"apartment_windows","pos":Vector3(10,4.7,20),"look":Vector3(0,5.2,5),"ortho":false,"rod":Vector3(2,0,8.6)}
	]:
		rod.position=shot.rod;rod.rotation.y=PI
		game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL if shot.ortho else Camera3D.PROJECTION_PERSPECTIVE
		game.camera.size=shot.get("size",25.0);game.camera.fov=72
		game.camera.position=shot.pos;game.camera.look_at(shot.look)
		for i in range(12):game.session_paused=false;hide_ui(game);await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output.path_join(shot.id+".png"))==OK)
		print("CAPTURE ",shot.id)
	rod.queue_free();game.queue_free();await process_frame;quit()
