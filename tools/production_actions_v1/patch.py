"""Task-driven worker presentation; retains the existing inventory commit code."""
from pathlib import Path
HERE=Path(__file__).parent

def once(text, old, new):
    assert text.count(old)==1, f'Production animation baseline drift: {old[:80]}'
    return text.replace(old,new,1)

def apply_entries(entries):
    result=[]
    for name,data,flags in entries:
        if name=='scripts/main.gd':
            text=data.decode()
            text=once(text,'if production_worker_action_dwell >= PRODUCTION_WORKER_DWELL_SECONDS:', 'if production_worker_action_dwell >= preload("res://scripts/production_actions.gd").duration(production_worker_pending_action):')
            old='func _production_worker_station_position(station_name: String) -> Vector3:\n'
            text=once(text,old,old+'\tvar action_target:Variant=preload("res://scripts/production_actions.gd").target(self,production_worker_pending_action,production_worker_pending_slot)\n\tif action_target is Vector3 and station_name in ["workbench","grow"]:return action_target\n')
            text=once(text,'\nfunc _inventory_grams(inventory: Dictionary)', '\n\tload("res://scripts/bench_layout.gd").original(self)\n\nfunc _inventory_grams(inventory: Dictionary)')
            text=once(text,'\tfor name_variant in bagged_inventory.keys():\n\t\tvar bagged_name: String = str(name_variant)\n\t\tvar normal_has_space: bool = _total_stored_stock() < _storage_capacity()\n\t\tvar dealer_overflow_available: bool = not normal_has_space and _dealer_locker_free_capacity() > 0\n\t\tif int(bagged_inventory.get(bagged_name, 0)) > 0 and (normal_has_space or dealer_overflow_available):\n\t\t\tvar stock_task: String = "Stocking %s" % bagged_name if normal_has_space else "Overflow stocking Dealer Locker"\n\t\t\t_set_production_worker_task("store", "storage", -1, bagged_name, stock_task)\n\t\t\treturn\n\tfor name_variant in trimmed_inventory.keys():\n\t\tvar trimmed_name: String = str(name_variant)\n\t\tif int(trimmed_inventory.get(trimmed_name, 0)) > 0:\n\t\t\t_set_production_worker_task("bag", "workbench", -1, trimmed_name, "Bagging %s" % trimmed_name)\n\t\t\treturn\n\tfor name_variant in untrimmed_inventory.keys():\n\t\tvar untrimmed_name: String = str(name_variant)\n\t\tif int(untrimmed_inventory.get(untrimmed_name, 0)) > 0:\n\t\t\t_set_production_worker_task("trim", "workbench", -1, untrimmed_name, "Trimming %s" % untrimmed_name)\n\t\t\treturn\n','\tfor name_variant in untrimmed_inventory.keys():\n\t\tvar untrimmed_name: String = str(name_variant)\n\t\tif int(untrimmed_inventory.get(untrimmed_name, 0)) > 0:\n\t\t\t_set_production_worker_task("trim", "workbench", -1, untrimmed_name, "Trimming %s" % untrimmed_name)\n\t\t\treturn\n\tfor name_variant in trimmed_inventory.keys():\n\t\tvar trimmed_name: String = str(name_variant)\n\t\tif int(trimmed_inventory.get(trimmed_name, 0)) > 0:\n\t\t\t_set_production_worker_task("bag", "workbench", -1, trimmed_name, "Bagging %s" % trimmed_name)\n\t\t\treturn\n\tfor name_variant in bagged_inventory.keys():\n\t\tvar bagged_name: String = str(name_variant)\n\t\tvar normal_has_space: bool = _total_stored_stock() < _storage_capacity()\n\t\tvar dealer_overflow_available: bool = not normal_has_space and _dealer_locker_free_capacity() > 0\n\t\tif int(bagged_inventory.get(bagged_name, 0)) > 0 and (normal_has_space or dealer_overflow_available):\n\t\t\tvar stock_task: String = "Stocking %s" % bagged_name if normal_has_space else "Overflow stocking Dealer Locker"\n\t\t\t_set_production_worker_task("store", "storage", -1, bagged_name, stock_task)\n\t\t\treturn\n')
            text=once(text,'\t\tproduction_worker_action_dwell = 0.0\n\t\t_execute_production_worker_action()','\t\tvar finished_action:String=production_worker_pending_action\n\t\tproduction_worker_action_dwell = 0.0\n\t\t_execute_production_worker_action()\n\t\tif finished_action=="trim":_assign_production_worker_task()')
            text=once(text,'\tproduction_worker_task_label.position = Vector3(0, 2.10, 0)','\tproduction_worker_task_label.position = Vector3(0, 2.55, 0)\n\tproduction_worker_task_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED')
            data=text.encode()
        elif name=='scripts/crew_phone.gd':
            text=data.decode();old='\t\tfor player in malik_worker.find_children("*","AnimationPlayer",true,false):'
            text=once(text,old,'\t\tvar work_pose:Node3D=malik_worker.get_node_or_null("ProductionActions")\n\t\tif work_pose==null:\n\t\t\twork_pose=load("res://scripts/production_actions.gd").new();work_pose.name="ProductionActions";malik_worker.add_child(work_pose);work_pose.setup(host,malik_worker)\n\t\twork_pose.sync()\n'+old)
            data=text.encode()
        elif name=='scripts/furniture_editor.gd':
            data=once(data.decode(),' elif sku.begins_with("shelf_")','  load("res://scripts/bench_layout.gd").purchased(root)\n elif sku.begins_with("shelf_")').encode()
        result.append([name,data,flags])
    for name in ['production_actions.gd','production_rig.gd','bench_layout.gd']:
        result.append(['scripts/'+name,(HERE/name).read_bytes(),0])
    return result
