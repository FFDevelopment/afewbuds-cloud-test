from pathlib import Path
import struct, hashlib, re, json, collections

PCK=Path("index-cloudtest10.pck")
HTML=Path("index.html")
VERSION=Path("version.json")
BUILD=Path("BUILD_VERSION.txt")
RELEASE="0.7.9-beta.19-cloudtest.53"
PACK_URL="index-cloudtest10.pck?build=53"

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
    if row[0]!="scripts/main.gd":
        continue
    found=True
    text=row[1].decode("utf-8","replace").rstrip(" \n\0")

    # Premium Dealer Storage: place visual stock relative to shelf top surfaces.
    m=pat("_build_premium_dealer_locker_visual").search(text)
    if not m: raise SystemExit("premium locker visual missing")
    block=m.group(0)
    replacements={
        '_dealer_premium_jar(premium_dealer_locker_root, "PremiumJarA", Vector3(-0.38, 2.20, -0.38), 0.11, 0.22, Color("718d48"))':
        '_dealer_premium_jar(premium_dealer_locker_root, "PremiumJarA", Vector3(-0.18, 2.1675, -0.38), 0.11, 0.22, Color("718d48"))',
        '_dealer_premium_jar(premium_dealer_locker_root, "PremiumJarB", Vector3(-0.38, 2.20, 0.00), 0.10, 0.20, Color("87934e"))':
        '_dealer_premium_jar(premium_dealer_locker_root, "PremiumJarB", Vector3(-0.18, 2.1575, -0.05), 0.10, 0.20, Color("87934e"))',
        '_dealer_premium_jar(premium_dealer_locker_root, "PremiumJarC", Vector3(-0.38, 2.20, 0.34), 0.08, 0.17, Color("667e40"))':
        '_dealer_premium_jar(premium_dealer_locker_root, "PremiumJarC", Vector3(-0.18, 2.1425, 0.28), 0.08, 0.17, Color("667e40"))',
        '_dealer_premium_jar(premium_dealer_locker_root, "PremiumJarD", Vector3(-0.38, 1.76, -0.30), 0.10, 0.20, Color("8b7d45"))':
        '_dealer_premium_jar(premium_dealer_locker_root, "PremiumJarD", Vector3(-0.18, 1.7075, -0.27), 0.10, 0.20, Color("8b7d45"))',
        '_dealer_premium_jar(premium_dealer_locker_root, "PremiumJarE", Vector3(-0.38, 1.76, 0.18), 0.10, 0.20, Color("6d8a4a"))':
        '_dealer_premium_jar(premium_dealer_locker_root, "PremiumJarE", Vector3(-0.18, 1.7075, 0.18), 0.10, 0.20, Color("6d8a4a"))',
        '_dealer_premium_box(premium_dealer_locker_root, "PremiumPouchA", Vector3(-0.39, 1.34, -0.26), Vector3(0.08, 0.30, 0.28), Color("485f52"), 0.62)':
        '_dealer_premium_box(premium_dealer_locker_root, "PremiumPouchA", Vector3(-0.20, 1.3075, -0.22), Vector3(0.08, 0.30, 0.28), Color("485f52"), 0.62)',
        '_dealer_premium_box(premium_dealer_locker_root, "PremiumPouchB", Vector3(-0.39, 1.34, 0.12), Vector3(0.08, 0.25, 0.24), Color("58715d"), 0.62)':
        '_dealer_premium_box(premium_dealer_locker_root, "PremiumPouchB", Vector3(-0.20, 1.2825, 0.15), Vector3(0.08, 0.25, 0.24), Color("58715d"), 0.62)',
    }
    for old,new in replacements.items():
        if old in block:
            block=block.replace(old,new,1)
        elif new not in block:
            raise SystemExit("locker content anchor missing: "+old[:60])

    if "# Shelf-relative stock placement" not in block:
        marker='\t_dealer_premium_jar(premium_dealer_locker_root, "PremiumJarA"'
        idx=block.find(marker)
        if idx<0: raise SystemExit("jar marker missing")
        block=block[:idx]+"\t# Shelf-relative stock placement: x stays safely behind the front face; y sits on each shelf top.\n"+block[idx:]

    text=text[:m.start()]+block.rstrip()+"\n\n"+text[m.end():]

    # Bagging Bench III replaces old lower-frame visuals instead of overlaying them.
    helper=r'''func _sync_bagging_bench_level3_visibility() -> void:
	var upgraded: bool = bagging_level >= 3
	var legacy_lower_parts: Array[String] = [
		"BenchFrontApron",
		"BenchBackApron",
		"BenchLeg_0_0",
		"BenchLeg_0_1",
		"BenchLeg_1_0",
		"BenchLeg_1_1",
		"BenchLowerShelf",
		"BenchGreenBin",
		"BenchGreenBinLid",
		"BenchClearBin",
		"BenchClearBinLid",
		"BenchBaggieStackUnder",
		"BenchSupplyBox"
	]
	for node_name: String in legacy_lower_parts:
		var legacy_node: Node3D = get_node_or_null(node_name) as Node3D
		if legacy_node != null:
			legacy_node.visible = not upgraded

	var bench3_names: Array[String] = [
		"BenchIIIBackBoard",
		"BenchIIIUpperCabinet",
		"BenchIIIUpperLip",
		"BenchIIITaskLight",
		"BenchIIILowerCabinetL",
		"BenchIIILowerCabinetR",
		"BenchIIIToolRail",
		"BenchIIISmallShelf",
		"BenchIIIWorldLabel"
	]
	for node_name: String in bench3_names:
		var upgraded_node: Node3D = get_node_or_null(node_name) as Node3D
		if upgraded_node != null:
			upgraded_node.visible = upgraded
	for child: Node in get_children():
		var child_name: String = str(child.name)
		if child_name.begins_with("BenchIIIDrawer") or child_name.begins_with("BenchIIITool_"):
			if child is Node3D:
				(child as Node3D).visible = upgraded
'''
    text=upsert_before(text,"_sync_bagging_bench_level3_visibility",helper,"_apply_visual_upgrades")

    m=pat("_apply_visual_upgrades").search(text)
    if not m: raise SystemExit("_apply_visual_upgrades missing")
    apply=m.group(0)
    if "_sync_bagging_bench_level3_visibility()" not in apply:
        anchor='\tif bagging_level >= 3:\n\t\t_build_bagging_bench_level3_visual()\n\t\t_set_mesh_color("BenchTop", Color("332c28"))\n'
        if anchor not in apply: raise SystemExit("bench III apply anchor missing")
        apply=apply.replace(anchor,anchor+'\t_sync_bagging_bench_level3_visibility()\n',1)
    text=text[:m.start()]+apply.rstrip()+"\n\n"+text[m.end():]

    required=[
        'PremiumJarA", Vector3(-0.18, 2.1675, -0.38)',
        'PremiumJarD", Vector3(-0.18, 1.7075, -0.27)',
        'PremiumPouchA", Vector3(-0.20, 1.3075, -0.22)',
        'func _sync_bagging_bench_level3_visibility() -> void:',
        '"BenchLowerShelf"',
        'legacy_node.visible = not upgraded',
        '_sync_bagging_bench_level3_visibility()',
        '"Bagging Bench III"',
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

packed=rebuild(blob,fb,entries)
PCK.write_bytes(packed)

_,_,verify=parse(PCK)
sources={name:data.decode("utf-8","replace") for name,data,_ in verify if name in ["scripts/main.gd","scripts/touch_scroll.gd"]}
main=sources.get("scripts/main.gd","")
for needle in [
    'PremiumJarA", Vector3(-0.18, 2.1675, -0.38)',
    'func _sync_bagging_bench_level3_visibility() -> void:',
    '_sync_bagging_bench_level3_visibility()',
    '"Bagging Bench III"',
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
meta["dealer_storage_shelf_alignment"]="premium jars/pouches moved deeper into cabinet and seated on shelf-relative top surfaces"
meta["bagging_bench_iii_replacement"]="Level III now hides legacy lower frame/legs/shelf/bins so the industrial workstation replaces rather than overlays the old bench"
VERSION.write_text(json.dumps(meta,indent=2)+"\n")

BUILD.write_text(
    "AFewBuds Cloud Test\n"
    "Game build: 0.7.9-beta.19\n"
    f"Web release: {RELEASE}\n"
    "Runtime: premium Dealer Storage shelf alignment + true Bagging Bench III visual replacement\n"
)

print("Built",RELEASE,len(packed))

# finalized cloudtest53 deployment marker
