extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
 checks+=1
 if ok:print("PASS ",message)
 else:failures+=1;push_error("PROPERTY_STAFF FAIL: "+message)
func run()->void:
 var desktop:bool=ResourceLoader.exists("res://prototype/apartment.tscn")
 var scene:PackedScene=load("res://prototype/apartment.tscn" if desktop else "res://scenes/main.tscn")
 var game:Node3D=scene.instantiate()
 root.add_child(game)
 for i in 15:await process_frame
 game.set_process(false);game.neighborhood.set_process(false)
 if desktop:game.fp_player.set_physics_process(false)
 else:game.neighborhood.physics_body.set_physics_process(false)
 for t in game.find_children("*","Timer",true,false):t.stop()
 game.tutorial_active=false;game.tutorial_seen=true;game.session_paused=false;game.daily_report_pending=false
 game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide()
 game.apartment_rent_state.lease_active=true
 game.property_opportunity_state={"acquired":true,"agreement_signed":true,"agreement":"purchase","relocated":true}
 game.grower_level=6;game.cash=30000;game.heat=0.0;game.production_worker_arrested=false
 var service:RefCounted=game.production_crew
 var ops:RefCounted=game.neighborhood.location_ops
 var people:RefCounted=ops.crew
 var furniture:Node=game.inventory_system.furniture
 var model:RefCounted=furniture.model
 check(service!=null and service.initialized,"Property production service starts before worker simulation")
 check(service.hired_count()==0,"Empty career has independent vacant apartment and house positions")
 check(service.hire("house"),"Hire house production worker without taking apartment slot")
 check(not game.packing_employee_hired and service.on_duty("house"),"House worker does not occupy legacy apartment position")
 check(service.hire("apartment"),"Hire a second production worker at apartment")
 check(service.hired_count()==2 and service.on_duty("house") and service.on_duty("apartment"),"One paid worker per property can be active together")
 check(people.roster().has("Production Worker") and people.roster().has("House Production Worker"),"Both independent workers appear under Contacts and Properties")
 check(ops.computer_staff_names("apartment").size()==1 and ops.computer_staff_names("house").size()==1,"Computer screens show only local workers")
 var wage_before:int=game.cash
 var wages:Dictionary=service.charge_wages()
 check(game.cash==wage_before-2*game.PACKER_DAILY_WAGE and int(wages.spent)==2*game.PACKER_DAILY_WAGE,"Each working property's payroll is charged once")
 service.toggle_auto_plant("house")
 check(bool(service.record("house").auto_plant) and not bool(service.record("apartment").auto_plant),"House auto-plant preference cannot turn on apartment auto-plant")
 service.toggle("house")
 check(not service.on_duty("house") and service.on_duty("apartment"),"Sending house worker home does not pause apartment worker")
 check(not service.transfer("Production Worker","house"),"Cannot transfer into a second occupied production position")
 service.fire("house")
 check(service.hired_count()==1 and not bool(service.record("house").hired),"Firing house worker does not fire apartment worker")
 check(service.transfer("Production Worker","house"),"Move existing apartment worker to vacant house")
 check(service.hired_count()==1 and not bool(service.record("apartment").hired) and bool(service.record("house").hired),"Transferred worker frees apartment hiring position")
 check(service.hire("apartment"),"Hire apartment production after transferring previous worker to house")
 check(service.hired_count()==2,"Transfer plus new hire produces exactly one worker at each property")
 var state:Dictionary=JSON.parse_string(JSON.stringify(game.location_state.production_workers_v1))
 check(bool(state.apartment.hired) and bool(state.house.hired),"Both separate worker records survive JSON career serialization")
 var friend:Dictionary=game._customer_by_name("Rod")
 game.customer_relationships["Rod"]={"visits":5,"loyalty":85,"player_sales":5}
 service.fire("house")
 check(game._friend_is_recruitable(friend),"Known loyal client qualifies for production work")
 check(service.recruit("Rod","house"),"Text recruitment can assign a loyal friend to the house")
 check(people.assignment("Rod")=="house" and service.name_for("house")=="Rod","Named recruit retains exact house assignment and identity")
 check(service.hired_count()==2,"House named friend does not replace apartment production worker")
 var level_price:int=model.upgrade_cost("legacy_packing") if model.state.items.has("legacy_packing") else 0
 check(level_price>=0,"Upgrade pricing stays available for legacy owned equipment")
 game.grower_level=2
 check(model.unlock_level("bench_2")==3 and model.unlock_level("bench_3")==6 and model.unlock_level("storage_5")==9,"Legacy station level requirements are retained")
 check(not model.unlock_reason("bench_3").is_empty(),"Locked levels report their Grower requirement without charging")
 game.grower_level=6
 var temp:String="bench_fit_level3"
 model.state.items[temp]={"sku":"bench_3","property":"backpack","locked":false,"paid":850,"upgrades":{}}
 game.camera.global_position=Vector3(40.1,1.7,-2.1)
 furniture.begin(temp)
 furniture.point=Vector3(47.0,0,-2.1)
 furniture.yaw=0
 furniture.fit_aim_to_room()
 var xlimit:float=model.ROOMS.house.packing.end.x-model.size_of(temp,0).x*.5
 check(furniture.point.x<=xlimit and furniture.point.x>=xlimit-.1,"Packing Bench III aim fits against packing-room wall instead of projecting through")
 var near_wall:Vector3=Vector3(xlimit-.015,0,-2.4)
 check(model.validate(temp,"house",near_wall,0).is_empty(),"Full-size Packing Bench III legally fits within a narrow wall clearance: "+model.validate(temp,"house",near_wall,0))
 furniture.point=near_wall
 check(furniture.obstacle().is_empty(),"Complete wall and furniture physics accepts Packing Bench III near wall: "+furniture.obstacle())
 check(not model.validate(temp,"house",Vector3(xlimit+.22,0,-2.4),0).is_empty(),"Bench cannot clip through wall when pushed beyond room")
 furniture.cancel_placement()
 model.state.items.erase(temp)
 game.queue_free()
 for i in 6:await process_frame
 print("PROPERTY_PRODUCTION_STAFF_RESULT: "+("PASS" if failures==0 else "FAIL")+" checks="+str(checks)+" failures="+str(failures))
 quit(1 if failures else 0)
