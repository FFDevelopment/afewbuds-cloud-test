extends SceneTree
var failures:int=0
var checks:int=0
func check(ok:bool,note:String)->void:
 checks+=1
 if ok:print("PASS: ",note)
 else:failures+=1;push_error("FAIL: "+note)
func _initialize()->void:call_deferred("run")
func has_button(node:Node,needle:String)->bool:
 for child in node.find_children("*","Button",true,false):
  if str(child.text).contains(needle):return true
 return false
func run()->void:
 var is_desktop:bool=ResourceLoader.exists("res://prototype/apartment.tscn")
 var path:String="res://prototype/apartment.tscn" if is_desktop else "res://scenes/main.tscn"
 var game:Node3D=load(path).instantiate()
 root.add_child(game)
 for i in 18:await process_frame
 game.set_process(false);game.neighborhood.set_process(false)
 if is_desktop and game.fp_player!=null:game.fp_player.set_physics_process(false)
 if not is_desktop and game.neighborhood.physics_body!=null:game.neighborhood.physics_body.set_physics_process(false)
 for timer in game.find_children("*","Timer",true,false):timer.stop()
 game.gameplay_ready=true;game.tutorial_active=false;game.session_paused=false;game.daily_report_pending=false;game.customer_waiting=false
 game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide()
 if game.inventory_system!=null:
  game.inventory_system.set_process(false)
  game.inventory_system.guide.state.active=false
  game.inventory_system.guide.state.completed=true
 var memory:Dictionary=game.advancement_ready_history
 check(memory.is_empty(),"New career has no fabricated completed milestones")
 var storage:Dictionary=game._find_advancement("storage_two")
 var flavor:Dictionary=game._find_advancement("recipe_citrus_velvet")
 var original_seeds:Dictionary=game.seed_inventory.duplicate(true)
 var old_grams:int=int(game.advancement_stats.get("grams_stored",0))
 var old_hybrids:int=int(game.advancement_stats.get("hybrids_created",0))
 var old_storage:int=game.storage_level
 # A capacity upgrade alone is not enough when grams-stored condition was never achieved.
 game.storage_level=2
 game.advancement_stats["grams_stored"]=57
 game.advancement_ready_history.erase("storage_two")
 check(not game._advancement_is_ready(storage),"57 of 75 grams correctly blocks an unearned storage reward")
 game.advancement_stats["grams_stored"]=75
 check(game._advancement_is_ready(storage),"75 cumulative grams and upgraded storage earn reward")
 game.seed_inventory.clear()
 for i in range(mini(5,game.SEED_ORDER.size())):game.seed_inventory[game.SEED_ORDER[i]]=1
 game.advancement_stats["hybrids_created"]=1
 check(game._advancement_is_ready(flavor),"Five concurrent seed varieties and completed hybrid earn recipe")
 game._record_advancement_history()
 check(bool(game.advancement_ready_history.get("storage_two",false)) and bool(game.advancement_ready_history.get("recipe_citrus_velvet",false)),"Qualified achievements are recorded permanently")
 game.seed_inventory.clear()
 game.storage_level=1
 game._save_game()
 check(game._advancement_is_ready(storage) and game._advancement_is_ready(flavor),"Selling stock and planting seeds cannot undo ready rewards")
 var stored:Variant=JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
 check(stored is Dictionary and bool(stored.get("advancement_ready_history",{}).get("storage_two",false)) and int(stored.get("advancement_stats",{}).get("seed_varieties_peak",0))>=5,"Reward history and peak seed varieties persist in career save")
 # Reeves is a real contact after the first meeting, but not before.
 var crew:RefCounted=game.neighborhood.location_ops.crew
 game.reeves_met=true;game.reeves_arrangement_active=false;game.reeves_arrangement_ended=false
 game.corrupt_contact_unlocked=true;game.heat=50.0;game.heat_peak=50.0;game.cash=10000
 game._open_phone_app("clients")
 check(has_button(game.phone_list,"Agent Reeves"),"Meeting Reeves unlocks his named Contacts entry")
 crew.open_thread("Agent Reeves")
 crew.show_actions()
 check(has_button(game.phone_list,"ASK REEVES TO REDUCE HEAT"),"Reeves private message shows costed heat contact option")
 var heat_before:float=game.heat
 var cash_before:int=game.cash
 crew.reeves_message("status")
 check(is_equal_approx(game.heat,heat_before) and game.cash==cash_before,"Free check-in does not reduce heat or charge money")
 var calls_before:int=game.corrupt_contact_calls
 crew.reeves_message("help")
 check(game.corrupt_contact_calls==calls_before+1 and game.cash<cash_before and game.heat<heat_before,"Paid Reeves text uses existing cost and heat consequences")
 game._build_heat_app()
 check(not has_button(game.phone_list,"PAY REEVES"),"Reeves contact actions no longer appear inside Heat dashboard")
 game.seed_inventory=original_seeds
 game.advancement_stats["grams_stored"]=old_grams
 game.advancement_stats["hybrids_created"]=old_hybrids
 game.storage_level=old_storage
 # Clear retained signal Callables and RefCounted crew fixtures before teardown.
 for node in game.phone_list.get_children():node.queue_free()
 await process_frame
 crew=null
 game.queue_free()
 await process_frame
 print("REWARD_CONTACT_RESULT: ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
