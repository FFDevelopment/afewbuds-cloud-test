extends RefCounted
var world: Node3D
var host: Node3D
var ops: RefCounted:
	get:return world.location_ops
var thread := ""
var actions := false
var malik_scene: PackedScene
var malik_visitor: Node3D
var malik_worker: Node3D
var tick := 0.0
var applying := false
var manager_node: Node3D
func setup(owner: Node3D) -> void:
	world=owner;host=world.host
	if not host.location_state.get("staff_assignments",{}) is Dictionary:host.location_state["staff_assignments"]={}
	if not host.location_state.has("staff_assignments"):host.location_state["staff_assignments"]={}
	if not host.location_state.has("crew_alerts"):host.location_state["crew_alerts"]={}
func label(parent: Node, text: String) -> void:
	var node:=Label.new();node.text=text;node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(node)
func button(parent: Node,text: String,action: Callable,disabled: bool=false) -> void:
	var node:=Button.new();node.text=text;node.custom_minimum_size.y=54;node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;node.disabled=disabled;node.pressed.connect(action);parent.add_child(node)
func role(name: String) -> String:
	if host.packing_employee_hired and name==host._critical_production_sender():return "production"
	if name in host._active_dealer_roster() or (name=="Dealer Team" and host._total_dealer_count()>0):return "dealer"
	return host._friend_staff_role(name)
func roster() -> Array[String]:
	var names: Array[String]=host._active_dealer_roster()
	if host.packing_employee_hired and not names.has(host._critical_production_sender()):names.append(host._critical_production_sender())
	return names
func assignment(name: String) -> String:return str(host.location_state.staff_assignments.get(name,"apartment"))
func contacts() -> void:
	host.phone_title.text="Contacts"
	label(host.phone_list,"Known clients and your crew. Open a contact for messages, appointments, recruiting and property assignment.")
	var names: Array[String]=roster()
	for client in host.customers:
		if host._customer_is_known(client) and not names.has(str(client.name)):names.append(str(client.name))
	names.sort()
	for name in names:
		var job:=role(name)
		button(host.phone_list,name+"\n"+(job.capitalize()+" · "+assignment(name).capitalize() if not job.is_empty() else "Client"),open_thread.bind(name))
	if names.is_empty():label(host.phone_list,"Contacts appear as you get to know clients or hire staff.")
func open_thread(name: String) -> void:
	thread=name;actions=false;host.phone_current_app="texts";host.phone_open=true;host.phone_panel.show();host._refresh_phone();jump_latest.call_deferred()
func jump_latest() -> void:
	host.phone_scroll.scroll_vertical=int(host.phone_scroll.get_v_scroll_bar().max_value)
func back() -> void:
	if actions:actions=false
	else:thread=""
	host._refresh_phone()
func show_actions() -> void:actions=true;host._refresh_phone()
func peer(message: Dictionary) -> String:return str(message.get("contact",message.get("sender","Unknown")))
func unread(name: String) -> int:
	var count:=0
	for msg in host.phone_text_messages:
		if peer(msg)==name and not bool(msg.get("read",false)):count+=1
	return count
func recount() -> void:
	host.phone_text_unread=0
	for msg in host.phone_text_messages:
		if not bool(msg.get("read",false)):host.phone_text_unread+=1
