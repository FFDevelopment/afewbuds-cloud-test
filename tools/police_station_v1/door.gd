extends "res://scripts/interior_door.gd"
## Narrow staff corridors require these doors to swing into their rooms.
var swing_side:=0.0
func toggle(player:Vector3) -> void:
	super.toggle(global_position+global_basis.z*swing_side if swing_side!=0 and not opened else player)
