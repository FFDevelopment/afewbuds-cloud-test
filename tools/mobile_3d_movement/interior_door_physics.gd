extends Node3D
var opened:=false
var busy:=false
var width:=1.5
var open_angle:=PI/2
var pass_through:=false
var host:Node3D
var physics_body:StaticBody3D
var physics_shape:CollisionShape3D

func _ready() -> void:
	call_deferred("_ensure_physics")

func _ensure_physics() -> void:
	if physics_body!=null or not has_node("Leaf"):return
	physics_body=StaticBody3D.new()
	physics_body.name="DoorPhysics"
	physics_body.collision_layer=1
	physics_body.collision_mask=4
	physics_shape=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(width,2.72,.12)
	physics_shape.shape=shape
	physics_shape.position=Vector3(width/2,1.36,0)
	physics_body.add_child(physics_shape)
	get_node("Leaf").add_child(physics_body)
	_refresh_physics_collision()

func _set_leaf_collision(solid:bool) -> void:
	_ensure_physics()
	if physics_shape!=null:physics_shape.set_deferred("disabled",not solid)

func _refresh_physics_collision() -> void:
	if physics_shape!=null:physics_shape.set_deferred("disabled",busy or pass_through)

func toggle(player:Vector3) -> void:
	if busy:return
	_ensure_physics()
	if not opened:
		var point:=to_local(player)
		open_angle=PI/2 if point.z>=0.0 else -PI/2
	busy=true
	pass_through=true
	if host!=null and host.neighborhood!=null:host.neighborhood.collision_timer=0.0
	_set_leaf_collision(false)
	var leaf:Node3D=get_node("Leaf")
	var tween:=create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(leaf,"rotation:y",0.0 if opened else open_angle,0.4)
	tween.tween_callback(func():
		opened=not opened
		busy=false
		refresh_collision()
	)

func refresh_collision() -> void:
	if busy:return
	var player_position:Vector3=host.camera.global_position if host!=null else global_position
	if host!=null and host.neighborhood!=null and host.neighborhood.physics_body!=null:
		player_position=host.neighborhood.physics_body.global_position+Vector3.UP*host.neighborhood.WALK_EYE_HEIGHT
	var point:Vector3=get_node("Leaf").to_local(player_position)
	var near_leaf:bool=Vector2(point.x,point.z).distance_to(Vector2(clampf(point.x,0.0,width),0.0))<.40
	var next:bool=near_leaf
	if next!=pass_through and host!=null and host.neighborhood!=null:host.neighborhood.collision_timer=0.0
	pass_through=next
	_refresh_physics_collision()

func _process(_delta:float) -> void:
	if physics_body==null:_ensure_physics()
	if pass_through and not busy:refresh_collision()
