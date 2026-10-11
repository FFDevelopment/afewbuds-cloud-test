extends RefCounted
## Two independent property worker slots, using the existing proven worker AI
## within a short-lived property context. Legacy career scalars are maintained
## for the apartment, while new property states are persisted by stable ID.
const PLACES=["apartment","house"]
var host:Node3D
var slots:Dictionary={}
var actors:Dictionary={}
var current:String="apartment"
var scoped:bool=false
var initialized:bool=false

func _vec(v:Vector3)->Array:return [v.x,v.y,v.z]
func _at(value:Variant,fallback:Vector3=Vector3.ZERO)->Vector3:
 if value is Vector3:return value
 if value is Array and value.size()==3:return Vector3(float(value[0]),float(value[1]),float(value[2]))
 return fallback
func _default()->Dictionary:
 return {"hired":false,"active":false,"friend":"","auto_plant":false,"tasks":0,"last":"Off duty",
 "task":"Off duty","pending":"","slot":-1,"strain":"","target":[0.75,0.0,2.55],
 "dwell":0.0,"stall":0.0,"walk":0.0,"route":[],"route_index":0,"route_end":[0,0,0],
 "route_valid":false,"arrested":false,"bail":0,"away_service":5.0,
 "position":[0.75,0.0,2.55],"yaw":0.0}
func _capture()->void:
 if not initialized:return
 var d:Dictionary=slots[current]
 d.hired=host.packing_employee_hired
 d.active=host.packing_employee_active
 d.friend=host.production_worker_friend_name
 d.auto_plant=host.production_worker_auto_plant
 d.tasks=host.production_worker_tasks_today
 d.last=host.production_worker_last_action
 d.task=host.production_worker_task
 d.pending=host.production_worker_pending_action
 d.slot=host.production_worker_pending_slot
 d.strain=host.production_worker_pending_strain
 d.target=_vec(host.production_worker_target_position)
 d.dwell=host.production_worker_action_dwell
 d.stall=host.production_worker_stall_seconds
 d.walk=host.production_worker_walk_phase
 d.route=[]
 for p in host.production_worker_route_points:d.route.append(_vec(p))
 d.route_index=host.production_worker_route_index
 d.route_end=_vec(host.production_worker_route_destination)
 d.route_valid=host.production_worker_route_valid
 d.arrested=host.production_worker_arrested
 d.bail=host.production_worker_bail_due
 d.away_service=host.away_worker_next_service
 if actors.has(current) and is_instance_valid(actors[current]):
  d.position=_vec(actors[current].position)
  d.yaw=actors[current].rotation.y
 slots[current]=d
 host.location_state["production_workers_v1"]=slots

func _load(property:String)->void:
 current=property
 var d:Dictionary=slots[property]
 host.packing_employee_hired=bool(d.get("hired",false))
 host.packing_employee_active=bool(d.get("active",false))
 host.production_worker_friend_name=str(d.get("friend",""))
 host.production_worker_auto_plant=bool(d.get("auto_plant",false))
 host.production_worker_tasks_today=int(d.get("tasks",0))
 host.production_worker_last_action=str(d.get("last","Off duty"))
 host.production_worker_task=str(d.get("task","Off duty"))
 host.production_worker_pending_action=str(d.get("pending",""))
 host.production_worker_pending_slot=int(d.get("slot",-1))
 host.production_worker_pending_strain=str(d.get("strain",""))
 host.production_worker_target_position=_at(d.get("target",[0,0,0]))
 host.production_worker_action_dwell=float(d.get("dwell",0))
 host.production_worker_stall_seconds=float(d.get("stall",0))
 host.production_worker_walk_phase=float(d.get("walk",0))
 host.production_worker_route_points.clear()
 for coord in d.get("route",[]):host.production_worker_route_points.append(_at(coord))
 host.production_worker_route_index=int(d.get("route_index",0))
 host.production_worker_route_destination=_at(d.get("route_end",[0,0,0]))
 host.production_worker_route_valid=bool(d.get("route_valid",false))
 host.production_worker_arrested=bool(d.get("arrested",false))
 host.production_worker_bail_due=int(d.get("bail",0))
 host.away_worker_next_service=float(d.get("away_service",5.0))
 if actors.has(property):
  var node:Node3D=actors[property]
  host.production_worker_node=node
  host.production_worker_head=node.get_node_or_null("Head") as MeshInstance3D
  host.production_worker_face_shell=node.get_node_or_null("FriendFaceWrap") as MeshInstance3D
  host.production_worker_task_label=node.get_node_or_null("Label3D") as Label3D
  node.position=_at(d.get("position",[]),Vector3(35,0,1.5) if property=="house" else Vector3(0.75,0,2.55))
  node.rotation.y=float(d.get("yaw",0.0))

