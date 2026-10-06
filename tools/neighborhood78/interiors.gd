extends RefCounted
## Native procedural interiors. Walls are tessellated around scheduled apertures.
## All coordinates share the existing neighborhood; no travel screen or interior teleport.
var rounder = load("res://scripts/living_couch.gd").new()
var world: Node3D
var openings: Array[Dictionary] = []

func box(id: String, at: Vector3, size: Vector3, color: String, kind: int = 0, structural: bool = false) -> MeshInstance3D:
	var m: MeshInstance3D = world._interior_piece(id,at,size,color,kind)
	m.layers = 2
	m.set_meta("structural",structural)
	if id in ["SofaBase","SofaBack","SofaArm","SofaCushion","Mattress","Pillow","ToiletBase","ToiletTank","Basin"]:
		m.mesh = rounder._rounded(size,0.10)
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 4
		var shape := CollisionShape3D.new()
		var collision := BoxShape3D.new()
		collision.size = size
		shape.shape = collision
		body.add_child(shape)
		m.add_child(body)
	return m

# A wall in local (horizontal, height) coordinates minus rectangular openings.
func wall(id: String, start: Vector3, length: float, height: float, axis: Vector3, holes: Array, color: String = "d0c4ac", kind: int = 0) -> void:
	var xs: Array[float] = [0.0,length]
	var ys: Array[float] = [0.0,height]
	for h in holes:
		xs.append(h.position.x); xs.append(h.end.x)
		ys.append(h.position.y); ys.append(h.end.y)
		openings.append({"wall":id,"rect":[h.position.x,h.position.y,h.size.x,h.size.y]})
	xs.sort(); ys.sort()
	for i in range(xs.size()-1):
		for j in range(ys.size()-1):
			var w := xs[i+1]-xs[i]
			var h := ys[j+1]-ys[j]
			if w < 0.001 or h < 0.001: continue
			var mid := Vector2((xs[i]+xs[i+1])/2,(ys[j]+ys[j+1])/2)
			var cut := false
			for hole in holes:
				if hole.has_point(mid): cut = true
			if cut: continue
			box(id,start+axis*mid.x+Vector3.UP*mid.y,Vector3(w,h,0.22) if axis.x != 0 else Vector3(0.22,h,w),color,kind,true)
			if kind == 1:
				var inward := Vector3.FORWARD if id.ends_with("Front") else Vector3.BACK
				if id == "HouseSide": inward = Vector3.RIGHT if start.x < 35 else Vector3.LEFT
				if id == "ShopWest": inward = Vector3.RIGHT
				if id == "ShopEast": inward = Vector3.LEFT
				var lining := box(id+"Plaster",start+axis*mid.x+Vector3.UP*mid.y+inward*0.115,Vector3(w,h,0.015) if axis.x != 0 else Vector3(0.015,h,w),"c9c0a8")
				lining.set_meta("no_collision",true)

func glass(id: String, at: Vector3, width: float, height: float, axis: Vector3, fitted: bool = false) -> void:
	var pane_width := width-0.14 if fitted else width
	var pane_height := height-0.14 if fitted else height
	var size := Vector3(pane_width,pane_height,0.04) if axis.x != 0 else Vector3(0.04,pane_height,pane_width)
	var pane := box(id,at,size,"c2dedc",0,true)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.68,0.84,0.83,0.16)
	mat.roughness = 0.18
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	pane.material_override = mat
	var jamb_height := height-0.14 if fitted else height+0.1
	var rail_width := width if fitted else width+0.1
	var jamb_offset := (width-0.07)/2 if fitted else width/2
	var rail_offset := (height-0.07)/2 if fitted else height/2
	for side in [-1.0,1.0]:
		box(id+"Jamb",at+axis*side*jamb_offset,Vector3(0.07,jamb_height,0.24) if axis.x != 0 else Vector3(0.24,jamb_height,0.07),"3c493e")
		box(id+"Rail",at+Vector3.UP*side*rail_offset,Vector3(rail_width,0.07,0.24) if axis.x != 0 else Vector3(0.24,0.07,rail_width),"3c493e")

func covering_box(id: String, at: Vector3, width: float, height: float, depth: float, axis: Vector3, color: String) -> void:
	var size := Vector3(width,height,depth) if axis.x != 0 else Vector3(depth,height,width)
	box(id,at,size,color).set_meta("no_collision",true)

