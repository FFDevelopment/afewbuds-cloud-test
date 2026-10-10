#!/usr/bin/env python3
"""Verify each published Cloud Test archive has one coherent unique browser build ID."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
receipt = json.loads((ROOT / "tools/mobile_3d_movement/build_receipt.json").read_text())
manifest = json.loads((ROOT / "version.json").read_text())
html = (ROOT / "index.html").read_text()
loader = (ROOT / "shared/afb-runtime-mobile-3d-v1.js").read_text()
patch = json.loads((ROOT / "runtime/mobile-3d-v1.patch.json").read_text())

pack_sha = receipt["target_sha256"]
token = pack_sha[:12]
release = manifest["release_id"]
assert token == manifest["runtime_pack_sha256"][:12] and pack_sha == manifest["runtime_pack_sha256"]
assert release.endswith("." + token), (release, token)
assert f'const AFB_TEST_RELEASE = "{release}";' in html
for url in [
    f"shared/afb-api.js?v={token}",
    f"shared/afb-expansion-save.js?v={token}",
    f"index-accountsync10.js?v={token}",
    f"shared/afb-runtime-mobile-3d-v1.js?v={token}",
]:
    assert url in html, f"Cached JS: {url}"
assert f"patch.json?v={token}" in loader, "Cached PCK delta recipe URL"
asset_urls = [x[1] for x in patch["segments"] if x[0] == "asset"]
assert asset_urls and all(x.endswith("?v=" + token) for x in asset_urls)
assert patch["target_sha256"] == pack_sha
print("AFB_RELEASE_STAMP_RESULT: PASS", release, "asset_count=", len(asset_urls))
