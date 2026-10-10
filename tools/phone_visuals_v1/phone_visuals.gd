extends RefCounted
# Shared visual layer. All actions and balances still come from the live game.
const SIZE := Vector2(440,805)
const INK := Color("f3f3e9")
const MUTED := Color("9caea3")
const MINT := Color("a4e3b3")
const ICONS = {"Properties": "<path d=\"m3 10 9-7 9 7M5 9v12h14V9M9 21v-8h6v8\"/>", "Contacts": "<circle cx=\"12\" cy=\"7\" r=\"4\"/><path d=\"M4 21v-3a8 8 0 0 1 16 0v3\"/>", "Shop": "<path d=\"M3 3h3l3 13h10l3-9H7M10 21h.01M19 21h.01\"/>", "Genetics": "<path d=\"M6 3c0 8 12 10 12 18M18 3C18 11 6 13 6 21M7 5h10M8 9h8M8 15h8M7 19h10\"/>", "Clients": "<circle cx=\"8\" cy=\"8\" r=\"3\"/><circle cx=\"18\" cy=\"9\" r=\"3\"/><path d=\"M1 21v-3a7 7 0 0 1 14 0v3M16 15a6 6 0 0 1 7 6\"/>", "Rewards": "<path d=\"M7 3h10v6a5 5 0 0 1-10 0V3ZM7 5H3v3a5 5 0 0 0 5 5M17 5h4v3a5 5 0 0 1-5 5M12 14v7M7 21h10\"/>", "Stats": "<path d=\"M3 21V11h4v10M10 21V6h4v15M17 21V2h4v19\"/>", "Heat": "<path d=\"m12 2 9 4v6c0 5-9 10-9 10S3 17 3 12V6l9-4Z M12 7v6M12 17h.01\"/>", "Messages": "<path d=\"M3 3h18v14H8l-5 4V3Z M7 8h10M7 12h7\"/>", "Leaderboard": "<path d=\"M7 3h10v6a5 5 0 0 1-10 0V3ZM7 5H3v3a5 5 0 0 0 5 5M17 5h4v3a5 5 0 0 1-5 5M12 14v7M7 21h10\"/>", "Battery": "<rect x=\"2\" y=\"7\" width=\"18\" height=\"10\" rx=\"2\"/><path d=\"M23 10v4M5 10v4M8 10v4M11 10v4M14 10v4M17 10v4\"/>", "Back": "<path d=\"m15 5-7 7 7 7\"/>", "Home": "<path d=\"M4 12h16\" stroke-width=\"4\"/>", "Help": "<circle cx=\"12\" cy=\"12\" r=\"9\"/><path d=\"M9 9a3 3 0 1 1 5 2c-2 1-2 2-2 3M12 17h.01\"/>", "Pause": "<path d=\"M8 5v14M16 5v14\" stroke-width=\"3\"/>"}

static var icon_cache:Dictionary={}

static func box(color:Color, radius:int=16, border:Color=Color("35483c"), padding:int=14) -> StyleBoxFlat:
	var b:=StyleBoxFlat.new()
	b.bg_color=color;b.border_color=border;b.set_border_width_all(1);b.set_corner_radius_all(radius)
	b.content_margin_left=padding;b.content_margin_right=padding;b.content_margin_top=padding;b.content_margin_bottom=padding
	return b

static func fit(host:Node) -> void:
	var panel:Control=host.phone_panel
	if panel==null:return
	if ThemeDB.fallback_font is FontFile and ThemeDB.fallback_font.oversampling < 2.0:
		ThemeDB.fallback_font.oversampling=2.0
	var screen:Vector2=host.get_viewport().get_visible_rect().size
	var available:=screen-Vector2(52,116)
	# Keep phone text at a readable physical size when the desktop canvas
	# scales down. Shorten the scrolling screen instead of shrinking its type.
	var window_size:=Vector2(host.get_window().size)
	# Headless CI starts with a dummy 64px window, not a player display.
	if DisplayServer.get_name()=="headless" and window_size.x<320:window_size=screen
	var canvas_scale:=minf(window_size.x/screen.x,window_size.y/screen.y)
	var factor:=minf(available.x/SIZE.x,maxf(available.y/SIZE.y,1.0/maxf(canvas_scale,0.1)))
	var layout_size:=Vector2(SIZE.x,minf(SIZE.y,available.y/factor))
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.size=layout_size
	panel.scale=Vector2.ONE*factor
	panel.position=((screen-layout_size*factor)*0.5+Vector2(0,38)).round()

