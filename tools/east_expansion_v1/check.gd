extends SceneTree
var game:Node3D
var w:Node3D
var failures:=0
var results:Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String,data:Variant=null) -> void:
	results.append({"check":label,"passed":ok,"data":data})
	if not ok:failures+=1;push_error(label+": "+str(data))
func route(from:Vector2,to:Vector2) -> bool:
	var step:=.5
	var start:=Vector2i(roundi(from.x/step),roundi(from.y/step))
	var target:=Vector2i(roundi(to.x/step),roundi(to.y/step))
	var queue:Array[Vector2i]=[start];var seen:Dictionary={start:true};var i:=0
	while i<queue.size():
		var cell:=queue[i];i+=1
		if cell==target:return true
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next:Vector2i=cell+offset
			if seen.has(next):continue
			var at:=Vector2(next)*step
			if at.x<48 or at.x>136 or at.y< -35 or at.y>38:continue
			if not w._walkable(Vector3(at.x,2.16,at.y)):continue
			seen[next]=true;queue.append(next)
	return false
func run() -> void:
	assert(OS.get_user_data_dir().contains("AFB Character Fit Validation"))
	if DisplayServer.get_name()=="headless":
		push_error("Use the graphics renderer: headless dummy rendering cannot read back MultiMesh transforms.");quit(2);return
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	w=game.neighborhood;game.set_process(false);w.set_process(false)
	for timer in game.find_children("*","Timer",true,false):timer.stop()
	w.map_obstacles.clear();w._collect_map_colliders(w)
	var core:Array[String]=[];var instance_count:=0;var batch_count:=0
	for node in w.find_children("*","MultiMeshInstance3D",true,false):
		batch_count+=1;instance_count+=node.multimesh.instance_count
		for i in range(node.multimesh.instance_count):
			var t:Transform3D=node.multimesh.get_instance_transform(i)
			if t.origin.x<48:core.append(str(node.multimesh.mesh.get_class())+":"+str(t))
	core.sort()
	var core_hash:=JSON.stringify(core).sha256_text()
	var snapshot={"core_geometry_sha256":core_hash,"core_instances":core.size(),"static_instances":instance_count,"batches":batch_count,"buildings":w.building_bounds.size()}
	if not w.has_meta("east_landmarks"):
		FileAccess.open("res://../baseline_geometry.json",FileAccess.WRITE).store_string(JSON.stringify(snapshot,"\t"))
		print("BASELINE_GEOMETRY ",JSON.stringify(snapshot));quit();return
	var baseline:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../baseline_geometry.json"))
	check(core_hash==baseline.core_geometry_sha256,"Original hub exterior geometry unchanged",snapshot)
	check(w.building_bounds.size()==int(baseline.buildings)+17,"Nineteen residential exteriors replace two old edge buildings")
	check(batch_count<=int(baseline.batches)+18,"Expansion reuses batched geometry/materials",{"before":baseline.batches,"after":batch_count})
	check(instance_count<int(baseline.static_instances)*2.2,"Bounded static-instance growth",{"before":baseline.static_instances,"after":instance_count})
	check(w.map_doors.size()==5,"All original interactive doors retained")
	for z in [-19.0,8.5,17.0,24.0]:
		for x in [72.0,73.0,74.0,78.8,79.2]:check(w._walkable(Vector3(x,2.16,z)),"Open east connection "+str(Vector2(x,z)))
	for at in [Vector2(81.5,9),Vector2(91,9),Vector2(100,9),Vector2(125.5,-1.5),Vector2(125.5,-15.5),Vector2(115.5,-1.5),Vector2(111,-28),Vector2(111,30),Vector2(122,24),Vector2(131,-22.5),Vector2(88,-16.5)]:check(route(Vector2(65,17),at),"Walk from hub to "+str(at))
	for z in range(-14,9):check(w._walkable(Vector3(125.5,2.16,z)),"Park central path remains clear "+str(z))
	for at in [Vector3(137.1,2.16,17),Vector3(120,2.16,39.1),Vector3(120,2.16,-36.1)]:check(not w._walkable(at),"Visible perimeter blocks escape "+str(at))
	for bounds in w.building_bounds:
		if bounds.position.x>=78:check(not w._walkable(bounds.get_center()),"New building collision "+str(bounds.position))
	for feature in w.get_meta("east_landmarks"):
		if feature.kind=="bench":check(absf(feature.seat_top-.46821849)<.001,"Park bench at fitted seat height")
		if feature.kind=="garage":check(not w._walkable(feature.at+Vector3.UP*2.16),"Rear garage collision")
	var window_count:=0;var upper_count:=0
	for window in w.window_layout_records:
		window_count+=1
		# Full frame +/-0.675; the sill extends 0.77 below the center.
		check(window.at.y-.77>window.floor+.5 and window.at.y+.675<window.ceiling-.25,"Window stays inside story "+str(window_count),{"building":window.building,"floor":window.floor,"center":window.at.y,"ceiling":window.ceiling})
		if window.row>0 or window.building=="ApartmentUpper":upper_count+=1
	check(upper_count>0,"Upper-story windows audited",upper_count)
	var report={"passed":failures==0,"failures":failures,"checks":results,"geometry":snapshot,"upper_windows_checked":upper_count,"all_windows_checked":window_count}
	FileAccess.open("res://../east_results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("EAST_CHECKS ",results.size()," checks; ",failures," failures; upper windows=",upper_count," total windows=",window_count)
	game.queue_free();await process_frame;quit(1 if failures else 0)
