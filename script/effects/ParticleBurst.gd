class_name ParticleBurst
extends Node2D

# The particle burst is the local "note hit" debris. Each lane gets a profile
# that matches its feedback identity: heavy for KICK, quick for HH, sharp for
# SNARE, medium for TOMS, small/upward for RIDE and the original large burst
# for CRASH.

const MAX_PARTICLES: int = 16
const DEFAULT_PROFILE: String = "crash"

const PROFILES: Dictionary = {
	"kick": {
		"count": 12,
		"size": [7.0, 15.0],
		"speed": [70.0, 200.0],
		"life": [0.18, 0.32],
		"gravity": 260.0,
		"white": 0.0,
		"angle_center": 0.0,
		"angle_spread": TAU,
		"duration": 0.34,
	},
	"hat": {
		"count": 12,
		"size": [2.0, 6.0],
		"speed": [240.0, 480.0],
		"life": [0.08, 0.16],
		"gravity": 60.0,
		"white": 0.35,
		"angle_center": 0.0,
		"angle_spread": TAU,
		"duration": 0.20,
	},
	"snare": {
		"count": 16,
		"size": [3.0, 7.0],
		"speed": [300.0, 560.0],
		"life": [0.08, 0.18],
		"gravity": 90.0,
		"white": 0.20,
		"angle_center": 0.0,
		"angle_spread": TAU,
		"duration": 0.22,
	},
	"tom": {
		"count": 14,
		"size": [4.0, 9.0],
		"speed": [140.0, 300.0],
		"life": [0.18, 0.30],
		"gravity": 180.0,
		"white": 0.10,
		"angle_center": 0.0,
		"angle_spread": TAU,
		"duration": 0.32,
	},
	"ride": {
		"count": 8,
		"size": [2.0, 5.0],
		"speed": [80.0, 180.0],
		"life": [0.14, 0.26],
		"gravity": 30.0,
		"white": 0.45,
		"angle_center": -PI * 0.5,
		"angle_spread": PI * 0.9,
		"duration": 0.28,
	},
	"crash": {
		"count": 16,
		"size": [4.0, 10.0],
		"speed": [60.0, 250.0],
		"life": [0.20, 0.40],
		"gravity": 0.0,
		"white": 0.0,
		"angle_center": 0.0,
		"angle_spread": TAU,
		"duration": 0.40,
	},
}

var _particles: Array[Dictionary] = []
var _duration: float = 0.4
var _timer: float = 0.0
var _gravity: float = 0.0
var _initialized: bool = false


static func profile_for_lane(lane_index: int) -> String:
	match lane_index:
		0:
			return "hat"
		1:
			return "crash"
		2:
			return "snare"
		3:
			return "kick"
		4, 5, 6:
			return "tom"
		7:
			return "ride"
		_:
			return ""


func warm_up() -> void:
	_init_particles()


func _init_particles() -> void:
	if _initialized:
		return
	_initialized = true
	for i in range(MAX_PARTICLES):
		var rect := ColorRect.new()
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)
		_particles.append({
			"rect": rect,
			"vel": Vector2.ZERO,
			"life": 0.0,
			"max_life": 1.0,
		})


func play(color: Color, profile_name: String = "") -> void:
	_init_particles()

	var profile: Dictionary = PROFILES.get(profile_name, PROFILES[DEFAULT_PROFILE])
	_duration = float(profile["duration"])
	_gravity = float(profile["gravity"])
	_timer = _duration

	var particle_color: Color = color.lerp(Color.WHITE, float(profile["white"]))
	var count: int = mini(int(profile["count"]), MAX_PARTICLES)
	var sizes: Array = profile["size"]
	var speeds: Array = profile["speed"]
	var lives: Array = profile["life"]
	var angle_center: float = float(profile["angle_center"])
	var angle_spread: float = float(profile["angle_spread"])

	for i in range(MAX_PARTICLES):
		var p = _particles[i]
		if i >= count:
			p.rect.visible = false
			p.life = 0.0
			continue

		var angle: float = randf_range(0.0, TAU)
		if angle_spread < TAU:
			angle = angle_center + randf_range(-angle_spread * 0.5, angle_spread * 0.5)
		var speed: float = randf_range(float(speeds[0]), float(speeds[1]))
		var life: float = randf_range(float(lives[0]), float(lives[1]))

		p.rect.position = Vector2.ZERO
		p.rect.size = Vector2(
			randf_range(float(sizes[0]), float(sizes[1])),
			randf_range(float(sizes[0]), float(sizes[1]))
		)
		p.rect.color = particle_color
		p.rect.color.a = 1.0
		p.rect.visible = true
		p.vel = Vector2(cos(angle), sin(angle)) * speed
		p.life = life
		p.max_life = life


func _process(delta: float) -> void:
	if _timer <= 0.0:
		return
	_timer -= delta
	for p in _particles:
		if p.life <= 0.0:
			continue
		p.vel.y += _gravity * delta
		p.rect.position += p.vel * delta
		p.life -= delta
		var alpha: float = sqrt(clampf(p.life / p.max_life, 0.0, 1.0))
		p.rect.color.a = alpha if p.life > 0.0 else 0.0
		p.rect.visible = p.life > 0.0
	if _timer <= 0.0:
		if get_parent():
			get_parent().remove_child(self)
