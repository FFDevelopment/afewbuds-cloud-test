# Cloud test .83 — property details and walking inspection

Rod's existing Chapter 4 property offer unlock remains the gate. Inspect the sale sign or approach and double-tap the house entrance to review property details. Tour House opens the physical door; no teleport, payment, equipment grant or premature chapter completion occurs.

Spend two active seconds in each of the six main rooms to inspect it. Room progress is stored in `property_opportunity_state` within the existing career save and restored on reload. Pause and other game panels prevent inspection progress. End Tour saves progress; reopening details lets the player continue. The grow room remains empty.

The responsive scroll panel keeps Tour and Back/End Tour controls visible. Existing apartment, market, house, shade, lighting, sky, client-visit, account and leaderboard behavior is preserved. Property payment options and relocation are the next phase.

Build: `python tools/build_neighborhood83.py` then `python tools/make_delta83.py`. The web loader reconstructs and verifies the .83 pack using the unchanged .63 pack. Do not upload the full generated pack.

Validation: `check_property.gd` covers the offer gate, real entrance interaction, modal input, walking tour, all six rooms, career serialization/reload, corrupt room IDs, paused progress, and no cash/equipment changes. `check_map.gd` retains door sweep, glass collision, room routing and touch tests, updated to enter via the property tour flow.
