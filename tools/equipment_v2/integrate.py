from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]

def patch_main(s):
    # Preserve stable plant indices on load, including packed/sold tent tombstones.
    start=s.index('func _ensure_tent_capacity() -> void:')
    end=s.index('\nfunc ',start+5)
    s=s[:start]+'''func _ensure_tent_capacity() -> void:
	var equipment:Dictionary=location_state.get("furniture_v1",{})
	if int(equipment.get("schema",1))>=2:
		for item in equipment.get("items",{}).values():
			for slot in item.get("slots",[]):
				while plant_slots.size()<=int(slot):plant_slots.append(_empty_plant_slot())
		return
	var target_slots:int=maxi(plant_slots.size(),maxi(1,grow_tent_count)*3)
	while plant_slots.size()<target_slots:plant_slots.append(_empty_plant_slot())
''' +s[end:]
    s=s.replace('grow_tent_count = clampi(int(data.get("grow_tent_count", grow_tent_count)), 1, 3)','grow_tent_count = maxi(0,int(data.get("grow_tent_count", grow_tent_count)))')
    s=s.replace('func _sync_grow_expansion_visuals() -> void:\n','func _sync_grow_expansion_visuals() -> void:\n\tif inventory_system!=null and inventory_system.furniture!=null and int(inventory_system.furniture.model.state.get("schema",1))>=2:return\n',1)
    for name in ['_plant_seed','_water_plant','_fertilize_plant','_harvest_plant']:
        import re
        m=re.search(r'func '+name+r'\(slot_index: int[^\n]*\n',s)
        if m:s=s[:m.end()]+'''\tif inventory_system!=null and inventory_system.furniture!=null and not inventory_system.furniture.model.can_plant(slot_index):return
'''+s[m.end():]
    s=s.replace('func _update_plant_visual(slot_index: int) -> void:\n','func _update_plant_visual(slot_index: int) -> void:\n\tif inventory_system!=null and inventory_system.furniture!=null and not inventory_system.furniture.model.can_plant(slot_index):\n\t\tif slot_index<plant_visuals.size():plant_visuals[slot_index].hide()\n\t\treturn\n',1)
    # Stock produced by a harvest belongs to that tent's property bench (or backpack if absent).
    s=s.replace('_add_inventory(untrimmed_inventory, strain_name, harvest_amount)','''if inventory_system!=null and inventory_system.furniture!=null:
		inventory_system.equipment_harvest(slot_index,strain_name,harvest_amount)
	else:_add_inventory(untrimmed_inventory, strain_name, harvest_amount)''')
    # Per-slot water billing on manual and live auto/worker care.
    s=s.replace('_charge_water_use(1)','_charge_water_use(1,slot_index)')
    s=s.replace('func _charge_water_use(count: int = 1) -> void:','func _charge_water_use(count: int = 1, slot_index:int = -1) -> void:')
    s=s.replace('neighborhood.location_ops.charge_water_use(count)','''if slot_index>=0 and inventory_system!=null and inventory_system.furniture!=null:
			var property:String=inventory_system.furniture.model.slot_property(slot_index)
			if property in ["apartment","house"]:
				var ledger:Dictionary=neighborhood.location_ops.utility_state(property)
				ledger.water_uses=int(ledger.get("water_uses",0))+count
				ledger.today_water=float(ledger.get("today_water",0.0))+WATER_COST_PER_WATERING*count
				neighborhood.location_ops._sync_legacy_utility_totals()
				return
		neighborhood.location_ops.charge_water_use(count)''')
    # Worker must never fill a removed station or plant in a packed tent.
    s=s.replace('func _assign_production_worker_task() -> void:\n','func _assign_production_worker_task() -> void:\n\tif inventory_system!=null and not inventory_system.worker_equipment_ready():production_worker_pending_action="";production_worker_task="Equipment unavailable";return\n',1)
    s=s.replace('func _execute_production_worker_action() -> void:\n','func _execute_production_worker_action() -> void:\n\tif inventory_system!=null and not inventory_system.worker_equipment_ready():production_worker_pending_action="";return\n',1)
    s=s.replace('if int(plant_slots[slot_index].get("stage", -1)) < 0:', 'if int(plant_slots[slot_index].get("stage", -1)) < 0 and (inventory_system==null or inventory_system.furniture==null or inventory_system.furniture.model.can_plant(slot_index)):')
    return s

