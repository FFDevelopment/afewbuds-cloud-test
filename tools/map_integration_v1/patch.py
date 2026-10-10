"""Integrate the tested map while keeping mobile movement and touch adapters."""
import json
from pathlib import Path
HERE=Path(__file__).parent
PATCHES=json.loads((HERE/'map.patch.json').read_text())
def apply(source,name):
    lines=PATCHES[name];i=2
    while i<len(lines):
        assert lines[i].startswith('@@'),(name,lines[i]);i+=1
        old=[];new=[]
        while i<len(lines) and not lines[i].startswith('@@'):
            line=lines[i];i+=1
            if line[0] in ' -':old.append(line[1:])
            if line[0] in ' +':new.append(line[1:])
        before=''.join(old);after=''.join(new)
        assert source.count(before)==1,'Map integration source drift: '+name+' '+before[:180]
        source=source.replace(before,after,1)
    return source

def integrate(entries):
    result=[]
    seen=set()
    for name,data,flags in entries:
        if name in PATCHES:
            data=apply(data.decode(),name).encode();seen.add(name)
        result.append([name,data,flags])
    assert seen==set(PATCHES),set(PATCHES)-seen
    for name in ['grow_equipment_visuals.gd','parked_vehicle.gd','market_cart.gd']:
        result.append(['scripts/'+name,(HERE/name).read_bytes(),0])
    for path in sorted((HERE/'visual_lab').iterdir()):
        result.append(['visual_lab/'+path.name,path.read_bytes(),0])
    return result
