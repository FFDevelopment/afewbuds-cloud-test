extends RefCounted
var world: Node3D
var host: Node3D
var ops: RefCounted:
	get:return world.location_ops
var thread := ""
var actions := false
var character_scenes: Dictionary = {}
var malik_visitor: Node3D
var malik_worker: Node3D
var tick := 0.0
var applying := false
var manager_attempted := false
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
		if not host.lay_low_active:button(host.phone_list,"CLOSE SHOP" if host.business_open else "OPEN SHOP",command.bind(thread,"close" if host.business_open else "open"))
		button(host.phone_list,"SET UP SHOP" if host.lay_low_active else "SHUT DOWN SHOP & LAY LOW",command.bind(thread,"reopen" if host.lay_low_active else "shutdown"))
		button(host.phone_list,"TEXT: APARTMENT STATUS",command.bind(thread,"status"))
		if job=="dealer":button(host.phone_list,"GO BACK TO STREET DEALS" if manager()==thread else "HANDLE APARTMENT DOOR",return_to_street.bind(thread) if manager()==thread else assign_manager.bind(thread))
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
	if can_handle():host._schedule_next_customer(true)
	outgoing(name,"Run the apartment and answer clients at the door.")
	send(name,"I'll answer clients at the apartment using packaged stock in its locker, storage or packing bench. I'm off street deals while assigned here. Cash and commission settle at nightly closeout.")
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
	actions=true
	if role(name).is_empty() or assignment(name)!="apartment":return
	outgoing(name,{"shutdown":"Shut down shop and lay low.","reopen":"Set up shop again.","close":"Close shop for clients.","open":"Open shop again.","status":"How is the apartment doing?"}[action])
	if (role(name)=="dealer" and host.dealer_arrested) or (role(name)=="production" and host.production_worker_arrested):send(name,"I'm being held. I can't act on that until bail is resolved.");return
	if action=="close":
		host._set_business_away();send(name,"Shop closed to clients. Production and the current lights stay as they are.")
	elif action=="open":
		if host.lay_low_active:send(name,"We are laying low. Use Set Up Shop to resume.");return
		if host._staff_heat_locked() or host.game_day<host.raid_lockdown_until_day:send(name,"We cannot open while heat or raid restrictions are active.");return
		host._reopen_business();send(name,"Shop is open again." if host.business_open else "Shop could not reopen yet.")
	elif action=="shutdown":
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
func return_to_street(name: String) -> void:
	if manager()!=name:return
	host.location_state["apartment_manager"]="";manager_attempted=false
	host._schedule_next_customer(true)
	outgoing(name,"Go back to street deals.");send(name,"Back on street deals. I'll use the Dealer Locker again. You'll need to answer the apartment door.");host._refresh_phone()
func can_handle() -> bool:
	return not host._simulation_blocked() and not manager().is_empty() and host.dealers_active and host.business_open and not host.lay_low_active and not host.dealer_arrested and host.dealer_balance_due<=0
