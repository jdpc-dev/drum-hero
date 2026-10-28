class_name ParticleBurst
extends Node2D

var _particles: Array[Dictionary] = []
var _duration: float = 0.4
var _timer: float = 0.0
var _color: Color = Color.WHITE
var _initialized: bool = false


func _init_particles() -> void:
	if _initialized:
		return
	_initialized = true
	for i in range(16):
		var rect := ColorRect.new()
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)
		_particles.append({
			"rect": rect,
			"vel": Vector2.ZERO,
			"life": 0.0,
		})


func play(color: Color) -> void:
	_init_particles()
	_timer = _duration
	_color = color
	for i in range(16):
		var p = _particles[i]
		var angle: float = randf_range(0, TAU)
		var speed: float = randf_range(60, 250)
		p.rect.position = Vector2.ZERO
		p.rect.size = Vector2(randf_range(4, 10), randf_range(4, 10))
		p.rect.color = color
		p.rect.color.a = 1.0
		p.rect.visible = true
		p.vel = Vector2(cos(angle), sin(angle)) * speed
		p.life = randf_range(0.2, _duration)


func _process(delta: float) -> void:
	if _timer <= 0.0:
		return
	_timer -= delta
	for p in _particles:
		if p.life <= 0.0:
			continue
		p.rect.position += p.vel * delta
		p.life -= delta
		var alpha: float = sqrt(clampf(p.life / _duration, 0.0, 1.0))
		p.rect.color.a = alpha if p.life > 0.0 else 0.0
		p.rect.visible = p.life > 0.0
	if _timer <= 0.0:
		if get_parent():
			get_parent().remove_child(self)
