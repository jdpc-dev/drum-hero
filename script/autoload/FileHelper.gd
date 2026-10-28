class_name FileHelper
extends RefCounted


static func read_file(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file:
		var data: PackedByteArray = file.get_buffer(file.get_length())
		file.close()
		return data
	if OS.has_feature("android"):
		var uri := _to_content_uri(path)
		if not uri.is_empty():
			file = FileAccess.open(uri, FileAccess.READ)
			if file:
				var data: PackedByteArray = file.get_buffer(file.get_length())
				file.close()
				return data
	return PackedByteArray()


static func file_exists(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file:
		file.close()
		return true
	if OS.has_feature("android"):
		var uri := _to_content_uri(path)
		if not uri.is_empty():
			file = FileAccess.open(uri, FileAccess.READ)
			if file:
				file.close()
				return true
	return false


static func _to_content_uri(path: String) -> String:
	if not path.begins_with("/storage/emulated/"):
		return ""
	var rel: String = path.trim_prefix("/storage/emulated/")
	var parts := rel.split("/")
	if parts.size() < 2:
		return ""
	var encoded: String = ""
	for i in range(1, parts.size()):
		if i > 1:
			encoded += "%2F"
		encoded += parts[i].uri_encode()
	return "content://com.android.externalstorage.documents/document/primary%3A" + encoded
