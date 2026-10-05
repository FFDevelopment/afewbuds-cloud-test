from pathlib import Path
import struct, hashlib, re, json

SOURCE = Path("index-cloudtest10.pck")
TARGET = Path("index-cloudtest10.pck")
PACK_URL = "index-cloudtest10.pck?build=30"
RELEASE = "0.7.9-beta.19-cloudtest.30"
STASH_ART_B64 = "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"

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

    # Hidden Wall Stash upgrade after the 400g vault.
    vault_const='const VAULT_SUPPLY: String = "AFB Storage Vault"\n'
    if vault_const not in text:
        raise SystemExit("Vault constant missing")
    if 'const HIDDEN_STASH_SUPPLY:' not in text:
        text=text.replace(vault_const,vault_const+'const HIDDEN_STASH_SUPPLY: String = "Hidden Wall Stash"\n',1)

    vault_catalog='\t"AFB Storage Vault": {"unlock": 7, "cost": 1800, "description": "Replace all storage shelves with the AFB steel-and-green vault. 400g TOTAL sellable storage. Requires Storage Shelving III. Existing stock, reservations and listings stay unchanged."},\n'
    if vault_catalog not in text:
        raise SystemExit("Vault catalog entry missing")
    if '"Hidden Wall Stash":' not in text:
        stash_catalog='\t"Hidden Wall Stash": {"unlock": 9, "cost": 3250, "description": "Replace the 400g vault with a framed concealed wall stash. 1000g TOTAL sellable storage. Federal raids cannot find stored product. Requires the AFB Storage Vault."},\n'
        text=text.replace(vault_catalog,vault_catalog+stash_catalog,1)

    storage_var="var storage_vault: StorageVault\n"
    if storage_var not in text:
        raise SystemExit("storage vault variable missing")
    if "var hidden_stash_frame_pivot:" not in text:
        visual_vars=(
            "var hidden_stash_frame_pivot: Node3D\n"
            "var hidden_stash_interior_root: Node3D\n"
            "var hidden_stash_frame_open: bool = false\n"
            "var hidden_stash_frame_tween: Tween\n"
            "var hidden_stash_art_texture: Texture2D\n"
        )
        text=text.replace(storage_var,storage_var+visual_vars,1)

    friend_var="var friend_staff_roles: Dictionary = {}\n"
    if friend_var not in text:
        raise SystemExit("friend staff roles variable missing")
    if "var friend_dealer_stats:" not in text:
        text=text.replace(friend_var,friend_var+"var friend_dealer_stats: Dictionary = {}\n",1)

    storage_capacity='''func _storage_capacity() -> int:
\tif storage_level >= 5:
\t\treturn 1000
\tif storage_level >= 4:
\t\treturn StorageVault.CAPACITY_GRAMS
\tif storage_level <= 1:
\t\treturn 40
\tif storage_level == 2:
\t\treturn 90
\treturn 160
'''
    text=replace_func(text,"_storage_capacity",storage_capacity)

    # Upgrade purchase rules and persistence use the existing storage_level save field.
    buy_pat=re.compile(r"^func _buy_supply\(supply_name: String\) -> void:\n.*?(?=^func |\Z)",re.M|re.S)
    bm=buy_pat.search(text)
    if not bm:
        raise SystemExit("buy supply missing")
    buyfn=bm.group(0)
    vault_req='\tif supply_name == VAULT_SUPPLY and storage_level < 3:\n\t\tstatus_label.text = "Install Storage Shelving III before buying the vault."\n\t\treturn\n'
    if vault_req not in buyfn:
        raise SystemExit("vault requirement block missing")
    buyfn=buyfn.replace(vault_req,vault_req+'\tif supply_name == HIDDEN_STASH_SUPPLY and storage_level < 4:\n\t\tstatus_label.text = "Install the AFB Storage Vault before buying the Hidden Wall Stash."\n\t\treturn\n',1)
    vault_case='\t\t"AFB Storage Vault":\n\t\t\tstorage_level = 4\n'
    if vault_case not in buyfn:
        raise SystemExit("vault purchase case missing")
    buyfn=buyfn.replace(vault_case,vault_case+'\t\t"Hidden Wall Stash":\n\t\t\tstorage_level = 5\n',1)
    text=text[:bm.start()]+buyfn.rstrip()+"\n\n"+text[bm.end():]

    supply_pat=re.compile(r"^func _supply_is_purchased\(supply_name: String\) -> bool:\n.*?(?=^func |\Z)",re.M|re.S)
    sm=supply_pat.search(text)
    if not sm:
        raise SystemExit("supply purchased function missing")
    supplyfn=sm.group(0)
    vault_owned='\t\t"AFB Storage Vault": return storage_level >= 4\n'
    if vault_owned not in supplyfn:
        raise SystemExit("vault owned case missing")
    supplyfn=supplyfn.replace(vault_owned,vault_owned+'\t\t"Hidden Wall Stash": return storage_level >= 5\n',1)
    text=text[:sm.start()]+supplyfn.rstrip()+"\n\n"+text[sm.end():]

    upgrades_pat=re.compile(r"^func _build_upgrades_app\(\) -> void:\n.*?(?=^func |\Z)",re.M|re.S)
    um=upgrades_pat.search(text)
    if not um:
        raise SystemExit("upgrades builder missing")
    upgrades=um.group(0)
    vault_gate='\t\telif supply_name == VAULT_SUPPLY and storage_level < 3:\n\t\t\tbuy.text = "REQUIRES SHELVING III + LEVEL 7"\n\t\t\tbuy.disabled = true\n'
    if vault_gate not in upgrades:
        raise SystemExit("vault upgrade gate missing")
    upgrades=upgrades.replace(vault_gate,vault_gate+'\t\telif supply_name == HIDDEN_STASH_SUPPLY and storage_level < 4:\n\t\t\tbuy.text = "REQUIRES AFB STORAGE VAULT"\n\t\t\tbuy.disabled = true\n',1)
    text=text[:um.start()]+upgrades.rstrip()+"\n\n"+text[um.end():]

    # Build the concealed picture frame at the exact old vault anchor and swing it open on approach.
    visual_helpers = '''func _get_hidden_stash_art_texture() -> Texture2D:
\tif hidden_stash_art_texture != null:
\t\treturn hidden_stash_art_texture
\tvar raw: PackedByteArray = Marshalls.base64_to_raw("ART_B64_TOKEN")
\tvar image: Image = Image.new()
\tif image.load_webp_from_buffer(raw) != OK:
\t\treturn null
\thidden_stash_art_texture = ImageTexture.create_from_image(image)
\treturn hidden_stash_art_texture

func _hidden_stash_box(parent: Node3D, part_name: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
\tvar part: MeshInstance3D = MeshInstance3D.new()
\tpart.name = part_name
\tvar box: BoxMesh = BoxMesh.new()
\tbox.size = size
\tvar material: StandardMaterial3D = StandardMaterial3D.new()
\tmaterial.albedo_color = color
\tmaterial.roughness = 0.66
\tbox.material = material
\tpart.mesh = box
\tpart.position = pos
\tparent.add_child(part)
\treturn part

func _build_hidden_wall_stash_visual() -> void:
\tif hidden_stash_interior_root != null:
\t\treturn
\thidden_stash_interior_root = Node3D.new()
\thidden_stash_interior_root.name = "HiddenWallStash"
\thidden_stash_interior_root.position = StorageVault.ANCHOR
\thidden_stash_interior_root.rotation.y = StorageVault.FACING
\tadd_child(hidden_stash_interior_root)
\t_hidden_stash_box(hidden_stash_interior_root, "HiddenStashBack", Vector3(0.0, 1.30, -0.12), Vector3(2.08, 2.12, 0.08), Color("17191b"))
\t_hidden_stash_box(hidden_stash_interior_root, "HiddenStashTop", Vector3(0.0, 2.37, 0.02), Vector3(2.14, 0.10, 0.38), Color("3e342c"))
\t_hidden_stash_box(hidden_stash_interior_root, "HiddenStashBottom", Vector3(0.0, 0.23, 0.02), Vector3(2.14, 0.10, 0.38), Color("3e342c"))
\t_hidden_stash_box(hidden_stash_interior_root, "HiddenStashSideL", Vector3(-1.02, 1.30, 0.02), Vector3(0.10, 2.12, 0.38), Color("3e342c"))
\t_hidden_stash_box(hidden_stash_interior_root, "HiddenStashSideR", Vector3(1.02, 1.30, 0.02), Vector3(0.10, 2.12, 0.38), Color("3e342c"))
\tfor shelf_y: float in [0.78, 1.31, 1.84]:
\t\t_hidden_stash_box(hidden_stash_interior_root, "HiddenStashShelf", Vector3(0.0, shelf_y, 0.03), Vector3(1.86, 0.07, 0.34), Color("765b43"))
\thidden_stash_frame_pivot = Node3D.new()
\thidden_stash_frame_pivot.name = "HiddenStashFramePivot"
\thidden_stash_frame_pivot.position = Vector3(-1.04, 1.30, 0.245)
\thidden_stash_interior_root.add_child(hidden_stash_frame_pivot)
\t_hidden_stash_box(hidden_stash_frame_pivot, "HiddenStashFrame", Vector3(1.04, 0.0, 0.0), Vector3(2.12, 2.34, 0.08), Color("111315"))
\t_hidden_stash_box(hidden_stash_frame_pivot, "HiddenStashMat", Vector3(1.04, 0.0, 0.046), Vector3(1.90, 2.12, 0.025), Color("e8e3d7"))
\tvar art: Sprite3D = Sprite3D.new()
\tart.name = "HiddenStashArtwork"
\tart.texture = _get_hidden_stash_art_texture()
\tif art.texture != null:
\t\tart.pixel_size = 1.72 / float(art.texture.get_width())
\tart.position = Vector3(1.04, 0.0, 0.065)
\tart.shaded = false
\thidden_stash_frame_pivot.add_child(art)
\thidden_stash_frame_pivot.rotation.y = 0.0
\thidden_stash_frame_open = false

func _set_hidden_stash_open(opened: bool) -> void:
\tif hidden_stash_frame_pivot == null:
\t\treturn
\tif hidden_stash_frame_tween != null and hidden_stash_frame_tween.is_running():
\t\thidden_stash_frame_tween.kill()
\thidden_stash_frame_open = opened
\tvar target_angle: float = deg_to_rad(-98.0) if opened else 0.0
\thidden_stash_frame_tween = create_tween()
\thidden_stash_frame_tween.tween_property(hidden_stash_frame_pivot, "rotation:y", target_angle, 0.32)

'''.replace("ART_B64_TOKEN", STASH_ART_B64)
    sync_marker="func _sync_storage_furniture() -> void:\n"
    if sync_marker not in text:
        raise SystemExit("storage sync marker missing")
    if "func _build_hidden_wall_stash_visual() -> void:" not in text:
        text=text.replace(sync_marker,visual_helpers+sync_marker,1)

    storage_sync='''func _sync_storage_furniture() -> void:
\tvar show_hidden_stash: bool = storage_level >= 5
\tvar show_vault: bool = storage_level >= 4 and not show_hidden_stash
\tif show_vault and storage_vault == null:
\t\tstorage_vault = StorageVault.new()
\t\tstorage_vault.name = "StorageVault"
\t\tstorage_vault.position = StorageVault.ANCHOR
\t\tstorage_vault.rotation.y = StorageVault.FACING
\t\tadd_child(storage_vault)
\tif storage_vault != null:
\t\tstorage_vault.visible = show_vault
\tif hidden_stash_interior_root == null:
\t\t_build_hidden_wall_stash_visual()
\tif hidden_stash_interior_root != null:
\t\thidden_stash_interior_root.visible = show_hidden_stash
\t\tif not show_hidden_stash and hidden_stash_frame_pivot != null:
\t\t\thidden_stash_frame_pivot.rotation.y = 0.0
\t\t\thidden_stash_frame_open = false
\tvar shelf_names: Array[String] = ["StorageBack", "ShelfPostL", "ShelfPostR", "Shelf0", "Shelf1", "Shelf2", "Shelf3", "StorageBinA", "StorageBinB", "StorageJarA", "StorageJarB", "StorageBagA", "StorageBagB", "StorageCaseC", "StorageUpgradeBin", "StorageShelfBank2", "StorageExtraShelf0", "StorageExtraShelf1", "StorageExtraShelf2", "StorageExtraShelf3", "StorageWorldLabel"]
\tfor part_name: String in shelf_names:
\t\tvar part: Node3D = get_node_or_null(part_name) as Node3D
\t\tif part != null:
\t\t\tpart.visible = not show_vault and not show_hidden_stash
\tif storage_world_label != null:
\t\tstorage_world_label.text = "STORAGE   |   %dg CAP" % _storage_capacity()
'''
    text=replace_func(text,"_sync_storage_furniture",storage_sync)

    open_storage='''func _open_storage_panel() -> void:
\tif storage_level >= 5:
\t\t_set_hidden_stash_open(true)
\t\tawait get_tree().create_timer(0.28).timeout
\telif storage_vault != null and storage_level >= 4:
\t\tstorage_vault.turn_handle()
\tstorage_panel.visible = true
\t_set_world_controls_visible(false)
\t_refresh_storage_panel()
'''
    text=replace_func(text,"_open_storage_panel",open_storage)

    close_storage='''func _close_storage_panel() -> void:
\t_cancel_phone_gesture()
\tstorage_panel.visible = false
\tif storage_level >= 5:
\t\t_set_hidden_stash_open(false)
\t_go_to_view("main_storage")
\t_set_world_controls_visible(true)
\tstatus_label.text = "You close the hidden stash." if storage_level >= 5 else "You step back from storage."
'''
    text=replace_func(text,"_close_storage_panel",close_storage)

    text=text.replace(
        'contextual_button.text = ("APPROACH VAULT" if storage_level >= 4 else "APPROACH STORAGE") if _facing_station_threshold() else "LOOK TOWARD STORAGE"',
        'contextual_button.text = ("APPROACH HIDDEN STASH" if storage_level >= 5 else ("APPROACH VAULT" if storage_level >= 4 else "APPROACH STORAGE")) if _facing_station_threshold() else "LOOK TOWARD STORAGE"',
        1
    )
    text=text.replace(
        'contextual_button.text = "OPEN VAULT  |  400g" if storage_level >= 4 else "OPEN STORAGE"',
        'contextual_button.text = "OPEN HIDDEN STASH  |  1000g" if storage_level >= 5 else ("OPEN VAULT  |  400g" if storage_level >= 4 else "OPEN STORAGE")',
        1
    )

    storage_panel_pat=re.compile(r"^func _build_storage_panel\(\) -> void:\n.*?(?=^func |\Z)",re.M|re.S)
    spm=storage_panel_pat.search(text)
    if not spm:
        raise SystemExit("storage panel builder missing")
    storage_builder=spm.group(0)
    storage_builder=storage_builder.replace(
        '"This is your sellable inventory. The phone storefront pulls its quantities directly from here. Buy larger shelves or the 400g AFB vault in Phone -> Business -> Upgrades. Swipe the product list to scroll."',
        '"This is your sellable inventory. The phone storefront pulls directly from here. The 1000g Hidden Wall Stash replaces the vault and protects stored product during raids."',
        1
    )
    text=text[:spm.start()]+storage_builder.rstrip()+"\n\n"+text[spm.end():]

    refresh_storage_pat=re.compile(r"^func _refresh_storage_panel\(\) -> void:\n.*?(?=^func |\Z)",re.M|re.S)
    rsm=refresh_storage_pat.search(text)
    if not rsm:
        raise SystemExit("storage refresh missing")
    storage_refresh=rsm.group(0)
    old_header='capacity_header.text = "%s   |   %dg / %dg stored\\n%dg free" % ["AFB VAULT" if storage_level >= 4 else "STORAGE LEVEL %d" % storage_level, _total_stored_stock(), _storage_capacity(), maxi(0, _storage_capacity() - _total_stored_stock())]'
    new_header='capacity_header.text = "%s   |   %dg / %dg stored\\n%dg free" % ["HIDDEN WALL STASH" if storage_level >= 5 else ("AFB VAULT" if storage_level >= 4 else "STORAGE LEVEL %d" % storage_level), _total_stored_stock(), _storage_capacity(), maxi(0, _storage_capacity() - _total_stored_stock())]'
    if old_header not in storage_refresh:
        raise SystemExit("storage capacity header missing")
    storage_refresh=storage_refresh.replace(old_header,new_header,1)
    text=text[:rsm.start()]+storage_refresh.rstrip()+"\n\n"+text[rsm.end():]

    # Friend dealer accounting: individual sales, gross and commission while preserving pooled settlement.
    friend_helpers='''func _ensure_friend_dealer_stats(customer_name: String) -> Dictionary:
\tvar stats: Dictionary = {}
\tif friend_dealer_stats.has(customer_name) and friend_dealer_stats[customer_name] is Dictionary:
\t\tstats = (friend_dealer_stats[customer_name] as Dictionary).duplicate(true)
\tfor key: String in ["sales", "grams", "gross", "commission_earned", "wages_earned", "today_sales", "today_grams", "today_gross", "today_commission"]:
\t\tif not stats.has(key):
\t\t\tstats[key] = 0
\tfriend_dealer_stats[customer_name] = stats
\treturn stats

func _active_dealer_roster() -> Array[String]:
\tvar roster: Array[String] = []
\tfor friend_name: String in _friend_staff_names("dealer"):
\t\troster.append(friend_name)
\tfor index: int in range(dealer_count):
\t\troster.append("Hired Dealer %d" % (index + 1))
\treturn roster

func _record_friend_dealer_sale(customer_name: String, grams: int, gross: int, commission: int) -> void:
\tif customer_name.is_empty() or _friend_staff_role(customer_name) != "dealer":
\t\treturn
\tvar stats: Dictionary = _ensure_friend_dealer_stats(customer_name)
\tstats["sales"] = int(stats.get("sales", 0)) + 1
\tstats["grams"] = int(stats.get("grams", 0)) + grams
\tstats["gross"] = int(stats.get("gross", 0)) + gross
\tstats["commission_earned"] = int(stats.get("commission_earned", 0)) + commission
\tstats["today_sales"] = int(stats.get("today_sales", 0)) + 1
\tstats["today_grams"] = int(stats.get("today_grams", 0)) + grams
\tstats["today_gross"] = int(stats.get("today_gross", 0)) + gross
\tstats["today_commission"] = int(stats.get("today_commission", 0)) + commission
\tfriend_dealer_stats[customer_name] = stats

func _friend_dealer_daily_report(pay_wages: bool) -> Array[Dictionary]:
\tvar rows: Array[Dictionary] = []
\tfor friend_name: String in _friend_staff_names("dealer"):
\t\tvar stats: Dictionary = _ensure_friend_dealer_stats(friend_name)
\t\tvar wage: int = DEALER_DAILY_WAGE if pay_wages else 0
\t\tif wage > 0:
\t\t\tstats["wages_earned"] = int(stats.get("wages_earned", 0)) + wage
\t\t\tfriend_dealer_stats[friend_name] = stats
\t\trows.append({
\t\t\t"name": friend_name,
\t\t\t"sales": int(stats.get("today_sales", 0)),
\t\t\t"grams": int(stats.get("today_grams", 0)),
\t\t\t"gross": int(stats.get("today_gross", 0)),
\t\t\t"commission": int(stats.get("today_commission", 0)),
\t\t\t"wage": wage,
\t\t\t"total_pay": int(stats.get("today_commission", 0)) + wage
\t\t})
\treturn rows

func _reset_friend_dealer_daily_stats() -> void:
\tfor name_variant: Variant in friend_dealer_stats.keys():
\t\tvar friend_name: String = str(name_variant)
\t\tvar stats: Dictionary = _ensure_friend_dealer_stats(friend_name)
\t\tstats["today_sales"] = 0
\t\tstats["today_grams"] = 0
\t\tstats["today_gross"] = 0
\t\tstats["today_commission"] = 0
\t\tfriend_dealer_stats[friend_name] = stats

func _daily_report_friend_dealers_text(report: Dictionary) -> String:
\tvar rows_variant: Variant = report.get("friend_dealers", [])
\tif not (rows_variant is Array) or (rows_variant as Array).is_empty():
\t\treturn ""
\tvar lines: Array[String] = []
\tfor row_variant: Variant in rows_variant as Array:
\t\tif not (row_variant is Dictionary):
\t\t\tcontinue
\t\tvar row: Dictionary = row_variant as Dictionary
\t\tlines.append("%s  |  %d sale(s), %dg, $%d gross  |  Commission $%d + wage $%d = $%d pay" % [str(row.get("name", "Friend")), int(row.get("sales", 0)), int(row.get("grams", 0)), int(row.get("gross", 0)), int(row.get("commission", 0)), int(row.get("wage", 0)), int(row.get("total_pay", 0))])
\treturn "\\n".join(PackedStringArray(lines))

'''
    friend_marker="func _friend_staff_role(customer_name: String) -> String:\n"
    if friend_marker not in text:
        raise SystemExit("friend role marker missing")
    if "func _ensure_friend_dealer_stats(" not in text:
        text=text.replace(friend_marker,friend_helpers+friend_marker,1)

    recruit_pat=re.compile(r"^func _recruit_friend_staff\(customer_name: String, role: String\) -> void:\n.*?(?=^func |\Z)",re.M|re.S)
    rfm=recruit_pat.search(text)
    if not rfm:
        raise SystemExit("friend recruit function missing")
    recruit=rfm.group(0)
    dealer_assign='\t\tfriend_staff_roles[customer_name] = "dealer"\n'
    if dealer_assign not in recruit:
        raise SystemExit("friend dealer assignment missing")
    recruit=recruit.replace(dealer_assign,dealer_assign+'\t\t_ensure_friend_dealer_stats(customer_name)\n',1)
    text=text[:rfm.start()]+recruit.rstrip()+"\n\n"+text[rfm.end():]

    dealer_pat=re.compile(r"^func _dealer_sell_one\(show_feedback: bool\) -> bool:\n.*?(?=^func |\Z)",re.M|re.S)
    dsm=dealer_pat.search(text)
    if not dsm:
        raise SystemExit("dealer sale function missing")
    dealerfn=dsm.group(0)
    commission_line='\tvar commission: int = int(ceil(float(gross_revenue) * DEALER_COMMISSION_RATE))\n'
    if commission_line not in dealerfn:
        raise SystemExit("dealer commission line missing")
    dealerfn=dealerfn.replace(commission_line,commission_line+'\tvar dealer_roster: Array[String] = _active_dealer_roster()\n\tvar sale_dealer_name: String = ""\n\tif not dealer_roster.is_empty():\n\t\tsale_dealer_name = dealer_roster[dealer_sales_today % dealer_roster.size()]\n',1)
    sales_inc='\tdealer_sales_today += 1\n'
    if sales_inc not in dealerfn:
        raise SystemExit("dealer sales increment missing")
    dealerfn=dealerfn.replace(sales_inc,sales_inc+'\t_record_friend_dealer_sale(sale_dealer_name, qty, gross_revenue, commission)\n',1)
    text=text[:dsm.start()]+dealerfn.rstrip()+"\n\n"+text[dsm.end():]

    employees_pat=re.compile(r"^func _build_employees_app\(\) -> void:\n.*?(?=^func |\Z)",re.M|re.S)
    em=employees_pat.search(text)
    if not em:
        raise SystemExit("employees app missing")
    employees=em.group(0)
    dealer_detail_add='\tdealer_box.add_child(dealer_detail)\n'
    if dealer_detail_add not in employees:
        raise SystemExit("dealer detail add missing")
    friend_stats_ui=('\tfor friend_dealer_name: String in friend_dealers:\n'
                     '\t\tvar friend_stats: Dictionary = _ensure_friend_dealer_stats(friend_dealer_name)\n'
                     '\t\tvar friend_line: Label = Label.new()\n'
                     '\t\tfriend_line.text = "%s  |  Today: %d sales / %dg / $%d gross  |  Career: %d sales / %dg / $%d gross  |  Commission earned: $%d" % [friend_dealer_name, int(friend_stats.get("today_sales", 0)), int(friend_stats.get("today_grams", 0)), int(friend_stats.get("today_gross", 0)), int(friend_stats.get("sales", 0)), int(friend_stats.get("grams", 0)), int(friend_stats.get("gross", 0)), int(friend_stats.get("commission_earned", 0))]\n'
                     '\t\tfriend_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART\n'
                     '\t\tfriend_line.modulate = Color("a8d389")\n'
                     '\t\tdealer_box.add_child(friend_line)\n')
    employees=employees.replace(dealer_detail_add,dealer_detail_add+friend_stats_ui,1)
    text=text[:em.start()]+employees.rstrip()+"\n\n"+text[em.end():]

    prep_pat=re.compile(r"^func _prepare_daily_report\(closing_day: int\) -> void:\n.*?(?=^func |\Z)",re.M|re.S)
    prm=prep_pat.search(text)
    if not prm:
        raise SystemExit("daily report prep missing")
    prep=prm.group(0)
    prep=prep.replace('if _total_dealer_count() > 0 and dealers_active:','if _total_dealer_count() > 0 and (dealers_active or dealer_sales_today > 0):',1)
    dealer_net_line='\tvar dealer_net: int = dealer_gross - dealer_commission - dealer_wages\n'
    if dealer_net_line not in prep:
        raise SystemExit("dealer net line missing")
    prep=prep.replace(dealer_net_line,dealer_net_line+'\tvar friend_dealer_report: Array[Dictionary] = _friend_dealer_daily_report(dealer_wages > 0)\n',1)
    last_key='\t\t"dealer_sales_count": dealer_sales_today\n'
    if last_key not in prep:
        raise SystemExit("dealer sales report key missing")
    prep=prep.replace(last_key,'\t\t"dealer_sales_count": dealer_sales_today,\n\t\t"friend_dealers": friend_dealer_report\n',1)
    reset_sales='\tdealer_sales_today = 0\n'
    if reset_sales not in prep:
        raise SystemExit("dealer daily reset missing")
    prep=prep.replace(reset_sales,reset_sales+'\t_reset_friend_dealer_daily_stats()\n',1)
    text=text[:prm.start()]+prep.rstrip()+"\n\n"+text[prm.end():]

    show_report='''func _show_daily_report() -> void:
\tif not daily_report_pending or daily_report_panel == null:
\t\treturn
\tvar report: Dictionary = daily_report_data
\tvar closing_day: int = int(report.get("day", maxi(1, game_day - 1)))
\tvar next_day: int = int(report.get("next_day", game_day))
\tvar dealer_count_report: int = int(report.get("dealer_count", 0))
\tvar dealer_gross: int = int(report.get("dealer_gross", 0))
\tvar dealer_commission: int = int(report.get("dealer_commission", 0))
\tvar dealer_wages: int = int(report.get("dealer_wages", 0))
\tvar dealer_net: int = int(report.get("dealer_net", 0))
\tvar gross: int = int(report.get("gross", 0))
\tvar total_cost: int = int(report.get("total_cost", 0))
\tvar profit: int = int(report.get("profit", 0))
\tdaily_report_title.text = ("DEALER DROP-OFF  |  DAY %d" % closing_day) if dealer_count_report > 0 else ("DAY %d CLOSEOUT" % closing_day)
\tvar settlement_line: String = "No dealer settlement tonight."
\tif dealer_count_report > 0:
\t\tif dealer_net >= 0:
\t\t\tsettlement_line = "Dealer cash collected: $%d\\nCommission + wages: $%d\\nCASH THEY HAND YOU AFTER PAY: $%d" % [dealer_gross, dealer_commission + dealer_wages, dealer_net]
\t\telse:
\t\t\tsettlement_line = "Dealer cash collected: $%d\\nCommission + wages: $%d\\nYOU OWE THE CREW: $%d" % [dealer_gross, dealer_commission + dealer_wages, -dealer_net]
\tvar friend_section: String = ""
\tvar friend_text: String = _daily_report_friend_dealers_text(report)
\tif not friend_text.is_empty():
\t\tfriend_section = "\\n\\nFRIEND DEALERS\\n%s" % friend_text
\tdaily_report_body.text = "PRODUCT SOLD\\n%s\\n\\nREVENUE / COSTS\\nGross product revenue: $%d\\n%s\\n\\nTotal operating cost: $%d\\nDAY PROFIT: $%d\\n\\n%s%s\\n\\nPower charges are posted to Utilities and can be paid from the Business app." % [_daily_report_sales_text(report), gross, _daily_report_expense_text(report), total_cost, profit, settlement_line, friend_section]
\tdaily_report_action.text = ("SETTLE DEALERS  |  START DAY %d" % next_day) if dealer_count_report > 0 else ("START DAY %d" % next_day)
\tdaily_report_panel.visible = true
\t_set_world_controls_visible(false)
\tif not closeout_announced:
\t\tcloseout_announced = true
\t\tif dealer_count_report > 0 and knock_player != null and not session_paused:
\t\t\tknock_player.play()
\t_refresh_tutorial_coach()
\tif status_label != null:
\t\tstatus_label.text = "DAY CLOSED  |  Time is frozen. Review the report, then press START DAY when ready."
'''
    text=replace_func(text,"_show_daily_report",show_report)

    # Save/load named dealer history.
    save_friend_marker='\t\t"friend_staff_roles": friend_staff_roles,\n'
    if save_friend_marker not in text:
        raise SystemExit("friend staff save marker missing")
    text=text.replace(save_friend_marker,save_friend_marker+'\t\t"friend_dealer_stats": friend_dealer_stats,\n',1)
    load_friend_marker='\tfriend_staff_roles = (data.get("friend_staff_roles", friend_staff_roles) as Dictionary).duplicate(true)\n'
    if load_friend_marker not in text:
        raise SystemExit("friend staff load marker missing")
    text=text.replace(load_friend_marker,load_friend_marker+'\tvar loaded_friend_dealer_stats: Variant = data.get("friend_dealer_stats", {})\n\tif loaded_friend_dealer_stats is Dictionary:\n\t\tfriend_dealer_stats = (loaded_friend_dealer_stats as Dictionary).duplicate(true)\n',1)

    # Raid now wipes all exposed growing/processing/storage product; hidden stash survives.
    raid_func='''func _trigger_raid_event() -> void:
\tvar lost_plants: int = 0
\tfor slot_index: int in range(plant_slots.size()):
\t\tif int(plant_slots[slot_index].get("stage", -1)) >= 0:
\t\t\tlost_plants += 1
\t\t\tplant_slots[slot_index] = _empty_plant_slot()
\tvar lost_bench: int = _inventory_grams(untrimmed_inventory) + _inventory_grams(trimmed_inventory) + _inventory_grams(bagged_inventory)
\tuntrimmed_inventory.clear()
\ttrimmed_inventory.clear()
\tbagged_inventory.clear()
\tvar lost_storage: int = 0
\tvar protected_storage: int = 0
\tif storage_level >= 5:
\t\tprotected_storage = _total_stored_stock()
\telse:
\t\tfor product_variant in products.keys():
\t\t\tvar product_name: String = str(product_variant)
\t\t\tvar data: Dictionary = products[product_name]
\t\t\tvar stock: int = int(data.get("stock", 0))
\t\t\tlost_storage += stock
\t\t\tdata["stock"] = 0
\t\t\tdata["reserved"] = 0
\t\t\tdata["listed"] = false
\t\t\tproducts[product_name] = data
\tvar seized_cash: int = mini(cash, 300 + int(round(heat)) * 8)
\tcash -= seized_cash
\treputation = maxi(0, reputation - 10)
\tdealers_active = false
\tpacking_employee_active = false
\tproduction_worker_pending_action = ""
\tproduction_worker_task = "Off duty"
\tproduction_worker_last_action = "Sent home after raid"
\t_reset_production_worker_navigation()
\tif business_open:
\t\t_set_business_away()
\tlay_low_active = true
\traid_lockdown_until_day = game_day + 1
\traids_survived += 1
\tlast_raid_day = game_day
\t_increment_advancement_stat("raids_survived")
\tenforcement_risk = maxf(20.0, enforcement_risk - 45.0)
\theat = minf(heat, 35.0)
\treeves_arrangement_active = false
\treeves_missed_payments = 0
\treeves_next_payment_day = game_day + 2
\treeves_payment_level += 1
\traid_warning_day = -1
\t_update_all_plant_visuals()
\t_sync_packing_bench_visuals(true)
\tif storage_panel != null and storage_panel.visible:
\t\t_refresh_storage_panel()
\tvar protected_note: String = ""
\tif protected_storage > 0:
\t\tprotected_note = " Hidden Wall Stash protected %dg." % protected_storage
\tlast_enforcement_report = "Day %d federal raid: %d growing plant(s), %dg from the packing bench, %dg exposed storage and $%d cash seized. Reputation -10. Operation locked until Day %d.%s" % [game_day, lost_plants, lost_bench, lost_storage, seized_cash, raid_lockdown_until_day, protected_note]
\tenforcement_report_pending = true
\t_log_heat_event(last_enforcement_report)
\t_push_phone_text("AFB Alert", last_enforcement_report)
\tstatus_label.text = "FEDERAL RAID - Plants, bench stock and exposed storage were seized. Check the report."
\t_update_cash_ui()
\t_save_game()
'''
    text=replace_func(text,"_trigger_raid_event",raid_func)

    # Verification.
    checks=[
        'const HIDDEN_STASH_SUPPLY: String = "Hidden Wall Stash"',
        '"Hidden Wall Stash": {"unlock": 9, "cost": 3250',
        'return 1000',
        'func _build_hidden_wall_stash_visual() -> void:',
        'deg_to_rad(-98.0)',
        '"APPROACH HIDDEN STASH"',
        '"OPEN HIDDEN STASH  |  1000g"',
        'friend_dealer_stats',
        '_record_friend_dealer_sale(sale_dealer_name, qty, gross_revenue, commission)',
        '"friend_dealers": friend_dealer_report',
        'FRIEND DEALERS',
        'lost_plants',
        'lost_bench',
        'protected_storage',
        'Federal raids cannot find stored product',
    ]
    for needle in checks:
        if needle not in text:
            raise SystemExit("cloudtest30 verification failed: "+needle)
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
meta["hidden_wall_stash"]="$3250, 1000g sellable storage, replaces vault, raid-proof, animated frame"
meta["raid_seizure"]="all growing plants, packing-bench product and exposed storage"
meta["friend_dealer_accounting"]="individual sales/gross/commission plus end-of-day summary"
v.write_text(json.dumps(meta,indent=2)+"\n")

print("Built",RELEASE)
print("Added Hidden Wall Stash, raid seizure rework and animated wall frame")
print("Added named friend dealer accounting and end-of-day breakdown")
