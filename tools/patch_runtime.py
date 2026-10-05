from pathlib import Path
import struct, hashlib, re, json

SOURCE = Path("index-cloudtest10.pck")
TARGET = Path("index-cloudtest10.pck")
PACK_URL = "index-cloudtest10.pck?build=27"
RELEASE = "0.7.9-beta.19-cloudtest.27"

def align(n, a=32):
    return (n+a-1)//a*a

def parse(path):
    blob=path.read_bytes()
    if blob[:4] != b"GDPC":
        raise SystemExit("not pck")
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
            raise SystemExit("md5 mismatch "+name)
        entries.append([name,data,flags])
    return blob,fb,entries

def rebuild(blob,fb,entries):
    out=bytearray(blob[:fb]); cur=0; directory=[]
    for name,data,flags in entries:
        at=align(cur)
        out.extend(b"\0"*(at-cur))
        off=at
        out.extend(data)
        cur=off+len(data)
        directory.append((name,off,len(data),hashlib.md5(data).digest(),flags))
    do=align(len(out))
    out.extend(b"\0"*(do-len(out)))
    struct.pack_into("<Q",out,32,do)
    out.extend(struct.pack("<I",len(directory)))
    for name,off,size,md5,flags in directory:
        raw=name.encode(); plen=(len(raw)+3)//4*4
        out.extend(struct.pack("<I",plen)); out.extend(raw); out.extend(b"\0"*(plen-len(raw)))
        out.extend(struct.pack("<Q",off)); out.extend(struct.pack("<Q",size)); out.extend(md5); out.extend(struct.pack("<I",flags))
    return bytes(out)

blob,fb,entries=parse(SOURCE)

for row in entries:
    if row[0]!="scripts/main.gd":
        continue
    text=row[1].decode("utf-8","replace").rstrip(" \n\0")

    old_heat='"description": "Use the fictional Reeves contact once to reduce Heat."'
    new_heat='"description": "Use the Reeves contact once to reduce Heat."'
    if old_heat not in text:
        raise SystemExit("Reeves reward dev wording missing")
    text=text.replace(old_heat,new_heat,1)

    old_alert='message = "A fictional contact named Reeves says people have been asking questions nearby."'
    new_alert='message = "Reeves says people have been asking questions nearby."'
    if old_alert not in text:
        raise SystemExit("Reeves alert dev wording missing")
    text=text.replace(old_alert,new_alert,1)

    rewards_intro = (
        '\tvar intro: Label = Label.new()\n'
        '\tintro.text = "Build AFewBuds across eight career tracks. Heat now turns Chapter 3 into a live risk-management layer alongside loyalty, staff, sales and genetics."\n'
        '\tintro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART\n'
        '\tphone_list.add_child(intro)\n\n'
    )
    if rewards_intro not in text:
        raise SystemExit("Rewards dev intro missing")
    text=text.replace(rewards_intro,"",1)

    if "fictional contact named Reeves" in text or "fictional Reeves contact" in text:
        raise SystemExit("Reeves fictional wording still present")
    if "Build AFewBuds across eight career tracks" in text:
        raise SystemExit("Rewards dev intro still present")
    if '"Task", "Chapter progress & rewards", "task"' not in text:
        raise SystemExit("Task hierarchy unexpectedly missing")
    if "CLOUD TEST" in text:
        raise SystemExit("visible CLOUD TEST wording returned")

    row[1]=text.encode()

packed=rebuild(blob,fb,entries)
TARGET.write_bytes(packed)

idx=Path("index.html")
html=idx.read_text()
html=re.sub(r'const AFB_TEST_RELEASE = "[^"]+";',f'const AFB_TEST_RELEASE = "{RELEASE}";',html,count=1)
html=re.sub(r'"fileSizes":\{[^}]*\}',f'"fileSizes":{{"{PACK_URL}":{len(packed)},"index.wasm":37902138}}',html,count=1)
html=re.sub(r'"mainPack":"[^"]+"',f'"mainPack":"{PACK_URL}"',html,count=1)
idx.write_text(html)

v=Path("version.json")
meta=json.loads(v.read_text())
meta["release_id"]=RELEASE
meta["storefront_control_location"]="BudShop top"
meta["phone_home"]="BudShop, Task, Settings"
meta["task_page"]="Chapter progress, Rewards"
meta["visible_dev_wording"]="removed"
v.write_text(json.dumps(meta,indent=2)+"\n")

print("Built",RELEASE)
print("Removed Reeves fictional wording")
print("Removed Rewards developer intro")
