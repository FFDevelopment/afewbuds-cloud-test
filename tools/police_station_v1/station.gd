extends Node3D
## Native, continuous two-floor police station. Z plan coordinates use a .8 scale.
const BASE:=Vector3(149,0,-15.4)
const STORY:=3.6
const EYE:=2.16
const RADIUS:=.26
const HEIGHT:=2.43
var world:Node3D
var colliders:Array[AABB]=[]
var batches:Dictionary={}
var doors:Array[Node3D]=[]
var rooms:Array[Dictionary]=[]
var openings:Array[Dictionary]=[]
var windows:Array[Dictionary]=[]
var parts:Array[Dictionary]=[]
var wall_bounds:Array[AABB]=[]
var floor_index:=0
var material_cache:Dictionary={}

func point(x:float,y:float,z:float) -> Vector3:return BASE+Vector3(x,y,z*.8)
func local_point(at:Vector3) -> Vector3:
	var p:=at-BASE;p.z/=.8;return p
func box(id:String,at:Vector3,size:Vector3,color:String,solid:bool=true,wood:bool=false) -> void:
	parts.append({"id":id,"bounds":AABB(at-size/2,size),"floor":floor_index})
	var key:=str(floor_index)+":"+color+":"+str(wood)
	if not batches.has(key):batches[key]={"floor":floor_index,"color":color,"wood":wood,"transforms":[]}
	batches[key].transforms.append(Transform3D(Basis.from_scale(size),at))
	if solid:colliders.append(AABB(at-size/2,size))
func part(id:String,x:float,y:float,z:float,size:Vector3,color:String,solid:bool=true,wood:bool=false) -> void:
	box(id,point(x,y,z),size,color,solid,wood)
func mat(color:String,wood:bool=false) -> Material:
	var key:=color+str(wood)
	if not material_cache.has(key):
		var material:=ShaderMaterial.new();material.shader=load("res://scripts/police_surface.gdshader")
		material.set_shader_parameter("tint",Color(color))
		material.set_shader_parameter("finish",1 if wood else (2 if color=="a3a39b" else 0))
		material_cache[key]=material
	return material_cache[key]
func flush() -> void:
	for key in batches:
		var b:Dictionary=batches[key];var mesh:=BoxMesh.new();mesh.size=Vector3.ONE
		var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=b.transforms.size()
		for i in range(mm.instance_count):mm.set_instance_transform(i,b.transforms[i])
		var node:=MultiMeshInstance3D.new();node.name="StationBatch";node.multimesh=mm;node.layers=2
		node.material_override=mat(b.color,b.wood);node.set_meta("station_floor",b.floor);add_child(node)

func rail(a:Vector3,b:Vector3) -> void:
	var size:=Vector3(.075,.075,a.distance_to(b));var center:Vector3=(a+b)/2
	box("ContinuousHandrail",center,size,"485861",false)
	var key:=str(floor_index)+":485861:"+str(false)
	batches[key].transforms[-1]=Transform3D(Basis.looking_at((b-a).normalized(),Vector3.UP)*Basis.from_scale(size),center)

func label(text:String,x:float,y:float,z:float,yaw:float=0,size:float=.004) -> void:
	var n:=Label3D.new();n.text=text;n.font_size=40;n.pixel_size=size;n.position=point(x,y,z);n.rotation.y=yaw
	n.modulate=Color("e8edf1");n.outline_size=3;n.set_meta("station_floor",floor_index);add_child(n)

