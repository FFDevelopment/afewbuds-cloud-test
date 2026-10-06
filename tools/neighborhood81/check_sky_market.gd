extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func run() -> void:
	var game: Node3D=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.session_paused=false
	game.tutorial_active=false
	game.daily_report_pending=false
	game.customer_waiting=false
	for name in ["tutorial_panel","daily_report_panel","pause_overlay","sale_panel","grow_panel","plant_direct_panel","bagging_panel","storage_panel","dealer_storage_panel","supply_inventory_panel","system_control_panel","trim_panel","bag_minigame_panel","peephole_panel"]:
		var panel=game.get(name)
		if panel!=null: panel.hide()
	game.visit_timer.stop()
	var n: Node3D=game.neighborhood
	n._arrive_outside()
	var controls: RefCounted=n.house_controls
	check(controls.shades.size()==11,"Ten house coverings plus apartment blinds")
	check(controls.switches.size()==11,"Eight house rooms, grow panel and two market circuits")
	n.map_obstacles.clear(); n._collect_map_colliders(n)
	for id in ["market_stock","market_front"]:
		var spec: Dictionary=controls.switches[id]
		game.camera.position=Vector3(14.1,1.64,spec.at.z)
		game.camera.look_at(spec.at)
		check(n._walkable(game.camera.position),"Stockroom switch approach clear")
		check(controls.nearby()=="switch_"+id,"Correct stockroom circuit selected: "+id)
		var other := "market_stock" if id=="market_front" else "market_front"
		var before: bool=controls.switches[other].lamp.visible
		controls.use("switch_"+id)
		check(not spec.lamp.visible,"Market switch toggles matching light")
		for extra in spec.extra: check(not extra.lamp.visible,"Front circuit includes both sales-floor fixtures")
		check(controls.switches[other].lamp.visible==before,"Other market circuit stays unchanged")
		controls.use("switch_"+id)
		game.camera.position=Vector3(16.1,1.64,spec.at.z)
		game.camera.look_at(spec.at)
		check(controls.nearby().is_empty(),"Market switches cannot be operated through stockroom wall")
	var approaches := {"LivingFrontShade":Vector3(29.2,1.64,1.5),"LivingSideShade":Vector3(26.5,1.64,-1.2),"KitchenSideShade":Vector3(26.5,1.64,-10.7),"KitchenRearShade":Vector3(27.95,1.64,-12.0),"BathroomShade":Vector3(33.15,1.64,-12.9),"BedroomShade":Vector3(35.1,1.64,-13.2)}
	# Bedroom shade is reachable from beside the bed, without standing on it.
	approaches.BedroomShade=Vector3(34.65,1.64,-13.2)
	for id in approaches:
		var spec: Dictionary=controls.shades[id]
		game.camera.position=approaches[id]
		game.camera.look_at(spec.at)
		check(n._walkable(game.camera.position),"New covering has clear approach: "+id)
		check(controls.nearby()=="shade_"+id,"New covering reachable from its room: "+id)
		var point: Vector2=game.camera.unproject_position(spec.at)
		n.tap_distance=0
		n._tap(point); n._tap(point)
		await create_timer(0.45).timeout
		check(not spec.closed,"Double tap opens new covering: "+id)
		controls.use("shade_"+id)
		await create_timer(0.45).timeout
		check(spec.closed,"New covering closes again: "+id)
	var weather: RefCounted=n.weather
	game.game_time_minutes=360
	weather.update(0)
	check(weather.sun_direction.x>0.9 and absf(weather.sun_direction.y)<0.01,"Sun rises in east at 6AM")
	game.game_time_minutes=720
	weather.update(0)
	check(weather.sun_direction.y>0.9 and weather.daylight>0.99,"Sun reaches midday height")
	game.game_time_minutes=1080
	weather.update(0)
	check(weather.sun_direction.x< -0.9 and absf(weather.sun_direction.y)<0.01,"Sun sets in west at 6PM")
	var previous := 1.0
	for minute in range(1020,1141):
		game.game_time_minutes=minute
		weather.update(0)
		check(weather.daylight<=previous+0.001,"Sunset light fades continuously")
		check(previous-weather.daylight<0.03,"No abrupt daytime/nighttime light flip")
		previous=weather.daylight
	game.game_time_minutes=0
	weather.update(1)
	check(weather.moon.visible and weather.moon.light_energy>0.07 and not n.outdoor_sun.visible,"Moon illuminates night after sunset")
	var cloud_time: float=weather.cloud_seconds
	game.session_paused=true
	weather.update(1)
	check(weather.cloud_seconds==cloud_time,"Cloud motion pauses with gameplay")
	game.session_paused=false
	weather.update(1)
	check(weather.cloud_seconds>cloud_time,"Cloud motion resumes")
	check(game.world_environment_ref.sky==n.outdoor_environment.sky,"Apartment window uses actual moving outdoor sky")
	game._save_game()
	var save: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	check(save.house_control_state.has("market_front") and save.house_control_state.has("BathroomShade"),"Market and new covering states serialized with career")
	if OS.get_cmdline_user_args().has("--capture"):
		root.size=Vector2i(1280,800)
		game.camera.position=Vector3(8,1.64,25)
		for shot in [{"id":"sunrise","minute":375.0,"look":Vector3(28,6,25)},{"id":"day","minute":780.0,"look":Vector3(22,8,4)},{"id":"sunset","minute":1065.0,"look":Vector3(-12,6,25)},{"id":"moon","minute":30.0,"look":Vector3(5.5,20,28.5)}]:
			game.game_time_minutes=shot.minute
			game.camera.look_at(shot.look)
			for i in range(6):
				game.session_paused=false
				game.pause_overlay.hide()
				game.game_time_minutes=shot.minute
				weather.update(0)
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/workspace/scratch/05254e9fc6fb/review/sky80-"+shot.id+".png")
	print("Sky/market .80 checks: ",failures," failures; all windows, new shade approaches/taps, independent stockroom switches, sun east/noon/west, continuous twilight, moon, clouds/pause, saved controls")
	quit(1 if failures else 0)
