extends SceneTree
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures+=1;push_error(message)
func run() -> void:
	var game: Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process(false);game.neighborhood.set_process(false);game.tutorial_active=false;game.tutorial_panel.hide();game.pause_overlay.hide();game.session_paused=false;game.daily_report_pending=false;game.daily_report_panel.hide();game.visit_timer.stop()
	var world: Node3D=game.neighborhood
	for id in ["ShopEntrance","HouseEntrance","StockroomDoor","BathroomDoor","BedroomDoor"]:
		var door: Node3D=world.get_node(id)
		var original: Vector3=door.rotation
		if id=="BedroomDoor":door.rotation.y=PI/2
		for side in [-1.0,1.0]:
			game.camera.position=door.to_global(Vector3(door.width/2,1.7,side*0.45))
			door.toggle(game.camera.position);door.toggle(game.camera.position)
			check(door.busy and door.pass_through and not world.transitioning,id+" swing does not block player movement")
			await create_timer(0.5).timeout
			check(door.opened and is_equal_approx(door.get_node("Leaf").rotation.y,side*PI/2),id+" opens away from approach side")
			game.camera.position=door.to_global(Vector3(door.width/2,1.7,0))
			door.toggle(game.camera.position);await create_timer(0.5).timeout
			check(not door.opened and not door.busy and is_zero_approx(door.get_node("Leaf").rotation.y),id+" closes through occupied swing on original path")
			check(door.pass_through,id+" waits to restore collision while player overlaps closed leaf")
			world.map_obstacles.clear();world._collect_map_colliders(door);check(world.map_obstacles.is_empty(),id+" deferred leaf excluded from movement collision")
			game.camera.position=door.to_global(Vector3(door.width/2,1.7,side*1.4));door.refresh_collision()
			check(not door.pass_through,id+" restores solid leaf after player clears")
			world.map_obstacles.clear();world._collect_map_colliders(door);check(not world.map_obstacles.is_empty(),id+" closed door collision remains solid")
		door.rotation=original
	for side in [-1.0,1.0]:
		game.camera.position=Vector3(0,1.7,5.84+side*0.45);world._toggle_door();world._toggle_door()
		await create_timer(0.45).timeout
		check(world.door_open and is_equal_approx(world.door_pivot.rotation.y,side*PI/2),"Apartment opens away from either side")
		game.camera.position=Vector3(0,1.7,5.84);world._toggle_door();await create_timer(0.45).timeout
		check(not world.door_open and world.door_pass_through and not world.transitioning,"Apartment closes without trapping doorway occupant")
		check(world._walkable(game.camera.position),"Doorway occupant can step clear of closed apartment door")
		game.camera.position=Vector3(0,1.7,4.5);world._refresh_apartment_door_collision()
		check(not world.door_pass_through and not world._walkable(Vector3(0,1.7,5.84)),"Closed apartment doorway becomes solid after clearance")
	var crew: RefCounted=world.location_ops.crew
	game.dealer_count=1;game.dealers_active=true;game.business_open=true
	for name in ["Malik","Rod"]:
		if crew.manager_node!=null:crew.manager_node.free();crew.manager_node=null
		crew.manager_node=crew.character_instance(name);game.add_child(crew.manager_node)
		crew.animate_manager(Vector3(0.04,0,0.06),false,0.05)
		for player in crew.manager_node.find_children("*","AnimationPlayer",true,false):check(player.current_animation.ends_with("walk") and player.is_playing(),name+" dealer plays walk while moving")
		crew.animate_manager(Vector3.ZERO,false,0.05)
		for player in crew.manager_node.find_children("*","AnimationPlayer",true,false):check(player.current_animation.ends_with("idle"),name+" dealer returns to idle")
		crew.seated_pose(crew.manager_node,true);crew.animate_manager(Vector3.ZERO,true,0.05)
		check(bool(crew.manager_node.get_meta("seated",false)),name+" seated pose retained")
	crew.manager_node.free();crew.manager_node=game.production_worker_node.duplicate();game.add_child(crew.manager_node)
	crew.animate_manager(Vector3(0.1,0,0.1),false,0.05)
	check(absf(crew.manager_node.get_node("LegL").rotation.x)>0.01,"Generic dealer uses articulated walk cycle")
	print("Door swing/dealer walk .92 checks: ",failures," failures")
	game.queue_free();await process_frame;quit(1 if failures else 0)
