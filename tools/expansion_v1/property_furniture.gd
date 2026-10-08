extends RefCounted
## Persistent ownership and placement rules. Runtime/UI uses this same authority.
const CATALOG={
 "grow_tent":{"name":"Grow Tent","shop":"grow","price":480,"size":[3.12,2.8,1.5],"grow_only":true},
 "sofa":{"name":"Two-seat Sofa","shop":"furniture","price":350,"size":[1.9,.9,.85]},
 "armchair":{"name":"Armchair","shop":"furniture","price":180,"size":[.85,.95,.85]},
 "coffee_table":{"name":"Coffee Table","shop":"furniture","price":95,"size":[1.1,.48,.6]},
 "dining_table":{"name":"Dining Table","shop":"furniture","price":220,"size":[1.5,.78,.85]},
 "bookcase":{"name":"Bookcase","shop":"furniture","price":160,"size":[.9,1.9,.35]},
 "bed":{"name":"Double Bed","shop":"furniture","price":450,"size":[1.55,.65,2.05]}}
# Conservative usable floor rectangles; thresholds/cross halls stay clear.
const ROOMS={
 "apartment":{"main":Rect2(-4.7,-3.65,9.4,9.1),"grow":Rect2(-4.7,-10.0,9.4,5.5)},
 "house":{"living":Rect2(25.4,-4.6,7.65,7.15),"packing":Rect2(37,-4.6,7.6,7.15),"kitchen":Rect2(25.4,-13.55,5.5,6.1),"bathroom":Rect2(31.7,-13.55,2.05,6.1),"bedroom":Rect2(34.65,-13.55,3.5,6.1),"grow":Rect2(39.05,-13.55,5.55,6.1)}}
var host:Node
var state:Dictionary
var error:=""
func setup(owner:Node) -> void:
 host=owner
 if not host.location_state.get("furniture_v1",{}) is Dictionary:host.location_state["furniture_v1"]={}
 if not host.location_state.has("furniture_v1"):host.location_state["furniture_v1"]={}
 state=host.location_state.furniture_v1
 if not state.has("items"):state["items"]={}
 if not state.has("next_id"):state["next_id"]=1
 state["schema"]=1
 # Existing purchased tent capacity is an entitlement, never recharged or reduced.
 for i in range(host.grow_tent_count):
  var id:="legacy_tent_%d"%i
  if not state.items.values().any(func(e):return int(e.get("legacy_slot",-1))==i):state.items[id]={"sku":"grow_tent","legacy_slot":i,"property":"legacy","locked":true}
func controlled(property:String) -> bool:
 if property=="apartment":return bool(host.apartment_rent_state.get("lease_active",true))
 return property=="house" and bool(host.property_opportunity_state.get("acquired",false))
func tent_count() -> int:
 var count:=0
 for entry in state.items.values():
  if entry.sku=="grow_tent":count+=1
 return count
func price_for(sku:String) -> int:
 if sku=="grow_tent":return 1050 if tent_count()>=2 else 480
 return int(CATALOG[sku].price)
func own(sku:String) -> String:
 error=""
 if not CATALOG.has(sku):error="Unknown furniture.";return ""
 var price:int=price_for(sku)
 if host.cash<price:error="Not enough cash.";return ""
 if sku=="grow_tent":
  var count:int=tent_count()
  if count>=3:error="This operation supports three tents.";return ""
  var level:int=6 if count>=2 else 3
  if host.grower_level<level:error="Unlocks at Level %d."%level;return ""
  for name in host.location_state.get("deliveries",{}):
   if str(name).begins_with("Grow Tent Slot "):error="Collect and install your paid tent order first.";return ""
 var id:="furniture_%d"%int(state.next_id)
 state.next_id=int(state.next_id)+1
 state.items[id]={"sku":sku,"property":"storage","locked":false}
 host.cash-=price
 host._record_daily_expense("Furniture",price)
 save()
 return id
