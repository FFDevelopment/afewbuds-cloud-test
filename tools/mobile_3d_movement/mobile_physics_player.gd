extends CharacterBody3D
## Shared mobile/web first-person physics body. UI and interaction stay with the
## game; this controller owns grounded capsule movement for touch, keyboard and
## eventually controller input on every AFewBuds build.
const WALK_SPEED:=3.4
const ACCELERATION:=15.0
const DECELERATION:=20.0
const GRAVITY:=18.0
const BODY_HEIGHT:=2.43
const BODY_RADIUS:=0.26
var desired:=Vector2.ZERO
var camera_yaw:=0.0
var enabled:=false

func _ready() -> void:
	collision_layer=4
	collision_mask=1
	motion_mode=CharacterBody3D.MOTION_MODE_GROUNDED
	floor_snap_length=.32
	floor_max_angle=deg_to_rad(48.0)
	floor_stop_on_slope=true
	max_slides=6
	safe_margin=.025
	var collider:=CollisionShape3D.new()
	collider.name="PlayerCapsule"
	var capsule:=CapsuleShape3D.new()
	capsule.radius=BODY_RADIUS
	capsule.height=BODY_HEIGHT
	collider.shape=capsule
	collider.position.y=BODY_HEIGHT/2.0
	add_child(collider)

func drive(input_vector:Vector2,yaw:float) -> void:
	desired=input_vector.limit_length(1.0)
	camera_yaw=yaw
	enabled=true

func stop() -> void:
	desired=Vector2.ZERO
	velocity=Vector3.ZERO
	enabled=false

func _physics_process(delta:float) -> void:
	if not enabled:
		velocity.x=move_toward(velocity.x,0.0,DECELERATION*delta)
		velocity.z=move_toward(velocity.z,0.0,DECELERATION*delta)
		return
	var direction:=Basis(Vector3.UP,camera_yaw)*Vector3(desired.x,0,desired.y)
	var target:=direction*WALK_SPEED
	var rate:=ACCELERATION if desired.length_squared()>.0025 else DECELERATION
	velocity.x=move_toward(velocity.x,target.x,rate*delta)
	velocity.z=move_toward(velocity.z,target.z,rate*delta)
	velocity.y=-.5 if is_on_floor() else velocity.y-GRAVITY*delta
	move_and_slide()
