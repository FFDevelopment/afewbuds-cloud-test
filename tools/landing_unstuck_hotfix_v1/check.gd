extends SceneTree
## Real scene and physics tests for landing 201/301 plus pause-menu recovery.
var checks:int=0
var failures:int=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures+=1;push_error("LANDING_UNSTUCK FAIL: "+message)
func _initialize()->void:call_deferred("run")
func run()->void:
 var desktop:bool=ResourceLoader.exists("res://prototype/apartment.tscn")
 if root.has_node("AFBCloud"):await root.get_node("AFBCloud").prepare(true)
 var scene_path:String="res://prototype/apartment.tscn" if desktop else "res://scenes/main.tscn"
 var game:Node3D=load(scene_path).instantiate()
 root.add_child(game)
 for i in 12:await process_frame
 game.set_process(false)
 game._install_map_update()
 for i in 4:await physics_frame
 check(game.has_node("MapVisuals"),"Actual apartment exterior art is present")
 var player:CharacterBody3D=game.fp_player if desktop else game.neighborhood.physics_body
 player.set_physics_process(false)
 game.neighborhood.set_process(false)
 for pair in [["201",4.4,-7.4],["301",7.9,2.2]]:
  var door:Node=game.find_child("LandingApartment"+str(pair[0]),true,false)
  check(door!=null,"Apartment "+str(pair[0])+" door remains in the world")
  if door==null:continue
  var leaf:Node=door.get_node_or_null("DoorLeaf")
  var solid:StaticBody3D=leaf.get_node_or_null("LandingDoorCollision") if leaf!=null else null
  check(solid!=null and solid.collision_layer==1,"Apartment "+str(pair[0])+" leaf has an enabled collider")
  if solid==null:continue
  var shape:CollisionShape3D=solid.get_child(0) as CollisionShape3D
  check(shape!=null and shape.shape is BoxShape3D and (shape.shape as BoxShape3D).size.y>=2.6,"Full-height leaf blocks player capsule")
  var from_pos:=Vector3(5.75,float(pair[1])+1.4,float(pair[2]))
  var to_pos:=Vector3(4.75,float(pair[1])+1.4,float(pair[2]))
  var query:=PhysicsRayQueryParameters3D.create(from_pos,to_pos,1)
  var hit:Dictionary=player.get_world_3d().direct_space_state.intersect_ray(query)
  check(not hit.is_empty() and hit.collider==solid,"Live physics ray hits closed "+str(pair[0])+" door")
 var menu:Node=game.inventory_system.session_menu
 var recovery:Node=menu.recovery
 check(recovery!=null and menu.has_method("_request_unstuck"),"Unstuck action installed on Pause")
 game._pause_gameplay()
 var old_cash:int=game.cash
 var old_stats:Dictionary=game.advancement_stats.duplicate(true)
 var safe:=Vector3(6.65,4.54,-7.4)
 recovery.checkpoint=safe
 recovery.has_checkpoint=true
 player.global_position=Vector3(5.13,4.52,-7.4)
 for i in 3:await physics_frame
 menu._request_unstuck()
 check(player.global_position.distance_to(safe)<.08,"Unstuck returns to prior verified floor instead of clipping through the door")
 check(game.cash==old_cash and game.advancement_stats==old_stats,"Unstuck preserves money and career stats")
 var prior:Vector3=player.global_position
 menu._request_unstuck()
 check(player.global_position==prior,"Cooldown blocks repeated recovery")
 check(game.session_paused and game.pause_overlay.visible,"Unstuck does not unexpectedly resume gameplay")
 game.queue_free()
 for i in 3:await process_frame
 print("LANDING_UNSTUCK_RESULT: "+("PASS" if failures==0 else "FAIL")+" checks="+str(checks))
 quit(0 if failures==0 else 1)
