from pathlib import Path
import struct, hashlib, re, json, collections

PCK=Path("index-cloudtest10.pck")
HTML=Path("index.html")
VERSION=Path("version.json")
BUILD=Path("BUILD_VERSION.txt")
RELEASE="0.7.9-beta.19-cloudtest.57"
PACK_URL="index-cloudtest10.pck?build=57"

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

    # Scroll controller for direct plant/seed picker.
    if "var plant_direct_scroll: PhoneTouchScroll" not in text:
        anchor="var plant_direct_panel: PanelContainer\nvar plant_direct_box: VBoxContainer\n"
        if anchor not in text:
            raise SystemExit("plant direct variable anchor missing")
        text=text.replace(
            anchor,
            "var plant_direct_panel: PanelContainer\nvar plant_direct_box: VBoxContainer\nvar plant_direct_scroll: PhoneTouchScroll\n",
            1,
        )

    build_func=r'''func _build_direct_plant_panel() -> void:
	plant_direct_panel = PanelContainer.new()
	plant_direct_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	plant_direct_panel.offset_left = 22
	plant_direct_panel.offset_right = -22
	plant_direct_panel.offset_top = -450
	plant_direct_panel.offset_bottom = -82
	plant_direct_panel.visible = false
	plant_direct_panel.add_theme_stylebox_override("panel", _style_box(Color("11191f"), Color("40515b"), 18, 2))
	hud.add_child(plant_direct_panel)

	plant_direct_scroll = PhoneTouchScroll.new()
	plant_direct_scroll.name = "plant_direct_scroll"
	plant_direct_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plant_direct_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	plant_direct_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	plant_direct_scroll.scroll_deadzone = 10
	plant_direct_panel.add_child(plant_direct_scroll)

	plant_direct_box = VBoxContainer.new()
	plant_direct_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plant_direct_box.add_theme_constant_override("separation", 8)
	plant_direct_scroll.add_child(plant_direct_box)
'''
    text=replace_func(text,"_build_direct_plant_panel",build_func)

    # Remove the artificial 3-seed cap and show all owned seeds, including
    # future/extra genetics that are not yet listed in SEED_ORDER.
    old_seed_block=re.compile(
        r'\t\tvar shown: int = 0\n'
        r'\t\tfor seed_name in SEED_ORDER:\n'
        r'.*?'
        r'\t\tif shown == 0:\n'
        r'\t\t\tvar none: Label = Label\.new\(\)\n'
        r'\t\t\tnone\.text = "No seeds owned\. Buy unlocked seeds from the phone\."\n'
        r'\t\t\tplant_direct_box\.add_child\(none\)\n'
        r'\t\treturn',
        re.S
    )
    m=old_seed_block.search(text)
    if not m:
        raise SystemExit("3-seed picker block missing")

    new_seed_block=r'''		var owned_seed_names: Array[String] = []
		for seed_name: String in SEED_ORDER:
			if int(seed_inventory.get(seed_name, 0)) > 0:
				owned_seed_names.append(seed_name)
		for seed_variant: Variant in seed_inventory.keys():
			var extra_seed_name: String = str(seed_variant)
			if int(seed_inventory.get(extra_seed_name, 0)) > 0 and not owned_seed_names.has(extra_seed_name):
				owned_seed_names.append(extra_seed_name)

		var shown: int = 0
		for seed_name: String in owned_seed_names:
			var seed_count: int = int(seed_inventory.get(seed_name, 0))
			if seed_count <= 0:
				continue
			var seed_button: Button = Button.new()
			seed_button.text = "%s (%d)" % [seed_name, seed_count]
			seed_button.custom_minimum_size.y = 48
			seed_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			seed_button.pressed.connect(_direct_plant_seed.bind(seed_name))
			seed_row.add_child(seed_button)
			shown += 1
		if shown == 0:
			var none: Label = Label.new()
			none.text = "No seeds owned. Buy unlocked seeds from the phone."
			plant_direct_box.add_child(none)
		return'''
    text=text[:m.start()]+new_seed_block+text[m.end():]

    # Route mobile drag gestures to the new seed picker scroll without breaking taps.
    input_match=pat("_input").search(text)
    if not input_match:
        raise SystemExit("_input missing")
    input_block=input_match.group(0)
    scroll_hook='''	if plant_direct_panel != null and plant_direct_panel.visible and plant_direct_scroll != null and plant_direct_scroll.handle_pointer(event):
		get_viewport().set_input_as_handled()
		return
'''
    if scroll_hook not in input_block:
        anchor='''	if phone_open and phone_scroll != null and phone_scroll.handle_pointer(event):
		get_viewport().set_input_as_handled()
		return
'''
        if anchor not in input_block:
            raise SystemExit("phone scroll input anchor missing")
        input_block=input_block.replace(anchor,anchor+scroll_hook,1)
        text=text[:input_match.start()]+input_block.rstrip()+"\n\n"+text[input_match.end():]

    # Reset gesture state whenever the direct plant panel opens/closes.
    open_match=pat("_open_direct_plant").search(text)
    if not open_match: raise SystemExit("_open_direct_plant missing")
    open_block=open_match.group(0)
    if "plant_direct_scroll.cancel_touch()" not in open_block:
        anchor="\tselected_plant_slot = slot_index\n"
        if anchor not in open_block: raise SystemExit("open plant anchor missing")
        open_block=open_block.replace(anchor,anchor+"\tif plant_direct_scroll != null:\n\t\tplant_direct_scroll.cancel_touch()\n\t\tplant_direct_scroll.scroll_vertical = 0\n",1)
        text=text[:open_match.start()]+open_block.rstrip()+"\n\n"+text[open_match.end():]

    close_match=pat("_close_direct_plant").search(text)
    if not close_match: raise SystemExit("_close_direct_plant missing")
    close_block=close_match.group(0)
    if "plant_direct_scroll.cancel_touch()" not in close_block:
        anchor="\tplant_direct_panel.visible = false\n"
        if anchor not in close_block: raise SystemExit("close plant anchor missing")
        close_block=close_block.replace(anchor,anchor+"\tif plant_direct_scroll != null:\n\t\tplant_direct_scroll.cancel_touch()\n",1)
        text=text[:close_match.start()]+close_block.rstrip()+"\n\n"+text[close_match.end():]

    required=[
        "var plant_direct_scroll: PhoneTouchScroll",
        'plant_direct_scroll.name = "plant_direct_scroll"',
        "var owned_seed_names: Array[String] = []",
        "for seed_name: String in owned_seed_names:",
        "extra_seed_name",
        "plant_direct_scroll.handle_pointer(event)",
        "plant_direct_scroll.scroll_vertical = 0",
        '"Bagging Bench III"',
        "PremiumLeftDoorPivot",
    ]
    for needle in required:
        if needle not in text: raise SystemExit("verify "+needle)

    forbidden=[
        "if shown >= 3:",
    ]
    for needle in forbidden:
        if needle in text: raise SystemExit("old seed cap remains: "+needle)

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
    "var plant_direct_scroll: PhoneTouchScroll",
    "var owned_seed_names: Array[String] = []",
    "for seed_name: String in owned_seed_names:",
    "plant_direct_scroll.handle_pointer(event)",
]:
    if needle not in main: raise SystemExit("packed verify "+needle)
if "if shown >= 3:" in main:
    raise SystemExit("packed runtime still caps owned seeds at 3")
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
meta["planting_seed_picker"]="empty pots list every owned seed type instead of stopping after 3"
meta["planting_seed_picker_scroll"]="direct plant panel uses PhoneTouchScroll so large seed collections remain usable on mobile"
meta["planting_seed_picker_future_genetics"]="owned seed_inventory entries not present in SEED_ORDER are appended automatically"
meta["runtime_payload"]="cloudtest57 PCK with unlimited owned-seed planting picker"
VERSION.write_text(json.dumps(meta,indent=2)+"\n")

BUILD.write_text(
    "AFewBuds Cloud Test\n"
    "Game build: 0.7.9-beta.19\n"
    f"Web release: {RELEASE}\n"
    "Runtime: all owned seeds available when planting + mobile scrollable seed picker\n"
)

print("Built",RELEASE,len(packed))