func setup(owner:Node3D)->void:
 host=owner
 var original:Node3D=host.production_worker_node
 var saved:Variant=host.location_state.get("production_workers_v1",{})
 var legacy:Dictionary=_default()
 legacy.hired=host.packing_employee_hired
 legacy.active=host.packing_employee_active
 legacy.friend=host.production_worker_friend_name
 legacy.auto_plant=host.production_worker_auto_plant
 legacy.tasks=host.production_worker_tasks_today
 legacy.last=host.production_worker_last_action
 legacy.task=host.production_worker_task
 legacy.arrested=host.production_worker_arrested
 legacy.bail=host.production_worker_bail_due
 slots={"apartment":_default(),"house":_default()}
 if saved is Dictionary and saved.has("apartment") and saved.has("house"):
  for place in PLACES:
   if saved[place] is Dictionary:slots[place].merge(saved[place],true)
 else:
  var old_name:String=host.production_worker_friend_name if not host.production_worker_friend_name.is_empty() else "Production Worker"
  var old_assignment:String=str(host.location_state.get("staff_assignments",{}).get(old_name,"apartment"))
  if old_assignment not in PLACES:old_assignment="apartment"
  if legacy.hired:slots[old_assignment].merge(legacy,true)
 actors["apartment"]=original
 if original!=null:
  var house_actor:Node3D=original.duplicate()
  house_actor.name="HouseProductionWorker"
  house_actor.position=Vector3(35.0,0.0,1.45)
  house_actor.visible=false
  host.add_child(house_actor)
  actors["house"]=house_actor
 for place in PLACES:
  var record:Dictionary=slots[place]
  # A resume may have retained a task, but its old navigation targets and
  # scene coordinates are not guaranteed to be valid after the next boot.
  record.pending=""
  record.slot=-1
  record.strain=""
  record.dwell=0.0
  record.route=[]
  record.route_valid=false
  if place=="house" and record.get("position",[])==[0.75,0.0,2.55]:record.position=[35.0,0.0,1.45]
  slots[place]=record
 initialized=true
 host.location_state["production_workers_v1"]=slots
 _sync_assignments()
 _load("apartment")
 host.auto_bagger_unlocked=hired_count()>0

func _sync_assignments()->void:
 var assignments:Dictionary=host.location_state.get("staff_assignments",{})
 for place in PLACES:
  if not bool(slots[place].get("hired",false)):continue
  assignments[name_for(place)]=place
 host.location_state["staff_assignments"]=assignments

func with_property(place:String,task:Callable)->Variant:
 if place not in PLACES:return null
 var previous:String=current
 if initialized:_capture()
 _load(place)
 var earlier_scope:bool=scoped
 scoped=true
 var result:Variant=task.call()
 scoped=earlier_scope
 _capture()
 _load(previous)
 return result

func record(place:String)->Dictionary:
 if place not in PLACES:return {}
 if initialized and current==place:_capture()
 return slots[place]

func name_for(place:String)->String:
 if place not in PLACES:return ""
 var friend:String=str(slots[place].get("friend",""))
 return friend if not friend.is_empty() else ("House Production Worker" if place=="house" else "Production Worker")
func property_for_name(name:String)->String:
 for place in PLACES:
  if bool(slots[place].get("hired",false)) and name_for(place)==name:return place
 return ""
func all_names()->Array[String]:
 var names:Array[String]=[]
 for place in PLACES:
  if bool(slots[place].get("hired",false)):names.append(name_for(place))
 return names
func hired_count()->int:
 var total:int=0
 for place in PLACES:
  if bool(slots[place].get("hired",false)):total+=1
 return total
func on_duty(place:String)->bool:
 return bool(record(place).get("hired",false)) and bool(record(place).get("active",false))
func active_for_name(name:String)->bool:
 return on_duty(property_for_name(name))
func any_duty()->bool:
 for place in PLACES:
  if on_duty(place):return true
 return false
func payroll_due(place:String)->int:
 return host.PACKER_DAILY_WAGE if on_duty(place) else 0
func can_hire(place:String)->bool:
 return place in PLACES and host.inventory_system!=null and host.inventory_system.furniture.model.controlled(place) and not bool(record(place).get("hired",false)) and host.grower_level>=5 and not host._staff_heat_locked()

