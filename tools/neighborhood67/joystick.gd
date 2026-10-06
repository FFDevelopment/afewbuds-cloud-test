extends Control
# One captured finger steers; another remains available for camera look.
var value := Vector2.ZERO
var pointer := -99
var knob := Vector2.ZERO
const RADIUS := 72.0
const DEAD_ZONE := 0.12
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 visibility_changed.connect(_release_if_hidden)
func _release_if_hidden() -> void:
 if not is_visible_in_tree(): release()
func release() -> void:
 pointer=-99
 value=Vector2.ZERO
 knob=Vector2.ZERO
 queue_redraw()
func _set_point(point: Vector2) -> void:
 var delta: Vector2=point-get_global_rect().get_center()
 knob=delta.limit_length(RADIUS)
 var magnitude: float=knob.length()/RADIUS
 value=Vector2.ZERO if magnitude <= DEAD_ZONE else knob.normalized()*clampf((magnitude-DEAD_ZONE)/(1.0-DEAD_ZONE),0.0,1.0)
 queue_redraw()
func _input(event: InputEvent) -> void:
 if not is_visible_in_tree(): return
 if event is InputEventScreenTouch:
  if event.pressed and pointer==-99 and get_global_rect().has_point(event.position):
   pointer=event.index
   _set_point(event.position)
   get_viewport().set_input_as_handled()
  elif not event.pressed and pointer==event.index:
   release()
   get_viewport().set_input_as_handled()
 elif event is InputEventScreenDrag and event.index==pointer:
  _set_point(event.position)
  get_viewport().set_input_as_handled()
 elif event is InputEventMouseButton and event.device!=-1 and event.button_index==MOUSE_BUTTON_LEFT:
  if event.pressed and pointer==-99 and get_global_rect().has_point(event.position):
   pointer=-1
   _set_point(event.position)
   get_viewport().set_input_as_handled()
  elif not event.pressed and pointer==-1:
   release()
   get_viewport().set_input_as_handled()
 elif event is InputEventMouseMotion and event.device!=-1 and pointer==-1:
  _set_point(event.position)
  get_viewport().set_input_as_handled()
func _draw() -> void:
 var center:=size/2.0
 draw_circle(center,RADIUS+12.0,Color(0.06,0.13,0.11,0.75))
 draw_arc(center,RADIUS+12.0,0,TAU,64,Color("71bb91"),2.0,true)
 draw_circle(center+knob,29.0,Color(0.24,0.52,0.39,0.92))
 draw_arc(center+knob,29.0,0,TAU,40,Color("b0e2bd"),2.0,true)
 for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
  draw_line(center+direction*58.0,center+direction*66.0,Color("71bb91"),2.0,true)
