def patch_main(s):
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
    return s
