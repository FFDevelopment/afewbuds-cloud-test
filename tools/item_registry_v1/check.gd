extends SceneTree
## Shared item/equipment schema and compatibility tests for mobile + desktop.
var failures: int = 0
var checks: int = 0

func check(ok: bool, note: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", note)
	else:
		failures += 1
		push_error("FAIL: " + note)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var furniture_script: Script = load("res://scripts/property_furniture.gd")
	var constants: Dictionary = furniture_script.get_script_constant_map()
	var original: Dictionary = constants.get("LEGACY_CATALOG", {})
	check(original.has("sofa") and original.has("computer") and original.has("ventilation") and original.has("grow_tent"), "All legacy furniture and equipment are present")
	var before: String = JSON.stringify(original)
	var registry: RefCounted = load("res://scripts/item_registry.gd").new()
	registry.setup(original)
	check(registry.verify_legacy(original), "All legacy SKUs, descriptions, prices and weights remain unchanged")
	check(registry.load_external_catalog("res://data/item_definitions.json"), "Versioned empty content catalog loads without changing existing equipment")
	check(registry.quote("sofa") == 350 and registry.quote("computer") == 550 and registry.quote("ventilation") == 320, "Existing store prices remain identical")
	check(registry.keys_for_shop("equipment").has("ventilation") and registry.keys_for_shop("furniture").has("computer"), "Old store categories remain the same")
	check(not registry.register_definition("sofa", {"name": "Wrong", "shop": "furniture", "price": 1, "weight": 1, "size": [1, 1, 1]}), "Cannot overwrite an existing SKU and corrupt purchased equipment")
	check(not registry.register_definition("../unsafe", {"name": "Unsafe", "shop": "tools", "price": 1, "weight": 1, "size": [1, 1, 1]}), "Cannot use unsafe item identifiers")
	check(not registry.register_definition("bad_item", {"name": "Broken", "shop": "tools", "price": 2, "weight": 1, "size": [-1, 1, 1]}), "Reject invalid physical dimensions")
	var spec: Dictionary = {"name": "Workshop Tool Cart", "shop": "tools", "price": 275, "weight": 13, "size": [1.0, 1.1, 0.65], "interaction": "tool_storage", "allowed_room_uses": ["packing", "storage"], "model_path": "res://assets/furniture/workshop_cart.glb"}
	check(registry.register_definition("workshop_cart_01", spec), "New item registers by ID without rewriting the gameplay code")
	check(registry.has("workshop_cart_01") and registry.quote("workshop_cart_01") == 275, "New item's SKU and price are available to all shop readers")
	check(registry.keys_for_shop("tools").has("workshop_cart_01") and registry.effect_key("workshop_cart_01") == "tool_storage", "Shop group and action metadata resolve automatically")
	check(registry.permits_room("workshop_cart_01", "packing") and not registry.permits_room("workshop_cart_01", "bedroom"), "Per-item room restrictions prevent invalid placement")
	check(not registry.permits_room("ventilation", "living") and registry.permits_room("ventilation", "grow"), "Existing grow-only equipment restrictions remain")
	check(registry.register_alias("legacy_cart", "workshop_cart_01") and registry.canonical("legacy_cart") == "workshop_cart_01", "Optional alias resolves existing item IDs without changing saved identifiers")
	var prepared: Dictionary = {"extra_toolbox_02": {"name": "Extra Toolbox", "shop": "tools", "price": 55, "weight": 4, "size": [0.5, 0.5, 0.5]}}
	check(registry.import_definitions(prepared) and registry.quote("extra_toolbox_02") == 55, "Catalog imports independent extra item definitions")
	var invalid_batch: Dictionary = {
		"next_toolbox_03": {"name": "Later Toolbox", "shop": "tools", "price": 55, "weight": 4, "size": [0.5, 0.5, 0.5]},
		"bad_item_04": {"name": "Invalid", "shop": "tools", "price": -5, "weight": 4, "size": [0.5, 0.5, 0.5]}
	}
	check(not registry.import_definitions(invalid_batch) and not registry.has("next_toolbox_03"), "Invalid multi-item content pack rolls back all new definitions")
	check(registry.verify_legacy(original) and JSON.stringify(original) == before, "Adding items never mutates the legacy definitions")
	var copy: Dictionary = registry.get_definition("workshop_cart_01")
	copy["price"] = 1
	check(registry.quote("workshop_cart_01") == 275, "Consumers receive defensive item definition copies")
	check(not registry.register_definition("workshop_cart_01", spec), "Duplicate new SKUs cannot override existing ones")
	check(registry.quote("not_in_catalog") == -1 and registry.get_definition("not_in_catalog").is_empty(), "Unknown item IDs are handled safely")
	print("ITEM_REGISTRY_RESULT: ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
