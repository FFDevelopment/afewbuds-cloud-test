extends RefCounted
## Item ownership is authoritative; inventory views are adapters over these records.
const CATALOG={
 "grow_tent":{"name":"Grow Tent · 3 plants","shop":"grow","price":800,"size":[3.12,2.8,1.5],"grow_only":true,"plants":3,"weight":12},
 "tent_1":{"name":"Compact Tent · 1 plant","shop":"grow","price":240,"size":[1.15,2.5,1.2],"grow_only":true,"plants":1,"weight":6},
 "tent_2":{"name":"Twin Tent · 2 plants","shop":"grow","price":480,"size":[2.15,2.65,1.4],"grow_only":true,"plants":2,"weight":9},
 "tent_4":{"name":"Wide Tent · 4 plants","shop":"grow","price":1200,"size":[4.1,2.8,1.5],"grow_only":true,"plants":4,"weight":16},
 "bench_1":{"name":"Packing Bench I","shop":"equipment","price":180,"size":[1.6,1.25,.85],"kind":"packing","tier":1,"weight":18},
 "bench_2":{"name":"Packing Bench II","shop":"equipment","price":450,"size":[1.8,1.25,.85],"kind":"packing","tier":2,"weight":22},
 "bench_3":{"name":"Packing Bench III","shop":"equipment","price":850,"size":[2.1,1.25,.9],"kind":"packing","tier":3,"weight":28},
 "shelf_1":{"name":"Grow Supply Shelf I","shop":"equipment","price":100,"size":[1.56,2.315,.68],"kind":"supply","tier":1,"weight":10},
 "shelf_2":{"name":"Grow Supply Shelf II","shop":"equipment","price":280,"size":[1.56,2.315,.68],"kind":"supply","tier":2,"weight":14},
 "shelf_3":{"name":"Grow Supply Shelf III","shop":"equipment","price":600,"size":[1.56,2.315,.68],"kind":"supply","tier":3,"weight":18},
 "storage_1":{"name":"Storage Shelving I","shop":"equipment","price":140,"size":[1.25,1.9,.6],"kind":"storage","tier":1,"capacity":40,"weight":12},
 "storage_2":{"name":"Storage Shelving II","shop":"equipment","price":360,"size":[1.35,2,.65],"kind":"storage","tier":2,"capacity":80,"weight":16},
 "storage_3":{"name":"Storage Shelving III","shop":"equipment","price":900,"size":[1.5,2.1,.7],"kind":"storage","tier":3,"capacity":160,"weight":20},
 "storage_4":{"name":"AFB Storage Vault","shop":"equipment","price":1800,"size":[1.55,2.1,.9],"kind":"storage","tier":4,"capacity":400,"weight":30},
 "storage_5":{"name":"Hidden Wall Stash","shop":"equipment","price":3250,"size":[1.72,2.4,.34],"kind":"storage","tier":5,"capacity":1000,"weight":22},
 "dealer_1":{"name":"Dealer Locker I","shop":"equipment","price":300,"size":[1.2,2,.75],"kind":"dealer","tier":1,"capacity":100,"weight":16},
 "dealer_2":{"name":"Dealer Locker II","shop":"equipment","price":600,"size":[1.3,2,.8],"kind":"dealer","tier":2,"capacity":200,"weight":20},
 "dealer_3":{"name":"Dealer Locker III","shop":"equipment","price":900,"size":[1.5,2.83,.92],"kind":"dealer","tier":3,"capacity":300,"weight":24},
 "dealer_4":{"name":"Dealer Locker IV","shop":"equipment","price":1200,"size":[1.5,2.83,.92],"kind":"dealer","tier":4,"capacity":400,"weight":28},
 "water_kit":{"name":"Auto Water Kit","shop":"equipment","price":420,"size":[.55,.75,.5],"weight":5,"grow_only":true},
 "ventilation":{"name":"Ventilation Unit","shop":"equipment","price":320,"size":[.6,1.1,.6],"weight":8,"grow_only":true},
 "grow_light":{"name":"Supplemental Grow Light","shop":"equipment","price":250,"size":[.65,2.4,.65],"weight":6,"grow_only":true},
 "sofa":{"name":"Two-seat Sofa","shop":"furniture","price":350,"size":[1.9,.9,.85],"weight":25},
 "armchair":{"name":"Armchair","shop":"furniture","price":180,"size":[.85,.95,.85],"weight":15},
 "coffee_table":{"name":"Coffee Table","shop":"furniture","price":95,"size":[1.1,.48,.6],"weight":8},
 "dining_table":{"name":"Dining Table","shop":"furniture","price":220,"size":[1.5,.78,.85],"weight":18},
 "bookcase":{"name":"Bookcase","shop":"furniture","price":160,"size":[.9,1.9,.35],"weight":14},
 "bed":{"name":"Double Bed","shop":"furniture","price":450,"size":[1.55,.65,2.05],"weight":30},
 "dining_chair":{"name":"Dining Chair","shop":"furniture","price":65,"size":[.65,1.2,.65],"weight":7},
 "wardrobe":{"name":"Wardrobe","shop":"furniture","price":240,"size":[1.2,2.5,.85],"weight":25},
 "tv_console":{"name":"TV & Console","shop":"furniture","price":420,"size":[2.1,1.8,.65],"weight":24},
 "fridge":{"name":"Refrigerator","shop":"furniture","price":400,"size":[1.05,2.4,1],"weight":32},
 "floor_lamp":{"name":"Floor Lamp","shop":"furniture","price":85,"size":[.5,1.8,.5],"weight":5},
 "computer":{"name":"Computer Desk","shop":"furniture","price":550,"size":[1.5,1.5,.85],"weight":22}}