def patch_inventory(s):
    s=s.replace('var furniture:Node','var furniture:Node\nvar equipment_positions:Dictionary={}')
    s=s.replace('func title(id:String) -> String:\n','func title(id:String) -> String:\n if id.ends_with(":delivery"):return id.get_slice(":",0).capitalize()+" · Curbside Delivery"\n if furniture!=null and furniture.model!=null:\n  var asset:String=furniture.model.container_item(id)\n  if not asset.is_empty():return id.get_slice(":",0).capitalize()+" · "+furniture.model.item_name(asset)\n',1)
    s=s.replace('func item_name(item:String) -> String:\n','func item_name(item:String) -> String:\n if category(item)=="furniture" and furniture.model.state.items.has(item.get_slice("|",1)):return furniture.model.item_name(item.get_slice("|",1))+" · Packed"\n',1)
    s=s.replace('var result:Dictionary={}\n if id=="market:orders":','''var result:Dictionary={}
 if furniture!=null and furniture.model!=null:
  for asset in furniture.model.state.items:
   if furniture.model.state.items[asset].get("property","")==id:result["furniture|"+asset]=1
 if id.ends_with(":delivery"):return result
 if id=="market:orders":''',1)
    s=s.replace('result=state.backpack.duplicate(true)','result.merge(state.backpack.duplicate(true))')
    s=s.replace('result=state.containers[id].duplicate(true)','result.merge(state.containers[id].duplicate(true))')
    s=s.replace('if id.get_slice(":",0)!=operation():return result','if not primary_container(id):return result')
    s=s.replace('if id.get_slice(":",0)==operation():','if primary_container(id):')
    s=s.replace('func set_amount(id:String,item:String,n:int) -> void:\n','''func set_amount(id:String,item:String,n:int) -> void:
 if category(item)=="furniture":
  var asset:String=item.get_slice("|",1)
  if furniture.model.state.items.has(asset):furniture.model.state.items[asset].property=id if n>0 else "transfer"
  return
''',1)
    s=s.replace('["equipment","delivery"]','["equipment","delivery","furniture"]')
    s=s.replace('if id=="market:orders":return false','if id=="market:orders" or id.ends_with(":delivery"):return false')
    s=s.replace('func capacity(id:String,item:String) -> int:\n','''func capacity(id:String,item:String) -> int:
 if furniture!=null and id!="backpack":
  var asset:String=furniture.model.container_item(id)
  if not asset.is_empty():
   var spec:Dictionary=furniture.model.CATALOG[furniture.model.state.items[asset].sku]
   var kind:String=spec.get("kind","");var tier:int=int(spec.get("tier",1))
   if kind=="supply":return [12,24,48][clampi(tier-1,0,2)] if group(item)=="seeds" else [20,40,80][clampi(tier-1,0,2)]
   if kind=="packing":return 2000
   return 12 if group(item)=="equipment" else int(spec.get("capacity",40))
''',1)
    s=s.replace('func unit_weight(item:String) -> int:\n','func unit_weight(item:String) -> int:\n if category(item)=="furniture" and furniture.model.state.items.has(item.get_slice("|",1)):return int(furniture.model.CATALOG[furniture.model.state.items[item.get_slice("|",1)].sku].get("weight",8))*POUND\n',1)
    # Container kinds can carry an instance suffix; canonical primary remains the host's live adapter.
    s=s.replace('id.get_slice(":",1)','container_kind(id)')
    start=s.index('func reachable(id:String) -> bool:');end=s.index('func transfer(',start)
    s=s[:start]+'''func reachable(id:String) -> bool:
 if not controlled(id):return false
 var positions:Dictionary=all_positions()
 if not positions.has(id):return false
 var position:Vector3=host.camera.global_position
 if host.neighborhood.get("in_station")==true:position=host.neighborhood.walk_position
 return position.distance_to(positions[id])<=3.1
func near_container() -> String:
 var best:="";var distance:=3.1
 var positions:Dictionary=all_positions()
 for id in positions:
  if not controlled(id):continue
  var delta:Vector3=positions[id]-host.camera.global_position
  if delta.length()<distance and (-host.camera.global_basis.z).dot(delta.normalized())>.55:
   if host.neighborhood.has_method("_door_line_clear") and not host.neighborhood._door_line_clear(positions[id]):continue
   best=id;distance=delta.length()
 return best
''' +s[end:]
    s=s.replace('func render_inspector() -> void:\n','func render_inspector() -> void:\n',1)
    s=s.replace(' if container_id.is_empty():\n  var hint:', ''' if category(selected)=="furniture" and selected_source=="backpack":
  var asset:String=selected.get_slice("|",1)
  button("Place item",func():close();furniture.begin(asset),text_box,true)
  if reachable("market:orders"):
   button("Sell to market · $%d"%furniture.model.resale(asset),func():
    if furniture.model.sell(asset):selected="";render()
    else:notice.text=furniture.model.error,text_box)
 if container_id.is_empty():
  var hint:''',1)
    s=s.replace('if category(selected)=="delivery":hint=', 'if category(selected)=="furniture":hint="Place your item in a property you hold."\n  elif category(selected)=="delivery":hint=')
    s=s.replace('"delivery":"equipment","cash"','"delivery":"equipment","furniture":"equipment","cash"')
    s=s.replace('if native_station_target(target) or (not nearby.is_empty() and target.is_empty()):world.action.hide()','if not nearby.is_empty() or native_station_target(target):world.action.hide()')
    s=s.replace('elif not target.is_empty():nearby_button.hide()','elif not target.is_empty() and nearby.is_empty():nearby_button.hide()')
    s += '''
func container_kind(id:String) -> String:return id.get_slice(":",1).get_slice("@",0)
func primary_container(id:String) -> bool:return id==operation()+":"+container_kind(id)
func all_positions() -> Dictionary:
 var result:Dictionary={"market:orders":POSITIONS["market:orders"]}
 if furniture==null or furniture.model==null:return POSITIONS.duplicate()
 for property in furniture.model.CURBS:
  if not contents(property+":delivery").is_empty():result[property+":delivery"]=furniture.model.CURBS[property]+Vector3.UP
 for asset in furniture.model.state.items:
  var e:Dictionary=furniture.model.state.items[asset]
  if e.get("property","") not in furniture.model.ROOMS or not e.has("position"):continue
  var id:String=furniture.model.container_of(asset)
  if id.is_empty():continue
  result[id]=Vector3(e.position[0],1.2,e.position[2])
 return result
func equipment_harvest(slot:int,strain:String,amount:int) -> void:
 var property:String=furniture.model.slot_property(slot)
 var target:String=property+":packing"
 if furniture.model.primary(property,"packing").is_empty():target="backpack"
 var item:String="raw|"+strain
 set_amount(target,item,int(contents(target).get(item,0))+amount)
 revision+=1
func worker_equipment_ready() -> bool:
 if furniture==null:return true
 for kind in ["packing","supply","storage"]:
  if furniture.model.primary(operation(),kind).is_empty():return false
 return true
'''
    return s

