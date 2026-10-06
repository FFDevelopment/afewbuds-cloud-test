# Park seating and seated eyes

Release `0.7.9-beta.19-cloudtest.96-east.3` adds seating to all three park
benches. Approach the open front and use **Sit on bench**, or double-tap it.
Use **Stand up**, keyboard movement or the touch stick to leave the seat.
The camera initially faces away from the backrest and remains free to look around.
Standing restores the previous walkable position, with checked front-of-bench
alternatives if that position becomes blocked.

The couch camera was still at 1.18 units, which was too low for the resized
characters. The actual midpoint of `Eye_L` and `Eye_R` in both Malik and Rod's
`sit` animation is `(0, 1.562837, -0.106215)` in world-sized model coordinates.
Both couch and bench views now use that position, rotated for the seat direction
and adjusted for the seat surface height. Standing restores the existing 2.16-unit
eye height. This does not introduce a visible playable avatar or customization UI.

Validation includes 55 seating checks, 113 character/furniture checks, 818 map
checks, existing room-route checks, verified JavaScript pack reconstruction,
and browser guest startup. Seating checks exercise the actual action signal,
double-tap handling, keyboard and touch movement, all three facing directions,
blocked exits, modal prevention, couch compatibility, and the imported eye bones.
Native renders show all three seated views, the couch view and a staged Rod
reference. Rod is present only in the review capture.

The map geometry and character assets are unchanged from `.96-east.2`.
The existing district builder imports `patch.py` and packages `seating.gd`.

```text
python -B tools/east_expansion_v1/build.py --output-dir <scratch>
godot --headless --path <scratch>/candidate --script <absolute tools/park_seating_v1/check.gd>
node tools/east_expansion_v1/verify_loader.mjs
```

Use the graphics renderer for the existing map checks and `capture.gd`.
The generated native project uses an isolated validation save directory.
Open [review.html](review.html) for screenshots; results are in `validation/`.
