from pathlib import Path
import struct, hashlib, re, json, collections

SOURCE = Path("index-cloudtest10.pck")
TARGET = Path("index-cloudtest10.pck")
PACK_URL = "index-cloudtest10.pck?build=40"
RELEASE = "0.7.9-beta.19-cloudtest.40"

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

def func_pattern(name):
    return re.compile(r"^func "+re.escape(name)+r"\([^\n]*\)(?: -> [^:]+)?:\n.*?(?=^func |\Z)",re.M|re.S)

def replace_func(src,name,new_func):
    pat=func_pattern(name)
    matches=list(pat.finditer(src))
    if not matches:
        raise SystemExit("Function missing: "+name)
    insert_at=matches[0].start()
    for m in reversed(matches):
        src=src[:m.start()]+src[m.end():]
    return src[:insert_at]+new_func.rstrip()+"\n\n"+src[insert_at:]

def upsert_before(src,name,new_func,before_name):
    pat=func_pattern(name)
    matches=list(pat.finditer(src))
    if matches:
        insert_at=matches[0].start()
        for m in reversed(matches):
            src=src[:m.start()]+src[m.end():]
        return src[:insert_at]+new_func.rstrip()+"\n\n"+src[insert_at:]
    marker="func "+before_name+"("
    insert_at=src.find(marker)
    if insert_at < 0:
        raise SystemExit("Insert anchor missing: "+before_name)
    return src[:insert_at]+new_func.rstrip()+"\n\n"+src[insert_at:]

blob,fb,entries=parse(SOURCE)
main_found=False

for row in entries:
    if row[0]!="scripts/main.gd":
        continue
    main_found=True
    text=row[1].decode("utf-8","replace").rstrip(" \n\0")

    home_func='''func _build_phone_home() -> void:
\tvar summary: Label = Label.new()
\tsummary.text = "DAY %d  |  %s\\n$%d cash   |   Level %d   |   Storefront %s" % [game_day, _format_game_clock(), cash, grower_level, "OPEN" if business_open else "AWAY"]
\tsummary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
\tsummary.add_theme_font_size_override("font_size", 21)
\tphone_list.add_child(summary)
\tvar grid: GridContainer = _phone_category_grid()
\t_add_phone_app_tile(grid, "", "BudShop", "Store, business & operations", "budshop")
\t_add_phone_app_tile(grid, "", "Texts", ("%d unread" % phone_text_unread) if phone_text_unread > 0 else "Crew & story messages", "texts")
\t_add_phone_app_tile(grid, "", "Task", "Chapter progress & rewards", "task")
\t_add_phone_app_tile(grid, "", "Leaderboard", "Weekly & lifetime rankings", "leaderboard")
\t_add_phone_app_tile(grid, "", "Settings", "Help & system controls", "settings")
'''
    text=replace_func(text,"_build_phone_home",home_func)

    refresh_match=func_pattern("_refresh_phone").search(text)
    if not refresh_match:
        raise SystemExit("_refresh_phone missing")
    refresh=refresh_match.group(0)
    leaderboard_arm=re.compile(r'\t\t"leaderboard":\n\t\t\tphone_title\.text = "Leaderboard"\n\t\t\t_build_leaderboard_app\(\)\n')
    refresh=leaderboard_arm.sub('',refresh)
    settings_arm='''\t\t"settings":
\t\t\tphone_title.text = "Settings"
\t\t\t_build_settings_app()
'''
    leaderboard_settings='''\t\t"leaderboard":
\t\t\tphone_title.text = "Leaderboard"
\t\t\t_build_leaderboard_app()
\t\t"settings":
\t\t\tphone_title.text = "Settings"
\t\t\t_build_settings_app()
'''
    if settings_arm not in refresh:
        raise SystemExit("Settings route anchor missing")
    refresh=refresh.replace(settings_arm,leaderboard_settings,1)
    text=text[:refresh_match.start()]+refresh.rstrip()+"\n\n"+text[refresh_match.end():]

    open_match=func_pattern("_open_phone_app").search(text)
    if not open_match:
        raise SystemExit("_open_phone_app missing")
    open_func=open_match.group(0)
    open_func=re.sub(r'\n\tif app_name == "leaderboard":\n\t\tcall_deferred\("_open_web_leaderboard"\)','',open_func)
    refresh_call='\t_refresh_phone()\n'
    if refresh_call not in open_func:
        raise SystemExit("_open_phone_app refresh anchor missing")
    open_func=open_func.replace(refresh_call,refresh_call+'\tif app_name == "leaderboard":\n\t\tcall_deferred("_open_web_leaderboard")\n',1)
    text=text[:open_match.start()]+open_func.rstrip()+"\n\n"+text[open_match.end():]

    leaderboard_page='''func _build_leaderboard_app() -> void:
\tvar intro: Label = Label.new()
\tintro.text = "GLOBAL LEADERBOARD"
\tintro.add_theme_font_size_override("font_size", 22)
\tphone_list.add_child(intro)
\tvar detail: Label = Label.new()
\tdetail.text = "Compare AFewBuds players by Lifetime or Weekly stats. Rankings are shown highest to lowest. Tap a player in the leaderboard to view their public career stats."
\tdetail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
\tdetail.modulate = Color("b8c5ca")
\tphone_list.add_child(detail)
\tvar open_button: Button = Button.new()
\topen_button.text = "OPEN LEADERBOARD"
\topen_button.custom_minimum_size.y = 62
\topen_button.add_theme_font_size_override("font_size", 19)
\topen_button.pressed.connect(_open_web_leaderboard)
\tphone_list.add_child(open_button)
'''
    leaderboard_bridge='''func _open_web_leaderboard() -> void:
\tif not OS.has_feature("web"):
\t\tstatus_label.text = "Global leaderboard is available in the AFewBuds web/cloud build."
\t\treturn
\tJavaScriptBridge.eval("window.AFB_LEADERBOARD && window.AFB_LEADERBOARD.open();", true)
'''
    text=upsert_before(text,"_build_leaderboard_app",leaderboard_page,"_restore_phone_scroll")
    text=upsert_before(text,"_open_web_leaderboard",leaderboard_bridge,"_restore_phone_scroll")

    names=re.findall(r"^func\s+([A-Za-z0-9_]+)\(",text,re.M)
    dup={k:v for k,v in collections.Counter(names).items() if v>1}
    if dup:
        raise SystemExit("Duplicate GDScript functions: "+repr(dup))
    if text.count('"Leaderboard", "Weekly & lifetime rankings", "leaderboard"') != 1:
        raise SystemExit("Leaderboard Home tile count invalid")
    refresh_check=func_pattern("_refresh_phone").search(text)
    if not refresh_check or refresh_check.group(0).count('\t\t"leaderboard":\n') != 1:
        raise SystemExit("Leaderboard route count invalid")
    for name in ["_build_leaderboard_app","_open_web_leaderboard"]:
        if len(list(func_pattern(name).finditer(text))) != 1:
            raise SystemExit(name+" must exist exactly once")

    row[1]=text.encode()

