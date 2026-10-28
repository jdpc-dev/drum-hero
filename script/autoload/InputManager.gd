extends Node

enum KickState { IDLE, KICK_DOWN, COOLDOWN }

var touch_lane_map: Dictionary = {}
var haptic_kick_enabled: bool = false

var _kick_state: KickState = KickState.IDLE
var _kick_cooldown_timer: float = 0.0
var _last_kick_time: float = 0.0

var sensitivity: float = 1.0
var activation_threshold: float = 8.0
var release_threshold: float = 4.0
var cooldown_duration: float = 0.15
var min_interval: float = 0.08
var smoothing_strength: float = 0.15
var calibration_duration: float = 1.5

var _calibration_remaining: float = 0.0
var _neutral_orientation: Vector3 = Vector3.ZERO
var _filtered_accel: Vector3 = Vector3.ZERO
var _gravity_estimate: Vector3 = Vector3.DOWN

signal kick_detected()
signal lane_touched(lane_index: int, is_begin: bool)


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
    if not haptic_kick_enabled:
        return

    if _calibration_remaining > 0.0:
        _calibration_remaining -= delta
        var raw: Vector3 = Input.get_accelerometer()
        _gravity_estimate = _gravity_estimate.lerp(raw, 0.1)
        if _calibration_remaining <= 0.0:
            _neutral_orientation = _gravity_estimate
        return

    var raw_accel: Vector3 = Input.get_accelerometer()
    _filtered_accel = _filtered_accel.lerp(raw_accel, smoothing_strength)

    var linear_accel: Vector3 = _filtered_accel - _gravity_estimate
    var forward: float = linear_accel.dot(Vector3.BACK)

    match _kick_state:
        KickState.IDLE:
            if forward > activation_threshold * sensitivity:
                var now: float = Time.get_ticks_msec() / 1000.0
                if now - _last_kick_time >= min_interval:
                    _kick_state = KickState.KICK_DOWN
                    _last_kick_time = now
                    kick_detected.emit()

        KickState.KICK_DOWN:
            if forward < release_threshold * sensitivity:
                _kick_state = KickState.COOLDOWN
                _kick_cooldown_timer = cooldown_duration

        KickState.COOLDOWN:
            _kick_cooldown_timer -= delta
            if _kick_cooldown_timer <= 0.0:
                _kick_state = KickState.IDLE


func start_calibration() -> void:
    _calibration_remaining = calibration_duration
    _gravity_estimate = Vector3.DOWN
    _filtered_accel = Vector3.ZERO
    _kick_state = KickState.IDLE


func is_kick_ready() -> bool:
    return _kick_state == KickState.IDLE and _calibration_remaining <= 0.0


func reset() -> void:
    _kick_state = KickState.IDLE
    _kick_cooldown_timer = 0.0
    _filtered_accel = Vector3.ZERO


func handle_touch_event(index: int, position: Vector2, pressed: bool, lane_count: int) -> void:
    var vw: float = ProjectSettings.get_setting("display/window/size/viewport_width", 1920)
    var lane_width: float = vw / float(lane_count)
    var lane_index: int = int(position.x / lane_width)
    lane_index = clampi(lane_index, 0, lane_count - 1)
    if pressed:
        touch_lane_map[index] = lane_index
    else:
        touch_lane_map.erase(index)
    lane_touched.emit(lane_index, pressed)
