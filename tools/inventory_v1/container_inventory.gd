extends Node
## Container inventory shared by desktop and mobile. Existing production counters
## are live adapters, so workers and sales cannot diverge from displayed stock.
var host:Node3D
var state:Dictionary
var layer:CanvasLayer
var overlay:ColorRect
var panel:PanelContainer
var columns:BoxContainer
var preview_note:Label
var heading:Label
var notice:Label
var footer:BoxContainer
var quantity:SpinBox
var confirm:Button
var backpack_button:Button
var nearby_button:Button
var container_id:=""
var adding:=false
var selected:=""
var selected_source:=""
var revision:=0
var selected_revision:=-1
var busy:=false
var resume_container:=""
const KINDS:=["supply","storage","dealer","packing"]
const POSITIONS:={
 "apartment:supply":Vector3(-4.05,1.25,-6.45),
 "apartment:storage":Vector3(-3.95,1.3,-.06),
 "apartment:dealer":Vector3(3.95,1.3,-2.2),
 "apartment:packing":Vector3(3.25,1.35,.78),
 "house:supply":Vector3(43.82,1.3,-9.1),
 "house:storage":Vector3(43.88,1.3,-3.2),
 "house:dealer":Vector3(38.0,1.3,-3.73),
 "house:packing":Vector3(41.2,1.3,-3.58)}

func setup(owner:Node3D) -> void:
 host=owner
 ensure_state()
 build_ui()
 host.get_viewport().size_changed.connect(resize)
 # Label the house's containers so each has a distinct physical interaction.
 for id in POSITIONS:
  if not id.begins_with("house:"):continue
  var marker:=Label3D.new()
  marker.text=title(id);marker.font_size=30;marker.pixel_size=.007
  marker.position=POSITIONS[id]+Vector3(0,.65,0);marker.rotation.y=-PI/2
  marker.billboard=BaseMaterial3D.BILLBOARD_ENABLED
  marker.modulate=Color("cee5b4");marker.outline_size=8
  host.neighborhood.add_child(marker)

func ensure_state() -> void:
 if not host.location_state.get("container_inventory",{}) is Dictionary:host.location_state["container_inventory"]={}
 if not host.location_state.has("container_inventory"):host.location_state["container_inventory"]={}
 state=host.location_state.container_inventory
 if not state.get("backpack",{}) is Dictionary:state["backpack"]={}
 if not state.has("backpack"):state["backpack"]={}
 if not state.get("containers",{}) is Dictionary:state["containers"]={}
 if not state.has("containers"):state["containers"]={}
 state["schema"]=1
 for property in ["apartment","house"]:
  for kind in KINDS:
   var id:String=property+":"+kind
   if not state.containers.get(id,{}) is Dictionary:state.containers[id]={}
   if not state.containers.has(id):state.containers[id]={}
 # No destructive migration: legacy shelf, stock, pipeline and carried fields
 # remain authoritative adapters. Already-owned equipment is retained as-is.

func operation() -> String:return str(host.location_state.get("operation_contents_property","apartment"))
func title(id:String) -> String:
 if id=="backpack":return "BACKPACK"
 return id.get_slice(":",0).capitalize()+" · "+str({"supply":"Grow Shelf","storage":"Storage / Stash","dealer":"Dealer Storage","packing":"Packing Bench"}.get(id.get_slice(":",1),"Storage"))
func category(item:String) -> String:return item.get_slice("|",0)
func item_name(item:String) -> String:
 if item=="cash":return "Cash"
 if item=="fertilizer":return "Fertilizer"
 return item.get_slice("|",1)+str({"seed":" · Seeds","raw":" · Untrimmed","trimmed":" · Trimmed","product":" · Packaged","equipment":" · Packed equipment"}.get(category(item),""))
func units(item:String,n:int) -> String:
 if item=="cash":return "$%d" % n
 return "%dg" % n if category(item) in ["raw","trimmed","product"] else "%d" % n
func _append_map(dst:Dictionary,src:Dictionary,prefix:String) -> void:
 for key in src:
  if int(src[key])>0:dst[prefix+"|"+str(key)]=int(src[key])
