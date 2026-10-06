extends Node3D

# AFewBuds olive loveseat. Real, static furniture; local -Z faces the room.
# Fits the established sofa bay. No economy, save, collision or input changes.
const ANCHOR: Vector3 = Vector3(-2.28, 0.0, 3.07)
const SEAT_TOP: float = 0.4682184907339378
const SEAT_DROP: float = 0.27628150926606226
const LEG_HEIGHT: float = 0.13
const BASE_HEIGHT: float = 0.14
var part_bounds: Dictionary = {}
var fabric: StandardMaterial3D
var trim: StandardMaterial3D
var cream: StandardMaterial3D
var leaf: StandardMaterial3D
var wood: StandardMaterial3D
var throw_material: StandardMaterial3D
var triangle_count: int = 0

func _ready() -> void:
	name = "AFBLoveseat"
	var weave: Texture2D = _make_weave()
	fabric = _material(Color("728252"), weave, 0.93)
	trim = _material(Color("414c32"), weave, 0.96)
	cream = _material(Color("d6ceb1"), weave, 0.98)
	leaf = _material(Color("526535"), weave, 0.98)
	wood = _material(Color("b68b61"), _walnut_texture(), 0.72)
	wood.uv1_scale = Vector3(2, 2, 2)
	throw_material = _material(Color("9aab78"), weave, 0.98)
	throw_material.vertex_color_use_as_albedo = true
	_build()
	_build_seating()

func _make_weave() -> Texture2D:
	# A small repeating cloth tile, generated once; no large photo or runtime shader.
	var image: Image = Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y: int in range(64):
		for x: int in range(64):
			var warp: float = sin(float(x) * PI / 4.0)
			var weft: float = sin(float(y) * PI / 4.0)
			var grain: float = sin(float(x * 73 + y * 119)) * 0.025
			var value: float = 0.86 + 0.055 * warp + 0.045 * weft + grain
			image.set_pixel(x, y, Color(value, value, value))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _material(color: Color, texture: Texture2D, roughness: float) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.albedo_texture = texture
	mat.roughness = roughness
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(7, 7, 7)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return mat

func _add(part_name: String, mesh: Mesh, pos: Vector3, material: Material, angles: Vector3 = Vector3.ZERO, parent: Node3D = self) -> MeshInstance3D:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.material_override = material
	part.position = pos
	part.rotation_degrees = angles
	parent.add_child(part)
	if not part_bounds.has(part_name): part_bounds[part_name] = []
	part_bounds[part_name].append(part.transform * mesh.get_aabb())
	for surface: int in range(mesh.get_surface_count()):
		triangle_count += int(mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX].size() / 3) if mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX] != null else int(mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX].size() / 3)
	return part

func _axis_steps(half_size: float, radius: float) -> Array[float]:
	var core: float = maxf(0.001, half_size - radius)
	var samples: Array[float] = [-half_size]
	for i: int in range(1, 5):
		samples.append(-core - radius * cos(float(i) * PI / 8.0))
	samples.append(-core * 0.5)
	samples.append(0.0)
	samples.append(core * 0.5)
	for i: int in range(5):
		samples.append(core + radius * sin(float(i) * PI / 8.0))
	return samples

func _point(p: Vector3, half_size: Vector3, radius: float, normal: Vector3, puff: float) -> Vector3:
	var core: Vector3 = half_size - Vector3.ONE * radius
	var clamped: Vector3 = p.clamp(-core, core)
	var result: Vector3 = clamped + (p - clamped).normalized() * radius
	# Gentle stuffing only on large faces; broad flat seats, not capsule bubbles.
	if puff > 0.0:
		var a: float = 0.0
		var b: float = 0.0
		if absf(normal.y) > 0.5:
			a = p.x / half_size.x
			b = p.z / half_size.z
		elif absf(normal.z) > 0.5:
			a = p.x / half_size.x
			b = p.y / half_size.y
		else:
			a = p.y / half_size.y
			b = p.z / half_size.z
		result += normal * puff * maxf(0.0, 1.0 - a * a) * maxf(0.0, 1.0 - b * b)
	return result

