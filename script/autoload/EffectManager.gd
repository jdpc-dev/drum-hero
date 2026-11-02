extends Node

var _particle_pool: Array[Node] = []
var _shockwave_pool: Array[Node] = []
var _crash_impact_pool: Array[Node] = []
var _lane_pulse_pool: Array[Node] = []
var _judgement_pool: Array[Node] = []

const MAX_POOL_SIZE: int = 16
const CRASH_SHOCKWAVE_SCENE := preload("res://scene/UI/Effects/CrashShockwave.tscn")
const CRASH_IMPACT_SCENE := preload("res://scene/UI/Effects/CrashImpact.tscn")
const DRUM_PULSE_SCENE := preload("res://scene/UI/Effects/DrumPulse.tscn")
const LANE_PULSE_SCENE := preload("res://scene/UI/Effects/LanePulse.tscn")

var _crash_shockwave: CrashShockwave
var _drum_pulse: DrumPulse

var _hit_sfx: AudioStreamPlayer
var _miss_sfx: AudioStreamPlayer


func _ready() -> void:
	# One persistent overlay: CRASH hits overlap instead of stacking copies of
	# a full-screen shader. It stays hidden and outside the process loop while
	# there is no wave travelling.
	_crash_shockwave = CRASH_SHOCKWAVE_SCENE.instantiate() as CrashShockwave
	add_child(_crash_shockwave)

	# Subtle screen feedback for KICK, HH and SNARE. It lives one layer below
	# the CRASH overlay so the crash always remains the dominant effect.
	_drum_pulse = DRUM_PULSE_SCENE.instantiate() as DrumPulse
	add_child(_drum_pulse)

	_hit_sfx = AudioStreamPlayer.new()
	_hit_sfx.stream = _generate_beep(880.0, 0.08)
	_hit_sfx.name = "HitSFX"
	_hit_sfx.volume_db = -6.0
	add_child(_hit_sfx)

	_miss_sfx = AudioStreamPlayer.new()
	_miss_sfx.stream = _generate_beep(220.0, 0.15)
	_miss_sfx.name = "MissSFX"
	_miss_sfx.volume_db = -9.0
	add_child(_miss_sfx)


func play_hit_sfx() -> void:
	if _hit_sfx:
		_hit_sfx.stop()
		_hit_sfx.play()


func play_miss_sfx() -> void:
	if _miss_sfx:
		_miss_sfx.stop()
		_miss_sfx.play()


static func _generate_beep(freq: float, duration: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var num_samples: int = int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(num_samples * 2)

	for i in range(num_samples):
		var t: float = float(i) / float(sample_rate)
		var envelope: float = 1.0 - (float(i) / float(num_samples))
		var sample: float = sin(2.0 * PI * freq * t) * envelope * 0.5
		var s16: int = int(clamp(sample * 32767.0, -32768.0, 32767.0))
		data.encode_s16(i * 2, s16)

	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	return wav


func trigger_particle_burst(position: Vector2, color: Color, parent: Node, lane_index: int = -1) -> void:
	var burst: Node = _borrow(_particle_pool, preload("res://scene/UI/Effects/ParticleBurst.tscn"))
	if burst:
		parent.add_child(burst)
		burst.global_position = position
		var profile: String = ParticleBurst.profile_for_lane(lane_index) if lane_index >= 0 else ""
		burst.call("play", color, profile)


func trigger_shockwave(position: Vector2, parent: Node, color: Color = Color(1.0, 0.3, 0.1, 0.6), radius: float = 200.0) -> void:
	var shock: Node = _borrow(_shockwave_pool, preload("res://scene/UI/Effects/Shockwave.tscn"))
	if shock:
		parent.add_child(shock)
		shock.global_position = position
		shock.call("play", radius, color)


func trigger_crash_impact(position: Vector2, parent: Node, color: Color) -> void:
	var impact: Node = _borrow(_crash_impact_pool, CRASH_IMPACT_SCENE)
	if impact:
		parent.add_child(impact)
		impact.global_position = position
		impact.call("play", color)


# Exclusive to the CRASH lane: a full-screen lens bubble magnifies and warps
# the rendered gameplay as the pressure wave expands from the hit position.
func trigger_crash_shockwave(position: Vector2, color: Color) -> void:
	if _crash_shockwave:
		_crash_shockwave.trigger(position, color)


# Subtle screen-space feedback: KICK lifts the top edge, HH shakes the frame,
# SNARE adds a short staccato jolt.
func trigger_drum_pulse(lane_index: int) -> void:
	if _drum_pulse:
		_drum_pulse.trigger(lane_index)


# Small local feedback for TOMS (double heartbeat ring) and RIDE (bell ping).
func trigger_lane_pulse(mode: String, position: Vector2, parent: Node, color: Color) -> void:
	var pulse: Node = _borrow(_lane_pulse_pool, LANE_PULSE_SCENE)
	if pulse:
		parent.add_child(pulse)
		pulse.global_position = position
		pulse.call("play", mode, color)


func show_judgement(accuracy: int, position: Vector2, parent: Node) -> void:
	var popup: Node = _borrow(_judgement_pool, preload("res://scene/UI/Effects/JudgementPopup.tscn"))
	if popup:
		parent.add_child(popup)
		popup.global_position = position
		popup.call("show_judgement", accuracy)


func _borrow(pool: Array, scene: PackedScene) -> Node:
	var i := 0
	while i < pool.size():
		if not is_instance_valid(pool[i]):
			pool.remove_at(i)
		else:
			i += 1

	for instance in pool:
		if not instance.is_inside_tree():
			return instance

	if pool.size() < MAX_POOL_SIZE:
		var instance := scene.instantiate()
		pool.append(instance)
		return instance

	return null
