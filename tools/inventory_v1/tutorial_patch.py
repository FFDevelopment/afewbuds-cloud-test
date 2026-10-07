import re

def patch_main(s):
    def replace_function(name,body):
        nonlocal s
        start=s.index('func '+name+'(');end=s.find('\nfunc ',start+1)
        if end<0:end=len(s)
        body=body.replace('tutorial_panel.add_child(root)','var intro_scroll:=PhoneTouchScroll.new()\n\tintro_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED\n\tintro_scroll.follow_focus=true\n\troot.size_flags_horizontal=Control.SIZE_EXPAND_FILL\n\ttutorial_panel.add_child(intro_scroll)\n\tintro_scroll.add_child(root)')
        s=s[:start]+body+s[end:]
    replace_function('_build_help_app','func _build_help_app() -> void:\n\tif inventory_system!=null and inventory_system.guide!=null:inventory_system.guide.populate_help(phone_list)\n')
    replace_function('_dismiss_tutorial','func _dismiss_tutorial() -> void:\n\tif inventory_system!=null and inventory_system.guide!=null:inventory_system.guide.start()\n')
    replace_function('_skip_tutorial','func _skip_tutorial() -> void:\n\tif inventory_system!=null and inventory_system.guide!=null:inventory_system.guide.skip()\n')
    s=s.replace('func _tutorial_record(action: String, slot_index: int = -1, strain_name: String = "") -> void:\n','func _tutorial_record(action: String, slot_index: int = -1, strain_name: String = "") -> void:\n\tif inventory_system!=null and inventory_system.guide!=null:inventory_system.guide.record(action,slot_index)\n')
    s=s.replace('return reset_confirmation_open or reset_in_progress or session_paused or daily_report_pending or tutorial_active','return _guide_protects_plants() or reset_confirmation_open or reset_in_progress or session_paused or daily_report_pending or tutorial_active')
    s=s.replace('return not tutorial_active and (tutorial_panel','return not _guide_protects_plants() and not tutorial_active and (tutorial_panel')
    s=s.replace('\t_increment_advancement_stat("sales")','\tif inventory_system!=null and inventory_system.guide!=null:inventory_system.guide.record("sale")\n\t_increment_advancement_stat("sales")')
    start=s.index('func _build_tutorial_panel()');end=s.index('func _show_tutorial()',start)
    body=s[start:end];body=re.sub(r'body.text = ".*?"\n', 'body.text = "Welcome to Bongchester. Learn movement, your phone and backpack, market orders, growing, packing and selling.\\n\\nFollow the on-screen guide and do each action yourself. Time and plants are protected until the sale lesson. Controls match your device and current bindings.\\n\\nYou can skip any step or resume from Phone > Help."\n', body,count=1)
    body=body.replace('tutorial_panel.add_child(root)','var intro_scroll:=PhoneTouchScroll.new()\n\tintro_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED\n\tintro_scroll.follow_focus=true\n\troot.size_flags_horizontal=Control.SIZE_EXPAND_FILL\n\ttutorial_panel.add_child(intro_scroll)\n\tintro_scroll.add_child(root)')
    s=s[:start]+body+s[end:]
    s+='\nfunc _guide_protects_plants() -> bool:\n\tvar guide:Dictionary=location_state.get("first_day_guide",{})\n\treturn bool(guide.get("active",false)) and int(guide.get("step",0))<16\n'
    return s
