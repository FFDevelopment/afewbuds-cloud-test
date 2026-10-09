import re

def edit_function(s,name,edit):
    start=s.index('func '+name+'(')
    end=s.find('\nfunc ',start+1)
    if end<0:end=len(s)
    return s[:start]+edit(s[start:end])+s[end:]

def patch_main(s):
    for name in ['_refresh_direct_plant_panel','_refresh_grow_panel']:
        def ui(body):
            body=re.sub(r'int\(seed_inventory.get\((\w+), 0\)\)',r'_usable_seed_count(\1)',body)
            body=body.replace('fertilizer_units','_usable_fertilizer_count()')
            body=body.replace('No seeds owned. Buy unlocked seeds from the phone.','No seeds available. Collect seed orders at Central Market.')
            body=body.replace('Fertilizer stock: %d uses','Fertilizer available: %d')
            body=body.replace('Choose an owned seed. Planting happens here in the world instead of from the full grow menu.','Choose a seed from your backpack or grow shelf.')
            return body
        s=edit_function(s,name,ui)
    s=edit_function(s,'_plant_seed',lambda b:b.replace('strain_name: String)', 'strain_name: String, use_backpack: bool = true)').replace('int(seed_inventory.get(strain_name, 0))','_usable_seed_count(strain_name) if use_backpack else int(seed_inventory.get(strain_name, 0))').replace('seed_inventory[strain_name] = count - 1','if not _consume_seed(strain_name, use_backpack):return'))
    s=edit_function(s,'_execute_production_worker_action',lambda b:b.replace('_plant_seed(slot_index, strain_name)','_plant_seed(slot_index, strain_name, false)'))
    s=edit_function(s,'_fertilize_plant',lambda b:b.replace('fertilizer_units <= 0','_usable_fertilizer_count() <= 0').replace('fertilizer_units -= 1','if not _consume_fertilizer():return'))
    s=edit_function(s,'_player_available_amount',lambda b:b.replace('return _available_amount(product_name)','return _available_amount(product_name) + _carried_amount("product|"+product_name)'))
    s=edit_function(s,'_player_product_sellable',lambda b:b.replace('_available_amount(product_name) > 0','_player_available_amount(product_name) > 0'))
    s=edit_function(s,'_consume_player_sale_stock',lambda b:'func _consume_player_sale_stock(product_name: String, qty: int) -> bool:\n\tif qty<=0 or not products.has(product_name) or _player_available_amount(product_name)<qty:return false\n\tvar carried:int=mini(qty,_carried_amount("product|"+product_name))\n\tif carried>0:_consume_carried("product|"+product_name,carried)\n\tvar data:Dictionary=products[product_name]\n\tdata["stock"]=int(data.get("stock",0))-(qty-carried)\n\tproducts[product_name]=data\n\treturn true\n')
    s=edit_function(s,'_effective_price',lambda b:b.replace('var equipment_bonus: int = maxi(0, bagging_level - 1)','var equipment_bonus: int = 0'))
    s=edit_function(s,'_start_bag_minigame',lambda b:re.sub(r'\tif bagging_level >= 3 and not tutorial_active:\n\t\tbag_target_units = .*?\n\telse:\n\t\tbag_target_units = mini\(3, amount\)', '\tbag_target_units = mini(_packing_batch_size(), amount)', b))
    s=edit_function(s,'_seal_current_bag',lambda b:b.replace('rng.randi_range(1, mini(4, remaining))','mini(_packing_batch_size(), remaining)'))
    s=edit_function(s,'_finish_bud_drag',lambda b:b.replace('bag_current_units += 1','bag_current_units += _packing_drop_size()'))
    s=s.replace('Each drop adds one game unit to the scale.','Each drop adds up to %dg.' ) if False else s
    s=s.replace('"Drag buds into the open bag. Each drop adds one game unit to the scale."','"Drag product into the bag. Each drop adds up to %dg." % _packing_drop_size()')
    s=s.replace('Level III perk: continuous 1-4g manual bagging until the selected strain is fully packaged.','Bench II: 2g per drop, 6g batches. Bench III: 4g per drop, 12g batches and continuous packing.')
    s=s.replace('packaged and available from normal storage','packaged and ready to sell').replace('business normal storage','your backpack or storage').replace('No substitute has enough stock in normal storage.','No alternative has enough packaged stock.')
    # Keep developer terminology out of player-facing descriptions.
    s=s.replace('Dense fictional dessert-profile','Dense dessert-profile').replace('Top-shelf fictional reserve','Top-shelf reserve').replace('A fictional crossbreed','A crossbreed').replace('A fictional cold-fruit','A cold-fruit').replace('A fictional gold-and-berry','A gold-and-berry').replace('A fictional prestige','A prestige').replace('A fictional investigator','An investigator').replace('Fictional game genetics.','Strain genetics.').replace('create fictional hybrid seeds','create hybrid seeds')
    for old,new in {'Better packaging adds value to every sale.': 'Pack up to 2g per drop in 6g batches.', 'Industrial production workstation. Enables continuous manual bagging with variable 1-4g bags until the selected strain is fully packaged.': 'Pack up to 4g per drop in 12g batches and continue automatically with the next bag.', 'and _player_available_amount(product_name) > 0': 'and _player_available_amount(product_name) > 0', 'bool(data.get("listed", false)) and _player_available_amount(product_name) > 0': '(bool(data.get("listed", false)) or _carried_amount("product|"+product_name)>0) and _player_available_amount(product_name)>0', 'return _available_amount(product_name) + _carried_amount("product|"+product_name)': 'return (_available_amount(product_name) if bool(products.get(product_name,{}).get("listed",false)) else 0) + _carried_amount("product|"+product_name)', 'Supply Shelf Lv %d   |   Seeds %d/%d   |   Fertilizer %d/%d" % [grow_tent_count, tent_level, plant_slots.size(), bagging_level, storage_level, _storage_capacity(), supply_shelf_level, _total_seed_inventory(), _supply_seed_capacity(), fertilizer_units, _supply_fertilizer_capacity()]': 'Supply Shelf Lv %d" % [grow_tent_count, tent_level, plant_slots.size(), bagging_level, storage_level, _storage_capacity(), supply_shelf_level]'}.items():s=s.replace(old,new)
    return s+HELPERS

