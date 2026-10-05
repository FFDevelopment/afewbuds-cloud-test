from pathlib import Path
import struct, hashlib, re, json

PCK=Path("index-cloudtest10.pck")
HTML=Path("index.html")
VERSION=Path("version.json")
BUILD=Path("BUILD_VERSION.txt")
RELEASE="0.7.9-beta.19-cloudtest.43"
PACK_URL="index-cloudtest10.pck?build=43"

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
        if hashlib.md5(data).digest()!=md5: raise SystemExit("md5 mismatch "+name)
        entries.append([name,data,flags])
    return blob,fb,entries

def rebuild(blob,fb,entries):
    out=bytearray(blob[:fb]); cur=0; directory=[]
    for name,data,flags in entries:
        at=align(cur); out.extend(b"\0"*(at-cur)); off=at; out.extend(data); cur=off+len(data)
        directory.append((name,off,len(data),hashlib.md5(data).digest(),flags))
    do=align(len(out)); out.extend(b"\0"*(do-len(out))); struct.pack_into("<Q",out,32,do)
    out.extend(struct.pack("<I",len(directory)))
    for name,off,size,md5,flags in directory:
        raw=name.encode(); plen=(len(raw)+3)//4*4
        out.extend(struct.pack("<I",plen)); out.extend(raw); out.extend(b"\0"*(plen-len(raw)))
        out.extend(struct.pack("<Q",off)); out.extend(struct.pack("<Q",size)); out.extend(md5); out.extend(struct.pack("<I",flags))
    return bytes(out)

blob,fb,entries=parse(PCK)
found=False
for row in entries:
    if row[0]!="scripts/main.gd": continue
    found=True
    text=row[1].decode("utf-8","replace").rstrip(" \n\0")
    if 'func _roman(value: int) -> String:' not in text:
        marker='func _dealer_locker_capacity() -> int:\n'
        if marker not in text:
            raise SystemExit("dealer locker helper anchor missing")
        helper='''func _roman(value: int) -> String:
\tmatch value:
\t\t1: return "I"
\t\t2: return "II"
\t\t3: return "III"
\t\t4: return "IV"
\t\t_: return str(value)

'''
        text=text.replace(marker,helper+marker,1)
    required=[
        'func _roman(value: int) -> String:',
        'const DEALER_COMMISSION_RATE: float = 0.10',
        'var dealer_customers_served_today: Dictionary = {}',
        'func _dealer_locker_add_from_storage',
        'func _dealer_locker_remove_to_storage',
        'func _dealer_sell_one(show_feedback: bool, assigned_dealer_name: String = "")',
        'Overflow stocked %dg %s in Dealer Locker',
    ]
    for needle in required:
        if needle not in text: raise SystemExit("hotfix verification failed: "+needle)
    row[1]=text.encode()
if not found: raise SystemExit("main.gd missing")

packed=rebuild(blob,fb,entries)
PCK.write_bytes(packed)
_,_,verify=parse(PCK)
source={}
for name,data,_ in verify:
    if name in ["scripts/main.gd","scripts/personal_inventory.gd","scripts/touch_scroll.gd"]:
        source[name]=data.decode("utf-8","replace")
if 'func _roman(value: int) -> String:' not in source.get("scripts/main.gd",""):
    raise SystemExit("roman helper absent after rebuild")
if 'DEALER STORAGE' not in source.get("scripts/personal_inventory.gd",""):
    raise SystemExit("dealer locker UI missing after hotfix")
if 'const TAP_SLOP: float = 12.0' not in source.get("scripts/touch_scroll.gd",""):
    raise SystemExit("mobile tap fix missing after hotfix")

html=HTML.read_text()
html=re.sub(r'const AFB_TEST_RELEASE = "[^"]+";',f'const AFB_TEST_RELEASE = "{RELEASE}";',html,count=1)
html=re.sub(r'"fileSizes":\{[^}]*\}',f'"fileSizes":{{"{PACK_URL}":{len(packed)},"index.wasm":37902138}}',html,count=1)
html=re.sub(r'"mainPack":"[^"]+"',f'"mainPack":"{PACK_URL}"',html,count=1)
HTML.write_text(html)

meta=json.loads(VERSION.read_text())
meta["release_id"]=RELEASE
meta["dealer_locker_hotfix"]="adds missing tier-name helper; cloudtest42 dealer behavior otherwise unchanged"
VERSION.write_text(json.dumps(meta,indent=2)+"\n")

if BUILD.exists():
    s=BUILD.read_text()
    s=re.sub(r"Web release: .*",f"Web release: {RELEASE}",s)
    if "Web release:" not in s: s+=f"\nWeb release: {RELEASE}\n"
    BUILD.write_text(s)

print("Built",RELEASE)
print("Dealer locker tier helper verified")
print("PCK bytes",len(packed))
