"""Build .81 from the checked .63 runtime, preserving all existing pack entries."""
from pathlib import Path
import struct, hashlib, json, re, base64
ROOT=Path(__file__).resolve().parent.parent
SOURCE=ROOT/'index-cloudtest10.pck'
TARGET=ROOT/'index-cloudtest88.pck'

def parse(blob):
    assert blob[:4]==b'GDPC'
    fb,do=struct.unpack_from('<QQ',blob,24)
    count=struct.unpack_from('<I',blob,do)[0]; pos=do+4; entries=[]
    for _ in range(count):
        plen=struct.unpack_from('<I',blob,pos)[0];pos+=4
        name=blob[pos:pos+plen].rstrip(b'\0').decode();pos+=plen
        off,size=struct.unpack_from('<QQ',blob,pos);pos+=16
        digest=blob[pos:pos+16];pos+=16
        flags=struct.unpack_from('<I',blob,pos)[0];pos+=4
        data=blob[fb+off:fb+off+size]
        assert hashlib.md5(data).digest()==digest,name
        entries.append([name,data,flags])
    return fb,entries

def rebuild(blob,fb,entries):
    out=bytearray(blob[:fb]);directory=[]
    for name,data,flags in entries:
        out.extend(b'\0'*(-len(out)%32));off=len(out)-fb
        out.extend(data);directory.append((name,off,len(data),hashlib.md5(data).digest(),flags))
    out.extend(b'\0'*(-len(out)%32));struct.pack_into('<Q',out,32,len(out));out.extend(struct.pack('<I',len(directory)))
    for name,off,size,digest,flags in directory:
        raw=name.encode();raw+=b'\0'*(-len(raw)%4)
        out.extend(struct.pack('<I',len(raw))+raw+struct.pack('<QQ',off,size)+digest+struct.pack('<I',flags))
    return bytes(out)

def patch(text):
    def once(a,b):
        nonlocal text
        assert text.count(a)==1,repr(a)
        text=text.replace(a,b,1)
    once('extends Node3D','extends Node3D\n\nvar neighborhood: Node3D')
    once('\t_build_audio_players()','\t_build_audio_players()\n\tneighborhood = load("res://scripts/neighborhood.gd").new()\n\tadd_child(neighborhood)\n\tneighborhood.setup(self)')
    once('func _input(event: InputEvent) -> void:\n','func _input(event: InputEvent) -> void:\n\tif neighborhood != null and neighborhood.active and not _any_modal_open() and not daily_report_pending:\n\t\tneighborhood.handle_input(event)\n\t\treturn\n')
    once('func _refresh_navigation_ui() -> void:\n','func _refresh_navigation_ui() -> void:\n\tif neighborhood != null and neighborhood.active:\n\t\tneighborhood.refresh_controls()\n\t\treturn\n')
    once('func _context_action() -> void:\n','func _context_action() -> void:\n\tif current_view == "door" and not customer_waiting and neighborhood != null:\n\t\tneighborhood.leave_apartment()\n\t\treturn\n')
    once('\t\t\telse:\n\t\t\t\tcontextual_button.text = "LOOK THROUGH PEEPHOLE"','\t\t\telse:\n\t\t\t\tcontextual_button.text = "OPEN DOOR & WALK OUTSIDE"')
    assert text.count('\tphone_text_unread += 1')==2
    text=text.replace('\tphone_text_unread += 1','\tphone_text_unread += 1\n\tif neighborhood != null:\n\t\tneighborhood.play_text()')
    once('\tvar knock_stream: AudioStream = load("res://assets/audio/door_knock.wav") as AudioStream','\tvar knock_stream: AudioStreamMP3 = AudioStreamMP3.new()\n\tknock_stream.data = FileAccess.get_file_as_bytes("res://assets/audio/door_knock_soft.mp3")')
    once('\tknock_player.volume_db = -1.5','\tknock_player.volume_db = -10.0')
    # Dealer closeout notifications are texts, not someone knocking at the door.
    once('\t\tif dealer_count_report > 0 and knock_player != null and not session_paused:\n\t\t\tknock_player.play()', '\t\tif dealer_count_report > 0 and neighborhood != null and not session_paused:\n\t\t\tneighborhood.play_text()')
    once('func _go_to_waiting_customer() -> void:\n','func _go_to_waiting_customer() -> void:\n\tif neighborhood != null and neighborhood.active:\n\t\tstatus_label.text = "Walk back to your apartment entrance to answer the door."\n\t\treturn\n')
    once('\t_add_box("FrontWall", Vector3(0, 2.15, 6.0), Vector3(10.2, 4.3, 0.18), Color("c2beb5"), 0.94, false, "res://assets/textures/painted_wall.png", Vector3(3.0, 2.0, 1.0))', '\t_add_box("FrontWallL", Vector3(-3.075, 2.15, 6.0), Vector3(4.05, 4.3, 0.18), Color("c2beb5"), 0.94, false, "res://assets/textures/painted_wall.png")\n\t_add_box("FrontWallR", Vector3(3.075, 2.15, 6.0), Vector3(4.05, 4.3, 0.18), Color("c2beb5"), 0.94, false, "res://assets/textures/painted_wall.png")\n\t_add_box("FrontWallHeader", Vector3(0, 3.705, 6.0), Vector3(2.1, 1.27, 0.18), Color("c2beb5"), 0.94)')
    return text

