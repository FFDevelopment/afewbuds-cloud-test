extends RefCounted
## Shared, deterministic first-floor house navigation. No changes to saves or inventory.
## Grid follows the real wall apertures in prototype/interiors.gd (x,z in world metres).
const CELL := 0.30
const CORNER := Vector2(25.3, -13.7)
const COLS := 65
const ROWS := 55
const RADIUS := 0.23
var host: Node3D
var grid: AStarGrid2D
var stamp := ""
var stamp_time := -100000
var routes: Dictionary = {}

func setup(owner: Node3D) -> void:
    host = owner

func reset(agent: String = "") -> void:
    if agent.is_empty():routes.clear()
    else:routes.erase(agent)

func _id(point: Vector3) -> Vector2i:
    return Vector2i(roundi((point.x - CORNER.x)/CELL), roundi((point.z - CORNER.y)/CELL))

func _point(id: Vector2i, y: float = 0.0) -> Vector3:
    return Vector3(CORNER.x + float(id.x)*CELL, y, CORNER.y + float(id.y)*CELL)

func _rectangle(point: Vector3, center: Vector2, size: Vector2, extra: float = RADIUS) -> bool:
    return absf(point.x-center.x) < size.x*0.5+extra and absf(point.z-center.y) < size.y*0.5+extra

func _walls(point: Vector3) -> bool:
    var x := point.x
    var z := point.z
    if x < 25.52 or x > 44.50 or z < -13.49 or z > 2.48:return true
    # Front living / entry / packing partitions. Access only through their openings.
    if absf(x-33.5) < .11+RADIUS and z > -5.05 and z < 2.9 and not (z > -.8+RADIUS and z < .7-RADIUS):return true
    if absf(x-36.5) < .11+RADIUS and z > -5.05 and z < 2.9 and not (z > -.8+RADIUS and z < .7-RADIUS):return true
    # The front rooms end at the cross-hall. Approach the hall via the entry passage.
    if absf(z+5.0) < .11+RADIUS and (x < 33.5 or x > 36.5):return true
    # Four rear doors, matching the wall cut-outs in interiors.gd.
    if absf(z+7.0) < .11+RADIUS:
        var passage := (x>28.0+RADIUS and x<29.5-RADIUS) or (x>32.0+RADIUS and x<33.3-RADIUS) or (x>35.8+RADIUS and x<37.2-RADIUS) or (x>40.3+RADIUS and x<41.9-RADIUS)
        if not passage:return true
    # Kitchen, bathroom, bedroom and grow-room partitions.
    if z < -7.0 and z > -13.9:
        for divider in [31.3,34.2,38.6]:
            if absf(x-divider)<.11+RADIUS:return true
    return false

func _built_in(point: Vector3) -> bool:
    # Solid furnishings. Small handles, rugs and lights are intentionally omitted.
    for shape in [
        [29.2,-3.6,2.0,.9], [29.2,-1.8,2.0,.9], [29.2,2.2,2.8,.5],
        [26.35,1.65,1.5,.85],
        [28.3,-9.4,2.0,1.2], [28.5,-13.35,4.8,.85], [29.6,-7.7,1.05,1.0],
        [27.7,-10.5,.64,.60], [28.9,-10.5,.64,.60],
        [27.7,-8.3,.64,.60], [28.9,-8.3,.64,.60],
        [32.7,-12.9,2.3,1.7], [31.85,-9.1,.8,1.1], [33.35,-10.5,.55,.75],
        [36.5,-11.4,2.1,3.2], [34.85,-8.6,.85,1.2],
        [41.2,-4.2,4.5,1.1], [44.35,-3.2,.8,.8], [38,-4.25,1.15,.9],
        [44.25,-9.1,.7,.7]
    ]:
        if _rectangle(point,Vector2(shape[0],shape[1]),Vector2(shape[2],shape[3])):return true
    return false

func _installed_footprints() -> Array[Dictionary]:
    var shapes: Array[Dictionary] = []
    if host == null or host.inventory_system == null or host.inventory_system.furniture == null:return shapes
    var model: RefCounted = host.inventory_system.furniture.model
    if model == null:return shapes
    for item_id in model.state.items.keys():
        var item: Dictionary = model.state.items[item_id]
        if str(item.get("property","")) != "house" or not item.has("position"):continue
        var pos: Array = item.position
        if pos.size()<3 or float(pos[1])>1.45:continue # High wall-mounted utilities.
        var sku: String = str(item.get("sku",""))
        if not model.CATALOG.has(sku):continue
        var dimensions: Vector3 = model.size_of(str(item_id),int(item.get("yaw",0)))
        if dimensions.x < .18 or dimensions.z < .18:continue
        shapes.append({"center":Vector2(float(pos[0]),float(pos[2])),"size":Vector2(dimensions.x,dimensions.z),"yaw":deg_to_rad(float(item.get("yaw",0)))})
    return shapes

func _blocked(point: Vector3, placed: Array[Dictionary]) -> bool:
    if _walls(point) or _built_in(point):return true
    for shape in placed:
        var shifted := Vector2(point.x,point.z)-shape.center
        var local := shifted.rotated(-float(shape.yaw))
        if absf(local.x)<shape.size.x*.5+RADIUS and absf(local.y)<shape.size.y*.5+RADIUS:return true
    return false

