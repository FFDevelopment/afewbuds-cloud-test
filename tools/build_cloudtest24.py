from pathlib import Path
import struct, hashlib, re, json, collections

PCK=Path("index-cloudtest10.pck")
HTML=Path("index.html")
VERSION=Path("version.json")
BUILD=Path("BUILD_VERSION.txt")
RELEASE="0.7.9-beta.19-cloudtest.62"
PACK_URL="index-cloudtest10.pck?build=62"

def align(n,a=32): return (n+a-1)//a*a

def parse(path):
    blob=path.read_bytes()
    if blob[:4]!=b"GDPC": raise SystemExit("not PCK")
    fb=struct.unpack_from("<Q",blob,24)[0]
    do=struct.unpack_from("<Q",blob,32)[0]
    count=struct.unpack_from("<I",blob,do)[0]
    pos=do+4; entries=[]
    for _ in range(count):
        plen=struct.unpack_from("<I",blob,pos)[0]; pos+=4
        name=blob[pos:pos+plen].rstrip(b"\0").decode(); pos+=plen
        off=struct.unpack_from("<Q",blob,pos)[0]; pos+=8
        size=struct.unpack_from("<Q",blob,pos)[0]; pos+=8
        md5=blob[pos:pos+16]; pos+=16
        flags=struct.unpack_from("<I",blob,pos)[0]; pos+=4
        data=blob[fb+off:fb+off+size]
        if hashlib.md5(data).digest()!=md5: raise SystemExit("md5 "+name)
        entries.append([name,data,flags])
    return blob,fb,entries

def rebuild(blob,fb,entries):
    out=bytearray(blob[:fb]); cur=0; rows=[]
    for name,data,flags in entries:
        at=align(cur); out.extend(b"\0"*(at-cur)); off=at
        out.extend(data); cur=off+len(data)
        rows.append((name,off,len(data),hashlib.md5(data).digest(),flags))
    do=align(len(out)); out.extend(b"\0"*(do-len(out))); struct.pack_into("<Q",out,32,do)
    out.extend(struct.pack("<I",len(rows)))
    for name,off,size,md5,flags in rows:
        raw=name.encode(); plen=(len(raw)+3)//4*4
        out.extend(struct.pack("<I",plen)); out.extend(raw); out.extend(b"\0"*(plen-len(raw)))
        out.extend(struct.pack("<Q",off)); out.extend(struct.pack("<Q",size)); out.extend(md5); out.extend(struct.pack("<I",flags))
    return bytes(out)

def pat(name):
    return re.compile(r"^func "+re.escape(name)+r"\([^\n]*\)(?: -> [^:]+)?:\n.*?(?=^func |\Z)",re.M|re.S)

def replace_func(src,name,new):
    ms=list(pat(name).finditer(src))
    if not ms: raise SystemExit("missing "+name)
    at=ms[0].start()
    for m in reversed(ms):
        src=src[:m.start()]+src[m.end():]
    return src[:at]+new.rstrip()+"\n\n"+src[at:]

def upsert_before(src,name,new,before):
    ms=list(pat(name).finditer(src))
    if ms:
        at=ms[0].start()
        for m in reversed(ms):
            src=src[:m.start()]+src[m.end():]
        return src[:at]+new.rstrip()+"\n\n"+src[at:]
    at=src.find("func "+before+"(")
    if at<0: raise SystemExit("anchor "+before)
    return src[:at]+new.rstrip()+"\n\n"+src[at:]

blob,fb,entries=parse(PCK)
found=False

