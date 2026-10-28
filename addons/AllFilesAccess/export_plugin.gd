@tool
extends EditorExportPlugin


var _target: String = "export_plugin.gd"
var _plugin_name: String = "AllFilesAccess"


func _get_name() -> String:
	return _plugin_name


func _supports_platform(platform: EditorExportPlatform) -> bool:
	if platform is EditorExportPlatformPC:
		return false
	return true


func _get_android_libraries(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
	if debug:
		return PackedStringArray(["res://addons/AllFilesAccess/bin/debug/AllFilesAccess.aar"])
	return PackedStringArray(["res://addons/AllFilesAccess/bin/release/AllFilesAccess.aar"])


func _get_android_dependencies(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
	return PackedStringArray()
