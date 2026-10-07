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

	# Police station now uses the same physical capsule, including door leaves,
	# floors and one smooth collision ramp beneath the visible stair treads.
	var station:Node3D=w.police_station
	check(station.get_node_or_null("StationStructure") is StaticBody3D,"Police station has native StaticBody3D structure")
	check(station.get_node_or_null("StationStructure/StairRamp") is CollisionShape3D,"Police stairs expose a continuous physics ramp")
	# Visual stairwell pieces must not occupy volume inside the upstairs deck.
	var upper_decks:Array[AABB]=[]
	for entry in station.parts:
		if str(entry.id) in ["UpperFloorWest","UpperFloorNorth","UpperFloorSouth"]:
			upper_decks.append(entry.bounds)
	var stair_clips:Array[String]=[]
	for entry in station.parts:
		var id_text:=str(entry.id)
		if int(entry.floor)==0 and (id_text.begins_with("Stair") or id_text=="ContinuousHandrail" or id_text=="RailWallBracket"):
			for deck in upper_decks:
				if entry.bounds.intersects(deck):
					stair_clips.append(id_text)
	check(stair_clips.is_empty(),"Police stair/wall geometry does not clip through upstairs floor",stair_clips)
	var final_nosing_count:=0
	for entry in station.parts:
		if str(entry.id)=="StairNosing" and int(entry.floor)==0:final_nosing_count+=1
	check(final_nosing_count==19,"Top stair nosing stops below upstairs landing",final_nosing_count)
	var public_door:Node3D=station.get_node("PUBLIC_ENTRANCE")
	await frames(2)
	check(public_door.get_node_or_null("Leaf/DoorPhysics") is StaticBody3D,"Police door uses shared physical door controller")
	w.physics_body.global_position=station.point(11.2,.02,30)
	w.physics_body.velocity=Vector3.ZERO
	w._sync_camera_from_physics()
	game.camera.rotation=Vector3.ZERO
	w.pad.value=Vector2(0,-1)
	await frames(55)
	w.pad.value=Vector2.ZERO
	check(station.local_point(w.physics_body.global_position).z>28.0,"Closed police entrance physically blocks capsule",w.physics_body.global_position)
	public_door.toggle(game.camera.global_position)
	await create_timer(.55).timeout
	w.physics_body.global_position=station.point(11.2,.02,30)
	w.physics_body.velocity=Vector3.ZERO
	w._sync_camera_from_physics()
	game.camera.rotation=Vector3.ZERO
	w.pad.value=Vector2(0,-1)
	await frames(100)
	w.pad.value=Vector2.ZERO
	check(station.local_point(w.physics_body.global_position).z<27.5,"Open police entrance permits same capsule",w.physics_body.global_position)

	w.physics_body.global_position=station.point(21.5,.02,20.7)
	w.physics_body.velocity=Vector3.ZERO
	w._sync_camera_from_physics()
	game.camera.rotation=Vector3.ZERO
	w.pad.value=Vector2(0,-1)
	await frames(165)
	w.pad.value=Vector2.ZERO
	var stair_top:Vector3=station.local_point(w.physics_body.global_position)
	check(stair_top.y>3.15 and stair_top.z<14.7,"Same mobile capsule climbs police stair ramp continuously",stair_top)

	# Acceleration is intentionally eased: touch movement starts smoothly rather
	# than snapping immediately to full walk speed.
	w.physics_body.global_position=Vector3(80,.02,17)
	w.physics_body.velocity=Vector3.ZERO
	w._sync_camera_from_physics()
	game.camera.rotation=Vector3.ZERO
	w.pad.value=Vector2(1,0)
	await frames(1)
	var first_speed:float=Vector2(w.physics_body.velocity.x,w.physics_body.velocity.z).length()
	await frames(24)
	var cruise_speed:float=Vector2(w.physics_body.velocity.x,w.physics_body.velocity.z).length()
	w.pad.value=Vector2.ZERO
	await frames(18)
	var stopped_speed:float=Vector2(w.physics_body.velocity.x,w.physics_body.velocity.z).length()
	check(first_speed>0.0 and first_speed<w.physics_body.WALK_SPEED,"Touch movement accelerates instead of snapping to full speed",first_speed)
	check(cruise_speed>3.0,"Touch movement reaches normal walking speed",cruise_speed)
	check(stopped_speed<.25,"Touch movement decelerates cleanly",stopped_speed)

	# Full forward stick is the mobile sprint gesture. Partial forward remains
	# walk speed so the player keeps fine control indoors.
	w.physics_body.global_position=Vector3(5,.02,22)
	w.physics_body.velocity=Vector3.ZERO
	w.physics_body.stamina=w.physics_body.STAMINA_MAX
	w.physics_body.exhausted=false
	w._sync_camera_from_physics()
	game.camera.rotation=Vector3.ZERO
	w.pad.value=Vector2(0,-1)
	await frames(45)
	var sprint_speed:float=Vector2(w.physics_body.velocity.x,w.physics_body.velocity.z).length()
	var stamina_after_sprint:float=w.physics_body.stamina
	check(w.physics_body.is_sprinting and sprint_speed>4.8,"Full forward touch stick engages sprint",sprint_speed)
	check(stamina_after_sprint<w.physics_body.STAMINA_MAX-5.0,"Sprint drains stamina",stamina_after_sprint)
	check(w.stamina_bar!=null and w.stamina_bar.visible and w.stamina_bar.value<100.0,"Sprint stamina bar becomes visible",w.stamina_bar.value if w.stamina_bar!=null else -1)
	check(w.stamina_text!=null and w.stamina_text.text=="SPRINTING","Sprint HUD says SPRINTING",w.stamina_text.text if w.stamina_text!=null else "")

	w.pad.value=Vector2(0,-.72)
	await frames(35)
	var partial_speed:float=Vector2(w.physics_body.velocity.x,w.physics_body.velocity.z).length()
	check(not w.physics_body.is_sprinting and partial_speed<4.1,"Partial forward touch remains normal walking",partial_speed)

	w.pad.value=Vector2.ZERO
	var stamina_before_recovery:float=w.physics_body.stamina
	await frames(90)
	check(w.physics_body.stamina>stamina_before_recovery+5.0,"Stamina recovers after sprint delay",w.physics_body.stamina)

	w.physics_body.stamina=.1
	w.physics_body.exhausted=false
	w.pad.value=Vector2(0,-1)
	await frames(10)
	check(w.physics_body.exhausted and not w.physics_body.is_sprinting,"Empty stamina triggers exhaustion lockout")
	w.pad.value=Vector2.ZERO
	await frames(150)
	check(not w.physics_body.exhausted and w.physics_body.stamina>=w.physics_body.STAMINA_REENABLE,"Recovery clears exhaustion after threshold",w.physics_body.stamina)

	w.physics_body.stop()
	game.queue_free()
	await frames()
	print("MOBILE_3D_TEST_RESULT: ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
