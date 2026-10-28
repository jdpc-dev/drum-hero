class_name HitLine
extends Node2D

var _hit_line_rects: Array[ColorRect] = []
var _rect_lane_indices: Array[int] = []
var _original_colors: Array[Color] = []
var _flash_timers: Array[float] = []
var _flash_duration: float = 0.1

var _highway: Node
var _hit_zone_center_y: float = 0.0
var _pixels_per_second: float = 0.0
var _judgment_area_rects: Array[ColorRect] = []


func setup(highway: Node) -> void:
	_highway = highway
	position.y = highway.hit_line_top_y

	var lane_nodes: Array = highway.lane_nodes
	var count: int = lane_nodes.size()
	var lane_w: float = highway.screen_w / float(count)
	var hit_zone_h: float = highway.hit_line_bottom_y - highway.hit_line_top_y
	_hit_zone_center_y = hit_zone_h * 0.5

	var scroll_distance: float = highway.highway_bottom_y - highway.highway_top_y
	_pixels_per_second = scroll_distance / 2.0

	var bg_line := ColorRect.new()
	bg_line.color = Color(0.5, 0.5, 0.5, 0.25)
	bg_line.size = Vector2(highway.screen_w, 2.0)
	bg_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_line)

	var lane_colors: Array[Color] = highway._get_lane_colors()

	for i in range(count):
		var lane_idx: int = lane_nodes[i].lane_index
		var rect := ColorRect.new()
		rect.color = lane_colors[lane_idx]
		rect.color.a = 0.35
		rect.size = Vector2(lane_w * 0.9, hit_zone_h * 0.6)
		rect.position = Vector2(lane_w * i + lane_w * 0.05, hit_zone_h * 0.2)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)
		_hit_line_rects.append(rect)
		_rect_lane_indices.append(lane_idx)
		_original_colors.append(rect.color)
		_flash_timers.append(0.0)

	_build_judgment_areas()


func _build_judgment_areas() -> void:
	for r in _judgment_area_rects:
		r.queue_free()
	_judgment_area_rects.clear()

	var good_ms: float = SettingsManager.judgement_good_ms
	var excellent_ms: float = SettingsManager.judgement_excellent_ms
	var perfect_ms: float = SettingsManager.judgement_perfect_ms
	var miss_ms: float = SettingsManager.judgement_miss_ms
	var arcade_scale: float = 2.5

	var bands: Array[Dictionary] = [
		{ "from": -miss_ms, "to": -good_ms, "color": Color(1, 0.5, 0, 0.20) },
		{ "from": -good_ms, "to": -excellent_ms, "color": Color(0.2, 0.6, 1, 0.22) },
		{ "from": -excellent_ms, "to": -perfect_ms, "color": Color(0.2, 1, 0.2, 0.24) },
		{ "from": -perfect_ms, "to": perfect_ms, "color": Color(1, 0.9, 0.2, 0.28) },
		{ "from": perfect_ms, "to": miss_ms, "color": Color(1, 0.5, 0, 0.20) },
	]

	for band in bands:
		var y_from: float = _hit_zone_center_y + (band.from / 1000.0) * _pixels_per_second * arcade_scale
		var y_to: float = _hit_zone_center_y + (band.to / 1000.0) * _pixels_per_second * arcade_scale
		var top: float = minf(y_from, y_to)
		var height: float = absf(y_to - y_from)
		var rect := ColorRect.new()
		rect.color = band.color
		rect.size = Vector2(_highway.screen_w, height)
		rect.position = Vector2(0, top)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.z_index = -1
		add_child(rect)
		_judgment_area_rects.append(rect)

	var miss_top: float = _hit_zone_center_y + (miss_ms / 1000.0) * _pixels_per_second * arcade_scale
	var miss_rect := ColorRect.new()
	miss_rect.color = Color(1, 0.2, 0.2, 0.18)
	miss_rect.size = Vector2(_highway.screen_w, _highway.screen_h - miss_top)
	miss_rect.position = Vector2(0, miss_top)
	miss_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	miss_rect.z_index = -1
	add_child(miss_rect)
	_judgment_area_rects.append(miss_rect)


func flash(lane_index: int) -> void:
	for i in range(_hit_line_rects.size()):
		if _rect_lane_indices[i] == lane_index:
			_flash_timers[i] = _flash_duration
			_hit_line_rects[i].color = Color.WHITE
			break


func _process(delta: float) -> void:
	var visible: bool = SettingsManager.show_judgment_areas
	for r in _judgment_area_rects:
		r.visible = visible

	for i in range(_flash_timers.size()):
		if _flash_timers[i] > 0.0:
			_flash_timers[i] -= delta
			if _flash_timers[i] <= 0.0:
				_flash_timers[i] = 0.0
				_hit_line_rects[i].color = _original_colors[i]
			else:
				var t: float = _flash_timers[i] / _flash_duration
				_hit_line_rects[i].color = _original_colors[i].lerp(Color.WHITE, t * t)
