extends Node3D
# First exterior: isolated geometry and navigation; career simulation stays in main.
const ORIGIN := Vector3(22, 0, 4)
var host: Node3D
var active := false
var transitioning := false
var door_open := false
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
	position = ORIGIN
	visible = true
	outdoor_environment=Environment.new()
	outdoor_environment.background_mode=Environment.BG_COLOR
	outdoor_environment.background_color=Color("b5c7d0")
	outdoor_environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	outdoor_environment.ambient_light_color=Color("c6d0d1")
	outdoor_environment.ambient_light_energy=0.4
	_build_block()
	_build_controls()
	_build_door_hinge()
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
const APARTMENT_ENTRY := Vector3(-22, 1.64, 4.8)
const HOUSE_ENTRY := Vector3(22, 1.64, 3.1)

func _material(color: String, tile: int = -1, glow: float = 0.0) -> Material:
	var key := "%s:%d:%f" % [color, tile, glow]
	if materials.has(key): return materials[key]
	var material: Material
	if tile >= 0:
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
	batches[key]["transforms"].append(Transform3D(basis, pos))

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
	obstacles.append(Rect2(Vector2(x-width/2.0-0.22,z-depth/2.0-0.22),Vector2(width+0.44,depth+0.44)))

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
	_cylinder(Vector3(x,1.75,z),0.15,3.5,"74604a")
	_obstacle(x,z,0.55,0.55)
	for index in range(5):
		var angle:=float(index)*2.1+float(seed_value)*0.4
		var point:=Vector3(x+sin(angle)*0.8,3.45+float(index%2)*0.85,z+cos(angle)*0.6)
		_instance("sphere",point,Vector3(2.1,2.1,2.0),"c2d3a6",8)

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
	_obstacle(x,z,4.7,1.9)
	_box(Vector3(x,0.63,z),Vector3(4.5,0.64,1.8),color)
	_box(Vector3(x-0.2,1.18,z),Vector3(2.25 if not pickup else 1.6,0.7,1.65),color)
	_box(Vector3(x-0.2,1.21,z+0.84),Vector3(1.75 if not pickup else 1.20,0.44,0.03),"43606a")
	_box(Vector3(x-0.2,1.21,z-0.84),Vector3(1.75 if not pickup else 1.20,0.44,0.03),"43606a")
	_box(Vector3(x+0.94,1.21,z),Vector3(0.04,0.44,1.45),"43606a")
	_box(Vector3(x+2.26,0.57,z),Vector3(0.05,0.15,1.45),"b1b2a5")
	for side in [-1.0,1.0]:
		for axle in [-1.45,1.45]: _cylinder(Vector3(x+axle,0.4,z+side*0.89),0.37,0.22,"252826",Vector3(PI/2,0,0))
		_box(Vector3(x+2.28,0.76,z+side*0.58),Vector3(0.04,0.22,0.35),"eee3ad",-1,0.15)

