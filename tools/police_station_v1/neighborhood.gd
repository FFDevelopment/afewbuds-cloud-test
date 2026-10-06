extends Node3D
var police_station:Node3D
var entrance_records:Array[Dictionary]=[]
const Seating=preload("res://scripts/seating.gd")
var bench_seating=Seating.new()
const TreeLayout=preload("res://scripts/east_expansion.gd")
var window_layout_records:Array[Dictionary]=[]
const ScalePolicy=preload("res://scripts/scale_policy.gd")
var prop_transform:=Transform3D.IDENTITY
var prop_active:=false
var fitted_prop_bounds:Array[Dictionary]=[]
var prop_bounds:=AABB()
var prop_has_bounds:=false

var weather: RefCounted
var location_ops: RefCounted
var property_opportunity: RefCounted
var house_controls: RefCounted
var client_visits: RefCounted
var map_doors: Array[Node3D] = []
var map_obstacles: Array[Rect2] = []
# First exterior: isolated geometry and navigation; career simulation stays in main.
const ORIGIN := Vector3.ZERO
var host: Node3D
var layout_queued := false
var active := false
var in_station := false
var mobile_hud: RefCounted
var couch_seated := false
var couch_stand := Vector3.ZERO
var opening_station := false
var walk_position := Vector3.ZERO
var walk_rotation := Vector3.ZERO
var interior_obstacles: Array[Rect2] = []
var collision_timer := 0.0
var tap_start := Vector2.ZERO
var tap_distance := 0.0
var last_tap_time := -1000
var last_tap_station := ""
var transitioning := false
var door_open := false
var door_busy := false
var door_open_angle := PI/2
var door_pass_through := false
var tile_textures: Array[Texture2D] = []
var controls: CanvasLayer
var pad: Control
var action: Button
var buttons: Array[Button] = []
var pointer := -99
var last_pointer := Vector2.ZERO
var obstacles: Array[Rect2] = []
var door_pivot: Node3D
var text_player: AudioStreamPlayer
var last_ding := -1000
var materials: Dictionary = {}
var outdoor_environment: Environment
var outdoor_sun: DirectionalLight3D
var saved_indoor_sun_visible: bool = true

func setup(owner_node: Node3D) -> void:
	host = owner_node
	bench_seating.setup(self)
	client_visits = load("res://scripts/client_visits.gd").new()
	client_visits.setup(self)
	house_controls=load("res://scripts/house_controls.gd").new()
	house_controls.setup(self)
	position = ORIGIN
	visible = true
	outdoor_environment=Environment.new()
	outdoor_environment.background_mode=Environment.BG_COLOR
	outdoor_environment.background_color=Color("b5c7d0")
	outdoor_environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	outdoor_environment.ambient_light_color=Color("c6d0d1")
	outdoor_environment.ambient_light_energy=0.4
	load("res://scripts/furniture_fit.gd").apply_apartment(host)
	_build_block()
	weather=load("res://scripts/weather.gd").new()
	weather.setup(self)
	host.world_environment_ref.background_mode=Environment.BG_SKY
	host.world_environment_ref.sky=outdoor_environment.sky
	_build_controls()
	_build_door_hinge()
	property_opportunity=load("res://scripts/property_opportunity.gd").new()
	property_opportunity.setup(self)
	location_ops=load("res://scripts/location_ops.gd").new()
	location_ops.setup(self)
	host.get_tree().root.size_changed.connect(_queue_screen_layout)
	_queue_screen_layout()
	text_player = AudioStreamPlayer.new()
	var stream := AudioStreamMP3.new()
	stream.data = FileAccess.get_file_as_bytes("res://assets/audio/text_ding.mp3")
	text_player.stream = stream
	text_player.volume_db = -14.0
	add_child(text_player)

func play_text() -> void:
	if not host.gameplay_ready or host.session_paused:
		return
	var now := Time.get_ticks_msec()
	if now - last_ding < 700:
		return
	last_ding = now
	text_player.play()

# All static props share instanced meshes, keeping the larger textured block affordable.
var batches: Dictionary = {}
var atlas: Texture2D
var exterior_shader: Shader
var lamps: Array[OmniLight3D] = []
const WALK_EYE_HEIGHT := ScalePolicy.EYE_HEIGHT
const APARTMENT_ENTRY := Vector3(0, WALK_EYE_HEIGHT, 8.8)
const HOUSE_ENTRY := Vector3(40, WALK_EYE_HEIGHT, 8.3)

func _material(color: String, tile: int = -1, glow: float = 0.0) -> Material:
	var key := "%s:%d:%f" % [color, tile, glow]
	if materials.has(key): return materials[key]
	var material: Material
	if color=="74604a" and tile<0:
		var bark:=ShaderMaterial.new()
		bark.shader=load("res://scripts/bark.gdshader")
		bark.set_shader_parameter("tint",Color(color))
		material=bark
	elif tile >= 0:
		var textured := ShaderMaterial.new()
		textured.shader = exterior_shader
		textured.set_shader_parameter("surface_texture", tile_textures[tile])
		textured.set_shader_parameter("tint", Color(color))
		textured.set_shader_parameter("tile_meters", Vector3(2.4, 1.2, 2.4) if tile == 0 else Vector3(2.0, 2.0, 2.0))
		material = textured
	else:
		var plain := StandardMaterial3D.new()
		plain.albedo_color = Color(color)
		plain.roughness = 0.70
		if glow > 0.0:
			plain.emission_enabled = true
			plain.emission = Color(color)
			plain.emission_energy_multiplier = glow
		material = plain
	materials[key] = material
	return material

func _instance(kind: String, pos: Vector3, size: Vector3, color: String, tile: int = -1, rotation: Vector3 = Vector3.ZERO, glow: float = 0.0) -> void:
	var key := "%s:%s:%d:%f" % [kind, color, tile, glow]
	if not batches.has(key):
		batches[key] = {"kind":kind, "material":_material(color,tile,glow), "transforms":[]}
	var basis := Basis.from_euler(rotation).scaled(size)
	var transform:=Transform3D(basis,pos)
	if prop_active:
		# Rotation follows local primitive sizing, so car wheels retain their circular profile.
		transform=prop_transform*Transform3D(Basis.from_euler(rotation)*Basis.from_scale(size),pos)
		var local_box:=AABB(Vector3(-1,-.5,-1),Vector3(2,1,2)) if kind=="cylinder" else AABB(Vector3(-.5,-.5,-.5),Vector3.ONE)
		var transformed: AABB=transform*local_box
		prop_bounds=prop_bounds.merge(transformed) if prop_has_bounds else transformed
		prop_has_bounds=true
	batches[key]["transforms"].append(transform)

func _box(pos: Vector3, size: Vector3, color: String, tile: int = -1, glow: float = 0.0) -> void:
	_instance("box",pos,size,color,tile,Vector3.ZERO,glow)

func _cylinder(pos: Vector3, radius: float, height: float, color: String, rotation: Vector3 = Vector3.ZERO) -> void:
	_instance("cylinder",pos,Vector3(radius,height,radius),color,-1,rotation)

func _flush_batches() -> void:
	for key: String in batches:
		var batch: Dictionary = batches[key]
		var mesh: PrimitiveMesh
		if batch["kind"] == "cylinder":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius=1.0
			cylinder.bottom_radius=1.0
			cylinder.height=1.0
			cylinder.radial_segments=10
			cylinder.rings=1
			mesh=cylinder
		elif batch["kind"] == "sphere":
			var sphere := SphereMesh.new()
			sphere.radius=0.5
			sphere.height=1.0
			sphere.radial_segments=12
			sphere.rings=6
			mesh=sphere
		else:
			var cube := BoxMesh.new()
			cube.size=Vector3.ONE
			mesh=cube
		var multi := MultiMesh.new()
		multi.transform_format=MultiMesh.TRANSFORM_3D
		multi.mesh=mesh
		multi.instance_count=batch["transforms"].size()
		for index: int in range(multi.instance_count):
			multi.set_instance_transform(index,batch["transforms"][index])
		var instances := MultiMeshInstance3D.new()
		instances.multimesh=multi
		instances.material_override=batch["material"]
		add_child(instances)
	batches.clear()

