extends SceneTree
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures+=1;push_error(message)
func settle(game: Node3D) -> void:
	for frame in range(5):
		game.session_paused=false;game.pause_overlay.hide();await process_frame
func run() -> void:
	var game: Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process(false);game.neighborhood.set_process(false);game.tutorial_active=false;game.daily_report_pending=false;game.customer_waiting=false;game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide();game.visit_timer.stop();game.session_paused=false
	var world: Node3D=game.neighborhood
	var hud: RefCounted=world.mobile_hud
	world.active=true;world.controls.show()
	game.camera.position=Vector3(-25,1.7,20);hud.update(0.1)
	check(not world.action.visible,"No action when no target nearby")
	check(world.pad.visible,"Walking stick visible")
	check(not game.view_label.visible and not game.contextual_button.visible,"No redundant walking labels/buttons")
	game.camera.position=Vector3(0,1.7,4.5);world._process(0.016)
	check(world.action.visible,"Nearby door exposes single action")
	hud.update(6.0);check(not game.status_label.visible,"Instruction fades")
	game.phone_text_unread+=1;hud.update(0.1);check(game.status_label.visible and "New message" in game.status_label.text,"Unread message briefly notifies")
	hud.update(5.0);check(not game.status_label.visible,"Message notification fades")
	game.phone_open=true;game.phone_panel.show();hud.update(0.1)
	check(not world.pad.visible and not world.action.visible,"Phone hides movement and action")
	game.phone_open=false;game.phone_panel.hide()
	var ops: RefCounted=world.location_ops
	game.cash=200;game.location_state.pickup_fertilizer=0;game.location_state.carried_fertilizer=0
	var shelf: int=game.fertilizer_units
	ops.order_fertilizer()
	check(game.cash==155 and game.location_state.pickup_fertilizer==5 and game.fertilizer_units==shelf,"Fertilizer order charges once and waits for pickup")
	game.location_state.pickup_fertilizer=50;ops.order_fertilizer();check(game.cash==155,"Pending capacity blocks charging")
	game.location_state.pickup_fertilizer=5;game.location_state.carried_fertilizer=48
	game.camera.position=ops.CHECKOUT+Vector3(0,0,-1);game.camera.look_at(ops.CHECKOUT);ops.pickup()
	check(game.location_state.carried_fertilizer==50 and game.location_state.pickup_fertilizer==3 and game.cash==155,"Partial pickup preserves remainder and does not charge again")
	game._open_phone_app("shop")
	var supplies:=false
	for button in game.phone_list.find_children("*","Button",true,false):
		if button.get_meta("phone_app","")=="supplies":supplies=true
	check(supplies,"Store contains Supplies")
	ops.close();game.phone_open=false;game.phone_panel.hide()
	if OS.get_cmdline_user_args().has("--capture"):
		for size in [Vector2i(720,1280),Vector2i(1440,900)]:
			root.size=size;world._update_screen_layout();await settle(game)
			world.active=true;world.controls.show();game.camera.position=Vector3(-1.8,1.7,1.6);game.camera.look_at(Vector3(-2.28,1,3.07));world._process(0.016);hud.update(6.0);await settle(game)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/workspace/scratch/05254e9fc6fb/mobile90-"+str(size.x)+".png")
			check(world.pad.get_global_rect().end.x<world.action.get_global_rect().position.x,"Stick and action do not overlap")
	print("Mobile HUD/supply pickup .90 checks: ",failures," failures")
	game.queue_free();await process_frame;quit(1 if failures else 0)
