class_name CrashShockwave
extends CanvasLayer

# CRASH hits release a pressure wave: a large, soft bubble expands from the
# crash lane, dims the gameplay behind it as it sweeps the screen and carries a
# thin bright rim that pushes the already rendered image sideways. It is a
# screen-space effect on purpose: notes, lanes, HUD and particles are never
# moved, only the pixels that were already drawn are displaced while the ring
# passes over them.
#
# The overlay lives in EffectManager, invisible and out of the process loop
# until a hit arrives. Up to MAX_WAVES rings can overlap, so a fast crash roll
# blends instead of cutting the previous wave.

const MAX_WAVES: int = 3
const DURATION: float = 0.75
const STRENGTH_PX: float = 13.0
const WAVE_WIDTH_PX: float = 115.0
const RIM_CORE_PX: float = 5.0
const EDGE_SOFTNESS_PX: float = 28.0
const RIM_ALPHA: float = 0.32
const MAX_RADIUS_SCALE: float = 1.08  # of the farthest visible corner

@onready var _copy: BackBufferCopy = $BackBufferCopy
@onready var _ripple: ColorRect = $Ripple
@onready var _material: ShaderMaterial = _ripple.material as ShaderMaterial

var _waves: Array[Dictionary] = []
var _max_radius: float = 1500.0
var _viewport_size: Vector2 = Vector2(1280.0, 720.0)


func _ready() -> void:
	_stop()


# global_position is the crash lane origin in screen coordinates. color is the
# lane tone, used for the faint rim at the wavefront.
func trigger(global_position: Vector2, color: Color) -> void:
	_viewport_size = get_viewport().get_visible_rect().size
	if _viewport_size.x <= 0.0 or _viewport_size.y <= 0.0:
		return
	_max_radius = _farthest_corner_distance(global_position) * MAX_RADIUS_SCALE

	# Overlapping hits refresh the wave from their own origin: the oldest ring
	# is dropped only when the three slots are already in use.
	if _waves.size() >= MAX_WAVES:
		_waves.remove_at(0)
	_waves.append({
		"origin": global_position,
		"color": color,
		"elapsed": 0.0,
	})

	if not visible:
		visible = true
		_copy.visible = true
		_ripple.visible = true
		set_process(true)
	_update_uniforms()


func _process(delta: float) -> void:
	var i: int = _waves.size() - 1
	while i >= 0:
		_waves[i].elapsed += delta
		if _waves[i].elapsed >= DURATION:
			_waves.remove_at(i)
		i -= 1

	if _waves.is_empty():
		_stop()
		return
	_update_uniforms()


func _stop() -> void:
	_waves.clear()
	visible = false
	if _copy:
		_copy.visible = false
	if _ripple:
		_ripple.visible = false
	set_process(false)


func _update_uniforms() -> void:
	_material.set_shader_parameter("viewport_size", _viewport_size)
	_material.set_shader_parameter("wave_count", _waves.size())
	_material.set_shader_parameter("falloff_distance", _max_radius)
	_material.set_shader_parameter("wave_width", WAVE_WIDTH_PX)
	_material.set_shader_parameter("rim_core_width", RIM_CORE_PX)
	_material.set_shader_parameter("edge_softness", EDGE_SOFTNESS_PX)

	var wave_data: PackedVector4Array = PackedVector4Array()
	var ring_data: PackedVector4Array = PackedVector4Array()
	wave_data.resize(MAX_WAVES)
	ring_data.resize(MAX_WAVES)

	for i in range(MAX_WAVES):
		if i >= _waves.size():
			wave_data[i] = Vector4.ZERO
			ring_data[i] = Vector4.ZERO
			continue
		var wave: Dictionary = _waves[i]
		var t: float = clampf(wave.elapsed / DURATION, 0.0, 1.0)
		# Impulse-like expansion: a fast initial release that slows down as the
		# bubble loses energy, instead of a constant linear sweep.
		var eased: float = 1.0 - pow(1.0 - t, 1.7)
		var radius: float = _max_radius * eased
		var amplitude: float = _amplitude_at(t)
		var color: Color = wave.color
		# Keep the rim mostly neutral with a warm flash of the crash lane, so
		# it reads as a pressure edge instead of a solid orange line.
		var rim_color: Color = color.lerp(Color.WHITE, 0.35)
		var rim_alpha: float = RIM_ALPHA * _rim_envelope(t)
		wave_data[i] = Vector4(wave.origin.x, wave.origin.y, radius, amplitude)
		ring_data[i] = Vector4(rim_color.r, rim_color.g, rim_color.b, rim_alpha)

	_material.set_shader_parameter("waves", wave_data)
	_material.set_shader_parameter("wave_rings", ring_data)


# Radius that just reaches the last visible corner: the bubble covers the whole
# playfield without wasting most of its life outside the viewport.
func _farthest_corner_distance(position: Vector2) -> float:
	var max_distance: float = 0.0
	for corner in [Vector2.ZERO, Vector2(_viewport_size.x, 0.0), Vector2(0.0, _viewport_size.y), _viewport_size]:
		max_distance = maxf(max_distance, position.distance_to(corner))
	return max_distance


# Rim/bubble envelope: appears almost instantly and stays readable while the
# wave crosses the screen, then fades out over the last part of the expansion.
static func _rim_envelope(t: float) -> float:
	if t <= 0.0 or t >= 1.0:
		return 0.0
	var rise: float = smoothstep(0.0, 0.05, t)
	var fade: float = 1.0 - smoothstep(0.45, 0.92, t)
	return rise * fade


# Elastic displacement envelope: quick ramp in, one rebound and a smooth fade.
static func _amplitude_at(t: float) -> float:
	if t <= 0.0 or t >= 1.0:
		return 0.0
	var rise: float = smoothstep(0.0, 0.06, t)
	var fade: float = 1.0 - smoothstep(0.30, 0.95, t)
	var swing: float = 0.85 + 0.15 * cos(t * TAU * 1.5)
	return STRENGTH_PX * rise * fade * swing
