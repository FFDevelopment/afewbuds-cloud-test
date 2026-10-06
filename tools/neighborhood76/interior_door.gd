extends Node3D
var opened := false
var busy := false
var width := 1.5
var host: Node3D

func toggle(player: Vector3) -> void:
	if busy: return
	var p := to_local(player)
	# Same full swept capsule clearance on opening and closing; never queue a refusal.
	for i in range(49):
		var a := float(i)/48*PI/2
		var d := Vector2(cos(a),-sin(a))
		var q := Vector2(p.x,p.z)
		if q.distance_to(d*clampf(q.dot(d),0,width)) < 0.38:
			host.status_label.text = "Door blocked — step back from the swing."
			return
	busy = true
	host.neighborhood.transitioning = true
	var leaf: Node3D = get_node("Leaf")
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(leaf,"rotation:y",0.0 if opened else PI/2,0.4)
	tween.tween_callback(func():
		opened = not opened
		busy = false
		host.neighborhood.collision_timer = 0.0
		host.neighborhood.transitioning = false
	)