func _label(text: String, pos: Vector3, scale_value: float = 0.008, yaw: float = 0.0) -> void:
	var label := Label3D.new()
	label.text=text
	label.position=pos
	label.rotation.y=yaw
	label.font_size=42
	label.pixel_size=scale_value
	label.modulate=Color("efe5cc")
	label.outline_size=5
	add_child(label)

func _obstacle(x: float, z: float, width: float, depth: float) -> void:
	if prop_active:
		var a: AABB=prop_transform*AABB(Vector3(x-width/2,0,z-depth/2),Vector3(width,.01,depth))
		obstacles.append(Rect2(Vector2(a.position.x,a.position.z),Vector2(a.size.x,a.size.z)).grow(ScalePolicy.BODY_RADIUS))
	else:
		obstacles.append(Rect2(Vector2(x-width/2,z-depth/2),Vector2(width,depth)).grow(ScalePolicy.BODY_RADIUS))

func _facade(center: Vector3, size: Vector3, face: int, entrance: bool) -> void:
	var along_x := face < 2
	var width := size.x if along_x else size.z
	var sign_value := 1.0 if face in [0,2] else -1.0
	var columns := maxi(2,int(width/2.6))
	var floors := maxi(1,int(size.y/2.8))
	for floor_index in range(floors):
		for column in range(columns):
			var along := -width/2.0 + (float(column)+0.5)*width/float(columns)
			if entrance and floor_index==0 and absf(along)<1.65: continue
			var point := center + Vector3(along,1.8+float(floor_index)*2.8,sign_value*(size.z/2.0+0.06)) if along_x else center + Vector3(sign_value*(size.x/2.0+0.06),1.8+float(floor_index)*2.8,along)
			var face_size := Vector3(1.1,1.55,0.10) if along_x else Vector3(0.10,1.55,1.1)
			_box(point,face_size,"dad1be",7)
			var glass_size := Vector3(0.90,1.34,0.05) if along_x else Vector3(0.05,1.34,0.90)
			var outward := Vector3(0,0,sign_value*0.07) if along_x else Vector3(sign_value*0.07,0,0)
			_box(point+outward,glass_size,"49656c")
			_box(point+outward*1.4,Vector3(0.04,1.34,0.05) if along_x else Vector3(0.05,1.34,0.04),"e1dacb")
			_box(point+outward*1.4,Vector3(0.90,0.04,0.05) if along_x else Vector3(0.05,0.04,0.90),"e1dacb")
			_box(point+Vector3(0,-0.82,0),Vector3(1.22,0.12,0.25) if along_x else Vector3(0.25,0.12,1.22),"c5bca9",7)

func _building(pos: Vector3, size: Vector3, color: String, front_entry: bool = false, storefront: bool = false, shell: bool = false) -> void:
	if shell:
		_box(pos+Vector3(0,6.7,0),Vector3(size.x,4.6,size.z),color,0)
		for side in [-1.0,1.0]:
			_box(pos+Vector3(side*7.9,2.2,0),Vector3(0.2,4.4,size.z),color,0)
			_box(pos+Vector3(side*4.525,2.2,9),Vector3(6.95,4.4,0.2),color,0)
		_box(pos+Vector3(0,3.72,9),Vector3(2.1,1.36,0.2),color,0)
		_box(pos+Vector3(0,2.2,-9),Vector3(size.x,4.4,0.2),color,0)
	else:
		_box(pos+Vector3(0,size.y/2.0,0),size,color,0)
	_obstacle(pos.x,pos.z,size.x,size.z)
	_box(pos+Vector3(0,size.y+0.04,0),Vector3(size.x+0.2,0.16,size.z+0.2),"dad2c5",5)
	for face in range(4):
		if storefront and face == 0: continue
		_facade(pos,size,face,front_entry and face==0)
	for direction in [-1.0,1.0]:
		_box(pos+Vector3(0,size.y+0.22,direction*size.z/2.0),Vector3(size.x+0.35,0.38,0.25),"c9c0ad",7)
		_box(pos+Vector3(direction*size.x/2.0,size.y+0.22,0),Vector3(0.25,0.38,size.z),"c9c0ad",7)
	_box(pos+Vector3(-size.x*0.23,size.y+0.48,-size.z*0.16),Vector3(1.0,0.65,1.2),"858b87")
	_box(pos+Vector3(size.x*0.30,size.y+0.7,-size.z*0.28),Vector3(0.6,1.1,0.6),"b0a195",0)

func _hip_roof(center: Vector3, width: float, depth: float, rise: float) -> void:
	var w:=width/2.0
	var d:=depth/2.0
	var r:=maxf(0.0,w-d*0.55)
	var nw:=center+Vector3(-w,0,-d)
	var ne:=center+Vector3(w,0,-d)
	var sw:=center+Vector3(-w,0,d)
	var se:=center+Vector3(w,0,d)
	var rw:=center+Vector3(-r,rise,0)
	var re:=center+Vector3(r,rise,0)
	var triangles: Array[Vector3]=[nw,ne,re,nw,re,rw,se,sw,rw,se,rw,re,sw,nw,rw,ne,se,re]
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in triangles: surface.add_vertex(vertex)
	surface.generate_normals()
	var roof:=MeshInstance3D.new()
	roof.mesh=surface.commit()
	roof.material_override=_material("e4e7e5",3)
	add_child(roof)

func _fence(x: float, z: float, width: float, depth: float = 0.14) -> void:
	_obstacle(x,z,width,depth)
	_box(Vector3(x,0.35,z),Vector3(width,0.40,0.24),"c9bba6",7)
	_box(Vector3(x,1.0,z),Vector3(width,0.07,0.08),"293831")
	for post in range(int(width/0.3)+1):
		_box(Vector3(x-width/2.0+float(post)*0.3,0.77,z),Vector3(0.035,0.75,0.035),"293831")
	for end in [-1.0,1.0]:
		_box(Vector3(x+end*width/2.0,0.6,z),Vector3(0.32,1.2,0.32),"d0bc9d",0)

func _tree(x: float, z: float, seed_value: int = 0) -> void:
	var origin:=Vector3(x,0,z)
	var yaw:=0.0
	var frame:=Basis(Vector3.UP,yaw)*Basis.from_scale(Vector3.ONE*ScalePolicy.TREE_SCALE)
	prop_transform=Transform3D(frame,origin-frame*origin)
	prop_active=true;prop_has_bounds=false
	_cylinder(Vector3(x,1.75,z),0.15,3.5,"74604a")
	_obstacle(x,z,0.55,0.55)
	for index in range(5):
		var angle:=float(index)*2.1+float(seed_value)*0.4
		var point:=Vector3(x+sin(angle)*0.8,3.45+float(index%2)*0.85,z+cos(angle)*0.6)
		_instance("sphere",point,Vector3(2.1,2.1,2.0),"c2d3a6",8)
	prop_active=false
	fitted_prop_bounds.append({"kind":"tree","origin":origin,"bounds":prop_bounds,"scale":ScalePolicy.TREE_SCALE,"yaw":yaw})

func _lamp(x: float, z: float) -> void:
	_cylinder(Vector3(x,2.0,z),0.065,4.0,"29362e")
	_obstacle(x,z,0.18,0.18)
	_box(Vector3(x,4.06,z),Vector3(0.42,0.46,0.42),"dec89d",-1,0.6)
	_box(Vector3(x,4.35,z),Vector3(0.50,0.08,0.50),"29362e")
	var light:=OmniLight3D.new()
	light.position=Vector3(x,3.7,z)
	light.light_color=Color("ffd2a1")
	light.omni_range=8.0
	light.light_energy=0.0
	add_child(light)
	lamps.append(light)