def patch_editor(s):
    s=s.replace('var chapter:RefCounted','var chapter:RefCounted\nvar equipment_world:Node\nvar delivery_property:="backpack"')
    s=s.replace('layer=CanvasLayer.new();','equipment_world=load("res://scripts/equipment_world.gd").new();add_child(equipment_world);equipment_world.setup(self)\n layer=CanvasLayer.new();',1)
    start=s.index('func sync_world() -> void:');end=s.index('func piece(',start)
    s=s[:start]+'''func sync_world() -> void:
 if equipment_world!=null:equipment_world.sync()
''' +s[end:]
    # Existing collision query excludes owned rendered geometry through furniture_id.
    s=s.replace('if model.live(id):hint.text="Harvest or clear the plants before moving this tent.";selected="";return','if not model.empty_reason(id).is_empty():hint.text=model.empty_reason(id);selected="";return')
    s=s.replace('ghost=MeshInstance3D.new();','ghost=MeshInstance3D.new();',1)
    start=s.index('func render_list() -> void:');end=s.index('func begin(',start)
    s=s[:start]+'''func render_list() -> void:
 restore_camera();clear();hint.text="FURNITURE & EQUIPMENT"
 inventory.label("Empty and unlock equipment before picking it up. Packed items go into your backpack with their upgrades intact.",list)
 for id in model.state.items:
  var e:Dictionary=model.state.items[id]
  inventory.label(model.item_name(id)+" · "+str(e.get("property","backpack")).capitalize(),list)
  var reason:String=model.empty_reason(id)
  if not reason.is_empty():inventory.label(reason,list,13)
  var row:=HBoxContainer.new();list.add_child(row)
  if e.get("property","") in model.ROOMS:
   inventory.button("Unlock" if e.get("locked",false) else "Lock",func():model.lock(id,not bool(e.get("locked",false)));render_list(),row)
   inventory.button("Move",begin.bind(id),row).disabled=bool(e.get("locked",false)) or not reason.is_empty()
   inventory.button("Pick up",func():
    if model.pack(id):render_list()
    else:hint.text=model.error,row).disabled=bool(e.get("locked",false)) or not reason.is_empty()
  elif e.get("property","")=="backpack":inventory.button("Place",begin.bind(id),row)
  var upgrade:String=model.next_upgrade(id)
  if not upgrade.is_empty() and e.get("property","") in ["apartment","house","backpack"]:
   inventory.button("Upgrade to %s · $%d"%[model.CATALOG[upgrade].name,model.CATALOG[upgrade].price-model.CATALOG[e.sku].price],func():
    if model.upgrade(id):render_list()
    else:hint.text=model.error,list).disabled=not reason.is_empty()
func shop(shop_id:String) -> void:
 open();clear();hint.text="CENTRAL MARKET / "+shop_id.to_upper()
 inventory.label("Buy packed items or order a box to a property's curb. Select packed items in Backpack to place them.",list)
 var choices:=HBoxContainer.new();list.add_child(choices)
 for destination in ["backpack","apartment","house"]:
  if destination!="backpack" and not model.controlled(destination):continue
  inventory.button(("✓ " if delivery_property==destination else "")+destination.capitalize(),func():delivery_property=destination;shop(shop_id),choices)
 for sku in model.CATALOG:
  var item:Dictionary=model.CATALOG[sku]
  if item.shop!=shop_id:continue
  inventory.label("%s · $%d · %d lb"%[item.name,model.price_for(sku),item.get("weight",8)],list,18)
  if model.is_tent({"sku":sku}):inventory.label("%d plants · grow rooms only"%item.plants,list,14)
  inventory.button("Buy / order",func():
   var id:String=model.own(sku,delivery_property)
   if id.is_empty():hint.text=model.error
   else:shop(shop_id);hint.text="Packed item added to backpack." if delivery_property=="backpack" else "Delivery ready at the "+delivery_property+" curb.",list).disabled=host.cash<model.price_for(sku)
 inventory.button("Back to market",func():close();host.neighborhood.location_ops.market(),list)
 inventory.button("Sell packed equipment",sell_menu,list)
func sell_menu() -> void:
 open();clear();hint.text="MARKET BUYBACK · 50% OF EQUIPMENT VALUE"
 for id in model.state.items:
  if model.state.items[id].get("property","")!="backpack":continue
  inventory.button("Sell %s · $%d"%[model.item_name(id),model.resale(id)],func():
   if model.sell(id):sell_menu()
   else:hint.text=model.error,list)
''' +s[end:]
    # New models; existing migrated station art is retained by equipment_world.
    s=s.replace('if sku in ["coffee_table","dining_table"]:', '''if sku.begins_with("bench_"):
  piece(root,id,Vector3(0,s.y-.08,0),Vector3(s.x,.12,s.z),"92744d")
  for x in [-1,1]:
   for z in [-1,1]:piece(root,id,Vector3(x*(s.x/2-.1),s.y/2, z*(s.z/2-.1)),Vector3(.08,s.y,.08),"384344")
  piece(root,id,Vector3(-.35,s.y,.05),Vector3(.4,.08,.35),"a5afad")
  piece(root,id,Vector3(.35,s.y,.05),Vector3(.35,.06,.25),"465246")
 elif sku.begins_with("shelf_") or sku.begins_with("storage_") or sku.begins_with("dealer_"):
  for x in [-1,1]:piece(root,id,Vector3(x*(s.x/2-.04),s.y/2,0),Vector3(.08,s.y,s.z),"354443")
  for i in range(4):piece(root,id,Vector3(0,.1+i*(s.y-.15)/3,0),Vector3(s.x,.07,s.z),"82917c")
  piece(root,id,Vector3(0,s.y/2,-s.z/2+.03),Vector3(s.x,s.y,.06),"263231")
 elif sku in ["floor_lamp","grow_light"]:
  piece(root,id,Vector3(0,.05,0),Vector3(.45,.1,.45),"394444")
  piece(root,id,Vector3(0,s.y/2,0),Vector3(.06,s.y,.06),"64716b")
  piece(root,id,Vector3(0,s.y-.1,0),Vector3(.5,.15,.45),"e9e7c9")
 elif sku=="computer":
  piece(root,id,Vector3(0,.85,0),Vector3(s.x,.1,s.z),"8b7353")
  for x in [-1,1]:piece(root,id,Vector3(x*.6,.4,0),Vector3(.08,.8,.65),"344440")
  piece(root,id,Vector3(0,1.2,-.15),Vector3(.85,.5,.06),"285d44")
 elif sku in ["water_kit","ventilation"]:
  piece(root,id,Vector3(0,s.y/2,0),s,"526466")
  piece(root,id,Vector3(0,s.y*.6,s.z/2),Vector3(s.x*.6,s.y*.4,.025),"253532")
 elif sku in ["coffee_table","dining_table"]:''')
    return s

