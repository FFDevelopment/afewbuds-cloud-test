"""Seating integration applied after the east district's geometry patch."""
def apply(text):
    def once(old,new):
        nonlocal text
        assert text.count(old)==1,repr(old)
        text=text.replace(old,new,1)
    once('extends Node3D','extends Node3D\nconst Seating=preload("res://scripts/seating.gd")\nvar bench_seating=Seating.new()')
    once('\thost = owner_node','\thost = owner_node\n\tbench_seating.setup(self)')
    once('\tif couch_seated:\n\t\tif movement.length()>0.15:_toggle_couch()', '\tif bench_seating.seated>=0:\n\t\tif movement.length()>0.15:bench_seating.stand()\n\t\tif bench_seating.seated>=0:movement=Vector2.ZERO\n\tif couch_seated:\n\t\tif movement.length()>0.15:_toggle_couch()')
    once('if not couch_seated:local.y=', 'if not couch_seated and bench_seating.seated<0:local.y=')
    once('\tif target=="couch":action.text=', '\tif target.begins_with("bench_"):action.text="STAND UP" if bench_seating.seated>=0 else "SIT ON BENCH"\n\tif target=="couch":action.text=')
    once('func _near_target() -> String:\n\tif couch_seated:return "couch"', 'func _near_target() -> String:\n\tif couch_seated:return "couch"\n\tvar bench_target:String=bench_seating.target()\n\tif not bench_target.is_empty():return bench_target')
    once('\tvar target:=_near_target()\n\tif target=="couch":', '\tvar target:=_near_target()\n\tif target.begins_with("bench_"):\n\t\tbench_seating.use(target)\n\t\treturn\n\tif target=="couch":')
    once('\tif _tap_apartment_light(point):return', '\tif bench_seating.tap(point):return\n\tif _tap_apartment_light(point):return')
    once('host.camera.position=Vector3(-1.785,1.18,3.035)', 'host.camera.position=Seating.eyes(Vector3(-1.785,0,3.035),0,ScalePolicy.SEAT_HEIGHT)')
    return text
