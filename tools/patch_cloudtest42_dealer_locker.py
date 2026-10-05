from pathlib import Path
import struct, hashlib, re, json, collections

PCK = Path("index-cloudtest10.pck")
HTML = Path("index.html")
VERSION = Path("version.json")
BUILD = Path("BUILD_VERSION.txt")
RELEASE = "0.7.9-beta.19-cloudtest.42"
PACK_URL = "index-cloudtest10.pck?build=42"

def align(n, a=32):
    return (n + a - 1) // a * a

def parse(path):
    blob = path.read_bytes()
    if blob[:4] != b"GDPC":
        raise SystemExit("not a Godot PCK")
    file_base = struct.unpack_from("<Q", blob, 24)[0]
    dir_offset = struct.unpack_from("<Q", blob, 32)[0]
    count = struct.unpack_from("<I", blob, dir_offset)[0]
    pos = dir_offset + 4
    entries = []
    for _ in range(count):
        plen = struct.unpack_from("<I", blob, pos)[0]; pos += 4
        name = blob[pos:pos+plen].rstrip(b"\0").decode("utf-8"); pos += plen
        off = struct.unpack_from("<Q", blob, pos)[0]; pos += 8
        size = struct.unpack_from("<Q", blob, pos)[0]; pos += 8
        md5 = blob[pos:pos+16]; pos += 16
        flags = struct.unpack_from("<I", blob, pos)[0]; pos += 4
        data = blob[file_base+off:file_base+off+size]
        if hashlib.md5(data).digest() != md5:
            raise SystemExit("md5 mismatch " + name)
        entries.append([name, data, flags])
    return blob, file_base, entries

def rebuild(blob, file_base, entries):
    out = bytearray(blob[:file_base])
    cur = 0
    directory = []
    for name, data, flags in entries:
        at = align(cur)
        out.extend(b"\0" * (at - cur))
        off = at
        out.extend(data)
        cur = off + len(data)
        directory.append((name, off, len(data), hashlib.md5(data).digest(), flags))
    dir_offset = align(len(out))
    out.extend(b"\0" * (dir_offset - len(out)))
    struct.pack_into("<Q", out, 32, dir_offset)
    out.extend(struct.pack("<I", len(directory)))
    for name, off, size, md5, flags in directory:
        raw = name.encode("utf-8")
        plen = (len(raw) + 3) // 4 * 4
        out.extend(struct.pack("<I", plen))
        out.extend(raw)
        out.extend(b"\0" * (plen - len(raw)))
        out.extend(struct.pack("<Q", off))
        out.extend(struct.pack("<Q", size))
        out.extend(md5)
        out.extend(struct.pack("<I", flags))
    return bytes(out)

def func_pattern(name):
    return re.compile(r"^func " + re.escape(name) + r"\([^\n]*\)(?: -> [^:]+)?:\n.*?(?=^func |\Z)", re.M | re.S)

def replace_func(src, name, new_func):
    pat = func_pattern(name)
    matches = list(pat.finditer(src))
    if not matches:
        raise SystemExit("Function missing: " + name)
    start = matches[0].start()
    for m in reversed(matches):
        src = src[:m.start()] + src[m.end():]
    return src[:start] + new_func.rstrip() + "\n\n" + src[start:]

def upsert_before(src, name, new_func, before_name):
    pat = func_pattern(name)
    matches = list(pat.finditer(src))
    if matches:
        start = matches[0].start()
        for m in reversed(matches):
            src = src[:m.start()] + src[m.end():]
        return src[:start] + new_func.rstrip() + "\n\n" + src[start:]
    marker = "func " + before_name + "("
    at = src.find(marker)
    if at < 0:
        raise SystemExit("Insert anchor missing: " + before_name)
    return src[:at] + new_func.rstrip() + "\n\n" + src[at:]

blob, file_base, entries = parse(PCK)
main_found = False
inventory_found = False

