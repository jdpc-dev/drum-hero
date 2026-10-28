extends Node

var _plugin = null
var _is_android: bool = false


func _ready() -> void:
	_is_android = OS.get_name() == "Android"
	if _is_android and Engine.has_singleton("GestureExclusion"):
		_plugin = Engine.get_singleton("GestureExclusion")


func set_lane_exclusion(pad_left: float, lane_w: float, lane_count: int, pad_right: float, pad_top: float, labels_y: float) -> void:
	if not _plugin:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var left_w: int = int(pad_left + lane_w)
	var right_x: int = int(pad_left + lane_w * (lane_count - 1))
	_plugin.setExclusionRects(left_w, int(pad_top), right_x, int(labels_y), int(vp.x), int(vp.y))


func clear_exclusion() -> void:
	if _plugin:
		_plugin.clearExclusionRects()
