extends CanvasLayer
## Opt-in character editor; a separate camera previews the same modular rig.
## Only Save commits appearance into location_state.player_avatar_v1.
const Catalog=preload("res://scripts/avatar_catalog.gd")
const Visual=preload("res://scripts/avatar_visual.gd")
var host:Node3D
var menu:Node
var draft:Dictionary={}
var overlay:Control
var layout:GridContainer
var preview_image:SubViewportContainer
var preview_viewport:SubViewport
var preview_model:Node3D
var camera:Camera3D
var tabs:TabContainer
var message:Label
var zoom:float=3.1
var title:Label
func _ready()->void:
 layer=125
 visible=false
func open(owner:Node3D,source_menu:Node)->void:
 host=owner
 menu=source_menu
 var stored:Variant=host.location_state.get("player_avatar_v1",{})
 var record:Dictionary=Catalog.record_from(stored)
 draft=Catalog.sanitize(record.get("appearance",{}))
 if overlay==null:
  if DisplayServer.get_name()=="headless":
   # Renderer-owned SubViewport textures and ColorPicker popups leak on
   # Godot's dummy GPU. CI tests schema, rigging and Save/Cancel instead.
   preview_model=Visual.new()
   add_child(preview_model)
   camera=Camera3D.new()
   camera.current=false
   add_child(camera)
  else:_build()
 elif tabs!=null:_rebuild_editors()
 visible=true
 if preview_viewport!=null:
  preview_viewport.disable_3d=false
  preview_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
  if camera!=null:camera.make_current()
 zoom=3.1
 _update_camera()
 _update_layout()
 if message!=null:message.text="Changes are a preview until you save. No gameplay stats or NPCs are changed."
func _build()->void:
 overlay=Control.new()
 overlay.name="CharacterEditorOverlay"
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.mouse_filter=Control.MOUSE_FILTER_STOP
 add_child(overlay)
 var background:=ColorRect.new()
 background.color=Color("09110f")
 background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.add_child(background)
 var margin:=MarginContainer.new()
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 margin.add_theme_constant_override("margin_left",14)
 margin.add_theme_constant_override("margin_right",14)
 margin.add_theme_constant_override("margin_top",12)
 margin.add_theme_constant_override("margin_bottom",12)
 overlay.add_child(margin)
 var column:=VBoxContainer.new()
 column.add_theme_constant_override("separation",8)
 margin.add_child(column)
 var heading:=HBoxContainer.new()
 heading.add_theme_constant_override("separation",8)
 column.add_child(heading)
 title=Label.new()
 title.text="AFB · CHARACTER"
 title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 title.add_theme_font_size_override("font_size",22)
 heading.add_child(title)
 var cancel:=_button("CANCEL",_cancel)
 cancel.custom_minimum_size=Vector2(80,46)
 heading.add_child(cancel)
 var save:=_button("SAVE LOOK",_save)
 save.custom_minimum_size=Vector2(111,46)
 heading.add_child(save)
 message=Label.new()
 message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 message.add_theme_font_size_override("font_size",13)
 column.add_child(message)
 var outer_scroll:=ScrollContainer.new()
 outer_scroll.name="CharacterEditorScroll"
 outer_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 outer_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
 column.add_child(outer_scroll)
 layout=GridContainer.new()
 layout.columns=2
 layout.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 layout.add_theme_constant_override("h_separation",16)
 layout.add_theme_constant_override("v_separation",12)
 outer_scroll.add_child(layout)
 var left:=VBoxContainer.new()
 left.name="CharacterPreviewControls"
 left.add_theme_constant_override("separation",9)
 layout.add_child(left)
 # SubViewportContainer presents the live 3D image directly. A TextureRect
 # hosting its own SubViewportTexture could show an empty panel on WebGL/iOS.
 preview_image=SubViewportContainer.new()
 preview_image.name="CharacterPreview"
 preview_image.custom_minimum_size=Vector2(360,440)
 preview_image.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 preview_image.stretch=true
 preview_image.mouse_filter=Control.MOUSE_FILTER_STOP
 preview_image.gui_input.connect(_preview_input)
 left.add_child(preview_image)
 preview_viewport=SubViewport.new()
 preview_viewport.name="AvatarPreviewViewport"
 preview_viewport.size=Vector2i(384,480)
 preview_viewport.own_world_3d=true
 preview_viewport.transparent_bg=false
 preview_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED if DisplayServer.get_name()=="headless" else SubViewport.UPDATE_ALWAYS
 preview_image.add_child(preview_viewport)
 var stage:=Node3D.new()
 preview_viewport.add_child(stage)
 var world:=WorldEnvironment.new()
 var env:=Environment.new()
 env.background_mode=Environment.BG_COLOR
 env.background_color=Color("17241f")
 env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color=Color("c5e2d4")
 env.ambient_light_energy=.7
 world.environment=env
 stage.add_child(world)
 var key_light:=DirectionalLight3D.new()
 key_light.rotation_degrees=Vector3(-40,-28,0)
 key_light.light_energy=1.2
 stage.add_child(key_light)
 var fill:=DirectionalLight3D.new()
 fill.rotation_degrees=Vector3(-12,145,0)
 fill.light_energy=.35
 stage.add_child(fill)
 var floor:=MeshInstance3D.new()
 var ground:=CylinderMesh.new()
 ground.top_radius=.75
 ground.bottom_radius=.82
 ground.height=.08
 floor.mesh=ground
 floor.position=Vector3(0,-.08,0)
 var ground_mat:=StandardMaterial3D.new()
 ground_mat.albedo_color=Color("365548")
 floor.material_override=ground_mat
 stage.add_child(floor)
 preview_model=Visual.new()
 preview_model.name="PlayerPreview"
 stage.add_child(preview_model)
 camera=Camera3D.new()
 camera.fov=37
 camera.current=true
 stage.add_child(camera)
 _update_camera()
 call_deferred("_update_camera")
 var controls:=HBoxContainer.new()
 left.add_child(controls)
 controls.add_child(_button("◀ ROTATE",_rotate.bind(-PI/5.0)))
 controls.add_child(_button("ROTATE ▶",_rotate.bind(PI/5.0)))
 controls.add_child(_button("− ZOOM",_zoom.bind(.3)))
 controls.add_child(_button("+ ZOOM",_zoom.bind(-.3)))
 var motion:=HBoxContainer.new()
 left.add_child(motion)
 motion.add_child(_button("IDLE",_play.bind("idle")))
 motion.add_child(_button("WALK",_play.bind("walk")))
 var note:=Label.new()
 note.text="Drag your character to rotate. Wheel to zoom. Clothing fits the shared 56-bone rig."
 note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 left.add_child(note)
 tabs=TabContainer.new()
 tabs.name="AppearanceTabs"
 tabs.custom_minimum_size=Vector2(340,480)
 tabs.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 layout.add_child(tabs)
 _rebuild_editors()
 get_viewport().size_changed.connect(_update_layout)
