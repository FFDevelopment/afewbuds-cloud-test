from pathlib import Path
import struct, hashlib, re, json, collections

PCK=Path("index-cloudtest10.pck")
HTML=Path("index.html")
VERSION=Path("version.json")
RELEASE="0.7.9-beta.19-cloudtest.45"
PACK_URL="index-cloudtest10.pck?build=45"
REMOVE={"scripts/personal_inventory.gd","scripts/inventory_slot.gd"}

def al(n,a=32): return (n+a-1)//a*a
def parse(path):
    b=path.read_bytes(); fb=struct.unpack_from("<Q",b,24)[0]; do=struct.unpack_from("<Q",b,32)[0]
    n=struct.unpack_from("<I",b,do)[0]; p=do+4; out=[]
    for _ in range(n):
        q=struct.unpack_from("<I",b,p)[0]; p+=4
        name=b[p:p+q].rstrip(b"\0").decode(); p+=q
        off=struct.unpack_from("<Q",b,p)[0]; p+=8
        size=struct.unpack_from("<Q",b,p)[0]; p+=8
        md5=b[p:p+16]; p+=16; flags=struct.unpack_from("<I",b,p)[0]; p+=4
        data=b[fb+off:fb+off+size]
        if hashlib.md5(data).digest()!=md5: raise SystemExit("md5 "+name)
        out.append([name,data,flags])
    return b,fb,out
def rebuild(b,fb,entries):
    out=bytearray(b[:fb]); cur=0; rows=[]
    for name,data,flags in entries:
        at=al(cur); out.extend(b"\0"*(at-cur)); off=at; out.extend(data); cur=off+len(data)
        rows.append((name,off,len(data),hashlib.md5(data).digest(),flags))
    do=al(len(out)); out.extend(b"\0"*(do-len(out))); struct.pack_into("<Q",out,32,do); out.extend(struct.pack("<I",len(rows)))
    for name,off,size,md5,flags in rows:
        raw=name.encode(); q=(len(raw)+3)//4*4
        out.extend(struct.pack("<I",q)); out.extend(raw); out.extend(b"\0"*(q-len(raw)))
        out.extend(struct.pack("<Q",off)); out.extend(struct.pack("<Q",size)); out.extend(md5); out.extend(struct.pack("<I",flags))
    return bytes(out)
def pat(name): return re.compile(r"^func "+re.escape(name)+r"\([^\n]*\)(?: -> [^:]+)?:\n.*?(?=^func |\Z)",re.M|re.S)
def rep(src,name,new):
    ms=list(pat(name).finditer(src))
    if not ms: raise SystemExit("missing "+name)
    at=ms[0].start()
    for m in reversed(ms): src=src[:m.start()]+src[m.end():]
    return src[:at]+new.rstrip()+"\n\n"+src[at:]
def rm(src,name):
    for m in reversed(list(pat(name).finditer(src))): src=src[:m.start()]+src[m.end():]
    return src
def up(src,name,new,before):
    ms=list(pat(name).finditer(src))
    if ms:
        at=ms[0].start()
        for m in reversed(ms): src=src[:m.start()]+src[m.end():]
        return src[:at]+new.rstrip()+"\n\n"+src[at:]
    at=src.find("func "+before+"(")
    if at<0: raise SystemExit("anchor "+before)
    return src[:at]+new.rstrip()+"\n\n"+src[at:]

