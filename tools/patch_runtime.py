from pathlib import Path
import struct, hashlib, re, json

SOURCE_PCK = Path("index-accountsync11.pck")
VERSIONED_PCK = Path("index-cloudtest7.pck")
RELEASE_ID = "0.7.9-beta.19-cloudtest.7"
HUD_MARKER = "CLOUD TEST .7"

def align(n, a=32):
    return (n + a - 1) // a * a

def parse_pck(path):
    blob = path.read_bytes()
    if blob[:4] != b"GDPC":
        raise SystemExit("not pck")
    file_base = struct.unpack_from("<Q", blob, 24)[0]
    dir_offset = struct.unpack_from("<Q", blob, 32)[0]
    count = struct.unpack_from("<I", blob, dir_offset)[0]
    pos = dir_offset + 4
    entries = []
    for _ in range(count):
        plen = struct.unpack_from("<I", blob, pos)[0]; pos += 4
        raw = blob[pos:pos+plen]; pos += plen
        name = raw.rstrip(b"\0").decode()
        off = struct.unpack_from("<Q", blob, pos)[0]; pos += 8
        size = struct.unpack_from("<Q", blob, pos)[0]; pos += 8
        md5 = blob[pos:pos+16]; pos += 16
        flags = struct.unpack_from("<I", blob, pos)[0]; pos += 4
        content = blob[file_base+off:file_base+off+size]
        if hashlib.md5(content).digest() != md5:
            raise SystemExit("MD5 mismatch: " + name)
        entries.append([name, content, flags])
    return blob, file_base, entries

def patch_main(text):
    existing_room_restore = '''\tcurrent_room = "grow" if str(restored_runtime.get("current_room", "main")) == "grow" else "main"
\troom_ring = grow_room_ring if current_room == "grow" else main_room_ring
\t_go_to_view("grow_room_tent" if current_room == "grow" else "main_grow_door", false)
\troom_target_yaw = 0.0
\troom_target_pitch = 0.0
\tcamera.rotation = Vector3.ZERO
'''
    compact_room_restore = '''\tcurrent_room = "grow" if str(restored_runtime.get("current_room", "main")) == "grow" else "main"
\troom_ring = grow_room_ring if current_room == "grow" else main_room_ring
\tif current_room == "grow":
\t\t_go_to_view("grow_room_tent", false)
\telse:
\t\tcamera.position = Vector3(0, 1.64, 1.20)
\t\t_finish_leave_grow_room()
'''
    if existing_room_restore in text:
        text = text.replace(existing_room_restore, compact_room_restore, 1)
    else:
        previous_compact = '''\tcurrent_room = "grow" if str(restored_runtime.get("current_room", "main")) == "grow" else "main"
\troom_ring = grow_room_ring if current_room == "grow" else main_room_ring
\tif current_room == "grow":
\t\t_go_to_view("grow_room_tent", false)
\telse:
\t\t_finish_leave_grow_room()
'''
        if previous_compact in text:
            text = text.replace(previous_compact, compact_room_restore, 1)
        elif compact_room_restore not in text:
            raise SystemExit("expected .6 resume block not found")

    for old in [
        '''\t\t"current_view": _safe_resume_view(current_view, current_room),
\t\t"current_room": current_room,
''',
        '''\t\t"current_view": current_view,
\t\t"current_room": current_room,
'''
    ]:
        if old in text:
            text = text.replace(old, '''\t\t"current_view": "grow_room_tent" if current_room == "grow" else "main_grow_door",
\t\t"current_room": current_room,
''', 1)
            break

    text = re.sub(
        r'func _safe_resume_view\(view_name: String, room_name: String\) -> String:\n.*?(?=\nfunc )',
        '',
        text,
        count=1,
        flags=re.S
    )

    for old_marker in ["CLOUD TEST .3", "CLOUD TEST .4", "CLOUD TEST .5", "CLOUD TEST .6"]:
        text = text.replace(old_marker, HUD_MARKER)

    if 'var backpack_quick_button: Button' not in text:
        text = text.replace('var back_button: Button\n', 'var back_button: Button\nvar backpack_quick_button: Button\n', 1)

    if 'backpack_quick_button.text = "BAG"' not in text:
        marker = '''\tforward_button = Button.new()
\tforward_button.visible = false
\thud.add_child(forward_button)
'''
        addition = marker + '''
\tvar cloud_test_marker: Label = Label.new()
\tcloud_test_marker.text = "CLOUD TEST .7"
\tcloud_test_marker.set_anchors_preset(Control.PRESET_TOP_RIGHT)
\tcloud_test_marker.offset_left = -210
\tcloud_test_marker.offset_top = 18
\tcloud_test_marker.offset_right = -18
\tcloud_test_marker.offset_bottom = 58
\tcloud_test_marker.z_index = 300
\tcloud_test_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
\tcloud_test_marker.add_theme_font_size_override("font_size", 20)
\tcloud_test_marker.modulate = Color("9fe892")
\thud.add_child(cloud_test_marker)

\tbackpack_quick_button = Button.new()
\tbackpack_quick_button.text = "BAG"
\tbackpack_quick_button.tooltip_text = "Open backpack"
\tbackpack_quick_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
\tbackpack_quick_button.offset_left = -118
\tbackpack_quick_button.offset_top = -118
\tbackpack_quick_button.offset_right = -18
\tbackpack_quick_button.offset_bottom = -18
\tbackpack_quick_button.custom_minimum_size = Vector2(100, 100)
\tbackpack_quick_button.z_index = 250
\tbackpack_quick_button.add_theme_font_size_override("font_size", 18)
\tbackpack_quick_button.pressed.connect(_open_backpack_direct)
\thud.add_child(backpack_quick_button)
'''
        if marker not in text:
            raise SystemExit("HUD insertion marker missing")
        text = text.replace(marker, addition, 1)

    if 'func _open_backpack_direct() -> void:' not in text:
        marker = 'func _build_phone_panel() -> void:\n'
        funcs = '''func _open_backpack_direct() -> void:
\tif personal_inventory != null and personal_inventory.has_method("toggle_backpack"):
\t\tpersonal_inventory.call("toggle_backpack")
\t\treturn
\tstatus_label.text = "Backpack inventory is unavailable."

'''
        if marker not in text:
            raise SystemExit("phone marker missing")
        text = text.replace(marker, funcs + marker, 1)

    vis_pat = r'func _set_world_controls_visible\(visible: bool\) -> void:\n.*?(?=\nfunc )'
    vm = re.search(vis_pat, text, re.S)
    if vm:
        block = vm.group(0)
        if 'backpack_quick_button.visible = true' not in block:
            block += '\tif backpack_quick_button != null:\n\t\tbackpack_quick_button.visible = true\n'
            text = text[:vm.start()] + block + text[vm.end():]

    return text

