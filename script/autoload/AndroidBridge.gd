extends Node

var _plugin = null
var _is_android: bool = false


func _ready() -> void:
	_is_android = OS.get_name() == "Android"
	if _is_android and Engine.has_singleton("GestureExclusion"):
		_plugin = Engine.get_singleton("GestureExclusion")


func set_lane_exclusion(pad_x: float, lane_w: float, lane_count: int, pad_y: float, labels_y: float) -> void:
	if not _plugin:
		return
	var left_w: int = mini(int(pad_x + lane_w), 200)
	var right_x: int = maxi(int(pad_x + lane_w * (lane_count - 1)), 0)
	_plugin.setExclusionRects(left_w, int(pad_y), right_x, int(labels_y))


func clear_exclusion() -> void:
	if _plugin:
		_plugin.clearExclusionRects()
