"""Apply the universal item registry to the existing furniture model.

Preserve SKU keys, prices, weights, upgrades and old ownership records exactly.
"""
def patch_furniture(s: str) -> str:
    changes = [
        ('const CATALOG={', 'const LEGACY_CATALOG={'),
        ('var registry:RefCounted\nvar state:Dictionary',
         'var registry:RefCounted\nvar item_registry:RefCounted\nvar CATALOG:Dictionary={}\nvar state:Dictionary'),
        (' registry.setup(owner, ROOMS)\n',
         ' registry.setup(owner, ROOMS)\n item_registry=load("res://scripts/item_registry.gd").new()\n item_registry.setup(LEGACY_CATALOG)\n if not item_registry.load_external_catalog("res://data/item_definitions.json"):\n  push_error("Invalid item catalog; legacy equipment has been retained.")\n CATALOG=item_registry.definitions\n'),
        ('func price_for(sku:String) -> int:return int(CATALOG[sku].price)',
         'func price_for(sku:String) -> int:return item_registry.quote(sku)\nfunc register_item(sku:String,item:Dictionary) -> bool:\n return item_registry.register_definition(sku,item)\nfunc items_in_shop(shop_id:String) -> Array[String]:\n return item_registry.keys_for_shop(shop_id)'),
        ('if bool(CATALOG[e.sku].get("grow_only",false)) and not registry.is_grow_room(property,room):return "Grow equipment can only be placed in grow rooms."',
         'if not item_registry.permits_room(str(e.sku),str(registry.state.properties[property].get("room_uses",{}).get(room,room))):return "This equipment is not allowed in this room."'),
    ]
    for i, (old, new) in enumerate(changes):
        found = s.count(old)
        if found != 1:
            raise AssertionError(f"item registry integration {i}: baseline drift ({found} matches)")
        s = s.replace(old, new, 1)
    return s
