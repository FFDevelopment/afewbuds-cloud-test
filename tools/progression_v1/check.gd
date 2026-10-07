extends SceneTree
var failures:=0
var checks:=0
var game:Node3D

func _initialize() -> void:call_deferred("run")

func check(ok:bool,label:String,data:Variant=null) -> void:
	checks+=1
	if ok:print("PASS: ",label)
	else:
		failures+=1
		push_error("FAIL: "+label+" "+str(data))

func frames(count:int=4) -> void:
	for i in range(count):await physics_frame

func find_advancement(id:String) -> Dictionary:
	for entry:Dictionary in game.advancement_catalog:
		if str(entry.get("id",""))==id:return entry
	return {}

func mature_chapter_four_operation() -> void:
	for key in game.advancement_stats.keys():game.advancement_stats[key]=999
	game.grow_tent_count=3
	game.bagging_level=3
	game.dealer_locker_level=4
	game.packing_employee_hired=true
	game.packing_employee_active=true
	game.dealer_count=2
	game.reputation=250
	game.grower_level=15
	game.brand_level=8
	game.lifetime_revenue=50000
	game.heat_peak=50
	game.heat_reduced_total=30
	game.reeves_met=true
	game.product_launch_seen={"Purple Dream":true,"Green Crack":true}
	game.customer_relationships={
		"Tyler":{"sales":5,"player_sales":5,"visits":5,"loyalty":85},
		"Rod":{"sales":4,"player_sales":4,"visits":4,"loyalty":85}
	}
	game.friend_staff_roles={"Tyler":"dealer"}
	check(game._story_chapter_four_operation_complete(),"Late Chapter 4 operation requirements can unlock property opportunity")