for row in entries:
    if row[0] == "scripts/main.gd":
        main_found = True
        text = row[1].decode("utf-8", "replace").rstrip(" \n\0")

        # Dealer economy: commission only, no wage and no artificial sales cap.
        text = text.replace("const DEALER_DAILY_WAGE: int = 85", "const DEALER_DAILY_WAGE: int = 0", 1)
        text = text.replace("const DEALER_COMMISSION_RATE: float = 0.08", "const DEALER_COMMISSION_RATE: float = 0.10", 1)
        if "const DEALER_SALES_PER_DAY: int = 4" not in text:
            raise SystemExit("Dealer sales cap constant anchor missing")
        text = text.replace(
            "const DEALER_SALES_PER_DAY: int = 4",
            'const DEALER_LOCKER_CAPACITY_BY_LEVEL: Array[int] = [0, 100, 200, 300, 400]\n'
            'const DEALER_LOCKER_COST_BY_LEVEL: Array[int] = [0, 300, 600, 900, 1200]',
            1,
        )

        if "var dealer_locker_level: int" not in text:
            marker = "var dealer_balance_due: int = 0\n"
            if marker not in text:
                raise SystemExit("Dealer variable anchor missing")
            text = text.replace(
                marker,
                marker + "var dealer_locker_level: int = 0\nvar dealer_customers_served_today: Dictionary = {}\n",
                1,
            )

        # Physical locker is live again and is now Dealer Storage.
        disabled_locker = '''\tif action_id == "station_locker":
\t\tstatus_label.text = "Locker storage is unavailable for now."
\t\treturn true
'''
        if disabled_locker in text:
            text = text.replace(disabled_locker, "", 1)
        text = text.replace('"label": "Personal Locker"', '"label": "Dealer Locker"', 1)
        text = text.replace(
            'locker_tag.text = "GROW\nBETTER\nTOGETHER"',
            'locker_tag.text = "DEALER\nSTOCK\nLOCKER"',
            1,
        )

        # Each active dealer gets an attempt every dealer cycle. Successful sales share
        # a global per-day customer lock, so two dealers cannot serve the same person.
        automation_func = '''func _on_automation_tick() -> void:
\tif _simulation_blocked():
\t\treturn
\tif packing_employee_hired and packing_employee_active:
\t\t_assign_production_worker_task()
\telif production_worker_node != null:
\t\tproduction_worker_node.visible = false
\tif _total_dealer_count() > 0 and dealers_active:
\t\tauto_sale_accumulator += AUTO_TICK_SECONDS
\t\tif auto_sale_accumulator >= AUTO_SALE_SECONDS:
\t\t\tauto_sale_accumulator = 0.0
\t\t\tvar dealer_roster: Array[String] = _active_dealer_roster()
\t\t\tfor dealer_name: String in dealer_roster:
\t\t\t\t_dealer_sell_one(true, dealer_name)
\t_save_game()
'''
        text = replace_func(text, "_on_automation_tick", automation_func)

        # Dealer locker helpers.
        locker_helpers = '''func _dealer_locker_capacity() -> int:
\tvar level: int = clampi(dealer_locker_level, 0, DEALER_LOCKER_CAPACITY_BY_LEVEL.size() - 1)
\treturn DEALER_LOCKER_CAPACITY_BY_LEVEL[level]

func _dealer_locker_total() -> int:
\tvar total: int = 0
\tfor value_variant: Variant in locker_weed.values():
\t\ttotal += maxi(0, int(value_variant))
\treturn total

func _dealer_locker_free_capacity() -> int:
\treturn maxi(0, _dealer_locker_capacity() - _dealer_locker_total())

func _dealer_locker_next_cost() -> int:
\tvar next_level: int = dealer_locker_level + 1
\tif next_level <= 0 or next_level >= DEALER_LOCKER_COST_BY_LEVEL.size():
\t\treturn 0
\treturn DEALER_LOCKER_COST_BY_LEVEL[next_level]

func _buy_dealer_locker_upgrade() -> void:
\tif dealer_locker_level >= 4:
\t\treturn
\tvar next_level: int = dealer_locker_level + 1
\tvar cost: int = DEALER_LOCKER_COST_BY_LEVEL[next_level]
\tif cash < cost:
\t\tstatus_label.text = "You need $%d for Dealer Locker %s." % [cost, _roman(next_level)]
\t\treturn
\tcash -= cost
\t_record_daily_expense("Dealer Locker upgrade", cost)
\tdealer_locker_level = next_level
\t_update_cash_ui()
\tstatus_label.text = "Dealer Locker %s installed. Capacity: %dg." % [_roman(dealer_locker_level), _dealer_locker_capacity()]
\t_save_game()
\tif personal_inventory != null:
\t\tpersonal_inventory.refresh()
\tif phone_open:
\t\t_refresh_phone()

func _dealer_locker_add_from_storage(strain_name: String, requested_amount: int) -> int:
\tif dealer_locker_level <= 0 or not products.has(strain_name):
\t\treturn 0
\tvar available: int = maxi(0, _available_amount(strain_name))
\tvar free_capacity: int = _dealer_locker_free_capacity()
\tvar requested: int = available if requested_amount >= 999999 else maxi(0, requested_amount)
\tvar moved: int = mini(available, mini(free_capacity, requested))
\tif moved <= 0:
\t\tstatus_label.text = "Dealer Locker is full or that strain has no unreserved stock."
\t\treturn 0
\tvar data: Dictionary = products[strain_name]
\tdata["stock"] = maxi(0, int(data.get("stock", 0)) - moved)
\tproducts[strain_name] = data
\tlocker_weed[strain_name] = int(locker_weed.get(strain_name, 0)) + moved
\tstatus_label.text = "Stocked %dg %s in Dealer Locker. Dealers can now sell it." % [moved, strain_name]
\t_save_game()
\tif storage_panel != null and storage_panel.visible:
\t\t_refresh_storage_panel()
\treturn moved

func _dealer_locker_remove_to_storage(strain_name: String, requested_amount: int) -> int:
\tvar have: int = maxi(0, int(locker_weed.get(strain_name, 0)))
\tif have <= 0:
\t\treturn 0
\tvar free_capacity: int = maxi(0, _storage_capacity() - _total_stored_stock())
\tif free_capacity <= 0:
\t\tstatus_label.text = "Normal storage is full. Make space before removing dealer stock."
\t\treturn 0
\tvar requested: int = have if requested_amount >= 999999 else maxi(0, requested_amount)
\tvar moved: int = mini(have, mini(free_capacity, requested))
\tif moved <= 0:
\t\treturn 0
\tlocker_weed[strain_name] = have - moved
\tif int(locker_weed.get(strain_name, 0)) <= 0:
\t\tlocker_weed.erase(strain_name)
\t_ensure_product_exists(strain_name)
\tvar data: Dictionary = products[strain_name]
\tdata["stock"] = int(data.get("stock", 0)) + moved
\tproducts[strain_name] = data
\tstatus_label.text = "Returned %dg %s from Dealer Locker to normal storage." % [moved, strain_name]
\t_save_game()
\tif storage_panel != null and storage_panel.visible:
\t\t_refresh_storage_panel()
\treturn moved

func _dealer_customer_served_today(customer_name: String) -> bool:
\treturn dealer_customers_served_today.has(customer_name)
'''
        text = upsert_before(text, "_dealer_locker_capacity", locker_helpers, "_dealer_eligible_customers")

        dealer_sell = '''func _dealer_sell_one(show_feedback: bool, assigned_dealer_name: String = "") -> bool:
\tif _simulation_blocked():
\t\treturn false
\tif dealer_balance_due > 0:
\t\treturn false
\tif not business_open or not dealers_active or _total_dealer_count() <= 0:
\t\treturn false
\tif dealer_locker_level <= 0 or _dealer_locker_total() <= 0:
\t\treturn false
\tvar eligible: Array[Dictionary] = _dealer_eligible_customers()
\tif eligible.is_empty():
\t\treturn false
\tvar available_customers: Array[Dictionary] = []
\tfor customer: Dictionary in eligible:
\t\tvar customer_name: String = str(customer.get("name", ""))
\t\tif customer_name.is_empty() or _dealer_customer_served_today(customer_name):
\t\t\tcontinue
\t\tavailable_customers.append(customer)
\tif available_customers.is_empty():
\t\treturn false
\tvar chosen_customer: Dictionary = available_customers[rng.randi_range(0, available_customers.size() - 1)]
\tvar favorite: String = str(chosen_customer.get("favorite", ""))
\tvar product_name: String = ""
\tif products.has(favorite) and int(locker_weed.get(favorite, 0)) > 0:
\t\tproduct_name = favorite
\tif product_name.is_empty():
\t\tvar alternatives: Array[String] = []
\t\tfor name_variant: Variant in locker_weed.keys():
\t\t\tvar candidate: String = str(name_variant)
\t\t\tif int(locker_weed.get(candidate, 0)) > 0 and products.has(candidate):
\t\t\t\talternatives.append(candidate)
\t\tif alternatives.is_empty():
\t\t\treturn false
\t\tif rng.randf() > float(chosen_customer.get("flexibility", 0.0)):
\t\t\treturn false
\t\tproduct_name = alternatives[rng.randi_range(0, alternatives.size() - 1)]
\tvar available: int = maxi(0, int(locker_weed.get(product_name, 0)))
\tif available <= 0:
\t\treturn false
\tvar max_qty: int = mini(available, int(chosen_customer.get("max_qty", 2)))
\tvar min_qty: int = mini(max_qty, maxi(1, int(chosen_customer.get("min_qty", 1))))
\tif max_qty <= 0:
\t\treturn false
\tvar qty: int = rng.randi_range(min_qty, max_qty)
\tlocker_weed[product_name] = available - qty
\tif int(locker_weed.get(product_name, 0)) <= 0:
\t\tlocker_weed.erase(product_name)
\tvar gross_revenue: int = qty * _effective_price(product_name)
\tvar commission: int = int(ceil(float(gross_revenue) * DEALER_COMMISSION_RATE))
\tvar dealer_roster: Array[String] = _active_dealer_roster()
\tvar sale_dealer_name: String = assigned_dealer_name
\tif sale_dealer_name.is_empty() and not dealer_roster.is_empty():
\t\tsale_dealer_name = dealer_roster[dealer_sales_today % dealer_roster.size()]
\tdealer_cash_held += gross_revenue
\tdealer_commission_held += commission
\tlifetime_revenue += gross_revenue
\t_record_daily_sale(product_name, qty, gross_revenue, "dealer")
\tdealer_sales_today += 1
\t_record_friend_dealer_sale(sale_dealer_name, qty, gross_revenue, commission)
\tlast_dealer_customer_name = str(chosen_customer.get("name", ""))
\tdealer_customers_served_today[last_dealer_customer_name] = sale_dealer_name
\t_increment_advancement_stat("dealer_sales")
\t_increment_advancement_stat("sales")
\t_add_heat(1.8 + float(qty) * 0.45, "Dealer activity", false)
\tvar relationship: Dictionary = (customer_relationships[last_dealer_customer_name] as Dictionary).duplicate(true)
\trelationship["sales"] = int(relationship.get("sales", 0)) + 1
\trelationship["dealer_sales"] = int(relationship.get("dealer_sales", 0)) + 1
\tcustomer_relationships[last_dealer_customer_name] = relationship
\t_add_progress(qty * 4, 0)
\t_update_cash_ui()
\tif show_feedback:
\t\tstatus_label.text = "%s served %s: %dg %s  |  $%d gross, $%d commission  |  Locker %dg/%dg." % [sale_dealer_name if not sale_dealer_name.is_empty() else "Dealer", last_dealer_customer_name, qty, product_name, gross_revenue, commission, _dealer_locker_total(), _dealer_locker_capacity()]
\tif personal_inventory != null:
\t\tpersonal_inventory.refresh()
\tif phone_open:
\t\t_refresh_phone()
\treturn true
'''
        text = replace_func(text, "_dealer_sell_one", dealer_sell)

        # No dealer wages in payroll or friend-dealer closeout.
        staff_payroll = '''func _staff_daily_payroll() -> int:
\tvar total: int = 0
\tif packing_employee_hired and packing_employee_active:
\t\ttotal += PACKER_DAILY_WAGE
\treturn total
'''
        text = replace_func(text, "_staff_daily_payroll", staff_payroll)

        friend_report = '''func _friend_dealer_daily_report(_pay_wages: bool) -> Array[Dictionary]:
\tvar rows: Array[Dictionary] = []
\tfor friend_name: String in _friend_staff_names("dealer"):
\t\tvar stats: Dictionary = _ensure_friend_dealer_stats(friend_name)
\t\trows.append({
\t\t\t"name": friend_name,
\t\t\t"sales": int(stats.get("today_sales", 0)),
\t\t\t"grams": int(stats.get("today_grams", 0)),
\t\t\t"gross": int(stats.get("today_gross", 0)),
\t\t\t"commission": int(stats.get("today_commission", 0)),
\t\t\t"wage": 0,
\t\t\t"total_pay": int(stats.get("today_commission", 0))
\t\t})
\treturn rows
'''
        text = replace_func(text, "_friend_dealer_daily_report", friend_report)

        friend_text = '''func _daily_report_friend_dealers_text(report: Dictionary) -> String:
\tvar rows_variant: Variant = report.get("friend_dealers", [])
\tif not (rows_variant is Array) or (rows_variant as Array).is_empty():
\t\treturn ""
\tvar lines: Array[String] = []
\tfor row_variant: Variant in rows_variant as Array:
\t\tif not (row_variant is Dictionary):
\t\t\tcontinue
\t\tvar row: Dictionary = row_variant as Dictionary
\t\tlines.append("%s  |  %d sale(s), %dg, $%d gross  |  10%% commission: $%d" % [str(row.get("name", "Friend")), int(row.get("sales", 0)), int(row.get("grams", 0)), int(row.get("gross", 0)), int(row.get("commission", 0))])
\treturn "\\n".join(PackedStringArray(lines))
'''
        text = replace_func(text, "_daily_report_friend_dealers_text", friend_text)

        # Reset global per-day dealer customer lock when the day closes.
        reset_anchor = "\tdealer_sales_today = 0\n\t_reset_friend_dealer_daily_stats()\n"
        if reset_anchor not in text:
            raise SystemExit("Daily dealer reset anchor missing")
        text = text.replace(
            reset_anchor,
            "\tdealer_sales_today = 0\n\tdealer_customers_served_today = {}\n\t_reset_friend_dealer_daily_stats()\n",
            1,
        )

        # Closeout wording: commission only.
        text = text.replace(
            'settlement_line = "Dealer cash collected: $%d\\nCommission + wages: $%d\\nCASH THEY HAND YOU AFTER PAY: $%d" % [dealer_gross, dealer_commission + dealer_wages, dealer_net]',
            'settlement_line = "Dealer cash collected: $%d\\nDealer commission (10%%): $%d\\nCASH THEY HAND YOU AFTER COMMISSION: $%d" % [dealer_gross, dealer_commission, dealer_net]',
            1,
        )
        text = text.replace(
            'settlement_line = "Dealer cash collected: $%d\\nCommission + wages: $%d\\nYOU OWE THE CREW: $%d" % [dealer_gross, dealer_commission + dealer_wages, -dealer_net]',
            'settlement_line = "Dealer cash collected: $%d\\nDealer commission (10%%): $%d\\nBALANCE: $%d" % [dealer_gross, dealer_commission, -dealer_net]',
            1,
        )

        # Production worker: normal storage first. Dealer Locker is overflow only when
        # normal storage is already completely full.
        old_assign = '''\tfor name_variant in bagged_inventory.keys():
\t\tvar bagged_name: String = str(name_variant)
\t\tif int(bagged_inventory.get(bagged_name, 0)) > 0 and _total_stored_stock() < _storage_capacity():
\t\t\t_set_production_worker_task("store", "storage", -1, bagged_name, "Stocking %s" % bagged_name)
\t\t\treturn
'''
        new_assign = '''\tfor name_variant in bagged_inventory.keys():
\t\tvar bagged_name: String = str(name_variant)
\t\tvar normal_has_space: bool = _total_stored_stock() < _storage_capacity()
\t\tvar dealer_overflow_available: bool = not normal_has_space and _dealer_locker_free_capacity() > 0
\t\tif int(bagged_inventory.get(bagged_name, 0)) > 0 and (normal_has_space or dealer_overflow_available):
\t\t\tvar stock_task: String = "Stocking %s" % bagged_name if normal_has_space else "Overflow stocking Dealer Locker"
\t\t\t_set_production_worker_task("store", "storage", -1, bagged_name, stock_task)
\t\t\treturn
'''
        if old_assign not in text:
            raise SystemExit("Production worker assignment anchor missing")
        text = text.replace(old_assign, new_assign, 1)

        old_store = '''\t\t"store":
\t\t\tvar available_store: int = int(bagged_inventory.get(strain_name, 0))
\t\t\tvar free_capacity: int = maxi(0, _storage_capacity() - _total_stored_stock())
\t\t\tvar store_amount: int = mini(PRODUCTION_WORKER_BATCH_SIZE, mini(available_store, free_capacity))
\t\t\tif store_amount > 0:
\t\t\t\tbagged_inventory[strain_name] = available_store - store_amount
\t\t\t\t_ensure_product_exists(strain_name)
\t\t\t\tvar data: Dictionary = products[strain_name]
\t\t\t\tdata["stock"] = int(data.get("stock", 0)) + store_amount
\t\t\t\tproducts[strain_name] = data
'''
        new_store = '''\t\t"store":
\t\t\tvar available_store: int = int(bagged_inventory.get(strain_name, 0))
\t\t\tvar free_capacity: int = maxi(0, _storage_capacity() - _total_stored_stock())
\t\t\tvar store_amount: int = mini(PRODUCTION_WORKER_BATCH_SIZE, mini(available_store, free_capacity))
\t\t\tif store_amount > 0:
\t\t\t\tbagged_inventory[strain_name] = available_store - store_amount
\t\t\t\t_ensure_product_exists(strain_name)
\t\t\t\tvar data: Dictionary = products[strain_name]
\t\t\t\tdata["stock"] = int(data.get("stock", 0)) + store_amount
\t\t\t\tproducts[strain_name] = data
\t\t\telif free_capacity <= 0 and _dealer_locker_free_capacity() > 0:
\t\t\t\tvar overflow_amount: int = mini(PRODUCTION_WORKER_BATCH_SIZE, mini(available_store, _dealer_locker_free_capacity()))
\t\t\t\tif overflow_amount > 0:
\t\t\t\t\tbagged_inventory[strain_name] = available_store - overflow_amount
\t\t\t\t\tlocker_weed[strain_name] = int(locker_weed.get(strain_name, 0)) + overflow_amount
\t\t\t\t\tproduction_worker_last_action = "Overflow stocked %dg %s in Dealer Locker" % [overflow_amount, strain_name]
'''
        if old_store not in text:
            raise SystemExit("Production worker store anchor missing")
        text = text.replace(old_store, new_store, 1)

        # Dealer team UI: no wage/cap; show unique customer usage + locker state.
        emp_match = func_pattern("_build_employees_app").search(text)
        if not emp_match:
            raise SystemExit("Employees app missing")
        emp = emp_match.group(0)
        detail_pat = re.compile(r'\tdealer_detail\.text = "Dealers:.*?\n\tdealer_detail\.autowrap_mode', re.S)
        replacement = '''\tvar dealer_locker_cap: int = _dealer_locker_capacity()
\tvar dealer_locker_used: int = _dealer_locker_total()
\tdealer_detail.text = "Dealers: %d / %d  |  Status: %s\\nPay: %d%% commission only  |  No daily wage\\nSales today: %d  |  Unique clients served: %d / %d\\nDealer Locker: %dg / %dg%s\\nCash held for nightly drop-off: $%d\\nOutstanding dealer balance: $%d\\nFriend dealers: %s\\nEligible known clients: %s\\nNo daily sales cap. Every dealer shares one daily customer pool, so nobody can be sold to twice by the dealer team in the same day. Dealers sell only stock you put in the Dealer Locker." % [_total_dealer_count(), _dealer_capacity(), "WORKING" if dealers_active and _total_dealer_count() > 0 else "OFF DUTY", int(DEALER_COMMISSION_RATE * 100.0), dealer_sales_today, dealer_customers_served_today.size(), eligible_clients.size(), dealer_locker_used, dealer_locker_cap, "  |  LOCKED" if dealer_locker_cap <= 0 else "", dealer_cash_held, dealer_balance_due, dealer_staff_names, ", ".join(PackedStringArray(eligible_names)) if not eligible_names.is_empty() else "None yet"]
\tdealer_detail.autowrap_mode'''
        emp, count = detail_pat.subn(replacement, emp, count=1)
        if count != 1:
            raise SystemExit("Dealer employee detail anchor missing")
        text = text[:emp_match.start()] + emp.rstrip() + "\n\n" + text[emp_match.end():]

        # Dealer Locker upgrade card in Business > Upgrades.
        up_match = func_pattern("_build_upgrades_app").search(text)
        if not up_match:
            raise SystemExit("Upgrades app missing")
        upgrades = up_match.group(0)
        marker = "\tphone_list.add_child(equipment)\n\tfor supply_variant in supply_catalog.keys():\n"
        if marker not in upgrades:
            raise SystemExit("Upgrades insertion anchor missing")
        locker_card = '''\tphone_list.add_child(equipment)

\tvar dealer_locker_card: PanelContainer = PanelContainer.new()
\tphone_list.add_child(dealer_locker_card)
\tvar dealer_locker_box: VBoxContainer = VBoxContainer.new()
\tdealer_locker_box.add_theme_constant_override("separation", 7)
\tdealer_locker_card.add_child(dealer_locker_box)
\tvar dealer_locker_title: Label = Label.new()
\tdealer_locker_title.text = "DEALER LOCKER"
\tdealer_locker_title.add_theme_font_size_override("font_size", 20)
\tdealer_locker_box.add_child(dealer_locker_title)
\tvar dealer_locker_detail: Label = Label.new()
\tdealer_locker_detail.text = "Tier: %s  |  Capacity: %dg  |  Stored: %dg\\nDealers sell only from this locker. You stock it manually at the physical locker. The production worker can use it only as overflow after normal storage is completely full." % ["LOCKED" if dealer_locker_level <= 0 else _roman(dealer_locker_level), _dealer_locker_capacity(), _dealer_locker_total()]
\tdealer_locker_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
\tdealer_locker_box.add_child(dealer_locker_detail)
\tif dealer_locker_level < 4:
\t\tvar next_locker_level: int = dealer_locker_level + 1
\t\tvar next_locker_cost: int = DEALER_LOCKER_COST_BY_LEVEL[next_locker_level]
\t\tvar next_locker_capacity: int = DEALER_LOCKER_CAPACITY_BY_LEVEL[next_locker_level]
\t\tvar dealer_locker_buy: Button = Button.new()
\t\tdealer_locker_buy.text = "%s DEALER LOCKER %s  |  %dg  |  $%d" % ["UNLOCK" if dealer_locker_level <= 0 else "UPGRADE TO", _roman(next_locker_level), next_locker_capacity, next_locker_cost]
\t\tdealer_locker_buy.disabled = cash < next_locker_cost
\t\tdealer_locker_buy.custom_minimum_size.y = 50
\t\tdealer_locker_buy.pressed.connect(_buy_dealer_locker_upgrade)
\t\tdealer_locker_box.add_child(dealer_locker_buy)
\telse:
\t\tvar dealer_locker_max: Label = Label.new()
\t\tdealer_locker_max.text = "MAX TIER  |  400g"
\t\tdealer_locker_max.modulate = Color("a8d389")
\t\tdealer_locker_box.add_child(dealer_locker_max)

\tfor supply_variant in supply_catalog.keys():
'''
        upgrades = upgrades.replace(marker, locker_card, 1)
        text = text[:up_match.start()] + upgrades.rstrip() + "\n\n" + text[up_match.end():]

        # Save/load new dealer state.
        save_anchor = '\t\t"dealer_balance_due": dealer_balance_due,\n'
        if save_anchor not in text:
            raise SystemExit("Dealer save anchor missing")
        text = text.replace(
            save_anchor,
            save_anchor + '\t\t"dealer_locker_level": dealer_locker_level,\n\t\t"dealer_customers_served_today": dealer_customers_served_today,\n',
            1,
        )

        load_anchor = '\tdealer_balance_due = maxi(0, int(data.get("dealer_balance_due", 0)))\n'
        if load_anchor not in text:
            raise SystemExit("Dealer load anchor missing")
        text = text.replace(
            load_anchor,
            load_anchor + '\tdealer_locker_level = clampi(int(data.get("dealer_locker_level", dealer_locker_level)), 0, 4)\n'
            '\tvar loaded_dealer_customers_today: Variant = data.get("dealer_customers_served_today", {})\n'
            '\tif loaded_dealer_customers_today is Dictionary:\n'
            '\t\tdealer_customers_served_today = (loaded_dealer_customers_today as Dictionary).duplicate(true)\n',
            1,
        )

        locker_load_anchor = '''\tvar loaded_locker_weed: Variant = data.get("locker_weed", locker_weed)
\tif loaded_locker_weed is Dictionary:
\t\tlocker_weed = loaded_locker_weed as Dictionary
\tlocker_cash = maxi(0, int(data.get("locker_cash", locker_cash)))
'''
        if locker_load_anchor not in text:
            raise SystemExit("Locker migration anchor missing")
        locker_load_new = locker_load_anchor + '''\t# Migrate the unfinished personal-locker test safely into Dealer Storage.
\t# Existing locker product is preserved and receives the minimum tier needed to hold it.
\tvar legacy_dealer_stock: int = _dealer_locker_total()
\tif dealer_locker_level <= 0 and legacy_dealer_stock > 0:
\t\tdealer_locker_level = clampi(int(ceil(float(legacy_dealer_stock) / 100.0)), 1, 4)
\tif locker_cash > 0:
\t\tcash += locker_cash
\t\tlocker_cash = 0
'''
        text = text.replace(locker_load_anchor, locker_load_new, 1)

        product_load_anchor = '''\tfor pocket_strain_variant in personal_weed.keys():
\t\t_ensure_product_exists(str(pocket_strain_variant))
'''
        if product_load_anchor not in text:
            raise SystemExit("Product migration anchor missing")
        text = text.replace(
            product_load_anchor,
            product_load_anchor + '\tfor dealer_strain_variant: Variant in locker_weed.keys():\n\t\t_ensure_product_exists(str(dealer_strain_variant))\n',
            1,
        )

        # Hard verification for main.gd.
        required_main = [
            "const DEALER_DAILY_WAGE: int = 0",
            "const DEALER_COMMISSION_RATE: float = 0.10",
            "DEALER_LOCKER_CAPACITY_BY_LEVEL",
            "var dealer_locker_level: int = 0",
            "var dealer_customers_served_today: Dictionary = {}",
            "func _dealer_locker_add_from_storage",
            "func _dealer_locker_remove_to_storage",
            "func _dealer_sell_one(show_feedback: bool, assigned_dealer_name: String = \"\")",
            "dealer_customers_served_today[last_dealer_customer_name]",
            "Overflow stocked %dg %s in Dealer Locker",
            '"dealer_locker_level": dealer_locker_level',
            '"dealer_customers_served_today": dealer_customers_served_today',
            '"label": "Dealer Locker"',
            'locker_tag.text = "DEALER\\nSTOCK\\nLOCKER"',
        ]
        for needle in required_main:
            if needle not in text:
                raise SystemExit("main verification failed: " + needle)
        if "DEALER_SALES_PER_DAY" in text:
            raise SystemExit("Dealer sales cap reference remains")
        if "Locker storage is unavailable for now." in text:
            raise SystemExit("Locker is still disabled")

        names = re.findall(r"^func\s+([A-Za-z0-9_]+)\(", text, re.M)
        dup = {k:v for k,v in collections.Counter(names).items() if v > 1}
        if dup:
            raise SystemExit("Duplicate main functions: " + repr(dup))
        row[1] = text.encode("utf-8")

    elif row[0] == "scripts/personal_inventory.gd":
        inventory_found = True
        inv = row[1].decode("utf-8", "replace").rstrip(" \n\0")
        inv = inv.replace("const LOCKER_WEED_CAPACITY := 120", "const LOCKER_WEED_CAPACITY := 400", 1)

        locker_refresh = '''func _refresh_locker() -> void:
\t_clear(locker_body)
\t_header(locker_body, "DEALER STORAGE", close_locker)
\tvar capacity: int = game._dealer_locker_capacity()
\tvar used: int = game._dealer_locker_total()
\tvar summary := Label.new()
\tsummary.text = "Dealer Locker %s   |   %dg / %dg\\nDealers sell ONLY product stored here. You manually move packaged product between normal storage and this locker. The production worker uses this locker only when normal storage is completely full." % ["LOCKED" if game.dealer_locker_level <= 0 else game._roman(game.dealer_locker_level), used, capacity]
\tsummary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
\tlocker_body.add_child(summary)

\tif game.dealer_locker_level <= 0:
\t\tvar locked := Label.new()
\t\tlocked.text = "Dealer Locker I unlocks 100g for $300. Buy it in Phone -> Business -> Upgrades."
\t\tlocked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
\t\tlocker_body.add_child(locked)
\t\treturn

\tvar scroll := ScrollContainer.new()
\tscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
\tscroll.custom_minimum_size.y = 470
\tlocker_body.add_child(scroll)
\tvar content := VBoxContainer.new()
\tcontent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\tcontent.add_theme_constant_override("separation", 12)
\tscroll.add_child(content)

\tvar storage_title := Label.new()
\tstorage_title.text = "NORMAL STORAGE -> DEALER LOCKER"
\tstorage_title.add_theme_font_size_override("font_size", 19)
\tcontent.add_child(storage_title)
\tvar storage_note := Label.new()
\tstorage_note.text = "Only you can stock dealer inventory manually. Reserved product stays in normal storage."
\tstorage_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
\tcontent.add_child(storage_note)
\tvar storage_names: Array[String] = []
\tfor key_variant: Variant in game.products.keys():
\t\tvar strain_name: String = str(key_variant)
\t\tif game._available_amount(strain_name) > 0:
\t\t\tstorage_names.append(strain_name)
\tstorage_names.sort()
\tif storage_names.is_empty():
\t\tvar empty_storage := Label.new()
\t\tempty_storage.text = "No unreserved packaged product available in normal storage."
\t\tcontent.add_child(empty_storage)
\telse:
\t\tfor strain_name: String in storage_names:
\t\t\t_add_dealer_transfer_row(content, strain_name, game._available_amount(strain_name), true)

\tvar dealer_title := Label.new()
\tdealer_title.text = "DEALER LOCKER -> NORMAL STORAGE"
\tdealer_title.add_theme_font_size_override("font_size", 19)
\tcontent.add_child(dealer_title)
\tvar dealer_names: Array[String] = []
\tfor key_variant: Variant in game.locker_weed.keys():
\t\tvar strain_name: String = str(key_variant)
\t\tif int(game.locker_weed.get(strain_name, 0)) > 0:
\t\t\tdealer_names.append(strain_name)
\tdealer_names.sort()
\tif dealer_names.is_empty():
\t\tvar empty_locker := Label.new()
\t\tempty_locker.text = "Dealer Locker is empty."
\t\tcontent.add_child(empty_locker)
\telse:
\t\tfor strain_name: String in dealer_names:
\t\t\t_add_dealer_transfer_row(content, strain_name, int(game.locker_weed.get(strain_name, 0)), false)
'''
        inv = replace_func(inv, "_refresh_locker", locker_refresh)

        transfer_helpers = '''func _add_dealer_transfer_row(parent: VBoxContainer, strain_name: String, amount: int, moving_in: bool) -> void:
\tvar card := PanelContainer.new()
\tcard.add_theme_stylebox_override("panel", _style(Color("11191a"), Color("394d43"), 12, 1))
\tparent.add_child(card)
\tvar box := VBoxContainer.new()
\tbox.add_theme_constant_override("separation", 6)
\tcard.add_child(box)
\tvar title := Label.new()
\ttitle.text = "%s   |   %dg" % [strain_name, amount]
\ttitle.add_theme_font_size_override("font_size", 17)
\tbox.add_child(title)
\tvar controls := HBoxContainer.new()
\tcontrols.add_theme_constant_override("separation", 6)
\tbox.add_child(controls)
\tfor qty: int in [5, 10, 25]:
\t\tvar b := Button.new()
\t\tb.text = ("%s%dg" % ["+" if moving_in else "-", qty])
\t\tb.custom_minimum_size = Vector2(92, 42)
\t\tb.disabled = amount <= 0
\t\tif moving_in:
\t\t\tb.pressed.connect(_dealer_transfer_in.bind(strain_name, qty))
\t\telse:
\t\t\tb.pressed.connect(_dealer_transfer_out.bind(strain_name, qty))
\t\tcontrols.add_child(b)
\tvar all_button := Button.new()
\tall_button.text = "MAX" if moving_in else "ALL"
\tall_button.custom_minimum_size = Vector2(100, 42)
\tif moving_in:
\t\tall_button.pressed.connect(_dealer_transfer_in.bind(strain_name, 999999))
\telse:
\t\tall_button.pressed.connect(_dealer_transfer_out.bind(strain_name, 999999))
\tcontrols.add_child(all_button)

func _dealer_transfer_in(strain_name: String, amount: int) -> void:
\tgame._dealer_locker_add_from_storage(strain_name, amount)
\trefresh()

func _dealer_transfer_out(strain_name: String, amount: int) -> void:
\tgame._dealer_locker_remove_to_storage(strain_name, amount)
\trefresh()
'''
        inv = upsert_before(inv, "_add_dealer_transfer_row", transfer_helpers, "_inventory_drop")

        inv_required = [
            'DEALER STORAGE',
            'NORMAL STORAGE -> DEALER LOCKER',
            'DEALER LOCKER -> NORMAL STORAGE',
            'game._dealer_locker_add_from_storage',
            'game._dealer_locker_remove_to_storage',
        ]
        for needle in inv_required:
            if needle not in inv:
                raise SystemExit("inventory verification failed: " + needle)
        inv_names = re.findall(r"^func\s+([A-Za-z0-9_]+)\(", inv, re.M)
        inv_dup = {k:v for k,v in collections.Counter(inv_names).items() if v > 1}
        if inv_dup:
            raise SystemExit("Duplicate inventory functions: " + repr(inv_dup))
        row[1] = inv.encode("utf-8")

