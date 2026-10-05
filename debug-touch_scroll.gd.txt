extends ScrollContainer

# AFewBuds mobile phone gesture controller.
# A stationary touch is always a tap. Scrolling only begins after real movement.

const TAP_SLOP: float = 12.0

var finger: int = -1
var _start_pos: Vector2 = Vector2.ZERO
var _last_pos: Vector2 = Vector2.ZERO
var _dragging: bool = false

func is_gesture_busy() -> bool:
    return finger >= 0 or finger == -2

func cancel_touch() -> void:
    finger = -1
    _start_pos = Vector2.ZERO
    _last_pos = Vector2.ZERO
    _dragging = false

func _begin_pointer(pointer: int, pos: Vector2) -> bool:
    if finger != -1:
        return false
    finger = pointer
    _start_pos = pos
    _last_pos = pos
    _dragging = false
    return false

func _drag_pointer(pointer: int, pos: Vector2, relative: Vector2) -> bool:
    if pointer != finger:
        return false
    if not _dragging and _start_pos.distance_to(pos) >= maxf(TAP_SLOP, float(scroll_deadzone)):
        _dragging = true
    _last_pos = pos
    if not _dragging:
        return false
    scroll_vertical -= int(round(relative.y))
    return true

func _end_pointer(pointer: int) -> bool:
    if pointer != finger:
        return false
    var consumed := _dragging
    cancel_touch()
    return consumed

func handle_pointer(event: InputEvent) -> bool:
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed:
            return _begin_pointer(touch.index, touch.position)
        return _end_pointer(touch.index)

    if event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        return _drag_pointer(drag.index, drag.position, drag.relative)

    # Web builds can emit emulated mouse events for touch. Keep taps pass-through
    # and only consume once the pointer actually becomes a drag.
    if event is InputEventMouseButton:
        var button := event as InputEventMouseButton
        if event.device != -1 or button.button_index != MOUSE_BUTTON_LEFT:
            return false
        if button.pressed:
            if finger != -1:
                return false
            finger = -2
            _start_pos = button.position
            _last_pos = button.position
            _dragging = false
            return false
        if finger == -2:
            var consumed := _dragging
            cancel_touch()
            return consumed
        return false

    if event is InputEventMouseMotion:
        var motion := event as InputEventMouseMotion
        if event.device != -1 or finger != -2:
            return false
        if not _dragging and _start_pos.distance_to(motion.position) >= maxf(TAP_SLOP, float(scroll_deadzone)):
            _dragging = true
        _last_pos = motion.position
        if not _dragging:
            return false
        scroll_vertical -= int(round(motion.relative.y))
        return true

    return false
