extends Node
## First physical-customer slice. Uses the existing sale/stock/payment service.
## Only normal customer visits use this controller; Reeves keeps his own scene.
## The saved dictionary holds *completed* relationship history, never timers.
const DOOR_AT := Vector3(0.0, 0.0, 7.1)
const SIDEWALK_RIGHT := Vector3(3.25, 0.0, 9.2)
const SIDEWALK_LEFT := Vector3(-3.25, 0.0, 9.2)
const EXIT_RIGHT := Vector3(14.0, 0.0, 9.2)
const EXIT_LEFT := Vector3(-14.0, 0.0, 9.2)
const GUEST_WALK_SPEED := 1.65
const SMOKE_TIME_SECONDS := 15.0
var host:Node3D
var history:Dictionary={}
var guest:Node3D
var guest_name:String=""
var route:Array[Vector3]=[]
var stage:String=""
var smoke_elapsed:float=0.0
var panel:PanelContainer
var heading:Label
var detail:Label
var yes_button:Button
var no_button:Button
var current_motion:String=""

func setup(owner:Node3D)->void:
 host=owner
 var old:Variant=host.location_state.get("customer_encounters_v1",{})
 history=(old as Dictionary) if old is Dictionary else {}
 if not history.has("smoke_days") or not (history["smoke_days"] is Dictionary):history["smoke_days"]={}
 if not history.has("door_sales"):history["door_sales"]=0
 if not history.has("smoke_sessions"):history["smoke_sessions"]=0
 host.location_state["customer_encounters_v1"]=history
 _build_interaction_ui()

func _build_interaction_ui()->void:
 panel=PanelContainer.new()
 panel.name="CustomerSocialInteraction"
 panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
 panel.offset_left=12
 panel.offset_right=-12
 panel.offset_top=-240
 panel.offset_bottom=-16
 panel.add_theme_stylebox_override("panel",host._style_box(Color("121d19"),Color("759d88"),14,2))
 host.hud.add_child(panel)
 var content:=VBoxContainer.new()
 content.add_theme_constant_override("separation",10)
 panel.add_child(content)
 heading=Label.new()
 heading.add_theme_font_size_override("font_size",21)
 heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 content.add_child(heading)
 detail=Label.new()
 detail.add_theme_font_size_override("font_size",16)
 detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 content.add_child(detail)
 var buttons:=HBoxContainer.new()
 buttons.add_theme_constant_override("separation",10)
 content.add_child(buttons)
 yes_button=Button.new()
 yes_button.text="HANG OUT"
 yes_button.custom_minimum_size.y=50
 yes_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 yes_button.pressed.connect(_accept_smoke)
 buttons.add_child(yes_button)
 no_button=Button.new()
 no_button.text="NOT TODAY"
 no_button.custom_minimum_size.y=50
 no_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 no_button.pressed.connect(_decline_smoke)
 buttons.add_child(no_button)
 panel.hide()

func blocks_controls()->bool:return panel!=null and panel.visible
func has_departing_guest()->bool:return stage in ["invitation","entering","smoking","leaving"] and guest!=null and is_instance_valid(guest)
func available()->bool:
 return host.customer_waiting and not host.customer_departing and str(host.current_customer.get("special","")).is_empty()

func ensure_visible_guest()->Node3D:
 if not available():return null
 var crew:RefCounted=host.neighborhood.location_ops.crew
 var customer:String=str(host.current_customer.get("name",""))
 if customer.is_empty():return null
 var actor:Node3D=crew.malik_visitor
 if actor!=null and str(actor.get_meta("character",""))!=customer:
  actor.queue_free()
  crew.malik_visitor=null
  actor=null
 if actor==null:
  if crew.has_method("character_instance") and ResourceLoader.exists("res://assets/characters/"+customer+".glb"):
   actor=crew.character_instance(customer)
  else:
   actor=crew.generic_manager_instance(customer)
   actor.set_meta("character",customer)
  actor.name="VisitingCustomer"
  actor.position=DOOR_AT
  host.add_child(actor)
  crew.malik_visitor=actor
 if actor!=null:
  actor.visible=true
  actor.position.y=0.0
 return actor

func prepare_sale()->bool:
 if not available():return false
 var actor:Node3D=ensure_visible_guest()
 if actor==null:return false
 if not host.neighborhood.door_open and not host.neighborhood.transitioning:
  host.neighborhood.toggle_door()
 host.peephole_checked=true
 host.status_label.text="You open the front door and speak with "+host._customer_display_name(host.current_customer)+"."
 return true

func opened_sale()->void:
 if not available():return
 ensure_visible_guest()
 # Keep the person visible in the actual 3D doorway. Use the existing stock,
 # pricing and substitution buttons; do not make another sales/payment route.
 if host.sale_customer_art!=null:host.sale_customer_art.hide()
 if host.sale_panel!=null:
  host.sale_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
  host.sale_panel.offset_left=12
  host.sale_panel.offset_right=-12
  host.sale_panel.offset_top=-360
  host.sale_panel.offset_bottom=-14

