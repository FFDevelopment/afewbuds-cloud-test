from pathlib import Path
import struct, hashlib, re, json

SOURCE = Path("index-cloudtest10.pck")
TARGET = Path("index-cloudtest10.pck")
PACK_URL = "index-cloudtest10.pck?build=35"
RELEASE = "0.7.9-beta.19-cloudtest.35"
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

    # .34 crop refinement: trim the remaining right-side white mat from the baked source image.
    art_loader = '''func _get_hidden_stash_art_texture() -> Texture2D:
\tif hidden_stash_art_texture != null:
\t\treturn hidden_stash_art_texture
\tvar raw: PackedByteArray = Marshalls.base64_to_raw("ART_B64_TOKEN")
\tvar source: Image = Image.new()
\tif source.load_webp_from_buffer(raw) != OK:
\t\treturn null
\tvar source_w: int = source.get_width()
\tvar source_h: int = source.get_height()
\tif source_w <= 0 or source_h <= 0:
\t\treturn null

\t# Crop to the colorful AFewBuds poster itself. The narrower width removes the lingering
\t# white mat on the right side while preserving the left/top/bottom composition.
\tvar crop_x: int = clampi(int(round(float(source_w) * 0.285)), 0, source_w - 1)
\tvar crop_y: int = clampi(int(round(float(source_h) * 0.135)), 0, source_h - 1)
\tvar crop_w: int = clampi(int(round(float(source_w) * 0.445)), 1, source_w - crop_x)
\tvar crop_h: int = clampi(int(round(float(source_h) * 0.468)), 1, source_h - crop_y)
\tvar cropped: Image = source.get_region(Rect2i(crop_x, crop_y, crop_w, crop_h))
\thidden_stash_art_texture = ImageTexture.create_from_image(cropped)
\treturn hidden_stash_art_texture
'''.replace("ART_B64_TOKEN", STASH_ART_B64)
    text=replace_func(text,"_get_hidden_stash_art_texture",art_loader)


    # cloudtest35 account category. Keep the existing Settings page and add Account.
    parent_func = '''func _phone_parent_app(app_name: String) -> String:
\tif app_name in ["seeds", "supplies"]:
\t\treturn "shop"
\tif app_name in ["bills", "employees", "upgrades"]:
\t\treturn "business"
\tif app_name == "account":
\t\treturn "settings"
\treturn "home"
'''
    text=replace_func(text,"_phone_parent_app",parent_func)

    refresh_pat=re.compile(r"^func _refresh_phone\(\) -> void:\n.*?(?=^func |\\Z)",re.M|re.S)
    refresh_match=refresh_pat.search(text)
    if not refresh_match:
        raise SystemExit("cloudtest35 refresh phone function missing")
    refresh=refresh_match.group(0)
    settings_route_pat=re.compile(r'\t\t"settings":\n\t\t\tphone_title\.text = "Settings"\n\t\t\t_build_settings_app\(\)\n')
    account_route='''\t\t"settings":
\t\t\tphone_title.text = "Settings"
\t\t\t_build_settings_app()
\t\t"account":
\t\t\tphone_title.text = "Account"
\t\t\t_build_account_app()
'''
    refresh, route_count=settings_route_pat.subn(account_route,refresh,count=1)
    if route_count != 1:
        raise SystemExit("cloudtest35 settings route anchor missing")
    text=text[:refresh_match.start()]+refresh.rstrip()+"\n\n"+text[refresh_match.end():]

    settings_func = '''func _build_settings_app() -> void:
\tvar intro: Label = Label.new()
\tintro.text = "Help, account, saves and system controls."
\tintro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
\tphone_list.add_child(intro)
\tvar grid: GridContainer = _phone_category_grid()
\t_add_phone_app_tile(grid, "", "Help", "Basics & controls", "help")
\t_add_phone_app_tile(grid, "", "Account", "Username, password, email & updates", "account")
\t_add_phone_app_tile(grid, "", "System", "Save game & safe quit", "system")
'''
    text=replace_func(text,"_build_settings_app",settings_func)

    account_funcs = '''func _build_account_app() -> void:
\tvar title: Label = Label.new()
\ttitle.text = "AFewBuds Account"
\ttitle.add_theme_font_size_override("font_size", 22)
\tphone_list.add_child(title)
\tvar detail: Label = Label.new()
\tdetail.text = "Change your username to an available name, update your email and update-email preference, or change your password. Your career stays attached to the same account."
\tdetail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
\tdetail.modulate = Color("b8c5ca")
\tphone_list.add_child(detail)
\tvar recovery: Label = Label.new()
\trecovery.text = "IMPORTANT: Add an email to your account so you can recover your password if you forget it."
\trecovery.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
\trecovery.modulate = Color("d8c99e")
\tphone_list.add_child(recovery)
\tvar open_button: Button = Button.new()
\topen_button.text = "OPEN ACCOUNT SETTINGS"
\topen_button.custom_minimum_size.y = 62
\topen_button.add_theme_font_size_override("font_size", 19)
\topen_button.pressed.connect(_open_web_account_settings)
\tphone_list.add_child(open_button)

func _open_web_account_settings() -> void:
\tif not OS.has_feature("web"):
\t\tstatus_label.text = "Account settings are available in the AFewBuds web/cloud build."
\t\treturn
\tJavaScriptBridge.eval("window.AFB_ACCOUNT_SETTINGS && window.AFB_ACCOUNT_SETTINGS.open();", true)

'''
    system_anchor = 'func _build_system_app() -> void:\n'
    if system_anchor not in text:
        raise SystemExit("cloudtest35 system app function anchor missing")
    text=text.replace(system_anchor,account_funcs+system_anchor,1)

    checks=[
        'float(source_w) * 0.285',
        'float(source_w) * 0.445',
        'float(source_h) * 0.468',
        'source.get_region(Rect2i(crop_x, crop_y, crop_w, crop_h))',
        'art_quad.size = Vector2(1.62, 1.26)',
        '"Hidden Wall Stash": {"unlock": 9, "cost": 3250',
        'return 1000',
        'friend_dealer_stats',
        'lost_plants',
        'protected_storage',
        'func _build_settings_app() -> void:',
        '"Account", "Username, password, email & updates", "account"',
        'IMPORTANT: Add an email to your account so you can recover your password if you forget it.',
        'window.AFB_ACCOUNT_SETTINGS && window.AFB_ACCOUNT_SETTINGS.open();',
    ]
    for needle in checks:
        if needle not in text:
            raise SystemExit("cloudtest35 verification failed: "+needle)
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
meta["hidden_stash_visual"]="same stash geometry; tightened right-side texture crop so colorful AFewBuds art fills the inner face evenly"
meta["account_settings"]="Settings > Account: username availability/change, email/update preference, password change; account id and cloud career preserved"
meta["password_recovery_note"]="Account page explains that an email is required for forgotten-password recovery"
v.write_text(json.dumps(meta,indent=2)+"\n")

print("Built",RELEASE)
print("Added Settings > Account and account management browser UI hook")
print("Preserved cloudtest34 hidden stash artwork refinement")
