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
 var touch:=InputEventScreenTouch.new()
 touch.index=2
 touch.position=point
 touch.pressed=true
 n.handle_input(touch)
 touch.pressed=false
 n.handle_input(touch)
 assert(n.active and not n.in_station)
 touch.pressed=true
 n.handle_input(touch)
 touch.pressed=false
 n.handle_input(touch)
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
 root.size=Vector2i(844,390)
 for i in range(4): await process_frame
 assert(root.content_scale_size==Vector2i(1440,900))
 assert(absf(game.camera.fov-78.0)<0.01)
 var visible: Rect2=root.get_visible_rect()
 assert(visible.size.x>visible.size.y)
 assert(absf(visible.size.x/visible.size.y-844.0/390.0)<0.02)
 assert(visible.encloses(n.pad.get_global_rect()))
 assert(visible.encloses(n.action.get_global_rect()))
 game._toggle_phone()
 for i in range(3): await process_frame
 var phone: Rect2=game.phone_panel.get_global_rect()
 assert(absf(phone.size.x-668.0)<2.0)
 assert(absf(phone.get_center().x-visible.get_center().x)<2.0)
 assert(visible.encloses(phone))
 game._toggle_phone()
 root.size=Vector2i(390,844)
 for i in range(4): await process_frame
 assert(root.content_scale_size==Vector2i(720,1280))
 assert(root.get_visible_rect().size.y>root.get_visible_rect().size.x)
 assert(root.get_visible_rect().encloses(n.pad.get_global_rect()))
 print("PASS .70 rotation, viewport aspect, corner controls, centered phone, wider FOV; .69 indoor walking, room transition, collision, double tap, station menu/back, seamless exit/return")
 quit()