def patch_ops(s):
    start=s.index('func equipment() -> void:');end=s.index('\nfunc ',start+5)
    s=s[:start]+'''func equipment() -> void:
	clear("CENTRAL MARKET - EQUIPMENT");market_navigation()
	b("Grow tents · 1 / 2 / 3 / 4 plants",market_grow_tents)
	b("Stations, upgraded equipment & utilities",func():host.inventory_system.furniture.shop("equipment"))
	b("Furniture",market_furniture)
	b("Sell packed equipment",func():host.inventory_system.furniture.sell_menu())
''' +s[end:]
    s=s.replace('func order_equipment(name: String) -> void:\n','func order_equipment(name: String) -> void:\n\tif host.inventory_system!=null and host.inventory_system.furniture!=null:equipment();return\n',1)
    s=s.replace('func order_dealer() -> void:\n','func order_dealer() -> void:\n\tif host.inventory_system!=null and host.inventory_system.furniture!=null:host.inventory_system.furniture.shop("equipment");return\n',1)
    s=s.replace('func install_property_storage_at(property:String) -> void:\n','func install_property_storage_at(property:String) -> void:\n\tif host.inventory_system!=null and host.inventory_system.furniture!=null:host.inventory_system.furniture.open();return\n',1)
    s=s.replace('func pack_apartment_paid_assets() -> void:\n','func pack_apartment_paid_assets() -> void:\n\tif host.inventory_system!=null and host.inventory_system.furniture!=null:host.inventory_system.furniture.open();return\n',1)
    s=s.replace('func _apartment_paid_equipment_labels() -> Array[String]:\n','func _apartment_paid_equipment_labels() -> Array[String]:\n\tif host.inventory_system!=null and host.inventory_system.furniture!=null:return []\n',1)
    # Online orders use the same physical item catalog and explicit destination buttons.
    s=s.replace('func phone_supplies() -> void:\n','func phone_supplies() -> void:\n',1)
    loc=s.index('func phone_supplies()');end=s.find('\nfunc ',loc+5)
    block=s[loc:end]
    block += '\n\tb("Order furniture / curbside delivery",func():host.inventory_system.furniture.shop("furniture"))\n\tb("Order equipment / curbside delivery",func():host.inventory_system.furniture.shop("equipment"))\n\tb("Order grow tents",market_grow_tents)\n'
    s=s[:loc]+block+s[end:]
    return s