func threads() -> void:
	if thread.is_empty():
		host.phone_title.text="Messages"
		var names: Array[String]=[]
		for i in range(host.phone_text_messages.size()-1,-1,-1):
			var name:=peer(host.phone_text_messages[i])
			if not names.has(name):names.append(name)
		for name in names:
			var preview:=""
			for i in range(host.phone_text_messages.size()-1,-1,-1):
				if peer(host.phone_text_messages[i])==name:preview=str(host.phone_text_messages[i].get("body",""));break
			button(host.phone_list,name+(" · %d unread" % unread(name) if unread(name)>0 else "")+"\n"+preview.left(90),open_thread.bind(name))
		if names.is_empty():label(host.phone_list,"No messages yet. Start from Contacts.")
		button(host.phone_list,"CONTACTS",host._open_phone_app.bind("clients"))
		return
	host.phone_title.text=thread
	button(host.phone_list,"BACK TO MESSAGES",back)
	if actions:
		render_actions()
		return
	button(host.phone_list,"CONTACT DETAILS & ACTIONS",show_actions)
	for i in range(host.phone_text_messages.size()):
		var msg: Dictionary=host.phone_text_messages[i]
		if peer(msg)!=thread:continue
		var card:=PanelContainer.new();card.add_theme_stylebox_override("panel",host._style_box(Color("183126") if bool(msg.get("outgoing",false)) else Color("171d24"),Color("33434f"),16,1));host.phone_list.add_child(card)
		var box:=VBoxContainer.new();card.add_child(box)
		label(box,("YOU" if bool(msg.get("outgoing",false)) else thread)+" · DAY %d %s" % [int(msg.get("day",host.game_day)),str(msg.get("time",""))])
		label(box,str(msg.get("body","")))
		world.client_visits.append_replies(box,msg,i)
		msg["read"]=true
	recount();host._save_game()
func render_actions() -> void:
	var job:=role(thread)
	if not job.is_empty():
		label(host.phone_list,job.to_upper()+" · Assigned to "+assignment(thread).capitalize())
		button(host.phone_list,"ASSIGN TO APARTMENT",assign.bind(thread,"apartment"))
		button(host.phone_list,"HOUSE · NOT ACQUIRED",assign.bind(thread,"house"),true)
		button(host.phone_list,"TEXT: SHUT DOWN APARTMENT / LAY LOW",command.bind(thread,"shutdown"))
		button(host.phone_list,"TEXT: REOPEN APARTMENT",command.bind(thread,"reopen"))
		button(host.phone_list,"TEXT: APARTMENT STATUS",command.bind(thread,"status"))
		if job=="dealer":button(host.phone_list,"RUN APARTMENT & ANSWER THE DOOR",assign_manager.bind(thread))
		if job=="dealer" and host.dealer_arrested:button(host.phone_list,"SEND DEALER BAIL · $%d" % host.dealer_bail_due,host._pay_dealer_bail,host.cash<host.dealer_bail_due)
		if job=="production" and host.production_worker_arrested:button(host.phone_list,"SEND WORKER BAIL · $%d" % host.production_worker_bail_due,host._pay_production_bail,host.cash<host.production_worker_bail_due)
	else:
		var client: Dictionary=host._customer_by_name(thread)
		if not client.is_empty() and host._customer_is_known(client):
			button(host.phone_list,"TEXT: STOP BY / I'M OPEN",invite.bind(thread),not host.business_open)
			if host._friend_is_recruitable(client):
				button(host.phone_list,"OFFER DEALER WORK · APARTMENT",recruit.bind(thread,"dealer"),host._total_dealer_count()>=host._dealer_capacity())
				button(host.phone_list,"OFFER PRODUCTION WORK · APARTMENT",recruit.bind(thread,"production"),host.grower_level<5 or host.packing_employee_hired)
			elif str(client.get("tier",""))=="Friend":label(host.phone_list,"Recruiting requires %d loyalty and %d personal sales." % [host.FRIEND_RECRUIT_LOYALTY,host.FRIEND_RECRUIT_PLAYER_SALES])
	button(host.phone_list,"BACK TO CONVERSATION",back)
func outgoing(name: String,body: String) -> void:
	host.phone_text_messages.append({"sender":"You","contact":name,"body":body,"outgoing":true,"read":true,"day":host.game_day,"time":host._format_game_clock()})
	while host.phone_text_messages.size()>120:host.phone_text_messages.pop_front()
func send(name: String,body: String) -> void:
	host._push_phone_text(name,body);host._save_game()
func assign(name: String,property: String) -> void:
	if role(name).is_empty() or property!="apartment":return
	host.location_state.staff_assignments[name]=property
	outgoing(name,"Work out of the apartment.");send(name,"Assigned to the apartment. I'll use its stock and equipment.");host._refresh_phone()
func recruit(name: String,job: String) -> void:
	actions=false
	host._recruit_friend_staff(name,job)
	if role(name)==job:assign(name,"apartment")
func invite(name: String) -> void:
	if not host.business_open:return
	outgoing(name,"I'm available at the apartment. Stop by when you can.");host._text_known_customer(name);host._refresh_phone();host._save_game()
