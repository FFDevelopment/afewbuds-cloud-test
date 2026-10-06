extends Node3D
var opened := false
var busy := false
var width := 1.5
var open_angle := PI/2
var pass_through := false
var host: Node3D
func toggle(player: Vector3) -> void:
	if busy:return
	if not opened:
		var point:=to_local(player)
		open_angle=PI/2 if point.z>=0.0 else -PI/2
	busy=true;pass_through=true
	host.neighborhood.collision_timer=0.0
	var leaf: Node3D=get_node("Leaf")
	var tween:=create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(leaf,"rotation:y",0.0 if opened else open_angle,0.4)
	tween.tween_callback(func():
		opened=not opened;busy=false
		refresh_collision()
	)
func refresh_collision() -> void:
	if busy:return
	var point: Vector3=get_node("Leaf").to_local(host.camera.global_position)
	var near_leaf: bool=Vector2(point.x,point.z).distance_to(Vector2(clampf(point.x,0.0,width),0.0))<0.40
	var next: bool=near_leaf
	if next!=pass_through:host.neighborhood.collision_timer=0.0
	pass_through=next
func _process(_delta: float) -> void:
	if pass_through and not busy:refresh_collision()
