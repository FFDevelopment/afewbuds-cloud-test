def apply(text):
    def once(old,new):
        nonlocal text
        assert text.count(old)==1,repr(old)
        text=text.replace(old,new,1)
    once('extends Node3D','extends Node3D\nvar police_station:Node3D\nvar entrance_records:Array[Dictionary]=[]')
    once('\t_flush_batches()','\tload("res://scripts/police_district.gd").new().build(self)\n\tpolice_station=load("res://scripts/police_station.gd").new()\n\tpolice_station.name="PoliceStation"\n\tadd_child(police_station)\n\tpolice_station.build(self)\n\t_flush_batches()')
    once('pos.x > 136.7','pos.x > 200.7')
    once('func _walkable(pos: Vector3) -> bool:\n\tvar world: Vector3=pos+ORIGIN','func _walkable(pos: Vector3) -> bool:\n\tvar world: Vector3=pos+ORIGIN\n\tif police_station!=null and police_station.covers(world):return police_station.walkable(world)')
    once('if not couch_seated and bench_seating.seated<0:local.y=WALK_EYE_HEIGHT-ORIGIN.y','if not couch_seated and bench_seating.seated<0:\n\t\tlocal.y=(police_station.eye_height(ORIGIN+local) if police_station!=null and police_station.covers(ORIGIN+local) else WALK_EYE_HEIGHT)-ORIGIN.y')
    once('\tvar bench_target:String=bench_seating.target()', '\tvar police_target:String=police_station.target() if police_station!=null else ""\n\tif not police_target.is_empty():return police_target\n\tvar bench_target:String=bench_seating.target()')
    once('\tif target.begins_with("bench_"):action.text=', '\tif target.begins_with("police_"):action.text=police_station.title(target)\n\tif target.begins_with("bench_"):action.text=')
    once('\tvar target:=_near_target()\n\tif target.begins_with("bench_"):', '\tvar target:=_near_target()\n\tif target.begins_with("police_"):\n\t\tpolice_station.use(target)\n\t\treturn\n\tif target.begins_with("bench_"):')
    once('\tif bench_seating.tap(point):return', '\tif police_station!=null and police_station.tap(point):return\n\tif bench_seating.tap(point):return')
    once('func _map_room(pos: Vector3) -> String:', 'func _map_room(pos: Vector3) -> String:\n\tif police_station!=null and police_station.covers(pos):return police_station.room_title(pos)')
    once('	if tile >= 0:', '	if color=="74604a" and tile<0:\n		var bark:=ShaderMaterial.new()\n		bark.shader=load("res://scripts/bark.gdshader")\n		bark.set_shader_parameter("tint",Color(color))\n		material=bark\n	elif tile >= 0:')
    once('func entrance(at: Vector3, normal: Vector3) -> void:', 'func entrance(at: Vector3, normal: Vector3) -> void:\n	entrance_records.append({"at":at,"normal":normal})')
    return text
