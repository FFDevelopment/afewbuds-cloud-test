extends SceneTree
var failures:=0
var checks:Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks.append({"check":message,"passed":ok})
	if not ok:failures+=1;push_error(message)
func run() -> void:
	assert(OS.get_user_data_dir().contains("AFB Character Fit Validation"))
	var game: Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process(false);game.neighborhood.set_process(false);game.session_paused=false;game.tutorial_active=false;game.daily_report_pending=false;game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide();game.visit_timer.stop()
	var world: Node3D=game.neighborhood
	var crew: RefCounted=world.location_ops.crew
	var couch: Node3D=game.get_node("AFBLoveseat")
	check(is_equal_approx(couch.SEAT_TOP,0.4682184907339378),"Uploaded lower couch replaces original")
	check(couch.has_node("SeatLeft") and couch.has_node("SeatRight"),"Couch retains fitted seat markers")
	var visuals: Array[Node3D]=[]
	for name in ["Malik","Rod","Kobi"]:
		var model: Node3D=crew.character_instance(name);root.add_child(model);visuals.append(model)
		var rig: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
		var player: AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0]
		var mesh: MeshInstance3D=model.find_children("*","MeshInstance3D",true,false)[0]
		check(rig.get_bone_count()==56,name+" master rig retained")
		check(mesh.material_override!=null and mesh.material_override.albedo_texture!=null,name+" supplied atlas applied")
		var bounds: AABB=mesh.global_transform*mesh.get_aabb();check(bounds.size.y>2.2 and bounds.size.y<2.5,name+" supplied 2.35-unit physical scale retained")
		player.play("idle");player.advance(.3);var idle_root: Vector3=rig.get_bone_pose_position(rig.find_bone("Root"))
		crew.seated_pose(model,true);check(player.current_animation.ends_with("sit"),name+" uses supplied sit animation")
		player.advance(.3);rig.force_update_all_bone_transforms()
		var matrices: Array[Transform3D]=[]
		for j in range(mesh.skin.get_bind_count()):matrices.append(rig.global_transform*rig.get_bone_global_pose((rig.find_bone(mesh.skin.get_bind_name(j)) if not str(mesh.skin.get_bind_name(j)).is_empty() else mesh.skin.get_bind_bone(j)))*mesh.skin.get_bind_pose(j))
		var sole:=INF;var pelvis:=INF
		for surface in range(mesh.mesh.get_surface_count()):
			var arrays: Array=mesh.mesh.surface_get_arrays(surface)
			for i in range(arrays[Mesh.ARRAY_VERTEX].size()):
				var v: Vector3=arrays[Mesh.ARRAY_VERTEX][i];var p:=Vector3.ZERO
				for k in range(4):p+=(matrices[arrays[Mesh.ARRAY_BONES][i*4+k]]*v)*arrays[Mesh.ARRAY_WEIGHTS][i*4+k]
				sole=minf(sole,p.y)
				if v.y>.79 and v.y<.97 and absf(v.x)<.185 and p.z>-.1*rig.global_transform.basis.get_scale().z:pelvis=minf(pelvis,p.y)
		check(absf(sole)<.004,name+" seated feet grounded")
		check(absf(pelvis-couch.SEAT_TOP)<.004,name+" pelvis rests on supplied cushion")
		print(name," height=",bounds.size.y," sole=",sole," pelvis=",pelvis)
		crew.seated_pose(model,false);player.advance(.3);check(player.current_animation.ends_with("idle") and rig.get_bone_pose_position(rig.find_bone("Root")).distance_to(idle_root)<.0001,name+" standing resets seated root")
		game.packing_employee_hired=true;game.production_worker_friend_name=name;crew.update_malik();check(crew.malik_worker.get_meta("character")==name,name+" production appearance updated")
		game.current_customer=game._customer_by_name(name);game.customer_waiting=true;crew.update_malik();check(crew.malik_visitor.get_meta("character")==name,name+" visitor appearance updated")
	game.customer_waiting=false;crew.update_malik();game.production_worker_node.show();game.production_worker_pending_action="";game.production_worker_task="Waiting for work";game.production_worker_node.position=Vector3(-2.775,0,2.1);crew.update_seating(.1)
	check(bool(crew.malik_worker.get_meta("seated",false)) and is_zero_approx(crew.malik_worker.position.y),"Worker sits with floor-level character root")
	game.production_worker_pending_action="water";crew.update_seating(.1);check(not bool(crew.malik_worker.get_meta("seated",true)),"Worker resumes standing for work")
	game.production_worker_friend_name="Rod";game.friend_staff_roles["Kobi"]="dealer"
	game.location_state["apartment_manager"]="Kobi";game.location_state.staff_assignments["Kobi"]="apartment"
	crew.update(.01)
	check(crew.manager_node!=null and crew.manager_node.get_meta("character","")=="Kobi","Assigned Kobi door manager uses his ped")
	check(crew.manager_node!=crew.malik_worker,"Kobi manager and Rod worker have independent instances")
	crew.animate_manager(Vector3(.1,0,0),false,.1)
	var manager_player:AnimationPlayer=crew.manager_node.find_children("*","AnimationPlayer",true,false)[0]
	check(manager_player.current_animation.ends_with("walk"),"Kobi manager walks during movement")
	crew.seated_pose(crew.manager_node,true);check(manager_player.current_animation.ends_with("sit"),"Kobi manager can sit")
	crew.seated_pose(crew.manager_node,false);check(manager_player.current_animation.ends_with("idle"),"Kobi manager stands back into idle")
	var header: Material=game.get_node("FrontWallHeader").get_active_material(0)
	var wall: Material=game.get_node("FrontWallR").get_active_material(0)
	check(header.albedo_texture!=null and header.albedo_texture==wall.albedo_texture and header.albedo_color==wall.albedo_color and header.uv1_scale==wall.uv1_scale,"Door header matches adjoining painted-wall material")
	FileAccess.open("res://../kobi_results.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures==0,"failures":failures,"checks":checks},"\t"))
	for model in visuals:model.queue_free()
	game.queue_free();await process_frame;print("KOBI_INTEGRATION ",checks.size()," checks; ",failures," failures");quit(1 if failures else 0)