func reset_property_state() -> void:
	game.property_opportunity_state={
		"rooms":["living","kitchen","grow","packing","bathroom","bedroom"],
		"inspection_complete":true,
		"details_viewed":true,
		"tour_started":true
	}
	game.location_state["active_property"]="apartment"
	game.location_state["operation_assets_property"]="apartment"
	game.location_state["operation_contents_property"]="apartment"
	game.location_state["property_storage"]=[]
	game.location_state.erase("property_utilities")
	game.apartment_rent_state["balance"]=0
	game.apartment_rent_state["first_unpaid"]=0
	game.apartment_rent_state["lease_active"]=true
	game.apartment_rent_state["next_due"]=game.game_day+14
	game.neighborhood.property_opportunity._ensure_state()
	game.neighborhood.location_ops._ensure_property_utilities()
	game.neighborhood.location_ops._sync_legacy_utility_totals()

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(10)
	for timer in game.find_children("*","Timer",true,false):timer.stop()
	game.session_paused=false
	game.tutorial_active=false
	game.daily_report_pending=false
	game.customer_waiting=false
	game.tutorial_panel.hide()
	game.pause_overlay.hide()
	game.daily_report_panel.hide()
	game.cash=50000
	mature_chapter_four_operation()
	reset_property_state()
	game.chapter_four_story_stage=5
	game.property_offer_unlocked=false
	check(not game._story_chapter_four_complete(),"Mature operation alone does not complete Chapter 4")
	game._sync_chapter_four_story()
	check(game.property_offer_unlocked and game.chapter_four_story_stage>=6,"Mature operation unlocks house opportunity at Chapter 4 stage 6")
	check(not game._story_chapter_four_complete(),"Property offer still does not complete Chapter 4")

	var op=game.neighborhood.property_opportunity
	check(op.agreement_upfront("rent")==1800 and op.agreement_weekly("rent")==600,"Rent terms match roadmap")
	check(op.agreement_upfront("lease")==4500 and op.agreement_weekly("lease")==1000 and op.LEASE_TOTAL==18500,"Lease-to-own terms match roadmap")
	check(op.agreement_upfront("purchase")==17500 and op.agreement_weekly("purchase")==0,"Purchase terms match roadmap")

	var cash_before:int=game.cash
	op.sign_agreement("purchase")
	check(bool(game.property_opportunity_state.get("agreement_signed",false)) and str(game.property_opportunity_state.get("agreement",""))=="purchase","Purchase agreement signs")
	check(game.cash==cash_before-17500,"Purchase deducts exact $17,500 price",game.cash)
	check(not game._story_chapter_four_complete(),"Signing agreement does not complete Chapter 4")
	op.confirm_relocation()
	check(bool(game.property_opportunity_state.get("relocated",false)) and str(game.location_state.get("active_property",""))=="house","Relocation switches active operation to house")
	check(bool(game.apartment_rent_state.get("lease_active",false)),"Moving to house keeps apartment lease active by default")
	check(str(game.location_state.get("operation_assets_property",""))=="house" and str(game.location_state.get("operation_contents_property",""))=="house","Player-owned operation assets and contents move with the house relocation")
	check(not game._story_chapter_four_complete(),"Relocation waits for first house entry before Chapter 4 completion")
	var house_door:Node3D=game.neighborhood.get_node("HouseEntrance")
	game.camera.global_position=Vector3(35,1.64,4.8)
	game.camera.look_at(Vector3(35,1.4,3.0))
	game.neighborhood._use_map_door("HouseEntrance")
	await create_timer(.5).timeout
	check(house_door.opened and not op.is_open(),"Relocated house entrance opens normally instead of reopening property preview")
	game.camera.global_position=Vector3(30,1.64,0)
	op.update(0.0)
	check(bool(game.property_opportunity_state.get("first_entry",false)) and bool(game.property_opportunity_state.get("chapter5_started",false)),"First house entry starts Chapter 5")
	check(game._story_chapter_four_complete() and game.chapter_four_story_stage==7,"First house entry completes Chapter 4 at story stage 7",game.chapter_four_story_stage)
	check(game._advancement_is_ready(find_advancement("c4_new_base")),"Choose Your Next Base final Chapter 4 milestone becomes ready")

	# Recurring house economics and multi-property rent.
	reset_property_state()
	var ops=game.neighborhood.location_ops
	game.game_day=20
	game.property_opportunity_state["agreement"]="rent"
	game.property_opportunity_state["agreement_signed"]=true
	game.property_opportunity_state["relocated"]=true
	game.property_opportunity_state["next_due"]=20
	game.location_state["active_property"]="house"
	check(ops._update_house_payment() and ops.balance()==600,"House rent posts $600 every 7 game days",ops.balance())
	game.cash=5000
	ops.pay_rent()
	check(ops.balance()==0 and game.cash==4400,"House rent payment deducts exact balance",game.cash)

	reset_property_state()
	game.game_day=30
	game.property_opportunity_state["agreement"]="lease"
	game.property_opportunity_state["agreement_signed"]=true
	game.property_opportunity_state["relocated"]=true
	game.property_opportunity_state["equity_paid"]=4500
	game.property_opportunity_state["ownership_total"]=18500
	game.property_opportunity_state["next_due"]=30
	game.location_state["active_property"]="house"
	ops._update_house_payment()
	check(ops.balance()==1000,"Lease posts $1,000 seven-day payment",ops.balance())
	game.cash=5000
	ops.pay_rent()
	check(int(game.property_opportunity_state.get("equity_paid",0))==5500,"Lease payment builds ownership equity",game.property_opportunity_state.get("equity_paid"))

	# Keeping both properties means both recurring obligations continue.
	reset_property_state()
	game.game_day=40
	game.property_opportunity_state["agreement"]="rent"
	game.property_opportunity_state["agreement_signed"]=true
	game.property_opportunity_state["acquired"]=true
	game.property_opportunity_state["relocated"]=true
	game.property_opportunity_state["next_due"]=40
	game.location_state["active_property"]="house"
	game.location_state["operation_assets_property"]="house"
	game.location_state["operation_contents_property"]="house"
	game.apartment_rent_state["lease_active"]=true
	game.apartment_rent_state["next_due"]=40
	ops.update(0.0)
	check(ops.apartment_balance()==600 and ops.house_balance()==600,"Keeping apartment and house accrues both property payments independently",[ops.apartment_balance(),ops.house_balance()])

	# Utilities accrue only on controlled properties that are actually consuming them.
	var apt_util:Dictionary=ops.utility_state("apartment")
	var house_util:Dictionary=ops.utility_state("house")
	apt_util["today_power"]=0.0
	house_util["today_power"]=0.0
	game.main_ceiling_light_on=false
	game.floor_lamp_on=false
	game.grow_room_light_on=false
	game.grow_lights_on=true
	game.ventilation_installed=true
	game.ventilation_on=true
	game.house_control_state={"living":false,"packing":false,"kitchen":false,"bathroom":false,"bedroom":false,"cross_hall":false,"grow":false}
	ops.track_power_usage(10.0)
	check(float(house_util.get("today_power",0.0))>0.0 and is_zero_approx(float(apt_util.get("today_power",0.0))),"House operation power bills house while unused apartment stays at zero",[apt_util,house_util])
	game.main_ceiling_light_on=true
	ops.track_power_usage(10.0)
	check(float(apt_util.get("today_power",0.0))>0.0,"Leaving an apartment light on creates apartment electricity usage",apt_util)
	var house_water_before:float=float(house_util.get("today_water",0.0))
	ops.charge_water_use(2)
	check(float(house_util.get("today_water",0.0))>house_water_before and int(house_util.get("water_uses",0))==2,"Plant water usage follows the property holding operation equipment",house_util)

	# Releasing is only available once another property exists and apartment-assigned operation contents/assets are gone.
	game.camera.global_position=Vector3(30,1.64,0)
	game.location_state["operation_assets_property"]="house"
	game.location_state["operation_contents_property"]="house"
	var old_apartment_balance:int=ops.apartment_balance()
	check(ops.apartment_release_blockers().is_empty(),"Cleared apartment with another property can be released",ops.apartment_release_blockers())
	ops.request_apartment_release()
	check(ops.apartment_release_confirm,"Real Estate release requires explicit confirmation")
	ops.confirm_apartment_release()
	check(not ops.apartment_lease_active() and int(game.apartment_rent_state.get("next_due",-1))==0,"Releasing apartment stops future apartment rent")
	check(ops.apartment_balance()==old_apartment_balance,"Existing apartment rent debt survives lease release",ops.apartment_balance())
	var apt_power_before:float=float(apt_util.get("today_power",0.0))
	ops.track_power_usage(10.0)
	check(is_equal_approx(float(apt_util.get("today_power",0.0)),apt_power_before),"Released apartment stops generating new electricity charges")
	var door_was_open:bool=game.neighborhood.door_open
	game.neighborhood._toggle_door()
	await create_timer(.1).timeout
	check(not game.neighborhood.door_open and not door_was_open,"Released apartment front door remains locked")
	game.cash=10000
	ops.reacquire_apartment()
	check(not ops.apartment_lease_active(),"Apartment cannot be re-rented while old rent debt remains")
	ops.pay_apartment_rent()
	var cash_before_rerent:int=game.cash
	ops.reacquire_apartment()
	check(ops.apartment_lease_active() and game.cash==cash_before_rerent-ops.APARTMENT_REACQUIRE_COST,"Cleared apartment can be rented again through Real Estate")
	check(game.has_method("_build_real_estate_app"),"Real Estate exists as a top-level phone app")

	# Heat balance: routine activity is softened, serious events are not.
	game.heat=0
	game.reeves_arrangement_active=false
	game.reeves_arrangement_ended=false
	game._add_heat(10.0,"Door sale",false)
	check(absf(game.heat-7.0)<.01,"Routine Door sale Heat uses 70% multiplier",game.heat)
	game._add_heat(5.0,"Reeves arrangement refused",false)
	check(absf(game.heat-12.0)<.01,"Serious Reeves refusal keeps full Heat penalty",game.heat)
	game.heat=100
	game._apply_paused_heat_and_quiet_time(3600.0)
	check(game.heat>66.5 and game.heat<66.8,"One offline hour cools about 33 Heat, making full cooldown ~3 hours",game.heat)
	check(game.HEAT_DECAY_AWAY_PER_GAME_MINUTE > (100.0/(180.0*60.0)),"Active in-game lay-low rate is faster than offline cooling")
	check(game.HEAT_DECAY_OPEN_PER_GAME_MINUTE > (100.0/(180.0*60.0)),"Even active open-play passive cooling is faster than offline cooling")

	# Branching Reeves objectives.
	game.advancement_choice_state={}
	game.advancement_stats["reeves_payments"]=0
	game.advancement_stats["reeves_missed_payments"]=0
	game.advancement_claimed.erase("reeves_payments")
	game.advancement_claimed.erase("reeves_miss")
	game._increment_advancement_stat("reeves_payments")
	check(str(game.advancement_choice_state.get("reeves_payment_outcome",""))=="pay","First on-time Reeves payment locks compliant branch")
	check(game._advancement_is_retired(find_advancement("reeves_miss")),"Miss-payment milestone retires after choosing on-time payments")
	check(not game._advancement_is_retired(find_advancement("reeves_payments")),"Chosen on-time milestone remains active")
	check(not game._advancement_is_retired(find_advancement("reeves_negotiate")),"Settle Up remains compatible with compliant route")

	game.advancement_choice_state={}
	game.advancement_stats["reeves_payments"]=0
	game.advancement_stats["reeves_missed_payments"]=0
	game._increment_advancement_stat("reeves_missed_payments")
	check(str(game.advancement_choice_state.get("reeves_payment_outcome",""))=="miss","Missed Reeves payment locks refusal branch")
	check(game._advancement_is_retired(find_advancement("reeves_payments")),"On-time-payment milestone retires after missed-payment route")
	check(not game._advancement_is_retired(find_advancement("reeves_miss")),"Chosen missed-payment milestone remains active")

	game.advancement_choice_state={}
	game.advancement_stats["reeves_payments"]=2
	game.advancement_stats["reeves_missed_payments"]=1
	game._migrate_advancement_choices()
	check(str(game.advancement_choice_state.get("reeves_payment_outcome",""))=="legacy_both","Old saves with progress on both Reeves routes preserve legacy history")
	check(not game._advancement_is_retired(find_advancement("reeves_payments")) and not game._advancement_is_retired(find_advancement("reeves_miss")),"Legacy conflicting progress is not deleted")

	game.queue_free()
	await frames()
	print("PROGRESSION_V1_TEST_RESULT: ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
