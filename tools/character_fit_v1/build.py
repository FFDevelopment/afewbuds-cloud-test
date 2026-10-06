"""Build the isolated character-fit candidate from the verified .96 runtime.

python tools/character_fit_v1/build.py --output-dir <scratch>
Existing game entries are retained except main/neighborhood/interiors; saves,
character bytes, apartment couch, shader/texture bytes and gameplay stay intact.
"""
from pathlib import Path
import argparse,base64,hashlib,importlib.util,json,struct,difflib,re
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent

def read_recipe(path):
    recipe=json.loads(path.read_text());base=(ROOT/recipe['base_url'].split('?')[0]).read_bytes()
    assert len(base)==recipe['base_size'] and hashlib.sha256(base).hexdigest()==recipe['base_sha256']
    result=bytearray()
    for row in recipe['segments']:
        if row[0]=='copy':result.extend(base[row[1]:row[1]+row[2]])
        elif row[0]=='zero':result.extend(b'\0'*row[1])
        elif row[0]=='data':result.extend(base64.b64decode(row[1]))
        elif row[0]=='asset':
            data=(ROOT/row[1].split('?')[0]).read_bytes()
            assert len(data)==row[2] and hashlib.sha256(data).hexdigest()==row[3]
            result.extend(data)
        else:raise ValueError(row[0])
    assert len(result)==recipe['target_size'] and hashlib.sha256(result).hexdigest()==recipe['target_sha256']
    return bytes(result)

