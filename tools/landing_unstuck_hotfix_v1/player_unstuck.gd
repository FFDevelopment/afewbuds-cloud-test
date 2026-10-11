extends Node
## Recovery for both first-person controllers; never changes career data or accounts.
const COOLDOWN_MS:int=25000
const CHECK_EVERY:float=.45
var host:Node
var checkpoint:Vector3=Vector3.ZERO
var has_checkpoint:bool=false
var since_sample:float=0.0
var last_use_msec:int=-COOLDOWN_MS
func setup(owner:Node)->void:
 host=owner
 set_physics_process(true)
func actor()->CharacterBody3D:
 if host==null or not is_instance_valid(host):return null
 var desktop_player:Node=host.get_node_or_null("FirstPersonPlayer")
 if desktop_player is CharacterBody3D:return desktop_player
 if host.neighborhood==null:return null
 var mobile_player:Variant=host.neighborhood.get("physics_body")
 return mobile_player as CharacterBody3D if mobile_player is CharacterBody3D else null
func clear_for(body:CharacterBody3D,point:Vector3)->bool:
 if body==null or not (is_finite(point.x) and is_finite(point.y) and is_finite(point.z)):return false
 var collider:CollisionShape3D=body.get_node_or_null("PlayerCapsule")
 if collider==null or collider.shape==null:return false
 var query:=PhysicsShapeQueryParameters3D.new()
 query.shape=collider.shape
 query.transform=Transform3D(body.global_basis,point+body.global_basis*collider.position)
 query.collision_mask=1
 query.collide_with_bodies=true
 query.exclude=[body.get_rid()]
 return body.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func supported(body:CharacterBody3D,point:Vector3)->bool:
 var query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.3,point-Vector3.UP*.75,1,[body.get_rid()])
 var hit:Dictionary=body.get_world_3d().direct_space_state.intersect_ray(query)
 return not hit.is_empty() and absf(float(hit.position.y)-point.y)<.6
func valid_spot(body:CharacterBody3D,point:Vector3)->bool:
 return clear_for(body,point) and supported(body,point)
func _physics_process(delta:float)->void:
 if host==null or not is_instance_valid(host) or host.session_paused:return
 since_sample+=delta
 if since_sample<CHECK_EVERY:return
 since_sample=0.0
 var body:CharacterBody3D=actor()
 if body==null or not body.is_on_floor() or body.velocity.y< -2.0:return
 var point:Vector3=body.global_position
 if point.y< -4.7 or point.y>20.0:return
 if valid_spot(body,point):
  checkpoint=point
  has_checkpoint=true
func recovery_candidates(current:Vector3)->Array[Vector3]:
 var candidates:Array[Vector3]=[
  Vector3(6.65,4.54,-7.4),  # apartment 201 landing
  Vector3(6.65,8.04,2.2),   # apartment 301 landing
  Vector3(6.70,.16,3.55),   # outdoor starter apartment stair exit
  Vector3(0,.16,8.5),       # public apartment approach
  Vector3(17,.16,8.2),      # market public sidewalk
  Vector3(35,.16,9.1)       # house public sidewalk
 ]
 var road_x:float=clampf(current.x,-28.0,198.0)
 candidates.append(Vector3(road_x,.16,17))
 candidates.append(Vector3(road_x,.16,-19))
 candidates.sort_custom(func(a:Vector3,b:Vector3)->bool:return a.distance_to(current)<b.distance_to(current))
 return candidates
func recover()->String:
 var body:CharacterBody3D=actor()
 if body==null:return "UNSTUCK unavailable: player controller is not ready."
 var now:int=Time.get_ticks_msec()
 if last_use_msec>=0 and now-last_use_msec<COOLDOWN_MS:
  return "UNSTUCK is cooling down. Try again shortly."
 var current:Vector3=body.global_position
 var target:Vector3=Vector3.INF
 if has_checkpoint and checkpoint.distance_to(current)<=12.0 and valid_spot(body,checkpoint):
  target=checkpoint
 else:
  for candidate in recovery_candidates(current):
   if Vector2(candidate.x,candidate.z).distance_to(Vector2(current.x,current.z))>24.0:continue
   if valid_spot(body,candidate):
    target=candidate
    break
 if target==Vector3.INF:return "No verified safe location nearby. Your position was not changed."
 body.stop()
 body.global_position=target
 body.velocity=Vector3.ZERO
 checkpoint=target
 has_checkpoint=true
 last_use_msec=now
 if body.has_method("sync_camera"):body.sync_camera()
 elif host.neighborhood!=null and host.neighborhood.has_method("_sync_camera_from_physics"):
  host.neighborhood._sync_camera_from_physics()
 return "UNSTUCK: returned to a nearby safe spot. Resume when ready."