func _button(label:String,callback:Callable)->Button:
 var button:=Button.new()
 button.text=label
 button.custom_minimum_size.y=46
 button.pressed.connect(callback)
 return button
func _tab(label:String)->VBoxContainer:
 var scroll:=ScrollContainer.new()
 scroll.name=label
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
 tabs.add_child(scroll)
 var column:=VBoxContainer.new()
 column.add_theme_constant_override("separation",12)
 column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 scroll.add_child(column)
 return column
func _row(parent:VBoxContainer,label:String)->HBoxContainer:
 var row:=HBoxContainer.new()
 row.add_theme_constant_override("separation",12)
 parent.add_child(row)
 var name_label:=Label.new()
 name_label.text=label
 name_label.custom_minimum_size.x=105
 row.add_child(name_label)
 return row
func _choice(parent:VBoxContainer,key:String,label:String)->void:
 var row:=_row(parent,label)
 var chooser:=OptionButton.new()
 chooser.name="Avatar_"+key
 chooser.custom_minimum_size.y=48
 chooser.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var options:Array=Catalog.OPTIONS[key]
 for id in options:chooser.add_item(Catalog.label_for(key,str(id)))
 chooser.select(maxi(0,options.find(str(draft[key]))))
 chooser.item_selected.connect(_choose.bind(key))
 row.add_child(chooser)
func _color(parent:VBoxContainer,key:String,label:String)->void:
 var row:=_row(parent,label)
 var picker:=ColorPickerButton.new()
 picker.name="Avatar_"+key
 picker.edit_alpha=false
 picker.custom_minimum_size=Vector2(116,46)
 picker.color=Color("#"+str(draft[key]))
 picker.color_changed.connect(_change_color.bind(key))
 row.add_child(picker)
func _rebuild_editors()->void:
 if tabs==null:return
 for child in tabs.get_children():
  tabs.remove_child(child)
  child.queue_free()
 var body:=_tab("Body")
 _choice(body,"body","Body fit")
 _choice(body,"face","Face")
 _color(body,"skin_color","Skin")
 _color(body,"eye_color","Eyes")
 var tones:=Label.new()
 tones.text="Skin presets"
 body.add_child(tones)
 var swatches:=GridContainer.new()
 swatches.columns=5
 body.add_child(swatches)
 for hex_color in Catalog.SKIN_SWATCHES:
  var sample:=_button("●",_skin_preset.bind(str(hex_color)))
  sample.custom_minimum_size=Vector2(48,48)
  sample.add_theme_color_override("font_color",Color("#"+str(hex_color)))
  swatches.add_child(sample)
 var hair:=_tab("Hair")
 _choice(hair,"hair","Hairstyle")
 _choice(hair,"beard","Facial hair")
 _color(hair,"hair_color","Hair color")
 var clothes:=_tab("Clothes")
 _choice(clothes,"top","Top")
 _choice(clothes,"outerwear","Jacket / coat")
 _choice(clothes,"bottom","Bottoms")
 _choice(clothes,"shoes","Shoes")
 _color(clothes,"top_color","Top dye")
 _color(clothes,"outerwear_color","Jacket dye")
 _color(clothes,"bottom_color","Bottom dye")
 _color(clothes,"shoe_color","Shoe dye")
 var details:=_tab("Details")
 _choice(details,"headwear","Hat")
 _choice(details,"glasses","Glasses")
 _choice(details,"gloves","Gloves")
 _choice(details,"bag","Bag")
 _choice(details,"jewelry","Jewelry")
 _color(details,"headwear_color","Hat dye")
 _color(details,"bag_color","Bag dye")
 var reset:=_button("RESET UNSAVED PREVIEW",_reset)
 details.add_child(reset)
 _refresh_preview()
