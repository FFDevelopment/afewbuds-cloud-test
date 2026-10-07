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
var art_cache:Dictionary={}
var filter_kind:="All"
var filter_bar:HBoxContainer
var body_layout:BoxContainer
var inspector:PanelContainer
var back_button:Button
var close_button:Button
var quantity_strip:HBoxContainer
var transfer_preview:Label
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
var packing_return:=""
var packing_action:Button
# Integer weight units preserve 1g of product exactly. One unit is 0.00001g.
const POUND:=45359237
const GRAM:=100000
const BACKPACK_LIMITS:=[35*POUND,55*POUND,80*POUND,110*POUND]
const BACKPACK_PRICES:=[250,750,1750]
const KINDS:=["supply","storage","dealer","packing"]
const POSITIONS:={
 "market:orders":Vector3(14,1.3,3),
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
 process_priority=50
 ensure_state()
 build_ui()
 if host.neighborhood.get("action")!=null:style_button(host.neighborhood.action,true)
 for work_panel in [host.trim_panel,host.bag_minigame_panel]:
  work_panel.add_theme_stylebox_override("panel",ui_style("111713","566052",16))
  for action in work_panel.find_children("*","Button",true,false):style_button(action,true)
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
 state["schema"]=2
 state["backpack_level"]=clampi(int(state.get("backpack_level",1)),1,BACKPACK_LIMITS.size())
 for property in ["apartment","house"]:
  for kind in KINDS:
   var id:String=property+":"+kind
   if not state.containers.get(id,{}) is Dictionary:state.containers[id]={}
   if not state.containers.has(id):state.containers[id]={}
 # No destructive migration: legacy shelf, stock, pipeline and carried fields
 # remain authoritative adapters. Already-owned equipment is retained as-is.

func operation() -> String:return str(host.location_state.get("operation_contents_property","apartment"))
func title(id:String) -> String:
 if id=="market:orders":return "Central Market · Order Pickup"
 if id=="backpack":return "BACKPACK"
 return id.get_slice(":",0).capitalize()+" · "+str({"supply":"Grow Shelf","storage":"Storage / Stash","dealer":"Dealer Storage","packing":"Packing Bench"}.get(id.get_slice(":",1),"Storage"))
func category(item:String) -> String:return item.get_slice("|",0)
func item_name(item:String) -> String:
 if item=="cash":return "Cash"
 if item=="fertilizer":return "Fertilizer"
 return item.get_slice("|",1)+str({"seed":" · Seeds","raw":" · Untrimmed","trimmed":" · Trimmed","product":" · Packaged","equipment":" · Packed equipment","delivery":" · Paid equipment"}.get(category(item),""))
func units(item:String,n:int) -> String:
 if item=="cash":return "$%d" % n
 return "%dg" % n if category(item) in ["raw","trimmed","product"] else "%d" % n
func _append_map(dst:Dictionary,src:Dictionary,prefix:String) -> void:
 for key in src:
  if int(src[key])>0:dst[prefix+"|"+str(key)]=int(src[key])
func _add_deliveries(result:Dictionary,id:String) -> void:
 for name in host.location_state.get("deliveries",{}):
  var receipt:Dictionary=host.location_state.deliveries[name]
  if str(receipt.get("inventory_container","backpack" if receipt.get("collected",true) else "market:orders"))==id:result["delivery|"+str(name)]=1
func delivery_carried(name:String) -> bool:
 return int(contents("backpack").get("delivery|"+name,0))==1
func contents(id:String) -> Dictionary:
 ensure_state()
 var result:Dictionary={}
 if id=="market:orders":
  _append_map(result,host.location_state.get("pickup_seeds",{}),"seed")
  if int(host.location_state.get("pickup_fertilizer",0))>0:result.fertilizer=int(host.location_state.pickup_fertilizer)
  _add_deliveries(result,id)
  return result
 if id=="backpack":
  result=state.backpack.duplicate(true)
  _add_deliveries(result,id)
  _append_map(result,host.location_state.get("carried_seeds",{}),"seed")
  if int(host.location_state.get("carried_fertilizer",0))>0:result.fertilizer=int(host.location_state.carried_fertilizer)
  result.cash=host.cash
  for asset in host.location_state.get("property_storage",[]):
   var key:String="equipment|"+str(asset)
   result[key]=int(result.get(key,0))+1
  return result
 if not state.containers.has(id):return result
 result=state.containers[id].duplicate(true)
 _add_deliveries(result,id)
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
 if kind=="delivery":
  if host.location_state.deliveries.has(name):
   host.location_state.deliveries[name]["inventory_container"]=id if n>0 else ""
   host.location_state.deliveries[name]["collected"]=id!="market:orders"
  return
 if id=="market:orders":
  if kind=="seed":host.location_state.pickup_seeds[name]=n
  if item=="fertilizer":host.location_state.pickup_fertilizer=n
  return
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
 if category(item) in ["equipment","delivery"]:return "equipment"
 return item
func accepts(id:String,item:String) -> bool:
 if id=="backpack":return true
 if id=="market:orders":return false
 var kind:=id.get_slice(":",1)
 if kind=="supply":return group(item) in ["seeds","fertilizer"]
 if kind=="dealer":return category(item)=="product"
 if kind=="packing":return group(item)=="grams"
 return kind=="storage" and (category(item)=="product" or item=="cash" or group(item)=="equipment")
func capacity(id:String,item:String) -> int:
 if item=="cash":return 2000000000
 var key:=group(item)
 if id=="backpack":return int(backpack_limit()/maxi(1,unit_weight(item)))
 match id.get_slice(":",1):
  "supply":return host._supply_seed_capacity() if key=="seeds" else host._supply_fertilizer_capacity()
  "dealer":return host._dealer_locker_capacity()
  "storage":return 12 if key=="equipment" else host._storage_capacity()
  "packing":return 2000
 return 0
func unit_weight(item:String) -> int:
 if item=="cash":return 0
 if category(item)=="seed":return 907185 # 0.02 lb, rounded to 0.00001g
 if item=="fertilizer":return POUND # Five individual fertilizer items per 5 lb pack
 if group(item)=="grams":return GRAM
 if group(item)=="equipment":
  var name:String=item.get_slice("|",1).to_lower()
  if "tent" in name:return 8*POUND
  if "bench" in name:return 10*POUND
  if "shelf" in name:return 6*POUND
  if "storage" in name or "vault" in name or "stash" in name:return 12*POUND
  return 4*POUND
 return 0
func backpack_weight() -> int:
 var weight_units:=0
 var items:=contents("backpack")
 for item in items:weight_units+=int(items[item])*unit_weight(item)
 return weight_units
func backpack_limit() -> int:
 ensure_state()
 return BACKPACK_LIMITS[int(state.backpack_level)-1]
func weight_text(weight_units:int) -> String:return "%.2f lb" % (float(weight_units)/POUND)
func backpack_summary() -> String:
 return "Backpack %s / %s · Level %d%s" % [weight_text(backpack_weight()),weight_text(backpack_limit()),int(state.backpack_level)," · Over capacity" if backpack_weight()>backpack_limit() else ""]
func upgrade_backpack(expected_level:int) -> bool:
 ensure_state()
 var level:int=int(state.backpack_level)
 if expected_level!=level or level>=BACKPACK_LIMITS.size() or not reachable("market:orders"):return false
 var price:int=BACKPACK_PRICES[level-1]
 if host.cash<price:return false
 host.cash-=price;state.backpack_level=level+1;revision+=1
 host._record_daily_expense("Backpack upgrade",price)
 host._update_cash_ui();host._save_game()
 host.neighborhood.location_ops.market()
 return true
func free_space(id:String,item:String) -> int:
 if not accepts(id,item):return 0
 if id=="backpack":
  if unit_weight(item)==0:return maxi(0,2000000000-int(contents(id).get(item,0)))
  return int(maxi(0,backpack_limit()-backpack_weight())/unit_weight(item))
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
 if id in ["backpack","market:orders"]:return true
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
 if destination==operation()+":storage" and category(item)=="product":
  var strain:String=item.get_slice("|",1)
  if host.tutorial_active and host.tutorial_step==8 and strain==host.tutorial_harvest_strain:host.products[strain]["listed"]=false
  host._increment_advancement_stat("grams_stored",amount)
  host._tutorial_record("store",-1,strain)
  host._schedule_next_customer(true)
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
 for receipt in host.location_state.get("deliveries",{}).values():
  var held_at:String=str(receipt.get("inventory_container",""))
  if held_at.begins_with(old_property+":"):receipt.inventory_container=held_at.replace(old_property+":",new_property+":")
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
 container_id="";adding=false;selected="";selected_source="";filter_kind="All"
 overlay.show();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;render()
func open_container(kind:String) -> void:
 var id:String=kind if kind.contains(":") else ("house" if host.camera.position.x>25 else "apartment")+":"+kind
 if not reachable(id):host.status_label.text="Walk up to the "+title(id)+" to open it.";return
 if id.ends_with(":dealer") and host.dealer_locker_level==0:host.status_label.text="Unlock Dealer Storage first.";return
 container_id=id;adding=id=="market:orders";selected="";selected_source="";filter_kind="All"
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
func native_station_target(target:String) -> bool:
 return target in ["station_workbench","station_storage","storage_vault","station_supply","station_locker"]
func sync_station_prompt(nearby:String) -> void:
 if host.get("fp_player")!=null:
  var target:Node=host.get("fp_target")
  if target!=null and native_station_target(str(target.get_meta("interaction_id",""))) and not nearby.is_empty():
   host.fp_prompt.text=""
   nearby_button.text+="  [E]"
 else:
  var world:Node=host.neighborhood
  if world.get("action")!=null:
   var target:String=world._near_target()
   if not nearby.is_empty() and (target.is_empty() or native_station_target(target)):world.action.hide()
   elif not target.is_empty():nearby_button.hide()
 if nearby_button.visible:host.contextual_button.hide()
func _process(_delta:float) -> void:
 if host==null:return
 if is_open():_fit()
 var modal:bool=host._any_modal_open() or host.daily_report_pending or host.tutorial_active
 backpack_button.visible=not modal
 var nearby:String=near_container() if not modal else ""
 if nearby=="market:orders":nearby=""
 nearby_button.visible=not nearby.is_empty()
 if not nearby.is_empty():nearby_button.text="OPEN "+title(nearby).get_slice(" · ",1).to_upper()
 sync_station_prompt(nearby)
 if is_open() and not container_id.is_empty() and not reachable(container_id):close()
func ui_style(bg:String,border:String="343b34",radius:int=12,width:int=1) -> StyleBoxFlat:
 var style:=StyleBoxFlat.new();style.bg_color=Color(bg);style.border_color=Color(border)
 style.set_corner_radius_all(radius);style.set_border_width_all(width)
 for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:style.set_content_margin(side,10)
 return style
func style_button(b:Button,primary:bool=false) -> void:
 b.add_theme_stylebox_override("normal",ui_style("438d31" if primary else "252a26","69aa4f" if primary else "444b43",9))
 b.add_theme_stylebox_override("hover",ui_style("57a43b" if primary else "343d31","8ac46b" if primary else "719263",9))
 b.add_theme_stylebox_override("pressed",ui_style("2b6024","80df59",9,2))
 b.add_theme_stylebox_override("disabled",ui_style("222723","343a33",9))
 b.add_theme_color_override("font_color",Color("faf5df"));b.add_theme_color_override("font_disabled_color",Color("747e70"))
func button(text:String,callback:Callable,parent:Node,primary:bool=false) -> Button:
 var b:=Button.new();b.text=text;b.custom_minimum_size.y=40
 b.add_theme_font_size_override("font_size",16);style_button(b,primary)
 b.pressed.connect(callback);parent.add_child(b);return b
func label(text:String,parent:Node,size:int=17) -> Label:
 var l:=Label.new();l.text=text;l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",Color("f4f0df"));parent.add_child(l);return l
func art(item:String) -> Texture2D:
 var key:String={"seed":"seeds","fertilizer":"fertilizer","equipment":"equipment","delivery":"equipment","cash":"cash","product":"product","raw":"jar","trimmed":"jar"}.get(category(item),"equipment")
 if art_cache.has(key):return art_cache[key]
 var path:String="res://assets/inventory/"+key+".png"
 if FileAccess.file_exists(path):
  var img:=Image.new()
  if img.load_png_from_buffer(FileAccess.get_file_as_bytes(path))==OK:
   art_cache[key]=ImageTexture.create_from_image(img);return art_cache[key]
 var legacy:String={"seeds":"seed","equipment":"storage","cash":"jar","product":"bag","jar":"bud"}.get(key,key)
 return host._load_item_icon(legacy)
func art_rect(item:String,parent:Node,size:Vector2) -> TextureRect:
 var picture:=TextureRect.new();picture.texture=art(item);picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.custom_minimum_size=size
 picture.size_flags_horizontal=Control.SIZE_EXPAND_FILL;picture.size_flags_vertical=Control.SIZE_EXPAND_FILL
 picture.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(picture);return picture
func short_name(item:String) -> String:
 var name:String=item.get_slice("|",1) if item.contains("|") else item_name(item)
 if category(item)=="seed":name+=" Seeds"
 if category(item)=="product":name+=" Pack"
 if category(item)=="raw":name+=" · Untrimmed"
 if category(item)=="trimmed":name+=" · Trimmed"
 return name
func set_filter(value:String) -> void:
 filter_kind=value;selected="";render()
func filter_matches(item:String) -> bool:
 match filter_kind:
  "Seeds":return category(item)=="seed"
  "Supplies":return item=="fertilizer" or (not container_id.ends_with(":supply") and category(item)=="seed")
  "Equipment":return group(item)=="equipment"
  "Products":return group(item)=="grams"
 return true
func go_back() -> void:
 if adding and container_id!="market:orders":adding=false;selected="";render()
 else:close()
func build_ui() -> void:
 layer=CanvasLayer.new();layer.layer=35;add_child(layer)
 var hud:=Control.new();hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(hud)
 backpack_button=button("Backpack  [I]",open_backpack,hud)
 backpack_button.set_anchors_preset(Control.PRESET_TOP_RIGHT);backpack_button.offset_left=-200;backpack_button.offset_right=-18;backpack_button.offset_top=120;backpack_button.offset_bottom=166
 nearby_button=button("Open container",func():open_container(near_container()),hud,true)
 nearby_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM);nearby_button.offset_left=-180;nearby_button.offset_right=180;nearby_button.offset_top=-210;nearby_button.offset_bottom=-162
 if not host.has_method("_use_target"):
  nearby_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
  nearby_button.offset_left=-242;nearby_button.offset_right=-22;nearby_button.offset_top=-125;nearby_button.offset_bottom=-45
 overlay=ColorRect.new();overlay.color=Color(.015,.02,.015,.68);overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(overlay)
 panel=PanelContainer.new();overlay.add_child(panel)
 var style:=ui_style("111713","566052",20)
 for edge in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:style.set_content_margin(edge,14)
 panel.add_theme_stylebox_override("panel",style)
 var root:=VBoxContainer.new();root.add_theme_constant_override("separation",8);panel.add_child(root)
 var top:=HBoxContainer.new();top.add_theme_constant_override("separation",12);root.add_child(top)
 back_button=button("‹",go_back,top);back_button.custom_minimum_size.x=40
 heading=label("Backpack",top,25);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 close_button=button("×",close,top);close_button.custom_minimum_size.x=40
 filter_bar=HBoxContainer.new();filter_bar.add_theme_constant_override("separation",6);root.add_child(filter_bar)
 for value in ["All","Supplies","Seeds","Equipment","Products"]:
  var tab:=button(value,set_filter.bind(value),filter_bar);tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tab.add_theme_font_size_override("font_size",14);tab.custom_minimum_size.y=32
 preview_note=label("Inventory preview · Separate test career",root,12);preview_note.modulate=Color("a4ae9a")
 body_layout=BoxContainer.new();body_layout.size_flags_vertical=Control.SIZE_EXPAND_FILL;body_layout.add_theme_constant_override("separation",12);root.add_child(body_layout)
 columns=BoxContainer.new();columns.size_flags_horizontal=Control.SIZE_EXPAND_FILL;columns.size_flags_vertical=Control.SIZE_EXPAND_FILL;columns.add_theme_constant_override("separation",12);body_layout.add_child(columns)
 inspector=PanelContainer.new();inspector.add_theme_stylebox_override("panel",ui_style("171e18"));body_layout.add_child(inspector)
 notice=label("",root,14)
 footer=BoxContainer.new();footer.add_theme_constant_override("separation",10);root.add_child(footer)
 quantity_strip=HBoxContainer.new();quantity_strip.size_flags_horizontal=Control.SIZE_EXPAND_FILL;quantity_strip.size_flags_stretch_ratio=2;quantity_strip.add_theme_constant_override("separation",5);footer.add_child(quantity_strip)
 button("−",func():quantity.value=maxf(1,quantity.value-1),quantity_strip).custom_minimum_size.x=36
 quantity=SpinBox.new();quantity.min_value=1;quantity.max_value=1;quantity.step=1;quantity.custom_minimum_size=Vector2(70,40)
 quantity.get_line_edit().alignment=HORIZONTAL_ALIGNMENT_CENTER;quantity.add_theme_font_size_override("font_size",18);quantity_strip.add_child(quantity)
 button("+",func():quantity.value=minf(quantity.max_value,quantity.value+1),quantity_strip).custom_minimum_size.x=36
 button("Max",func():quantity.value=quantity.max_value,quantity_strip)
 transfer_preview=label("",quantity_strip,13);transfer_preview.size_flags_horizontal=Control.SIZE_EXPAND_FILL;transfer_preview.autowrap_mode=TextServer.AUTOWRAP_OFF;transfer_preview.add_theme_font_size_override("font_size",11)
 confirm=button("Select an item",commit_selection,footer,true);confirm.size_flags_horizontal=Control.SIZE_EXPAND_FILL;confirm.custom_minimum_size.x=150
 quantity.value_changed.connect(func(_value):selection_summary())
 overlay.hide();resize()