b,fb,entries=parse(PCK); final=[]; found=False
for row in entries:
    if row[0] in REMOVE: continue
    if row[0]=="scripts/main.gd":
        found=True; t=row[1].decode("utf-8","replace").rstrip(" \n\0")
        for old in [
            'const PersonalInventory = preload("res://scripts/personal_inventory.gd")\n',
            'var personal_inventory: Node\n','var personal_weed: Dictionary = {}\n',
            'var locker_cash: int = 0\n','var backpack_quick_button: Button\n']:
            t=t.replace(old,"",1)
        t=rm(t,"_init_personal_inventory_deferred"); t=rm(t,"_open_backpack_direct")
        anchor="var storage_refresh_revision: int = 0\n"
        if "var dealer_storage_panel: PanelContainer" not in t:
            t=t.replace(anchor,anchor+"var dealer_storage_panel: PanelContainer\nvar dealer_storage_list: VBoxContainer\nvar dealer_storage_scroll: PhoneTouchScroll\n",1)
        t=t.replace("\t_build_storage_panel()\n\t_build_supply_inventory_panel()\n","\t_build_storage_panel()\n\t_build_dealer_storage_panel()\n\t_build_supply_inventory_panel()\n",1)

        build='''func _build_dealer_storage_panel() -> void:
\tdealer_storage_panel = _make_full_panel(34, 132, -34, -72)
\tvar root: VBoxContainer = _panel_root(dealer_storage_panel, "DEALER STORAGE", _close_dealer_storage_panel)
\tvar help: Label = Label.new()
\thelp.text = "Dealers sell only product stored here. You stock it manually from normal storage. Production can overflow here only when normal storage is completely full."
\thelp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
\troot.add_child(help)
\tdealer_storage_scroll = PhoneTouchScroll.new()
\tdealer_storage_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
\troot.add_child(dealer_storage_scroll)
\tdealer_storage_list = VBoxContainer.new()
\tdealer_storage_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\tdealer_storage_list.add_theme_constant_override("separation", 10)
\tdealer_storage_scroll.add_child(dealer_storage_list)
\tvar leave: Button = Button.new()
\tleave.text = "CLOSE DEALER STORAGE"
\tleave.custom_minimum_size = Vector2(0, 58)
\tleave.pressed.connect(_close_dealer_storage_panel)
\troot.add_child(leave)
'''
        t=up(t,"_build_dealer_storage_panel",build,"_build_supply_inventory_panel")

        runtime='''func _open_dealer_storage_panel() -> void:
\tif dealer_storage_panel == null:
\t\tstatus_label.text = "Dealer Storage panel failed to initialize."
\t\treturn
\tdealer_storage_panel.visible = true
\tdealer_storage_panel.move_to_front()
\t_set_world_controls_visible(false)
\t_refresh_dealer_storage_panel()
\tstatus_label.text = "Dealer Storage opened."

func _close_dealer_storage_panel() -> void:
\tif dealer_storage_scroll != null:
\t\tdealer_storage_scroll.cancel_touch()
\tdealer_storage_panel.visible = false
\t_go_to_view("main_workbench")
\t_set_world_controls_visible(true)

func _dealer_storage_transfer(strain: String, amount: int, moving_in: bool) -> void:
\tif moving_in:
\t\t_dealer_locker_add_from_storage(strain, amount)
\telse:
\t\t_dealer_locker_remove_to_storage(strain, amount)
\t_refresh_dealer_storage_panel()

func _dealer_storage_row(parent: VBoxContainer, strain: String, amount: int, moving_in: bool) -> void:
\tvar parts: Dictionary = _make_inventory_card("bag")
\tvar card: PanelContainer = parts["card"] as PanelContainer
\tvar content: VBoxContainer = parts["content"] as VBoxContainer
\tparent.add_child(card)
\tvar title: Label = Label.new()
\ttitle.text = "%s   |   %dg" % [strain, amount]
\ttitle.add_theme_font_size_override("font_size", 20)
\tcontent.add_child(title)
\tvar row: HBoxContainer = HBoxContainer.new()
\tcontent.add_child(row)
\tfor qty: int in [5, 10, 25]:
\t\tvar b: Button = Button.new()
\t\tb.text = ("%s%dg" % ["+" if moving_in else "-", qty])
\t\tb.custom_minimum_size = Vector2(88,44)
\t\tb.pressed.connect(_dealer_storage_transfer.bind(strain, qty, moving_in))
\t\trow.add_child(b)
\tvar all: Button = Button.new()
\tall.text = "MAX" if moving_in else "ALL"
\tall.custom_minimum_size = Vector2(96,44)
\tall.pressed.connect(_dealer_storage_transfer.bind(strain, 999999, moving_in))
\trow.add_child(all)

func _refresh_dealer_storage_panel() -> void:
\tif dealer_storage_list == null:
\t\treturn
\t_clear_children(dealer_storage_list)
\tvar summary: Label = Label.new()
\tsummary.text = "DEALER LOCKER %s   |   %dg / %dg" % ["LOCKED" if dealer_locker_level <= 0 else _roman(dealer_locker_level), _dealer_locker_total(), _dealer_locker_capacity()]
\tsummary.add_theme_font_size_override("font_size", 20)
\tdealer_storage_list.add_child(summary)
\tif dealer_locker_level <= 0:
\t\tvar locked: Label = Label.new()
\t\tlocked.text = "Unlock Dealer Locker I in Phone -> Business -> Upgrades."
\t\tdealer_storage_list.add_child(locked)
\t\treturn
\tvar a: Label = Label.new(); a.text = "NORMAL STORAGE -> DEALER STORAGE"; a.add_theme_font_size_override("font_size",19); dealer_storage_list.add_child(a)
\tvar names: Array[String] = []
\tfor k: Variant in products.keys():
\t\tvar s: String = str(k)
\t\tif _available_amount(s)>0: names.append(s)
\tnames.sort()
\tfor s: String in names: _dealer_storage_row(dealer_storage_list,s,_available_amount(s),true)
\tvar b: Label = Label.new(); b.text = "DEALER STORAGE -> NORMAL STORAGE"; b.add_theme_font_size_override("font_size",19); dealer_storage_list.add_child(b)
\tvar dnames: Array[String] = []
\tfor k: Variant in locker_weed.keys():
\t\tvar s: String = str(k)
\t\tif int(locker_weed.get(s,0))>0: dnames.append(s)
\tdnames.sort()
\tfor s: String in dnames: _dealer_storage_row(dealer_storage_list,s,int(locker_weed.get(s,0)),false)
'''
        t=up(t,"_open_dealer_storage_panel",runtime,"_open_supply_inventory_panel")
        t=rep(t,"_open_dealer_locker_after_approach",'''func _open_dealer_locker_after_approach() -> void:
\tif current_view == "locker":
\t\t_open_dealer_storage_panel()
''')
        t=t.replace("personal_inventory.open_locker()","_open_dealer_storage_panel()")
        t=re.sub(r'\n\tif personal_inventory != null:\n\t\tpersonal_inventory\.refresh\(\)',"",t)

        t=rep(t,"_any_modal_open",'''func _any_modal_open() -> bool:
\treturn reset_confirmation_open or reset_in_progress or session_paused or phone_open or sale_panel.visible or grow_panel.visible or (plant_direct_panel != null and plant_direct_panel.visible) or bagging_panel.visible or storage_panel.visible or (dealer_storage_panel != null and dealer_storage_panel.visible) or (supply_inventory_panel != null and supply_inventory_panel.visible) or (system_control_panel != null and system_control_panel.visible) or trim_panel.visible or bag_minigame_panel.visible or (peephole_panel != null and peephole_panel.visible) or (tutorial_panel != null and tutorial_panel.visible) or (daily_report_panel != null and daily_report_panel.visible)
''')
        t=rep(t,"_cancel_phone_gesture",'''func _cancel_phone_gesture() -> void:
\tfor scroll: PhoneTouchScroll in [phone_scroll, bagging_scroll, storage_scroll, dealer_storage_scroll, supply_inventory_scroll]:
\t\tif scroll != null:
\t\t\tscroll.cancel_touch()
''')
        t=rep(t,"_handle_station_list_pointer",'''func _handle_station_list_pointer(event: InputEvent) -> bool:
\tif phone_open or trim_panel.visible or bag_minigame_panel.visible: return false
\tif bagging_panel.visible and bagging_scroll != null: return bagging_scroll.handle_pointer(event)
\tif storage_panel.visible and storage_scroll != null: return storage_scroll.handle_pointer(event)
\tif dealer_storage_panel != null and dealer_storage_panel.visible and dealer_storage_scroll != null: return dealer_storage_scroll.handle_pointer(event)
\tif supply_inventory_panel != null and supply_inventory_panel.visible and supply_inventory_scroll != null: return supply_inventory_scroll.handle_pointer(event)
\treturn false
''')
        m=pat("_hide_learning_panels").search(t)
        if m:
            x=m.group(0).replace("storage_panel, trim_panel","storage_panel, dealer_storage_panel, trim_panel")
            t=t[:m.start()]+x.rstrip()+"\n\n"+t[m.end():]
        t=t.replace("phone_open or bagging_panel.visible or storage_panel.visible or (supply_inventory_panel","phone_open or bagging_panel.visible or storage_panel.visible or (dealer_storage_panel != null and dealer_storage_panel.visible) or (supply_inventory_panel",1)

        t=rep(t,"_has_listed_stock",'''func _has_listed_stock() -> bool:
\tfor k: Variant in products.keys():
\t\tif _player_product_sellable(str(k)): return true
\treturn false
''')
        t=rep(t,"_player_available_amount",'''func _player_available_amount(product_name: String) -> int:
\treturn _available_amount(product_name)
''')
        t=rep(t,"_player_product_sellable",'''func _player_product_sellable(product_name: String) -> bool:
\tif not products.has(product_name): return false
\tvar data: Dictionary = products[product_name]
\treturn bool(data.get("listed", false)) and _available_amount(product_name) > 0
''')
        t=rep(t,"_consume_player_sale_stock",'''func _consume_player_sale_stock(product_name: String, qty: int) -> bool:
\tif qty <= 0 or not products.has(product_name) or _available_amount(product_name) < qty: return false
\tvar data: Dictionary = products[product_name]
\tdata["stock"] = maxi(0, int(data.get("stock",0)) - qty)
\tproducts[product_name] = data
\treturn true
''')
        t=t.replace("storage or your backpack","normal storage").replace("business storage or your backpack","normal storage").replace("between storage and your backpack","in normal storage")
        t=t.replace('\t\t"personal_weed": personal_weed,\n',"").replace('\t\t"locker_cash": locker_cash,\n',"")

        old=re.compile(r'\tvar loaded_personal_weed: Variant = data\.get\("personal_weed", personal_weed\)\n\tif loaded_personal_weed is Dictionary:\n\t\tpersonal_weed = loaded_personal_weed as Dictionary\n\tvar loaded_locker_weed: Variant = data\.get\("locker_weed", locker_weed\)\n\tif loaded_locker_weed is Dictionary:\n\t\tlocker_weed = loaded_locker_weed as Dictionary\n\tlocker_cash = maxi\(0, int\(data\.get\("locker_cash", locker_cash\)\)\)\n\tvar loaded_products: Variant = data\.get\("products", products\)\n\tif loaded_products is Dictionary:\n\t\tproducts = loaded_products as Dictionary\n\tfor pocket_strain_variant in personal_weed\.keys\(\):\n\t\t_ensure_product_exists\(str\(pocket_strain_variant\)\)\n')
        new='''\tvar legacy_personal: Dictionary = {}
\tvar lp: Variant = data.get("personal_weed", {})
\tif lp is Dictionary: legacy_personal = (lp as Dictionary).duplicate(true)
\tvar lw: Variant = data.get("locker_weed", locker_weed)
\tif lw is Dictionary: locker_weed = (lw as Dictionary).duplicate(true)
\tvar legacy_cash: int = maxi(0, int(data.get("locker_cash",0)))
\tvar loaded_products: Variant = data.get("products", products)
\tif loaded_products is Dictionary: products = loaded_products as Dictionary
\tfor k: Variant in legacy_personal.keys():
\t\tvar s: String = str(k); var amount: int = maxi(0,int(legacy_personal.get(s,0)))
\t\tif amount>0:
\t\t\t_ensure_product_exists(s)
\t\t\tvar pd: Dictionary = products[s]; pd["stock"] = int(pd.get("stock",0))+amount; products[s]=pd
\tif legacy_cash>0: cash += legacy_cash
'''
        t,count=old.subn(new,t,count=1)
        if count!=1: raise SystemExit("legacy load block")
        for bad in ["PersonalInventory","personal_inventory","personal_weed","locker_cash","backpack_quick_button","your backpack"]:
            if bad in t: raise SystemExit("legacy remains "+bad)
        for req in ["func _build_dealer_storage_panel()","func _refresh_dealer_storage_panel()","const DEALER_COMMISSION_RATE: float = 0.10","create_timer(0.38)"]:
            if req not in t: raise SystemExit("missing "+req)
        names=re.findall(r"^func\s+([A-Za-z0-9_]+)\(",t,re.M)
        dup={k:v for k,v in collections.Counter(names).items() if v>1}
        if dup: raise SystemExit("dup "+repr(dup))
        row[1]=t.encode()
    final.append(row)
