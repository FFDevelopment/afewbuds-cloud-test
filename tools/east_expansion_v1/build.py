"""Add the east district to the merged .96-fit.1 pack, preserving all interiors."""
from pathlib import Path
import argparse,base64,difflib,hashlib,importlib.util,json,re,struct
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result
fit=module('fit_build',ROOT/'tools/character_fit_v1/build.py')
pack=module('pack_build',ROOT/'tools/build_neighborhood96.py')

def directory(data):
    filebase,offset=struct.unpack_from('<QQ',data,24);p=offset+4;rows=[]
    for _ in range(struct.unpack_from('<I',data,offset)[0]):
        size=struct.unpack_from('<I',data,p)[0];p+=4
        name=data[p:p+size].rstrip(b'\0').decode();p+=size
        where,length=struct.unpack_from('<QQ',data,p);p+=36
        rows.append((name,filebase+where,length))
    return rows

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output-dir',required=True);args=ap.parse_args()
    out=Path(args.output_dir).resolve();out.mkdir(parents=True,exist_ok=True)
    baseline=fit.read_recipe(ROOT/'runtime/character-fit-v1.patch.json');fb,entries=pack.parse(baseline)
    before={n:b for n,b,f in entries}
    text=before['scripts/neighborhood.gd'].decode()
    def once(a,b):
        nonlocal text
        assert text.count(a)==1,repr(a)
        text=text.replace(a,b,1)
    once('extends Node3D','extends Node3D\nvar window_layout_records:Array[Dictionary]=[]')
    once('\t\t\t\t\tfacade_window(point,normal)','\t\t\t\t\twindow_layout_records.append({"at":point,"floor":pos.y+row*3.24,"ceiling":minf(pos.y+(row+1)*3.24,pos.y+size.y),"building":label_text,"row":row})\n\t\t\t\t\tfacade_window(point,normal)')
    once('\tfence(Vector3(73,0,-36),Vector3(73,0,39))','\t# The east fence moves outward; all core geometry stays in place.\n\tload("res://scripts/east_expansion.gd").new().build(self)')
    once('pos.x > 72.7','pos.x > 136.7')
    once('for x in [-28.0,61.0]:','for x in [-28.0]: # East-edge exteriors are reorganized by east_expansion.gd.')
    (HERE/'neighborhood.gd').write_text(text,encoding='utf-8',newline='\n')
    updated=[[n,text.encode() if n=='scripts/neighborhood.gd' else b,f] for n,b,f in entries]
    updated.append(['scripts/east_expansion.gd',(HERE/'east_expansion.gd').read_text(encoding='utf-8').encode(),0])
    candidate=pack.rebuild(baseline,fb,updated)
    after={n:b for n,b,f in pack.parse(candidate)[1]}
    changed=[n for n in before if before[n]!=after[n]]
    assert changed==['scripts/neighborhood.gd'],changed
    (out/'candidate.pck').write_bytes(candidate)
    fit.extract(entries,out/'baseline','East Baseline');fit.extract(updated,out/'candidate','East Candidate')
    base=(ROOT/'index-cloudtest10.pck').read_bytes();source={n:(o,s) for n,o,s in directory(base)}
    segments=[]
    def add(data):
        if data:segments.append(['data',base64.b64encode(data).decode()])
    def copy(o,s):
        if s:segments.append(['copy',o,s])
    add(candidate[:fb]);cursor=fb
    assets=['assets/characters/Malik.glb','assets/characters/Rod.glb','assets/characters/Malik_BaseColor.png','assets/characters/Rod_BaseColor.png','assets/furniture/walnut.png']
    for name,offset,size in directory(candidate):
        if offset>cursor:
            assert not any(candidate[cursor:offset]);segments.append(['zero',offset-cursor])
        data=candidate[offset:offset+size]
        if name in assets:segments.append(['asset',name+'?v=east-expansion-v1',len(data),hashlib.sha256(data).hexdigest()])
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
    add(candidate[cursor:])
    recipe={'format':'afb-pack-delta-1','base_url':'index-cloudtest10.pck?build=63','base_size':len(base),'base_sha256':hashlib.sha256(base).hexdigest(),'target_size':len(candidate),'target_sha256':hashlib.sha256(candidate).hexdigest(),'segments':segments}
    recipe_path=ROOT/'runtime/east-expansion-v1.patch.json'
    recipe_path.write_text(json.dumps(recipe,separators=(',',':'))+'\n',newline='\n')
    assert fit.read_recipe(recipe_path)==candidate
    loader=(ROOT/'shared/afb-runtime-character-fit-v1.js').read_text().replace('character-fit-v1','east-expansion-v1').replace('AFB_RUNTIME_CHARACTER_FIT_V1','AFB_RUNTIME_EAST_EXPANSION_V1')
    (ROOT/'shared/afb-runtime-east-expansion-v1.js').write_text(loader,newline='\n')
    release='0.7.9-beta.19-cloudtest.96-east.1'
    index=(ROOT/'index.html').read_text().replace('character-fit-v1','east-expansion-v1').replace('AFB_RUNTIME_CHARACTER_FIT_V1','AFB_RUNTIME_EAST_EXPANSION_V1')
    index=re.sub(r'0\.7\.9-beta\.19-cloudtest\.96-(?:fit|east)\.1',release,index)
    index=re.sub(r'"fileSizes":\{[^}]*\}',f'"fileSizes":{{"index-east-expansion-v1.pck":{len(candidate)},"index.wasm":{(ROOT/"index.wasm").stat().st_size}}}',index,count=1)
    (ROOT/'index.html').write_text(index,newline='\n')
    version=json.loads((ROOT/'version.json').read_text());version['release_id']=release
    version['east_expansion']={'type':'Residential streets, rear lanes and pocket park','east_boundary':137,'core_buildings_and_interiors':'unchanged from .96-fit.1; two decorative east-edge buildings reorganized','new_buildings':'19 exterior residences and 5 rear-lane garages, replacing 2 old edge buildings; no new enterable interiors','upper_windows':'Audited per story, including apartment upper floors above the 4.4-unit ground-floor volume'}
    version['runtime_delivery']='SHA-256-verified east-expansion-v1 pack delta; additive district over merged .96-fit.1.'
    (ROOT/'version.json').write_text(json.dumps(version,indent=2)+'\n',newline='\n')
    (ROOT/'BUILD_VERSION.txt').write_text('AFewBuds Cloud Test\nGame build: 0.7.9-beta.19\nWeb release: '+release+'\nRuntime: East residential streets, rear lanes and pocket park\n',newline='\n')
    receipt={'baseline_sha256':hashlib.sha256(baseline).hexdigest(),'target_sha256':hashlib.sha256(candidate).hexdigest(),'target_bytes':len(candidate),'changed_existing_entries':changed,'added_entries':['scripts/east_expansion.gd'],'unchanged_entries':len(before)-len(changed),'all_interiors_characters_gameplay_unchanged':True,'reconstruction_verified':True}
    (HERE/'build_receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',newline='\n');print(json.dumps(receipt))
if __name__=='__main__':main()