func resize() -> void:
 if panel==null:return
 if is_open():render()
 _fit()
func _fit() -> void:
 var screen:Vector2=host.get_viewport().get_visible_rect().size
 var portrait:bool=screen.y>screen.x
 var compact:bool=screen.y<500
 preview_note.visible=not compact and not (portrait and adding)
 footer.vertical=portrait
 columns.vertical=portrait
 body_layout.vertical=portrait
 back_button.visible=adding or not container_id.is_empty()
 inspector.custom_minimum_size.x=0 if portrait else (210 if compact else 260)
 panel.size=Vector2(minf(1140,screen.x-24),minf(900,screen.y-24))
 panel.position=(screen-panel.size)/2
func clear(node:Node) -> void:
 for child in node.get_children():node.remove_child(child);child.queue_free()
func select_item(source:String,item:String) -> void:
 selected=item;selected_source=source;selected_revision=revision
 render()
func render() -> void:
 clear(columns);clear(inspector);packing_action=null
 var screen:Vector2=host.get_viewport().get_visible_rect().size
 var compact:bool=screen.y<500
 heading.text="Backpack" if container_id.is_empty() else title(container_id)
 heading.add_theme_font_size_override("font_size",20 if compact else 25)
 filter_bar.visible=container_id.is_empty() or not adding
 for tab in filter_bar.get_children():
  tab.visible=tab.text in (["All","Supplies","Seeds"] if container_id.ends_with(":supply") else ["All","Supplies","Equipment","Products"])
  style_button(tab,tab.text==filter_kind)
 inspector.visible=not adding and not selected.is_empty()
 if container_id.is_empty():render_inventory("backpack")
 else:
  render_inventory(container_id)
  if adding:render_inventory("backpack")
 if inspector.visible:render_inspector()
 footer.visible=not container_id.is_empty()
 confirm.disabled=selected.is_empty()
 notice.text="Select an item for details." if container_id.is_empty() else ("Choose an order and quantity. Anything that does not fit stays at the shop." if container_id=="market:orders" else "Select an item to take, or open your backpack to add stock.")
 if not selected.is_empty() and not container_id.is_empty():
  var dst:String=container_id if selected_source=="backpack" else "backpack"
  var maximum:int=mini(available(selected_source,selected),free_space(dst,selected))
  quantity.max_value=maxi(1,maximum);quantity.value=clampf(quantity.value,1,quantity.max_value)
  confirm.disabled=maximum<=0
  notice.text=("Backpack → "+title(container_id) if selected_source=="backpack" else title(container_id)+" → Backpack")+" · "+short_name(selected)
  if maximum<=0:notice.text="Not enough space or this item is not accepted here."
 selection_summary();_fit.call_deferred()
