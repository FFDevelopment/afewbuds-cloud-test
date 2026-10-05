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

blob,fb,entries=parse(PCK)
found=False
for row in entries:
    if row[0]!="scripts/main.gd":
        continue
    found=True
    text=row[1].decode("utf-8","replace").rstrip(" \n\0")

    # 1) Kitchen: slide the complete sink/cabinet run left until it meets the
    # right grow-room door frame at x ~= 1.02 without overlapping the doorway.
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

    # 2) Basic Dealer Storage I/II: move from the front side of the workbench
    # (z +2.68) to the opposite/back side (center z -2.20).
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

    # 3) Premium Level III/IV cabinet follows the same new Dealer Storage spot.
    old_premium='premium_dealer_locker_root.position = Vector3(4.52, 0.0, 2.68)'
    new_premium='premium_dealer_locker_root.position = Vector3(4.52, 0.0, -2.20)'
    if old_premium not in text:
        if new_premium not in text: raise SystemExit("premium locker position anchor missing")
    else:
        text=text.replace(old_premium,new_premium,1)

    # 4) Shift the complete packing/work bench 0.24 along its wall toward the
    # front/right side. Shift every Node3D produced by this builder as a unit,
    # so tools, scale, bins, labels and dynamic bud/bag roots stay aligned.
    m=pat("_build_bagging_station").search(text)
    if not m: raise SystemExit("_build_bagging_station missing")
    bench=m.group(0)
    if "packing_station_start_index" not in bench:
        bench=bench.replace(
            "func _build_bagging_station() -> void:\n",
            "func _build_bagging_station() -> void:\n\tvar packing_station_start_index: int = get_child_count()\n",
            1
        )
        anchor="\t_sync_packing_bench_visuals(true)\n"
        if anchor not in bench: raise SystemExit("packing shift anchor missing")
        bench=bench.replace(anchor,anchor+
            "\tfor child_index: int in range(packing_station_start_index, get_child_count()):\n"
            "\t\tvar shifted_child: Node = get_child(child_index)\n"
            "\t\tif shifted_child is Node3D:\n"
            "\t\t\t(shifted_child as Node3D).position.z += 0.24\n",1)
    text=text[:m.start()]+bench.rstrip()+"\n\n"+text[m.end():]

    # 5) Interaction targets move with the physical furniture.
    direct_old='''\t{"id": "station_workbench", "room": "main", "pos": Vector3(3.95, 1.15, 0.30), "view": "workbench"},
\t{"id": "station_locker", "room": "main", "pos": Vector3(4.13, 1.30, 2.68), "view": "locker"},'''
    direct_new='''\t{"id": "station_workbench", "room": "main", "pos": Vector3(3.95, 1.15, 0.54), "view": "workbench"},
\t{"id": "station_locker", "room": "main", "pos": Vector3(4.13, 1.30, -2.20), "view": "locker"},'''
    if direct_old not in text:
        if direct_new not in text: raise SystemExit("direct station anchors missing")
    else:
        text=text.replace(direct_old,direct_new,1)

    # 6) Close-up cameras track the relocated stations.
    view_old='''\t\t"workbench": {"pos": Vector3(1.15, 1.60, 1.10), "rot": Vector3(0, -PI / 2.0, 0), "label": "Bagging Station"},
\t\t"locker": {"pos": Vector3(1.72, 1.56, 2.58), "rot": Vector3(0, -PI / 2.0, 0), "fov": 68.0, "label": "Personal Locker"},'''
    view_new='''\t\t"workbench": {"pos": Vector3(1.15, 1.60, 1.34), "rot": Vector3(0, -PI / 2.0, 0), "label": "Bagging Station"},
\t\t"locker": {"pos": Vector3(1.72, 1.56, -2.30), "rot": Vector3(0, -PI / 2.0, 0), "fov": 68.0, "label": "Dealer Storage"},'''
    if view_old not in text:
        # .47+ may already call it Dealer Storage while retaining old coordinates.
        alt_old='''\t\t"workbench": {"pos": Vector3(1.15, 1.60, 1.10), "rot": Vector3(0, -PI / 2.0, 0), "label": "Bagging Station"},
\t\t"locker": {"pos": Vector3(1.72, 1.56, 2.58), "rot": Vector3(0, -PI / 2.0, 0), "fov": 68.0, "label": "Dealer Storage"},'''
        if alt_old in text:
            text=text.replace(alt_old,view_new,1)
        elif view_new not in text:
            raise SystemExit("camera view anchors missing")
    else:
        text=text.replace(view_old,view_new,1)

    required=[
        'Vector3(2.16, 0.46, -3.54)',
        'Vector3(1.68, 0.99, -3.54)',
        'Vector3(4.52, 1.28, -2.20)',
        'premium_dealer_locker_root.position = Vector3(4.52, 0.0, -2.20)',
        'packing_station_start_index',
        '(shifted_child as Node3D).position.z += 0.24',
        '"station_workbench", "room": "main", "pos": Vector3(3.95, 1.15, 0.54)',
        '"station_locker", "room": "main", "pos": Vector3(4.13, 1.30, -2.20)',
        '"workbench": {"pos": Vector3(1.15, 1.60, 1.34)',
        '"locker": {"pos": Vector3(1.72, 1.56, -2.30)',
        'PremiumLeftDoorPivot',
        'PremiumRightDoorPivot',
        'dealer_storage_reopen_after_pause',
        'const TAP_SLOP: float = 12.0',
    ]
    # TAP_SLOP lives in touch_scroll.gd, verified after rebuild instead.
    for needle in required[:-1]:
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
    'Vector3(2.16, 0.46, -3.54)',
    'premium_dealer_locker_root.position = Vector3(4.52, 0.0, -2.20)',
    '(shifted_child as Node3D).position.z += 0.24',
    '"station_locker", "room": "main", "pos": Vector3(4.13, 1.30, -2.20)',
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
meta["main_room_layout"]="kitchen moved to grow-door frame; Dealer Storage moved to opposite/back side of packing bench; bench shifted +0.24 along wall"
meta["dealer_storage_layout_position"]="Dealer Storage center moved from z 2.68 to z -2.20 for both basic and premium cabinets"
meta["packing_bench_layout_shift"]="complete packing station shifted +0.24 along wall with interaction/camera alignment preserved"
VERSION.write_text(json.dumps(meta,indent=2)+"\n")

print("Built",RELEASE,len(packed))