func _rounded(dimensions: Vector3, radius: float, puff: float = 0.0) -> ArrayMesh:
	var h: Vector3 = dimensions * 0.5
	radius = minf(radius, minf(h.x, minf(h.y, h.z)) * 0.94)
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uv: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var faces: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	for normal: Vector3 in faces:
		var u: Vector3 = Vector3.UP.cross(normal).normalized() if absf(normal.y) < 0.5 else Vector3.RIGHT
		var v: Vector3 = normal.cross(u).normalized()
		var uh: float = absf(u.dot(h))
		var vh: float = absf(v.dot(h))
		var us: Array[float] = _axis_steps(uh, radius)
		var vs: Array[float] = _axis_steps(vh, radius)
		var origin: int = vertices.size()
		for y: int in range(vs.size()):
			for x: int in range(us.size()):
				var p: Vector3 = normal * absf(normal.dot(h)) + u * us[x] + v * vs[y]
				var point: Vector3 = _point(p, h, radius, normal, puff)
				var derivative_u: Vector3 = _point(p + u * 0.0001, h, radius, normal, puff) - _point(p - u * 0.0001, h, radius, normal, puff)
				var derivative_v: Vector3 = _point(p + v * 0.0001, h, radius, normal, puff) - _point(p - v * 0.0001, h, radius, normal, puff)
				var n: Vector3 = derivative_u.cross(derivative_v).normalized()
				vertices.append(point)
				normals.append(n if n.dot(normal) >= 0 else -n)
				uv.append(Vector2(us[x] / dimensions.x, vs[y] / dimensions.y))
		for y: int in range(vs.size() - 1):
			for x: int in range(us.size() - 1):
				var a: int = origin + y * us.size() + x
				var b: int = a + 1
				var c: int = a + us.size()
				var d: int = c + 1
				# Godot front faces use clockwise winding.
				indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var result: ArrayMesh = ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

func _tube(points: PackedVector3Array, radius: float, closed: bool = false) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var sides: int = 6
	for i: int in range(points.size()):
		var before: int = (i - 1 + points.size()) % points.size() if closed else maxi(0, i - 1)
		var after: int = (i + 1) % points.size() if closed else mini(points.size() - 1, i + 1)
		var direction: Vector3 = (points[after] - points[before]).normalized()
		var tangent: Vector3 = direction.cross(Vector3.UP if absf(direction.y) < 0.90 else Vector3.RIGHT).normalized()
		var bitangent: Vector3 = direction.cross(tangent)
		for j: int in range(sides):
			var n: Vector3 = tangent * cos(float(j) * TAU / sides) + bitangent * sin(float(j) * TAU / sides)
			vertices.append(points[i] + n * radius)
			normals.append(n)
	for i: int in range(points.size() if closed else points.size() - 1):
		for j: int in range(sides):
			var a: int = i * sides + j
			var b: int = i * sides + (j + 1) % sides
			var c: int = ((i + 1) % points.size()) * sides + j
			var d: int = ((i + 1) % points.size()) * sides + (j + 1) % sides
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var result: ArrayMesh = ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

func _piping(dimensions: Vector2, radius: float, horizontal: bool) -> ArrayMesh:
	var points: PackedVector3Array = PackedVector3Array()
	for corner: int in range(4):
		var angle: float = float(corner) * PI / 2.0
		var center: Vector2 = Vector2(1 if corner == 0 or corner == 3 else -1, 1 if corner < 2 else -1) * (dimensions * 0.5 - Vector2.ONE * radius)
		for step: int in range(7):
			var a: float = angle + float(step) * PI / 12.0
			var p: Vector2 = center + Vector2(cos(a), sin(a)) * radius
			points.append(Vector3(p.x, 0, p.y) if horizontal else Vector3(p.x, p.y, 0))
	return _tube(points, 0.0055, true)

func _pillow(part_name: String, position_value: Vector3, rotation_value: Vector3, striped: bool) -> void:
	var pivot: Node3D = Node3D.new()
	pivot.name = part_name
	pivot.position = position_value
	pivot.rotation_degrees = rotation_value
	add_child(pivot)
	_add("PillowCloth", _rounded(Vector3(0.44, 0.43, 0.19), 0.079, 0.024), Vector3.ZERO, cream if striped else leaf, Vector3.ZERO, pivot)
	_add("PillowPiping", _piping(Vector2(0.427, 0.417), 0.075, false), Vector3(0, 0, -0.010), trim, Vector3.ZERO, pivot)
	if striped:
		for i: int in range(-2, 3):
			var points: PackedVector3Array = PackedVector3Array()
			for j: int in range(21):
				var y: float = lerpf(-0.172, 0.172, float(j) / 20.0)
				var x: float = float(i) * 0.061
				var z: float = -0.097 - 0.025 * (1.0 - pow(x / 0.22, 2)) * (1.0 - pow(y / 0.215, 2))
				points.append(Vector3(x, y, z))
			_add("WovenStripe", _tube(points, 0.007), Vector3.ZERO, leaf, Vector3.ZERO, pivot)
	else:
		_leaf_embroidery(pivot)

