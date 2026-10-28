extends Node

var song_list: Array[Dictionary] = []

const SUPPORTED_FORMATS = ["ogg", "opus", "wav", "mp3"]

var custom_song_path: String = ""
var custom_song_dirs: Array[String] = []

const CONFIG_PATH := "user://song_path.cfg"


func _ready() -> void:
	_load_custom_path()


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
	for sd in custom_song_dirs:
		if not sd.is_empty():
			_scan_song(sd)


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
	if not custom_song_path.is_empty():
		paths.append(custom_song_path)
	return paths


func _get_external_path() -> String:
	var downloads: String = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if downloads.is_empty():
		return ""
	return downloads.get_base_dir().path_join("Android/data/com.drum.hero/files/DrumHero")


func set_custom_song_path(path: String) -> void:
	custom_song_path = path
	_save_custom_path()
	scan_songs()


func clear_all_custom() -> void:
	custom_song_path = ""
	custom_song_dirs.clear()
	_save_custom_path()
	scan_songs()


func add_song_dir(dir: String) -> void:
	if dir.is_empty():
		return
	if not dir in custom_song_dirs:
		custom_song_dirs.append(dir)


func get_user_song_dir() -> String:
	if OS.has_feature("android"):
		var p: String = _get_external_path()
		if not p.is_empty():
			return p
	return ProjectSettings.globalize_path("user://DrumHero")


func _load_custom_path() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		custom_song_path = cfg.get_value("settings", "custom_song_path", "")
		var arr: Array = cfg.get_value("settings", "custom_song_dirs", [])
		custom_song_dirs.clear()
		for a in arr:
			custom_song_dirs.append(str(a))


func _save_custom_path() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "custom_song_path", custom_song_path)
	_save_custom_paths(cfg)


func _save_custom_paths(cfg: ConfigFile = null) -> void:
	if not cfg:
		cfg = ConfigFile.new()
		cfg.set_value("settings", "custom_song_path", custom_song_path)
	cfg.set_value("settings", "custom_song_dirs", custom_song_dirs)
	cfg.save(CONFIG_PATH)


func _scan_song(song_path: String) -> void:
	var ini_path: String = song_path.path_join("song.ini")
	if not FileHelper.file_exists(ini_path):
		return
	var ini_data: Dictionary = _parse_ini(ini_path)
	var entry: Dictionary = {
		"path": song_path,
		"name": ini_data.get("name", song_path.get_file()),
		"artist": ini_data.get("artist", "Unknown Artist"),
		"album": ini_data.get("album", ""),
		"genre": ini_data.get("genre", ""),
		"year": ini_data.get("year", ""),
		"charter": ini_data.get("charter", ""),
		"diff_drums": ini_data.get("diff_drums", 0),
		"album_path": song_path.path_join("album.jpg") if FileHelper.file_exists(song_path.path_join("album.jpg")) else "",
		"background_path": song_path.path_join("background.jpg") if FileHelper.file_exists(song_path.path_join("background.jpg")) else "",
		"notes_path": song_path.path_join("notes.mid") if FileHelper.file_exists(song_path.path_join("notes.mid")) else "",
	}
	if not entry.notes_path.is_empty():
		entry["difficulties"] = _detect_song_difficulties(entry.notes_path)
	else:
		entry["difficulties"] = []
	song_list.append(entry)


func _detect_song_difficulties(notes_path: String) -> Array:
	var MidiParserClass = preload("res://script/chart/MidiParser.gd")
	return MidiParserClass.detect_difficulties(notes_path)


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
		if FileHelper.file_exists(full):
			return full
	return ""
