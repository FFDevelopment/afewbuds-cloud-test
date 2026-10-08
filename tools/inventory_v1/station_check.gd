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
 game.camera.position=inv.all_positions()[id]+Vector3(2 if inv.all_positions()[id].x<0 else -2,.34,0)
 game.camera.look_at(inv.all_positions()[id])
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
 check(inv.packing.active and not inv.is_open(),"Trim opens physical work area without inventory overlay")
 inv.packing.selected=0;inv.packing.use_selected();inv.packing.selected=1
 for i in range(3):inv.packing.use_selected()
 check(int(game.trimmed_inventory.get(strain,0))==3 and int(game.untrimmed_inventory.get(strain,0))==0,"Trimming conserves the harvested three grams")
 check(inv.is_open() and not game.bagging_panel.visible,"Finishing trim returns to modern bench")
 inv.select_item("apartment:packing","trimmed|"+strain)
 check(inv.packing_action!=null and not inv.packing_action.disabled,"Trimmed product exposes Bag by hand")
 inv.packing_action.pressed.emit()
 check(inv.packing.active and not inv.is_open(),"Bagging opens physical work area")
 while inv.packing.progress<inv.packing.amount:
  inv.packing.selected=0;inv.packing.use_selected();inv.packing.selected=1;inv.packing.use_selected()
 inv.packing.selected=2;inv.packing.use_selected()
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
 check(not inv.nearby_button.visible if desktop else inv.nearby_button.visible,"Platform uses one station prompt")
 check(game.fp_prompt.text=="OLD PROMPT" if desktop else not game.neighborhood.action.visible,"Desktop retains its door-style prompt; mobile hides its duplicate")
 check(not game.contextual_button.visible,"Legacy contextual station button stays hidden")
 inv.open_container("supply")
 var tabs:Array=[]
 for tab in inv.filter_bar.get_children():
  if tab.visible:tabs.append(tab.text)
 check(tabs==["All","Supplies","Seeds"],"Grow shelf exposes only All, Supplies and Seeds filters")
 inv.set_filter("Seeds")
 check(inv.filter_matches("seed|Purple Dream") and not inv.filter_matches("fertilizer"),"Seeds filter shows seeds only")
 inv.set_filter("Supplies")
 check(inv.filter_matches("fertilizer") and not inv.filter_matches("seed|Purple Dream"),"Shelf supplies filter shows fertilizer only")
 game.location_state.carried_seeds={"Purple Dream":2};game.location_state.carried_fertilizer=2
 game.cash=100;game.location_state.property_storage=["Grow Tent upgrade"];inv.state.backpack={"product|Purple Dream":2}
 inv.adding=true;inv.render()
 var backpack_frame:Node=inv.columns.get_child(1)
 var items:Array=[]
 for control in backpack_frame.find_children("*","Button",true,false):
  if not control.tooltip_text.is_empty():items.append(control.tooltip_text)
 check(items.size()==2 and str(items).contains("Fertilizer") and str(items).contains("Seeds"),"Add Stock hides cash, equipment and product at the grow shelf")
 inv.close();inv.open_backpack()
 check(inv.contents("backpack").has("cash") and inv.contents("backpack").has("equipment|Grow Tent upgrade") and inv.contents("backpack").has("product|Purple Dream"),"Shelf filtering never removes unrelated owned items")
 check(inv.nearby_button.anchor_left==(.5 if desktop else 1.0) and inv.nearby_button.anchor_top==1.0,"Mobile interaction is bottom-right; desktop keeps its existing placement")
 empty_bag();game.cash=0
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
 inv.close()
 game.cash=10000
 var locker:String=inv.furniture.model.own("dealer_1")
 check(inv.furniture.model.place(locker,"apartment",Vector3(3.9,0,-2.2),90),"Place owned dealer locker for interaction checks")
 inv.furniture.sync_world()
 for kind in ["supply","storage","dealer","packing"]:
  stand("apartment:"+kind)
  if not desktop:
   game.current_room="grow" if kind=="supply" else "main"
   game.neighborhood.active=true;game.neighborhood.in_station=false
   game.neighborhood._sync_physics_from_camera()
   game.neighborhood._process(0)
   inv._process(0)
   game.neighborhood.mobile_hud.update(0)
   check(inv.nearby_button.visible and not game.neighborhood.action.visible,"Only modern mobile interaction survives both HUD updates: "+kind)
   var native:String={"supply":"station_supply","storage":"station_storage","dealer":"station_locker","packing":"station_workbench"}[kind]
   game.neighborhood._open_station(native)
   check(inv.is_open() and not game.neighborhood.in_station,"Mobile interaction bypasses old close-up controls: "+kind)
   inv.close()
 for item in ["seed|Purple Dream","fertilizer","cash","product|Purple Dream","raw|Purple Dream","equipment|Grow Tent upgrade"]:
  var texture:Texture2D=inv.art(item)
  check(texture!=null and texture.get_width()>=1024,"High-resolution inventory art: "+item)
 inv.close();game.queue_free();await process_frame
 print("STATION_INVENTORY_TEST_RESULT: ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
