from pathlib import Path
import struct, hashlib, re, json

PCK = Path("index-cloudtest10.pck")
HTML = Path("index.html")
VERSION = Path("version.json")
BUILD = Path("BUILD_VERSION.txt")
RELEASE = "0.7.9-beta.19-cloudtest.41"
PACK_URL = "index-cloudtest10.pck?build=41"

def align(n, a=32):
    return (n + a - 1) // a * a

def parse(path):
    blob = path.read_bytes()
    if blob[:4] != b"GDPC":
        raise SystemExit("not a Godot PCK")
    file_base = struct.unpack_from("<Q", blob, 24)[0]
    dir_offset = struct.unpack_from("<Q", blob, 32)[0]
    count = struct.unpack_from("<I", blob, dir_offset)[0]
    pos = dir_offset + 4
    entries = []
    for _ in range(count):
        plen = struct.unpack_from("<I", blob, pos)[0]; pos += 4
        name = blob[pos:pos+plen].rstrip(b"\0").decode("utf-8"); pos += plen
        off = struct.unpack_from("<Q", blob, pos)[0]; pos += 8
        size = struct.unpack_from("<Q", blob, pos)[0]; pos += 8
        md5 = blob[pos:pos+16]; pos += 16
        flags = struct.unpack_from("<I", blob, pos)[0]; pos += 4
        data = blob[file_base+off:file_base+off+size]
        if hashlib.md5(data).digest() != md5:
            raise SystemExit("md5 mismatch " + name)
        entries.append([name, data, flags])
    return blob, file_base, entries

def rebuild(blob, file_base, entries):
    out = bytearray(blob[:file_base])
    cur = 0
    directory = []
    for name, data, flags in entries:
        at = align(cur)
        out.extend(b"\0" * (at - cur))
        off = at
        out.extend(data)
        cur = off + len(data)
        directory.append((name, off, len(data), hashlib.md5(data).digest(), flags))
    dir_offset = align(len(out))
    out.extend(b"\0" * (dir_offset - len(out)))
    struct.pack_into("<Q", out, 32, dir_offset)
    out.extend(struct.pack("<I", len(directory)))
    for name, off, size, md5, flags in directory:
        raw = name.encode("utf-8")
        plen = (len(raw) + 3) // 4 * 4
        out.extend(struct.pack("<I", plen))
        out.extend(raw)
        out.extend(b"\0" * (plen - len(raw)))
        out.extend(struct.pack("<Q", off))
        out.extend(struct.pack("<Q", size))
        out.extend(md5)
        out.extend(struct.pack("<I", flags))
    return bytes(out)

TOUCH_SCROLL = r'''extends ScrollContainer

# AFewBuds mobile phone gesture controller.
# A stationary touch is always a tap. Scrolling only begins after real movement.

const TAP_SLOP: float = 12.0

var finger: int = -1
var _start_pos: Vector2 = Vector2.ZERO
var _last_pos: Vector2 = Vector2.ZERO
var _dragging: bool = false

func is_gesture_busy() -> bool:
    return finger >= 0 or finger == -2

func cancel_touch() -> void:
    finger = -1
    _start_pos = Vector2.ZERO
    _last_pos = Vector2.ZERO
    _dragging = false

func _begin_pointer(pointer: int, pos: Vector2) -> bool:
    if finger != -1:
        return false
    finger = pointer
    _start_pos = pos
    _last_pos = pos
    _dragging = false
    return false

func _drag_pointer(pointer: int, pos: Vector2, relative: Vector2) -> bool:
    if pointer != finger:
        return false
    if not _dragging and _start_pos.distance_to(pos) >= maxf(TAP_SLOP, float(scroll_deadzone)):
        _dragging = true
    _last_pos = pos
    if not _dragging:
        return false
    scroll_vertical -= int(round(relative.y))
    return true

func _end_pointer(pointer: int) -> bool:
    if pointer != finger:
        return false
    var consumed := _dragging
    cancel_touch()
    return consumed

func handle_pointer(event: InputEvent) -> bool:
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed:
            return _begin_pointer(touch.index, touch.position)
        return _end_pointer(touch.index)

    if event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        return _drag_pointer(drag.index, drag.position, drag.relative)

    # Web builds can emit emulated mouse events for touch. Keep taps pass-through
    # and only consume once the pointer actually becomes a drag.
    if event is InputEventMouseButton:
        var button := event as InputEventMouseButton
        if event.device != -1 or button.button_index != MOUSE_BUTTON_LEFT:
            return false
        if button.pressed:
            if finger != -1:
                return false
            finger = -2
            _start_pos = button.position
            _last_pos = button.position
            _dragging = false
            return false
        if finger == -2:
            var consumed := _dragging
            cancel_touch()
            return consumed
        return false

    if event is InputEventMouseMotion:
        var motion := event as InputEventMouseMotion
        if event.device != -1 or finger != -2:
            return false
        if not _dragging and _start_pos.distance_to(motion.position) >= maxf(TAP_SLOP, float(scroll_deadzone)):
            _dragging = true
        _last_pos = motion.position
        if not _dragging:
            return false
        scroll_vertical -= int(round(motion.relative.y))
        return true

    return false
'''