func _shop() -> void:
	_building(Vector3(0,0,1),Vector3(12,3.9,10),"e6d8c5",true,true)
	_box(Vector3(0,1.55,6.07),Vector3(10.4,2.2,0.12),"54766e")
	_box(Vector3(0,0.72,6.17),Vector3(10.6,0.60,0.12),"d1b98b",7)
	for x in [-4.8,-2.6,0.0,2.6,4.8]: _box(Vector3(x,1.7,6.20),Vector3(0.10,2.6,0.12),"c7b898",7)
	_box(Vector3(0,3.08,6.45),Vector3(11.4,0.16,1.3),"35664f")
	_box(Vector3(0,2.86,7.03),Vector3(11.4,0.35,0.07),"35664f")
	_label("CORNER MARKET",Vector3(0,3.43,6.25),0.008)
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
	# Ground continues beneath every background lot and beyond the playable fence.
	_box(Vector3(0,-0.20,0),Vector3(128,0.3,112),"c3c3b9",5)
	# Junctions belong to the main road / alley, so branches stop at their edges.
	# Eight metres of main-road continuation and six metres of side-road reserve.
	_box(Vector3(0,-0.01,15),Vector3(100,0.16,10),"d7d5cb",1)
	_box(Vector3(0,-0.01,-20),Vector3(84,0.16,4),"d7d5cb",1)
	for x in [-38.0,38.0]:
		_box(Vector3(x,-0.01,-4),Vector3(8,0.16,28),"d7d5cb",1) # -18 to 10
		_box(Vector3(x,-0.01,-25),Vector3(8,0.16,6),"d7d5cb",1) # -28 to -22
		_box(Vector3(x,-0.01,25),Vector3(8,0.16,10),"d7d5cb",1) # 20 to 30
	_box(Vector3(-10.5,-0.01,-4),Vector3(6.5,0.16,28),"d7d5cb",1)
	# Sidewalks and curbs stop at every street mouth instead of crossing it.
	var north_spans: Array[Vector2]=[Vector2(-50,-42),Vector2(-34,-13.75),Vector2(-7.25,34),Vector2(42,50)]
	var south_spans: Array[Vector2]=[Vector2(-50,-42),Vector2(-34,34),Vector2(42,50)]
	for spans in [north_spans,south_spans]:
		var north: bool=spans==north_spans
		for span: Vector2 in spans:
			var center: float=(span.x+span.y)/2.0
			var width: float=span.y-span.x
			_box(Vector3(center,0.08,8 if north else 22),Vector3(width,0.20,4),"e1dfd5",2)
			_box(Vector3(center,0.13,10 if north else 20),Vector3(width,0.26,0.18),"c8c4b9",7)
			for joint in range(int(ceil(span.x/2.0)),int(floor(span.y/2.0))+1):
				_box(Vector3(float(joint)*2.0,0.184,8 if north else 22),Vector3(0.025,0.012,3.8),"838780")
	_box(Vector3(-32,0.08,-6),Vector3(4,0.20,24),"dfdcd2",2)
	_box(Vector3(32.7,0.08,-6),Vector3(2.6,0.20,24),"dfdcd2",2)
	_box(Vector3(-6.9,0.08,-8),Vector3(0.65,0.20,20),"dfdcd2",2)
	for x in [-43.0,43.0]:
		_box(Vector3(x,0.08,-4),Vector3(2,0.20,28),"dfdcd2",2)
		_box(Vector3(x,0.08,25),Vector3(2,0.20,10),"dfdcd2",2)
	# Keep markings out of junction centres; crossings sit beside each junction.
	for x in [-31.5,-5.5,31.5]:
		for stripe in range(7):
			_box(Vector3(x,0.083,10.8+float(stripe)*1.35),Vector3(3.0,0.01,0.55),"deded3")
	for span in [Vector2(-50,-42.6),Vector2(-33.4,-14.35),Vector2(-6.65,33.4),Vector2(42.6,50)]:
		for z in [14.85,15.15]:
			_box(Vector3((span.x+span.y)/2.0,0.083,z),Vector3(span.y-span.x,0.012,0.10),"d8b257")
	for x in [-38.0,38.0]:
		for span in [Vector2(-28,-22.6),Vector2(-17.4,9.4),Vector2(20.6,30)]:
			for offset in [-0.15,0.15]:
				_box(Vector3(x+offset,0.083,(span.x+span.y)/2.0),Vector3(0.10,0.012,span.y-span.x),"d8b257")
	_apartment()
	_shop()
	_house()
	# Parking sits behind the shop and opens onto the rear alley.
	_box(Vector3(0,0,-11.4),Vector3(13,0.16,12.6),"c6c5be",1)
	for x in [-5.0,-1.5,2.0,5.5]: _box(Vector3(x,0.09,-11.0),Vector3(0.07,0.015,6.3),"d3d4c8")
	_car(0,-11.8,"7d8686",true)
	for x in [-4.5,5.4]:
		_box(Vector3(x,0.56,-17.0),Vector3(1.05,1.0,0.8),"3f6552")
		_obstacle(x,-17.0,1.05,0.8)
	_car(-23,18.5,"415b50")
	_car(18,11.5,"8d4540")
	for index in range(5):
		var x: float=-26.0+float(index)*13.0
		_building(Vector3(x,0,-30),Vector3(11,7.0+float(index%3)*2.8,14),"c9beb0" if index%2==0 else "e5dbcb")
		_building(Vector3(x,0,31),Vector3(11,7.5+float(index%3)*2.7,13),"c2beb4" if index%2==0 else "d8c3b3")
	for z in [-13.0,2.0,31.0]:
		_building(Vector3(-51,0,z),Vector3(14,9,12),"d9c5b3")
		_building(Vector3(51,0,z),Vector3(14,8.5,12),"c5c0b4")
	for x in [-31.2,-13.8,8.8,32.2]: _tree(x,7.5,int(x))
	for x in [-28.0,-7.0,12.0,30.0]: _tree(x,22.4,int(x))
	for x in [-32.0,10.0,31.5]: _tree(x,-17.0,int(x))
	for x in [-32.0,-7.0,8.5,32.0]: _lamp(x,9.1)
	# Sealed alleys use gates, parked vehicles, and buildings rather than abrupt slabs.
	_fence(-38,-21.8,7.4)
	_fence(38,-21.8,7.4)
	for x in [-42.0,42.0]:
		_box(Vector3(x,0.42,23.1),Vector3(0.6,0.75,2),"b5baac",7)
	var sun:=DirectionalLight3D.new()
	outdoor_sun=sun
	sun.rotation_degrees=Vector3(-52,-32,0)
	sun.light_color=Color("ffe6c7")
	sun.light_energy=0.48
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=38.0
	add_child(sun)
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
	action.offset_left=-305
	action.offset_right=-22
	action.offset_top=-112
	action.offset_bottom=-45
	action.focus_mode=Control.FOCUS_NONE
	_style_button(action)
	action.pressed.connect(_interact)
	controls.add_child(action)
	controls.hide()

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
	if transitioning: return
	var p: Vector3=host.camera.position
	if absf(p.x) < 1.3 and p.z > 5.2 and p.z < 8.0:
		host.status_label.text="Step clear of the door before opening or closing it."
		return
	transitioning=true
	door_open=not door_open
	var tween:=create_tween()
	tween.tween_property(door_pivot,"rotation:y",-1.45 if door_open else 0.0,0.35)
	tween.finished.connect(func(): transitioning=false)
	host.status_label.text="Door opened. Walk through when ready." if door_open else "Apartment door closed."

