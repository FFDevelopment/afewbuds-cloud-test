extends SceneTree
var failures:=0
var checks:=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 checks+=1
 if ok:print("PASS ",label)
 else:failures+=1;push_error(label)
func ready_plant(strain:String) -> Dictionary:
 return {"strain":strain,"stage":3,"growth":100.0,"water":80.0,"health":100.0,"fertilizer":0.0,"dead":false}
func run():
 var desktop:=ResourceLoader.exists("res://prototype/apartment.tscn")
 if root.has_node("AFBCloud"):root.get_node("AFBCloud").inventory_preview=true
 var game=load("res://prototype/apartment.tscn" if desktop else "res://scenes/main.tscn").instantiate();root.add_child(game)
 for i in 20:await process_frame
 game.set_process(false);game.neighborhood.set_process(false)
 if desktop:game.fp_player.set_physics_process(false)
 else:game.neighborhood.physics_body.set_physics_process(false)
 for timer in game.find_children("*","Timer",true,false):timer.stop()
 game.gameplay_ready=true;game.tutorial_active=false;game.session_paused=false;game.daily_report_pending=false
 game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide()
 var dialogue=load("res://scripts/phone_dialogue.gd")
 var first:String=dialogue.compose(game,"Malik","closed",{"property":"house"})
 game.location_state=JSON.parse_string(JSON.stringify(game.location_state))
 var second:String=dialogue.compose(game,"Malik","closed",{"property":"house"})
 check(first!=second and first.contains("house") and second.contains("house"),"Dialogue varies across save reloads and names the actual property")
 for intent in dialogue.LINES:
  var body:String=dialogue.compose(game,"Rod",intent,{"property":"house","status":"closed","when":"soon","client":"Malik","qty":7,"product":"Street Green"})
  check(not body.contains("{") and not body.is_empty(),"Dialogue context resolves: "+intent)
 var inv=game.inventory_system;inv.set_process(false);inv.guide.state.active=false;inv.guide.state.completed=true;inv.furniture.set_process(false)
 var model=inv.furniture.model;var genetics=game.genetics_system
 game.cash=100000;game.grower_level=20;game.heat=0;game.property_opportunity_state={"acquired":true,"agreement_signed":true,"agreement":"purchase","relocated":true}
 game.packing_employee_hired=true;game.packing_employee_active=true;game.dealer_count=1;game.dealers_active=true
 var crew=game.neighborhood.location_ops.crew;var shop=crew.shop
 var worker:String=game._critical_production_sender()
 game.location_state.staff_assignments[worker]="house"
 game.location_state.staff_assignments["Hired Dealer 1"]="apartment"
 var controls=game.neighborhood.house_controls
 controls.states["living"]=true;controls.states["bedroom"]=false;controls.states["grow_lights"]=true;controls.states["grow_ventilation"]=true
 game.main_ceiling_light_on=true;game.grow_lights_on=true;game.floor_lamp_on=false;game.ventilation_on=true
 shop.command(worker,"close")
 check(not shop.is_open("house") and game.business_open and controls.states.living,"House close is local and keeps equipment on")
 shop.command(worker,"open")
 check(shop.is_open("house"),"On-duty house employee can reopen")
 shop.command(worker,"shutdown")
 check(shop.laying_low("house") and not controls.states.living and not controls.states.grow_lights and not controls.states.grow_ventilation,"House lay low switches equipment off")
 check(game.main_ceiling_light_on and game.grow_lights_on and game.business_open,"House shutdown never touches apartment equipment or shop")
 check(not shop.production_allowed() and shop.dealer_allowed("Hired Dealer 1"),"House production pauses while apartment dealer remains eligible")
 var snapshot:String=JSON.stringify(shop.record("house").equipment_before_shutdown)
 shop.command(worker,"shutdown")
 check(JSON.stringify(shop.record("house").equipment_before_shutdown)==snapshot,"Repeated shutdown preserves original settings")
 game.heat=80;shop.command(worker,"reopen")
 check(shop.laying_low("house") and not controls.states.living,"Blocked reopen does not restore equipment")
 game.heat=0;shop.command(worker,"reopen")
 check(controls.states.living and controls.states.grow_lights and not controls.states.bedroom and shop.production_allowed(),"Set Up restores exactly the previous switches")
 shop.command("Hired Dealer 1","shutdown")
 check(game.lay_low_active and not game.grow_lights_on and not game.ventilation_on and shop.is_open("house"),"Apartment shutdown remains local")
 shop.command("Hired Dealer 1","reopen")
 check(game.business_open and game.grow_lights_on and game.ventilation_on and not game.floor_lamp_on,"Apartment equipment restores with off switches preserved")
 game.packing_employee_active=false;shop.command(worker,"close")
 check(shop.is_open("house"),"Off-duty employees cannot close remote property")
 for cat in ["equipment|Grow Tent","delivery|Paid Tent","furniture|legacy_sofa"]:
  check(not inv.accepts("apartment:storage",cat) and not inv.accepts("house:storage",cat),"Both properties reject "+cat)
 # Every supported tent size uses its own slot membership; never adjacent tents.
 var originals:Dictionary=model.state.items.duplicate(true)
 for count in [1,2,3,4]:
  var sku:String=""
  for key in model.CATALOG:
   if int(model.CATALOG[key].get("plants",0))==count:sku=key;break
  check(not sku.is_empty(),"Catalog supports "+str(count)+"-plant tent")
  if sku.is_empty():continue
  model.state.items={"test_tent":{"sku":sku,"property":"apartment","position":[0,0,-9],"slots":range(count)}}
  game.plant_slots.clear()
  for i in count:game.plant_slots.append(ready_plant(["Purple Dream","Blue Frost","Citrus Rush","Velvet Haze"][i]))
  for i in count:genetics.planted(i)
  if count>1:
   for attempt in 10000:
    genetics.state().salt=str(attempt)
    if genetics.pair_roll(game.plant_slots[0],game.plant_slots[1])<genetics.CROSS_CHANCE_PERCENT:break
  var found:Array=genetics.harvest(0)
  check(found.is_empty() if count==1 else not found.is_empty(),str(count)+"-plant cross eligibility")
  var prior:int=int(game.advancement_stats.hybrids_created)
  genetics.harvest(0)
  check(int(game.advancement_stats.hybrids_created)==prior,"Pair outcome cannot repeat on reopening/harvesting again")
  if count>1:
   check(game.seed_catalog.has(str(found[0])) and game.SEED_ORDER.has(str(found[0])),"Discovered seed enters live catalog and planting choices")
 # Same strains and dead plants cannot cross.
 check(not genetics.eligible(ready_plant("Purple Dream"),ready_plant("Purple Dream")),"Identical strains excluded")
 var dead:Dictionary=ready_plant("Blue Frost");dead.dead=true
 check(not genetics.eligible(ready_plant("Purple Dream"),dead),"Dead parent excluded")
 var custom:String=genetics.discover("Street Green","Citrus Rush","test_tent","house")
 var child:String=genetics.discover(custom,"Blue Frost","test_tent","house")
 check(game.seed_catalog.has(child),"Discovered strains can parent future generations")
 var reverse:String=genetics.discover("Blue Frost",custom,"test_tent","house")
 check(reverse==child,"Parent order gives same stable lineage and name")
 var salt:String=str(genetics.state().salt)
 var serialized:String=JSON.stringify(game.location_state)
 game.location_state=JSON.parse_string(serialized);genetics.setup(game);inv.ensure_state()
 check(str(genetics.state().salt)==salt and game.seed_catalog.has(child),"Save round-trip preserves odds and dynamic strain definitions")
 inv.set_amount("backpack","fertilizer",200)
 genetics.state().pending[child]=1
 genetics.claim_pending(false)
 check(int(genetics.state().pending.get(child,0))==1,"Full backpack preserves seed as pending journal reward")
 inv.set_amount("backpack","fertilizer",0)
 genetics.claim_pending(false)
 check(not genetics.state().pending.has(child) and int(inv.contents("backpack").get("seed|"+child,0))>0,"Earned seed claims into backpack after freeing capacity")
 var before_seeds:String=JSON.stringify(inv.contents("backpack"))
 game._create_genetics_cross("frozen_purple")
 check(JSON.stringify(inv.contents("backpack"))==before_seeds,"Removed phone crafting cannot create or consume seeds")
 model.state.items=originals
 for player in game.find_children("*","AudioStreamPlayer",true,false):player.stop();player.stream=null
 game.queue_free();await process_frame;await process_frame
 print("PROPERTY_GAMEPLAY_RESULT: PASS" if failures==0 else "PROPERTY_GAMEPLAY_RESULT: FAIL checks=%d failures=%d" % [checks,failures])
 quit(1 if failures else 0)
