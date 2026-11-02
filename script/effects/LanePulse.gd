class_name LanePulse
extends Node2D

# Small local feedback for lanes that should not move the whole screen:
#   TOM   -> two quick soft rings, a "lub-dub" heartbeat
#   RIDE  -> a tiny bell ring with a few short sparkles
#
# Drawn in world space with additive light bands, so it stays much quieter than
# the CRASH nova/impact and can be captured by the screen-space effects.

const TOM_DURATION: float = 0.44
const RIDE_DURATION: float = 0.30
const RIDE_SPARK_COUNT: int = 6

var _mode: String = "tom"
var _elapsed: float = 0.0
var _color: Color = Color.WHITE
var _sparks: Array[Dictionary] = []


func _ready() -> void:
	z_index = 2
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	self.material = material
	set_process(false)


func play(mode: String, color: Color) -> void:
	_mode = mode
	_color = color
	_elapsed = 0.0
	_sparks.clear()

	if mode == "ride":
		for i in RIDE_SPARK_COUNT:
			var angle: float = randf_range(0.0, TAU)
			var pick: float = randf()
			_sparks.append({
				"direction": Vector2(cos(angle), sin(angle)),
				"speed": randf_range(80.0, 190.0),
				"age": 0.0,
				"life": randf_range(0.1, 0.2),
				"length": randf_range(5.0, 12.0),
				"width": randf_range(1.0, 1.8),
				"color": Color(1.0, 0.95, 0.8) if pick < 0.7 else Color(1.0, 1.0, 1.0),
			})

	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	for spark in _sparks:
		spark.age += delta
	queue_redraw()

	if _elapsed >= _duration():
		set_process(false)
		if get_parent():
			get_parent().remove_child(self)


func _duration() -> float:
	return RIDE_DURATION if _mode == "ride" else TOM_DURATION


func _draw() -> void:
	if _mode == "ride":
		var bell_tint: Color = Color(1.0, 0.94, 0.72).lerp(_color, 0.15)
		_draw_soft_ring(0.0, 0.20, 8.0, 50.0, 0.18, 0.38, bell_tint)
		for spark in _sparks:
			var age: float = spark.age
			var life: float = spark.life
			if age >= life:
				continue
			var k: float = age / life
			var tip: Vector2 = spark.direction * spark.speed * age
			var tail: Vector2 = tip - spark.direction * spark.length * (1.0 - k)
			var color: Color = spark.color
			color.a = (1.0 - k) * (1.0 - k)
			draw_line(tip, tail, color, maxf(0.5, spark.width * (1.0 - 0.5 * k)), true)
	else:
		var tom_tint: Color = _color.lerp(Color.WHITE, 0.35)
		# First beat: bigger and brighter. Second beat: smaller and softer.
		_draw_soft_ring(0.0, 0.28, 18.0, 95.0, 0.22, 0.30, tom_tint)
		_draw_soft_ring(0.12, 0.26, 14.0, 72.0, 0.22, 0.20, tom_tint)


func _draw_soft_ring(delay: float, duration: float, start_radius: float, end_radius: float, width_ratio: float, alpha: float, color: Color) -> void:
	var t: float = (_elapsed - delay) / duration
	if t < 0.0 or t >= 1.0:
		return
	var eased: float = 1.0 - pow(1.0 - t, 2.0)
	var radius: float = lerpf(start_radius, end_radius, eased)
	var fade: float = (1.0 - t) * (1.0 - t)
	var band: float = maxf(4.0, radius * width_ratio)
	for layer in range(3):
		var spread: float = 1.0 + 0.6 * float(layer)
		var layer_alpha: float = fade * alpha * (0.36 - 0.08 * float(layer))
		var layer_color := Color(color.r, color.g, color.b, layer_alpha)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, layer_color, band * spread, true)