func assign_manager(name: String) -> void:
	if role(name)!="dealer" or assignment(name)!="apartment":return
	host.location_state["apartment_manager"]=name
	outgoing(name,"Run the apartment and answer clients at the door.")
	send(name,"I'll handle eligible clients while you're out, using the Dealer Locker. Keep it stocked. Cash and commission settle at nightly closeout.")
	host._refresh_phone()
func manager() -> String:
	var name:=str(host.location_state.get("apartment_manager",""))
	return name if role(name)=="dealer" and assignment(name)=="apartment" else ""
func shutdown() -> void:
	if applying:return
	applying=true
	if not host.lay_low_active:
		host.location_state["shutdown_duty"]={"production":host.packing_employee_active,"dealers":host.dealers_active}
	host._start_lay_low()
	host.ventilation_on=false;host.packing_employee_active=false;host.dealers_active=false
	host.production_worker_pending_action="";host.production_worker_task="Hanging out · Apartment lay low";host.production_worker_last_action=host.production_worker_task
	host._reset_production_worker_navigation()
	host.location_state["crew_idle"]=true
	var controls: RefCounted=world.house_controls
	if controls.shades.has("ApartmentBlind"):
		var shade: Dictionary=controls.shades.ApartmentBlind
		shade.closed=true;shade.node.scale.y=1.0;controls.states["ApartmentBlind"]=true
		host.house_control_state=controls.states.duplicate(true)
	host._refresh_light_interaction_visuals();host._save_game();applying=false
func command(name: String,action: String) -> void:
	actions=false
	if role(name).is_empty() or assignment(name)!="apartment":return
	outgoing(name,{"shutdown":"Shut down the apartment and lay low.","reopen":"Reopen the apartment.","status":"How is the apartment doing?"}[action])
	if (role(name)=="dealer" and host.dealer_arrested) or (role(name)=="production" and host.production_worker_arrested):send(name,"I'm being held. I can't act on that until bail is resolved.");return
	if action=="shutdown":
		shutdown();send(name,"Apartment shut down: blinds closed, lights and ventilation off, sales and work stopped. We're staying inside and hanging out.")
	elif action=="reopen":
		if host._staff_heat_locked() or host.game_day<host.raid_lockdown_until_day:send(name,"We can't reopen while the heat or raid restriction is still active.");return
		host._stop_lay_low_and_reopen()
		if host.business_open:
			host.location_state["crew_idle"]=false
			var saved: Dictionary=host.location_state.get("shutdown_duty",{})
			host.packing_employee_active=bool(saved.get("production",false)) and host.packing_employee_hired and not host.production_worker_arrested
			host.dealers_active=bool(saved.get("dealers",false)) and host._total_dealer_count()>0 and not host.dealer_arrested
			send(name,"Apartment reopened. Previous on-duty crew can work again. Lights and blinds stay as you left them; use the computer's production controls to choose what to turn on.")
	else:send(name,"Apartment: %s. Dealer stock %dg; shelf %d seeds / %d fertilizer uses. %s" % ["LAY LOW" if host.lay_low_active else ("OPEN" if host.business_open else "AWAY"),host._dealer_locker_total(),host._total_seed_inventory(),host.fertilizer_units,"Dealer answering the door: "+manager() if not manager().is_empty() else "No door manager assigned."])
	host._refresh_phone();host._save_game()
func serve_visit(client: Dictionary,request: Dictionary) -> bool:
	var name:=manager()
	if name.is_empty() or not host.dealers_active or not host.business_open or host.lay_low_active:return false
	if not host._dealer_sell_one(false,name,client,request):return false
	world.client_visits._release_visit()
	return true
func computer_controls() -> void:
	label(ops.ui.body,"APARTMENT STOREFRONT · "+("LAY LOW" if host.lay_low_active else ("OPEN" if host.business_open else "AWAY")))
	button(ops.ui.body,"REOPEN APARTMENT" if not host.business_open else "APARTMENT AWAY · TEXT CLIENTS",host._reopen_business if not host.business_open else host._set_business_away)
	button(ops.ui.body,"APARTMENT LAY LOW · SHUT DOWN",shutdown)
	button(ops.ui.body,"CONTACTS & CREW TEXTS",func():ops.close();host._open_phone_app("clients");host.phone_open=true;host.phone_panel.show())
	label(ops.ui.body,"Door manager: "+(manager() if not manager().is_empty() else "Not assigned. Assign a dealer from Contacts."))
