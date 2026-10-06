extends SceneTree
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures+=1;push_error(message)
func labels(node: Node) -> String:
	var result:=""
	for button in node.find_children("*","Button",true,false):result+=button.text+"\n"
	return result
func visit(game: Node3D,client: Dictionary,product: String,qty: int) -> void:
	game.current_customer=client.duplicate(true);game.active_request={"product":product,"qty":qty};game.customer_waiting=true;game.customer_answered=false;game.customer_departing=false
func run() -> void:
	var game: Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process(false);game.neighborhood.set_process(false);game.gameplay_ready=true;game.session_paused=false;game.tutorial_active=false;game.daily_report_pending=false;game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide();game.visit_timer.stop();game.dealer_count=1;game.dealers_active=true;game.business_open=true;game.dealer_balance_due=0;game.dealer_arrested=false;game.lay_low_active=false
	var crew: RefCounted=game.neighborhood.location_ops.crew
	var dealer: String="Hired Dealer 1";crew.assign_manager(dealer)
	var client: Dictionary=game.customers[0].duplicate(true)
	var product: String=str(client.favorite)
	game.products[product]={"stock":5,"reserved":2,"listed":true,"price":20,"grade":"B"};game.locker_weed={};game.bagged_inventory={};game.dealer_locker_level=0;game.dealer_customers_served_today={};game.customer_relationships[str(client.name)]={"visits":1,"player_sales":0}
	visit(game,client,product,2);var gross: int=game.lifetime_revenue
	check(crew.serve_visit(client,game.active_request),"Door serves stored stock without locker or prior player sale")
	check(game.products[product].stock==3 and game.lifetime_revenue==gross+40 and not game.customer_waiting,"Actual order consumes storage and settles original dealer accounting")
	check(not crew.serve_visit(client,{"product":product,"qty":2}),"Released visit cannot sell twice")
	game.bagged_inventory[product]=2;game.locker_weed[product]=1
	visit(game,client,product,3);check(crew.serve_visit(client,game.active_request),"Later legitimate repeat visit combines packaged sources")
	check(game.products[product].stock==2 and game.bagged_inventory[product]==1 and not game.locker_weed.has(product),"Locker then unreserved storage then packaged bench; reserves preserved")
	visit(game,client,product,5);var before: int=game.lifetime_revenue
	check(not crew.serve_visit(client,game.active_request) and game.lifetime_revenue==before and game.bagged_inventory[product]==1,"Short stock cannot partially charge or consume")
	game.customer_waiting=false;game.current_customer={};game.locker_weed[product]=20
	game.products[product].stock=0;game.products[product].listed=false;game.bagged_inventory={}
	check(game._has_listed_stock(),"Door visitor scheduling sees locker-only packaged stock")
	check(not game._dealer_sell_one(false,dealer),"Door-assigned dealer cannot also make street sales")
	crew.thread=dealer;crew.actions=true;game.phone_current_app="texts";game._refresh_phone()
	check("GO BACK TO STREET DEALS" in labels(game.phone_list) and not "HANDLE APARTMENT DOOR" in labels(game.phone_list),"Door role replaces assignment action")
	crew.command(dealer,"close");check(not game.business_open and "OPEN SHOP" in labels(game.phone_list) and not "CLOSE SHOP" in labels(game.phone_list),"Close flips to Open on same screen")
	crew.command(dealer,"open");check(game.business_open and "CLOSE SHOP" in labels(game.phone_list),"Open flips to Close")
	crew.command(dealer,"shutdown");check(game.lay_low_active and "SET UP SHOP" in labels(game.phone_list) and not "SHUT DOWN SHOP & LAY LOW" in labels(game.phone_list),"Lay Low flips to Set Up Shop")
	game.heat=0;crew.command(dealer,"reopen");check(not game.lay_low_active and game.business_open,"Setup restores storefront and prior crew duty")
	crew.return_to_street(dealer);check(crew.manager().is_empty() and "HANDLE APARTMENT DOOR" in labels(game.phone_list),"Return restores street role and inverse button")
	# Existing waiting visitor is completed after manager reaches the door, even at home.
	crew.assign_manager(dealer);game.camera.position=Vector3(0,1.7,3);game.products[product].stock=12;game.customer_waiting=false;crew.update(0.01)
	visit(game,client,product,2);crew.manager_node.position=Vector3(1.45,0,4.45);crew.update(0.01)
	check(not game.customer_waiting,"Manager handles waiting visitor while player watches at home")
	game.camera.position=Vector3(-25,1.7,20);visit(game,client,product,2)
	check(not game.neighborhood.client_visits.route_arrival() and game.customer_waiting,"Assigned manager retains away visitor for door service")
	crew.manager_attempted=false;crew.manager_node.position=Vector3(1.45,0,4.45);crew.update(0.01)
	check(not game.customer_waiting,"Manager completes away visitor")
	visit(game,client,product,2);game.session_paused=true;crew.manager_attempted=false;crew.manager_node.position=Vector3(1.45,0,4.45);crew.update(0.01)
	check(game.customer_waiting and not crew.manager_attempted,"Paused play cannot sell or consume the pending manager attempt")
	game.session_paused=false;crew.update(0.01);check(not game.customer_waiting,"Resuming lets manager complete pending visit")
	print("Door dealer/toggle .91 checks: ",failures," failures")
	game.queue_free();await process_frame;quit(1 if failures else 0)
