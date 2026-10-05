from pathlib import Path
import struct, hashlib, re, json

src=Path("index-cloudtest22.pck")
outp=Path("index-cloudtest23.pck")
blob=src.read_bytes()
fb=struct.unpack_from("<Q",blob,24)[0]
do=struct.unpack_from("<Q",blob,32)[0]
count=struct.unpack_from("<I",blob,do)[0]
pos=do+4
entries=[]
for _ in range(count):
    plen=struct.unpack_from("<I",blob,pos)[0]; pos+=4
    name=blob[pos:pos+plen].rstrip(b"\0").decode(); pos+=plen
    off=struct.unpack_from("<Q",blob,pos)[0]; pos+=8
    size=struct.unpack_from("<Q",blob,pos)[0]; pos+=8
    md5=blob[pos:pos+16]; pos+=16
    flags=struct.unpack_from("<I",blob,pos)[0]; pos+=4
    data=blob[fb+off:fb+off+size]
    if hashlib.md5(data).digest()!=md5:
        raise SystemExit("MD5 mismatch: "+name)
    entries.append([name,data,flags])

for row in entries:
    if row[0]!="scripts/main.gd":
        continue
    text=row[1].decode("utf-8","replace").rstrip(" \n\0")
    old='''\tview_label.offset_top = 98
\tview_label.offset_bottom = 132
'''
    new='''\tview_label.offset_top = 103
\tview_label.offset_bottom = 137
'''
    if old not in text:
        raise SystemExit("view label offsets not found")
    text=text.replace(old,new,1)
    if "CLOUD TEST" in text:
        raise SystemExit("visible CLOUD TEST wording returned")
    row[1]=text.encode()

out=bytearray(blob[:fb]); cursor=0; directory=[]
for name,data,flags in entries:
    aligned=(cursor+31)//32*32
    out.extend(b"\0"*(aligned-cursor))
    off=aligned
    out.extend(data)
    cursor=off+len(data)
    directory.append((name,off,len(data),hashlib.md5(data).digest(),flags))
ndo=(len(out)+31)//32*32
out.extend(b"\0"*(ndo-len(out)))
struct.pack_into("<Q",out,32,ndo)
out.extend(struct.pack("<I",len(directory)))
for name,off,size,md5,flags in directory:
    raw=name.encode(); plen=(len(raw)+3)//4*4
    out.extend(struct.pack("<I",plen)); out.extend(raw); out.extend(b"\0"*(plen-len(raw)))
    out.extend(struct.pack("<Q",off)); out.extend(struct.pack("<Q",size)); out.extend(md5); out.extend(struct.pack("<I",flags))
outp.write_bytes(out)

html=Path("index.html").read_text()
html=re.sub(r'const AFB_TEST_RELEASE = "[^"]+";','const AFB_TEST_RELEASE = "0.7.9-beta.19-cloudtest.23";',html,count=1)
html=re.sub(r'"fileSizes":\{[^}]*\}',f'"fileSizes":{{"{outp.name}":{len(out)},"index.wasm":37902138}}',html,count=1)
html=re.sub(r'"mainPack":"[^"]+"',f'"mainPack":"{outp.name}"',html,count=1)
Path("index.html").write_text(html)

v=json.loads(Path("version.json").read_text())
v["release_id"]="0.7.9-beta.19-cloudtest.23"
v["room_hint_adjustment"]="down-5px-from-cloudtest22"
Path("version.json").write_text(json.dumps(v,indent=2)+"\n")
print("Built cloudtest23 from cloudtest22; room/swipe wording moved down 5px")
