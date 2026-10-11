extends SceneTree
## Headless contract: every usable house room is bounded by structural wall
## faces (not the smaller historic purchase/ownership rectangles). Stairs,
## interior partitions, doorways and fixtures still retain collision authority.
var failures:=0
var checks:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,reason:String)->void:
 checks+=1
 if ok:print("PASS ",reason)
 else:failures+=1;push_error("HOUSE_ROOM_BOUNDARY FAIL: "+reason)
func near(a:float,b:float)->bool:return absf(a-b)<.002
func run()->void:
 var desktop:bool=ResourceLoader.exists("res://prototype/apartment.tscn")
 var game:Node3D=load("res://prototype/apartment.tscn" if desktop else "res://scenes/main.tscn").instantiate()
 root.add_child(game)
 for i in 18:await process_frame
 game.set_process(false);game.neighborhood.set_process(false)
 if desktop:game.fp_player.set_physics_process(false)
 else:game.neighborhood.physics_body.set_physics_process(false)
 for clock in game.find_children("*","Timer",true,false):clock.stop()
 game.tutorial_active=false;game.daily_report_pending=false;game.session_paused=false
 game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide()
 game.property_opportunity_state={"acquired":true,"relocated":true,"agreement_signed":true,"agreement":"purchase"}
 game.apartment_rent_state.lease_active=true
 game._install_map_update()
 var editor:Node=game.inventory_system.furniture
 editor.set_process(false)
 var model:RefCounted=editor.model
 var expected:Dictionary={
  "living":[25.115,-4.885,33.385,2.885],
  "packing":[36.615,-4.885,44.885,2.885],
  "kitchen":[25.115,-13.885,31.185,-7.115],
  "bathroom":[31.415,-13.885,34.085,-7.115],
  "bedroom":[34.315,-13.885,38.485,-7.115],
  "grow":[38.715,-13.885,44.885,-7.115]
 }
 var legacy:Dictionary=model.registry.rooms_for("house")
 var new_rooms:Dictionary=model.placement_rooms("house",0)
 check(new_rooms.size()>=6,"House retains living, packing, kitchen, bathroom, bedroom and grow-room placement records")
 for key in expected:
  var r:Rect2=new_rooms.get(key,Rect2())
  var coords:Array=expected[key]
  check(near(r.position.x,coords[0]) and near(r.position.y,coords[1]) and near(r.end.x,coords[2]) and near(r.end.y,coords[3]),"Real structural wall faces matched: "+key)
  check(r.size.x>=(legacy.get(key,Rect2()) as Rect2).size.x-.02,"Usable "+key+" is not narrowed by old stored room bounds")
  var probe_id:String="bounds_probe_"+key
  model.state.items[probe_id]={"sku":"floor_lamp","property":"backpack","locked":false,"paid":85,"upgrades":{}}
  var inside:Vector3=Vector3(r.position.x+.255,0,r.position.y+.255)
  check(model.validate(probe_id,"house",inside,0).is_empty(),"Small furniture can reach "+key+" wall-side corner within five millimetres")
  check(not model.validate(probe_id,"house",Vector3(r.end.x-.15,0,r.get_center().y),0).is_empty(),"Cannot move "+key+" furniture through the right wall")
  check(not model.validate(probe_id,"house",Vector3(r.get_center().x,0,r.end.y-.15),0).is_empty(),"Cannot move "+key+" furniture through the front wall")
  model.state.items.erase(probe_id)
 var basement:Rect2=model.BASEMENT_GROW_PLACEMENT
 check(near(basement.position.x,26.105) and near(basement.end.x,40.9) and near(basement.position.y,-13.695) and near(basement.end.y,1.395),"Basement grow zone reaches safe wall faces while reserving the stair wing")
 var registered:Dictionary=model.registry.rooms_for("house")
 check(registered.has("basement_grow") and (registered.basement_grow as Rect2).is_equal_approx(basement),"Basement registry and furniture editor use exactly the same floor bounds")
 check(model.registry.room_at("house",Vector3(40.7,-3.3,-6))=="basement_grow","Expanded basement-side walkway remains the same controlled grow room")
 check(model.registry.room_at("house",Vector3(35,-3.3,1.20))=="basement_grow","Previously excluded basement-front floor is registered")
 check(model.registry.room_at("house",Vector3(43,-3.3,-10))!="basement_grow","Staircase is excluded from grow placement")
 var tent:String="test_house_basement_tent"
 model.state.items[tent]={"sku":"tent_1","property":"backpack","locked":false,"paid":240,"upgrades":{}}
 var basement_site:Vector3=Vector3(basement.position.x+.58,-3.8,-6)
 check(model.validate(tent,"house",basement_site,0).is_empty(),"Small tent fits close to basement's left physical wall")
 check(not model.validate(tent,"house",Vector3(43,-3.8,-10),0).is_empty(),"Stair flight and rails cannot accept a grow tent")
 check(not model.validate(tent,"house",Vector3(26.38,-3.8,-6),0).is_empty(),"Basement tent cannot penetrate sidewall")
 game.camera.global_position=Vector3(29,-2.16,-5)
 editor.property="house";editor.selected=tent;editor.point=basement_site;editor.yaw=0
 await physics_frame
 check(editor.inside("house") and editor.obstacle().is_empty(),"Live basement physics accepts wall-side tent placement: "+editor.obstacle())
 var front_site:=Vector3(35.0,-3.8,basement.end.y-.605)
 check(model.validate(tent,"house",front_site,0).is_empty(),"Extended basement-front area accepts plants without entering stairs")
 editor.point=front_site
 check(editor.obstacle().is_empty(),"Live basement front wall is clear of stairs and fixtures: "+editor.obstacle())
 model.state.items.erase(tent)
 editor.selected=""
 check(not model.placement_rooms("apartment",0).is_empty(),"Apartment placement boundaries remain unchanged")
 check((model.registry.rooms_for("house").packing as Rect2).is_equal_approx(legacy.packing),"House ownership/property registry retains original save-space bounds")
 game.queue_free()
 for i in 5:await process_frame
 print("HOUSE_ROOM_BOUNDARIES_RESULT: "+("PASS" if failures==0 else "FAIL")+" checks="+str(checks)+" failures="+str(failures))
 quit(1 if failures>0 else 0)