func _arrive_outside() -> void:
	active=true
	saved_indoor_sun_visible=host.sun_light.visible
	host._reset_world_pointer()
	host._cancel_camera_view_tween()
	host.current_view="neighborhood"
	host.status_label.text="Walk through the open doorway. You can close the door from either side."
	host.camera.environment=outdoor_environment if host.camera.position.z >= 6.0 else null
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
	host.current_view="door"

func refresh_controls() -> void:
	for button in [host.left_button,host.right_button,host.forward_button,host.back_button,host.contextual_button,host.door_quick_button]:
		button.hide()
	for label in [host.view_label,host.status_label]:
		label.add_theme_color_override("font_outline_color",Color("17251f"))
		label.add_theme_constant_override("outline_size",4)
	host.view_label.text="FRONT DOOR | WALK THROUGH / DRAG TO LOOK" if host.camera.position.z < 6.0 else "NEIGHBORHOOD | STICK TO WALK / DRAG TO LOOK"

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
			if pointer==event.index: pointer=-99
		elif pointer==-99 and not _over_ui(event.position):
			pointer=event.index
			last_pointer=event.position
	elif event is InputEventScreenDrag and event.index==pointer:
		_look(event.position-last_pointer)
		last_pointer=event.position
	elif event is InputEventMouseButton and event.device!=-1 and event.button_index==MOUSE_BUTTON_LEFT:
		pointer=-1 if event.pressed and not _over_ui(event.position) else -99
	elif event is InputEventMouseMotion and event.device!=-1 and pointer==-1:
		_look(event.relative)

