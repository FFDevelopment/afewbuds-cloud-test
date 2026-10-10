extends SceneTree
var failures:=0
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
 if not ok:failures+=1;push_error(message)
 else:print("PASS ",message)
func run():
 var desktop:=ResourceLoader.exists("res://prototype/apartment.tscn")
 if root.has_node("AFBCloud"):await root.get_node("AFBCloud").prepare(true)
 var game=load("res://prototype/apartment.tscn" if desktop else "res://scenes/main.tscn").instantiate();root.add_child(game)
 game.set_process(false)
 var camera_before:Transform3D=game.camera.global_transform
 var paused_before:bool=game.session_paused
 game._install_map_update()
 check(game.camera.global_transform.is_equal_approx(camera_before) and game.session_paused==paused_before,"Map setup preserves loaded camera and pause state")
 for i in 3:await process_frame
 game.set_process(false);game.neighborhood.set_process(false)
 var player=game.fp_player if desktop else game.neighborhood.physics_body
 player.set_physics_process(false)
 game._install_map_update();game._install_map_update()
 check(game.has_node("BasementExpansion") and game.get_node("MapVisuals").is_processing()==false,"Map installs once without preview processing")
 game.session_paused=false;game.tutorial_active=false;game.daily_report_pending=false
 var inv=game.inventory_system;inv.set_process(false);var editor=inv.furniture;editor.set_process(false)
 var model=editor.model;game.cash=50000;game.packing_employee_active=false;game.production_worker_pending_action=""
 game.property_opportunity_state={"acquired":true,"first_entry":true,"relocated":true}
 var id:String=model.own("tent_2","backpack")
 game.camera.global_position=Vector3(29,-2.16,-5)
 editor.property="house";editor.selected=id;editor.yaw=0;editor.point=Vector3(29,-3.8,-10)
 await physics_frame
 check(editor.placement_floor()==-3.8 and editor.obstacle().is_empty(),"Basement accepts grow equipment on its own floor")
 check(model.place(id,"house",editor.point,0),"Place basement tent")
 editor.equipment_world.sync()
 var slot:int=int(model.state.items[id].slots[0])
 check(is_equal_approx(game.plant_visuals[slot].global_position.y,-3.54),"Basement plants render at saved floor height")
 check(model.registry.room_at("house",Vector3(29,-2,-10))=="basement_grow","Basement uses house grow room boundaries")
 var second:String=model.own("tent_1","backpack")
 check(not model.validate(second,"house",Vector3(43,-3.8,-10),0).is_empty(),"Stair aisle reserved")
 check(not model.validate(second,"house",Vector3(38.9,0,-10),0).is_empty(),"Basement bounds cannot authorize upstairs wall crossings")
 game.open_house_system();var apartment_light:bool=game.grow_lights_on
 var house_light:bool=bool(game.house_control_state.get("grow_lights",false))
 game._activate_room_interaction("grow_light_switch")
 check(bool(game.house_control_state.get("grow_lights",false))!=house_light and game.grow_lights_on==apartment_light,"Basement controls only house lighting")
 var eye:Vector3=game.camera.global_position;game._close_system_control_panel()
 check(game.camera.global_position==eye,"Closing basement panel does not teleport")
 for sku in ["water_kit","ventilation"]:
  var unit:String=model.own(sku,"backpack");editor.selected=unit;editor.wall_mount=true
  for wall_case in [["basement",Vector3(29,-1.7,-5),Vector3(26,-2.15,-5),"house"],["house",Vector3(41,2,-10),Vector3(44.8,1.7,-10),"house"],["apartment",Vector3(0,2,-7),Vector3(-5,1.7,-7),"apartment"]]:
   game.camera.global_position=wall_case[1];game.camera.look_at(wall_case[2]);editor.property=wall_case[3]
   editor.aim()
   check(editor.wall_found and editor.obstacle().is_empty(),"Wall mount "+sku+" in "+wall_case[0]+": "+editor.obstacle())
   check(model.has_mount_support(unit,editor.point,editor.yaw),"Mounted utility has solid wall support")
   check(not model.has_mount_support(unit,editor.point+Vector3(0,0,2.0) if editor.yaw==0 else editor.point+Vector3(2,0,0),editor.yaw),"Floating utilities are rejected")
 editor.selected=""
 var saved:Dictionary=JSON.parse_string(JSON.stringify(model.state));game.location_state.furniture_v1=saved;model.setup(game)
 check(is_equal_approx(model.state.items[id].position[1],-3.8) and int(model.state.items[id].slots[0])==slot,"Save reload preserves basement equipment and plant identity")
 game.production_worker_node.position=Vector3(43.8,0,-7.6)
 game.production_worker_target_position=Vector3(29,-3.8,-10);game._reset_production_worker_navigation()
 game._house_worker_navigation_target()
 check(game.production_worker_route_points.size()>5,"House workers use switchback waypoints to change floors")
 var passed_landing:=false
 for i in 1000:
  var target:Vector3=game._house_worker_navigation_target()
  game.production_worker_node.position=game.production_worker_node.position.move_toward(target,.1)
  if game.production_worker_node.position.distance_to(Vector3(42,-1.9,-13))<.2:passed_landing=true
 check(passed_landing and game.production_worker_node.position.distance_to(game.production_worker_target_position)<.1,"Worker reaches basement through stair landing")
 # Exercise the live collision refresh, not just freshly installed geometry.
 if desktop:game._add_physical_collisions(game)
 else:
  game.neighborhood.interior_obstacles.clear()
  game.neighborhood._collect_colliders(game)
  game.neighborhood.map_obstacles.clear()
  game.neighborhood._collect_map_colliders(game.neighborhood)
  game.neighborhood._rebuild_physics_obstacles(true)
 player.position=Vector3(6.02,.12,3.5);player.velocity=Vector3.ZERO
 for tick in 290:
  await physics_frame
  player.velocity=Vector3(0,-.5 if player.is_on_floor() else player.velocity.y-18.0/60.0,-3.4)
  player.move_and_slide()
 check(player.position.z< -6.8 and player.position.y>4.3,"Walk from sidewalk to first fire escape landing after collision refresh")
 for tick in 290:
  await physics_frame
  player.velocity=Vector3(0,-.5 if player.is_on_floor() else player.velocity.y-18.0/60.0,3.4)
  player.move_and_slide()
 check(player.position.z>2.8 and player.position.y<.15,"Walk down fire escape and exit onto sidewalk")
 print("MAP_INTEGRATION_RESULT: ","PASS" if failures==0 else "FAIL")
 game.queue_free();await process_frame;quit(1 if failures else 0)
