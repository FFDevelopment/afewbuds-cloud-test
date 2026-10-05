from pathlib import Path
import struct, hashlib, re, json, collections

PCK=Path("index-cloudtest10.pck")
HTML=Path("index.html")
VERSION=Path("version.json")
BUILD=Path("BUILD_VERSION.txt")
RELEASE="0.7.9-beta.19-cloudtest.54"
PACK_URL="index-cloudtest10.pck?build=54"

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

blob,fb,entries=parse(PCK)
found=False
for row in entries:
    if row[0]!="scripts/main.gd":
        continue
    found=True
    text=row[1].decode("utf-8","replace").rstrip(" \n\0")

    # ---------- Packing scale ----------
    m=pat("_build_bagging_station").search(text)
    if not m: raise SystemExit("_build_bagging_station missing")
    bench=m.group(0)

    scale_pattern=re.compile(
        r'\t_add_box\("ScaleBody".*?\t\tadd_child\(label3d\)\n',
        re.S
    )
    sm=scale_pattern.search(bench)
    if not sm: raise SystemExit("current scale block missing")

    new_scale=r'''	# Compact front-facing digital packing scale.
	# Bench faces toward -X, so the control panel/display live on the -X face.
	var scale_center: Vector3 = Vector3(3.86, 1.29, -0.08)
	var scale_black: Color = Color("171a1d")
	var scale_panel: Color = Color("0c0f11")
	var scale_button: Color = Color("34393d")
	var scale_green: Color = Color("a3d8ad")
	var scale_steel: Color = Color("c9cdcb")

	# Four rubber feet keep the body planted on the tabletop.
	for foot_x: float in [3.52, 4.16]:
		for foot_z: float in [-0.42, 0.26]:
			_add_cylinder("ScaleFoot_%s_%s" % [str(foot_x), str(foot_z)], Vector3(foot_x, 1.18, foot_z), 0.035, 0.035, 0.04, Color("111416"), 0.84)

	# Matte black body with a smaller upper deck and centered brushed-steel plate.
	_add_box("ScaleBody", scale_center, Vector3(0.86, 0.18, 0.96), scale_black, 0.46, false, "res://assets/textures/matte_plastic.png")
	_add_box("ScaleBodyUpper", Vector3(3.93, 1.37, -0.08), Vector3(0.70, 0.08, 0.88), Color("202428"), 0.40, false, "res://assets/textures/matte_plastic.png")
	_add_box("ScalePlatform", Vector3(3.96, 1.445, -0.08), Vector3(0.76, 0.055, 0.82), scale_steel, 0.18, false, "res://assets/textures/brushed_metal.png", Vector3(1.3, 1.0, 1.3))

	# Player-facing front control panel. Thin X dimension = vertical face toward room.
	_add_box("ScaleFrontPanel", Vector3(3.418, 1.285, -0.08), Vector3(0.026, 0.145, 0.78), scale_panel, 0.28)
	_add_box("ScaleDisplayFrame", Vector3(3.400, 1.292, -0.08), Vector3(0.012, 0.105, 0.37), Color("080a0b"), 0.16)
	_add_box("ScaleDisplay", Vector3(3.391, 1.292, -0.08), Vector3(0.008, 0.086, 0.33), scale_green, 0.16, true)

	# Two buttons to the left of the display and four to the right, like the reference scale.
	for button_data: Dictionary in [
		{"name":"ScaleButtonL1","y":1.325,"z":-0.365},
		{"name":"ScaleButtonL2","y":1.250,"z":-0.365},
		{"name":"ScaleButtonR1","y":1.325,"z":0.205},
		{"name":"ScaleButtonR2","y":1.325,"z":0.335},
		{"name":"ScaleButtonR3","y":1.250,"z":0.205},
		{"name":"ScaleButtonR4","y":1.250,"z":0.335}
	]:
		_add_box(str(button_data["name"]), Vector3(3.387, float(button_data["y"]), float(button_data["z"])), Vector3(0.014, 0.052, 0.095), scale_button, 0.34)

	var scale_text: Label3D = Label3D.new()
	scale_text.name = "PackingScaleText"
	scale_text.text = "0.00 g"
	scale_text.font_size = 42
	scale_text.modulate = Color("d9f5bb")
	scale_text.position = Vector3(3.378, 1.292, -0.08)
	scale_text.rotation_degrees = Vector3(0, -90, 0)
	scale_text.pixel_size = 0.00175
	add_child(scale_text)
'''
    bench=bench[:sm.start()]+new_scale+bench[sm.end():]
    text=text[:m.start()]+bench.rstrip()+"\n\n"+text[m.end():]

    # ---------- Hidden Wall Stash ----------
    old_anchor='hidden_stash_interior_root.position = StorageVault.ANCHOR'
    new_anchor='hidden_stash_interior_root.position = StorageVault.ANCHOR + Vector3(-0.24, 0.0, 0.0)'
    if old_anchor in text:
        text=text.replace(old_anchor,new_anchor,1)
    elif new_anchor not in text:
        raise SystemExit("hidden stash root anchor missing")

    required=[
        'var scale_center: Vector3 = Vector3(3.86, 1.29, -0.08)',
        '"ScaleBodyUpper"',
        '"ScaleFrontPanel", Vector3(3.418, 1.285, -0.08)',
        '"ScaleDisplay", Vector3(3.391, 1.292, -0.08)',
        'scale_text.rotation_degrees = Vector3(0, -90, 0)',
        '"ScaleButtonL1"',
        '"ScaleButtonR4"',
        'hidden_stash_interior_root.position = StorageVault.ANCHOR + Vector3(-0.24, 0.0, 0.0)',
        '"Bagging Bench III"',
        'PremiumLeftDoorPivot',
        'dealer_storage_reopen_after_pause',
    ]
    for needle in required:
        if needle not in text: raise SystemExit("verify "+needle)

    forbidden=[
        '"ScaleBaseLipFront"',
        '"ScaleBaseLipBack"',
        '"ScaleButtonTare"',
        '"ScaleButtonMode"',
        '"ScaleButtonPcs"',
        '"ScaleButtonPower"',
        'scale_text.rotation_degrees = Vector3(-90, 0, 0)',
    ]
    for needle in forbidden:
        if needle in text: raise SystemExit("old scale artifact remains: "+needle)

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
    '"ScaleFrontPanel", Vector3(3.418, 1.285, -0.08)',
    'scale_text.rotation_degrees = Vector3(0, -90, 0)',
    'hidden_stash_interior_root.position = StorageVault.ANCHOR + Vector3(-0.24, 0.0, 0.0)',
]:
    if needle not in main: raise SystemExit("packed verify "+needle)
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
meta["packing_scale_visual"]="compact matte-black digital scale fully on tabletop with centered brushed-steel platform and player-facing green display/buttons"
meta["packing_scale_orientation"]="front control face moved from Z axis to -X face to match right-wall bench orientation"
meta["hidden_stash_wall_fit"]="Hidden Wall Stash root moved 0.24 units toward left wall to eliminate floating gap"
meta["runtime_payload"]="cloudtest54 PCK with scale rebuild and Hidden Wall Stash wall-fit correction"
VERSION.write_text(json.dumps(meta,indent=2)+"\n")

BUILD.write_text(
    "AFewBuds Cloud Test\n"
    "Game build: 0.7.9-beta.19\n"
    f"Web release: {RELEASE}\n"
    "Runtime: packing scale rebuild + Hidden Wall Stash wall-fit correction\n"
)

print("Built",RELEASE,len(packed))

# finalized cloudtest54 deployment marker
