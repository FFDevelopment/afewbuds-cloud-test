from pathlib import Path
import struct, hashlib, re, json, sys

if len(sys.argv) != 4:
    raise SystemExit("usage: rebuild_from_main.py <stable_pck> <feature_pck> <cloud_repo_dir>")

STABLE_PCK = Path(sys.argv[1])
FEATURE_PCK = Path(sys.argv[2])
ROOT = Path(sys.argv[3])
OUT_PCK = ROOT / "index-cloudtest13.pck"
RELEASE_ID = "0.7.9-beta.19-cloudtest.13"
HUD_MARKER = "CLOUD TEST .13"

def align(n, a=32):
    return (n + a - 1) // a * a

def parse_pck(path):
    blob = path.read_bytes()
    if blob[:4] != b"GDPC":
        raise SystemExit(f"not pck: {path}")
    file_base = struct.unpack_from("<Q", blob, 24)[0]
    dir_offset = struct.unpack_from("<Q", blob, 32)[0]
    count = struct.unpack_from("<I", blob, dir_offset)[0]
    pos = dir_offset + 4
    out = []
    for _ in range(count):
        plen = struct.unpack_from("<I", blob, pos)[0]; pos += 4
        raw = blob[pos:pos+plen]; pos += plen
        name = raw.rstrip(b"\0").decode()
        off = struct.unpack_from("<Q", blob, pos)[0]; pos += 8
        size = struct.unpack_from("<Q", blob, pos)[0]; pos += 8
        md5 = blob[pos:pos+16]; pos += 16
        flags = struct.unpack_from("<I", blob, pos)[0]; pos += 4
        data = blob[file_base+off:file_base+off+size]
        if hashlib.md5(data).digest() != md5:
            raise SystemExit("md5 mismatch: " + name)
        out.append([name, data, flags])
    return blob, file_base, out

def funcs(text):
    found={}
    pat=re.compile(r'^func ([A-Za-z0-9_]+)\([^\n]*\)(?: -> [^:]+)?:\n.*?(?=^func |\Z)', re.M|re.S)
    for m in pat.finditer(text):
        found[m.group(1)]=m.group(0).rstrip()
    return found

def replace_func(dst, src_funcs, name):
    if name not in src_funcs:
        raise SystemExit("stable function missing: "+name)
    pat=re.compile(r'^func '+re.escape(name)+r'\([^\n]*\)(?: -> [^:]+)?:\n.*?(?=^func |\Z)', re.M|re.S)
    m=pat.search(dst)
    if not m:
        raise SystemExit("feature function missing: "+name)
    return dst[:m.start()] + src_funcs[name] + "\n\n" + dst[m.end():]

def rebuild(header_blob, file_base, entries):
    out = bytearray(header_blob[:file_base])
    cursor = 0
    directory = []
    for name, data, flags in entries:
        target = align(cursor, 32)
        if target > cursor:
            out.extend(b"\0" * (target - cursor))
        off = target
        out.extend(data)
        cursor = off + len(data)
        directory.append((name, off, len(data), hashlib.md5(data).digest(), flags))
    dir_offset = align(len(out), 32)
    if dir_offset > len(out):
        out.extend(b"\0" * (dir_offset - len(out)))
    struct.pack_into("<Q", out, 32, dir_offset)
    out.extend(struct.pack("<I", len(directory)))
    for name, off, size, md5, flags in directory:
        raw=name.encode()
        plen=(len(raw)+3)//4*4
        out.extend(struct.pack("<I", plen))
        out.extend(raw)
        out.extend(b"\0"*(plen-len(raw)))
        out.extend(struct.pack("<Q", off))
        out.extend(struct.pack("<Q", size))
        out.extend(md5)
        out.extend(struct.pack("<I", flags))
    return bytes(out)

stable_blob, stable_fb, stable_entries = parse_pck(STABLE_PCK)
_, _, feature_entries = parse_pck(FEATURE_PCK)

stable = {name:[data,flags] for name,data,flags in stable_entries}
feature = {name:[data,flags] for name,data,flags in feature_entries}

stable_main = stable["scripts/main.gd"][0].decode("utf-8","replace").rstrip(" \n\0")
feature_main = feature["scripts/main.gd"][0].decode("utf-8","replace").rstrip(" \n\0")

# Start with the feature gameplay script so the approved cloud-test work is retained.
# Then force save/resume/lifecycle primitives back to the exact working main runtime.
stable_funcs = funcs(stable_main)
stable_funcs["_ready"] = stable_funcs["_ready"] + '\n\tcall_deferred("_init_personal_inventory_deferred")'

for name in [
    "_ready",
    "_capture_runtime_state",
    "_restore_runtime_state",
    "_go_to_view",
    "_pause_gameplay",
    "_resume_gameplay",
    "_notification",
    "_install_lifecycle_hooks",
    "_on_browser_pause",
]:
    feature_main = replace_func(feature_main, stable_funcs, name)

# Inventory initialization is isolated from the working main startup path.
if 'func _init_personal_inventory_deferred() -> void:' not in feature_main:
    helper = '''func _init_personal_inventory_deferred() -> void:
\tif personal_inventory != null:
\t\treturn
\tpersonal_inventory = PersonalInventory.new()
\tadd_child(personal_inventory)
\tpersonal_inventory.setup(self)

'''
    marker = 'func _process(delta: float) -> void:\n'
    if marker not in feature_main:
        raise SystemExit("process marker missing for deferred inventory helper")
    feature_main = feature_main.replace(marker, helper + marker, 1)

