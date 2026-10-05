from pathlib import Path
import struct, hashlib, re, json, collections

PCK=Path("index-cloudtest10.pck")
HTML=Path("index.html")
VERSION=Path("version.json")
RELEASE="0.7.9-beta.19-cloudtest.48"
PACK_URL="index-cloudtest10.pck?build=48"

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

blob,fb,entries=parse(PCK); found=False
for row in entries:
    if row[0]!="scripts/main.gd": continue
    found=True
    text=row[1].decode("utf-8","replace").rstrip(" \n\0")

    # Runtime references for the premium Level III/IV cabinet.
    if "var premium_dealer_locker_root: Node3D" not in text:
        anchor="var dealer_storage_scroll: PhoneTouchScroll\n"
        if anchor not in text: raise SystemExit("dealer storage variable anchor missing")
        text=text.replace(anchor,anchor+
            "var premium_dealer_locker_root: Node3D\n"
            "var premium_dealer_locker_door_pivot: Node3D\n"
            "var premium_dealer_locker_open: bool = false\n"
            "var premium_dealer_locker_tween: Tween\n",1)

    # Give the Level I/II labels stable names so the visual swap can hide them.
    text=re.sub(
        r'(var locker_logo: Label3D = Label3D\.new\(\)\n)(?!\tlocker_logo\.name)',
        r'\1\tlocker_logo.name = "DealerBasicLogo"\n',
        text,
        count=1
    )
    text=re.sub(
        r'(var locker_tag: Label3D = Label3D\.new\(\)\n)(?!\tlocker_tag\.name)',
        r'\1\tlocker_tag.name = "DealerBasicTag"\n',
        text,
        count=1
    )

    # Build premium cabinet beside the original model, then show only the appropriate tier visual.
    living=pat("_build_living_furniture").search(text)
    if not living: raise SystemExit("_build_living_furniture missing")
    block=living.group(0)
    if "_build_premium_dealer_locker_visual()" not in block:
        block=block.rstrip()+"\n\t_build_premium_dealer_locker_visual()\n\t_sync_dealer_locker_visual()\n"
        text=text[:living.start()]+block.rstrip()+"\n\n"+text[living.end():]

    helpers=r'''func _dealer_premium_box(parent: Node3D, part_name: String, pos: Vector3, size: Vector3, color: Color, roughness: float = 0.45, texture_path: String = "", emissive: bool = false) -> MeshInstance3D:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.name = part_name
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if not texture_path.is_empty():
		var tex: Texture2D = load(texture_path) as Texture2D
		if tex != null:
			material.albedo_texture = tex
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.4
	mesh.material = material
	part.mesh = mesh
	part.position = pos
	parent.add_child(part)
	return part

func _dealer_premium_jar(parent: Node3D, part_name: String, pos: Vector3, radius: float, height: float, bud_color: Color) -> void:
	var jar: MeshInstance3D = MeshInstance3D.new()
	jar.name = part_name
	var jar_mesh: CylinderMesh = CylinderMesh.new()
	jar_mesh.top_radius = radius
	jar_mesh.bottom_radius = radius
	jar_mesh.height = height
	jar_mesh.material = _make_flat_material(Color(bud_color.r * 0.72, bud_color.g * 0.72, bud_color.b * 0.72), 0.28)
	jar.mesh = jar_mesh
	jar.position = pos
	parent.add_child(jar)
	var cap: MeshInstance3D = MeshInstance3D.new()
	var cap_mesh: CylinderMesh = CylinderMesh.new()
	cap_mesh.top_radius = radius * 1.05
	cap_mesh.bottom_radius = radius * 1.05
	cap_mesh.height = 0.035
	cap_mesh.material = _make_flat_material(Color("202428"), 0.24)
	cap.mesh = cap_mesh
	cap.position = pos + Vector3(0, height * 0.52, 0)
	parent.add_child(cap)

func _build_premium_dealer_locker_visual() -> void:
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

	# Matte-black cabinet shell with open-front interior.
	_dealer_premium_box(premium_dealer_locker_root, "PremiumBack", Vector3(0.28, 1.42, 0.0), Vector3(0.12, 2.70, 1.38), interior, 0.34, "res://assets/textures/brushed_metal.png")
	_dealer_premium_box(premium_dealer_locker_root, "PremiumTop", Vector3(-0.02, 2.77, 0.0), Vector3(0.72, 0.12, 1.50), black, 0.32, "res://assets/textures/brushed_metal.png")
	_dealer_premium_box(premium_dealer_locker_root, "PremiumBottom", Vector3(-0.02, 0.08, 0.0), Vector3(0.72, 0.16, 1.50), black, 0.32, "res://assets/textures/brushed_metal.png")
	_dealer_premium_box(premium_dealer_locker_root, "PremiumSideL", Vector3(-0.02, 1.42, -0.72), Vector3(0.72, 2.62, 0.10), black, 0.32, "res://assets/textures/brushed_metal.png")
	_dealer_premium_box(premium_dealer_locker_root, "PremiumSideR", Vector3(-0.02, 1.42, 0.72), Vector3(0.72, 2.62, 0.10), black, 0.32, "res://assets/textures/brushed_metal.png")

	# Shelving and drawers.
	for shelf_y: float in [0.68, 1.13, 1.58, 2.03]:
		_dealer_premium_box(premium_dealer_locker_root, "PremiumShelf", Vector3(-0.10, shelf_y, 0.0), Vector3(0.55, 0.055, 1.20), edge, 0.30, "res://assets/textures/brushed_metal.png")
	_dealer_premium_box(premium_dealer_locker_root, "PremiumDrawer1", Vector3(-0.34, 0.42, 0.0), Vector3(0.08, 0.30, 1.10), Color("202428"), 0.28, "res://assets/textures/brushed_metal.png")
	_dealer_premium_box(premium_dealer_locker_root, "PremiumDrawer2", Vector3(-0.34, 0.15, 0.0), Vector3(0.08, 0.20, 1.10), Color("1b1f22"), 0.28, "res://assets/textures/brushed_metal.png")

	# Green LED strips and interior glow.
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

	# Visible product containers.
	_dealer_premium_jar(premium_dealer_locker_root, "PremiumJarA", Vector3(-0.38, 2.20, -0.38), 0.11, 0.22, Color("718d48"))
	_dealer_premium_jar(premium_dealer_locker_root, "PremiumJarB", Vector3(-0.38, 2.20, 0.00), 0.10, 0.20, Color("87934e"))
	_dealer_premium_jar(premium_dealer_locker_root, "PremiumJarC", Vector3(-0.38, 2.20, 0.34), 0.08, 0.17, Color("667e40"))
	_dealer_premium_jar(premium_dealer_locker_root, "PremiumJarD", Vector3(-0.38, 1.76, -0.30), 0.10, 0.20, Color("8b7d45"))
	_dealer_premium_jar(premium_dealer_locker_root, "PremiumJarE", Vector3(-0.38, 1.76, 0.18), 0.10, 0.20, Color("6d8a4a"))
	_dealer_premium_box(premium_dealer_locker_root, "PremiumPouchA", Vector3(-0.39, 1.34, -0.26), Vector3(0.08, 0.30, 0.28), Color("485f52"), 0.62)
	_dealer_premium_box(premium_dealer_locker_root, "PremiumPouchB", Vector3(-0.39, 1.34, 0.12), Vector3(0.08, 0.25, 0.24), Color("58715d"), 0.62)

	# Opening front door on a right-side hinge.
	premium_dealer_locker_door_pivot = Node3D.new()
	premium_dealer_locker_door_pivot.name = "PremiumDoorPivot"
	premium_dealer_locker_door_pivot.position = Vector3(-0.42, 1.43, 0.73)
	premium_dealer_locker_root.add_child(premium_dealer_locker_door_pivot)
	_dealer_premium_box(premium_dealer_locker_door_pivot, "PremiumDoor", Vector3(-0.02, 0.0, -0.73), Vector3(0.08, 2.55, 1.40), Color("181b1e"), 0.30, "res://assets/textures/brushed_metal.png")
	_dealer_premium_box(premium_dealer_locker_door_pivot, "PremiumDoorLedTop", Vector3(-0.07, 1.16, -0.73), Vector3(0.025, 0.025, 1.23), green, 0.10, "", true)
	_dealer_premium_box(premium_dealer_locker_door_pivot, "PremiumDoorLedBottom", Vector3(-0.07, -1.16, -0.73), Vector3(0.025, 0.025, 1.23), green, 0.10, "", true)
	_dealer_premium_box(premium_dealer_locker_door_pivot, "PremiumDoorLedSide", Vector3(-0.07, 0.0, -0.10), Vector3(0.025, 2.30, 0.025), green, 0.10, "", true)
	_dealer_premium_box(premium_dealer_locker_door_pivot, "PremiumHandle", Vector3(-0.09, 0.0, -0.22), Vector3(0.08, 0.42, 0.09), Color("555d61"), 0.22, "res://assets/textures/brushed_metal.png")
	_dealer_premium_box(premium_dealer_locker_door_pivot, "PremiumKeypad", Vector3(-0.095, -0.08, -0.38), Vector3(0.06, 0.28, 0.16), Color("111416"), 0.22)
	_dealer_premium_box(premium_dealer_locker_door_pivot, "PremiumKeypadRing", Vector3(-0.13, -0.12, -0.38), Vector3(0.018, 0.07, 0.07), green, 0.10, "", true)

	var premium_label: Label3D = Label3D.new()
	premium_label.name = "PremiumDealerStorageLabel"
	premium_label.text = "DEALER\nSTORAGE"
	premium_label.font_size = 28
	premium_label.pixel_size = 0.0028
	premium_label.position = Vector3(-0.10, 0.42, -0.74)
	premium_label.rotation_degrees = Vector3(0, -90, 0)
	premium_label.modulate = Color("7df5a9")
	premium_dealer_locker_door_pivot.add_child(premium_label)

	premium_dealer_locker_root.visible = false
	premium_dealer_locker_open = false

func _sync_dealer_locker_visual() -> void:
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
	if not premium and premium_dealer_locker_door_pivot != null:
		premium_dealer_locker_door_pivot.rotation.y = 0.0
		premium_dealer_locker_open = false

func _set_premium_dealer_locker_open(opened: bool) -> void:
	if premium_dealer_locker_door_pivot == null or dealer_locker_level < 3:
		return
	if premium_dealer_locker_tween != null and premium_dealer_locker_tween.is_running():
		premium_dealer_locker_tween.kill()
	premium_dealer_locker_open = opened
	var target: float = deg_to_rad(-102.0) if opened else 0.0
	premium_dealer_locker_tween = create_tween()
	premium_dealer_locker_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	premium_dealer_locker_tween.tween_property(premium_dealer_locker_door_pivot, "rotation:y", target, 0.32)
'''
    text=upsert_before(text,"_dealer_premium_box",helpers,"_sync_storage_furniture")

    # Level III+ opens the premium door before showing the existing Dealer Storage UI.
    opener=r'''func _open_dealer_locker_after_approach() -> void:
	if current_view != "locker":
		return
	if dealer_storage_panel == null:
		status_label.text = "Dealer Storage panel failed to initialize."
		return
	if dealer_locker_level >= 3:
		_set_premium_dealer_locker_open(true)
		await get_tree().create_timer(0.30).timeout
	_open_dealer_storage_panel()
'''
    text=replace_func(text,"_open_dealer_locker_after_approach",opener)

    close_match=pat("_close_dealer_storage_panel").search(text)
    if not close_match: raise SystemExit("close dealer storage missing")
    close_block=close_match.group(0)
    if "_set_premium_dealer_locker_open(false)" not in close_block:
        close_block=close_block.replace(
            "\tif dealer_storage_scroll != null:\n\t\tdealer_storage_scroll.cancel_touch()\n",
            "\tif dealer_storage_scroll != null:\n\t\tdealer_storage_scroll.cancel_touch()\n\tif dealer_locker_level >= 3:\n\t\t_set_premium_dealer_locker_open(false)\n",
            1
        )
        text=text[:close_match.start()]+close_block.rstrip()+"\n\n"+text[close_match.end():]

    # Buying Level III swaps to the premium model immediately; Level IV retains it.
    buy_match=pat("_buy_dealer_locker_upgrade").search(text)
    if not buy_match: raise SystemExit("_buy_dealer_locker_upgrade missing")
    buy_block=buy_match.group(0)
    if "_sync_dealer_locker_visual()" not in buy_block:
        anchor="\tdealer_locker_level = next_level\n"
        if anchor not in buy_block: raise SystemExit("dealer locker level assignment missing")
        buy_block=buy_block.replace(anchor,anchor+"\t_sync_dealer_locker_visual()\n",1)
        text=text[:buy_match.start()]+buy_block.rstrip()+"\n\n"+text[buy_match.end():]

    required=[
        "var premium_dealer_locker_root: Node3D",
        "func _build_premium_dealer_locker_visual() -> void:",
        "func _sync_dealer_locker_visual() -> void:",
        "func _set_premium_dealer_locker_open(opened: bool) -> void:",
        "dealer_locker_level >= 3",
        'premium_label.text = "DEALER\\nSTORAGE"',
        '"res://assets/textures/brushed_metal.png"',
        "PremiumInteriorGlow",
        "_sync_dealer_locker_visual()",
        "_set_premium_dealer_locker_open(true)",
        "_set_premium_dealer_locker_open(false)",
        "const DEALER_COMMISSION_RATE: float = 0.10",
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
for needle in ["func _build_premium_dealer_locker_visual() -> void:","PremiumDoorPivot","_set_premium_dealer_locker_open(true)"]:
    if needle not in main: raise SystemExit("packed verify "+needle)
if "const TAP_SLOP: float = 12.0" not in sources.get("scripts/touch_scroll.gd",""): raise SystemExit("tap fix lost")

html=HTML.read_text()
html=re.sub(r'const AFB_TEST_RELEASE = "[^"]+";',f'const AFB_TEST_RELEASE = "{RELEASE}";',html,count=1)
html=re.sub(r'"fileSizes":\{[^}]*\}',f'"fileSizes":{{"{PACK_URL}":{len(packed)},"index.wasm":37902138}}',html,count=1)
html=re.sub(r'"mainPack":"[^"]+"',f'"mainPack":"{PACK_URL}"',html,count=1)
HTML.write_text(html)

meta=json.loads(VERSION.read_text())
meta["release_id"]=RELEASE
meta["dealer_storage_visual_progression"]="Levels I-II use original locker; Level III introduces premium matte-black green-lit cabinet; Level IV keeps same cabinet"
meta["dealer_storage_premium_interaction"]="Level III-IV premium door opens before Dealer Storage UI and closes when UI closes"
meta["dealer_storage_level_capacity"]="I 100g, II 200g, III 300g, IV 400g"
VERSION.write_text(json.dumps(meta,indent=2)+"\n")
print("Built",RELEASE,len(packed))