func serve_visit(client: Dictionary,request: Dictionary) -> bool:
	var name:=manager()
	if not host.customer_waiting or host.customer_answered or host.customer_departing or str(host.current_customer.get("name",""))!=str(client.get("name","")):return false
	if not can_handle() or not str(client.get("special","")).is_empty():return false
	if not host._dealer_sell_one(false,name,client,request):return false
	host.customer_answered=true;host._record_customer_encounter(false)
	var summary: String="Served %s · %dg %s. Proceeds settle at closeout." % [str(client.get("name","client")),int(request.get("qty",0)),str(request.get("product",""))]
	world.client_visits._release_visit()
	host.status_label.text=name+": "+summary
	send(name,summary)
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
	if not host.customer_waiting:manager_attempted=false
	update_malik()
	update_seating(delta)
	if bool(host.location_state.get("crew_idle",false)) and not host.lay_low_active:host.location_state["crew_idle"]=false
	var name:=manager()
	if manager_node!=null and str(manager_node.get_meta("contact",""))!=name:manager_node.queue_free();manager_node=null
	if not name.is_empty() and host.production_worker_node!=null:
		if manager_node==null:
			manager_node=character_instance(name) if name in ["Malik","Rod"] else host.production_worker_node.duplicate()
			manager_node.name="ApartmentDoorManager";host.add_child(manager_node);manager_node.set_meta("contact",name)
			if name not in ["Malik","Rod"]:
				for child in manager_node.get_children():
					if str(child.name).ends_with("Visual"):child.queue_free()
					if child is MeshInstance3D:child.visible=child.name!=host.production_worker_face_shell.name
			for tag in manager_node.find_children("*","Label3D",true,false):tag.text=name+" · APARTMENT DEALER"
		manager_node.visible=not host.dealer_arrested
		var relax: bool=not host.customer_waiting and not world.couch_seated
		var seat:=Vector3(-1.785 if host.packing_employee_hired else -2.775,0,3.035)
		var before: Vector3=manager_node.position
		manager_node.position=manager_node.position.move_toward(seat if relax else Vector3(1.45,0,4.45),delta*2.0)
		var seated: bool=relax and Vector2(manager_node.position.x-seat.x,manager_node.position.z-seat.z).length()<0.1
		if seated:manager_node.rotation.y=0.0
		seated_pose(manager_node,seated)
		animate_manager(Vector3(manager_node.position.x-before.x,0,manager_node.position.z-before.z),seated,delta)
		if host.customer_waiting and not host.customer_answered and not host.customer_departing and can_handle() and not manager_attempted and manager_node.position.distance_to(Vector3(1.45,0,4.45))<0.2 and str(host.current_customer.get("special","")).is_empty():
			manager_attempted=true
			var client: Dictionary=host.current_customer.duplicate(true)
			var request: Dictionary=host.active_request.duplicate(true)
			if not serve_visit(client,request):
				send(name,"I cannot fill %s: %dg %s requested. Check packaged stock and reserved stock." % [str(client.get("name","client")),int(request.get("qty",0)),str(request.get("product",""))])
				if not world.client_visits.is_home():world.client_visits._release_visit();world.client_visits._send_missed(client,request,"Your dealer could not fill my order. Let me know when you have stock.")
	elif manager_node!=null:manager_node.hide()
	tick+=delta
	if tick<10 or host._simulation_blocked():return
	tick=0
	if host.business_open and host.dealers_active and host._total_dealer_count()>0:alert(name if not name.is_empty() else host._critical_dealer_sender(),"dealer_stock",packaged_stock()==0 if not name.is_empty() else host._dealer_locker_total()==0,"Apartment packaged stock is empty. Restock it so I can serve the door." if not name.is_empty() else "Dealer Locker is empty. I cannot sell on the street until you restock it.")
	if host.packing_employee_hired and host.packing_employee_active:
		var worker: String=host._critical_production_sender()
		alert(worker,"seeds",host._total_seed_inventory()==0,"We're out of seeds. Collect an order at Central Market and deposit it at the computer.")
		alert(worker,"fertilizer",host.fertilizer_units==0,"Fertilizer is out. I'll keep watering existing plants, but you'll need to restock fertilizer at Central Market.")

func malik_instance() -> Node3D:return character_instance("Malik")
func character_instance(name: String) -> Node3D:
	if name not in ["Malik","Rod"]:return Node3D.new()
	var scene: PackedScene=character_scenes.get(name)
	if scene==null:
		var document:=GLTFDocument.new();var state:=GLTFState.new()
		var error: int=document.append_from_buffer(FileAccess.get_file_as_bytes("res://assets/characters/"+name+".glb"),"",state)
		if error!=OK:push_error(name+" GLB import failed: %d" % error);return Node3D.new()
		var model: Node3D=document.generate_scene(state)
		model.name=name+"Visual"
		var texture_image:=Image.new()
		if texture_image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/characters/"+name+"_BaseColor.png"))==OK:
			var material:=StandardMaterial3D.new();material.albedo_texture=ImageTexture.create_from_image(texture_image);material.roughness=0.83;material.cull_mode=BaseMaterial3D.CULL_DISABLED
			for mesh in model.find_children("*","MeshInstance3D",true,false):mesh.material_override=material
		scene=PackedScene.new();scene.pack(model);model.free();character_scenes[name]=scene
	var instance: Node3D=scene.instantiate()
	instance.set_meta("character",name)
	for player in instance.find_children("*","AnimationPlayer",true,false):
		for clip in player.get_animation_list():
			if str(clip).ends_with("idle"):player.play(clip);break
	return instance
