# .92 door swing and manager walking

Uses the fixed-hinge side selection from the 3D prototype integration branch's game/prototype/door_swing.gd: positive hinge-local Z opens +PI/2, negative Z opens -PI/2. The stored angle is retained when closing, including rotated doors. Apartment has its equivalent fixed world hinge axis. Existing property inspection/unlock checks remain in neighborhood interaction routing.

Unlike the prototype's swept clearance refusal, this mobile adaptation permits the leaf to pass through the player during opening and closing. Door animations do not lock walking controls. Moving leaves are excluded from the runtime's rectangle collision collection, and collision is deferred while the player still overlaps the final leaf; it resumes once clear. Closed doors remain solid afterwards. Repeat input while animating is ignored rather than queued.

Assigned managers rotate toward travel and use walk/idle clips on Malik/Rod rigs. Generic dealers use the production staff's articulated arm/leg gait. Sitting preserves the seated pose.

Native checks: all five map doors plus apartment from both sides, rotated hinge, occupied closing path, restored collision, animation input debounce, named and generic walk cycles. Original dealer service/toggle regression and actual verified JS pack loader also checked.
