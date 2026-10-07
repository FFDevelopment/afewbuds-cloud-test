extends RefCounted
const ROOMS := {"living":"Living room", "kitchen":"Kitchen", "grow":"Grow room", "packing":"Packing room", "bathroom":"Bathroom", "bedroom":"Bedroom"}
const RENT_DEPOSIT:=1800
const RENT_PAYMENT:=600
const LEASE_DOWN:=4500
const LEASE_PAYMENT:=1000
const LEASE_TOTAL:=18500
const PURCHASE_PRICE:=17500
const PAYMENT_INTERVAL:=7

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
var pending_agreement := ""

func setup(owner: Node3D) -> void:
	world=owner
	host=owner.host
	_ensure_state()
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
	end.pressed.connect(show_details)
	tour_bar.add_child(end)
	overlay.hide()
	tour_bar.hide()
	host.get_viewport().size_changed.connect(resize)
	resize()

func _ensure_state() -> void:
	if not host.property_opportunity_state is Dictionary:
		host.property_opportunity_state={}
	var defaults:Dictionary={
		"rooms":[],
		"inspection_complete":false,
		"details_viewed":false,
		"tour_started":false,
		"agreement":"",
		"agreement_signed":false,
		"acquired":false,
		"relocated":false,
		"first_entry":false,
		"chapter5_started":false,
		"upfront_paid":0,
		"balance":0,
		"next_due":0,
		"equity_paid":0,
		"ownership_total":LEASE_TOTAL,
		"owned":false
	}
	for key in defaults:
		if not host.property_opportunity_state.has(key):
			host.property_opportunity_state[key]=defaults[key]
	if not host.location_state is Dictionary:host.location_state={}
	if not host.location_state.has("active_property"):host.location_state["active_property"]="apartment"

func state() -> Dictionary:
	_ensure_state()
	return host.property_opportunity_state

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

func _clear() -> void:
	for container in [body,footer]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()

func label(text: String, size: int=24) -> void:
	var item := Label.new()
	item.text=text
	item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size",size)
	item.add_theme_color_override("font_color",Color("e5efdf"))
	body.add_child(item)

func button(text: String, callback: Callable, disabled:bool=false) -> void:
	var item := Button.new()
	item.text=text
	item.custom_minimum_size.y=54
	item.add_theme_font_size_override("font_size",22)
	item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	item.disabled=disabled
	item.pressed.connect(callback)
	footer.add_child(item)

func visited() -> Array:
	var result: Array=[]
	var saved: Variant=state().get("rooms",[])
	if saved is Array:
		for room in saved:
			if ROOMS.has(str(room)) and not result.has(str(room)): result.append(str(room))
	return result

func agreement_name(kind:String="") -> String:
	var value:=kind if not kind.is_empty() else str(state().get("agreement",""))
	return {"rent":"RENT","lease":"LEASE TO OWN","purchase":"PURCHASE"}.get(value,"NONE")

func agreement_upfront(kind:String) -> int:
	return {"rent":RENT_DEPOSIT,"lease":LEASE_DOWN,"purchase":PURCHASE_PRICE}.get(kind,0)

func agreement_weekly(kind:String) -> int:
	return {"rent":RENT_PAYMENT,"lease":LEASE_PAYMENT}.get(kind,0)