func _car(x: float, z: float, color: String, pickup: bool = false) -> void:
	var origin:=Vector3(x,0,z)
	var yaw:=PI/2 if pickup else 0.0
	var frame:=Basis(Vector3.UP,yaw)*Basis.from_scale(Vector3.ONE*ScalePolicy.CAR_SCALE)
	prop_transform=Transform3D(frame,origin-frame*origin)
	prop_active=true;prop_has_bounds=false
	_obstacle(x,z,4.7,2.0)
	_box(Vector3(x,0.63,z),Vector3(4.5,0.64,1.8),color)
	_box(Vector3(x-0.2,1.18,z),Vector3(2.25 if not pickup else 1.6,0.7,1.65),color)
	_box(Vector3(x-0.2,1.21,z+0.84),Vector3(1.75 if not pickup else 1.20,0.44,0.03),"43606a")
	_box(Vector3(x-0.2,1.21,z-0.84),Vector3(1.75 if not pickup else 1.20,0.44,0.03),"43606a")
	_box(Vector3(x+0.94,1.21,z),Vector3(0.04,0.44,1.45),"43606a")
	_box(Vector3(x+2.26,0.57,z),Vector3(0.05,0.15,1.45),"b1b2a5")
	for side in [-1.0,1.0]:
		for axle in [-1.45,1.45]: _cylinder(Vector3(x+axle,0.37,z+side*0.89),0.37,0.22,"252826",Vector3(PI/2,0,0))
		_box(Vector3(x+2.28,0.76,z+side*0.58),Vector3(0.04,0.22,0.35),"eee3ad",-1,0.15)
	prop_active=false
	fitted_prop_bounds.append({"kind":"car","origin":origin,"bounds":prop_bounds,"scale":ScalePolicy.CAR_SCALE,"yaw":yaw})

func _shop() -> void:
	_building(Vector3(0,0,1),Vector3(12,3.9,10),"e6d8c5",true,true)
	_box(Vector3(0,1.55,6.07),Vector3(10.4,2.2,0.12),"54766e")
	_box(Vector3(0,0.72,6.17),Vector3(10.6,0.60,0.12),"d1b98b",7)
	for x in [-4.8,-2.6,0.0,2.6,4.8]: _box(Vector3(x,1.7,6.20),Vector3(0.10,2.6,0.12),"c7b898",7)
	_box(Vector3(0,3.08,6.45),Vector3(11.4,0.16,1.3),"35664f")
	_box(Vector3(0,2.86,7.03),Vector3(11.4,0.35,0.07),"35664f")
	_label("CENTRAL MARKET",Vector3(0,3.43,6.25),0.008)
	for x in [-4.7,4.7]:
		_box(Vector3(x,0.40,6.8),Vector3(0.85,0.7,0.6),"86714c",6)
		_instance("sphere",Vector3(x,0.90,6.8),Vector3(0.8,0.7,0.7),"b7cca1",8)

func _apartment() -> void:
	_building(Vector3(-22,0,-7),Vector3(16,9.0,18),"f0e4d3",true,false,true)
	for side in [-1.0,1.0]: _box(Vector3(-22+side*1.1,1.7,2.18),Vector3(0.20,3.3,0.25),"dad1bb",7)
	_box(Vector3(-22,3.42,2.17),Vector3(2.4,0.22,0.35),"dad1bb",7)
	for step in range(3):
		_box(Vector3(-22,0.1+float(step)*0.08,4.9-float(step)*0.7),Vector3(3.2,0.2+float(step)*0.16,0.7),"ddd4c4",2)
	_label("APARTMENTS",Vector3(-22,3.85,2.20),0.008)
	# Fire escape and stoop rails make the apartment entrance recognizable.
	for floor_index in [1,2]:
		var y:=float(floor_index)*2.8+0.7
		_box(Vector3(-26.5,y,2.55),Vector3(3.8,0.10,1.2),"303d35")
		_box(Vector3(-26.5,y+0.65,3.12),Vector3(3.8,0.06,0.06),"303d35")
		for post in range(9): _box(Vector3(-28.3+float(post)*0.45,y+0.35,3.12),Vector3(0.04,0.70,0.04),"303d35")
		for rung in range(10): _box(Vector3(-25.5,y-float(rung)*0.23,2.45),Vector3(0.65,0.05,0.05),"303d35")

func _house() -> void:
	var center:=Vector3(22,0,-7)
	_building(center,Vector3(19,3.6,16),"ecddc8",true)
	_hip_roof(center+Vector3(0,3.82,0),20.1,17.1,2.0)
	_box(Vector3(22,1.62,1.10),Vector3(1.7,2.9,0.16),"b39772",6)
	_box(Vector3(22,0.16,2.9),Vector3(4.6,0.32,3.4),"dad0bd",2)
	_hip_roof(Vector3(22,3.4,2.1),5.2,3.6,0.7)
	for x in [19.9,24.1]: _box(Vector3(x,1.77,3.4),Vector3(0.18,3.1,0.18),"d6cab3",7)
	_box(Vector3(22,0.08,4.8),Vector3(2.6,0.16,2.4),"ddd5c8",2)
	for x in [16.0,28.0]:
		_box(Vector3(x,0.04,3.65),Vector3(7.3,0.12,4.6),"dde3ca",4)
		_box(Vector3(x,0.28,1.65),Vector3(6.8,0.42,0.90),"a6ac82",8)
		for flower in range(12):
			_instance("sphere",Vector3(x-3.0+float(flower)*0.53,0.59,1.77),Vector3(0.16,0.15,0.16),"e9d9a9" if flower%2==0 else "a685b1")
		_fence(x,6.0,8.4)
	_box(Vector3(22,0.08,6.1),Vector3(3.0,0.16,0.5),"dad0bd",2)
	_label("HOUSE FOR SALE",Vector3(28.2,1.35,5.6),0.005)
	_box(Vector3(28.2,0.66,5.52),Vector3(0.08,1.32,0.08),"c8b695",6)
	_box(Vector3(28.2,1.35,5.52),Vector3(2.4,0.62,0.06),"2c4b39")
	_box(Vector3(29,5.45,-11),Vector3(0.7,1.5,0.7),"d8c8b6",0)

var building_bounds: Array[AABB] = []
var grass_bounds: Array[Rect2] = []
func piece(label_text: String, pos: Vector3, size: Vector3, color: String, surface: int = 0) -> void:
	var tile: int=-1
	var tint: String=color
	if surface == 1:
		tile=0
		tint="f0e4d3"
	elif surface == 2:
		tile=2
		tint="e1dfd5"
	elif surface == 4:
		tile=3
		tint="e4e7e5"
	elif surface == 3:
		tile=5
		tint="c3c3b9"
		if label_text in ["Street","RearAlley","SideStreet","ShopParking"]:
			tile=1
			tint="d7d5cb"
		elif label_text == "HouseLawn":
			tile=4
			tint="dde3ca"
		elif label_text == "HouseDoor":
			tile=6
			tint="b39772"
		elif label_text == "ShopAwning":
			tile=-1
			tint="315e4c"
	if label_text == "EntrancePath":
		tile=2
		tint="e1dfd5"
	elif label_text == "ExteriorDoor":
		tile=6
		tint="b39772"
	elif label_text in ["EntryTrim","EntryLintel","WindowFrame","WindowSill"]:
		tile=7
	# Paving is cut around recessed tree soil, so two materials never share a face.
	if pos.y < 0 and ((surface == 2 and label_text in ["FrontSidewalk","HouseSidewalk","FarSidewalk","AlleySidewalk","InnerAlleySidewalk","SidewalkReturn","ApartmentSideWalkR","RearCourtyard","EastPaving"]) or label_text == "HouseLawn"):
		var slabs: Array[Rect2] = [Rect2(Vector2(pos.x-size.x/2,pos.z-size.z/2),Vector2(size.x,size.z))]
		for site in TreeLayout.TREE_SITES:
			var hole := Rect2(Vector2(site.x,site.z)-Vector2.ONE*TreeLayout.TREE_BED_SIZE/2,Vector2.ONE*TreeLayout.TREE_BED_SIZE)
			var remaining: Array[Rect2] = []
			for slab in slabs:
				if not slab.intersects(hole):
					remaining.append(slab)
					continue
				var cut := slab.intersection(hole)
				for part in [Rect2(slab.position,Vector2(cut.position.x-slab.position.x,slab.size.y)),Rect2(Vector2(cut.end.x,slab.position.y),Vector2(slab.end.x-cut.end.x,slab.size.y)),Rect2(Vector2(cut.position.x,slab.position.y),Vector2(cut.size.x,cut.position.y-slab.position.y)),Rect2(Vector2(cut.position.x,cut.end.y),Vector2(cut.size.x,slab.end.y-cut.end.y))]:
					if part.size.x > 0.001 and part.size.y > 0.001: remaining.append(part)
			slabs=remaining
		for slab in slabs:
			_box(Vector3(slab.get_center().x,pos.y,slab.get_center().y),Vector3(slab.size.x,size.y,slab.size.y),tint,tile)
	else:
		_box(pos,size,tint,tile)