func wall(id:String,x:float,z:float,length:float,along_x:bool,holes:Array=[],color:String="d6d1c7") -> void:
	var start:=point(x,floor_index*STORY,z);var axis:=Vector3.RIGHT if along_x else Vector3.BACK
	var span:=length if along_x else length*.8
	var cuts:Array[Rect2]=[]
	for raw in holes:cuts.append(Rect2(raw.position*Vector2(1 if along_x else .8,1),raw.size*Vector2(1 if along_x else .8,1)))
	var wall_height:float=STORY
	if floor_index==0 and id.begins_with("Stair"):wall_height=STORY-.20
	elif floor_index==1:wall_height=STORY-.23
	var xs:Array[float]=[0,span];var ys:Array[float]=[0,wall_height]
	for h in cuts:
		xs.append(h.position.x);xs.append(h.end.x);ys.append(h.position.y);ys.append(h.end.y)
		openings.append({"wall":id,"floor":floor_index,"origin":start,"axis":axis,"rect":h})
	xs.sort();ys.sort()
	for i in range(xs.size()-1):
		for j in range(ys.size()-1):
			var w:=xs[i+1]-xs[i];var h:=ys[j+1]-ys[j]
			if w<.001 or h<.001:continue
			var center:=Vector2((xs[i]+xs[i+1])/2,(ys[j]+ys[j+1])/2);var cut:=false
			for hole in cuts:
				if hole.has_point(center):cut=true
			if cut:continue
			box(id,start+axis*center.x+Vector3.UP*center.y,Vector3(w,h,.22) if along_x else Vector3(.22,h,w),color)
			wall_bounds.append(parts[-1].bounds)
	# Low trim is split around floor-level openings as well.
	for i in range(xs.size()-1):
		var mid:float=(xs[i]+xs[i+1])/2;var cut:=false
		for hole in cuts:
			if hole.has_point(Vector2(mid,.08)):cut=true
		if not cut:
			# Facade skirting belongs on the inside only; a centered trim box
			# previously protruded outside as a dark band at both floor levels.
			var inward:Vector3={"Front":Vector3.FORWARD,"Rear":Vector3.BACK,"West":Vector3.RIGHT,"East":Vector3.LEFT}.get(id,Vector3.ZERO)
			var normal:=Vector3.BACK if along_x else Vector3.RIGHT
			var trim_depth:=.03
			var trim_offset:=.11+trim_depth/2+.003
			var faces:Array[Vector3]=[inward] if inward!=Vector3.ZERO else [normal,-normal]
			var trim_from:float=xs[i]
			var trim_to:float=xs[i+1]
			# Interior wall ends butt into another wall. Stop the base at that
			# wall's half-thickness so perpendicular skirting forms a clean corner.
			if inward==Vector3.ZERO:
				if is_equal_approx(trim_from,0.0):trim_from+=.11
				if is_equal_approx(trim_to,span):trim_to-=.11
			var trim_length:=trim_to-trim_from
			if trim_length>.02:
				var trim_mid:float=(trim_from+trim_to)/2
				for face in faces:
					box(id+"Skirting",start+axis*trim_mid+Vector3.UP*.07+face*trim_offset,Vector3(trim_length,.14,trim_depth) if along_x else Vector3(trim_depth,.14,trim_length),"737777",false)

func window_at(x:float,z:float,width:float,along_x:bool,sill:float=1.15,height:float=1.6,privacy:bool=false) -> void:
	# Width/height describe the masonry aperture, not the pane. All frame
	# parts sit INSIDE it; .01 m clearance avoids intersections with the wall.
	var at:=point(x,floor_index*STORY+sill+height/2,z)
	var pane_width:=width-.18;var pane_height:=height-.18
	var size:=Vector3(pane_width,pane_height,.035) if along_x else Vector3(.035,pane_height,pane_width)
	var glass:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;glass.mesh=mesh;glass.position=at
	var m:=StandardMaterial3D.new();m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.albedo_color=Color(.32,.48,.53,.28);m.roughness=.85 if privacy else .24
	if privacy:m.albedo_color=Color(.59,.68,.69,.88)
	glass.material_override=m;glass.layers=2;glass.set_meta("station_floor",floor_index);add_child(glass)
	var aperture_size:=Vector3(width,height,.22) if along_x else Vector3(.22,height,width)
	var pane_bounds:=AABB(at-size/2,size)
	colliders.append(pane_bounds)
	windows.append({"at":at,"floor":floor_index*STORY,"bottom":at.y-height/2,"top":at.y+height/2,"bounds":pane_bounds,"aperture":AABB(at-aperture_size/2,aperture_size),"privacy":privacy})
	var axis:=Vector3.RIGHT if along_x else Vector3.BACK
	for s in [-1.0,1.0]:
		box("WindowJamb",at+axis*s*(width/2-.05),Vector3(.08,pane_height,.28) if along_x else Vector3(.28,pane_height,.08),"303e49",false)
		box("WindowRail",at+Vector3.UP*s*(height/2-.05),Vector3(width-.02,.08,.28) if along_x else Vector3(.28,.08,width-.02),"303e49",false)
	box("WindowMullion",at,Vector3(.06,pane_height,.14) if along_x else Vector3(.14,pane_height,.06),"303e49",false)

