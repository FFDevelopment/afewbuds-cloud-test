from pathlib import Path
import struct, hashlib, re, json

SOURCE = Path("index-cloudtest10.pck")
TARGET = Path("index-cloudtest10.pck")
PACK_URL = "index-cloudtest10.pck?build=26"
RELEASE = "0.7.9-beta.19-cloudtest.26"

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

    # Main phone: replace direct Rewards tile with Task.
    old_home='''\t_add_phone_app_tile(grid, "", "BudShop", "Store, business & operations", "budshop")
\t_add_phone_app_tile(grid, "", "Rewards", "%d ready to claim" % _advancement_ready_count(), "advancements")
\t_add_phone_app_tile(grid, "", "Settings", "Help & system controls", "settings")
'''
    new_home='''\t_add_phone_app_tile(grid, "", "BudShop", "Store, business & operations", "budshop")
\t_add_phone_app_tile(grid, "", "Task", "Chapter progress & rewards", "task")
\t_add_phone_app_tile(grid, "", "Settings", "Help & system controls", "settings")
'''
    if old_home not in text:
        raise SystemExit("phone home Rewards tile block missing")
    text=text.replace(old_home,new_home,1)

    # Task page: chapter/story progress first, then Rewards category.
    task_builder='''func _build_task_app() -> void:
\t_build_story_progress_section()
\tvar grid: GridContainer = _phone_category_grid()
\t_add_phone_app_tile(grid, "", "Rewards", "%d ready to claim" % _advancement_ready_count(), "advancements")

'''
    marker='func _build_phone_home() -> void:\n'
    if marker not in text:
        raise SystemExit("phone home builder marker missing")
    if 'func _build_task_app() -> void:' not in text:
        text=text.replace(marker,task_builder+marker,1)

    # Rewards page should now contain rewards only; chapter info lives in Task.
    rewards_start='func _build_advancements_app() -> void:\n\t_build_story_progress_section()\n'
    if rewards_start not in text:
        raise SystemExit("Rewards chapter section call missing")
    text=text.replace(rewards_start,'func _build_advancements_app() -> void:\n',1)

    # Back navigation: Rewards -> Task.
    parent_pat=re.compile(r'^func _phone_parent_app\(app_name: String\) -> String:\n.*?(?=^func |\Z)',re.M|re.S)
    pm=parent_pat.search(text)
    if not pm:
        raise SystemExit("phone parent router missing")
    parent_fn=pm.group(0)
    target='\tif app_name in ["help", "system"]:\n\t\treturn "settings"\n'
    if target not in parent_fn:
        raise SystemExit("settings parent route missing")
    parent_fn=parent_fn.replace(
        target,
        '\tif app_name == "advancements":\n\t\treturn "task"\n'+target,
        1
    )
    text=text[:pm.start()]+parent_fn.rstrip()+"\n\n"+text[pm.end():]

    # Route Task in phone refresh.
    refresh_pat=re.compile(r'^func _refresh_phone\(\) -> void:\n.*?(?=^func |\Z)',re.M|re.S)
    rm=refresh_pat.search(text)
    if not rm:
        raise SystemExit("phone refresh router missing")
    rf=rm.group(0)
    route='''\t\t"settings":
\t\t\tphone_title.text = "Settings"
\t\t\t_build_settings_app()
'''
    if route not in rf:
        raise SystemExit("settings route missing")
    rf=rf.replace(
        route,
        '''\t\t"task":
\t\t\tphone_title.text = "Task"
\t\t\t_build_task_app()
'''+route,
        1
    )
    text=text[:rm.start()]+rf.rstrip()+"\n\n"+text[rm.end():]

    # Bottom dock follows the new top-level hierarchy.
    old_dock='\t_add_phone_dock_button(dock, "REWARDS", "advancements")\n'
    new_dock='\t_add_phone_dock_button(dock, "TASK", "task")\n'
    if old_dock not in text:
        raise SystemExit("Rewards dock button missing")
    text=text.replace(old_dock,new_dock,1)

    # Verification.
    checks=[
        '"Task", "Chapter progress & rewards", "task"',
        'func _build_task_app() -> void:',
        '_build_story_progress_section()',
        '"Rewards", "%d ready to claim" % _advancement_ready_count(), "advancements"',
        'if app_name == "advancements":',
        'return "task"',
        '"task":',
        'phone_title.text = "Task"',
        '"TASK", "task"',
    ]
    for needle in checks:
        if needle not in text:
            raise SystemExit("Task hierarchy verification failed: "+needle)

    adv_pat=re.compile(r'^func _build_advancements_app\(\) -> void:\n.*?(?=^func |\Z)',re.M|re.S)
    am=adv_pat.search(text)
    if not am:
        raise SystemExit("Rewards builder missing after patch")
    if "_build_story_progress_section()" in am.group(0):
        raise SystemExit("chapter info still present in Rewards")
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
meta["storefront_control_location"]="BudShop top"\nmeta["phone_home"]="BudShop, Task, Settings"\nmeta["task_page"]="Chapter progress, Rewards"
v.write_text(json.dumps(meta,indent=2)+"\n")

print("Built",RELEASE)
print("Storefront controls moved to top of BudShop")
print("Your Supply now begins with inventory/listing controls")