const ROOMS={
 "apartment":{"main":Rect2(-4.7,-3.65,9.4,9.1),"grow":Rect2(-4.7,-10.0,9.4,5.5)},
 "house":{"living":Rect2(25.4,-4.6,7.65,7.15),"packing":Rect2(37,-4.6,7.6,7.15),"kitchen":Rect2(25.4,-13.55,5.5,6.1),"bathroom":Rect2(31.7,-13.55,2.05,6.1),"bedroom":Rect2(34.65,-13.55,3.5,6.1),"grow":Rect2(39.05,-13.55,5.55,6.1)}}
# Front grow-room corners keep migrated utility units clear of shelves and tents.
const UTILITY_POSITIONS={
 "apartment":{"water_kit":Vector3(3.8,0,-5.1),"ventilation":Vector3(3.8,0,-6.4)},
 "house":{"water_kit":Vector3(39.65,0,-8.2),"ventilation":Vector3(40.65,0,-8.2)}}
const CURBS={"apartment":Vector3(-2,0,7.2),"house":Vector3(34.8,0,4.8)}
var host:Node
var state:Dictionary
var error:=""
var busy:=false
func inv():return host.inventory_system
func setup(owner:Node) -> void:
 host=owner
 if not host.location_state.get("furniture_v1",{}) is Dictionary:host.location_state["furniture_v1"]={}
 if not host.location_state.has("furniture_v1"):host.location_state["furniture_v1"]={}
 state=host.location_state.furniture_v1
 if not state.has("items"):state["items"]={}
 if not state.has("next_id"):state["next_id"]=1
 if int(state.get("schema",1))<2:migrate()
 ensure_slots()
