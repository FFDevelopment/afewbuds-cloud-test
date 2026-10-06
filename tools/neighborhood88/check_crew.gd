extends SceneTree
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures+=1;push_error(message)
func run() -> void:
	var game: Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.tutorial_active=false;game.tutorial_panel.hide();game.session_paused=false;game.daily_report_pending=false;game.pause_overlay.hide();game.daily_report_panel.hide();game.customer_waiting=false;game.visit_timer.stop()
	var n: Node3D=game.neighborhood;var ops: RefCounted=n.location_ops;var crew: RefCounted=ops.crew
	game.phone_text_messages.assign([{"sender":"Rod","body":"Story stays here","read":false},{"sender":"Malik","body":"Hey","read":false}]);game.phone_text_unread=2
	crew.thread="";game.phone_current_app="texts";game._refresh_phone();check(game.phone_text_unread==2,"Inbox does not mark all threads read")
	crew.open_thread("Malik");check(game.phone_text_unread==1,"Opening Malik thread leaves Rod unread")
	check(crew.unread("Rod")==1 and crew.unread("Malik")==0,"Contact unread counts")
	game.phone_open=false;game.phone_panel.hide();game.packing_employee_hired=true;game.packing_employee_active=true;game.dealer_count=1;game.dealers_active=true
	var dealer: String=game._active_dealer_roster()[0]
	crew.assign(dealer,"apartment");crew.assign_manager(dealer)
	check(crew.assignment(dealer)=="apartment" and crew.manager()==dealer,"Dealer property and manager assignment")
	crew.assign(dealer,"house");check(crew.assignment(dealer)=="apartment","Unacquired house assignment rejected")
	game.main_ceiling_light_on=true;game.floor_lamp_on=true;game.grow_room_light_on=true;game.grow_lights_on=true;game.ventilation_installed=true;game.ventilation_on=true
	crew.command(dealer,"shutdown")
	check(game.lay_low_active and not game.business_open and not game.packing_employee_active and not game.dealers_active,"Remote shutdown stops sales and crew work")
	check(not game.main_ceiling_light_on and not game.floor_lamp_on and not game.grow_room_light_on and not game.grow_lights_on and not game.ventilation_on,"All apartment electrical circuits shut down")
	check(game._current_power_rate_per_game_minute()==0 and not game._offline_worker_care_enabled(),"No new power or offline worker water use during shutdown")
	check(n.house_controls.shades.ApartmentBlind.closed,"Shutdown closes apartment blinds")
	game._update_production_worker_visual(1);check(game.production_worker_node.visible,"Production worker remains inside while laying low")
	game.heat=80;crew.command(dealer,"reopen");check(not game.business_open,"Heat lock respected by remote reopen")
	game.heat=0;crew.command(dealer,"reopen");check(game.business_open and game.packing_employee_active and game.dealers_active,"Reopen restores previously on-duty staff")
	game.phone_open=false;game.phone_panel.hide();game.seed_inventory={};game.fertilizer_units=0;game.locker_weed={}
	var count: int=game.phone_text_messages.size();crew.update(11);var after: int=game.phone_text_messages.size();crew.update(11)
	check(after>count and game.phone_text_messages.size()==after,"Empty stock alerts fire once without repeat spam")
	var seed: String=game.SEED_ORDER[0];game.seed_inventory[seed]=1;game.fertilizer_units=1;game.locker_weed[seed]=1;crew.update(11)
	game.seed_inventory={};game.fertilizer_units=0;game.locker_weed={};crew.update(11);check(game.phone_text_messages.size()>after,"Refilling rearms empty stock alerts")
	var client: Dictionary=game.customers[0];client=client.duplicate(true)
	client["tier"]="Local";game.customers[0]=client;game.customer_relationships[str(client.name)]={"visits":10,"player_sales":3,"sales":3}
	var product: String=str(client.favorite);game.products[product]={"stock":10,"listed":true,"price":20,"grade":"B"};game.locker_weed[product]=10;game.dealer_locker_level=1;game.dealer_balance_due=0;game.dealer_customers_served_today={}
	game.current_customer=client;game.active_request={"product":product,"qty":2};game.customer_waiting=false
	var gross: int=game.lifetime_revenue;var cash: int=game.dealer_cash_held
	check(crew.serve_visit(client,game.active_request),"Assigned dealer serves actual client door request")
	check(int(game.locker_weed[product])==8 and game.lifetime_revenue>gross and game.dealer_cash_held>cash,"Door sale uses locker and original revenue/settlement accounting")
	check(not crew.serve_visit(client,{"product":product,"qty":2}),"Daily dealer pool prevents double-selling same client")
	var model: Node3D=crew.malik_instance();root.add_child(model)
	var skeletons=model.find_children("*","Skeleton3D",true,false);check(skeletons.size()==1 and skeletons[0].get_bone_count()==56,"Malik GLB retains 56-bone rig")
	check(model.find_children("*","MeshInstance3D",true,false).size()>0,"Malik has imported skinned mesh")
	for player in model.find_children("*","AnimationPlayer",true,false):check(not player.current_animation.is_empty(),"Malik starts arms-down idle animation")
	game._save_game();var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH));check(saved.location_state.get("apartment_manager","")==dealer and saved.location_state.staff_assignments.has(dealer),"Property staff state saved")
	if OS.get_cmdline_user_args().has("--capture"):
		game.set_process(false);n.set_process(false);model.show();model.position=Vector3(2,0,3.2);model.look_at(Vector3(0,0,1));game.packing_employee_hired=true;game.production_worker_friend_name="Malik";game.production_worker_node.position=Vector3(2.0,0,3.2);crew.update_malik();game._update_production_worker_visual(0);game.production_worker_node.hide()
		game.camera.position=Vector3(0.0,1.5,1.0);game.camera.look_at(Vector3(2,1.05,3.2));game.phone_open=false;game.phone_panel.hide();game.pause_overlay.hide();root.size=Vector2i(1280,800)
		for i in range(8):
			game.session_paused=false;game.pause_overlay.hide();game.production_worker_node.visible=false;await process_frame
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/scratch/05254e9fc6fb/malik88.png")
		crew.open_thread("Malik");root.size=Vector2i(420,800)
		for i in range(6):
			game.session_paused=false;game.pause_overlay.hide();await process_frame
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/scratch/05254e9fc6fb/thread88.png")
	model.queue_free();game.queue_free();await process_frame
	print("Crew/threads/Malik .88 checks: ",failures," failures");quit(1 if failures else 0)