def patch_packing(s):
    s=s.replace('var active:=false','var active:=false\nvar station_id:=""\nvar station_tier:=1')
    s=s.replace(' var stock:Dictionary=host.untrimmed_inventory if category=="raw" else host.trimmed_inventory\n var available:int=int(stock.get(name,0))',''' station_id=inventory.container_id if inventory.container_kind(inventory.container_id)=="packing" else inventory.operation()+":packing"
 var asset:String=inventory.furniture.model.container_item(station_id)
 if asset.is_empty() or not inventory.reachable(station_id):return
 station_tier=int(inventory.furniture.model.CATALOG[inventory.furniture.model.state.items[asset].sku].get("tier",1))
 var available:int=int(inventory.contents(station_id).get(item,0))''')
    s=s.replace('host._packing_batch_size()','[4,6,12][clampi(station_tier-1,0,2)]').replace('host._packing_drop_size()','(1 if station_tier==1 else host.rng.randi_range(1,2 if station_tier==2 else 4))')
    s=s.replace('surface.position=Vector3(3.56,1.28,1.29) if apartment else Vector3(39.6,1.175,-4.2)','surface.position=inventory.all_positions()[station_id]')
    s=s.replace('var available:int=int(host.untrimmed_inventory.get(strain,0))','var available:int=int(inventory.contents(station_id).get("raw|"+strain,0))')
    s=s.replace('host.untrimmed_inventory[strain]=available-moved','inventory.set_amount(station_id,"raw|"+strain,available-moved)')
    s=s.replace('host._add_inventory(host.trimmed_inventory,strain,moved)','inventory.set_amount(station_id,"trimmed|"+strain,int(inventory.contents(station_id).get("trimmed|"+strain,0))+moved)')
    s=s.replace('int(host.trimmed_inventory.get(strain,0))','int(inventory.contents(station_id).get("trimmed|"+strain,0))')
    s=s.replace('host.trimmed_inventory[strain]=available-moved','inventory.set_amount(station_id,"trimmed|"+strain,available-moved)')
    s=s.replace('host._add_inventory(host.bagged_inventory,strain,moved)','inventory.set_amount(station_id,"product|"+strain,int(inventory.contents(station_id).get("product|"+strain,0))+moved)')
    s=s.replace('host.bagging_level>=3','station_tier>=3').replace('int(host.trimmed_inventory[strain])','int(inventory.contents(station_id).get("trimmed|"+strain,0))')
    return s

