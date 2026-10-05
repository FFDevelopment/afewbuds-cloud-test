from pathlib import Path
import struct, hashlib, re, json, collections

PCK=Path("index-cloudtest10.pck")
HTML=Path("index.html")
VERSION=Path("version.json")
RELEASE="0.7.9-beta.19-cloudtest.51"
PACK_URL="index-cloudtest10.pck?build=51"

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

def upsert_before(src,name,new,before):
    ms=list(pat(name).finditer(src))
    if ms:
        at=ms[0].start()
        for m in reversed(ms): src=src[:m.start()]+src[m.end():]
        return src[:at]+new.rstrip()+"\n\n"+src[at:]
    at=src.find("func "+before+"(")
    if at<0: raise SystemExit("anchor "+before)
    return src[:at]+new.rstrip()+"\n\n"+src[at:]

blob,fb,entries=parse(PCK)
found=False
for row in entries:
    if row[0]!="scripts/main.gd": continue
    found=True
    text=row[1].decode("utf-8","replace").rstrip(" \n\0")

    # ---------- Main-room layout ----------
    m=pat("_build_apartment_details").search(text)
    if not m: raise SystemExit("_build_apartment_details missing")
    apt=m.group(0)

    kitchen_replacements={
        'Vector3(3.43, 0.46, -3.54)':'Vector3(2.16, 0.46, -3.54)',
        'Vector3(3.43, 0.93, -3.55)':'Vector3(2.22, 0.93, -3.55)',
        'Vector3(3.43, 1.38, -3.93)':'Vector3(2.22, 1.38, -3.93)',
        'Vector3(3.53, 2.08, -3.73)':'Vector3(2.26, 2.08, -3.73)',
        'Vector3(2.95, 0.99, -3.54)':'Vector3(1.68, 0.99, -3.54)',
        'Vector3(2.95, 1.17, -3.86)':'Vector3(1.68, 1.17, -3.86)',
    }
    for old,new in kitchen_replacements.items():
        if old not in apt: raise SystemExit("kitchen anchor missing "+old)
        apt=apt.replace(old,new,1)

    locker_replacements={
        'Vector3(4.52, 1.28, 2.68)':'Vector3(4.52, 1.28, -2.20)',
        'Vector3(4.13, 1.30, 2.68)':'Vector3(4.13, 1.30, -2.20)',
        'Vector3(4.13, 2.48, 2.68)':'Vector3(4.13, 2.48, -2.20)',
        'Vector3(4.13, 0.13, 2.68)':'Vector3(4.13, 0.13, -2.20)',
        'Vector3(4.13, 1.30, 2.37)':'Vector3(4.13, 1.30, -2.51)',
        'Vector3(4.13, 1.30, 2.99)':'Vector3(4.13, 1.30, -1.89)',
        'Vector3(4.08, 1.30 + vent_offset, 2.68)':'Vector3(4.08, 1.30 + vent_offset, -2.20)',
        'Vector3(4.08, 1.28, 2.56)':'Vector3(4.08, 1.28, -2.32)',
        'Vector3(4.06, 1.26, 2.56)':'Vector3(4.06, 1.26, -2.32)',
        'Vector3(4.045, 1.26, 2.56)':'Vector3(4.045, 1.26, -2.32)',
        'Vector3(4.10, 2.00, 3.02)':'Vector3(4.10, 2.00, -1.86)',
        'Vector3(4.10, 0.64, 3.02)':'Vector3(4.10, 0.64, -1.86)',
        'Vector3(4.80, 0.08, 2.95)':'Vector3(4.80, 0.08, -1.93)',
        'Vector3(4.80, 0.08, 2.41)':'Vector3(4.80, 0.08, -2.47)',
        'Vector3(4.09, 1.62, 2.70)':'Vector3(4.09, 1.62, -2.18)',
        'Vector3(4.88, 1.46, 2.51)':'Vector3(4.88, 1.46, -2.37)',
    }
    for old,new in locker_replacements.items():
        if old not in apt: raise SystemExit("basic locker anchor missing "+old)
        apt=apt.replace(old,new,1)
    text=text[:m.start()]+apt.rstrip()+"\n\n"+text[m.end():]

    old_premium='premium_dealer_locker_root.position = Vector3(4.52, 0.0, 2.68)'
    new_premium='premium_dealer_locker_root.position = Vector3(4.52, 0.0, -2.20)'
    if old_premium in text:
        text=text.replace(old_premium,new_premium,1)
    elif new_premium not in text:
        raise SystemExit("premium locker position missing")

    m=pat("_build_bagging_station").search(text)
    if not m: raise SystemExit("_build_bagging_station missing")
    bench=m.group(0)
    if "packing_station_start_index" not in bench:
        bench=bench.replace("func _build_bagging_station() -> void:\n",
                            "func _build_bagging_station() -> void:\n\tvar packing_station_start_index: int = get_child_count()\n",1)
        anchor="\t_sync_packing_bench_visuals(true)\n"
        if anchor not in bench: raise SystemExit("bench shift anchor missing")
        bench=bench.replace(anchor,anchor+
            "\tfor child_index: int in range(packing_station_start_index, get_child_count()):\n"
            "\t\tvar shifted_child: Node = get_child(child_index)\n"
            "\t\tif shifted_child is Node3D:\n"
            "\t\t\t(shifted_child as Node3D).position.z += 0.24\n",1)
    text=text[:m.start()]+bench.rstrip()+"\n\n"+text[m.end():]

    # Direct station interaction positions.
    text,n1=re.subn(
        r'(\{"id": "station_workbench", "room": "main", "pos": )Vector3\([^)]+\)(, "view": "workbench"\})',
        r'\1Vector3(3.95, 1.15, 0.54)\2',text,count=1)
    text,n2=re.subn(
        r'(\{"id": "station_locker", "room": "main", "pos": )Vector3\([^)]+\)(, "view": "locker"\})',
        r'\1Vector3(4.13, 1.30, -2.20)\2',text,count=1)
    if n1!=1 or n2!=1: raise SystemExit("direct station regex failed")

    # Close-up views, preserving whatever label the current runtime uses.
    text,n3=re.subn(
        r'("workbench": \{"pos": )Vector3\([^)]+\)(, "rot": Vector3\(0, -PI / 2\.0, 0\), "label": "Bagging Station"\})',
        r'\1Vector3(1.15, 1.60, 1.34)\2',text,count=1)
    text,n4=re.subn(
        r'("locker": \{"pos": )Vector3\([^)]+\)(, "rot": Vector3\(0, -PI / 2\.0, 0\), "fov": 68\.0, "label": "[^"]+"\})',
        r'\1Vector3(1.72, 1.56, -2.30)\2',text,count=1)
    if n3!=1 or n4!=1: raise SystemExit("camera view regex failed")

    # ---------- Bagging Bench III ----------
    catalog_anchor='"Bagging Bench II": {"unlock": 3, "cost": 275, "description": "Better packaging adds value to every sale."},'
    bench3_catalog='"Bagging Bench III": {"unlock": 6, "cost": 850, "description": "Industrial production workstation. Enables continuous manual bagging with variable 1-4g bags until the selected strain is fully packaged."},'
    if bench3_catalog not in text:
        if catalog_anchor not in text: raise SystemExit("Bagging Bench II catalog anchor missing")
        text=text.replace(catalog_anchor,catalog_anchor+"\n\t"+bench3_catalog,1)

    # Purchase state.
    m=pat("_supply_is_purchased").search(text)
    if not m: raise SystemExit("_supply_is_purchased missing")
    block=m.group(0)
    if '"Bagging Bench III": return bagging_level >= 3' not in block:
        anchor='\t\t"Bagging Bench II": return bagging_level >= 2\n'
        if anchor not in block: raise SystemExit("bench II purchased anchor missing")
        block=block.replace(anchor,anchor+'\t\t"Bagging Bench III": return bagging_level >= 3\n',1)
        text=text[:m.start()]+block.rstrip()+"\n\n"+text[m.end():]

    # Purchase routing + prerequisite.
    m=pat("_buy_supply").search(text)
    if not m: raise SystemExit("_buy_supply missing")
    block=m.group(0)
    if 'supply_name == "Bagging Bench III" and bagging_level < 2' not in block:
        prereq='\tif supply_name == HIDDEN_STASH_SUPPLY and storage_level < 4:\n\t\tstatus_label.text = "Install the AFB Storage Vault before buying the Hidden Wall Stash."\n\t\treturn\n'
        if prereq not in block: raise SystemExit("buy prerequisite anchor missing")
        block=block.replace(prereq,prereq+
            '\tif supply_name == "Bagging Bench III" and bagging_level < 2:\n'
            '\t\tstatus_label.text = "Install Bagging Bench II first."\n'
            '\t\treturn\n',1)
    if '"Bagging Bench III":\n\t\t\tbagging_level = maxi(bagging_level, 3)' not in block:
        route='\t\t"Bagging Bench II":\n\t\t\tbagging_level = maxi(bagging_level, 2)\n'
        if route not in block: raise SystemExit("bench II buy route missing")
        block=block.replace(route,route+
            '\t\t"Bagging Bench III":\n'
            '\t\t\tbagging_level = maxi(bagging_level, 3)\n',1)
    text=text[:m.start()]+block.rstrip()+"\n\n"+text[m.end():]

    # Permanent Bagging Bench family card in Upgrades, sequential like the other systems.
    m=pat("_build_upgrades_app").search(text)
    if not m: raise SystemExit("_build_upgrades_app missing")
    up=m.group(0)
    if '"BAGGING BENCH"' not in up:
        dealer_anchor='\t_add_dealer_locker_family_card(phone_list)\n'
        if dealer_anchor not in up: raise SystemExit("dealer family card anchor missing")
        bagging_card='''\tvar bagging_next: String = ""
\tif bagging_level <= 1: bagging_next = "Bagging Bench II"
\telif bagging_level == 2: bagging_next = "Bagging Bench III"
\tvar bagging_detail: String = "Current: Bench %s\\nLevel III perk: continuous 1-4g manual bagging until the selected strain is fully packaged." % _roman(bagging_level)
\t_add_upgrade_family_card(phone_list, "BAGGING BENCH", bagging_detail, bagging_next)

'''
        up=up.replace(dealer_anchor,bagging_card+dealer_anchor,1)
    # Prevent Bench II/III from also appearing as standalone equipment cards.
    up=up.replace(
        'var chain_names: Array[String] = ["Grow Supply Shelf II", "Grow Supply Shelf III", "Storage Shelving II", "Storage Shelving III", VAULT_SUPPLY, HIDDEN_STASH_SUPPLY, "Grow Tent Slot 2", "Grow Tent Slot 3"]',
        'var chain_names: Array[String] = ["Grow Supply Shelf II", "Grow Supply Shelf III", "Storage Shelving II", "Storage Shelving III", VAULT_SUPPLY, HIDDEN_STASH_SUPPLY, "Grow Tent Slot 2", "Grow Tent Slot 3", "Bagging Bench II", "Bagging Bench III"]',
        1
    )
    text=text[:m.start()]+up.rstrip()+"\n\n"+text[m.end():]

    # Level III industrial visual inspired by the supplied workstation references.
    visual=r'''func _build_bagging_bench_level3_visual() -> void:
	if get_node_or_null("BenchIIIBackBoard") != null:
		return
	var black: Color = Color("171a1d")
	var dark: Color = Color("202428")
	var steel: Color = Color("3a4146")
	var green: Color = Color("46e884")
	var wood: Color = Color("765238")

	# Tall industrial back / pegboard silhouette.
	_add_box("BenchIIIBackBoard", Vector3(4.62, 1.96, 0.54), Vector3(0.12, 1.48, 3.14), dark, 0.42, false, "res://assets/textures/brushed_metal.png", Vector3(1.0, 1.0, 2.0))
	_add_box("BenchIIIUpperCabinet", Vector3(4.43, 2.83, 0.54), Vector3(0.48, 0.58, 3.08), black, 0.34, false, "res://assets/textures/brushed_metal.png", Vector3(1.0, 1.0, 2.0))
	_add_box("BenchIIIUpperLip", Vector3(4.14, 2.50, 0.54), Vector3(0.54, 0.08, 3.02), steel, 0.30, false, "res://assets/textures/brushed_metal.png")
	_add_box("BenchIIITaskLight", Vector3(4.08, 2.43, 0.54), Vector3(0.035, 0.035, 2.76), green, 0.10, "", Vector3.ONE, true)

	# Enclosed lower cabinets/drawers while retaining the existing walnut work surface.
	_add_box("BenchIIILowerCabinetL", Vector3(3.48, 0.58, -0.34), Vector3(0.22, 0.86, 1.20), black, 0.36, false, "res://assets/textures/brushed_metal.png")
	_add_box("BenchIIILowerCabinetR", Vector3(3.48, 0.58, 1.42), Vector3(0.22, 0.86, 1.20), black, 0.36, false, "res://assets/textures/brushed_metal.png")
	for y_value: float in [0.34, 0.58, 0.82]:
		_add_box("BenchIIIDrawerL_%s" % str(y_value), Vector3(3.34, y_value, -0.34), Vector3(0.035, 0.18, 1.02), steel, 0.28)
		_add_box("BenchIIIDrawerR_%s" % str(y_value), Vector3(3.34, y_value, 1.42), Vector3(0.035, 0.18, 1.02), steel, 0.28)

	# Tool rail / small shelf details.
	_add_box("BenchIIIToolRail", Vector3(4.52, 1.90, 0.54), Vector3(0.10, 0.08, 2.70), Color("565e63"), 0.26, false, "res://assets/textures/brushed_metal.png")
	_add_box("BenchIIISmallShelf", Vector3(4.33, 1.58, 1.54), Vector3(0.46, 0.08, 0.72), wood, 0.54, false, "res://assets/textures/walnut.png")
	for tool_z: float in [-0.70, -0.28, 0.14, 0.56]:
		_add_box("BenchIIITool_%s" % str(tool_z), Vector3(4.49, 1.98, tool_z), Vector3(0.08, 0.36, 0.08), Color("b7bdc1"), 0.25, false, "res://assets/textures/brushed_metal.png")

	var label: Label3D = Label3D.new()
	label.name = "BenchIIIWorldLabel"
	label.text = "BAGGING BENCH III"
	label.font_size = 26
	label.pixel_size = 0.0028
	label.position = Vector3(3.98, 2.92, 0.54)
	label.rotation_degrees = Vector3(0, -90, 0)
	label.modulate = Color("9af4b6")
	add_child(label)
'''
    text=upsert_before(text,"_build_bagging_bench_level3_visual",visual,"_apply_visual_upgrades")

    m=pat("_apply_visual_upgrades").search(text)
    if not m: raise SystemExit("_apply_visual_upgrades missing")
    apply=m.group(0)
    if "_build_bagging_bench_level3_visual()" not in apply:
        anchor='\tif bagging_level >= 2:\n\t\t_set_mesh_color("ScaleBody", Color("16191d"))\n\t\t_set_mesh_color("BenchTop", Color("594231"))\n'
        if anchor not in apply: raise SystemExit("bagging visual anchor missing")
        apply=apply.replace(anchor,anchor+
            '\tif bagging_level >= 3:\n'
            '\t\t_build_bagging_bench_level3_visual()\n'
            '\t\t_set_mesh_color("BenchTop", Color("332c28"))\n',1)
        text=text[:m.start()]+apply.rstrip()+"\n\n"+text[m.end():]

    # Continuous 1-4g manual bagging at Bench III.
    start=r'''func _start_bag_minigame(strain_name: String) -> void:
	_cancel_phone_gesture()
	if tutorial_active and strain_name != tutorial_harvest_strain:
		status_label.text = "For the guide, use your harvested %s first." % tutorial_harvest_strain
		return
	if not _tutorial_can_do("bag"):
		return
	var amount: int = int(trimmed_inventory.get(strain_name, 0))
	if amount <= 0:
		return
	bag_active_strain = strain_name
	bag_available_units = amount
	bag_current_units = 0
	if bagging_level >= 3 and not tutorial_active:
		bag_target_units = rng.randi_range(1, mini(4, amount))
	else:
		bag_target_units = mini(3, amount)
	bag_dragging = false
	bag_bud_token.position = bag_token_home
	bag_bud_token.visible = true
	bag_seal_button.disabled = true
	bagging_panel.visible = false
	bag_minigame_panel.visible = true
	_refresh_bag_weight()
	_set_world_controls_visible(false)
'''
    text=replace_func(text,"_start_bag_minigame",start)

    seal=r'''func _seal_current_bag() -> void:
	if bag_active_strain.is_empty() or bag_current_units < bag_target_units:
		return
	var available: int = int(trimmed_inventory.get(bag_active_strain, 0))
	var moved: int = mini(available, bag_target_units)
	if moved <= 0:
		return

	trimmed_inventory[bag_active_strain] = available - moved
	_add_inventory(bagged_inventory, bag_active_strain, moved)
	_increment_advancement_stat("bags_sealed")
	_tutorial_record("bag", -1, bag_active_strain)
	_save_game()

	var remaining: int = int(trimmed_inventory.get(bag_active_strain, 0))
	if bagging_level >= 3 and not tutorial_active and remaining > 0:
		bag_available_units = remaining
		bag_current_units = 0
		bag_target_units = rng.randi_range(1, mini(4, remaining))
		bag_dragging = false
		bag_bud_token.position = bag_token_home
		bag_bud_token.visible = true
		bag_seal_button.disabled = true
		status_label.text = "Sealed %dg of %s. %dg remains - keep bagging." % [moved, bag_active_strain, remaining]
		_refresh_bag_weight()
		_sync_packing_bench_visuals(true)
		return

	status_label.text = "Sealed %dg of %s. All selected product is packaged." % [moved, bag_active_strain]
	_close_bag_minigame()
'''
    text=replace_func(text,"_seal_current_bag",seal)

    required=[
        '"Bagging Bench III"',
        '"unlock": 6, "cost": 850',
        '"Bagging Bench III": return bagging_level >= 3',
        'bagging_level = maxi(bagging_level, 3)',
        '"BAGGING BENCH"',
        'func _build_bagging_bench_level3_visual() -> void:',
        'BenchIIIUpperCabinet',
        'BenchIIITaskLight',
        'rng.randi_range(1, mini(4, amount))',
        'rng.randi_range(1, mini(4, remaining))',
        '"keep bagging."',
        'Vector3(2.16, 0.46, -3.54)',
        'premium_dealer_locker_root.position = Vector3(4.52, 0.0, -2.20)',
        '(shifted_child as Node3D).position.z += 0.24',
        '"station_locker", "room": "main", "pos": Vector3(4.13, 1.30, -2.20)',
        'PremiumLeftDoorPivot',
        'dealer_storage_reopen_after_pause',
    ]
    for needle in required:
        if needle not in text: raise SystemExit("verify "+needle)

    names=re.findall(r"^func\s+([A-Za-z0-9_]+)\(",text,re.M)
    dup={k:v for k,v in collections.Counter(names).items() if v>1}
    if dup: raise SystemExit("duplicates "+repr(dup))

    row[1]=text.encode("utf-8")

if not found: raise SystemExit("main missing")
packed=rebuild(blob,fb,entries); PCK.write_bytes(packed)

_,_,verify=parse(PCK)
sources={name:data.decode("utf-8","replace") for name,data,_ in verify if name in ["scripts/main.gd","scripts/touch_scroll.gd"]}
main=sources.get("scripts/main.gd","")
for needle in [
    '"Bagging Bench III"',
    'func _build_bagging_bench_level3_visual() -> void:',
    'rng.randi_range(1, mini(4, remaining))',
    'premium_dealer_locker_root.position = Vector3(4.52, 0.0, -2.20)',
    'PremiumLeftDoorPivot',
    'dealer_storage_reopen_after_pause',
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
meta["main_room_layout"]="kitchen shifted to grow-door frame; Dealer Storage moved to opposite side of packing bench; complete packing station shifted +0.24 along wall"
meta["bagging_bench_iii"]="Level 6 / $850 industrial workstation upgrade inspired by supplied reference images"
meta["bagging_bench_iii_perk"]="continuous manual bagging; each bag is randomly 1-4g and the minigame continues until the selected strain has no trimmed product left"
VERSION.write_text(json.dumps(meta,indent=2)+"\n")
print("Built",RELEASE,len(packed))
