# East residential expansion

Release `0.7.9-beta.19-cloudtest.96-east.3`, built over the merged furniture-fit
release at `ab71721ebd6e6ca8f97f872502dd0828266bfca9`.

The map extends east from x=73 to x=137. The main street and rear lane continue
through the old boundary into a new intersection, residential rows, five
rear-lane garages and a pocket park. The district uses the existing prototype
materials and geometry style, following the supplied reference's circulation
and residential layout rather than claiming its finished art quality.

Two decorative buildings at the old east edge are replaced/reoriented as part
of 19 residential exteriors. Their doors and garage doors are scenery for now;
there are no new enterable interiors. All three park benches support sitting,
and the seated camera now matches the shared rig's eyes. The three finished
hub buildings, their interiors, furniture and character assets remain unchanged.

## Preservation and window checks

Only `scripts/neighborhood.gd` changes in the existing runtime; the new district
is in `scripts/east_expansion.gd`, with interactions in `scripts/seating.gd`.
All other 210 pack entries are byte-identical
to the merged furniture release. The original three functional buildings are
not moved, resized, rebuilt or given new interior code.

The renderer comparison additionally hashes the 1,667 original aboveground
batched instances with centers west of x=48, covering the preserved core exterior.
Their geometry hash is identical before and after. Two decorative buildings
east of that boundary are intentionally reorganized, as authorized.

Tree trunks, soil patches and paving cutouts now share one placement list.
Two displaced hub cutouts are corrected, and the cramped expansion trees move
onto wider sidewalk planting areas. All 16 trunks are centered on their patches,
meet the soil surface, and have canopy clearance from building bounds.

All 669 generated facade windows were checked against their individual story
bands, including 372 upper-story windows. The apartment upper floors start
above its 4.4-unit ground floor; their window centers are 6.44 and 9.68. Other
residential stories use 3.24-unit spacing, with centers 2.04 above each floor.
Frames and sills remain inside the story with clearance. The prior scale pass
already corrected these positions, so this expansion preserves that alignment.

## Validation

- 818 expansion checks pass: preserved core geometry, tree planting, original five functional
  doors, open old boundary and ground seams, walking routes from the hub,
  unobstructed park path, exterior collisions, containment and window alignment.
- The character/furniture checks pass with 113 checks across the larger map.
- Existing door-swing checks and house/market route checks report zero failures.
- The actual JavaScript loader reconstructs the expected pack and verifies its
  SHA-256. Chrome guest startup is checked without a cloud-account sign-in.
- Static batched geometry grows from 2,204 to 4,723 instances and from 34 to 45
  MultiMesh batches. This is a geometry budget check, not an FPS benchmark or
  a guarantee of performance on every phone.

Screenshots and test results are in `previews/` and `validation/`.
Open [review.html](review.html) to inspect the district and upper windows.
See [seating validation](../park_seating_v1/README.md) for the added bench controls
and corrected seated views in `.96-east.3`.
Rod is staged only in review captures to show scale; no duplicate live NPC is
added. Customizable-player integration is not part of this map release.

## Reproduce

```text
python -B tools/east_expansion_v1/build.py --output-dir <scratch>
node tools/east_expansion_v1/verify_loader.mjs
```

The build verifies the merged baseline, preserves its entries, and writes a
small delta over the immutable base assets rather than a full replacement PCK.
Extracted native projects use isolated validation save directories.

Run Godot 4.7.2 with `--path <scratch>/baseline --script <absolute check.gd>`,
then the same command with `<scratch>/candidate`. This particular check needs
the graphics renderer: the headless dummy renderer cannot read back MultiMesh
transforms. Run the existing fit, route and door checks headlessly against the
candidate. Capture with `capture.gd -- <absolute image output directory>`.

The new builder is pinned to the merged `.96-fit.1` recipe. If main changes,
adapt the baseline first instead of replacing a newer runtime with this one.
