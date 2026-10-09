extends RefCounted
## Data-only property registry. Property names are labels, not save keys.
## A saved property ID never changes when its display name changes.
const SCHEMA_VERSION: int = 1
const DEFAULT_SYSTEMS := ["inventory", "furniture", "equipment", "computer", "utilities", "grow", "staff"]
var host: Node
var state: Dictionary = {}

func setup(owner: Node, legacy_rooms: Dictionary = {}) -> void:
	host = owner
	var stored: Variant = host.location_state.get("property_registry", {})
	state = stored if stored is Dictionary else {}
	if not state.get("properties", {}) is Dictionary:
		state["properties"] = {}
	if not state.has("properties"):
		state["properties"] = {}
	state["next_serial"] = maxi(1, int(state.get("next_serial", 1)))
	state["schema"] = maxi(SCHEMA_VERSION, int(state.get("schema", 0)))
	host.location_state["property_registry"] = state
	# Existing saves are linked in place; furniture, invoices, staff, and stock
	# remain in their original property-keyed dictionaries until migrated.
	for spec in [["apartment", "Starter Apartment"], ["house", "Maple Flats House"]]:
		var id: String = spec[0]
		if not state.properties.has(id):
			var bounds: Dictionary = legacy_rooms.get(id, {})
			_register(id, spec[1], "residential", bounds, "", true)
		else:
			_ensure_systems(state.properties[id])

func _rect_data(value: Variant) -> Array:
	if value is Rect2:
		var rect: Rect2 = value
		return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	if value is Array and value.size() == 4:
		return [float(value[0]), float(value[1]), float(value[2]), float(value[3])]
	return []

func _clean_rooms(source: Dictionary) -> Dictionary:
	var output: Dictionary = {}
	for room_name in source:
		var coords: Array = _rect_data(source[room_name])
		if coords.size() != 4 or str(room_name).is_empty():
			continue
		if coords[2] <= 0.0 or coords[3] <= 0.0:
			continue
		var finite: bool = true
		for coord in coords:
			if not is_finite(float(coord)):
				finite = false
		if finite:
			output[str(room_name)] = coords
	return output

func _ensure_systems(record: Dictionary) -> void:
	if not record.get("systems", {}) is Dictionary:
		record["systems"] = {}
	if not record.has("systems"):
		record["systems"] = {}
	for key in DEFAULT_SYSTEMS:
		if not record.systems.get(key, {}) is Dictionary:
			record.systems[key] = {}
		elif not record.systems.has(key):
			record.systems[key] = {}

func _register(id: String, label: String, property_type: String, rooms: Dictionary, parent_id: String, legacy: bool) -> bool:
	if id.is_empty() or state.properties.has(id) or (not parent_id.is_empty() and not exists(parent_id)):
		return false
	var clean: Dictionary = _clean_rooms(rooms)
	if clean.is_empty():
		return false
	var entry: Dictionary = {
		"id": id, "name": label, "type": property_type,
		"parent_id": parent_id, "legacy": legacy, "access": legacy,
		"rooms": clean, "room_uses": {}, "systems": {}
	}
	_ensure_systems(entry)
	state.properties[id] = entry
	return true

func register_property(label: String, property_type: String, rooms: Dictionary, id: String = "", parent_id: String = "") -> String:
	# Explicit IDs support externally authored maps. New IDs are generated
	# without knowing future street, neighborhood, or property names.
	var candidate: String = id.strip_edges()
	if candidate.is_empty():
		while true:
			candidate = "property_%06d" % int(state.next_serial)
			state.next_serial = int(state.next_serial) + 1
			if not exists(candidate):
				break
	if candidate in ["backpack", "market"] or candidate.contains(":") or candidate.contains("/") or candidate.contains(" "):
		return ""
	return candidate if _register(candidate, label, property_type, rooms, parent_id, false) else ""