func closed_covering(id: String, at: Vector3, width: float, height: float, axis: Vector3, inward: Vector3, blackout: bool = false) -> void:
	var center := at+inward*0.18
	# Opaque backing closes every gap; glass still supplies the window collision.
	covering_box(id+"Backing",center,width,height,0.018,axis,"535b4b" if blackout else "807969")
	covering_box(id+"Header",center+Vector3.UP*(height/2-0.04)+inward*0.025,width,0.08,0.07,axis,"c1b79e")
	if blackout:
		covering_box(id+"Hem",center-Vector3.UP*(height/2-0.025)+inward*0.012,width,0.05,0.035,axis,"78816a")
	else:
		var rows := ceili(height/0.095)
		var pitch := height/rows
		for row in range(rows):
			covering_box(id+"Slat",center+Vector3.UP*(-height/2+(row+0.5)*pitch),width,pitch*0.96,0.025,axis,"b2a88e" if row%2==0 else "aaa087")
	var panels := maxi(1,ceili(width/2))
	for panel in range(panels):
		var offset := -width/2+(panel+1)*width/panels-0.09
		covering_box(id+"Cord",center+axis*offset+inward*0.055,0.018,height-0.12,0.018,axis,"d3c8af")

func door(id: String, center: Vector3, width: float, angle: float = 0.0, glazed: bool = false) -> void:
	var pivot: Node3D = load("res://scripts/interior_door.gd").new()
	pivot.name = id
	pivot.width = width
	pivot.host = world.host
	world.add_child(pivot)
	world.map_doors.append(pivot)
	pivot.position = center - Basis(Vector3.UP,angle)*Vector3(width/2,0,0)
	pivot.rotation.y = angle
	var leaf := Node3D.new()
	leaf.name = "Leaf"
	pivot.add_child(leaf)
	var before := world.get_children()
	if glazed:
		glass(id+"Glass",Vector3(width/2,1.3,0),width-0.12,2.48,Vector3.RIGHT)
	else:
		box(id+"Panel",Vector3(width/2,1.3,0),Vector3(width-0.035,2.6,0.10),"4e5f47",3)
		box(id+"Inset",Vector3(width/2,1.5,0.065),Vector3(width-0.3,1.65,0.04),"627256",3)
	box(id+"Handle",Vector3(width-0.18,1.05,0.13),Vector3(0.08,0.24,0.12),"c5b077")
	for child in world.get_children():
		if child not in before: child.reparent(leaf,false)
	var area := Area3D.new()
	area.collision_layer = 8
	area.collision_mask = 0
	area.set_meta("interaction_id","interior_door")
	area.set_meta("door_controller",pivot)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width,2.6,0.35)
	collision.shape = shape
	area.add_child(collision)
	area.position = Vector3(width/2,1.3,0)
	leaf.add_child(area)

func light(at: Vector3) -> void:
	box("CeilingLight",at,Vector3(1.2,0.07,0.35),"e7dfc1")
	var lamp := OmniLight3D.new()
	world.add_child(lamp)
	lamp.position = at-Vector3.UP*0.16
	lamp.light_color = Color("ffe9c7")
	lamp.light_energy = 0.85
	lamp.omni_range = 7.0
	lamp.light_cull_mask = 2
	lamp.shadow_enabled = false

func table(at: Vector3, size: Vector2, color: String = "87613e", height: float = 0.94) -> void:
	box("TableTop",at+Vector3.UP*(height-0.06),Vector3(size.x,0.12,size.y),color,3)
	for x in [-1.0,1.0]:
		for z in [-1.0,1.0]:
			box("TableLeg",at+Vector3(x*(size.x/2-0.1),(height-0.12)/2,z*(size.y/2-0.1)),Vector3(0.12,height-0.12,0.12),"343d36")

