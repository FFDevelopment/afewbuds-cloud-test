from pathlib import Path
import struct, hashlib, re, json, collections

PCK=Path("index-cloudtest10.pck")
HTML=Path("index.html")
VERSION=Path("version.json")
BUILD=Path("BUILD_VERSION.txt")
RELEASE="0.7.9-beta.19-cloudtest.55"
PACK_URL="index-cloudtest10.pck?build=55"

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

    # ---------- Kitchen redesign ----------
    m=pat("_build_apartment_details").search(text)
    if not m: raise SystemExit("_build_apartment_details missing")
    apt=m.group(0)
    old_kitchen=re.search(
        r'\t_add_box\("KitchenBase".*?\t_add_cylinder\("FaucetStem".*?\n',
        apt,re.S
    )
    if not old_kitchen: raise SystemExit("old kitchen block missing")

    new_kitchen=r'''	# Modern matte-black kitchen/sink run inspired by the approved reference.
	var kitchen_black: Color = Color("17191c")
	var kitchen_panel: Color = Color("202226")
	var kitchen_stone: Color = Color("252b29")
	var kitchen_steel: Color = Color("b9c0c1")
	var kitchen_green: Color = Color("77d996")

	# Lower cabinet carcass and dark stone worktop.
	_add_box("KitchenBase", Vector3(2.18, 0.46, -3.54), Vector3(2.48, 0.84, 0.76), kitchen_black, 0.54, false, "res://assets/textures/matte_plastic.png", Vector3(2.0, 1.0, 1.0))
	_add_box("KitchenToeKick", Vector3(2.18, 0.11, -3.46), Vector3(2.42, 0.16, 0.56), Color("101214"), 0.62, false, "res://assets/textures/matte_plastic.png")
	_add_box("KitchenCounter", Vector3(2.18, 0.94, -3.52), Vector3(2.62, 0.12, 0.88), kitchen_stone, 0.38, false, "res://assets/textures/matte_plastic.png", Vector3(2.2, 1.0, 1.0))
	_add_box("KitchenCounterLip", Vector3(2.18, 0.98, -3.08), Vector3(2.62, 0.07, 0.06), Color("333936"), 0.34)

	# Three lower cabinet faces with recessed brushed-metal pulls.
	var lower_centers: Array[float] = [1.40, 2.18, 2.96]
	for lower_index: int in range(lower_centers.size()):
		var lower_x: float = lower_centers[lower_index]
		_add_box("KitchenLowerDoor%d" % lower_index, Vector3(lower_x, 0.48, -3.135), Vector3(0.72, 0.68, 0.045), kitchen_panel, 0.48, false, "res://assets/textures/matte_plastic.png")
		_add_box("KitchenLowerHandle%d" % lower_index, Vector3(lower_x, 0.77, -3.105), Vector3(0.30, 0.055, 0.035), kitchen_steel, 0.22, false, "res://assets/textures/brushed_metal.png")

	# Full-height dark stone backsplash.
	_add_box("KitchenBacksplash", Vector3(2.18, 1.49, -3.935), Vector3(2.62, 0.98, 0.055), Color("252a29"), 0.42, false, "res://assets/textures/matte_plastic.png", Vector3(2.0, 1.0, 1.0))

	# Matte-black upper cabinet bank with three doors.
	_add_box("KitchenUpper", Vector3(2.18, 2.36, -3.72), Vector3(2.56, 0.94, 0.44), kitchen_black, 0.50, false, "res://assets/textures/matte_plastic.png", Vector3(2.0, 1.0, 1.0))
	var upper_centers: Array[float] = [1.40, 2.18, 2.96]
	for upper_index: int in range(upper_centers.size()):
		var upper_x: float = upper_centers[upper_index]
		_add_box("KitchenUpperDoor%d" % upper_index, Vector3(upper_x, 2.36, -3.485), Vector3(0.72, 0.82, 0.045), kitchen_panel, 0.46, false, "res://assets/textures/matte_plastic.png")
		_add_box("KitchenUpperHandle%d" % upper_index, Vector3(upper_x, 2.02, -3.455), Vector3(0.30, 0.05, 0.035), kitchen_steel, 0.22, false, "res://assets/textures/brushed_metal.png")

	# Subtle green under-cabinet task light.
	_add_box("KitchenUnderCabinetGlow", Vector3(2.18, 1.85, -3.47), Vector3(2.28, 0.025, 0.025), kitchen_green, 0.10, true)

	# Stainless inset sink and black rim.
	_add_box("SinkRim", Vector3(2.18, 0.995, -3.46), Vector3(0.98, 0.045, 0.56), Color("111416"), 0.26)
	_add_box("SinkBasin", Vector3(2.18, 1.005, -3.46), Vector3(0.88, 0.055, 0.46), kitchen_steel, 0.16, false, "res://assets/textures/brushed_metal.png")

	# Tall gooseneck-style faucet built from stainless segments.
	_add_cylinder("FaucetStem", Vector3(2.18, 1.25, -3.79), 0.035, 0.035, 0.48, kitchen_steel, 0.18)
	_add_cylinder("FaucetTop", Vector3(2.18, 1.48, -3.70), 0.035, 0.035, 0.20, kitchen_steel, 0.18, Vector3(PI / 2.0, 0, 0))
	_add_cylinder("FaucetSpout", Vector3(2.18, 1.43, -3.60), 0.032, 0.032, 0.15, kitchen_steel, 0.18)
	_add_cylinder("FaucetControl", Vector3(2.45, 1.15, -3.77), 0.028, 0.028, 0.18, kitchen_steel, 0.20)
'''
    apt=apt[:old_kitchen.start()]+new_kitchen+apt[old_kitchen.end():]
    text=text[:m.start()]+apt.rstrip()+"\n\n"+text[m.end():]

    # ---------- Move packing bench another +0.24 toward the front door ----------
    # Existing .54 code shifts all original bench pieces +0.24 from source coords.
    # Make total source-relative shift +0.48.
    old_shift='(shifted_child as Node3D).position.z += 0.24'
    new_shift='(shifted_child as Node3D).position.z += 0.48'
    if old_shift in text:
        text=text.replace(old_shift,new_shift,1)
    elif new_shift not in text:
        raise SystemExit("packing bench shift anchor missing")

    # Bench III is created later; shift just its newly-created upgrade pieces +0.24.
    m=pat("_build_bagging_bench_level3_visual").search(text)
    if not m: raise SystemExit("Bench III visual missing")
    bench3=m.group(0)
    if "bench3_start_index" not in bench3:
        bench3=bench3.replace(
            "func _build_bagging_bench_level3_visual() -> void:\n\tif get_node_or_null(\"BenchIIIBackBoard\") != null:\n\t\treturn\n",
            "func _build_bagging_bench_level3_visual() -> void:\n\tif get_node_or_null(\"BenchIIIBackBoard\") != null:\n\t\treturn\n\tvar bench3_start_index: int = get_child_count()\n",
            1
        )
        bench3=bench3.rstrip()+"\n\tfor child_index: int in range(bench3_start_index, get_child_count()):\n\t\tvar shifted_child: Node = get_child(child_index)\n\t\tif shifted_child is Node3D:\n\t\t\t(shifted_child as Node3D).position.z += 0.24\n"
    text=text[:m.start()]+bench3.rstrip()+"\n\n"+text[m.end():]

    # Move workbench interaction/camera another +0.24.
    text,n1=re.subn(
        r'(\{"id": "station_workbench", "room": "main", "pos": Vector3\(3\.95, 1\.15, )0\.54(\), "view": "workbench"\})',
        r'\g<1>0.78\2',text,count=1)
    text,n2=re.subn(
        r'("workbench": \{"pos": Vector3\(1\.15, 1\.60, )1\.34(\), "rot": Vector3\(0, -PI / 2\.0, 0\), "label": "Bagging Station"\})',
        r'\g<1>1.58\2',text,count=1)
    if n1!=1 or n2!=1: raise SystemExit("workbench interaction/view move failed")

    # ---------- Move only the shelf setup +0.24 toward the front door ----------
    # Do NOT move StorageVault.ANCHOR or Hidden Wall Stash along Z.
    m=pat("_build_storage_area").search(text)
    if not m: raise SystemExit("_build_storage_area missing")
    storage=m.group(0)
    if "storage_shelf_start_index" not in storage:
        storage=storage.replace(
            "func _build_storage_area() -> void:\n",
            "func _build_storage_area() -> void:\n\tvar storage_shelf_start_index: int = get_child_count()\n",
            1
        )
        storage=storage.rstrip()+"\n\tfor child_index: int in range(storage_shelf_start_index, get_child_count()):\n\t\tvar shifted_child: Node = get_child(child_index)\n\t\tif shifted_child is Node3D:\n\t\t\t(shifted_child as Node3D).position.z += 0.24\n"
    text=text[:m.start()]+storage.rstrip()+"\n\n"+text[m.end():]

    # Later-created Level II/III shelf upgrade props follow the shelf by +0.24.
    replacements={
        'Vector3(-4.14, 2.245, 0.28)':'Vector3(-4.14, 2.245, 0.52)',
        'Vector3(-4.72, 1.28, -2.35)':'Vector3(-4.72, 1.28, -2.11)',
        'Vector3(-4.30, extra_y, -2.35)':'Vector3(-4.30, extra_y, -2.11)',
    }
    for old,new in replacements.items():
        if old in text:
            text=text.replace(old,new,1)
        elif new not in text:
            raise SystemExit("storage upgrade anchor missing "+old)

    # Storage shelf interaction target and close-up move +0.24.
    text,n3=re.subn(
        r'(\{"id": "station_storage", "room": "main", "pos": Vector3\(-4\.35, 1\.35, )-0\.30(\), "view": "storage"\})',
        r'\g<1>-0.06\2',text,count=1)
    text,n4=re.subn(
        r'("storage": \{"pos": Vector3\(-1\.15, 1\.60, )0\.65(\), "rot": Vector3\(-0\.04, atan2\(3\.18, 0\.95\), 0\), "label": "Storage"\})',
        r'\g<1>0.89\2',text,count=1)
    if n3!=1 or n4!=1: raise SystemExit("storage interaction/view move failed")

    # Explicit safety: vault/hidden stash remain at current along-wall Z=-0.30.
    if 'const ANCHOR: Vector3 = Vector3(-4.33, 0.0, -0.30)' in text:
        raise SystemExit("storage_vault.gd unexpectedly embedded in main")
    if 'hidden_stash_interior_root.position = StorageVault.ANCHOR + Vector3(-0.24, 0.0, 0.0)' not in text:
        raise SystemExit("hidden stash wall-fit correction lost")

    required=[
        '"KitchenLowerDoor0"',
        '"KitchenUpperDoor2"',
        '"KitchenUnderCabinetGlow"',
        '"SinkRim"',
        '"FaucetTop"',
        '(shifted_child as Node3D).position.z += 0.48',
        'bench3_start_index',
        '(shifted_child as Node3D).position.z += 0.24',
        '"station_workbench", "room": "main", "pos": Vector3(3.95, 1.15, 0.78)',
        '"station_storage", "room": "main", "pos": Vector3(-4.35, 1.35, -0.06)',
        'hidden_stash_interior_root.position = StorageVault.ANCHOR + Vector3(-0.24, 0.0, 0.0)',
        '"Bagging Bench III"',
        'PremiumLeftDoorPivot',
    ]
    for needle in required:
        if needle not in text: raise SystemExit("verify "+needle)

    names=re.findall(r"^func\s+([A-Za-z0-9_]+)\(",text,re.M)
    dup={k:v for k,v in collections.Counter(names).items() if v>1}
    if dup: raise SystemExit("duplicates "+repr(dup))

    row[1]=text.encode("utf-8")