blob, file_base, entries = parse(PCK)
found = False
for row in entries:
    if row[0] == "scripts/touch_scroll.gd":
        found = True
        old = row[1].decode("utf-8", "replace")
        if "func handle_pointer" not in old or "func cancel_touch" not in old:
            raise SystemExit("unexpected touch_scroll.gd API")
        row[1] = TOUCH_SCROLL.encode("utf-8")
        break
if not found:
    raise SystemExit("scripts/touch_scroll.gd missing")

packed = rebuild(blob, file_base, entries)
PCK.write_bytes(packed)

html = HTML.read_text()
html = re.sub(r'const AFB_TEST_RELEASE = "[^"]+";', f'const AFB_TEST_RELEASE = "{RELEASE}";', html, count=1)
html = re.sub(r'"fileSizes":\{[^}]*\}', f'"fileSizes":{{"{PACK_URL}":{len(packed)},"index.wasm":37902138}}', html, count=1)
html = re.sub(r'"mainPack":"[^"]+"', f'"mainPack":"{PACK_URL}"', html, count=1)
HTML.write_text(html)

meta = json.loads(VERSION.read_text())
meta["release_id"] = RELEASE
meta["mobile_phone_taps"] = "stationary touch opens immediately; scroll starts only after 12px movement"
meta["mobile_phone_scroll"] = "tap-vs-swipe uses movement threshold, not hold duration"
VERSION.write_text(json.dumps(meta, indent=2) + "\n")

build_text = BUILD.read_text() if BUILD.exists() else ""
build_text = re.sub(r"Web release: .*", f"Web release: {RELEASE}", build_text)
if "Web release:" not in build_text:
    build_text += f"\nWeb release: {RELEASE}\n"
BUILD.write_text(build_text)

# Verification: ensure the new controller is in the rebuilt pack.
_, _, verify_entries = parse(PCK)
verified = False
for name, data, _ in verify_entries:
    if name == "scripts/touch_scroll.gd":
        text = data.decode("utf-8", "replace")
        required = [
            "const TAP_SLOP: float = 12.0",
            "return _begin_pointer(touch.index, touch.position)",
            "return _end_pointer(touch.index)",
            "_start_pos.distance_to(pos)",
            "scroll_vertical -= int(round(relative.y))",
        ]
        for needle in required:
            if needle not in text:
                raise SystemExit("verification failed: " + needle)
        verified = True
        break
if not verified:
    raise SystemExit("rebuilt touch controller missing")

print("Built", RELEASE)
print("Stationary phone touches now pass through as taps; only movement beyond threshold is consumed as scroll.")
print("PCK bytes", len(packed))
