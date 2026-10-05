from pathlib import Path
import struct, hashlib, re, json, collections

PCK=Path("index-cloudtest10.pck")
HTML=Path("index.html")
VERSION=Path("version.json")
BUILD=Path("BUILD_VERSION.txt")
RELEASE="0.7.9-beta.19-cloudtest.59"
PACK_URL="index-cloudtest10.pck?build=59"

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

    # -------- Add milestones for systems that now exist in-game --------
    bench_anchor='''\t{"id": "bench_two", "category": "Processing", "tier": 2, "title": "Better Workbench", "description": "Upgrade the bagging station to Level 2.", "state": "bagging_level", "target": 2, "reward_cash": 150, "reward_xp": 60, "reward_rep": 3, "requires": [{"metric": "bags_sealed", "target": 15, "label": "Bags sealed"}]},'''
    bench_add='''\t{"id": "bench_three", "category": "Processing", "tier": 3, "title": "Production Station", "description": "Install Bagging Bench III and move into continuous production.", "state": "bagging_level", "target": 3, "reward_cash": 250, "reward_xp": 125, "reward_rep": 7, "requires": [{"metric": "bags_sealed", "target": 30, "label": "Bags sealed"}]},
\t{"id": "production_volume", "category": "Processing", "tier": 3, "title": "Production Run", "description": "Build a real production rhythm and move 250g of finished product into storage.", "metric": "grams_stored", "target": 250, "reward_cash": 350, "reward_xp": 150, "reward_rep": 8, "requires": [{"metric": "grams_trimmed", "target": 150, "label": "Grams trimmed"}, {"metric": "bags_sealed", "target": 60, "label": "Bags sealed"}]},'''
    if '"id": "bench_three"' not in text:
        if bench_anchor not in text: raise SystemExit("bench_two advancement anchor missing")
        text=text.replace(bench_anchor,bench_anchor+"\n"+bench_add,1)

    dealer_anchor='''\t{"id": "first_dealer_sale", "category": "Sales", "tier": 2, "title": "First Delegated Sale", "description": "Have a hired dealer complete a sale with an eligible known client.", "metric": "dealer_sales", "target": 1, "reward_cash": 50, "reward_xp": 60, "reward_rep": 4},'''
    dealer_t1='''\t{"id": "dealer_storage_one", "category": "Dealers", "tier": 1, "title": "Stock the Team", "description": "Unlock Dealer Storage and give your dealer network dedicated inventory.", "state": "dealer_locker_level", "target": 1, "reward_cash": 50, "reward_xp": 40, "reward_rep": 2},'''
    if '"id": "dealer_storage_one"' not in text:
        if dealer_anchor not in text: raise SystemExit("first dealer sale advancement anchor missing")
        text=text.replace(dealer_anchor,dealer_t1+"\n"+dealer_anchor,1)

    dealer5_anchor='''\t{"id": "dealer_five", "category": "Business", "tier": 2, "title": "Delegating", "description": "Have dealers complete 5 sales to known clients.", "metric": "dealer_sales", "target": 5, "reward_cash": 75, "reward_xp": 100, "reward_rep": 7},'''
    dealer_more='''\t{"id": "dealer_fifteen", "category": "Dealers", "tier": 3, "title": "Street Coverage", "description": "Have dealers complete 15 total sales.", "metric": "dealer_sales", "target": 15, "reward_cash": 150, "reward_xp": 160, "reward_rep": 10},
\t{"id": "dealer_storage_premium", "category": "Dealers", "tier": 3, "title": "Secure Distribution", "description": "Upgrade Dealer Storage to Level III and install the premium cabinet.", "state": "dealer_locker_level", "target": 3, "reward_cash": 200, "reward_xp": 140, "reward_rep": 8, "requires": [{"metric": "dealer_sales", "target": 10, "label": "Dealer sales"}]},
\t{"id": "dealer_storage_max", "category": "Dealers", "tier": 4, "title": "Fully Stocked Network", "description": "Max Dealer Storage at Level IV.", "state": "dealer_locker_level", "target": 4, "reward_cash": 250, "reward_xp": 220, "reward_rep": 12, "requires": [{"metric": "dealer_sales", "target": 30, "label": "Dealer sales"}]},'''
    if '"id": "dealer_fifteen"' not in text:
        if dealer5_anchor not in text: raise SystemExit("dealer_five advancement anchor missing")
        text=text.replace(dealer5_anchor,dealer5_anchor+"\n"+dealer_more,1)

    # -------- Roadmap helpers --------
    helpers=r'''func _advancement_lane_name(entry: Dictionary) -> String:
	var advancement_id: String = str(entry.get("id", ""))
	if advancement_id in ["first_dealer_sale", "dealer_five", "dealer_twentyfive"]:
		return "Dealers"
	var category_name: String = str(entry.get("category", ""))
	match category_name:
		"Processing":
			return "Production"
		"Customers":
			return "Sales"
		"Heat":
			return "Heat / Street"
		_:
			return category_name

func _advancement_lane_order() -> Array[String]:
	return ["Growing", "Production", "Sales", "Dealers", "Business", "Genetics", "Heat / Street", "Property"]

func _advancement_lane_current_tier(lane_name: String) -> int:
	var current_tier: int = 999
	for entry: Dictionary in advancement_catalog:
		if _advancement_lane_name(entry) != lane_name:
			continue
		var advancement_id: String = str(entry.get("id", ""))
		if bool(advancement_claimed.get(advancement_id, false)):
			continue
		current_tier = mini(current_tier, int(entry.get("tier", 1)))
	return -1 if current_tier == 999 else current_tier

func _advancement_lane_next_tier(lane_name: String, current_tier: int) -> int:
	var next_tier: int = 999
	for entry: Dictionary in advancement_catalog:
		if _advancement_lane_name(entry) != lane_name:
			continue
		var advancement_id: String = str(entry.get("id", ""))
		if bool(advancement_claimed.get(advancement_id, false)):
			continue
		var entry_tier: int = int(entry.get("tier", 1))
		if entry_tier > current_tier:
			next_tier = mini(next_tier, entry_tier)
	return -1 if next_tier == 999 else next_tier

func _advancement_story_label() -> String:
	if not _story_chapter_one_complete():
		return "CHAPTER 1 - STARTING SMALL"
	if not _story_chapter_two_complete():
		return "CHAPTER 2 - BUILDING A NAME"
	if not _story_chapter_three_complete():
		return "CHAPTER 3 - GETTING NOTICED"
	return "CHAPTER 3 COMPLETE  |  NEXT: CHAPTER 4 - OUTGROWING THE APARTMENT"

func _add_advancement_roadmap_milestone(parent: VBoxContainer, entry: Dictionary, current_tier: int) -> void:
	var advancement_id: String = str(entry.get("id", ""))
	var target: int = maxi(1, int(entry.get("target", 1)))
	var current_value: int = mini(_advancement_value(entry), target)
	var complete: bool = _advancement_is_ready(entry)
	var tier: int = int(entry.get("tier", 1))

	var card: PanelContainer = PanelContainer.new()
	card.set_meta("advancement_id", advancement_id)
	var border_color: Color = Color("7bb88a") if complete else (Color("776b3f") if tier == current_tier else Color("42515a"))
	card.add_theme_stylebox_override("panel", _style_box(Color("151d24"), border_color, 14, 1))
	parent.add_child(card)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)

	var title: Label = Label.new()
	var state_text: String = "READY" if complete else ("CURRENT" if tier == current_tier else "READY AHEAD")
	title.text = "%s  |  TIER %d  |  %s" % [state_text, tier, str(entry.get("title", "Milestone"))]
	title.add_theme_font_size_override("font_size", 19)
	box.add_child(title)

	var detail: Label = Label.new()
	detail.text = str(entry.get("description", ""))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(detail)

	var progress: ProgressBar = ProgressBar.new()
	progress.min_value = 0
	progress.max_value = target
	progress.value = current_value
	progress.show_percentage = false
	progress.custom_minimum_size.y = 14
	box.add_child(progress)

	var progress_text: Label = Label.new()
	progress_text.text = "%d / %d" % [current_value, target]
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
		box.add_child(requirement_label)

	var reward: Label = Label.new()
	reward.text = "REWARD  |  %s" % _advancement_reward_text(entry)
	reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward.modulate = Color("8ed6a3") if complete else Color("7f8d96")
	box.add_child(reward)

	var claim: Button = Button.new()
	claim.custom_minimum_size.y = 48
	if complete:
		claim.text = "CLAIM REWARD"
		claim.pressed.connect(_claim_advancement.bind(advancement_id))
	else:
		claim.text = "IN PROGRESS"
		claim.disabled = true
	box.add_child(claim)
'''
    text=upsert_before(text,"_advancement_lane_name",helpers,"_build_advancements_app")

    # -------- Replace Advancements with roadmap UI --------
    roadmap=r'''func _build_advancements_app() -> void:
	var claimed_count: int = _advancement_claimed_count()
	var ready_count: int = _advancement_ready_count()

	var summary_card: PanelContainer = PanelContainer.new()
	summary_card.add_theme_stylebox_override("panel", _style_box(Color("111920"), Color("776b3f"), 16, 2))
	phone_list.add_child(summary_card)
	var summary_box: VBoxContainer = VBoxContainer.new()
	summary_box.add_theme_constant_override("separation", 6)
	summary_card.add_child(summary_box)

	var rank: Label = Label.new()
	rank.text = "CAREER ROADMAP  |  %s" % _advancement_career_rank()
	rank.add_theme_font_size_override("font_size", 22)
	rank.modulate = Color("e4cf83")
	summary_box.add_child(rank)

	var story: Label = Label.new()
	story.text = "STORY  |  %s" % _advancement_story_label()
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.modulate = Color("c6d4da")
	summary_box.add_child(story)

	var summary: Label = Label.new()
	summary.text = "%d / %d milestones claimed   |   %d reward%s ready" % [claimed_count, advancement_catalog.size(), ready_count, "" if ready_count == 1 else "s"]
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.modulate = Color("d7c28a") if ready_count > 0 else Color("9fb0ba")
	summary_box.add_child(summary)

	var overall: ProgressBar = ProgressBar.new()
	overall.min_value = 0
	overall.max_value = maxi(1, advancement_catalog.size())
	overall.value = claimed_count
	overall.show_percentage = false
	overall.custom_minimum_size.y = 16
	summary_box.add_child(overall)

	if ready_count > 0:
		var claim_all: Button = Button.new()
		claim_all.text = "CLAIM ALL READY REWARDS (%d)" % ready_count
		claim_all.custom_minimum_size.y = 54
		claim_all.add_theme_font_size_override("font_size", 17)
		claim_all.add_theme_stylebox_override("normal", _style_box(Color("1b3324"), Color("78c98a"), 12, 2))
		claim_all.pressed.connect(_claim_all_advancements)
		summary_box.add_child(claim_all)

	var roadmap_hint: Label = Label.new()
	roadmap_hint.text = "Each lane shows your current tier and the next tier ahead. Claimed milestones stay saved but are removed from the active list. If you already completed a future goal, it appears as READY AHEAD instead of being hidden."
	roadmap_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
		lane_card.add_theme_stylebox_override("panel", _style_box(Color("131b21"), Color("37454e"), 16, 1))
		phone_list.add_child(lane_card)
		var lane_box: VBoxContainer = VBoxContainer.new()
		lane_box.add_theme_constant_override("separation", 7)
		lane_card.add_child(lane_box)

		var lane_title: Label = Label.new()
		lane_title.text = "%s   |   %d/%d" % [lane_name.to_upper(), lane_claimed, lane_total]
		lane_title.add_theme_font_size_override("font_size", 21)
		lane_title.modulate = Color("d7c28a")
		lane_box.add_child(lane_title)

		var lane_progress: ProgressBar = ProgressBar.new()
		lane_progress.min_value = 0
		lane_progress.max_value = maxi(1, lane_total)
		lane_progress.value = lane_claimed
		lane_progress.show_percentage = false
		lane_progress.custom_minimum_size.y = 12
		lane_box.add_child(lane_progress)

		var current_tier: int = _advancement_lane_current_tier(lane_name)
		if current_tier < 0:
			var mastered: Label = Label.new()
			mastered.text = "MASTERED  |  All current milestones claimed."
			mastered.modulate = Color("8ed6a3")
			lane_box.add_child(mastered)
			continue

		var focus: Label = Label.new()
		focus.text = "CURRENT FOCUS  |  TIER %d" % current_tier
		focus.modulate = Color("c6d4da")
		lane_box.add_child(focus)

		var visible_count: int = 0
		for entry: Dictionary in advancement_catalog:
			if _advancement_lane_name(entry) != lane_name:
				continue
			var advancement_id: String = str(entry.get("id", ""))
			if bool(advancement_claimed.get(advancement_id, false)):
				continue
			var entry_tier: int = int(entry.get("tier", 1))
			if entry_tier == current_tier or _advancement_is_ready(entry):
				_add_advancement_roadmap_milestone(lane_box, entry, current_tier)
				visible_count += 1

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
				preview.modulate = Color("687781")
				lane_box.add_child(preview)
'''
    text=replace_func(text,"_build_advancements_app",roadmap)

    # Task tile now describes the roadmap rather than a generic rewards bucket.
    task=r'''func _build_task_app() -> void:
	_build_story_progress_section()
	var grid: GridContainer = _phone_category_grid()
	_add_phone_app_tile(grid, "", "Advancements", "Roadmap + %d reward%s ready" % [_advancement_ready_count(), "" if _advancement_ready_count() == 1 else "s"], "advancements")
'''
    text=replace_func(text,"_build_task_app",task)

    # Dealer Storage levels can now drive roadmap milestones.
    value_match=pat("_advancement_value").search(text)
    if not value_match: raise SystemExit("_advancement_value missing")
    value_block=value_match.group(0)
    if 'if state_name == "dealer_locker_level":' not in value_block:
        anchor='''\tif state_name == "bagging_level":
\t\treturn bagging_level
'''
        if anchor not in value_block: raise SystemExit("bagging advancement state anchor missing")
        value_block=value_block.replace(anchor,anchor+'''\tif state_name == "dealer_locker_level":
\t\treturn dealer_locker_level
''',1)
    text=text[:value_match.start()]+value_block.rstrip()+"\n\n"+text[value_match.end():]

    # Chapter 3 completion now points at the agreed Chapter 4 direction without
    # pretending Chapter 4 mechanics are already active.
    story_match=pat("_build_story_progress_section").search(text)
    if not story_match: raise SystemExit("_build_story_progress_section missing")
    story_block=story_match.group(0)
    story_block=story_block.replace(
        'chapter_title.text = "STORY  |  CHAPTER 3 COMPLETE"',
        'chapter_title.text = "STORY  |  CHAPTER 3 COMPLETE  |  NEXT: OUTGROWING THE APARTMENT"',
        1
    )
    story_block=story_block.replace(
        'objectives.text += "\\n\\nNEXT: Chapter 4 - Competition. Rival pressure will build on the Heat system."',
        'objectives.text += "\\n\\nCHAPTER 4 PREVIEW - OUTGROWING THE APARTMENT\\nLarger operation • more staff/dealers • bulk production • new location.\\nPreview only for now; Chapter 4 mechanics are not active yet."',
        1
    )
    text=text[:story_match.start()]+story_block.rstrip()+"\n\n"+text[story_match.end():]

    required=[
        '"id": "bench_three"',
        '"id": "production_volume"',
        '"id": "dealer_storage_one"',
        '"id": "dealer_fifteen"',
        '"id": "dealer_storage_premium"',
        '"id": "dealer_storage_max"',
        'func _advancement_lane_name(entry: Dictionary) -> String:',
        'func _add_advancement_roadmap_milestone',
        '"CAREER ROADMAP  |  %s"',
        '"CURRENT FOCUS  |  TIER %d"',
        '"LOCKED NEXT  |  TIER %d',
        '"READY AHEAD"',
        '"Advancements", "Roadmap + %d reward%s ready"',
        'if state_name == "dealer_locker_level":',
        'CHAPTER 4 PREVIEW - OUTGROWING THE APARTMENT',
        'var plant_direct_scroll: PhoneTouchScroll',
        'hidden_stash_interior_root.position = StorageVault.ANCHOR + Vector3(-0.36, 0.0, 0.0)',
    ]
    for needle in required:
        if needle not in text:
            raise SystemExit("verify "+needle)

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
vault=sources.get("scripts/storage_vault.gd","")

