extends RefCounted
## Client appointments live in saved phone messages and follow the active game clock.
var world: Node3D
var host: Node3D
var tick := 0.0

func setup(owner_node: Node3D) -> void:
	world=owner_node
	host=world.host

func is_home() -> bool:
	return world._indoors(host.camera.position)

func clock() -> float:
	return float(host.game_day)*1440.0+host.game_time_minutes

func _release_visit() -> void:
	for timer in [host.customer_patience_timer,host.customer_exit_timer]:
		if timer != null: timer.stop()
	host.customer_waiting=false
	host.customer_departing=false
	host.customer_answered=false
	host.peephole_checked=false
	host.current_customer={}
	host.active_request={}
	host.knock_banner.hide()
	if host.knock_player != null: host.knock_player.stop()
	host._schedule_next_customer()

func route_arrival() -> bool:
	var client: Dictionary=host.current_customer.duplicate(true)
	if client.is_empty() or not str(client.get("special","")).is_empty(): return false
	var name := str(client.get("name","Client"))
	for message in host.phone_text_messages:
		if str(message.get("sender",""))!=name or not message.has("client_visit"): continue
		if message.get("client_reply","")=="scheduled" or float(message.get("declined_until",0))>clock():
			_release_visit()
			return true
	if world.location_ops.crew.can_handle():return false
	if is_home(): return false
	var request: Dictionary=host.active_request.duplicate(true)
	_release_visit()
	_send_missed(client,request)
	return true

func _send_missed(client: Dictionary, request: Dictionary, body: String = "") -> void:
	var name := str(client.get("name","Client"))
	for message in host.phone_text_messages:
		if message.get("sender","")==name and message.has("client_visit") and message.get("client_reply","")=="pending": return
	if body.is_empty():body=world.location_ops.crew.say(name,"missed")
	# Add the reply payload before refreshing the phone, so its first render has buttons.
	host.phone_text_messages.append({"sender":name,"body":body,"day":host.game_day,"time":host._format_game_clock(),"read":false,"client_visit":client.duplicate(true),"client_request":request.duplicate(true),"client_reply":"pending"})
	while host.phone_text_messages.size()>120: host.phone_text_messages.pop_front()
	host.phone_text_unread+=1
	world.play_text()
	host.status_label.text=name+" texted you. Open Phone → Texts to reply."
	if host.phone_open and host.phone_current_app in ["home","texts"]: host._refresh_phone()
	host._save_game()

func append_replies(parent: VBoxContainer, message: Dictionary, index: int) -> void:
	if not message.has("client_visit"): return
	var reply := str(message.get("client_reply","pending"))
	if reply in ["pending","scheduled"]:
		if reply=="scheduled":
			var note := Label.new()
			note.text="Scheduled: "+_appointment_label(float(message.get("client_due",clock())))
			note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			parent.add_child(note)
		var grid := GridContainer.new()
		grid.columns=2
		grid.add_theme_constant_override("h_separation",8)
		grid.add_theme_constant_override("v_separation",8)
		parent.add_child(grid)
		for option in [{"text":"STOP BY NOW","minutes":10.0},{"text":"IN 1 GAME HOUR","minutes":60.0},{"text":"IN 2 GAME HOURS","minutes":120.0},{"text":"ANOTHER TIME","minutes":-1.0}]:
			var button := Button.new()
			button.text=option.text
			button.custom_minimum_size=Vector2(0,54)
			button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			button.add_theme_font_size_override("font_size",18)
			button.pressed.connect(_reply.bind(index,float(option.minutes)))
			grid.add_child(button)
	else:
		var note := Label.new()
		note.text="YOU: Another time." if reply=="declined" else ("Appointment missed — reply to their latest text." if reply=="missed" else ("Visit canceled — reply to their latest text." if reply=="canceled" else "They stopped by."))
		note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(note)

func _appointment_label(due: float) -> String:
	var minute := int(floor(due))%1440
	var hour := int(minute/60)
	return "Day %d, %d:%02d %s" % [int(floor(due/1440)),12 if hour%12==0 else hour%12,minute%60,"AM" if hour<12 else "PM"]

func _reply(index: int, minutes: float) -> void:
	if index<0 or index>=host.phone_text_messages.size(): return
	var message: Dictionary=host.phone_text_messages[index]
	if not message.has("client_visit") or message.get("client_reply","") not in ["pending","scheduled"]: return
	if minutes<0:
		message.client_reply="declined"
		message.declined_until=clock()+60.0
		message.erase("client_due")
		host.status_label.text="You told %s another time. This visit is canceled." % message.sender
	else:
		message.client_reply="scheduled"
		message.client_due=clock()+minutes
		message.erase("declined_until")
		host.status_label.text="%s will stop by %s. Be at your apartment with your storefront open." % [message.sender,"soon" if minutes==10 else "at "+_appointment_label(message.client_due)]
	host.phone_text_messages[index]=message
	world.location_ops.crew.outgoing(str(message.sender),"Another time." if minutes<0 else ("Stop by now." if minutes==10 else "Stop by at "+_appointment_label(message.client_due)))
	world.location_ops.crew.send(str(message.sender),world.location_ops.crew.say(str(message.sender),"declined" if minutes<0 else "scheduled",{"when":"soon" if minutes==10 else "at "+_appointment_label(float(message.get("client_due",clock())))}))
	host._save_game()
	if host.phone_open: host._refresh_phone()

func reserve_slot() -> bool:
	for message in host.phone_text_messages:
		if message.get("client_reply","")=="scheduled" and float(message.get("client_due",0))<=clock()+30.0:
			host._schedule_next_customer(true)
			return true
	return false

func update(delta: float) -> void:
	if not host.gameplay_ready or host._simulation_blocked(): return
	if not is_home() and host.knock_player != null and host.knock_player.playing: host.knock_player.stop()
	if not is_home() and host.customer_waiting and not host.customer_answered and not host.customer_departing and str(host.current_customer.get("special","")).is_empty():
		route_arrival()
	tick-=delta
	if tick>0: return
	tick=0.5
	for index in range(host.phone_text_messages.size()):
		var message: Dictionary=host.phone_text_messages[index]
		if message.get("client_reply","")!="scheduled" or float(message.get("client_due",0))>clock(): continue
		if host.customer_waiting: return
		var client: Dictionary=message.get("client_visit",{}).duplicate(true)
		var request: Dictionary=message.get("client_request",{}).duplicate(true)
		if not is_home() and not world.location_ops.crew.can_handle():
			message.client_reply="missed"
			host.phone_text_messages[index]=message
			_send_missed(client,request,world.location_ops.crew.say(str(client.get("name","Client")),"appointment_missed"))
			return
		if not host.business_open or not host._has_listed_stock() or not host._friend_staff_role(str(client.get("name",""))).is_empty():
			message.client_reply="canceled"
			host.phone_text_messages[index]=message
			_send_missed(client,request,world.location_ops.crew.say(str(client.get("name","Client")),"unavailable"))
			return
		message.client_reply="arrived"
		host.phone_text_messages[index]=message
		host.current_customer=client
		host.active_request=request
		host.customer_waiting=true
		host.customer_departing=false
		host.customer_answered=false
		host.peephole_checked=false
		host.visit_timer.stop()
		host._play_door_knock()
		host._start_customer_patience()
		host.status_label.text=str(client.get("name","Your client"))+" is at your apartment door. Walk over and check the peephole."
		host._refresh_navigation_ui()
		host._refresh_door_alert()
		host._save_game()
		if host.phone_open and host.phone_current_app=="texts": host._refresh_phone()
		return