if not found: raise SystemExit("main missing")
packed=rebuild(b,fb,final); PCK.write_bytes(packed)
_,_,check=parse(PCK); paths={x[0] for x in check}
if paths & REMOVE: raise SystemExit("old inventory scripts remain")
src={n:d.decode("utf-8","replace") for n,d,_ in check if n in ["scripts/main.gd","scripts/touch_scroll.gd"]}
if "PersonalInventory" in src.get("scripts/main.gd",""): raise SystemExit("old inventory survives")
if "const TAP_SLOP: float = 12.0" not in src.get("scripts/touch_scroll.gd",""): raise SystemExit("tap fix lost")
html=HTML.read_text()
html=re.sub(r'const AFB_TEST_RELEASE = "[^"]+";',f'const AFB_TEST_RELEASE = "{RELEASE}";',html,count=1)
html=re.sub(r'"fileSizes":\{[^}]*\}',f'"fileSizes":{{"{PACK_URL}":{len(packed)},"index.wasm":37902138}}',html,count=1)
html=re.sub(r'"mainPack":"[^"]+"',f'"mainPack":"{PACK_URL}"',html,count=1)
HTML.write_text(html)
meta=json.loads(VERSION.read_text()); meta["release_id"]=RELEASE
meta["inventory_status"]="old backpack/personal-locker runtime removed"
meta["dealer_storage_ui"]="native station panel independent of old player inventory"
meta["legacy_inventory_migration"]="old backpack product moves once to normal storage; old locker cash returns to cash"
meta["player_inventory_note"]="removed for now; redesign later"
VERSION.write_text(json.dumps(meta,indent=2)+"\n")
print("Built",RELEASE,len(packed))