func shelf(at: Vector3, width: float, depth: float, stocked: bool = true) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 4
	body.position = at+Vector3.UP*0.95
	var shape := CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = Vector3(width,1.9,depth)
	shape.shape = volume
	body.add_child(shape)
	world.add_child(body)
	for x in [-1.0,1.0]:
		for z in [-1.0,1.0]:
			box("ShelfUpright",at+Vector3(x*(width/2-0.04),0.95,z*(depth/2-0.04)),Vector3(0.08,1.9,0.08),"454d46")
	for level in range(4):
		var y := 0.12+level*0.46
		box("ShelfBoard",at+Vector3(0,y,0),Vector3(width,0.07,depth),"b4a281",3)
		if stocked:
			for j in range(int(width/0.3)):
				for k in range(maxi(1,int(depth/0.4))):
					var colors := ["b36f43","718555","dfc278","6e9591","cba284"]
					var pos := at+Vector3(-width/2+0.18+j*0.3,y+0.18,-depth/2+0.18+k*0.4)
					var m := box("Merchandise",pos,Vector3(0.22,0.29,0.26),colors[(j+k+level)%5])
					m.set_meta("no_collision",true)
					box("ProductLabel",pos+Vector3(0,0,0.132),Vector3(0.14,0.1,0.005),"e2d6b6").set_meta("no_collision",true)

func cylinder(id: String, at: Vector3, radius: float, height: float, color: String) -> void:
	var m := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius*0.9
	mesh.height = height
	mesh.radial_segments = 16
	m.mesh = mesh
	m.name = id
	m.position = at
	m.layers = 2
	m.material_override = world._surface(0,color)
	world.add_child(m)

func build(owner_node: Node3D) -> void:
	world = owner_node
	shop()
	house()
	world.set_meta("interior_openings",openings)
	rounder.free()

func shop() -> void:
	world.building_bounds.append(AABB(Vector3(12,0,-2),Vector3(10,3.6,8)))
	box("ShopFloor",Vector3(17,-0.075,2),Vector3(10,0.15,8),"b1a58c",2,true)
	box("ShopCeiling",Vector3(17,3.55,2),Vector3(10.2,0.2,8.2),"d0c6ae",0,true)
	wall("ShopWest",Vector3(12,0,-2),8,3.5,Vector3.BACK,[],"925c42",1)
	wall("ShopEast",Vector3(22,0,-2),8,3.5,Vector3.BACK,[],"925c42",1)
	wall("ShopRear",Vector3(12,0,-2),10,3.5,Vector3.RIGHT,[],"925c42",1)
	wall("ShopFront",Vector3(12,0,6),10,3.5,Vector3.RIGHT,[Rect2(0.35,0.45,6.7,2.3),Rect2(7.7,0,1.7,2.65)],"925c42",1)
	glass("ShopDisplay",Vector3(15.7,1.6,6),6.7,2.3,Vector3.RIGHT)
	for x in [14.0,16.0,18.0]: box("DisplayMullion",Vector3(x,1.6,6),Vector3(0.07,2.3,0.25),"3c493e")
	door("ShopEntrance",Vector3(20.55,0,6),1.7,0,true)
	box("ShopAwning",Vector3(17,2.95,6.6),Vector3(10.3,0.18,1.2),"315e4c",3)
	world._label("CENTRAL MARKET",Vector3(17,3.3,6.18),0.008)
	# Stockroom is fully enclosed, entered behind checkout through its own door.
	wall("StockroomEast",Vector3(15.25,0,-2),3.1,3.5,Vector3.BACK,[])
	wall("StockroomFront",Vector3(12,0,1.1),3.25,3.5,Vector3.RIGHT,[Rect2(1.6,0,1.35,2.65)])
	door("StockroomDoor",Vector3(14.275,0,1.1),1.35)
	shelf(Vector3(12.65,0,-0.4),0.75,2.0)
	shelf(Vector3(14.2,0,-1.55),1.6,0.55)
	box("Checkout",Vector3(14.0,0.5,3.0),Vector3(3.0,1,0.75),"765b41",3)
	box("CounterTop",Vector3(14.0,1.04,3.0),Vector3(3.15,0.08,0.9),"3b423b")
	box("Register",Vector3(14.6,1.21,3),Vector3(0.45,0.26,0.36),"252c29")
	box("RegisterScreen",Vector3(14.6,1.48,2.97),Vector3(0.42,0.28,0.07),"73958a")
	for x in [16.6,18.8]: shelf(Vector3(x,0,2.1),0.8,2.3)
	for x in [17.0,18.6,20.2]:
		box("CoolerBack",Vector3(x,1.15,-1.7),Vector3(1.5,2.3,0.25),"343e39")
		shelf(Vector3(x,0,-1.1),1.4,0.8)
		glass("CoolerGlass",Vector3(x,1.13,-0.63),1.42,2.15,Vector3.RIGHT)
		box("CoolerHandle",Vector3(x+0.5,1.15,-0.54),Vector3(0.05,0.45,0.08),"bcc3b1")
	table(Vector3(21.35,0,2.0),Vector2(0.85,1.6))
	box("CoffeeMachine",Vector3(21.3,1.25,1.8),Vector3(0.55,0.62,0.5),"353e36")
	for z in [2.35,2.6]: cylinder("CupStack",Vector3(21.3,1.08,z),0.065,0.28,"d6c9ab")
	box("WelcomeMat",Vector3(20.5,0.008,4.9),Vector3(1.6,0.015,0.8),"536047")
	for at in [Vector3(13.6,3.4,-0.5),Vector3(17.2,3.4,1.6),Vector3(19.7,3.4,4.1)]: light(at)

