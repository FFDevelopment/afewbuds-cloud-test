extends SceneTree
const Actions=preload("res://scripts/production_actions.gd")
var errors:Array[String]=[]
func check(ok:bool,why:String):
 if not ok:errors.append(why);push_error(why)
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.set_process(false);game.neighborhood.set_process(false);game.neighborhood.physics_body.set_physics_process(false)
 game.session_paused=false;game.tutorial_active=false;game.daily_report_pending=false;game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide();game.visit_timer.stop()
 game.packing_employee_hired=true;game.packing_employee_active=true;game.production_worker_arrested=false;game.lay_low_active=false
 var crew=game.neighborhood.location_ops.crew
 var inv=game.inventory_system
 var strain:String=game.SEED_ORDER[0]
 game.untrimmed_inventory={strain:6};game.trimmed_inventory={strain:3};game.bagged_inventory={}
 inv.furniture.equipment_world.packing_visual_signatures.clear();inv.furniture.equipment_world.sync_packing_displays()
 var bench:Node3D=Actions.station(game);var stock_visual:Node=bench.get_node("PackingDisplayVisuals")
 check(not stock_visual.find_children("RawBud*","MeshInstance3D",true,false).is_empty(),"Raw harvest appears on owned bench tray")
 check(not stock_visual.find_children("TrimmedBud*","MeshInstance3D",true,false).is_empty(),"Trimmed stock remains visible on tray")
 var tray_mesh:MeshInstance3D=bench.find_child("TrimTray",true,false)
 if tray_mesh!=null:
  var bounds:=Actions.bounds_in(bench,tray_mesh)
  for nug in stock_visual.find_children("*Bud*","MeshInstance3D",true,false):
   check(nug.position.x>bounds.position.x and nug.position.x<bounds.end.x and nug.position.z>bounds.position.z and nug.position.z<bounds.end.z,"Stock buds stay on actual tray")
 var initial:=JSON.stringify([game.untrimmed_inventory,game.trimmed_inventory,game.bagged_inventory])
 var samples:=0
 for who in crew.FriendCharacters.NAMES:
  game.production_worker_friend_name=who
  for task in ["trim","bag","harvest","plant","water","fertilize"]:
   game.production_worker_pending_action=task;game.production_worker_pending_slot=0 if task in Actions.GROW_TASKS else -1;game.production_worker_pending_strain=strain
   var target:Variant=Actions.target(game,task,game.production_worker_pending_slot)
   check(target is Vector3,"Target exists "+task)
   if not target is Vector3:continue
   game.production_worker_target_position=target;game.production_worker_node.global_position=target
   crew.update_malik()
   var pose=crew.malik_worker.get_node("ProductionActions")
   for frame in 21:
    game.production_worker_action_dwell=Actions.duration(task)*float(frame)/20;pose.sync()
    check(pose.active==task,"Active pose "+who+" "+task)
    for bone in pose.rig.sk.get_bone_count():
     var transform:Transform3D=pose.rig.sk.get_bone_global_pose(bone)
     check(transform.origin.is_finite() and transform.basis.is_finite(),"Finite pose")
    samples+=1
   game.packing_employee_active=false;pose.sync();check(pose.active.is_empty() and not pose.bag.visible and not pose.scissors.visible,"Off duty clears props");game.packing_employee_active=true
 var world=inv.furniture.equipment_world
 var station_id:String=inv.furniture.model.primary(inv.worker_property(),"packing")
 var original_root:Node3D=world.rendered[station_id]
 var original_sku:String=inv.furniture.model.state.items[station_id].sku
 for tier in [1,2,3]:
  var sku:String="bench_"+str(tier);inv.furniture.model.state.items[station_id].sku=sku
  var placed:=Node3D.new();game.add_child(placed);inv.furniture.build_prop(placed,station_id,sku);world.rendered[station_id]=placed
  world.packing_visual_signatures.clear();world.sync_packing_displays()
  check(not placed.get_node("PackingDisplayVisuals").find_children("RawBud*","MeshInstance3D",true,false).is_empty(),"Placed tier shows harvest "+sku)
  for task in ["trim","bag"]:
   game.production_worker_pending_action=task;game.production_worker_pending_slot=-1;game.production_worker_pending_strain=strain
   game.production_worker_target_position=Actions.target(game,task,-1);game.production_worker_node.global_position=game.production_worker_target_position;game.production_worker_action_dwell=Actions.duration(task)*.45
   crew.update_malik();check(crew.malik_worker.get_node("ProductionActions").active==task,"Placed station animation "+sku+" "+task)
  crew.malik_worker.get_node("ProductionActions").stop();world.rendered[station_id]=original_root;placed.free()
 inv.furniture.model.state.items[station_id].sku=original_sku
 check(JSON.stringify([game.untrimmed_inventory,game.trimmed_inventory,game.bagged_inventory])==initial,"Visual samples never mutate inventory")
 game.production_worker_pending_action="trim";game.production_worker_pending_slot=-1;game.production_worker_pending_strain=strain
 game._execute_production_worker_action_local()
 check(int(game.untrimmed_inventory.get(strain,0))==3 and int(game.trimmed_inventory.get(strain,0))==6,"Trim commits one three-gram batch")
 game.production_worker_pending_action="bag";game.production_worker_pending_strain=strain;game._execute_production_worker_action_local()
 check(int(game.trimmed_inventory.get(strain,0))==3 and int(game.bagged_inventory.get(strain,0))==3,"Bag commits one three-gram batch")
 var committed:=JSON.stringify([game.untrimmed_inventory,game.trimmed_inventory,game.bagged_inventory]);game._execute_production_worker_action_local()
 check(JSON.stringify([game.untrimmed_inventory,game.trimmed_inventory,game.bagged_inventory])==committed,"Repeated completion does not duplicate product")
 game.plant_slots[0]={"strain":strain,"stage":game.STAGES.size()-1,"growth":100.0,"water":80.0,"health":100.0,"fertilizer":50.0,"dead":false}
 game._update_plant_visual(0)
 game.production_worker_pending_action="harvest";game.production_worker_pending_slot=0;game.production_worker_pending_strain=strain
 game.production_worker_target_position=Actions.target(game,"harvest",0);game.production_worker_node.global_position=game.production_worker_target_position;game.production_worker_action_dwell=2.0;crew.update_malik()
 check(int(game.plant_slots[0].stage)==game.STAGES.size()-1,"Harvest pose leaves crop intact before completion")
 game._execute_production_worker_action_local()
 check(int(game.plant_slots[0].stage)==-1,"Harvest completion clears the mature crop")
 var after_harvest:=JSON.stringify([game.untrimmed_inventory,game.inventory_system.state]);game._execute_production_worker_action_local()
 check(JSON.stringify([game.untrimmed_inventory,game.inventory_system.state])==after_harvest,"Harvest cannot award twice")
 game.seed_inventory[strain]=3;game.fertilizer_units=3
 for task in ["plant","water","fertilize"]:
  game.production_worker_pending_action=task;game.production_worker_pending_slot=0;game.production_worker_pending_strain=strain
  game.production_worker_target_position=Actions.target(game,task,0);game.production_worker_node.global_position=game.production_worker_target_position;game.production_worker_action_dwell=Actions.duration(task)*.5
  var before_tend:=JSON.stringify([game.seed_inventory,game.fertilizer_units,game.plant_slots])
  crew.update_malik()
  check(JSON.stringify([game.seed_inventory,game.fertilizer_units,game.plant_slots])==before_tend,"Tending pose consumes no supplies "+task)
  game._execute_production_worker_action_local()
  if task=="plant":check(int(game.seed_inventory[strain])==2 and int(game.plant_slots[0].stage)==0,"Plant consumes exactly one seed")
  if task=="water":check(float(game.plant_slots[0].water)==100.0,"Water completion fills target pot")
  if task=="fertilize":check(game.fertilizer_units==2 and float(game.plant_slots[0].fertilizer)==100.0,"Fertilizing consumes one use")
  var after_tend:=JSON.stringify([game.seed_inventory,game.fertilizer_units,game.plant_slots]);game._execute_production_worker_action_local()
  check(JSON.stringify([game.seed_inventory,game.fertilizer_units,game.plant_slots])==after_tend,"Tending cannot commit twice "+task)
 # Real update-loop boundary: commit progress without dropping the trimming pose.
 for slot in game.plant_slots:slot.stage=-1
 game.untrimmed_inventory={"Purple Dream":9,"Street Green":6};game.trimmed_inventory={};game.bagged_inventory={};game.production_worker_auto_plant=false
 game.production_worker_pending_action="";game._assign_production_worker_task()
 game.production_worker_node.global_position=game.production_worker_target_position;game.production_worker_action_dwell=3.98;crew.update_malik()
 var continuous_pose=crew.malik_worker.get_node("ProductionActions")
 var before_hand:Vector3=continuous_pose.rig.grip("R")
 game._update_production_worker_visual(.03);crew.update_malik()
 check(game.production_worker_pending_action=="trim" and game.production_worker_pending_strain=="Purple Dream","Same strain continues immediately without automation timer")
 check(continuous_pose.scissors.visible and continuous_pose.active=="trim","Scissors remain active across progress boundary")
 check(before_hand.distance_to(continuous_pose.rig.grip("R"))<.035,"Hand does not return to rest between portions")
 check(int(game.untrimmed_inventory.get("Purple Dream",0))==6,"Continuous animation still commits exactly one portion")
 for cycle in 2:
  game.production_worker_action_dwell=3.98;crew.update_malik();game._update_production_worker_visual(.03);crew.update_malik()
 game._update_production_worker_visual(0)
 check(game.production_worker_pending_strain=="Street Green" and game.production_worker_task_label.text.contains("STREET GREEN"),"Label announces the next strain when trimming switches")
 check(game.production_worker_task_label.position.y>=2.5 and game.production_worker_task_label.billboard==BaseMaterial3D.BILLBOARD_ENABLED,"Worker label stays above head and faces camera")
 # Palette regression: same colors/textures as plants, including future registered hybrids.
 game.seed_catalog["QA Future Cross"]={"profile":"solar"}
 var color_strains:Array[String]=["Purple Dream","QA Future Cross"]
 for color_strain in color_strains:
  game.untrimmed_inventory={color_strain:6};game.trimmed_inventory={color_strain:3};game.bagged_inventory={}
  world.sync_packing_displays()
  var pile:Node=original_root.get_node("PackingDisplayVisuals")
  var expected:Color=game._strain_visual_palette(color_strain).bud
  for nug in pile.find_children("*Bud*","MeshInstance3D",true,false):
   check(nug.get_meta("strain")==color_strain,"Tray refreshes when equal-weight strain changes")
   check(nug.mesh.material.albedo_color.is_equal_approx(expected) and nug.mesh.material.albedo_texture!=null,"Tray matches plant palette and texture")
  game.plant_slots[0]={"strain":color_strain,"stage":game.STAGES.size()-1,"growth":100.0,"water":100.0,"health":100.0,"fertilizer":100.0,"dead":false}
  for task in ["harvest","trim","bag"]:
   game.production_worker_pending_action=task;game.production_worker_pending_slot=0 if task=="harvest" else -1;game.production_worker_pending_strain=color_strain
   game.production_worker_target_position=Actions.target(game,task,game.production_worker_pending_slot);game.production_worker_node.global_position=game.production_worker_target_position;game.production_worker_action_dwell=Actions.duration(task)*.7
   crew.update_malik();var pose=crew.malik_worker.get_node("ProductionActions")
   check(pose.bud.material_override.albedo_color.is_equal_approx(expected),"Handled bud matches plant "+task)
   check(pose.bag_fill.material_override.albedo_color.is_equal_approx(expected),"Bag contents retain strain color")
 # Mixed stock must complete all trimming, then all bagging, then storage.
 for slot in game.plant_slots:slot.stage=-1
 game.production_worker_pending_action="";game.production_worker_auto_plant=false
 game.untrimmed_inventory={"Purple Dream":7,"QA Future Cross":5};game.trimmed_inventory={"Purple Dream":2};game.bagged_inventory={"QA Future Cross":1};game.products={};game.locker_weed={}
 var order:Array[String]=[]
 for step in 40:
  game._assign_production_worker_task_local()
  var task:String=game.production_worker_pending_action
  if task.is_empty():break
  order.append(task)
  if task=="bag":check(game._inventory_grams(game.untrimmed_inventory)==0,"No bagging until all raw stock is trimmed")
  if task=="store":check(game._inventory_grams(game.untrimmed_inventory)==0 and game._inventory_grams(game.trimmed_inventory)==0,"No storage trips until all stock is bagged")
  game._execute_production_worker_action_local()
 check(order.has("trim") and order.has("bag") and order.has("store"),"Worker completes all three processing stages")
 check(int(game.products.get("Purple Dream",{}).get("stock",0))==9 and int(game.products.get("QA Future Cross",{}).get("stock",0))==6,"Batch processing conserves grams and keeps strains separate")
 check(game._inventory_grams(game.untrimmed_inventory)+game._inventory_grams(game.trimmed_inventory)+game._inventory_grams(game.bagged_inventory)==0,"Batch finishes with an empty bench")
 game.products={"Purple Dream":{"stock":game._storage_capacity()}};game.locker_weed={"Purple Dream":game._dealer_locker_capacity()};game.bagged_inventory={"QA Future Cross":3};game.production_worker_pending_action=""
 game._assign_production_worker_task_local()
 check(game.production_worker_pending_action.is_empty() and int(game.bagged_inventory["QA Future Cross"])==3,"Full storage leaves finished bags on bench")
 game.untrimmed_inventory={"Purple Dream":3};game.plant_slots[0]={"strain":"Purple Dream","stage":1,"growth":10.0,"water":10.0,"health":100.0,"fertilizer":100.0,"dead":false}
 game._assign_production_worker_task_local();check(game.production_worker_pending_action=="water","Urgent plant care interrupts processing")
 game._execute_production_worker_action_local();game._assign_production_worker_task_local();check(game.production_worker_pending_action=="trim","Processing resumes after care")
 print("PRODUCTION_ACTIONS_RESULT ",JSON.stringify({"passed":errors.is_empty(),"samples":samples,"errors":errors}))
 print("PRODUCTION_ACTIONS_TEST_RESULT: "+("PASS" if errors.is_empty() else "FAIL"))
 quit(0 if errors.is_empty() else 1)