func building(label_text: String, pos: Vector3, size: Vector3, color: String, windows: bool = true) -> void:
	size.y*=ScalePolicy.BACKGROUND_BUILDING_SCALE_Y
	var bounds := AABB(pos, size)
	building_bounds.append(bounds)
	if is_zero_approx(pos.y): _obstacle(pos.x+size.x/2,pos.z+size.z/2,size.x,size.z)
	if is_zero_approx(pos.y):
		piece(label_text+"Foundation",Vector3(pos.x+size.x/2,-0.08,pos.z+size.z/2),Vector3(size.x,0.16,size.z),"777567",2)
	piece(label_text, pos + size / 2.0, size, color, 1)
	piece(label_text + "Roof", pos + Vector3(size.x/2, size.y+0.1, size.z/2), Vector3(size.x+0.3, 0.2, size.z+0.3), "454647", 3)
	var front := Vector3.FORWARD if label_text == "OppositeBuilding" else Vector3.BACK
	if label_text == "OuterHouse": front = Vector3.RIGHT if pos.x < 0 else Vector3.LEFT
	var center := pos + size/2.0
	var door_center := Vector3(center.x,0,center.z) + front * (size.z/2 if front.z != 0 else size.x/2)
	if windows:
		for normal in [Vector3.BACK,Vector3.FORWARD,Vector3.LEFT,Vector3.RIGHT]:
			var tangent := Vector3.RIGHT if normal.z != 0 else Vector3.BACK
			var width: float = size.x if normal.z != 0 else size.z
			var depth: float = size.z if normal.z != 0 else size.x
			var columns := maxi(2,int(width/2.4))
			for row in range(int(size.y/3.24)):
				for col in range(columns):
					var offset := (float(col)+0.5)*width/columns-width/2
					if is_zero_approx(pos.y) and normal == front and row == 0 and absf(offset) < 1.4: continue
					var point: Vector3 = Vector3(center.x,pos.y+2.04+row*3.24,center.z)+normal*(depth/2+0.05)+tangent*offset
					window_layout_records.append({"at":point,"floor":pos.y+row*3.24,"ceiling":minf(pos.y+(row+1)*3.24,pos.y+size.y),"building":label_text,"row":row})
					facade_window(point,normal)
	if is_zero_approx(pos.y) and windows:
		entrance(door_center,front)

func facade_part(label_text: String, at: Vector3, size: Vector3, normal: Vector3, color: String) -> void:
	piece(label_text,at,size if normal.z != 0 else Vector3(size.z,size.y,size.x),color)

func facade_window(at: Vector3, normal: Vector3) -> void:
	facade_part("WindowFrame",at,Vector3(0.95,1.35,0.1),normal,"c7baa1")
	facade_part("WindowGlass",at+normal*0.065,Vector3(0.79,1.17,0.035),normal,"46595c")
	facade_part("WindowMullion",at+normal*0.09,Vector3(0.04,1.17,0.025),normal,"c7baa1")
	facade_part("WindowSill",at+Vector3(0,-0.72,0)+normal*0.07,Vector3(1.08,0.1,0.24),normal,"a69f90")

func entrance(at: Vector3, normal: Vector3) -> void:
	entrance_records.append({"at":at,"normal":normal})
	var tangent := Vector3.RIGHT if normal.z != 0 else Vector3.BACK
	facade_part("EntryRecess",at+Vector3.UP*1.475+normal*0.025,Vector3(1.55,2.95,0.045),normal,"252a27")
	facade_part("ExteriorDoor",at+Vector3.UP*1.425+normal*0.055,Vector3(1.18,2.85,0.065),normal,"4a493d")
	for side in [-1.0,1.0]:
		facade_part("EntryTrim",at+Vector3.UP*1.475+tangent*side*0.76+normal*0.13,Vector3(0.12,2.95,0.26),normal,"c7baa1")
	facade_part("EntryLintel",at+Vector3.UP*3.0+normal*0.13,Vector3(1.65,0.16,0.26),normal,"c7baa1")
	facade_part("DoorGlass",at+Vector3.UP*1.92+normal*0.10,Vector3(0.72,0.8,0.025),normal,"586e70")
	facade_part("DoorHandle",at+Vector3.UP*1.30+tangent*0.42+normal*0.14,Vector3(0.055,0.22,0.09),normal,"b6a87e")
	facade_part("EntryCanopy",at+Vector3.UP*3.28+normal*0.45,Vector3(2.0,0.12,1.0),normal,"414b44")
	# Flush paths join the nearest sidewalk; these background doors stay closed.
	var distance: float = 2.5
	if normal.x > 0: distance = -18.0-at.x
	elif normal.x < 0: distance = at.x-57.0
	elif normal.z < 0: distance = at.z-26.0
	elif at.z < 0: distance = -24.0-at.z
	distance = maxf(0.6,distance)
	facade_part("EntrancePath",at+normal*(distance/2)+Vector3(0,-0.052,0),Vector3(1.8,0.11,distance),normal,"a9a394")