def rebuild_pck(original_blob, file_base, entries):
    out = bytearray(original_blob[:file_base])
    cursor = 0
    directory = []

    for name, content, flags in entries:
        target = align(cursor, 32)
        if target > cursor:
            out.extend(b"\0" * (target - cursor))
        off = target
        out.extend(content)
        cursor = off + len(content)
        directory.append((name, off, len(content), hashlib.md5(content).digest(), flags))

    new_dir_offset = align(len(out), 32)
    if new_dir_offset > len(out):
        out.extend(b"\0" * (new_dir_offset - len(out)))

    struct.pack_into("<Q", out, 32, new_dir_offset)
    out.extend(struct.pack("<I", len(directory)))

    for name, off, size, md5, flags in directory:
        raw = name.encode()
        plen = (len(raw) + 3) // 4 * 4
        out.extend(struct.pack("<I", plen))
        out.extend(raw)
        out.extend(b"\0" * (plen - len(raw)))
        out.extend(struct.pack("<Q", off))
        out.extend(struct.pack("<Q", size))
        out.extend(md5)
        out.extend(struct.pack("<I", flags))

    return bytes(out)

original_blob, file_base, entries = parse_pck(SOURCE_PCK)
found_main = False

for entry in entries:
    name, content, flags = entry
    if name == "scripts/main.gd":
        text = content.decode("utf-8").rstrip(" \n\0")
        patched = patch_main(text).encode()
        entry[1] = patched
        found_main = True
    elif name == "project.godot":
        text = content.decode("utf-8").rstrip(" \n\0")
        text = text.replace("AFewBuds Beta v0.7.7.1-beta.1", "AFB Test v0.7.9-b19")
        text = text.replace("0.7.7.1-beta.1", "0.7.9-beta.19")
        entry[1] = text.encode()

if not found_main:
    raise SystemExit("scripts/main.gd missing")

rebuilt = rebuild_pck(original_blob, file_base, entries)
SOURCE_PCK.write_bytes(rebuilt)
VERSIONED_PCK.write_bytes(rebuilt)

idx = Path("index.html")
html = idx.read_text()
html = re.sub(r'const AFB_TEST_RELEASE = "[^"]+";', f'const AFB_TEST_RELEASE = "{RELEASE_ID}";', html, count=1)
html = re.sub(r'"fileSizes":\{[^}]*\}', f'"fileSizes":{{"{VERSIONED_PCK.name}":{len(rebuilt)},"index.wasm":37902138}}', html, count=1)
html = re.sub(r'"mainPack":"[^"]+"', f'"mainPack":"{VERSIONED_PCK.name}"', html, count=1)
idx.write_text(html)

v = Path("version.json")
meta = json.loads(v.read_text())
meta["release_id"] = RELEASE_ID
meta["game_build"] = "0.7.9-beta.19"
meta["channel"] = "standalone-cloud-test"
meta["updater"] = "network-only-no-service-worker"
v.write_text(json.dumps(meta, indent=2) + "\n")

print("rebuilt PCK bytes", len(rebuilt))
print("mainPack", VERSIONED_PCK.name)
print("release", RELEASE_ID)
print("known-good main resume", "_finish_leave_grow_room()" in patch_main(next(e[1].decode("utf-8") for e in entries if e[0] == "scripts/main.gd")))
