extends SceneTree
var game: Node3D
var n: Node3D
var visits: RefCounted
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func prepare(client: String = "Rod") -> void:
	game.visit_timer.stop()
	game.preferred_customer_name=client
	game.force_rod_test_visit=false
	game.last_customer_name=""
func due_now(index: int) -> void:
	game.phone_text_messages[index]["client_due"]=visits.clock()-1
	visits.tick=0
	visits.update(0.5)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.session_paused=false
	game.tutorial_active=false
	game.daily_report_pending=false
	game.customer_waiting=false
	game.phone_open=false
	for name in ["tutorial_panel","daily_report_panel","pause_overlay","sale_panel","grow_panel","plant_direct_panel","bagging_panel","storage_panel","dealer_storage_panel","supply_inventory_panel","system_control_panel","trim_panel","bag_minigame_panel","peephole_panel"]:
		var panel=game.get(name)
		if panel != null: panel.hide()
	n=game.neighborhood
	visits=n.client_visits
	n._arrive_outside()
	game.phone_text_messages.clear()
	game.phone_text_unread=0
	game.business_open=true
	game.products["Purple Dream"].stock=30
	game.products["Purple Dream"].listed=true
	game.camera.position=Vector3(0,1.64,9)
	prepare()
	game._customer_arrives()
	check(not game.customer_waiting and not game.knock_banner.visible and not game.knock_player.playing,"Outside arrival sends text without knock or door alert")
	check(game.phone_text_messages.size()==1 and game.phone_text_messages[0].sender=="Rod","Real selected client texts the player")
	check(game.customer_patience_timer.is_stopped(),"Away client does not run doorstep patience")
	var rep: int=game.reputation
	prepare()
	game._customer_arrives()
	check(game.phone_text_messages.size()==1,"Same waiting client does not spam duplicate texts")
	check(game.reputation==rep,"Missed visit has no doorstep penalty")
	var box:=VBoxContainer.new()
	root.add_child(box)
	visits.append_replies(box,game.phone_text_messages[0],0)
	check(box.get_child(0).get_child_count()==4,"Four reply choices rendered")
	box.queue_free()
	visits._reply(0,60)
	var due: float=game.phone_text_messages[0].client_due
	check(absf(due-visits.clock()-60)<0.01,"One-hour appointment uses game clock")
	game._save_game()
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	check(saved.phone_text_messages[0].client_reply=="scheduled" and absf(saved.phone_text_messages[0].client_due-due)<0.01,"Appointment survives actual saved-game serialization")
	game.phone_text_messages.clear()
	game._load_game()
	game.session_paused=false
	game.tutorial_active=false
	check(game.phone_text_messages[0].client_reply=="scheduled","Appointment restored by actual game loader")
	game.camera.position=Vector3(0,1.64,2)
	game.game_time_minutes+=30
	visits.tick=0
	visits.update(0.5)
	check(not game.customer_waiting,"Scheduled customer does not arrive early")
	game.session_paused=true
	game.game_time_minutes+=31
	visits.tick=0
	visits.update(0.5)
	check(not game.customer_waiting,"Pause blocks appointment delivery")
	game.session_paused=false
	visits.update(0.5)
	check(game.customer_waiting and game.current_customer.name=="Rod","Due appointment brings the exact client to the apartment")
	check(game.knock_player.playing and not game.customer_patience_timer.is_stopped(),"At-home appointment uses normal knock and patience")
	game._refresh_door_alert()
	check(game.knock_banner.visible and not game.door_alert_button.visible,"At-home door alert keeps guidance and removes obsolete Go to Door")
	game.camera.position=Vector3(0,1.64,4.2)
	game.camera.look_at(Vector3(0,1.5,5.78))
	n._process(0.016)
	check(n._near_target()=="station_door","Nearby physical door action answers client")
	n._interact()
	await create_timer(0.6).timeout
	check(game.peephole_panel.visible,"Physical door action opens existing peephole")
	game._answer_from_peephole()
	check(game.sale_panel.visible and game.customer_answered,"Peephole answer reaches existing client sale")
	game._end_customer_visit(false)
	game._go_to_view("main_door",false)
	game.camera.position=Vector3(35,1.64,0)
	prepare("Nia")
	game._customer_arrives()
	var index: int=game.phone_text_messages.size()-1
	check(game.phone_text_messages[index].sender=="Nia" and not game.customer_waiting,"House tour also counts as away from apartment")
	visits._reply(index,-1)
	prepare("Nia")
	game._customer_arrives()
	check(game.phone_text_messages[index].client_reply=="declined" and game.phone_text_messages.size()==index+1,"Another time cancels visit and prevents immediate repeated request")
	game.game_time_minutes+=61
	prepare("Nia")
	game._customer_arrives()
	index=game.phone_text_messages.size()-1
	visits._reply(index,10)
	check(game.phone_text_messages[index].client_reply=="scheduled","Stop by now schedules a near-term visit")
	due_now(index)
	check(not game.customer_waiting and not game.knock_player.playing and game.phone_text_messages[index].client_reply=="missed","Away scheduled arrival sends a fresh text without knocking")
	var fresh: int=game.phone_text_messages.size()-1
	check(fresh>index and game.phone_text_messages[fresh].client_reply=="pending","Missed appointment allows replying again")
	visits._reply(fresh,120)
	check(absf(game.phone_text_messages[fresh].client_due-visits.clock()-120)<0.01,"Two-hour appointment uses game clock")
	visits._reply(fresh,-1)
	game._start_reeves_door_visit("payment_due")
	check(game.reeves_visit_pending and not game.customer_waiting,"Official visit is deferred until player returns home")
	game.reeves_visit_pending=false
	game.camera.position=Vector3(0,1.64,2)
	prepare("Rod")
	game._customer_arrives()
	check(game.customer_waiting,"Ordinary at-home customer still visits")
	game.camera.position=Vector3(0,1.64,9)
	visits.update(0.1)
	check(not game.customer_waiting and not game.knock_player.playing,"Walking away from waiting client converts visit to text")
	if OS.get_cmdline_user_args().has("--capture"):
		game._toggle_phone()
		game._open_phone_app("texts")
		for size in [Vector2i(1280,800),Vector2i(390,844)]:
			root.size=size
			for i in range(6): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/workspace/scratch/05254e9fc6fb/review/client78-"+("landscape" if size.x>size.y else "portrait")+".png")
	print("Client .78 checks: ",failures," failures; away/home arrivals, no spam or penalties, four replies, saved/restored appointment, timing/pause, physical answer, decline, missed appointments, official deferral")
	quit(1 if failures else 0)
