extends RefCounted
const Districts = preload("res://scripts/districts.gd")
var world: Node3D
var host: Node3D
var last_status := ""
var status_left := 0.0
var unread := 0
var learned := false
func setup(owner: Node3D) -> void:
	world=owner;host=owner.host;unread=host.phone_text_unread
	var bar: Control=host.world_top_bar
	bar.offset_top=12;bar.offset_bottom=70
	host.cash_label.add_theme_font_size_override("font_size",23)
	host.brand_label.add_theme_font_size_override("font_size",20)
	host.brand_label.modulate=Color.WHITE
	host.brand_label.add_theme_color_override("font_color",Color("e5efdf"))
	host.brand_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	update_location()
	host.day_night_label.custom_minimum_size=Vector2(105,44)
	for button in bar.find_children("*","Button",true,false):
		button.custom_minimum_size=Vector2(105,48)
		button.add_theme_font_size_override("font_size",17)
	host.status_label.offset_top=112;host.status_label.offset_bottom=164
	host.status_label.add_theme_font_size_override("font_size",16)
	host.status_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	host.view_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	world.action.add_theme_font_size_override("font_size",17)
	world.action.custom_minimum_size=Vector2(0,80)
func update_location() -> void:
	# Station close-ups may move the camera; keep the district where the player stood.
	var position: Vector3=world.walk_position if world.in_station else host.camera.position
	host.brand_label.text=Districts.CITY + " /\n" + Districts.district_at(position)
func update(delta: float) -> void:
	update_location()
	if host.tutorial_active:return
	var walking: bool=world.active
	var modal: bool=host._any_modal_open() or host.daily_report_pending
	if walking and not learned and not modal:
		learned=true
		host.status_label.text="Stick to walk · Drag to look · Double tap nearby objects"
	if host.phone_text_unread>unread:
		host.status_label.text="New message · Open Phone → Messages"
	unread=host.phone_text_unread
	if host.status_label.text!=last_status:
		last_status=host.status_label.text
		status_left=4.0
	status_left=maxf(0.0,status_left-delta)
	host.status_label.visible=status_left>0.0 and not modal
	host.status_label.modulate.a=minf(1.0,status_left)
	host.view_label.visible=not walking and not modal
	if walking:
		for button in [host.left_button,host.right_button,host.forward_button,host.back_button,host.contextual_button,host.door_quick_button]:button.hide()
	elif world.in_station:
		# Keep the station's own panel and Back, rather than room navigation arrows.
		for button in [host.left_button,host.right_button,host.forward_button,host.door_quick_button]:button.hide()
		if host.back_button.visible:host.back_button.text="BACK"
	world.pad.visible=walking and not modal
	world.action.visible=walking and not modal and not world._near_target().is_empty() and not (host.inventory_system!=null and host.inventory_system.native_station_target(world._near_target()))
	# Visitor countdown is immediate information; keep it compact and persistent.
	if host.knock_banner!=null and host.knock_banner.visible:
		host.knock_banner.offset_top=12 if modal else host.world_top_bar.offset_bottom+12;host.knock_banner.offset_bottom=host.knock_banner.offset_top+56
		host.knock_banner.offset_left=-210;host.knock_banner.offset_right=210
		host.knock_text.add_theme_font_size_override("font_size",18)
		host.door_alert_detail.add_theme_font_size_override("font_size",14)
		host.door_alert_dot.hide()
		host.door_alert_button.hide()
		host.status_label.hide()
