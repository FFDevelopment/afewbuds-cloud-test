# AFewBuds shared gameplay core — safe migration architecture

## Repository strategy
**Do not combine public releases or replace save identities.** Two public
distribution repositories remain intact:
- Mobile/web: `FFDevelopment/afewbuds-beta` (PWA, touch controls and updater)
- Desktop: `FFDevelopment/AFewBuds-Desktop-Beta` (Windows/Linux + launcher)

Development sources remain in `afewbuds-3d-prototype` and `afewbuds-cloud-test`.
The canonical shared property module currently lives at
`afewbuds-3d-prototype/game/scripts/property_registry.gd`; the mobile source
contains a byte-identical copy, checked against the pinned canonical commit by CI.

A future monorepo or dedicated `afewbuds-core` repository could hold all
shared simulation code, but moving source trees is **not required** to share
rules and risks breaking build and release paths.

## Migration contract (registry v1)
- Keep the original `apartment` and `house` save keys unchanged.
- The new `location_state.property_registry` key is additive. Existing
  `furniture_v1`, `container_inventory`, `property_utilities`,
  `staff_assignments`, `property_opportunity_state`, and
  `apartment_rent_state` continue to own the existing data.
- Stable IDs do not change when a property is renamed. New player-created IDs
  come from a monotonic serial; authored buildings may use explicit IDs.
- No implicit ownership of new buildings. Legacy apartment/house access rules
  and existing rent, lease and purchase behavior are retained.
- Metadata supports multiple rooms, per-room grow restrictions and nested units.
- Registry schema versions must never decrease on save reload.
- Do not promote a new feature to a public beta until old-career fixtures,
  restored saves, property-isolation tests and both export pipelines pass.
- Test import and cloud-save transactions without changing player accounts.
  Save migration should be idempotent; failed validation must not overwrite
  the last confirmed career. Existing updater and rollback paths stay intact.

## Scope of the current development milestone
Implemented: stable-ID registry, additive legacy registration, independent
property data buckets, name changes, nested units, valid-room mapping, property
access checks, and partial furniture placement integration.

Not complete: dynamic computer station registration, generalized utility
simulation, custom-property NPC navigation/worker scheduling, grow wall panels
in arbitrary buildings, all future delivery points, full item/NPC registries,
and a complete universal game-core extraction. These remain on legacy
apartment/house paths until converted and tested. **Do not publish this
development branch as a universal property system yet.**

## Verification
- Desktop: `python tools/test.py GODOT dynamic_property_test property_isolation_test equipment_test`
- Mobile candidate: `python tools/mobile_3d_movement/build.py --output-dir OUTPUT`
  then Godot imports the candidate and runs
  `tools/dynamic_property_v1/check.gd` and the property-isolation test.
- CI checks byte-level equality of the same Godot registry logic on desktop
  and mobile and prevents drift between platforms.

## Next shared modules
Convert future-property interactions systematically:
1. Registered door/room boundaries and entry/curb positions.
2. Property-scoped furniture and equipment catalog + placement.
3. Property-scoped inventory, computers, utilities, grow panels and workers.
4. Shared NPC rig/animation definitions and behavior.
5. Versioned save migration and end-to-end release tests for both platforms.

Never change public PWA/app storage keys, launcher data paths, account IDs,
career IDs, or recorded purchases just to consolidate repositories.

## Universal item and equipment registry (v1 development)
- `game/scripts/item_registry.gd` is the canonical implementation mirrored
  byte-for-byte into mobile at `tools/item_registry_v1/item_registry.gd`.
- The original `property_furniture.gd` catalog remains the immutable
  `LEGACY_CATALOG`. At startup the shared item registry makes an identical
  runtime dictionary that the current shop, pricing, backpack weight,
  furniture placement, and upgrade systems can read without changing save IDs.
- New SKU definitions require price, shop, label, weight, dimensions and may
  specify room-type restrictions, optional model path and interaction metadata.
- A new item model is **not automatically modeled or animated**: its graphical
  scene, UI art and any unique behavior still need to be supplied and tested.
- Existing SKUs cannot be overwritten by content registration. Changed item
  economics or renames require an explicit versioned migration with tests.
- No new item definitions are written into player career saves, and this
  development milestone does not touch live accounts.
- Godot checks `prototype/item_registry_test.gd` on desktop and
  `tools/item_registry_v1/check.gd` in mobile's reconstructed candidate
  compare all legacy definitions and verify dynamic registration behavior.

## Planned next stages — do not describe these as shipped
1. Finish dynamic property services: placement, delivery/entry locations,
   computers, grow panels, bills, utilities, inventory, workers, and access.
2. Reuse the item registry for richer asset/model definitions, interactions
   and upgrade graph validation (without removing old purchases).
3. Standardize character identity, shared rigs and animation state to stop
   NPC visual duplication, and preserve desktop/mobile controls.
4. Add property-scoped worker work orders and station scheduling.
5. Add data-defined stories, milestones and conversations with stable IDs.
6. Extend the economy and business accounts with one consistent transaction
   record for each property.
7. Extend interaction registrations to doors, stations, computers and NPCs.
8. Require explicit versioned save migrations, snapshots, idempotence,
   corruption rollback, public-beta QA and platform parity at each release.


## Property spatial contract v2 (development)

The shared registry accepts optional `set_room_height(property, room, floor,
ceiling)` bounds, with the floor included and ceiling excluded. Both room and
property lookup respect these bounds; overlapping floors resolve independently.
Legacy rooms without authored heights retain their original behavior. This
change does not change existing map geometry or guess legacy floor heights.

`register_site` records stable named entry, curb, delivery, grow-panel, packing,
supply and staff destinations. Interior destinations must lie in their declared
room and floor. `sites_for` filters invalid/stale locations and returns copies.
Sites do not grant access, teleport players, create stations or schedule workers.
Those consumers still need conversion as part of the property-services stage.

Schema 2 adds only optional height/site fields to existing registry records.
Old property IDs, purchases, balances, staff and save identities are preserved.
The shared 41-check registry fixture covers stacked floors, boundary edges,
invalid destinations, access, JSON reload and repeated migration. The normal
mobile release pipeline now gates on registry and item tests as desktop does.

## Agreed advancement delivery order

1. Complete property service routing from registered rooms and destinations.
2. Extend the item/equipment registry and validate upgrades/asset definitions.
3. Standardize NPC identity, shared rigs and animation contracts.
4. Route worker work orders and business automation through property services.
5. Move story/milestone/conversation definitions into a shared story engine.
6. Consolidate property economy transactions and business records.
7. Unify physical interaction registrations and access checks.
8. Add explicit versioned career migrations and recovery across both platforms.

The existing phone/desktop save-sync fix is a working baseline, not an
unfinished prerequisite. Preserve it through every phase. Alongside these
stages, finish verified update-before-play delivery for desktop and mobile.
The eight stages are not all shipped; spatial v2 is the first additional slice
of stage 1 after the phone UI work.