def patch_clients(text):
    def once(a,b):
        nonlocal text
        assert text.count(a)==1,repr(a)
        text=text.replace(a,b,1)
    once('\tactive_request = {"product": requested, "qty": qty}\n\tcustomer_waiting = true', '\tactive_request = {"product": requested, "qty": qty}\n\tif neighborhood != null and neighborhood.client_visits.route_arrival():\n\t\treturn\n\tcustomer_waiting = true')
    once('func _customer_arrives() -> void:\n\tif _simulation_blocked():\n\t\treturn\n\tif customer_waiting:\n\t\treturn', 'func _customer_arrives() -> void:\n\tif _simulation_blocked():\n\t\treturn\n\tif customer_waiting:\n\t\treturn\n\tif neighborhood != null and neighborhood.client_visits.reserve_slot():\n\t\treturn')
    once('\t\t\tbox.add_child(message)', '\t\t\tbox.add_child(message)\n\t\t\tif neighborhood != null:\n\t\t\t\tneighborhood.client_visits.append_replies(box,msg,index)')
    once('\trow.add_child(door_alert_button)', '\trow.add_child(door_alert_button)\n\tdoor_alert_button.hide()')
    once('\tknock_banner.visible = show', '\tshow = show and (neighborhood == null or neighborhood.client_visits.is_home())\n\tknock_banner.visible = show')
    once('func _handle_door_alert_pointer(event: InputEvent) -> bool:\n\tif door_alert_button == null:', 'func _handle_door_alert_pointer(event: InputEvent) -> bool:\n\tif door_alert_button == null or not door_alert_button.is_visible_in_tree():')
    once('func _play_door_knock() -> void:\n', 'func _play_door_knock() -> void:\n\tif neighborhood != null and not neighborhood.client_visits.is_home():\n\t\treturn\n')
    once('func _start_reeves_door_visit(reason: String) -> void:\n\tif _simulation_blocked():\n\t\treturn', 'func _start_reeves_door_visit(reason: String) -> void:\n\tif _simulation_blocked():\n\t\treturn\n\tif neighborhood != null and not neighborhood.client_visits.is_home():\n\t\treeves_visit_pending = true\n\t\treeves_visit_reason = reason\n\t\treturn')
    text=text.replace('Check the front door  |  %ds left','Walk to the front door  |  %ds left')
    once('var neighborhood: Node3D','var neighborhood: Node3D\nvar house_control_state: Dictionary = {}')
    once('\t\t"phone_text_messages": phone_text_messages,','\t\t"house_control_state": house_control_state,\n\t\t"phone_text_messages": phone_text_messages,')
    once('\tvar loaded_text_messages: Variant = data.get("phone_text_messages", [])','\tvar saved_house_controls: Variant = data.get("house_control_state", {})\n\tif saved_house_controls is Dictionary: house_control_state = saved_house_controls.duplicate(true)\n\tvar loaded_text_messages: Variant = data.get("phone_text_messages", [])')
    old_wall='\t_add_box("FrontWallL", Vector3(-3.075, 2.15, 6.0), Vector3(4.05, 4.3, 0.18), Color("c2beb5"), 0.94, false, "res://assets/textures/painted_wall.png")'
    walls=[]
    for name,pos,size in [('FrontWindowLeft',(-4.81,2.15,6.0),(0.58,4.3,0.18)),('FrontWindowRight',(-1.885,2.15,6.0),(1.67,4.3,0.18)),('FrontWindowBottom',(-3.62,0.755,6.0),(1.8,1.51,0.18)),('FrontWindowTop',(-3.62,3.545,6.0),(1.8,1.51,0.18))]:
        walls.append(f'\t_add_box("{name}", Vector3{pos}, Vector3{size}, Color("c2beb5"), 0.94, false, "res://assets/textures/painted_wall.png")')
    once(old_wall,'\n'.join(walls))
    for line in ['\t_add_box("WindowFrame", Vector3(-3.62, 2.15, 5.86), Vector3(2.10, 1.55, 0.08), Color("e5e0d8"), 0.58)\n','\tliving_window_glass = _add_box("WindowGlass", Vector3(-3.62, 2.15, 5.80), Vector3(1.80, 1.28, 0.035), Color("7192a4"), 0.14, true)\n','\twindow_sun_disc = _add_sphere("WindowSun", Vector3(-4.05, 2.48, 5.70), Vector3(0.12, 0.12, 0.035), Color("ffd58a"), 0.22)\n']:
        once(line,'')
    return text

