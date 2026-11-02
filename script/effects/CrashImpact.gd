class_name CrashImpact
extends Node2D

# Local cymbal burst for CRASH hits: a white-hot flash, a few fast metal rings
# and a spray of silver/gold sparks. It is drawn in world space on top of the
# notes, so the screen-space pressure bubble can still refract it as a whole.
#
# The node is pooled by EffectManager and removes itself when the burst ends.

const DURATION: float = 0.38
const SPARK_COUNT: int = 42

var _elapsed: float = 0.0
var _sparks: Array[Dictionary] = []
var _tint: Color = Color(1.0, 0.85, 0.55)


func _ready() -> void:
	z_index = 2
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	self.material = material
	set_process(false)


func play(color: Color) -> void:
	_tint = color
	_elapsed = 0.0
	_sparks.clear()

	for i in SPARK_COUNT:
		var angle: float = randf_range(0.0, TAU)
		var direction := Vector2(cos(angle), sin(angle))
		var pick: float = randf()
		var spark_color: Color
		if pick < 0.52:
			spark_color = Color(0.92, 0.96, 1.0)  # silver-white
		elif pick < 0.82:
			spark_color = Color(1.0, 0.95, 0.78)  # pale gold
		else:
			spark_color = Color(1.0, 0.78, 0.36)  # cymbal gold

		_sparks.append({
			"direction": direction,
			"speed": randf_range(420.0, 950.0),
			"age": 0.0,
			"life": randf_range(0.14, 0.34),
			"width": randf_range(1.2, 3.0),
			"length": randf_range(14.0, 38.0),
			"color": spark_color,
		})

	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	for spark in _sparks:
		spark.age += delta
	queue_redraw()

	if _elapsed >= DURATION:
		set_process(false)
		if get_parent():
			get_parent().remove_child(self)


func _draw() -> void:
	# White-hot center: a short, bright point of contact.
	var flash_t: float = _elapsed / 0.09
	if flash_t < 1.0:
		var fade: float = (1.0 - flash_t) * (1.0 - flash_t)
		var radius: float = lerpf(24.0, 82.0, flash_t)
		draw_circle(Vector2.ZERO, radius * 1.7, Color(_tint.r, _tint.g, _tint.b, fade * 0.18))
		draw_circle(Vector2.ZERO, radius, Color(_tint.r, _tint.g, _tint.b, fade * 0.45))
		draw_circle(Vector2.ZERO, radius * 0.55, Color(1.0, 1.0, 1.0, fade * 0.95))

	# Metal rings: a fast bright edge, a slower gold echo and a faint outer wash.
	_draw_ring(0.0, 0.16, 22.0, 200.0, 8.0, 1.0, Color(0.92, 0.96, 1.0))
	_draw_ring(0.012, 0.24, 10.0, 155.0, 3.5, 0.75, Color(1.0, 0.82, 0.45))
	_draw_ring(0.03, 0.34, 6.0, 250.0, 1.8, 0.42, Color(1.0, 0.95, 0.82))

	# Sparks: short outward streaks that slow down and fade.
	for spark in _sparks:
		var age: float = spark.age
		var life: float = spark.life
		if age >= life:
			continue
		var k: float = age / life
		var distance: float = spark.speed * age * (1.0 - 0.35 * k)
		var tip: Vector2 = spark.direction * distance
		var tail: Vector2 = tip - spark.direction * spark.length * (1.0 - k)
		var color: Color = spark.color
		color.a = pow(1.0 - k, 1.5)
		draw_line(tip, tail, color, maxf(0.5, spark.width * (1.0 - 0.6 * k)), true)


func _draw_ring(delay: float, duration: float, start_radius: float, end_radius: float, width: float, alpha: float, color: Color) -> void:
	var t: float = (_elapsed - delay) / duration
	if t < 0.0 or t >= 1.0:
		return
	var eased: float = 1.0 - pow(1.0 - t, 2.0)
	var radius: float = lerpf(start_radius, end_radius, eased)
	var ring_color := Color(color.r, color.g, color.b, (1.0 - t) * (1.0 - t) * alpha)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, ring_color, maxf(0.5, width * (1.0 - t)), true)
