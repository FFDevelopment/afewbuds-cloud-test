extends RefCounted
## An additive outdoor district, east of the original x=73 boundary.
## Existing hub, buildings and interiors are owned by neighborhood.gd unchanged.
const EAST_LIMIT:=137.0
const PARK:=Rect2(118,-14,16,20)
const TREE_BED_SIZE:=1.5
# One list drives trunks, soil and the holes cut in all paving/grass surfaces.
# First four sites retain the approved hub tree locations.
const TREE_SITES:=[Vector3(-7,0,10.5),Vector3(10,0,10.5),Vector3(24.5,0,10.5),Vector3(46.75,0,10.5),Vector3(62,0,10.5),Vector3(72,0,10.5),Vector3(82,0,10.5),Vector3(92,0,10.5),Vector3(100,0,10.5),Vector3(67,0,24),Vector3(87,0,24),Vector3(126,0,24),Vector3(120.2,0,-11),Vector3(131.5,0,-11),Vector3(120.3,0,3.5),Vector3(131.3,0,3.5)]
var w:Node3D
var landmarks:Array[Dictionary]=[]

static func plant(world:Node3D,at:Vector3) -> void:
	# Soil top and trunk bottom meet at y=0.
	world._box(at+Vector3(0,-.025,0),Vector3(TREE_BED_SIZE,.05,TREE_BED_SIZE),"4c4737",5)
	world.tree(at)

func slab(id:String, x0:float, x1:float, z0:float, z1:float, y:float, depth:float, color:String, surface:int) -> void:
	w.piece(id,Vector3((x0+x1)/2,y,(z0+z1)/2),Vector3(x1-x0,depth,z1-z0),color,surface)

func walk(x0:float,x1:float,z0:float,z1:float) -> void:
	slab("EastPaving",x0,x1,z0,z1,-.10,.18,"a9a394",2)

func curb(x0:float,x1:float,z0:float,z1:float) -> void:
	slab("EastCurb",x0,x1,z0,z1,.025,.12,"c8c4b9",0)

func bench(at:Vector3, facing:float) -> void:
	var basis:=Basis(Vector3.UP,facing)
	for x in [-.82,.82]:
		for z in [-.20,.20]:
			w._box(at+basis*Vector3(x,.199,z),Vector3(.085,.398,.085),"343c36")
	var seat:=Transform3D(basis,Vector3.ZERO)*AABB(Vector3(-1.1,-.035,-.31),Vector3(2.2,.07,.62))
	var back:=Transform3D(basis,Vector3.ZERO)*AABB(Vector3(-1.1,-.33,-.0375),Vector3(2.2,.66,.075))
	w._box(at+Vector3(0,.433,0),seat.size,"a88a5f",6)
	w._box(at+basis*Vector3(0,.82,.28),back.size,"a88a5f",6)
	var footprint:=AABB(Vector3(-1.1,0,-.34),Vector3(2.2,1.2,.68))
	footprint=Transform3D(basis,at)*footprint
	w._obstacle(at.x,at.z,footprint.size.x,footprint.size.z)
	landmarks.append({"kind":"bench","at":at,"seat_top":.468})
	w.bench_seating.add(at,facing,.468)

func garage(x:float) -> void:
	var at:=Vector3(x,0,-13.0)
	w._box(at+Vector3(0,1.65,0),Vector3(4.4,3.3,4),"bda887",0)
	w._box(at+Vector3(0,3.38,0),Vector3(4.7,.16,4.3),"4d5150",3)
	w._box(at+Vector3(0,1.43,-2.015),Vector3(3.45,2.85,.05),"a5aaa2")
	for i in range(7):w._box(at+Vector3(0,.3+i*.38,-2.05),Vector3(3.42,.025,.035),"6a736c")
	w._obstacle(at.x,at.z,4.4,4.0)
	walk(x-2.1,x+2.1,-17,-15)
	landmarks.append({"kind":"garage","at":at})

