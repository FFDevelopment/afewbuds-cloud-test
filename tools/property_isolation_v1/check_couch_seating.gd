extends SceneTree
# Regression: the hired worker and door manager must hold the CURRENT couch
# cushion instead of alternating between the cushion and an old approach point.
var failures:=0
var checks:=0
func check(ok:bool,message:String) -> void:
 checks+=1
 if ok:print("PASS: ",message)
 else:failures+=1;push_error("FAIL: "+message)
func _initialize():call_deferred("run")
func horizontal(a:Vector3,b:Vector3) -> float:
 return Vector2(a.x-b.x,a.z-b.z).length()
func step_worker(game:Node3D,crew:RefCounted,frames:int=120) -> void:
 for i in frames:
  game._update_production_worker_visual(.05)
  crew.update_seating(.05)
func step_both(game:Node3D,crew:RefCounted,frames:int=120) -> void:
 for i in frames:
  game._update_production_worker_visual(.05)
  crew.update(.05)
func run() -> void:
 var game:Node3D=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 for i in 20:await process_frame
 game.set_process(false);game.neighborhood.set_process(false)
 if game.neighborhood.physics_body!=null:game.neighborhood.physics_body.set_physics_process(false)
 for t in game.find_children("*","Timer",true,false):t.stop()
 game.gameplay_ready=true;game.session_paused=false;game.daily_report_pending=false;game.tutorial_active=false;game.customer_waiting=false
 game.tutorial_panel.hide();game.daily_report_panel.hide();game.pause_overlay.hide()
 var inv:Node=game.inventory_system;inv.set_process(false);inv.furniture.set_process(false)
 inv.guide.state.active=false;inv.guide.state.completed=true
 check(not game._simulation_blocked(),"NPC test simulation is unpaused and guide is inactive")
 var model:RefCounted=inv.furniture.model
 var crew:RefCounted=game.neighborhood.location_ops.crew
 for character in ["Kobi","Malik","Rod"]:
  var avatar:Node3D=crew.character_instance(character)
  var animations:Array=[]
  for player in avatar.find_children("*","AnimationPlayer",true,false):
   for clip in player.get_animation_list():
    var anim:Animation=player.get_animation(clip)
    animations.append({"name":clip,"length":anim.length if anim!=null else -1.0,"tracks":anim.get_track_count() if anim!=null else -1})
  var bones:Array[String]=[]
  for rig in avatar.find_children("*","Skeleton3D",true,false):
   for index in range(rig.get_bone_count()):
    var key:String=rig.get_bone_name(index)
    if key.to_lower().contains("leg") or key.to_lower().contains("thigh") or key.to_lower().contains("hip") or key.to_lower().contains("knee"):
     bones.append(key)
  print("NPC_SITTING_DIAGNOSTIC ",character," animations=",JSON.stringify(animations)," bones=",str(bones))
  for player in avatar.find_children("*","AnimationPlayer",true,false):
   var idle:Animation=player.get_animation("idle")
   var sit:Animation=player.get_animation("sit")
   if idle==null or sit==null:continue
   var paths:Array[String]=[]
   for track in range(sit.get_track_count()):
    paths.append(str(sit.track_get_path(track)))
   print("NPC_SIT_TRACKS ",character," ",str(paths))
   check(sit.get_track_count()>=idle.get_track_count(),"Character "+character+" sit animation keeps relaxed idle upper-body tracks; sit "+str(sit.get_track_count())+" vs idle "+str(idle.get_track_count()))
   var arm_count:int=0
   var arms_match:bool=true
   var bent_legs:Array[String]=[]
   for it in range(idle.get_track_count()):
    var key:String=str(idle.track_get_path(it)).to_lower()
    var is_arm:bool=key.contains("upperarm") or key.contains("lowerarm") or key.contains("hand_")
    if not is_arm:continue
    if idle.track_get_key_count(it)==0:continue
    arm_count+=1
    var matches:bool=false
    for st in range(sit.get_track_count()):
     if sit.track_get_type(st)==idle.track_get_type(it) and sit.track_get_path(st)==idle.track_get_path(it) and sit.track_get_key_count(st)>0:
      matches=sit.track_get_key_value(st,0)==idle.track_get_key_value(it,0)
      break
    if not matches:arms_match=false
   for st in range(sit.get_track_count()):
    var key:String=str(sit.track_get_path(st)).to_lower()
    if key.contains("upperleg") or key.contains("lowerleg"):
     bent_legs.append(str(sit.track_get_path(st)))
   print("NPC_SIT_POSE_VERIFICATION ",character," arm_tracks=",arm_count," arms_match_idle=",arms_match," leg_tracks=",str(bent_legs))
   check(arm_count>=4 and arms_match,"Character "+character+" has relaxed non-T-pose upper arms during sitting")
   check(bent_legs.size()>=4,"Character "+character+" retains sitting thigh and knee tracks")


  avatar.queue_free()
 game.location_state.active_property="apartment"
 game.location_state.operation_contents_property="apartment"
 check(model.state.items.has("legacy_sofa"),"Original public couch exists in furniture inventory")
 var old_couch:Dictionary=model.state.items["legacy_sofa"].duplicate(true)
 model.state.items["legacy_sofa"].property="apartment"
 model.state.items["legacy_sofa"].position=[-2.4,0.0,3.2]
 model.state.items["legacy_sofa"].yaw=0
 game.packing_employee_hired=true;game.packing_employee_active=true;game.production_worker_arrested=false
 game.production_worker_pending_action="";game.production_worker_task="Waiting for work"
 var worker:Node3D=game.production_worker_node
 worker.show()
 var seat:Vector3=crew.idle_spot(false,false)
 worker.position=seat+Vector3(.65,0,-.90)
 step_worker(game,crew,125)
 check(bool(worker.get_meta("seated",false)) and horizontal(worker.position,seat)<.02,"Production worker reaches cushion (at %s, target %s, task %s, blocked %s)"%[worker.position,seat,game.production_worker_task,game._simulation_blocked()])
 var position_before:Vector3=worker.position
 step_worker(game,crew,70)
 check(bool(worker.get_meta("seated",false)) and horizontal(worker.position,position_before)<.005,"Idle worker holds one seat for repeated frames; no couch/table ping-pong")
 check(absf(worker.position.y+0.57)<.02 or absf(worker.position.y)<.02,"Seated worker height is stable")
 # Sofa moved during the career: release the previous seat and walk to the new one.
 model.state.items["legacy_sofa"].position=[-1.0,0.0,2.5]
 model.state.items["legacy_sofa"].yaw=90
 var new_seat:Vector3=crew.idle_spot(false,false)
 step_worker(game,crew,1)
 check(not bool(worker.get_meta("seated",false)),"Moving the sofa invalidates the old NPC seat")
 step_worker(game,crew,165)
 check(bool(worker.get_meta("seated",false)) and horizontal(worker.position,new_seat)<.02,"Worker reaches moved sofa (at %s, target %s, nav %s)"%[worker.position,new_seat,game.production_worker_target_position])
 # The generic dealer also needs a position lock (its sit pose changes Y).
 game.dealer_count=1;game.dealers_active=true;game.dealer_arrested=false
 var dealers:Array=game._active_dealer_roster()
 check(not dealers.is_empty(),"Dealer available to test couch seat")
 if not dealers.is_empty():
  game.location_state.staff_assignments[str(dealers[0])]="apartment"
  game.location_state.apartment_manager=str(dealers[0])
  step_both(game,crew,190)
  var manager:Node3D=crew.manager_node
  var manager_seat:Vector3=crew.idle_spot(true,false)
  check(manager!=null and bool(manager.get_meta("seated",false)) and horizontal(manager.position,manager_seat)<.02,"Dealer manager sits at its live cushion position")
  if manager!=null:
   var manager_at:Vector3=manager.position
   step_both(game,crew,90)
   check(bool(manager.get_meta("seated",false)) and horizontal(manager.position,manager_at)<.005 and absf(manager.position.y-manager_at.y)<.01,"Door manager remains seated without vertical or table movement")
   game.customer_waiting=true
   step_both(game,crew,2)
   check(not bool(manager.get_meta("seated",false)),"Door manager stands when a visitor arrives")
   game.customer_waiting=false
 # Removing the sofa must remove the NPC seat, rather than leave an invisible one.
 model.state.items["legacy_sofa"].property="backpack"
 model.state.items["legacy_sofa"].erase("position")
 step_worker(game,crew,3)
 check(not bool(worker.get_meta("seated",false)) and crew.idle_couch().is_empty(),"Packed couch leaves no invisible NPC seat")
 game.production_worker_pending_action="trim"
 step_worker(game,crew,2)
 check(not bool(worker.get_meta("seated",false)),"Work assignment never leaves worker seated")
 # Every imported production character must stand normally when the final
 # work station is reached. A stale route waypoint must not keep "walk" playing.
 for person in ["Malik","Rod","Kobi"]:
  game.production_worker_friend_name=person
  for work_station in ["workbench","grow","storage","entry"]:
   var goal:Vector3=game._production_worker_station_position(work_station)
   game.production_worker_pending_action="trim"
   game.production_worker_task="Working at "+work_station
   game.production_worker_target_position=goal
   worker.position=goal
   worker.set_meta("seated",false)
   # Reproduce the old bug: the next cached waypoint is elsewhere.
   game.production_worker_route_valid=true
   game.production_worker_route_destination=goal
   game.production_worker_route_index=0
   game.production_worker_route_points.clear()
   game.production_worker_route_points.append(goal+Vector3(1.5,0,0))
   crew.update_malik()
   var avatar:Node3D=crew.malik_worker
   var stood:bool=avatar!=null
   if avatar!=null:
    for anim_player in avatar.find_children("*","AnimationPlayer",true,false):
     stood=stood and str(anim_player.current_animation).ends_with("idle")
   check(stood,person+" stands at "+work_station+" without looping walk when navigation cache is stale")
   # Still walk on the way to the NEXT task: no permanent idle lock.
   worker.position=goal+Vector3(2,0,1)
   game._reset_production_worker_navigation()
   crew.update_malik()
   var walking:bool=avatar!=null
   if avatar!=null:
    for anim_player in avatar.find_children("*","AnimationPlayer",true,false):
     walking=walking and str(anim_player.current_animation).ends_with("walk")
   check(walking,person+" resumes walk when travelling toward "+work_station)
   worker.position=goal
   game._reset_production_worker_navigation()
   crew.update_malik()
   var stopped:bool=avatar!=null
   if avatar!=null:
    for anim_player in avatar.find_children("*","AnimationPlayer",true,false):
     stopped=stopped and str(anim_player.current_animation).ends_with("idle")
   check(stopped,person+" returns to standing idle upon arrival at "+work_station)
 model.state.items["legacy_sofa"]=old_couch
 game.queue_free()
 await process_frame
 print("NPC_COUCH_SEATING_RESULT: ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
