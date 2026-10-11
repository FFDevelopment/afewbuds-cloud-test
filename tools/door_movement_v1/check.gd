extends SceneTree
# Deterministic house door cycle regression: no teleport, speed cap, real route and movable sofas.
var failures:=0
var checks:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if ok:print("PASS: "+message)
	else:failures+=1;push_error("HOUSE_DOOR_MOTION FAIL: "+message)
func _initialize()->void:call_deferred("run")
func run()->void:
	var desktop:bool=ResourceLoader.exists("res://prototype/apartment.tscn")
	var game:Node3D=load("res://prototype/apartment.tscn" if desktop else "res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.neighborhood.set_process(false)
	if desktop:game.fp_player.set_physics_process(false)
	elif game.neighborhood.physics_body!=null:game.neighborhood.physics_body.set_physics_process(false)
	game.gameplay_ready=true
	game.session_paused=false
	game.tutorial_active=false
	game.daily_report_pending=false
	game.tutorial_panel.hide()
	game.pause_overlay.hide()
	game.daily_report_panel.hide()
	game.visit_timer.stop()
	game.property_opportunity_state["acquired"]=true
	game.property_opportunity_state["relocated"]=true
	game.location_state["active_property"]="house"
	game.location_state["staff_duty"]={"Rod":true}
	game.location_state["staff_assignments"]["Rod"]="house"
	game.location_state["door_managers"]={"house":"Rod"}
	game.friend_staff_roles["Rod"]="door"
	var crew:RefCounted=game.neighborhood.location_ops.crew
	var nav:RefCounted=game._house_npc_route()
	var approach:Vector3=crew.house_couch_approach()
	var seat:Vector3=crew.idle_spot(true,false,"house")
	check(approach!=Vector3.INF and seat.distance_to(approach)>0.5,"Seating has a distinct walkable stand/exit point")
	check(not nav._blocked(approach,nav._installed_footprints()),"House couch exit is outside furniture footprint")
	var manager:Node3D=Node3D.new()
	game.add_child(manager)
	crew.manager_node=manager
	manager.position=seat
	crew.seated_pose(manager,true)
	manager.set_meta("house_motion","seated")
	manager.set_meta("idle_seat_id",str(crew.idle_couch("house").get("id","")))
	manager.set_meta("idle_seat_position",seat)
	manager.set_meta("house_stand_point",approach)
	var client:Dictionary=game.customers[0].duplicate(true)
	game.customer_waiting=true
	game.customer_answered=false
	game.customer_departing=false
	game.current_customer=client
	game.active_request={"product":str(client.get("favorite","")),"qty":1}
	crew._update_house_door_manager(.1,"Rod")
	check(str(manager.get_meta("house_motion",""))=="stand" and manager.position.distance_to(Vector3(seat.x,0,seat.z))<.01,"Worker rises at couch instead of teleporting to the door")
	check(not crew.manager_attempted,"Customer sale cannot happen during stand-up")
	var max_step:float=0.0
	var stepped_from_couch:=false
	var reached_door:=false
	var route_clear:=true
	var earliest_sale:=false
	var total:float=.1
	for i in 220:
		var before:Vector3=manager.position
		crew._update_house_door_manager(.1,"Rod")
		total+=.1
		var delta_horizontal:float=Vector2(manager.position.x-before.x,manager.position.z-before.z).length()
		max_step=maxf(max_step,delta_horizontal)
		var motion:String=str(manager.get_meta("house_motion",""))
		if motion=="walk" and manager.position.distance_to(seat)>1.5:
			stepped_from_couch=true
			if nav._blocked(manager.position,nav._installed_footprints()):route_clear=false
		if manager.position.distance_to(Vector3(35,0,2.1))<.18:reached_door=true
		if crew.manager_attempted and total<4.0:earliest_sale=true
		if crew.manager_attempted:break
	check(max_step<.2,"Movement stays within a walking-speed step, without a position snap")
	check(stepped_from_couch and route_clear,"Route to the front door avoids the couch and other furniture")
	check(reached_door and not earliest_sale,"Worker physically arrives at door before attempting customer service")
	check(crew.manager_attempted,"Dealer waits at door for a service interaction before offering the sale")
	game.customer_waiting=false
	game.current_customer={}
	for i in 260:
		crew._update_house_door_manager(.1,"Rod")
		if bool(manager.get_meta("seated",false)):break
	check(bool(manager.get_meta("seated",false)),"Worker returns using a safe approach and completes sitting animation")
	var model:RefCounted=game.inventory_system.furniture.model
	var snapshot:Dictionary=model.state.items.duplicate(true)
	model.state.items["nav_moved_sofa"]={"sku":"sofa","property":"house","position":[30.5,0,0],"yaw":90}
	nav.refresh(true)
	var moved:Dictionary=crew.idle_couch("house")
	var new_approach:Vector3=crew.house_couch_approach()
	check(str(moved.get("id",""))=="nav_moved_sofa" and new_approach!=Vector3.INF,"Moved sofa supplies updated door-dealer resting target")
	check(new_approach.distance_to(approach)>1.0 and not nav._blocked(new_approach,nav._installed_footprints()),"Rearranged furniture forces a fresh walkable seating approach")
	model.state.items=snapshot
	nav.refresh(true)
	game.queue_free()
	await process_frame
	await process_frame
	print("HOUSE_DOOR_MOTION_RESULT: "+("PASS" if failures==0 else "FAIL")+" checks="+str(checks)+" failures="+str(failures))
	quit(0 if failures==0 else 1)