func selection_summary() -> void:
 if confirm==null:return
 if selected.is_empty() or container_id.is_empty():confirm.text="Select an item";transfer_preview.text="";return
 var amount:int=int(quantity.value)
 confirm.text=("Store " if selected_source=="backpack" else "Take ")+units(selected,amount)
 var change:int=unit_weight(selected)*amount*(-1 if selected_source=="backpack" else 1)
 transfer_preview.text=weight_text(backpack_weight())+" → "+weight_text(backpack_weight()+change)
func render_capacity(id:String,parent:Node) -> void:
 var text:String=""
 var ratio:=0.0
 var items:Dictionary=contents(id)
 if id=="backpack":
  text=weight_text(backpack_weight())+" / "+weight_text(backpack_limit())+" · Lv "+str(state.backpack_level)
  ratio=float(backpack_weight())/maxi(1,backpack_limit())
 elif id=="market:orders":text="Paid orders · Collect what fits"
 elif id.ends_with(":supply"):
  var seeds:=0
  for item in items:
   if category(item)=="seed":seeds+=int(items[item])
  var fertilizer:int=int(items.get("fertilizer",0))
  text="Seeds %d/%d · Fertilizer %d/%d" % [seeds,capacity(id,"seed|sample"),fertilizer,capacity(id,"fertilizer")]
  ratio=maxf(float(seeds)/maxi(1,capacity(id,"seed|sample")),float(fertilizer)/maxi(1,capacity(id,"fertilizer")))
 else:
  var grams:=0
  for item in items:
   if group(item)=="grams":grams+=int(items[item])
  text="Product %d / %d g" % [grams,capacity(id,"product|sample")];ratio=float(grams)/maxi(1,capacity(id,"product|sample"))
 label(text,parent,13).modulate=Color("bac4b0")
 if id=="market:orders":return
 var bar:=ProgressBar.new();bar.custom_minimum_size.y=7;bar.max_value=1;bar.value=clampf(ratio,0,1);bar.show_percentage=false
 var background:=ui_style("30372f","30372f",4,0);var fill:=ui_style("77d44d" if ratio<=1 else "d9964c","77d44d",4,0)
 for edge in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:background.set_content_margin(edge,0);fill.set_content_margin(edge,0)
 bar.add_theme_stylebox_override("background",background);bar.add_theme_stylebox_override("fill",fill);parent.add_child(bar)