func hire(place:String)->bool:
 if not can_hire(place) or host.cash<host.PACKER_HIRE_COST:return false
 var assignments:Dictionary=host.location_state.get("staff_assignments",{})
 assignments[name_for(place)]=place
 host.location_state["staff_assignments"]=assignments
 with_property(place,func():host._hire_packing_employee())
 var success:bool=bool(slots[place].get("hired",false))
 if not success:assignments.erase(name_for(place))
 host._refresh_phone()
 return success

func recruit(name:String,place:String)->bool:
 if not can_hire(place):return false
 if not host._friend_is_recruitable(host._customer_by_name(name)):return false
 var prior:Variant=host.location_state.get("staff_assignments",{}).get(name,null)
 host.location_state["staff_assignments"][name]=place
 with_property(place,func():host._recruit_friend_staff(name,"production",place))
 if not bool(slots[place].get("hired",false)) or str(slots[place].get("friend",""))!=name:
  if prior==null:host.location_state["staff_assignments"].erase(name)
  else:host.location_state["staff_assignments"][name]=prior
  return false
 var assignments:Dictionary=host.location_state.get("staff_assignments",{})
 assignments[name]=place
 host.location_state["staff_assignments"]=assignments
 host._save_game()
 host._refresh_phone()
 return true

func toggle(place:String)->void:
 if place in PLACES and bool(record(place).get("hired",false)):
  with_property(place,func():host._toggle_packing_employee())
  host._refresh_phone()
func toggle_auto_plant(place:String)->void:
 if place in PLACES and bool(record(place).get("hired",false)):
  with_property(place,func():host._toggle_production_worker_auto_plant())
  host._refresh_phone()
func fire(place:String)->void:
 if place not in PLACES or not bool(record(place).get("hired",false)):return
 var worker:String=name_for(place)
 var friend:String=str(slots[place].get("friend",""))
 if not friend.is_empty():
  with_property(place,func():host._release_friend_staff(friend))
 else:
  with_property(place,func():host._fire_packing_employee())
 var assignments:Dictionary=host.location_state.get("staff_assignments",{})
 assignments.erase(worker)
 host.location_state["staff_assignments"]=assignments
 host.auto_bagger_unlocked=hired_count()>0
 host._save_game()
 host._refresh_phone()

func transfer(name:String,target:String)->bool:
 var source:String=property_for_name(name)
 if source.is_empty() or target not in PLACES or not host.inventory_system.furniture.model.controlled(target):return false
 if source==target:return true
 if bool(record(target).get("hired",false)):
  host.status_label.text="That property already has a production worker. Send one home or fire that worker before transferring."
  return false
 _capture()
 var moved:Dictionary=slots[source].duplicate(true)
 var generic:bool=str(moved.get("friend","")).is_empty()
 slots[source]=_default()
 moved.pending=""
 moved.slot=-1
 moved.strain=""
 moved.route=[]
 moved.route_valid=false
 moved.dwell=0.0
 moved.task="Transferring to "+target.capitalize()
 moved.last=moved.task
 moved.position=[35.0,0.0,1.45] if target=="house" else [0.65,0.0,3.85]
 moved.target=moved.position.duplicate()
 slots[target]=moved
 var assignments:Dictionary=host.location_state.get("staff_assignments",{})
 assignments.erase(name)
 assignments[name_for(target)]=target
 host.location_state["staff_assignments"]=assignments
 _load("apartment")
 host._save_game()
 host._refresh_phone()
 return true

func tick()->void:
 for place in PLACES:
  if not host.inventory_system.furniture.model.controlled(place):continue
  with_property(place,func():
   if host.packing_employee_hired and host.packing_employee_active:
    host._assign_production_worker_task()
   elif host.production_worker_node!=null:host.production_worker_node.visible=false
  )
func update(delta:float)->void:
 for place in PLACES:
  if not host.inventory_system.furniture.model.controlled(place):
   if actors.has(place):actors[place].visible=false
   continue
  with_property(place,func():host._update_production_worker_visual(delta))

func charge_wages()->Dictionary:
 var paid:Array[String]=[]
 var missed:Array[String]=[]
 var spent:int=0
 for place in PLACES:
  var d:Dictionary=record(place)
  if not bool(d.get("hired",false)) or not bool(d.get("active",false)):continue
  if host.cash>=host.PACKER_DAILY_WAGE:
   host.cash-=host.PACKER_DAILY_WAGE
   spent+=host.PACKER_DAILY_WAGE
   host._record_daily_expense("Production worker wage · "+place.capitalize(),host.PACKER_DAILY_WAGE)
   paid.append(place.capitalize()+" production worker $%d" % host.PACKER_DAILY_WAGE)
  else:
   d.active=false
   d.pending=""
   d.task="Off duty - unpaid"
   d.last=d.task
   missed.append(place.capitalize()+" production worker")
 _load("apartment")
 return {"paid":paid,"missed":missed,"spent":spent}

