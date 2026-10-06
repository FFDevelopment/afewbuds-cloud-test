extends SceneTree
var game:Node3D
var world:Node3D
var station:Node3D
var results:Array=[]
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String,data:Variant=null) -> void:
	results.append({"check":label,"passed":ok,"data":data})
	if not ok:failures+=1;push_error(label+" "+str(data))
func flood(start:Vector3,floor_y:float) -> Dictionary:
	var step:=.32;var queue:Array[Vector2i]=[];var visited:Dictionary={}
	var seed:=Vector2i(roundi((start.x-station.BASE.x)/step),roundi((start.z-station.BASE.z)/step))
	queue.append(seed);visited[seed]=true;var cursor:=0
	while cursor<queue.size():
		var cell:=queue[cursor];cursor+=1
		for dir in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next:Vector2i=cell+dir
			if visited.has(next) or next.x< -5 or next.x>80 or next.y< -6 or next.y>77:continue
			var at:Vector3=station.BASE+Vector3(next.x*step,station.EYE+floor_y,next.y*step)
			if absf(station.floor_at(at)-floor_y)>.1 or not world._walkable(at):continue
			visited[next]=true;queue.append(next)
	return visited
func reached(cells:Dictionary,at:Vector3) -> bool:
	for c in cells:
		var p:Vector3=station.BASE+Vector3(c.x*.32,at.y,c.y*.32)
		if Vector2(p.x-at.x,p.z-at.z).length()<.55:return true
	return false
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	world=game.neighborhood;station=world.police_station;game.set_process(false);world.set_process(false);game._cancel_camera_view_tween()
	for timer in game.find_children("*","Timer",true,false):timer.stop()
	game.session_paused=false;game.tutorial_active=false;game.daily_report_pending=false;game.customer_waiting=false
	game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide();world.active=true
	check(OS.get_user_data_dir().contains("AFB Character Fit Validation"),"Isolated validation save")
	# Regression for the reported parking/partition/entrance defects.
	var surfaces:Array=world.get_meta("police_surfaces")
	var overlaps:Array=[]
	for i in range(surfaces.size()):
		for j in range(i+1,surfaces.size()):
			var a:Dictionary=surfaces[i];var b:Dictionary=surfaces[j]
			if a.tile not in [2,3] or b.tile not in [2,3]:continue
			if absf(a.top-b.top)>.002:continue
			var overlap:Rect2=a.rect.intersection(b.rect)
			if overlap.size.x>.002 and overlap.size.y>.002:overlaps.append([a,b])
	check(overlaps.is_empty(),"Parking and sidewalk finish surfaces do not overlap",overlaps)
	for win in station.windows:
		var clips:Array=[]
		for p in station.parts:
			if p.id in ["Front","Rear","West","East"] or p.id.ends_with("Skirting") or p.id.begins_with("Window"):continue
			if win.bounds.grow(.22).intersects(p.bounds):clips.append(p.id)
		check(clips.is_empty(),"Window clears partitions and adjacent fixtures "+str(win.at),clips)
	var entries:=0
	for entry in world.entrance_records:
		if entry.at.x<149:continue
		entries+=1
		check(entry.normal==Vector3.FORWARD and is_equal_approx(entry.at.z,27.0),"Residence entry faces the police street",entry)
		check(world._walkable(Vector3(entry.at.x,2.16,26.4)),"Residence entrance path is accessible",entry.at)
	check(entries==4,"All four police-street residences have entrances")
	check(station.doors.size()>=14,"Ground and upper doors registered",station.doors.size())
	check(world.map_doors.size()==5,"Original five doors preserved")
	check(world.bench_seating.benches.size()==3,"Park seating preserved")
	for d in station.doors:
		var center:Vector3=d.to_global(Vector3(d.width/2,station.EYE,0))
		check(not world._walkable(center),str(d.name)+" closed blocks passage")
		d.toggle(center+d.basis.z)
	game.camera.position=Vector3(140,2.16,17);await create_timer(.55).timeout
	for d in station.doors:
		d.refresh_collision()
		var center:Vector3=d.to_global(Vector3(d.width/2,station.EYE,0))
		check(d.opened and world._walkable(center),str(d.name)+" opens to clear aperture",center)
	var ground_start:Vector3=station.point(11.2,station.EYE,29.5)
	var lower:=flood(ground_start,0)
	for target in [Vector3(11.2,0,26),Vector3(20.3,0,26.5),Vector3(12,0,18.8),Vector3(7,0,5),Vector3(7,0,12),Vector3(20,0,4.5),Vector3(20,0,10.5),Vector3(14.3,0,-2),Vector3(21.5,0,21)]:
		check(reached(lower,station.point(target.x,station.EYE,target.z)),"Lobby route to ground room "+str(target))
	var upper:=flood(station.point(21.5,station.EYE+station.STORY,12.75),station.STORY)
	for target in [Vector3(7,0,9),Vector3(15,0,9.5),Vector3(23,0,5.3),Vector3(20,0,9.5),Vector3(6.5,0,25),Vector3(11,0,18),Vector3(15,0,14)]:
		check(reached(upper,station.point(target.x,station.EYE+station.STORY,target.z)),"Upper landing route to room "+str(target))
	# Walk both ways in short real movement increments; verify collision and eye support.
	var position:Vector3=station.point(21.5,station.EYE,21)
	for direction in [-1.0,1.0]:
		for i in range(83):
			var next:=position+Vector3(0,0,direction*.08)
			check(world._walkable(next),"Stair path clearance "+str(direction)+" "+str(i),next)
			next.y=station.eye_height(next);position=next
		check(absf(position.y-(station.EYE+(station.STORY if direction<0 else 0)))<.01,"Stairs finish at correct floor "+str(direction),position)
	for win in station.windows:check(win.bottom>win.floor+.8 and win.top<win.floor+3.4,"Window contained in its floor",win)
	game.camera.position=station.point(21.5,station.EYE,21);game.camera.rotation=Vector3.ZERO
	world.pad.value=Vector2(0,-1)
	for i in range(117):world._process(.016)
	world.pad.value=Vector2.ZERO
	check(absf(game.camera.position.y-5.76)<.01,"Real touch movement climbs stairs without resetting eyes",game.camera.position)
	world.pad.value=Vector2(0,1)
	for i in range(117):world._process(.016)
	world.pad.value=Vector2.ZERO
	check(absf(game.camera.position.y-2.16)<.01,"Real touch movement descends stairs",game.camera.position)
	for at in [Vector3(137,2.16,17),Vector3(142,2.16,17),Vector3(160.2,2.16,10),Vector3(190,2.16,17),Vector3(176,2.16,0)]:check(world._walkable(at),"Open district route "+str(at))
	check(not world._walkable(Vector3(201.1,2.16,17)),"East perimeter contains player")
	var front:Node3D=station.get_node("PUBLIC_ENTRANCE")
	game.camera.position=station.point(11.2,2.16,30);game.camera.look_at(station.point(11.2,1.6,28))
	world._process(.016)
	check(world._near_target().begins_with("police_") and world.action.visible,"Front entrance exposes contextual action")
	check(world.action.text.begins_with("CLOSE"),"Open front door offers Close")
	world.action.pressed.emit();await create_timer(.55).timeout
	check(not front.opened,"Contextual action closes police door")
	world._process(.016);check(world.action.text.begins_with("OPEN"),"Closed front door offers Open")
	var door_screen:Vector2=game.camera.unproject_position(front.get_node("Leaf").to_global(Vector3(front.width/2,1.5,0)))
	world.last_tap_station="";world.tap_distance=0;world._tap(door_screen);world._tap(door_screen)
	await create_timer(.55).timeout
	check(front.opened,"Double tap opens police door")
	game.daily_report_pending=true;world._interact();check(front.opened and not front.busy,"Modal blocks police door interaction");game.daily_report_pending=false
	# Do not allow upper-floor movement through exterior walls or windows.
	for at in [station.point(0,5.76,25),station.point(24,5.76,25),station.point(12,5.76,28)]:check(not world._walkable(at),"Upper shell blocks falling outside "+str(at))
	var count:=0
	for n in station.find_children("*","MultiMeshInstance3D",true,false):count+=n.multimesh.instance_count
	FileAccess.open("res://../police_results.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures==0,"failures":failures,"checks":results,"station_instances":count,"station_batches":station.batches.size(),"doors":station.doors.size(),"room_count":station.rooms.size(),"ground_reachable_cells":lower.size(),"upper_reachable_cells":upper.size()},"\t"))
	print("POLICE_CHECKS ",results.size()," checks; ",failures," failures; instances ",count," batches ",station.batches.size())
	game.queue_free();await process_frame;quit(1 if failures else 0)