for row in entries:
    if row[0]!="scripts/main.gd":
        continue
    found=True
    text=row[1].decode("utf-8","replace").rstrip(" \n\0")

    # ---------- Water utility constants/state ----------
    const_anchor='const POWER_BILL_MAX_BALANCE: int = 2500\n'
    const_add='const WATER_COST_PER_WATERING: float = 2.0\nconst WATER_BILL_MAX_BALANCE: int = 2000\n'
    if 'const WATER_COST_PER_WATERING' not in text:
        if const_anchor not in text: raise SystemExit("power constant anchor missing")
        text=text.replace(const_anchor,const_anchor+const_add,1)

    var_anchor='var lifetime_power_cost: int = 0\n'
    var_add='var current_day_water_cost: float = 0.0\nvar current_day_water_uses: int = 0\nvar water_bill_due: int = 0\nvar last_water_bill: int = 0\nvar lifetime_water_cost: int = 0\n'
    if 'var current_day_water_cost' not in text:
        if var_anchor not in text: raise SystemExit("utility var anchor missing")
        text=text.replace(var_anchor,var_anchor+var_add,1)

    # ---------- Advancement ----------
    power_adv='\t{"id": "first_power_bill", "category": "Business", "tier": 1, "title": "Keep the Power On", "description": "Pay your first utility bill.", "metric": "power_bills_paid", "target": 1, "reward_cash": 0, "reward_xp": 25, "reward_rep": 1},'
    water_adv='\t{"id": "first_water_bill", "category": "Business", "tier": 1, "title": "Pay the Water", "description": "Pay your first water bill after using the property plumbing to care for plants.", "metric": "water_bills_paid", "target": 1, "reward_cash": 0, "reward_xp": 25, "reward_rep": 1},'
    if '"id": "first_water_bill"' not in text:
        if power_adv not in text: raise SystemExit("first power bill advancement anchor missing")
        text=text.replace(power_adv,power_adv+"\n"+water_adv,1)

    # ---------- Water utility helpers ----------
    helpers=r'''func _charge_water_use(count: int = 1) -> void:
	if count <= 0:
		return
	current_day_water_uses += count
	current_day_water_cost += WATER_COST_PER_WATERING * float(count)

func _finalize_daily_water_bill(show_feedback: bool) -> void:
	var bill: int = maxi(0, int(ceil(current_day_water_cost)))
	last_water_bill = bill
	if bill > 0:
		water_bill_due = mini(WATER_BILL_MAX_BALANCE, water_bill_due + bill)
		lifetime_water_cost += bill
	current_day_water_cost = 0.0
	current_day_water_uses = 0
	if show_feedback and status_label != null and bill > 0:
		status_label.text = "Water bill posted: $%d  |  Total water balance due: $%d." % [bill, water_bill_due]
	if phone_open and phone_current_app in ["home", "business", "bills", "employees", "stats"]:
		_refresh_phone()

func _pay_water_bill() -> void:
	if water_bill_due <= 0:
		return
	if cash < water_bill_due:
		status_label.text = "You need $%d to pay the outstanding water bill." % water_bill_due
		return
	var paid: int = water_bill_due
	cash -= paid
	water_bill_due = 0
	_increment_advancement_stat("water_bills_paid")
	_update_cash_ui()
	status_label.text = "Water bill paid: $%d." % paid
	_save_game()
	if phone_open:
		_refresh_phone()
'''
    text=upsert_before(text,"_charge_water_use",helpers,"_pay_power_bill")

    # ---------- Every watering route incurs property water usage ----------
    water_manual=r'''func _water_plant(slot_index: int) -> void:
	if tutorial_active and slot_index != tutorial_slot:
		status_label.text = "Use the plant you just planted. SHOW ME selects the right pot."
		return
	if not _tutorial_can_do("water"):
		return
	if slot_index < 0 or slot_index >= plant_slots.size():
		return
	var slot: Dictionary = plant_slots[slot_index]
	if int(slot.get("stage", -1)) < 0 or int(slot.get("stage", -1)) >= 3 or bool(slot.get("dead", false)) or float(slot.get("water", 0.0)) >= 95.0:
		return
	var water: float = float(slot.get("water", 0.0))
	water = clampf(water + 42.0, 0.0, 100.0)
	slot["water"] = water
	plant_slots[slot_index] = slot
	_charge_water_use(1)
	_increment_advancement_stat("waters")
	_tutorial_record("water", slot_index)
	_save_game()
	status_label.text = "%s was watered. Water usage was added to Utilities." % str(slot.get("strain", "Plant"))
	_refresh_grow_panel()
'''
    text=replace_func(text,"_water_plant",water_manual)

    auto_water=r'''func _update_plant_over_time(slot_index: int, elapsed_seconds: float) -> void:
	if _simulation_blocked() or slot_index < 0 or slot_index >= plant_slots.size():
		return
	var before_water: float = float(plant_slots[slot_index].get("water", 0.0))
	var before_stage: int = int(plant_slots[slot_index].get("stage", -1))
	var before_dead: bool = bool(plant_slots[slot_index].get("dead", false))
	plant_slots[slot_index] = PlantGrowth.advance(plant_slots[slot_index], elapsed_seconds, _plant_growth_settings(false))
	var after_water: float = float(plant_slots[slot_index].get("water", 0.0))
	if auto_water_unlocked and before_stage >= 0 and before_stage < 3 and not before_dead and after_water > before_water + 0.01:
		_charge_water_use(1)
	_update_plant_visual(slot_index)
'''
    text=replace_func(text,"_update_plant_over_time",auto_water)

    offline=r'''func _simulate_offline_plants(elapsed_seconds: float, worker_care: bool = false) -> void:
	if elapsed_seconds <= 0.0 or not is_finite(elapsed_seconds) or not _offline_crops_enabled():
		return
	var before: Array[Dictionary] = plant_slots.duplicate(true)
	var care_allowed: bool = worker_care and _offline_worker_care_enabled()
	var result: Dictionary = OfflinePlantCare.advance(plant_slots, elapsed_seconds, _plant_growth_settings(true), fertilizer_units, care_allowed, away_worker_next_service)
	var updated: Array = result["plants"]
	for i: int in range(plant_slots.size()):
		plant_slots[i] = updated[i]
	fertilizer_units = int(result["fertilizer_units"])
	away_worker_next_service = float(result["service_in"])
	var offline_waterings: int = maxi(0, int(result["waterings"]))
	if offline_waterings > 0:
		_charge_water_use(offline_waterings)
	var matured: int = 0
	var died: int = 0
	var growing: int = 0
	for i: int in range(plant_slots.size()):
		if int(before[i].get("stage", -1)) < 0 or int(before[i].get("stage", -1)) >= 3 or bool(before[i].get("dead", false)):
			continue
		var after: Dictionary = plant_slots[i]
		if bool(after.get("dead", false)):
			died += 1
		elif int(after.get("stage", -1)) == 3:
			matured += 1
		else:
			growing += 1
	offline_plant_report["seconds"] = float(offline_plant_report.get("seconds", 0.0)) + elapsed_seconds
	offline_plant_report["matured"] = int(offline_plant_report.get("matured", 0)) + matured
	offline_plant_report["died"] = int(offline_plant_report.get("died", 0)) + died
	offline_plant_report["growing"] = growing
	offline_plant_report["worker_care"] = bool(offline_plant_report.get("worker_care", false)) or care_allowed
	offline_plant_report["waterings"] = int(offline_plant_report.get("waterings", 0)) + offline_waterings
	offline_plant_report["fertilizes"] = int(offline_plant_report.get("fertilizes", 0)) + int(result["fertilizes"])
	if care_allowed:
		production_worker_pending_action = ""
		production_worker_pending_slot = -1
		production_worker_pending_strain = ""
		production_worker_action_dwell = 0.0
		production_worker_task = "Checking plants after away care"
		production_worker_last_action = production_worker_task
		_reset_production_worker_navigation()
'''
    text=replace_func(text,"_simulate_offline_plants",offline)

    worker_old='''\t\t"water":
\t\t\tif slot_index >= 0 and slot_index < plant_slots.size():
\t\t\t\tvar slot: Dictionary = plant_slots[slot_index]
\t\t\t\tslot["water"] = 100.0
\t\t\t\tslot["health"] = minf(100.0, float(slot.get("health", 100.0)) + 2.0)
\t\t\t\tplant_slots[slot_index] = slot
\t\t\t\t_update_plant_visual(slot_index)
'''
    worker_new='''\t\t"water":
\t\t\tif slot_index >= 0 and slot_index < plant_slots.size():
\t\t\t\tvar slot: Dictionary = plant_slots[slot_index]
\t\t\t\tslot["water"] = 100.0
\t\t\t\tslot["health"] = minf(100.0, float(slot.get("health", 100.0)) + 2.0)
\t\t\t\tplant_slots[slot_index] = slot
\t\t\t\t_charge_water_use(1)
\t\t\t\t_update_plant_visual(slot_index)
'''
    if worker_old in text:
        text=text.replace(worker_old,worker_new,1)
    elif worker_new not in text:
        raise SystemExit("worker water branch missing")

    closeout_old='''\t\t_finalize_daily_power_bill(false)
\t\t_process_daily_payroll(false)
'''
    closeout_new='''\t\t_finalize_daily_power_bill(false)
\t\t_finalize_daily_water_bill(false)
\t\t_process_daily_payroll(false)
'''
    if closeout_old in text:
        text=text.replace(closeout_old,closeout_new,1)
    elif closeout_new not in text:
        raise SystemExit("closeout utility finalization anchor missing")

    # ---------- Bills / business UI ----------
    business=r'''func _build_business_app() -> void:
	var summary: Label = Label.new()
	summary.text = "GROWER LEVEL %d   |   XP %d / %d\nBrand Level %d   |   Reputation %d\nStorefront: %s" % [grower_level, grower_xp, _xp_needed_for_next_level(), brand_level, reputation, "OPEN" if business_open else "AWAY"]
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_font_size_override("font_size", 19)
	phone_list.add_child(summary)
	var grid: GridContainer = _phone_category_grid()
	_add_phone_app_tile(grid, "", "Bills", "$%d outstanding" % (power_bill_due + water_bill_due + dealer_balance_due), "bills")
	_add_phone_app_tile(grid, "", "Employees", "Worker & dealer team", "employees")
	_add_phone_app_tile(grid, "", "Upgrades", "Equipment, tents & storage", "upgrades")
'''
    text=replace_func(text,"_build_business_app",business)

    bills=r'''func _build_bills_app() -> void:
	var intro: Label = Label.new()
	intro.text = "Outstanding bills: $%d\nElectricity and water are property utilities. Today's wages and dealer cash are settled at daily closeout." % (power_bill_due + water_bill_due + dealer_balance_due)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	phone_list.add_child(intro)

	var electric_card: PanelContainer = PanelContainer.new()
	phone_list.add_child(electric_card)
	var electric_box: VBoxContainer = VBoxContainer.new()
	electric_card.add_child(electric_box)
	var electric_title: Label = Label.new()
	electric_title.text = "ELECTRICITY"
	electric_title.add_theme_font_size_override("font_size", 20)
	electric_box.add_child(electric_title)
	var electric_detail: Label = Label.new()
	var ventilation_status: String = "NOT INSTALLED" if not ventilation_installed else ("ON" if ventilation_on else "OFF")
	electric_detail.text = "Estimated today: $%d  |  Last bill: $%d  |  Balance due: $%d\nHome lights: %s  |  Lamp: %s\nGrow-room light: %s  |  Grow lights: %s  |  Ventilation: %s\n%d tent(s) powered\nGrow lights OFF = about %d%% normal growth. Ventilation unavailable/OFF = about %d%% normal growth." % [int(ceil(current_day_power_cost)), last_power_bill, power_bill_due, _on_off(main_ceiling_light_on), _on_off(floor_lamp_on), _on_off(grow_room_light_on), _on_off(grow_lights_on), ventilation_status, grow_tent_count, int(round(GROW_LIGHTS_OFF_GROWTH_MULTIPLIER * 100.0)), int(round(VENTILATION_INACTIVE_GROWTH_MULTIPLIER * 100.0))]
	electric_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	electric_box.add_child(electric_detail)
	if power_bill_due > 0:
		var pay_power: Button = Button.new()
		pay_power.text = "PAY ELECTRIC BILL  |  $%d" % power_bill_due
		pay_power.disabled = cash < power_bill_due
		pay_power.custom_minimum_size.y = 50
		pay_power.pressed.connect(_pay_power_bill)
		electric_box.add_child(pay_power)

	var water_card: PanelContainer = PanelContainer.new()
	phone_list.add_child(water_card)
	var water_box: VBoxContainer = VBoxContainer.new()
	water_card.add_child(water_box)
	var water_title: Label = Label.new()
	water_title.text = "WATER / PLUMBING"
	water_title.add_theme_font_size_override("font_size", 20)
	water_box.add_child(water_title)
	var water_detail: Label = Label.new()
	water_detail.text = "Estimated today: $%d  |  Waterings today: %d\nLast bill: $%d  |  Balance due: $%d\nWater comes from the property plumbing automatically. Manual watering, Auto Water Kit and production-worker care each add $%d per watering." % [int(ceil(current_day_water_cost)), current_day_water_uses, last_water_bill, water_bill_due, int(WATER_COST_PER_WATERING)]
	water_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	water_box.add_child(water_detail)
	if water_bill_due > 0:
		var pay_water: Button = Button.new()
		pay_water.text = "PAY WATER BILL  |  $%d" % water_bill_due
		pay_water.disabled = cash < water_bill_due
		pay_water.custom_minimum_size.y = 50
		pay_water.pressed.connect(_pay_water_bill)
		water_box.add_child(pay_water)

	var dealer_card: PanelContainer = PanelContainer.new()
	phone_list.add_child(dealer_card)
	var dealer_box: VBoxContainer = VBoxContainer.new()
	dealer_card.add_child(dealer_box)
	var dealer_detail: Label = Label.new()
	dealer_detail.text = "DEALER BALANCE\nOutstanding: $%d\nCash held for nightly drop-off: $%d" % [dealer_balance_due, dealer_cash_held]
	dealer_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dealer_box.add_child(dealer_detail)
	if dealer_balance_due > 0:
		var pay_dealers: Button = Button.new()
		pay_dealers.text = "PAY DEALER BALANCE  |  $%d" % dealer_balance_due
		pay_dealers.disabled = cash < dealer_balance_due
		pay_dealers.custom_minimum_size.y = 50
		pay_dealers.pressed.connect(_pay_dealer_balance)
		dealer_box.add_child(pay_dealers)
	else:
		var clear: Label = Label.new()
		clear.text = "No outstanding dealer balance."
		dealer_box.add_child(clear)
'''
    text=replace_func(text,"_build_bills_app",bills)

    # ---------- Daily closeout ----------
    report=r'''func _prepare_daily_report(closing_day: int) -> void:
	if daily_report_pending:
		return
	var dealer_wages: int = 0
	if _total_dealer_count() > 0 and (dealers_active or dealer_sales_today > 0):
		dealer_wages = _total_dealer_count() * DEALER_DAILY_WAGE
	var dealer_gross: int = dealer_cash_held
	var dealer_commission: int = dealer_commission_held
	var gross_revenue: int = _sum_daily_sales_gross()
	var recorded_expenses: int = _sum_daily_expenses()
	var power_cost: int = last_power_bill
	var water_cost: int = last_water_bill
	var total_cost: int = recorded_expenses + power_cost + water_cost + dealer_commission + dealer_wages
	var operating_profit: int = gross_revenue - total_cost
	var dealer_net: int = dealer_gross - dealer_commission - dealer_wages
	var friend_dealer_report: Array[Dictionary] = _friend_dealer_daily_report(dealer_wages > 0)
	daily_report_data = {
		"day": closing_day,
		"next_day": closing_day + 1,
		"sales": daily_sales_by_product.duplicate(true),
		"gross": gross_revenue,
		"dealer_gross": dealer_gross,
		"dealer_commission": dealer_commission,
		"dealer_wages": dealer_wages,
		"dealer_net": dealer_net,
		"expenses": daily_expenses_by_category.duplicate(true),
		"power_cost": power_cost,
		"water_cost": water_cost,
		"total_cost": total_cost,
		"profit": operating_profit,
		"dealer_count": _total_dealer_count(),
		"personal_sales": int(advancement_stats.get("sales", 0)),
		"dealer_sales_count": dealer_sales_today,
		"friend_dealers": friend_dealer_report
	}
	daily_report_pending = true
	_hide_learning_panels()
	knock_banner.visible = false
	closeout_announced = false
	_cancel_station_drag()
	if knock_player != null:
		knock_player.stop()
	_sync_simulation_pause()
	dealer_cash_held = 0
	dealer_commission_held = 0
	daily_sales_by_product = {}
	daily_expenses_by_category = {}
	dealer_sales_today = 0
	dealer_customers_served_today = {}
	_reset_friend_dealer_daily_stats()
	production_worker_tasks_today = 0
	last_production_payroll_cost = 0
	if visit_timer != null:
		visit_timer.stop()
	_save_game()
	_show_daily_report()
'''
    text=replace_func(text,"_prepare_daily_report",report)

    show_report=r'''func _show_daily_report() -> void:
	if not daily_report_pending or daily_report_panel == null:
		return
	var report: Dictionary = daily_report_data
	var closing_day: int = int(report.get("day", maxi(1, game_day - 1)))
	var next_day: int = int(report.get("next_day", game_day))
	var dealer_count_report: int = int(report.get("dealer_count", 0))
	var dealer_gross: int = int(report.get("dealer_gross", 0))
	var dealer_commission: int = int(report.get("dealer_commission", 0))
	var dealer_wages: int = int(report.get("dealer_wages", 0))
	var dealer_net: int = int(report.get("dealer_net", 0))
	var gross: int = int(report.get("gross", 0))
	var power_cost: int = int(report.get("power_cost", 0))
	var water_cost: int = int(report.get("water_cost", 0))
	var total_cost: int = int(report.get("total_cost", 0))
	var profit: int = int(report.get("profit", 0))
	daily_report_title.text = ("DEALER DROP-OFF  |  DAY %d" % closing_day) if dealer_count_report > 0 else ("DAY %d CLOSEOUT" % closing_day)
	var settlement_line: String = "No dealer settlement tonight."
	if dealer_count_report > 0:
		if dealer_net >= 0:
			settlement_line = "Dealer cash collected: $%d\nDealer commission (10%%): $%d\nCASH THEY HAND YOU AFTER COMMISSION: $%d" % [dealer_gross, dealer_commission, dealer_net]
		else:
			settlement_line = "Dealer cash collected: $%d\nDealer commission (10%%): $%d\nBALANCE: $%d" % [dealer_gross, dealer_commission, -dealer_net]
	var friend_section: String = ""
	var friend_text: String = _daily_report_friend_dealers_text(report)
	if not friend_text.is_empty():
		friend_section = "\n\nFRIEND DEALERS\n%s" % friend_text
	daily_report_body.text = "PRODUCT SOLD\n%s\n\nREVENUE / COSTS\nGross product revenue: $%d\n%s\nElectricity: $%d\nWater: $%d\n\nTotal operating cost: $%d\nDAY PROFIT: $%d\n\n%s%s\n\nElectric and water charges are posted to Business -> Bills and can be paid separately." % [_daily_report_sales_text(report), gross, _daily_report_expense_text(report), power_cost, water_cost, total_cost, profit, settlement_line, friend_section]
	daily_report_action.text = ("SETTLE DEALERS  |  START DAY %d" % next_day) if dealer_count_report > 0 else ("START DAY %d" % next_day)
	daily_report_panel.visible = true
	_set_world_controls_visible(false)
	if not closeout_announced:
		closeout_announced = true
		if dealer_count_report > 0 and knock_player != null and not session_paused:
			knock_player.play()
	_refresh_tutorial_coach()
	if status_label != null:
		status_label.text = "DAY CLOSED  |  Time is frozen. Review the report, then press START DAY when ready."
'''
    text=replace_func(text,"_show_daily_report",show_report)

    stats=r'''func _build_stats_app() -> void:
	var stored: int = _total_stored_stock()
	var stats: Label = Label.new()
	stats.text = "CAREER\nRank: %s\nMilestones: %d / %d\nLifetime revenue: $%d\nCurrent cash: $%d\nReputation: %d\nBrand Level: %d\nHeat: %d / 100  |  %s\nPeak Heat: %d\nStored sellable inventory: %dg\nGrow Shelf Lv %d  |  Seeds %d/%d  |  Fertilizer %d/%d\nLifetime utilities: $%d electric  |  $%d water\nAdvancement rewards ready: %d" % [_advancement_career_rank(), _advancement_claimed_count(), advancement_catalog.size(), lifetime_revenue, cash, reputation, brand_level, int(round(heat)), _heat_stage_name(), int(round(heat_peak)), stored, supply_shelf_level, _total_seed_inventory(), _supply_seed_capacity(), fertilizer_units, _supply_fertilizer_capacity(), lifetime_power_cost, lifetime_water_cost, _advancement_ready_count()]
	stats.add_theme_font_size_override("font_size", 19)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	phone_list.add_child(stats)
	var reset: Button = Button.new()
	reset.text = "RESET CAREER DATA..."
	reset.name = "ResetCareerButton"
	reset.custom_minimum_size.y = 50
	reset.pressed.connect(_reset_beta_save)
	phone_list.add_child(reset)
'''
    text=replace_func(text,"_build_stats_app",stats)

    # ---------- Save/load ----------
    save_anchor='''\t\t"lifetime_power_cost": lifetime_power_cost,
'''
    save_add='''\t\t"current_day_water_cost": current_day_water_cost,
\t\t"current_day_water_uses": current_day_water_uses,
\t\t"water_bill_due": water_bill_due,
\t\t"last_water_bill": last_water_bill,
\t\t"lifetime_water_cost": lifetime_water_cost,
'''
    if '"current_day_water_cost": current_day_water_cost' not in text:
        if save_anchor not in text: raise SystemExit("save utility anchor missing")
        text=text.replace(save_anchor,save_anchor+save_add,1)

    load_anchor='''\tlifetime_power_cost = maxi(0, int(data.get("lifetime_power_cost", lifetime_power_cost)))
'''
    load_add='''\tcurrent_day_water_cost = maxf(0.0, float(data.get("current_day_water_cost", current_day_water_cost)))
\tcurrent_day_water_uses = maxi(0, int(data.get("current_day_water_uses", current_day_water_uses)))
\twater_bill_due = maxi(0, int(data.get("water_bill_due", water_bill_due)))
\tlast_water_bill = maxi(0, int(data.get("last_water_bill", last_water_bill)))
\tlifetime_water_cost = maxi(0, int(data.get("lifetime_water_cost", lifetime_water_cost)))
'''
    if 'current_day_water_cost = maxf(0.0, float(data.get("current_day_water_cost"' not in text:
        if load_anchor not in text: raise SystemExit("load utility anchor missing")
        text=text.replace(load_anchor,load_anchor+load_add,1)

    old_metrics='"ventilation_toggled", "power_bills_paid", "night_sales"'
    new_metrics='"ventilation_toggled", "power_bills_paid", "water_bills_paid", "night_sales"'
    if old_metrics in text:
        text=text.replace(old_metrics,new_metrics,1)
    elif new_metrics not in text:
        raise SystemExit("advancement metrics anchor missing")

    # ---------- Player-facing explanations ----------
    text=text.replace(
        '"Tap WATER on the plant you just planted. Its water meter rises; watering does not cost fertilizer."',
        '"Tap WATER on the plant you just planted. Its water meter rises. Water comes from the property plumbing and is added to your Water Bill; it does not cost fertilizer."'
    )
    text=text.replace(
        "Watering continues without fertilizer.\\nHire:",
        "Watering uses property water and adds to your Water Bill; it continues without fertilizer.\\nHire:"
    )
    text=text.replace(
        "watering continues when fertilizer runs out.",
        "watering continues when fertilizer runs out and adds to your Water Bill."
    )

    required=[
        'const WATER_COST_PER_WATERING: float = 2.0',
        'var water_bill_due: int = 0',
        'func _charge_water_use(count: int = 1) -> void:',
        'func _pay_water_bill() -> void:',
        '_finalize_daily_water_bill(false)',
        '_charge_water_use(offline_waterings)',
        '"WATER / PLUMBING"',
        '"PAY WATER BILL  |  $%d"',
        '"water_cost": water_cost',
        '"current_day_water_cost": current_day_water_cost',
        '"water_bills_paid"',
        '"id": "first_water_bill"',
        '"CAREER ROADMAP\\n%s"',
        'chapter_title.text = "STORY\\nCHAPTER 3 COMPLETE\\nNEXT: OUTGROWING THE APARTMENT"',
    ]
    for needle in required:
        if needle not in text: raise SystemExit("verify "+needle)

    names=re.findall(r"^func\s+([A-Za-z0-9_]+)\(",text,re.M)
    dup={k:v for k,v in collections.Counter(names).items() if v>1}
    if dup: raise SystemExit("duplicates "+repr(dup))

    row[1]=text.encode("utf-8")

