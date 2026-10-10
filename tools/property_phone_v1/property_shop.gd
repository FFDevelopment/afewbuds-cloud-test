extends RefCounted
## Per-property operations; additive state lives in the existing location save.
var host:Node3D
var crew:RefCounted:
	get:return host.neighborhood.location_ops.crew
const HOUSE_LIGHTS=["living","packing","entry_hall","cross_hall","kitchen","bathroom","bedroom","grow","grow_lights","grow_ventilation"]
const APARTMENT_LIGHTS=["main_ceiling_light_on","floor_lamp_on","grow_room_light_on","grow_lights_on","ventilation_on"]
func setup(owner:Node3D,_team:RefCounted) -> void:
	host=owner
func record(property:String) -> Dictionary:
	if not host.location_state.get("property_shop",{}) is Dictionary:host.location_state["property_shop"]={}
	if not host.location_state.has("property_shop"):host.location_state["property_shop"]={}
	var all:Dictionary=host.location_state.property_shop
	if not all.get(property,{}) is Dictionary or not all.has(property):all[property]={}
	return all[property]
func laying_low(property:String) -> bool:
	return host.lay_low_active if property=="apartment" else bool(record(property).get("lay_low",false))
func is_open(property:String) -> bool:
	return (host.business_open if property=="apartment" else bool(record(property).get("open",true))) and not laying_low(property)
func status(property:String) -> String:
	return "LAYING LOW" if laying_low(property) else ("OPEN" if is_open(property) else "CLOSED")
func on_duty(name:String) -> bool:
	var role:String=crew.role(name)
	if role=="production":return host.packing_employee_active and not host.production_worker_arrested
	return role=="dealer" and host.dealers_active and not host.dealer_arrested and crew.ops.portfolio_staff_duty(name)
func operator_for(property:String) -> String:
	for name in crew.roster():
		if crew.assignment(name)==property and on_duty(name):return name
	return ""
func production_allowed() -> bool:
	return not laying_low(host.inventory_system.worker_property())
func dealer_allowed(name:String) -> bool:
	return on_duty(name) and is_open(crew.assignment(name))
func snapshot(property:String) -> Dictionary:
	var result:Dictionary={"lights":{},"shades":{}}
	var controls:RefCounted=crew.world.house_controls
	if property=="apartment":
		for key in APARTMENT_LIGHTS:result.lights[key]=bool(host.get(key))
	else:
		for key in HOUSE_LIGHTS:result.lights[key]=bool(controls.states.get(key,false if key.begins_with("grow_") else true))
	for key in controls.shades:
		if (key=="ApartmentBlind")==(property=="apartment"):result.shades[key]=bool(controls.shades[key].closed)
	return result
func apply_equipment(property:String,settings:Dictionary,shutdown:bool) -> void:
	var controls:RefCounted=crew.world.house_controls
	for key in settings.get("lights",{}):
		var value:bool=false if shutdown else bool(settings.lights[key])
		if property=="apartment":host.set(key,value)
		else:
			controls.states[key]=value
			if controls.switches.has(key) and key!="grow_ventilation":controls._set_light(key,value)
	for key in settings.get("shades",{}):
		var value:bool=true if shutdown else bool(settings.shades[key])
		controls.states[key]=value
		if controls.shades.has(key):
			controls.shades[key].closed=value
			controls.shades[key].node.scale.y=1.0 if value else 0.055
	host.house_control_state=controls.states.duplicate(true)
	controls._sync_house_ventilation();controls.refresh_grow_panel()
	host._refresh_light_interaction_visuals();host._update_day_night_visuals()
	if host.inventory_system.furniture!=null:host.inventory_system.furniture.equipment_world.sync()
func close_property(property:String) -> void:
	# The existing apartment customer queue remains authoritative. Inventory
	# adapters are restored before saving, including when another property is primary.
	if property=="apartment":
		var previous:String=host.inventory_system.operation()
		host.inventory_system.activate_adapters("apartment")
		host.phone_remote_stock_change=true
		host._set_business_away()
		host.phone_remote_stock_change=false
		host.inventory_system.activate_adapters(previous)
	else:record(property)["open"]=false
