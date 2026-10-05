from pathlib import Path
import struct, hashlib, re, json

SOURCE = Path("index-cloudtest10.pck")
TARGET = Path("index-cloudtest10.pck")
PACK_URL = "index-cloudtest10.pck?build=29"
RELEASE = "0.7.9-beta.19-cloudtest.29"

def align(n, a=32):
    return (n+a-1)//a*a

def parse(path):
    blob=path.read_bytes()
    if blob[:4] != b"GDPC":
        raise SystemExit("not pck")
    fb=struct.unpack_from("<Q",blob,24)[0]
    do=struct.unpack_from("<Q",blob,32)[0]
    count=struct.unpack_from("<I",blob,do)[0]
    pos=do+4
    entries=[]
    for _ in range(count):
        plen=struct.unpack_from("<I",blob,pos)[0]; pos+=4
        name=blob[pos:pos+plen].rstrip(b"\0").decode(); pos+=plen
        off=struct.unpack_from("<Q",blob,pos)[0]; pos+=8
        size=struct.unpack_from("<Q",blob,pos)[0]; pos+=8
        md5=blob[pos:pos+16]; pos+=16
        flags=struct.unpack_from("<I",blob,pos)[0]; pos+=4
        data=blob[fb+off:fb+off+size]
        if hashlib.md5(data).digest()!=md5:
            raise SystemExit("md5 mismatch "+name)
        entries.append([name,data,flags])
    return blob,fb,entries

def rebuild(blob,fb,entries):
    out=bytearray(blob[:fb]); cur=0; directory=[]
    for name,data,flags in entries:
        at=align(cur)
        out.extend(b"\0"*(at-cur))
        off=at
        out.extend(data)
        cur=off+len(data)
        directory.append((name,off,len(data),hashlib.md5(data).digest(),flags))
    do=align(len(out))
    out.extend(b"\0"*(do-len(out)))
    struct.pack_into("<Q",out,32,do)
    out.extend(struct.pack("<I",len(directory)))
    for name,off,size,md5,flags in directory:
        raw=name.encode(); plen=(len(raw)+3)//4*4
        out.extend(struct.pack("<I",plen)); out.extend(raw); out.extend(b"\0"*(plen-len(raw)))
        out.extend(struct.pack("<Q",off)); out.extend(struct.pack("<Q",size)); out.extend(md5); out.extend(struct.pack("<I",flags))
    return bytes(out)

blob,fb,entries=parse(SOURCE)

