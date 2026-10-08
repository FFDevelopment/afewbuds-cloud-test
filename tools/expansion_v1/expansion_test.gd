extends SceneTree
var failures:=0
var checks:=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
 else:print("PASS ",label)
func run():
 var desktop:=ResourceLoader.exists("res://prototype/apartment.tscn")
 var game=load("res://prototype/apartment.tscn" if desktop else "res://scenes/main.tscn").instantiate();root.add_child(game)
 for i in range(15):await process_frame
 game.set_process(false);game.neighborhood.set_process(false)
 if desktop:game.fp_player.set_physics_process(false)
 else:game.neighborhood.physics_body.set_physics_process(false)
 for timer in game.find_children("*","Timer",true,false):timer.stop()
 game.tutorial_active=false;game.session_paused=false;game.daily_report_pending=false
 game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide()
 var inv=game.inventory_system;inv.set_process(false);inv.guide.state.active=false;inv.guide.state.completed=true
 inv.furniture.set_process(false)
 var market=game.neighborhood.location_ops
 market.market()
 check(market.is_open(),"Central Market opens with platform adapter")
 market.equipment()
 check(market.is_open(),"Upgrades category opens")
 market.market_grow_tents()
 check(inv.furniture.is_open() and inv.furniture.hint.text=="UPGRADES / GROW TENTS","Grow tents open under Upgrades")
 market.market_furniture()
 check(inv.furniture.is_open() and "FURNITURE" in inv.furniture.hint.text,"Furniture category opens at Central Market")
 inv.furniture.close()
 var m=inv.furniture.model
 game.cash=10000;game.property_opportunity_state={"acquired":true,"first_entry":true,"relocated":true}
 game.location_state.operation_contents_property="house"
 var chair:String=m.own("armchair");var table:String=m.own("coffee_table")
 check(m.place(chair,"house",Vector3(28,0,-2),0),"Place purchased chair")
 check(m.place(table,"house",Vector3(30,0,-2),0),"Place purchased table")
 inv.furniture.sync_world()
 check(inv.furniture.rendered.size()==2,"Placed furniture has physical world instances")
 m.lock(chair,false);m.pack(chair);inv.furniture.sync_world()
 check(inv.furniture.rendered.size()==1,"Packing removes world instance")
 m.place(chair,"house",Vector3(28,0,-2),0)
 var story=inv.furniture.chapter
 game.advancement_stats.harvests=100;game.advancement_stats.grams_trimmed=1000;game.advancement_stats.bags_sealed=50;game.advancement_stats.sales=100;game.advancement_stats.dealer_sales=20
 story.tick()
 check(story.stage()==1,"Furniture milestone advances once")
 check(not story.ready(),"Old career harvest totals do not complete new chapter")
 for i in range(game.plant_slots.size()):game.plant_slots[i]=game._empty_plant_slot()
 m.lock("legacy_tent_0",false)
 check(m.place("legacy_tent_0","house",Vector3(41.8,0,-12),0),"Legacy tent placeable in house")
 inv.furniture.sync_world();m.lock("legacy_tent_0",false);m.pack("legacy_tent_0");inv.furniture.sync_world()
 check(game.plant_visuals[0].get_node("PlantHitArea0").collision_layer==0,"Packed tent disables plant interactions")
 check(m.powered_tent_count("house")==0,"Packed tent does not consume electricity")
 check(m.place("legacy_tent_0","house",Vector3(41.8,0,-12),0),"Packed tent can be placed again")
 inv.furniture.sync_world()
 check(game.plant_visuals[0].get_node("PlantHitArea0").collision_layer==8,"Replaced tent restores plant interactions")
 check(m.powered_tent_count("house")==1,"Placed tent power belongs to its property")
 game.advancement_stats.harvests+=3;story.tick()
 check(story.stage()==2,"House harvest milestone advances")
 game.advancement_stats.grams_trimmed+=30;game.advancement_stats.bags_sealed+=5;story.tick()
 check(story.stage()==3,"Craft milestone advances")
 game.advancement_stats.sales+=7;game.advancement_stats.dealer_sales+=2;story.tick()
 check(story.stage()==4,"Customer milestone advances")
 game.location_state.house_bills_paid=1;story.tick()
 check(story.stage()==5,"House bills milestone advances")
 game.lifetime_revenue+=2500;game.advancement_stats.sales+=5;game.heat=26
 check(not story.meet_rod(),"Finale requires low heat")
 game.heat=20
 check(story.meet_rod() and story.complete(),"Chapter 5 can complete")
 var cash:int=game.cash
 check(not story.meet_rod() and game.cash==cash,"Finale reward cannot be claimed twice")
 var packing=inv.packing
 game.untrimmed_inventory={"Street Green":8};game.trimmed_inventory={};game.bagged_inventory={}
 packing.start("raw|Street Green")
 check(packing.active and packing.targets.size()==3,"Packing uses objects in the world")
 packing.selected=1;packing.use_selected()
 check(packing.progress==0,"Scissors required before trimming")
 packing.selected=0;packing.use_selected();packing.selected=1;packing.use_selected();packing.close(false)
 check(game.untrimmed_inventory["Street Green"]==8 and int(game.trimmed_inventory.get("Street Green",0))==0,"Canceling trim conserves inventory")
 packing.start("raw|Street Green");packing.selected=0;packing.use_selected();packing.selected=1
 for i in range(8):packing.use_selected()
 check(game.untrimmed_inventory["Street Green"]==0 and game.trimmed_inventory["Street Green"]==8,"Trimming conserves exact grams")
 inv.close();packing.start("trimmed|Street Green")
 packing.selected=2;packing.use_selected()
 check(int(game.bagged_inventory.get("Street Green",0))==0,"Cannot seal an empty bag")
 var amount:int=packing.amount
 while packing.progress<packing.amount:
  packing.selected=0;packing.use_selected();packing.selected=1;packing.use_selected()
 packing.selected=2;packing.use_selected()
 check(game.bagged_inventory["Street Green"]==amount and game.trimmed_inventory["Street Green"]==8-amount,"Sealing conserves exact grams")
 print("EXPANSION_TEST_RESULT: ","PASS" if failures==0 else "FAIL"," checks=",checks)
 game.queue_free();await process_frame;quit(0 if failures==0 else 1)