for needle in [
    '"id": "bench_three"',
    '"id": "dealer_storage_one"',
    '"CAREER ROADMAP  |  %s"',
    '"LOCKED NEXT  |  TIER %d',
    'CHAPTER 4 PREVIEW - OUTGROWING THE APARTMENT',
]:
    if needle not in main: raise SystemExit("packed progression verify "+needle)
if 'const ANCHOR: Vector3 = Vector3(-4.33, 0.0, -0.30)' not in vault:
    raise SystemExit("vault anchor changed unexpectedly")
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
meta["advancement_roadmap"]="Advancements reorganized into progression lanes with current-tier focus, ready-ahead surfacing, lane completion, and locked-next preview"
meta["advancement_lanes"]="Growing, Production, Sales, Dealers, Business, Genetics, Heat / Street, Property"
meta["advancement_new_milestones"]="Bagging Bench III / production volume plus Dealer Storage and dealer-network progression"
meta["chapter4_preview"]="Chapter 3 completion now previews Chapter 4: Outgrowing the Apartment without enabling unfinished mechanics"
meta["runtime_payload"]="cloudtest59 PCK with advancement roadmap phase 1"
VERSION.write_text(json.dumps(meta,indent=2)+"\n")

BUILD.write_text(
    "AFewBuds Cloud Test\n"
    "Game build: 0.7.9-beta.19\n"
    f"Web release: {RELEASE}\n"
    "Runtime: advancement roadmap phase 1 + new Production/Dealer milestones + Chapter 4 preview\n"
)

print("Built",RELEASE,len(packed))

# finalized cloudtest59 advancement roadmap deployment marker