func door(id:String,x:float,z:float,width:float,side:bool=false,bars:bool=false,glazed:bool=false) -> void:
	var physical_width:=width*(.8 if side else 1.0)
	var pivot:Node3D=load("res://scripts/police_door.gd").new();pivot.name=id;pivot.width=physical_width;pivot.host=world.host
	pivot.set_meta("plan_width",width);pivot.set_meta("side_door",side)
	if id in ["LOCKER_ROOM","STAFF_TOILET"]:pivot.swing_side=-1.0
	var yaw:=PI/2 if side else 0.0;pivot.position=point(x,floor_index*STORY,z)-Basis(Vector3.UP,yaw)*Vector3(physical_width/2,0,0);pivot.rotation.y=yaw
	pivot.set_meta("station_floor",floor_index);pivot.set_meta("title",id.replace("_"," "));add_child(pivot)
	var leaf:=Node3D.new();leaf.name="Leaf";pivot.add_child(leaf)
	if bars:
		for i in range(9):door_box(leaf,Vector3(.06+i*(physical_width-.12)/8,1.425,0),Vector3(.055,2.85,.065),"525d65")
		for y in [.12,1.4,2.75]:door_box(leaf,Vector3(physical_width/2,y,0),Vector3(physical_width,.065,.075),"525d65")
	else:
		door_box(leaf,Vector3(physical_width/2,1.425,0),Vector3(physical_width-.035,2.85,.10),"264760" if glazed else "aa8961")
		if glazed:door_box(leaf,Vector3(physical_width/2,1.65,.06),Vector3(maxf(.2,physical_width-.24),1.95,.025),"64858b")
	door_box(leaf,Vector3(maxf(.12,physical_width-.15),1.28,.12),Vector3(.09,.25,.14),"b5b8b2")
	doors.append(pivot)
	if id not in ["PUBLIC_ENTRANCE","REAR_BOOKING_ENTRANCE"]:
		label(id.replace("_"," "),x-.25 if side else x,floor_index*STORY+3.16,z if side else z+.32,-PI/2 if side else 0,.0025)
	# Frame trim sits entirely inside the cut aperture with clearance from masonry.
	var along:=Vector3.BACK if side else Vector3.RIGHT
	var center:=point(x,floor_index*STORY,z)
	var frame_width:=.07
	var frame_depth:=.16
	var frame_height:=2.82
	var frame_edge:=physical_width/2-frame_width/2-.006
	for s in [-1.0,1.0]:
		box("DoorJamb",center+along*s*frame_edge+Vector3.UP*(frame_height/2),Vector3(frame_depth,frame_height,frame_width) if side else Vector3(frame_width,frame_height,frame_depth),"747d82",false)
	var header_span:=maxf(.1,physical_width-frame_width*2-.012)
	box("DoorHeader",center+Vector3.UP*2.86,Vector3(frame_depth,.07,header_span) if side else Vector3(header_span,.07,frame_depth),"747d82",false)

func door_box(parent:Node3D,at:Vector3,size:Vector3,color:String) -> void:
	var n:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;n.mesh=mesh;n.position=at;n.material_override=mat(color);n.layers=2;parent.add_child(n)

func room(id:String,rect:Rect2) -> void:
	rooms.append({"name":id,"rect":rect,"floor":floor_index})
	var center:=rect.get_center();var y:=float(floor_index)*STORY
	part("CeilingFixture",center.x,y+3.36,center.y,Vector3(1.6,.07,.5),"ebefe9",false)
	var light:=OmniLight3D.new();light.position=point(center.x,y+3.18,center.y);light.light_color=Color("fff0da");light.light_energy=.85
	light.light_energy=.45;light.omni_range=5.5;light.shadow_enabled=true;light.light_cull_mask=2;light.set_meta("station_floor",floor_index);add_child(light)

