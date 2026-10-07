extends SceneTree
func _initialize() -> void:call_deferred("run")
func hide_ui(node:Node) -> void:
	if node is Control or node is CanvasLayer:node.hide()
	for child in node.get_children():hide_ui(child)
func run() -> void:
	assert(OS.get_user_data_dir().contains("AFB Character Fit Validation"))
	var output:=OS.get_cmdline_user_args()[0];DirAccess.make_dir_recursive_absolute(output);root.size=Vector2i(1400,1000)
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	var w=game.neighborhood;var crew=w.location_ops.crew
	game.set_process(false);w.set_process(false);game._cancel_camera_view_tween()
	for timer in game.find_children("*","Timer",true,false):timer.stop()
	game.game_time_minutes=720;game._update_day_night_visuals();w.weather.update(0);game.sun_light.hide()
	var model:Node3D=crew.character_instance("Kobi");root.add_child(model)
	var player:AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0]
	var shots:Array=[
		{"id":"kobi_standing","at":Vector3(125.5,0,-1.6),"pos":Vector3(127.6,1.8,-5.8),"look":Vector3(125.5,1.15,-1.6),"clip":"idle","time":.3},
		{"id":"kobi_walk","at":Vector3(125.5,0,-1.6),"pos":Vector3(128.5,1.7,-5.8),"look":Vector3(125.5,1.15,-1.6),"clip":"walk","time":.18},
		{"id":"kobi_bend","at":Vector3(125.5,0,-1.6),"pos":Vector3(129.5,1.7,-4.8),"look":Vector3(125.5,1,-1.6),"clip":"bend_test","time":.5},
		{"id":"kobi_seated","at":Vector3(-2.775,0,3.035),"pos":Vector3(.1,1.6,-.35),"look":Vector3(-2.5,1.05,3.035),"clip":"sit","time":.5,"inside":true}
	]
	for shot in shots:
		model.position=shot.at
		player.play(shot.clip);player.seek(shot.time,true);player.pause()
		game.camera.environment=game.world_environment_ref if shot.get("inside",false) else w.outdoor_environment
		game.camera.fov=48;game.camera.position=shot.pos;game.camera.look_at(shot.look)
		for frame in range(10):game.session_paused=false;hide_ui(game);await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(shot.id+".png"));print("CAPTURE ",shot.id)
	model.queue_free();game.queue_free();await process_frame;quit()
