extends SceneTree
var game: Node3D
var world: Node3D
var results:Array=[]
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, name: String, data: Variant=null) -> void:
	results.append({"check":name,"passed":ok,"data":data})
	if not ok:failures+=1;push_error(name+": "+str(data))
func bounds(n: MeshInstance3D) -> AABB:return n.global_transform*n.get_aabb()
func top(n: MeshInstance3D) -> float:return bounds(n).end.y
func bottom(n: MeshInstance3D) -> float:return bounds(n).position.y
func part(id: String) -> MeshInstance3D:
	for n in world.find_children("*","MeshInstance3D",true,false):
		if n.get_meta("fit_part","")==id:return n
	return null
func refresh() -> void:
	world.interior_obstacles.clear();world._collect_colliders(game)
	world.map_obstacles.clear();world._collect_map_colliders(world)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	world=game.neighborhood;game.set_process(false);world.set_process(false)
	game.session_paused=false;game.tutorial_active=false;game.daily_report_pending=false
	for timer in game.find_children("*","Timer",true,false):timer.stop()
	game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide()
	check(OS.get_user_data_dir().contains("AFB Character Fit Validation"),"Isolated validation save directory")
	var coffee:MeshInstance3D=game.get_node("CoffeeTop")
	check(absf(top(coffee)-.44)<.001,"Apartment coffee table at fitted height",top(coffee))
	check(absf(coffee.position.z-1.27)<.001,"Coffee table leaves shoe room",coffee.position.z)
	check(absf(bottom(game.get_node("CoffeeCup"))-top(coffee))<.001,"Cup supported by table")
	check(game.has_node("FittedCoffeeLeg0") and game.has_node("FittedCoffeeLeg1"),"Four coffee-table supports")
	check(absf(top(game.get_node("KitchenCounter"))-1.16)<.001,"Apartment kitchen worktop height")
	check(absf(top(game.get_node("KitchenBase"))-bottom(game.get_node("KitchenCounter")))<.001,"Counter rests on cabinet")
	check(absf(top(part("KitchenWorktop"))-1.16)<.001,"House kitchen worktop height")
	check(absf(top(part("CounterTop"))-1.16)<.001,"Market checkout height")
	check(absf(top(part("ChairSeat"))-.46821849)<.001,"Dining seat matches character leg reference")
	check(absf(top(part("ToiletSeat"))-.46821849)<.001,"Bathroom seat matches reference")
	check(absf(top(part("Fridge"))-2.4)<.001,"Fridge fits character height")
	check(absf(top(part("Mattress"))-.68)<.001,"Bed height adjusted without shortening mattress")
	var couch:Node3D=world.get_node("HouseFittedCouch")
	check(is_equal_approx(couch.SEAT_TOP,.46821849) and couch.scale==Vector3.ONE,"House uses fitted couch without scaling")
	check(game.get_node("AFBLoveseat").scale==Vector3.ONE,"Apartment couch unchanged")
	for level in [1,2,3,4,5,1]:
		game.storage_level=level;game.bagging_level=mini(level,3);game._apply_visual_upgrades()
		var p:Vector3=game.get_node("KitchenCounter").position
		var count:=game.get_child_count()
		game._apply_visual_upgrades()
		check(game.get_node("KitchenCounter").position==p and count==game.get_child_count(),"Repeated fit does not move or duplicate furniture at upgrade "+str(level))
		if level<4:
			check(absf(top(game.get_node("Shelf3"))-2.05)<.001,"Top shelf fit at level "+str(level))
			check(absf(bottom(game.get_node("StorageCaseC"))-top(game.get_node("Shelf3")))<.001,"Storage contents supported at level "+str(level))
		if level==3:
			check(absf(top(game.get_node("StorageExtraShelf3"))-2.05)<.001,"Expansion shelf follows fitted rack")
			check(absf(bottom(game.get_node("StorageUpgradeBin"))-2.05)<.001,"Upgrade bin rests on top shelf")
		if game.bagging_level==3:
			check(absf(bottom(game.get_node("BenchIIILowerCabinetL")))<.001 and absf(top(game.get_node("BenchIIIUpperCabinet"))-2.92)<.001,"Upgraded bench supports and overhead cabinet")
	game.storage_level=1;game.bagging_level=1;game._apply_visual_upgrades()
	refresh()
	check(world.map_doors.size()==5,"All five existing map doors retained")
	for door in world.map_doors:
		var header:MeshInstance3D=world.get_node(str(door.name)+"FixedHeader")
		check(bottom(header)>2.42+.35,str(door.name)+" head clearance",bottom(header)-2.42)
		check(door.width>.894+.3,str(door.name)+" broad-character width clearance",door.width-.894)
		var center:Vector3=door.to_global(Vector3(door.width/2,2.16,0))
		check(not world._walkable(center),str(door.name)+" closed leaf blocks walking")
		game.camera.position=door.to_global(Vector3(door.width/2,2.16,1.0))
		door.toggle(game.camera.position);await create_timer(.5).timeout
		refresh()
		check(door.opened and world._walkable(center),str(door.name)+" opens into a walkable doorway")
		for offset in [-.45,0.0,.45]:
			check(world._walkable(door.to_global(Vector3(door.width/2,2.16,offset))),str(door.name)+" clearance sample "+str(offset))
	# Open door tests leave the whole interior traversable. Verify key aisles/streets.
	for position in [Vector3(35,2.16,0),Vector3(35,2.16,-6),Vector3(32.65,2.16,-8),Vector3(36.5,2.16,-8),Vector3(20.55,2.16,4.4),Vector3(17.7,2.16,4.5),Vector3(18,2.16,-3.1),Vector3(8.5,2.16,10.5),Vector3(45.5,2.16,10.5),Vector3(35,2.16,10.5)]:
		check(world._walkable(position),"Walkable aisle "+str(position))
	for prop in world.fitted_prop_bounds:
		var a:AABB=prop.bounds
		if prop.kind=="car":
			check(a.size.y>1.85 and absf(a.position.y)<.002,"Car size and wheel grounding",{"size":str(a.size),"bottom":a.position.y})
			check(not world._walkable(prop.origin+Vector3.UP*2.16),"Enlarged car footprint blocks player",str(prop.origin))
			if absf(prop.origin.z+6.5)<.01:check(a.position.z> -10.3 and a.end.z< -2.0 and a.position.x>16 and a.end.x<20,"Rotated truck fits a parking bay",str(a))
		else:check(a.end.y>6.0 and absf(a.position.y)<.002,"Tree size and trunk grounding",str(a))
	# Any object at head level must block movement, not just objects below old eye height.
	var head_test:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(.5,.15,.5)
	head_test.mesh=box;world.add_child(head_test);head_test.position=Vector3(35,2.30,0)
	refresh();check(not world._walkable(Vector3(35,2.16,0)),"New head-level obstacle blocks walking")
	head_test.free();refresh();check(world._walkable(Vector3(35,2.16,0)),"Removing head obstacle restores path")
	game.camera.position=Vector3(-1.8,2.16,1.9);world._toggle_couch()
	check(world.couch_seated and absf(game.camera.position.y-1.562837)<.001,"Couch camera matches shared-rig seated eye height")
	world._toggle_couch();check(not world.couch_seated and is_equal_approx(game.camera.position.y,2.16),"Couch stand restores walking eye height")
	var file:=FileAccess.open("res://../fit_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures==0,"failures":failures,"checks":results},"\t"));file.close()
	print("CHARACTER_FIT_CHECKS ",results.size()," checks; ",failures," failures")
	game.queue_free();await process_frame;quit(1 if failures else 0)