def extract(entries,destination,label):
    destination.mkdir(parents=True,exist_ok=True)
    for name,data,flags in entries:
        if name=='project.binary':continue
        path=(destination/name.removeprefix('res://')).resolve()
        assert path.is_relative_to(destination.resolve())
        path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
    # Separate native-only user-data namespace; never load or change the user's career.
    (destination/'project.godot').write_text('''config_version=5
[application]
config/name="AFB Character Fit Validation '''+label+'''"
run/main_scene="res://scenes/main.tscn"
[display]
window/size/viewport_width=1280
window/size/viewport_height=800
window/stretch/mode="canvas_items"
[animation]
compatibility/default_parent_skeleton_in_mesh_instance_3d=true
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
''')

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output-dir',required=True);args=ap.parse_args()
    out=Path(args.output_dir).resolve();out.mkdir(parents=True,exist_ok=True)
    spec=importlib.util.spec_from_file_location('pack',ROOT/'tools/build_neighborhood96.py')
    pack=importlib.util.module_from_spec(spec);spec.loader.exec_module(pack)
    blob=read_recipe(ROOT/'runtime/cloudtest96.patch.json');fb,entries=pack.parse(blob)
    old={n:b for n,b,f in entries}
    source_main=old['scripts/main.gd'].decode()
    start=source_main.index('func _apply_visual_upgrades()');end=source_main.index('\nfunc ',start+5)
    patched=source_main[:end].rstrip()+'\n\tload("res://scripts/furniture_fit.gd").apply_apartment(self)\n\n'+source_main[end:]
    replacements={'scripts/main.gd':patched.encode()}
    for name in ['neighborhood.gd','interiors.gd','furniture_fit.gd','scale_policy.gd']:
        replacements['scripts/'+name]=(HERE/name).read_text(encoding='utf-8').encode('utf-8')
    updated=[[n,replacements.pop(n,b),f] for n,b,f in entries]
    updated.extend([n,b,0] for n,b in replacements.items())
    built=pack.rebuild(blob,fb,updated);new={n:b for n,b,f in pack.parse(built)[1]}
    changed=[n for n in old if new[n]!=old[n]]
    assert set(changed)=={'scripts/main.gd','scripts/neighborhood.gd','scripts/interiors.gd'},changed
    assert new['project.godot']==old['project.godot']
    (out/'candidate.pck').write_bytes(built)
    extract(entries,out/'baseline','Baseline')
    extract(updated,out/'candidate','Candidate')
    # Sparse delta against the same immutable .63 base used by .96.
    base=(ROOT/'index-cloudtest10.pck').read_bytes();base_fb,base_entries=pack.parse(base)
    def directory(data):
        filebase,offset=struct.unpack_from('<QQ',data,24);p=offset+4;rows=[]
        for _ in range(struct.unpack_from('<I',data,offset)[0]):
            size=struct.unpack_from('<I',data,p)[0];p+=4
            name=data[p:p+size].rstrip(b'\0').decode();p+=size
            where,length=struct.unpack_from('<QQ',data,p);p+=36
            rows.append((name,filebase+where,length))
        return rows
    source={n:(o,s) for n,o,s in directory(base)};segments=[]
    def add(data):
        if data:segments.append(['data',base64.b64encode(data).decode()])
    def copy(o,s):
        if s:segments.append(['copy',o,s])
    add(built[:fb]);cursor=fb
    assets=['assets/characters/Malik.glb','assets/characters/Rod.glb','assets/characters/Malik_BaseColor.png','assets/characters/Rod_BaseColor.png','assets/furniture/walnut.png']
    for name,offset,size in directory(built):
        if offset>cursor:
            assert not any(built[cursor:offset]);segments.append(['zero',offset-cursor])
        data=built[offset:offset+size]
        if name in assets:segments.append(['asset',name+'?v=character-fit-v1',len(data),hashlib.sha256(data).hexdigest()])
        elif name in source:
            oldoff,oldsize=source[name];previous=base[oldoff:oldoff+oldsize]
            if data==previous:copy(oldoff,oldsize)
            elif name=='scripts/main.gd':
                a=previous.splitlines(keepends=True);b=data.splitlines(keepends=True);offsets=[0]
                for line in a:offsets.append(offsets[-1]+len(line))
                for op,l,r,x,y in difflib.SequenceMatcher(None,a,b,autojunk=False).get_opcodes():
                    if op=='equal':copy(oldoff+offsets[l],offsets[r]-offsets[l])
                    elif op in ['replace','insert']:add(b''.join(b[x:y]))
            else:add(data)
        else:add(data)
        cursor=offset+size
    add(built[cursor:])
    recipe={'format':'afb-pack-delta-1','base_url':'index-cloudtest10.pck?build=63','base_size':len(base),'base_sha256':hashlib.sha256(base).hexdigest(),'target_size':len(built),'target_sha256':hashlib.sha256(built).hexdigest(),'segments':segments}
    recipe_path=ROOT/'runtime/character-fit-v1.patch.json';recipe_path.write_text(json.dumps(recipe,separators=(',',':'))+'\n',newline='\n')
    assert read_recipe(recipe_path)==built
    loader=(ROOT/'shared/afb-runtime96.js').read_text().replace('.96 pack','character-fit-v1 pack').replace('runtime/cloudtest96.patch.json?v=96','runtime/character-fit-v1.patch.json?v=1').replace('AFB_RUNTIME96','AFB_RUNTIME_CHARACTER_FIT_V1').replace('index-cloudtest96.pck','index-character-fit-v1.pck')
    (ROOT/'shared/afb-runtime-character-fit-v1.js').write_text(loader)
    release='0.7.9-beta.19-cloudtest.96-fit.1'
    index=(ROOT/'index.html').read_text()
    index=re.sub(r'shared/afb-runtime(?:96|character-fit-v1)\.js\?v=(?:96|1)','shared/afb-runtime-character-fit-v1.js?v=1',index)
    index=index.replace('AFB_RUNTIME96','AFB_RUNTIME_CHARACTER_FIT_V1')
    index=re.sub(r'const AFB_TEST_RELEASE = "[^"]+";',f'const AFB_TEST_RELEASE = "{release}";',index)
    index=re.sub(r'const AFB_TEST_TITLE = "[^"]+";',f'const AFB_TEST_TITLE = "AFewBuds Cloud Test {release}";',index)
    index=re.sub(r'"mainPack":"[^"]+"','"mainPack":"index-character-fit-v1.pck"',index)
    index=re.sub(r'"fileSizes":\{[^}]*\}',f'"fileSizes":{{"index-character-fit-v1.pck":{len(built)},"index.wasm":{(ROOT/"index.wasm").stat().st_size}}}',index,count=1)
    index=re.sub(r'<title>AFewBuds Cloud Test [^<]+</title>',f'<title>AFewBuds Cloud Test {release}</title>',index)
    (ROOT/'index.html').write_text(index)
    version=json.loads((ROOT/'version.json').read_text());version['release_id']=release
    version['character_furniture_fit']='Fixed character scale; fitted apartment/house furniture, 2.85-unit door leaves, larger cars/trees/background stories, unchanged streets and usable room footprints.'
    version['scale_reference']={'character_height':2.35,'max_height':2.42,'eye_height':2.16,'collision_radius':.26,'door_leaf':2.85,'door_opening':2.9,'car_scale':1.25,'tree_scale':1.2,'background_story_scale_y':1.2}
    version['runtime_delivery']='SHA-256-verified character-fit-v1 pack delta over unchanged .63 assets; derived from .96.'
    (ROOT/'version.json').write_text(json.dumps(version,indent=2)+'\n')
    (ROOT/'BUILD_VERSION.txt').write_text('AFewBuds Cloud Test\nGame build: 0.7.9-beta.19\nWeb release: '+release+'\nRuntime: Character-scale furniture and world fit over cloudtest.96\n')
    receipt={'base_sha256':hashlib.sha256(blob).hexdigest(),'target_sha256':hashlib.sha256(built).hexdigest(),'changed_existing_entries':changed,'added_entries':[n for n in new if n not in old],'unchanged_entries':len(old)-len(changed),'character_assets_unchanged':all(new[n]==old[n] for n in assets),'delta_reconstruction_verified':True,'target_bytes':len(built),'delta_bytes':recipe_path.stat().st_size}
    (HERE/'build_receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt))

if __name__=='__main__':main()
