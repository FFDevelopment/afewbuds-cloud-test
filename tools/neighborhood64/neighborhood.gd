extends Node3D
# First exterior: isolated geometry and navigation; career simulation stays in main.
const ORIGIN := Vector3(120, 0, 0)
var host: Node3D
var active := false
var transitioning := false
var controls: CanvasLayer
var pad: HBoxContainer
var action: Button
var buttons: Array[Button] = []
var pointer := -99
var last_pointer := Vector2.ZERO
var obstacles: Array[Rect2] = []
var door_pivot: Node3D
var text_player: AudioStreamPlayer
var last_ding := -1000
var materials: Dictionary = {}
var outdoor_environment: Environment
var outdoor_sun: DirectionalLight3D

func setup(owner_node: Node3D) -> void:
	host = owner_node
	position = ORIGIN
	visible = false
	outdoor_environment=Environment.new()
	outdoor_environment.background_mode=Environment.BG_COLOR
	outdoor_environment.background_color=Color("b5c7d0")
	outdoor_environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	outdoor_environment.ambient_light_color=Color("c6d0d1")
	outdoor_environment.ambient_light_energy=0.4
	_build_block()
	_build_controls()
	_build_door_hinge()
	text_player = AudioStreamPlayer.new()
	var stream := AudioStreamMP3.new()
	stream.data = FileAccess.get_file_as_bytes("res://assets/audio/text_ding.mp3")
	text_player.stream = stream
	text_player.volume_db = -14.0
	add_child(text_player)

func play_text() -> void:
	if not host.gameplay_ready or host.session_paused:
		return
	var now := Time.get_ticks_msec()
	if now - last_ding < 700:
		return
	last_ding = now
	text_player.play()