func conclude_visit(completed:bool)->void:
 if str(host.current_customer.get("special",""))!="":return
 if not host.customer_answered:return
 var name:String=str(host.current_customer.get("name",""))
 if name.is_empty():return
 var actor:Node3D=ensure_visible_guest()
 if actor==null:return
 var crew:RefCounted=host.neighborhood.location_ops.crew
 # Give departing actor to this controller. The next scheduled customer can
 # have a separate rig without force-hiding the old one on every crew update.
 if crew.malik_visitor==actor:crew.malik_visitor=null
 guest=actor
 guest_name=name
 current_motion=""
 if completed:
  history["door_sales"]=int(history.get("door_sales",0))+1
  var visits:Dictionary=history.get("smoke_days",{})
  var last_day:int=int(visits.get(name,-1))
  var loyalty:int=int(host.customer_relationships.get(name,{}).get("loyalty",0))
  var chance:float=clampf(.12+float(loyalty)*.003, .12,.42)
  if last_day!=host.game_day and host.rng.randf()<chance and str(host.current_customer.get("tier",""))!="Federal":
   stage="invitation"
   route.clear()
   _play_guest_motion("idle")
   heading.text=name+" wants to hang out"
   detail.text="\"I just picked up. Want to kick back and have a smoke for a little while?\""
   panel.show()
   return
 start_departure()

func start_departure()->void:
 panel.hide()
 if guest==null or not is_instance_valid(guest):
  guest=null
  stage=""
  return
 stage="leaving"
 _play_guest_motion("walk")
 route.clear()
 if guest.position.z<6.8:
  route.append(Vector3(0.0,0.0,7.4))
 var right:bool=guest_name.hash()%2==0
 route.append(SIDEWALK_RIGHT if right else SIDEWALK_LEFT)
 route.append(EXIT_RIGHT if right else EXIT_LEFT)

func _accept_smoke()->void:
 if stage!="invitation" or guest==null:return
 stage="entering"
 panel.hide()
 smoke_elapsed=0.0
 route=[Vector3(0,0,5.1),Vector3(-.7,0,3.4),Vector3(-1.5,0,1.4)]
 _play_guest_motion("walk")
 host.status_label.text=guest_name+" is coming inside to hang out. The session only progresses while you're playing."
 host._set_world_controls_visible(true)

func _decline_smoke()->void:
 if stage!="invitation":return
 host.status_label.text="You told "+guest_name+" maybe another time."
 host._set_world_controls_visible(true)
 start_departure()

func _finish_smoke()->void:
 # Never pay a second social reward after the actor has exited or been freed.
 if stage!="smoking" or guest_name.is_empty() or guest==null or not is_instance_valid(guest):return
 var days:Dictionary=history.get("smoke_days",{})
 var previous:int=int(days.get(guest_name,-1))
 if previous!=host.game_day:
  days[guest_name]=host.game_day
  history["smoke_days"]=days
  history.smoke_sessions=int(history.get("smoke_sessions",0))+1
  var relation:Dictionary=host.customer_relationships.get(guest_name,{}).duplicate(true)
  relation.loyalty=clampi(int(relation.get("loyalty",0))+6,0,100)
  host.customer_relationships[guest_name]=relation
  host.status_label.text="You spent time with "+guest_name+". Loyalty +6. They head home."
  host._save_game()
 start_departure()

func _play_guest_motion(name:String)->void:
 if guest==null or not is_instance_valid(guest) or current_motion==name:return
 current_motion=name
 for player in guest.find_children("*","AnimationPlayer",true,false):
  for clip in player.get_animation_list():
   var value:String=str(clip).to_lower()
   if value==name or value.ends_with("/"+name) or value.ends_with("_"+name):
    if player.current_animation!=clip:player.play(clip)
    break

func _walk(delta:float)->void:
 if guest==null or not is_instance_valid(guest):
  stage=""
  route.clear()
  return
 if route.is_empty():
  if stage=="entering":
   stage="smoking"
   smoke_elapsed=0.0
   _play_guest_motion("sit")
   if host.neighborhood.door_open and not host.neighborhood.transitioning:host.neighborhood.toggle_door()
  else:
   guest.hide()
   guest.queue_free()
   guest=null
   guest_name=""
   stage=""
   current_motion=""
  return
 var destination:Vector3=route.front()
 var before:Vector3=guest.position
 guest.position=guest.position.move_toward(destination,maxf(0.0,delta)*GUEST_WALK_SPEED)
 var motion:Vector3=destination-before
 if motion.length_squared()>.0001:
  guest.rotation.y=atan2(motion.x,motion.z)
 if guest.position.distance_to(destination)<.03:
  route.pop_front()
  if stage=="leaving" and route.size()==1 and host.neighborhood.door_open and not host.neighborhood.transitioning:
   host.neighborhood.toggle_door()

func _process(delta:float)->void:
 if host==null or host._simulation_blocked():return
 match stage:
  "entering","leaving":_walk(delta)
  "smoking":
   smoke_elapsed+=maxf(0.0,delta)
   if smoke_elapsed>=SMOKE_TIME_SECONDS:_finish_smoke()
