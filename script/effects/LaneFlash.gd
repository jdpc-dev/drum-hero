class_name LaneFlash
extends Node2D

var _duration: float = 0.08
var _timer: float = 0.0
var _color: Color = Color(1, 1, 1, 0.5)
var _rect: Rect2


func play(lane_width: float = 0.0) -> void:
    _timer = _duration
    _rect = Rect2(-lane_width * 0.5, -50, lane_width, 100)


func _process(delta: float) -> void:
    if _timer > 0.0:
        _timer -= delta
        queue_redraw()
        if _timer <= 0.0:
            queue_free()


func _draw() -> void:
    if _timer > 0.0:
        var alpha: float = clampf(_timer / _duration, 0.0, 1.0)
        draw_rect(_rect, Color(_color.r, _color.g, _color.b, alpha * 0.5))