static func label(text:String, size:int=14, color:Color=INK) -> Label:
	var item:=Label.new();item.text=text
	item.add_theme_font_size_override("font_size",size);item.add_theme_color_override("font_color",color)
	item.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return item

static func icon(name:String, color:String="f7f0d8") -> Texture2D:
	var key:=name+color
	if icon_cache.has(key):return icon_cache[key]
	var source:String='<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 24 24"><g fill="none" stroke="#'+color+'" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">'+str(ICONS.get(name,ICONS.Properties))+'</g></svg>'
	var image:=Image.new();image.load_svg_from_string(source)
	icon_cache[key]=ImageTexture.create_from_image(image)
	return icon_cache[key]

static func tile(parent:GridContainer, name:String, app:String, color:String, action:Callable, detail:String="") -> void:
	var button:=Button.new();button.set_meta("phone_app",app);button.set_meta("phone_visual",true)
	button.custom_minimum_size=Vector2(0,99);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.text=name
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:button.add_theme_color_override(state,Color.TRANSPARENT)
	button.tooltip_text=detail;button.pressed.connect(action)
	for state in ["normal","hover","pressed"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus",box(Color("203a2a"),18,MINT,0))
	parent.add_child(button)
	var plate:=Panel.new();plate.position=Vector2(16,2);plate.size=Vector2(65,65);plate.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style:=box(Color(color),18,Color("8caa8c"),0);style.shadow_color=Color(0,0,0,0.3);style.shadow_size=5;style.shadow_offset=Vector2(0,4)
	plate.add_theme_stylebox_override("panel",style);button.add_child(plate)
	var wash:=TextureRect.new();wash.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	var wash_image:=Image.new()
	wash_image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="65" height="65"><defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#ffffff" stop-opacity=".13"/><stop offset="1" stop-color="#000000" stop-opacity=".25"/></linearGradient></defs><rect x="1" y="1" width="63" height="63" rx="17" fill="url(#g)"/></svg>')
	wash.texture=ImageTexture.create_from_image(wash_image);wash.size=Vector2(65,65);wash.mouse_filter=Control.MOUSE_FILTER_IGNORE;plate.add_child(wash)
	var picture:=TextureRect.new();picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.texture=icon(name);picture.position=Vector2(17,17);picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.size=Vector2(31,31);picture.mouse_filter=Control.MOUSE_FILTER_IGNORE;plate.add_child(picture)
	var caption:=label(name,13);caption.position=Vector2(0,77);caption.size=Vector2(97,18);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;button.add_child(caption)
	button.resized.connect(func():plate.position.x=(button.size.x-65)*0.5;caption.size.x=button.size.x)
	button.mouse_entered.connect(func():plate.modulate=Color(1.2,1.2,1.2))
	button.mouse_exited.connect(func():plate.modulate=Color.WHITE)

static func home(host:Node) -> void:
	var parent:VBoxContainer=host.phone_list
	parent.set_meta("phone_visual",true)
	parent.add_theme_constant_override("separation",19)
	var brand:=RichTextLabel.new();brand.bbcode_enabled=true;brand.fit_content=true;brand.scroll_active=false;brand.text="[b]AFew[color=#a4e3b3]Buds[/color][/b]";brand.add_theme_font_size_override("normal_font_size",39);brand.add_theme_font_size_override("bold_font_size",39);parent.add_child(brand)
	parent.add_child(label("YOUR WORLD. WITHIN REACH.",12,MUTED))
	var ops=host.neighborhood.location_ops if host.neighborhood!=null else null
	var property:String=ops.active_property() if ops!=null else "apartment"
	var widget:=Button.new();widget.custom_minimum_size.y=106;widget.add_theme_stylebox_override("normal",box(Color("1c3024"),19));widget.pressed.connect(host._phone_open_property_from_business.bind(property));parent.add_child(widget)
	var art:=TextureRect.new();art.texture=icon("Properties","cce0ae");art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.position=Vector2(15,24);art.size=Vector2(52,52);art.mouse_filter=Control.MOUSE_FILTER_IGNORE;widget.add_child(art)
	var title:=label(ops.portfolio_name(property) if ops!=null else "Properties",15);title.position=Vector2(80,18);widget.add_child(title)
	var count:int=ops.computer_staff_names(property).size() if ops!=null else 0
	var staff:=label("%d assigned crew" % count,13,MUTED);staff.position=Vector2(80,44);widget.add_child(staff)
	var due:int=ops.computer_due(property) if ops!=null else 0
	var bill:=label(("$%d in bills due" % due) if due>0 else "All bills paid",13,Color("e6b983") if due>0 else MINT);bill.position=Vector2(80,66);widget.add_child(bill)
	var grid:=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",13);parent.add_child(grid)
	var names=["Properties","Contacts","Shop","Genetics","Messages","Rewards","Leaderboard","Stats","Heat"]
	var apps=["realestate","clients","shop","genetics","texts","task","leaderboard","stats","heat"]
	var colors=["416c51","486a7d","79603e","536c38","386557","806331","65516e","416477","784c3f"]
	for i in range(names.size()):tile(grid,names[i],apps[i],colors[i],host._open_phone_app.bind(apps[i]))
	var dock:=HBoxContainer.new();dock.add_theme_constant_override("separation",5);parent.add_child(dock)
	for spec in [["Help","help"],["Settings","settings"],["Save & Session","system"]]:
		var item:=Button.new();item.text=spec[0];item.add_theme_stylebox_override("normal",box(Color("1b2b21"),16,Color("314537"),8));item.custom_minimum_size.y=58;item.size_flags_horizontal=Control.SIZE_EXPAND_FILL;item.add_theme_font_size_override("font_size",13);item.pressed.connect(host._open_phone_app.bind(spec[1]));dock.add_child(item)
	var balance:=label("$%d   ·   Day %d   ·   Grower %d" % [host.cash,host.game_day,host.grower_level],13,MUTED);balance.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;parent.add_child(balance)

static func polish(node:Node) -> void:
	if node.has_meta("phone_visual"):return
	for child in node.get_children():
		if child is Control:
			child.custom_minimum_size.x=0
			if child is Label:
				child.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
				child.add_theme_font_size_override("font_size",mini(20,child.get_theme_font_size("font_size")))
			elif child is Button:
				child.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
				child.add_theme_font_size_override("font_size",14)
				child.custom_minimum_size.y=maxf(48,child.custom_minimum_size.y)
				child.add_theme_stylebox_override("normal",box(Color("1c2c22")))
				child.add_theme_stylebox_override("hover",box(Color("2b4232"),16,MINT))
				child.add_theme_stylebox_override("pressed",box(Color("35553e"),16,MINT))
				child.add_theme_stylebox_override("focus",box(Color(0,0,0,0),16,MINT))
		polish(child)

static func row(parent:VBoxContainer, text:String, action:Callable, disabled:bool=false) -> Button:
	var button:=Button.new();button.text=text;button.disabled=disabled;button.set_meta("phone_visual",true)
	button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y=76;button.pressed.connect(action);parent.add_child(button)
	button.add_theme_stylebox_override("normal",box(Color("192a20"),16))
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]:button.add_theme_color_override(state,Color.TRANSPARENT)
	var content:=HBoxContainer.new();content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);content.offset_left=14;content.offset_right=-14;content.offset_top=12;content.offset_bottom=-12;content.add_theme_constant_override("separation",12);content.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(content)
	var picture:=TextureRect.new();picture.texture=icon("Contacts" if "EMPLOYEE" in text or "CREW" in text else ("Stats" if "BILL" in text or "PAY" in text else "Properties"),"a4e3b3");picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.custom_minimum_size=Vector2(26,26);picture.size_flags_horizontal=Control.SIZE_SHRINK_CENTER;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(picture)
	var details:=VBoxContainer.new();details.size_flags_horizontal=Control.SIZE_EXPAND_FILL;details.mouse_filter=Control.MOUSE_FILTER_IGNORE;details.alignment=BoxContainer.ALIGNMENT_CENTER;content.add_child(details)
	var parts:=text.replace(" · ","\n").split("\n",false,1)
	var title:=label(parts[0].capitalize(),14);title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;details.add_child(title)
	if parts.size()>1:
		var sub:=label(parts[1],13,MUTED);sub.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;details.add_child(sub)
	content.add_child(label("›",22,MUTED))
	if disabled:content.modulate.a=0.4
	return button