if not found:
    raise SystemExit("main missing")

packed=rebuild(blob,fb,entries)
PCK.write_bytes(packed)

_,_,verify=parse(PCK)
sources={name:data.decode("utf-8","replace") for name,data,_ in verify if name in ["scripts/main.gd","scripts/touch_scroll.gd","scripts/storage_vault.gd"]}
main=sources.get("scripts/main.gd","")
for needle in [
    'const WATER_COST_PER_WATERING: float = 2.0',
    'func _pay_water_bill() -> void:',
    '"WATER / PLUMBING"',
    '_finalize_daily_water_bill(false)',
    '"id": "first_water_bill"',
]:
    if needle not in main: raise SystemExit("packed water utility verify "+needle)
if "const TAP_SLOP: float = 12.0" not in sources.get("scripts/touch_scroll.gd",""):
    raise SystemExit("mobile tap fix lost")
if 'const ANCHOR: Vector3 = Vector3(-4.33, 0.0, -0.30)' not in sources.get("scripts/storage_vault.gd",""):
    raise SystemExit("vault anchor changed")

html=HTML.read_text()
html=re.sub(r'const AFB_TEST_RELEASE = "[^"]+";',f'const AFB_TEST_RELEASE = "{RELEASE}";',html,count=1)
html=re.sub(r'const AFB_TEST_TITLE = "[^"]+";',f'const AFB_TEST_TITLE = "AFewBuds Cloud Test v{RELEASE}";',html,count=1)
html=re.sub(r'<title>AFewBuds Cloud Test[^<]*</title>',f'<title>AFewBuds Cloud Test {RELEASE}</title>',html,count=1)
html=re.sub(r'"fileSizes":\{[^}]*\}',f'"fileSizes":{{"{PACK_URL}":{len(packed)},"index.wasm":37902138}}',html,count=1)
html=re.sub(r'"mainPack":"[^"]+"',f'"mainPack":"{PACK_URL}"',html,count=1)
HTML.write_text(html)

meta=json.loads(VERSION.read_text())
meta["release_id"]=RELEASE
meta["water_utility"]="Property water is now billed at $2 per real watering event rather than being a free/inventory resource"
meta["water_sources"]="Manual watering, Auto Water Kit, live production-worker watering, and away-time production-worker care all create water usage"
meta["water_bills"]="Separate Water Bill balance, payment, save persistence, daily closeout cost and lifetime utility stats"
meta["water_advancement"]="Added Pay the Water milestone for first paid water bill"
meta["runtime_payload"]="cloudtest62 PCK with water/electric property utility foundation"
VERSION.write_text(json.dumps(meta,indent=2)+"\n")

BUILD.write_text(
    "AFewBuds Cloud Test\n"
    "Game build: 0.7.9-beta.19\n"
    f"Web release: {RELEASE}\n"
    "Runtime: water utility + electric/water Bills split + utility closeout/save integration\n"
)

print("Built",RELEASE,len(packed))

# finalized cloudtest62 water utility deployment marker