func _choose(index:int,key:String)->void:
 var items:Array=Catalog.OPTIONS.get(key,[])
 if index<0 or index>=items.size():return
 draft[key]=str(items[index])
 _refresh_preview()
func _change_color(value:Color,key:String)->void:
 draft[key]=value.to_html(false)
 _refresh_preview()
func _skin_preset(hex_color:String)->void:
 draft["skin_color"]=hex_color
 _rebuild_editors()
func _refresh_preview()->void:
 if preview_model!=null and is_instance_valid(preview_model):
  preview_model.rebuild(draft)
func _reset()->void:
 draft=Catalog.defaults()
 _rebuild_editors()
 message.text="Reset the preview. SAVE LOOK to keep these changes."
func _rotate(angle:float)->void:
 if preview_model!=null:preview_model.rotation.y+=angle
func _zoom(delta:float)->void:
 zoom=clampf(zoom+delta,2.15,4.5)
 _update_camera()
func _update_camera()->void:
 if camera==null:return
 # Frame the *actual imported rig*, not an assumed 1.22 m-high model.
 # Character assets can have different scene-root offsets/scales.
 var target:=Vector3(0,1.05,0)
 var height:float=1.85
 if preview_model!=null and preview_model.skeleton!=null:
  var sk:Skeleton3D=preview_model.skeleton
  var head:int=sk.find_bone("Head")
  var left_foot:int=sk.find_bone("Foot_L")
  if head>=0 and left_foot>=0:
   var head_at:Vector3=sk.to_global(sk.get_bone_global_pose(head).origin)
   var foot_at:Vector3=sk.to_global(sk.get_bone_global_pose(left_foot).origin)
   target=(head_at+foot_at)*.5
   target.y+=.04
   height=maxf(1.3,head_at.distance_to(foot_at))
 var distance:float=zoom*maxf(.85,height/1.85)
 camera.position=target+Vector3(.12,0,-distance)
 camera.look_at(target)
func _preview_input(event:InputEvent)->void:
 if event is InputEventMouseMotion:
  if (event.button_mask & MOUSE_BUTTON_MASK_LEFT)!=0:_rotate(event.relative.x*.01)
 elif event is InputEventScreenDrag:
  _rotate(event.relative.x*.012)
 elif event is InputEventMouseButton and event.pressed:
  if event.button_index==MOUSE_BUTTON_WHEEL_UP:_zoom(-.18)
  elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:_zoom(.18)
func _play(clip:String)->void:
 if preview_model!=null:preview_model.play_preview(clip)
func _update_layout()->void:
 if layout==null or preview_image==null:return
 var viewport_size:Vector2=get_viewport().get_visible_rect().size
 var wide:bool=viewport_size.x>=860.0
 layout.columns=2 if wide else 1
 var picture_width:float=minf(380.0,maxf(250.0,viewport_size.x-45.0))
 preview_image.custom_minimum_size=Vector2(picture_width,460 if wide else 280)
 tabs.custom_minimum_size=Vector2(355 if wide else picture_width,470 if wide else 400)
func _cancel()->void:
 _close()
func _close()->void:
 if preview_viewport!=null:
  preview_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 visible=false
 if menu!=null and menu.avatar_editor==self:menu.avatar_editor=null
 queue_free()
func _save()->void:
 if host==null or menu==null or menu.cloud_locked or menu.quitting:return
 var had_record:bool=host.location_state.has("player_avatar_v1")
 var previous:Variant=host.location_state.get("player_avatar_v1",{})
 var current_record:Dictionary=Catalog.record_from(previous)
 current_record["appearance"]=Catalog.sanitize(draft)
 current_record["created"]=true
 current_record["saved_at_unix"]=int(Time.get_unix_time_from_system())
 host.location_state["player_avatar_v1"]=current_record
 host._save_game()
 if not bool(host.last_save_ok):
  if had_record:host.location_state["player_avatar_v1"]=previous
  else:host.location_state.erase("player_avatar_v1")
  if message!=null:message.text="Could not save appearance on this device. The previous character was kept."
  return
 _close()
 menu.show_page("settings")
 host.pause_message.text="CHARACTER SAVED · Outfit follows this career on other devices after cloud sync."
func _unhandled_input(event:InputEvent)->void:
 if not visible:return
 if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
  _cancel()
  get_viewport().set_input_as_handled()
