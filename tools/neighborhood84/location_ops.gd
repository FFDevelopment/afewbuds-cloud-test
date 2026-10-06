extends RefCounted
var world: Node3D
var host: Node3D
var ui: RefCounted
var installing := false
var computer_context := ""
var management_app := ""
var rendering_management := false
var last_notice := -1
const APT_PC := Vector3(4.15,1.35,2.2)
const HOUSE_PC := Vector3(26.35,1.35,1.65)
const CHECKOUT := Vector3(14,1.3,3)
func setup(owner: Node3D) -> void:
	world=owner;host=owner.host
	ui=load("res://scripts/property_opportunity.gd").new()
	ui.setup(world)
	for key in ["carried_seeds","pickup_seeds","deliveries","house"]:
		if not host.location_state.get(key,{}) is Dictionary:host.location_state[key]={}
		if not host.location_state.has(key):host.location_state[key]={}
	host.location_state["carried_fertilizer"]=maxi(0,int(host.location_state.get("carried_fertilizer",0)))
	if not host.apartment_rent_state.has("next_due"):
		host.apartment_rent_state={"next_due":host.game_day+14,"balance":0,"first_unpaid":0}
		host._save_game()
	make_computer("Apartment",APT_PC,true)
	make_computer("House",HOUSE_PC,false)
func make_computer(id: String, at: Vector3, apartment: bool) -> void:
	var desk: MeshInstance3D=host._add_box(id+"ComputerDesk",at+Vector3(0,-0.6,0),Vector3(0.65,0.12,1.1),Color("68543e"),0.9)
	var monitor: MeshInstance3D=host._add_box(id+"ComputerMonitor",at,Vector3(0.10,0.55,0.7),Color("202b29"),0.9)
	var screen: MeshInstance3D=host._add_box(id+"ComputerScreen",at+Vector3(-0.065,0,0),Vector3(0.025,0.44,0.6),Color("55856e"),0.7,true)
	var stand: MeshInstance3D=host._add_box(id+"ComputerStand",at+Vector3(0,-0.42,0),Vector3(0.15,0.36,0.2),Color("26332d"),0.9)
	var keyboard: MeshInstance3D=host._add_box(id+"ComputerKeyboard",at+Vector3(-0.22,-0.5,0),Vector3(0.28,0.05,0.55),Color("29332e"),0.9)
	var legs: Array[MeshInstance3D]=[]
	for z in [-0.4,0.4]:legs.append(host._add_box(id+"ComputerLeg",Vector3(at.x+0.15,0.35,at.z+z),Vector3(0.08,0.7,0.08),Color("403a2d"),0.9))
	for node in [desk,monitor,screen,stand,keyboard]+legs:
		node.layers=1 if apartment else 2
		if not apartment:node.reparent(world,true)
func is_open() -> bool:return ui!=null and ui.is_open()
func near(point: Vector3, range_limit: float=2.4) -> bool:
	var offset: Vector3=point-host.camera.position
	return offset.length()<range_limit and (-host.camera.global_basis.z).dot(offset.normalized())>0.3
func target() -> String:
	if world._indoors(host.camera.position) and near(APT_PC):return "apartment_computer"
	var room: String=world.house_controls._inside_room(host.camera.position)
	if room=="living" and near(HOUSE_PC):return "house_computer"
	if room=="market_front" and near(CHECKOUT,2.7):return "market_checkout"
	return ""
func use(id: String) -> void:
	match id:
		"apartment_computer":computer("apartment")
		"house_computer":computer("house")
		"market_checkout":market()
func clear(title: String) -> void:
	for container in [ui.body,ui.footer]:
		for child in container.get_children():container.remove_child(child);child.queue_free()
	ui.label(title,30)
	ui.overlay.show();ui.resize()
	world.pad.release();world.pointer=-99