func _leaf_embroidery(parent: Node3D) -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(7):
		var angle: float = deg_to_rad(float(i - 3) * 25.0)
		var direction: Vector2 = Vector2(sin(angle), cos(angle))
		var side: Vector2 = Vector2(direction.y, -direction.x)
		var origin: Vector2 = Vector2(0, -0.10)
		var length: float = 0.25 - absf(float(i - 3)) * 0.035
		var points: Array[Vector2] = [origin, origin + direction * length * 0.45 + side * 0.024, origin + direction * length, origin + direction * length * 0.45 - side * 0.024]
		for index: int in [0, 1, 2, 0, 2, 3]:
			var p: Vector2 = points[index]
			var z: float = -0.098 - 0.025 * (1.0 - pow(p.x / 0.22, 2)) * (1.0 - pow(p.y / 0.215, 2))
			surface.set_normal(Vector3.FORWARD)
			surface.add_vertex(Vector3(p.x, p.y, z))
	var print_material: StandardMaterial3D = cream.duplicate() as StandardMaterial3D
	print_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add("LeafEmbroidery", surface.commit(), Vector3.ZERO, print_material, Vector3.ZERO, parent)

func _throw_point(t: float, w: float) -> Vector3:
	# Follow the actual rounded arm profile, then hang down its outside.
	var x: float
	var y: float
	if t < 0.60:
		x = lerpf(-0.995, -1.32, t / 0.60)
		var dx: float = maxf(0.0, absf(x + 1.135) - 0.030)
		y = 0.95 + sqrt(maxf(0.0, 0.155 * 0.155 - dx * dx)) + 0.009
	else:
		var a: float = (t - 0.60) / 0.40
		x = -1.329 - 0.014 * sin(a * PI)
		y = 0.959 - 0.61 * a
	var fold: float = 0.005 * sin(w * TAU * 4.0 + t * 1.7)
	return Vector3(x + fold * maxf(0.0, (t - 0.5) * 2), y + fold * (1.0 - t) - SEAT_DROP, -0.05 + w * 0.59)

func _build_throw() -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: int = 30
	var columns: int = 18
	for row: int in range(rows):
		for column: int in range(columns):
			for offset: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var t: float = float(row + offset.x) / float(rows)
				var w: float = float(column + offset.y) / float(columns) - 0.5
				var value: float = 0.89 + 0.08 * cos(w * TAU * 9)
				surface.set_color(Color(value, value, value))
				surface.set_uv(Vector2(t * 3, w * 3))
				surface.add_vertex(_throw_point(t, w))
	surface.generate_normals()
	var mat: StandardMaterial3D = throw_material.duplicate() as StandardMaterial3D
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add("KnittedThrow", surface.commit(), Vector3.ZERO, mat)
	# Raised paired strands form cable-knit columns, sharing one material.
	for stripe: int in range(6):
		for strand: int in range(2):
			var points: PackedVector3Array = PackedVector3Array()
			for step: int in range(37):
				var t: float = float(step) / 36.0
				var w: float = -0.425 + float(stripe) * 0.17 + sin(t * TAU * 7.0 + float(strand) * PI) * 0.017
				var p: Vector3 = _throw_point(t, w)
				p += Vector3(-0.006 if t > 0.45 else 0.0, 0.006 if t <= 0.60 else 0.0, 0.0)
				points.append(p)
			_add("KnitCable", _tube(points, 0.006), Vector3.ZERO, cream)