func _over_ui(point: Vector2) -> bool:
	return pad.get_global_rect().has_point(point) or action.get_global_rect().has_point(point) or host._pointer_over_room_ui(point)

func _look(motion: Vector2) -> void:
	host.camera.rotation.y-=motion.x*0.004
	host.camera.rotation.x=clampf(host.camera.rotation.x-motion.y*0.003,-0.65,0.65)

func _process(delta: float) -> void:
	outdoor_sun.visible=door_open or host.camera.position.z >= 6.0
	if not active: return
	var indoors: bool=host.camera.position.z < 6.0
	host.current_room="main" if indoors else "neighborhood"
	host.camera.environment=null if indoors else outdoor_environment
	host.sun_light.visible=saved_indoor_sun_visible if indoors else false
	var night: bool=host.day_phase=="NIGHT"
	outdoor_sun.light_energy=0.10 if night else 0.48
	for lamp in lamps: lamp.light_energy=0.8 if night else 0.0
	outdoor_environment.background_color=Color("202c41") if night else Color("b5c7d0")
	outdoor_environment.ambient_light_energy=0.28 if night else 0.38
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
	var step: Vector3=Basis(Vector3.UP,host.camera.rotation.y)*Vector3(movement.x,0,movement.y)*minf(delta,0.05)*3.2
	var local: Vector3=host.camera.position-ORIGIN
	var next:=local+Vector3(step.x,0,0)
	if _walkable(next): local=next
	next=local+Vector3(0,0,step.z)
	if _walkable(next): local=next
	host.camera.position=ORIGIN+local
	if host.camera.position.z < 3.45:
		end_walk()
		host._refresh_navigation_ui()
		host.status_label.text="Back inside. Use the front door to walk out again."
		return
	host.view_label.text="FRONT DOOR | WALK THROUGH / DRAG TO LOOK" if host.camera.position.z < 6.0 else "NEIGHBORHOOD | STICK TO WALK / DRAG TO LOOK"
	var target:=_near_target()
	action.disabled=target.is_empty()
	action.text=("CLOSE APARTMENT DOOR" if door_open else "OPEN APARTMENT DOOR") if target=="apartment" else (("INSPECT HOUSE" if host.property_offer_unlocked else "HOUSE | NOT AVAILABLE YET") if target=="house" else "WALK TO AN ENTRANCE")
	if host.customer_waiting:
		host.status_label.text="Someone is at your apartment door. Walk back to answer."

func _walkable(pos: Vector3) -> bool:
	var world: Vector3=pos+ORIGIN
	if absf(world.x) < 0.76 and world.z >= 3.3 and world.z <= 8.9:
		if not door_open and world.z >= 5.55 and world.z <= 6.3: return false
		return true
	if pos.x < -42.0 or pos.x > 42.0 or pos.z < -21.6 or pos.z > 24.2: return false
	for rect in obstacles:
		if rect.has_point(Vector2(pos.x,pos.z)): return false
	return true

func _near_target() -> String:
	var pos: Vector3=host.camera.position-ORIGIN
	if absf(host.camera.position.x) < 2.7 and host.camera.position.z > 3.3 and host.camera.position.z < 10.0: return "apartment"
	if Vector2(pos.x-HOUSE_ENTRY.x,pos.z-HOUSE_ENTRY.z).length()<2.25: return "house"
	return ""

func _interact() -> void:
	if not active or host._any_modal_open() or host.daily_report_pending: return
	match _near_target():
		"apartment":
			_toggle_door()
		"house":
			host.status_label.text="This is the house from Rod's offer. Check his message for the property opportunity." if host.property_offer_unlocked else "This house is not available yet. Keep building your operation and watch for Rod's text."
