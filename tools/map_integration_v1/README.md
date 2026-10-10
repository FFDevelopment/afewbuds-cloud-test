# Combined development build — 2026-10-10

Integrated map source: `FFDevelopment/afewbuds-3d-prototype`, branch `map/visual-lab-wood-basement-20261010`, commit `1a70d38090ca10463cead74364fc6bdd370b4da5`.

The desktop merge retains phone/gameplay source `8c9383e1498a2fccac9a242103b2ef8389bddbd9`. The mobile integration retains the native touch and account adapters. Continue future changes from development main, with shared behavior mirrored through the mobile builder.

Integration fixes:
- Normal map installation preserves loaded position, pause state and clock.
- Basement room heights cannot authorize upstairs furniture placement.
- New ventilation/auto-water wall mounting accepts the actual wall faces; support, collision, height and doorway checks remain enforced.
- House worker destinations retain saved floor height and use switchback waypoints between floors.
- House grow-panel status updates on both platforms.
- Quantity selectors and one persisted market cart cover seeds, fertilizer, equipment and furniture. Checkout validates the full order before charging once. Paid purchases persist at market pickup; collect only what fits and return for the rest.
- Equipment text distinguishes fixed placement locks from progression locks. Seed cards show their existing level requirement; current equipment purchases have no story-goal gate.

The two tester beta repositories are not part of this publication. Chapter 5 finale and a full redesigned unlock roadmap remain future work.

Regression coverage: map integration (startup, floors, mounting, panel, saves, worker route) and cart integration (mixed quantities, affordability, exact charge, double checkout, capacity overflow, persistence, locked seeds), plus existing gameplay suites and release export checks.

The checked patch runs after the existing phone pipeline and fails on source drift. Shared visual/cart modules are copied from the merged desktop project; platform map adapters are explicit.
