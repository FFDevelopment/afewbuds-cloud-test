extends SceneTree
## End-to-end UI and role-transfer test with disposable career data only.
var failures:int=0
var checks:int=0
func check(ok:bool,note:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+note)
	else:print("PASS: ",note)
func labels(node:Node)->String:
	var text_content:=""
	for child in node.find_children("*","Control",true,false):
		if child is Label or child is Button:
			text_content+=str(child.text)+"\n"
	return text_content
func _initialize()->void:call_deferred("run")
func run()->void:
	check(not OS.has_feature("web") and "tmp" in OS.get_user_data_dir(),"Mobile staff test uses disposable headless save location")
	if failures>0:quit(1);return
	var is_desktop:bool=ResourceLoader.exists("res://prototype/apartment.tscn")
	var game:Node3D=load("res://prototype/apartment.tscn" if is_desktop else "res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(20):await process_frame
	game.set_process(false);game.neighborhood.set_process(false)
	if is_desktop:game.fp_player.set_physics_process(false)
	elif game.neighborhood.physics_body!=null:game.neighborhood.physics_body.set_physics_process(false)
	for timer in game.find_children("*","Timer",true,false):timer.stop()
	game.gameplay_ready=true;game.session_paused=false;game.tutorial_active=false;game.daily_report_pending=false
	game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide()
	var ops:RefCounted=game.neighborhood.location_ops
	var crew:RefCounted=ops.crew
	game.cash=100000;game.grower_level=12
	game.property_offer_unlocked=true
	game.property_opportunity_state["acquired"]=true
	game.property_opportunity_state["relocated"]=true
	game.apartment_rent_state["lease_active"]=true
	game.packing_employee_hired=true;game.packing_employee_active=true;game.production_worker_friend_name="Malik"
	game.friend_staff_roles={"Malik":"production","Tyler":"dealer"}
	game.dealer_count=0;game.dealers_active=true
	game.location_state["staff_assignments"]={"Malik":"house","Tyler":"apartment"}
	game.friend_dealer_stats["Tyler"]={"sales":17,"grams":42,"gross":560,"commission_earned":56,"today_sales":3,"today_grams":7,"today_gross":100,"today_commission":10}
	game.phone_open=true;game.phone_panel.show();game.phone_current_app="budshop";game._refresh_phone()
	var summary:String=labels(game.phone_list)
	check("BUSINESS OVERVIEW" in summary and "PROPERTY ACCOUNTS" in summary,"Remote phone shows operation overview and multiple property accounts")
	check("VIEW HOUSE OPERATION" in summary,"Second operation is selectable from phone without relocating player")
	var active:String=ops.active_property()
	game._phone_business_select("house")
	check(game._phone_business_selected()=="house" and ops.active_property()==active,"Selecting an operation never relocates the player or moves any equipment")
	game._open_phone_app("employees")
	var employees:String=labels(game.phone_list)
	check("Malik" in employees and "Tyler" in employees,"Employees shows all hired staff and their property assignments")
	check("TEXT TYLER" in employees and "TRANSFER TO HOUSE" in employees,"Phone employees offers transfer-by-text")
	check("SEND WORKER HOME" in employees and "SEND DEALERS HOME" in employees,"Phone employees restores both duty actions")
	game._toggle_packing_employee()
	check(not game.packing_employee_active,"Send worker home changes actual production duty state")
	game._open_phone_app("employees")
	check("PUT WORKER ON DUTY" in labels(game.phone_list),"Off-duty production employee shows return-to-work button")
	game._toggle_packing_employee()
	check(game.packing_employee_active,"Put worker on duty activates production again")
	game._toggle_dealers()
	check(not game.dealers_active,"Send all dealers home changes actual team duty state")
	game._open_phone_app("employees")
	check("PUT DEALERS ON DUTY" in labels(game.phone_list),"Off-duty dealer team exposes return-to-work button")
	game.dealer_balance_due=120
	game._open_phone_app("employees")
	check("Pay the $120 dealer balance" in labels(game.phone_list),"Unpaid dealer balance is visibly explained rather than silently hiding clock-in")
	check(game._staff_duty_blocker("dealer").contains("$120"),"Dealer balance blocker reflects the real payroll rule")
	game.dealer_balance_due=0
	game._toggle_dealers()
	check(game.dealers_active,"Clearing balance enables dealer team to clock back in")
	game._toggle_dealers()
	game.heat=81
	game._open_phone_app("employees")
	check("Heat is 75 or higher" in labels(game.phone_list),"High heat visibly explains off-duty status")
	game.heat=0
	game._toggle_dealers()
	check(game.dealers_active,"Removing heat blocker restores dealer team duty")

	check("$10 commission" in employees and "$56 commission" in employees,"Individual dealer performance includes today's and career commission")
	crew.open_thread("Tyler")
	crew.show_actions()
	var contact:String=labels(game.phone_list)
	check("TRANSFER TYLER TO HOUSE" in contact,"Hired dealer contact offers text transfer to other property")
	check("FIRE TYLER" in contact,"Hired dealer contact offers dismissal")
	check("THIS DEALER" in contact and "COMMISSION" in contact.to_upper(),"Dealer contact exposes deal counts, gross and commission")
	crew.transfer_from_contact("Tyler","house")
	check(crew.assignment("Tyler")=="house" and game.friend_staff_roles.Tyler=="dealer","Text transfer changes location but not employment or role")
	check(game.friend_dealer_stats.Tyler.sales==17 and game.friend_dealer_stats.Tyler.commission_earned==56,"Text transfer preserves cumulative sales/commission")
	game.apartment_rent_state["lease_active"]=false
	crew.transfer_from_contact("Tyler","apartment")
	check(crew.assignment("Tyler")=="house","Cannot transfer employee into released apartment")
	game.apartment_rent_state["lease_active"]=true
	crew.open_thread("Malik");crew.show_actions()
	check("TRANSFER MALIK TO APARTMENT" in labels(game.phone_list),"Production worker also has text transfer")
	crew.transfer_from_contact("Malik","apartment")
	check(crew.assignment("Malik")=="apartment" and game.packing_employee_hired,"Worker move preserves hired role")
	crew.open_thread("Tyler");crew.show_actions()
	crew.request_staff_release("Tyler")
	check("CONFIRM FIRE TYLER" in labels(game.phone_list),"Firing requires explicit confirmation")
	crew.confirm_staff_release("Tyler")
	check(not game.friend_staff_roles.has("Tyler") and not game.location_state.staff_assignments.has("Tyler"),"Firing removes role and property assignment")
	check(game.friend_dealer_stats.Tyler.commission_earned==56,"Firing retains historical commission totals")
	ops.computer("house")
	var computer:String=labels(ops.ui.body)
	check("OVERVIEW" in computer and "EMPLOYEES" in computer and "PRODUCTION" in computer and "INVENTORY" in computer and "EQUIPMENT" in computer and "BILLS" in computer,"Property computer uses six clear dashboard sections")
	ops.manage("employees")
	check(ops.computer_staff_names("house").is_empty(),"House staff list does not include a worker moved to apartment")
	ops.close()
	var saved_staff:Dictionary=game.friend_staff_roles.duplicate(true)
	var saved_location:Dictionary=game.location_state.staff_assignments.duplicate(true)
	game._save_game()
	var disk:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	check(disk.friend_staff_roles==saved_staff and disk.location_state.staff_assignments==saved_location,"New UI saves the same worker records, without rewriting the career schema")
	game.queue_free();await process_frame;await process_frame
	print("STAFF_UI_RESULT: ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
