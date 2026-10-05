from pathlib import Path
import struct, hashlib, re, json, collections

PCK=Path("index-cloudtest10.pck")
HTML=Path("index.html")
VERSION=Path("version.json")
BUILD=Path("BUILD_VERSION.txt")
RELEASE="0.7.9-beta.19-cloudtest.60"
PACK_URL="index-cloudtest10.pck?build=60"

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

def upsert_before(src,name,new,before):
    ms=list(pat(name).finditer(src))
    if ms:
        at=ms[0].start()
        for m in reversed(ms):
            src=src[:m.start()]+src[m.end():]
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

    helper=r'''func _constrain_advancement_phone_width(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Control:
			var control: Control = child as Control
			control.custom_minimum_size.x = 0.0
			control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if control is Label:
				var label: Label = control as Label
				label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			elif control is Button:
				var button: Button = control as Button
				button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_constrain_advancement_phone_width(child)
'''
    text=upsert_before(text,"_constrain_advancement_phone_width",helper,"_build_advancements_app")

    roadmap=r'''func _build_advancements_app() -> void:
	var claimed_count: int = _advancement_claimed_count()
	var ready_count: int = _advancement_ready_count()

	var summary_card: PanelContainer = PanelContainer.new()
	summary_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_card.add_theme_stylebox_override("panel", _style_box(Color("111920"), Color("776b3f"), 16, 2))
	phone_list.add_child(summary_card)
	var summary_box: VBoxContainer = VBoxContainer.new()
	summary_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_box.add_theme_constant_override("separation", 6)
	summary_card.add_child(summary_box)

	var rank: Label = Label.new()
	rank.text = "CAREER ROADMAP\n%s" % _advancement_career_rank()
	rank.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rank.add_theme_font_size_override("font_size", 22)
	rank.modulate = Color("e4cf83")
	summary_box.add_child(rank)

	var story: Label = Label.new()
	story.text = "STORY  |  %s" % _advancement_story_label()
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story.modulate = Color("c6d4da")
	summary_box.add_child(story)

	var summary: Label = Label.new()
	summary.text = "%d / %d milestones claimed   |   %d reward%s ready" % [claimed_count, advancement_catalog.size(), ready_count, "" if ready_count == 1 else "s"]
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.modulate = Color("d7c28a") if ready_count > 0 else Color("9fb0ba")
	summary_box.add_child(summary)

	var overall: ProgressBar = ProgressBar.new()
	overall.min_value = 0
	overall.max_value = maxi(1, advancement_catalog.size())
	overall.value = claimed_count
	overall.show_percentage = false
	overall.custom_minimum_size = Vector2(0, 16)
	overall.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_box.add_child(overall)

	if ready_count > 0:
		var claim_all: Button = Button.new()
		claim_all.text = "CLAIM ALL (%d)" % ready_count
		claim_all.custom_minimum_size = Vector2(0, 54)
		claim_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		claim_all.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		claim_all.add_theme_font_size_override("font_size", 17)
		claim_all.add_theme_stylebox_override("normal", _style_box(Color("1b3324"), Color("78c98a"), 12, 2))
		claim_all.pressed.connect(_claim_all_advancements)
		summary_box.add_child(claim_all)

	var roadmap_hint: Label = Label.new()
	roadmap_hint.text = "Each lane shows your current tier and the next tier ahead. Claimed milestones stay saved but are removed from the active list. If you already completed a future goal, it appears as READY AHEAD instead of being hidden."
	roadmap_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	roadmap_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roadmap_hint.modulate = Color("9fb0ba")
	phone_list.add_child(roadmap_hint)

	for lane_name: String in _advancement_lane_order():
		var lane_total: int = 0
		var lane_claimed: int = 0
		for lane_entry: Dictionary in advancement_catalog:
			if _advancement_lane_name(lane_entry) != lane_name:
				continue
			lane_total += 1
			if bool(advancement_claimed.get(str(lane_entry.get("id", "")), false)):
				lane_claimed += 1
		if lane_total <= 0:
			continue

		var lane_card: PanelContainer = PanelContainer.new()
		lane_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lane_card.add_theme_stylebox_override("panel", _style_box(Color("131b21"), Color("37454e"), 16, 1))
		phone_list.add_child(lane_card)
		var lane_box: VBoxContainer = VBoxContainer.new()
		lane_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lane_box.add_theme_constant_override("separation", 7)
		lane_card.add_child(lane_box)

		var lane_title: Label = Label.new()
		lane_title.text = "%s   |   %d/%d" % [lane_name.to_upper(), lane_claimed, lane_total]
		lane_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lane_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lane_title.add_theme_font_size_override("font_size", 21)
		lane_title.modulate = Color("d7c28a")
		lane_box.add_child(lane_title)

		var lane_progress: ProgressBar = ProgressBar.new()
		lane_progress.min_value = 0
		lane_progress.max_value = maxi(1, lane_total)
		lane_progress.value = lane_claimed
		lane_progress.show_percentage = false
		lane_progress.custom_minimum_size = Vector2(0, 12)
		lane_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lane_box.add_child(lane_progress)

		var current_tier: int = _advancement_lane_current_tier(lane_name)
		if current_tier < 0:
			var mastered: Label = Label.new()
			mastered.text = "MASTERED  |  All current milestones claimed."
			mastered.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			mastered.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			mastered.modulate = Color("8ed6a3")
			lane_box.add_child(mastered)
			continue

		var focus: Label = Label.new()
		focus.text = "CURRENT FOCUS  |  TIER %d" % current_tier
		focus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		focus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		focus.modulate = Color("c6d4da")
		lane_box.add_child(focus)

		for entry: Dictionary in advancement_catalog:
			if _advancement_lane_name(entry) != lane_name:
				continue
			var advancement_id: String = str(entry.get("id", ""))
			if bool(advancement_claimed.get(advancement_id, false)):
				continue
			var entry_tier: int = int(entry.get("tier", 1))
			if entry_tier == current_tier or _advancement_is_ready(entry):
				_add_advancement_roadmap_milestone(lane_box, entry, current_tier)

		var next_tier: int = _advancement_lane_next_tier(lane_name, current_tier)
		if next_tier > 0:
			var next_titles: Array[String] = []
			for next_entry: Dictionary in advancement_catalog:
				if _advancement_lane_name(next_entry) != lane_name:
					continue
				if int(next_entry.get("tier", 1)) != next_tier:
					continue
				var next_id: String = str(next_entry.get("id", ""))
				if bool(advancement_claimed.get(next_id, false)):
					continue
				if _advancement_is_ready(next_entry):
					continue
				next_titles.append(str(next_entry.get("title", "Milestone")))
			if not next_titles.is_empty():
				var preview: Label = Label.new()
				preview.text = "LOCKED NEXT  |  TIER %d\n%s" % [next_tier, "  •  ".join(next_titles)]
				preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				preview.modulate = Color("687781")
				lane_box.add_child(preview)

	_constrain_advancement_phone_width(phone_list)
	phone_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	phone_list.custom_minimum_size.x = 0.0
	phone_list.queue_sort()
	phone_scroll.queue_sort()
'''
    text=replace_func(text,"_build_advancements_app",roadmap)

    milestone=r'''func _add_advancement_roadmap_milestone(parent: VBoxContainer, entry: Dictionary, current_tier: int) -> void:
	var advancement_id: String = str(entry.get("id", ""))
	var target: int = maxi(1, int(entry.get("target", 1)))
	var current_value: int = mini(_advancement_value(entry), target)
	var complete: bool = _advancement_is_ready(entry)
	var tier: int = int(entry.get("tier", 1))

	var card: PanelContainer = PanelContainer.new()
	card.set_meta("advancement_id", advancement_id)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var border_color: Color = Color("7bb88a") if complete else (Color("776b3f") if tier == current_tier else Color("42515a"))
	card.add_theme_stylebox_override("panel", _style_box(Color("151d24"), border_color, 14, 1))
	parent.add_child(card)

	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)

	var title: Label = Label.new()
	var state_text: String = "READY" if complete else ("CURRENT" if tier == current_tier else "READY AHEAD")
	title.text = "%s  |  TIER %d\n%s" % [state_text, tier, str(entry.get("title", "Milestone"))]
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 19)
	box.add_child(title)

	var detail: Label = Label.new()
	detail.text = str(entry.get("description", ""))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(detail)

	var progress: ProgressBar = ProgressBar.new()
	progress.min_value = 0
	progress.max_value = target
	progress.value = current_value
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(0, 14)
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(progress)

	var progress_text: Label = Label.new()
	progress_text.text = "%d / %d" % [current_value, target]
	progress_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_text.modulate = Color("9fb0ba")
	box.add_child(progress_text)

	for requirement_variant: Variant in entry.get("requires", []):
		if not (requirement_variant is Dictionary):
			continue
		var requirement: Dictionary = requirement_variant as Dictionary
		var needed: int = int(requirement.get("target", 1))
		var progress_value: int = mini(needed, _advancement_value(requirement))
		var requirement_label: Label = Label.new()
		requirement_label.text = "%s %s: %d / %d" % ["[x]" if progress_value >= needed else "[ ]", str(requirement.get("label", "Extra goal")), progress_value, needed]
		requirement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		requirement_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(requirement_label)

	var reward: Label = Label.new()
	reward.text = "REWARD  |  %s" % _advancement_reward_text(entry)
	reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward.modulate = Color("8ed6a3") if complete else Color("7f8d96")
	box.add_child(reward)

	var claim: Button = Button.new()
	claim.custom_minimum_size = Vector2(0, 48)
	claim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	claim.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if complete:
		claim.text = "CLAIM REWARD"
		claim.pressed.connect(_claim_advancement.bind(advancement_id))
	else:
		claim.text = "IN PROGRESS"
		claim.disabled = true
	box.add_child(claim)
'''
    text=replace_func(text,"_add_advancement_roadmap_milestone",milestone)

    required=[
        'func _constrain_advancement_phone_width(node: Node) -> void:',
        'rank.text = "CAREER ROADMAP\\n%s"',
        'claim_all.text = "CLAIM ALL (%d)"',
        'title.text = "%s  |  TIER %d\\n%s"',
        'phone_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED',
        '"id": "bench_three"',
        '"id": "dealer_storage_max"',
        'CHAPTER 4 PREVIEW - OUTGROWING THE APARTMENT',
        'hidden_stash_interior_root.position = StorageVault.ANCHOR + Vector3(-0.36, 0.0, 0.0)',
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
    'func _constrain_advancement_phone_width(node: Node) -> void:',
    'rank.text = "CAREER ROADMAP\\n%s"',
    'claim_all.text = "CLAIM ALL (%d)"',
    'title.text = "%s  |  TIER %d\\n%s"',
    'phone_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED',
]:
    if needle not in main: raise SystemExit("packed width verify "+needle)
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
meta["advancement_phone_width_fix"]="Advancements no longer increases phone/game width; roadmap controls wrap within the existing phone viewport and horizontal scrolling stays disabled"
meta["advancement_header_compaction"]="Career roadmap and milestone titles split across lines; claim-all label shortened"
meta["runtime_payload"]="cloudtest60 PCK with advancement phone width containment"
VERSION.write_text(json.dumps(meta,indent=2)+"\n")

BUILD.write_text(
    "AFewBuds Cloud Test\n"
    "Game build: 0.7.9-beta.19\n"
    f"Web release: {RELEASE}\n"
    "Runtime: cloudtest59 roadmap + fixed-width Advancements phone layout\n"
)

print("Built",RELEASE,len(packed))

# finalized cloudtest60 advancement phone width deployment marker