func contents(id:String) -> Dictionary:
 ensure_state()
 var result:Dictionary={}
 if id=="backpack":
  result=state.backpack.duplicate(true)
  _append_map(result,host.location_state.get("carried_seeds",{}),"seed")
  if int(host.location_state.get("carried_fertilizer",0))>0:result.fertilizer=int(host.location_state.carried_fertilizer)
  result.cash=host.cash
  for asset in host.location_state.get("property_storage",[]):
   var key:String="equipment|"+str(asset)
   result[key]=int(result.get(key,0))+1
  return result
 if not state.containers.has(id):return result
 result=state.containers[id].duplicate(true)
 if id.get_slice(":",0)!=operation():return result
 match id.get_slice(":",1):
  "supply":
   _append_map(result,host.seed_inventory,"seed")
   if host.fertilizer_units>0:result.fertilizer=host.fertilizer_units
  "storage":
   for key in host.products:
    if int(host.products[key].get("stock",0))>0:result["product|"+str(key)]=int(host.products[key].stock)
  "dealer":_append_map(result,host.locker_weed,"product")
  "packing":
   _append_map(result,host.untrimmed_inventory,"raw")
   _append_map(result,host.trimmed_inventory,"trimmed")
   _append_map(result,host.bagged_inventory,"product")
 return result
func set_amount(id:String,item:String,n:int) -> void:
 var kind:=category(item)
 var name:=item.get_slice("|",1)
 n=maxi(0,n)
 if id=="backpack":
  if kind=="seed":host.location_state.carried_seeds[name]=n;return
  if item=="fertilizer":host.location_state.carried_fertilizer=n;return
  if item=="cash":host.cash=n;return
  if kind=="equipment":
   var assets:Array=host.location_state.get("property_storage",[])
   while assets.has(name):assets.erase(name)
   for i in n:assets.append(name)
   host.location_state.property_storage=assets;return
  if n==0:state.backpack.erase(item)
  else:state.backpack[item]=n
  return
 if id.get_slice(":",0)==operation():
  match id.get_slice(":",1):
   "supply":
    if kind=="seed":host.seed_inventory[name]=n;return
    if item=="fertilizer":host.fertilizer_units=n;return
   "storage":
    if kind=="product":host._ensure_product_exists(name);host.products[name].stock=n;return
   "dealer":
    if kind=="product":host.locker_weed[name]=n;return
   "packing":
    if kind=="raw":host.untrimmed_inventory[name]=n;return
    if kind=="trimmed":host.trimmed_inventory[name]=n;return
    if kind=="product":host.bagged_inventory[name]=n;return
 if n==0:state.containers[id].erase(item)
 else:state.containers[id][item]=n
func group(item:String) -> String:
 if category(item) in ["product","raw","trimmed"]:return "grams"
 if category(item)=="seed":return "seeds"
 if category(item)=="equipment":return "equipment"
 return item
func accepts(id:String,item:String) -> bool:
 if id=="backpack":return true
 var kind:=id.get_slice(":",1)
 if kind=="supply":return group(item) in ["seeds","fertilizer"]
 if kind=="dealer":return category(item)=="product"
 if kind=="packing":return group(item)=="grams"
 return kind=="storage" and (category(item)=="product" or item=="cash" or category(item)=="equipment")
func capacity(id:String,item:String) -> int:
 if item=="cash":return 2000000000
 var key:=group(item)
 if id=="backpack":return int({"seeds":50,"fertilizer":50,"grams":200,"equipment":12}.get(key,0))
 match id.get_slice(":",1):
  "supply":return host._supply_seed_capacity() if key=="seeds" else host._supply_fertilizer_capacity()
  "dealer":return host._dealer_locker_capacity()
  "storage":return 12 if key=="equipment" else host._storage_capacity()
  "packing":return 2000
 return 0
func free_space(id:String,item:String) -> int:
 if not accepts(id,item):return 0
 var used:=0
 var items:=contents(id)
 for key in items:
  if group(key)==group(item):used+=int(items[key])
 return maxi(0,capacity(id,item)-used)
func available(id:String,item:String) -> int:
 var value:int=int(contents(id).get(item,0))
 if id==operation()+":storage" and category(item)=="product":
  value=mini(value,host._available_amount(item.get_slice("|",1)))
 return maxi(0,value)
func controlled(id:String) -> bool:
 if id=="backpack":return true
 return host.neighborhood.location_ops._property_controlled(id.get_slice(":",0))
func reachable(id:String) -> bool:
 if not POSITIONS.has(id) or not controlled(id):return false
 var position:Vector3=host.camera.global_position
 if host.neighborhood.get("in_station")==true:position=host.neighborhood.walk_position
 return position.distance_to(POSITIONS[id])<=3.1
func near_container() -> String:
 var best:=""
 var distance:=3.1
 for id in POSITIONS:
  if not controlled(id):continue
  if id.ends_with(":dealer") and host.dealer_locker_level==0:continue
  var delta:Vector3=POSITIONS[id]-host.camera.global_position
  if delta.length()<distance and (-host.camera.global_basis.z).dot(delta.normalized())>.65:
   if host.neighborhood.has_method("_door_line_clear") and not host.neighborhood._door_line_clear(POSITIONS[id]):continue
   best=id;distance=delta.length()
 return best
