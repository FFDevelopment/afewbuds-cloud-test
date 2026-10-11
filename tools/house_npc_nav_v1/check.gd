extends SceneTree
# House NPC paths: run against the actual 3D interior and current furniture registry.
var checks:=0
var failures:=0
func check(ok:bool,note:String)->void:
    checks+=1
    if ok:print("PASS: ",note)
    else:failures+=1;push_error("HOUSE_NAV FAIL: "+note)

func _initialize()->void:call_deferred("run")
func sample_clear(nav:RefCounted,points:Array[Vector3],title:String)->void:
    var placed:Array[Dictionary]=nav._installed_footprints()
    for i in range(1,points.size()):
        var begin:Vector3=points[i-1]
        var end:Vector3=points[i]
        var distance:float=begin.distance_to(end)
        var slices:int=maxi(1,ceili(distance/.12))
        for j in range(1,slices):
            var position:Vector3=begin.lerp(end,float(j)/float(slices))
            if nav._blocked(position,placed):
                check(false,title+" crosses a wall or occupied footprint at "+str(position))
                return
    check(true,title+" keeps inside clear floor and door apertures")

func run()->void:
    var desktop:bool=ResourceLoader.exists("res://prototype/apartment.tscn")
    var game:Node3D=load("res://prototype/apartment.tscn" if desktop else "res://scenes/main.tscn").instantiate()
    root.add_child(game)
    for i in range(20):await process_frame
    game.set_process(false)
    game.neighborhood.set_process(false)
    if desktop:game.fp_player.set_physics_process(false)
    elif game.neighborhood.physics_body!=null:game.neighborhood.physics_body.set_physics_process(false)
    for timer in game.find_children("*","Timer",true,false):timer.stop()
    game.gameplay_ready=true
    game.session_paused=false
    game.tutorial_active=false
    game.daily_report_pending=false
    game.tutorial_panel.hide()
    game.pause_overlay.hide()
    game.daily_report_panel.hide()
    game.property_opportunity_state["acquired"]=true
    game.property_opportunity_state["relocated"]=true
    var ops:RefCounted=game.neighborhood.location_ops
    var crew:RefCounted=ops.crew
    var nav:RefCounted=game._house_npc_route()
    nav.refresh(true)
    var routes:Array[Dictionary]=[
        {"a":Vector3(28.0,0,0),"b":Vector3(40.5,0,-2.0),"name":"living to packing via entry hall"},
        {"a":Vector3(41.5,0,-2.0),"b":Vector3(41.4,0,-9.0),"name":"packing to grow via hall"},
        {"a":Vector3(27.0,0,-11.0),"b":Vector3(41.7,0,-9.0),"name":"kitchen to grow room through two rear doors"},
        {"a":Vector3(35.8,0,-9.0),"b":Vector3(32.8,0,-9.0),"name":"bedroom to bathroom via rear hall"},
        {"a":Vector3(41.4,0,-9.0),"b":Vector3(35.0,0,2.1),"name":"grow room to house entrance"},
        {"a":Vector3(28.0,0,0),"b":Vector3(35.0,0,2.1),"name":"living room to front door"},
        {"a":Vector3(35.0,0,2.1),"b":Vector3(27.0,0,-11.0),"name":"entry hall to kitchen"}
    ]
    for route in routes:
        var start:Vector3=route.a
        var finish:Vector3=route.b
        var points:Array[Vector3]=nav.plan(start,finish)
        check(points.size()>3 and points[-1].distance_to(finish)<.65,route.name+" finds a route and reaches its target")
        if points.size()>0:
            var chain:Array[Vector3]=[start]
            chain.append_array(points)
            sample_clear(nav,chain,str(route.name))
    # Crossing hall wall directly is forbidden even if a route exists.
    check(nav._walls(Vector3(33.5,0,-3.2)) and not nav._walls(Vector3(33.5,0,-.1)),"Front divider is blocked except through the real door opening")
    check(nav._walls(Vector3(40,0,-7)) and not nav._walls(Vector3(41,0,-7)),"Rear grow doorway retains its true clearance")
    check(crew.idle_couch("house").get("id","")=="house_fitted_couch","Fitted house sofa supplies a real idle seating spot")
    var house_seat:Vector3=crew.idle_spot(true,false,"house")
    check(house_seat.x>26 and house_seat.x<33.3 and house_seat.z>-5 and house_seat.z<3,"Door employee house idle seat stays in living room")
    var model:RefCounted=game.inventory_system.furniture.model
    var previous:Dictionary=model.state.items.duplicate(true)
    model.state.items["nav_test_furniture"]={"sku":"coffee_table","property":"house","position":[34.9,0,-6.0],"yaw":0}
    nav.refresh(true)
    check(nav._blocked(Vector3(34.9,0,-6),nav._installed_footprints()),"New house furniture blocks navigation cells")
    var reroute:Array[Vector3]=nav.plan(Vector3(35,0,1.8),Vector3(41.5,0,-9))
    check(not reroute.is_empty(),"Worker still finds a hall route around placed furniture")
    if not reroute.is_empty():
        var chain:Array[Vector3]=[Vector3(35,0,1.8)]
        chain.append_array(reroute)
        sample_clear(nav,chain,"House route after furniture rearrangement")
    model.state.items=previous
    nav.refresh(true)
    # Routes must be independent for the production worker and the door employee.
    var worker_next:Vector3=nav.next_waypoint("production",Vector3(35,0,1.4),Vector3(41.3,0,-9.0))
    var door_next:Vector3=nav.next_waypoint("door_Rod",Vector3(29.0,0,-2.5),Vector3(35,0,2.1))
    check(worker_next!=door_next and nav.routes.size()==2,"Multiple NPC routes do not overwrite each other")
    var blocked_grid:AStarGrid2D=nav.grid
    blocked_grid.fill_solid_region(blocked_grid.region,true)
    nav.reset()
    var stopped:Vector3=nav.next_waypoint("blocked",Vector3(28,0,0),Vector3(42,0,-10))
    check(stopped.distance_to(Vector3(28,0,0))<.001,"Unreachable route stops instead of phasing through a wall")
    game.queue_free()
    await process_frame
    await process_frame
    print("HOUSE_NPC_NAV_RESULT: "+("PASS" if failures==0 else "FAIL")+" checks="+str(checks)+" failures="+str(failures))
    quit(0 if failures==0 else 1)
