"""Add stable-ID property registry to the mobile game without rewriting career data.

This is the same registry implementation as desktop. Old apartment/house
inventory, utility, furniture and staffing structures remain authoritative.
"""
def patch_furniture(source: str) -> str:
    changes = [
        ("var host:Node\n", "var host:Node\nvar registry:RefCounted\n"),
        ("func setup(owner:Node) -> void:\n host=owner\n", 'func setup(owner:Node) -> void:\n host=owner\n registry=load("res://scripts/property_registry.gd").new()\n registry.setup(owner, ROOMS)\n'),
        ('func controlled(property:String) -> bool:\n if property=="apartment":return bool(host.apartment_rent_state.get("lease_active",true))\n return property=="house" and bool(host.property_opportunity_state.get("acquired",false))',
         'func controlled(property:String) -> bool:\n return registry!=null and registry.controlled(property)\nfunc property_at(world_point:Vector3) -> String:\n return registry.property_at(world_point) if registry!=null else ""'),
        ('if is_tent(e) and e.get("property","") in ROOMS:n+=1',
         'if is_tent(e) and registry.exists(str(e.get("property",""))):n+=1'),
        ('return not id.is_empty() and state.items[id].get("property","") in ROOMS',
         'return not id.is_empty() and registry.exists(str(state.items[id].get("property","")))'),
        ('if container_of(id)==container and state.items[id].get("property","") in ROOMS:return id',
         'if container_of(id)==container and registry.exists(str(state.items[id].get("property",""))):return id'),
        ('if e.get("property","") in ROOMS and e.property!=property:return "Pick up this item into your backpack before moving it to another property."',
         'if registry.exists(str(e.get("property",""))) and e.property!=property:return "Pick up this item into your backpack before moving it to another property."'),
        ('if e.get("property","")!="backpack" and e.get("property","") not in ROOMS:return "Collect this item into your backpack first."',
         'if e.get("property","")!="backpack" and not registry.exists(str(e.get("property",""))):return "Collect this item into your backpack first."'),
        ('for key in ROOMS[property]:\n  if (ROOMS[property][key] as Rect2).grow(.35 if e.sku=="storage_5" else 0.14).encloses(rect):room=key;break',
         'var allowed_rooms:Dictionary=registry.rooms_for(property)\n for key in allowed_rooms:\n  if (allowed_rooms[key] as Rect2).grow(.35 if e.sku=="storage_5" else 0.14).encloses(rect):room=key;break'),
        ('if bool(CATALOG[e.sku].get("grow_only",false)) and room!="grow":return "Grow equipment can only be placed in grow rooms."',
         'if bool(CATALOG[e.sku].get("grow_only",false)) and not registry.is_grow_room(property,room):return "Grow equipment can only be placed in grow rooms."'),
        ('if e.get("property","") not in ROOMS:error="Only placed equipment can be picked up.";return false',
         'if not registry.exists(str(e.get("property",""))):error="Only placed equipment can be picked up.";return false'),
        ('if e.get("property","") in ROOMS and not sku.begins_with("shelf_"):',
         'if registry.exists(str(e.get("property",""))) and not sku.begins_with("shelf_"):'),
        ('if e.get("property","")!=property or property not in ROOMS:continue',
         'if e.get("property","")!=property or not registry.exists(property):continue'),
    ]
    for n, (old, new) in enumerate(changes):
        amount = source.count(old)
        if amount != 1:
            raise AssertionError(f"dynamic property patch anchor {n}: found {amount}; refused to change potentially incompatible save schema")
        source = source.replace(old, new, 1)
    return source
