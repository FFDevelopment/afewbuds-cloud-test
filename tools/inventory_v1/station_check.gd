extends SceneTree
var game:Node3D
var inv:Node
var ops:RefCounted
var failures:=0
var checks:=0
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;push_error("FAIL: "+message)
 else:print("PASS: ",message)
func stand(id:String):
 game.camera.position=inv.POSITIONS[id]+Vector3(0,.34,2)
 game.camera.look_at(inv.POSITIONS[id])
func empty_bag():
 game.location_state.carried_seeds={};game.location_state.carried_fertilizer=0
 game.location_state.property_storage=[];inv.state.backpack={}
func run():
 var desktop:bool=ResourceLoader.exists("res://prototype/apartment.tscn")
 game=load("res://prototype/apartment.tscn" if desktop else "res://scenes/main.tscn").instantiate();root.add_child(game)
 for i in 12:await process_frame
 game.set_process(false);game.neighborhood.set_process(false)
 if desktop:game.fp_player.set_physics_process(false)
 else:game.neighborhood.physics_body.set_physics_process(false)
 for timer in game.find_children("*","Timer",true,false):timer.stop()
 game.session_paused=false;game.tutorial_active=false;game.daily_report_pending=false;game.customer_waiting=false
 game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide();game.phone_open=false;game.phone_panel.hide()
 inv=game.inventory_system;inv.set_process(false);ops=game.neighborhood.location_ops
 inv.ensure_state();inv.state.backpack_level=1;empty_bag()
 game.location_state.pickup_seeds={};game.location_state.pickup_fertilizer=0;game.location_state.deliveries={}
 game.location_state.active_property="apartment";game.location_state.operation_contents_property="apartment"
 var strain:String="Purple Dream"
 game.cash=0;game.untrimmed_inventory={strain:3};game.trimmed_inventory={};game.bagged_inventory={}
 game.products={};game.location_state.deliveries={}
 stand("apartment:packing")
 game._open_bagging_panel()
 check(inv.is_open() and inv.container_id=="apartment:packing" and not game.bagging_panel.visible,"Bench opens only the modern station screen")
 inv.select_item("apartment:packing","raw|"+strain)
 check(inv.packing_action!=null and not inv.packing_action.disabled,"Raw harvest exposes Trim by hand")
 inv.packing_action.pressed.emit()
 check(game.trim_panel.visible and not inv.is_open(),"Trim opens its work area without inventory overlay")
 for target in game.trim_targets:
  game.trim_scissors.position=target.position
  game._check_trim_collisions()
 check(int(game.trimmed_inventory.get(strain,0))==3 and int(game.untrimmed_inventory.get(strain,0))==0,"Trimming conserves the harvested three grams")
 game._close_trim_minigame()
 check(inv.is_open() and not game.bagging_panel.visible,"Finishing trim returns to modern bench")
 inv.select_item("apartment:packing","trimmed|"+strain)
 check(inv.packing_action!=null and not inv.packing_action.disabled,"Trimmed product exposes Bag by hand")
 inv.packing_action.pressed.emit()
 check(game.bag_minigame_panel.visible and not inv.is_open(),"Bagging opens its work area")
 for i in game.bag_target_units:
  game.bag_bud_token.global_position=game.bag_target_panel.global_position
  game._finish_bud_drag()
 game.bag_seal_button.pressed.emit()
 check(int(game.bagged_inventory.get(strain,0))==3 and int(game.trimmed_inventory.get(strain,0))==0,"Sealing transfers exactly three grams to packaged bench stock")
 check(inv.is_open() and not game.bagging_panel.visible,"Sealing returns to the modern bench")
 inv.select_item("apartment:packing","product|"+strain)
 check(inv.packing_action==null,"Packaged product does not offer reprocessing")
 var r=inv.transfer("apartment:packing","backpack","product|"+strain,3)
 check(r.ok and int(inv.contents("backpack").get("product|"+strain,0))==3,"Finished product goes into backpack")
 check(not inv.transfer("apartment:packing","backpack","product|"+strain,3).ok,"Repeated take cannot duplicate finished product")
 inv.close();stand("apartment:storage")
 var stored_before:int=int(game.advancement_stats.get("grams_stored",0))
 check(inv.transfer("backpack","apartment:storage","product|"+strain,3).ok,"Product can be carried to storage")
 check(int(game.products[strain].stock)==3 and not inv.contents("backpack").has("product|"+strain),"Store conserves product and empties the carried amount")
 check(int(game.advancement_stats.get("grams_stored",0))==stored_before+3,"Storage transfer retains progression credit")
 stand("apartment:supply")
 if desktop:
  var target:=Area3D.new();target.set_meta("interaction_id","station_supply");game.add_child(target);game.fp_target=target;game.fp_prompt.text="OLD PROMPT"
 else:game.neighborhood.action.visible=true
 inv._process(0)
 check(inv.nearby_button.visible,"New station button is available")
 check(game.fp_prompt.text.is_empty() if desktop else not game.neighborhood.action.visible,"Duplicate original station prompt is hidden")
 check(not game.contextual_button.visible,"Legacy contextual station button stays hidden")
 inv.close();game.untrimmed_inventory={};game.trimmed_inventory={};game.bagged_inventory={}
 for dimensions in [Vector2i(390,844),Vector2i(844,390),Vector2i(1280,800)]:
  root.content_scale_size=dimensions;root.size=dimensions
  stand("apartment:packing");inv.open_container("packing");inv.adding=true;inv.render()
  for i in 30:await process_frame
  var empties:=0
  for lbl in inv.columns.find_children("*","Label",true,false):
   if lbl.text=="No items in this category.":
    empties+=1
    check(lbl.size.x>=180 and lbl.size.y<=50,"Empty message reads horizontally at "+str(dimensions))
  check(empties==2,"Both empty inventories show one full-width message")
  var rect:Rect2=inv.panel.get_global_rect();var screen:Vector2=root.get_visible_rect().size
  check(rect.position.x>=0 and rect.position.y>=0 and rect.end.x<=screen.x+1 and rect.end.y<=screen.y+1,"Empty panels fit viewport at "+str(dimensions))
 inv.close();game.queue_free();await process_frame
 print("STATION_INVENTORY_TEST_RESULT: ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
