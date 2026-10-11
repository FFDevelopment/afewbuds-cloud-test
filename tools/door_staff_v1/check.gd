extends SceneTree
# Deterministic development-only door staffing and customer preference regression.
var checks:int=0
var failures:int=0
func check(ok:bool,note:String)->void:
    checks+=1
    if not ok:
        failures+=1
        push_error("DOOR_STAFF FAIL: "+note)
    else:print("PASS: "+note)
func _initialize()->void:call_deferred("run")
func run()->void:
    var desktop:bool=ResourceLoader.exists("res://prototype/apartment.tscn")
    var scene:String="res://prototype/apartment.tscn" if desktop else "res://scenes/main.tscn"
    var game=load(scene).instantiate()
    root.add_child(game)
    for i in range(20):await process_frame
    game.set_process(false);game.neighborhood.set_process(false)
    if desktop:game.fp_player.set_physics_process(false)
    elif game.neighborhood.physics_body!=null:game.neighborhood.physics_body.set_physics_process(false)
    for timer in game.find_children("*","Timer",true,false):timer.stop()
    game.gameplay_ready=true;game.tutorial_active=false;game.session_paused=false;game.daily_report_pending=false
    game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide()
    game.grower_level=20;game.heat=0;game.cash=10000;game.business_open=true;game.lay_low_active=false
    game.property_offer_unlocked=true
    game.property_opportunity_state["acquired"]=true
    game.property_opportunity_state["relocated"]=true
    game.apartment_rent_state["lease_active"]=true
    game.friend_staff_roles.clear();game.dealer_count=0;game.dealers_active=false
    game.location_state["staff_assignments"]={}
    game.location_state["door_managers"]={}
    game.location_state["staff_duty"]={}
    var ops=game.neighborhood.location_ops
    var crew=ops.crew
    for name in ["Rod","Kobi","Diddy"]:
        game.customer_relationships[name]={"visits":25,"player_sales":game.FRIEND_RECRUIT_PLAYER_SALES,"loyalty":100}
        check(game._friend_is_recruitable(game._customer_by_name(name)),name+" is eligible through friendship, without dealer experience")
    var initial_cash:int=game.cash
    game._recruit_friend_staff("Rod","door","apartment")
    check(game.friend_staff_roles.get("Rod","")=="door" and crew.manager("apartment")=="Rod","Apartment has dedicated door employee")
    check(game.cash==initial_cash-500 and game._total_dealer_count()==0 and not game.dealers_active,"One-time hire fee; street dealer capacity and duty remain untouched")
    var cash_after:int=game.cash
    game._recruit_friend_staff("Diddy","door","apartment")
    check(game.cash==cash_after and not game.friend_staff_roles.has("Diddy"),"One door worker maximum per property")
    game._recruit_friend_staff("Kobi","door","house")
    check(crew.manager("house")=="Kobi" and crew.assignment("Kobi")=="house","House has independent door worker")
    crew.assign("Rod","house")
    check(crew.assignment("Rod")=="apartment","Worker cannot transfer into occupied house role")
    game._recruit_friend_staff("Rod","dealer")
    check(game._total_dealer_count()==0 and game.friend_staff_roles.get("Rod","")=="door","Friend cannot hold overlapping street and door roles")
    check(crew.shop.dealer_allowed("Rod") and crew.shop.dealer_allowed("Kobi"),"Door duty operates without street dealers")
    ops.portfolio_property="apartment"
    ops.portfolio_set_duty("Rod")
    check(not crew.shop.dealer_allowed("Rod") and crew.shop.dealer_allowed("Kobi"),"Send home is individual and property isolated")
    ops.portfolio_set_duty("Rod")
    check(crew.shop.dealer_allowed("Rod"),"Door worker returns to duty")
    game._record_friend_dealer_sale("Rod",3,90,9)
    game._record_friend_dealer_sale("Kobi",2,50,5)
    check(int(game.friend_dealer_stats.Rod.commission_earned)==9 and int(game.friend_dealer_stats.Kobi.commission_earned)==5,"Sales and commission tracked per door employee")
    var customer:Dictionary=game._customer_by_name("Dre")
    var requested:String="Street Green"
    var alternative:String="Purple Dream"
    var before:float=game._substitute_acceptance_chance_for(customer,requested,alternative)
    for i in 2:game._record_customer_strain_experience("Dre",requested,alternative)
    check(str(game.customer_relationships.Dre.get("secondary_strain",""))==alternative and game._customer_favorite(customer)==requested,"Two accepted substitutes create secondary preference without replacing main favorite")
    for i in 3:game._record_customer_strain_experience("Dre",requested,alternative)
    var after:float=game._substitute_acceptance_chance_for(customer,requested,alternative)
    check(game._customer_favorite(customer)==alternative and after>before,"Five accepted substitutes can change favorite and increase future acceptance")
    for key in game.products.keys():
        game.products[key]["listed"]=false
        game.products[key]["stock"]=0
    game.products[requested]["listed"]=true
    game.products[requested]["stock"]=0
    game.products[alternative]["listed"]=true
    game.products[alternative]["stock"]=5
    game.products[alternative]["reserved"]=0
    game.locker_weed.clear();game.bagged_inventory.clear()
    var qty:int=3
    var chance:float=game._substitute_acceptance_chance_for(customer,requested,alternative)
    game.rng.seed=418
    var random_roll:float=game.rng.randf()
    game.rng.seed=418
    var before_stock:int=int(game.products[alternative]["stock"])
    var offered:String=game._dealer_best_offer(customer,requested,qty,true)
    check((offered==alternative)==(random_roll<=chance),"Highest acceptance percentage drives actual single sale roll")
    check(int(game.products[alternative]["stock"])==before_stock,"Rejected or pending offer does not consume inventory")
    game.products[alternative]["listed"]=false
    check(game._dealer_best_offer(customer,requested,qty,true)=="","Unlisted alternative cannot be offered")
    game.products[alternative]["listed"]=true
    game.products[alternative]["reserved"]=4
    check(game._dealer_best_offer(customer,requested,qty,true)=="","Reserved or insufficient inventory cannot be offered")
    game.products[alternative]["reserved"]=0
    game._release_friend_staff("Rod")
    check(not game.friend_staff_roles.has("Rod") and crew.manager("apartment").is_empty(),"Firing clears assignment and apartment door coverage")
    check(int(game.friend_dealer_stats.Rod.commission_earned)==9,"Dismissal retains the worker's earned commission history")
    game.queue_free()
    await process_frame;await process_frame
    print("DOOR_STAFF_RESULT: "+("PASS" if failures==0 else "FAIL")+" checks="+str(checks)+" failures="+str(failures))
    quit(0 if failures==0 else 1)