for row in entries:
    if row[0]!="scripts/main.gd":
        continue
    text=row[1].decode("utf-8","replace").rstrip(" \n\0")

    def replace_func(src, name, new_func):
        pat=re.compile(r"^func "+re.escape(name)+r"\([^\n]*\)(?: -> [^:]+)?:\n.*?(?=^func |\Z)",re.M|re.S)
        m=pat.search(src)
        if not m:
            raise SystemExit("Function missing: "+name)
        return src[:m.start()]+new_func.rstrip()+"\n\n"+src[m.end():]

    # Persistent phone text inbox + critical Heat staff state.
    marker="var last_customer_broadcast: String = \"\"\n"
    if marker not in text:
        raise SystemExit("text state insertion marker missing")
    state_block = (
        "var phone_text_messages: Array[Dictionary] = []\n"
        "var phone_text_unread: int = 0\n"
        "var critical_staff_event_active: bool = false\n"
        "var dealer_arrested: bool = false\n"
        "var dealer_bail_due: int = 0\n"
        "var production_worker_arrested: bool = false\n"
        "var production_worker_bail_due: int = 0\n"
    )
    if "var phone_text_messages:" not in text:
        text=text.replace(marker,marker+state_block,1)

    helpers = '''func _staff_heat_locked() -> bool:
\treturn heat >= 75.0

func _push_phone_text(sender: String, body: String) -> void:
\tif sender.is_empty() or body.is_empty():
\t\treturn
\tphone_text_messages.append({
\t\t"sender": sender,
\t\t"body": body,
\t\t"day": game_day,
\t\t"time": _format_game_clock(),
\t\t"read": false
\t})
\twhile phone_text_messages.size() > 60:
\t\tphone_text_messages.pop_front()
\tphone_text_unread += 1
\tif phone_open and phone_current_app in ["home", "texts"]:
\t\t_refresh_phone()

func _critical_dealer_sender() -> String:
\tvar friend_dealers: Array[String] = _friend_staff_names("dealer")
\tif not friend_dealers.is_empty():
\t\treturn friend_dealers[0]
\treturn "Dealer Team"

func _critical_production_sender() -> String:
\treturn production_worker_friend_name if not production_worker_friend_name.is_empty() else "Production Worker"

func _handle_critical_heat_staff() -> void:
\tif critical_staff_event_active or heat < 100.0:
\t\treturn
\tcritical_staff_event_active = true
\tvar had_dealers: bool = dealers_active and _total_dealer_count() > 0
\tvar had_production: bool = packing_employee_hired and packing_employee_active
\tif not had_dealers and not had_production:
\t\treturn
\tvar arrest_target: String = ""
\tif had_dealers and had_production:
\t\tarrest_target = "dealer" if rng.randf() < 0.5 else "production"
\telif had_dealers:
\t\tarrest_target = "dealer"
\telse:
\t\tarrest_target = "production"
\tif had_dealers:
\t\tdealers_active = false
\t\tvar dealer_sender: String = _critical_dealer_sender()
\t\tif arrest_target == "dealer":
\t\t\tdealer_arrested = true
\t\t\tdealer_bail_due = 750
\t\t\t_push_phone_text(dealer_sender, "I got picked up. Bail is $%d. I cannot go back to work until you send it, and I am staying home until the heat cools down." % dealer_bail_due)
\t\telse:
\t\t\t_push_phone_text(dealer_sender, "The heat is way too hot. We are heading home. Do not put us back out until things cool down.")
\tif had_production:
\t\tpacking_employee_active = false
\t\tproduction_worker_pending_action = ""
\t\tproduction_worker_task = "Off duty"
\t\tproduction_worker_last_action = "Went home - Heat too high"
\t\t_reset_production_worker_navigation()
\t\tvar worker_sender: String = _critical_production_sender()
\t\tif arrest_target == "production":
\t\t\tproduction_worker_arrested = true
\t\t\tproduction_worker_bail_due = 600
\t\t\t_push_phone_text(worker_sender, "I got picked up. Bail is $%d. I cannot come back to work until you send it, and I am staying off duty until the heat cools down." % production_worker_bail_due)
\t\telse:
\t\t\t_push_phone_text(worker_sender, "There is too much heat around the place. I am heading home. Call me back in when things cool down.")
\tstatus_label.text = "Heat hit 100. Your crew shut down. Check Texts."
\t_save_game()

func _pay_dealer_bail() -> void:
\tif not dealer_arrested or dealer_bail_due <= 0:
\t\treturn
\tif cash < dealer_bail_due:
\t\tstatus_label.text = "You need $%d for dealer bail." % dealer_bail_due
\t\treturn
\tvar amount: int = dealer_bail_due
\tcash -= amount
\t_record_daily_expense("Dealer bail", amount)
\tdealer_bail_due = 0
\tdealer_arrested = false
\t_push_phone_text(_critical_dealer_sender(), "I am out. Appreciate the bail. I am still staying home until the heat drops below 75.")
\t_update_cash_ui()
\t_save_game()
\t_refresh_phone()

func _pay_production_bail() -> void:
\tif not production_worker_arrested or production_worker_bail_due <= 0:
\t\treturn
\tif cash < production_worker_bail_due:
\t\tstatus_label.text = "You need $%d for production-worker bail." % production_worker_bail_due
\t\treturn
\tvar amount: int = production_worker_bail_due
\tcash -= amount
\t_record_daily_expense("Production worker bail", amount)
\tproduction_worker_bail_due = 0
\tproduction_worker_arrested = false
\t_push_phone_text(_critical_production_sender(), "I am out. Thanks for handling bail. I will come back once the heat drops below 75.")
\t_update_cash_ui()
\t_save_game()
\t_refresh_phone()

func _build_texts_app() -> void:
\tif dealer_arrested and dealer_bail_due > 0:
\t\tvar dealer_bail: Button = Button.new()
\t\tdealer_bail.text = "SEND DEALER BAIL  |  $%d" % dealer_bail_due
\t\tdealer_bail.disabled = cash < dealer_bail_due
\t\tdealer_bail.custom_minimum_size.y = 54
\t\tdealer_bail.pressed.connect(_pay_dealer_bail)
\t\tphone_list.add_child(dealer_bail)
\tif production_worker_arrested and production_worker_bail_due > 0:
\t\tvar worker_bail: Button = Button.new()
\t\tworker_bail.text = "SEND WORKER BAIL  |  $%d" % production_worker_bail_due
\t\tworker_bail.disabled = cash < production_worker_bail_due
\t\tworker_bail.custom_minimum_size.y = 54
\t\tworker_bail.pressed.connect(_pay_production_bail)
\t\tphone_list.add_child(worker_bail)
\tif phone_text_messages.is_empty():
\t\tvar empty: Label = Label.new()
\t\tempty.text = "No messages yet."
\t\tempty.modulate = Color("aeb9bf")
\t\tphone_list.add_child(empty)
\telse:
\t\tfor index: int in range(phone_text_messages.size() - 1, -1, -1):
\t\t\tvar msg: Dictionary = phone_text_messages[index]
\t\t\tvar card: PanelContainer = PanelContainer.new()
\t\t\tcard.add_theme_stylebox_override("panel", _style_box(Color("171d24"), Color("33434f"), 16, 1))
\t\t\tphone_list.add_child(card)
\t\t\tvar box: VBoxContainer = VBoxContainer.new()
\t\t\tbox.add_theme_constant_override("separation", 5)
\t\t\tcard.add_child(box)
\t\t\tvar header: Label = Label.new()
\t\t\theader.text = "%s   •   DAY %d  %s" % [str(msg.get("sender", "Unknown")), int(msg.get("day", game_day)), str(msg.get("time", ""))]
\t\t\theader.add_theme_font_size_override("font_size", 18)
\t\t\theader.modulate = Color("8ed6a3")
\t\t\tbox.add_child(header)
\t\t\tvar message: Label = Label.new()
\t\t\tmessage.text = str(msg.get("body", ""))
\t\t\tmessage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
\t\t\tbox.add_child(message)
\tfor i: int in range(phone_text_messages.size()):
\t\tphone_text_messages[i]["read"] = true
\tphone_text_unread = 0

'''
    insert_marker="func _text_known_customer(customer_name: String) -> void:\n"
    if insert_marker not in text:
        raise SystemExit("text helper insertion marker missing")
    if "func _build_texts_app() -> void:" not in text:
        text=text.replace(insert_marker,helpers+insert_marker,1)

    # Phone home gets a real Texts category.
    home_pat=re.compile(r"^func _build_phone_home\(\) -> void:\n.*?(?=^func |\Z)",re.M|re.S)
    hm=home_pat.search(text)
    if not hm:
        raise SystemExit("phone home missing")
    home=hm.group(0)
    task_tile='\t_add_phone_app_tile(grid, "", "Task", "Chapter progress & rewards", "task")\n'
    if task_tile not in home:
        raise SystemExit("Task tile missing")
    texts_tile='\t_add_phone_app_tile(grid, "", "Texts", ("%d unread" % phone_text_unread) if phone_text_unread > 0 else "Crew & story messages", "texts")\n'
    home=home.replace(task_tile,texts_tile+task_tile,1)
    text=text[:hm.start()]+home.rstrip()+"\n\n"+text[hm.end():]

    # Route the Texts app.
    refresh_pat=re.compile(r"^func _refresh_phone\(\) -> void:\n.*?(?=^func |\Z)",re.M|re.S)
    rm=refresh_pat.search(text)
    if not rm:
        raise SystemExit("phone refresh missing")
    rf=rm.group(0)
    route='\t\t"task":\n\t\t\tphone_title.text = "Task"\n\t\t\t_build_task_app()\n'
    if route not in rf:
        raise SystemExit("Task route missing")
    rf=rf.replace(route,'\t\t"texts":\n\t\t\tphone_title.text = "Texts"\n\t\t\t_build_texts_app()\n'+route,1)
    text=text[:rm.start()]+rf.rstrip()+"\n\n"+text[rm.end():]

    # 100 Heat immediately shuts down active crew.
    add_pat=re.compile(r"^func _add_heat\([^\n]*\) -> void:\n.*?(?=^func |\Z)",re.M|re.S)
    am=add_pat.search(text)
    if not am:
        raise SystemExit("add heat function missing")
    addfn=am.group(0)
    trigger='\t_check_reeves_trigger()\n'
    if trigger not in addfn:
        raise SystemExit("add heat trigger line missing")
    addfn=addfn.replace(trigger,'\tif heat >= 100.0 and not critical_staff_event_active:\n\t\t_handle_critical_heat_staff()\n'+trigger,1)
    text=text[:am.start()]+addfn.rstrip()+"\n\n"+text[am.end():]

    # Re-arm the event only after the operation has cooled below HOT.
    reduce_pat=re.compile(r"^func _reduce_heat\([^\n]*\) -> void:\n.*?(?=^func |\Z)",re.M|re.S)
    dm=reduce_pat.search(text)
    if not dm:
        raise SystemExit("reduce heat function missing")
    reducefn=dm.group(0)
    cause_line='\tlast_heat_cause = reason\n'
    if cause_line not in reducefn:
        raise SystemExit("reduce heat cause line missing")
    reducefn=reducefn.replace(cause_line,cause_line+'\tif heat < 75.0:\n\t\tcritical_staff_event_active = false\n',1)
    text=text[:dm.start()]+reducefn.rstrip()+"\n\n"+text[dm.end():]

    # Production worker refuses reactivation while arrested or Heat is HOT/CRITICAL.
    prod_toggle='''func _toggle_packing_employee() -> void:
\tif not packing_employee_hired:
\t\treturn
\tif not packing_employee_active and production_worker_arrested:
\t\tstatus_label.text = "Your worker is still being held. Pay the bail from Texts first."
\t\treturn
\tif not packing_employee_active and _staff_heat_locked():
\t\tstatus_label.text = "Your worker refuses to come back while Heat is 75 or higher."
\t\treturn
\tpacking_employee_active = not packing_employee_active
\tif not packing_employee_active:
\t\tproduction_worker_pending_action = ""
\t\tproduction_worker_task = "Off duty"
\t\tproduction_worker_last_action = "Off duty"
\telse:
\t\tproduction_worker_task = "Clocking in"
\t\tproduction_worker_last_action = "Clocking in"
\t\tproduction_worker_target_position = _production_worker_station_position("entry")
\t_reset_production_worker_navigation()
\tstatus_label.text = "Production worker is now %s." % ("WORKING" if packing_employee_active else "OFF DUTY")
\t_save_game()
\t_refresh_phone()
'''
    text=replace_func(text,"_toggle_packing_employee",prod_toggle)

    dealer_toggle='''func _toggle_dealers() -> void:
\tif _total_dealer_count() <= 0:
\t\treturn
\tif not dealers_active and dealer_arrested:
\t\tstatus_label.text = "One of your dealers is still being held. Pay the bail from Texts first."
\t\treturn
\tif not dealers_active and _staff_heat_locked():
\t\tstatus_label.text = "Your dealers refuse to go back out while Heat is 75 or higher."
\t\treturn
\tif dealer_balance_due > 0 and not dealers_active:
\t\tstatus_label.text = "Clear the $%d dealer balance before putting the team back on duty." % dealer_balance_due
\t\treturn
\tdealers_active = not dealers_active
\tstatus_label.text = "Dealer team is now %s." % ("WORKING" if dealers_active else "OFF DUTY")
\t_save_game()
\t_refresh_phone()
'''
    text=replace_func(text,"_toggle_dealers",dealer_toggle)

    # Prevent new/recruited crew from starting work while Heat is HOT/CRITICAL.
    for fname in ["_hire_packing_employee", "_hire_dealer", "_recruit_friend_staff"]:
        pat=re.compile(r"^func "+re.escape(fname)+r"\([^\n]*\)(?: -> [^:]+)?:\n",re.M)
        m=pat.search(text)
        if not m:
            raise SystemExit("staff hire function missing: "+fname)
        gate=(m.group(0)+'\tif _staff_heat_locked():\n\t\tstatus_label.text = "Nobody wants to start work while Heat is 75 or higher."\n\t\treturn\n')
        text=text[:m.start()]+gate+text[m.end():]

    # Do not let firing/releasing be used to bypass unpaid bail.
    for fname, guard in [
        ("_fire_packing_employee", '\tif production_worker_arrested:\n\t\tstatus_label.text = "Resolve the worker bail first."\n\t\treturn\n'),
        ("_fire_generic_dealer", '\tif dealer_arrested:\n\t\tstatus_label.text = "Resolve the dealer bail first."\n\t\treturn\n'),
    ]:
        pat=re.compile(r"^func "+re.escape(fname)+r"\([^\n]*\)(?: -> [^:]+)?:\n",re.M)
        m=pat.search(text)
        if m:
            text=text[:m.end()]+guard+text[m.end():]

    rel_pat=re.compile(r"^func _release_friend_staff\(customer_name: String\) -> void:\n",re.M)
    rel=rel_pat.search(text)
    if not rel:
        raise SystemExit("release friend staff missing")
    rel_guard=('\tvar held_role: String = _friend_staff_role(customer_name)\n'
               '\tif (held_role == "production" and production_worker_arrested) or (held_role == "dealer" and dealer_arrested):\n'
               '\t\tstatus_label.text = "Resolve the bail before ending this staff role."\n'
               '\t\treturn\n')
    text=text[:rel.end()]+rel_guard+text[rel.end():]

    # Save/load texts and arrest state.
    save_marker='\t\t"last_customer_broadcast": last_customer_broadcast,\n'
    if save_marker not in text:
        raise SystemExit("save text marker missing")
    save_extra=('\t\t"phone_text_messages": phone_text_messages,\n'
                '\t\t"phone_text_unread": phone_text_unread,\n'
                '\t\t"critical_staff_event_active": critical_staff_event_active,\n'
                '\t\t"dealer_arrested": dealer_arrested,\n'
                '\t\t"dealer_bail_due": dealer_bail_due,\n'
                '\t\t"production_worker_arrested": production_worker_arrested,\n'
                '\t\t"production_worker_bail_due": production_worker_bail_due,\n')
    text=text.replace(save_marker,save_marker+save_extra,1)

    load_marker='\tlast_customer_broadcast = str(data.get("last_customer_broadcast", last_customer_broadcast))\n'
    if load_marker not in text:
        raise SystemExit("load text marker missing")
    load_extra=('\tvar loaded_text_messages: Variant = data.get("phone_text_messages", [])\n'
                '\tif loaded_text_messages is Array:\n'
                '\t\tphone_text_messages.clear()\n'
                '\t\tfor msg_variant: Variant in loaded_text_messages:\n'
                '\t\t\tif msg_variant is Dictionary:\n'
                '\t\t\t\tphone_text_messages.append((msg_variant as Dictionary).duplicate(true))\n'
                '\tphone_text_unread = maxi(0, int(data.get("phone_text_unread", phone_text_unread)))\n'
                '\tcritical_staff_event_active = bool(data.get("critical_staff_event_active", critical_staff_event_active))\n'
                '\tdealer_arrested = bool(data.get("dealer_arrested", dealer_arrested))\n'
                '\tdealer_bail_due = maxi(0, int(data.get("dealer_bail_due", dealer_bail_due)))\n'
                '\tproduction_worker_arrested = bool(data.get("production_worker_arrested", production_worker_arrested))\n'
                '\tproduction_worker_bail_due = maxi(0, int(data.get("production_worker_bail_due", production_worker_bail_due)))\n')
    text=text.replace(load_marker,load_marker+load_extra,1)

    # Cleaner pause screen: concise, readable, no rate dump.
    pause_pat=re.compile(r"^func _pause_gameplay\([^\n]*\) -> void:\n.*?(?=^func |\Z)",re.M|re.S)
    pm=pause_pat.search(text)
    if not pm:
        raise SystemExit("pause function missing")
    pausefn=pm.group(0)
    pausefn=pausefn.replace(
        '\t\tvar crop_copy: String = "Existing crops still grow, use their water and applied fertilizer, and can lose health. Crops that finish alive wait for harvest. No on-duty worker is available to tend them."\n',
        '\t\tvar crop_copy: String = "Existing crops continue growing while you are away."\n',1)
    pausefn=pausefn.replace(
        '\t\t\tcrop_copy = "Your on-duty worker waters and fertilizes existing plants while away. Fertilizer uses your stored supply (%d left); watering continues if it runs out. No new seeds, harvesting or processing. Ready crops wait for you. Your day, sales, wages and story stay paused." % fertilizer_units\n',
        '\t\t\tcrop_copy = "Your worker keeps existing plants watered and fertilized."\n',1)
    pausefn=pausefn.replace(
        '\t\t\tcrop_copy = "First-day lesson protected: plants and all timers remain frozen while you learn."\n',
        '\t\t\tcrop_copy = "First-day lesson active: plants stay frozen."\n',1)
    old_pause='\t\tpause_message.text = "%s\\n\\n%s\\nHeat cools while paused: 100 to 0 in 72 real minutes.\\n%s\\nDay %d  |  %s" % [reason, crop_copy, _offline_plant_summary(), game_day, _format_game_clock()]\n'
    new_pause=('\t\tvar heat_copy: String = "Heat cools slowly while paused."\n'
               '\t\tif lay_low_active:\n'
               '\t\t\theat_copy = "Heat cools slowly. Lay Low time continues."\n'
               '\t\tpause_message.text = "PAUSED\\nDay %d  |  %s\\n\\nGameplay is frozen: visitors, sales, wages and story.\\n\\nWHILE AWAY\\n%s\\n%s" % [game_day, _format_game_clock(), crop_copy, heat_copy]\n')
    if old_pause not in pausefn:
        raise SystemExit("old verbose pause message missing")
    pausefn=pausefn.replace(old_pause,new_pause,1)
    text=text[:pm.start()]+pausefn.rstrip()+"\n\n"+text[pm.end():]

    # Verification.
    checks=[
        'func _build_texts_app() -> void:',
        '"Texts", ("%d unread" % phone_text_unread)',
        'phone_title.text = "Texts"',
        'Heat hit 100. Your crew shut down. Check Texts.',
        'dealer_bail_due = 750',
        'production_worker_bail_due = 600',
        'heat >= 75.0',
        '"phone_text_messages": phone_text_messages',
        'Gameplay is frozen: visitors, sales, wages and story.',
    ]
    for needle in checks:
        if needle not in text:
            raise SystemExit("cloudtest29 verification failed: "+needle)
    if "Heat cools while paused: 100 to 0 in 72 real minutes." in text:
        raise SystemExit("verbose pause Heat rate still visible")
    if "CLOUD TEST" in text:
        raise SystemExit("visible CLOUD TEST wording returned")

    row[1]=text.encode()

