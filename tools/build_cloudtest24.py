from pathlib import Path
import struct, hashlib, re, json, collections

PCK=Path("index-cloudtest10.pck")
HTML=Path("index.html")
VERSION=Path("version.json")
BUILD=Path("BUILD_VERSION.txt")
RELEASE="0.7.9-beta.19-cloudtest.58"
PACK_URL="index-cloudtest10.pck?build=58"

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

blob,fb,entries=parse(PCK)
found=False

for row in entries:
    if row[0]!="scripts/main.gd":
        continue
    found=True
    text=row[1].decode("utf-8","replace").rstrip(" \n\0")

    # Remove the three fake building/window placeholder boxes that render as
    # dark squares on the living-room window.
    window_lines=[
        '\t_add_box("WindowBuildingA", Vector3(-4.18, 1.85, 5.74), Vector3(0.34, 0.58, 0.022), Color("202a31"), 0.92)\n',
        '\t_add_box("WindowBuildingB", Vector3(-3.65, 1.72, 5.74), Vector3(0.46, 0.84, 0.022), Color("263038"), 0.92)\n',
        '\t_add_box("WindowBuildingC", Vector3(-3.05, 1.90, 5.74), Vector3(0.38, 0.48, 0.022), Color("1e282f"), 0.92)\n',
    ]
    for line in window_lines:
        if line in text:
            text=text.replace(line,"",1)

    # Pull the Hidden Wall Stash another 0.12 toward the left wall.
    old='hidden_stash_interior_root.position = StorageVault.ANCHOR + Vector3(-0.24, 0.0, 0.0)'
    new='hidden_stash_interior_root.position = StorageVault.ANCHOR + Vector3(-0.36, 0.0, 0.0)'
    if old in text:
        text=text.replace(old,new,1)
    elif new not in text:
        raise SystemExit("hidden stash wall-fit anchor missing")

    required=[
        'hidden_stash_interior_root.position = StorageVault.ANCHOR + Vector3(-0.36, 0.0, 0.0)',
        '"WindowGlass"',
        '"WindowFrame"',
        '"WindowSun"',
        '"Bagging Bench III"',
        'var plant_direct_scroll: PhoneTouchScroll',
    ]
    for needle in required:
        if needle not in text: raise SystemExit("verify "+needle)

    forbidden=[
        '"WindowBuildingA"',
        '"WindowBuildingB"',
        '"WindowBuildingC"',
        'hidden_stash_interior_root.position = StorageVault.ANCHOR + Vector3(-0.24, 0.0, 0.0)',
    ]
    for needle in forbidden:
        if needle in text: raise SystemExit("old visual remains: "+needle)

    names=re.findall(r"^func\s+([A-Za-z0-9_]+)\(",text,re.M)
    dup={k:v for k,v in collections.Counter(names).items() if v>1}
    if dup: raise SystemExit("duplicates "+repr(dup))

    row[1]=text.encode("utf-8")

if not found:
    raise SystemExit("main missing")

packed=rebuild(blob,fb,entries)
PCK.write_bytes(packed)

_,_,verify=parse(PCK)
sources={name:data.decode("utf-8","replace") for name,data,_ in verify if name in ["scripts/main.gd","scripts/touch_scroll.gd","scripts/storage_vault.gd"]}
main=sources.get("scripts/main.gd","")
vault=sources.get("scripts/storage_vault.gd","")

if 'hidden_stash_interior_root.position = StorageVault.ANCHOR + Vector3(-0.36, 0.0, 0.0)' not in main:
    raise SystemExit("packed stash offset missing")
for needle in ['"WindowBuildingA"','"WindowBuildingB"','"WindowBuildingC"']:
    if needle in main:
        raise SystemExit("packed window placeholder remains: "+needle)
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
meta["window_cleanup"]="removed WindowBuildingA/B/C placeholder boxes that appeared as three dark squares on the living-room window"
meta["hidden_stash_wall_fit"]="Hidden Wall Stash moved from -0.24 to -0.36 X offset toward left wall; vault anchor unchanged"
meta["runtime_payload"]="cloudtest58 PCK with window placeholder cleanup and final Hidden Wall Stash wall-fit pass"
VERSION.write_text(json.dumps(meta,indent=2)+"\n")

BUILD.write_text(
    "AFewBuds Cloud Test\n"
    "Game build: 0.7.9-beta.19\n"
    f"Web release: {RELEASE}\n"
    "Runtime: remove three window placeholder squares + move Hidden Wall Stash another 0.12 toward wall\n"
)

print("Built",RELEASE,len(packed))

# finalized cloudtest58 deployment marker