func _build() -> void:
	_add("CouchBase", _rounded(Vector3(2.29, BASE_HEIGHT, 0.89), 0.055), Vector3(0, 0.187, 0.0), fabric)
	_add("BackFrame", _rounded(Vector3(2.34, 0.86, 0.18), 0.079), Vector3(0, 0.88 - SEAT_DROP, 0.35), fabric)
	for side: int in [-1, 1]:
		_add("RoundedArm", _rounded(Vector3(0.37, 0.65, 0.97), 0.155), Vector3(float(side) * 1.135, 0.78 - SEAT_DROP, 0.0), fabric)
		_add("SeatCushion", _rounded(Vector3(0.96, 0.205, 0.80), 0.080, 0.015), Vector3(float(side) * 0.495, 0.627 - SEAT_DROP, -0.036), fabric)
		_add("SeatPiping", _piping(Vector2(0.948, 0.788), 0.080, true), Vector3(float(side) * 0.495, 0.636 - SEAT_DROP, -0.036), trim)
		_add("BackCushion", _rounded(Vector3(0.965, 0.65, 0.235), 0.105, 0.020), Vector3(float(side) * 0.497, 1.043 - SEAT_DROP, 0.241), fabric, Vector3(7.0, 0.0, 0.0))
		_add("BackPiping", _piping(Vector2(0.954, 0.639), 0.095, false), Vector3(float(side) * 0.497, 1.043 - SEAT_DROP, 0.22), trim, Vector3(7.0, 0.0, 0.0))
		for rear: int in [-1, 1]:
			var leg_mesh: CylinderMesh = CylinderMesh.new()
			leg_mesh.height = LEG_HEIGHT
			leg_mesh.top_radius = 0.064
			leg_mesh.bottom_radius = 0.042
			leg_mesh.radial_segments = 12
			leg_mesh.rings = 1
			_add("TaperedWoodLeg", leg_mesh, Vector3(float(side) * 0.995, LEG_HEIGHT * 0.5, float(rear) * 0.29), wood)
	_pillow("LeafPillow", Vector3(-0.70, 0.932 - SEAT_DROP, -0.065), Vector3(13, -10, -10), false)
	_pillow("StripedPillow", Vector3(0.67, 0.925 - SEAT_DROP, -0.073), Vector3(14, 9, 10), true)
	_build_throw()
	_add("BrandPatch", _rounded(Vector3(0.017, 0.105, 0.32), 0.006), Vector3(1.324, 0.664 - SEAT_DROP, -0.13), cream)
	var label: Label3D = Label3D.new()
	label.name = "AFewBudsSideLabel"
	label.text = "AFewBuds"
	label.font_size = 36
	label.pixel_size = 0.0015
	label.outline_size = 0
	label.modulate = Color("35492c")
	label.position = Vector3(1.335, 0.664 - SEAT_DROP, -0.13)
	label.rotation_degrees.y = 90
	add_child(label)
	_batch_static_parts()

func _batch_static_parts() -> void:
	# Keep mobile draw calls low: combine static mesh parts by shared material.
	var batches: Dictionary = {}
	for child: Node in get_children():
		if not child is MeshInstance3D:
			continue
		var part: MeshInstance3D = child as MeshInstance3D
		var key: int = part.material_override.get_instance_id()
		if not batches.has(key):
			var tool: SurfaceTool = SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			batches[key] = {"tool": tool, "material": part.material_override, "parts": []}
		var batch: Dictionary = batches[key]
		(batch["tool"] as SurfaceTool).append_from(part.mesh, 0, part.transform)
		(batch["parts"] as Array).append(part)
	for key: Variant in batches:
		var batch: Dictionary = batches[key]
		var mesh: ArrayMesh = (batch["tool"] as SurfaceTool).commit()
		var combined: MeshInstance3D = MeshInstance3D.new()
		combined.name = "UpholsteryBatch"
		combined.mesh = mesh
		combined.material_override = batch["material"] as Material
		add_child(combined)
		for part: MeshInstance3D in batch["parts"]:
			remove_child(part)
			part.free()

func world_bounds() -> AABB:
	var result: AABB = AABB()
	var initialized: bool = false
	var nodes: Array[Node] = [self]
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		nodes.append_array(node.get_children())
		if node is MeshInstance3D:
			var part: MeshInstance3D = node as MeshInstance3D
			var bounds: AABB = part.global_transform * part.get_aabb()
			result = result.merge(bounds) if initialized else bounds
			initialized = true
	return result

func _build_seating() -> void:
	for side in [-1,1]:
		var marker := Marker3D.new()
		marker.name = "SeatLeft" if side == -1 else "SeatRight"
		marker.position = Vector3(side * .495, SEAT_TOP, -.036)
		add_child(marker)
	var body := StaticBody3D.new()
	body.name = "CouchCollision"
	add_child(body)
	var shapes := [[Vector3(0,.187,0),Vector3(2.29,BASE_HEIGHT,.89)],[Vector3(0,.88-SEAT_DROP,.35),Vector3(2.34,.86,.18)]]
	for side in [-1,1]:
		shapes.append([Vector3(side*1.135,.78-SEAT_DROP,0),Vector3(.37,.65,.97)])
		shapes.append([Vector3(side*.495,SEAT_TOP-.11,-.036),Vector3(.96,.22,.8)])
		shapes.append([Vector3(side*.497,1.043-SEAT_DROP,.241),Vector3(.965,.65,.235)])
	for entry in shapes:
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = entry[1]
		col.shape = box
		col.position = entry[0]
		body.add_child(col)

func _walnut_texture() -> Texture2D:
	var source:=Image.new()
	if source.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/furniture/walnut.png"))!=OK:return null
	source.generate_mipmaps()
	return ImageTexture.create_from_image(source)