func ignore_pointer(node:Node) -> void:
 if node is Control:node.mouse_filter=Control.MOUSE_FILTER_IGNORE
 for child in node.get_children():ignore_pointer(child)
func render_inventory(id:String) -> void:
 var frame:=PanelContainer.new();frame.size_flags_horizontal=Control.SIZE_EXPAND_FILL;frame.size_flags_vertical=Control.SIZE_EXPAND_FILL
 frame.add_theme_stylebox_override("panel",ui_style("161c17","323a32",13));columns.add_child(frame)
 var column:=VBoxContainer.new();column.add_theme_constant_override("separation",7);frame.add_child(column)
 var head:=HBoxContainer.new();column.add_child(head)
 var title_label:=label("Backpack" if id=="backpack" else title(id).get_slice(" · ",1),head,19);title_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 if id not in ["backpack","market:orders"] and not adding:
  button("+ Add Stock",func():adding=true;filter_kind="All";selected="";render(),head,true).add_theme_font_size_override("font_size",14)
 render_capacity(id,column)
 var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(scroll)
 var grid:=GridContainer.new();grid.columns=3 if container_id.is_empty() and host.get_viewport().get_visible_rect().size.x>=1100 and selected.is_empty() else 2
 grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",8);scroll.add_child(grid)
 var items:=contents(id);var keys:Array=items.keys();keys.sort_custom(func(a,b):
  if id=="backpack" and not container_id.is_empty() and accepts(container_id,a)!=accepts(container_id,b):return accepts(container_id,a)
  return str(a)<str(b))
 var count:=0
 for item in keys:
  if int(items[item])<=0 or (not adding and not filter_matches(item)):continue
  if container_id.ends_with(":supply") and not accepts(container_id,item):continue
  count+=1
  var compact:bool=host.get_viewport().get_visible_rect().size.y<500
  var card:=Button.new();card.custom_minimum_size=Vector2(0,128 if compact else 190);card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  card.add_theme_stylebox_override("normal",ui_style("1b201c","3a4039",12))
  card.add_theme_stylebox_override("hover",ui_style("242e20","789d61",12))
  card.add_theme_stylebox_override("pressed",ui_style("22371c","83e35b",12,3))
  card.add_theme_stylebox_override("disabled",ui_style("161a17","30362f",12))
  card.toggle_mode=true;card.button_pressed=selected==item and selected_source==id
  card.disabled=id=="backpack" and not container_id.is_empty() and not accepts(container_id,item)
  card.tooltip_text=item_name(item)+" · "+("1 g" if group(item)=="grams" else weight_text(unit_weight(item)))+" each"+(" · Not accepted here" if card.disabled else "")
  grid.add_child(card)
  var stack:=VBoxContainer.new();card.add_child(stack);stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);stack.offset_left=8;stack.offset_right=-8;stack.offset_top=6;stack.offset_bottom=-6
  stack.add_theme_constant_override("separation",2)
  art_rect(item,stack,Vector2(0,60 if compact else 108))
  var name_label:=label(short_name(item),stack,13 if compact else 15);name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  name_label.max_lines_visible=2;name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
  var weight:=label("Weightless" if item=="cash" else weight_text(unit_weight(item)*int(items[item])),stack,11);weight.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;weight.modulate=Color("b6c1ae")
  var badge:=Label.new();badge.text=units(item,int(items[item]));badge.add_theme_font_size_override("font_size",13);badge.add_theme_stylebox_override("normal",ui_style("101510","58604e",8));badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
  card.add_child(badge);badge.set_anchors_preset(Control.PRESET_TOP_RIGHT);badge.offset_left=-76;badge.offset_right=-7;badge.offset_top=7;badge.offset_bottom=28
  ignore_pointer(stack);ignore_pointer(badge)
  if card.disabled:stack.modulate=Color(1,1,1,.38);badge.modulate=Color(1,1,1,.4)
  card.pressed.connect(select_item.bind(id,item))
  if card.button_pressed:reveal_selection.call_deferred(scroll,card)
 if count==0:
  grid.columns=1
  var empty:=label("No items in this category.",grid,16)
  empty.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  empty.custom_minimum_size.x=180
  empty.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
