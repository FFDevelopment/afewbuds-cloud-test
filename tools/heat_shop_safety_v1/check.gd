extends SceneTree
# Public-release guard: high Heat can never strand the owner with an open
# storefront. Phone listing controls must remain readable at iPhone width.
var checks:int=0
var failures:int=0
func check(ok:bool,message:String)->void:
 checks+=1
 if ok:print("PASS ",message)
 else:failures+=1;push_error("HEAT_SHOP_SAFETY FAIL: "+message)
func _initialize()->void:call_deferred("run")
func run()->void:
 var desktop:bool=ResourceLoader.exists("res://prototype/apartment.tscn")
 var game:Node3D=load("res://prototype/apartment.tscn" if desktop else "res://scenes/main.tscn").instantiate()
 root.add_child(game)
 for i in 20:await process_frame
 game.set_process(false);game.neighborhood.set_process(false)
 if desktop:game.fp_player.set_physics_process(false)
 else:game.neighborhood.physics_body.set_physics_process(false)
 for t in game.find_children("*","Timer",true,false):t.stop()
 game.tutorial_active=false;game.tutorial_seen=true
 game.session_paused=false;game.daily_report_pending=false
 game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide()
 game.apartment_rent_state.lease_active=true
 game.property_opportunity_state={"acquired":true,"agreement_signed":true,"agreement":"purchase","relocated":true,"first_entry":true}
 game.grower_level=6;game.cash=30000;game.heat=0.0;game.business_open=true;game.lay_low_active=false
 game.raid_lockdown_until_day=0
 var ops:RefCounted=game.neighborhood.location_ops
 var crew:RefCounted=ops.crew
 var shop:RefCounted=crew.shop
 var workers:RefCounted=game.production_crew
 check(workers.hire("house"),"House production employee hired normally")
 var worker_name:String=workers.name_for("house")
 check(crew.role(worker_name)=="production","Crew contact remains available after duty changes")
 var days_before:String=JSON.stringify(game.location_state)
 workers.record("house").active=false
 game.heat=95.0
 check(game._staff_heat_locked() and not workers.on_duty("house"),"Critical Heat puts the worker off duty")
 var controls:=VBoxContainer.new()
 root.add_child(controls)
 shop.render(controls,"apartment")
 var close:Button=null
 var shut:Button=null
 for b in controls.find_children("*","Button",true,false):
  var btn:Button=b
  if btn.text.begins_with("CLOSE SHOP"):close=btn
  if btn.text.begins_with("SHUT DOWN"):shut=btn
 check(close!=null and not close.disabled,"Owner can close an open shop without any employee at critical Heat")
 check(shut!=null and not shut.disabled,"Owner can lay low at critical Heat even when crew is off duty")
 shop.owner_control("apartment","close")
 check(not game.business_open and not game.lay_low_active,"Closing the apartment stops sales but preserves the optional lay-low action")
 shop.owner_control("apartment","shutdown")
 check(game.lay_low_active and not game.business_open and not game.main_ceiling_light_on,"Lay Low closes storefront and powers down the real apartment")
 check(not workers.on_duty("house"),"Owner emergency shutdown never clocks a different property's worker in")
 shop.owner_control("house","shutdown")
 check(shop.laying_low("house") and not shop.is_open("house"),"Owner can independently shut down the house")
 check(not shop.reopen("house"),"High Heat blocks reopening without blocking closure")
 game._open_phone_app("heat")
 var heat_buttons:Array[String]=[]
 for node in game.phone_list.find_children("*","Button",true,false):
  heat_buttons.append((node as Button).text)
 var safety_count:int=heat_buttons.filter(func(x):return str(x).begins_with("REOPEN LOCKED")).size()
 check(safety_count>=2,"Heat phone exposes both property controls even with all staff off duty")
 # Off-duty crew still answer emergency closure commands; no illegal reactivation.
 game.heat=10.0
 check(shop.reopen("house"),"House reopens normally once Heat is safe")
 game.heat=95.0
 crew.command(worker_name,"shutdown")
 check(shop.laying_low("house") and not shop.is_open("house"),"Off-duty worker can relay a valid emergency shutdown")
 crew.command(worker_name,"reopen")
 check(shop.laying_low("house"),"Off-duty worker cannot bypass the reopening restriction")
 shop.owner_control("apartment","open")
 check(not game.business_open and game.lay_low_active,"Owner cannot reopen at critical Heat")
 game.heat=20.0
 check(shop.reopen("apartment") and game.business_open and not game.lay_low_active,"Normal reopening restores apartment only once Heat is under control")
 check(not shop.is_open("house"),"Reopening apartment does not open the shut house")
 # Narrow viewport test reproduces the otherwise invisible LIST/UNLIST strip.
 game.get_window().size=Vector2i(390,830)
 game._open_phone_app("products")
 game.phone_panel.show()
 for i in 3:await process_frame
 var found:int=0
 var wide:int=0
 var vertically_stacked:int=0
 for node in game.phone_list.find_children("*","Button",true,false):
  var button:Button=node
  if not button.has_meta("product_listing_toggle"):continue
  found+=1
  if button.text in ["LIST","UNLIST"] and button.size.x>=80:wide+=1
  if button.get_parent() is VBoxContainer:vertically_stacked+=1
 check(found>0 and wide==found,"At phone width every LIST/UNLIST button has readable text and a real tap target")
 check(found==vertically_stacked,"Narrow listing headers are stacked rather than squeezed into vertical green bars")
 var preserved:Dictionary=JSON.parse_string(JSON.stringify(game.location_state))
 check(preserved.has("container_inventory") and preserved.has("property_shop"),"Emergency controls keep inventory and property operation save records")
 controls.queue_free()
 game.queue_free()
 for i in 4:await process_frame
 print("HEAT_SHOP_SAFETY_RESULT: "+("PASS" if failures==0 else "FAIL")+" checks="+str(checks)+" failures="+str(failures))
 quit(1 if failures else 0)