func show_details() -> void:
	if not host.property_offer_unlocked:
		host.status_label.text="This house is not available yet. Keep building your operation and watch for Rod's text."
		return
	_ensure_state()
	world.pad.release()
	world.pointer=-99
	state()["details_viewed"]=true
	host._save_game()
	_clear()
	if bool(state().get("relocated",false)):
		label("AFewBuds HOUSE OPERATION",30)
		label("CHAPTER 5 — BUILDING AN OPERATION",27)
		label("Agreement: %s" % agreement_name(),22)
		label("The house is now your active operation. Your career inventory, genetics, crew, dealers and purchased equipment progression were preserved during the move.",20)
		if str(state().get("agreement",""))=="lease":
			label("OWNERSHIP EQUITY: $%d / $%d" % [int(state().get("equity_paid",0)),LEASE_TOTAL],22)
		button("BACK TO NEIGHBORHOOD",end_tour)
		overlay.show();tour_bar.hide();resize()
		return
	if bool(state().get("agreement_signed",false)):
		show_relocation()
		return
	label("ROD'S PROPERTY OPPORTUNITY",30)
	label("A HOUSE WITH ROOM TO GROW",28)
	label("Across from your apartment: a living room, kitchen, bathroom, bedroom, and separate grow and packing rooms.")
	label("The grow room is empty. Your apartment equipment and stock stay where they are during the inspection.")
	var seen: Array=visited()
	label("ROOMS INSPECTED: %d / %d" % [seen.size(),ROOMS.size()],26)
	for room in ROOMS: label(("✓ " if seen.has(room) else "○ ")+ROOMS[room],23)
	if seen.size()==ROOMS.size():
		label("INSPECTION COMPLETE — choose how you want to secure the property.",26)
		button("AGREEMENT OPTIONS",show_agreements)
	else:
		label("Inspect every room before signing an agreement.",20)
	button("CONTINUE WALKING TOUR" if not seen.is_empty() else "TOUR HOUSE",begin_tour)
	button("END TOUR" if touring else "BACK TO NEIGHBORHOOD",end_tour)
	overlay.show()
	tour_bar.hide()
	resize()

func show_agreements() -> void:
	if not host.property_offer_unlocked or not bool(state().get("inspection_complete",false)):return
	_clear()
	label("CHOOSE YOUR NEXT BASE",30)
	label("Signing secures the house. Nothing is relocated until you review and confirm the move.",20)
	label("RENT",26)
	label("$%d move-in / deposit · $%d every %d game days · no ownership equity." % [RENT_DEPOSIT,RENT_PAYMENT,PAYMENT_INTERVAL],19)
	label("LEASE TO OWN",26)
	label("$%d down · $%d every %d game days · payments build toward $%d ownership." % [LEASE_DOWN,LEASE_PAYMENT,PAYMENT_INTERVAL,LEASE_TOTAL],19)
	label("PURCHASE",26)
	label("$%d outright · no recurring property payment · permanent ownership." % PURCHASE_PRICE,19)
	button("RENT · $%d" % RENT_DEPOSIT,confirm_agreement.bind("rent"),host.cash<RENT_DEPOSIT)
	button("LEASE TO OWN · $%d DOWN" % LEASE_DOWN,confirm_agreement.bind("lease"),host.cash<LEASE_DOWN)
	button("PURCHASE · $%d" % PURCHASE_PRICE,confirm_agreement.bind("purchase"),host.cash<PURCHASE_PRICE)
	button("BACK",show_details)
	overlay.show();tour_bar.hide();resize()

func confirm_agreement(kind:String) -> void:
	if kind not in ["rent","lease","purchase"] or not bool(state().get("inspection_complete",false)):return
	pending_agreement=kind
	_clear()
	label("CONFIRM %s" % agreement_name(kind),30)
	label("Upfront due now: $%d" % agreement_upfront(kind),24)
	if agreement_weekly(kind)>0:
		label("Recurring payment: $%d every %d game days." % [agreement_weekly(kind),PAYMENT_INTERVAL],20)
	if kind=="lease":label("Your $%d down payment counts toward the $%d ownership total." % [LEASE_DOWN,LEASE_TOTAL],20)
	label("This agreement does not move anything yet. You will review the relocation before confirming.",19)
	button("SIGN %s" % agreement_name(kind),sign_agreement.bind(kind),host.cash<agreement_upfront(kind))
	button("BACK TO OPTIONS",show_agreements)
	overlay.show();resize()

