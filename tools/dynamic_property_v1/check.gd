extends SceneTree
## Shared property-ID and old-career compatibility checks (desktop + mobile).
class MockHost:
	extends Node
	var location_state: Dictionary = {}
	var apartment_rent_state: Dictionary = {"lease_active": true, "balance": 132}
	var property_opportunity_state: Dictionary = {"acquired": false, "relocated": false}
var failures: int = 0
var checks: int = 0

func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + why)
	else:
		print("PASS: ", why)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var room_defs: Dictionary = {
		"apartment": {"main": Rect2(-4.7, -3.65, 9.4, 9.1), "grow": Rect2(-4.7, -10.0, 9.4, 5.5)},
		"house": {"living": Rect2(25.4, -4.6, 7.65, 7.15), "grow": Rect2(38.71, -13.89, 6.18, 6.78)}
	}
	var host := MockHost.new()
	root.add_child(host)
	host.location_state = {
		"furniture_v1": {"schema": 2, "items": {"legacy_sofa": {"property": "apartment", "sku": "sofa", "locked": true}}, "next_id": 92},
		"container_inventory": {"containers": {"apartment:storage": {"product|Street Green": 20}, "house:storage": {"product|Street Green": 5}}},
		"property_utilities": {"apartment": {"power_due": 24}, "house": {"power_due": 8}},
		"staff_assignments": {"Malik": "apartment", "Rod": "house"},
		"active_property": "apartment",
		"player_progression": {"chapter": 5, "reputation": 84}
	}
	var before: Dictionary = host.location_state.duplicate(true)
	var registry: RefCounted = load("res://scripts/property_registry.gd").new()
	registry.setup(host, room_defs)
	check(registry.exists("apartment") and registry.exists("house"), "Legacy apartment and house keep their stable IDs")
	check(not registry.controlled("house") and registry.controlled("apartment"), "Existing house unlock and apartment lease safeguards remain intact")
	for key in before:
		check(JSON.stringify(host.location_state[key]) == JSON.stringify(before[key]), "Registry preserves untouched legacy save field: " + key)
	var generated: String = registry.register_property("Future Name Not Known", "commercial", {"main": Rect2(95, 95, 20, 20), "grow_a": Rect2(117, 95, 5, 6)})
	check(generated.begins_with("property_") and registry.exists(generated), "Future building registers without a preselected name or hardcoded ID")
	check(not registry.controlled(generated), "New building is inaccessible until acquired")
	check(registry.set_access(generated, true), "New building can be unlocked independently")
	check(registry.room_at(generated, Vector3(97, 0, 98)) == "main", "Dynamic room boundary lookup works")
	check(registry.set_room_use(generated, "grow_a", "grow") and registry.is_grow_room(generated, "grow_a"), "Grow-room restrictions are configurable per building")
	var unit: String = registry.register_unit(generated, "Unit 101", {"private": Rect2(97, 97, 6, 6)})
	check(registry.exists(unit) and registry.set_access(unit, true), "Nested apartments and commercial units register under buildings")
	check(registry.property_at(Vector3(98, 0, 99)) == unit, "Unit ID wins over parent building at the same position")
	check(registry.rename_property(generated, "Bongchester Warehouse") and registry.display_name(generated) == "Bongchester Warehouse", "Renaming does not change a property ID")
	var original_id: String = generated
	registry.system_data(generated, "inventory")["raw_stock"] = 17
	registry.system_data("apartment", "inventory")["raw_stock"] = 43
	registry.system_data(generated, "utilities")["power_due"] = 21
	check(int(registry.system_data(generated, "inventory").get("raw_stock", 0)) == 17 and int(registry.system_data("apartment", "inventory").get("raw_stock", 0)) == 43, "Separate inventory ledgers cannot overwrite one another")
	check(registry.register_property("Duplicated", "residential", {"main": Rect2(10, 20, 8, 8)}, original_id).is_empty(), "Duplicate property IDs cannot be registered")
	check(registry.register_property("Unsafe", "commercial", {"front": Rect2(0, 0, 5, 5)}, "house:storage").is_empty(), "Property IDs cannot masquerade as inventory containers")
	var saved: String = JSON.stringify(host.location_state)
	var restored: Variant = JSON.parse_string(saved)
	check(restored is Dictionary and (restored as Dictionary).has("property_registry"), "Registry stores only JSON-compatible save data")
	var other := MockHost.new()
	root.add_child(other)
	other.location_state = restored
	other.apartment_rent_state = host.apartment_rent_state.duplicate(true)
	other.property_opportunity_state = host.property_opportunity_state.duplicate(true)
	var loaded: RefCounted = load("res://scripts/property_registry.gd").new()
	loaded.setup(other, room_defs)
	check(loaded.exists(original_id) and loaded.display_name(original_id) == "Bongchester Warehouse", "Save reload preserves registered property IDs and renamed labels")
	check(loaded.exists(unit) and loaded.property_at(Vector3(98, 0, 99)) == unit, "Save reload preserves independent units")
	check(int(loaded.system_data(original_id, "inventory").get("raw_stock", 0)) == 17 and int(loaded.system_data("apartment", "inventory").get("raw_stock", 0)) == 43, "Save reload preserves property-separated inventory")
	check(other.location_state.furniture_v1.items.legacy_sofa.property == "apartment" and other.location_state.container_inventory.containers["apartment:storage"]["product|Street Green"] == 20, "Existing bought furniture and stored product survive migration")
	check(other.location_state.property_utilities.apartment.power_due == 24 and other.location_state.staff_assignments.Malik == "apartment", "Existing utility balances and staff assignments survive migration")
	check(loaded.controlled("apartment") and not loaded.controlled("house"), "Legacy lease and house purchase permissions survive reload")
	host.queue_free()
	other.queue_free()
	await process_frame
	await process_frame
	print("DYNAMIC_PROPERTY_REGISTRY_RESULT: ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