func alert(name: String,key: String,empty: bool,body: String) -> void:
	var alerts: Dictionary=host.location_state.crew_alerts
	if not empty:alerts.erase(key);return
	if alerts.has(key):return
	alerts[key]=true;send(name,"Apartment: "+body)
func update(delta: float) -> void:
	update_malik()
	if bool(host.location_state.get("crew_idle",false)) and not host.lay_low_active:host.location_state["crew_idle"]=false
	var name:=manager()
	if manager_node!=null and str(manager_node.get_meta("contact",""))!=name:manager_node.queue_free();manager_node=null
	if not name.is_empty() and host.production_worker_node!=null:
		if manager_node==null:
			manager_node=malik_instance() if name=="Malik" else host.production_worker_node.duplicate();manager_node.name="ApartmentDoorManager";host.add_child(manager_node);manager_node.set_meta("contact",name)
		manager_node.visible=not host.dealer_arrested
		manager_node.position=Vector3(-1.9,0,2.3) if host.lay_low_active else Vector3(1.45,0,4.45)
	elif manager_node!=null:manager_node.hide()
	tick+=delta
	if tick<10 or host._simulation_blocked():return
	tick=0
	if host.business_open and host.dealers_active and host._total_dealer_count()>0:alert(name if not name.is_empty() else host._critical_dealer_sender(),"dealer_stock",host._dealer_locker_total()==0,"Dealer Locker is empty. I can't serve clients until you restock it.")
	if host.packing_employee_hired and host.packing_employee_active:
		var worker: String=host._critical_production_sender()
		alert(worker,"seeds",host._total_seed_inventory()==0,"We're out of seeds. Collect an order at Central Market and deposit it at the computer.")
		alert(worker,"fertilizer",host.fertilizer_units==0,"Fertilizer is out. I'll keep watering existing plants, but you'll need to restock fertilizer at Central Market.")

func malik_instance() -> Node3D:
	if malik_scene==null:
		var document:=GLTFDocument.new();var state:=GLTFState.new()
		var error: int=document.append_from_buffer(FileAccess.get_file_as_bytes("res://assets/characters/Malik.glb"),"",state)
		if error!=OK:push_error("Malik GLB import failed: %d" % error);return Node3D.new()
		var model: Node3D=document.generate_scene(state)
		model.name="MalikVisual"
		malik_scene=PackedScene.new();malik_scene.pack(model);model.free()
	var instance: Node3D=malik_scene.instantiate()
	for player in instance.find_children("*","AnimationPlayer",true,false):
		for clip in player.get_animation_list():
			if str(clip).ends_with("idle"):player.play(clip);break
	return instance
func update_malik() -> void:
	var worker: Node3D=host.production_worker_node
	if host.production_worker_friend_name=="Malik" and worker!=null:
		if malik_worker==null:malik_worker=malik_instance();worker.add_child(malik_worker)
		malik_worker.show()
		for child in worker.get_children():
			if child is MeshInstance3D:child.hide()
		for player in malik_worker.find_children("*","AnimationPlayer",true,false):
			var wanted: String="walk" if host.packing_employee_active and worker.position.distance_to(host._production_worker_navigation_target())>0.10 else "idle"
			for clip in player.get_animation_list():
				if str(clip).ends_with(wanted) and player.current_animation!=clip:player.play(clip)
	elif malik_worker!=null:
		malik_worker.hide()
		if worker!=null:
			for child in worker.get_children():
				if child is MeshInstance3D and child!=host.production_worker_face_shell:child.show()
	if host.customer_waiting and str(host.current_customer.get("name",""))=="Malik":
		if malik_visitor==null:malik_visitor=malik_instance();host.add_child(malik_visitor);malik_visitor.position=Vector3(0,0,7.1)
		malik_visitor.show()
	elif malik_visitor!=null:malik_visitor.hide()
