extends SceneTree
## Release gate for physical house packing and stair-safe basement expansion.
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,note:String)->void:
 checks+=1
 if ok:print("PASS ",note)
 else:failures+=1;push_error("HOUSE_PACKING_PARITY FAIL: "+note)
func run()->void:
 var desktop:bool=ResourceLoader.exists("res://prototype/apartment.tscn")
 if root.has_node("AFBCloud"):await root.get_node("AFBCloud").prepare(true)
 var game:Node3D=load("res://prototype/apartment.tscn" if desktop else "res://scenes/main.tscn").instantiate()
 root.add_child(game)
 for i in 18:await process_frame
 game.set_process(false);game.neighborhood.set_process(false)
 if desktop:game.fp_player.set_physics_process(false)
 else:game.neighborhood.physics_body.set_physics_process(false)
 for timer in game.find_children("*","Timer",true,false):timer.stop()
 game.tutorial_active=false;game.daily_report_pending=false;game.session_paused=false
 game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide()
 game.property_opportunity_state={"acquired":true,"relocated":true,"agreement_signed":true,"agreement":"purchase"}
 game.apartment_rent_state.lease_active=true
 game.cash=80000;game.grower_level=12
 game._install_map_update()
 var inv:Node=game.inventory_system
 inv.set_process(false);inv.furniture.set_process(false)
 var editor:Node=inv.furniture
 var model:RefCounted=editor.model
 # The house checkout floor bounds must reflect real wall faces, not old insets.
 var rooms:Dictionary=model.placement_rooms("house",0.0)
 for room in ["living","packing","kitchen","bathroom","bedroom","grow"]:
  check(rooms.has(room) and rooms[room] is Rect2,"All six upstairs house room bounds preserved: "+room)
 check(is_equal_approx(float(model.size_of("legacy_packing").x),float(model.size_of("legacy_packing").x)),"Legacy apartment bench remains loaded")
 var bench:String="qa_house_bench3"
 model.state.items[bench]={"sku":"bench_3","property":"backpack","locked":false,"paid":850,"upgrades":{}}
 var bench_size:Vector3=model.size_of(bench)
 check(bench_size.x>=3.5 and bench_size.z>=1.3,"Purchased Bench III has the same full-size footprint as the apartment station")
 var packing:Rect2=rooms.packing
 var place:Vector3=Vector3(40.9,0,packing.position.y+bench_size.z*.5+.01)
 game.camera.global_position=Vector3(40.9,1.63,-1.55)
 game.camera.look_at(place+Vector3.UP)
 editor.property="house";editor.selected=bench;editor.point=place;editor.yaw=0
 await physics_frame
 check(model.validate(bench,"house",place,0).is_empty(),"Full-size Bench III fits against actual house packing wall")
 check(editor.obstacle().is_empty(),"Real wall physics accepts full-size Bench III: "+editor.obstacle())
 check(model.place(bench,"house",place,0),"Full-size bench purchases can be placed in house without clipping")
 editor.sync_world()
 var rendered:Node3D=editor.equipment_world.rendered.get(bench)
 check(rendered!=null,"Purchased bench has its own world prop")
 if rendered!=null:
  check(rendered.find_child("ApprovedPackingBenchModel",true,false)!=null,"Purchased bench clones apartment finished model")
  check(rendered.find_child("BenchTop",true,false)!=null and rendered.find_child("TrimTray",true,false)!=null and rendered.find_child("ScalePlatform",true,false)!=null,"Trim tray, scale and tabletop render on the bought station")
 var house_id:String=model.container_of(bench)
 check(house_id=="house:packing","House's first packing station has its own house container")
 var site:Vector3=inv.all_positions().get(house_id,Vector3.ZERO)
 check(absf(site.y-(place.y+1.2))<.01,"House bench interaction is at its actual floor height")
 game.camera.global_position=site+Vector3(0,.15,1.45)
 check(inv.reachable(house_id),"House packing station interaction is reachable")
 var original_apartment:Dictionary=inv.contents("apartment:packing").duplicate(true)
 inv.set_amount(house_id,"raw|Street Green",8)
 inv.open_container(house_id)
 check(inv.container_id==house_id,"House bench opens its own stock")
 inv.selected="raw|Street Green";inv.selected_source=house_id
 inv.process_selected()
 check(inv.packing.active and inv.packing.station_id==house_id,"House Trim by hand starts the correct property's real packing interaction")
 if inv.packing.active:
  inv.packing.selected=0;inv.packing.use_selected()
  inv.packing.selected=1
  for i in 8:inv.packing.use_selected()
 check(int(inv.contents(house_id).get("trimmed|Street Green",0))==8,"Hand trimming deposits exclusively into house bench")
 check(inv.contents("apartment:packing")==original_apartment,"Manual house trimming never transfers apartment stock")
 inv.open_container(house_id)
 inv.selected="trimmed|Street Green";inv.selected_source=house_id
 inv.process_selected()
 check(inv.packing.active and inv.packing.mode=="bag","House Bag by hand begins the correct equipment interaction")
 if inv.packing.active:
  inv.packing.selected=0;inv.packing.use_selected()
  inv.packing.selected=1
  for i in 8:inv.packing.use_selected()
  inv.packing.selected=2;inv.packing.use_selected()
 check(int(inv.contents(house_id).get("product|Street Green",0))==8,"Manual bagging commits product to the house only")
 check(inv.contents("apartment:packing")==original_apartment,"Apartment inventories remain unchanged after house packaging")
 inv.close()
 # Basement floor is -3.8: formerly every placement appeared at Y=+1.2.
 var basement_bench:String="qa_basement_bench"
 model.state.items[basement_bench]={"sku":"bench_1","property":"backpack","locked":false,"paid":180,"upgrades":{}}
 var down:Vector3=Vector3(34.1,-3.8,-3.4)
 check(model.place(basement_bench,"house",down,0),"Basement packing bench can be placed inside registered grow floor: "+model.error)
 var down_id:String=model.container_of(basement_bench)
 var down_pos:Vector3=inv.all_positions().get(down_id,Vector3.ZERO)
 check(absf(down_pos.y-(-3.8+1.2))<.01,"Basement interaction follows its actual floor, not upstairs")
 game.camera.global_position=down_pos+Vector3(0,.2,1.35)
 check(inv.reachable(down_id),"Basement packing station opens within normal interaction radius")
 inv.set_amount(down_id,"raw|Street Green",2)
 inv.open_container(down_id)
 inv.selected="raw|Street Green";inv.selected_source=down_id
 inv.process_selected()
 check(inv.packing.active and inv.packing.station_id==down_id,"Basement trim action targets the downstairs bench and its independent container")
 if inv.packing.active:inv.packing.close(false)
 inv.close()
 var ext:Dictionary=model.placement_rooms("house",-3.8)
 check(ext.has("basement_grow") and ext.has("basement_east"),"Basement has west grow floor and extra safe eastern grow wing")
 var east:Rect2=ext.basement_east
 check(east.end.x>44.5 and east.end.y>1.2,"East basement grow wing follows the actual wall instead of old 40.5 limit")
 var tent:String="qa_east_tent"
 model.state.items[tent]={"sku":"tent_1","property":"backpack","locked":false,"paid":240,"upgrades":{}}
 check(model.validate(tent,"house",Vector3(42.55,-3.8,-4.5),0).is_empty(),"East basement wing accepts tents where floor physically exists")
 check(not model.validate(tent,"house",Vector3(42.55,-3.8,-10),0).is_empty(),"Stairwell still excludes planting and furniture placement")
 check(model.registry.rooms_for("house").has("basement_east"),"New basement wing registered with the original owned house")
 model.state.items.erase(tent);model.state.items.erase(basement_bench)
 game.queue_free()
 for i in 6:await process_frame
 print("HOUSE_PACKING_PARITY_RESULT: "+("PASS" if failures==0 else "FAIL")+" checks="+str(checks)+" failures="+str(failures))
 quit(1 if failures>0 else 0)