if not main_found:
    raise SystemExit("scripts/main.gd missing")
if not inventory_found:
    raise SystemExit("scripts/personal_inventory.gd missing")

packed = rebuild(blob, file_base, entries)
PCK.write_bytes(packed)

# Validate the rebuilt PCK and source payloads.
_, _, verify_entries = parse(PCK)
verify = {name: data.decode("utf-8", "replace") for name, data, _ in verify_entries if name in ["scripts/main.gd", "scripts/personal_inventory.gd", "scripts/touch_scroll.gd"]}
if "scripts/main.gd" not in verify or "scripts/personal_inventory.gd" not in verify:
    raise SystemExit("rebuilt source verification missing")
if "const TAP_SLOP: float = 12.0" not in verify.get("scripts/touch_scroll.gd", ""):
    raise SystemExit("cloudtest41 instant-tap controller was not preserved")

html = HTML.read_text()
html = re.sub(r'const AFB_TEST_RELEASE = "[^"]+";', f'const AFB_TEST_RELEASE = "{RELEASE}";', html, count=1)
html = re.sub(r'"fileSizes":\{[^}]*\}', f'"fileSizes":{{"{PACK_URL}":{len(packed)},"index.wasm":37902138}}', html, count=1)
html = re.sub(r'"mainPack":"[^"]+"', f'"mainPack":"{PACK_URL}"', html, count=1)
HTML.write_text(html)