func chair(x:float,z:float,yaw:float=0) -> void:
	var y:=floor_index*STORY;var basis:=Basis(Vector3.UP,yaw);var at:=point(x,y,z)
	box("ChairSeat",at+Vector3.UP*.433,Vector3(.64,.07,.62),"294558")
	box("ChairBack",at+basis*Vector3(0,.88,.28),Vector3(.64,.72,.08) if absf(sin(yaw))<.5 else Vector3(.08,.72,.64),"294558")
	for dx in [-.24,.24]:
		for dz in [-.23,.23]:box("ChairLeg",at+basis*Vector3(dx,.2,dz),Vector3(.055,.4,.055),"454b4d",false)

func table(x:float,z:float,width:float,depth:float,h:float=.96) -> void:
	var y:=floor_index*STORY
	part("OakTop",x,y+h-.06,z,Vector3(width,.12,depth),"b39771",true,true)
	for dx in [-width/2+.12,width/2-.12]:
		for dz in [-depth/2+.12,depth/2-.12]:box("TableLeg",point(x,y+(h-.12)/2,z)+Vector3(dx,0,dz),Vector3(.1,h-.12,.1),"4b5459",false)

func desk(x:float,z:float) -> void:
	table(x,z,2.1,.95)
	var y:=floor_index*STORY
	part("Monitor",x,y+1.3,z-.14,Vector3(.82,.5,.07),"23323c")
	part("Screen",x,y+1.3,z-.08,Vector3(.72,.4,.025),"435c75",false)
	part("ScreenStand",x,y+1.05,z-.1,Vector3(.14,.2,.1),"363e44",false)
	part("Keyboard",x,y+.98,z+.3,Vector3(.65,.035,.22),"30383a",false)
	part("DeskPedestal",x+.75,y+.42,z,Vector3(.52,.84,.72),"6d7274")
	for level in [.2,.47,.72]:part("DrawerPull",x+.75,y+level,z+.46,Vector3(.22,.035,.06),"bcc0bb",false)
	chair(x,z+1.25,0)

func plant(x:float,z:float) -> void:
	var y:=floor_index*STORY
	part("Planter",x,y+.3,z,Vector3(.65,.6,.65),"858578")
	for dx in [-.22,0,.22]:part("PlantLeaves",x+dx,y+.93,z,Vector3(.24,.85,.5),"526544",false)

func restroom(x:float,z:float) -> void:
	var y:=floor_index*STORY
	part("ToiletBase",x,y+.2,z,Vector3(.45,.4,.68),"dfded4")
	part("ToiletSeat",x,y+.44,z+.1,Vector3(.58,.055,.7),"f0efe6")
	part("ToiletTank",x,y+.68,z-.35,Vector3(.62,.58,.22),"dfded4")
	part("Washstand",x+1.9,y+.55,z,Vector3(1.05,1.1,.65),"c0b8a5")
	part("Basin",x+1.9,y+1.15,z,Vector3(1.1,.1,.72),"eee9dd")
	part("Tap",x+1.9,y+1.35,z-.2,Vector3(.06,.3,.1),"a6afb0",false)
	part("Mirror",x+1.9,y+1.95,z-1.03,Vector3(.95,.95,.04),"71868a",false)