func migrate() -> void:
 var property:String=str(host.location_state.get("operation_assets_property","apartment"))
 for i in range(host.grow_tent_count):
  if not state.items.values().any(func(e):return int(e.get("legacy_slot",-1))==i):
   state.items["legacy_tent_%d"%i]={"sku":"grow_tent","legacy_slot":i,"property":"legacy","locked":true}
 for id in state.items:
  var e:Dictionary=state.items[id]
  if not CATALOG.has(e.sku):continue
  if e.sku=="grow_tent" and e.has("legacy_slot"):
   var base:int=int(e.legacy_slot)*3
   e.slots=[base,base+1,base+2]
  if e.get("property","")=="legacy":
   e.property=property
   var slot:int=int(e.get("legacy_slot",0))
   e.position=[0 if slot==0 else (-3.2 if slot==1 else 3.2),0,-9.14 if slot==0 else -9.28];e.yaw=0
   if property=="house":e.position=[41.8,0,-12+slot*1.7]
  if e.get("property","")=="storage":e.property="backpack"
  if is_tent(e):e["quality"]=host.tent_level
  e["paid"]=int(CATALOG[e.sku].price);e["upgrades"]=e.get("upgrades",{});e["condition"]=100
 # Preserve purchased station tiers and current stock; no item is charged twice.
 var tiers={"packing":host.bagging_level,"supply":host.supply_shelf_level,"storage":host.storage_level,"dealer":host.dealer_locker_level}
 for kind in tiers:
  if int(tiers[kind])<=0:continue
  var prefix:String={"packing":"bench","supply":"shelf","storage":"storage","dealer":"dealer"}[kind]
  var sku:String=prefix+"_"+str(tiers[kind])
  var pos:Vector3=inv().POSITIONS.get((property if property in ROOMS else "apartment")+":"+kind,Vector3.ZERO)
  state.items["legacy_"+kind]={"sku":sku,"property":property if property in ROOMS else "backpack","position":[pos.x,0,pos.z],"yaw":90 if property=="apartment" else 0,"locked":true,"container":property+":"+kind,"legacy_group":kind,"paid":CATALOG[sku].price,"upgrades":{},"condition":100}
 for spec in [["water_kit",host.auto_water_unlocked],["ventilation",host.ventilation_installed]]:
  if spec[1]:state.items["legacy_"+spec[0]]={"sku":spec[0],"property":property if property in ROOMS else "backpack","position":utility_position(property,str(spec[0])),"yaw":0,"locked":true,"paid":CATALOG[spec[0]].price,"upgrades":{},"condition":100}
 # Existing moveable decor is owned; built-in walls, plumbing and switches remain fixtures.
 state.items["legacy_sofa"]={"sku":"sofa","property":"apartment","position":[-2.4,0,3.2],"yaw":0,"locked":true,"legacy_group":"sofa","paid":350,"upgrades":{},"condition":100}

 var old_names={"Grow Tent Slot 2":"grow_tent","Grow Tent Slot 3":"grow_tent","Bagging Bench II":"bench_2","Bagging Bench III":"bench_3","Grow Supply Shelf II":"shelf_2","Grow Supply Shelf III":"shelf_3","Storage Shelving II":"storage_2","Storage Shelving III":"storage_3","AFB Storage Vault":"storage_4","Hidden Wall Stash":"storage_5","Auto Water Kit":"water_kit","Grow Room Ventilation":"ventilation"}
 for name in host.location_state.get("deliveries",{}).keys():
  var receipt:Dictionary=host.location_state.deliveries[name]
  var sku:String=old_names.get(name,"")
  if receipt.get("kind","")=="dealer":sku="dealer_"+str(receipt.get("level",1))
  if sku.is_empty():continue
  var id:="furniture_%d"%int(state.next_id);state.next_id=int(state.next_id)+1
  var destination:String=str(receipt.get("property","apartment"))+":delivery"
  if bool(receipt.get("collected",false)):destination=str(receipt.get("inventory_container","backpack"))
  state.items[id]={"sku":sku,"property":destination,"locked":false,"paid":receipt.get("paid",CATALOG[sku].price),"upgrades":{},"condition":100}
  host.location_state.deliveries.erase(name)
 # Aggregate legacy storage labels describe the already-migrated equipment, not extra copies.
 var retained:Array=[]
 for name in host.location_state.get("property_storage",[]):
  if name not in old_names and name not in ["Grow Tent Slots II-III","Grow Tent upgrade","Grow Room Ventilation","Auto Water Kit"] and not str(name).begins_with("Dealer Storage"):retained.append(name)
 host.location_state.property_storage=retained
 state["schema"]=2
 state["migration_complete"]=true
func utility_position(property:String,sku:String) -> Array:
 var at:Vector3=UTILITY_POSITIONS.get(property,UTILITY_POSITIONS.apartment)[sku]
 return [at.x,0,at.z]
func repair_utility_positions() -> void:
 for sku in ["water_kit","ventilation"]:
  var id:String="legacy_"+str(sku)
  if not state.items.has(id):continue
  var e:Dictionary=state.items[id]
  if e.get("utility_layout_version",0)>=2:continue
  var p:Array=e.get("position",[])
  var previous:Vector2=Vector2(-3.2,-5.1) if sku=="water_kit" else Vector2(3.2,-5.1)
  var old_spawn:bool=p.size()==3 and (Vector2(p[0],p[2]).distance_to(Vector2(-3.8,-5.3))<.02 or (e.get("utility_layout_version",0)==1 and Vector2(p[0],p[2]).distance_to(previous)<.02))
  # Repair only known generated spawns, never a player's chosen placement.
  if not e.get("player_placed",false) and e.get("property","") in ROOMS and old_spawn:
   e.position=utility_position(e.property,sku)
  e.utility_layout_version=2
