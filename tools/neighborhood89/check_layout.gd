extends SceneTree
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:failures+=1;push_error(message)
func apps(parent: Node) -> Array[String]:
	var result: Array[String]=[]
	for button in parent.find_children("*","Button",true,false):
		if button.has_meta("phone_app"):result.append(str(button.get_meta("phone_app")))
	return result
func text(parent: Node) -> String:
	var result:=""
	for node in parent.find_children("*","Label",true,false):result+=node.text+"\n"
	return result
func run() -> void:
	var game: Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.session_paused=false;game.tutorial_active=false;game.daily_report_pending=false;game.customer_waiting=false;game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide();game.visit_timer.stop()
	var ops: RefCounted=game.neighborhood.location_ops
	game.phone_current_app="home";game._refresh_phone()
	var home:=apps(game.phone_list)
	check(home.has("shop") and home.has("clients") and home.has("budshop"),"Home contains Store, Contacts and Illegal Businesses")
	check(not home.has("lights") and not home.has("stats"),"Phone Home omits light controls; Stats stays in Businesses")
	game._open_phone_app("budshop");var overview:=apps(game.phone_list)
	check(overview.has("stats") and overview.has("bills") and overview.has("heat"),"Businesses includes Stats, Bills and Heat")
	check(not overview.has("shop") and not overview.has("clients") and not overview.has("lights") and not overview.has("products"),"No duplicate Store/Contacts or apartment controls in phone overview")
	game.business_open=true;game.lay_low_active=false;game._refresh_phone();check("Storefront: OPEN" in text(game.phone_list),"Open status shown")
	game.business_open=false;game._refresh_phone();check("Storefront: AWAY" in text(game.phone_list),"Away status shown")
	game.lay_low_active=true;game._refresh_phone();check("Storefront: LAYING LOW" in text(game.phone_list),"Laying Low takes priority over Away")
	game._open_phone_app("heat")
	for button in game.phone_list.find_children("*","Button",true,false):check(not "LAY LOW" in button.text and not "REOPEN" in button.text,"Heat has no direct property shutdown/reopen buttons")
	game._open_phone_app("shop");check(not apps(game.phone_list).has("supplies"),"Regular Store omits obsolete phone fertilizer purchases")
	game._open_phone_app("lights");check(game.phone_current_app=="budshop","Legacy Lights navigation blocked")
	for app in ["bills","stats","heat"]:check(game._phone_parent_app(app)=="budshop","Back returns to Illegal Businesses: "+app)
	game.phone_open=false;game.phone_panel.hide();game.camera.position=Vector3(3,1.64,4.35);game.camera.look_at(ops.APT_PC)
	ops.computer("apartment");check(ops.management_app=="business" and not game.phone_open,"Computer opens its Business overview")
	for app in ["operations","inventory","property","employees","products","genetics","upgrades","bills"]:
		ops.manage(app);check(ops.management_app==app and ops.is_open() and not game.phone_open,"Computer category reachable: "+app)
	ops.manage("operations");game._open_phone_app("employees");check(ops.management_app=="employees" and not game.phone_open,"Existing management navigation stays inside computer")
	ops.computer("apartment");var count: int=ops.ui.body.find_children("*","Button",true,false).size();check(count==3,"Computer landing has only three section buttons")
	if OS.get_cmdline_user_args().has("--capture"):
		game.set_process(false);game.neighborhood.set_process(false);root.size=Vector2i(420,800)
		for i in range(6):game.session_paused=false;game.pause_overlay.hide();await process_frame
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/scratch/05254e9fc6fb/computer89.png")
		ops.close();game.phone_open=true;game.phone_panel.show();game.phone_current_app="home";game._refresh_phone()
		for i in range(6):game.session_paused=false;game.pause_overlay.hide();await process_frame
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/scratch/05254e9fc6fb/phone89.png")
	game.queue_free();await process_frame;print("Phone/computer .89 layout checks: ",failures," failures");quit(1 if failures else 0)