func _layout_signature() -> String:
    if host==null or host.inventory_system==null or host.inventory_system.furniture==null:return "no-items"
    var data: Array[String] = []
    var model:RefCounted=host.inventory_system.furniture.model
    var ids: Array = model.state.items.keys()
    ids.sort()
    for id in ids:
        var entry:Dictionary=model.state.items[id]
        if str(entry.get("property",""))!="house" or not entry.has("position"):continue
        data.append(str(id)+":"+JSON.stringify([entry.get("sku",""),entry.position,entry.get("yaw",0),entry.get("size_override",[])]))
    return "|".join(PackedStringArray(data))

func refresh(force: bool = false) -> void:
    if not force and grid!=null and Time.get_ticks_msec()-stamp_time<500:return
    stamp_time=Time.get_ticks_msec()
    var current:String=_layout_signature()
    if not force and grid!=null and current==stamp:return
    stamp=current
    grid=AStarGrid2D.new()
    grid.region=Rect2i(Vector2i.ZERO,Vector2i(COLS,ROWS))
    grid.cell_size=Vector2(CELL,CELL)
    grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
    grid.update()
    var furniture:Array[Dictionary]=_installed_footprints()
    for z in ROWS:
        for x in COLS:
            var id:=Vector2i(x,z)
            grid.set_point_solid(id,_blocked(_point(id),furniture))
    reset()

func _nearest_valid(candidate: Vector2i, reference: Vector2i) -> Vector2i:
    var best:=Vector2i(-1,-1)
    var score:=INF
    for radius in 7:
        for dz in range(-radius,radius+1):
            for dx in range(-radius,radius+1):
                var cell:=candidate+Vector2i(dx,dz)
                if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell):continue
                var value:=Vector2(candidate-cell).length_squared()+.08*Vector2(reference-cell).length_squared()
                if value<score:score=value;best=cell
        if best.x>=0:return best
    return best

func _ground_route(from: Vector3, goal: Vector3) -> Array[Vector3]:
    refresh()
    var points: Array[Vector3] = []
    var start:=_nearest_valid(_id(from),_id(goal))
    var finish:=_nearest_valid(_id(goal),start)
    if start.x<0 or finish.x<0:return points
    var ids: Array[Vector2i]=grid.get_id_path(start,finish)
    if ids.is_empty():return points
    var last_direction:=Vector2i(100,100)
    for i in range(1,ids.size()):
        var direction:Vector2i=ids[i]-ids[i-1]
        if i>1 and direction!=last_direction:points.append(_point(ids[i-1]))
        last_direction=direction
    var end:Vector3=_point(finish)
    if not points.is_empty() and points[-1].distance_to(end)<.08:points.pop_back()
    points.append(end)
    if not grid.is_point_solid(_id(goal)) and end.distance_to(goal)<.36:points[-1]=Vector3(goal.x,0.0,goal.z)
    return points

func plan(from: Vector3, goal: Vector3) -> Array[Vector3]:
    if from.y>-.5 and goal.y>-.5:return _ground_route(from,goal)
    # Keep the existing multi-flight basement stair landings; route to and from
    # the stairhead with the same ground-floor wall-aware search.
    var stairs:Array[Vector3]=[
        Vector3(43.8,0,-7.6),Vector3(43.8,0,-8.3),
        Vector3(43.8,-1.9,-12.4),Vector3(43.8,-1.9,-13),
        Vector3(42,-1.9,-13),Vector3(42,-1.9,-12.4),
        Vector3(42,-3.8,-8.3),Vector3(42,-3.8,-7.4),Vector3(40.6,-3.8,-7.4)
    ]
    if from.y<-.5 and goal.y<-.5:return [goal] # Basement has its own unobstructed fixture route for now.
    if from.y>-.5:
        var up:Array[Vector3]=_ground_route(from,stairs[0])
        up.append_array(stairs.slice(1))
        up.append(goal)
        return up
    stairs.reverse()
    var down:Array[Vector3]=stairs.duplicate()
    down.append_array(_ground_route(stairs[-1],goal))
    return down

func next_waypoint(agent:String,from:Vector3,goal:Vector3) -> Vector3:
    refresh()
    var state:Dictionary=routes.get(agent,{})
    if state.is_empty() or (state.get("goal",Vector3.INF) as Vector3).distance_to(goal)>.25:
        state={"goal":goal,"points":plan(from,goal),"index":0}
        routes[agent]=state
    var points:Array=state.get("points",[])
    if points.is_empty():return from # Never cross a wall as a fallback.
    var at:int=int(state.get("index",0))
    while at<points.size() and from.distance_to(points[at])<.19:at+=1
    state["index"]=at
    routes[agent]=state
    if at>=points.size():return from
    _open_door(from,points[at])
    return points[at]

func arrived(agent:String,at:Vector3,goal:Vector3) -> bool:
    var state:Dictionary=routes.get(agent,{})
    if state.is_empty() or (state.get("goal",Vector3.INF) as Vector3).distance_to(goal)>.25:return at.distance_to(goal)<.23
    var points:Array=state.get("points",[])
    if points.is_empty():return false
    return at.distance_to(points[-1])<.29

func _open_door(here:Vector3,next_point:Vector3) -> void:
    if host==null or host.neighborhood==null:return
    for label in ["HouseEntrance","BathroomDoor","BedroomDoor"]:
        var door:Node3D=host.neighborhood.get_node_or_null(label)
        if door==null or bool(door.get("opened")) or bool(door.get("busy")):continue
        var center:Vector3=door.global_position+door.global_basis*Vector3(float(door.get("width"))*.5,0,0)
        if Vector2(center.x-here.x,center.z-here.z).length()<1.0 and Vector2(center.x-next_point.x,center.z-next_point.z).length()<1.55:
            door.toggle(here)
