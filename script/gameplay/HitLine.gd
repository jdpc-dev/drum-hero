class_name HitLine
extends Node2D

var _hit_line_rects: Array[ColorRect] = []
var _rect_lane_indices: Array[int] = []
var _original_colors: Array[Color] = []
var _flash_timers: Array[float] = []
var _flash_duration: float = 0.1


func setup(highway: Node) -> void:
	position.y = highway.hit_line_top_y

	var lane_nodes: Array = highway.lane_nodes
	var count: int = lane_nodes.size()
	var lane_w: float = highway.screen_w / float(count)
	var hit_zone_h: float = highway.hit_line_bottom_y - highway.hit_line_top_y

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


func flash(lane_index: int) -> void:
	for i in range(_hit_line_rects.size()):
		if _rect_lane_indices[i] == lane_index:
			_flash_timers[i] = _flash_duration
			_hit_line_rects[i].color = Color.WHITE
			break


func _process(delta: float) -> void:
	for i in range(_flash_timers.size()):
		if _flash_timers[i] > 0.0:
			_flash_timers[i] -= delta
			if _flash_timers[i] <= 0.0:
				_flash_timers[i] = 0.0
				_hit_line_rects[i].color = _original_colors[i]
			else:
				var t: float = _flash_timers[i] / _flash_duration
				_hit_line_rects[i].color = _original_colors[i].lerp(Color.WHITE, t * t)
