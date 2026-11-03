class_name DrumPulse
extends CanvasLayer

# Subtle per-lane screen feedback, deliberately quieter than the CRASH
# shockwave:
#   KICK  -> the top edge/corners of the screen lift briefly
#   HH    -> a very small whole-screen shake
#   SNARE -> a short staccato jolt, like a burst of hits
#
# The overlay is a screen-space copy so it moves the whole rendered frame
# (highway, notes and HUD) without touching any gameplay node.

const MAX_PULSES: int = 8
const KICK_DURATION: float = 0.22
const HAT_DURATION: float = 0.16
const SNARE_DURATION: float = 0.14

const KICK_LIFT_PX: float = 8.5
const KICK_GLOW: float = 0.65
const HAT_SHAKE_PX: float = 2.0
const SNARE_JOLT_PX: float = 3.0

@onready var _copy: BackBufferCopy = $BackBufferCopy
@onready var _pulse: ColorRect = $Pulse
@onready var _material: ShaderMaterial = _pulse.material as ShaderMaterial

var _pulses: Array[Dictionary] = []
var _viewport_size: Vector2 = Vector2(1280.0, 720.0)
var _warming_up: bool = false


func _ready() -> void:
	_stop()


# Draw one neutral frame at startup so the compiler/back-buffer path is ready
# before the first KICK/HH/SNARE hit. The rect is nearly transparent.
func warm_up() -> void:
	if visible or _warming_up:
		return
	_warming_up = true
	_viewport_size = get_viewport().get_visible_rect().size
	_material.set_shader_parameter("viewport_size", _viewport_size)
	_material.set_shader_parameter("screen_offset", Vector2.ZERO)
	_material.set_shader_parameter("top_lift", 0.0)
	_material.set_shader_parameter("top_glow", 0.0)
	visible = true
	_copy.visible = true
	_pulse.visible = true
	_pulse.modulate.a = 0.01
	await get_tree().process_frame
	await get_tree().process_frame
	_pulse.modulate.a = 1.0
	if _warming_up:
		_warming_up = false
		_stop()


func trigger(lane_index: int) -> void:
	var type: String = ""
	match lane_index:
		0:
			type = "hat"
		2:
			type = "snare"
		3:
			type = "kick"
		_:
			return

	if _pulses.size() >= MAX_PULSES:
		_pulses.pop_front()
	_pulses.append({"type": type, "age": 0.0})

	if _warming_up:
		_warming_up = false
	if not visible or not is_processing():
		visible = true
		_copy.visible = true
		_pulse.visible = true
		set_process(true)
	_update_uniforms()


func _process(delta: float) -> void:
	var i: int = _pulses.size() - 1
	while i >= 0:
		_pulses[i].age += delta
		if _pulses[i].age >= _duration(_pulses[i].type):
			_pulses.remove_at(i)
		i -= 1

	if _pulses.is_empty():
		_stop()
		return
	_update_uniforms()


func _stop() -> void:
	_pulses.clear()
	visible = false
	if _copy:
		_copy.visible = false
	if _pulse:
		_pulse.visible = false
	set_process(false)


static func _duration(type: String) -> float:
	match type:
		"kick":
			return KICK_DURATION
		"hat":
			return HAT_DURATION
		_:
			return SNARE_DURATION


func _update_uniforms() -> void:
	_viewport_size = get_viewport().get_visible_rect().size

	var offset: Vector2 = Vector2.ZERO
	var top_lift: float = 0.0
	var top_glow: float = 0.0

	for pulse in _pulses:
		var age: float = pulse.age
		match pulse.type:
			"kick":
				var env: float = exp(-age * 16.0) * clampf(age / 0.008, 0.0, 1.0)
				top_lift += KICK_LIFT_PX * env
				top_glow += KICK_GLOW * env
			"hat":
				var env: float = exp(-age * 22.0)
				offset += Vector2(
					sin(age * TAU * 46.0),
					cos(age * TAU * 38.0)
				) * HAT_SHAKE_PX * env
			"snare":
				# Short pulse train: alternating micro-jolts with a fast decay.
				var interval: float = 0.028
				var step: int = int(age / interval)
				var local: float = fmod(age, interval) / interval
				var impulse: float = pow(1.0 - local, 2.2) * pow(0.7, step)
				var direction: float = 1.0 if step % 2 == 0 else -1.0
				offset += Vector2(SNARE_JOLT_PX, SNARE_JOLT_PX * 0.45) * impulse * direction

	offset = offset.limit_length(4.0)
	_material.set_shader_parameter("viewport_size", _viewport_size)
	_material.set_shader_parameter("screen_offset", offset)
	_material.set_shader_parameter("top_lift", minf(top_lift, 9.0))
	_material.set_shader_parameter("top_glow", minf(top_glow, 0.8))