def finish_main(s):
    # No old purchase path may spawn replacement tents or silently discard owned stations.
    for signature in ['func _buy_supply(supply_name: String) -> void:', 'func _buy_dealer_locker_upgrade() -> void:']:
        if signature in s:
            condition='supply_name != "Fertilizer Pack"' if 'supply_name' in signature else 'true'
            s=s.replace(signature+'\n',signature+'\n\tif '+condition+' and inventory_system!=null and inventory_system.furniture!=null:\n\t\tinventory_system.furniture.shop("equipment");return\n',1)
    # Capacities follow an installed station; removing it does not leave a usable ghost station.
    for signature,kind,item in [('func _storage_capacity() -> int:','storage','product|Street Green'),('func _dealer_locker_capacity() -> int:','dealer','product|Street Green'),('func _supply_seed_capacity() -> int:','supply','seed|Street Green'),('func _supply_fertilizer_capacity() -> int:','supply','fertilizer')]:
        s=s.replace(signature+'\n',signature+'\n\tif inventory_system!=null and inventory_system.furniture!=null:\n\t\tvar id:String=inventory_system.operation()+":'+kind+'"\n\t\tif inventory_system.furniture.model.container_item(id).is_empty():return 0\n\t\treturn inventory_system.capacity(id,"'+item+'")\n',1)
    # The old upgrade phone page is now the owned equipment manager.
    if 'func _phone_upgrades() -> void:' in s:
        s=s.replace('func _phone_upgrades() -> void:\n','func _phone_upgrades() -> void:\n\tif inventory_system!=null and inventory_system.furniture!=null:inventory_system.furniture.open();return\n',1)
    s=s.replace('inventory_system.equipment_harvest(slot_index,strain_name,harvest_amount)','if not inventory_system.equipment_harvest(slot_index,strain_name,harvest_amount):\n\t\t\tstatus_label.text="Make room in your backpack or place an empty packing bench before harvesting.";return')
    # Persisted tent quality follows that tent, rather than every tent in the operation.
    s=s.replace('if tent_level >= 2:\n\t\tharvest_amount', 'if (inventory_system.furniture.model.tent_quality(slot_index) if inventory_system!=null else tent_level) >= 2:\n\t\tharvest_amount')
    return s