func ensure_slots() -> void:
 var next:int=host.plant_slots.size()
 for e in state.items.values():
  if not CATALOG.has(e.sku) or not is_tent(e):continue
  if not e.has("slots"):
   e.slots=[]
   for i in int(CATALOG[e.sku].plants):e.slots.append(next);next+=1
  # JSON numbers reload as floats; Array membership distinguishes float from int.
  for index in range(e.slots.size()):e.slots[index]=int(e.slots[index])
  for slot in e.slots:
   while host.plant_slots.size()<=int(slot):host.plant_slots.append(host._empty_plant_slot())
func is_tent(e:Dictionary) -> bool:return CATALOG.has(e.get("sku","")) and CATALOG[e.sku].has("plants")
func controlled(property:String) -> bool:
 if property=="apartment":return bool(host.apartment_rent_state.get("lease_active",true))
 return property=="house" and bool(host.property_opportunity_state.get("acquired",false))
func tent_count() -> int:
 var n:=0
 for e in state.items.values():
  if is_tent(e) and e.get("property","") in ROOMS:n+=1
 return n
func price_for(sku:String) -> int:return int(CATALOG[sku].price)
func item_name(id:String) -> String:return str(CATALOG[state.items[id].sku].name)
func own(sku:String,destination:String="backpack") -> String:
 error=""
 if busy or not CATALOG.has(sku):error="Unknown equipment.";return ""
 if destination!="backpack" and not controlled(destination):error="Choose a property you hold.";return ""
 var price:int=price_for(sku)
 if host.cash<price:error="Not enough cash.";return ""
 if destination=="backpack" and inv().backpack_weight()+int(CATALOG[sku].get("weight",8))*inv().POUND>inv().backpack_limit():error="Backpack is full. Order a curbside delivery instead.";return ""
 busy=true
 var id:="furniture_%d"%int(state.next_id);state.next_id=int(state.next_id)+1
 state.items[id]={"sku":sku,"property":"backpack" if destination=="backpack" else destination+":delivery","locked":false,"paid":price,"condition":100,"upgrades":{}}
 ensure_slots();host.cash-=price;host._record_daily_expense("Equipment",price)
 save();busy=false;return id
func size_of(id:String,yaw:int=0) -> Vector3:
 var a:Array=state.items[id].get("size_override",CATALOG[state.items[id].sku].size);var s:=Vector3(a[0],a[1],a[2])
 return Vector3(s.z,s.y,s.x) if posmod(yaw,180)==90 else s
func bounds(id:String,point:Vector3,yaw:int) -> Rect2:
 var s:=size_of(id,yaw);return Rect2(Vector2(point.x-s.x/2,point.z-s.z/2),Vector2(s.x,s.z))
func item_for_slot(slot:int) -> String:
 for id in state.items:
  if slot in state.items[id].get("slots",[]):return id
 return ""
func can_plant(slot:int) -> bool:
 var id:=item_for_slot(slot)
 return not id.is_empty() and state.items[id].get("property","") in ROOMS
func slot_property(slot:int) -> String:
 var id:=item_for_slot(slot);return str(state.items[id].get("property","")) if not id.is_empty() else ""
func live(id:String) -> bool:
 for slot in state.items.get(id,{}).get("slots",[]):
  if int(slot)<host.plant_slots.size() and (int(host.plant_slots[int(slot)].get("stage",-1))>=0 or bool(host.plant_slots[int(slot)].get("dead",false))):return true
 return false
func station_kind(id:String) -> String:return str(CATALOG[state.items[id].sku].get("kind",""))
func container_of(id:String) -> String:return str(state.items[id].get("container",""))
func primary(property:String,kind:String) -> String:
 for id in state.items:
  if state.items[id].get("property","")==property and station_kind(id)==kind and container_of(id)==property+":"+kind:return id
 return ""
func container_item(container:String) -> String:
 for id in state.items:
  if container_of(id)==container and state.items[id].get("property","") in ROOMS:return id
 return ""