func size_of(id:String,yaw:int=0) -> Vector3:
 var a:Array=CATALOG[state.items[id].sku].size
 var s:=Vector3(float(a[0]),float(a[1]),float(a[2]))
 return Vector3(s.z,s.y,s.x) if posmod(yaw,180)==90 else s
func bounds(id:String,point:Vector3,yaw:int) -> Rect2:
 var s:=size_of(id,yaw)
 return Rect2(Vector2(point.x-s.x/2,point.z-s.z/2),Vector2(s.x,s.z))
func live(id:String) -> bool:
 var entry:Dictionary=state.items.get(id,{})
 if not entry.has("legacy_slot"):return false
 var start:int=int(entry.legacy_slot)*3
 for i in range(start,mini(start+3,host.plant_slots.size())):
  if int(host.plant_slots[i].get("stage",-1))>=0:return true
 return false
func validate(id:String,property:String,point:Vector3,yaw:int) -> String:
 if not state.items.has(id):return "Furniture is not owned."
 if not controlled(property):return "You do not hold this property."
 var entry:Dictionary=state.items[id]
 if bool(entry.get("locked",false)):return "Unlock the furniture first."
 if live(id):return "Harvest or clear the plants before moving this tent."
 if not point.is_finite() or absf(point.y)>.05 or yaw%90!=0:return "Place on the floor with quarter-turn rotation."
 var rect:=bounds(id,point,yaw).grow(.08)
 var room:=""
 for key in ROOMS[property]:
  if (ROOMS[property][key] as Rect2).encloses(rect):room=key;break
 if room.is_empty():return "Keep the entire item inside one room and clear of doorways."
 if bool(CATALOG[entry.sku].get("grow_only",false)) and room!="grow":return "Grow tents can only be placed in grow rooms."
 for other in state.items:
  if other==id:continue
  var e:Dictionary=state.items[other]
  if e.get("property","")!=property or not e.has("position"):continue
  var v:Array=e.position
  if rect.intersects(bounds(other,Vector3(v[0],v[1],v[2]),int(e.yaw))):return "Furniture overlaps another item."
 return ""
func place(id:String,property:String,point:Vector3,yaw:int) -> bool:
 error=validate(id,property,point,yaw)
 if not error.is_empty():return false
 var e:Dictionary=state.items[id]
 e.property=property;e.position=[point.x,0.0,point.z];e.yaw=posmod(yaw,360);e.locked=true
 if e.sku=="grow_tent" and not e.has("legacy_slot"):
  e.legacy_slot=host.grow_tent_count
  host.grow_tent_count+=1
  host._sync_grow_expansion_visuals()
 save();return true
func pack(id:String) -> bool:
 error=""
 if not state.items.has(id):return false
 var e:Dictionary=state.items[id]
 if e.get("locked",false):error="Unlock the furniture first.";return false
 if live(id):error="Harvest or clear the plants before packing the tent.";return false
 e.property="storage";e.erase("position");e.erase("yaw")
 save();return true
func lock(id:String,value:bool) -> void:
 if state.items.has(id):state.items[id].locked=value;save()
func can_plant(slot:int) -> bool:
 for e in state.items.values():
  if int(e.get("legacy_slot",-1))==slot/3:return e.get("property","")!="storage"
 return true
func powered_tent_count(property:String) -> int:
 var total:=0
 for entry in state.items.values():
  if entry.sku!="grow_tent":continue
  var placed:String=str(entry.get("property","storage"))
  if placed=="legacy":placed=str(host.location_state.get("operation_assets_property","apartment"))
  if placed==property:total+=1
 return total
func property_has_furniture(property:String) -> bool:
 for e in state.items.values():
  if e.get("property","")==property or (property=="apartment" and e.get("property","")=="legacy"):return true
 return false
func save() -> void:
 host._update_cash_ui();host._save_game()