func build(owner:Node3D) -> void:
	world=owner
	for f in [0,1]:
		floor_index=f
		# Upper deck has a real opening over the full stairwell.
		if f==0:part("GroundFloor",12,-.08,14,Vector3(23.76,.16,22.16),"a3a39b",false)
		else:
			part("UpperFloorWest",9.56,STORY-.1,14,Vector3(18.88,.2,22.16),"aaaead",false)
			part("UpperFloorNorth",21.44,STORY-.1,6.825,Vector3(4.88,.2,10.68),"aaaead",false)
			part("UpperFloorSouth",21.44,STORY-.1,24.925,Vector3(4.88,.2,4.68),"aaaead",false)
		# Openings follow each room, with solid margins at partition junctions.
		var front_holes:Array=[Rect2(1,1.15,5,1.6)]
		if f==0:
			front_holes.append(Rect2(10,0,2.4,2.9))
			front_holes.append(Rect2(20,2.05,2.8,.75))
		else:
			front_holes.append(Rect2(10,1.15,5,1.6))
			front_holes.append(Rect2(20,1.15,3,1.6))
		wall("Front",0,28,24,true,front_holes,"c6c1b4")
		window_at(3.5,28,5,true)
		if f==0:window_at(21.4,28,2.8,true,2.05,.75,true)
		else:
			window_at(12.5,28,5,true);window_at(21.5,28,3,true)
		wall("Rear",0,0,24,true,[Rect2(2,1.15,5,1.6),Rect2(13.4,0,1.8,2.9)] if f==0 else [Rect2(2,1.15,5,1.6),Rect2(11,1.45,5,1.3)],"c6c1b4")
		window_at(4.5,0,5,true)
		if f==1:window_at(13.5,0,5,true,1.45,1.3)
		wall("West",0,0,28,false,[Rect2(1.5,1.15,3,1.6),Rect2(23,1.15,4,1.6)],"c6c1b4")
		window_at(0,3,2.4,false);window_at(0,25,3.2,false)
		if f==0:
			# High frosted daylight in cells and public restroom; no low cell glazing.
			wall("East",24,0,28,false,[Rect2(1.5,2.25,2.5,.65),Rect2(7.5,2.25,2.5,.65),Rect2(24,2.05,2.5,.75)],"c6c1b4")
			window_at(24,2.75,2,false,2.25,.65,true);window_at(24,8.75,2,false,2.25,.65,true)
			window_at(24,25.25,2,false,2.05,.75,true)
		else:
			wall("East",24,0,28,false,[Rect2(2,2.25,2.5,.65),Rect2(7,2.25,2.5,.65),Rect2(23,1.15,4,1.6)],"c6c1b4")
			window_at(24,3.25,2,false,2.25,.65,true);window_at(24,8.25,2,false,2.25,.65,true)
			window_at(24,25,3.2,false)
		# Stairwell doors are at the bottom landing and top landing respectively.
		wall("StairWest",19,12,10,false,[Rect2(8.15,0,2,2.9)] if f==0 else [Rect2(.15,0,2,2.9)])
		wall("StairSouth",19,22,5,true,[])
		wall("StairNorth",19,12,5,true,[] if f==0 else [])
		# Sign above the clear stair aperture; no swing leaf obstructs the landing.
		label("STAIRS UP" if f==0 else "STAIRS DOWN",18.7,f*STORY+3.16,21.15 if f==0 else 13.15,-PI/2,.003)
		if f==0:ground_rooms()
		else:upper_rooms()
	# Stair treads rise northward; floor-aware movement uses the matching ramp.
	floor_index=0
	for i in range(20):
		var h:float=(i+1)*STORY/20
		part("StairTread",21.5,h/2,20.5-(i+.5)*.35,Vector3(4.6,h,.28),"888d8e",false)
		if i<19:part("StairNosing",21.5,h+.009,20.5-i*.35,Vector3(4.6,.018,.035),"bfc4c1",false)
	for x in [19.4,23.6]:
		rail(point(x,.95,20.5),point(x,STORY+.95,13.5))
		for t in [.1,.4,.7,.9]:
			part("RailWallBracket",19.25 if x<20 else 23.78,.92+STORY*t,20.5-7*t,Vector3(.3,.055,.06),"485861",false)
	floor_index=1
	part("TopLanding",21.5,STORY-.1,12.75,Vector3(4.6,.2,1.2),"a2a7a5",false)
	# Separate plaster undersides keep floor finishes off the ceilings.
	floor_index=1
	part("CeilingWest",9.56,3.385,14,Vector3(18.88,.025,22.16),"d6d1c7",false)
	part("CeilingNorth",21.44,3.385,6.825,Vector3(4.88,.025,10.68),"d6d1c7",false)
	part("CeilingSouth",21.44,3.385,24.925,Vector3(4.88,.025,4.68),"d6d1c7",false)
	# A roof separate from the upper-floor meshes permits honest cutaway captures.
	floor_index=2;part("Roof",12,7.12,14,Vector3(24.5,.24,22.8),"676d70",false)
	part("UpperCeiling",12,6.99,14,Vector3(23.76,.025,22.16),"d6d1c7",false)
	for x in [0.0,24.0]:part("RoofParapet",x,7.5,14,Vector3(.28,.65,22.6),"b8b7ae",false)
	for z in [0.0,28.0]:part("RoofParapet",12,7.5,z,Vector3(24,.65,.28),"b8b7ae",false)
	for x in [6.0,17.0]:part("RoofHVAC",x,7.7,8,Vector3(2,1,1.5),"a7aaa5",false)
	floor_index=0
	door("PUBLIC_ENTRANCE",11.2,28,2.4,false,false,true);door("REAR_BOOKING_ENTRANCE",14.3,0,1.8)
	part("PublicThreshold",11.2,-.02,28,Vector3(2.4,.04,.5),"888d8e",false)
	part("RearThreshold",14.3,-.02,0,Vector3(1.8,.04,.5),"888d8e",false)
	for x in [8.0,16.0]:part("NavyFacade",x,3.5,28.18,Vector3(.8,7,.24),"254967",false)
	part("EntranceCanopy",11.2,3.12,29,Vector3(6,.18,2),"354853",false)
	part("StationNameBoard",12,6.9,28.3,Vector3(13,.65,.16),"d4d2c6",false)
	label("AFEWBUDS POLICE",12,6.9,28.43,0,.009)
	part("BadgeBacking",8,4.7,28.28,Vector3(1.2,1.2,.12),"254967",false)
	label("AFB\nPOLICE",8,4.7,28.42,0,.005)
	for x in [2.0,6.0,18.0,22.0]:plant(x,29.8)
	flush()

