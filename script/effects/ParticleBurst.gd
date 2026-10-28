class_name ParticleBurst
extends Node2D

var _particles: Array[Dictionary] = []
var _duration: float = 0.4
var _timer: float = 0.0
var _color: Color = Color.WHITE


func play(color: Color) -> void:
    _timer = _duration
    _color = color
    _particles.clear()
    for i in range(16):
        var angle: float = randf_range(0, TAU)
        var speed: float = randf_range(60, 250)
        _particles.append({
            "pos": Vector2.ZERO,
            "vel": Vector2(cos(angle), sin(angle)) * speed,
            "life": randf_range(0.2, _duration),
            "size": randf_range(4, 10),
        })


func _process(delta: float) -> void:
    if _timer <= 0.0:
        return
    _timer -= delta
    for p in _particles:
        p.pos += p.vel * delta
        p.life -= delta
    queue_redraw()
    if _timer <= 0.0:
        queue_free()


func _draw() -> void:
    for p in _particles:
        if p.life > 0.0:
            var alpha: float = sqrt(clampf(p.life / _duration, 0.0, 1.0))
            draw_circle(p.pos, p.size, Color(_color.r, _color.g, _color.b, alpha))
