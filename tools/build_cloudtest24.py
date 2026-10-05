from pathlib import Path
import struct, hashlib, re, json, collections

PCK=Path("index-cloudtest10.pck")
HTML=Path("index.html")
VERSION=Path("version.json")
BUILD=Path("BUILD_VERSION.txt")
RELEASE="0.7.9-beta.19-cloudtest.61"
PACK_URL="index-cloudtest10.pck?build=61"

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
    for m in reversed(ms):
        src=src[:m.start()]+src[m.end():]
    return src[:at]+new.rstrip()+"\n\n"+src[at:]

blob,fb,entries=parse(PCK)
found=False

for row in entries:
    if row[0]!="scripts/main.gd":
        continue
    found=True
    text=row[1].decode("utf-8","replace").rstrip(" \n\0")

    story=r'''func _build_story_progress_section() -> void:
	var story_card: PanelContainer = PanelContainer.new()
	story_card.custom_minimum_size.x = 0.0
	story_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story_card.add_theme_stylebox_override("panel", _style_box(Color("171d25"), Color("776b3f"), 18, 2))
	phone_list.add_child(story_card)

	var story_box: VBoxContainer = VBoxContainer.new()
	story_box.custom_minimum_size.x = 0.0
	story_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story_box.add_theme_constant_override("separation", 7)
	story_card.add_child(story_box)

	var chapter_one_done: bool = _story_chapter_one_complete()
	var chapter_two_done: bool = _story_chapter_two_complete()
	var chapter_three_done: bool = _story_chapter_three_complete()

	var chapter_title: Label = Label.new()
	if not chapter_one_done:
		chapter_title.text = "STORY\nCHAPTER 1 - STARTING SMALL"
	elif not chapter_two_done:
		chapter_title.text = "STORY\nCHAPTER 2 - BUILDING A NAME"
	elif not chapter_three_done:
		chapter_title.text = "STORY\nCHAPTER 3 - GETTING NOTICED"
	else:
		chapter_title.text = "STORY\nCHAPTER 3 COMPLETE\nNEXT: OUTGROWING THE APARTMENT"
	chapter_title.custom_minimum_size.x = 0.0
	chapter_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chapter_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chapter_title.add_theme_font_size_override("font_size", 22)
	chapter_title.modulate = Color("e4cf83")
	story_box.add_child(chapter_title)

	var objectives: Label = Label.new()
	if not chapter_one_done:
		objectives.text = "\n".join([
			_story_checkmark(int(advancement_stats.get("plants_planted", 0)) >= 1, "Plant your first seed"),
			_story_checkmark(int(advancement_stats.get("harvests", 0)) >= 1, "Complete your first harvest"),
			_story_checkmark(int(advancement_stats.get("grams_trimmed", 0)) >= 5, "Hand-trim 5g"),
			_story_checkmark(int(advancement_stats.get("bags_sealed", 0)) >= 1, "Seal your first bag"),
			_story_checkmark(int(advancement_stats.get("grams_stored", 0)) >= 10, "Put 10g into storage"),
			_story_checkmark(int(advancement_stats.get("products_listed", 0)) >= 1, "List your first product"),
			_story_checkmark(int(advancement_stats.get("sales", 0)) >= 1, "Complete your first sale")
		])
		objectives.text += "\n\nUNLOCK: Chapter 2 + Fresh Drop customer rushes"
	elif not chapter_two_done:
		objectives.text = "\n".join([
			_story_checkmark(_story_first_regular_complete(), "First Regular - complete 3 sales with one customer"),
			_story_checkmark(int(advancement_stats.get("customers_known", 0)) >= 4, "Know Your People - recognize 4 customers"),
			_story_checkmark(reputation >= 50, "Word Gets Around - reach 50 reputation"),
			_story_checkmark(_launched_product_count() >= 2, "Fresh Drop - launch 2 different products"),
			_story_checkmark(grow_tent_count >= 2, "Room to Grow - install Tent 2"),
			_story_checkmark(grower_level >= 5 and brand_level >= 3 and lifetime_revenue >= 2000, "Established - Grower 5, Brand 3, $2,000 revenue")
		])
		objectives.text += "\n\nUNLOCK: Customer texting after First Regular.\nNEXT: Getting Noticed."
	else:
		objectives.text = "\n".join([
			_story_checkmark(_max_friend_loyalty() >= FRIEND_RECRUIT_LOYALTY, "Real Loyalty - build one friend to 70 loyalty"),
			_story_checkmark(_friend_staff_count() >= 1, "Put Your People On - recruit a loyal friend"),
			_story_checkmark(int(advancement_stats.get("dealer_sales", 0)) >= 5, "Delegating - complete 5 dealer sales"),
			_story_checkmark(int(advancement_stats.get("customers_known", 0)) >= 8, "Growing Network - recognize 8 customers"),
			_story_checkmark(reputation >= 100, "People Are Talking - reach 100 reputation"),
			_story_checkmark(grower_level >= 8 and lifetime_revenue >= 5000, "Too Big to Ignore - Grower 8 and $5,000 revenue"),
			_story_checkmark(heat_peak >= 25.0, "On the Radar - reach 25 Heat"),
			_story_checkmark(heat_reduced_total >= 10.0, "Cool Things Down - reduce 10 total Heat"),
			_story_checkmark(reeves_met, "Federal Pressure - meet Agent Reeves at the door")
		])
		objectives.text += "\n\nCHAPTER 4 PREVIEW\nOUTGROWING THE APARTMENT\nLarger operation • more staff/dealers • bulk production • new location.\nPreview only for now; Chapter 4 mechanics are not active yet."

	objectives.custom_minimum_size.x = 0.0
	objectives.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objectives.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_box.add_child(objectives)
'''
    text=replace_func(text,"_build_story_progress_section",story)

    task=r'''func _build_task_app() -> void:
	_build_story_progress_section()
	var grid: GridContainer = _phone_category_grid()
	_add_phone_app_tile(grid, "", "Advancements", "Roadmap + %d reward%s ready" % [_advancement_ready_count(), "" if _advancement_ready_count() == 1 else "s"], "advancements")

	# Task uses the same fixed-width containment as the Advancements page.
	# Long chapter/objective copy must wrap inside the phone instead of
	# increasing the minimum width of the phone/game viewport.
	_constrain_advancement_phone_width(phone_list)
	phone_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	phone_list.custom_minimum_size.x = 0.0
	phone_list.queue_sort()
	phone_scroll.queue_sort()
'''
    text=replace_func(text,"_build_task_app",task)

    required=[
        'chapter_title.text = "STORY\\nCHAPTER 3 COMPLETE\\nNEXT: OUTGROWING THE APARTMENT"',
        'objectives.custom_minimum_size.x = 0.0',
        'func _constrain_advancement_phone_width(node: Node) -> void:',
        '# Task uses the same fixed-width containment as the Advancements page.',
        'phone_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED',
        '"CAREER ROADMAP\\n%s"',
        '"id": "bench_three"',
        '"id": "dealer_storage_max"',
    ]
    for needle in required:
        if needle not in text: raise SystemExit("verify "+needle)

    names=re.findall(r"^func\s+([A-Za-z0-9_]+)\(",text,re.M)
    dup={k:v for k,v in collections.Counter(names).items() if v>1}
    if dup: raise SystemExit("duplicates "+repr(dup))
    row[1]=text.encode("utf-8")