HELPERS='\nfunc _carried_amount(item:String) -> int:\n\tif inventory_system==null:return 0\n\treturn maxi(0,int(inventory_system.contents("backpack").get(item,0)))\nfunc _consume_carried(item:String,amount:int) -> bool:\n\tif amount<=0 or _carried_amount(item)<amount:return false\n\tinventory_system.set_amount("backpack",item,_carried_amount(item)-amount)\n\tinventory_system.revision+=1\n\treturn true\nfunc _usable_seed_count(strain:String) -> int:\n\treturn maxi(0,int(seed_inventory.get(strain,0)))+_carried_amount("seed|"+strain)\nfunc _usable_fertilizer_count() -> int:\n\treturn maxi(0,fertilizer_units)+_carried_amount("fertilizer")\nfunc _consume_seed(strain:String,use_backpack:bool=true) -> bool:\n\tif use_backpack and _consume_carried("seed|"+strain,1):return true\n\tif int(seed_inventory.get(strain,0))<=0:return false\n\tseed_inventory[strain]=int(seed_inventory[strain])-1\n\tif inventory_system!=null:inventory_system.revision+=1\n\treturn true\nfunc _consume_fertilizer() -> bool:\n\tif _consume_carried("fertilizer",1):return true\n\tif fertilizer_units<=0:return false\n\tfertilizer_units-=1\n\tif inventory_system!=null:inventory_system.revision+=1\n\treturn true\nfunc _packing_drop_size() -> int:\n\treturn 1 if tutorial_active else [1,2,4][clampi(bagging_level-1,0,2)]\nfunc _packing_batch_size() -> int:\n\treturn 3 if tutorial_active else [3,6,12][clampi(bagging_level-1,0,2)]\n'
