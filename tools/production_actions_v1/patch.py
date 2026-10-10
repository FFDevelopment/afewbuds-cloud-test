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