func fence(a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	var along_x := absf(a.x-b.x) > absf(a.z-b.z)
	for index in range(int(ceil(length/0.6))+1):
		var at := a.lerp(b, float(index)/ceil(length/0.6))
		piece("FencePost", at+Vector3.UP*0.6, Vector3(0.065,1.2,0.065), "343c36")
	for height in [0.35, 1.0]:
		piece("FenceRail", (a+b)/2+Vector3.UP*height, Vector3(length,0.08,0.08) if along_x else Vector3(0.08,0.08,length), "343c36")
	_obstacle((a.x+b.x)/2,(a.z+b.z)/2,length if along_x else 0.1,0.1 if along_x else length)

func tree(at: Vector3) -> void:
	_tree(at.x,at.z,int(at.x))

func _build_block() -> void:
	var image:=Image.new()
	assert(image.load_webp_from_buffer(FileAccess.get_file_as_bytes("res://assets/neighborhood/exterior_atlas.webp"))==OK)
	image.generate_mipmaps()
	atlas=ImageTexture.create_from_image(image)
	for row in range(3):
		for column in range(3):
			var tile_image:=image.get_region(Rect2i(column*418,row*418,418,418))
			tile_image.generate_mipmaps()
			tile_textures.append(ImageTexture.create_from_image(tile_image))
	exterior_shader=load("res://scripts/exterior.gdshader")
	_box(Vector3(20.5,-0.20,1.5),Vector3(117,0.20,87),"c3c3b9",5)
	piece("Street", Vector3(20.5,-0.18,17), Vector3(117,0.3,10), "505452",3)
	piece("RearAlley", Vector3(20.5,-0.18,-19), Vector3(117,0.3,4), "555a57",3)
	# Split at intersections to avoid overlapping asphalt surfaces.
	for x in [-12.0,51.0]:
		for span in [Vector2(-42,-21),Vector2(-17,12),Vector2(22,45)]:
			piece("SideStreet",Vector3(x,-0.18,(span.x+span.y)/2),Vector3(6,0.3,span.y-span.x),"505452",3)
	# Sidewalks stop at side-road junctions instead of running across them.
	for span in [Vector2(-38,-15),Vector2(-9,48),Vector2(54,79)]:
		if span.x < 25 and span.y > 45:
			for segment in [Vector2(span.x,25),Vector2(45,span.y)]:
				piece("FrontSidewalk",Vector3((segment.x+segment.y)/2,-0.10,9.1),Vector3(segment.y-segment.x,0.18,6),"a9a394",2)
			piece("HouseSidewalk",Vector3(35,-0.10,10.15),Vector3(20,0.18,3.9),"a9a394",2)
		else:
			piece("FrontSidewalk",Vector3((span.x+span.y)/2,-0.10,9.1),Vector3(span.y-span.x,0.18,6),"a9a394",2)
		piece("FarSidewalk",Vector3((span.x+span.y)/2,-0.10,24),Vector3(span.y-span.x,0.18,4),"a9a394",2)
		piece("AlleySidewalk",Vector3((span.x+span.y)/2,-0.10,-22.5),Vector3(span.y-span.x,0.18,3),"a9a394",2)
		piece("InnerAlleySidewalk",Vector3((span.x+span.y)/2,-0.10,-15.7),Vector3(span.y-span.x,0.18,2.6),"a9a394",2)
	for x in [-16.5,-7.5,46.5,55.5]:
		for span in [Vector2(-42,-24),Vector2(-14.4,6.1),Vector2(26,45)]:
			piece("SidewalkReturn",Vector3(x,-0.10,(span.x+span.y)/2),Vector3(3,0.18,span.y-span.x),"a9a394",2)
	# Preserve the cloud-test stone curb finish around the prototype's street mouths.
	for span in [Vector2(-38,-15),Vector2(-9,48),Vector2(54,79)]:
		for z in [12.0,22.0,-21.0,-17.0]:
			_box(Vector3((span.x+span.y)/2,0.025,z),Vector3(span.y-span.x,0.12,0.12),"c8c4b9",7)
	for x in [-15.0,-9.0,48.0,54.0]:
		for span in [Vector2(-42,-21),Vector2(-17,12),Vector2(22,45)]:
			_box(Vector3(x,0.025,(span.x+span.y)/2),Vector3(0.12,0.12,span.y-span.x),"c8c4b9",7)
	piece("ApartmentSideWalkR", Vector3(8.5,-0.10,-2.10), Vector3(6.6,0.18,16.4), "a9a394",2)
	piece("ShopParking", Vector3(18,-0.10,-6.15), Vector3(12,0.18,8.3), "626560",3)
	piece("HouseRearYard", Vector3(35,-0.10,-14.2), Vector3(20,0.18,0.4), "686b5c",3)
	piece("RearCourtyard",Vector3(8,-0.10,-12.35),Vector3(34,0.18,4.1),"a9a394",2)
	# Keep the apartment roofline above the actual ceiling, not inside the rooms.
	building("ApartmentUpper",Vector3(-5.1,4.4,-10.3),Vector3(10.2,5.4,16.4),"8e5743")
	# Thin brick exterior skins preserve the original room finishes and door opening.
	for side in [-1.0,1.0]:
		piece("ApartmentBrickSide",Vector3(side*5.115,2.2,-2.1),Vector3(0.01,4.4,16.4),"f0e4d3",1)
		if side>0:
			piece("ApartmentBrickFront",Vector3(side*3.075,2.2,6.115),Vector3(4.05,4.4,0.01),"f0e4d3",1)
		else:
			piece("ApartmentWindowBrickLeft",Vector3(-4.81,2.2,6.115),Vector3(0.58,4.4,0.01),"f0e4d3",1)
			piece("ApartmentWindowBrickRight",Vector3(-1.885,2.2,6.115),Vector3(1.67,4.4,0.01),"f0e4d3",1)
			piece("ApartmentWindowBrickBottom",Vector3(-3.62,0.755,6.115),Vector3(1.8,1.51,0.01),"f0e4d3",1)
			piece("ApartmentWindowBrickTop",Vector3(-3.62,3.595,6.115),Vector3(1.8,1.61,0.01),"f0e4d3",1)
	# Exterior stone trim surrounds the real opening, leaving glazing and blinds clear.
	for x in [-4.59,-2.65]:
		facade_part("WindowFrame",Vector3(x,2.15,6.19),Vector3(0.14,1.42,0.18),Vector3.BACK,"c7baa1")
	facade_part("WindowFrame",Vector3(-3.62,2.86,6.19),Vector3(2.08,0.14,0.18),Vector3.BACK,"c7baa1")
	facade_part("WindowSill",Vector3(-3.62,1.44,6.25),Vector3(2.16,0.14,0.36),Vector3.BACK,"a69f90")
	for x in [-1.08,1.08]:
		facade_part("EntryTrim",Vector3(x,1.51,6.20),Vector3(0.14,3.02,0.2),Vector3.BACK,"c7baa1")
	# Solid head reveal bridges the original interior frame to the exterior lintel.
	facade_part("EntryLintel",Vector3(0,3.01,5.96),Vector3(2.1,0.20,0.58),Vector3.BACK,"c7baa1")
	facade_part("EntryLintel",Vector3(0,3.09,6.20),Vector3(2.30,0.16,0.2),Vector3.BACK,"c7baa1")
	facade_part("WindowSill",Vector3(0,-0.025,6.23),Vector3(2.1,0.07,0.32),Vector3.BACK,"a69f90")
	piece("ApartmentBrickRear",Vector3(0,2.2,-10.315),Vector3(10.24,4.4,0.01),"f0e4d3",1)
	piece("ApartmentBrickHeader",Vector3(0,3.715,6.115),Vector3(2.1,1.37,0.01),"f0e4d3",1)
	_obstacle(0,-2.1,10.2,16.4)
	load("res://scripts/interiors.gd").new().build(self)
	piece("CornerShopRoof",Vector3(17,3.7,2),Vector3(10.3,0.2,8.3),"454647",3)
	_hip_roof(Vector3(35,3.6,-5.5),20.8,17.8,3.2)
	_hip_roof(Vector3(35,3.4,4.1),5.2,3.6,0.7)
	for x in [32.9,37.1]: _box(Vector3(x,1.77,5.4),Vector3(0.18,3.1,0.18),"d6cab3",7)
	piece("HousePath",Vector3(35,-0.08,5.6),Vector3(2.4,0.14,5),"a9a394",2)
	for x in [29.25,40.75]:
		var lawn := Rect2(Vector2(x-4.25,3.3),Vector2(8.5,4.8))
		grass_bounds.append(lawn)
		piece("HouseLawn",Vector3(x,-0.045,5.7),Vector3(8.5,0.06,4.8),"586d3e",3)
		fence(Vector3(x-4.25,0,8.2),Vector3(x+4.25,0,8.2))
	fence(Vector3(25,0,3.2),Vector3(25,0,8.2))
	fence(Vector3(45,0,3.2),Vector3(45,0,8.2))
	_label("HOUSE FOR SALE",Vector3(40,1.45,8.3),0.005)
	piece("SaleSignPost",Vector3(40,0.65,8.3),Vector3(0.08,1.3,0.08),"c7baa1")
	# Rear buildings start beyond the alley, over nine metres behind the grow room.
	for x in [-5.0,7.0,19.0,31.0]:
		building("RearBuilding",Vector3(x,0,-31),Vector3(10,8,7),"806957")
		building("OppositeBuilding",Vector3(x,0,27),Vector3(10,7,7),"817363")
	# Outer lots flank the side roads, fully inside the expanded border.
	for x in [-28.0]: # East-edge exteriors are reorganized by east_expansion.gd.
		for z in [-9.0,27.0]:
			building("OuterHouse",Vector3(x,0,z),Vector3(7,6,7),"806957")
	# Side-road extensions are deliberately clear to both fence ends.
	for x in [-12.0,51.0]:
		for z in range(-34,39,4):
			if (z >= -22 and z <= -16) or (z >= 11 and z <= 23): continue
			piece("SideRoadStripe",Vector3(x,-0.012,z),Vector3(0.1,0.012,2.0),"c3a04c")
	# Leave a clear approach to both crosswalks beside the wider tree trunks.
	for i in range(4):TreeLayout.plant(self,TreeLayout.TREE_SITES[i])
	for x in [-4.0,18.0,41.0]:
		piece("LampPost",Vector3(x,2.0,23),Vector3(0.13,4,0.13),"303a36")
		piece("LampHead",Vector3(x,4,23),Vector3(0.45,0.25,0.45),"cfbd91")
	for x in range(-30,72,4):
		if (-17 < x and x < -7) or (46 < x and x < 56): continue
		for z in [16.7,17.0]:
			piece("RoadStripe",Vector3(x,-0.012,z),Vector3(2.4,0.012,0.1),"c3a04c")
	for x in [8.5,45.5]:
		for z in range(13,22,2):
			piece("Crosswalk",Vector3(x,-0.01,z),Vector3(2.8,0.01,0.65),"c3c0b0")
	for x in [14.0,18.0,22.0]:
		piece("ParkingLine",Vector3(x,0.004,-6.5),Vector3(0.06,0.014,6.2),"b9b9a9")
	# Continuous visible containment outside the side streets and rear alley.
	fence(Vector3(-32,0,-36),Vector3(73,0,-36))
	fence(Vector3(-32,0,39),Vector3(73,0,39))
	fence(Vector3(-32,0,-36),Vector3(-32,0,39))
	# The east fence moves outward; all core geometry stays in place.
	load("res://scripts/east_expansion.gd").new().build(self)
	_label("APARTMENTS",Vector3(0,3.45,6.16),0.006)
	_car(18,-6.5,"7d8686",true)
	_car(-1,20.7,"415b50")
	_car(32,13.4,"8d4540")
	for x in [-4.0,18.0,41.0]: _lamp(x,23.0)
	var sun := DirectionalLight3D.new()
	outdoor_sun = sun
	sun.rotation_degrees = Vector3(-48,-30,0)
	sun.light_color = Color("f4e4c9")
	sun.light_energy = 0.65
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=38.0
	add_child(sun)
	load("res://scripts/police_district.gd").new().build(self)
	police_station=load("res://scripts/police_station.gd").new()
	police_station.name="PoliceStation"
	add_child(police_station)
	police_station.build(self)
	_flush_batches()

func _build_controls() -> void:
	controls=CanvasLayer.new()
	controls.layer=4
	add_child(controls)
	pad=load("res://scripts/joystick.gd").new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	pad.offset_left=22
	pad.offset_right=222
	pad.offset_top=-245
	pad.offset_bottom=-45
	controls.add_child(pad)
	action=Button.new()
	action.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	action.offset_left=-242
	action.offset_right=-22
	action.offset_top=-125
	action.offset_bottom=-45
	action.focus_mode=Control.FOCUS_NONE
	_style_button(action)
	action.pressed.connect(_interact)
	controls.add_child(action)
	controls.hide()
	mobile_hud=load("res://scripts/mobile_hud.gd").new();mobile_hud.setup(self)

func _style_button(button: Button) -> void:
	for state in ["normal","hover","pressed","disabled"]:
		var style:=StyleBoxFlat.new()
		style.bg_color=Color("183e32") if state=="pressed" else Color("14231f")
		style.border_color=Color("71bb91")
		style.set_border_width_all(2)
		style.set_corner_radius_all(10)
		button.add_theme_stylebox_override(state,style)
	button.add_theme_color_override("font_color",Color("eef6eb"))
	button.add_theme_color_override("font_disabled_color",Color("92a398"))

func _build_door_hinge() -> void:
	door_pivot=Node3D.new()
	door_pivot.position=Vector3(-0.94,1.48,5.84)
	host.add_child(door_pivot)
	var outside_handle:=MeshInstance3D.new()
	var handle_mesh:=SphereMesh.new()
	handle_mesh.radius=0.075
	handle_mesh.height=0.15
	outside_handle.mesh=handle_mesh
	outside_handle.material_override=_material("d0ae69")
	outside_handle.position=Vector3(1.58,-0.14,0.13)
	door_pivot.add_child(outside_handle)
	for part_name in ["Door","DoorPanelTop","DoorPanelBottom","DoorKnob","Peephole"]:
		var part=host.get_node_or_null(part_name)
		if part != null:
			part.reparent(door_pivot,true)

func leave_apartment() -> void:
	if active or transitioning or host._any_modal_open() or host.customer_waiting: return
	if not door_open: _toggle_door()
	_arrive_outside()

func _toggle_door() -> void:
	if transitioning or door_busy:return
	if not door_open:door_open_angle=PI/2 if host.camera.global_position.z>=door_pivot.global_position.z else -PI/2
	door_busy=true;door_pass_through=true;collision_timer=0.0
	door_open=not door_open
	var tween:=create_tween()
	tween.tween_property(door_pivot,"rotation:y",door_open_angle if door_open else 0.0,0.35)
	tween.finished.connect(func():door_busy=false;_refresh_apartment_door_collision())
	host.status_label.text="Door opened. Walk through when ready." if door_open else "Apartment door closed."
func _refresh_apartment_door_collision() -> void:
	if door_busy:return
	var point:=door_pivot.to_local(host.camera.global_position)
	var occupied: bool=Vector2(point.x,point.z).distance_to(Vector2(clampf(point.x,0.0,1.88),0.0))<0.40
	if door_pass_through!=occupied:collision_timer=0.0
	door_pass_through=occupied

func _arrive_outside() -> void:
	active=true
	saved_indoor_sun_visible=host.sun_light.visible
	host._reset_world_pointer()
	host._cancel_camera_view_tween()
	host.current_view="walking"
	host.camera.position.y=WALK_EYE_HEIGHT
	host.camera.fov=78.0
	host.status_label.text="Walk through the open doorway. You can close the door from either side."
	host.camera.environment=host.world_environment_ref if _indoors(host.camera.position) else outdoor_environment
	host._refresh_navigation_ui()

func end_walk() -> void:
	if not active: return
	active=false
	host.camera.environment=null
	host.sun_light.visible=saved_indoor_sun_visible
	controls.hide()
	pad.release()
	pointer=-99
	host.current_room="main"
	host.room_ring=host.main_room_ring
	host.current_view="walking"

func refresh_controls() -> void:
	for button in [host.left_button,host.right_button,host.forward_button,host.back_button,host.contextual_button,host.door_quick_button]:
		button.hide()
	for label in [host.view_label,host.status_label]:
		label.add_theme_color_override("font_outline_color",Color("17251f"))
		label.add_theme_constant_override("outline_size",4)
	host.view_label.text="Apartment" if _indoors(host.camera.position) else "Neighborhood"

func handle_input(event: InputEvent) -> void:
	if host._any_modal_open() or host.daily_report_pending:
		pointer=-99
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_P:
			host._toggle_phone()
		elif event.keycode==KEY_E:
			_interact()
	if event is InputEventScreenTouch:
		if not event.pressed:
			if pointer==event.index:
				_tap(event.position)
				pointer=-99
		elif pointer==-99 and not _over_ui(event.position):
			pointer=event.index
			last_pointer=event.position
			tap_start=event.position
			tap_distance=0.0
	elif event is InputEventScreenDrag and event.index==pointer:
		tap_distance=maxf(tap_distance,event.position.distance_to(tap_start))
		_look(event.position-last_pointer)
		last_pointer=event.position
	elif event is InputEventMouseButton and event.device!=-1 and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed and not _over_ui(event.position):
			pointer=-1
			tap_start=event.position
			tap_distance=0.0
		elif not event.pressed and pointer==-1:
			_tap(event.position)
			pointer=-99
	elif event is InputEventMouseMotion and event.device!=-1 and pointer==-1:
		tap_distance=maxf(tap_distance,event.position.distance_to(tap_start))
		_look(event.relative)

func _over_ui(point: Vector2) -> bool:
	return (pad.is_visible_in_tree() and pad.get_global_rect().has_point(point)) or (action.is_visible_in_tree() and action.get_global_rect().has_point(point)) or host._pointer_over_room_ui(point)

func _look(motion: Vector2) -> void:
	host.camera.rotation.y-=motion.x*0.004
	host.camera.rotation.x=clampf(host.camera.rotation.x-motion.y*0.003,-0.65,0.65)

func _indoors(pos: Vector3) -> bool:
	return pos.x > -5.1 and pos.x < 5.1 and pos.z > -10.3 and pos.z < 6.1

func _process(delta: float) -> void:
	if door_pass_through and not door_busy:_refresh_apartment_door_collision()
	if mobile_hud!=null:mobile_hud.update(delta)
	if location_ops!=null:location_ops.update(delta)
	if property_opportunity!=null: property_opportunity.update(delta)
	client_visits.update(delta)
	# Keep the real neighborhood lit through the apartment window with its door closed.
	weather.update(delta)
	if not active:
		if host.gameplay_ready and not host.tutorial_active and not in_station and not host._any_modal_open() and not host.daily_report_pending and (host.current_view in host.main_room_ring or host.current_view in host.grow_room_ring):
			_arrive_outside()
		else: return
	collision_timer-=delta
	if collision_timer<=0.0:
		interior_obstacles.clear()
		_collect_colliders(host)
		map_obstacles.clear()
		_collect_map_colliders(self)
		collision_timer=0.3
	var indoors: bool=_indoors(host.camera.position)
	host.current_room=("grow" if host.camera.position.z < -4.0 else "main") if indoors else "neighborhood"
	host.room_ring=host.grow_room_ring if host.current_room=="grow" else host.main_room_ring
	host.camera.environment=host.world_environment_ref if indoors else outdoor_environment
	host.sun_light.visible=false
	var blocked: bool=host._any_modal_open() or host.daily_report_pending or transitioning
	controls.visible=not blocked
	if blocked:
		pointer=-99
		pad.release()
		return
	var turn:=float(Input.is_physical_key_pressed(KEY_LEFT))-float(Input.is_physical_key_pressed(KEY_RIGHT))
	host.camera.rotation.y+=turn*delta*1.65
	var movement: Vector2=pad.value
	movement+=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	movement=movement.limit_length(1.0)
	if bench_seating.seated>=0:
		if movement.length()>0.15:bench_seating.stand()
		if bench_seating.seated>=0:movement=Vector2.ZERO
	if couch_seated:
		if movement.length()>0.15:_toggle_couch()
		else:movement=Vector2.ZERO
	var step: Vector3=Basis(Vector3.UP,host.camera.rotation.y)*Vector3(movement.x,0,movement.y)*minf(delta,0.05)*3.4
	var local: Vector3=host.camera.position-ORIGIN
	var next:=local+Vector3(step.x,0,0)
	if _walkable(next): local=next
	next=local+Vector3(0,0,step.z)
	if _walkable(next): local=next
	if not couch_seated and bench_seating.seated<0:
		local.y=(police_station.eye_height(ORIGIN+local) if police_station!=null and police_station.covers(ORIGIN+local) else WALK_EYE_HEIGHT)-ORIGIN.y
	host.camera.position=ORIGIN+local
	host.view_label.text="Apartment" if _indoors(host.camera.position) else "Neighborhood"
	var target:=_near_target()
	action.visible=not target.is_empty()
	action.disabled=target.is_empty()
	action.text=("CLOSE APARTMENT DOOR" if door_open else "OPEN APARTMENT DOOR") if target=="apartment" else (("INSPECT HOUSE" if host.property_offer_unlocked else "HOUSE | NOT AVAILABLE YET") if target=="house" else ("USE "+target.trim_prefix("station_").replace("_"," ").to_upper() if target.begins_with("station_") else "APPROACH A STATION OR ENTRANCE"))
	if target.begins_with("housecontrol_"): action.text=house_controls.title(target.trim_prefix("housecontrol_"))
	if target.begins_with("operation_"):action.text="USE "+target.trim_prefix("operation_").replace("_"," ").to_upper()
	if target.begins_with("police_"):action.text=police_station.title(target)
	if target.begins_with("bench_"):action.text="STAND UP" if bench_seating.seated>=0 else "SIT ON BENCH"
	if target=="couch":action.text="STAND UP" if couch_seated else "SIT ON COUCH"
	if target=="station_door": action.text="CHECK DOOR"
	action.text=action.text.replace("APARTMENT DOOR","DOOR").replace("APARTMENT COMPUTER","COMPUTER").replace("HOUSE COMPUTER","COMPUTER").replace("HOUSE DETAILS","HOUSE").replace("NOT AVAILABLE YET","LOCKED")
	if target.begins_with("mapdoor_"):
		var map_door: Node3D = get_node(NodePath(target.trim_prefix("mapdoor_")))
		action.text = ("CLOSE " if map_door.opened else "OPEN ")+_door_title(map_door)
		if map_door.name == "HouseEntrance":
			if not host.property_offer_unlocked: action.text="HOUSE | NOT AVAILABLE YET"
			elif not map_door.opened and not property_opportunity.touring: action.text="VIEW HOUSE DETAILS"
	var room_title := _map_room(host.camera.position)
	if not room_title.is_empty(): host.view_label.text = room_title
	if host.customer_waiting:
		pass # Compact visitor alert keeps its countdown visible.

func _walkable(pos: Vector3) -> bool:
	var world: Vector3=pos+ORIGIN
	if police_station!=null and police_station.covers(world):return police_station.walkable(world)
	if absf(world.x) < 0.76 and world.z >= 3.3 and world.z <= 8.9:
		if not door_open and not door_pass_through and world.z >= 5.55 and world.z <= 6.3: return false
		if world.z>=5.55: return true
	if _indoors(world):
		if world.x> -4.72 and world.x< -2.52 and world.z>5.76: return false
		for rect in interior_obstacles:
			if rect.has_point(Vector2(world.x,world.z)): return false
		return true
	if pos.x < -31.7 or pos.x > 200.7 or pos.z < -35.7 or pos.z > 38.7: return false
	for rect in map_obstacles:
		if rect.has_point(Vector2(world.x,world.z)): return false
	for rect in obstacles:
		if rect.has_point(Vector2(pos.x,pos.z)): return false
	return true

func _near_target() -> String:
	if couch_seated:return "couch"
	var police_target:String=police_station.target() if police_station!=null else ""
	if not police_target.is_empty():return police_target
	var bench_target:String=bench_seating.target()
	if not bench_target.is_empty():return bench_target
	if _indoors(host.camera.position) and Vector2(host.camera.position.x+2.28,host.camera.position.z-3.07).length()<2.0:return "couch"
	var house_target: String=house_controls.nearby()
	if not house_target.is_empty(): return "housecontrol_"+house_target
	var operation_target: String=location_ops.target() if location_ops!=null else ""
	if not operation_target.is_empty():return "operation_"+operation_target
	if host.customer_waiting and _station_reachable("station_door"): return "station_door"
	var nearby_door := _near_map_door()
	if nearby_door != null: return "mapdoor_"+str(nearby_door.name)
	var pos: Vector3=host.camera.position-ORIGIN
	if absf(host.camera.position.x) < 2.7 and host.camera.position.z > 3.3 and host.camera.position.z < 10.0: return "apartment"
	if Vector2(pos.x-HOUSE_ENTRY.x,pos.z-HOUSE_ENTRY.z).length()<2.25: return "house"
	return _near_station()

func _interact() -> void:
	if not active or host._any_modal_open() or host.daily_report_pending: return
	var target:=_near_target()
	if target.begins_with("police_"):
		police_station.use(target)
		return
	if target.begins_with("bench_"):
		bench_seating.use(target)
		return
	if target=="couch":
		_toggle_couch()
		return
	if target.begins_with("operation_"):
		location_ops.use(target.trim_prefix("operation_"))
		return
	if target.begins_with("housecontrol_"):
		house_controls.use(target.trim_prefix("housecontrol_"))
		return
	if target.begins_with("mapdoor_"):
		_use_map_door(target.trim_prefix("mapdoor_"))
		return
	if target.begins_with("station_"):
		_open_station(target)
		return
	match target:
		"apartment":
			_toggle_door()
		"house":
			property_opportunity.show_details()


func _collect_colliders(node: Node) -> void:
	if node==door_pivot and (door_busy or door_pass_through):return
	if node==self or str(node.name).contains("Worker"): return
	if node is MeshInstance3D and node.is_visible_in_tree() and node.mesh != null:
		var bounds: AABB=node.global_transform*node.get_aabb()
		if bounds.position.y < ScalePolicy.BODY_HEIGHT and bounds.end.y > 0.35 and maxf(bounds.size.x,bounds.size.z)>0.3 and bounds.position.x < 5.3 and bounds.end.x > -5.3 and bounds.position.z < 6.3 and bounds.end.z > -10.3:
			interior_obstacles.append(Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z)).grow(ScalePolicy.BODY_RADIUS))
	for child in node.get_children(): _collect_colliders(child)