if not found:
    raise SystemExit("main missing")

packed=rebuild(blob,fb,entries)
PCK.write_bytes(packed)

_,_,verify=parse(PCK)
sources={name:data.decode("utf-8","replace") for name,data,_ in verify if name in ["scripts/main.gd","scripts/touch_scroll.gd","scripts/storage_vault.gd"]}
main=sources.get("scripts/main.gd","")
for needle in [
    'chapter_title.text = "STORY\\nCHAPTER 3 COMPLETE\\nNEXT: OUTGROWING THE APARTMENT"',
    '# Task uses the same fixed-width containment as the Advancements page.',
    'phone_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED',
]:
    if needle not in main: raise SystemExit("packed task width verify "+needle)
if "const TAP_SLOP: float = 12.0" not in sources.get("scripts/touch_scroll.gd",""):
    raise SystemExit("mobile tap fix lost")
if 'const ANCHOR: Vector3 = Vector3(-4.33, 0.0, -0.30)' not in sources.get("scripts/storage_vault.gd",""):
    raise SystemExit("vault anchor changed")

html=HTML.read_text()
html=re.sub(r'const AFB_TEST_RELEASE = "[^"]+";',f'const AFB_TEST_RELEASE = "{RELEASE}";',html,count=1)
html=re.sub(r'const AFB_TEST_TITLE = "[^"]+";',f'const AFB_TEST_TITLE = "AFewBuds Cloud Test v{RELEASE}";',html,count=1)
html=re.sub(r'<title>AFewBuds Cloud Test[^<]*</title>',f'<title>AFewBuds Cloud Test {RELEASE}</title>',html,count=1)
html=re.sub(r'"fileSizes":\{[^}]*\}',f'"fileSizes":{{"{PACK_URL}":{len(packed)},"index.wasm":37902138}}',html,count=1)
html=re.sub(r'"mainPack":"[^"]+"',f'"mainPack":"{PACK_URL}"',html,count=1)
HTML.write_text(html)

meta=json.loads(VERSION.read_text())
meta["release_id"]=RELEASE
meta["task_phone_width_fix"]="Task story card now wraps chapter titles/objectives and runs fixed-width containment so it cannot stretch the phone/game viewport"
meta["task_story_header"]="Chapter headings split into compact multi-line phone-safe titles"
meta["runtime_payload"]="cloudtest61 PCK with Task screen width containment on top of cloudtest60 roadmap"
VERSION.write_text(json.dumps(meta,indent=2)+"\n")

BUILD.write_text(
    "AFewBuds Cloud Test\n"
    "Game build: 0.7.9-beta.19\n"
    f"Web release: {RELEASE}\n"
    "Runtime: cloudtest60 roadmap + Task story-card fixed-width containment\n"
)

print("Built",RELEASE,len(packed))