func house() -> void:
	world.building_bounds.append(AABB(Vector3(25,0,-14),Vector3(20,3.5,17)))
	box("HouseFloor",Vector3(35,-0.075,-5.5),Vector3(20,0.15,17),"957047",3,true)
	box("HouseCeiling",Vector3(35,3.45,-5.5),Vector3(20.2,0.18,17.2),"d1c6ac",0,true)
	wall("HouseFront",Vector3(25,0,3),20,3.5,Vector3.RIGHT,[Rect2(1.3,0.85,5.8,1.9),Rect2(9.1,0,1.8,2.65),Rect2(12.9,0.85,5.8,1.9)],"986848",1)
	for x in [29.2,40.8]: glass("HouseFrontWindow",Vector3(x,1.8,3),5.8,1.9,Vector3.RIGHT)
	door("HouseEntrance",Vector3(35,0,3),1.8)
	for x in [25.0,45.0]:
		wall("HouseSide",Vector3(x,0,-14),17,3.5,Vector3.BACK,[Rect2(2,0.9,2.6,1.8),Rect2(11.5,0.9,2.6,1.8)],"986848",1)
		for z in [-10.7,-1.2]: glass("HouseSideWindow",Vector3(x,1.8,z),2.6,1.8,Vector3.BACK)
	wall("HouseRear",Vector3(25,0,-14),20,3.5,Vector3.RIGHT,[Rect2(1.7,0.9,2.5,1.8),Rect2(7,1.5,1.1,1.0),Rect2(10,0.9,2.3,1.8),Rect2(15,0.9,2.5,1.8)],"986848",1)
	for a in [Vector3(27.95,1.8,2.5),Vector3(36.15,1.8,2.3),Vector3(41.25,1.8,2.5)]: glass("HouseRearWindow",Vector3(a.x,a.y,-14),a.z,1.8,Vector3.RIGHT)
	glass("BathroomWindow",Vector3(32.55,2,-14),1.1,1.0,Vector3.RIGHT,true)
	closed_covering("PackingFrontBlind",Vector3(40.8,1.8,3),5.8,1.9,Vector3.RIGHT,Vector3.FORWARD)
	closed_covering("PackingSideBlind",Vector3(45,1.8,-1.2),2.6,1.8,Vector3.BACK,Vector3.LEFT)
	closed_covering("GrowSideShade",Vector3(45,1.8,-10.7),2.6,1.8,Vector3.BACK,Vector3.LEFT,true)
	closed_covering("GrowRearShade",Vector3(41.25,1.8,-14),2.5,1.8,Vector3.RIGHT,Vector3.BACK,true)
	# Central hall x33.5..36.5, front to transverse hall z-5..-7.
	for x in [33.5,36.5]: wall("HallSide",Vector3(x,0,-5),8,3.5,Vector3.BACK,[Rect2(4.2,0,1.5,2.65)])
	wall("FrontRoomDividerL",Vector3(25,0,-5),8.5,3.5,Vector3.RIGHT,[])
	wall("FrontRoomDividerR",Vector3(36.5,0,-5),8.5,3.5,Vector3.RIGHT,[])
	# Rear rooms each open onto the cross hall, never into another room.
	wall("RearHall",Vector3(25,0,-7),20,3.5,Vector3.RIGHT,[Rect2(3,0,1.5,2.65),Rect2(7,0,1.3,2.65),Rect2(10.8,0,1.4,2.65),Rect2(15.3,0,1.6,2.65)])
	for x in [31.3,34.2,38.6]: wall("RearPartition",Vector3(x,0,-14),7,3.5,Vector3.BACK,[])
	door("BathroomDoor",Vector3(32.65,0,-7),1.3)
	door("BedroomDoor",Vector3(36.5,0,-7),1.4)
	# Living room: seating faces the TV across a low coffee table.
	box("LivingRug",Vector3(29.3,0.012,-0.7),Vector3(5.5,0.02,4),"9c9270")
	box("SofaBase",Vector3(29.2,0.35,-3.6),Vector3(3.5,0.7,1),"616b49")
	box("SofaBack",Vector3(29.2,0.9,-4),Vector3(3.5,0.8,0.25),"566344")
	for x in [27.6,30.8]: box("SofaArm",Vector3(x,0.7,-3.55),Vector3(0.28,0.65,1.1),"566344")
	for x in [28.3,29.2,30.1]: box("SofaCushion",Vector3(x,0.76,-3.5),Vector3(0.82,0.16,0.7),"76805b")
	table(Vector3(29.2,0,-1.4),Vector2(2,0.9),"87613e",0.5)
	box("TVConsole",Vector3(29.2,0.35,2.2),Vector3(2.8,0.7,0.5),"4b4938",3)
	box("TV",Vector3(29.2,1.25,2.2),Vector3(2.1,1.05,0.12),"242e2a")
	# Kitchen: rear counter, side cabinets, dining table with chairs.
	box("KitchenTile",Vector3(28.15,0.012,-10.5),Vector3(6.1,0.02,6.8),"827f6b",2)
	box("KitchenCabinets",Vector3(28.5,0.46,-13.35),Vector3(4.8,0.92,0.85),"5d6350",3)
	box("KitchenWorktop",Vector3(28.5,0.97,-13.35),Vector3(4.9,0.1,0.92),"aaa58d")
	box("SinkRim",Vector3(27.8,1.035,-13.3),Vector3(0.85,0.04,0.6),"9da99f")
	box("SinkBasin",Vector3(27.8,1.06,-13.3),Vector3(0.65,0.025,0.43),"4a5954")
	box("Faucet",Vector3(27.8,1.25,-13.55),Vector3(0.06,0.4,0.06),"aeb7a4")
	box("Cooktop",Vector3(29.8,1.03,-13.3),Vector3(0.8,0.04,0.6),"292f29")
	for x in [29.6,30.0]:
		for z in [-13.5,-13.1]: box("Burner",Vector3(x,1.06,z),Vector3(0.19,0.02,0.19),"747c71")
	box("Fridge",Vector3(25.8,1.05,-12),Vector3(1.05,2.1,1),"9b9f8d")
	table(Vector3(28.3,0,-9.4),Vector2(2,1.2))
	for x in [27.7,28.9]:
		for z in [-10.5,-8.3]:
			box("ChairSeat",Vector3(x,0.47,z),Vector3(0.5,0.12,0.5),"687150")
			box("ChairBase",Vector3(x,0.2,z),Vector3(0.32,0.4,0.32),"4a513c")
	for x in [26.5,27.3,28.1,28.9,29.7,30.5]:
		box("CabinetDoor",Vector3(x,0.48,-12.91),Vector3(0.72,0.77,0.04),"6f765c",3)
		box("CabinetHandle",Vector3(x+0.22,0.62,-12.86),Vector3(0.045,0.2,0.045),"bec2a8")
	box("FridgeSeam",Vector3(25.8,1.45,-11.49),Vector3(1.0,0.04,0.015),"596556")
	box("FridgeHandle",Vector3(26.15,1.0,-11.43),Vector3(0.06,0.5,0.07),"d3d1ba")
	# Bathroom, separated by full-height walls.
	box("BathroomTile",Vector3(32.75,0.014,-10.5),Vector3(2.65,0.025,6.8),"7f9087",2)
	box("ShowerTray",Vector3(32.7,0.1,-12.9),Vector3(2.3,0.2,1.7),"c4c9b8")
	glass("ShowerScreen",Vector3(32.1,1.25,-12),1.1,2.3,Vector3.RIGHT)
	box("ToiletBase",Vector3(33.35,0.3,-10.5),Vector3(0.55,0.6,0.75),"dfdfcd")
	box("ToiletTank",Vector3(33.4,0.8,-10.85),Vector3(0.6,0.65,0.2),"dfdfcd")
	box("Vanity",Vector3(31.85,0.44,-9.1),Vector3(0.8,0.88,1.1),"777559",3)
	box("Basin",Vector3(31.85,0.95,-9.1),Vector3(0.82,0.14,1.05),"d6dbcb")
	box("ToiletSeat",Vector3(33.35,0.63,-10.4),Vector3(0.55,0.06,0.58),"bfc8b5")
	box("ToiletBowl",Vector3(33.35,0.666,-10.4),Vector3(0.34,0.012,0.38),"66746a")
	box("VanityBasin",Vector3(31.85,1.024,-9.1),Vector3(0.53,0.014,0.68),"697c74")
	box("VanityMirror",Vector3(31.43,1.75,-9.1),Vector3(0.04,0.95,0.85),"a5c3be")
	# Bedroom.
	box("BedFrame",Vector3(36.5,0.3,-11.4),Vector3(2.1,0.6,3.2),"65533c",3)
	box("Mattress",Vector3(36.5,0.69,-11.4),Vector3(2,0.25,3.1),"d6cfb7")
	box("Blanket",Vector3(36.5,0.85,-10.9),Vector3(2.02,0.12,2.0),"788158")
	box("Pillow",Vector3(36.5,0.87,-12.55),Vector3(1.5,0.18,0.55),"ece0c6")
	box("Wardrobe",Vector3(34.85,1,-8.6),Vector3(0.85,2,1.2),"675b43",3)
	# Grow room preview equipment: no duplicate simulation plants or free inventory.
	box("GrowTile",Vector3(41.8,0.012,-10.5),Vector3(6.2,0.02,6.8),"6c7468",2)
	for x in [40.0,42.0,44.0]:
		box("GrowTentBack",Vector3(x,1.35,-13.4),Vector3(1.7,2.7,0.14),"293330")
		for dx in [-0.8,0.8]: box("GrowTentSide",Vector3(x+dx,1.35,-12.6),Vector3(0.1,2.7,1.6),"333d36")
		box("GrowTentTop",Vector3(x,2.67,-12.6),Vector3(1.7,0.12,1.7),"28312b")
		box("GrowTray",Vector3(x,0.08,-12.6),Vector3(1.7,0.16,1.7),"333f35")
		box("GrowLight",Vector3(x,2.45,-12.6),Vector3(1.2,0.08,0.8),"e5dba8")
		for dx in [-0.4,0.4]: cylinder("EmptyPlanter",Vector3(x+dx,0.36,-12.6),0.275,0.4,"756047")
	shelf(Vector3(44.25,0,-9.1),0.7,1.6,false)
	# Packing room: bench, scale, jars, cabinets and storage shelves.
	box("PackingTile",Vector3(40.8,0.012,-1),Vector3(8.1,0.02,7.7),"77796a",2)
	table(Vector3(41.2,0,-4.2),Vector2(4.5,1.1))
	box("PackingScale",Vector3(40.5,1.04,-4.2),Vector3(0.65,0.2,0.5),"b1b8a0")
	box("ScaleDisplay",Vector3(40.5,1.15,-3.94),Vector3(0.28,0.09,0.02),"75a87c")
	for x in [41.3,41.8,42.3]: cylinder("PackingJar",Vector3(x,1.15,-4.2),0.14,0.42,"839878")
	shelf(Vector3(44.35,0,-1.2),0.8,2.5,false)
	box("PackingCabinet",Vector3(38,1,-4.25),Vector3(1.15,2,0.9),"444f43")
	for at in [Vector3(29.2,3.32,-1),Vector3(35,3.32,0),Vector3(41,3.32,-1),Vector3(28,3.32,-10.5),Vector3(32.7,3.32,-10.5),Vector3(36.5,3.32,-10.5),Vector3(41.8,3.32,-10.5),Vector3(35,3.32,-6)]: light(at)

