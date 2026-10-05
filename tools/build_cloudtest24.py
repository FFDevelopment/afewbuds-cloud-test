from pathlib import Path
import struct, hashlib, re, json, collections

PCK=Path("index-cloudtest10.pck")
HTML=Path("index.html")
VERSION=Path("version.json")
RELEASE="0.7.9-beta.19-cloudtest.50"
PACK_URL="index-cloudtest10.pck?build=50"

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
    for m in reversed(ms): src=src[:m.start()]+src[m.end():]
    return src[:at]+new.rstrip()+"\n\n"+src[at:]

blob,fb,entries=parse(PCK)
found=False
for row in entries:
    if row[0]!="scripts/main.gd":
        continue
    found=True
    text=row[1].decode("utf-8","replace").rstrip(" \n\0")

    # Replace the single premium-door runtime state with explicit left/right doors.
    old_vars='''var premium_dealer_locker_root: Node3D
var premium_dealer_locker_door_pivot: Node3D
var premium_dealer_locker_open: bool = false
var premium_dealer_locker_tween: Tween
'''
    new_vars='''var premium_dealer_locker_root: Node3D
var premium_dealer_locker_left_door_pivot: Node3D
var premium_dealer_locker_right_door_pivot: Node3D
var premium_dealer_locker_open: bool = false
var premium_dealer_locker_left_tween: Tween
var premium_dealer_locker_right_tween: Tween
var dealer_storage_reopen_after_pause: bool = false
'''
    if old_vars in text:
        text=text.replace(old_vars,new_vars,1)
    elif "var premium_dealer_locker_left_door_pivot: Node3D" not in text:
        raise SystemExit("premium door variable block missing")

    build_func=r'''func _build_premium_dealer_locker_visual() -> void:
	if premium_dealer_locker_root != null:
		return
	premium_dealer_locker_root = Node3D.new()
	premium_dealer_locker_root.name = "PremiumDealerStorage"
	premium_dealer_locker_root.position = Vector3(4.52, 0.0, 2.68)
	add_child(premium_dealer_locker_root)

	var black: Color = Color("171a1d")
	var edge: Color = Color("252a2e")
	var green: Color = Color("43f08a")
	var interior: Color = Color("0e1712")

	_dealer_premium_box(premium_dealer_locker_root, "PremiumBack", Vector3(0.28, 1.42, 0.0), Vector3(0.12, 2.70, 1.38), interior, 0.34, "res://assets/textures/brushed_metal.png")
	_dealer_premium_box(premium_dealer_locker_root, "PremiumTop", Vector3(-0.02, 2.77, 0.0), Vector3(0.72, 0.12, 1.50), black, 0.32, "res://assets/textures/brushed_metal.png")
	_dealer_premium_box(premium_dealer_locker_root, "PremiumBottom", Vector3(-0.02, 0.08, 0.0), Vector3(0.72, 0.16, 1.50), black, 0.32, "res://assets/textures/brushed_metal.png")
	_dealer_premium_box(premium_dealer_locker_root, "PremiumSideL", Vector3(-0.02, 1.42, -0.72), Vector3(0.72, 2.62, 0.10), black, 0.32, "res://assets/textures/brushed_metal.png")
	_dealer_premium_box(premium_dealer_locker_root, "PremiumSideR", Vector3(-0.02, 1.42, 0.72), Vector3(0.72, 2.62, 0.10), black, 0.32, "res://assets/textures/brushed_metal.png")

	for shelf_y: float in [0.68, 1.13, 1.58, 2.03]:
		_dealer_premium_box(premium_dealer_locker_root, "PremiumShelf", Vector3(-0.10, shelf_y, 0.0), Vector3(0.55, 0.055, 1.20), edge, 0.30, "res://assets/textures/brushed_metal.png")
	_dealer_premium_box(premium_dealer_locker_root, "PremiumDrawer1", Vector3(-0.34, 0.42, 0.0), Vector3(0.08, 0.30, 1.10), Color("202428"), 0.28, "res://assets/textures/brushed_metal.png")
	_dealer_premium_box(premium_dealer_locker_root, "PremiumDrawer2", Vector3(-0.34, 0.15, 0.0), Vector3(0.08, 0.20, 1.10), Color("1b1f22"), 0.28, "res://assets/textures/brushed_metal.png")

	_dealer_premium_box(premium_dealer_locker_root, "PremiumLedTop", Vector3(-0.38, 2.59, 0.0), Vector3(0.025, 0.025, 1.28), green, 0.10, "", true)
	_dealer_premium_box(premium_dealer_locker_root, "PremiumLedLeft", Vector3(-0.38, 1.42, -0.63), Vector3(0.025, 2.35, 0.025), green, 0.10, "", true)
	_dealer_premium_box(premium_dealer_locker_root, "PremiumLedRight", Vector3(-0.38, 1.42, 0.63), Vector3(0.025, 2.35, 0.025), green, 0.10, "", true)
	var glow: OmniLight3D = OmniLight3D.new()
	glow.name = "PremiumInteriorGlow"
	glow.position = Vector3(-0.18, 1.65, 0.0)
	glow.light_color = Color("4cff96")
	glow.light_energy = 0.45
	glow.omni_range = 2.1
	premium_dealer_locker_root.add_child(glow)

	_dealer_premium_jar(premium_dealer_locker_root, "PremiumJarA", Vector3(-0.38, 2.20, -0.38), 0.11, 0.22, Color("718d48"))
	_dealer_premium_jar(premium_dealer_locker_root, "PremiumJarB", Vector3(-0.38, 2.20, 0.00), 0.10, 0.20, Color("87934e"))
	_dealer_premium_jar(premium_dealer_locker_root, "PremiumJarC", Vector3(-0.38, 2.20, 0.34), 0.08, 0.17, Color("667e40"))
	_dealer_premium_jar(premium_dealer_locker_root, "PremiumJarD", Vector3(-0.38, 1.76, -0.30), 0.10, 0.20, Color("8b7d45"))
	_dealer_premium_jar(premium_dealer_locker_root, "PremiumJarE", Vector3(-0.38, 1.76, 0.18), 0.10, 0.20, Color("6d8a4a"))
	_dealer_premium_box(premium_dealer_locker_root, "PremiumPouchA", Vector3(-0.39, 1.34, -0.26), Vector3(0.08, 0.30, 0.28), Color("485f52"), 0.62)
	_dealer_premium_box(premium_dealer_locker_root, "PremiumPouchB", Vector3(-0.39, 1.34, 0.12), Vector3(0.08, 0.25, 0.24), Color("58715d"), 0.62)

	# Two true door leaves. Both are mounted from the front face and hinge from
	# opposite outer edges. Their open angles are opposite signs so both swing
	# toward the player, never through the cabinet interior.
	premium_dealer_locker_left_door_pivot = Node3D.new()
	premium_dealer_locker_left_door_pivot.name = "PremiumLeftDoorPivot"
	premium_dealer_locker_left_door_pivot.position = Vector3(-0.42, 1.43, -0.73)
	premium_dealer_locker_root.add_child(premium_dealer_locker_left_door_pivot)
	_dealer_premium_box(premium_dealer_locker_left_door_pivot, "PremiumLeftDoor", Vector3(-0.02, 0.0, 0.36), Vector3(0.08, 2.55, 0.70), Color("181b1e"), 0.30, "res://assets/textures/brushed_metal.png")
	_dealer_premium_box(premium_dealer_locker_left_door_pivot, "PremiumLeftLedOuter", Vector3(-0.07, 0.0, 0.03), Vector3(0.025, 2.30, 0.025), green, 0.10, "", true)
	_dealer_premium_box(premium_dealer_locker_left_door_pivot, "PremiumLeftHandle", Vector3(-0.09, 0.0, 0.08), Vector3(0.08, 0.42, 0.09), Color("555d61"), 0.22, "res://assets/textures/brushed_metal.png")

	premium_dealer_locker_right_door_pivot = Node3D.new()
	premium_dealer_locker_right_door_pivot.name = "PremiumRightDoorPivot"
	premium_dealer_locker_right_door_pivot.position = Vector3(-0.42, 1.43, 0.73)
	premium_dealer_locker_root.add_child(premium_dealer_locker_right_door_pivot)
	_dealer_premium_box(premium_dealer_locker_right_door_pivot, "PremiumRightDoor", Vector3(-0.02, 0.0, -0.36), Vector3(0.08, 2.55, 0.70), Color("181b1e"), 0.30, "res://assets/textures/brushed_metal.png")
	_dealer_premium_box(premium_dealer_locker_right_door_pivot, "PremiumRightLedOuter", Vector3(-0.07, 0.0, -0.03), Vector3(0.025, 2.30, 0.025), green, 0.10, "", true)
	_dealer_premium_box(premium_dealer_locker_right_door_pivot, "PremiumRightHandle", Vector3(-0.09, 0.0, -0.08), Vector3(0.08, 0.42, 0.09), Color("555d61"), 0.22, "res://assets/textures/brushed_metal.png")
	_dealer_premium_box(premium_dealer_locker_right_door_pivot, "PremiumKeypad", Vector3(-0.095, -0.08, -0.22), Vector3(0.06, 0.28, 0.16), Color("111416"), 0.22)
	_dealer_premium_box(premium_dealer_locker_right_door_pivot, "PremiumKeypadRing", Vector3(-0.13, -0.12, -0.22), Vector3(0.018, 0.07, 0.07), green, 0.10, "", true)

	var left_label: Label3D = Label3D.new()
	left_label.text = "DEALER"
	left_label.font_size = 22
	left_label.pixel_size = 0.0026
	left_label.position = Vector3(-0.10, 0.42, 0.34)
	left_label.rotation_degrees = Vector3(0, -90, 0)
	left_label.modulate = Color("7df5a9")
	premium_dealer_locker_left_door_pivot.add_child(left_label)

	var right_label: Label3D = Label3D.new()
	right_label.text = "STORAGE"
	right_label.font_size = 22
	right_label.pixel_size = 0.0026
	right_label.position = Vector3(-0.10, 0.42, -0.34)
	right_label.rotation_degrees = Vector3(0, -90, 0)
	right_label.modulate = Color("7df5a9")
	premium_dealer_locker_right_door_pivot.add_child(right_label)

	premium_dealer_locker_root.visible = false
	premium_dealer_locker_open = false
'''
    text=replace_func(text,"_build_premium_dealer_locker_visual",build_func)

    sync_func=r'''func _sync_dealer_locker_visual() -> void:
	var premium: bool = dealer_locker_level >= 3
	for child: Node in get_children():
		if not child is Node3D:
			continue
		var node: Node3D = child as Node3D
		var part_name: String = str(node.name)
		if part_name.begins_with("Locker") or part_name in ["DealerBasicLogo", "DealerBasicTag"]:
			node.visible = not premium
	if premium_dealer_locker_root != null:
		premium_dealer_locker_root.visible = premium
	if not premium:
		if premium_dealer_locker_left_door_pivot != null:
			premium_dealer_locker_left_door_pivot.rotation.y = 0.0
		if premium_dealer_locker_right_door_pivot != null:
			premium_dealer_locker_right_door_pivot.rotation.y = 0.0
		premium_dealer_locker_open = false
'''
    text=replace_func(text,"_sync_dealer_locker_visual",sync_func)

    door_func=r'''func _set_premium_dealer_locker_open(opened: bool) -> void:
	if premium_dealer_locker_left_door_pivot == null or premium_dealer_locker_right_door_pivot == null or dealer_locker_level < 3:
		return
	if premium_dealer_locker_left_tween != null and premium_dealer_locker_left_tween.is_running():
		premium_dealer_locker_left_tween.kill()
	if premium_dealer_locker_right_tween != null and premium_dealer_locker_right_tween.is_running():
		premium_dealer_locker_right_tween.kill()
	premium_dealer_locker_open = opened

	# Front of the cabinet is negative X. Left leaf uses negative Y rotation,
	# right leaf positive Y rotation; both move toward negative X/outward.
	var left_target: float = deg_to_rad(-102.0) if opened else 0.0
	var right_target: float = deg_to_rad(102.0) if opened else 0.0

	premium_dealer_locker_left_tween = create_tween()
	premium_dealer_locker_left_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	premium_dealer_locker_left_tween.tween_property(premium_dealer_locker_left_door_pivot, "rotation:y", left_target, 0.32)

	premium_dealer_locker_right_tween = create_tween()
	premium_dealer_locker_right_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	premium_dealer_locker_right_tween.tween_property(premium_dealer_locker_right_door_pivot, "rotation:y", right_target, 0.32)
'''
    text=replace_func(text,"_set_premium_dealer_locker_open",door_func)

    # Pause takes exclusive UI control. Dealer Storage is temporarily hidden,
    # then restored by Resume Game.
    pause_func=r'''func _pause_gameplay(reason: String = "Paused. Resume whenever you are ready.", start_unix: float = 0.0) -> void:
	if not gameplay_ready or session_paused or reset_in_progress:
		return
	dealer_storage_reopen_after_pause = dealer_storage_panel != null and dealer_storage_panel.visible
	if away_started_unix <= 0.0:
		away_started_unix = start_unix if start_unix > 0.0 else Time.get_unix_time_from_system()
		away_growth_allowed = _offline_crops_enabled()
		away_worker_care_allowed = _offline_worker_care_enabled()
		away_worker_next_service = OfflinePlantCare.CARE_INTERVAL
		offline_plant_report.clear()
	session_paused = true
	_cancel_beta_reset()
	_cancel_phone_gesture()
	room_look_drag_active = false
	_cancel_station_drag()

	if dealer_storage_panel != null:
		dealer_storage_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if dealer_storage_reopen_after_pause:
			dealer_storage_panel.visible = false

	_sync_simulation_pause()
	if knock_player != null:
		knock_player.stop()
	if pause_overlay != null:
		var crop_copy: String = "Existing crops continue growing while you are away."
		if away_worker_care_allowed:
			crop_copy = "Your worker keeps existing plants watered and fertilized."
		if not away_growth_allowed:
			crop_copy = "First-day lesson active: plants stay frozen."
		var heat_copy: String = "Heat cools slowly while paused."
		if lay_low_active:
			heat_copy = "Heat cools slowly. Lay Low time continues."
		pause_message.text = "PAUSED\nDay %d  |  %s\n\nGameplay is frozen: visitors, sales, wages and story.\n\nWHILE AWAY\n%s\n%s" % [game_day, _format_game_clock(), crop_copy, heat_copy]
		pause_overlay.z_index = 1000
		pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		pause_overlay.visible = true
		pause_overlay.move_to_front()
	_refresh_tutorial_coach()
	_save_game()
'''
    text=replace_func(text,"_pause_gameplay",pause_func)

    resume_func=r'''func _resume_gameplay() -> void:
	if not session_paused:
		return
	if web_lifecycle != null and bool(web_lifecycle.hidden):
		return
	if away_started_unix > 0.0:
		var paused_now: float = Time.get_unix_time_from_system()
		_apply_paused_heat_and_quiet_time(maxf(0.0, paused_now - away_started_unix))
	_settle_away_plants()
	_update_all_plant_visuals()
	_update_cash_ui()
	if phone_open:
		_refresh_phone()
	if grow_panel.visible:
		_refresh_grow_panel()
	if plant_direct_panel != null and plant_direct_panel.visible:
		_refresh_direct_plant_panel()
	if not offline_plant_report.is_empty():
		status_label.text = _offline_plant_summary()

	session_paused = false
	if web_lifecycle != null:
		web_lifecycle.away = false
	last_active_frame_msec = Time.get_ticks_msec()
	last_active_frame_unix = Time.get_unix_time_from_system()

	if pause_overlay != null:
		pause_overlay.visible = false

	if dealer_storage_panel != null:
		dealer_storage_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		if dealer_storage_reopen_after_pause and current_view == "locker":
			dealer_storage_panel.visible = true
			dealer_storage_panel.move_to_front()
			_refresh_dealer_storage_panel()
			if dealer_locker_level >= 3:
				_set_premium_dealer_locker_open(true)
	dealer_storage_reopen_after_pause = false

	_sync_simulation_pause()
	_refresh_utility_controls()
	_set_world_controls_visible(not _any_modal_open())
	_refresh_tutorial_coach()
	if daily_report_pending:
		_show_daily_report()
	elif not _simulation_blocked():
		_schedule_next_customer()
		_check_reeves_trigger()
		_maybe_start_reeves_visit()
	_save_game()
'''
    text=replace_func(text,"_resume_gameplay",resume_func)

    close_match=pat("_close_dealer_storage_panel").search(text)
    if not close_match: raise SystemExit("close dealer storage missing")
    close_block=close_match.group(0)
    if "dealer_storage_reopen_after_pause = false" not in close_block:
        close_block=close_block.replace(
            "\tif dealer_storage_scroll != null:\n\t\tdealer_storage_scroll.cancel_touch()\n",
            "\tdealer_storage_reopen_after_pause = false\n\tif dealer_storage_scroll != null:\n\t\tdealer_storage_scroll.cancel_touch()\n",
            1
        )
        text=text[:close_match.start()]+close_block.rstrip()+"\n\n"+text[close_match.end():]

    required=[
        "var premium_dealer_locker_left_door_pivot: Node3D",
        "var premium_dealer_locker_right_door_pivot: Node3D",
        "var dealer_storage_reopen_after_pause: bool = false",
        "PremiumLeftDoorPivot",
        "PremiumRightDoorPivot",
        "var left_target: float = deg_to_rad(-102.0) if opened else 0.0",
        "var right_target: float = deg_to_rad(102.0) if opened else 0.0",
        "dealer_storage_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE",
        "pause_overlay.z_index = 1000",
        "dealer_storage_panel.mouse_filter = Control.MOUSE_FILTER_STOP",
        "dealer_storage_reopen_after_pause and current_view == \"locker\"",
        "const DEALER_COMMISSION_RATE: float = 0.10",
    ]
    for needle in required:
        if needle not in text: raise SystemExit("verify "+needle)

    forbidden=[
        "premium_dealer_locker_door_pivot",
        "premium_dealer_locker_tween",
        'var target: float = deg_to_rad(102.0) if opened else 0.0',
    ]
    for needle in forbidden:
        if needle in text: raise SystemExit("old single-door code remains: "+needle)

    names=re.findall(r"^func\s+([A-Za-z0-9_]+)\(",text,re.M)
    dup={k:v for k,v in collections.Counter(names).items() if v>1}
    if dup: raise SystemExit("duplicates "+repr(dup))

    row[1]=text.encode("utf-8")

