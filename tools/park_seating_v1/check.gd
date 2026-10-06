extends SceneTree
var game:Node3D
var world:Node3D
var checks:Array=[]
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
	checks.append({"check":label,"passed":ok})
	if not ok:failures+=1;push_error(label)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	world=game.neighborhood;game.set_process(false);world.set_process(false);game._cancel_camera_view_tween()
	for timer in game.find_children("*","Timer",true,false):timer.stop()
	game.session_paused=false;game.tutorial_active=false;game.daily_report_pending=false;game.customer_waiting=false
	game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide();world.active=true
	world.interior_obstacles.clear();world._collect_colliders(game)
	world.map_obstacles.clear();world._collect_map_colliders(world)
	var seats=world.bench_seating
	Input.use_accumulated_input=false
	check(OS.get_user_data_dir().contains("AFB Character Fit Validation"),"Isolated validation save")
	check(seats.benches.size()==3,"All three park benches registered")
	for id in ["Malik","Rod"]:
		var model:Node3D=world.location_ops.crew.character_instance(id);root.add_child(model)
		world.location_ops.crew.seated_pose(model,true)
		for player in model.find_children("*","AnimationPlayer",true,false):player.advance(0);player.seek(.5,true)
		var skeleton:Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
		var midpoint:Vector3=(skeleton.get_bone_global_pose(skeleton.find_bone("Eye_L")).origin+skeleton.get_bone_global_pose(skeleton.find_bone("Eye_R")).origin)*.5
		print("RIG_EYES ",id," ",midpoint," global ",skeleton.to_global(midpoint))
		check(skeleton.to_global(midpoint).distance_to(seats.RIG_SEATED_EYES)<.001,id+" actual sit eye bones match camera reference")
		model.free()
	for i in range(seats.benches.size()):
		var b:Dictionary=seats.benches[i];var basis:=Basis(Vector3.UP,b.facing)
		var approach:Vector3=b.at+basis*Vector3(0,world.WALK_EYE_HEIGHT,-1.05)
		game.camera.position=approach
		game.camera.look_at(b.at+Vector3.UP*.7)
		check(world._walkable(approach),"Bench %d approach is walkable"%i)
		check(world._near_target()=="bench_"+str(i),"Bench %d front is reachable"%i)
		world._process(.016)
		check(world.action.visible and world.action.text=="SIT ON BENCH","Bench %d sit button visible"%i)
		world.action.pressed.emit()
		var expected:Vector3=seats.eyes(b.at,b.facing,b.seat_top)
		check(seats.seated==i and game.camera.position.distance_to(expected)<.001,"Bench %d button sits at eyes"%i)
		check((-game.camera.basis.z).dot(-basis.z)>.999,"Bench %d faces away from backrest"%i)
		check(not world.couch_seated,"Bench %d does not occupy apartment couch"%i)
		world._process(.016)
		check(game.camera.position.distance_to(expected)<.001,"Bench %d camera stays at seated height"%i)
		check(world.action.text=="STAND UP","Bench %d stand button visible"%i)
		world.action.pressed.emit()
		check(seats.seated<0 and game.camera.position.distance_to(approach)<.001,"Bench %d button restores safe standing position"%i)
		game.camera.position=b.at+basis*Vector3(0,world.WALK_EYE_HEIGHT,1.05)
		check(seats.target().is_empty(),"Bench %d cannot sit through backrest"%i)
		game.camera.position=approach;game.camera.look_at(b.at+Vector3.UP*.65)
		world.last_tap_station="";world.tap_distance=0
		var screen:Vector2=game.camera.unproject_position(b.at+Vector3.UP*.65)
		world._tap(screen);check(seats.seated<0,"Bench %d first tap only hints"%i)
		world._tap(screen);check(seats.seated==i,"Bench %d double tap sits"%i)
		world.pad.value=Vector2(0,-1);world._process(.016);world.pad.value=Vector2.ZERO
		check(seats.seated<0 and is_equal_approx(game.camera.position.y,world.WALK_EYE_HEIGHT) and world._walkable(game.camera.position),"Bench %d movement stands and stays walkable"%i)
		game.camera.position=approach;world._interact()
		var key:=InputEventKey.new();key.physical_keycode=KEY_W;key.pressed=true;Input.parse_input_event(key)
		Input.flush_buffered_events();world._process(.016)
		var release:=InputEventKey.new();release.physical_keycode=KEY_W;release.pressed=false;Input.parse_input_event(release);Input.flush_buffered_events()
		check(seats.seated<0 and is_equal_approx(game.camera.position.y,world.WALK_EYE_HEIGHT),"Bench %d keyboard stands"%i)
		if seats.seated>=0:seats.stand()
		game.camera.position=approach;game.daily_report_pending=true;world._interact()
		check(seats.seated<0,"Bench %d modal blocks seating"%i);game.daily_report_pending=false
	# A blocked return point must use a checked alternative, never a blind teleport.
	var b:Dictionary=seats.benches[0];var basis:=Basis(Vector3.UP,b.facing)
	game.camera.position=b.at+basis*Vector3(.65,world.WALK_EYE_HEIGHT,-1.4);world._interact()
	var return_at:Vector3=seats.return_position
	world.obstacles.append(Rect2(Vector2(return_at.x-.15,return_at.z-.15),Vector2(.3,.3)))
	check(seats.stand() and world._walkable(game.camera.position) and game.camera.position.distance_to(return_at)>.2,"Blocked saved exit uses clear front fallback")
	world.obstacles.pop_back()
	game.camera.position=Vector3(0,world.WALK_EYE_HEIGHT,0);seats.use("bench_0")
	check(seats.seated<0,"Cannot remotely activate a bench")
	game.camera.position=Vector3(-1.8,world.WALK_EYE_HEIGHT,1.9);world._interact()
	check(world.couch_seated and absf(game.camera.position.y-seats.RIG_SEATED_EYES.y)<.001,"Couch uses actual seated eye height")
	check(absf(game.camera.position.z-(3.035+seats.RIG_SEATED_EYES.z))<.001,"Couch uses actual eye forward offset")
	world._process(.016);check(absf(game.camera.position.y-seats.RIG_SEATED_EYES.y)<.001,"Couch seated view remains stable")
	world._interact();check(not world.couch_seated and is_equal_approx(game.camera.position.y,world.WALK_EYE_HEIGHT),"Couch stand restores walking eyes")
	FileAccess.open("res://../seating_results.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures==0,"failures":failures,"checks":checks},"\t"))
	print("SEATING_CHECKS ",checks.size()," checks; ",failures," failures")
	game.queue_free();await process_frame;quit(1 if failures else 0)
