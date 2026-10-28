class_name Note
extends Node2D

var note_data: ChartData.NoteEvent
var lane_ref: Lane
var _hit: bool = false
var _missed: bool = false

var _rect: ColorRect


var _is_kick_full_width: bool = false


func _ready() -> void:
	var lane: int = note_data.lane
	_rect = ColorRect.new()
	_rect.color = _get_color_for_lane(lane)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hw: Node = lane_ref.highway_ref if lane_ref else null
	_is_kick_full_width = (lane == 3 and hw != null and GameManager.mode == GameManager.GameMode.HAPTIC)

	if _is_kick_full_width:
		_rect.size = Vector2(hw.screen_w, (hw.screen_w / float(hw.lane_nodes.size())) * 0.25)
	else:
		var total_lanes: int = hw.lane_nodes.size() if hw else 8
		var lane_w: float = (hw.screen_w if hw else 1280.0) / float(total_lanes)
		_rect.size = Vector2(lane_w * 0.95, lane_w * 0.25)
		z_index = 1

	add_child(_rect)


func update_position(current_time: float) -> void:
	if not lane_ref:
		return
	var highway: Node = lane_ref.highway_ref
	var pos: Vector2 = highway.call("note_position",
		note_data.tick, lane_ref.lane_index, note_data.time, current_time
	)
	if _is_kick_full_width:
		_rect.position = Vector2(highway.screen_w * 0.5 - _rect.size.x * 0.5, pos.y - _rect.size.y * 0.5)
	else:
		_rect.position = Vector2(pos.x - _rect.size.x * 0.5, pos.y - _rect.size.y * 0.5)


func _on_hit() -> void:
	_hit = true
	_rect.color = Color.WHITE


func _on_miss() -> void:
	_missed = true
	_rect.color = Color(0.5, 0.5, 0.5, 0.3)


static func _get_color_for_lane(lane: int) -> Color:
	match lane:
		0: return Color(0.9, 0.8, 0.2)
		1: return Color(1.0, 0.6, 0.0)
		2: return Color(0.8, 0.2, 0.2)
		3: return Color(0.6, 0.4, 0.8)
		4: return Color(0.2, 0.7, 0.9)
		5: return Color(0.2, 0.9, 0.5)
		6: return Color(0.9, 0.3, 0.6)
		7: return Color(0.5, 0.8, 0.3)
		_: return Color.WHITE
