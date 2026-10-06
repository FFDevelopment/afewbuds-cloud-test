"""Publish the tested pack as a small deterministic delta against existing .63 assets."""
from pathlib import Path
import struct, hashlib, base64, json, difflib
ROOT=Path(__file__).resolve().parent.parent

def directory(blob):
    fb,do=struct.unpack_from('<QQ',blob,24);p=do+4;rows=[]
    for _ in range(struct.unpack_from('<I',blob,do)[0]):
        n=struct.unpack_from('<I',blob,p)[0];p+=4
        name=blob[p:p+n].rstrip(b'\0').decode();p+=n
        off,size=struct.unpack_from('<QQ',blob,p);p+=36
        rows.append((name,fb+off,size))
    return fb,do,rows

def main():
    base=(ROOT/'index-cloudtest10.pck').read_bytes()
    target=(ROOT/'index-cloudtest96.pck').read_bytes()
    fb,do,rows=directory(target)
    source={n:(o,s) for n,o,s in directory(base)[2]}
    segments=[]
    def add(data):
        if data:segments.append(['data',base64.b64encode(data).decode()])
    def copy(offset,length):
        if length:
            if segments and segments[-1][0]=='copy' and segments[-1][1]+segments[-1][2]==offset:
                segments[-1][2]+=length
            else:segments.append(['copy',offset,length])
    add(target[:fb]);cursor=fb
    for name,offset,size in rows:
        if offset>cursor:
            padding=target[cursor:offset]
            assert not any(padding)
            segments.append(['zero',len(padding)])
        data=target[offset:offset+size]
        if name in ['assets/characters/Malik.glb','assets/characters/Rod.glb','assets/characters/Malik_BaseColor.png','assets/characters/Rod_BaseColor.png','assets/furniture/walnut.png']:
            segments.append(['asset',name+'?v=96',len(data),hashlib.sha256(data).hexdigest()])
        elif name in source:
            old_offset,old_size=source[name];old=base[old_offset:old_offset+old_size]
            if old==data:copy(old_offset,old_size)
            elif name=='scripts/main.gd':
                old_lines=old.splitlines(keepends=True);new_lines=data.splitlines(keepends=True)
                offsets=[0]
                for line in old_lines:offsets.append(offsets[-1]+len(line))
                for op,a,b,c,d in difflib.SequenceMatcher(None,old_lines,new_lines,autojunk=False).get_opcodes():
                    if op=='equal':copy(old_offset+offsets[a],offsets[b]-offsets[a])
                    elif op in ('replace','insert'):add(b''.join(new_lines[c:d]))
            else:add(data)
        else:add(data)
        cursor=offset+size
    add(target[cursor:])
    recipe={'format':'afb-pack-delta-1','base_url':'index-cloudtest10.pck?build=63','base_size':len(base),'base_sha256':hashlib.sha256(base).hexdigest(),'target_size':len(target),'target_sha256':hashlib.sha256(target).hexdigest(),'segments':segments}
    result=bytearray()
    for row in segments:
        if row[0]=='copy':result.extend(base[row[1]:row[1]+row[2]])
        elif row[0]=='zero':result.extend(b'\0'*row[1])
        elif row[0]=='asset':result.extend((ROOT/row[1].split('?')[0]).read_bytes())
        else:result.extend(base64.b64decode(row[1]))
    assert bytes(result)==target
    destination=ROOT/'runtime/cloudtest96.patch.json';destination.parent.mkdir(exist_ok=True)
    destination.write_text(json.dumps(recipe,separators=(',',':'))+'\n')
    print('Verified byte-identical delta:',destination.stat().st_size,'bytes instead of',len(target))
if __name__=='__main__':main()
