extends RefCounted
## Apply the approved FurnitureFit_v1 dimensions to existing named game nodes.
## Idempotent: upgrades can call this again without cumulative scaling or offsets.
const Policy=preload("res://scripts/scale_policy.gd")

static func mesh(host: Node, id: String) -> MeshInstance3D:
	return host.get_node_or_null(id) as MeshInstance3D
static func bounds(ob: MeshInstance3D) -> AABB:
	return ob.transform*ob.get_aabb()
static func y(host: Node, id: String, height: float) -> void:
	var ob:=mesh(host,id)
	if ob!=null:ob.position.y=height
static func box_y(host: Node, id: String, bottom: float, top: float) -> void:
	var ob:=mesh(host,id)
	if ob==null or not ob.mesh is BoxMesh:return
	ob.mesh=ob.mesh.duplicate()
	ob.mesh.size.y=top-bottom
	ob.position.y=(bottom+top)*.5
static func rest(host: Node, id: String, height: float) -> void:
	var ob:=mesh(host,id)
	if ob!=null:ob.position.y+=height-bounds(ob).position.y

static func apply_apartment(host: Node3D) -> void:
	var coffee:=mesh(host,"CoffeeTop")
	if coffee!=null:
		coffee.position=Vector3(-2.28,.3875,1.27)
		for id in ["CoffeeLegL","CoffeeLegR"]:
			var leg:=mesh(host,id)
			if leg!=null:
				leg.mesh=leg.mesh.duplicate();leg.mesh.height=.335
				leg.position.y=.1675;leg.position.z=.95
		for side in range(2):
			var id:="FittedCoffeeLeg%d"%side
			if not host.has_node(NodePath(id)):host._add_cylinder(id,Vector3(-2.91 if side==0 else -1.65,.1675,1.59),.035,.035,.335,Color("303538"),.44)
		var cup:=mesh(host,"CoffeeCup")
		if cup!=null:cup.position.z=1.15;rest(host,"CoffeeCup",.44)
	box_y(host,"KitchenBase",0,1.04)
	box_y(host,"KitchenToeKick",0,.16)
	for entry in [["KitchenCounter",1.10],["KitchenCounterLip",1.14],["SinkRim",1.155],["SinkBasin",1.165],["FaucetStem",1.41],["FaucetTop",1.64],["FaucetSpout",1.59],["FaucetControl",1.31]]:y(host,entry[0],entry[1])
	for i in range(3):y(host,"KitchenLowerDoor%d"%i,.56);y(host,"KitchenLowerHandle%d"%i,.85)
	box_y(host,"KitchenBacksplash",1.16,1.98)
	for id in ["BenchLeg_0_0","BenchLeg_0_1","BenchLeg_1_0","BenchLeg_1_1","BenchIIILowerCabinetL","BenchIIILowerCabinetR"]:box_y(host,id,0,1.04)
	for entry in [["BenchIIIUpperCabinet",2.63],["BenchIIIUpperLip",2.30],["BenchIIITaskLight",2.23],["BenchIIIWorldLabel",2.72]]:
		var ob:=host.get_node_or_null(NodePath(entry[0])) as Node3D
		if ob!=null:ob.position.y=entry[1]
	for pair in [["BenchJarGlass","BenchJarLid"],["BenchJarGlass2","BenchJarLid2"]]:
		var jar:=mesh(host,pair[0])
		if jar!=null:
			var delta:=1.16-bounds(jar).position.y
			jar.position.y+=delta
			var lid:=mesh(host,pair[1])
			if lid!=null:lid.position.y+=delta
	for id in ["BagStack","ToolCup"]:rest(host,id,1.16)
	var shelf_tops:Array[float]=[.3825,.94,1.50,2.05]
	for i in range(4):
		y(host,"Shelf%d"%i,shelf_tops[i]-.0425)
		y(host,"StorageExtraShelf%d"%i,shelf_tops[i]-.045)
	for pair in [["StorageBinA",0],["StorageBinB",0],["StorageJarA",1],["StorageJarB",1],["StorageBagA",2],["StorageBagB",2],["StorageCaseC",3],["StorageUpgradeBin",3]]:rest(host,pair[0],shelf_tops[pair[1]])
	for id in ["ShelfPostL","ShelfPostR"]:box_y(host,id,0,2.40)
	for id in ["StorageBack","StorageShelfBank2"]:box_y(host,id,0,2.48)
	# Only the unhinged direct children are adjusted; later upgrade calls leave doors alone.
	y(host,"Peephole",2.12)
	box_y(host,"Door",0,2.84)
	for id in ["DoorFrameL","DoorFrameR"]:box_y(host,id,0,2.93)
	if host.has_node("TVConsole"):
		for i in range(4):
			var id:="FittedConsoleFoot%d"%i
			if not host.has_node(NodePath(id)):host._add_box(id,Vector3(-3.96 if i<2 else -2.08,.045,-3.70 if i%2==0 else -3.34),Vector3(.08,.09,.08),Color("303538"))
		rest(host,"TVStand",.81)
	if host.has_node("FloorLampStem") and not host.has_node("FittedLampBase"):host._add_cylinder("FittedLampBase",Vector3(-3.78,.025,3.35),.22,.22,.05,Color("303538"))
	# Navigation uses live mesh bounds, refreshed after an upgrade or visibility change.
	if host.get("neighborhood")!=null:host.neighborhood.collision_timer=0.0
