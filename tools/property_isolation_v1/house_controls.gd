extends RefCounted
var world: Node3D
var host: Node3D
var switches: Dictionary = {}
var shades: Dictionary = {}
var states: Dictionary = {}
var last_target := ""
var last_time := -1000
var grow_panel_label: Label3D

func setup(owner_node: Node3D) -> void:
	world=owner_node
	host=world.host
	states=host.house_control_state.duplicate(true)

func register_light(id: String, lamp: Light3D, fixture: MeshInstance3D, switch_at: Vector3, axis: Vector3 = Vector3.RIGHT, inward: Vector3 = Vector3.BACK) -> void:
	if switches.has(id):
		switches[id].extra.append({"lamp":lamp,"fixture":fixture})
		_set_light(id,bool(states.get(id,true)))
		return
	var plate: MeshInstance3D=world._interior_piece("HouseSwitch"+id,switch_at,Vector3(0.15,0.23,0.035) if axis.x!=0 else Vector3(0.035,0.23,0.15),"ded6c0")
	plate.layers=2
	plate.set_meta("no_collision",true)
	var rocker: MeshInstance3D=world._interior_piece("SwitchRocker"+id,switch_at+inward*0.026,Vector3(0.07,0.12,0.025) if axis.x!=0 else Vector3(0.025,0.12,0.07),"92a17d")
	rocker.layers=2
	rocker.set_meta("no_collision",true)
	switches[id]={"lamp":lamp,"fixture":fixture,"at":switch_at,"rocker":rocker,"energy":lamp.light_energy,"extra":[]}
	_set_light(id,bool(states.get(id,true)))

func register_grow(lamps: Array, fixtures: Array) -> void:
	var at := Vector3(38.76,1.5,-9.1)
	var panel: MeshInstance3D=world._interior_piece("HouseGrowServicePanel",at,Vector3(0.12,0.85,0.7),"46534c")
	panel.layers=2
	panel.set_meta("no_collision",true)
	grow_panel_label=Label3D.new()
	grow_panel_label.name="HouseGrowStatus"
	grow_panel_label.position=at+Vector3(0.08,0.28,0)
	grow_panel_label.font_size=20
	grow_panel_label.pixel_size=0.00125
	grow_panel_label.outline_size=4
	grow_panel_label.modulate=Color("d4f5d2")
	world.add_child(grow_panel_label)
	var rocker: MeshInstance3D=world._interior_piece("GrowServiceRocker",at+Vector3(0.08,0,0),Vector3(0.035,0.18,0.15),"92a17d")
	rocker.layers=2
	rocker.set_meta("no_collision",true)
	switches["grow_lights"]={"lamps":lamps,"fixtures":fixtures,"at":at,"rocker":rocker}
	# This is a second, independent wall-panel control. A house ventilation
	# unit must be placed inside the HOUSE grow room before it can run.
	var air_at:Vector3=at+Vector3(0,-0.28,0)
	var air_rocker:MeshInstance3D=world._interior_piece("HouseGrowVentilationRocker",air_at+Vector3(0.08,0,0),Vector3(0.035,0.14,0.15),"81918b")
	air_rocker.layers=2
	air_rocker.set_meta("no_collision",true)
	switches["grow_ventilation"]={"at":air_at,"rocker":air_rocker}
	_set_light("grow_lights",bool(states.get("grow_lights",false)))
	_sync_house_ventilation()

func grow_snapshot() -> Dictionary:
	# Placed HOUSE tents drive this panel. Legacy fixture arrays can be empty
	# even when the player owns fully usable tents with planted slots.
	var data:Dictionary={"tents":0,"capacity":0,"active":0,"ready":0,"dry":0,"dead":0,"ventilation":false,"ventilation_on":false}
	if host.inventory_system==null or host.inventory_system.furniture==null:return data
	var model:RefCounted=host.inventory_system.furniture.model
	if model==null:return data
	for entry in model.state.items.values():
		if str(entry.get("property",""))!="house" or not entry.has("position"):continue
		if str(entry.get("sku",""))=="ventilation":data.ventilation=true
		if not model.is_tent(entry):continue
		data.tents+=1
		for slot_id in entry.get("slots",[]):
			var index:int=int(slot_id)
			if index<0 or index>=host.plant_slots.size():continue
			data.capacity+=1
			var plant:Dictionary=host.plant_slots[index]
			if int(plant.get("stage",-1))<0:continue
			data.active+=1
			if bool(plant.get("dead",false)):data.dead+=1
			elif int(plant.get("stage",-1))>=host.STAGES.size()-1 or float(plant.get("growth",0.0))>=100.0:data.ready+=1
			elif float(plant.get("water",0.0))<=25.0:data.dry+=1
	data.ventilation_on=bool(data.ventilation) and bool(states.get("grow_ventilation",false))
	return data