func heat_shutdown(arrest_one:bool)->void:
 var candidate:String=""
 for place in PLACES:
  var d:Dictionary=record(place)
  if not bool(d.get("hired",false)) or not bool(d.get("active",false)):continue
  if candidate.is_empty():candidate=place
  d.active=false
  d.pending=""
  d.task="Off duty"
  d.last="Went home - Heat too high"
  host._push_phone_text(name_for(place),"There is too much heat at the "+place+". I am heading home until things cool down.")
 if arrest_one and not candidate.is_empty():
  slots[candidate].arrested=true
  slots[candidate].bail=600
  host._push_phone_text(name_for(candidate),"I got picked up. Bail is $600. I cannot work until bail is paid and Heat cools down.")
 _load("apartment")

func pay_bail(place:String)->void:
 if place not in PLACES:return
 with_property(place,func():host._pay_production_bail())
 host._refresh_phone()

# Offline progression is split by property and merged once. Advancing all
# slots twice would double crop growth; copying only the originating property's
# slots makes that impossible. Water and fertilizer remain in that operation.
func offline_plants(elapsed:float,worker_care:bool)->void:
 if elapsed<=0.0 or not is_finite(elapsed) or not host._offline_crops_enabled():return
 var original:Array[Dictionary]=host.plant_slots.duplicate(true)
 var summary:Dictionary={"waterings":0,"fertilizes":0,"cared":false}
 for place in PLACES:
  if not host.inventory_system.furniture.model.controlled(place):continue
  with_property(place,_offline_one.bind(place,original,elapsed,worker_care,summary))
 var matured:int=0
 var dead:int=0
 var growing:int=0
 for i in range(host.plant_slots.size()):
  var before:Dictionary=original[i]
  var after:Dictionary=host.plant_slots[i]
  if int(before.get("stage",-1))<0 or int(before.get("stage",-1))>=3 or bool(before.get("dead",false)):continue
  if bool(after.get("dead",false)):dead+=1
  elif int(after.get("stage",-1))>=3:matured+=1
  else:growing+=1
 var report:Dictionary=host.offline_plant_report
 report["seconds"]=float(report.get("seconds",0.0))+elapsed
 report["matured"]=int(report.get("matured",0))+matured
 report["died"]=int(report.get("died",0))+dead
 report["growing"]=growing
 report["worker_care"]=bool(report.get("worker_care",false)) or bool(summary.cared)
 report["waterings"]=int(report.get("waterings",0))+int(summary.waterings)
 report["fertilizes"]=int(report.get("fertilizes",0))+int(summary.fertilizes)

func _offline_one(place:String,original:Array[Dictionary],elapsed:float,care:bool,summary:Dictionary)->void:
 host.inventory_system.at_property(place,_offline_at_property.bind(place,original,elapsed,care,summary))
func _offline_at_property(place:String,original:Array[Dictionary],elapsed:float,care:bool,summary:Dictionary)->void:
 var model:RefCounted=host.inventory_system.furniture.model
 var settings:Dictionary=host._plant_growth_settings(true)
 var can_work:bool=care and host.packing_employee_hired and host.packing_employee_active and not host.production_worker_arrested and host.game_day>=host.raid_lockdown_until_day and not host.neighborhood.location_ops.crew.shop.laying_low(place)
 var result:Dictionary=preload("res://scripts/offline_plant_care.gd").advance(original,elapsed,settings,host.fertilizer_units,can_work,host.away_worker_next_service)
 var plants:Array=result.get("plants",[])
 for i in range(host.plant_slots.size()):
  if model.slot_property(i)==place:host.plant_slots[i]=plants[i]
 host.fertilizer_units=int(result.get("fertilizer_units",host.fertilizer_units))
 host.away_worker_next_service=float(result.get("service_in",5.0))
 if can_work:
  summary.cared=true
  summary.waterings=int(summary.waterings)+int(result.get("waterings",0))
  summary.fertilizes=int(summary.fertilizes)+int(result.get("fertilizes",0))
  for idx in result.get("water_by_slot",{}):
   if model.slot_property(int(idx))==place:
    host._charge_water_use(int(result.water_by_slot[idx]),int(idx))
  host.production_worker_pending_action=""
  host.production_worker_pending_slot=-1
  host.production_worker_pending_strain=""
  host.production_worker_task="Checking plants after away care"
  host.production_worker_last_action=host.production_worker_task
  host._reset_production_worker_navigation()
