extends RefCounted
var w:Node3D
var surfaces:Array[Dictionary]=[]
var signs:Array[Dictionary]=[]
var driveways:Array[Dictionary]=[]
func slab(x0:float,x1:float,z0:float,z1:float,color:String,tile:int,y:float=-.1,depth:float=.18) -> void:
	surfaces.append({"rect":Rect2(x0,z0,x1-x0,z1-z0),"tile":tile,"top":y+depth/2})
	var tint:="d7d5cb" if tile==3 else ("e1dfd5" if tile==2 else color)
	w._box(Vector3((x0+x1)/2,y,(z0+z1)/2),Vector3(x1-x0,depth,z1-z0),tint,1 if tile==3 else tile)
func build(world:Node3D) -> void:
	w=world
	# Append to the previous district's x=143 ground edge.
	slab(143,207,-42,45,"c3c3b9",5,-.20,.20)
	slab(143,207,12,22,"505452",3,-.18,.30)
	slab(143,207,-21,-17,"555a57",3,-.18,.30)
	for span in [Vector2(-42,-21),Vector2(-17,12),Vector2(22,45)]:slab(139,145,span.x,span.y,"505452",3,-.18,.30)
	for span in [Vector2(145,200)]:
		for side in [Vector2(145,185.5),Vector2(191.5,200)]:slab(side.x,side.y,7,12,"a9a394",2)
		slab(span.x,span.y,22,26,"a9a394",2)
		for side in [Vector2(145,158.5),Vector2(164.5,200)]:slab(side.x,side.y,-24,-21,"a9a394",2)
		slab(span.x,span.y,-17,-15.5,"a9a394",2)
	# Front forecourt, west sidewalk and the public-parking route.
	slab(145,149,-15.5,7,"a9a394",2)
	slab(173.2,179,-15.5,7,"a9a394",2)
	for side in [Vector2(145,185.5),Vector2(191.5,200)]:slab(side.x,side.y,11.94,12.06,"c8c4b9",-1,.025,.12)
	slab(145,200,21.94,22.06,"c8c4b9",-1,.025,.12)
	for x in range(146,201,4):
		for z in [16.7,17.0]:w._box(Vector3(x,-.012,z),Vector3(2.4,.012,.1),"c3a04c")
	for x in [136.5,147.5]:
		for z in range(13,22,2):w._box(Vector3(x,-.01,z),Vector3(2.8,.01,.65),"c3c0b0")
	for z in [9.2,24.0]:
		for x in [140.0,142.0,144.0]:w._box(Vector3(x,-.01,z),Vector3(.65,.01,2.8),"c3c0b0")
	# Patrol parking opens onto the existing rear lane.
	slab(149,174,-33,-24,"505452",3,-.12)
	slab(158.5,164.5,-24,-21,"505452",3,-.12)
	driveways.append({"id":"patrol","rect":Rect2(158.5,-24,6,3),"aisle":Rect2(158.5,-31,6,14)})
	w.fence(Vector3(149,0,-33),Vector3(174,0,-33));w.fence(Vector3(149,0,-33),Vector3(149,0,-24))
	w.fence(Vector3(174,0,-33),Vector3(174,0,-24))
	for z in [-30.5,-26.5]:
		for x in [153.5,169.5]:
			w._car(x,z,"d2d6d1")
			w._box(Vector3(x,2.015,z),Vector3(.75,.15,.35),"2b3b4a")
			w._box(Vector3(x-.2,2.11,z),Vector3(.3,.09,.32),"446b99",-1,.25)
			w._box(Vector3(x+.2,2.11,z),Vector3(.3,.09,.32),"a45046",-1,.25)
			w._label("POLICE",Vector3(x,1.05,z+1.14),.003)
	for x in [150.0,166.0]:
		for z in [-32.5,-28.5,-24.5]:slab(x,x+7,z-.03,z+.03,"c9c8b5",-1,-.018,.008)
	parking_sign("PATROL PARKING",Vector3(161.5,2.5,-32.7),4.3,.006)
	# Public parking on the station's east side; leave the entrance/aisle open.
	slab(179,199,-14,7,"505452",3,-.12)
	slab(185.5,191.5,7,12,"505452",3,-.12)
	driveways.append({"id":"public","rect":Rect2(185.5,7,6,5),"aisle":Rect2(185.5,-14,6,26)})
	for z in [-14.0,-9.0,-4.0,1.0,6.0]:
		for x in [179.5,191.5]:slab(x,x+6,z-.03,z+.03,"d0cdbb",-1,-.018,.008)
	w._car(182.5,-11.5,"455c70");w._car(195,-1.5,"8b8e82")
	slab(179.5,185.5,1,6,"425e7d",-1,-.027,.008)
	parking_sign("PUBLIC PARKING",Vector3(194,2.5,10.5),4.1,.006)
	parking_sign("ACCESSIBLE",Vector3(178.4,2.0,3.5),1.9,.003,PI/2)
	for x in [151.0,164.0,181.0,192.0]:w.building("OppositeBuilding",Vector3(x,0,27),Vector3(8,6.0,7),"897766")
	for at in [Vector2(147,10.8),Vector2(175,10.8),Vector2(198,10.8),Vector2(148,-22),Vector2(176,-22),Vector2(193,24)]:w._lamp(at.x,at.y)

	w.set_meta("police_surfaces",surfaces)
	w.set_meta("police_signs",signs)
	w.set_meta("police_driveways",driveways)
func parking_sign(text:String,at:Vector3,width:float,pixel:float,yaw:float=0) -> void:
	w._box(Vector3(at.x,at.y/2,at.z),Vector3(.09,at.y,.09),"58616a")
	var normal:=Basis(Vector3.UP,yaw)*Vector3.BACK
	w._box(at,Vector3(.10,.55,width) if absf(normal.x)>.5 else Vector3(width,.55,.10),"29485f")
	w._label(text,at+normal*.065,pixel,yaw)
	signs.append({"text":text,"at":at,"normal":normal})
