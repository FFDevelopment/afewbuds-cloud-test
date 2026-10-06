"""Build .81 from the checked .63 runtime, preserving all existing pack entries."""
from pathlib import Path
import struct, hashlib, json, re, base64
ROOT=Path(__file__).resolve().parent.parent
SOURCE=ROOT/'index-cloudtest10.pck'
TARGET=ROOT/'index-cloudtest81.pck'

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
        entries.append(['scripts/'+name,(ROOT/'tools/neighborhood81'/name).read_bytes(),0])
    entries.append(['scripts/neighborhood.gd',(ROOT/'tools/neighborhood81/neighborhood.gd').read_bytes(),0])
    entries.append(['scripts/exterior.gdshader',(ROOT/'tools/neighborhood66/exterior.gdshader').read_bytes(),0])
    entries.append(['assets/neighborhood/exterior_atlas.webp',(ROOT/'tools/neighborhood65/assets/exterior_atlas.webp').read_bytes(),0])
    audio=json.loads((ROOT/'tools/neighborhood64/audio.json').read_text())
    for name,data in audio['files'].items():entries.append(['assets/audio/'+name,base64.b64decode(data),0])
    packed=rebuild(blob,fb,entries);parse(packed);TARGET.write_bytes(packed)
    old={e[0]:e[1] for e in parse(blob)[1]};new={e[0]:e[1] for e in parse(packed)[1]}
    assert all(new[k]==v for k,v in old.items() if k!='scripts/main.gd')
    release='0.7.9-beta.19-cloudtest.81'
    html=(ROOT/'index.html').read_text().replace('AFB_RUNTIME80','AFB_RUNTIME81').replace('afb-runtime80.js?v=80','afb-runtime81.js?v=81')
    html=re.sub(r'const AFB_TEST_TITLE = "[^"]+";',f'const AFB_TEST_TITLE = "AFewBuds Cloud Test {release}";',html)
    html,n=re.subn(r'const AFB_TEST_RELEASE = "[^"]+";',f'const AFB_TEST_RELEASE = "{release}";',html,count=1);assert n==1
    html,n=re.subn(r'"mainPack":"[^"]+"','"mainPack":"index-cloudtest81.pck"',html,count=1);assert n==1
    html,n=re.subn(r'"fileSizes":\{[^}]*\}',f'"fileSizes":{{"index-cloudtest81.pck":{len(packed)},"index.wasm":{(ROOT/"index.wasm").stat().st_size}}}',html,count=1);assert n==1
    html,n=re.subn(r'<title>AFewBuds Cloud Test [^<]+</title>',f'<title>AFewBuds Cloud Test {release}</title>',html,count=1);assert n==1
    (ROOT/'index.html').write_text(html)
    meta=json.loads((ROOT/'version.json').read_text());meta['release_id']=release
    meta['runtime_delivery']='SHA-256 verified .81 map pack delta over unchanged .63 assets.'
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