func close() -> void:ui.overlay.hide();management_app=""
func b(text: String, callback: Callable, disabled: bool=false) -> void:
	var item := Button.new()
	item.text=text;item.custom_minimum_size.y=54
	item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size",22)
	item.disabled=disabled;item.pressed.connect(callback);ui.body.add_child(item)
func total(inventory: Dictionary) -> int:
	var amount:=0
	for key in inventory:amount+=maxi(0,int(inventory[key]))
	return amount
func order_seed(name: String) -> void:
	if host.tutorial_active or not host.seed_catalog.has(name):return
	var info: Dictionary=host.seed_catalog[name]
	if bool(info.get("recipe_only",false)) or host.grower_level<int(info.get("unlock",1)):return
	var price: int=int(info.get("cost",10))
	if host.cash<price or total(host.location_state.pickup_seeds)>=50:return
	host.cash-=price
	host._record_daily_expense("Seed orders",price)
	host.location_state.pickup_seeds[name]=int(host.location_state.pickup_seeds.get(name,0))+1
	host._increment_advancement_stat("seeds_bought")
	host._update_cash_ui();host._save_game();host._refresh_phone()
	host.status_label.text="Seed order ready at Central Market. Pick it up at the checkout."
func pickup() -> void:
	if target()!="market_checkout":return
	var capacity: int=50-total(host.location_state.carried_seeds)
	for name in host.location_state.pickup_seeds.keys():
		var quantity: int=mini(capacity,maxi(0,int(host.location_state.pickup_seeds[name])))
		if quantity<=0:continue
		host.location_state.carried_seeds[name]=int(host.location_state.carried_seeds.get(name,0))+quantity
		host.location_state.pickup_seeds[name]-=quantity;capacity-=quantity
		if int(host.location_state.pickup_seeds[name])==0:host.location_state.pickup_seeds.erase(name)
	host._save_game();market()
func fertilizer() -> void:
	if target()!="market_checkout" or host.cash<45 or int(host.location_state.carried_fertilizer)>45:return
	host.cash-=45;host.location_state.carried_fertilizer+=5
	host._record_daily_expense("Supplies",45);host._increment_advancement_stat("supplies_bought")
	host._update_cash_ui();host._save_game();market()
func eligible(name: String) -> bool:
	if rent_overdue():return false
	if not host.supply_catalog.has(name) or host._supply_is_purchased(name) or host.location_state.deliveries.has(name):return false
	if host.grower_level<int(host.supply_catalog[name].get("unlock",1)):return false
	if name=="Grow Supply Shelf III" and host.supply_shelf_level<2:return false
	if name==host.VAULT_SUPPLY and host.storage_level<3:return false
	if name==host.HIDDEN_STASH_SUPPLY and host.storage_level<4:return false
	if name=="Bagging Bench III" and host.bagging_level<2:return false
	return true
func order_equipment(name: String) -> void:
	if target()!="market_checkout" or not eligible(name):return
	var price: int=int(host.supply_catalog[name].get("cost",10))
	if host.cash<price:return
	host.cash-=price;host._record_daily_expense("Equipment orders",price)
	host.location_state.deliveries[name]={"property":"apartment","paid":price}
	host._update_cash_ui();host._save_game();equipment()
func install(name: String) -> void:
	if target()!="apartment_computer" or not host.location_state.deliveries.has(name):return
	var delivery: Dictionary=host.location_state.deliveries[name]
	if str(delivery.get("property",""))!="apartment":return
	if host._supply_is_purchased(name):return
	if str(delivery.get("kind",""))=="dealer":
		installing=true;host._buy_dealer_locker_upgrade();installing=false
		if host.dealer_locker_level>=int(delivery.level):host.location_state.deliveries.erase(name)
		host._save_game()
		if host.phone_open:host._refresh_phone()
		else:computer("apartment")
		return
	var price: int=int(host.supply_catalog[name].cost)
	host.supply_catalog[name].cost=0;installing=true
	host._buy_supply(name)
	installing=false;host.supply_catalog[name].cost=price
	if host._supply_is_purchased(name):host.location_state.deliveries.erase(name)
	host._save_game()
	if host.phone_open:host._refresh_phone()
	else:computer("apartment")
