class_name CrashShockwave
extends CanvasLayer

# CRASH hits release a pressure wave: a soft ring expands from the crash lane
# and pushes the already rendered gameplay image sideways as it travels. It is
# a screen-space effect on purpose: notes, lanes, HUD and particles are never
# moved, only the pixels that were already drawn are displaced while the ring
# passes over them.
#
# The overlay lives in EffectManager, invisible and out of the process loop
# until a hit arrives. Up to MAX_WAVES rings can overlap, so a fast crash roll
# blends instead of cutting the previous wave.

const MAX_WAVES: int = 3
const DURATION: float = 0.42
const STRENGTH_PX: float = 9.0
const WAVE_WIDTH_PX: float = 68.0
const RING_ALPHA: float = 0.10
const MAX_RADIUS_SCALE: float = 1.06  # of the farthest visible corner

@onready var _copy: BackBufferCopy = $BackBufferCopy
@onready var _ripple: ColorRect = $Ripple
@onready var _material: ShaderMaterial = _ripple.material as ShaderMaterial

var _waves: Array[Dictionary] = []
var _max_radius: float = 1500.0
var _viewport_size: Vector2 = Vector2(1280.0, 720.0)


func _ready() -> void:
	_stop()


# global_position is the crash lane origin in screen coordinates. color is the
# lane tone, used only for the faint ring tint at the wavefront.
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
		# ring loses energy, instead of a constant linear sweep.
		var eased: float = 1.0 - pow(1.0 - t, 1.6)
		var radius: float = _max_radius * eased
		var amplitude: float = _amplitude_at(t)
		var color: Color = wave.color
		var ring_alpha: float = RING_ALPHA * _envelope(t)
		wave_data[i] = Vector4(wave.origin.x, wave.origin.y, radius, amplitude)
		ring_data[i] = Vector4(color.r, color.g, color.b, ring_alpha)

	_material.set_shader_parameter("waves", wave_data)
	_material.set_shader_parameter("wave_rings", ring_data)


# Radius that just reaches the last visible corner: the ring travels across
# the whole playfield without wasting most of its life outside the viewport.
func _farthest_corner_distance(position: Vector2) -> float:
	var max_distance: float = 0.0
	for corner in [Vector2.ZERO, Vector2(_viewport_size.x, 0.0), Vector2(0.0, _viewport_size.y), _viewport_size]:
		max_distance = maxf(max_distance, position.distance_to(corner))
	return max_distance


# Elastic envelope: quick ramp in, one rebound and a smooth fade to zero.
static func _envelope(t: float) -> float:
	if t <= 0.0 or t >= 1.0:
		return 0.0
	var rise: float = smoothstep(0.0, 0.10, t)
	var fade: float = 1.0 - smoothstep(0.15, 1.0, t)
	var swing: float = 0.82 + 0.18 * cos(t * TAU * 1.5)
	return rise * fade * swing


static func _amplitude_at(t: float) -> float:
	return STRENGTH_PX * _envelope(t)