func _station_reachable(id: String) -> bool:
	for spec in host.ROOM_DIRECT_STATIONS:
		if spec.id!=id or spec.view.is_empty() or spec.room!=host.current_room: continue
		if id=="station_tent2" and host.grow_tent_count<2: return false
		if id=="station_tent3" and host.grow_tent_count<3: return false
		var offset: Vector3=spec.pos-host.camera.position
		offset.y=0
		return offset.length()<2.7 and (-host.camera.global_basis.z).dot(offset.normalized())>0.25
	return false

func _near_station() -> String:
	var closest := ""
	var distance := 2.7
	for spec in host.ROOM_DIRECT_STATIONS:
		if not _station_reachable(spec.id): continue
		var d: float=host.camera.position.distance_to(spec.pos)
		if d<distance:
			distance=d
			closest=spec.id
	return closest

func _tap(point: Vector2) -> void:
	if tap_distance>24.0: return
	if police_station!=null and police_station.tap(point):return
	if bench_seating.tap(point):return
	if _tap_apartment_light(point):return
	if _near_target()=="couch":
		var at:=Vector3(-1.78,0.8,3.07)
		if couch_seated or (not host.camera.is_position_behind(at) and host.camera.unproject_position(at).distance_to(point)<150):
			var now:=Time.get_ticks_msec()
			if last_tap_station=="couch" and now-last_tap_time<420:_toggle_couch();last_tap_station=""
			else:last_tap_station="couch";last_tap_time=now;host.status_label.text="Double tap the couch to sit. Move the stick to stand up."
			return
	if house_controls.tap(point): return
	var op: String=location_ops.target()
	var op_position: Vector3=location_ops.APT_PC if op=="apartment_computer" else (location_ops.HOUSE_PC if op=="house_computer" else location_ops.CHECKOUT)
	if not op.is_empty() and not host.camera.is_position_behind(op_position) and host.camera.unproject_position(op_position).distance_to(point)<150:
		var tick := Time.get_ticks_msec()
		if last_tap_station==op and tick-last_tap_time<420:
			last_tap_station=""
			location_ops.use(op)
		else:
			last_tap_station=op
			last_tap_time=tick
			host.status_label.text="Double tap to use "+op.replace("_"," ")+"."
		return
	if house_controls.tap(point): return
	var door := _near_map_door()
	if door != null:
		var door_at: Vector3 = door.get_node("Leaf").to_global(Vector3(door.width/2,1.3,0))
		if not host.camera.is_position_behind(door_at) and host.camera.unproject_position(door_at).distance_to(point)<110:
			var key := "mapdoor_"+str(door.name)
			var tick := Time.get_ticks_msec()
			if last_tap_station==key and tick-last_tap_time<420:
				last_tap_station=""
				_use_map_door(str(door.name))
			else:
				last_tap_station=key
				last_tap_time=tick
				host.status_label.text="Double tap to use this door."
			return
	if tap_distance>24.0: return
	var id: String=host._direct_station_at(point)
	if not _station_reachable(id):
		last_tap_station=""
		return
	var now := Time.get_ticks_msec()
	if id==last_tap_station and now-last_tap_time<420:
		last_tap_station=""
		_open_station(id)
	else:
		last_tap_station=id
		last_tap_time=now
		host.status_label.text="Double tap to use this station."