func deposit() -> void:
	if target()!="apartment_computer":return
	var capacity: int=maxi(0,host._supply_seed_capacity()-host._total_seed_inventory())
	for name in host.location_state.carried_seeds.keys():
		var amount: int=mini(capacity,maxi(0,int(host.location_state.carried_seeds[name])))
		if amount<=0:continue
		host.seed_inventory[name]=int(host.seed_inventory.get(name,0))+amount
		host.location_state.carried_seeds[name]-=amount;capacity-=amount
		if int(host.location_state.carried_seeds[name])==0:host.location_state.carried_seeds.erase(name)
	var fertilizer_amount: int=mini(maxi(0,host._supply_fertilizer_capacity()-host.fertilizer_units),int(host.location_state.carried_fertilizer))
	host.fertilizer_units+=fertilizer_amount;host.location_state.carried_fertilizer-=fertilizer_amount
	host._save_game();computer("apartment")
func market() -> void:
	clear("CENTRAL MARKET — CHECKOUT")
	ui.label("Collect seed orders, buy fertilizer, or order equipment for your property. Cash: $%d" % host.cash)
	b("COLLECT SEED ORDERS · %d READY" % total(host.location_state.pickup_seeds),pickup,total(host.location_state.pickup_seeds)==0 or total(host.location_state.carried_seeds)>=50)
	b("FERTILIZER · +5 USES · $45",fertilizer,host.cash<45 or int(host.location_state.carried_fertilizer)>45)
	b("BROWSE SEEDS",seeds)
	b("EQUIPMENT & UPGRADES",equipment)
	ui.label("CARRIED: %d / 50 seeds · %d / 50 fertilizer uses. Deposit supplies at your property computer." % [total(host.location_state.carried_seeds),int(host.location_state.carried_fertilizer)])
	ui.button("CLOSE",close)
func seeds() -> void:
	clear("CENTRAL MARKET — SEEDS")
	ui.label("Orders are held at this checkout until collected. They do not go straight onto your grow shelf.")
	for name in host.SEED_ORDER:
		if not host.seed_catalog.has(name):continue
		var data: Dictionary=host.seed_catalog[name]
		if bool(data.get("recipe_only",false)):continue
		var price: int=int(data.get("cost",10))
		var level: int=int(data.get("unlock",1))
		b("ORDER %s · $%d · LEVEL %d" % [name,price,level],func():order_seed(name);seeds(),host.cash<price or host.grower_level<level or total(host.location_state.pickup_seeds)>=50)
	ui.button("BACK TO CHECKOUT",market)
func equipment() -> void:
	clear("CENTRAL MARKET — EQUIPMENT")
	if rent_overdue():ui.label("Apartment rent is overdue. Pay it in Business → Bills to resume new equipment orders. Seeds, fertilizer and sales remain available.")
	ui.label("Delivery location: APARTMENT. Orders wait for installation at its computer. House deliveries become available once the house is acquired.")
	if host.dealer_locker_level<4:
		var level: int=host.dealer_locker_level+1
		var dealer_name: String="Dealer Storage "+host._roman(level)
		var price: int=host.DEALER_LOCKER_COST_BY_LEVEL[level]
		b("%s · $%d" % [dealer_name,price],order_dealer,host.cash<price or host.location_state.deliveries.has(dealer_name) or rent_overdue())
	for name in host.supply_catalog:
		if name=="Fertilizer Pack":continue
		var data: Dictionary=host.supply_catalog[name]
		var price: int=int(data.get("cost",10))
		var title: String="%s · $%d · LEVEL %d" % [name,price,int(data.get("unlock",1))]
		if host.location_state.deliveries.has(name):title+=" · AWAITING INSTALLATION"
		elif host._supply_is_purchased(name):title+=" · INSTALLED"
		b(title,order_equipment.bind(name),not eligible(name) or host.cash<price)
	ui.button("BACK TO CHECKOUT",market)
