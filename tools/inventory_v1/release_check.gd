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
 game.seed_inventory={strain:3};game.fertilizer_units=3
 game.location_state.carried_seeds={strain:2};game.location_state.carried_fertilizer=2
 game.plant_slots[0]=game._empty_plant_slot()
 var before_weight:int=inv.backpack_weight()
 game._plant_seed(0,strain)
 check(game.location_state.carried_seeds[strain]==1 and game.seed_inventory[strain]==3,"Planting consumes one carried seed before shelf stock")
 check(inv.backpack_weight()<before_weight,"Using a seed releases its backpack weight")
 game._plant_seed(0,strain)
 check(game.location_state.carried_seeds[strain]==1,"Occupied pot cannot consume another seed")
 game._fertilize_plant(0)
 check(game.location_state.carried_fertilizer==1 and game.fertilizer_units==3,"Fertilizing consumes one carried item before shelf stock")
 game.plant_slots[0].fertilizer=100.0;game._fertilize_plant(0)
 check(game.location_state.carried_fertilizer==1,"Already fertilized plant cannot consume an item")
 game.plant_slots[0]=game._empty_plant_slot();game._plant_seed(0,strain,false)
 check(game.location_state.carried_seeds[strain]==1 and game.seed_inventory[strain]==2,"Workers use shelf seeds without touching backpack")
 game.location_state.carried_seeds={};game.plant_slots[0]=game._empty_plant_slot();game._plant_seed(0,strain)
 check(game.seed_inventory[strain]==1,"Manual planting still uses shelf when backpack is empty")
 game.products={};game._ensure_product_exists(strain);game.products[strain].stock=8;game.products[strain].reserved=5;game.products[strain].listed=true
 inv.set_amount("backpack","product|"+strain,4)
 check(game._player_available_amount(strain)==7,"Sales combine carried product with unreserved stored stock")
 check(not game._consume_player_sale_stock(strain,8) and game.products[strain].stock==8 and game._carried_amount("product|"+strain)==4,"Oversized sale is atomic and leaves both sources unchanged")
 check(game._consume_player_sale_stock(strain,6) and game.products[strain].stock==6 and game._carried_amount("product|"+strain)==0,"Sale consumes backpack first, then only remaining storage quantity")
 check(game.products[strain].reserved==5 and game._available_amount(strain)==1,"Existing storage reservations remain protected")
 game.products[strain].listed=false;inv.set_amount("backpack","product|"+strain,2)
 check(game._player_product_sellable(strain) and game._player_available_amount(strain)==2,"Carried product can be offered without listing stored product")
 var price:int=game._effective_price(strain)
 for level in [1,2,3]:
  game.bagging_level=level
  check(game._effective_price(strain)==price,"Bench level %d does not change product price" % level)
  game.trimmed_inventory={strain:13};game.bagged_inventory={};game._start_bag_minigame(strain)
  for frame in 3:await process_frame
  var target:int=game.bag_target_units;var drops:=0
  while game.bag_current_units<target:
   game.bag_bud_token.global_position=game.bag_target_panel.global_position;game._finish_bud_drag();drops+=1
  check(drops==3,"Bench level %d packs its larger batch in three drops" % level)
  game._seal_current_bag()
  check(int(game.trimmed_inventory.get(strain,0))+int(game.bagged_inventory.get(strain,0))==13,"Bench level %d conserves product through sealing" % level)
  if game.bag_minigame_panel.visible:game._close_bag_minigame()
  inv.close()
 game._save_game()
 var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
 check(int(saved.bagging_level)==3,"Purchased bench upgrade persists")
 game.camera.position=Vector3(3,1.64,4.35);game.camera.look_at(ops.APT_PC)
 ops.computer("apartment");ops.manage("inventory")
 var text:String=""
 for label_node in ops.ui.body.find_children("*","Label",true,false):text+=label_node.text
 check(not "SUPPLY SHELF" in text and not "CARRIED" in text and not "Add Stock" in text,"Computer inventory page has no obsolete supply instructions")
 for size in [Vector2i(390,844),Vector2i(844,390)]:
  root.content_scale_size=size;root.size=size;ops.ui.resize();ops.clear("COMPUTER")
  for i in 20:ops.b("Row %d" % i,func():pass)
  ops.ui.button("CLOSE COMPUTER",ops.close)
  for frame in 5:await process_frame
  check(ops.ui.panel.get_global_rect().end.x<=root.get_visible_rect().size.x and ops.ui.panel.get_global_rect().end.y<=root.get_visible_rect().size.y,"Computer fits viewport %s" % size)
  check(ops.ui.scroll.get_v_scroll_bar().max_value>ops.ui.scroll.size.y,"Long computer menus overflow vertically %s" % size)
  var position:Vector2=ops.ui.scroll.global_position+Vector2(40,ops.ui.scroll.size.y-40)
  var down:=InputEventScreenTouch.new();down.index=0;down.position=position;down.pressed=true;inv._input(down)
  var drag:=InputEventScreenDrag.new();drag.index=0;drag.position=position-Vector2(0,100);drag.relative=Vector2(0,-100);inv._input(drag)
  check(ops.ui.scroll.scroll_vertical>=int(90/ops.ui.panel.scale.y),"Touch swipe scrolls computer menu %s" % size)
  down.pressed=false;down.position=drag.position;inv._input(down)
  check(ops.ui.footer.get_child_count()==1 and ops.ui.footer.get_global_rect().end.y<=root.get_visible_rect().size.y,"Close stays visible outside scrolling content %s" % size)
 ops.close();game.queue_free();await process_frame
 print("RELEASE_READINESS_TEST_RESULT: ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