func build(world:Node3D) -> void:
	w=world
	# Original ground/asphalt ends at x=79; append flush surfaces without overlap.
	w._box(Vector3(111,-.20,1.5),Vector3(64,.20,87),"c3c3b9",5)
	slab("Street",79,143,12,22,-.18,.30,"505452",3)
	slab("RearAlley",79,143,-21,-17,-.18,.30,"555a57",3)
	for span in [Vector2(-42,-21),Vector2(-17,12),Vector2(22,45)]:
		slab("SideStreet",108,114,span.x,span.y,-.18,.30,"505452",3)
	for span in [Vector2(79,108),Vector2(114,143)]:
		walk(span.x,span.y,6.1,12)
		walk(span.x,span.y,22,26)
		walk(span.x,span.y,-24,-21)
		walk(span.x,span.y,-17,-14.4)
		for z in [12.0,22.0,-21.0,-17.0]:curb(span.x,span.y,z-.06,z+.06)
	for x in [106.5,115.5]:
		for span in [Vector2(-42,-24),Vector2(-14.4,6.1),Vector2(26,45)]:walk(x-1.5,x+1.5,span.x,span.y)
	for x in [108.0,114.0]:
		for span in [Vector2(-42,-21),Vector2(-17,12),Vector2(22,45)]:curb(x-.06,x+.06,span.x,span.y)
	# Extend the existing yellow centerline rhythm and mark the new junction.
	for x in range(74,137,4):
		if x>104 and x<118:continue
		for z in [16.7,17.0]:w.piece("EastRoadStripe",Vector3(x,-.012,z),Vector3(2.4,.012,.1),"c3a04c")
	for z in range(-32,39,4):
		if (z>=-22 and z<=-16) or (z>=10 and z<=24):continue
		w.piece("EastSideStripe",Vector3(111,-.012,z),Vector3(.10,.012,2),"c3a04c")
	for x in [104.5,117.5]:
		for z in range(13,22,2):w.piece("EastCrosswalk",Vector3(x,-.01,z),Vector3(2.8,.01,.65),"c3c0b0")
	for z in [9.2,24.0]:
		for x in range(109,114,2):w.piece("EastCrosswalk",Vector3(x,-.01,z),Vector3(.65,.01,2.8),"c3c0b0")
	# Reorient the two old east-edge buildings into coherent residential rows.
	# The three functional hub buildings remain outside this editable edge.
	for x in [59.0,68.0,78.0,87.0,96.0]:
		w.building("EastResidence",Vector3(x,0,-8),Vector3(7.5,6.0,14),"86624d")
		slab("HouseLawn",x,x+7.5,-14.4,-8,-.045,.06,"586d3e",3)
		w.fence(Vector3(x,0,-14.4),Vector3(x,0,-8))
		garage(x+3.75)
		landmarks.append({"kind":"residence","at":Vector3(x+3.75,0,8.5)})
	# Fronts on opposite sidewalks; their interiors remain future work.
	for x in [58.0,68.0,78.0,88.0,98.0,119.0,128.0]:
		w.building("RearBuilding",Vector3(x,0,-31),Vector3(7.5,6,7),"806957")
		w.building("OppositeBuilding",Vector3(x,0,27),Vector3(7.5,6,7),"817363")
	# A pocket park with three clear entrances and a continuous accessible path.
	w.grass_bounds.append(PARK)
	slab("HouseLawn",118,134,-14,6,-.045,.06,"586d3e",3)
	walk(124,127,-14.5,8.2)
	walk(116.8,135,-3,-.2)
	w.fence(Vector3(118,0,-14),Vector3(124,0,-14))
	w.fence(Vector3(127,0,-14),Vector3(134,0,-14))
	w.fence(Vector3(118,0,6),Vector3(124,0,6))
	w.fence(Vector3(127,0,6),Vector3(134,0,6))
	w.fence(Vector3(118,0,-14),Vector3(118,0,-3))
	w.fence(Vector3(118,0,-.2),Vector3(118,0,6))
	w.fence(Vector3(134,0,-14),Vector3(134,0,6))
	bench(Vector3(121.8,0,-5.4),-PI/2)
	bench(Vector3(129.2,0,-5.4),PI/2)
	bench(Vector3(130,0,3.8),0)
	landmarks.append({"kind":"park","at":Vector3(125.5,0,-1.6)})
	# Broad sidewalk planting sites replace cramped gaps between buildings.
	for i in range(4,TREE_SITES.size()):plant(w,TREE_SITES[i])
	for at in [Vector3(82,0,23.4),Vector3(101,0,23.4),Vector3(131,0,23.4),Vector3(116.2,0,-12.5)]:w._lamp(at.x,at.z)
	for at in [Vector3(121.5,0,-8.5),Vector3(130,0,-8.5)]:
		w._cylinder(at+Vector3.UP*.46,.22,.92,"345c40")
		w._obstacle(at.x,at.z,.44,.44)
	w._car(91,20.5,"435c70")
	w._car(126,13.4,"566a50")
	w._car(100,-19,"898c83")
	# Relocated east containment; north/south/west limits retain their coordinates.
	w.fence(Vector3(73,0,-36),Vector3(EAST_LIMIT,0,-36))
	w.fence(Vector3(73,0,39),Vector3(EAST_LIMIT,0,39))
	w.fence(Vector3(EAST_LIMIT,0,-36),Vector3(EAST_LIMIT,0,39))
	w.set_meta("east_landmarks",landmarks)