if not found: raise SystemExit("main missing")
packed=rebuild(blob,fb,entries)
PCK.write_bytes(packed)

_,_,verify=parse(PCK)
sources={name:data.decode("utf-8","replace") for name,data,_ in verify if name in ["scripts/main.gd","scripts/touch_scroll.gd"]}
main=sources.get("scripts/main.gd","")
for needle in [
    "PremiumLeftDoorPivot",
    "PremiumRightDoorPivot",
    "dealer_storage_reopen_after_pause",
    "pause_overlay.z_index = 1000",
]:
    if needle not in main: raise SystemExit("packed verify "+needle)
if "const TAP_SLOP: float = 12.0" not in sources.get("scripts/touch_scroll.gd",""):
    raise SystemExit("mobile tap fix lost")

html=HTML.read_text()
html=re.sub(r'const AFB_TEST_RELEASE = "[^"]+";',f'const AFB_TEST_RELEASE = "{RELEASE}";',html,count=1)
html=re.sub(r'"fileSizes":\{[^}]*\}',f'"fileSizes":{{"{PACK_URL}":{len(packed)},"index.wasm":37902138}}',html,count=1)
html=re.sub(r'"mainPack":"[^"]+"',f'"mainPack":"{PACK_URL}"',html,count=1)
HTML.write_text(html)

meta=json.loads(VERSION.read_text())
meta["release_id"]=RELEASE
meta["dealer_storage_double_doors"]="premium Level III-IV cabinet now uses separate left/right door leaves with opposite outward hinge rotations"
meta["dealer_storage_pause_fix"]="Dealer Storage hides and releases input during pause; Resume Game restores it if it was open"
VERSION.write_text(json.dumps(meta,indent=2)+"\n")

print("Built",RELEASE,len(packed))
