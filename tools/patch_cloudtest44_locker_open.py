from pathlib import Path
import struct, hashlib, re, json, collections

PCK=Path("index-cloudtest10.pck")
HTML=Path("index.html")
VERSION=Path("version.json")
BUILD=Path("BUILD_VERSION.txt")
RELEASE="0.7.9-beta.19-cloudtest.44"
PACK_URL="index-cloudtest10.pck?build=44"

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
        if hashlib.md5(data).digest()!=md5: raise SystemExit("md5 mismatch "+name)
        entries.append([name,data,flags])
    return blob,fb,entries

def rebuild(blob,fb,entries):
    out=bytearray(blob[:fb]); cur=0; directory=[]
    for name,data,flags in entries:
        at=align(cur); out.extend(b"\0"*(at-cur)); off=at; out.extend(data); cur=off+len(data)
        directory.append((name,off,len(data),hashlib.md5(data).digest(),flags))
    do=align(len(out)); out.extend(b"\0"*(do-len(out))); struct.pack_into("<Q",out,32,do)
    out.extend(struct.pack("<I",len(directory)))
    for name,off,size,md5,flags in directory:
        raw=name.encode(); plen=(len(raw)+3)//4*4
        out.extend(struct.pack("<I",plen)); out.extend(raw); out.extend(b"\0"*(plen-len(raw)))
        out.extend(struct.pack("<Q",off)); out.extend(struct.pack("<Q",size)); out.extend(md5); out.extend(struct.pack("<I",flags))
    return bytes(out)

def func_pattern(name):
    return re.compile(r"^func "+re.escape(name)+r"\([^\n]*\)(?: -> [^:]+)?:\n.*?(?=^func |\Z)",re.M|re.S)

def replace_func(src,name,new_func):
    pat=func_pattern(name); matches=list(pat.finditer(src))
    if not matches: raise SystemExit("missing "+name)
    at=matches[0].start()
    for m in reversed(matches):
        src=src[:m.start()]+src[m.end():]
    return src[:at]+new_func.rstrip()+"\n\n"+src[at:]

def upsert_before(src,name,new_func,before_name):
    pat=func_pattern(name); matches=list(pat.finditer(src))
    if matches:
        at=matches[0].start()
        for m in reversed(matches):
            src=src[:m.start()]+src[m.end():]
        return src[:at]+new_func.rstrip()+"\n\n"+src[at:]
    marker="func "+before_name+"("
    at=src.find(marker)
    if at<0: raise SystemExit("anchor missing "+before_name)
    return src[:at]+new_func.rstrip()+"\n\n"+src[at:]

blob,fb,entries=parse(PCK)
main_found=False
inv_found=False

