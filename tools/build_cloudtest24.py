from pathlib import Path
import struct, hashlib, re, json, collections

PCK=Path("index-cloudtest10.pck")
HTML=Path("index.html")
VERSION=Path("version.json")
RELEASE="0.7.9-beta.19-cloudtest.46"
PACK_URL="index-cloudtest10.pck?build=46"

def align(n,a=32):
    return (n+a-1)//a*a

def parse(path):
    blob=path.read_bytes()
    if blob[:4]!=b"GDPC":
        raise SystemExit("not PCK")
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

def replace_func(src,name,new_func):
    matches=list(pat(name).finditer(src))
    if not matches:
        raise SystemExit("missing function "+name)
    at=matches[0].start()
    for m in reversed(matches):
        src=src[:m.start()]+src[m.end():]
    return src[:at]+new_func.rstrip()+"\n\n"+src[at:]

blob,fb,entries=parse(PCK)
found=False
for row in entries:
    if row[0]!="scripts/main.gd":
        continue
    found=True
    text=row[1].decode("utf-8","replace").rstrip(" \n\0")

    # Guarantee Dealer Storage is actually instantiated during UI construction.
    m=pat("_build_ui").search(text)
    if not m:
        raise SystemExit("_build_ui missing")
    block=m.group(0)
    if "_build_dealer_storage_panel()" not in block:
        if "\t_build_storage_panel()\n" not in block:
            raise SystemExit("storage build anchor missing")
        block=block.replace("\t_build_storage_panel()\n","\t_build_storage_panel()\n\t_build_dealer_storage_panel()\n",1)
        text=text[:m.start()]+block.rstrip()+"\n\n"+text[m.end():]

    # Guarantee the physical locker always opens the native Dealer Storage panel.
    approach='''func _approach_station_then_open(action_id: String) -> bool:
\tvar target_view: String = _direct_station_view(action_id)
\tif target_view.is_empty() or not views.has(target_view):
\t\treturn false
\tstatus_label.text = "Approaching..."
\t_go_to_view(target_view, true)
\tif action_id == "station_locker":
\t\tvar locker_timer: SceneTreeTimer = get_tree().create_timer(0.40)
\t\tlocker_timer.timeout.connect(_open_dealer_locker_after_approach, CONNECT_ONE_SHOT)
\t\treturn true
\tif camera_view_tween != null:
\t\tcamera_view_tween.finished.connect(_finish_direct_station_approach.bind(action_id), CONNECT_ONE_SHOT)
\telse:
\t\t_finish_direct_station_approach(action_id)
\treturn true
'''
    text=replace_func(text,"_approach_station_then_open",approach)

    opener='''func _open_dealer_locker_after_approach() -> void:
\tif current_view != "locker":
\t\treturn
\tif dealer_storage_panel == null:
\t\tstatus_label.text = "Dealer Storage panel failed to initialize."
\t\treturn
\t_open_dealer_storage_panel()
'''
    text=replace_func(text,"_open_dealer_locker_after_approach",opener)

    # Upgrade list: only show the next tier in each progression chain.
    m=pat("_build_upgrades_app").search(text)
    if not m:
        raise SystemExit("_build_upgrades_app missing")
    up=m.group(0)
    loop_anchor='''\tfor supply_variant in supply_catalog.keys():
\t\tvar supply_name: String = str(supply_variant)
\t\tif supply_name == "Fertilizer Pack":
\t\t\tcontinue
'''
    if loop_anchor not in up:
        raise SystemExit("upgrade loop anchor missing")
    gated='''\tfor supply_variant in supply_catalog.keys():
\t\tvar supply_name: String = str(supply_variant)
\t\tif supply_name == "Fertilizer Pack":
\t\t\tcontinue

\t\t# Sequential upgrade chains: only the next tier is visible.
\t\tif supply_name == "Grow Supply Shelf II" and supply_shelf_level != 1:
\t\t\tcontinue
\t\tif supply_name == "Grow Supply Shelf III" and supply_shelf_level != 2:
\t\t\tcontinue

\t\tif supply_name == "Storage Shelving II" and storage_level != 1:
\t\t\tcontinue
\t\tif supply_name == "Storage Shelving III" and storage_level != 2:
\t\t\tcontinue
\t\tif supply_name == VAULT_SUPPLY and storage_level != 3:
\t\t\tcontinue
\t\tif supply_name == HIDDEN_STASH_SUPPLY and storage_level != 4:
\t\t\tcontinue

\t\tif supply_name == "Grow Tent Slot 2" and grow_tent_count != 1:
\t\t\tcontinue
\t\tif supply_name == "Grow Tent Slot 3" and grow_tent_count != 2:
\t\t\tcontinue
'''
    up=up.replace(loop_anchor,gated,1)
    text=text[:m.start()]+up.rstrip()+"\n\n"+text[m.end():]

    # Verification.
    required=[
        "func _build_dealer_storage_panel() -> void:",
        "_build_dealer_storage_panel()",
        "func _open_dealer_storage_panel() -> void:",
        "func _refresh_dealer_storage_panel() -> void:",
        "create_timer(0.40)",
        'supply_name == "Grow Supply Shelf II" and supply_shelf_level != 1',
        'supply_name == "Grow Supply Shelf III" and supply_shelf_level != 2',
        'supply_name == "Storage Shelving II" and storage_level != 1',
        'supply_name == "Storage Shelving III" and storage_level != 2',
        'supply_name == VAULT_SUPPLY and storage_level != 3',
        'supply_name == HIDDEN_STASH_SUPPLY and storage_level != 4',
        'supply_name == "Grow Tent Slot 2" and grow_tent_count != 1',
        'supply_name == "Grow Tent Slot 3" and grow_tent_count != 2',
        "const DEALER_COMMISSION_RATE: float = 0.10",
    ]
    for needle in required:
        if needle not in text:
            raise SystemExit("verification failed: "+needle)

    names=re.findall(r"^func\s+([A-Za-z0-9_]+)\(",text,re.M)
    dup={k:v for k,v in collections.Counter(names).items() if v>1}
    if dup:
        raise SystemExit("duplicate functions "+repr(dup))

    row[1]=text.encode("utf-8")

