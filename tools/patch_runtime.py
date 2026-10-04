from pathlib import Path
import struct, hashlib, re, json

P = Path("index-accountsync11.pck")
blob = bytearray(P.read_bytes())
if blob[:4] != b"GDPC":
    raise SystemExit("not pck")

fb = struct.unpack_from("<Q", blob, 24)[0]
do = struct.unpack_from("<Q", blob, 32)[0]
count = struct.unpack_from("<I", blob, do)[0]
pos = do + 4
entries = []

for _ in range(count):
    plen = struct.unpack_from("<I", blob, pos)[0]
    pos += 4
    raw = bytes(blob[pos:pos+plen])
    pos += plen
    name = raw.rstrip(b"\0").decode()
    off = struct.unpack_from("<Q", blob, pos)[0]
    pos += 8
    size = struct.unpack_from("<Q", blob, pos)[0]
    pos += 8
    md5pos = pos
    pos += 16
    pos += 4
    entries.append((name, off, size, md5pos))

main_entry = next(x for x in entries if x[0] == "scripts/main.gd")
project_entry = next(x for x in entries if x[0] == "project.godot")

# Update project metadata so the running build identifies itself correctly.
pname, poff, psize, pmd5pos = project_entry
pstart = fb + poff
ptext = bytes(blob[pstart:pstart+psize]).decode("utf-8").rstrip(" \n\0")
ptext = ptext.replace("AFewBuds Beta v0.7.7.1-beta.1", "AFewBuds Cloud Test v0.7.9-beta.19")
ptext = ptext.replace("0.7.7.1-beta.1", "0.7.9-beta.19")
pdata = ptext.encode()
if len(pdata) > psize:
    raise SystemExit("project.godot metadata grew beyond slot")
ppadded = pdata + b"\n" + b" " * (psize - len(pdata) - 1)
blob[pstart:pstart+psize] = ppadded
blob[pmd5pos:pmd5pos+16] = hashlib.md5(ppadded).digest()

name, off, size, md5pos = main_entry
start = fb + off
text = bytes(blob[start:start+size]).decode("utf-8").rstrip(" \n\0")

# Resume by room only, never by close-up/station view.
pat = r'func _restore_runtime_state\(\) -> void:\n.*?(?=\nfunc )'
m = re.search(pat, text, re.S)
if not m:
    raise SystemExit("restore function missing")
block = m.group(0)

variants = [
'''\tcurrent_room = str(restored_runtime.get("current_room", "main"))
\troom_ring = grow_room_ring if current_room == "grow" else main_room_ring
\tvar saved_view: String = _safe_resume_view(str(restored_runtime.get("current_view", "main_grow_door")), current_room)
\tif views.has(saved_view):
\t\t_go_to_view(saved_view, false)
\telse:
\t\tcurrent_room = "main"
\t\troom_ring = main_room_ring
\t\t_go_to_view("main_grow_door", false)
''',
'''\tcurrent_room = str(restored_runtime.get("current_room", "main"))
\troom_ring = grow_room_ring if current_room == "grow" else main_room_ring
\tvar saved_view: String = str(restored_runtime.get("current_view", "main_grow_door"))
\tif views.has(saved_view):
\t\t_go_to_view(saved_view, false)
'''
]
new_view = '''\tcurrent_room = "grow" if str(restored_runtime.get("current_room", "main")) == "grow" else "main"
\troom_ring = grow_room_ring if current_room == "grow" else main_room_ring
\t_go_to_view("grow_room_tent" if current_room == "grow" else "main_grow_door", false)
\troom_target_yaw = 0.0
\troom_target_pitch = 0.0
\tcamera.rotation = Vector3.ZERO
'''
for old in variants:
    if old in block:
        block = block.replace(old, new_view, 1)
        break
else:
    raise SystemExit("restore view block missing")

text = text[:m.start()] + block + text[m.end():]

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

# Main-script-owned BAG button so it cannot depend on helper initialization.
if 'var backpack_quick_button: Button' not in text:
    text = text.replace(
        'var back_button: Button\n',
        'var back_button: Button\nvar backpack_quick_button: Button\n',
        1
    )

build_marker = '''\tforward_button = Button.new()
\tforward_button.visible = false
\thud.add_child(forward_button)
'''
bag_build = '''\tforward_button = Button.new()
\tforward_button.visible = false
\thud.add_child(forward_button)

\tvar cloud_test_marker: Label = Label.new()
\tcloud_test_marker.text = "CLOUD TEST .3"
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
\tbackpack_quick_button.add_theme_stylebox_override("normal", _style_box(Color("183221"), Color("83c978"), 18, 3))
\tbackpack_quick_button.add_theme_stylebox_override("hover", _style_box(Color("24472f"), Color("a0e292"), 18, 3))
\tbackpack_quick_button.pressed.connect(_open_backpack_direct)
\thud.add_child(backpack_quick_button)
\thud.move_child(backpack_quick_button, hud.get_child_count() - 1)
'''
if build_marker not in text:
    raise SystemExit("HUD marker missing")
text = text.replace(build_marker, bag_build, 1)

if 'func _open_backpack_direct() -> void:' not in text:
    marker = 'func _build_phone_panel() -> void:\n'
    if marker not in text:
        raise SystemExit("phone marker missing")
    funcs = '''func _open_backpack_direct() -> void:
\tif personal_inventory != null and personal_inventory.has_method("toggle_backpack"):
\t\tpersonal_inventory.call("toggle_backpack")
\t\treturn
\tstatus_label.text = "Backpack inventory is unavailable."

'''
    text = text.replace(marker, funcs + marker, 1)

# Make BAG survive every world-control visibility refresh.
vis_pat = r'func _set_world_controls_visible\(visible: bool\) -> void:\n.*?(?=\nfunc )'
vm = re.search(vis_pat, text, re.S)
if vm:
    vblock = vm.group(0)
    if 'backpack_quick_button.visible = true' not in vblock:
        vblock += '\tif backpack_quick_button != null:\n\t\tbackpack_quick_button.visible = true\n'
        text = text[:vm.start()] + vblock + text[vm.end():]

data = text.encode()
if len(data) > size:
    lines = [ln for ln in text.splitlines(True) if not ln.lstrip().startswith("#")]
    text = re.sub(r'\n{3,}', '\n\n', ''.join(lines))
    data = text.encode()
if len(data) > size:
    raise SystemExit(f"patched main too large {len(data)} > {size}")

padded = data + b"\n" + b" " * (size - len(data) - 1)
blob[start:start+size] = padded
blob[md5pos:md5pos+16] = hashlib.md5(padded).digest()
P.write_bytes(blob)

v = Path("version.json")
meta = json.loads(v.read_text())
meta["release_id"] = "0.7.9-beta.19-cloudtest.3"
v.write_text(json.dumps(meta, indent=2) + "\n")

idx = Path("index.html")
s = idx.read_text()
s = s.replace("0.7.9-beta.19-cloudtest.1", "0.7.9-beta.19-cloudtest.3").replace("0.7.9-beta.19-cloudtest.2", "0.7.9-beta.19-cloudtest.3")
idx.write_text(s)

print("patched main bytes", len(data), "slot", size)
print("room-only resume", '"grow_room_tent" if current_room == "grow" else "main_grow_door"' in text)
print("direct BAG button", 'backpack_quick_button.text = "BAG"' in text)
