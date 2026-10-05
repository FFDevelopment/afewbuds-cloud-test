from pathlib import Path
import struct, hashlib, re, json

SRC=Path("index-cloudtest24.pck")
OUT=Path("index-cloudtest25.pck")
RELEASE="0.7.9-beta.19-cloudtest.25"

blob=SRC.read_bytes()
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

def get_func(text,name):
    pat=re.compile(r'^func '+re.escape(name)+r'\([^\n]*\)(?: -> [^:]+)?:\n.*?(?=^func |\Z)',re.M|re.S)
    m=pat.search(text)
    if not m:
        raise SystemExit("Function missing: "+name)
    return pat,m,m.group(0)

for row in entries:
    if row[0]!="scripts/main.gd":
        continue
    text=row[1].decode("utf-8","replace").rstrip(" \n\0")

    # Extract storefront control card from Your Supply.
    prod_pat,prod_match,products_fn=get_func(text,"_build_products_app")
    start=products_fn.find("\tvar business_card: PanelContainer = PanelContainer.new()")
    end=products_fn.find("\tfor name_variant in products.keys():")
    if start<0 or end<0 or end<=start:
        raise SystemExit("Storefront card block not found in Your Supply")
    storefront_block=products_fn[start:end]

    # Remove storefront control card from Your Supply.
    products_new=products_fn[:start]+products_fn[end:]
    products_new=products_new.replace(
        'intro.text = "Your phone storefront pulls directly from bagged inventory in storage. Customers can visit throughout the day. Traffic is lighter in the morning, normal in the afternoon, busiest in the evening, and quieter late at night. Use Away when you want uninterrupted production time."',
        'intro.text = "Manage bagged inventory, storefront listings, prices and reserved stock here."',
        1
    )
    text=text[:prod_match.start()]+products_new.rstrip()+"\n\n"+text[prod_match.end():]

    # Re-find BudShop after text changed and put storefront controls above categories.
    bud_pat,bud_match,bud_fn=get_func(text,"_build_budshop_app")
    insert='\tphone_list.add_child(intro)\n'
    if insert not in bud_fn:
        raise SystemExit("BudShop intro insertion point missing")
    bud_new=bud_fn.replace(
        insert,
        insert+"\n"+storefront_block,
        1
    )
    text=text[:bud_match.start()]+bud_new.rstrip()+"\n\n"+text[bud_match.end():]

    # Hard checks: exactly one storefront card, now inside BudShop only.
    _,_,bud_check=get_func(text,"_build_budshop_app")
    _,_,prod_check=get_func(text,"_build_products_app")
    if "STOREFRONT: %s" not in bud_check:
        raise SystemExit("Storefront controls missing from BudShop")
    if "_set_business_away" not in bud_check or "_reopen_business" not in bud_check:
        raise SystemExit("Storefront open/away actions missing from BudShop")
    if "STOREFRONT: %s" in prod_check or "_set_business_away" in prod_check or "_reopen_business" in prod_check:
        raise SystemExit("Storefront controls still present in Your Supply")
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
OUT.write_bytes(out)

html=Path("index.html").read_text()
html=re.sub(r'const AFB_TEST_RELEASE = "[^"]+";',f'const AFB_TEST_RELEASE = "{RELEASE}";',html,count=1)
html=re.sub(r'"fileSizes":\{[^}]*\}',f'"fileSizes":{{"{OUT.name}":{len(out)},"index.wasm":37902138}}',html,count=1)
html=re.sub(r'"mainPack":"[^"]+"',f'"mainPack":"{OUT.name}"',html,count=1)
Path("index.html").write_text(html)

v=json.loads(Path("version.json").read_text())
v["release_id"]=RELEASE
v["storefront_control_location"]="BudShop top"
Path("version.json").write_text(json.dumps(v,indent=2)+"\n")
print("Built cloudtest25: storefront controls moved from Your Supply to top of BudShop")