func ground_rooms() -> void:
	wall("LobbySecure",0,20,19,true,[Rect2(16,0,1.8,2.9)])
	door("STAFF_ACCESS",16.9,20,1.8)
	wall("PublicRestroomWest",19,22,6,false,[Rect2(3.6,0,2,2.9)])
	door("PUBLIC_RESTROOM",19,26.6,1.6,true)
	wall("BookingNorth",0,14,15,true,[])
	wall("BookingEast",15,14,6,false,[Rect2(2.1,0,2,2.9)])
	door("BOOKING",15,17.1,1.6,true)
	wall("InterviewEast",9,0,7,false,[Rect2(3.8,0,2,2.9)])
	door("INTERVIEW",9,4.8,1.6,true)
	wall("InterviewSouth",0,7,9,true,[])
	wall("EvidenceEast",9,7,7,false,[Rect2(3.8,0,2,2.9)])
	door("EVIDENCE",9,11.8,1.6,true)
	wall("CellsWest",19,0,12,false,[Rect2(2,0,2,2.9),Rect2(8,0,2,2.9)],"b6b8b3")
	wall("CellDivider",19,6,5,true,[],"b6b8b3")
	for z in [3.0,9.0]:
		door("HOLDING_CELL_1" if z==3 else "HOLDING_CELL_2",19,z,1.6,true,true)
		part("CellBedFrame",22,.3,z,Vector3(1.05,.55,2.2),"656d70")
		part("CellMattress",22,.64,z,Vector3(1,.14,2.15),"9a9d8a")
		part("CellPillow",22,.77,z-.8,Vector3(.85,.14,.5),"c2c5b5",false)
		part("CellToilet",23.15,.25,z+1.9,Vector3(.5,.5,.65),"a6b0b1")
	room("PUBLIC LOBBY",Rect2(0,20,19,8));room("PUBLIC RESTROOM",Rect2(19,22,5,6))
	room("BOOKING",Rect2(0,14,15,6));room("INTERVIEW",Rect2(0,0,9,7));room("EVIDENCE",Rect2(0,7,9,7))
	room("HOLDING CELL 1",Rect2(19,0,5,6));room("HOLDING CELL 2",Rect2(19,6,5,6));room("SECURE CORRIDOR",Rect2(9,0,10,14))
	for x in [2.0,3.1,4.2,5.3]:chair(x,25.8,0)
	part("ReceptionBase",12.7,.53,23,Vector3(6.1,1.06,1.15),"294b63")
	part("ReceptionOak",12.7,1.11,23,Vector3(6.3,.12,1.25),"b39771",true,true)
	part("ReceptionReturn",9.8,.55,24,Vector3(.6,1.1,1.6),"294b63")
	part("ReceptionMonitor",13,1.39,22.8,Vector3(.75,.45,.09),"2d414c",false)
	chair(13,21.5,PI);label("RECEPTION",12.7,.85,23.8,0,.0045)
	part("BookingCounter",6,.55,17.6,Vector3(9,1.1,1.05),"888a7f")
	part("BookingTop",6,1.15,17.6,Vector3(9.2,.1,1.15),"bdc1b7")
	desk(5,15.5);label("BOOKING",7.5,3.05,19.84,PI,.005)
	table(4.3,3.4,2.6,1.15);chair(4.3,5.1);chair(4.3,1.8,PI)
	part("InterviewBoard",4,2.1,6.82,Vector3(3,1.2,.08),"b5c2bd",false)
	for x in [1.2,3.5,5.8]:
		part("EvidenceRack",x,1.15,8,Vector3(1.9,2.3,.65),"47555c")
		for level in [.45,1.05,1.65]:
			part("EvidenceBox",x,level,8.5,Vector3(1.6,.44,.55),"b6ae92",false)
			part("EvidenceLabel",x,level,8.86,Vector3(.45,.13,.01),"e4e1d4",false)
	label("EVIDENCE STORE",4.5,2.8,13.82,PI,.005)
	restroom(20.2,23.2);plant(1.1,22)

