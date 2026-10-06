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
			if not region.has_point(p) or not n._walkable(Vector3(p.x,1.64,p.y)): continue
			seen[next]=true
			queue.append(next)
	return false
func run() -> void:
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
	n=game.neighborhood
	n._arrive_outside()
	refresh()
	check(n.map_doors.size()==5,"Five prototype doors present")
	check(not n._walkable(Vector3(35,1.64,3)),"Closed house entrance blocks walking")
	check(not n._walkable(Vector3(20.55,1.64,6)),"Closed glazed shop door blocks walking")
	for pos in [Vector3(29.2,1.64,3),Vector3(25,1.64,-1.2),Vector3(15.7,1.64,6)]:
		check(not n._walkable(pos),"Glass remains collidable: "+str(pos))
	game.camera.position=Vector3(35,1.64,5)
	game.camera.look_at(Vector3(35,1.64,3))
	game.property_offer_unlocked=false
	n._interact()
	check(not n.get_node("HouseEntrance").busy,"House remains locked until existing Rod offer")
	game.property_offer_unlocked=true
	n._interact()
	await create_timer(0.5).timeout
	refresh()
	check(n.get_node("HouseEntrance").opened,"House opens after Rod offer")
	check(n._walkable(Vector3(35,1.64,3)),"Open house entrance is clear")
	for name in ["BathroomDoor","BedroomDoor","ShopEntrance","StockroomDoor"]:
		var door: Node3D = n.get_node(NodePath(name))
		door.toggle(Vector3(door.position.x+door.width/2,1.64,door.position.z+2))
		await create_timer(0.5).timeout
		check(door.opened,"Door opens: "+name)
	refresh()
	var house := Rect2(24,-15,22,23)
	for destination in [Vector2(31,0),Vector2(41,0),Vector2(30,-9),Vector2(32.7,-8.4),Vector2(36.5,-8.7),Vector2(41.2,-9)]:
		check(path(Vector2(35,5),destination,house),"House round-trip route: "+str(destination))
	var shop := Rect2(11,-3,12,12)
	for destination in [Vector2(20.5,3),Vector2(17.7,2),Vector2(14.2,0),Vector2(19.4,-0.1),Vector2(20.5,2)]:
		check(path(Vector2(20.55,8),destination,shop),"Shop round-trip route: "+str(destination))
	var shop_door: Node3D = n.get_node("ShopEntrance")
	shop_door.toggle(shop_door.position+Vector3(shop_door.width/2,1.64,-0.3))
	check(not shop_door.busy and shop_door.opened,"Closing refuses full swing when player occupies it")
	shop_door.toggle(Vector3(20.55,1.64,8))
	await create_timer(0.5).timeout
	refresh()
	check(not shop_door.opened and not n._walkable(Vector3(20.55,1.64,6)),"Closing shop door restores collision")
	game.camera.position=Vector3(20.55,1.64,8)
	game.camera.look_at(Vector3(20.55,1.3,6))
	var point: Vector2 = game.camera.unproject_position(Vector3(20.55,1.3,6))
	n.tap_distance=0
	n._tap(point)
	check(not shop_door.busy,"First door tap only targets")
	n._tap(point)
	await create_timer(0.5).timeout
	check(shop_door.opened,"Double tap opens nearby market door")
	n.tap_distance=50
	n._tap(point)
	n._tap(point)
	check(not shop_door.busy,"Look swipes never operate doors")
	if OS.get_cmdline_user_args().has("--capture"):
		root.size=Vector2i(1280,800)
		for shot in [{"id":"market","pos":Vector3(21,1.64,4.3),"look":Vector3(17.5,1.35,2)},{"id":"house","pos":Vector3(31.5,1.64,1),"look":Vector3(28.5,1.3,-3)},{"id":"block","pos":Vector3(10,12,24),"look":Vector3(27,0,-3)}]:
			game.camera.position=shot.pos
			game.camera.look_at(shot.look)
			for i in range(6): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/workspace/scratch/05254e9fc6fb/review/map76-"+shot.id+".png")
	print("Map .76 checks: ",failures," failures; doors, progression gate, glass collisions, room paths, double tap and swipe guard")
	quit(1 if failures else 0)
