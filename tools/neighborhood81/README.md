# Cloud-test .79 house controls

Preserves the career economy and account interface; extends the house
and Central Market map geometry from prototype 0.9.5 integration commit
`a5d64b5fd2b2265ca4dc4f8a7aae00784c2ef0eb`.

The existing block, texture atlas, apartment, analog movement, look gestures,
station interactions, responsive phone UI, sounds and Chapter 4 progression
remain. House entrance requires the existing `property_offer_unlocked` flag.
House rooms are a tour; this does not enable relocation, house production,
property transactions, or market purchases.

Adaptations:
- Prototype meshes use the existing cloud texture atlas and material cache.
- Five doors use existing nearby action controls and double tapping.
- Door opening and closing require clearance through the complete swing.
- Collision rectangles are refreshed after door movement. Glass and stocked
  shelf volumes remain solid; wall openings are real apertures.
- Nearby door interactions check the approach path; look swipes cannot tap doors.

Build: `python tools/build_neighborhood76.py`, then `python tools/make_delta76.py`.
The pack builder verifies that every unrelated .63 entry remains byte-identical.
The delta builder reconstructs and verifies the complete pack byte for byte.

Validation: run `check_map.gd` against the extracted pack with Godot 4.7.2.
Checks cover all five doors, the house progression gate, collidable windows,
routes between outside and each room, swing refusal, close collision restoration,
double tapping and swipe protection. Existing .70 apartment/station/phone-layout
checks are also run against the updated pack with an isolated test save directory.

Window privacy update: bathroom trim and glass fit the exact 1.1 x 1.0 m wall
aperture. Both packing-room windows have closed slatted blinds over opaque
backing. Both grow-room windows have closed blackout shades. Coverings are
placed behind the existing glass, without changing room routes or collision.

Client visits: `client_visits.gd` routes away arrivals to saved actionable phone
texts. Replies invite a client in 10 game minutes (Stop by now), 60 or 120 game
minutes, or decline for now. The appointment shows its game day and clock time;
only active simulation time advances it. Missing an appointment sends another
replyable text. Duplicate pending texts are suppressed. Generic arrivals yield
the doorstep around appointment times; normal at-home sales remain unchanged.
Official visits are queued until home. The obsolete Go to Door control is hidden
and its pointer handler disabled; the nearby apartment action checks the door.

`check_visits.gd` exercises real customer selection, away notifications, patience
and reputation, reply UI, actual save/load, due times and pause, physical
peephole/sale access, rejection cooldown, missed appointments and official visits.

The market sign and indoor location label now read CENTRAL MARKET.

House controls: eight room switches map to their own ceiling fixtures. Local
shadowed room lights respect interior walls. The separate house grow panel
controls only installed house grow lamps, which use their own lighting layer.
The house starts without grow tents, planters or grow lamps; future house
upgrades use `house_grow_tent_count`, independent of apartment equipment.
All four coverings raise/lower with a nearby double tap from their own room.
States persist in `house_control_state`; old saves default to closed coverings
and lit ceiling fixtures. The packing shelf leaves its side blind reachable.
`check_controls.gd` verifies each switch independently, clear approaches,
shade operation and outside/swipe guards, empty equipment and actual save/reload.

Apartment window: original solid wall and exterior skin are cut around a real
glass aperture. Painted-wall materials and side curtains are retained; the fake
sky panel and sun disc are removed. Its blinds default open, work only from
inside, and share career persistence with house controls. Window collision
remains solid with the blinds raised. Native render and save/reload checks cover
the apartment opening and both directions of covering movement.
