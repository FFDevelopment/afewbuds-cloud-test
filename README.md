# Inventory test build

This branch is an isolated inventory experiment. See [preview instructions and save behavior](INVENTORY_PREVIEW.md).

# AFewBuds Cloud Test — mobile 3D baseline

`main` is the canonical mobile/web game. Baseline: **mobile 3D v12** (`0.7.9-beta.19-cloudtest.99-mobile3d.12`), paired with [desktop 0.13.2](https://github.com/FFDevelopment/afewbuds-3d-prototype).

[Play AFewBuds](https://ffdevelopment.github.io/afewbuds-cloud-test/). The former `/mobile-3d-movement/` URL serves the same build for existing links and bookmarks.

## Included

- Physics movement, working doors/stairs, sprint stamina and touch controls.
- Bongchester districts: Roachwood, Half Baked Heights and Paranoia Point.
- Chapter 4 property finale, house purchase/rent/lease-to-own, relocation and Chapter 5 opening.
- Real Estate, retained apartment leases, release safeguards and per-property billing.
- Newest-first messages and shared account careers.

Chapter 5 does not yet have a full mission chain or finale. Interactive furniture placement and further phone reorganization remain pending.

## Build and release

Every push to `main` runs **Build mobile baseline**. It reconstructs the runtime, verifies the pack hash, imports it with Godot 4.7.2, and runs movement/stamina/district plus progression/property/message checks before committing generated files. **Deploy cloud-test baseline** publishes only after that build succeeds.

Local reconstruction: `python tools/mobile_3d_movement/build.py --output-dir <directory outside this checkout>`. Test scripts are `tools/mobile_3d_movement/check.gd` and `tools/progression_v1/check.gd`. Pages staging uses `tools/stage_pages.py`; it excludes historical packs, inactive recipes, tools, archived workflows and database files.

`archive/workflows/` preserves retired one-off Actions jobs. Pinned packs, recipes, assets and build helpers remain in Git because reconstruction depends on them. See `AGENTS.md` for paired-release rules and `tools/mobile_3d_movement/DISTRICTS.md` for district boundaries.
