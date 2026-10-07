"""Add Kobi to the verified police/park repair runtime; preserve other entries."""
from pathlib import Path
import argparse,base64,difflib,hashlib,importlib.util,json,re
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
east=module('east_builder',ROOT/'tools/east_expansion_v1/build.py')
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output-dir',required=True);args=ap.parse_args()
    out=Path(args.output_dir).resolve();out.mkdir(parents=True,exist_ok=True)
    baseline=east.fit.read_recipe(ROOT/'runtime/police-station-v1.patch.json')
    assert hashlib.sha256(baseline).hexdigest()=='21702e3db6652ef425c1d072a797cdf6f9e4686b2cb9b2253e1c70d1c9f849a4'
    fb,entries=east.pack.parse(baseline);before={n:b for n,b,f in entries}
    crew=before['scripts/crew_phone.gd'].decode()
    assert crew.count('["Malik","Rod"]')==5
    crew=crew.replace('["Malik","Rod"]','["Malik","Rod","Kobi"]')
    updated=[[n,crew.encode() if n=='scripts/crew_phone.gd' else b,f] for n,b,f in entries]
    added=['assets/characters/Kobi.glb','assets/characters/Kobi_BaseColor.png']
    for name in added:updated.append([name,(ROOT/name).read_bytes(),0])
    built=east.pack.rebuild(baseline,fb,updated);after={n:b for n,b,f in east.pack.parse(built)[1]}
    changed=[n for n in before if before[n]!=after[n]]
    assert changed==['scripts/crew_phone.gd'],changed
    (out/'candidate.pck').write_bytes(built)
    east.fit.extract(updated,out/'candidate','Kobi Candidate')
    base=(ROOT/'index-cloudtest10.pck').read_bytes();source={n:(o,s) for n,o,s in east.directory(base)}
    segments=[]
    def add(data):
        if data:segments.append(['data',base64.b64encode(data).decode()])
    def copy(offset,size):
        if size:segments.append(['copy',offset,size])
    add(built[:fb]);cursor=fb
    assets=['assets/characters/Kobi.glb','assets/characters/Kobi_BaseColor.png','assets/characters/Malik.glb','assets/characters/Rod.glb','assets/characters/Malik_BaseColor.png','assets/characters/Rod_BaseColor.png','assets/furniture/walnut.png']
    for name,offset,size in east.directory(built):
        if offset>cursor:
            assert not any(built[cursor:offset]);segments.append(['zero',offset-cursor])
        data=built[offset:offset+size]
        if name in assets:segments.append(['asset',name+'?v=kobi-v1',size,hashlib.sha256(data).hexdigest()])
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
    recipe_path=ROOT/'runtime/kobi-v1.patch.json';recipe_path.write_text(json.dumps(recipe,separators=(',',':'))+'\n',newline='\n')
    assert east.fit.read_recipe(recipe_path)==built
    loader=(ROOT/'shared/afb-runtime-police-station-v1.js').read_text().replace('police-station-v1','kobi-v1').replace('AFB_RUNTIME_POLICE_STATION_V1','AFB_RUNTIME_KOBI_V1').replace('patch.json?v=3','patch.json?v=1')
    (ROOT/'shared/afb-runtime-kobi-v1.js').write_text(loader,newline='\n')
    release='0.7.9-beta.19-cloudtest.98-kobi.1'
    index=(ROOT/'index.html').read_text().replace('police-station-v1','kobi-v1').replace('AFB_RUNTIME_POLICE_STATION_V1','AFB_RUNTIME_KOBI_V1')
    index=re.sub(r'afb-runtime-kobi-v1\.js\?v=\d+','afb-runtime-kobi-v1.js?v=1',index)
    index=re.sub(r'0\.7\.9-beta\.19-cloudtest\.(?:97-police|98-kobi)\.\d+',release,index)
    index=re.sub(r'"fileSizes":\{[^}]*\}',f'"fileSizes":{{"index-kobi-v1.pck":{len(built)},"index.wasm":{(ROOT/"index.wasm").stat().st_size}}}',index,count=1)
    (ROOT/'index.html').write_text(index,newline='\n')
    version=json.loads((ROOT/'version.json').read_text());version['release_id']=release
    version['kobi_npc']={'appearances':['existing customer visits','production worker','manager'],'shared_rig_bones':56,'clips':['idle','walk','bend_test','sit'],'outfit':'Plain white crewneck, khaki trousers, original light sneakers'}
    version['runtime_delivery']='SHA-256-verified kobi-v1 delta over .97-police.3'
    (ROOT/'version.json').write_text(json.dumps(version,indent=2)+'\n',newline='\n')
    (ROOT/'BUILD_VERSION.txt').write_text('AFewBuds Cloud Test\nGame build: 0.7.9-beta.19\nWeb release: '+release+'\nRuntime: Kobi NPC plus police and park repairs\n',newline='\n')
    receipt={'baseline_sha256':hashlib.sha256(baseline).hexdigest(),'target_sha256':hashlib.sha256(built).hexdigest(),'target_bytes':len(built),'changed_existing_entries':changed,'added_entries':added,'unchanged_entries':len(before)-len(changed),'reconstruction_verified':True}
    (HERE/'build_receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',newline='\n');print(json.dumps(receipt))
if __name__=='__main__':main()
