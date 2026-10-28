extends Node

var _plugin = null
var _all_files_access = null
var _is_android: bool = false


func _ready() -> void:
	_is_android = OS.get_name() == "Android"
	if not _is_android:
		return
	if Engine.has_singleton("GestureExclusion"):
		_plugin = Engine.get_singleton("GestureExclusion")
	if Engine.has_singleton("AllFilesAccess"):
		_all_files_access = Engine.get_singleton("AllFilesAccess")


func set_lane_exclusion(pad_left: float, pad_w: float, lane_count: int, pad_right: float, pad_top: float, labels_y: float) -> void:
	if not _plugin:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var left_w: int = int(pad_left + pad_w)
	var right_x: int = int(pad_left + pad_w * (lane_count - 1))
	_plugin.setExclusionRects(left_w, int(pad_top), right_x, int(labels_y), int(vp.x), int(vp.y))


func clear_exclusion() -> void:
	if _plugin:
		_plugin.clearExclusionRects()


func has_all_files_access() -> bool:
	if not _is_android:
		return true
	if not _all_files_access:
		return false
	return _all_files_access.hasAllFilesAccess()


func request_all_files_access() -> bool:
	if not _is_android:
		return true
	if not _all_files_access:
		return false
	return _all_files_access.requestAllFilesAccess()


func open_all_files_settings() -> bool:
	if not _is_android:
		return true
	if not _all_files_access:
		return false
	return _all_files_access.openAllFilesSettings()


func is_storage_plugin_available() -> bool:
	return _all_files_access != null


func get_storage_last_error() -> String:
	if not _all_files_access:
		return "plugin_missing"
	var err: String = _all_files_access.getLastError()
	return err if not err.is_empty() else ""


func is_path_readable(path: String) -> bool:
	if path.is_empty():
		return false
	if not _is_android:
		return FileAccess.file_exists(path)
	if not _all_files_access:
		return false
	return _all_files_access.isPathReadable(path)
