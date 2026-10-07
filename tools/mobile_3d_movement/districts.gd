extends RefCounted
## Shared world-space districts. Indoor floors keep their building's district.
const CITY := "Bongchester"

static func district_at(position: Vector3) -> String:
	# The east expansion starts at x=73; the police cross street starts at x=139.
	if position.x >= 139.0:return "Paranoia Point"
	if position.x >= 73.0:return "Half Baked Heights"
	return "Roachwood"

static func heading(position: Vector3) -> String:
	return CITY + " / " + district_at(position)