func computer(property: String) -> void:
	computer_context=property
	management_app=""
	clear(property.to_upper()+" — OPERATION COMPUTER")
	if property=="house":
		ui.label("Property inspection: %d / 6 rooms. This house has not been acquired. No production equipment or stock is assigned here." % world.property_opportunity.visited().size())
		ui.button("REVIEW HOUSE",func():close();world.property_opportunity.show_details())
	else:
		ui.label("PROPERTY INVENTORY: %d / %d seeds · %d / %d fertilizer uses. %d grow tents installed." % [host._total_seed_inventory(),host._supply_seed_capacity(),host.fertilizer_units,host._supply_fertilizer_capacity(),host.grow_tent_count])
		ui.label("CARRIED: %d seeds · %d fertilizer uses. Supplies left over when a shelf is full stay with you." % [total(host.location_state.carried_seeds),int(host.location_state.carried_fertilizer)])
		b("DEPOSIT CARRIED SUPPLIES",deposit,total(host.location_state.carried_seeds)==0 and int(host.location_state.carried_fertilizer)==0)
		for name in host.location_state.deliveries:b("INSTALL "+str(name),install.bind(str(name)))
		for app in ["employees","products","genetics","upgrades"]:
			var title: String={"employees":"STAFF & ASSIGNMENTS","products":"INVENTORY & LISTINGS","genetics":"GENETICS","upgrades":"EQUIPMENT & INSTALLATION"}[app]
			b(title,manage.bind(str(app)))
		b("PRODUCTION & UTILITIES",production)
		b("BILLS & APARTMENT RENT",manage.bind("bills"))
	ui.button("CLOSE COMPUTER",func():computer_context="";close())
func manage(app: String) -> void:
	if target()!="apartment_computer":return
	computer_context="apartment";management_app=app
	rendering_management=true
	clear("APARTMENT — "+app.to_upper())
	var previous_list: VBoxContainer=host.phone_list
	host.phone_list=ui.body
	match app:
		"employees":host._build_employees_app()
		"products":host._build_products_app()
		"genetics":host._build_genetics_app()
		"upgrades":host._build_upgrades_app()
		"bills":host._build_bills_app()
	host.phone_list=previous_list
	ui.button("REFRESH",manage.bind(app))
	ui.button("BACK TO COMPUTER",computer.bind("apartment"))
	rendering_management=false
func management_allowed() -> bool:return computer_context=="apartment" and target()=="apartment_computer"
func supply_intercept(name: String) -> bool:
	if installing:return false
	# The guided starter purchase stays with the tutorial; regular restocking moves to the market.
	if host.tutorial_active and name=="Fertilizer Pack":return false
	host.status_label.text="Buy fertilizer and order equipment at the Central Market checkout."
	return true
func redirect(app: String) -> bool:
	if host.tutorial_active or management_allowed():return false
	if app in ["employees","products","genetics","upgrades"]:
		host.phone_current_app="home";host._refresh_phone()
		host.status_label.text="Use your apartment computer for detailed operation management."
		return true
	return false
func balance() -> int:return maxi(0,int(host.apartment_rent_state.get("balance",0)))
func update(_delta: float) -> void:
	if not host.phone_open and not is_open():computer_context=""
	var due: int=int(host.apartment_rent_state.get("next_due",host.game_day+14))
	var changed:=false
	while host.game_day>=due:
		if balance()==0:host.apartment_rent_state["first_unpaid"]=due
		host.apartment_rent_state.balance=balance()+600;due+=14;changed=true
	host.apartment_rent_state.next_due=due
	if changed:host._save_game()
	if last_notice!=host.game_day and (due-host.game_day<=3 or balance()>0):
		last_notice=host.game_day
		host.status_label.text="Apartment rent: $%d due. Pay in Business → Bills." % balance() if balance()>0 else "Apartment rent: $600 due on Day %d." % due
