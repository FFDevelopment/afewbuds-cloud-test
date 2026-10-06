extends RefCounted
## Measured midpoint of Eye_L/Eye_R in the shared rig's sit animation.
const RIG_SEAT_TOP:=.4682184907339378
const RIG_SEATED_EYES:=Vector3(0,1.562837,-.106215)
var world:Node3D
var benches:Array[Dictionary]=[]
var seated:=-1
var return_position:=Vector3.ZERO

static func eyes(at:Vector3,facing:float,seat_top:float) -> Vector3:
	return at+Basis(Vector3.UP,facing)*(RIG_SEATED_EYES+Vector3.UP*(seat_top-RIG_SEAT_TOP))

func setup(owner:Node3D) -> void:world=owner

func add(at:Vector3,facing:float,seat_top:float) -> void:
	benches.append({"at":at,"facing":facing,"seat_top":seat_top})

func target() -> String:
	if seated>=0:return "bench_"+str(seated)
	var closest:=-1;var distance:=2.0
	for i in range(benches.size()):
		var b:Dictionary=benches[i]
		var local:Vector3=Basis(Vector3.UP,b.facing).inverse()*(world.host.camera.position-b.at)
		# Approach the open front, never pull the player through the backrest.
		var d:=Vector2(local.x,local.z).length()
		if local.z<-.35 and absf(local.x)<1.4 and d<distance:
			closest=i;distance=d
	return "bench_"+str(closest) if closest>=0 else ""

func stand() -> bool:
	if seated<0:return true
	var b:Dictionary=benches[seated]
	var candidates:Array[Vector3]=[return_position]
	for x in [0.0,-.65,.65]:
		candidates.append(b.at+Basis(Vector3.UP,b.facing)*Vector3(x,world.WALK_EYE_HEIGHT,-1.05))
	for at in candidates:
		at.y=world.WALK_EYE_HEIGHT
		if not world._walkable(at-world.ORIGIN):continue
		world.host.camera.position=at;seated=-1
		world.host.status_label.text="Back on your feet."
		return true
	world.host.status_label.text="The space in front of the bench is blocked."
	return false

func use(id:String) -> void:
	if not world.active or world.transitioning or world.host._any_modal_open() or world.host.daily_report_pending:return
	if seated>=0:stand();return
	if id!=target() or not id.begins_with("bench_"):return
	var i:=int(id.trim_prefix("bench_"));var b:Dictionary=benches[i]
	return_position=world.host.camera.position
	seated=i
	world.host.camera.position=eyes(b.at,b.facing,b.seat_top)
	world.host.camera.rotation=Vector3(0,b.facing,0)
	world.host.status_label.text="Relaxing on the bench. Move to stand up."

func tap(point:Vector2) -> bool:
	var id:=target()
	if id.is_empty():return false
	var at:Vector3=benches[int(id.trim_prefix("bench_"))].at+Vector3.UP*.65
	if seated<0 and (world.host.camera.is_position_behind(at) or world.host.camera.unproject_position(at).distance_to(point)>=150):return false
	var now:=Time.get_ticks_msec()
	if world.last_tap_station==id and now-world.last_tap_time<420:
		use(id);world.last_tap_station=""
	else:
		world.last_tap_station=id;world.last_tap_time=now
		world.host.status_label.text="Double tap to stand up." if seated>=0 else "Double tap the bench to sit. Move to stand up."
	return true
