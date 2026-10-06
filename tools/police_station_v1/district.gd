extends RefCounted
var w:Node3D
func slab(x0:float,x1:float,z0:float,z1:float,color:String,tile:int,y:float=-.1,depth:float=.18) -> void:
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
		slab(span.x,span.y,7.1,12,"a9a394",2)
		slab(span.x,span.y,22,26,"a9a394",2)
		slab(span.x,span.y,-24,-21,"a9a394",2)
		slab(span.x,span.y,-17,-15.5,"a9a394",2)
	# Front forecourt, west sidewalk and the public-parking route.
	slab(146,176,7,11.7,"b3b0a3",2)
	slab(145,149,-17,7,"a9a394",2)
	slab(173.2,177,-17,7,"a9a394",2)
	for z in [12.0,22.0]:slab(145,200,z-.06,z+.06,"c8c4b9",-1,.025,.12)
	for x in range(146,201,4):
		for z in [16.7,17.0]:w._box(Vector3(x,-.012,z),Vector3(2.4,.012,.1),"c3a04c")
	for x in [136.5,147.5]:
		for z in range(13,22,2):w._box(Vector3(x,-.01,z),Vector3(2.8,.01,.65),"c3c0b0")
	for z in [9.2,24.0]:
		for x in [140.0,142.0,144.0]:w._box(Vector3(x,-.01,z),Vector3(.65,.01,2.8),"c3c0b0")
	# Patrol parking opens onto the existing rear lane.
	slab(149,174,-33,-22,"505452",3)
	w.fence(Vector3(149,0,-33),Vector3(174,0,-33));w.fence(Vector3(149,0,-33),Vector3(149,0,-22))
	w.fence(Vector3(174,0,-33),Vector3(174,0,-22))
	for z in [-30.5,-26.5]:
		for x in [154.0,165.0]:
			w._car(x,z,"d2d6d1")
			w._box(Vector3(x,2.015,z),Vector3(.75,.15,.35),"2b3b4a")
			w._box(Vector3(x-.2,2.11,z),Vector3(.3,.09,.32),"446b99",-1,.25)
			w._box(Vector3(x+.2,2.11,z),Vector3(.3,.09,.32),"a45046",-1,.25)
			w._label("POLICE",Vector3(x,1.05,z+1.14),.003)
	for x in [150.0,158.0,162.0,170.0]:slab(x,x+.06,-32,-25,"c9c8b5",-1,.005,.012)
	w._label("PATROL PARKING",Vector3(162,2.0,-32.8),.006)
	# Public parking on the station's east side; leave the entrance/aisle open.
	slab(179,199,-14,7,"505452",3)
	for z in [-11.0,-6.0,-1.0,4.0]:
		for x in [179.5,191.5]:slab(x,x+6,z-.03,z+.03,"d0cdbb",-1,.005,.012)
	w._car(183,-8.5,"455c70");w._car(195,1.5,"8b8e82")
	slab(179.5,185.5,2,6,"425e7d",-1,-.003,.014)
	w._label("PUBLIC PARKING",Vector3(189,2.4,6),.006)
	w._label("ACCESSIBLE",Vector3(182.5,1.4,6),.003)
	for x in [151.0,164.0,181.0,192.0]:w.building("PoliceDistrictResidence",Vector3(x,0,27),Vector3(8,6.0,7),"897766")
	for at in [Vector2(147,10.8),Vector2(175,10.8),Vector2(198,10.8),Vector2(148,-22),Vector2(176,-22),Vector2(193,24)]:w._lamp(at.x,at.y)
