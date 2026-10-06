extends SceneTree
var game: Node3D
var n: Node3D
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func refresh() -> void:
	n.map_obstacles.clear()
	n._collect_map_colliders(n)
func path(start: Vector2, finish: Vector2, region: Rect2) -> bool:
	var step := 0.2
	var origin := region.position
	var first := Vector2i(roundi((start.x-origin.x)/step),roundi((start.y-origin.y)/step))
	var last := Vector2i(roundi((finish.x-origin.x)/step),roundi((finish.y-origin.y)/step))
	var queue: Array[Vector2i] = [first]
	var seen := {first:true}
	var cursor := 0
	while cursor<queue.size():
		var cell := queue[cursor]
		cursor+=1
		if cell==last: return true
		for offset in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var next: Vector2i = cell+offset
			if seen.has(next): continue
			var p := origin+Vector2(next)*step
			if not region.has_point(p) or not n._walkable(Vector3(p.x,2.16,p.y)): continue
			seen[next]=true
			queue.append(next)
	return false
func run() -> void:
	assert(OS.get_user_data_dir().contains("AFB Character Fit Validation"))
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.session_paused=false
	game.tutorial_active=false
	game.daily_report_pending=false
	game.customer_waiting=false
	for name in ["tutorial_panel","daily_report_panel","pause_overlay","sale_panel","grow_panel","plant_direct_panel","bagging_panel","storage_panel","dealer_storage_panel","supply_inventory_panel","system_control_panel","trim_panel","bag_minigame_panel","peephole_panel"]:
		var panel=game.get(name)
		if panel != null: panel.hide()
	game.set_process(false)
	n=game.neighborhood
	n.set_process(false)
	n._arrive_outside()
	refresh()
	check(n.map_doors.size()==5,"Five prototype doors present")
	check(not n._walkable(Vector3(35,2.16,3)),"Closed house entrance blocks walking")
	check(not n._walkable(Vector3(20.55,2.16,6)),"Closed glazed shop door blocks walking")
	for pos in [Vector3(29.2,2.16,3),Vector3(25,2.16,-1.2),Vector3(15.7,2.16,6)]:
		check(not n._walkable(pos),"Glass remains collidable: "+str(pos))
	game.camera.position=Vector3(35,2.16,5)
	game.camera.look_at(Vector3(35,2.16,3))
	game.property_offer_unlocked=false
	n._interact()
	check(not n.get_node("HouseEntrance").busy,"House remains locked until existing Rod offer")
	game.property_offer_unlocked=true
	n._interact()
	check(n.property_opportunity.is_open(),"House opens property details before tour")
	n.property_opportunity.begin_tour()
	await create_timer(0.5).timeout
	refresh()
	check(n.get_node("HouseEntrance").opened,"House opens after Rod offer")
	check(n._walkable(Vector3(35,2.16,3)),"Open house entrance is clear")
	for name in ["BathroomDoor","BedroomDoor","ShopEntrance","StockroomDoor"]:
		var door: Node3D = n.get_node(NodePath(name))
		door.toggle(Vector3(door.position.x+door.width/2,2.16,door.position.z+2))
		await create_timer(0.5).timeout
		check(door.opened,"Door opens: "+name)
	refresh()
	var house := Rect2(24,-15,22,23)
	for destination in [Vector2(31,0),Vector2(41,0),Vector2(30,-9),Vector2(32.7,-8.4),Vector2(36.5,-8.7),Vector2(41.2,-9)]:
		check(path(Vector2(35,5),destination,house),"House round-trip route: "+str(destination))
	var shop := Rect2(11,-3,12,12)
	for destination in [Vector2(20.5,3),Vector2(17.7,2),Vector2(14.2,0),Vector2(19.4,-0.1),Vector2(20.5,2)]:
		check(path(Vector2(20.55,8),destination,shop),"Shop round-trip route: "+str(destination))
	print("Character-fit room-route checks: ",failures," failures; doors, progression gate, glass collisions, room paths")
	quit(1 if failures else 0)
