"""Keep original apartment grow panels from counting house plant slots."""
def apply(s):
    old_loop="\tfor slot_variant: Variant in plant_slots:\n\t\tif not (slot_variant is Dictionary):"
    new_loop="\tvar apartment_capacity:int=0\n\tfor slot_index in range(plant_slots.size()):\n\t\tif inventory_system!=null and inventory_system.furniture!=null and inventory_system.furniture.model.slot_property(slot_index)!=\"apartment\":continue\n\t\tapartment_capacity+=1\n\t\tvar slot_variant:Variant=plant_slots[slot_index]\n\t\tif not (slot_variant is Dictionary):"
    assert s.count(old_loop)==2, "Apartment grow status loops changed"
    s=s.replace(old_loop,new_loop)
    old_capacity="[display_state, active_plants, plant_slots.size(), ready_plants, \"ON\" if grow_lights_on else \"OFF\", vent_text]"
    assert s.count(old_capacity)==1
    s=s.replace(old_capacity,"[display_state, active_plants, apartment_capacity, ready_plants, \"ON\" if grow_lights_on else \"OFF\", vent_text]",1)
    old_status="func _grow_room_status_text() -> String:\n\tvar installed_tents: int = clampi(grow_tent_count, 1, 3)\n\tvar total_slots: int = installed_tents * 3\n\treturn \"Room systems are stable. %d tent(s) installed  |  %d plant slots  |  ventilation and lighting online.\" % [installed_tents, total_slots]"
    assert s.count(old_status)==1
    s=s.replace(old_status,"func _grow_room_status_text() -> String:\n\tvar installed_tents:int=0\n\tvar total_slots:int=0\n\tif inventory_system!=null and inventory_system.furniture!=null:\n\t\tvar model:RefCounted=inventory_system.furniture.model\n\t\tfor e in model.state.items.values():\n\t\t\tif e.get(\"property\",\"\")!=\"apartment\" or not e.has(\"position\") or not model.is_tent(e):continue\n\t\t\tinstalled_tents+=1\n\t\t\ttotal_slots+=e.get(\"slots\",[]).size()\n\telse:\n\t\tinstalled_tents=clampi(grow_tent_count,1,3)\n\t\ttotal_slots=installed_tents*3\n\treturn \"Apartment grow room: %d placed tent(s)  |  %d available plant slots.\" % [installed_tents,total_slots]",1)
    return s