def patch_crew(text):
    guard='neighborhood!=null and neighborhood.location_ops!=null and neighborhood.location_ops.crew!=null'
    text=text.replace('func _build_texts_app() -> void:\n','func _build_texts_app() -> void:\n\tif '+guard+':\n\t\tneighborhood.location_ops.crew.threads()\n\t\treturn\n')
    text=text.replace('func _build_clients_app() -> void:\n','func _build_clients_app() -> void:\n\tif '+guard+':\n\t\tneighborhood.location_ops.crew.contacts()\n\t\treturn\n')
    text=text.replace('func _phone_go_back() -> void:\n','func _phone_go_back() -> void:\n\tif '+guard+' and phone_current_app=="texts" and not neighborhood.location_ops.crew.thread.is_empty():\n\t\tneighborhood.location_ops.crew.back()\n\t\treturn\n')
    text=text.replace('func _open_phone_app(app_name: String) -> void:\n','func _open_phone_app(app_name: String) -> void:\n\tif '+guard+' and app_name=="texts":neighborhood.location_ops.crew.thread=""\n')
    text=text.replace('"Clients", "Customers & loyalty"','"Contacts", "Clients, crew & messages"').replace('"Texts", (','"Messages", (')
    text=text.replace('size() > 60','size() > 120')
    # Shop availability now belongs to the apartment computer; phone shows status.
    start=text.index('\tvar away_copy: Label',text.index('func _build_budshop_app()'))
    end=text.index('\tvar intro: Label',start)
    text=text[:start]+'\tvar note := Label.new()\n\tnote.text="Open, close or lay low from the apartment computer. Contact your assigned crew for remote shutdown."\n\tnote.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART\n\tbusiness_box.add_child(note)\n'+text[end:]
    text=text.replace('func _start_lay_low() -> void:\n','func _start_lay_low() -> void:\n\tif '+guard+' and not neighborhood.location_ops.crew.applying:\n\t\tneighborhood.location_ops.crew.shutdown()\n\t\treturn\n')
    text=text.replace('var rate: float = POWER_BASE_COST_PER_GAME_MINUTE','var rate: float = 0.0 if lay_low_active else POWER_BASE_COST_PER_GAME_MINUTE')
    text=text.replace('var bill: int = maxi(1, int(ceil(current_day_power_cost)))','var bill: int = maxi(0, int(ceil(current_day_power_cost)))')
    text=text.replace('\tproduction_worker_node.visible = on_duty\n\tif not on_duty:\n\t\treturn','\tproduction_worker_node.visible = on_duty or (packing_employee_hired and lay_low_active and not production_worker_arrested)\n\tif not on_duty:\n\t\tif production_worker_node.visible:production_worker_node.position=production_worker_node.position.move_toward(_production_worker_station_position("idle"),PRODUCTION_WORKER_MOVE_SPEED*delta)\n\t\treturn')
    text=text.replace('func _dealer_sell_one(show_feedback: bool, assigned_dealer_name: String = "") -> bool:', 'func _dealer_sell_one(show_feedback: bool, assigned_dealer_name: String = "", door_customer: Dictionary = {}, door_order: Dictionary = {}) -> bool:')
    text=text.replace('\tvar favorite: String = str(chosen_customer.get("favorite", ""))','\tif not door_customer.is_empty():\n\t\tvar matches: bool=false\n\t\tfor candidate in available_customers:\n\t\t\tif candidate.get("name","")==door_customer.get("name",""):matches=true\n\t\tif not matches:return false\n\t\tchosen_customer=door_customer\n\tvar favorite: String = str(door_order.get("product",chosen_customer.get("favorite", "")))')
    text=text.replace('\tif product_name.is_empty():\n\t\tvar alternatives: Array[String] = []','\tif product_name.is_empty():\n\t\tif not door_customer.is_empty():return false\n\t\tvar alternatives: Array[String] = []')
    text=text.replace('\tvar qty: int = rng.randi_range(min_qty, max_qty)\n\tlocker_weed[product_name]', '\tvar qty: int = rng.randi_range(min_qty, max_qty)\n\tif not door_customer.is_empty():\n\t\tqty=int(door_order.get("qty",0))\n\t\tif qty<=0 or available<qty:return false\n\tlocker_weed[product_name]')
    return text