packed=rebuild(blob,fb,entries)
TARGET.write_bytes(packed)

idx=Path("index.html")
html=idx.read_text()
html=re.sub(r'const AFB_TEST_RELEASE = "[^"]+";',f'const AFB_TEST_RELEASE = "{RELEASE}";',html,count=1)
html=re.sub(r'"fileSizes":\{[^}]*\}',f'"fileSizes":{{"{PACK_URL}":{len(packed)},"index.wasm":37902138}}',html,count=1)
html=re.sub(r'"mainPack":"[^"]+"',f'"mainPack":"{PACK_URL}"',html,count=1)
idx.write_text(html)

v=Path("version.json")
meta=json.loads(v.read_text())
meta["release_id"]=RELEASE
meta["storefront_control_location"]="BudShop top"
meta["phone_home"]="BudShop, Task, Settings"
meta["task_page"]="Chapter progress, Rewards"
meta["visible_dev_wording"]="removed"
meta["paused_heat_decay"]="100 Heat over 72 real minutes"
meta["paused_lay_low_progress"]="1 Reeves quiet day per 24 real minutes while Lay Low is active"
meta["texts_app"]="persistent crew and story inbox"
meta["critical_heat_staff"]="100 Heat sends active crew home; one active role is arrested; return blocked at 75+ Heat"
meta["pause_overlay"]="simplified"
v.write_text(json.dumps(meta,indent=2)+"\n")

print("Built",RELEASE)
print("Added persistent Texts inbox and critical Heat staff consequences")
print("Added bail states and simplified pause overlay")
