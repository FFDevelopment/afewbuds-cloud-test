def patch_main(s):
    for name in ['_assign_production_worker_task','_execute_production_worker_action']:
        signature=f'func {name}() -> void:\n'
        wrapper=signature+f'\tif inventory_system!=null:\n\t\tinventory_system.at_property(inventory_system.worker_property(),{name}_local)\n\telse:{name}_local()\n\nfunc {name}_local() -> void:\n'
        assert signature in s
        s=s.replace(signature,wrapper,1)
    start=s.index('func _assign_production_worker_task_local')
    end=s.index('func _execute_production_worker_action()',start)
    part=s[start:end].replace('for slot_index in range(plant_slots.size()):','for slot_index in range(plant_slots.size()):\n\t\tif inventory_system!=null and inventory_system.furniture.model.slot_property(slot_index)!=inventory_system.worker_property():continue',1)
    part=part.replace('if int(plant_slots[slot_index].get("stage", -1)) < 0 and', 'if (inventory_system==null or inventory_system.furniture.model.slot_property(slot_index)==inventory_system.worker_property()) and int(plant_slots[slot_index].get("stage", -1)) < 0 and')
    s=s[:start]+part+s[end:]
    s=s.replace('\tvar action_id: String = production_worker_pending_action','\tif inventory_system!=null and production_worker_pending_slot>=0 and inventory_system.furniture.model.slot_property(production_worker_pending_slot)!=inventory_system.worker_property():\n\t\tproduction_worker_pending_action=""\n\t\treturn\n\tvar action_id: String = production_worker_pending_action',1)
    signature='func _dealer_sell_one(show_feedback: bool, assigned_dealer_name: String = "", door_customer: Dictionary = {}, door_order: Dictionary = {}) -> bool:\n'
    wrapper=signature+'\tif inventory_system!=null:\n\t\treturn bool(inventory_system.at_property(inventory_system.staff_property(assigned_dealer_name),_dealer_sell_one_local.bind(show_feedback,assigned_dealer_name,door_customer,door_order)))\n\treturn _dealer_sell_one_local(show_feedback,assigned_dealer_name,door_customer,door_order)\n\n'+signature.replace('_dealer_sell_one(', '_dealer_sell_one_local(')
    assert signature in s;s=s.replace(signature,wrapper,1)
    s=s.replace('model.slot_property(i)==inventory_system.operation()', 'model.slot_property(i)==inventory_system.worker_property()')
    signature='func _simulate_offline_plants(elapsed_seconds: float, worker_care: bool = false) -> void:\n'
    replacement=signature+'\tif inventory_system!=null and inventory_system.furniture!=null and inventory_system.controlled(inventory_system.worker_property()+":packing"):\n\t\tinventory_system.at_property(inventory_system.worker_property(),_simulate_offline_plants_local.bind(elapsed_seconds,worker_care))\n\telse:_simulate_offline_plants_local(elapsed_seconds,worker_care and (inventory_system==null or inventory_system.controlled(inventory_system.worker_property()+":packing")))\n\n'+signature.replace('_simulate_offline_plants(', '_simulate_offline_plants_local(')
    assert signature in s;s=s.replace(signature,replacement,1)
    for name,params,args in [('_plant_seed','slot_index: int, strain_name: String, use_backpack: bool = true','slot_index,strain_name,use_backpack'),('_water_plant','slot_index: int','slot_index'),('_fertilize_plant','slot_index: int','slot_index'),('_harvest_plant','slot_index: int','slot_index')]:
        signature=f'func {name}({params}) -> void:\n'
        replacement=signature+f'\tif inventory_system!=null and inventory_system.furniture!=null:\n\t\tinventory_system.at_property(inventory_system.furniture.model.slot_property(slot_index),{name}_local.bind({args}))\n\telse:{name}_local({args})\n\n'+signature.replace(name+'(',name+'_local(')
        assert signature in s;s=s.replace(signature,replacement,1)
    signature='func _refresh_direct_plant_panel() -> void:\n'
    replacement=signature+'\tif inventory_system!=null and inventory_system.furniture!=null and selected_plant_slot>=0:\n\t\tinventory_system.at_property(inventory_system.furniture.model.slot_property(selected_plant_slot),_refresh_direct_plant_panel_local)\n\telse:_refresh_direct_plant_panel_local()\n\n'+signature.replace('_refresh_direct_plant_panel(', '_refresh_direct_plant_panel_local(')
    assert signature in s;s=s.replace(signature,replacement,1)
    return s

def patch_crew(s):
    for name,params,args in [('packaged_stock','',''),('product_stock','product: String','product')]:
        signature=f'func {name}({params}) -> int:\n'
        replacement=signature+f'\tif host.inventory_system!=null:return int(host.inventory_system.at_property("apartment",{name}_local'+(f'.bind({args})' if args else '')+'))\n\treturn '+name+'_local('+args+')\n\n'+signature.replace(name+'(',name+'_local(')
        assert signature in s;s=s.replace(signature,replacement,1)
    s=s.replace('host._total_seed_inventory()==0','property_supply_empty(assignment(worker),"seed|")').replace('host.fertilizer_units==0','property_supply_empty(assignment(worker),"fertilizer")')
    s=s.replace('host._dealer_locker_total()==0','property_supply_empty(assignment(host._critical_dealer_sender()),"product|", "dealer")')
    s+='''
func property_supply_empty(property:String,prefix:String,kind:String="supply") -> bool:
	if host.inventory_system==null:return false
	for item in host.inventory_system.contents(property+":"+kind):
		if str(item).begins_with(prefix) and int(host.inventory_system.contents(property+":"+kind)[item])>0:return false
	return true
'''
    return s
