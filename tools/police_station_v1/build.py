"""Append the police district to the verified seated-camera release."""
from pathlib import Path
import argparse,base64,difflib,hashlib,importlib.util,json,re
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
east=module('east_builder',ROOT/'tools/east_expansion_v1/build.py')
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output-dir',required=True);args=ap.parse_args()
    out=Path(args.output_dir).resolve();out.mkdir(parents=True,exist_ok=True)
    baseline=east.fit.read_recipe(ROOT/'runtime/east-expansion-v1.patch.json')
    assert hashlib.sha256(baseline).hexdigest()=='746ee56a3dee5bf02db4eb993752dc37a18fb7f72e720f0c8f4f24d6e56702a4'
    fb,entries=east.pack.parse(baseline);before={n:b for n,b,f in entries}
    neighborhood=module('police_patch',HERE/'patch.py').apply(before['scripts/neighborhood.gd'].decode())
    district=before['scripts/east_expansion.gd'].decode().replace('const EAST_LIMIT:=137.0','const EAST_LIMIT:=201.0').replace('Vector2(114,143)','Vector2(114,139)')
    replacements={'scripts/neighborhood.gd':neighborhood.encode(),'scripts/east_expansion.gd':district.encode()}
    updated=[[n,replacements.get(n,b),f] for n,b,f in entries]
    added=[('station.gd','police_station.gd'),('district.gd','police_district.gd'),('door.gd','police_door.gd'),('surface.gdshader','police_surface.gdshader'),('bark.gdshader','bark.gdshader')]
    for filename,target in added:updated.append(['scripts/'+target,(HERE/filename).read_text().encode(),0])
    built=east.pack.rebuild(baseline,fb,updated);after={n:b for n,b,f in east.pack.parse(built)[1]}
    changed=[n for n in before if before[n]!=after[n]]
    assert set(changed)==set(replacements),changed
    (out/'candidate.pck').write_bytes(built);(HERE/'neighborhood.gd').write_text(neighborhood,newline='\n')
    east.fit.extract(entries,out/'baseline','Police Baseline');east.fit.extract(updated,out/'candidate','Police Candidate')
    base=(ROOT/'index-cloudtest10.pck').read_bytes();source={n:(o,s) for n,o,s in east.directory(base)}
    segments=[]
    def add(data):
        if data:segments.append(['data',base64.b64encode(data).decode()])
    def copy(offset,size):
        if size:segments.append(['copy',offset,size])
    add(built[:fb]);cursor=fb
    assets=['assets/characters/Malik.glb','assets/characters/Rod.glb','assets/characters/Malik_BaseColor.png','assets/characters/Rod_BaseColor.png','assets/furniture/walnut.png']
    for name,offset,size in east.directory(built):
        if offset>cursor:
            assert not any(built[cursor:offset]);segments.append(['zero',offset-cursor])
        data=built[offset:offset+size]
        if name in assets:segments.append(['asset',name+'?v=police-station-v1',size,hashlib.sha256(data).hexdigest()])
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
    recipe_path=ROOT/'runtime/police-station-v1.patch.json';recipe_path.write_text(json.dumps(recipe,separators=(',',':'))+'\n',newline='\n')
    assert east.fit.read_recipe(recipe_path)==built
    loader=(ROOT/'shared/afb-runtime-east-expansion-v1.js').read_text().replace('east-expansion-v1','police-station-v1').replace('AFB_RUNTIME_EAST_EXPANSION_V1','AFB_RUNTIME_POLICE_STATION_V1')
    loader=loader.replace('patch.json?v=1','patch.json?v=2')
    (ROOT/'shared/afb-runtime-police-station-v1.js').write_text(loader,newline='\n')
    release='0.7.9-beta.19-cloudtest.97-police.2'
    index=(ROOT/'index.html').read_text().replace('east-expansion-v1','police-station-v1').replace('AFB_RUNTIME_EAST_EXPANSION_V1','AFB_RUNTIME_POLICE_STATION_V1')
    index=index.replace('afb-runtime-police-station-v1.js?v=1','afb-runtime-police-station-v1.js?v=2')
    index=re.sub(r'0\.7\.9-beta\.19-cloudtest\.(?:96-east|97-police)\.\d+',release,index)
    index=re.sub(r'"fileSizes":\{[^}]*\}',f'"fileSizes":{{"index-police-station-v1.pck":{len(built)},"index.wasm":{(ROOT/"index.wasm").stat().st_size}}}',index,count=1)
    (ROOT/'index.html').write_text(index,newline='\n')
    version=json.loads((ROOT/'version.json').read_text());version['release_id']=release
    version['police_station']={'east_boundary':201,'interior':'Two continuous floors, working doors and walkable stairs','area':'Police station, rear patrol parking, east public parking and road extension','gameplay':'Explorable building; no arrest, police AI or evidence gameplay added'}
    version['runtime_delivery']='SHA-256-verified police-station-v1 delta over .96-east.3'
    (ROOT/'version.json').write_text(json.dumps(version,indent=2)+'\n',newline='\n')
    (ROOT/'BUILD_VERSION.txt').write_text('AFewBuds Cloud Test\nGame build: 0.7.9-beta.19\nWeb release: '+release+'\nRuntime: Police station district and two-floor interior\n',newline='\n')
    receipt={'baseline_sha256':hashlib.sha256(baseline).hexdigest(),'target_sha256':hashlib.sha256(built).hexdigest(),'target_bytes':len(built),'changed_existing_entries':changed,'added_entries':['scripts/'+target for filename,target in added],'unchanged_entries':len(before)-len(changed),'reconstruction_verified':True}
    (HERE/'build_receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',newline='\n');print(json.dumps(receipt))
if __name__=='__main__':main()