func pay_rent() -> void:
	var amount:=balance()
	if amount<=0 or host.cash<amount:return
	host.cash-=amount;host.apartment_rent_state.balance=0;host.apartment_rent_state.first_unpaid=0
	host._record_daily_expense("Apartment rent",amount);host._update_cash_ui();host._save_game();host._refresh_phone()
	host.status_label.text="Apartment rent paid: $%d." % amount
func rent_ui(parent: VBoxContainer) -> void:
	var text := Label.new()
	var first: int=int(host.apartment_rent_state.get("first_unpaid",0))
	text.text="APARTMENT RENT · $600 EVERY 14 GAME DAYS\nNext payment: Day %d · Balance: $%d" % [int(host.apartment_rent_state.get("next_due",host.game_day+14)),balance()]
	if first>0:text.text+="\n"+("OVERDUE" if host.game_day>first+3 else "Grace period through Day %d" % (first+3))
	text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(text)
	if balance()>0:
		var pay := Button.new();pay.text="PAY APARTMENT RENT · $%d" % balance();pay.custom_minimum_size.y=54
		pay.disabled=host.cash<balance();pay.pressed.connect(pay_rent);parent.add_child(pay)
func equipment_ui(parent: VBoxContainer) -> void:
	var hint := Label.new();hint.text="Order equipment at Central Market, then install paid deliveries here. Delivery location: Apartment."
	hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(hint)
	for name in host.location_state.deliveries:
		if str(host.location_state.deliveries[name].get("kind",""))=="dealer":
			var action := Button.new();action.text="INSTALL "+str(name);action.custom_minimum_size.y=54;action.pressed.connect(install.bind(str(name)));parent.add_child(action)
	for name in host.supply_catalog:
		if name=="Fertilizer Pack":continue
		var row := Label.new();row.text=str(name)+(" · INSTALLED" if host._supply_is_purchased(name) else (" · DELIVERY READY" if host.location_state.deliveries.has(name) else " · NOT INSTALLED"));row.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(row)
		if host.location_state.deliveries.has(name):
			var action := Button.new();action.text="INSTALL "+str(name);action.custom_minimum_size.y=54;action.pressed.connect(install.bind(str(name)));parent.add_child(action)

func production() -> void:
	if target()!="apartment_computer":return
	close();world.in_station=true
	world.walk_position=host.camera.position;world.walk_rotation=host.camera.rotation
	host._open_system_control_panel()
func order_summary(parent: VBoxContainer) -> void:
	var note := Label.new()
	note.text="CENTRAL MARKET: %d seed(s) ready for pickup.\nCARRIED: %d seed(s), %d fertilizer uses. Deposit carried supplies at your apartment computer." % [total(host.location_state.pickup_seeds),total(host.location_state.carried_seeds),int(host.location_state.carried_fertilizer)]
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(note)

func order_dealer() -> void:
	if target()!="market_checkout" or host.dealer_locker_level>=4 or rent_overdue():return
	var level: int=host.dealer_locker_level+1
	var name: String="Dealer Storage "+host._roman(level)
	var cost: int=host.DEALER_LOCKER_COST_BY_LEVEL[level]
	if host.cash<cost or host.location_state.deliveries.has(name):return
	host.cash-=cost;host._record_daily_expense("Dealer storage order",cost)
	host.location_state.deliveries[name]={"property":"apartment","kind":"dealer","level":level,"paid":cost}
	host._update_cash_ui();host._save_game();equipment()

func refresh_management() -> bool:
	if rendering_management:return true
	if is_open() and not management_app.is_empty():
		manage(management_app)
		return true
	return false

func rent_overdue() -> bool:
	return balance()>0 and host.game_day>int(host.apartment_rent_state.get("first_unpaid",host.game_day))+3