func _box(pos: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	if not materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(color)
		material.roughness = 0.85
		materials[color] = material
	mesh.material_override = materials[color]
	mesh.position = pos
	add_child(mesh)
	return mesh

func _label(text: String, pos: Vector3, scale_value: float = 0.012) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.font_size = 42
	label.pixel_size = scale_value
	label.modulate = Color("fff1d4")
	add_child(label)

func _building(pos: Vector3, size: Vector3, color: String) -> void:
	_box(pos + Vector3(0, size.y / 2.0, 0), size, color)
	obstacles.append(Rect2(Vector2(pos.x-size.x/2.0-0.32, pos.z-size.z/2.0-0.32), Vector2(size.x+0.64, size.z+0.64)))
	_box(pos+Vector3(0,size.y,0), Vector3(size.x+0.35,0.22,size.z+0.35), "494a45")
	for floor_index in range(int(size.y / 2.8)):
		for column in range(int(size.x / 2.1)):
			var x := pos.x-size.x/2.0+1.1+column*2.1
			var y := 1.8+floor_index*2.8
			_box(Vector3(x,y,pos.z+size.z/2.0+0.04),Vector3(1.0,1.45,0.09),"d2c4ad")
			_box(Vector3(x,y,pos.z+size.z/2.0+0.10),Vector3(0.78,1.20,0.09),"526a6c")
			_box(Vector3(x,y,pos.z+size.z/2.0+0.16),Vector3(0.04,1.2,0.03),"c5bcaa")
			_box(Vector3(x,y,pos.z+size.z/2.0+0.16),Vector3(0.8,0.04,0.03),"c5bcaa")

func _build_block() -> void:
	_box(Vector3(0,-0.18,2),Vector3(64,0.3,48),"535654")
	_box(Vector3(0,0,-4),Vector3(60,0.16,8),"b7b2a7")
	_box(Vector3(0,0,12),Vector3(60,0.16,4),"b7b2a7")
	_box(Vector3(0,0.10,0),Vector3(60,0.18,0.24),"ded8c7")
	_box(Vector3(0,0.10,10),Vector3(60,0.18,0.24),"ded8c7")
	for x in range(-28,29,4):
		_box(Vector3(x,0.01,4.8),Vector3(2.4,0.025,0.10),"dcb85e")
		_box(Vector3(x,0.01,5.15),Vector3(2.4,0.025,0.10),"dcb85e")
	for z in range(1,10,2):
		_box(Vector3(-2,0.02,z),Vector3(3,0.035,0.75),"e4ded0")
	for x in range(-28,29,2):
		_box(Vector3(x,0.085,-3),Vector3(0.025,0.01,5.6),"92938c")
	_building(Vector3(-16,0,-10),Vector3(13,9,9),"975b42")
	_building(Vector3(-2,0,-10),Vector3(9,3.8,9),"a57250")
	_building(Vector3(14,0,-11),Vector3(14,3.5,10),"ab7454")
	# House hip-roof silhouette, layered eaves, porch and fenced garden.
	for tier in range(9):
		_box(Vector3(14,3.7+tier*0.17,-11),Vector3(15-tier*0.9,0.2,11-tier*0.72),"363d40")
	_box(Vector3(14,1.38,-5.93),Vector3(1.6,2.7,0.14),"664a35")
	_box(Vector3(14,0.15,-4.9),Vector3(3.8,0.3,1.9),"c6bbaa")
	_box(Vector3(14,0.1,-2.8),Vector3(2.5,0.12,2.5),"c6bbaa")
	for x in [9.0,19.0]:
		_box(Vector3(x,0.12,-3.5),Vector3(5.5,0.18,3.5),"65784b")
		obstacles.append(Rect2(Vector2(x-2.95,-5.5),Vector2(5.9,3.9)))
		for post in range(9):
			_box(Vector3(x-2.5+post*0.62,0.6,-1.7),Vector3(0.06,1.1,0.06),"313b35")
		_box(Vector3(x,0.95,-1.7),Vector3(5.2,0.05,0.06),"313b35")
	_label("HOUSE FOR SALE",Vector3(19,1.6,-1.45),0.008)
	_box(Vector3(19,0.75,-1.5),Vector3(0.09,1.5,0.09),"d4c5ac")
	# Apartment entry and corner shop.
	_box(Vector3(-16,1.4,-5.42),Vector3(1.6,2.8,0.16),"4e4c3e")
	_label("APARTMENTS",Vector3(-16,3.1,-5.3),0.009)
	_box(Vector3(-2,2.8,-5.05),Vector3(8.4,0.25,1.0),"397461")
	_box(Vector3(-2,1.6,-5.4),Vector3(7.6,2.0,0.10),"849b8b")
	_label("CORNER MARKET",Vector3(-2,3.23,-5.15),0.009)
	for x in [-4.7,-2.0,0.7]:
		_box(Vector3(x,1.5,-5.3),Vector3(0.08,2.4,0.12),"dfccb0")
	for x in [-26.0,5.0,25.0]:
		_box(Vector3(x,1.4,-0.9),Vector3(0.2,2.8,0.2),"746044")
		var foliage := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius=1.5
		sphere.height=3.5
		foliage.mesh=sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color=Color("557044")
		foliage.material_override=mat
		foliage.position=Vector3(x,3.5,-0.9)
		add_child(foliage)
		obstacles.append(Rect2(Vector2(x-0.5,-1.4),Vector2(1,1)))
	for x in [-22.0,-8.0,8.0,23.0]:
		_box(Vector3(x,2.0,9.5),Vector3(0.11,4,0.11),"37413b")
		_box(Vector3(x,4,9.5),Vector3(0.5,0.3,0.5),"ecd19c")
	for x in [-23.0,4.0,23.0]:
		_box(Vector3(x,0.55,8.3),Vector3(3.8,0.75,1.6),"344c4f")
		_box(Vector3(x,1.12,8.3),Vector3(2.1,0.65,1.45),"677a7b")
		obstacles.append(Rect2(Vector2(x-2.2,7.2),Vector2(4.4,2.2)))
	# Buildings and closed side streets provide visible block boundaries.
	for x in [-29.0,29.0]:
		_box(Vector3(x,0.7,4.5),Vector3(0.5,1.4,18),"817c65")
	for x in range(-27,28,9):
		_building(Vector3(x,0,19),Vector3(8,7+(x+27)%5,8),"7e7366")
		_building(Vector3(x,0,-24),Vector3(8,12+(x+27)%7,7),"8b8176")
	var sun := DirectionalLight3D.new()
	outdoor_sun=sun
	sun.rotation_degrees=Vector3(-48,-30,0)
	sun.light_color=Color("ffddac")
	sun.light_energy=0.65
	sun.shadow_enabled=false
	add_child(sun)

func _build_controls() -> void:
	controls=CanvasLayer.new()
	controls.layer=4
	add_child(controls)
	pad=HBoxContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	pad.offset_left=-260
	pad.offset_right=260
	pad.offset_top=-165
	pad.offset_bottom=-99
	pad.add_theme_constant_override("separation",12)
	controls.add_child(pad)
	for caption in ["TURN L","WALK","BACK","TURN R"]:
		var button:=Button.new()
		button.text=caption
		button.custom_minimum_size=Vector2(120,66)
		button.focus_mode=Control.FOCUS_NONE
		_style_button(button)
		pad.add_child(button)
		buttons.append(button)
	action=Button.new()
	action.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	action.offset_left=-260
	action.offset_right=256
	action.offset_top=-88
	action.offset_bottom=-28
	action.focus_mode=Control.FOCUS_NONE
	_style_button(action)
	action.pressed.connect(_interact)
	controls.add_child(action)
	controls.hide()

func _style_button(button: Button) -> void:
	for state in ["normal","hover","pressed","disabled"]:
		var style:=StyleBoxFlat.new()
		style.bg_color=Color("183e32") if state=="pressed" else Color("14231f")
		style.border_color=Color("71bb91")
		style.set_border_width_all(2)
		style.set_corner_radius_all(10)
		button.add_theme_stylebox_override(state,style)
	button.add_theme_color_override("font_color",Color("eef6eb"))
	button.add_theme_color_override("font_disabled_color",Color("92a398"))

func _build_door_hinge() -> void:
	door_pivot=Node3D.new()
	door_pivot.position=Vector3(-0.94,1.48,5.84)
	host.add_child(door_pivot)
	for part_name in ["Door","DoorPanelTop","DoorPanelBottom","DoorKnob","Peephole"]:
		var part=host.get_node_or_null(part_name)
		if part != null:
			part.reparent(door_pivot,true)

func leave_apartment() -> void:
	if active or transitioning or host._any_modal_open() or host.customer_waiting:
		return
	transitioning=true
	host.current_view="room_transition"
	host._reset_world_pointer()
	host._cancel_camera_view_tween()
	host._refresh_navigation_ui()
	var tween:=create_tween()
	tween.tween_property(door_pivot,"rotation:y",-1.45,0.35)
	tween.tween_property(host.camera,"position",Vector3(0,1.64,5.6),0.5)
	tween.tween_callback(_arrive_outside)

func _arrive_outside() -> void:
	active=true
	host.camera.environment=outdoor_environment
	transitioning=false
	visible=true
	door_pivot.rotation.y=0
	host.current_room="neighborhood"
	host.current_view="neighborhood"
	host.camera.position=ORIGIN+Vector3(-16,1.64,-3.7)
	host.camera.rotation=Vector3(0,PI,0)
	host.status_label.text="Walk the block. Your apartment is behind you; the new house is beside the market."
	host._refresh_navigation_ui()

func refresh_controls() -> void:
	for button in [host.left_button,host.right_button,host.forward_button,host.back_button,host.contextual_button,host.door_quick_button]:
		button.hide()
	for label in [host.view_label,host.status_label]:
		label.add_theme_color_override("font_outline_color",Color("17251f"))
		label.add_theme_constant_override("outline_size",4)
	host.view_label.text="NEIGHBORHOOD | HOLD TO WALK / DRAG TO LOOK"

func handle_input(event: InputEvent) -> void:
	if host._any_modal_open() or host.daily_report_pending:
		pointer=-99
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_P:
			host._toggle_phone()
		elif event.keycode==KEY_E:
			_interact()
	if event is InputEventScreenTouch:
		if not event.pressed:
			if pointer==event.index: pointer=-99
		elif pointer==-99 and not _over_ui(event.position):
			pointer=event.index
			last_pointer=event.position
	elif event is InputEventScreenDrag and event.index==pointer:
		_look(event.position-last_pointer)
		last_pointer=event.position
	elif event is InputEventMouseButton and event.device!=-1 and event.button_index==MOUSE_BUTTON_LEFT:
		pointer=-1 if event.pressed and not _over_ui(event.position) else -99
	elif event is InputEventMouseMotion and event.device!=-1 and pointer==-1:
		_look(event.relative)

func _over_ui(point: Vector2) -> bool:
	return pad.get_global_rect().has_point(point) or action.get_global_rect().has_point(point) or host._pointer_over_room_ui(point)

func _look(motion: Vector2) -> void:
	host.camera.rotation.y-=motion.x*0.004
	host.camera.rotation.x=clampf(host.camera.rotation.x-motion.y*0.003,-0.65,0.65)

func _process(delta: float) -> void:
	if not active: return
	var night: bool=host.day_phase=="NIGHT"
	outdoor_sun.light_energy=0.08 if night else 0.65
	outdoor_environment.background_color=Color("202c41") if night else Color("b5c7d0")
	outdoor_environment.ambient_light_energy=0.35 if night else 0.4
	var blocked: bool=host._any_modal_open() or host.daily_report_pending or transitioning
	controls.visible=not blocked
	if blocked:
		pointer=-99
		return
	var turn:=float(buttons[0].button_pressed or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))-float(buttons[3].button_pressed or Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
	var walk:=float(buttons[1].button_pressed or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))-float(buttons[2].button_pressed or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
	host.camera.rotation.y+=turn*delta*1.65
	var heading: float=host.camera.rotation.y
	var step:=Vector3(-sin(heading),0,-cos(heading))*walk*minf(delta,0.05)*3.2
	var local: Vector3=host.camera.position-ORIGIN
	var next:=local+Vector3(step.x,0,0)
	if _walkable(next): local=next
	next=local+Vector3(0,0,step.z)
	if _walkable(next): local=next
	host.camera.position=ORIGIN+local
	var target:=_near_target()
	action.disabled=target.is_empty()
	action.text="RETURN TO APARTMENT" if target=="apartment" else (("INSPECT HOUSE" if host.property_offer_unlocked else "HOUSE | NOT AVAILABLE YET") if target=="house" else "WALK TO AN ENTRANCE")
	if host.customer_waiting:
		host.status_label.text="Someone is at your apartment door. Walk back to answer."

func _walkable(pos: Vector3) -> bool:
	if pos.x < -28 or pos.x > 28 or pos.z < -5.0 or pos.z > 13.5: return false
	for rect in obstacles:
		if rect.has_point(Vector2(pos.x,pos.z)): return false
	return true

func _near_target() -> String:
	var pos: Vector3=host.camera.position-ORIGIN
	if Vector2(pos.x+16,pos.z+4.5).length()<2.5: return "apartment"
	if Vector2(pos.x-14,pos.z+4.2).length()<2.5: return "house"
	return ""

func _interact() -> void:
	if not active or host._any_modal_open() or host.daily_report_pending: return
	match _near_target():
		"apartment":
			active=false
			host.camera.environment=null
			visible=false
			controls.hide()
			pointer=-99
			host.current_room="main"
			host.room_ring=host.main_room_ring
			host._go_to_view("door",false)
			host.status_label.text="You step back into your apartment."
		"house":
			host.status_label.text="Rod's property offer is ready. This is the house. Tours and ownership options are coming next." if host.property_offer_unlocked else "This house is not available yet. Keep building your operation and watch for Rod's text."
