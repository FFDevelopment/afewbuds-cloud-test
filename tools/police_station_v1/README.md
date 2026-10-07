# Police station district

Release `0.7.9-beta.19-cloudtest.97-police.3` extends the map east of the
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

- 279 station checks: closed/open door clearance, action-button and double-tap
  interaction, modal guard, walking routes to every room, stair clearance,
  actual touch movement up/down, both eye heights, window bands and containment.
- 901 map regression checks, including original tree/soil alignment, park
  routes, original five functional doors and upper-window alignment.
- 125 character/furniture checks and 55 seating checks pass; existing
  house/market room-route checks report zero failures.
- JavaScript loader reconstruction matches the packaged SHA-256. Chrome guest
  startup is checked without signing into or changing a cloud career.
- All 211 other prior pack entries remain byte-identical to `.96-east.3`.
  Existing neighborhood integration, bark material, east containment fence
  and four paving/curb endpoints change;
  five new station scripts/shaders are added. The three completed buildings,
  interiors, characters, furniture and park assets are preserved.
- 3,674 original aboveground batch instances inside x<136, -35<z<38 have the
  same geometry hash before/after. Four boundary-junction curbs are excluded from that hash because their ends
  are shortened to clear the new crossing street. Boundary rails and paving are
  intentionally outside that comparison.
- Static batch instances rise from 4,723 to 6,476, batches from 45 to 141.
  These are geometry counts, not an FPS guarantee. The station itself uses
  914 box instances across 85 material/floor batches plus doors/windows/lights.

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

## Police district polish (.97-police.2)

Parking finishes now use non-overlapping rectangles. The patrol lot reaches the
rear lane, its painted bays follow the cars, and the forecourt no longer doubles
up over the front sidewalk. The old district's paving stops at the new crossing
street. All four opposite houses face the street and have connecting entrance
paths (decorative closed doors, like the existing opposite-apartment buildings).

Tree trunks share a procedural bark material with rough grain and shallow normal
detail; no new image download is required. The station's window schedule follows
room boundaries, with high frosted cell/toilet/locker windows, clearance from the
briefing board and partitions, and a kitchen sill above its counter. The facade
badge moves onto the solid navy column, and restroom mirrors sit on their walls.

279 station checks include parking surface overlap, all 18 windows against nearby
partitions/fixtures, four residence entrance orientations and paths, door
interaction and stair/room movement. The 901 map, 125 fit and 55 seating checks
also pass (1,360 total), plus room-route checks. Native renders cover 15 views;
Chrome guest startup rendered successfully with no reported warnings or errors.

The Pages staging script excludes unused historical packs/recipes and server-only
source from the deployment. It preserves those files in Git for old builders.
Its selection follows the active HTML loader and recipe rather than deleting old
source inputs. See `validation/deployment_size.json` and `size_audit.json` for
uncompressed sizes. These changes do not claim an FPS gain: the old files were
not fetched by the running game. About 72 MB of startup assets remain before web
compression, mostly the engine and immutable base pack; phone performance still
needs measurement on the target devices. The polish adds only about 3 KB to the
reconstructed game pack.

## Openings and driveway repair (.97-police.3)

The previous checks excluded the wall hosting each window and only inspected the
pane. This revision also checks every actual frame against every wall box. Frames
now fit inside the masonry aperture, with panes sized to the inner frame opening.
Walls extend the full 3.6-unit story; floors and ceilings stop inside the facade.
Exterior-wall skirting is placed on the interior face only. Its old centered boxes
had produced the visible dark strips outside at ground and upper-floor level.

Both lots have six-unit-wide asphalt driveway openings. Public parking now opens
through the sidewalk and curb directly to the main road; patrol parking opens
through the rear sidewalk to the lane, with cars moved clear of its center aisle.
The public parking sign stands beside the driveway. The accessible sign's text
and board both face its blue bay, whose boundaries align with the parking lines.

452 station checks and 901 map checks pass. These include frame/wall intersections,
glass apertures, floor/ceiling bounds, continuous facade coverage at the slab seam,
interior-only skirting, driveway/curb intersections, parked-car aisle clearance,
vehicle-width entry samples, sign direction and the existing room/stair routes.
21 native views include six close-ups of the reported defects. The 125 fit and 55
seating reports were last run for .97-police.2; their character/furniture assets
are unchanged here. No driving mechanic is introduced by these driveway repairs.
