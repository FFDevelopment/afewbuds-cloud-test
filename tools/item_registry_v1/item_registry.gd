extends RefCounted
## Shared item/equipment definition registry; no owned items or save data live here.
## Existing SKU keys and prices are imported unchanged from the playable catalog.
const SCHEMA_VERSION: int = 1
const SHOPS := ["grow", "equipment", "furniture", "supplies", "seeds", "tools", "decor"]
const STATIONS := ["packing", "supply", "storage", "dealer"]
var definitions: Dictionary = {}
var aliases: Dictionary = {}

func setup(legacy_catalog: Dictionary) -> void:
	definitions = {}
	aliases = {}
	for key in legacy_catalog:
		var sku: String = str(key)
		assert(_valid_key(sku), "Invalid legacy item SKU: " + sku)
		# Do not normalize or reprice previously purchased items.
		definitions[sku] = (legacy_catalog[key] as Dictionary).duplicate(true)

func _valid_key(sku: String) -> bool:
	if sku.is_empty() or sku.length() > 96:
		return false
	for c in sku:
		if not (c >= "a" and c <= "z") and not (c >= "0" and c <= "9") and c != "_":
			return false
	return true

func canonical(sku: String) -> String:
	return str(aliases.get(sku, sku))

func has(sku: String) -> bool:
	return definitions.has(canonical(sku))

func get_definition(sku: String) -> Dictionary:
	var id: String = canonical(sku)
	return (definitions[id] as Dictionary).duplicate(true) if definitions.has(id) else {}

func available_shops() -> Array[String]:
	var result: Array[String] = []
	for item in definitions.values():
		var shop: String = str(item.get("shop", ""))
		if not shop.is_empty() and not result.has(shop):
			result.append(shop)
	result.sort()
	return result

func keys_for_shop(shop_id: String) -> Array[String]:
	var result: Array[String] = []
	for key in definitions:
		if str(definitions[key].get("shop", "")) == shop_id:
			result.append(str(key))
	result.sort()
	return result

func register_definition(sku: String, item: Dictionary) -> bool:
	# Changes to existing SKUs require an explicit, versioned game migration.
	if not _valid_key(sku) or has(sku):
		return false
	for field in ["name", "shop", "price", "size", "weight"]:
		if not item.has(field):
			return false
	var title: String = str(item.get("name", "")).strip_edges()
	var shop_id: String = str(item.get("shop", ""))
	var size: Variant = item.get("size")
	if title.is_empty() or shop_id not in SHOPS or not size is Array or size.size() != 3:
		return false
	var width: float = float(size[0])
	var height: float = float(size[1])
	var depth: float = float(size[2])
	if not is_finite(width) or not is_finite(height) or not is_finite(depth) or minf(width, minf(height, depth)) <= 0.0:
		return false
	var price: int = int(item.get("price", -1))
	var weight: int = int(item.get("weight", -1))
	if price < 0 or weight < 0:
		return false
	var kind: String = str(item.get("kind", ""))
	if not kind.is_empty() and kind not in STATIONS:
		return false
	if item.has("plants") and (int(item.plants) < 1 or int(item.plants) > 32):
		return false
	if item.has("tier") and int(item.tier) < 1:
		return false
	if item.has("capacity") and int(item.capacity) < 0:
		return false
	if item.has("model_path") and not str(item.model_path).begins_with("res://"):
		return false
	var copy: Dictionary = item.duplicate(true)
	copy["name"] = title
	copy["price"] = price
	copy["weight"] = weight
	copy["size"] = [width, height, depth]
	definitions[sku] = copy
	return true

func register_alias(previous_sku: String, active_sku: String) -> bool:
	# Only aliases new, unused keys; existing inventories retain original SKUs.
	if not _valid_key(previous_sku) or has(previous_sku) or not definitions.has(active_sku):
		return false
	aliases[previous_sku] = active_sku
	return true

func permits_room(sku: String, room_use: String) -> bool:
	if not has(sku):
		return false
	var item: Dictionary = definitions[canonical(sku)]
	var roles: Variant = item.get("allowed_room_uses", [])
	if roles is Array and not roles.is_empty():
		return room_use in roles
	return not bool(item.get("grow_only", false)) or room_use == "grow"

func effect_key(sku: String) -> String:
	if not has(sku):
		return ""
	var item: Dictionary = definitions[canonical(sku)]
	return str(item.get("interaction", item.get("kind", "")))

func quote(sku: String) -> int:
	return int(definitions[canonical(sku)].get("price", 0)) if has(sku) else -1

func verify_legacy(legacy_catalog: Dictionary) -> bool:
	if legacy_catalog.size() > definitions.size():
		return false
	for key in legacy_catalog:
		if not definitions.has(key) or definitions[key] != legacy_catalog[key]:
			return false
	return true
