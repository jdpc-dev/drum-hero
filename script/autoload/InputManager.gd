extends Node

enum KickState { IDLE, KICK_DOWN, COOLDOWN }

var touch_lane_map: Dictionary = {}
var haptic_kick_enabled: bool = false

var _kick_state: KickState = KickState.IDLE
var _kick_cooldown_timer: float = 0.0
var _last_kick_time: float = 0.0
var _lift_detected: bool = false

var kick_down_timeout: float = 0.3
var _kick_down_timer: float = 0.0

var _calibration_remaining: float = 0.0
var _toward_axis: Vector3 = Vector3.BACK
var _filtered_accel: Vector3 = Vector3.ZERO
var _gravity_estimate: Vector3 = Vector3.DOWN
var _has_gravity_sensor: bool = false

signal kick_detected()
signal calibration_completed()
signal lane_touched(lane_index: int, is_begin: bool)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.game_state_changed.connect(_on_game_state_changed)


func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	if new_state == GameManager.GameState.PAUSED:
		reset()


var _is_desktop: bool = false


func _process(delta: float) -> void:
	if not haptic_kick_enabled:
		return
	if GameManager.state == GameManager.GameState.PAUSED:
		return

	var raw_accel: Vector3 = Input.get_accelerometer()

	# If accelerometer returns zero, try gravity sensor as fallback
	if raw_accel.length_squared() < 0.001:
		raw_accel = Input.get_gravity()

	# If still no sensor data, use desktop fallback (Space key / keyboard)
	if raw_accel.length_squared() < 0.001:
		_is_desktop = true
		_process_desktop_kick(delta)
		return
	_is_desktop = false

	var grav: Vector3 = Input.get_gravity()
	if grav.length_squared() > 0.001:
		_gravity_estimate = grav
		_has_gravity_sensor = true

	if _calibration_remaining > 0.0:
		_calibration_remaining = maxf(0.0, _calibration_remaining - delta)
		if not _has_gravity_sensor:
			_gravity_estimate = _gravity_estimate.lerp(raw_accel, 0.1)
		if _calibration_remaining <= 0.001:
			_calibration_remaining = 0.0
			_toward_axis = Vector3.BACK
			_lift_detected = false
			calibration_completed.emit()

	var lerp_factor: float = 1.0 - pow(1.0 - SettingsManager.haptic_smoothing_strength, delta * 60.0)
	_filtered_accel = _filtered_accel.lerp(raw_accel, lerp_factor)

	var linear_accel: Vector3 = _filtered_accel - _gravity_estimate
	var toward_accel: float = linear_accel.dot(_toward_axis)

	var sens: float = clamp(SettingsManager.haptic_sensitivity, 0.05, 10.0)
	var eff_activation: float = SettingsManager.haptic_activation_threshold / sens
	var eff_release: float = SettingsManager.haptic_release_threshold / sens

	match _kick_state:
		KickState.IDLE:
			if not _lift_detected and toward_accel > eff_activation:
				_lift_detected = true
			elif _lift_detected and toward_accel <= 0.0:
				var now: float = Time.get_ticks_msec() / 1000.0
				if now - _last_kick_time >= SettingsManager.haptic_min_interval:
					_lift_detected = false
					_kick_state = KickState.KICK_DOWN
					_kick_down_timer = 0.0
					_last_kick_time = now
					kick_detected.emit()
			elif _lift_detected and toward_accel < eff_release:
				_lift_detected = false

		KickState.KICK_DOWN:
			_kick_down_timer += delta
			if _kick_down_timer >= kick_down_timeout:
				_lift_detected = false
				_kick_state = KickState.COOLDOWN
				_kick_cooldown_timer = SettingsManager.haptic_cooldown_duration
			elif toward_accel < eff_release:
				_lift_detected = false
				_kick_state = KickState.COOLDOWN
				_kick_cooldown_timer = SettingsManager.haptic_cooldown_duration

		KickState.COOLDOWN:
			_kick_cooldown_timer = maxf(0.0, _kick_cooldown_timer - delta)
			if _kick_cooldown_timer <= 0.001:
				_kick_cooldown_timer = 0.0
				_kick_state = KickState.IDLE