if not found:
    raise SystemExit("scripts/main.gd missing")

packed=rebuild(blob,fb,entries)
PCK.write_bytes(packed)

# Re-parse and verify mobile tap behavior is still present.
_,_,verify=parse(PCK)
sources={name:data.decode("utf-8","replace") for name,data,_ in verify if name in ["scripts/main.gd","scripts/touch_scroll.gd"]}
if "const TAP_SLOP: float = 12.0" not in sources.get("scripts/touch_scroll.gd",""):
    raise SystemExit("mobile tap fix lost")
if "_build_dealer_storage_panel()" not in pat("_build_ui").search(sources["scripts/main.gd"]).group(0):
    raise SystemExit("Dealer Storage panel not instantiated")

html=HTML.read_text()
html=re.sub(r'const AFB_TEST_RELEASE = "[^"]+";',f'const AFB_TEST_RELEASE = "{RELEASE}";',html,count=1)
html=re.sub(r'"fileSizes":\{[^}]*\}',f'"fileSizes":{{"{PACK_URL}":{len(packed)},"index.wasm":37902138}}',html,count=1)
html=re.sub(r'"mainPack":"[^"]+"',f'"mainPack":"{PACK_URL}"',html,count=1)
HTML.write_text(html)

meta=json.loads(VERSION.read_text())
meta["release_id"]=RELEASE
meta["dealer_storage_open"]="native panel guaranteed to build and opens after locker approach"
meta["upgrade_progression"]="Storage, Grow Supply Shelf, Grow Tent Slots and Dealer Locker progress one tier at a time"
meta["storage_upgrade_chain"]="Storage I -> Shelving II -> Shelving III -> AFB Vault -> Hidden Wall Stash"
meta["grow_shelf_upgrade_chain"]="Grow Supply Shelf I -> II -> III"
meta["grow_tent_slot_chain"]="Tent Slot 1 -> Slot 2 -> Slot 3"
VERSION.write_text(json.dumps(meta,indent=2)+"\n")

print("Built",RELEASE,"PCK bytes",len(packed))
