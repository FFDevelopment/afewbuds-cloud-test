extends RefCounted
var world: Node3D
var host: Node3D
var switches: Dictionary = {}
var shades: Dictionary = {}
var states: Dictionary = {}
var last_target := ""
var last_time := -1000

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
	world._label("GROW LIGHTS",at+Vector3(0.08,0.23,0),0.0015)
	var rocker: MeshInstance3D=world._interior_piece("GrowServiceRocker",at+Vector3(0.08,0,0),Vector3(0.035,0.18,0.15),"92a17d")
	rocker.layers=2
	rocker.set_meta("no_collision",true)
	switches["grow_lights"]={"lamps":lamps,"fixtures":fixtures,"at":at,"rocker":rocker}
	_set_light("grow_lights",bool(states.get("grow_lights",false)))

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

func _inside_room(point: Vector3) -> String:
	if world._indoors(point): return "apartment"
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
	for id in switches:
		if (id==room or (id=="grow_lights" and room=="grow")) and _reachable(switches[id].at): return "switch_"+id
	for id in shades:
		var shade_room := "apartment" if id=="ApartmentBlind" else ("grow" if id.begins_with("Grow") else "packing")
		if room==shade_room and _reachable(shades[id].at): return "shade_"+id
	return ""

func title(target: String) -> String:
	if target.begins_with("switch_"):
		var id := target.trim_prefix("switch_")
		if id=="grow_lights" and switches[id].lamps.is_empty(): return "INSPECT HOUSE GROW PANEL"
		return ("TURN OFF " if states.get(id,true) else "TURN ON ")+("GROW LIGHTS" if id=="grow_lights" else id.replace("_"," ").to_upper()+" LIGHT")
	var id := target.trim_prefix("shade_")
	return "OPEN WINDOW COVERING" if shades[id].closed else "CLOSE WINDOW COVERING"

func use(target: String) -> void:
	if target!=nearby(): return
	if target.begins_with("switch_"):
		var id := target.trim_prefix("switch_")
		if id=="grow_lights" and switches[id].lamps.is_empty():
			host.status_label.text="No house grow equipment installed. House equipment has its own upgrades; apartment tents do not transfer automatically."
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