func transfer(source:String,destination:String,item:String,amount:int,expected_revision:int=-1) -> Dictionary:
 if busy:return {"ok":false,"reason":"Transfer already in progress."}
 if expected_revision>=0 and expected_revision!=revision:return {"ok":false,"reason":"Inventory changed. Select the item again."}
 if source==destination or amount<=0 or (source!="backpack" and destination!="backpack"):return {"ok":false,"reason":"Choose a backpack/container transfer."}
 var container:String=destination if source=="backpack" else source
 if not reachable(container):return {"ok":false,"reason":"Stand near this container to transfer items."}
 if not accepts(destination,item):return {"ok":false,"reason":"This container does not accept that item."}
 if amount>available(source,item):return {"ok":false,"reason":"Not enough available stock. Reserved orders stay in storage."}
 if amount>free_space(destination,item):return {"ok":false,"reason":"Not enough space for that amount."}
 busy=true
 var from_amount:int=int(contents(source).get(item,0))
 var to_amount:int=int(contents(destination).get(item,0))
 # No awaits between the debit and credit: both sides commit in one game tick.
 set_amount(source,item,from_amount-amount)
 set_amount(destination,item,to_amount+amount)
 revision+=1
 host._update_cash_ui()
 host._save_game()
 busy=false
 return {"ok":true,"reason":"%s %s." % ["Stored" if source=="backpack" else "Took",units(item,amount)]}
func property_has_items(property:String) -> bool:
 for kind in KINDS:
  for n in contents(property+":"+kind).values():
   if int(n)>0:return true
 return false
func relocate(old_property:String,new_property:String) -> void:
 # Fold destination stock into the operation before its owner changes.
 # This also preserves supplies previously left in a retained house container.
 ensure_state()
 for kind in KINDS:
  var old_id:String=old_property+":"+kind
  var new_id:String=new_property+":"+kind
  var merged:Dictionary=state.containers[new_id].duplicate(true)
  for item in state.containers[old_id]:merged[item]=int(merged.get(item,0))+int(state.containers[old_id][item])
  state.containers[old_id]={}
  state.containers[new_id]={}
  for item in merged:
   var native:bool=(kind=="supply" and group(item) in ["seeds","fertilizer"]) or (kind in ["storage","dealer"] and category(item)=="product") or (kind=="packing" and group(item)=="grams")
   if native:set_amount(old_id,item,int(contents(old_id).get(item,0))+int(merged[item]))
   else:state.containers[new_id][item]=merged[item]
 revision+=1
func is_open() -> bool:return overlay!=null and overlay.visible
func open_backpack() -> void:
 if host._any_modal_open() and not is_open():return
 container_id="";adding=false;selected="";selected_source=""
 overlay.show();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;render()
func open_container(kind:String) -> void:
 var id:String=kind if kind.contains(":") else ("house" if host.camera.position.x>25 else "apartment")+":"+kind
 if not reachable(id):host.status_label.text="Walk up to the "+title(id)+" to open it.";return
 if id.ends_with(":dealer") and host.dealer_locker_level==0:host.status_label.text="Unlock Dealer Storage first.";return
 container_id=id;adding=false;selected="";selected_source=""
 if id.ends_with(":storage") and host.storage_level>=5:host._set_hidden_stash_open(true)
 if id.ends_with(":dealer") and host.dealer_locker_level>=3:host._set_premium_dealer_locker_open(true)
 overlay.show();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;render()
func close() -> void:
 if container_id.ends_with(":storage") and host.storage_level>=5:host._set_hidden_stash_open(false)
 if container_id.ends_with(":dealer") and host.dealer_locker_level>=3:host._set_premium_dealer_locker_open(false)
 overlay.hide();selected="";container_id="";adding=false
 if host.get("fp_player")!=null and not host.session_paused:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func _unhandled_key_input(event:InputEvent) -> void:
 if not event is InputEventKey or not event.pressed or event.echo:return
 if event.physical_keycode==KEY_I:
  if is_open():close()
  else:open_backpack()
  get_viewport().set_input_as_handled()
 elif event.physical_keycode==KEY_ESCAPE and is_open():close();get_viewport().set_input_as_handled()
func pause_inventory() -> void:
 if is_open():
  resume_container=container_id if container_id.ends_with(":dealer") else ""
  close()
func resume_inventory() -> void:
 if not resume_container.is_empty():
  var reopening:=resume_container;resume_container="";open_container(reopening)
