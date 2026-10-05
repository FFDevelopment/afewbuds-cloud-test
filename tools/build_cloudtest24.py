from pathlib import Path
import struct, hashlib, re, json, collections

PCK=Path("index-cloudtest10.pck")
HTML=Path("index.html")
VERSION=Path("version.json")
BUILD=Path("BUILD_VERSION.txt")
RELEASE="0.7.9-beta.19-cloudtest.63"
PACK_URL="index-cloudtest10.pck?build=63"

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

    # Persisted Chapter 4 story/property handoff state.
    var_anchor='''var phone_text_messages: Array[Dictionary] = []
var phone_text_unread: int = 0
'''
    var_add='''var phone_text_messages: Array[Dictionary] = []
var phone_text_unread: int = 0
var chapter_four_story_stage: int = 0
var property_offer_unlocked: bool = false
'''
    if "var chapter_four_story_stage:" not in text:
        if var_anchor not in text: raise SystemExit("chapter4 variable anchor missing")
        text=text.replace(var_anchor,var_add,1)

    # Add Chapter 4 expansion milestones before the Property/lifestyle group.
    expansion_entries='''\t{"id": "c4_apartment_capacity", "category": "Expansion", "tier": 1, "title": "Apartment at Capacity", "description": "Fill the apartment grow room and install the top apartment bagging bench.", "state": "chapter_four_apartment_ready", "target": 1, "reward_cash": 0, "reward_xp": 150, "reward_rep": 10},
\t{"id": "c4_distribution_network", "category": "Expansion", "tier": 2, "title": "Distribution Network", "description": "Max Dealer Storage and prove the dealer side can move volume.", "state": "chapter_four_distribution_ready", "target": 1, "reward_cash": 0, "reward_xp": 200, "reward_rep": 12},
\t{"id": "c4_crew_operations", "category": "Expansion", "tier": 3, "title": "Crew Operations", "description": "Run AFewBuds with a real crew instead of doing every job yourself.", "state": "chapter_four_crew_ready", "target": 1, "reward_cash": 0, "reward_xp": 250, "reward_rep": 15},
\t{"id": "c4_demand_pressure", "category": "Expansion", "tier": 4, "title": "Demand Outgrows the Space", "description": "Build enough revenue, reputation and client reach that the apartment is holding the business back.", "state": "chapter_four_demand_ready", "target": 1, "reward_cash": 0, "reward_xp": 300, "reward_rep": 20},
\t{"id": "c4_expansion_ready", "category": "Expansion", "tier": 5, "title": "Expansion Ready", "description": "Prove the operation is mature enough to support a larger property.", "state": "chapter_four_complete", "target": 1, "reward_cash": 0, "reward_xp": 500, "reward_rep": 25, "reward_unlock": "PROPERTY OPPORTUNITY"},
'''
    if '"id": "c4_apartment_capacity"' not in text:
        prop_anchor='\t{"id": "lights_out", "category": "Property",'
        pos=text.find(prop_anchor)
        if pos<0: raise SystemExit("property advancement anchor missing")
        text=text[:pos]+expansion_entries+"\n"+text[pos:]

    # Chapter 4 story state helpers and one-time phone story beats.
    story_helpers=r'''func _story_chapter_four_apartment_complete() -> bool:
	return _story_chapter_three_complete() \
		and grow_tent_count >= 3 \
		and bagging_level >= 3

func _story_chapter_four_distribution_complete() -> bool:
	return _story_chapter_four_apartment_complete() \
		and dealer_locker_level >= 4 \
		and int(advancement_stats.get("dealer_sales", 0)) >= 20

func _story_chapter_four_crew_complete() -> bool:
	return _story_chapter_four_distribution_complete() \
		and _staff_count() >= 3 \
		and int(advancement_stats.get("worker_tasks", 0)) >= 50

func _story_chapter_four_demand_complete() -> bool:
	return _story_chapter_four_crew_complete() \
		and lifetime_revenue >= 15000 \
		and reputation >= 175 \
		and int(advancement_stats.get("customers_known", 0)) >= 12

func _story_chapter_four_operation_complete() -> bool:
	return _story_chapter_four_demand_complete() \
		and grower_level >= 10 \
		and int(advancement_stats.get("hybrids_created", 0)) >= 3 \
		and int(advancement_stats.get("grams_stored", 0)) >= 250

func _story_chapter_four_complete() -> bool:
	return _story_chapter_four_operation_complete()

func _chapter_four_target_story_stage() -> int:
	if not _story_chapter_three_complete():
		return 0
	var target: int = 1
	if _story_chapter_four_apartment_complete():
		target = 2
	if _story_chapter_four_distribution_complete():
		target = 3
	if _story_chapter_four_crew_complete():
		target = 4
	if _story_chapter_four_demand_complete():
		target = 5
	if _story_chapter_four_complete():
		target = 6
	return target

func _chapter_four_append_story_text(body: String) -> void:
	if body.is_empty():
		return
	phone_text_messages.append({
		"sender": "Rod",
		"body": body,
		"day": game_day,
		"time": _format_game_clock(),
		"read": false
	})
	while phone_text_messages.size() > 60:
		phone_text_messages.pop_front()
	phone_text_unread += 1

func _sync_chapter_four_story() -> bool:
	var target_stage: int = _chapter_four_target_story_stage()
	if target_stage <= chapter_four_story_stage:
		if _story_chapter_four_complete() and not property_offer_unlocked:
			property_offer_unlocked = true
			return true
		return false

	var changed: bool = false
	while chapter_four_story_stage < target_stage:
		chapter_four_story_stage += 1
		changed = true
		match chapter_four_story_stage:
			1:
				_chapter_four_append_story_text("You made it through all that pressure and this apartment is starting to feel real small. Keep building the operation, but start thinking bigger.")
			2:
				_chapter_four_append_story_text("Three tents and that new bench? Every wall in that place has a job now. You are officially out of room.")
			3:
				_chapter_four_append_story_text("Dealer Storage is maxed and the crew is moving product. This is bigger than people coming to your door now.")
			4:
				_chapter_four_append_story_text("You are running a crew now, not just doing everything yourself. The apartment is becoming the bottleneck.")
			5:
				_chapter_four_append_story_text("The numbers do not lie. Too many customers, too much product, too much traffic for one apartment. Finish proving the operation can handle a real move.")
			6:
				property_offer_unlocked = true
				_chapter_four_append_story_text("I got a line on a house that can actually fit this operation. You can rent it, lease it to own, or buy it outright. This is the next move.")
	return changed
'''
    text=upsert_before(text,"_story_chapter_four_apartment_complete",story_helpers,"_story_checkmark")

    # Story/task screen now contains a real Chapter 4.
    story_ui=r'''func _build_story_progress_section() -> void:
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
	var chapter_four_done: bool = _story_chapter_four_complete()

	var chapter_title: Label = Label.new()
	if not chapter_one_done:
		chapter_title.text = "STORY\nCHAPTER 1 - STARTING SMALL"
	elif not chapter_two_done:
		chapter_title.text = "STORY\nCHAPTER 2 - BUILDING A NAME"
	elif not chapter_three_done:
		chapter_title.text = "STORY\nCHAPTER 3 - GETTING NOTICED"
	elif not chapter_four_done:
		chapter_title.text = "STORY\nCHAPTER 4 - OUTGROWING THE APARTMENT"
	else:
		chapter_title.text = "STORY\nCHAPTER 4 COMPLETE\nEXPANSION OPPORTUNITY UNLOCKED"
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
	elif not chapter_three_done:
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
		objectives.text += "\n\nUNLOCK: Chapter 4 - Outgrowing the Apartment."
	elif not chapter_four_done:
		objectives.text = "\n".join([
			_story_checkmark(_story_chapter_four_apartment_complete(), "Apartment at Capacity - 3 grow tents + Bagging Bench III"),
			_story_checkmark(_story_chapter_four_distribution_complete(), "Distribution Network - Dealer Storage IV + 20 dealer sales"),
			_story_checkmark(_story_chapter_four_crew_complete(), "Crew Operations - 3 staff + 50 production-worker tasks"),
			_story_checkmark(_story_chapter_four_demand_complete(), "Demand Outgrows the Space - $15,000 revenue + 175 reputation + 12 known customers"),
			_story_checkmark(_story_chapter_four_operation_complete(), "Proven Operation - Grower 10 + 3 hybrid batches + 250g moved into storage")
		])
		objectives.text += "\n\nFINALE: prove the apartment can no longer support the operation and unlock your first house opportunity."
	else:
		objectives.text = "✓ Apartment operation maxed\n✓ Distribution proven\n✓ Crew proven\n✓ Demand proven\n✓ Operation proven\n\nEXPANSION OPPORTUNITY UNLOCKED\nRod found a residential operation property with RENT, LEASE-TO-OWN and PURCHASE options.\n\nThe property becomes the next major AFewBuds progression step."

	objectives.custom_minimum_size.x = 0.0
	objectives.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objectives.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_box.add_child(objectives)
'''
    text=replace_func(text,"_build_story_progress_section",story_ui)

    # Advancement story label follows Chapter 4.
    label_func=r'''func _advancement_story_label() -> String:
	if not _story_chapter_one_complete():
		return "CHAPTER 1 - STARTING SMALL"
	if not _story_chapter_two_complete():
		return "CHAPTER 2 - BUILDING A NAME"
	if not _story_chapter_three_complete():
		return "CHAPTER 3 - GETTING NOTICED"
	if not _story_chapter_four_complete():
		return "CHAPTER 4 - OUTGROWING THE APARTMENT"
	return "CHAPTER 4 COMPLETE  |  EXPANSION OPPORTUNITY UNLOCKED"
'''
    text=replace_func(text,"_advancement_story_label",label_func)

    # Expansion roadmap lane remains hidden until Chapter 3 is complete.
    lane_match=pat("_advancement_lane_order").search(text)
    if not lane_match: raise SystemExit("lane order missing")
    lane_block=lane_match.group(0)
    lane_block=re.sub(r'return \[[^\n]+\]', 'return ["Growing", "Production", "Sales", "Dealers", "Business", "Genetics", "Heat / Street", "Expansion", "Property"]', lane_block, count=1)
    text=text[:lane_match.start()]+lane_block.rstrip()+"\n\n"+text[lane_match.end():]

    adv_build=pat("_build_advancements_app").search(text)
    if not adv_build: raise SystemExit("advancements app missing")
    adv_block=adv_build.group(0)
    loop_anchor='''\tfor lane_name: String in _advancement_lane_order():
\t\tvar lane_total: int = 0
'''
    loop_repl='''\tfor lane_name: String in _advancement_lane_order():
\t\tif lane_name == "Expansion" and not _story_chapter_three_complete():
\t\t\tcontinue
\t\tvar lane_total: int = 0
'''
    if 'lane_name == "Expansion"' not in adv_block:
        if loop_anchor not in adv_block: raise SystemExit("adv lane loop anchor missing")
        adv_block=adv_block.replace(loop_anchor,loop_repl,1)
    text=text[:adv_build.start()]+adv_block.rstrip()+"\n\n"+text[adv_build.end():]

    # Chapter 4 states become normal advancement values.
    value_match=pat("_advancement_value").search(text)
    if not value_match: raise SystemExit("advancement value missing")
    value_block=value_match.group(0)
    state_anchor='''\tif state_name == "ventilation_installed":
\t\treturn 1 if ventilation_installed else 0
'''
    state_add='''\tif state_name == "ventilation_installed":
\t\treturn 1 if ventilation_installed else 0
\tif state_name == "chapter_four_apartment_ready":
\t\treturn 1 if _story_chapter_four_apartment_complete() else 0
\tif state_name == "chapter_four_distribution_ready":
\t\treturn 1 if _story_chapter_four_distribution_complete() else 0
\tif state_name == "chapter_four_crew_ready":
\t\treturn 1 if _story_chapter_four_crew_complete() else 0
\tif state_name == "chapter_four_demand_ready":
\t\treturn 1 if _story_chapter_four_demand_complete() else 0
\tif state_name == "chapter_four_complete":
\t\treturn 1 if _story_chapter_four_complete() else 0
'''
    if 'state_name == "chapter_four_complete"' not in value_block:
        if state_anchor not in value_block: raise SystemExit("adv state anchor missing")
        value_block=value_block.replace(state_anchor,state_add,1)
    text=text[:value_match.start()]+value_block.rstrip()+"\n\n"+text[value_match.end():]

    # Show named unlock rewards such as the property opportunity.
    reward_match=pat("_advancement_reward_text").search(text)
    if not reward_match: raise SystemExit("reward text missing")
    reward_block=reward_match.group(0)
    if 'reward_unlock' not in reward_block:
        anchor='''\tvar reward_recipe: String = str(entry.get("reward_recipe", ""))
'''
        repl='''\tvar reward_recipe: String = str(entry.get("reward_recipe", ""))
\tvar reward_unlock: String = str(entry.get("reward_unlock", ""))
'''
        if anchor not in reward_block: raise SystemExit("reward vars anchor missing")
        reward_block=reward_block.replace(anchor,repl,1)
        tail='''\tif not reward_recipe.is_empty():
\t\tparts.append("GENETICS RECIPE: %s" % reward_recipe)
\treturn "   |   ".join(parts)
'''
        tail_repl='''\tif not reward_recipe.is_empty():
\t\tparts.append("GENETICS RECIPE: %s" % reward_recipe)
\tif not reward_unlock.is_empty():
\t\tparts.append("UNLOCK: %s" % reward_unlock)
\treturn "   |   ".join(parts)
'''
        if tail not in reward_block: raise SystemExit("reward tail anchor missing")
        reward_block=reward_block.replace(tail,tail_repl,1)
    text=text[:reward_match.start()]+reward_block.rstrip()+"\n\n"+text[reward_match.end():]

    # Sync story state before any phone app renders, then persist only on changes.
    refresh_match=pat("_refresh_phone").search(text)
    if not refresh_match: raise SystemExit("refresh phone missing")
    refresh_block=refresh_match.group(0)
    refresh_anchor='''\tif phone_list == null:
\t\treturn
'''
    refresh_repl='''\tif phone_list == null:
\t\treturn
\tvar chapter_four_changed: bool = _sync_chapter_four_story()
\tif chapter_four_changed:
\t\t_save_game()
'''
    if 'chapter_four_changed' not in refresh_block:
        if refresh_anchor not in refresh_block: raise SystemExit("refresh anchor missing")
        refresh_block=refresh_block.replace(refresh_anchor,refresh_repl,1)
    text=text[:refresh_match.start()]+refresh_block.rstrip()+"\n\n"+text[refresh_match.end():]

    # Save/load migration.
    save_match=pat("_save_game").search(text)
    if not save_match: raise SystemExit("save missing")
    save_block=save_match.group(0)
    save_anchor='''\t\t"advancement_stats": advancement_stats,
\t\t"advancement_claimed": advancement_claimed
'''
    save_repl='''\t\t"advancement_stats": advancement_stats,
\t\t"advancement_claimed": advancement_claimed,
\t\t"chapter_four_story_stage": chapter_four_story_stage,
\t\t"property_offer_unlocked": property_offer_unlocked
'''
    if '"chapter_four_story_stage": chapter_four_story_stage' not in save_block:
        if save_anchor not in save_block: raise SystemExit("save chapter4 anchor missing")
        save_block=save_block.replace(save_anchor,save_repl,1)
    text=text[:save_match.start()]+save_block.rstrip()+"\n\n"+text[save_match.end():]

    load_match=pat("_load_game").search(text)
    if not load_match: raise SystemExit("load missing")
    load_block=load_match.group(0)
    load_anchor='''\tvar loaded_advancement_claimed: Variant = data.get("advancement_claimed", advancement_claimed)
\tif loaded_advancement_claimed is Dictionary:
\t\tadvancement_claimed = loaded_advancement_claimed as Dictionary
'''
    load_repl='''\tvar loaded_advancement_claimed: Variant = data.get("advancement_claimed", advancement_claimed)
\tif loaded_advancement_claimed is Dictionary:
\t\tadvancement_claimed = loaded_advancement_claimed as Dictionary
\tchapter_four_story_stage = clampi(int(data.get("chapter_four_story_stage", chapter_four_story_stage)), 0, 6)
\tproperty_offer_unlocked = bool(data.get("property_offer_unlocked", property_offer_unlocked))
'''
    if 'data.get("chapter_four_story_stage"' not in load_block:
        if load_anchor not in load_block: raise SystemExit("load chapter4 anchor missing")
        load_block=load_block.replace(load_anchor,load_repl,1)
    text=text[:load_match.start()]+load_block.rstrip()+"\n\n"+text[load_match.end():]

    required=[
        'var chapter_four_story_stage: int = 0',
        'var property_offer_unlocked: bool = false',
        'func _story_chapter_four_complete() -> bool:',
        'func _sync_chapter_four_story() -> bool:',
        '"sender": "Rod"',
        '"id": "c4_apartment_capacity"',
        '"id": "c4_expansion_ready"',
        'return ["Growing", "Production", "Sales", "Dealers", "Business", "Genetics", "Heat / Street", "Expansion", "Property"]',
        'lane_name == "Expansion" and not _story_chapter_three_complete()',
        'CHAPTER 4 - OUTGROWING THE APARTMENT',
        'EXPANSION OPPORTUNITY UNLOCKED',
        '"chapter_four_story_stage": chapter_four_story_stage',
        'data.get("chapter_four_story_stage"',
        'reward_unlock',
        '# Task uses the same fixed-width containment as the Advancements page.',
        'phone_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED',
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
    'func _story_chapter_four_complete() -> bool:',
    '"id": "c4_expansion_ready"',
    '"sender": "Rod"',
    'EXPANSION OPPORTUNITY UNLOCKED',
    '"chapter_four_story_stage": chapter_four_story_stage',
]:
    if needle not in main: raise SystemExit("packed ch4 verify "+needle)
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
meta["chapter4"]="Chapter 4 - Outgrowing the Apartment is active after Chapter 3"
meta["chapter4_milestones"]="Apartment at Capacity; Distribution Network; Crew Operations; Demand Outgrows the Space; Expansion Ready"
meta["chapter4_story"]="Rod sends one-time progression texts as the apartment operation outgrows its space"
meta["chapter4_finale"]="Completing Chapter 4 persistently unlocks the first property opportunity for the upcoming house system"
meta["expansion_lane"]="New Advancements lane appears only after Chapter 3 is complete"
meta["runtime_payload"]="cloudtest63 PCK with complete Chapter 4 storyline/milestones and property-offer handoff state"
VERSION.write_text(json.dumps(meta,indent=2)+"\n")

BUILD.write_text(
    "AFewBuds Cloud Test\n"
    "Game build: 0.7.9-beta.19\n"
    f"Web release: {RELEASE}\n"
    "Runtime: Chapter 4 Outgrowing the Apartment + Expansion milestones + Rod story texts + saved property offer unlock\n"
)

print("Built",RELEASE,len(packed))
