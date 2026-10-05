from pathlib import Path
import struct, hashlib, re, json, collections

PCK=Path("index-cloudtest10.pck")
HTML=Path("index.html")
VERSION=Path("version.json")
BUILD=Path("BUILD_VERSION.txt")
RELEASE="0.7.9-beta.19-cloudtest.56"
PACK_URL="index-cloudtest10.pck?build=56"

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
        if hashlib.md5(data).digest()!=md5: raise SystemExit("md5 "+name)
        entries.append([name,data,flags])
    return blob,fb,entries

def rebuild(blob,fb,entries):
    out=bytearray(blob[:fb]); cur=0; rows=[]
    for name,data,flags in entries:
        at=align(cur); out.extend(b"\0"*(at-cur)); off=at
        out.extend(data); cur=off+len(data)
        rows.append((name,off,len(data),hashlib.md5(data).digest(),flags))
    do=align(len(out)); out.extend(b"\0"*(do-len(out))); struct.pack_into("<Q",out,32,do)
    out.extend(struct.pack("<I",len(rows)))
    for name,off,size,md5,flags in rows:
        raw=name.encode(); plen=(len(raw)+3)//4*4
        out.extend(struct.pack("<I",plen)); out.extend(raw); out.extend(b"\0"*(plen-len(raw)))
        out.extend(struct.pack("<Q",off)); out.extend(struct.pack("<Q",size)); out.extend(md5); out.extend(struct.pack("<I",flags))
    return bytes(out)

def pat(name):
    return re.compile(r"^func "+re.escape(name)+r"\([^\n]*\)(?: -> [^:]+)?:\n.*?(?=^func |\Z)",re.M|re.S)

blob,fb,entries=parse(PCK)
found=False
for row in entries:
    if row[0]!="scripts/main.gd":
        continue
    found=True
    text=row[1].decode("utf-8","replace").rstrip(" \n\0")

    m=pat("_build_apartment_details").search(text)
    if not m: raise SystemExit("_build_apartment_details missing")
    block=m.group(0)

    locker_anchor=block.find('\t_add_box("LockerBody"')
    if locker_anchor<0: raise SystemExit("LockerBody anchor missing")
    kitchen=block[:locker_anchor]
    rest=block[locker_anchor:]

    replacements={
        'Vector3(2.18, 0.46, -3.54)':'Vector3(2.42, 0.46, -3.54)',
        'Vector3(2.18, 0.11, -3.46)':'Vector3(2.42, 0.11, -3.46)',
        'Vector3(2.18, 0.94, -3.52)':'Vector3(2.42, 0.94, -3.52)',
        'Vector3(2.18, 0.98, -3.08)':'Vector3(2.42, 0.98, -3.08)',
        'var lower_centers: Array[float] = [1.40, 2.18, 2.96]':'var lower_centers: Array[float] = [1.64, 2.42, 3.20]',
        'Vector3(2.18, 1.49, -3.935)':'Vector3(2.42, 1.49, -3.935)',
        'Vector3(2.18, 2.36, -3.72)':'Vector3(2.42, 2.36, -3.72)',
        'var upper_centers: Array[float] = [1.40, 2.18, 2.96]':'var upper_centers: Array[float] = [1.64, 2.42, 3.20]',
        'Vector3(2.18, 1.85, -3.47)':'Vector3(2.42, 1.85, -3.47)',
        'Vector3(2.18, 0.995, -3.46)':'Vector3(2.42, 0.995, -3.46)',
        'Vector3(2.18, 1.005, -3.46)':'Vector3(2.42, 1.005, -3.46)',
        'Vector3(2.18, 1.25, -3.79)':'Vector3(2.42, 1.25, -3.79)',
        'Vector3(2.18, 1.48, -3.70)':'Vector3(2.42, 1.48, -3.70)',
        'Vector3(2.18, 1.43, -3.60)':'Vector3(2.42, 1.43, -3.60)',
        'Vector3(2.45, 1.15, -3.77)':'Vector3(2.69, 1.15, -3.77)',
    }

    for old,new in replacements.items():
        if old in kitchen:
            kitchen=kitchen.replace(old,new,1)
        elif new not in kitchen:
            raise SystemExit("kitchen frame-clearance anchor missing: "+old)

    block=kitchen+rest
    text=text[:m.start()]+block.rstrip()+"\n\n"+text[m.end():]

    # Sanity: counter left edge should now be 2.42 - 2.62/2 = 1.11,
    # safely outside GrowDoorFrameR outer edge ~1.08.
    required=[
        'Vector3(2.42, 0.94, -3.52)',
        'Vector3(2.42, 1.49, -3.935)',
        'var lower_centers: Array[float] = [1.64, 2.42, 3.20]',
        'var upper_centers: Array[float] = [1.64, 2.42, 3.20]',
        'Vector3(2.42, 1.005, -3.46)',
        'Vector3(2.69, 1.15, -3.77)',
        '"LockerBody", Vector3(4.52, 1.28, -2.20)',
        'hidden_stash_interior_root.position = StorageVault.ANCHOR + Vector3(-0.24, 0.0, 0.0)',
        '"Bagging Bench III"',
    ]
    for needle in required:
        if needle not in text: raise SystemExit("verify "+needle)

    names=re.findall(r"^func\s+([A-Za-z0-9_]+)\(",text,re.M)
    dup={k:v for k,v in collections.Counter(names).items() if v>1}
    if dup: raise SystemExit("duplicates "+repr(dup))

    row[1]=text.encode("utf-8")

