from pathlib import Path
import struct, hashlib, re, json

src = Path("index-cloudtest19.pck")
outp = Path("index-cloudtest20.pck")
blob = src.read_bytes()

file_base = struct.unpack_from("<Q", blob, 24)[0]
dir_offset = struct.unpack_from("<Q", blob, 32)[0]
count = struct.unpack_from("<I", blob, dir_offset)[0]
pos = dir_offset + 4
entries = []

for _ in range(count):
    plen = struct.unpack_from("<I", blob, pos)[0]
    pos += 4
    name = blob[pos:pos+plen].rstrip(b"\0").decode()
    pos += plen
    off = struct.unpack_from("<Q", blob, pos)[0]
    pos += 8
    size = struct.unpack_from("<Q", blob, pos)[0]
    pos += 8
    md5 = blob[pos:pos+16]
    pos += 16
    flags = struct.unpack_from("<I", blob, pos)[0]
    pos += 4
    data = blob[file_base+off:file_base+off+size]
    if hashlib.md5(data).digest() != md5:
        raise SystemExit("MD5 mismatch: " + name)
    entries.append([name, data, flags])

for entry in entries:
    if entry[0] != "scripts/main.gd":
        continue
    text = entry[1].decode("utf-8", "replace").rstrip(" \n\0")
    text = text.replace("CLOUD TEST .19", "CLOUD TEST .20")
    old = "\thud = Control.new()\n\thud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)\n\tadd_child(hud)\n"
    new = "\thud = Control.new()\n\thud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)\n\thud.position = Vector2(0, -12)\n\tadd_child(hud)\n"
    if old not in text:
        raise SystemExit("HUD creation block missing")
    text = text.replace(old, new, 1)
    if "hud.position = Vector2(0, -12)" not in text:
        raise SystemExit("HUD lift missing")
    entry[1] = text.encode()

out = bytearray(blob[:file_base])
cursor = 0
directory = []
for name, data, flags in entries:
    aligned = (cursor + 31) // 32 * 32
    out.extend(b"\0" * (aligned - cursor))
    off = aligned
    out.extend(data)
    cursor = off + len(data)
    directory.append((name, off, len(data), hashlib.md5(data).digest(), flags))

new_dir_offset = (len(out) + 31) // 32 * 32
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

outp.write_bytes(out)

html_path = Path("index.html")
html = html_path.read_text()
html = re.sub(r'const AFB_TEST_RELEASE = "[^"]+";', 'const AFB_TEST_RELEASE = "0.7.9-beta.19-cloudtest.20";', html, count=1)
html = re.sub(r'"fileSizes":\{[^}]*\}', f'"fileSizes":{{"{outp.name}":{len(out)},"index.wasm":37902138}}', html, count=1)
html = re.sub(r'"mainPack":"[^"]+"', f'"mainPack":"{outp.name}"', html, count=1)
html_path.write_text(html)

version_path = Path("version.json")
meta = json.loads(version_path.read_text())
meta["release_id"] = "0.7.9-beta.19-cloudtest.20"
meta["hud_adjustment"] = "up-12px-from-cloudtest19"
version_path.write_text(json.dumps(meta, indent=2) + "\n")

print("Built cloudtest20 from cloudtest19 with HUD offset y=-12px")