func shutdown(property:String="apartment") -> void:
	if not crew.ops._property_controlled(property):return
	var data:Dictionary=record(property)
	if not laying_low(property):data["equipment_before_shutdown"]=snapshot(property)
	# Existing legacy lay-low saves have no snapshot: don't invent ON settings.
	if not data.has("equipment_before_shutdown"):data["equipment_before_shutdown"]=snapshot(property)
	close_property(property)
	data["lay_low"]=true;data["open"]=false
	if property=="apartment":host.lay_low_active=true;host.reeves_quiet_pause_seconds=0.0
	apply_equipment(property,data.equipment_before_shutdown,true)
	if host.inventory_system.worker_property()==property:
		host.production_worker_pending_action="";host.production_worker_pending_slot=-1
		host.production_worker_task="Laying low · "+property.capitalize()
		host.production_worker_last_action=host.production_worker_task
		host._reset_production_worker_navigation()
	# Keep duty assignments; the property gate suspends work without sending the
	# only worker home and making a remote Set Up command impossible.
	host.status_label.text=property.capitalize()+" shut down. Lights, ventilation and sales are off."
	host._save_game();host._refresh_phone()
func reopen(property:String) -> bool:
	if host._staff_heat_locked() or host.game_day<host.raid_lockdown_until_day:return false
	var data:Dictionary=record(property)
	if data.has("equipment_before_shutdown"):
		apply_equipment(property,data.equipment_before_shutdown,false)
		data.erase("equipment_before_shutdown")
	data["lay_low"]=false;data["open"]=true
	if property=="apartment":
		host.lay_low_active=false;host.reeves_quiet_pause_seconds=0.0
		var previous:String=host.inventory_system.operation()
		host.inventory_system.activate_adapters("apartment")
		host.phone_remote_stock_change=true
		host._reopen_business()
		host.phone_remote_stock_change=false
		host.inventory_system.activate_adapters(previous)
	host._save_game();host._refresh_phone()
	return true
func command(name:String,action:String) -> void:
	var property:String=crew.assignment(name)
	var context:Dictionary={"property":property,"status":status(property).to_lower()}
	var restoring:bool=laying_low(property)
	if crew.role(name).is_empty() or not crew.ops._property_controlled(property):return
	if action=="status":
		crew.send(name,crew.say(name,"status",context));return
	if action not in ["close","open","shutdown","reopen"]:return
	if not on_duty(name):
		crew.send(name,crew.say(name,"off_duty",context));return
	crew.outgoing(name,{"close":"Close shop for clients.","open":"Open shop again.","shutdown":"Shut down shop and lay low.","reopen":"Restore the equipment and set up shop again."}[action])
	if action=="close":
		close_property(property)
		crew.send(name,crew.say(name,"closed",context))
	elif action=="shutdown":
		shutdown(property)
		crew.send(name,crew.say(name,"shutdown",context))
	else:
		if action=="open" and laying_low(property):crew.send(name,crew.say(name,"setup_first",context));return
		if not reopen(property):crew.send(name,crew.say(name,"blocked",context));return
		crew.send(name,crew.say(name,"restored" if restoring else "opened",context))
	host._save_game();host._refresh_phone()
func render(parent:VBoxContainer,property:String) -> void:
	crew.label(parent,"SHOP OPERATIONS · "+status(property))
	var name:String=operator_for(property)
	crew.label(parent,"Assigned operator: "+name if not name.is_empty() else "Put an employee at this property on duty to manage the shop remotely.")
	if laying_low(property):crew.button(parent,"SET UP SHOP & OPEN",command.bind(name,"reopen"),name.is_empty())
	else:
		crew.button(parent,"CLOSE SHOP" if is_open(property) else "OPEN SHOP",command.bind(name,"close" if is_open(property) else "open"),name.is_empty())
		crew.button(parent,"SHUT DOWN SHOP & LAY LOW",command.bind(name,"shutdown"),name.is_empty())
	crew.label(parent,"Close stops new sales. Lay Low also shuts down equipment. Set Up restores the settings from before shutdown.")