if not found: raise SystemExit("main missing")

packed=rebuild(blob,fb,entries)
PCK.write_bytes(packed)

_,_,verify=parse(PCK)
sources={name:data.decode("utf-8","replace") for name,data,_ in verify if name in ["scripts/main.gd","scripts/touch_scroll.gd","scripts/storage_vault.gd"]}
main=sources.get("scripts/main.gd","")
vault=sources.get("scripts/storage_vault.gd","")

for needle in [
    'Vector3(2.42, 0.94, -3.52)',
    'var lower_centers: Array[float] = [1.64, 2.42, 3.20]',
    'Vector3(2.42, 1.005, -3.46)',
]:
    if needle not in main: raise SystemExit("packed verify "+needle)

if 'const ANCHOR: Vector3 = Vector3(-4.33, 0.0, -0.30)' not in vault:
    raise SystemExit("vault anchor changed unexpectedly")
if "const TAP_SLOP: float = 12.0" not in sources.get("scripts/touch_scroll.gd",""):
    raise SystemExit("mobile tap fix lost")

html=HTML.read_text()
html=re.sub(r'const AFB_TEST_RELEASE = "[^"]+";',f'const AFB_TEST_RELEASE = "{RELEASE}";',html,count=1)
html=re.sub(r'const AFB_TEST_TITLE = "[^"]+";',f'const AFB_TEST_TITLE = "AFewBuds Cloud Test v{RELEASE}";',html,count=1)
html=re.sub(r'<title>AFewBuds Cloud Test[^<]*</title>',f'<title>AFewBuds Cloud Test {RELEASE}</title>',html,count=1)
html=re.sub(r'"fileSizes":\{[^}]*\}',f'"fileSizes":{{"{PACK_URL}":{len(packed)},"index.wasm":37902138}}',html,count=1)
html=re.sub(r'"mainPack":"[^"]+"',f'"mainPack":"{PACK_URL}"',html,count=1)
HTML.write_text(html)

meta=json.loads(VERSION.read_text())
meta["release_id"]=RELEASE
meta["kitchen_doorframe_clearance"]="entire modern kitchen run shifted +0.24 X so counter/backplash/uppers clear GrowDoorFrameR with a small safety gap"
meta["vault_position_rule"]="vault remains unchanged at StorageVault.ANCHOR z=-0.30; hidden stash keeps only prior X wall-fit correction"
meta["runtime_payload"]="cloudtest56 PCK with kitchen door-frame clearance hotfix"
VERSION.write_text(json.dumps(meta,indent=2)+"\n")

BUILD.write_text(
    "AFewBuds Cloud Test\n"
    "Game build: 0.7.9-beta.19\n"
    f"Web release: {RELEASE}\n"
    "Runtime: modern kitchen shifted right to clear grow-room door frame; vault unchanged\n"
)

print("Built",RELEASE,len(packed))

# finalized cloudtest56 deployment marker