if not found: raise SystemExit("main missing")

packed=rebuild(blob,fb,entries)
PCK.write_bytes(packed)

_,_,verify=parse(PCK)
sources={name:data.decode("utf-8","replace") for name,data,_ in verify if name in ["scripts/main.gd","scripts/touch_scroll.gd","scripts/storage_vault.gd"]}
main=sources.get("scripts/main.gd","")
vault=sources.get("scripts/storage_vault.gd","")
for needle in [
    '"KitchenUnderCabinetGlow"',
    '"KitchenLowerDoor0"',
    '"station_workbench", "room": "main", "pos": Vector3(3.95, 1.15, 0.78)',
    '"station_storage", "room": "main", "pos": Vector3(-4.35, 1.35, -0.06)',
]:
    if needle not in main: raise SystemExit("packed verify "+needle)
if 'const ANCHOR: Vector3 = Vector3(-4.33, 0.0, -0.30)' not in vault:
    raise SystemExit("vault anchor changed unexpectedly")
if "const TAP_SLOP: float = 12.0" not in sources.get("scripts/touch_scroll.gd",""):
    raise SystemExit("mobile tap fix lost")

html=HTML.read_text()
html=re.sub(r'const AFB_TEST_RELEASE = "[^"]+";',f'const AFB_TEST_RELEASE = "{RELEASE}";',html,count=1)
html=re.sub(r'const AFB_TEST_TITLE = "[^"]+";',f'const AFB_TEST_TITLE = "AFewBuds Cloud Test v{RELEASE}";',html,count=1)
html=re.sub(r'<title>AFewBuds Cloud Test[^<]*</title>',f'<title>AFewBuds Cloud Test {RELEASE}</title>',html,count=1)
html=re.sub(r'"fileSizes":\{[^}]*\}',f'"fileSizes":{{"{PACK_URL}":{len(packed)},"index.wasm":37902138}}',html,count=1)
html=re.sub(r'"mainPack":"[^"]+"',f'"mainPack":"{PACK_URL}"',html,count=1)
HTML.write_text(html)

meta=json.loads(VERSION.read_text())
meta["release_id"]=RELEASE
meta["main_room_forward_shift"]="storage shelf and packing bench moved +0.24 toward front door; vault/hidden stash along-wall position unchanged"
meta["kitchen_visual"]="matte-black lower/upper cabinets, dark stone counter/backplash, stainless inset sink, gooseneck-style faucet, metal pulls, green under-cabinet light"
meta["vault_position_rule"]="vault remains at StorageVault.ANCHOR z=-0.30; hidden stash only retains prior -0.24 X wall-fit correction"
meta["runtime_payload"]="cloudtest55 PCK with forward furniture shift and modern black kitchen"
VERSION.write_text(json.dumps(meta,indent=2)+"\n")

BUILD.write_text(
    "AFewBuds Cloud Test\n"
    "Game build: 0.7.9-beta.19\n"
    f"Web release: {RELEASE}\n"
    "Runtime: shelf + bench forward shift, modern black kitchen; vault along-wall position preserved\n"
)

print("Built",RELEASE,len(packed))
