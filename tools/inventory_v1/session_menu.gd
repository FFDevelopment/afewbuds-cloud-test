extends Node
var host:Node
var inventory:Node
var panel:PanelContainer
var scroll:ScrollContainer
var body:VBoxContainer
var page:="home"
var quitting:=false
func setup(owner:Node,controller:Node) -> void:
 host=owner;inventory=controller
 var old:Node=host.pause_overlay.get_child(0)
 host.pause_message.get_parent().remove_child(host.pause_message)
 host.pause_overlay.remove_child(old);old.queue_free()
 panel=PanelContainer.new();host.pause_overlay.add_child(panel)
 panel.add_theme_stylebox_override("panel",inventory.ui_style("111c17","689c50",18))
 scroll=load("res://scripts/touch_scroll.gd").new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true
 panel.add_child(scroll)
 body=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",12);scroll.add_child(body)
 show_page("home")
func show_page(next:String) -> void:
 page=next
 if host.pause_message.get_parent()!=null:host.pause_message.get_parent().remove_child(host.pause_message)
 for child in body.get_children():body.remove_child(child);child.queue_free()
 inventory.label("AFewBuds" if page=="home" else page.to_upper(),body,26)
 if page=="home":
  body.add_child(host.pause_message);host.pause_message.add_theme_font_size_override("font_size",16)
  inventory.button("RESUME GAME",host._resume_gameplay,body,true)
  inventory.button("SETTINGS",func():show_page("settings"),body)
  inventory.button("HELP",func():show_page("help"),body)
  inventory.button("SAVE & QUIT",host._phone_safe_quit,body)
 elif page=="settings":
  inventory.button("BACK",func():show_page("home"),body)
  inventory.button("ACCOUNT SETTINGS",host._open_web_account_settings,body)
  var input:Node=get_tree().root.get_node_or_null("DesktopInput")
  if input!=null:inventory.button("CONTROLS & DISPLAY",input.show_settings,body)
  inventory.label("Your career saves automatically. Account changes keep your progress attached to your account.",body,17)
 elif page=="help":
  inventory.button("BACK",func():show_page("home"),body)
  inventory.guide.populate_help(body)
 scroll.scroll_vertical=0
func _process(_delta:float) -> void:
 if not host.pause_overlay.visible:return
 for button in body.find_children("*","Button",true,false):button.disabled=quitting
 var size:Vector2=host.get_viewport().get_visible_rect().size
 var factor:float=maxf(1.0,size.x/maxf(1.0,host.get_window().size.x))
 panel.scale=Vector2.ONE*factor
 panel.size=Vector2(minf(540,size.x/factor-24),minf(660,size.y/factor-32))
 panel.position=(size-panel.size*factor)/2
func _input(event:InputEvent) -> void:
 if host.pause_overlay.visible and (event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton or event is InputEventMouseMotion):
  if (scroll.is_gesture_busy() or host._pointer_in_control(scroll,event.position)) and scroll.handle_pointer(event):get_viewport().set_input_as_handled()
func quit_failed(message:String) -> void:
 quitting=false;host.pause_message.text=message;show_page("home")
func quit_saved() -> void:
 if OS.has_feature("web"):
  host.pause_message.text="GAME SAVED\nYou can safely close this tab, or choose Resume to keep playing."
  quitting=false;show_page("home")
  JavaScriptBridge.eval("window.close();",true)
 else:get_tree().quit()
