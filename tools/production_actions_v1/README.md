# Production task animation integration

Production workers now present their existing trim, bag and harvest tasks with a shared rig controller. Raw stock still becomes trimmed stock, then bagged product through the existing host commit functions. Visual sampling does not mutate inventory. Batch size remains 3 g.

Task dwell is now 4 seconds for trim, 6 for bag and 4.5 for harvest (previously 0.95 seconds each). This reduces throughput intentionally so the actions are readable. Other task timings and offline-care rules are unchanged.

The worker resolves its owned station and selected plant. Bench approach respects the scale display's facing direction; harvest approach respects tent orientation/floor elevation. At the bench it trims with scissors, weighs a portion, closes a side-held bag and lowers it. At a plant it reaches, snips and lowers the harvested cutting in its hand. The crop remains intact until the host's normal harvest completion. Pose targets are reach-limited; further visual polish may be needed on unusual layouts.

`bench_layout.gd` applies the approved smaller scale, tray placement and tool cleanup to original and purchased benches. The visible scale shows the current bagging batch during the weighing segment, restoring its previous idle display afterward.

Validation: desktop and generated mobile task tests each sample 567 poses across all nine friends, verify off-duty cleanup and no inventory writes from visual sampling, then verify single trim/bag/harvest completion without duplicate awards. Desktop asset validation and the 36-check station walking regression passed. Mobile pack reconstruction passed. The candidate logs retain existing image-loading warnings for floor/rug textures; full export/CI success is not asserted by these local checks.

ProductionActions is visual-only. First-person player hands, automatic machine packers, group sessions and player-driven harvest animation are not added here. Changes are on the friend-character development branch, not tester releases.

Worker tending now includes planting (4.5 s), watering (4 s), and fertilizing (3.5 s). These use the selected pot soil position, a planted-foot crouch, seed packet, watering can, and feed bottle. Supplies and plant state remain controlled by the existing completion code. All nine characters are sampled across six tasks; tests verify single seed/supply consumption and repeat-completion safety.

Strain color restoration: task buds, tray stock, worker bag contents, and manual trim buds use the plant palette and bud texture, including runtime-registered genetics profiles. Tray refresh keys include per-strain quantities. Worker selection now prioritizes all raw trimming, then all bagging, then storage, with existing plant-care priority and inventory completion rules unchanged. Regression tests cover equal-weight strain swaps, future profiles, mixed-strain conservation, full storage, and care/resume.

Continuous trimming: immediately choose the next task after a trim completion; retain the working arm pose across internal progress portions while the same strain remains. Ease out only on the final portion, reset on interruption, and keep the strain task caption. Production-worker caption raised to 2.55 m with camera-facing billboard. Tests exercise the real update loop across completion, measure hand continuity, verify strain switch captions, and retain inventory conservation checks.