func grow_summary() -> String:
	var status:Dictionary=grow_snapshot()
	var air:String=("RUNNING" if status.ventilation_on else "OFF") if status.ventilation else "NOT INSTALLED"
	return "HOUSE GROW · %d TENT(S) · %d/%d PLANTS · %d READY · %d DRY · %d DEAD · LIGHTS %s · AIR %s" % [status.tents,status.active,status.capacity,status.ready,status.dry,status.dead,"ON" if bool(states.get("grow_lights",false)) else "OFF",air]

func refresh_grow_panel() -> void:
	if grow_panel_label==null:return
	var status:Dictionary=grow_snapshot()
	grow_panel_label.text="HOUSE GROW   %d TENT(S)\nPLANTS %d/%d   READY %d\nLIGHTS %s   AIR %s" % [status.tents,status.active,status.capacity,status.ready,"ON" if bool(states.get("grow_lights",false)) else "OFF",("ON" if status.ventilation_on else "OFF") if status.ventilation else "NOT INSTALLED"]
	grow_panel_label.modulate=Color("f0d18d") if status.dry>0 or status.dead>0 else Color("d4f5d2")

func _sync_house_ventilation() -> void:
	if not switches.has("grow_ventilation"):return
	var live:bool=bool(grow_snapshot().ventilation_on)
	switches["grow_ventilation"].rocker.material_override=world._material("80d1ab" if live else "766b60")

func toggle_house_ventilation() -> bool:
	if not bool(grow_snapshot().ventilation):
		host.status_label.text="No ventilation unit is installed in the house grow room. Place a ventilation unit from Backpack first."
		refresh_grow_panel()
		return false
	states["grow_ventilation"]=not bool(states.get("grow_ventilation",false))
	host.house_control_state=states.duplicate(true)
	_sync_house_ventilation()
	refresh_grow_panel()
	host._save_game()
	host.status_label.text=grow_summary()
	return true

func toggle_house_grow_lights() -> bool:
	if grow_snapshot().tents<=0:
		host.status_label.text="No tents are placed in the house grow room. Install a tent from Backpack first."
		refresh_grow_panel()
		return false
	_set_light("grow_lights",not bool(states.get("grow_lights",false)))
	host.house_control_state=states.duplicate(true)
	if host.inventory_system!=null and host.inventory_system.furniture!=null:
		host.inventory_system.furniture.equipment_world.sync()
	refresh_grow_panel()
	host._save_game()
	host.status_label.text=grow_summary()
	return true

func register_shade(id: String, node: Node3D, at: Vector3, height: float) -> void:
	node.position=at+Vector3.UP*height/2
	for child in node.get_children(): child.position-=node.position
	shades[id]={"node":node,"at":at,"closed":bool(states.get(id,false if id=="ApartmentBlind" else true)),"busy":false}
	node.scale.y=1.0 if shades[id].closed else 0.055

func _set_light(id: String, on: bool) -> void:
	var spec: Dictionary=switches[id]
	if id=="grow_lights":
		for lamp in spec.lamps: lamp.visible=on
		for fixture in spec.fixtures: fixture.material_override=world._material("e5dba8" if on else "7b7a68",-1,0.35 if on else 0.0)
	else:
		for extra in spec.extra:
			extra.lamp.visible=on
			extra.fixture.material_override=world._material("e7dfc1" if on else "868477",-1,0.2 if on else 0.0)
		spec.lamp.visible=on
		spec.fixture.material_override=world._material("e7dfc1" if on else "868477",-1,0.2 if on else 0.0)
	spec.rocker.material_override=world._material("92a17d" if on else "766b60")
	states[id]=on
	if id=="grow_lights":refresh_grow_panel()

func _inside_room(point: Vector3) -> String:
	if world._indoors(point): return "apartment"
	if point.x>12 and point.x<22 and point.z> -2 and point.z<6:
		return "market_stock" if point.x<15.25 and point.z<1.1 else "market_front"
	if point.x<=25 or point.x>=45 or point.z<= -14 or point.z>=3: return ""
	if point.z> -5:
		return "living" if point.x<33.5 else ("packing" if point.x>36.5 else "entry_hall")
	if point.z> -7: return "cross_hall"
	return "kitchen" if point.x<31.3 else ("bathroom" if point.x<34.2 else ("bedroom" if point.x<38.6 else "grow"))

