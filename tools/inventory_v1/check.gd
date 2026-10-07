extends SceneTree
var game:Node3D
var inv:Node
var failures:=0
var checks:=0
func _initialize():call_deferred("run")
func check(ok:bool,title:String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("FAIL: "+title)
 else:print("PASS: ",title)
func frames(n:int=5):
 for i in n:await process_frame
func stand(id:String):
 game.camera.position=inv.POSITIONS[id]+Vector3(0,1.0,1.0)
func run():
 var desktop:bool=ResourceLoader.exists("res://prototype/apartment.tscn")
 if desktop:
  var cloud=root.get_node("AFBCloud")
  check(cloud.inventory_preview,"Desktop preview defaults to isolated saves")
  cloud.launched=true;cloud.session={"account_id":"inventory-fixture","username":"Preview","session_token":"not-a-real-token"}
  cloud.baseline={"cash":80,"lifetime_revenue":36130}
  cloud.queue_save({"cash":70,"lifetime_revenue":36130})
  check(cloud.pending.is_empty() and cloud.read_json(cloud.cache_path()).get("inventory_preview",false),"Desktop preview saves locally without queuing uploads")
  check((await cloud.request_rpc("afb_set_save",{})).has("error"),"Desktop preview blocks live save endpoint")
  check((await cloud.request_rpc("afb_leaderboard_report",{})).has("error"),"Desktop preview blocks leaderboard reporting")
  cloud.session={};cloud.launched=false
 game=load("res://prototype/apartment.tscn" if desktop else "res://scenes/main.tscn").instantiate();root.add_child(game)
 await frames(12)
 game.set_process(false);game.neighborhood.set_process(false)
 if desktop:game.fp_player.set_physics_process(false)
 else:game.neighborhood.physics_body.set_physics_process(false)
 for timer in game.find_children("*","Timer",true,false):timer.stop()
 game.session_paused=false;game.tutorial_active=false;game.daily_report_pending=false
 game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide()
 inv=game.inventory_system;inv.set_process(false)
 game.location_state.operation_contents_property="apartment"
 game.apartment_rent_state.lease_active=true
 game.seed_inventory={"Purple Dream":8};game.fertilizer_units=9
 game.location_state.carried_seeds={"Purple Dream":5};game.location_state.carried_fertilizer=3
 game.location_state.property_storage=["Grow Tent upgrade","Grow Tent upgrade"]
 game.cash=500
 inv.ensure_state();inv.state.backpack_level=4
 var first:Dictionary=inv.contents("apartment:supply")
 inv.ensure_state();inv.ensure_state()
 check(first==inv.contents("apartment:supply") and first.get("seed|Purple Dream")==8,"Repeated migration preserves existing shelf stock without duplication")
 check(inv.contents("backpack").get("seed|Purple Dream")==5 and inv.contents("backpack").cash==500,"Carried supplies and money retain exact quantities")
 check(inv.contents("backpack").get("equipment|Grow Tent upgrade")==2,"Paid packed equipment remains owned")
 stand("apartment:supply")
 inv.open_container("supply")
 check(inv.is_open() and inv.columns.get_child_count()==1,"Opening a shelf shows only that shelf")
 inv.adding=true;inv.render()
 check(inv.columns.get_child_count()==2,"Add Stock reveals backpack alongside the container")
 var rev:int=inv.revision
 check(inv.transfer("backpack","apartment:supply","seed|Purple Dream",3,rev).ok,"Store chosen seed quantity")
 check(game.seed_inventory["Purple Dream"]==11 and game.location_state.carried_seeds["Purple Dream"]==2,"Store changes both inventories exactly once")
 check(not inv.transfer("backpack","apartment:supply","seed|Purple Dream",1,rev).ok,"Duplicate submission with old revision cannot transfer twice")
 check(inv.transfer("apartment:supply","backpack","fertilizer",2).ok and game.fertilizer_units==7 and game.location_state.carried_fertilizer==5,"Take chosen fertilizer quantity")
 check(not inv.transfer("backpack","apartment:supply","cash",1).ok,"Shelf rejects cash")
 check(not inv.transfer("backpack","apartment:supply","equipment|Grow Tent upgrade",1).ok,"Shelf rejects furniture")
 check(not inv.transfer("backpack","apartment:supply","seed|Purple Dream",0).ok,"Zero quantity is rejected")
 check(not inv.transfer("backpack","apartment:supply","seed|Purple Dream",9999).ok,"Overdraw cannot lose or duplicate stock")
 game.fertilizer_units=game._supply_fertilizer_capacity()
 check(not inv.transfer("backpack","apartment:supply","fertilizer",1).ok,"Full shelf cannot accept more fertilizer")
 var old_count:int=game.seed_inventory["Purple Dream"]
 game.seed_inventory["Purple Dream"]-=1
 check(inv.contents("apartment:supply")["seed|Purple Dream"]==old_count-1,"Workers and planting share the shelf's live stock")
 game.camera.position=Vector3(90,2,10)
 check(not inv.transfer("apartment:supply","backpack","seed|Purple Dream",1).ok,"Transfers cannot access a remote container")
 inv.close();stand("apartment:storage")
 game._ensure_product_exists("Purple Dream");game.products["Purple Dream"].stock=20;game.products["Purple Dream"].reserved=5
 check(inv.available("apartment:storage","product|Purple Dream")==15,"Available product respects live reservation accounting")
 var total_before:int=20+int(inv.contents("backpack").get("product|Purple Dream",0))
 check(inv.transfer("apartment:storage","backpack","product|Purple Dream",5).ok,"Take packaged stock into backpack")
 check(game.products["Purple Dream"].stock+int(inv.contents("backpack").get("product|Purple Dream",0))==total_before,"Product transfer conserves grams")
 check(inv.transfer("backpack","apartment:storage","cash",25).ok and game.cash==475,"Stash can hold cash separately from carried money")
 check(inv.transfer("backpack","apartment:storage","equipment|Grow Tent upgrade",1).ok,"Store one paid equipment item")
 check(inv.transfer("apartment:storage","backpack","equipment|Grow Tent upgrade",1).ok and inv.contents("backpack").get("equipment|Grow Tent upgrade")==2,"Taking matching paid equipment preserves both items")
 check(inv.contents("apartment:storage").cash==25 and not inv.contents("apartment:supply").has("cash"),"Containers never expose each other's contents")
 game.property_opportunity_state.acquired=true;game.property_opportunity_state.relocated=true
 stand("house:storage")
 check(inv.transfer("backpack","house:storage","product|Purple Dream",2).ok,"House container has independent contents")
 check(inv.contents("house:storage").get("product|Purple Dream")==2 and game.products["Purple Dream"].stock==15,"House transfer cannot alter apartment stock")
 check(inv.property_has_items("apartment") and not game.neighborhood.location_ops.apartment_release_blockers().is_empty(),"Lease release refuses containers with contents")
 var state_copy:Dictionary=inv.state.duplicate(true)
 game._save_game()
 var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
 check(saved.location_state.container_inventory==JSON.parse_string(JSON.stringify(state_copy)),"Container ledger persists in the existing save schema")
 game.location_state.container_inventory=saved.location_state.container_inventory
 inv.ensure_state()
 check(inv.contents("house:storage").get("product|Purple Dream")==2 and inv.contents("apartment:storage").cash==25,"Reload preserves distinct property containers")
 game.apartment_rent_state.lease_active=false;stand("apartment:storage")
 check(not inv.transfer("apartment:storage","backpack","cash",1).ok,"Released property blocks access")
 game.apartment_rent_state.lease_active=true
 inv.close();inv.open_backpack()
 check(inv.is_open() and inv.columns.get_child_count()==1,"Backpack opens by itself")
 inv.set_process(true)
 for dimensions in [Vector2i(390,844),Vector2i(844,390),Vector2i(1280,800)]:
  root.content_scale_size=dimensions;root.size=dimensions;await frames()
  stand("apartment:supply");inv.open_container("supply");inv.adding=true;inv.select_item("backpack","seed|Purple Dream");await frames(30)
  var screen:Vector2=root.get_visible_rect().size
  check(inv.columns.vertical==(screen.y>screen.x),"Portrait stacks panels; landscape uses side-by-side at "+str(dimensions))
  var rect:Rect2=inv.panel.get_global_rect()
  check(rect.position.x>=0 and rect.position.y>=0 and rect.end.x<=screen.x+1 and rect.end.y<=screen.y+1,"Inventory stays within viewport at "+str(dimensions))
 inv.close()
 inv.relocate("apartment","house");game.location_state.operation_contents_property="house"
 check(inv.contents("house:storage").get("product|Purple Dream")==17,"Relocation merges existing destination stock without loss")
 check(inv.contents("house:storage").get("cash")==25 and not inv.property_has_items("apartment"),"Relocation moves stash extras and empties old property containers")
 game.queue_free();await frames()
 print("INVENTORY_TEST_RESULT: ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