func register_unit(parent_id: String, label: String, rooms: Dictionary, id: String = "") -> String:
	return register_property(label, "unit", rooms, id, parent_id)

func exists(id: String) -> bool:
	return state.properties.has(id)

func get_property(id: String) -> Dictionary:
	if not exists(id):
		return {}
	return (state.properties[id] as Dictionary).duplicate(true)

func display_name(id: String) -> String:
	return str(state.properties[id].get("name", id)) if exists(id) else id

func rename_property(id: String, label: String) -> bool:
	if not exists(id) or label.strip_edges().is_empty():
		return false
	state.properties[id]["name"] = label.strip_edges()
	return true

func set_access(id: String, allowed: bool) -> bool:
	if not exists(id) or bool(state.properties[id].get("legacy", false)):
		return false
	state.properties[id]["access"] = allowed
	return true

func controlled(id: String) -> bool:
	if not exists(id):
		return false
	if id == "apartment":
		return bool(host.apartment_rent_state.get("lease_active", true))
	if id == "house":
		return bool(host.property_opportunity_state.get("acquired", false)) and bool(host.property_opportunity_state.get("relocated", false))
	return bool(state.properties[id].get("access", false))

func property_ids(only_controlled: bool = false) -> Array[String]:
	var result: Array[String] = []
	for key in state.properties:
		var id: String = str(key)
		if not only_controlled or controlled(id):
			result.append(id)
	result.sort()
	return result

func rooms_for(id: String) -> Dictionary:
	var rooms: Dictionary = {}
	if not exists(id):
		return rooms
	for room in state.properties[id].get("rooms", {}):
		var coords: Array = _rect_data(state.properties[id].rooms[room])
		if coords.size() == 4:
			rooms[str(room)] = Rect2(float(coords[0]), float(coords[1]), float(coords[2]), float(coords[3]))
	return rooms

func room_at(id: String, world_point: Vector3) -> String:
	var rooms: Dictionary = rooms_for(id)
	for room in rooms:
		var rect: Rect2 = rooms[room]
		if rect.has_point(Vector2(world_point.x, world_point.z)):
			return room
	return ""

func _property_depth(id: String) -> int:
	var depth: int = 0
	var visited: Dictionary = {}
	var next_id: String = id
	while exists(next_id) and not visited.has(next_id):
		visited[next_id] = true
		next_id = str(state.properties[next_id].get("parent_id", ""))
		if not next_id.is_empty() and exists(next_id):
			depth += 1
	return depth

func property_at(world_point: Vector3) -> String:
	# Registered sub-units take priority over parent buildings, even when
	# their individual room geometry is larger than a parent room.
	var chosen: String = ""
	var best_depth: int = -1
	var smallest: float = INF
	for id in property_ids(true):
		for value in rooms_for(id).values():
			var rect: Rect2 = value
			if not rect.has_point(Vector2(world_point.x, world_point.z)):
				continue
			var depth: int = _property_depth(id)
			var area: float = rect.size.x * rect.size.y
			if depth > best_depth or (depth == best_depth and area < smallest):
				best_depth = depth
				smallest = area
				chosen = id
	return chosen

func set_room_use(id: String, room: String, use: String) -> bool:
	if not exists(id) or not rooms_for(id).has(room):
		return false
	state.properties[id].room_uses[room] = use
	return true

func is_grow_room(id: String, room: String) -> bool:
	if not exists(id):
		return false
	return str(state.properties[id].get("room_uses", {}).get(room, room)) == "grow"

func system_data(id: String, system: String) -> Dictionary:
	if not exists(id) or system not in DEFAULT_SYSTEMS:
		return {}
	_ensure_systems(state.properties[id])
	return state.properties[id].systems[system]

func owner_id(item: Dictionary) -> String:
	return str(item.get("property", ""))

func register_equipment(id: String, equipment_id: String) -> bool:
	if not exists(id) or equipment_id.is_empty():
		return false
	system_data(id, "equipment")[equipment_id] = true
	return true