func _reachable(at: Vector3) -> bool:
	var offset: Vector3=at-host.camera.position
	if offset.length()>2.5 or offset.length()<0.01: return false
	if (-host.camera.global_basis.z).dot(offset.normalized())<0.4: return false
	return world._door_line_clear(at)

func nearby() -> String:
	var room := _inside_room(host.camera.position)
	if room.is_empty(): return ""
	var nearest := ""
	var nearest_distance := 2.5
	for id in switches:
		if (id==room or (id in ["grow_lights","grow_ventilation"] and room=="grow") or (id=="market_front" and room=="market_stock")) and (not id.begins_with("market_") or room=="market_stock") and _reachable(switches[id].at):
			var offset: Vector3=switches[id].at-host.camera.position
			var distance: float=offset.length()+(1.0-(-host.camera.global_basis.z).dot(offset.normalized()))*2.0
			if distance<nearest_distance:
				nearest_distance=distance
				nearest="switch_"+id
	if not nearest.is_empty(): return nearest
	for id in shades:
		var shade_room := ""
		for prefix in {"Apartment":"apartment","Grow":"grow","Packing":"packing","Living":"living","Kitchen":"kitchen","Bathroom":"bathroom","Bedroom":"bedroom"}:
			if id.begins_with(prefix): shade_room={"Apartment":"apartment","Grow":"grow","Packing":"packing","Living":"living","Kitchen":"kitchen","Bathroom":"bathroom","Bedroom":"bedroom"}[prefix]
		var offset: Vector3=shades[id].at-host.camera.position
		if room==shade_room and offset.length()<2.8 and (-host.camera.global_basis.z).dot(offset.normalized())>0.4: return "shade_"+id
	return ""

func title(target: String) -> String:
	if target.begins_with("switch_"):
		var id := target.trim_prefix("switch_")
		if id=="grow_ventilation":
			refresh_grow_panel()
			if not bool(grow_snapshot().ventilation):return "INSPECT HOUSE VENTILATION · NOT INSTALLED"
			return ("TURN OFF " if bool(grow_snapshot().ventilation_on) else "TURN ON ")+"HOUSE VENTILATION"
		if id=="grow_lights":
			refresh_grow_panel()
			if grow_snapshot().tents<=0:return "INSPECT HOUSE GROW PANEL · NO TENTS PLACED"
			return ("TURN OFF " if bool(states.get(id,false)) else "TURN ON ")+"HOUSE GROW LIGHTS · "+str(grow_snapshot().tents)+" TENT(S)"
		return ("TURN OFF " if states.get(id,true) else "TURN ON ")+("GROW LIGHTS" if id=="grow_lights" else id.replace("_"," ").to_upper()+" LIGHT")
	var id := target.trim_prefix("shade_")
	return "OPEN WINDOW COVERING" if shades[id].closed else "CLOSE WINDOW COVERING"

func use(target: String) -> void:
	if target!=nearby(): return
	if target.begins_with("switch_"):
		var id := target.trim_prefix("switch_")
		if id=="grow_ventilation":
			toggle_house_ventilation()
			return
		if id=="grow_lights":
			toggle_house_grow_lights()
			return
		_set_light(id,not bool(states.get(id,true)))
	else:
		var id := target.trim_prefix("shade_")
		var spec: Dictionary=shades[id]
		if spec.busy: return
		spec.busy=true
		spec.closed=not spec.closed
		states[id]=spec.closed
		var tween: Tween=world.create_tween()
		tween.tween_property(spec.node,"scale:y",1.0 if spec.closed else 0.055,0.35)
		tween.finished.connect(func(): spec.busy=false)
	host.house_control_state=states.duplicate(true)
	host._save_game()
	host.status_label.text=title(target)

func tap(point: Vector2) -> bool:
	var target := nearby()
	if target.is_empty(): return false
	var id := target.trim_prefix("switch_").trim_prefix("shade_")
	var at: Vector3=switches[id].at if target.begins_with("switch_") else shades[id].at
	if host.camera.unproject_position(at).distance_to(point)>110: return false
	var now := Time.get_ticks_msec()
	if last_target==target and now-last_time<420:
		last_target=""
		use(target)
	else:
		last_target=target
		last_time=now
		host.status_label.text="Double tap to use this control."
	return true