func empty_reason(id:String) -> String:
 if not state.items.has(id):return "Item is no longer owned."
 if inv().furniture!=null and inv().furniture.equipment_world!=null and host.neighborhood.couch_seated and inv().furniture.equipment_world.seated_id==id:return "Stand up before moving this seat."
 if live(id):return "Harvest or remove every plant before moving this tent."
 var container:=container_of(id)
 if not container.is_empty():
  var stock:Dictionary=inv().contents(container)
  var labels:Array[String]=[]
  for item in stock:
   if int(stock[item])>0:labels.append(inv().units(item,int(stock[item]))+" "+inv().item_name(item))
  if not labels.is_empty():return "Empty this equipment first: "+", ".join(labels)+"."
  if station_kind(id)=="packing" and inv().packing!=null and inv().packing.active:return "Finish or cancel the active packing work first."
 if bool(host.packing_employee_active) and not str(host.get("production_worker_pending_action")).is_empty() and state.items[id].get("property","")==inv().operation():
  if station_kind(id) in ["packing","supply","storage","dealer"] or is_tent(state.items[id]):return "Pause the production worker before moving equipment."
 return ""
func validate(id:String,property:String,point:Vector3,yaw:int) -> String:
 if not state.items.has(id):return "Furniture is not owned."
 if not controlled(property):return "You do not hold this property."
 var e:Dictionary=state.items[id]
 if e.get("property","") in ROOMS and e.property!=property:return "Pick up this item into your backpack before moving it to another property."
 if e.get("property","")!="backpack" and e.get("property","") not in ROOMS:return "Collect this item into your backpack first."
 if bool(e.get("locked",false)):return "Unlock the furniture first."
 var reason:=empty_reason(id)
 if not reason.is_empty():return reason
 if not point.is_finite() or absf(point.y)>.05 or yaw%90!=0:return "Place on the floor with quarter-turn rotation."
 var rect:=bounds(id,point,yaw).grow(.06);var room:=""
 for key in ROOMS[property]:
  if (ROOMS[property][key] as Rect2).encloses(rect):room=key;break
 if room.is_empty():return "Keep the entire item inside one room and clear of doorways."
 if bool(CATALOG[e.sku].get("grow_only",false)) and room!="grow":return "Grow equipment can only be placed in grow rooms."
 for other in state.items:
  if other==id:continue
  var item:Dictionary=state.items[other]
  if item.get("property","")!=property or not item.has("position"):continue
  var p:Array=item.position
  if rect.intersects(bounds(other,Vector3(p[0],p[1],p[2]),int(item.get("yaw",0)))):return "Furniture overlaps another item."
 return ""
func place(id:String,property:String,point:Vector3,yaw:int) -> bool:
 error=validate(id,property,point,yaw)
 if not error.is_empty():return false
 var e:Dictionary=state.items[id]
 e.player_placed=true;e.property=property;e.position=[point.x,0.0,point.z];e.yaw=posmod(yaw,360);e.locked=true
 var kind:=station_kind(id)
 if not kind.is_empty():
  var primary_id:=primary(property,kind)
  e.container=property+":"+kind if primary_id.is_empty() or primary_id==id else property+":"+kind+"@"+id
  if not inv().state.containers.has(e.container):inv().state.containers[e.container]={}
 save();return true
func pack(id:String) -> bool:
 error=empty_reason(id)
 if not error.is_empty():return false
 var e:Dictionary=state.items[id]
 if e.get("locked",false):error="Unlock the furniture first.";return false
 if e.get("property","") not in ROOMS:error="Only placed equipment can be picked up.";return false
 if inv().backpack_weight()+int(CATALOG[e.sku].get("weight",8))*inv().POUND>inv().backpack_limit():error="Not enough backpack capacity for this packed item.";return false
 e.property="backpack";e.erase("position");e.erase("yaw");e.erase("container")
 save();return true
func lock(id:String,value:bool) -> void:
 if state.items.has(id):state.items[id].locked=value;save()
func resale(id:String) -> int:return int(int(state.items[id].get("paid",CATALOG[state.items[id].sku].price))*.5*float(state.items[id].get("condition",100))/100)
func sell(id:String) -> bool:
 error=empty_reason(id)
 if not error.is_empty():return false
 if not inv().reachable("market:orders"):error="Bring packed equipment to Central Market.";return false
 if state.items[id].get("property","")!="backpack":error="Pick up the equipment before selling it.";return false
 var amount:=resale(id);state.items.erase(id);host.cash+=amount;save();return true