func update_malik() -> void:
	var worker: Node3D=host.production_worker_node
	var name: String=host.production_worker_friend_name
	if name in ["Malik","Rod"] and worker!=null:
		if malik_worker!=null and str(malik_worker.get_meta("character",""))!=name:malik_worker.queue_free();malik_worker=null
		if malik_worker==null:malik_worker=character_instance(name);worker.add_child(malik_worker)
		malik_worker.show()
		for child in worker.get_children():
			if child is MeshInstance3D:child.hide()
		for player in malik_worker.find_children("*","AnimationPlayer",true,false):
			var wanted: String="sit" if bool(worker.get_meta("seated",false)) and host.production_worker_pending_action.is_empty() else ("walk" if host.packing_employee_active and worker.position.distance_to(host._production_worker_navigation_target())>0.10 else "idle")
			for clip in player.get_animation_list():
				if str(clip).ends_with(wanted) and player.current_animation!=clip:player.play(clip)
	elif malik_worker!=null:
		malik_worker.hide()
		if worker!=null:
			for child in worker.get_children():
				if child is MeshInstance3D and child!=host.production_worker_face_shell:child.show()
	var visitor: String=str(host.current_customer.get("name",""))
	if host.customer_waiting and visitor in ["Malik","Rod"]:
		if malik_visitor!=null and str(malik_visitor.get_meta("character",""))!=visitor:malik_visitor.queue_free();malik_visitor=null
		if malik_visitor==null:malik_visitor=character_instance(visitor);host.add_child(malik_visitor);malik_visitor.position=Vector3(0,0,7.1)
		malik_visitor.show()
	elif malik_visitor!=null:malik_visitor.hide()

func seated_pose(model: Node3D,seated: bool) -> void:
	if model==null:return
	if model.has_meta("character"):
		if not seated and bool(model.get_meta("seated",false)):
			for skeleton in model.find_children("*","Skeleton3D",true,false):skeleton.reset_bone_poses()
		for player in model.find_children("*","AnimationPlayer",true,false):
			for clip in player.get_animation_list():
				if str(clip).ends_with("sit" if seated else "idle") and (seated or bool(model.get_meta("seated",false))) and player.current_animation!=clip:player.play(clip)
		model.position.y=0.0
	else:
		model.position.y=-0.57 if seated else 0.0
	model.set_meta("seated",seated)

func update_seating(delta: float) -> void:
	var worker: Node3D=host.production_worker_node
	if worker!=null and worker.visible:
		var idle: bool=host.production_worker_pending_action.is_empty() and (not host.packing_employee_active or host.production_worker_task=="Waiting for work" or host.lay_low_active)
		var at:=Vector3(-2.775,0,2.1)
		var seated: bool=idle and worker.position.distance_to(at)<0.15
		if seated:worker.position=Vector3(-2.775,0,3.035);worker.rotation.y=0.0
		# Seated positions stay fixed until real work is assigned.
		if idle and bool(worker.get_meta("seated",false)):worker.position=Vector3(-2.775,0,3.035);seated=true
		worker.set_meta("seated",seated)
		if malik_worker!=null:seated_pose(malik_worker,seated)
		else:
			for part in ["LegL","LegR"]:
				var leg: Node3D=worker.get_node_or_null(part)
				if leg!=null:leg.rotation.x=-PI/2 if seated else 0.0
			worker.position.y=-0.57 if seated else 0.0

func packaged_stock() -> int:
	var amount: int=host._dealer_locker_total()
	for product in host.products:amount+=host._available_amount(product)
	for product in host.bagged_inventory:amount+=maxi(0,int(host.bagged_inventory[product]))
	return amount

func product_stock(product: String) -> int:
	return maxi(0,int(host.locker_weed.get(product,0)))+host._available_amount(product)+maxi(0,int(host.bagged_inventory.get(product,0)))

func animate_manager(motion: Vector3,seated: bool,delta: float) -> void:
	if manager_node==null:return
	var moving: bool=motion.length()>0.001 and not seated
	if moving:manager_node.rotation.y=lerp_angle(manager_node.rotation.y,atan2(-motion.x,-motion.z),minf(1.0,delta*8.0))
	if manager_node.has_meta("character"):
		if seated:return
		for player in manager_node.find_children("*","AnimationPlayer",true,false):
			for clip in player.get_animation_list():
				if str(clip).ends_with("walk" if moving else "idle") and (player.current_animation!=clip or not player.is_playing()):player.play(clip)
	else:
		var phase: float=float(manager_node.get_meta("walk_phase",0.0))
		phase=phase+motion.length()*4.5 if moving else lerpf(phase,0.0,minf(1.0,delta*5.0))
		manager_node.set_meta("walk_phase",phase)
		var swing: float=sin(phase)*0.42 if moving else 0.0
		for spec in [["ArmL",swing],["ArmR",-swing],["LegL",-swing*0.75],["LegR",swing*0.75]]:
			var part: Node3D=manager_node.get_node_or_null(spec[0])
			if part!=null:part.rotation.x=spec[1]
