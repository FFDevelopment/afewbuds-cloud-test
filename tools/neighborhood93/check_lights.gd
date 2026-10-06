extends SceneTree
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures+=1;push_error(message)
func run() -> void:
	var game: Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process(false);game.neighborhood.set_process(false);game.session_paused=false;game.tutorial_active=false;game.daily_report_pending=false;game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide();game.visit_timer.stop();game.current_room="main"
	var world: Node3D=game.neighborhood
	world.active=true;world.tap_distance=0
	for spec in [["main_light_switch",Vector3(1.42,1.47,5.72),["MainLightSwitchPlate","MainLightSwitchToggle"],"main_ceiling_light_on"],["floor_lamp",Vector3(-3.78,1.35,3.35),["FloorLampShade","FloorLampStem"],"floor_lamp_on"]]:
		game.camera.position=spec[1]+Vector3(0,0.2,-1.2);game.camera.look_at(spec[1]);await process_frame;game.session_paused=false;game.pause_overlay.hide()
		var rect: Rect2=game._room_target_screen_rect(spec[2]);check(rect.has_area(),spec[0]+" has visible target")
		var point: Vector2=rect.get_center()
		game.set(spec[3],false);world._tap(point);check(bool(game.get(spec[3])),spec[0]+" single tap turns on while walking")
		world._tap(point);check(not bool(game.get(spec[3])),spec[0]+" next tap turns off")
		world.tap_distance=30;world._tap(point);check(not bool(game.get(spec[3])),spec[0]+" drag does not toggle")
		world.tap_distance=0;game.phone_open=true;game.phone_panel.show();check(not world._tap_apartment_light(point),spec[0]+" phone blocks world taps")
		game.phone_open=false;game.phone_panel.hide()
		game.camera.position=spec[1]+Vector3(0,0,-4);game.camera.look_at(spec[1]);check(not world._tap_apartment_light(game.camera.unproject_position(spec[1])),spec[0]+" distant tap cannot toggle")
	check(not world.couch_seated,"Lamp tap does not select couch")
	print("Apartment single-tap lighting .93 checks: ",failures," failures")
	game.queue_free();await process_frame;quit(1 if failures else 0)
