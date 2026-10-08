#!/usr/bin/env python3
"""Stage the *public beta* web shell with a tested AFewBuds recovery game pack.

The public release remains untouched. Its immutable manifest is the copy source,
and every unchanged game/web asset is copied byte-for-byte. This intentionally
does NOT use the older cloud-test HTML, JS loader or incremental patch recipe.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shutil

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
PUBLIC_RELEASE = "0.16.0-mobile-beta.4"
PUBLIC_PACK_SHA256 = "494f9f05e81eb2fa1353f92fd4b2f959c4acd31609513bdf0f1ddf4bcf63095f"
TEST_RELEASE_PREFIX = "0.16.0-beta4-cloudtest-recovery"
REQUIRED_UI = (
    "func start_layout(", "func refresh_layout(", "func build_preview(",
    "func begin(", "Walk-around edit mode", "func snap_stash_to_wall(",
)
ALLOWED_SCRIPT_CHANGES = {
    "scripts/main.gd", "scripts/crew_phone.gd",
    "scripts/equipment_world.gd", "scripts/container_inventory.gd",
    "scripts/property_furniture.gd",
}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def game_contents(data):
    spec = importlib.util.spec_from_file_location(
        "afb_pack", ROOT / "tools/build_neighborhood96.py"
    )
    assert spec is not None and spec.loader is not None
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    _, entries = mod.parse(data)
    return {name: content for name, content, _flags in entries}


def verify_game(public_bytes, candidate_bytes):
    assert digest(public_bytes) == PUBLIC_PACK_SHA256, "The public beta package changed"
    old = game_contents(public_bytes)
    new = game_contents(candidate_bytes)
    assert old.keys() <= new.keys(), "Public game resources were removed"
    for name in ["scripts/furniture_editor.gd", "scripts/crew_phone.gd",
                 "scripts/container_inventory.gd", "scripts/main.gd",
                 "scripts/property_furniture.gd", "scripts/equipment_world.gd"]:
        assert name in old and name in new, f"Required public gameplay file missing: {name}"
    assert new["scripts/furniture_editor.gd"] == old["scripts/furniture_editor.gd"], (
        "The FREE-MOVEMENT furniture editor differs from the actual public game"
    )
    editor = new["scripts/furniture_editor.gd"].decode("utf-8")
    for marker in REQUIRED_UI:
        assert marker in editor, f"Missing public furniture control: {marker}"
    assert "func process_selected()" in new["scripts/container_inventory.gd"].decode(), "Inventory not present"
    assert "func idle_couch()" in new["scripts/crew_phone.gd"].decode(), "Relocated couch handling missing"
    assert "func sync_packing_displays()" in new["scripts/equipment_world.gd"].decode(), "3D scale stock missing"
    prop = new["scripts/property_furniture.gd"].decode()
    assert 'bounds(id,point,yaw).grow(.015)' in prop, "Wall placement tolerance missing"
    main = new["scripts/main.gd"].decode()
    assert "func _current_packing_bench_tier()" in main, "Upgraded packing tiers missing"
    changed = sorted(k for k in old if old[k] != new[k])
    unexpected = sorted(set(changed) - ALLOWED_SCRIPT_CHANGES)
    print("PUBLIC_GAME_RESOURCE_PARITY:",len(old),"public entries;",len(new),"recovery entries")
    print("PUBLIC_GAME_CHANGED_RESOURCES:", json.dumps(changed))
    assert not unexpected, "Unexpected modifications to public game: " + repr(unexpected)
    assert len(candidate_bytes) > 48000000, "Incomplete recovery package"
    print("PUBLIC_BETA_FURNITURE_PARITY: PASS (unchanged free-movement editor)")
    print("PUBLIC_BETA_GAMEPLAY_PARITY: PASS (all other resources retained)")


def stage(public, candidate, dest):
    assert not dest.exists(), "Refusing to overwrite an existing test directory"
    manifest = json.loads((public / "version.json").read_text())
    assert manifest["release_id"] == PUBLIC_RELEASE
    main_bytes = (public / "index-mobile.pck").read_bytes()
    candidate_bytes = candidate.read_bytes()
    # Use an immutable per-build release ID so the PWA cannot reuse old animation packs.
    test_release = TEST_RELEASE_PREFIX + "." + digest(candidate_bytes)[:12]
    verify_game(main_bytes, candidate_bytes)
    dest.mkdir(parents=True)
    for asset in manifest["files"]:
        p = asset["path"]
        data = (public / p).read_bytes()
        assert len(data) == asset["size"] and digest(data) == asset["sha256"], p
        target = dest / p
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(public / p, target)
    for extra in ("index-accountsync14.js", "index-accountsync14.pck",
                  "shared/afb-cloud-accountsync14.js", "BUILD_VERSION.txt", ".nojekyll"):
        source = public / extra
        if source.exists():
            target = dest / extra
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
    (dest / "index-mobile.pck").write_bytes(candidate_bytes)
    html = (dest / "index.html").read_text()
    assert "index-mobile.pck" in html and PUBLIC_RELEASE in html
    html = html.replace(PUBLIC_RELEASE, test_release)
    html, hits = re.subn(
        r'("index-mobile\.pck"\s*:\s*)\d+',
        lambda m: m.group(1) + str(len(candidate_bytes)),
        html,
    )
    assert hits == 1, "Public launcher game package size was not replaced exactly once"
    (dest / "index.html").write_text(html)
    manifest["release_id"] = test_release
    manifest["game_build"] = test_release
    for item in manifest["files"]:
        data = (dest / item["path"]).read_bytes()
        item["size"] = len(data)
        item["sha256"] = digest(data)
    (dest / "version.json").write_text(json.dumps(manifest, indent=2) + "\n")
    (dest / "BUILD_VERSION.txt").write_text(
        "AFewBuds Cloud Test\n"
        f"Baseline: {PUBLIC_RELEASE}\nBuild: {test_release}\n"
        f"Base pack sha256: {PUBLIC_PACK_SHA256}\n"
        f"Test pack sha256: {digest(candidate_bytes)}\n"
    )
    print("PUBLIC_BETA_SHELL_PARITY: PASS (" + str(len(manifest["files"])) + " verified public files)")
    print("RECOVERY_STAGE_READY: PASS",dest)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--public", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    stage(args.public.resolve(), args.candidate.resolve(), args.output.resolve())