meta = json.loads(VERSION.read_text())
meta["release_id"] = RELEASE
meta["dealer_economy"] = "10% commission only; no daily wage; no artificial daily sales cap"
meta["dealer_customer_lock"] = "one successful dealer-team sale per customer per game day across all dealers"
meta["dealer_locker"] = "physical locker is dealer-only stock; 100/200/300/400g tiers at $300/$600/$900/$1200"
meta["dealer_stock_source"] = "dealers sell only from Dealer Locker, never normal storage"
meta["production_worker_dealer_overflow"] = "worker may use Dealer Locker only when normal storage is completely full"
meta["player_inventory_note"] = "existing 40g backpack retained; old disabled personal locker repurposed as Dealer Storage"
meta["mobile_phone_taps"] = "cloudtest41 12px instant-tap movement threshold preserved"
VERSION.write_text(json.dumps(meta, indent=2) + "\n")

if BUILD.exists():
    build_text = BUILD.read_text()
    build_text = re.sub(r"Web release: .*", f"Web release: {RELEASE}", build_text)
    if "Web release:" not in build_text:
        build_text += f"\nWeb release: {RELEASE}\n"
    BUILD.write_text(build_text)

print("Built", RELEASE)
print("Dealer Locker tiers: 100/200/300/400g at $300/$600/$900/$1200")
print("Dealer pay: 10% commission, no daily wage, no fixed sales cap")
print("Dealer customers: globally unique per day across dealer team")
print("PCK bytes", len(packed))
