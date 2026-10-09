# Furniture placement repair

Purchased and existing non-legacy computer desks now use the complete original textured assembly. All original desk parts are captured together, preventing detached pieces in an empty house. Placement previews reuse the rendered item and omit collision bodies.

Backpack placement selects the property the player is inside. A walk-around layout mode supports repeated move and pickup actions. Occupied equipment remains blocked. Hidden stashes snap to suitable full-height wall segments. House grow-room bounds follow the inside wall faces; abandoned shelf collision bodies and empty station labels are removed.

Verified with paired property isolation integration tests covering desk textures and assembly, preview parity, current-property placement, near-wall tents, layout selection/cancellation, wall mounting and existing property inventory separation. Release pipelines run the broader regression suites.
