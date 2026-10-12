extends SceneTree
## First physical customer interaction contract, without real career mutations.
var failures:=0
var checks:=0
func check(result:bool,label:String)->void:
 checks+=1
 if result:print("PASS ",label)
 else:failures+=1;push_error("CUSTOMER_ENCOUNTER FAIL: "+label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var desktop:bool=ResourceLoader.exists("res://prototype/apartment.tscn")
 var scene:PackedScene=load("res://prototype/apartment.tscn" if desktop else "res://scenes/main.tscn")
 var game:Node3D=scene.instantiate()
 root.add_child(game)
 for i in range(18):await process_frame
 game.set_process(false)
 game.neighborhood.set_process(false)
 if desktop:game.fp_player.set_physics_process(false)
 else:game.neighborhood.physics_body.set_physics_process(false)
 game.session_paused=false
 game.daily_report_pending=false
 game.tutorial_active=false
 game.tutorial_seen=true
 game.tutorial_panel.hide()
 game.pause_overlay.hide()
 game.daily_report_panel.hide()
 for timer in game.find_children("*","Timer",true,false):timer.stop()
 var service:Node=game.customer_encounters
 check(service!=null and int(game.location_state.customer_encounters_v1.door_sales)==0,"Additive encounter history is initialized")
 check(not service.available(),"No ghost customer when no visit is scheduled")
 if desktop:game.fp_player.position=Vector3(0,0,4.4)
 else:game.neighborhood.physics_body.position=Vector3(0,0,4.4)
 game.camera.global_position=Vector3(0,1.7,4.6)
 game.camera.look_at(Vector3(0,1.65,7.1))
 var malik:Dictionary=game._customer_by_name("Malik")
 check(not malik.is_empty(),"Uses existing NPC and relationship catalog")
 game.current_customer=malik
 game.active_request={"product":"Street Green","qty":2}
 game.customer_waiting=true
 game.customer_departing=false
 game.customer_answered=false
 game.peephole_checked=false
 var guest:Node3D=service.ensure_visible_guest()
 check(guest!=null and guest.visible and guest.position.distance_to(Vector3(0,0,7.1))<.1,"A 3D customer appears at the apartment door")
 check(service.prepare_sale() and game.peephole_checked,"Door approach replaces normal customer peephole check")
 await create_timer(.5).timeout
 check(game.neighborhood.door_open,"Apartment door actually opens for the visitor")
 game._open_customer_sale()
 check(game.customer_answered and game.sale_panel.visible and not game.sale_customer_art.visible,"Physical buyer uses existing live sale/substitute/decline UI without covering character art")
 var actor:Node3D=guest
 game._end_customer_visit(false)
 check(not game.customer_waiting and service.stage=="leaving" and actor.visible,"Declining a sale releases visit but keeps customer walking away")
 for i in range(720):
  service._process(1.0/60.0)
 check(service.stage.is_empty() and (not is_instance_valid(actor) or not actor.visible),"Departing customer walks down sidewalk before despawning")
 game.current_customer=malik
 game.current_customer.special="reeves"
 game.customer_waiting=true
 check(not service.prepare_sale(),"Agent Reeves is not routed through normal customer sales")
 game.current_customer=malik
 game.current_customer.erase("special")
 game.customer_waiting=true
 game.customer_departing=false
 game.customer_answered=false
 guest=service.ensure_visible_guest()
 service.guest=guest
 service.guest_name="Malik"
 service.stage="invitation"
 service._accept_smoke()
 check(service.stage=="entering" and not service.panel.visible,"Smoke invitation accepted into a physical visit")
 for i in range(720):
  service._process(1.0/60.0)
 check(service.stage in ["smoking","leaving",""],"Guest can enter, hang out, then leave")
 for i in range(2000):
  service._process(1.0/60.0)
 check(int(service.history.smoke_sessions)==1 and int(service.history.smoke_days.Malik)==game.game_day,"Completed smoke session recorded once per customer/day")
 check(int(game.customer_relationships.get("Malik",{}).get("loyalty",0))>=6,"Social interaction improves real client relationship")
 var before:int=int(service.history.smoke_sessions)
 service.stage="smoking"
 service.smoke_elapsed=15.0
 service._finish_smoke()
 check(int(service.history.smoke_sessions)==before,"Social reward cannot be claimed twice in same game day")
 var serialized:Dictionary=JSON.parse_string(JSON.stringify(game.location_state))
 check(int(serialized.customer_encounters_v1.smoke_sessions)==1,"Completed encounters survive save JSON without persisting scene actor state")
 game.queue_free()
 for i in range(3):await process_frame
 print("CUSTOMER_ENCOUNTER_RESULT: "+("PASS" if failures==0 else "FAIL")+" checks="+str(checks)+" failures="+str(failures))
 quit(0 if failures==0 else 1)
