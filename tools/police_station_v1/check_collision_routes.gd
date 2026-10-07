extends SceneTree
var game:Node3D
var w:Node3D
var results:Array=[]
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String,data:Variant=null) -> void:
	results.append({"check":label,"passed":ok,"data":data})
	if not ok:failures+=1;push_error(label+" "+str(data))
func walk_route(id:String,route:Array) -> void:
	for reverse in [false,true]:
		var points:Array=route.duplicate()
		if reverse:points.reverse()
		game.camera.position=Vector3(points[0].x,2.16,points[0].y);game.camera.rotation=Vector3.ZERO
		var passed:=true
		for index in range(1,points.size()):
			var goal:Vector3=Vector3(points[index].x,2.16,points[index].y)
			for frame in range(600):
				var offset:Vector3=goal-game.camera.position
				if Vector2(offset.x,offset.z).length()<.055:break
				w.pad.value=Vector2(offset.x,offset.z).normalized();w._process(.016)
			if game.camera.position.distance_to(goal)>.09:passed=false;break
		w.pad.value=Vector2.ZERO
		check(passed,id+(" return" if reverse else " outward"),game.camera.position)
func run() -> void:
	assert(OS.get_user_data_dir().contains("AFB Character Fit Validation"))
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	w=game.neighborhood;game.set_process(false);w.set_process(false);game._cancel_camera_view_tween()
	for timer in game.find_children("*","Timer",true,false):timer.stop()
	game.session_paused=false;game.tutorial_active=false;game.daily_report_pending=false;game.customer_waiting=false
	game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide();w.active=true
	walk_route("West grass to west sidewalk",[Vector2(119,-12.5),Vector2(119,-1.6),Vector2(116,-1.6)])
	walk_route("West grass to front sidewalk",[Vector2(119,4.5),Vector2(123,4.5),Vector2(125.5,4.5),Vector2(125.5,9)])
	walk_route("East grass to east sidewalk",[Vector2(132.5,-8),Vector2(132.5,-1.6),Vector2(136,-1.6)])
	walk_route("North grass to rear sidewalk",[Vector2(123,-12.5),Vector2(125.5,-12.5),Vector2(125.5,-15.8)])
	walk_route("Public lot to street",[Vector2(188.5,-12),Vector2(188.5,16)])
	walk_route("Accessible bay to sidewalk",[Vector2(182.5,3.5),Vector2(182.5,10)])
	walk_route("Patrol lot to rear sidewalk",[Vector2(161.5,-30),Vector2(161.5,-19),Vector2(177,-19),Vector2(177,-16)])
	var seats=w.bench_seating
	for i in range(seats.benches.size()):
		var b:Dictionary=seats.benches[i];var basis:=Basis(Vector3.UP,b.facing)
		for distance in [.72,1.05,1.65]:
			game.camera.position=b.at+basis*Vector3(0,w.WALK_EYE_HEIGHT,-distance)
			seats.use("bench_"+str(i))
			check(seats.seated==i,"Bench %d sit from %.2f"%[i,distance])
			for frame in range(30):w._process(.016)
			w.pad.value=Vector2(0,-1);w._process(.016);w.pad.value=Vector2.ZERO
			check(seats.seated<0 and w._walkable(game.camera.position-w.ORIGIN),"Bench %d movement stands clear %.2f"%[i,distance],game.camera.position)
			var stood:=Vector2(game.camera.position.x,game.camera.position.z)
			walk_route("Bench %d to path and sidewalk %.2f"%[i,distance],[stood,Vector2(125.5,stood.y),Vector2(125.5,-1.6),Vector2(137,-1.6),Vector2(137,9)])
	var report={"passed":failures==0,"failures":failures,"checks":results}
	FileAccess.open("res://../collision_routes.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("COLLISION_ROUTES ",results.size()," checks; ",failures," failures")
	game.queue_free();await process_frame;quit(1 if failures else 0)
