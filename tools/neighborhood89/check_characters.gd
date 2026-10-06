extends SceneTree
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures+=1;push_error(message)
func run() -> void:
	var game: Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process(false);game.neighborhood.set_process(false);game.session_paused=false;game.tutorial_active=false;game.daily_report_pending=false;game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide();game.visit_timer.stop()
	var crew: RefCounted=game.neighborhood.location_ops.crew
	var visuals: Array[Node3D]=[]
	for name in ["Malik","Rod"]:
		var model: Node3D=crew.character_instance(name);root.add_child(model);visuals.append(model)
		var rigs=model.find_children("*","Skeleton3D",true,false);check(rigs.size()==1 and rigs[0].get_bone_count()==56,name+" retains 56-bone rig")
		var meshes=model.find_children("*","MeshInstance3D",true,false);check(not meshes.is_empty(),name+" has skinned geometry")
		var bounds:=AABB();var first:=true
		for mesh in meshes:
			var box: AABB=mesh.global_transform*mesh.get_aabb();bounds=box if first else bounds.merge(box);first=false
		check(bounds.size.y>1.5 and bounds.size.y<2.1,name+" supplied physical scale fits room")
		print(name," mesh height at supplied scale: ",bounds.size.y)
		for player in model.find_children("*","AnimationPlayer",true,false):
			check(not player.current_animation.is_empty(),name+" starts idle")
			var has_walk:=false
			for clip in player.get_animation_list():
				if str(clip).ends_with("walk"):has_walk=true
			check(has_walk,name+" has walk animation")
	game.packing_employee_hired=true;game.packing_employee_active=true
	for name in ["Malik","Rod"]:
		game.production_worker_friend_name=name;crew.update_malik()
		check(crew.malik_worker!=null and crew.malik_worker.get_meta("character","")==name,name+" replaces production worker visual")
		game.current_customer=game._customer_by_name(name);game.customer_waiting=true;crew.update_malik()
		check(crew.malik_visitor!=null and crew.malik_visitor.get_meta("character","")==name,name+" visitor visual selected")
	game.customer_waiting=false;crew.update_malik();check(not crew.malik_visitor.visible,"Visitor visual hides after visit")
	game.production_worker_node.show();game.production_worker_pending_action="";game.production_worker_task="Waiting for work"
	game.production_worker_node.position=Vector3(-2.775,0,2.1);crew.update_seating(0.1)
	check(bool(crew.malik_worker.get_meta("seated",false)),"Idle worker sits on couch")
	game.production_worker_pending_action="water";crew.update_seating(0.1)
	check(not bool(crew.malik_worker.get_meta("seated",true)),"Worker stands when work arrives")
	var world: Node3D=game.neighborhood
	game.camera.position=Vector3(-1.78,1.7,1.5);var before: Vector3=game.camera.position
	world._toggle_couch();check(world.couch_seated and game.camera.position.y<1.4,"Player seated viewpoint")
	world._toggle_couch();check(not world.couch_seated and game.camera.position==before,"Standing restores safe approach position")
	if OS.get_cmdline_user_args().has("--capture"):
		game.production_worker_node.hide();game.phone_open=false;game.phone_panel.hide();root.size=Vector2i(1280,800)
		visuals[0].position=Vector3(-2.775,0,3.0);visuals[1].position=Vector3(-1.785,0,3.0)
		crew.seated_pose(visuals[0],true);crew.seated_pose(visuals[1],true)
		for model in visuals:model.look_at(Vector3(1.7,0,-1.0))
		game.camera.position=Vector3(1.7,1.4,-0.25);game.camera.look_at(Vector3(-2.28,1.03,3.0))
		game.main_ceiling_light_on=true;game._update_day_night_visuals()
		for i in range(8):game.session_paused=false;game.pause_overlay.hide();await process_frame
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/scratch/05254e9fc6fb/malik-rod89.png")
	for model in visuals:model.queue_free()
	game.queue_free();await process_frame;print("Malik/Rod .89 checks: ",failures," failures");quit(1 if failures else 0)