func _process_desktop_kick(delta: float) -> void:
	if _calibration_remaining > 0.0:
		_calibration_remaining = maxf(0.0, _calibration_remaining - delta)
		if _calibration_remaining <= 0.001:
			_calibration_remaining = 0.0
			calibration_completed.emit()

	match _kick_state:
		KickState.IDLE:
			if Input.is_key_pressed(KEY_SPACE):
				var now: float = Time.get_ticks_msec() / 1000.0
				if now - _last_kick_time >= SettingsManager.haptic_min_interval:
					_kick_state = KickState.KICK_DOWN
					_kick_down_timer = 0.0
					_last_kick_time = now
					kick_detected.emit()

		KickState.KICK_DOWN:
			_kick_down_timer += delta
			if _kick_down_timer >= kick_down_timeout or not Input.is_key_pressed(KEY_SPACE):
				_kick_state = KickState.COOLDOWN
				_kick_cooldown_timer = SettingsManager.haptic_cooldown_duration

		KickState.COOLDOWN:
			_kick_cooldown_timer = maxf(0.0, _kick_cooldown_timer - delta)
			if _kick_cooldown_timer <= 0.001:
				_kick_cooldown_timer = 0.0
				_kick_state = KickState.IDLE


func start_calibration() -> void:
	var grav: Vector3 = Input.get_gravity()
	if grav.length_squared() > 0.001:
		_gravity_estimate = grav
		_has_gravity_sensor = true
		_calibration_remaining = 0.5
	else:
		_has_gravity_sensor = false
		_calibration_remaining = SettingsManager.haptic_calibration_duration
		_gravity_estimate = Vector3.DOWN
	_filtered_accel = Vector3.ZERO
	_kick_state = KickState.IDLE
	_lift_detected = false


func is_kick_ready() -> bool:
	return _kick_state == KickState.IDLE and _calibration_remaining <= 0.001


func reset() -> void:
	_kick_state = KickState.IDLE
	_lift_detected = false
	_kick_cooldown_timer = 0.0
	_kick_down_timer = 0.0
	_filtered_accel = Vector3.ZERO


func get_haptic_debug_string() -> String:
	var raw: Vector3 = Input.get_accelerometer()
	var grav: Vector3 = Input.get_gravity()
	var linear: Vector3 = _filtered_accel - _gravity_estimate
	var toward: float = linear.dot(_toward_axis)
	var sens: float = clamp(SettingsManager.haptic_sensitivity, 0.05, 10.0)
	var eff_act: float = SettingsManager.haptic_activation_threshold / sens
	var eff_rel: float = SettingsManager.haptic_release_threshold / sens
	var state_names := ["IDLE", "KICK_DOWN", "COOLDOWN"]
	var src: String = "DESKTOP" if _is_desktop else ("GRAVITY" if raw.length_squared() < 0.001 else "ACCEL")
	return (
        "=== HAPTIC DEBUG ===\n"
		+ "State: %s  Calib: %.1fs  Src: %s  Lift:%d\n" % [state_names[_kick_state], _calibration_remaining, src, int(_lift_detected)]
		+ "Raw: (%.1f, %.1f, %.1f)\n" % [raw.x, raw.y, raw.z]
		+ "Grav: (%.1f, %.1f, %.1f)\n" % [grav.x, grav.y, grav.z]
		+ "Axis: (%.2f, %.2f, %.2f)\n" % [_toward_axis.x, _toward_axis.y, _toward_axis.z]
		+ "Linear: (%.2f, %.2f, %.2f)\n" % [linear.x, linear.y, linear.z]
		+ "Toward: %.2f  EffAct: %.2f  EffRel: %.2f  Sens: %.1f" % [toward, eff_act, eff_rel, sens]
	)


func handle_touch_event(index: int, position: Vector2, pressed: bool, lane_index: int, lane_count: int = 8, screen_width: float = -1.0) -> void:
	if pressed:
		touch_lane_map[index] = lane_index
	else:
		touch_lane_map.erase(index)
	lane_touched.emit(lane_index, pressed)