for row in entries:
    if row[0]=="scripts/main.gd":
        main_found=True
        text=row[1].decode("utf-8","replace").rstrip(" \n\0")
        approach='''func _approach_station_then_open(action_id: String) -> bool:
\tvar target_view: String = _direct_station_view(action_id)
\tif target_view.is_empty() or not views.has(target_view):
\t\treturn false
\tstatus_label.text = "Approaching..."
\t_go_to_view(target_view, true)
\tif action_id == "station_locker":
\t\t# Do not depend on Tween.finished for the Dealer Locker. Repeated taps or a
\t\t# camera retarget can kill that signal before it fires. The arrival timer
\t\t# guarantees the locker opens once the 0.34s camera move finishes.
\t\tvar locker_arrival_timer: SceneTreeTimer = get_tree().create_timer(0.38)
\t\tlocker_arrival_timer.timeout.connect(_open_dealer_locker_after_approach, CONNECT_ONE_SHOT)
\t\treturn true
\tif camera_view_tween != null:
\t\tcamera_view_tween.finished.connect(_finish_direct_station_approach.bind(action_id), CONNECT_ONE_SHOT)
\telse:
\t\t_finish_direct_station_approach(action_id)
\treturn true
'''
        text=replace_func(text,"_approach_station_then_open",approach)

        helper='''func _open_dealer_locker_after_approach() -> void:
\tif current_view != "locker":
\t\treturn
\tif personal_inventory == null:
\t\tstatus_label.text = "Dealer Locker UI failed to initialize."
\t\treturn
\tpersonal_inventory.open_locker()
\tstatus_label.text = "Dealer Locker opened. Stock dealer inventory here."

'''
        text=upsert_before(text,"_open_dealer_locker_after_approach",helper,"_finish_direct_station_approach")

        finish=func_pattern("_finish_direct_station_approach").search(text)
        if not finish: raise SystemExit("finish approach missing")
        block=finish.group(0)
        block=block.replace('''\t\t"station_locker":
\t\t\tif personal_inventory != null:
\t\t\t\tpersonal_inventory.open_locker()
''','''\t\t"station_locker":
\t\t\t_open_dealer_locker_after_approach()
''')
        text=text[:finish.start()]+block.rstrip()+"\n\n"+text[finish.end():]

        required=[
            'func _open_dealer_locker_after_approach() -> void:',
            'create_timer(0.38)',
            'personal_inventory.open_locker()',
            'const DEALER_COMMISSION_RATE: float = 0.10',
            'func _dealer_locker_add_from_storage',
            'func _roman(value: int) -> String:',
        ]
        for needle in required:
            if needle not in text: raise SystemExit("main verify failed: "+needle)
        names=re.findall(r"^func\s+([A-Za-z0-9_]+)\(",text,re.M)
        dup={k:v for k,v in collections.Counter(names).items() if v>1}
        if dup: raise SystemExit("duplicate main funcs "+repr(dup))
        row[1]=text.encode()
    elif row[0]=="scripts/personal_inventory.gd":
        inv_found=True
        inv=row[1].decode("utf-8","replace").rstrip(" \n\0")
        open_func='''func open_locker() -> void:
\tif locker_panel == null:
\t\tif game != null and game.status_label != null:
\t\t\tgame.status_label.text = "Dealer Locker panel is unavailable."
\t\treturn
\tif backpack_panel != null:
\t\tbackpack_panel.visible = false
\tlocker_panel.visible = true
\tlocker_panel.move_to_front()
\tgame._set_world_controls_visible(false)
\trefresh()
'''
        inv=replace_func(inv,"open_locker",open_func)
        for needle in ["DEALER STORAGE","func open_locker() -> void:","locker_panel.visible = true","locker_panel.move_to_front()"]:
            if needle not in inv: raise SystemExit("inventory verify failed: "+needle)
        row[1]=inv.encode()

if not main_found or not inv_found: raise SystemExit("required scripts missing")
packed=rebuild(blob,fb,entries)
PCK.write_bytes(packed)

_,_,verify=parse(PCK)
sources={name:data.decode("utf-8","replace") for name,data,_ in verify if name in ["scripts/main.gd","scripts/personal_inventory.gd","scripts/touch_scroll.gd"]}
if "create_timer(0.38)" not in sources.get("scripts/main.gd",""): raise SystemExit("arrival timer absent")
if "locker_panel.move_to_front()" not in sources.get("scripts/personal_inventory.gd",""): raise SystemExit("locker front fix absent")
if "const TAP_SLOP: float = 12.0" not in sources.get("scripts/touch_scroll.gd",""): raise SystemExit("mobile tap fix lost")

html=HTML.read_text()
html=re.sub(r'const AFB_TEST_RELEASE = "[^"]+";',f'const AFB_TEST_RELEASE = "{RELEASE}";',html,count=1)
html=re.sub(r'"fileSizes":\{[^}]*\}',f'"fileSizes":{{"{PACK_URL}":{len(packed)},"index.wasm":37902138}}',html,count=1)
html=re.sub(r'"mainPack":"[^"]+"',f'"mainPack":"{PACK_URL}"',html,count=1)
HTML.write_text(html)

meta=json.loads(VERSION.read_text())
meta["release_id"]=RELEASE
meta["dealer_locker_open_fix"]="guaranteed 0.38s arrival timer opens Dealer Storage; panel is raised to front"
VERSION.write_text(json.dumps(meta,indent=2)+"\n")

if BUILD.exists():
    s=BUILD.read_text()
    s=re.sub(r"Web release: .*",f"Web release: {RELEASE}",s)
    if "Web release:" not in s: s+=f"\nWeb release: {RELEASE}\n"
    BUILD.write_text(s)

print("Built",RELEASE)
print("Dealer Locker open path now timer-backed and panel forced to front")
print("PCK bytes",len(packed))
