# Character and furniture scale pass

Candidate `0.7.9-beta.19-cloudtest.96-fit.1`, based on main commit
`ec2779191170e26e737aee4bc6c867f936a1fa2e` (the .96 walking-eye-height update).

The existing Malik and Rod models define the scale: approximately 2.35 world
units tall, with a 2.42-unit maximum player-kit preset. Their GLBs, textures,
animations and root scales are unchanged. The .96 walking eye height stays 2.16.

The pass adapts the approved `AFB_FurnitureFit_v1` dimensions to the actual
cloud-test builders. It keeps their named nodes, upgrade hooks, materials and
interactions. The supplied fitted couch is also used in the house living room.

| Element | Candidate dimensions / behavior |
| --- | --- |
| Fitted couch and dining seats | Seat top 0.46821849; existing sit clips reach the floor |
| Coffee tables | Top 0.44; apartment table moved forward for shoe clearance; four supports |
| Kitchen, packing and checkout counters | Worktop 1.16; cabinets and objects meet their supports |
| Storage shelves | Shelf tops 0.3825, 0.94, 1.50, 2.05; supported contents and upgrade bins |
| Functional map doors | Leaves 2.85; wall openings 2.90; header underside 2.83 |
| Walking collision checks | Radius 0.26; obstacles checked up to 2.43 above the floor |
| Cars | 1.25 scale; corrected wheel orientation and floor contact; enlarged collision bounds |
| Trees | 1.20 scale; two tree beds moved to clear crosswalk approaches |
| Background buildings | Vertical scale 1.20, including story spacing and decorative entries |
| House fixtures | Fitted chairs, toilet, vanity, bed, fridge and cabinets |

Street coordinates, room footprints and usable house/shop ceilings are retained.
The apartment's lower building volume stays aligned with the playable apartment.
This is a scale pass using the existing prototype art, not a replacement car,
tree or building asset set. The house couch is placed furniture; this change
does not add a new house seating interaction or new character-customization UI.

## Review

Open [review.html](review.html) for five baseline/candidate render comparisons.
Review characters are staged solely by `capture.gd`; they are not extra NPCs
added to the shipped game. Both renders use the same model scales and poses.

## Rebuild and validation

From the repository root:

```text
python -B tools/character_fit_v1/build.py --output-dir <scratch-directory>
node tools/character_fit_v1/verify_loader.mjs
```

The builder reconstructs the SHA-256-verified .96 baseline, patches three
existing script entries and adds two scripts. It asserts that all other 206
entries, including production project settings and character assets, are
unchanged. The browser recipe is independently reconstructed and hash-checked.
No full replacement PCK is committed.

Run Godot 4.7.2 with `--headless --path <scratch-directory>/candidate --script`
followed by the absolute path to each check:

- `tools/character_fit_v1/check_fit.gd`: 95 checks, zero failures. Actual mesh
  support heights, upgrades, idempotence, head clearance, five doors, car and
  tree grounding, parking bounds, crosswalks and player sit/stand.
- `tools/neighborhood95/check_assets.gd`: zero failures. Both 56-bone rigs,
  textures, unchanged scale, CPU-skinned seated foot/pelvis contact, standing
  reset, worker/visitor appearance and apartment header material.
- `tools/neighborhood92/check_doors.gd`: zero failures. Both approach sides,
  nonblocking door closing, collision timing, apartment door and worker gait.
- `tools/character_fit_v1/check_routes.gd`: zero failures. Grid paths into six
  house destinations and five market destinations, glass collision, property
  progression and inspection/tour behavior, at the current eye height.

Native validation projects use separate application names and save directories;
their configuration is never included in the shipped runtime. The standalone
loader check exercises the actual JavaScript loader and verifies the final PCK
hash, all seven fetches and unchanged WASM pass-through. Chrome guest startup
was checked on a fresh localhost origin without signing into a cloud account.
The existing pause overlay appeared during background browser automation;
interactive route and door coverage comes from the native checks above.

For native images, run `capture.gd` against the extracted baseline or candidate
without `--headless`, passing `-- <output-image-directory>` after Godot's options.
Only that validation script hides the UI and stages review NPCs.

## Provenance and release

`approved_manifest.json` and `approved_SIZE_AUDIT.json` record the approved
source package and dimensions;
the manifest describes that source package, not this repository's file roster.
All 90 source-file hashes were checked before integration. These are existing
user-authored AFewBuds assets. The optional canonical asset CLI was unavailable,
so validation uses direct hash checks and the engine rather than a CLI receipt.

`build_receipt.json` identifies the exact candidate pack. `validation/` contains
the check results and logs. GitHub Pages deploys main, so a feature branch does
not change the live cloud-test site. Check main again before merging if newer
work has landed; the builder intentionally targets .96 and must be adapted to
any later runtime rather than overwriting its changes.
