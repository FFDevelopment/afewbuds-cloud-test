extends CharacterBody3D
## Shared mobile/web first-person physics body. UI and interaction stay with the
## game; this controller owns grounded capsule movement for touch, keyboard and
## controller input on every AFewBuds build.
const WALK_SPEED:=3.4
const SPRINT_SPEED:=5.4
const ACCELERATION:=15.0
const SPRINT_ACCELERATION:=18.0
const DECELERATION:=20.0
const GRAVITY:=18.0
const BODY_HEIGHT:=2.43
const BODY_RADIUS:=0.26
const STAMINA_MAX:=100.0
const STAMINA_DRAIN:=18.0
const STAMINA_RECOVERY:=14.0
const STAMINA_RECOVERY_DELAY:=0.75
const STAMINA_REENABLE:=25.0
var desired:=Vector2.ZERO
var camera_yaw:=0.0
var enabled:=false
var wants_sprint:=false
var is_sprinting:=false
var exhausted:=false
var stamina:=STAMINA_MAX
var recovery_delay_left:=0.0

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

func drive(input_vector:Vector2,yaw:float,sprint_request:bool=false) -> void:
	desired=input_vector.limit_length(1.0)
	camera_yaw=yaw
	wants_sprint=sprint_request
	enabled=true

func stop() -> void:
	desired=Vector2.ZERO
	wants_sprint=false
	is_sprinting=false
	velocity=Vector3.ZERO
	enabled=false

func stamina_ratio() -> float:
	return clampf(stamina/STAMINA_MAX,0.0,1.0)

func _update_stamina(delta:float,forward:bool,moving:bool) -> void:
	if exhausted and stamina>=STAMINA_REENABLE:exhausted=false
	is_sprinting=enabled and wants_sprint and forward and moving and not exhausted and stamina>0.0
	if is_sprinting:
		stamina=maxf(0.0,stamina-STAMINA_DRAIN*delta)
		recovery_delay_left=STAMINA_RECOVERY_DELAY
		if stamina<=0.001:
			stamina=0.0
			exhausted=true
			is_sprinting=false
	else:
		recovery_delay_left=maxf(0.0,recovery_delay_left-delta)
		if recovery_delay_left<=0.0:
			stamina=minf(STAMINA_MAX,stamina+STAMINA_RECOVERY*delta)

func _physics_process(delta:float) -> void:
	var moving:=desired.length_squared()>.0025
	var forward:=desired.y<-.35
	_update_stamina(delta,forward,moving)
	if not enabled:
		velocity.x=move_toward(velocity.x,0.0,DECELERATION*delta)
		velocity.z=move_toward(velocity.z,0.0,DECELERATION*delta)
		return
	var direction:=Basis(Vector3.UP,camera_yaw)*Vector3(desired.x,0,desired.y)
	var speed:=SPRINT_SPEED if is_sprinting else WALK_SPEED
	var target:=direction*speed
	var rate:=SPRINT_ACCELERATION if is_sprinting else (ACCELERATION if moving else DECELERATION)
	velocity.x=move_toward(velocity.x,target.x,rate*delta)
	velocity.z=move_toward(velocity.z,target.z,rate*delta)
	velocity.y=-.5 if is_on_floor() else velocity.y-GRAVITY*delta
	move_and_slide()