func next_upgrade(id:String) -> String:
 if is_tent(state.items[id]):return "tent_quality" if int(state.items[id].get("quality",1))<2 else ""
 var e:Dictionary=state.items[id];var kind:=station_kind(id)
 if kind.is_empty():return ""
 var prefix:String={"packing":"bench","supply":"shelf","storage":"storage","dealer":"dealer"}[kind]
 var sku:=prefix+"_"+str(int(CATALOG[e.sku].get("tier",1))+1)
 return sku if CATALOG.has(sku) else ""
func upgrade(id:String) -> bool:
 error=empty_reason(id)
 if not error.is_empty():return false
 var sku:=next_upgrade(id)
 if sku.is_empty():error="This equipment is already at its highest tier.";return false
 var e:Dictionary=state.items[id]
 if sku=="tent_quality":
  if host.cash<320:error="Not enough cash.";return false
  e.quality=2;e.upgrades["light_kit"]=true;e.paid=int(e.get("paid",0))+320;host.cash-=320;host._record_daily_expense("Tent light kit",320);save();return true
 var price:int=int(CATALOG[sku].price)-int(CATALOG[e.sku].price)
 if host.cash<price:error="Not enough cash.";return false
 var old_sku:String=e.sku;var locked:bool=e.get("locked",false)
 var old_size:Array=e.get("size_override",[])
 if not sku.begins_with("shelf_"):e.erase("size_override")
 e.sku=sku;e.locked=false
 if e.get("property","") in ROOMS and not sku.begins_with("shelf_"):
  var p:Array=e.position;error=validate(id,e.property,Vector3(p[0],0,p[2]),int(e.yaw))
 if not error.is_empty():
  e.sku=old_sku;e.locked=locked
  if not old_size.is_empty():e.size_override=old_size
  return false
 e.locked=locked;e.paid=int(e.get("paid",0))+price;e.upgrades[sku]=true
 host.cash-=price;host._record_daily_expense("Equipment upgrade",price);save();return true
func powered_tent_count(property:String) -> float:
 var total:=0.0
 for e in state.items.values():
  if is_tent(e) and e.get("property","")==property:total+=float(CATALOG[e.sku].plants)/3.0
 return total
func property_has_furniture(property:String) -> bool:
 for e in state.items.values():
  if e.get("property","")==property or e.get("property","")==property+":delivery":return true
 return false
func save() -> void:
 host.grow_tent_count=tent_count()
 if inv()!=null:inv().revision+=1
 host._update_cash_ui();host._save_game()

func tent_quality(slot:int) -> int:
 var id:=item_for_slot(slot);return int(state.items[id].get("quality",1)) if not id.is_empty() else 1
func upgrade_label(id:String) -> String:
 var sku:=next_upgrade(id)
 if sku=="tent_quality":return "Fit improved light kit · $320"
 return "Upgrade to %s · $%d"%[CATALOG[sku].name,CATALOG[sku].price-CATALOG[state.items[id].sku].price]

func growth_settings(slot:int,base:Dictionary,offline:bool) -> Dictionary:
 var result:Dictionary=base.duplicate();result.erase("per_slot");result.erase("care_slots")
 var property:=slot_property(slot);var water:=false;var vent:=false;var light:=false
 for e in state.items.values():
  if e.get("property","")!=property or property not in ROOMS:continue
  if e.sku=="water_kit":water=true
  if e.sku=="ventilation":vent=true
  if e.sku=="grow_light":light=true
 result.auto_water=water and not offline
 result.ventilation_factor=1.0 if vent and host.ventilation_on else host.VENTILATION_INACTIVE_GROWTH_MULTIPLIER
 if light and host.grow_lights_on:result.light_factor=1.08
 return result

func utility_power(property:String) -> float:
 var rate:=0.0
 for e in state.items.values():
  if e.get("property","")!=property:continue
  if e.sku=="ventilation" and host.ventilation_on:rate+=host.POWER_VENTILATION_COST_PER_GAME_MINUTE
  if e.sku=="grow_light" and host.grow_lights_on:rate+=host.POWER_GROW_LIGHT_COST_PER_TENT_PER_GAME_MINUTE*.3
  if e.sku=="floor_lamp" and host.floor_lamp_on:rate+=host.POWER_LAMP_COST_PER_GAME_MINUTE
 return rate

func record_progress() -> void:
 if not state.has("progress"):state["progress"]={}
 for key in ["grow_tent_count","bagging_level","dealer_locker_level"]:state.progress[key]=maxi(int(state.progress.get(key,0)),int(host.get(key)))