func _process(_delta:float) -> void:
 if host==null:return
 if is_open():_fit()
 var modal:bool=host._any_modal_open() or host.daily_report_pending or host.tutorial_active
 backpack_button.visible=not modal
 var nearby:String=near_container() if not modal else ""
 nearby_button.visible=not nearby.is_empty()
 if not nearby.is_empty():nearby_button.text="OPEN "+title(nearby).get_slice(" · ",1).to_upper()
 if is_open() and not container_id.is_empty() and not reachable(container_id):close()
func button(text:String,callback:Callable,parent:Node) -> Button:
 var b:=Button.new();b.text=text;b.custom_minimum_size.y=36 if host.get_viewport().get_visible_rect().size.y<500 else 48
 b.add_theme_font_size_override("font_size",18);b.pressed.connect(callback);parent.add_child(b);return b
func label(text:String,parent:Node,size:int=19) -> Label:
 var l:=Label.new();l.text=text;l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 l.add_theme_font_size_override("font_size",size);parent.add_child(l);return l
func build_ui() -> void:
 layer=CanvasLayer.new();layer.layer=35;add_child(layer)
 var hud:=Control.new();hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(hud)
 backpack_button=button("BACKPACK  [I]",open_backpack,hud)
 backpack_button.set_anchors_preset(Control.PRESET_TOP_RIGHT);backpack_button.offset_left=-218;backpack_button.offset_right=-22;backpack_button.offset_top=120;backpack_button.offset_bottom=172
 nearby_button=button("OPEN CONTAINER",func():open_container(near_container()),hud)
 nearby_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM);nearby_button.offset_left=-180;nearby_button.offset_right=180;nearby_button.offset_top=-210;nearby_button.offset_bottom=-156
 overlay=ColorRect.new();overlay.color=Color(.015,.025,.023,.88);overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(overlay)
 panel=PanelContainer.new();overlay.add_child(panel)
 var style:=StyleBoxFlat.new();style.bg_color=Color("15231f");style.border_color=Color("82a775");style.set_border_width_all(2);style.set_corner_radius_all(14)
 for edge in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:style.set_content_margin(edge,18)
 panel.add_theme_stylebox_override("panel",style)
 var root:=VBoxContainer.new();root.add_theme_constant_override("separation",6);panel.add_child(root)
 var top:=HBoxContainer.new();root.add_child(top)
 heading=label("INVENTORY",top,25);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 button("CLOSE",close,top)
 preview_note=label("INVENTORY TEST · Separate preview career",root,15)
 preview_note.modulate=Color("aec39f")
 columns=BoxContainer.new();columns.size_flags_vertical=Control.SIZE_EXPAND_FILL;columns.add_theme_constant_override("separation",12);root.add_child(columns)
 notice=label("",root,17)
 footer=BoxContainer.new();footer.add_theme_constant_override("separation",10);root.add_child(footer)
 label("Amount",footer).autowrap_mode=TextServer.AUTOWRAP_OFF
 quantity=SpinBox.new();quantity.min_value=1;quantity.max_value=1;quantity.step=1;quantity.custom_minimum_size=Vector2(130,48);footer.add_child(quantity)
 button("MAX",func():quantity.value=quantity.max_value,footer)
 confirm=button("SELECT AN ITEM",commit_selection,footer);confirm.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 overlay.hide();resize()
func resize() -> void:
 if panel==null:return
 var screen:Vector2=host.get_viewport().get_visible_rect().size
 var width:float=minf(1140,screen.x-32)
 var height:float=minf(900,screen.y-40)
 panel.position=(screen-Vector2(width,height))/2
 panel.size=Vector2(width,height)
 if is_open():render()
func _fit() -> void:
 var screen:Vector2=host.get_viewport().get_visible_rect().size
 var compact:bool=screen.y<500
 preview_note.visible=not compact
 var style:StyleBoxFlat=panel.get_theme_stylebox("panel")
 for edge in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
  if style.get_content_margin(edge)!=(12 if compact else 18):style.set_content_margin(edge,12 if compact else 18)
 var top:Node=heading.get_parent()
 top.get_child(1).custom_minimum_size.y=36 if compact else 48
 quantity.custom_minimum_size.y=36 if compact else 48
 confirm.custom_minimum_size.y=36 if compact else 48
 footer.get_child(2).custom_minimum_size.y=36 if compact else 48
 panel.size=Vector2(minf(1140,screen.x-32),minf(900,screen.y-40))
 panel.position=(screen-panel.size)/2
func clear(node:Node) -> void:
 for child in node.get_children():node.remove_child(child);child.queue_free()
