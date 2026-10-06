# Cloud-test .78 map port

Preserves the .70 career runtime and .72 account interface; adds only the house
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