def main():
    blob=SOURCE.read_bytes();fb,entries=parse(blob)
    source_main=next(e[1] for e in entries if e[0]=='scripts/main.gd').decode()
    assert 'var property_offer_unlocked: bool = false' in source_main
    assert 'func _sync_chapter_four_story()' in source_main
    for entry in entries:
        if entry[0]=='scripts/main.gd':entry[1]=patch(source_main).replace('OPEN DOOR & WALK OUTSIDE','OPEN APARTMENT DOOR').replace('Vector3(1.88, 2.72, 0.12)','Vector3(1.94, 2.82, 0.12)').replace('func _go_to_view(view_name: String, animate: bool = true) -> void:\n','func _go_to_view(view_name: String, animate: bool = true) -> void:\n\tif neighborhood != null and neighborhood.handle_view_request(view_name):\n\t\treturn\n').encode()
    for entry in entries:
        if entry[0]=='scripts/main.gd':entry[1]=patch_clients(entry[1].decode()).encode()
    entries.append(['scripts/joystick.gd',(ROOT/'tools/neighborhood67/joystick.gd').read_bytes(),0])
    for name in ['interiors.gd','interior_door.gd','client_visits.gd','house_controls.gd','weather.gd','weather.gdshader']:
        entries.append(['scripts/'+name,(ROOT/('tools/neighborhood82' if name=='interiors.gd' else 'tools/neighborhood81')/name).read_bytes(),0])
    entries.append(['scripts/neighborhood.gd',''.join(line for line in (ROOT/'tools/neighborhood84/neighborhood.gd').read_text().splitlines(keepends=True) if line.strip() and not line.lstrip().startswith('#')).encode(),0])
    entries.append(['scripts/exterior.gdshader',(ROOT/'tools/neighborhood66/exterior.gdshader').read_bytes(),0])
    entries.append(['assets/neighborhood/exterior_atlas.webp',(ROOT/'tools/neighborhood65/assets/exterior_atlas.webp').read_bytes(),0])
    audio=json.loads((ROOT/'tools/neighborhood64/audio.json').read_text())
    for name,data in audio['files'].items():entries.append(['assets/audio/'+name,base64.b64decode(data),0])
    
    for entry in entries:
        if entry[0]=='scripts/interiors.gd':
            entry[1]=''.join(line for line in entry[1].decode().splitlines(keepends=True) if line.strip() and not line.lstrip().startswith('#')).encode()
    for entry in entries:
        if entry[0]=='scripts/main.gd':
            text=entry[1].decode()
            text=text.replace('var property_offer_unlocked: bool = false','var property_offer_unlocked: bool = false\nvar property_opportunity_state: Dictionary = {}')
            text=text.replace('func _any_modal_open() -> bool:\n','func _any_modal_open() -> bool:\n\tif neighborhood!=null and neighborhood.property_opportunity!=null and neighborhood.property_opportunity.is_open(): return true\n')
            text=text.replace('"property_offer_unlocked": property_offer_unlocked','"property_offer_unlocked": property_offer_unlocked,\n\t\t"property_opportunity_state": property_opportunity_state')
            text=text.replace('property_offer_unlocked = bool(data.get("property_offer_unlocked", property_offer_unlocked))','property_offer_unlocked = bool(data.get("property_offer_unlocked", property_offer_unlocked))\n\tvar saved_property: Variant=data.get("property_opportunity_state", {})\n\tif saved_property is Dictionary: property_opportunity_state=saved_property.duplicate(true)')
            entry[1]=text.encode()
    entries.append(['scripts/property_opportunity.gd',(ROOT/'tools/neighborhood83/property_opportunity.gd').read_bytes(),0])
    for entry in entries:
        if entry[0]=='scripts/main.gd':
            text=entry[1].decode()
            text=text.replace('var property_opportunity_state: Dictionary = {}','var property_opportunity_state: Dictionary = {}\nvar location_state: Dictionary = {}\nvar apartment_rent_state: Dictionary = {}')
            text=text.replace('func _any_modal_open() -> bool:\n','func _any_modal_open() -> bool:\n\tif neighborhood!=null and neighborhood.location_ops!=null and neighborhood.location_ops.is_open():return true\n')
            text=text.replace('"property_opportunity_state": property_opportunity_state','"property_opportunity_state": property_opportunity_state,\n\t\t"location_state": location_state,\n\t\t"apartment_rent_state": apartment_rent_state')
            text=text.replace('if saved_property is Dictionary: property_opportunity_state=saved_property.duplicate(true)','if saved_property is Dictionary: property_opportunity_state=saved_property.duplicate(true)\n\tvar saved_locations: Variant=data.get("location_state",{})\n\tif saved_locations is Dictionary:location_state=saved_locations.duplicate(true)\n\tvar saved_rent: Variant=data.get("apartment_rent_state",{})\n\tif saved_rent is Dictionary:apartment_rent_state=saved_rent.duplicate(true)')
            text=text.replace('func _buy_dealer_locker_upgrade() -> void:\n','func _buy_dealer_locker_upgrade() -> void:\n\tif neighborhood!=null and neighborhood.location_ops!=null and not neighborhood.location_ops.installing:\n\t\tstatus_label.text="Order dealer storage at Central Market, then install it at your computer."\n\t\treturn\n')
            text=text.replace('var cost: int = DEALER_LOCKER_COST_BY_LEVEL[next_level]','var cost: int = 0 if neighborhood!=null and neighborhood.location_ops!=null and neighborhood.location_ops.installing else DEALER_LOCKER_COST_BY_LEVEL[next_level]')
            text=text.replace('func _buy_seed(seed_name: String) -> void:\n','func _buy_seed(seed_name: String) -> void:\n\tif neighborhood!=null and neighborhood.location_ops!=null and not tutorial_active:\n\t\tneighborhood.location_ops.order_seed(seed_name)\n\t\treturn\n')
            text=text.replace('func _buy_supply(supply_name: String) -> void:\n','func _buy_supply(supply_name: String) -> void:\n\tif neighborhood!=null and neighborhood.location_ops!=null and neighborhood.location_ops.supply_intercept(supply_name):return\n')
            text=text.replace('func _refresh_phone() -> void:\n','func _refresh_phone() -> void:\n\tif neighborhood!=null and neighborhood.location_ops!=null and neighborhood.location_ops.refresh_management():return\n')
            text=text.replace('func _open_phone_app(app_name: String) -> void:\n','func _open_phone_app(app_name: String) -> void:\n\tif neighborhood!=null and neighborhood.location_ops!=null and neighborhood.location_ops.redirect(app_name):return\n')
            text=text.replace('func _build_shop_app() -> void:\n','func _build_shop_app() -> void:\n\tif neighborhood!=null and neighborhood.location_ops!=null:neighborhood.location_ops.order_summary(phone_list)\n')
            text=text.replace('func _build_bills_app() -> void:\n','func _build_bills_app() -> void:\n\tif neighborhood!=null and neighborhood.location_ops!=null:neighborhood.location_ops.rent_ui(phone_list)\n')
            text=text.replace('power_bill_due + water_bill_due + dealer_balance_due','power_bill_due + water_bill_due + dealer_balance_due + (neighborhood.location_ops.balance() if neighborhood!=null and neighborhood.location_ops!=null else 0)')
            # Phone retains orders and quick bills; management is entered at the computer.
            text=text.replace('_add_phone_app_tile(grid, "", "Genetics",','if (neighborhood!=null and neighborhood.location_ops!=null and neighborhood.location_ops.management_allowed()) or tutorial_active:_add_phone_app_tile(grid, "", "Genetics",')
            text=text.replace('_add_phone_app_tile(grid, "", "Your Supply",','if (neighborhood!=null and neighborhood.location_ops!=null and neighborhood.location_ops.management_allowed()) or tutorial_active:_add_phone_app_tile(grid, "", "Your Supply",')
            text=text.replace('_add_phone_app_tile(grid, "", "Employees",','if neighborhood!=null and neighborhood.location_ops!=null and neighborhood.location_ops.management_allowed():_add_phone_app_tile(grid, "", "Employees",')
            text=text.replace('_add_phone_app_tile(grid, "", "Upgrades",','if neighborhood!=null and neighborhood.location_ops!=null and neighborhood.location_ops.management_allowed():_add_phone_app_tile(grid, "", "Upgrades",')
            text=text.replace('func _build_supplies_app() -> void:\n','func _build_supplies_app() -> void:\n\tif not tutorial_active:\n\t\tvar notice := Label.new()\n\t\tnotice.text="Buy fertilizer at Central Market. Collected supplies stay with you until deposited at your apartment computer."\n\t\tnotice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART\n\t\tphone_list.add_child(notice)\n\t\treturn\n')
            start=text.index('func _build_seed_shop_app()');end=text.index('\nfunc ',start+5)
            part=text[start:end].replace('_supply_can_add_seeds(1)','neighborhood.location_ops.total(location_state.pickup_seeds)<50').replace('SUPPLY SHELF FULL','ORDER LIMIT REACHED').replace('BUY 1 SEED','ORDER 1 SEED')
            part=part.replace('New genetics unlock with Grower Level. Purchased seeds are delivered to Grow Supply Shelf Lv %d. Seed storage: %d / %d.','Order seeds for pickup at Central Market. Shelf Lv %d: %d / %d seeds. Collect orders at checkout, then deposit carried seeds at your computer.')
            text=text[:start]+part+text[end:]
            text=text.replace('func _build_upgrades_app() -> void:\n','func _build_upgrades_app() -> void:\n\tif not tutorial_active:\n\t\tneighborhood.location_ops.equipment_ui(phone_list)\n\t\treturn\n')
            text=text.replace('PHONE LAYOUT\\nShop -> Supplies for fertilizer; Shop -> Seeds for all shop seeds. Business -> Bills, Employees or Upgrades. Storage keeps your stock, prices, reserves and listings together.', 'PHONE LAYOUT\\nOrder seeds on the phone, collect them at Central Market checkout, then deposit carried supplies at your apartment computer. Fertilizer and equipment are bought at Central Market. Paid equipment waits for computer installation. Property computers manage inventory, listings, genetics, staff and production. Business -> Bills includes apartment rent: $600 every 14 game days, with a three-day grace period.')
            text=text.replace('Bills, employees & upgrades','Rent, utilities & balances')
            text=text.replace('Supplies & seeds','Seed orders & market info')
            text=text.replace('phone_title.text = "Employees"','phone_title.text = "Apartment · Employees"').replace('phone_title.text = "Your Supply"','phone_title.text = "Apartment · Inventory"').replace('phone_title.text = "Upgrades"','phone_title.text = "Apartment · Equipment"').replace('phone_title.text = "Genetics Lab"','phone_title.text = "Apartment · Genetics"')
            text=text.replace('Choose Supplies to restock fertilizer, or Seeds to browse all shop genetics. Equipment is in Business -> Upgrades.','Order seeds here and collect them at Central Market. Fertilizer and equipment are sold at its checkout. Detailed operation management is at your property computer.')
            text=text.replace('\t_add_phone_app_tile(grid, "", "Business", "Rent, utilities & balances", "business")\n','')
            text=text.replace('\tif neighborhood!=null and neighborhood.location_ops!=null and neighborhood.location_ops.refresh_management():return','\tif neighborhood!=null and neighborhood.location_ops!=null and neighborhood.location_ops.refresh_management():return\n\tif phone_current_app in ["business"]:phone_current_app="home"')
            text=text.replace('Phone -> Business -> Upgrades','Central Market checkout').replace('Business -> Upgrades','Central Market checkout').replace('Business -> Bills','Apartment computer -> Bills')
            text=text.replace('Seeds and fertilizer purchased from the phone are delivered here. Capacity upgrades are in Central Market checkout.','Collect seed orders and fertilizer at Central Market, then deposit them at your apartment computer. Order capacity upgrades at market checkout and install them at the computer.')
            text=text.replace('\t_add_phone_app_tile(grid, "", "Store", "Seed orders & market info", "shop")','\t_add_phone_app_tile(grid, "", "Store", "Seed orders & market info", "shop")\n\t_add_phone_app_tile(grid, "", "Bills", "Property rent, utilities & balances", "bills")')
            text=text.replace('if app_name in ["bills", "employees", "upgrades"]:', 'if app_name in ["employees", "upgrades"]:')
            text=text.replace('Apartment computer -> Bills','Phone -> Bills or apartment computer -> Bills')
            text=text.replace('\n\tif phone_current_app in ["business"]:phone_current_app="home"','')
            text=text.replace('_add_phone_app_tile(grid, "", "Bills", "Property rent, utilities & balances", "bills")','_add_phone_app_tile(grid, "", "Business", "Property overview & bills", "business")')
            text=text.replace('if app_name in ["employees", "upgrades"]:', 'if app_name in ["bills", "employees", "upgrades"]:')
            for tile in ['Employees", "Worker & dealer team", "employees"','Upgrades", "Equipment, tents & storage", "upgrades"']:
                text=text.replace('\tif neighborhood!=null and neighborhood.location_ops!=null and neighborhood.location_ops.management_allowed():_add_phone_app_tile(grid, "", "'+tile+')\n','')
            text=text.replace('Phone -> Bills','Phone -> Business -> Bills')
            text=text.replace('func _build_business_app() -> void:\n', 'func _build_business_app() -> void:\n\tvar property_note := Label.new()\n\tproperty_note.text="APARTMENT · Active operation\\nManage rent and utilities here. Use the apartment computer for inventory, staff, genetics, equipment and production.\\nHOUSE · Property opportunity; not yet acquired."\n\tproperty_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART\n\tphone_list.add_child(property_note)\n')
            text=text.replace('\nfunc _build_bills_app() -> void:', '\tif neighborhood!=null and neighborhood.location_ops!=null and neighborhood.location_ops.rendering_management:neighborhood.location_ops.business_extras()\n\nfunc _build_bills_app() -> void:')
            text=text.replace('Manage rent and utilities here. Use the apartment computer for inventory, staff, genetics, equipment and production.','Use Bills here or open the complete apartment Business interface at its computer.')
            text=patch_crew(text)
            entry[1]=text.encode()
    entries.append(['scripts/location_ops.gd' ,(ROOT/'tools/neighborhood88/location_ops.gd').read_bytes(),0])
    entries.append(['assets/characters/Malik.glb',(ROOT/'assets/characters/Malik.glb').read_bytes(),0])
    entries.append(['scripts/crew_phone.gd',(ROOT/'tools/neighborhood88/crew_phone.gd').read_bytes(),0])
    for entry in entries:
        if entry[0]=='scripts/client_visits.gd':entry[1]=entry[1].decode().replace('if is_home(): return false','if world.location_ops.crew.serve_visit(client,host.active_request):return true\n\tif is_home(): return false').replace('size()>60','size()>120').replace('\thost.phone_text_messages[index]=message', '\thost.phone_text_messages[index]=message\n\tworld.location_ops.crew.outgoing(str(message.sender),\"Another time.\" if minutes<0 else (\"Stop by now.\" if minutes==10 else \"Stop by at \"+_appointment_label(message.client_due)))',1).encode()
    packed=rebuild(blob,fb,entries);parse(packed);TARGET.write_bytes(packed)
    old={e[0]:e[1] for e in parse(blob)[1]};new={e[0]:e[1] for e in parse(packed)[1]}
    assert all(new[k]==v for k,v in old.items() if k!='scripts/main.gd')
    release='0.7.9-beta.19-cloudtest.88'
    html=(ROOT/'index.html').read_text().replace('AFB_RUNTIME87','AFB_RUNTIME88').replace('afb-runtime87.js?v=87','afb-runtime88.js?v=88')
    html=re.sub(r'const AFB_TEST_TITLE = "[^"]+";',f'const AFB_TEST_TITLE = "AFewBuds Cloud Test {release}";',html)
    html,n=re.subn(r'const AFB_TEST_RELEASE = "[^"]+";',f'const AFB_TEST_RELEASE = "{release}";',html,count=1);assert n==1
    html,n=re.subn(r'"mainPack":"[^"]+"','"mainPack":"index-cloudtest88.pck"',html,count=1);assert n==1
    html,n=re.subn(r'"fileSizes":\{[^}]*\}',f'"fileSizes":{{"index-cloudtest88.pck":{len(packed)},"index.wasm":{(ROOT/"index.wasm").stat().st_size}}}',html,count=1);assert n==1
    html,n=re.subn(r'<title>AFewBuds Cloud Test [^<]+</title>',f'<title>AFewBuds Cloud Test {release}</title>',html,count=1);assert n==1
    (ROOT/'index.html').write_text(html)
    meta=json.loads((ROOT/'version.json').read_text());meta['release_id']=release
    meta['location_management']='Central Market checkout, carried supplies, seed-order pickup, paid equipment delivery and computer installation. Apartment computer manages inventory, genetics, staff and equipment; house computer previews property until acquisition.'
    meta['crew_phone']='Contact message threads, apartment staff assignments, door manager, stock alerts and remote apartment lay-low commands. House assignment waits for acquisition.'
    meta['phone_business']='Lean Business category: property overview and Bills. Detailed operation management stays on property computers.'
    meta['apartment_rent']='$600 every 14 active game days; existing/new careers get 14 days before first charge, three-day grace, manual payment through Bills; no retroactive rent.'
    meta['runtime_delivery']='SHA-256 verified .88 property inspection pack delta over unchanged .63 assets.'
    meta['property_opportunity']='Rod-gated property details and physical six-room walking inspection; saved inspection progress. Acquisition, payment terms and relocation follow in a separate update.'
    meta['house_grow_equipment']='House grow room starts without tents, planters or grow lights; separate house_grow_tent_count controls installation, independent of apartment upgrades. House purchasing/upgrades are not enabled by this map update.'
    meta['apartment_window']='Real glazed aperture through apartment wall and brick exterior; original painted finish and side curtains retained, fake sky pane and sun removed, inside-only double-tap blinds default open and persist with the career.'
    meta['outdoor_sky']='Animated procedural cloud sky, visible sun rising +X east and setting -X west, opposing moon and stars, continuous game-clock light/color transitions and fading streetlights.'
    meta['market_lighting']='Independent sales-floor and stockroom lighting circuits, both controlled from stockroom switches; saved with existing room controls.'
    meta['house_shades']='All ten exterior house windows have operable inside-only saved coverings; apartment blinds retained.'
    meta['house_controls']='Eight correctly mapped room switches, separate house grow-light service panel, and inside-only double-tap window coverings; states saved with the career.'
    meta['client_visits']='Away clients text instead of knocking; Stop by now, in 1 or 2 game hours, or Another time. Appointments persist in saved texts; walk to the door to answer; obsolete Go to Door button hidden.'
    meta['house_window_privacy']='Bathroom frame fits its 1.1 x 1.0 m aperture; packing-room windows have closed blinds and grow-room windows have opaque blackout shades.'
    meta['map_build']='Prototype 0.9.5 house and Central Market rooms, real window openings, glazed doors and five manually operated doors; existing textures, controls, game progression and account fixes preserved.'
    meta['neighborhood']='Prototype 0.9.3 street, sidewalk and building footprint layout adapted with cloud-test texture atlas, opening door, analog controls and ground reserves.'
    meta['notification_audio']='Requested text ding at -14 dB; requested door knock at -10 dB.'
    (ROOT/'version.json').write_text(json.dumps(meta,indent=2)+'\n')
    (ROOT/'BUILD_VERSION.txt').write_text('AFewBuds Cloud Test\nGame build: 0.7.9-beta.19\nWeb release: '+release+'\nRuntime: Walkable neighborhood + apartment exit/return + quieter text ding and door knock\n')
    (ROOT/'debug-main.gd.txt').write_bytes(new['scripts/main.gd'])
    print('Built',release,len(packed),'bytes; all unrelated pack entries unchanged')
if __name__=='__main__':main()