def patch_growth(s):
    s=s.replace('func _plant_growth_settings(offline: bool) -> Dictionary:\n\treturn {','func _plant_growth_settings(offline: bool, slot_index:int = -1) -> Dictionary:\n\tvar settings:Dictionary = {',1)
    a=s.index('func _plant_growth_settings(');b=s.index('\nfunc ',a+5)
    s=s[:b]+'''
	if inventory_system!=null and inventory_system.furniture!=null:
		var model=inventory_system.furniture.model
		if slot_index>=0:return model.growth_settings(slot_index,settings,offline)
		settings["per_slot"]=[];settings["care_slots"]=[]
		for i in range(plant_slots.size()):
			settings.per_slot.append(model.growth_settings(i,settings,offline))
			settings.care_slots.append(model.slot_property(i)==inventory_system.operation())
	return settings
'''+s[b:]
    s=s.replace('_plant_growth_settings(false))','_plant_growth_settings(false,slot_index))')
    s=s.replace('if auto_water_unlocked and before_stage >= 0','if bool(_plant_growth_settings(false,slot_index).auto_water) and before_stage >= 0')
    s=s.replace('if offline_waterings > 0:\n\t\t_charge_water_use(offline_waterings)','if offline_waterings > 0:\n\t\tfor watered_slot in result.get("water_by_slot",{}):_charge_water_use(int(result.water_by_slot[watered_slot]),int(watered_slot))')
    return s

def patch_offline(s):
    s=s.replace('var waterings: int = 0','var waterings: int = 0\n\tvar water_by_slot:Dictionary={}',1)
    s=s.replace('PlantGrowth.advance(slots[i], elapsed_seconds, settings)','PlantGrowth.advance(slots[i], elapsed_seconds, settings.get("per_slot",[])[i] if i<settings.get("per_slot",[]).size() else settings)')
    s=s.replace('PlantGrowth.advance(slots[i], step, settings)','PlantGrowth.advance(slots[i], step, settings.get("per_slot",[])[i] if i<settings.get("per_slot",[]).size() else settings)')
    s=s.replace('if _growing(slots[i]) and float','if (i>=settings.get("care_slots",[]).size() or settings.care_slots[i]) and _growing(slots[i]) and float')
    s=s.replace('if _growing(slot) and int','if (i>=settings.get("care_slots",[]).size() or settings.care_slots[i]) and _growing(slot) and int')
    s=s.replace('waterings += 1','waterings += 1\n\t\t\t\t\twater_by_slot[target]=int(water_by_slot.get(target,0))+1')
    s=s.replace('return {"plants": slots,','return {"water_by_slot":water_by_slot,"plants": slots,')
    return s

def patch_neighborhood(s):
    s=s.replace('if _indoors(host.camera.position) and Vector2(host.camera.position.x+2.28,host.camera.position.z-3.07).length()<2.0:return "couch"','if host.inventory_system!=null and not host.inventory_system.furniture.equipment_world.nearby_seat().is_empty():return "couch"')
    s=s.replace('Seating.eyes(Vector3(-1.785,0,3.035),0,ScalePolicy.SEAT_HEIGHT)','host.inventory_system.furniture.equipment_world.seat_eye()')
    return s

def patch_story(s):
    a=s.index('func _story_chapter_two_complete()');z=s.index('func _chapter_four_target_story_stage()',a)
    chunk=s[a:z]
    for key in ['grow_tent_count','bagging_level','dealer_locker_level']:
        chunk=chunk.replace(key+' >=','maxi('+key+',int(location_state.get("furniture_v1",{}).get("progress",{}).get("'+key+'",0))) >=')
    return s[:a]+chunk+s[z:]

def restore_cabinet_hooks(s):
 for fn in ['_sync_storage_furniture','_sync_dealer_locker_visual']:
  sig='func '+fn+'() -> void:\n'
  s=s.replace(sig,sig+'\tif inventory_system!=null and inventory_system.furniture!=null and inventory_system.furniture.equipment_world!=null:\n\t\tinventory_system.furniture.sync_world();return\n',1)
 for fn,kind in [('_set_hidden_stash_open','storage'),('_set_premium_dealer_locker_open','dealer')]:
  sig='func '+fn+'(opened: bool) -> void:\n'
  s=s.replace(sig,sig+'\tif inventory_system!=null and inventory_system.furniture!=null and inventory_system.furniture.equipment_world!=null:\n\t\tvar target:String=inventory_system.container_id\n\t\tif target.is_empty():target=inventory_system.operation()+":'+kind+'"\n\t\tinventory_system.furniture.equipment_world.animate_container(target,opened);return\n',1)
 return s
