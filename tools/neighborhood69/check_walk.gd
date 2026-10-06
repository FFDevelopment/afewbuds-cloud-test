extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.session_paused=false
 game.tutorial_active=false
 game.daily_report_pending=false
 game.customer_waiting=false
 for name in ["tutorial_panel","daily_report_panel","pause_overlay","sale_panel","grow_panel","plant_direct_panel","bagging_panel","storage_panel","dealer_storage_panel","supply_inventory_panel","system_control_panel","trim_panel","bag_minigame_panel","peephole_panel"]:
  var panel=game.get(name)
  if panel != null: panel.hide()
 var n=game.neighborhood
 game._go_to_view("main_grow_door",false)
 n._process(0.016)
 assert(n.active)
 assert(n._walkable(Vector3(0,1.64,-4)))
 assert(not n._walkable(Vector3(2,1.64,-4)))
 assert(not n._walkable(Vector3(5,1.64,0)))
 assert(not n._walkable(Vector3(0,1.64,5.85)))
 game.camera.position=Vector3(0,1.64,-5)
 n._process(0.016)
 assert(n.active and game.current_room=="grow")
 game.camera.position=Vector3(0,1.64,2)
 n._process(0.016)
 assert(n.active and game.current_room=="main")
 game.camera.position=Vector3(2.3,1.64,0.78)
 game.camera.look_at(Vector3(3.95,1.15,0.78))
 n._process(0.016)
 assert(n._station_reachable("station_workbench"))
 var point: Vector2=game.camera.unproject_position(Vector3(3.95,1.15,0.78))
 n._tap(point)
 assert(n.active and not n.in_station)
 n._tap(point)
 assert(n.in_station and not n.active)
 await create_timer(0.6).timeout
 assert(game.bagging_panel.visible)
 game.bagging_panel.hide()
 game._nav("back")
 assert(n.active and not n.in_station)
 assert(game.camera.position==Vector3(2.3,1.64,0.78))
 game.camera.position=Vector3(0,1.64,4.5)
 game.camera.rotation=Vector3(0,PI,0)
 n._toggle_door()
 await create_timer(0.6).timeout
 assert(n.door_open and n._walkable(Vector3(0,1.64,5.85)))
 game.camera.position=Vector3(0,1.64,9)
 n._process(0.016)
 assert(n.active and game.current_room=="neighborhood")
 game.camera.position=Vector3(0,1.64,3)
 n._process(0.016)
 assert(n.active and game.current_room=="main")
 print("PASS .69 indoor walking, room transition, collision, double tap, station menu/back, seamless exit/return")
 quit()
