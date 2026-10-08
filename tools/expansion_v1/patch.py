def patch_main(s):
    s=s.replace('func _any_modal_open() -> bool:\n','func _any_modal_open() -> bool:\n\tif inventory_system!=null and inventory_system.packing!=null and inventory_system.packing.is_open():return true\n\tif inventory_system!=null and inventory_system.furniture!=null and inventory_system.furniture.is_open():return true\n',1)
    s=s.replace('func _plant_seed(slot_index: int, strain_name: String, use_backpack: bool = true) -> void:\n','func _plant_seed(slot_index: int, strain_name: String, use_backpack: bool = true) -> void:\n\tif inventory_system!=null and inventory_system.furniture!=null and not inventory_system.furniture.model.can_plant(slot_index):\n\t\tstatus_label.text="Place the grow tent before planting."\n\t\treturn\n',1)
    start=s.index('\telse:\n\t\tobjectives.text =',s.index('"STORY\\nCHAPTER 5'))
    end=s.index('\n\n\tobjectives.custom_minimum_size',start)
    return s[:start]+'\telse:\n\t\tobjectives.text = inventory_system.furniture.chapter.description()'+s[end:]