func select_item(source:String,item:String) -> void:
 selected=item;selected_source=source;selected_revision=revision
 render()
func render() -> void:
 clear(columns)
 var screen:Vector2=host.get_viewport().get_visible_rect().size
 columns.vertical=screen.y>screen.x
 footer.vertical=false
 footer.get_child(0).visible=screen.x>=640
 quantity.custom_minimum_size.x=90 if screen.x<640 else 130
 _fit.call_deferred()
 heading.text="BACKPACK" if container_id.is_empty() else title(container_id)
 if container_id.is_empty():render_inventory("backpack")
 else:
  render_inventory(container_id)
  if adding:render_inventory("backpack")
 footer.visible=not container_id.is_empty()
 confirm.disabled=selected.is_empty()
 if not selected.is_empty() and not container_id.is_empty():
  var dst:String=container_id if selected_source=="backpack" else "backpack"
  var maximum:int=mini(available(selected_source,selected),free_space(dst,selected))
  quantity.max_value=maxi(1,maximum);quantity.value=clampf(quantity.value,1,quantity.max_value)
  confirm.disabled=maximum<=0
  confirm.text="STORE" if selected_source=="backpack" else "TAKE"
  notice.text=item_name(selected)+(" · Not compatible / no space" if maximum<=0 else " · Choose amount to "+confirm.text.to_lower())
 else:
  confirm.text="SELECT AN ITEM"
  notice.text="Carried items travel with you. Open a physical container to store items." if container_id.is_empty() else "Select an item to take it, or choose Add Stock to open your backpack."
func render_inventory(id:String) -> void:
 var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.size_flags_vertical=Control.SIZE_EXPAND_FILL;columns.add_child(column)
 label(title(id),column,22)
 var items:=contents(id)
 var count:=0
 for key in items:
  if int(items[key])>0:count+=1
 var totals:Dictionary={}
 for item in items:totals[group(item)]=int(totals.get(group(item),0))+int(items[item])
 var detail:String="%d item types" % count
 if id.ends_with(":supply") or id=="backpack":detail+=" · Seeds %d/%d · Fertilizer %d/%d" % [int(totals.get("seeds",0)),capacity(id,"seed|sample"),int(totals.get("fertilizer",0)),capacity(id,"fertilizer")]
 else:detail+=" · Product %dg/%dg" % [int(totals.get("grams",0)),capacity(id,"product|sample")]
 label(detail,column,16).modulate=Color("bac9b3")
 if id!="backpack":
  button("HIDE BACKPACK" if adding else "ADD STOCK",func():adding=not adding;selected="";render(),column)
 var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(scroll)
 var grid:=GridContainer.new();grid.columns=2;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",8);scroll.add_child(grid)
 var keys:Array=items.keys();keys.sort_custom(func(a,b):
  if id=="backpack" and not container_id.is_empty() and accepts(container_id,a)!=accepts(container_id,b):return accepts(container_id,a)
  return str(a)<str(b))
 for item in keys:
  if int(items[item])<=0:continue
  var card:=Button.new();card.custom_minimum_size=Vector2(0,94);card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  card.text=(item.get_slice("|",1) if item.contains("|") else item_name(item))+"\n"+units(item,int(items[item]))
  if category(item)=="seed":card.text+=" seeds"
  elif category(item) in ["raw","trimmed","product"]:card.text+=" · "+str({"raw":"Untrimmed","trimmed":"Trimmed","product":"Packaged"}[category(item)])
  card.tooltip_text=item_name(item)
  card.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;card.add_theme_font_size_override("font_size",17)
  var icon_name:String={"seed":"seed","fertilizer":"fertilizer","raw":"bud","trimmed":"bud","product":"bag","equipment":"storage","cash":"jar"}.get(category(item),"storage")
  card.icon=host._load_item_icon(icon_name);card.expand_icon=true;card.add_theme_constant_override("icon_max_width",32)
  card.toggle_mode=true;card.button_pressed=selected==item and selected_source==id
  if id=="backpack" and not container_id.is_empty() and not accepts(container_id,item):card.text+="\nNot accepted here";card.disabled=true
  if id=="backpack" and container_id.is_empty():card.disabled=true
  card.pressed.connect(select_item.bind(id,item));grid.add_child(card)
 if count==0:label("This inventory is empty.",grid)
func commit_selection() -> void:
 if selected.is_empty() or container_id.is_empty():return
 var dst:String=container_id if selected_source=="backpack" else "backpack"
 var result:=transfer(selected_source,dst,selected,int(quantity.value),selected_revision)
 selected="";selected_source="";render();notice.text=str(result.reason)