# Visible test marker only. Internal app/save identity comes from main's project.godot.
feature_main = re.sub(r'CLOUD TEST \.\d+', HUD_MARKER, feature_main)
feature_main = feature_main.replace(
    '\t\t"workbench": _go_to_view("main_workbench")\n\t\t"storage": _go_to_view("main_storage")',
    '\t\t"workbench": _go_to_view("main_workbench")\n\t\t"locker": _go_to_view("main_workbench")\n\t\t"storage": _go_to_view("main_storage")',
    1
)

# Verify exact-view resume survived the rebuild.
required = [
    '"current_view": current_view',
    '"current_room": current_room',
    'var saved_view: String = str(restored_runtime.get("current_view", "main_grow_door"))',
    '_go_to_view(saved_view, false)',
]
for needle in required:
    if needle not in feature_main:
        raise SystemExit("resume parity check failed: "+needle)
if 'create_timer(0.12).timeout.connect(_go_to_view.bind' in feature_main:
    raise SystemExit("stale delayed camera override survived")

# Base every packaged file on working main.
out_map={name:[data,flags] for name,data,flags in stable_entries}

# Overlay only the additions that existed in the feature build and not in main.
approved_added=[]
for name,(data,flags) in feature.items():
    if name.startswith("assets/characters/peephole/") or name in [
        "scripts/inventory_slot.gd",
        "scripts/personal_inventory.gd",
    ]:
        if name == "scripts/personal_inventory.gd":
            text=data.decode("utf-8","replace").rstrip(" \n\0")
            text=text.replace("\t_build_backpack_button()\n","",1)
            text=text.replace(
                '\t_add_grid(left,"backpack",BACKPACK_SLOTS)\n',
                '\t_add_grid(left,"backpack",BACKPACK_SLOTS)\n\tfor item in _items("backpack"):\n\t\t_source_button(left,"MOVE %s -> LOCKER" % str(item.get("name","ITEM")),_inventory_drop.bind({"source":"backpack","item":item},"locker"))\n',
                1
            )
            text=text.replace(
                '\t_add_grid(right,"locker",LOCKER_SLOTS)\n',
                '\t_add_grid(right,"locker",LOCKER_SLOTS)\n\tfor item in _items("locker"):\n\t\t_source_button(right,"MOVE %s -> BAG" % str(item.get("name","ITEM")),_inventory_drop.bind({"source":"locker","item":item},"backpack"))\n',
                1
            )
            data=text.encode()
        out_map[name]=[data,flags]
        approved_added.append(name)

# Overlay the selectively merged gameplay script.
out_map["scripts/main.gd"]=[feature_main.encode(), stable["scripts/main.gd"][1]]

# project.godot is intentionally copied from working main byte-for-byte.
out_map["project.godot"]=[stable["project.godot"][0], stable["project.godot"][1]]

# Preserve main PCK order, then append approved new files in deterministic order.
ordered=[]
seen=set()
for name,_,_ in stable_entries:
    data,flags=out_map[name]
    ordered.append([name,data,flags]); seen.add(name)
for name in sorted(approved_added):
    if name not in seen:
        data,flags=out_map[name]
        ordered.append([name,data,flags]); seen.add(name)

rebuilt=rebuild(stable_blob, stable_fb, ordered)
OUT_PCK.write_bytes(rebuilt)

idx=ROOT/"index.html"
html=idx.read_text()
html=re.sub(r'const AFB_TEST_RELEASE = "[^"]+";', f'const AFB_TEST_RELEASE = "{RELEASE_ID}";', html, count=1)
html=re.sub(r'"fileSizes":\{[^}]*\}', f'"fileSizes":{{"{OUT_PCK.name}":{len(rebuilt)},"index.wasm":37902138}}', html, count=1)
html=re.sub(r'"mainPack":"[^"]+"', f'"mainPack":"{OUT_PCK.name}"', html, count=1)
idx.write_text(html)

vf=ROOT/"version.json"
meta=json.loads(vf.read_text())
meta["release_id"]=RELEASE_ID
meta["game_build"]="0.7.9-beta.19"
meta["channel"]="main-based-cloud-test"
meta["base_runtime"]="afewbuds-beta:index-accountsync10.pck"
meta["updater"]="network-only-no-service-worker"
vf.write_text(json.dumps(meta,indent=2)+"\n")

(ROOT/"BUILD_VERSION.txt").write_text(
    "AFewBuds Cloud Test\n"
    "Game build: 0.7.9-beta.19\n"
    "Cloud test: .13\n"
    "Base runtime: FFDevelopment/afewbuds-beta index-accountsync10.pck\n"
    "Overlay: portraits, inventory, genetics/seeds, clickable approaches, grow-tent plant interaction\n"
)

print("BASE", STABLE_PCK)
print("OUTPUT", OUT_PCK, len(rebuilt))
print("APPROVED ADDED FILES", len(approved_added))
for name in sorted(approved_added):
    print("+", name)
print("MAIN STARTUP/SAVE/RESUME/LIFECYCLE restored from working main")
print("Personal Inventory deferred until after main _ready completes")
print("PROJECT.GODOT copied byte-for-byte from working main")
