def patch_main(s):
    s=s.replace('var inventory_system: Node','var last_save_ok: bool = false\nvar inventory_system: Node',1)
    s=s.replace('func _save_game() -> void:\n','func _save_game() -> void:\n\tlast_save_ok=false\n',1)
    s=s.replace('\tfile.store_string(JSON.stringify(data))\n\tfile.close()', '\tfile.store_string(JSON.stringify(data))\n\tfile.flush()\n\tlast_save_ok=file.get_error()==OK\n\tfile.close()',1)
    s=s.replace('\t_add_phone_dock_button(dock, "SETTINGS", "settings")\n','')
    s=s.replace('\t_add_phone_app_tile(grid, "", "Settings", "Help & system controls", "settings")\n','')
    s=s.replace('Phone > Help','Pause > Help')
    a=s.index('func _phone_safe_quit()');b=s.index('\nfunc ',a+1)
    s=s[:a]+"""func _phone_safe_quit() -> void:
	var menu:Node=inventory_system.session_menu
	if menu.quitting:return
	menu.quitting=true
	phone_open=false;phone_panel.hide()
	_pause_gameplay()
	_save_game()
	if not last_save_ok:
		menu.quit_failed("Could not save on this device. Please try again. The game is still open.")
		return
	if OS.has_feature("web"):
		var until:int=Time.get_ticks_msec()+15000
		while str(JavaScriptBridge.eval("window.AFB_QUIT_SAVE_STATE || 'pending'",true))=="pending" and Time.get_ticks_msec()<until:
			await get_tree().process_frame
		if str(JavaScriptBridge.eval("window.AFB_QUIT_SAVE_STATE || 'pending'",true))!="saved":
			menu.quit_failed("Saving could not be confirmed. Keep this tab open and try again.")
			return
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.AFB_RELEASE_STATE='pending';window.AFB_CLOUD.releasePlay().then(()=>window.AFB_RELEASE_STATE='saved').catch(()=>window.AFB_RELEASE_STATE='failed');",true)
		var release_until:int=Time.get_ticks_msec()+15000
		while str(JavaScriptBridge.eval("window.AFB_RELEASE_STATE",true))=="pending" and Time.get_ticks_msec()<release_until:await get_tree().process_frame
		if str(JavaScriptBridge.eval("window.AFB_RELEASE_STATE",true))!="saved":
			menu.quit_failed("Could not finish cloud saving. Keep this tab open and retry.")
			return
	menu.quit_saved()
"""+s[b:]
    s=s.replace('func _resume_gameplay() -> void:\n','func _resume_gameplay() -> void:\n\tif inventory_system!=null and inventory_system.session_menu!=null and (inventory_system.session_menu.quitting or inventory_system.session_menu.cloud_locked):return\n')
    s=s.replace("SAVE & SLEEP / QUIT","SAVE & QUIT").replace("Sleep / safe quit","Save & quit")
    s=s.replace('\tif inventory_system!=null:inventory_system.pause_inventory()','\tif inventory_system!=null:inventory_system.pause_inventory()\n\tif inventory_system!=null and inventory_system.session_menu!=null:inventory_system.session_menu.show_page("home")',1)
    s=s.replace('\t_add_phone_dock_button(dock, "TASKS", "task")','\t_add_phone_dock_button(dock, "TASKS", "task")\n\t_add_phone_dock_button(dock, "PAUSE", "pause")')
    s=s.replace('func _open_phone_app(app_name: String) -> void:\n','func _open_phone_app(app_name: String) -> void:\n\tif app_name=="pause":\n\t\tphone_open=false;phone_panel.hide()\n\t\t_cancel_phone_gesture()\n\t\t_pause_gameplay()\n\t\treturn\n')
    return s