func _open_station(id: String) -> void:
	if not active or not _station_reachable(id): return
	walk_position=host.camera.position
	walk_rotation=host.camera.rotation
	in_station=true
	end_walk()
	opening_station=true
	host._approach_station_then_open(id)
	opening_station=false

func handle_view_request(view_name: String) -> bool:
	if opening_station: return false
	if in_station and (view_name in host.main_room_ring or view_name in host.grow_room_ring):
		in_station=false
		host._cancel_camera_view_tween()
		host.camera.position=walk_position
		host.camera.rotation=walk_rotation
		_arrive_outside()
		host.status_label.text="Walk freely. Double tap a nearby station to use it."
		return true
	if active: end_walk()
	return false


func _queue_screen_layout() -> void:
	if layout_queued: return
	layout_queued=true
	call_deferred("_update_screen_layout")

func _update_screen_layout() -> void:
	layout_queued=false
	var window: Window=host.get_tree().root
	var landscape: bool=window.size.x>window.size.y
	var base := Vector2i(1440,900) if landscape else Vector2i(720,1280)
	if window.content_scale_aspect!=Window.CONTENT_SCALE_ASPECT_EXPAND:
		window.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	if window.content_scale_size!=base: window.content_scale_size=base
	var width: float=host.get_viewport().get_visible_rect().size.x
	# Preserve portrait touch sizes; center the phone menu on a wider screen.
	var margin: float=maxf(26.0,(width-668.0)*0.5) if landscape else 26.0
	host.phone_panel.offset_left=margin
	host.phone_panel.offset_right=-margin
	host.phone_panel.offset_top=108.0 if landscape else 132.0
	host.phone_panel.offset_bottom=-26.0
	host._reset_world_pointer()
	pointer=-99
	pad.release()