func sign_agreement(kind:String) -> void:
	if bool(state().get("agreement_signed",false)):return
	var upfront:=agreement_upfront(kind)
	if upfront<=0 or host.cash<upfront:return
	host.cash-=upfront
	host._record_daily_expense("House "+agreement_name(kind).capitalize(),upfront)
	state()["agreement"]=kind
	state()["agreement_signed"]=true
	state()["acquired"]=true
	state()["upfront_paid"]=upfront
	state()["balance"]=0
	state()["next_due"]=host.game_day+PAYMENT_INTERVAL if agreement_weekly(kind)>0 else 0
	state()["equity_paid"]=LEASE_DOWN if kind=="lease" else (PURCHASE_PRICE if kind=="purchase" else 0)
	state()["owned"]=kind=="purchase"
	state()["signed_day"]=host.game_day
	host.location_state["house"]={
		"agreement":kind,
		"acquired":true,
		"active":false
	}
	host._update_cash_ui()
	host._save_game()
	show_relocation()

func show_relocation() -> void:
	_clear()
	label("PREPARE RELOCATION",30)
	label("Agreement signed: %s" % agreement_name(),23)
	label("MOVE WITH THE OPERATION",22)
	label("✓ seeds and fertilizer
✓ trimmed, bagged and stored product
✓ Dealer Storage inventory
✓ genetics unlocks
✓ staff and dealers
✓ purchased portable equipment progression",19)
	label("Permanent apartment construction stays with the apartment. This first relocation preserves your career state instead of deleting or repurchasing existing progression.",19)
	if str(state().get("agreement",""))=="lease":
		label("OWNERSHIP EQUITY: $%d / $%d" % [int(state().get("equity_paid",0)),LEASE_TOTAL],21)
	button("MOVE OPERATION",confirm_relocation)
	button("BACK TO PROPERTY",show_details)
	overlay.show();tour_bar.hide();resize()

func confirm_relocation() -> void:
	if not bool(state().get("agreement_signed",false)) or bool(state().get("relocated",false)):return
	state()["relocated"]=true
	state()["relocation_day"]=host.game_day
	host.location_state["active_property"]="house"
	if host.location_state.get("house",{}) is Dictionary:
		host.location_state["house"]["active"]=true
	host.apartment_rent_state["balance"]=0
	host.apartment_rent_state["first_unpaid"]=0
	state()["apartment_surrendered"]=true
	host._save_game()
	overlay.hide()
	tour_bar.hide()
	touring=false
	_mark_first_entry_if_inside()
	host.status_label.text="Relocation confirmed. Enter the house to complete Chapter 4 and begin Chapter 5."

func _mark_first_entry_if_inside() -> void:
	if not bool(state().get("relocated",false)) or bool(state().get("first_entry",false)):return
	var room:String=world.house_controls._inside_room(host.camera.position)
	if not ROOMS.has(room):return
	state()["first_entry"]=true
	state()["chapter5_started"]=true
	host._chapter_four_append_story_text("You made the move. The house is your operation now. Chapter 4 is complete — time to build something bigger.")
	host._save_game()
	host.status_label.text="CHAPTER 4 COMPLETE · Chapter 5 — Building an Operation."

func begin_tour() -> void:
	if not host.property_offer_unlocked or bool(state().get("relocated",false)): return
	overlay.hide()
	touring=true
	dwell.clear()
	state()["tour_started"]=true
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
	_mark_first_entry_if_inside()
	if not touring:return
	if not host.property_offer_unlocked:
		end_tour()
		return
	tour_bar.visible=not is_open() and not host._any_modal_open() and world.active
	if not tour_bar.visible:return
	var room: String=world.house_controls._inside_room(host.camera.position)
	var seen: Array=visited()
	if ROOMS.has(room) and not seen.has(room):
		dwell[room]=float(dwell.get(room,0.0))+minf(delta,0.1)
		if float(dwell[room])>=2.0:
			seen.append(room)
			state()["rooms"]=seen
			state()["inspection_complete"]=seen.size()==ROOMS.size()
			host._save_game()
	tour_label.text="HOUSE TOUR · %d / 6 ROOMS INSPECTED\n%s" % [seen.size(),("Inspection complete. Review the property when ready." if seen.size()==6 else (ROOMS[room]+(" · inspected" if seen.has(room) else " · inspecting…") if ROOMS.has(room) else "Walk to the house and inspect each room."))]
