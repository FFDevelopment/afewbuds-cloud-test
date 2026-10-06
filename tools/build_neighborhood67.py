"""Build .67 from the checked .63 runtime, preserving all existing pack entries."""
from pathlib import Path
import struct, hashlib, json, re, base64
ROOT=Path(__file__).resolve().parent.parent
SOURCE=ROOT/'index-cloudtest10.pck'
TARGET=ROOT/'index-cloudtest67.pck'

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
    once('\t_add_box("FrontWall", Vector3(0, 2.15, 6.0), Vector3(10.2, 4.3, 0.18), Color("c2beb5"), 0.94, false, "res://assets/textures/painted_wall.png", Vector3(3.0, 2.0, 1.0))', '\t_add_box("FrontWallL", Vector3(-3.075, 2.15, 6.0), Vector3(4.05, 4.3, 0.18), Color("c2beb5"), 0.94, false, "res://assets/textures/painted_wall.png")\n\t_add_box("FrontWallR", Vector3(3.075, 2.15, 6.0), Vector3(4.05, 4.3, 0.18), Color("c2beb5"), 0.94, false, "res://assets/textures/painted_wall.png")\n\t_add_box("FrontWallHeader", Vector3(0, 3.675, 6.0), Vector3(2.1, 1.27, 0.18), Color("c2beb5"), 0.94)')
    return text

def main():
    blob=SOURCE.read_bytes();fb,entries=parse(blob)
    source_main=next(e[1] for e in entries if e[0]=='scripts/main.gd').decode()
    assert 'var property_offer_unlocked: bool = false' in source_main
    assert 'func _sync_chapter_four_story()' in source_main
    for entry in entries:
        if entry[0]=='scripts/main.gd':entry[1]=patch(source_main).replace('OPEN DOOR & WALK OUTSIDE','OPEN APARTMENT DOOR').replace('Vector3(1.88, 2.72, 0.12)','Vector3(1.94, 2.82, 0.12)').replace('func _go_to_view(view_name: String, animate: bool = true) -> void:\n','func _go_to_view(view_name: String, animate: bool = true) -> void:\n\tif neighborhood != null and neighborhood.active:\n\t\tneighborhood.end_walk()\n').encode()
    entries.append(['scripts/joystick.gd',(ROOT/'tools/neighborhood67/joystick.gd').read_bytes(),0])
    entries.append(['scripts/neighborhood.gd',(ROOT/'tools/neighborhood67/neighborhood.gd').read_bytes(),0])
    entries.append(['scripts/exterior.gdshader',(ROOT/'tools/neighborhood66/exterior.gdshader').read_bytes(),0])
    entries.append(['assets/neighborhood/exterior_atlas.webp',(ROOT/'tools/neighborhood65/assets/exterior_atlas.webp').read_bytes(),0])
    audio=json.loads((ROOT/'tools/neighborhood64/audio.json').read_text())
    for name,data in audio['files'].items():entries.append(['assets/audio/'+name,base64.b64decode(data),0])
    packed=rebuild(blob,fb,entries);parse(packed);TARGET.write_bytes(packed)
    old={e[0]:e[1] for e in parse(blob)[1]};new={e[0]:e[1] for e in parse(packed)[1]}
    assert all(new[k]==v for k,v in old.items() if k!='scripts/main.gd')
    release='0.7.9-beta.19-cloudtest.67'
    html=(ROOT/'index.html').read_text()
    html,n=re.subn(r'const AFB_TEST_RELEASE = "[^"]+";',f'const AFB_TEST_RELEASE = "{release}";',html,count=1);assert n==1
    html,n=re.subn(r'"mainPack":"[^"]+"','"mainPack":"index-cloudtest67.pck"',html,count=1);assert n==1
    html,n=re.subn(r'"fileSizes":\{[^}]*\}',f'"fileSizes":{{"index-cloudtest67.pck":{len(packed)},"index.wasm":{(ROOT/"index.wasm").stat().st_size}}}',html,count=1);assert n==1
    html,n=re.subn(r'<title>AFewBuds Cloud Test [^<]+</title>',f'<title>AFewBuds Cloud Test {release}</title>',html,count=1);assert n==1
    (ROOT/'index.html').write_text(html)
    meta=json.loads((ROOT/'version.json').read_text());meta['release_id']=release
    meta['neighborhood']='Connected intersections with clear street mouths, split curbs and markings; road and ground reserves beyond unchanged playable bounds; real apartment doorway preserved; analog walking stick with independent drag-to-look.'
    meta['notification_audio']='Requested text ding at -14 dB; requested door knock at -10 dB.'
    (ROOT/'version.json').write_text(json.dumps(meta,indent=2)+'\n')
    (ROOT/'BUILD_VERSION.txt').write_text('AFewBuds Cloud Test\nGame build: 0.7.9-beta.19\nWeb release: '+release+'\nRuntime: Walkable neighborhood + apartment exit/return + quieter text ding and door knock\n')
    (ROOT/'debug-main.gd.txt').write_bytes(new['scripts/main.gd'])
    print('Built',release,len(packed),'bytes; all unrelated pack entries unchanged')
if __name__=='__main__':main()