func upper_rooms() -> void:
	wall("BriefingEast",9,0,11,false,[Rect2(8,0,2,2.9)])
	door("BRIEFING",9,9,1.6,true)
	wall("BriefingSouth",0,11,9,true,[])
	wall("KitchenEast",17,0,11,false,[Rect2(8,0,2,2.9)])
	wall("KitchenSouth",9,11,8,true,[Rect2(2.2,0,1.8,2.9)])
	door("BREAK_ROOM",12.1,11,1.8)
	wall("LockerSouth",19,6,5,true,[])
	wall("LockerWest",19,0,6,false,[Rect2(2,0,2,2.9)])
	door("LOCKER_ROOM",19,3,1.6,true)
	wall("StaffToiletSouth",19,11,5,true,[])
	wall("StaffToiletWest",19,6,5,false,[Rect2(1.3,0,2,2.9)])
	door("STAFF_TOILET",19,8.3,1.6,true)
	wall("ChiefEast",9,17,11,false,[Rect2(1.1,0,2,2.9)])
	door("CHIEF_OFFICE",9,19.1,1.6,true)
	wall("ChiefNorth",0,17,9,true,[])
	room("BRIEFING ROOM",Rect2(0,0,9,11));room("KITCHEN / BREAK ROOM",Rect2(9,0,8,11))
	room("LOCKER ROOM",Rect2(19,0,5,6));room("STAFF TOILET",Rect2(19,6,5,5))
	room("CHIEF'S OFFICE",Rect2(0,17,9,11));room("OFFICE / WORKSTATIONS",Rect2(9,17,10,11));room("UPPER HALL",Rect2(0,11,19,6))
	table(4.4,5.3,3.8,1.7)
	for x in [3.0,4.4,5.8]:chair(x,7.4);chair(x,3.2,PI)
	part("BriefingBoard",.18,5.75,7.8,Vector3(.08,1.6,3.2),"bdc6c0",false)
	for z in [6.4,7.8,9.2]:part("BriefingMap",.24,5.75,z,Vector3(.02,1.1,.95),"98b0b8",false)
	part("KitchenBase",13,4.14,1,Vector3(5.6,1.08,.85),"aaa18e")
	part("KitchenWorktop",13,4.72,1,Vector3(5.75,.08,.95),"c9ccc2")
	part("Fridge",10,4.8,1.1,Vector3(1.05,2.4,1),"c1c4bc")
	part("Microwave",12,4.98,1,Vector3(.8,.44,.6),"59636a")
	part("Sink",15,4.78,1,Vector3(1,.06,.65),"7b8b8e",false)
	table(13,7.2,2.4,1.6);chair(12.3,9);chair(13.7,9);chair(12.3,5.4,PI);chair(13.7,5.4,PI)
	for x in [19.6,20.7,21.8,22.9]:
		part("NavyLocker",x,4.7,1.2,Vector3(.97,2.2,.68),"315574")
		part("LockerHandle",x+.25,4.75,1.65,Vector3(.045,.24,.07),"bac0bc",false)
		for y in [5.25,5.35,5.45]:part("LockerVent",x,y,1.64,Vector3(.5,.025,.02),"1b303c",false)
	table(21.5,4.5,2.6,.55,.468)
	restroom(20,7.2)
	desk(4.5,22);chair(3.7,19.8,PI);chair(5.3,19.8,PI)
	for x in [11.5,16.1]:
		for z in [20.2,25]:desk(x,z)
	part("OfficeDivider",13.8,4.32,23,Vector3(.10,1.44,6.4),"a9afaa")
	plant(1.1,18.2);plant(17.6,15);plant(7.6,1.5)