func reveal_selection(scroll:ScrollContainer,card:Control) -> void:
 await get_tree().process_frame
 await get_tree().process_frame
 if is_instance_valid(scroll) and is_instance_valid(card):scroll.ensure_control_visible(card)
func packing_allowed() -> bool:
 return container_id==operation()+":packing" and selected_source==container_id and category(selected) in ["raw","trimmed"] and available(container_id,selected)>0
func process_selected() -> void:
 if not packing_allowed() or not reachable(container_id):return
 var item:String=selected
 packing_return=container_id
 close()
 if category(item)=="raw":host._start_trim_minigame(item.get_slice("|",1))
 else:host._start_bag_minigame(item.get_slice("|",1))
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 if not host.trim_panel.visible and not host.bag_minigame_panel.visible:return_to_packing()
func return_to_packing() -> void:
 host.bagging_panel.hide()
 var id:String=packing_return if not packing_return.is_empty() else operation()+":packing"
 packing_return=""
 open_container(id)
func render_inspector() -> void:
 var screen:Vector2=host.get_viewport().get_visible_rect().size
 var portrait:bool=screen.y>screen.x
 var row:=BoxContainer.new();row.vertical=not portrait;row.add_theme_constant_override("separation",10);inspector.add_child(row)
 art_rect(selected,row,Vector2(68 if portrait else 0,68 if portrait or screen.y<500 else 170))
 var text_box:=VBoxContainer.new();text_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(text_box)
 label(short_name(selected),text_box,18)
 var owned:int=int(contents(selected_source).get(selected,0))
 label("Owned: "+units(selected,owned),text_box,15)
 label("Weightless" if selected=="cash" else ("1 g" if group(selected)=="grams" else weight_text(unit_weight(selected)))+" each",text_box,14).modulate=Color("b6c1ae")
 if container_id.ends_with(":packing") and selected_source==container_id and category(selected) in ["raw","trimmed"]:
  packing_action=button("Trim by hand" if category(selected)=="raw" else "Bag by hand",process_selected,text_box,true)
  packing_action.disabled=not packing_allowed()
  if not packing_allowed():label("Processing is available at your active operation's bench.",text_box,13)
 if container_id.is_empty():
  var hint:String="Open a nearby container to store this item."
  if category(selected)=="delivery":hint="Install at your active property computer."
  elif category(selected)=="equipment":hint="Owned equipment · manage it in Real Estate."
  elif selected=="cash":hint="Cash never uses backpack capacity."
  label(hint,text_box,13).modulate=Color("b6c1ae")
func commit_selection() -> void:
 if selected.is_empty() or container_id.is_empty():return
 var dst:String=container_id if selected_source=="backpack" else "backpack"
 var result:=transfer(selected_source,dst,selected,int(quantity.value),selected_revision)
 selected="";selected_source="";render();notice.text=str(result.reason)
