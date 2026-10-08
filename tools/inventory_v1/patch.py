def patch_main(s):
    s=s.replace('func _ready() -> void:\n','func _ready() -> void:\n\t# Recipe outputs are earned through genetics, never purchased as seeds.\n\tfor recipe in _genetics_recipe_catalog():\n\t\tseed_catalog[str(recipe.output)]["recipe_only"]=true\n',1)
    s=s.replace('var storage_level: int = 1', 'var inventory_system: Node\nvar storage_level: int = 1',1)
    s=s.replace('\tneighborhood.setup(self)\n', '\tneighborhood.setup(self)\n\tinventory_system=load("res://scripts/container_inventory.gd").new()\n\tadd_child(inventory_system)\n\tinventory_system.setup(self)\n',1)
    s=s.replace('func _any_modal_open() -> bool:\n','func _any_modal_open() -> bool:\n\tif inventory_system!=null and inventory_system.is_open():return true\n',1)
    for method,kind in [('_open_storage_panel','storage'),('_open_supply_inventory_panel','supply'),('_open_dealer_storage_panel','dealer')]:
        needle='func '+method+'() -> void:\n'
        assert needle in s
        s=s.replace(needle,needle+'\tif inventory_system!=null:\n\t\tinventory_system.open_container("'+kind+'")\n\t\treturn\n',1)
    for method in ['_close_storage_panel','_close_supply_inventory_panel','_close_dealer_storage_panel']:
        needle='func '+method+'() -> void:\n'
        s=s.replace(needle,needle+'\tif inventory_system!=null and inventory_system.is_open():\n\t\tinventory_system.close()\n\t\treturn\n',1)
    s=s.replace('\tsession_paused = true\n', '\tsession_paused = true\n\tif inventory_system!=null:inventory_system.pause_inventory()\n',1)
    s=s.replace('\tsession_paused = false\n\tif web_lifecycle', '\tsession_paused = false\n\tif inventory_system!=null:inventory_system.resume_inventory()\n\tif web_lifecycle',1)
    s=s.replace('"PUT IN STORAGE", _store_product','"TAKE TO BACKPACK", _inventory_take_packed')
    s+='\nfunc _inventory_take_packed(strain_name:String) -> void:\n\tbagging_panel.hide()\n\tinventory_system.open_container("packing")\n\tinventory_system.select_item(inventory_system.container_id,"product|"+strain_name)\n'
    for old,new in {'then deposit them at your apartment computer.': 'then collect them into your backpack and store them at the grow shelf using Add Stock.', 'then deposit carried seeds at your computer.': 'then put carried seeds on your grow shelf using Add Stock.', 'then deposit carried supplies at your apartment computer.': 'then store carried supplies at your grow shelf using Add Stock.', 'Paid equipment waits for computer installation.': 'Paid equipment must be collected into your backpack before computer installation.'}.items():s=s.replace(old,new)
    import importlib.util
    from pathlib import Path
    spec=importlib.util.spec_from_file_location("inventory_release",Path(__file__).with_name("release_patch.py"))
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    s=module.patch_main(patch_stations(s))
    spec=importlib.util.spec_from_file_location("inventory_tutorial",Path(__file__).with_name("tutorial_patch.py"))
    tutorial=importlib.util.module_from_spec(spec);spec.loader.exec_module(tutorial)
    s=tutorial.patch_main(s)
    spec=importlib.util.spec_from_file_location("inventory_session",Path(__file__).with_name("session_patch.py"))
    session=importlib.util.module_from_spec(spec);spec.loader.exec_module(session)
    return restore_packing_minigames(session.patch_main(s))

def patch_stations(s):
    s=s.replace('func _open_bagging_panel() -> void:\n','func _open_bagging_panel() -> void:\n\tif inventory_system!=null:\n\t\tinventory_system.open_container("packing")\n\t\treturn\n',1)
    for name in ['_close_trim_minigame','_close_bag_minigame']:
        start=s.index('func '+name+'()')
        end=s.index('\nfunc ',start+1)
        body=s[start:end]
        body=body.replace('\tbagging_panel.visible = true\n\t_refresh_bagging_panel()', '\tif inventory_system!=null:\n\t\tinventory_system.return_to_packing()\n\telse:\n\t\tbagging_panel.visible = true\n\t\t_refresh_bagging_panel()')
        s=s[:start]+body+s[end:]
    return s

def restore_packing_minigames(source):
    """Maintain the original mouse/touch scissors game across every bench.
    Tier I works small batches; upgraded stations trim the selected strain
    and bag a continuous sequence of 7g, then the final remainder."""
    def replace(old, new):
        nonlocal source
        assert source.count(old) == 1, "packing source drift: " + old[:65]
        source = source.replace(old, new, 1)
    tier = '''func _current_packing_bench_tier() -> int:
\tif inventory_system != null and inventory_system.furniture != null:
\t\tvar packing_id: String = str(inventory_system.packing_return)
\t\tif packing_id.is_empty():
\t\t\tpacking_id = str(inventory_system.operation()) + ":packing"
\t\tvar model: RefCounted = inventory_system.furniture.model
\t\tvar asset: String = model.container_item(packing_id)
\t\tif not asset.is_empty() and model.state.items.has(asset):
\t\t\tvar sku: String = str(model.state.items[asset].get("sku", "bench_1"))
\t\t\treturn maxi(1, int(model.CATALOG.get(sku, {}).get("tier", 1)))
\treturn maxi(1, bagging_level)

'''
    replace("func _packing_drop_size() -> int:\n", tier + "func _packing_drop_size() -> int:\n")
    replace("return 1 if tutorial_active else [1,2,4][clampi(bagging_level-1,0,2)]",
            "return 1 if tutorial_active else [1,2,4][clampi(_current_packing_bench_tier()-1,0,2)]")
    replace("return 3 if tutorial_active else [3,6,12][clampi(bagging_level-1,0,2)]",
            "return 3 if tutorial_active or _current_packing_bench_tier() < 2 else 7")
    replace("trim_harvest_amount = amount\n\ttrim_total_units = mini(amount, 10)",
            "trim_harvest_amount = amount if _current_packing_bench_tier() >= 2 and not tutorial_active else mini(amount, 10)\n\ttrim_total_units = mini(trim_harvest_amount, 10)")
    replace("if bagging_level >= 3 and not tutorial_active and remaining > 0:",
            "if _current_packing_bench_tier() >= 2 and not tutorial_active and remaining > 0:")
    replace("var moved: int = mini(available, bag_target_units)\n\tif moved <= 0:\n\t\treturn",
            'if available < bag_target_units:\n\t\tstatus_label.text = "Packing stock changed. Reopen this strain to weigh the available amount."\n\t\t_close_bag_minigame()\n\t\treturn\n\tvar moved: int = bag_target_units')
    replace("\t_sync_packing_bench_visuals()\n\t_update_room_status_panel()",
            "\t_sync_packing_bench_visuals()\n\tif inventory_system != null and inventory_system.furniture != null and inventory_system.furniture.equipment_world != null:\n\t\tinventory_system.furniture.equipment_world.sync_packing_displays()\n\t_update_room_status_panel()")
    return source