func _interior_piece(id: String, at: Vector3, size: Vector3, color: String, kind: int = 0) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = id
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material("f0e4d3",0) if kind==1 else (_material(color,6) if kind==3 else (_material(color,2) if kind==2 else _material(color)))
	add_child(mesh)
	mesh.position = at
	return mesh

func _surface(_kind: int, color: String) -> Material:
	return _material(color)

func _collect_map_colliders(node: Node) -> void:
	if node.name=="Leaf" and node.get_parent() in map_doors and (node.get_parent().busy or node.get_parent().pass_through):return
	if node is MeshInstance3D and node.mesh != null and not node.get_meta("no_collision",false):
		var bounds: AABB = node.global_transform*node.get_aabb()
		if bounds.position.y < ScalePolicy.BODY_HEIGHT and bounds.end.y > 0.35 and maxf(bounds.size.x,bounds.size.z)>0.3 and bounds.position.x > 11 and bounds.end.x < 46:
			map_obstacles.append(Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z)).grow(ScalePolicy.BODY_RADIUS))
	if node is CollisionShape3D and node.get_parent() is StaticBody3D and node.shape is BoxShape3D:
		var bounds: AABB = node.global_transform*AABB(-node.shape.size/2,node.shape.size)
		if bounds.position.y < ScalePolicy.BODY_HEIGHT and bounds.end.y > 0.35:
			map_obstacles.append(Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z)).grow(ScalePolicy.BODY_RADIUS))
	for child in node.get_children(): _collect_map_colliders(child)

func _near_map_door() -> Node3D:
	var nearest: Node3D = null
	var distance := 2.5
	for door in map_doors:
		var center: Vector3 = door.get_node("Leaf").to_global(Vector3(door.width/2,1.64,0))
		var offset: Vector3 = center-host.camera.position
		var d := offset.length()
		if d < distance and (-host.camera.global_basis.z).dot(offset.normalized()) > 0.15 and _door_line_clear(center):
			nearest=door
			distance=d
	return nearest

func _door_title(door: Node3D) -> String:
	match str(door.name):
		"HouseEntrance": return "HOUSE DOOR"
		"ShopEntrance": return "MARKET DOOR"
		"StockroomDoor": return "STOCKROOM DOOR"
		"BathroomDoor": return "BATHROOM DOOR"
		"BedroomDoor": return "BEDROOM DOOR"
	return "DOOR"

func _use_map_door(id: String) -> void:
	var door: Node3D = get_node_or_null(NodePath(id))
	if door == null or door != _near_map_door(): return
	if id=="HouseEntrance" and not host.property_offer_unlocked:
		host.status_label.text="This house is not available yet. Watch for Rod's property offer."
		return
	if id=="HouseEntrance" and not door.opened and not property_opportunity.touring:
		property_opportunity.show_details()
		return
	door.toggle(host.camera.position)

func _map_room(pos: Vector3) -> String:
	if police_station!=null and police_station.covers(pos):return police_station.room_title(pos)
	if pos.x>25 and pos.x<45 and pos.z> -14 and pos.z<3: return "HOUSE TOUR"
	if pos.x>12 and pos.x<22 and pos.z> -2 and pos.z<6: return "CENTRAL MARKET"
	return ""


func _door_line_clear(center: Vector3) -> bool:
	var from: Vector3 = host.camera.position
	var distance := from.distance_to(center)
	var steps := int(maxf(0,distance-0.5)/0.15)
	for i in range(1,steps+1):
		if not _walkable(from.lerp(center,float(i)*0.15/distance)-ORIGIN): return false
	return true

func _toggle_couch() -> void:
	if couch_seated:
		host.camera.position=couch_stand
		couch_seated=false
	else:
		couch_stand=host.camera.position
		couch_seated=true
		host.camera.position=Seating.eyes(Vector3(-1.785,0,3.035),0,ScalePolicy.SEAT_HEIGHT)
		host.camera.rotation=Vector3.ZERO
	host.status_label.text="Relaxing on the couch. Move to stand up." if couch_seated else "Back on your feet."

func _tap_apartment_light(point: Vector2) -> bool:
	if not _indoors(host.camera.position) or host._any_modal_open():return false
	var id: String=host._room_interaction_at(point)
	if id not in ["main_light_switch","floor_lamp"]:return false
	var at:=Vector3(1.42,1.47,5.72) if id=="main_light_switch" else Vector3(-3.78,1.35,3.35)
	if host.camera.global_position.distance_to(at)>2.7:return false
	last_tap_station=""
	return host._activate_room_interaction(id)
