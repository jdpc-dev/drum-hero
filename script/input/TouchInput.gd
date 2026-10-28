class_name TouchInput
extends Node

var _hit_detection
var _highway_ref
var _lane_count: int = 8

var _touch_lane_map: Dictionary = {}
var _lane_highlight_timers: Dictionary = {}
var _highlight_duration: float = 0.12


func setup(highway, hit_detection) -> void:
	_highway_ref = highway
	_hit_detection = hit_detection
	_lane_count = highway.lane_nodes.size()
	if _lane_count <= 0:
		_lane_count = 8


func _process(delta: float) -> void:
	var changed: bool = false
	for lane in _lane_highlight_timers.keys():
		_lane_highlight_timers[lane] -= delta
		if _lane_highlight_timers[lane] <= 0.0:
			_lane_highlight_timers.erase(lane)
			changed = true
	if changed:
		_update_touch_zones()


var _is_touch_device: bool = DisplayServer.is_touchscreen_available()

func _input(event: InputEvent) -> void:
	if GameManager.state != GameManager.GameState.PLAYING:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.keycode
		if key >= KEY_1 and key <= KEY_8:
			var lane_index: int = key - KEY_1
			if lane_index < _lane_count:
				var did_hit: bool = _hit_detection.try_hit_lane(lane_index, Vector2.ZERO)
				if not did_hit:
					DrumSfxManager.play_for_lane(lane_index)
				_highlight_lane(lane_index)
			return

	if event is InputEventScreenTouch:
		var pos: Vector2 = _get_highway_local_pos(event.position)
		if event.pressed:
			var lane_index: int = _touch_to_lane(pos)
			if lane_index >= 0:
				_touch_lane_map[event.index] = lane_index
				var did_hit: bool = _hit_detection.try_hit_lane(lane_index, pos)
				if not did_hit:
					DrumSfxManager.play_for_lane(lane_index)
				_highlight_lane(lane_index)
				InputManager.handle_touch_event(event.index, pos, true, lane_index, _lane_count, _highway_ref.screen_w if _highway_ref else -1.0)
		else:
			var prev_lane: int = _touch_lane_map.get(event.index, -1)
			_touch_lane_map.erase(event.index)
			if prev_lane >= 0:
				InputManager.handle_touch_event(event.index, pos, false, prev_lane, _lane_count, _highway_ref.screen_w if _highway_ref else -1.0)
		return

	if _is_touch_device:
		return

	elif event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		var pos: Vector2 = _get_highway_local_pos(event.position)
		if event.pressed:
			var lane_index: int = _touch_to_lane(pos)
			_touch_lane_map[0] = lane_index
			var did_hit: bool = _hit_detection.try_hit_lane(lane_index, pos)
			if not did_hit:
				DrumSfxManager.play_for_lane(lane_index)
			_highlight_lane(lane_index)
		else:
			_touch_lane_map.erase(0)


func _highlight_lane(lane_index: int) -> void:
	_lane_highlight_timers[lane_index] = _highlight_duration
	_update_touch_zones()


func _update_touch_zones() -> void:
	if not _highway_ref:
		return
	for child in _highway_ref.get_children():
		if child is ColorRect and child.name.begins_with("TouchZone_"):
			var idx_str: String = child.name.trim_prefix("TouchZone_")
			var lane_idx: int = int(idx_str)
			child.color.a = 0.5 if _lane_highlight_timers.has(lane_idx) else 0.12


func _get_highway_local_pos(screen_pos: Vector2) -> Vector2:
	if not _highway_ref:
		return screen_pos
	return _highway_ref.to_local(screen_pos)


func _touch_to_lane(position: Vector2) -> int:
	var lane_w: float = _get_lane_width()
	var visual_idx: int = clampi(int(position.x / lane_w), 0, _lane_count - 1)
	if _highway_ref and visual_idx < _highway_ref.lane_nodes.size():
		return _highway_ref.lane_nodes[visual_idx].lane_index
	return visual_idx


func _get_lane_width() -> float:
	if _highway_ref:
		return _highway_ref.screen_w / float(_lane_count)
	var vw: float = ProjectSettings.get_setting("display/window/size/viewport_width", 1280)
	return vw / float(_lane_count)
