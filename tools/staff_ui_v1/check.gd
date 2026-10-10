extends SceneTree
## Property phone hub regression: disposable career, shared across desktop and mobile.
var failures:int=0
var checks:int=0
func check(ok:bool,note:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+note)
	else:print("PASS: ",note)
func labels(node:Node)->String:
	var text_content:=""
	for child in node.find_children("*","Control",true,false):
		if child is Label or child is Button:text_content+=str(child.text)+"\n"
	return text_content
func _initialize()->void:call_deferred("run")
func run()->void:
	var desktop:bool=ResourceLoader.exists("res://prototype/apartment.tscn")
	check(("QA" in OS.get_user_data_dir()) if desktop else (not OS.has_feature("web") and "tmp" in OS.get_user_data_dir()),"Tests use an isolated save directory")
	if failures>0:quit(1);return
	var game:Node3D=load("res://prototype/apartment.tscn" if desktop else "res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(20):await process_frame
	game.set_process(false);game.neighborhood.set_process(false)
	if desktop:game.fp_player.set_physics_process(false)
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
	game.phone_open=true;game.phone_panel.show()
	game._open_phone_app("realestate")
	check(game.phone_title.text=="Properties","Real Estate is renamed Properties without a new home-screen category")
	var root_menu:String=labels(game.phone_list)
	check("STARTER APARTMENT" in root_menu.to_upper() and "MAPLE FLATS HOUSE" in root_menu.to_upper(),"Properties lists both owned locations")
	check("PAY ALL UTILITIES" not in root_menu or ops.utility_total_due()>0,"Combined utility payment only appears when bills are owed")
	ops.portfolio_select("apartment");game._refresh_phone()
	var property_menu:String=labels(game.phone_list)
	check("EMPLOYEES" in property_menu and "STOCK" in property_menu and "ARRANGE FURNITURE" in property_menu and "BILLS" in property_menu,"Property menu has all management sections")
	game._open_phone_app("employees")
	check("Tyler" in labels(game.phone_list) and not ("Malik · Production" in labels(game.phone_list)),"Apartment employees shows only local staff")
	ops.portfolio_employee_open("Tyler")
	var actions:String=labels(game.phone_list)
	check("DEALER STATS" in actions and "SEND HOME" in actions and "TRANSFER" in actions and "FIRE" in actions,"Dealer profile exposes stats, duty, transfer, and fire")
	ops.portfolio_page_dealer_stats()
	var performance:String=labels(game.phone_list)
	check("17" in performance and "$560" in performance and "$56" in performance and "$10" in performance,"Individual dealer stats include lifetime and today's commissions")
	ops.portfolio_dealer_stats_back()
	ops.portfolio_set_duty("Tyler")
	check(not ops.portfolio_staff_duty("Tyler"),"Sending one dealer home changes their individual duty state")
	check(crew.roster().has("Tyler") and ops.computer_staff_names("apartment").has("Tyler"),"Off-duty workers remain visible in their property's roster")
	ops.portfolio_set_duty("Tyler")
	check(ops.portfolio_staff_duty("Tyler"),"Dealer can be returned to duty")
	ops.portfolio_transfer("Tyler","house")
	check(crew.assignment("Tyler")=="house" and game.friend_staff_roles.Tyler=="dealer","Transferring work location preserves role")
	check(int(game.friend_dealer_stats.Tyler.commission_earned)==56,"Dealer career history survives transfer")
	game._open_phone_app("realestate")
	ops.portfolio_select("house");game._refresh_phone()
	check("ARRANGE FURNITURE" in labels(game.phone_list),"House has its own furniture arrangement entry")
	if not ops.portfolio_on_site("house"):
		ops.portfolio_furniture()
		check("Visit Maple Flats House" in game.status_label.text,"Physical furniture editing is blocked while away")
	game._open_phone_app("employees");ops.portfolio_employee_open("Tyler")
	ops.portfolio_request_fire("Tyler")
	check("CONFIRM FIRE" in labels(game.phone_list),"Firing requires explicit confirmation")
	ops.portfolio_fire("Tyler")
	check(not game.friend_staff_roles.has("Tyler") and not game.location_state.staff_assignments.has("Tyler"),"Firing clears current employment and assignment")
	check(int(game.friend_dealer_stats.Tyler.commission_earned)==56,"Dismissal retains lifetime dealer history")
	game.dealer_count=1
	game.location_state["staff_assignments"]["Hired Dealer 1"]="house"
	check(crew.roster().has("Hired Dealer 1"),"Generic dealer roster is individually addressable")
	game._record_friend_dealer_sale("Hired Dealer 1",3,60,6)
	var generic:Dictionary=game.location_state.get("hired_dealer_stats",{}).get("Hired Dealer 1",{})
	check(int(generic.get("sales",0))==1 and int(generic.get("commission_earned",0))==6,"Generic hired dealer retains individual performance")
	ops.portfolio_employee_open("Hired Dealer 1")
	ops.portfolio_page_dealer_stats()
	check("$60" in labels(game.phone_list) and "$6" in labels(game.phone_list),"Generic dealer stats screen shows gross and commission")
	ops.portfolio_employee_back()
	ops.utility_state("apartment")["power_due"]=20
	ops.utility_state("apartment")["water_due"]=10
	ops.utility_state("house")["power_due"]=40
	ops.utility_state("house")["water_due"]=15
	ops._sync_legacy_utility_totals()
	game.cash=1000
	ops.portfolio_reset();game._open_phone_app("realestate")
	check("PAY ALL UTILITIES" in labels(game.phone_list),"All outstanding electricity and water balances are combined")
	ops.pay_all_portfolio_utilities()
	check(game.cash==915 and ops.utility_total_due()==0,"One combined payment pays each property's balance exactly once")
	ops.computer("house")
	check("MANAGEMENT MOVED TO THE PHONE" in labels(ops.ui.body),"In-game computer now points to the single phone-management UI")
	ops.close()
	game._save_game()
	var disk:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	check(disk.friend_dealer_stats.Tyler.commission_earned==56 and disk.location_state.staff_assignments.get("Hired Dealer 1","")=="house","Save preserves staff records and distinct property assignments")
	game.queue_free();await process_frame;await process_frame
	print("STAFF_UI_RESULT: ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
