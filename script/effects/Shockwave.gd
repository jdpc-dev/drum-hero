class_name Shockwave
extends Node2D

var _radius: float = 0.0
var _max_radius: float = 200.0
var _duration: float = 0.3
var _timer: float = 0.0
var _color: Color = Color(1.0, 0.3, 0.1, 0.6)


func play() -> void:
	_timer = _duration
	_radius = 0.0


func _process(delta: float) -> void:
	if _timer <= 0.0:
		return
	_timer -= delta
	var progress: float = 1.0 - (_timer / _duration)
	_radius = _max_radius * progress
	queue_redraw()
	if _timer <= 0.0:
		if get_parent():
			get_parent().remove_child(self)


func _draw() -> void:
	if _timer > 0.0:
		var alpha: float = clampf(_timer / _duration, 0.0, 1.0)
		var c: Color = Color(_color.r, _color.g, _color.b, alpha)
		draw_circle(Vector2.ZERO, _radius, c, false, 3.0)
		draw_circle(Vector2.ZERO, _radius * 0.6, Color(c.r, c.g, c.b, alpha * 0.3))
