class_name TouchInput
extends Node

var _hit_detection
var _highway_ref
var _lane_count: int = 8


func setup(highway, hit_detection) -> void:
    _highway_ref = highway
    _hit_detection = hit_detection
    _lane_count = highway.lane_nodes.size()


func _input(event: InputEvent) -> void:
    if GameManager.state != GameManager.GameState.PLAYING:
        return

    if event is InputEventKey and event.pressed and not event.echo:
        var key: int = event.keycode
        if key >= KEY_1 and key <= KEY_8:
            var lane_index: int = key - KEY_1
            if lane_index < _lane_count:
                _hit_detection.try_hit_lane(lane_index, Vector2.ZERO)
                InputManager.lane_touched.emit(lane_index, true)
            return

    if event is InputEventScreenTouch or event is InputEventMouseButton:
        var is_press: bool = false
        var pos: Vector2 = Vector2.ZERO
        var idx: int = 0
        if event is InputEventScreenTouch:
            is_press = event.pressed
            pos = event.position
            idx = event.index
        elif event is InputEventMouseButton:
            if event.button_index != MOUSE_BUTTON_LEFT:
                return
            is_press = event.pressed
            pos = event.position
            idx = 0
        if is_press:
            var lane_index: int = _touch_to_lane(pos)
            if lane_index >= 0:
                _hit_detection.try_hit_lane(lane_index, pos)
                InputManager.handle_touch_event(idx, pos, true, _lane_count)
        else:
            InputManager.handle_touch_event(idx, pos, false, _lane_count)


func _get_virtual_width() -> float:
    return ProjectSettings.get_setting("display/window/size/viewport_width", 1920)


func _touch_to_lane(position: Vector2) -> int:
    var screen_w: float = _get_virtual_width()
    var lane_w: float = screen_w / float(_lane_count)
    var idx: int = int(position.x / lane_w)
    return clampi(idx, 0, _lane_count - 1)