func covers(at:Vector3) -> bool:
	var p:=local_point(at)
	return p.x>-.6 and p.x<24.6 and p.z>-.75 and p.z<28.75
func floor_at(at:Vector3) -> float:
	var p:=local_point(at)
	if p.x>19.12 and p.x<23.88 and p.z>12.12 and p.z<21.88:
		return clampf((20.5-p.z)/7.0,0,1)*STORY
	return STORY if at.y>EYE+STORY/2 else 0.0
func eye_height(at:Vector3) -> float:return floor_at(at)+EYE
func walkable(at:Vector3) -> bool:
	var height:=floor_at(at)
	if absf(at.y-EYE-height)>.29:return false
	var body:=AABB(Vector3(at.x-RADIUS,height+.08,at.z-RADIUS),Vector3(RADIUS*2,HEIGHT-.08,RADIUS*2))
	for obstacle in colliders:
		if body.intersects(obstacle):return false
	for d in doors:
		if d.busy or d.pass_through:continue
		var leaf:Node3D=d.get_node("Leaf")
		var bounds:AABB=leaf.global_transform*AABB(Vector3(0,0,-.055),Vector3(d.width,2.85,.11))
		if body.intersects(bounds):return false
	return true
func nearby_door() -> int:
	var result:=-1;var distance:=2.5
	for i in range(doors.size()):
		var d:Node3D=doors[i];var at:Vector3=d.to_global(Vector3(d.width/2,1.6,0))
		var offset:Vector3=at-world.host.camera.position
		if offset.length()>=distance or (-world.host.camera.global_basis.z).dot(offset.normalized())<.12:continue
		# Test up to the aperture; its own leaf is intentionally ignored.
		var clear:=true
		for step in range(1,9):
			var sample:Vector3=world.host.camera.position.lerp(at,float(step)/10)
			for b in colliders:
				if b.has_point(sample):clear=false
		if clear:result=i;distance=offset.length()
	return result
func target() -> String:
	var i:=nearby_door();return "police_"+str(i) if i>=0 else ""
func title(id:String) -> String:
	var d:Node3D=doors[int(id.trim_prefix("police_"))]
	return ("CLOSE " if d.opened else "OPEN ")+str(d.get_meta("title"))
func use(id:String) -> void:
	if id!=target() or not world.active or world.host._any_modal_open() or world.transitioning:return
	doors[int(id.trim_prefix("police_"))].toggle(world.host.camera.position)
func tap(screen:Vector2) -> bool:
	var i:=nearby_door()
	if i<0:return false
	var d:Node3D=doors[i];var at:Vector3=d.get_node("Leaf").to_global(Vector3(d.width/2,1.5,0))
	if world.host.camera.is_position_behind(at) or world.host.camera.unproject_position(at).distance_to(screen)>130:return false
	var id:="police_"+str(i);var now:=Time.get_ticks_msec()
	if world.last_tap_station==id and now-world.last_tap_time<420:use(id);world.last_tap_station=""
	else:world.last_tap_station=id;world.last_tap_time=now;world.host.status_label.text="Double tap to use this door."
	return true
func room_title(at:Vector3) -> String:
	if not covers(at):return ""
	var p:=local_point(at);var f:=1 if floor_at(at)>STORY/2 else 0
	for r in rooms:
		if r.floor==f and r.rect.has_point(Vector2(p.x,p.z)):return "POLICE | "+r.name
	return "POLICE | STAIRS" if p.x>19 and p.z>12 and p.z<22 else "POLICE | CORRIDOR"
