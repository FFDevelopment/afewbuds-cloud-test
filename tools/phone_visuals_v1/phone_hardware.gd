extends Node2D
# Device-local sound preference; never changes a player's shared career.
const PATH := "user://phone_audio.cfg"
var owner_ref:WeakRef
var level:int=70
var readout:Label
var dismiss:Timer
func setup(host:Node) -> void:
	owner_ref=weakref(host)
	var config:=ConfigFile.new()
	if config.load(PATH)==OK:level=clampi(int(config.get_value("phone","ring_volume",70)),0,100)
	_add_key("+",Vector2(-18,165),Vector2(28,58),"Ring volume up",change_volume.bind(10))
	_add_key("−",Vector2(-18,229),Vector2(28,58),"Ring volume down",change_volume.bind(-10))
	_add_key("",Vector2(preload("res://scripts/phone_visuals.gd").SIZE.x-10,182),Vector2(28,76),"Power: close phone",power)
	readout=Label.new();readout.position=Vector2((preload("res://scripts/phone_visuals.gd").SIZE.x-246)*0.5,53);readout.size=Vector2(246,34)
	readout.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	readout.add_theme_font_size_override("font_size",13)
	readout.add_theme_stylebox_override("normal",preload("res://scripts/phone_visuals.gd").box(Color("29332f"),12,Color("bfc5cc"),6))
	readout.mouse_filter=Control.MOUSE_FILTER_IGNORE;readout.hide();add_child(readout)
	dismiss=Timer.new();dismiss.one_shot=true;dismiss.wait_time=1.8;dismiss.timeout.connect(readout.hide);add_child(dismiss)
	apply_volume.call_deferred()
func _add_key(caption:String,at:Vector2,dimensions:Vector2,hint:String,action:Callable) -> void:
	var button:=Button.new();button.name="Power" if caption.is_empty() else ("VolumeUp" if caption=="+" else "VolumeDown")
	button.position=at;button.size=dimensions;button.text=caption;button.tooltip_text=hint
	button.add_theme_font_size_override("font_size",9)
	for state in ["normal","hover","pressed","focus"]:
		var style:=StyleBoxFlat.new();style.bg_color=Color("848e9b") if state=="normal" else Color("c3ceda");style.border_color=Color("e5e8ed");style.set_border_width_all(1);style.set_corner_radius_all(3);style.expand_margin_left=-10;style.expand_margin_right=-10
		style.content_margin_left=0;style.content_margin_right=0;style.content_margin_top=0;style.content_margin_bottom=0
		button.add_theme_stylebox_override(state,style)
	button.add_theme_color_override("font_color",Color("18212a"));button.pressed.connect(action);add_child(button)
func power() -> void:
	var host=owner_ref.get_ref()
	if host!=null and host.phone_open:host._toggle_phone()
func change_volume(amount:int) -> void:
	level=clampi(level+amount,0,100)
	apply_volume()
	var config:=ConfigFile.new();config.set_value("phone","ring_volume",level);config.save(PATH)
	readout.text="Ringer muted" if level==0 else "Ring volume  %d%%" % level
	readout.show();dismiss.start()
	var host=owner_ref.get_ref()
	if level>0 and host!=null and host.neighborhood!=null and host.neighborhood.text_player!=null:host.neighborhood.text_player.play()
func apply_volume() -> void:
	var host=owner_ref.get_ref()
	if host==null or host.neighborhood==null or host.neighborhood.text_player==null:return
	# Preserve the existing -14 dB ding at the default 70%; door knocks stay physical.
	host.neighborhood.text_player.volume_db=-80.0 if level==0 else -14.0+linear_to_db(float(level)/70.0)
