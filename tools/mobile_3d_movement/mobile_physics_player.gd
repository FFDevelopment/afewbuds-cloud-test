extends CharacterBody3D
## Shared mobile/web first-person physics body. The neighborhood owns UI, camera
## and interaction state; this node owns capsule movement and floor response.
const WALK_SPEED:=3.4
const GRAVITY:=18.0
const BODY_HEIGHT:=2.43
const BODY_RADIUS:=0.26
var desired:=Vector2.ZERO
var camera_yaw:=0.0
var enabled:=false

func _ready() -> void:
	collision_layer=4
	collision_mask=1
	floor_snap_length=.28
	floor_max_angle=deg_to_rad(48.0)
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

func stop() -> void:
	desired=Vector2.ZERO
	velocity=Vector3.ZERO
	enabled=false

func _physics_process(delta:float) -> void:
	if not enabled:
		velocity.x=0.0
		velocity.z=0.0
		return
	var direction:=Basis(Vector3.UP,camera_yaw)*Vector3(desired.x,0,desired.y)
	velocity.x=direction.x*WALK_SPEED
	velocity.z=direction.z*WALK_SPEED
	velocity.y=-.5 if is_on_floor() else velocity.y-GRAVITY*delta
	move_and_slide()