if not main_found:
    raise SystemExit("scripts/main.gd missing")

packed=rebuild(blob,fb,entries)
TARGET.write_bytes(packed)

idx=Path("index.html")
html=idx.read_text()
if 'id="afb-leaderboard-modal"' not in html or 'window.AFB_LEADERBOARD' not in html:
    raise SystemExit("Browser leaderboard shell missing")
html=re.sub(r'const AFB_TEST_RELEASE = "[^"]+";',f'const AFB_TEST_RELEASE = "{RELEASE}";',html,count=1)
html=re.sub(r'"fileSizes":\{[^}]*\}',f'"fileSizes":{{"{PACK_URL}":{len(packed)},"index.wasm":37902138}}',html,count=1)
html=re.sub(r'"mainPack":"[^"]+"',f'"mainPack":"{PACK_URL}"',html,count=1)
idx.write_text(html)

v=Path("version.json")
meta=json.loads(v.read_text())
meta["release_id"]=RELEASE
meta["phone_home"]="BudShop, Texts, Task, Leaderboard, Settings"
meta["leaderboard"]="Phone Home > Leaderboard; browser-rendered Lifetime/Weekly Top 5/Top 25 with public career profiles"
meta["leaderboard_metrics"]="revenue, sales, dealer sales, harvests, hybrids, raids survived, days played, career score"
meta["leaderboard_runtime"]="minimal Godot bridge only; ranking/UI/Supabase logic remains in web layer"
meta["leaderboard_baseline"]="built directly from known-good cloudtest39/cloudtest36 PCK"
v.write_text(json.dumps(meta,indent=2)+"\n")

print("Built",RELEASE)
print("Minimal phone Leaderboard bridge applied")
print("PCK bytes",len(packed))
