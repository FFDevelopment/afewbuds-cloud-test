# Police station district

Release `0.7.9-beta.19-cloudtest.97-police.1` extends the map east of the
pocket park with a two-floor police station, four parked patrol cars in the
rear lot, public parking beside the station, a crossing street and four
decorative homes across the main road. The east boundary moves from 137 to 201.

The building follows the supplied AFewBuds station layout and material guide
using the game's current simplified geometry style. It uses warm concrete,
navy metal, dark frames, tinted windows, plaster, speckled ground-floor flooring,
matte upper flooring and procedural oak grain. It is a playable first pass,
not a reproduction of the concept image's photorealistic asset detail.

Ground floor: public lobby and reception, public restroom, booking counter,
interview room, evidence store, two holding cells and rear booking entrance.
Upper floor: briefing room, kitchenette/break area, lockers, staff toilet,
chief's office and four workstations. A continuous stairwell joins the floors;
it uses floor-aware collision and camera support rather than teleporting.

All 14 station doors work with the contextual action and double tap. Approach
the front entrance from the sidewalk east of the park, then enter staff access
to explore the rest of the building. The stairwell is on the right, beyond
the public restroom. Staff rooms are explorable in this test release.
The station does not yet add police NPCs, arrest logic, booking/evidence gameplay,
driveable patrol vehicles or new chair interactions. Existing park bench and
couch seating remain available with their corrected eye height.

## Validation

- 249 station checks: closed/open door clearance, action-button and double-tap
  interaction, modal guard, walking routes to every room, stair clearance,
  actual touch movement up/down, both eye heights, window bands and containment.
- 901 map regression checks, including original tree/soil alignment, park
  routes, original five functional doors and upper-window alignment.
- 125 character/furniture checks and 55 seating checks pass; existing
  house/market room-route checks report zero failures.
- JavaScript loader reconstruction matches the packaged SHA-256. Chrome guest
  startup is checked without signing into or changing a cloud career.
- All 211 other prior pack entries remain byte-identical to `.96-east.3`.
  Only existing neighborhood integration and the east containment fence change;
  four new station scripts/shader are added. The three completed buildings,
  interiors, characters, furniture and park assets are preserved.
- 3,678 original aboveground batch instances inside x<136, -35<z<38 have the
  same geometry hash before/after. Boundary rails and appended paving are
  intentionally outside that comparison.
- Static batch instances rise from 4,723 to 6,408, batches from 45 to 139.
  These are geometry counts, not an FPS guarantee. The station itself uses
  854 box instances across 85 material/floor batches plus doors/windows/lights.

The review page contains actual Godot renders, including each floor as a
cutaway and first-person views. Cutaway captures hide the other floor/roof;
runtime keeps the full shell. See [review.html](review.html).

## Reproduce

```text
python -B tools/police_station_v1/build.py --output-dir <scratch>
node tools/police_station_v1/verify_loader.mjs
godot --headless --path <scratch>/candidate --script <absolute check.gd>
```

Run `check_regression.gd` with the graphics renderer against baseline then
candidate; headless dummy rendering cannot report actual MultiMesh transforms.
Run the existing seating, fit and room-route checks against candidate. Capture
using `capture.gd -- <output-directory>` with the graphics renderer.

The builder is pinned to the verified `.96-east.3` recipe hash. If main's runtime
changes, adapt the baseline before rebuilding. Native validation projects use
an isolated save directory. Source reference images were supplied by the user;
no external model or paid image-generation services were used.
