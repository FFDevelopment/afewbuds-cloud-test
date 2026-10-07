extends SceneTree
# Branch preview gate: physics checks must pass before Pages deployment.
var failures:=0
var checks:=0
var game:Node3D
var w:Node3D

func _initialize() -> void:call_deferred("run")

func check(ok:bool,label:String,data:Variant=null) -> void:
	checks+=1
	if ok:print("PASS: ",label)
	else:
		failures+=1
		push_error("FAIL: "+label+" "+str(data))

func frames(count:int=4) -> void:
	for i in range(count):await physics_frame

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(8)
	w=game.neighborhood
	for timer in game.find_children("*","Timer",true,false):timer.stop()
	game.session_paused=false
	game.tutorial_active=false
	game.daily_report_pending=false
	game.customer_waiting=false
	game.tutorial_panel.hide()
	game.pause_overlay.hide()
	game.daily_report_panel.hide()
	w.active=true
	w.interior_obstacles.clear()
	w._collect_colliders(game)
	w.map_obstacles.clear()
	w._collect_map_colliders(w)
	w._rebuild_physics_obstacles()
	check(w.physics_body is CharacterBody3D,"Walking player is a CharacterBody3D")
	check(w.physics_body.get_node("PlayerCapsule").shape is CapsuleShape3D,"Walking player uses capsule collision")
	check(w.get_node_or_null("MobilePhysicsGround") is StaticBody3D,"Playable map has a real physics floor")
	check(w.physics_obstacle_root.get_child_count()>20,"Existing collision map is represented by StaticBody3D obstacles",w.physics_obstacle_root.get_child_count())

	# Repeated legacy collision scans must not churn StaticBody3D nodes when the
	# world layout did not actually change.
	var proxy_count:int=int(w.physics_obstacle_root.get_child_count())
	var proxy_id:int=int(w.physics_obstacle_root.get_child(0).get_instance_id()) if proxy_count>0 else 0
	for i in range(20):w._rebuild_physics_obstacles()
	check(w.physics_obstacle_root.get_child_count()==proxy_count and (proxy_count==0 or w.physics_obstacle_root.get_child(0).get_instance_id()==proxy_id),"Stable world state reuses physics obstacle proxies")

	# Closed apartment door blocks, then the same capsule must physically pass
	# through the exact doorway after the door opens.
	w.physics_body.global_position=Vector3(0,0.02,4.4)
	w.physics_body.velocity=Vector3.ZERO
	game.camera.rotation=Vector3.ZERO
	w.pad.value=Vector2(0,1)
	await frames(45)
	w.pad.value=Vector2.ZERO
	check(w.physics_body.global_position.z<5.75,"Closed apartment door physically blocks exit",w.physics_body.global_position)
	w._toggle_door()
	await create_timer(.5).timeout
	w.physics_body.global_position=Vector3(0,0.02,4.4)
	w.physics_body.velocity=Vector3.ZERO
	w._sync_camera_from_physics()
	game.camera.rotation=Vector3.ZERO
	w.pad.value=Vector2(0,1)
	await frames(95)
	w.pad.value=Vector2.ZERO
	check(w.physics_body.global_position.z>7.0,"Open apartment doorway physically permits exit",w.physics_body.global_position)

	# Cross the sidewalk/street/far-sidewalk seam on the actual physics body.
	w.physics_body.global_position=Vector3(5,0.02,9)
	w.physics_body.velocity=Vector3.ZERO
	game.camera.rotation=Vector3.ZERO
	w.pad.value=Vector2(0,1)
	await frames(270)
	w.pad.value=Vector2.ZERO
	check(w.physics_body.global_position.z>22.0,"Physics capsule crosses sidewalk and road continuously",w.physics_body.global_position)
	check(absf(w.physics_body.global_position.y)<.18,"Physics capsule remains grounded",w.physics_body.global_position)

	# Interior wall should stop the capsule rather than camera-coordinate gating.
	w.physics_body.global_position=Vector3(4.2,0.02,-2)
	w.physics_body.velocity=Vector3.ZERO
	game.camera.rotation=Vector3.ZERO
	w.pad.value=Vector2(1,0)
	await frames(90)
	w.pad.value=Vector2.ZERO
	check(w.physics_body.global_position.x<4.9,"Apartment wall physically blocks the capsule",w.physics_body.global_position)

	# Camera remains an eye-height view driven by the physics body.
	w._sync_camera_from_physics()
	check(absf(game.camera.global_position.y-w.physics_body.global_position.y-w.WALK_EYE_HEIGHT)<.01,"Camera follows physics body at walking eye height")

	w.physics_body.stop()
	game.queue_free()
	await frames()
	print("MOBILE_3D_TEST_RESULT: ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
