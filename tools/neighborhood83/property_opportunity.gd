extends RefCounted
const ROOMS := {"living":"Living room", "kitchen":"Kitchen", "grow":"Grow room", "packing":"Packing room", "bathroom":"Bathroom", "bedroom":"Bedroom"}
var world: Node3D
var host: Node3D
var layer: CanvasLayer
var overlay: ColorRect
var panel: PanelContainer
var footer: VBoxContainer
var body: VBoxContainer
var tour_bar: VBoxContainer
var tour_label: Label
var touring := false
var dwell: Dictionary = {}
func setup(owner: Node3D) -> void:
	world=owner
	host=owner.host
	layer=CanvasLayer.new()
	layer.layer=25
	world.add_child(layer)
	overlay=ColorRect.new()
	overlay.color=Color(0.025,0.045,0.035,0.88)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter=Control.MOUSE_FILTER_STOP
	layer.add_child(overlay)
	panel=PanelContainer.new()
	overlay.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color=Color("14231e")
	style.border_color=Color("74b692")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left=18
	style.content_margin_right=18
	style.content_margin_top=16
	style.content_margin_bottom=16
	panel.add_theme_stylebox_override("panel",style)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation",12)
	panel.add_child(layout)
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	footer=VBoxContainer.new()
	footer.add_theme_constant_override("separation",8)
	layout.add_child(footer)
	body=VBoxContainer.new()
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",12)
	scroll.add_child(body)
	tour_bar=VBoxContainer.new()
	tour_bar.add_theme_constant_override("separation",4)
	layer.add_child(tour_bar)
	tour_label=Label.new()
	tour_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	tour_label.add_theme_color_override("font_outline_color",Color("102019"))
	tour_label.add_theme_constant_override("outline_size",5)
	tour_label.add_theme_font_size_override("font_size",18)
	tour_bar.add_child(tour_label)
	var end := Button.new()
	end.text="REVIEW PROPERTY / END TOUR"
	end.custom_minimum_size.y=42
	end.pressed.connect(func(): show_details())
	tour_bar.add_child(end)
	overlay.hide()
	tour_bar.hide()
	host.get_viewport().size_changed.connect(resize)
	resize()
func resize() -> void:
	var viewport: Vector2=host.get_viewport().get_visible_rect().size
	var width: float=minf(760,viewport.x-24)
	var height: float=minf(780,viewport.y-36)
	panel.position=Vector2((viewport.x-width)/2,(viewport.y-height)/2)
	panel.size=Vector2(width,height)
	tour_bar.position=Vector2(18,140)
	tour_bar.size=Vector2(minf(410,viewport.x-36),100)
func is_open() -> bool:
	return overlay!=null and overlay.visible
func label(text: String, size: int=24) -> void:
	var item := Label.new()
	item.text=text
	item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size",size)
	item.add_theme_color_override("font_color",Color("e5efdf"))
	body.add_child(item)
func button(text: String, callback: Callable) -> void:
	var item := Button.new()
	item.text=text
	item.custom_minimum_size.y=54
	item.add_theme_font_size_override("font_size",22)
	item.pressed.connect(callback)
	footer.add_child(item)
func visited() -> Array:
	var result: Array=[]
	var saved: Variant=host.property_opportunity_state.get("rooms",[])
	if saved is Array:
		for room in saved:
			if ROOMS.has(str(room)) and not result.has(str(room)): result.append(str(room))
	return result
func show_details() -> void:
	if not host.property_offer_unlocked:
		host.status_label.text="This house is not available yet. Keep building your operation and watch for Rod's text."
		return
	world.pad.release()
	world.pointer=-99
	host.property_opportunity_state["details_viewed"]=true
	host._save_game()
	for container in [body,footer]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	label("ROD'S PROPERTY OPPORTUNITY",30)
	label("A HOUSE WITH ROOM TO GROW",28)
	label("Across from your apartment: a living room, kitchen, bathroom, bedroom, and separate grow and packing rooms.")
	label("The grow room is empty. Your apartment equipment and stock stay where they are during the inspection.")
	var seen: Array=visited()
	label("ROOMS INSPECTED: %d / %d" % [seen.size(),ROOMS.size()],26)
	for room in ROOMS: label(("✓ " if seen.has(room) else "○ ")+ROOMS[room],23)
	if seen.size()==ROOMS.size(): label("INSPECTION COMPLETE — you've seen every room.",26)
	button("CONTINUE WALKING TOUR" if not seen.is_empty() else "TOUR HOUSE",begin_tour)
	button("END TOUR" if touring else "BACK TO NEIGHBORHOOD",end_tour)
	overlay.show()
	tour_bar.hide()
	resize()
func begin_tour() -> void:
	if not host.property_offer_unlocked: return
	overlay.hide()
	touring=true
	dwell.clear()
	host.property_opportunity_state["tour_started"]=true
	host._save_game()
	var door: Node3D=world.get_node_or_null("HouseEntrance")
	if door!=null and not door.opened and not door.busy:
		door.toggle(host.camera.position)
	host.status_label.text="Walk through the house. Spend a moment in each room to inspect it."
	update(0)
func end_tour() -> void:
	overlay.hide()
	tour_bar.hide()
	touring=false
	dwell.clear()
	host._save_game()
	host.status_label.text="Your house inspection progress is saved."
func update(delta: float) -> void:
	if not touring: return
	if not host.property_offer_unlocked:
		end_tour()
		return
	tour_bar.visible=not is_open() and not host._any_modal_open() and world.active
	if not tour_bar.visible: return
	var room: String=world.house_controls._inside_room(host.camera.position)
	var seen: Array=visited()
	if ROOMS.has(room) and not seen.has(room):
		dwell[room]=float(dwell.get(room,0.0))+minf(delta,0.1)
		if float(dwell[room])>=2.0:
			seen.append(room)
			host.property_opportunity_state["rooms"]=seen
			host.property_opportunity_state["inspection_complete"]=seen.size()==ROOMS.size()
			host._save_game()
	tour_label.text="HOUSE TOUR · %d / 6 ROOMS INSPECTED\n%s" % [seen.size(),("Inspection complete. Review the property when ready." if seen.size()==6 else (ROOMS[room]+(" · inspected" if seen.has(room) else " · inspecting…") if ROOMS.has(room) else "Walk to the house and inspect each room."))]
