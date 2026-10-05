from pathlib import Path
import struct, hashlib, re, json

SOURCE = Path("index-cloudtest24.pck")
TARGET = Path("index-cloudtest10.pck")
PACK_URL = "index-cloudtest10.pck?build=25"
RELEASE = "0.7.9-beta.19-cloudtest.25"

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

    prod_pat=re.compile(r'^func _build_products_app\(\) -> void:\n.*?(?=^func |\Z)',re.M|re.S)
    pm=prod_pat.search(text)
    if not pm:
        raise SystemExit("Your Supply builder missing")
    prod=pm.group(0)
    start=prod.find("\tvar business_card: PanelContainer = PanelContainer.new()")
    end=prod.find("\tfor name_variant in products.keys():")
    if start < 0 or end < 0 or end <= start:
        raise SystemExit("storefront card block missing")
    storefront=prod[start:end]
    prod=prod[:start]+prod[end:]
    prod=prod.replace(
        'intro.text = "Your phone storefront pulls directly from bagged inventory in storage. Customers can visit throughout the day. Traffic is lighter in the morning, normal in the afternoon, busiest in the evening, and quieter late at night. Use Away when you want uninterrupted production time."',
        'intro.text = "Manage bagged inventory, storefront listings, prices and reserved stock here."',
        1
    )
    text=text[:pm.start()]+prod.rstrip()+"\n\n"+text[pm.end():]

    bud_pat=re.compile(r'^func _build_budshop_app\(\) -> void:\n.*?(?=^func |\Z)',re.M|re.S)
    bm=bud_pat.search(text)
    if not bm:
        raise SystemExit("BudShop builder missing")
    bud=bm.group(0)
    bud=bud.replace("func _build_budshop_app() -> void:\n","func _build_budshop_app() -> void:\n"+storefront,1)
    text=text[:bm.start()]+bud.rstrip()+"\n\n"+text[bm.end():]

    bm=bud_pat.search(text)
    pm=prod_pat.search(text)
    if "STOREFRONT: %s" not in bm.group(0):
        raise SystemExit("storefront controls missing from BudShop")
    if "_set_business_away" not in bm.group(0) or "_reopen_business" not in bm.group(0):
        raise SystemExit("storefront actions missing from BudShop")
    if "STOREFRONT: %s" in pm.group(0):
        raise SystemExit("storefront controls still present in Your Supply")
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
v.write_text(json.dumps(meta,indent=2)+"\n")

print("Built",RELEASE)
print("Storefront controls moved to top of BudShop")
print("Your Supply now begins with inventory/listing controls")
