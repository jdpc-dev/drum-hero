extends Node

var song_list: Array[Dictionary] = []

const SUPPORTED_FORMATS = ["ogg", "opus", "wav", "mp3"]

func _ready() -> void:
	pass


func scan_songs() -> void:
	song_list.clear()
	var paths = ["res://Songs"]
	paths.append_array(_get_user_song_paths())
	for songs_path in paths:
		if songs_path.is_empty():
			continue
		var dir := DirAccess.open(songs_path)
		if not dir:
			continue
		dir.list_dir_begin()
		var entry: String = dir.get_next()
		while entry != "":
			if entry.begins_with("."):
				entry = dir.get_next()
				continue
			var full_path: String = songs_path.path_join(entry)
			var sub_dir := DirAccess.open(full_path)
			if sub_dir:
				sub_dir = null
				_scan_song(full_path)
			entry = dir.get_next()
		dir.list_dir_end()


func _get_user_song_paths() -> Array:
	var paths = []
	if OS.has_feature("android"):
		var external: String = _get_external_path()
		if not external.is_empty():
			DirAccess.make_dir_recursive_absolute(external)
			paths.append(external)
	else:
		var user_path: String = "user://DrumHero"
		DirAccess.make_dir_recursive_absolute(user_path)
		paths.append(user_path)
	return paths

func _get_external_path() -> String:
	var downloads: String = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if downloads.is_empty():
		return ""
	return downloads.get_base_dir().path_join("Android/data/com.drum.hero/files/DrumHero")

func get_user_song_dir() -> String:
	if OS.has_feature("android"):
		var p: String = _get_external_path()
		if not p.is_empty():
			return p
	return ProjectSettings.globalize_path("user://DrumHero")

func _scan_song(song_path: String) -> void:
	var ini_path: String = song_path.path_join("song.ini")
	if not FileHelper.file_exists(ini_path) and not ResourceLoader.exists(ini_path):
		return
	var ini_data: Dictionary = _parse_ini(ini_path)
	var preview_path: String = ""
	for ext in SUPPORTED_FORMATS:
		var p: String = song_path.path_join("preview." + ext)
		if FileHelper.file_exists(p) or ResourceLoader.exists(p):
			preview_path = p
			break

	var preview_start: int = int(ini_data.get("preview_start_time", -1))

	var album_jpg: String = song_path.path_join("album.jpg")
	var bg_jpg: String = song_path.path_join("background.jpg")
	var notes_mid: String = song_path.path_join("notes.mid")
	var entry: Dictionary = {
		"path": song_path,
		"name": ini_data.get("name", song_path.get_file()),
		"artist": ini_data.get("artist", "Unknown Artist"),
		"album": ini_data.get("album", ""),
		"genre": ini_data.get("genre", ""),
		"year": ini_data.get("year", ""),
		"charter": ini_data.get("charter", ""),
		"diff_drums": ini_data.get("diff_drums", 0),
		"album_path": album_jpg if (FileHelper.file_exists(album_jpg) or ResourceLoader.exists(album_jpg)) else "",
		"background_path": bg_jpg if (FileHelper.file_exists(bg_jpg) or ResourceLoader.exists(bg_jpg)) else "",
		"notes_path": notes_mid if (FileHelper.file_exists(notes_mid) or ResourceLoader.exists(notes_mid)) else "",
		"preview_path": preview_path,
		"preview_start_time": preview_start,
		"song_length": int(ini_data.get("song_length", 0)),
	}
	if not entry.notes_path.is_empty():
		var diff_result: Dictionary = _detect_song_difficulties(entry.notes_path)
		entry["difficulties"] = diff_result.difficulties
		entry["has_drum_chart"] = diff_result.has_drum_chart
		entry["guitar_fallback_used"] = diff_result.guitar_fallback_used
	else:
		entry["difficulties"] = []
		entry["has_drum_chart"] = false
		entry["guitar_fallback_used"] = false
	song_list.append(entry)


func _detect_song_difficulties(notes_path: String) -> Dictionary:
	var MidiParserClass = preload("res://script/chart/MidiParser.gd")
	return MidiParserClass.detect_difficulties(notes_path, SettingsManager.use_guitar_fallback)


func _parse_ini(path: String) -> Dictionary:
	var result: Dictionary = {}
	var data: PackedByteArray = FileHelper.read_file(path)
	if data.is_empty():
		return result
	var content: String = data.get_string_from_utf8()
	if content.is_empty():
		return result
	var lines = content.split("\n", false)
	var section: String = ""
	for raw_line in lines:
		var line: String = raw_line.strip_edges()
		if line.begins_with(";") or line.begins_with("#"):
			continue
		if line.begins_with("["):
			section = line.substr(1, line.length() - 2).to_lower()
			continue
		var eq_pos: int = line.find("=")
		if eq_pos > 0:
			var key: String = line.substr(0, eq_pos).strip_edges().to_lower()
			var value: String = line.substr(eq_pos + 1).strip_edges()
			result[key] = value
	return result


func get_stem_path(song_path: String, stem_name: String) -> String:
	for ext in SUPPORTED_FORMATS:
		var full: String = song_path.path_join(stem_name + "." + ext)
		if FileHelper.file_exists(full) or ResourceLoader.exists(full):
			return full
	return ""
