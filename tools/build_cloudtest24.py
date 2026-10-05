from pathlib import Path
import struct, hashlib, re, json, collections

PCK=Path("index-cloudtest10.pck")
HTML=Path("index.html")
VERSION=Path("version.json")
RELEASE="0.7.9-beta.19-cloudtest.47"
PACK_URL="index-cloudtest10.pck?build=47"

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

    # Physical locker branding.
    text=text.replace('locker_logo.text = "AFewBuds"','locker_logo.text = "DEALER\\nSTORAGE"',1)
    text=text.replace("locker_logo.font_size = 34","locker_logo.font_size = 27",1)

    # Dealer Storage transfer UI: one row per strain, both directions on the same card.
    transfer_func='''func _dealer_storage_transfer(strain: String, amount: int, moving_in: bool) -> void:
\tif moving_in:
\t\t_dealer_locker_add_from_storage(strain, amount)
\telse:
\t\t_dealer_locker_remove_to_storage(strain, amount)
\t_refresh_dealer_storage_panel()
'''
    text=replace_func(text,"_dealer_storage_transfer",transfer_func)

    row_func='''func _dealer_storage_row(parent: VBoxContainer, strain: String, storage_amount: int, dealer_amount: int) -> void:
\tvar parts: Dictionary = _make_inventory_card("bag")
\tvar card: PanelContainer = parts["card"] as PanelContainer
\tvar content: VBoxContainer = parts["content"] as VBoxContainer
\tparent.add_child(card)

\tvar title: Label = Label.new()
\ttitle.text = strain
\ttitle.add_theme_font_size_override("font_size", 20)
\tcontent.add_child(title)

\tvar detail: Label = Label.new()
\tdetail.text = "Storage %dg   |   Dealer %dg" % [storage_amount, dealer_amount]
\tdetail.modulate = Color("b8c3c9")
\tcontent.add_child(detail)

\tvar controls: HBoxContainer = HBoxContainer.new()
\tcontrols.add_theme_constant_override("separation", 5)
\tcontent.add_child(controls)

\tfor qty: int in [1, 5]:
\t\tvar add_button: Button = Button.new()
\t\tadd_button.text = "+%d" % qty
\t\tadd_button.custom_minimum_size = Vector2(72, 42)
\t\tadd_button.disabled = storage_amount <= 0 or _dealer_locker_free_capacity() <= 0
\t\tadd_button.pressed.connect(_dealer_storage_transfer.bind(strain, qty, true))
\t\tcontrols.add_child(add_button)

\tvar max_button: Button = Button.new()
\tmax_button.text = "MAX"
\tmax_button.custom_minimum_size = Vector2(76, 42)
\tmax_button.disabled = storage_amount <= 0 or _dealer_locker_free_capacity() <= 0
\tmax_button.pressed.connect(_dealer_storage_transfer.bind(strain, 999999, true))
\tcontrols.add_child(max_button)

\tfor qty: int in [1, 5]:
\t\tvar remove_button: Button = Button.new()
\t\tremove_button.text = "-%d" % qty
\t\tremove_button.custom_minimum_size = Vector2(72, 42)
\t\tremove_button.disabled = dealer_amount <= 0
\t\tremove_button.pressed.connect(_dealer_storage_transfer.bind(strain, qty, false))
\t\tcontrols.add_child(remove_button)

\tvar all_button: Button = Button.new()
\tall_button.text = "ALL"
\tall_button.custom_minimum_size = Vector2(76, 42)
\tall_button.disabled = dealer_amount <= 0
\tall_button.pressed.connect(_dealer_storage_transfer.bind(strain, 999999, false))
\tcontrols.add_child(all_button)
'''
    text=replace_func(text,"_dealer_storage_row",row_func)

    refresh='''func _refresh_dealer_storage_panel() -> void:
\tif dealer_storage_list == null:
\t\treturn
\tif dealer_storage_scroll != null and dealer_storage_scroll.is_gesture_busy():
\t\treturn
\t_clear_children(dealer_storage_list)

\tvar summary: Label = Label.new()
\tsummary.text = "DEALER STORAGE %s   |   %dg / %dg\n+ moves product into Dealer Storage. - moves it back to normal Storage." % ["LOCKED" if dealer_locker_level <= 0 else _roman(dealer_locker_level), _dealer_locker_total(), _dealer_locker_capacity()]
\tsummary.add_theme_font_size_override("font_size", 20)
\tsummary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
\tdealer_storage_list.add_child(summary)

\tif dealer_locker_level <= 0:
\t\tvar locked: Label = Label.new()
\t\tlocked.text = "Unlock Dealer Locker I in Phone -> Business -> Upgrades."
\t\tdealer_storage_list.add_child(locked)
\t\treturn

\tvar strains: Array[String] = []
\tfor key_variant: Variant in products.keys():
\t\tvar strain: String = str(key_variant)
\t\tif _available_amount(strain) > 0 and not strains.has(strain):
\t\t\tstrains.append(strain)
\tfor key_variant: Variant in locker_weed.keys():
\t\tvar strain: String = str(key_variant)
\t\tif int(locker_weed.get(strain, 0)) > 0 and not strains.has(strain):
\t\t\tstrains.append(strain)
\tstrains.sort()

\tif strains.is_empty():
\t\tvar empty: Label = Label.new()
\t\tempty.text = "No packaged product is available in normal Storage or Dealer Storage."
\t\tempty.modulate = Color(1.0, 1.0, 1.0, 0.58)
\t\tdealer_storage_list.add_child(empty)
\t\treturn

\tfor strain: String in strains:
\t\t_dealer_storage_row(dealer_storage_list, strain, _available_amount(strain), maxi(0, int(locker_weed.get(strain, 0))))
'''
    text=replace_func(text,"_refresh_dealer_storage_panel",refresh)

    helpers='''func _add_upgrade_family_card(parent: VBoxContainer, title_text: String, detail_text: String, next_supply: String) -> void:
\tvar card: PanelContainer = PanelContainer.new()
\tcard.add_theme_stylebox_override("panel", _style_box(Color("151b20"), Color("37434c"), 14, 1))
\tparent.add_child(card)
\tvar box: VBoxContainer = VBoxContainer.new()
\tbox.add_theme_constant_override("separation", 7)
\tcard.add_child(box)
\tvar title: Label = Label.new()
\ttitle.text = title_text
\ttitle.add_theme_font_size_override("font_size", 21)
\tbox.add_child(title)
\tvar detail: Label = Label.new()
\tdetail.text = detail_text
\tdetail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
\tdetail.modulate = Color("b8c3c9")
\tbox.add_child(detail)
\tif next_supply.is_empty():
\t\tvar maxed: Label = Label.new()
\t\tmaxed.text = "MAX FOR CURRENT BUILD"
\t\tmaxed.add_theme_font_size_override("font_size", 17)
\t\tmaxed.modulate = Color("91c59d")
\t\tbox.add_child(maxed)
\t\treturn
\tvar info: Dictionary = supply_catalog[next_supply]
\tvar unlock_level: int = int(info.get("unlock", 1))
\tvar cost: int = int(info.get("cost", 0))
\tvar next_label: Label = Label.new()
\tnext_label.text = "NEXT: %s\n%s" % [next_supply, str(info.get("description", ""))]
\tnext_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
\tnext_label.modulate = Color("d8e1e5")
\tbox.add_child(next_label)
\tvar buy: Button = Button.new()
\tbuy.custom_minimum_size.y = 48
\tif grower_level < unlock_level:
\t\tbuy.text = "LOCKED   |   LEVEL %d" % unlock_level
\t\tbuy.disabled = true
\telse:
\t\tbuy.text = "BUY NEXT   |   $%d" % cost
\t\tbuy.disabled = cash < cost
\tbuy.pressed.connect(_buy_supply.bind(next_supply))
\tbox.add_child(buy)

func _add_dealer_locker_family_card(parent: VBoxContainer) -> void:
\tvar card: PanelContainer = PanelContainer.new()
\tcard.add_theme_stylebox_override("panel", _style_box(Color("151b20"), Color("37434c"), 14, 1))
\tparent.add_child(card)
\tvar box: VBoxContainer = VBoxContainer.new()
\tbox.add_theme_constant_override("separation", 7)
\tcard.add_child(box)
\tvar title: Label = Label.new()
\ttitle.text = "DEALER STORAGE"
\ttitle.add_theme_font_size_override("font_size", 21)
\tbox.add_child(title)
\tvar detail: Label = Label.new()
\tvar tier_text: String = "NOT INSTALLED" if dealer_locker_level <= 0 else "Locker %s" % _roman(dealer_locker_level)
\tdetail.text = "Current: %s\nCapacity: %dg   |   Stored: %dg" % [tier_text, _dealer_locker_capacity(), _dealer_locker_total()]
\tdetail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
\tdetail.modulate = Color("b8c3c9")
\tbox.add_child(detail)
\tif dealer_locker_level >= 4:
\t\tvar maxed: Label = Label.new()
\t\tmaxed.text = "MAX FOR CURRENT BUILD"
\t\tmaxed.add_theme_font_size_override("font_size", 17)
\t\tmaxed.modulate = Color("91c59d")
\t\tbox.add_child(maxed)
\t\treturn
\tvar next_level: int = dealer_locker_level + 1
\tvar next_cost: int = DEALER_LOCKER_COST_BY_LEVEL[next_level]
\tvar next_capacity: int = DEALER_LOCKER_CAPACITY_BY_LEVEL[next_level]
\tvar next_label: Label = Label.new()
\tnext_label.text = "NEXT: Dealer Locker %s   |   %dg" % [_roman(next_level), next_capacity]
\tnext_label.modulate = Color("d8e1e5")
\tbox.add_child(next_label)
\tvar buy: Button = Button.new()
\tbuy.text = "BUY NEXT   |   $%d" % next_cost
\tbuy.disabled = cash < next_cost
\tbuy.custom_minimum_size.y = 48
\tbuy.pressed.connect(_buy_dealer_locker_upgrade)
\tbox.add_child(buy)
'''
    text=upsert_before(text,"_add_upgrade_family_card",helpers,"_build_upgrades_app")

    upgrades='''func _build_upgrades_app() -> void:
\tvar intro: Label = Label.new()
\tintro.text = "Upgrade your operation one step at a time. Expandable systems stay visible even when maxed so future tiers can be added without the category disappearing."
\tintro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
\tphone_list.add_child(intro)

\tvar equipment: Label = Label.new()
\tequipment.text = "CURRENT EQUIPMENT\nGrow tents %d / 3   |   Tent Lv %d   |   Plant slots %d\nBagging Lv %d   |   Storage Lv %d (%dg)\nSupply Shelf Lv %d   |   Seeds %d/%d   |   Fertilizer %d/%d" % [grow_tent_count, tent_level, plant_slots.size(), bagging_level, storage_level, _storage_capacity(), supply_shelf_level, _total_seed_inventory(), _supply_seed_capacity(), fertilizer_units, _supply_fertilizer_capacity()]
\tequipment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
\tphone_list.add_child(equipment)

\tvar systems_heading: Label = Label.new()
\tsystems_heading.text = "EXPANDABLE SYSTEMS"
\tsystems_heading.add_theme_font_size_override("font_size", 19)
\tsystems_heading.modulate = Color("aeb9c0")
\tphone_list.add_child(systems_heading)

\tvar storage_name: String = "Storage I"
\tvar storage_next: String = ""
\tmatch storage_level:
\t\t1: storage_next = "Storage Shelving II"
\t\t2:
\t\t\tstorage_name = "Storage Shelving II"
\t\t\tstorage_next = "Storage Shelving III"
\t\t3:
\t\t\tstorage_name = "Storage Shelving III"
\t\t\tstorage_next = VAULT_SUPPLY
\t\t4:
\t\t\tstorage_name = "AFB Storage Vault"
\t\t\tstorage_next = HIDDEN_STASH_SUPPLY
\t\t_:
\t\t\tstorage_name = "Hidden Wall Stash"
\t_add_upgrade_family_card(phone_list, "STORAGE", "Current: %s\nCapacity: %dg   |   Stored: %dg" % [storage_name, _storage_capacity(), _total_stored_stock()], storage_next)

\tvar shelf_next: String = ""
\tif supply_shelf_level == 1: shelf_next = "Grow Supply Shelf II"
\telif supply_shelf_level == 2: shelf_next = "Grow Supply Shelf III"
\t_add_upgrade_family_card(phone_list, "GROW SUPPLY SHELF", "Current: Shelf %s\nSeeds: %d/%d   |   Fertilizer: %d/%d" % [_roman(supply_shelf_level), _total_seed_inventory(), _supply_seed_capacity(), fertilizer_units, _supply_fertilizer_capacity()], shelf_next)

\tvar tent_next: String = ""
\tif grow_tent_count == 1: tent_next = "Grow Tent Slot 2"
\telif grow_tent_count == 2: tent_next = "Grow Tent Slot 3"
\t_add_upgrade_family_card(phone_list, "GROW TENT SLOTS", "Installed: %d / 3\nPlant slots: %d   |   Tent equipment level: %d" % [grow_tent_count, plant_slots.size(), tent_level], tent_next)

\t_add_dealer_locker_family_card(phone_list)

\tvar chain_names: Array[String] = ["Grow Supply Shelf II", "Grow Supply Shelf III", "Storage Shelving II", "Storage Shelving III", VAULT_SUPPLY, HIDDEN_STASH_SUPPLY, "Grow Tent Slot 2", "Grow Tent Slot 3"]
\tvar installed: Array[String] = []
\tvar available: Array[String] = []
\tfor supply_variant: Variant in supply_catalog.keys():
\t\tvar supply_name: String = str(supply_variant)
\t\tif supply_name == "Fertilizer Pack" or chain_names.has(supply_name):
\t\t\tcontinue
\t\tif _supply_is_purchased(supply_name):
\t\t\tinstalled.append(supply_name)
\t\telse:
\t\t\tavailable.append(supply_name)
\tinstalled.sort()
\tavailable.sort()

\tvar installed_heading: Label = Label.new()
\tinstalled_heading.text = "INSTALLED EQUIPMENT"
\tinstalled_heading.add_theme_font_size_override("font_size", 19)
\tinstalled_heading.modulate = Color("aeb9c0")
\tphone_list.add_child(installed_heading)

\tvar installed_card: PanelContainer = PanelContainer.new()
\tinstalled_card.add_theme_stylebox_override("panel", _style_box(Color("151b20"), Color("37434c"), 14, 1))
\tphone_list.add_child(installed_card)
\tvar installed_box: VBoxContainer = VBoxContainer.new()
\tinstalled_box.add_theme_constant_override("separation", 5)
\tinstalled_card.add_child(installed_box)
\tif installed.is_empty():
\t\tvar none: Label = Label.new()
\t\tnone.text = "No standalone equipment installed yet."
\t\tinstalled_box.add_child(none)
\telse:
\t\tfor item_name: String in installed:
\t\t\tvar installed_row: Label = Label.new()
\t\t\tinstalled_row.text = "✓  %s" % item_name
\t\t\tinstalled_row.modulate = Color("91c59d")
\t\t\tinstalled_box.add_child(installed_row)

\tif available.is_empty():
\t\treturn

\tvar available_heading: Label = Label.new()
\tavailable_heading.text = "AVAILABLE EQUIPMENT"
\tavailable_heading.add_theme_font_size_override("font_size", 19)
\tavailable_heading.modulate = Color("aeb9c0")
\tphone_list.add_child(available_heading)

\tfor supply_name: String in available:
\t\tvar info: Dictionary = supply_catalog[supply_name]
\t\tvar unlock_level: int = int(info.get("unlock", 1))
\t\tvar cost: int = int(info.get("cost", 0))
\t\tvar card: PanelContainer = PanelContainer.new()
\t\tcard.add_theme_stylebox_override("panel", _style_box(Color("151b20"), Color("37434c"), 14, 1))
\t\tphone_list.add_child(card)
\t\tvar box: VBoxContainer = VBoxContainer.new()
\t\tbox.add_theme_constant_override("separation", 6)
\t\tcard.add_child(box)
\t\tvar title: Label = Label.new()
\t\ttitle.text = supply_name
\t\ttitle.add_theme_font_size_override("font_size", 20)
\t\tbox.add_child(title)
\t\tvar detail: Label = Label.new()
\t\tdetail.text = str(info.get("description", "Operation upgrade."))
\t\tdetail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
\t\tbox.add_child(detail)
\t\tvar buy: Button = Button.new()
\t\tbuy.custom_minimum_size.y = 48
\t\tif grower_level < unlock_level:
\t\t\tbuy.text = "LOCKED   |   LEVEL %d" % unlock_level
\t\t\tbuy.disabled = true
\t\telse:
\t\t\tbuy.text = "BUY   |   $%d" % cost
\t\t\tbuy.disabled = cash < cost
\t\tbuy.pressed.connect(_buy_supply.bind(supply_name))
\t\tbox.add_child(buy)
'''
    text=replace_func(text,"_build_upgrades_app",upgrades)

    required=[
        'locker_logo.text = "DEALER\\nSTORAGE"',
        'func _dealer_storage_row(parent: VBoxContainer, strain: String, storage_amount: int, dealer_amount: int)',
        'add_button.text = "+%d" % qty',
        'remove_button.text = "-%d" % qty',
        '"EXPANDABLE SYSTEMS"',
        '"STORAGE"',
        '"GROW SUPPLY SHELF"',
        '"GROW TENT SLOTS"',
        '"DEALER STORAGE"',
        '"MAX FOR CURRENT BUILD"',
        '"INSTALLED EQUIPMENT"',
        '"AVAILABLE EQUIPMENT"',
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
if 'locker_logo.text = "DEALER\\nSTORAGE"' not in main: raise SystemExit("world locker label not patched")
if "const TAP_SLOP: float = 12.0" not in sources.get("scripts/touch_scroll.gd",""): raise SystemExit("tap fix lost")

html=HTML.read_text()
html=re.sub(r'const AFB_TEST_RELEASE = "[^"]+";',f'const AFB_TEST_RELEASE = "{RELEASE}";',html,count=1)
html=re.sub(r'"fileSizes":\{[^}]*\}',f'"fileSizes":{{"{PACK_URL}":{len(packed)},"index.wasm":37902138}}',html,count=1)
html=re.sub(r'"mainPack":"[^"]+"',f'"mainPack":"{PACK_URL}"',html,count=1)
HTML.write_text(html)

meta=json.loads(VERSION.read_text())
meta["release_id"]=RELEASE
meta["upgrade_page"]="permanent expandable-system cards plus Installed/Available equipment sections"
meta["dealer_storage_transfer_ui"]="one row per strain with +1 +5 MAX and -1 -5 ALL"
meta["dealer_storage_world_label"]="physical locker says DEALER STORAGE"
VERSION.write_text(json.dumps(meta,indent=2)+"\n")
print("Built",RELEASE,len(packed))
