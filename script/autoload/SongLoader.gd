extends Node

# Scanning can be observed in two ways. `scan_songs()` walks the whole library
# in one go (used by tests and callers that do not need UI). Callers with
# something on screen call `begin_scan()` and then `scan_step()` once per frame
# from their `_process`: the walk is split into batches, the UI responds between
# batches, and `cancel_scan()` stops it without losing what was already found.
signal scan_progress(root_index: int, root_total: int, current_dir: String, dirs_visited: int, songs_found: int)
signal scan_finished(songs_found: int, cancelled: bool)

var song_list: Array[Dictionary] = []
var unreadable_roots: PackedStringArray = PackedStringArray()
var truncated_roots: PackedStringArray = PackedStringArray()
var cancelled_roots: PackedStringArray = PackedStringArray()
var is_scanning: bool = false

const SUPPORTED_FORMATS = ["ogg", "opus", "wav", "mp3"]
const CHART_FILENAMES = ["notes.mid", "notes.chart"]
const MAX_DIRS_PER_ROOT = 4000
# Work ceiling per batch. The limit is directories, not time: a large library is
# thousands of folders and at 60 Hz it is better to spread the work than to
# measure it. Each UI decides how much of its frame to spend with the deadline.
const MAX_DIRS_PER_FRAME = 64
# Unlimited batch for the one-shot walk (scan_songs()).
const UNLIMITED_DIR_BUDGET: int = 0x7FFFFFFF
# Frame margin for the deadline the UI passes to scan_step(). 8 ms leaves room
# for that frame's drawing even if the library is huge.
const SCAN_FRAME_BUDGET_MS = 8

var _scanned_paths: Dictionary = {}
var _dirs_visited: int = 0
var _depth_truncated: bool = false
var _current_root: String = ""

# State of the scan in progress (only used between begin_scan() and scan_finished).
var _scan_roots: PackedStringArray = PackedStringArray()
var _scan_root_index: int = 0
var _scan_current_dir: String = ""
var _scan_stack: Array = []
var _scan_cancelled: bool = false
var _scan_requested: bool = false
var _scan_dirs_total: int = 0


func _ready() -> void:
	pass


func begin_scan() -> bool:
	# Returns false if a scan is already running: SongLoader is a singleton and
	# only allows one, so the second caller must wait for it to finish instead
	# of overwriting the first one's half-built song_list.
	if is_scanning:
		return false
	song_list.clear()
	unreadable_roots = PackedStringArray()
	truncated_roots = PackedStringArray()
	cancelled_roots = PackedStringArray()
	_scanned_paths = {}
	_scan_roots = get_scan_roots()
	_scan_root_index = 0
	_scan_current_dir = ""
	_scan_stack = []
	_scan_cancelled = false
	_scan_requested = false
	_scan_dirs_total = 0
	# The current root is cleared so closing the previous scan does not get
	# attached to the next one.
	_current_root = ""
	_depth_truncated = false
	is_scanning = true
	return true


func cancel_scan() -> void:
	# It does not stop abruptly: it is honored in the next batch, at most one
	# frame later. What was already found stays in song_list.
	_scan_cancelled = true


func request_scan() -> void:
	# Requests a scan as soon as SongLoader is free. Since it is a singleton and
	# only allows one at a time, a second rescan (Settings over the menu, or
	# returning from the permissions screen) is queued instead of overwriting
	# the first one's half-built song_list.
	_scan_requested = true


func frame_deadline_usec() -> int:
	# The deadline passed to pump_scan() so as not to spend more than
	# SCAN_FRAME_BUDGET_MS in one batch.
	return Time.get_ticks_usec() + SCAN_FRAME_BUDGET_MS * 1000


func pump_scan(deadline_usec: int) -> bool:
	# A scan frame for callers with UI on screen: advances the walk (or starts
	# it if it was queued) and returns true only when nothing remains, neither a
	# running scan nor another one queued behind it. A rescan queued during the
	# current scan is served on the next frame, where the UI can already refresh
	# the previous list; meanwhile, the overlay stays up and does not flicker.
	if not is_scanning:
		if not _scan_requested:
			return true
		_scan_requested = false
		begin_scan()
		return false
	return scan_step(MAX_DIRS_PER_FRAME, deadline_usec) and not _scan_requested


func abort_scan() -> void:
	# Leaves SongLoader as it was before starting: no pending request and no
	# half-finished scan. If is_scanning = true were left behind, the next
	# begin_scan() would always fail and the library would freeze.
	_scan_requested = false
	if is_scanning:
		cancel_scan()
		# A batch of 0 only serves to close the just-cancelled scan, without
		# walking anything.
		scan_step(0)


func scan_step(dir_budget: int, deadline_usec: int = 0) -> bool:
	# Walks up to `dir_budget` directories (or until `deadline_usec` passes, if
	# > 0) and returns true when the scan has finished.
	if not is_scanning:
		return true
	var processed: int = 0
	while processed < dir_budget:
		if _scan_stack.is_empty() and not _advance_to_next_root():
			_finish_scan()
			return true
		_scan_one_dir()
		processed += 1
		# The clock is checked every eight directories: reading it on every
		# directory costs more than the walk itself over DirectoryAccess.
		if deadline_usec > 0 and processed % 8 == 0 and Time.get_ticks_usec() >= deadline_usec:
			break
	if _scan_cancelled:
		_finish_scan()
		return true
	# The event is emitted before closing the scan so the last UI to see it
	# already counts the entire walk and not one batch less.
	_emit_progress()
	if _scan_stack.is_empty() and not _has_roots_left():
		_finish_scan()
		return true
	return false


func scan_songs() -> void:
	# Full one-shot walk: a single unlimited batch. Used by tests and any caller
	# that has no UI to respond.
	if not begin_scan():
		return
	scan_step(UNLIMITED_DIR_BUDGET)


func _advance_to_next_root() -> bool:
	_close_current_root()
	while _scan_root_index < _scan_roots.size():
		var root: String = _scan_roots[_scan_root_index]
		_scan_root_index += 1
		if root.is_empty():
			continue
		_dirs_visited = 0
		_depth_truncated = false
		_current_root = root.simplify_path()
		_scan_stack.append([root, 0])
		return true
	return false


func _close_current_root() -> void:
	# Closes the previous root: if it was left due to the depth or directory
	# limit, a warning is reported. Called once per root, when the stack empties.
	if _current_root.is_empty():
		return
	if _depth_truncated and not truncated_roots.has(_current_root):
		truncated_roots.append(_current_root)
	_current_root = ""


func _has_roots_left() -> bool:
	var i: int = _scan_root_index
	while i < _scan_roots.size():
		if not _scan_roots[i].is_empty():
			return true
		i += 1
	return false


func _scan_one_dir() -> void:
	var entry: Array = _scan_stack.pop_back()
	var dir_path: String = entry[0]
	var depth: int = entry[1]
	_scan_current_dir = dir_path
	_scan_dirs_total += 1

	var canonical: String = dir_path.simplify_path()
	if _scanned_paths.has(canonical):
		return
	_scanned_paths[canonical] = true

	if _dirs_visited >= MAX_DIRS_PER_ROOT:
		_depth_truncated = true
		return

	var dir := DirAccess.open(dir_path)
	if not dir:
		# Only the root that fails to open is reported: an unreadable
		# subdirectory was ignored before too, and listing them would create
		# noise in every library.
		if depth == 0:
			unreadable_roots.append(dir_path)
		return
	_dirs_visited += 1

	var is_song: bool = false
	var chart_filename: String = ""
	var subdirs: PackedStringArray = PackedStringArray()
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if not name.begins_with("."):
			if dir.current_is_dir():
				subdirs.append(name)
			else:
				var lower_name: String = name.to_lower()
				for filename in CHART_FILENAMES:
					if lower_name == filename:
						is_song = true
						chart_filename = name
						break
		name = dir.get_next()
	dir.list_dir_end()

	if is_song:
		_scan_song(dir_path, chart_filename)
		return
	if depth >= SettingsManager.library_max_depth:
		_depth_truncated = true
		return
	if not SettingsManager.library_recursive:
		return

	# The stack is LIFO: subdirectories are pushed in reverse so they are
	# visited in the same order as depth-first recursion, and the song list
	# comes out sorted the same way.
	for i in range(subdirs.size() - 1, -1, -1):
		_scan_stack.append([dir_path.path_join(subdirs[i]), depth + 1])


func _emit_progress() -> void:
	scan_progress.emit(_scan_root_index, _scan_roots.size(), _scan_current_dir, _scan_dirs_total, song_list.size())


func _finish_scan() -> void:
	if not is_scanning:
		return
	if _scan_cancelled and not _scan_stack.is_empty() and not _current_root.is_empty():
		# Half-walked root: it is recorded separately from truncated_roots
		# because there the warning is "increase the depth" and here the scan
		# was stopped on purpose.
		cancelled_roots.append(_current_root)
	_scan_stack = []
	is_scanning = false
	scan_finished.emit(song_list.size(), _scan_cancelled)


func get_scan_roots() -> PackedStringArray:
	var roots := PackedStringArray()
	roots.append("res://Songs")
	var own_dir: String = get_user_song_dir()
	if not own_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(own_dir)
		roots.append(own_dir)
	if SettingsManager.library_preset_downloads:
		_append_system_dir(roots, OS.SYSTEM_DIR_DOWNLOADS)
	if SettingsManager.library_preset_documents:
		_append_system_dir(roots, OS.SYSTEM_DIR_DOCUMENTS)
	for custom_root in SettingsManager.library_roots:
		_append_root(roots, custom_root)
	return roots


func _append_system_dir(roots: PackedStringArray, system_dir: int) -> void:
	var path: String = OS.get_system_dir(system_dir)
	if path.is_empty():
		return
	_append_root(roots, path)


func _append_root(roots: PackedStringArray, raw_path: String) -> void:
	var path: String = raw_path.strip_edges()
	if path.is_empty():
		return
	if not path.begins_with("res://") and not path.begins_with("user://"):
		path = ProjectSettings.globalize_path(path)
	var normalized: String = path.simplify_path()
	if normalized.is_empty():
		return
	for existing in roots:
		if existing == normalized:
			return
	roots.append(normalized)


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

func _scan_song(song_path: String, notes_filename: String) -> void:
	var notes_path: String = song_path.path_join(notes_filename)
	var meta: Dictionary = _derive_metadata(song_path, notes_path)
	var preview_path: String = ""
	for ext in SUPPORTED_FORMATS:
		var p: String = song_path.path_join("preview." + ext)
		if _file_exists(p):
			preview_path = p
			break

	var album_jpg: String = song_path.path_join("album.jpg")
	var album_png: String = song_path.path_join("album.png")
	var bg_jpg: String = song_path.path_join("background.jpg")
	var entry: Dictionary = {
		"path": song_path,
		"name": meta.get("name", song_path.get_file()),
		"artist": meta.get("artist", "Unknown Artist"),
		"album": meta.get("album", ""),
		"genre": meta.get("genre", ""),
		"year": meta.get("year", ""),
		"charter": meta.get("charter", ""),
		"diff_drums": meta.get("diff_drums", 0),
		"album_path": album_jpg if _file_exists(album_jpg) else (album_png if _file_exists(album_png) else ""),
		"background_path": bg_jpg if _file_exists(bg_jpg) else "",
		"notes_path": notes_path,
		"preview_path": preview_path,
		"preview_start_time": int(meta.get("preview_start_time", -1)),
		"song_length": int(meta.get("song_length", 0)),
		"delay": int(meta.get("delay", 0)),
		"audio_blocked": _detect_blocked_audio(song_path),
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


func _file_exists(path: String) -> bool:
	return FileHelper.file_exists(path) or ResourceLoader.exists(path)


func _derive_metadata(song_path: String, notes_path: String) -> Dictionary:
	var meta: Dictionary = {}
	_apply_folder_name(meta, song_path)
	if notes_path.get_extension().to_lower() == "chart":
		_apply_chart_header(meta, notes_path)
	_apply_ini(meta, song_path.path_join("song.ini"))
	return meta


func _apply_folder_name(meta: Dictionary, song_path: String) -> void:
	var folder_name: String = song_path.get_file()
	meta["name"] = folder_name
	meta["artist"] = "Unknown Artist"
	var regex := RegEx.new()
	if regex.compile("^(.+?)\\s+-\\s+(.+?)(?:\\s+\\((.+)\\))?$") == OK:
		var result := regex.search(folder_name)
		if result != null:
			meta["artist"] = result.get_string(1)
			meta["name"] = result.get_string(2)
			var charter: String = result.get_string(3)
			if not charter.is_empty():
				meta["charter"] = charter
			return
	_apply_parent_as_artist(meta, song_path)


func _apply_parent_as_artist(meta: Dictionary, song_path: String) -> void:
	var parent: String = song_path.get_base_dir()
	if parent.is_empty():
		return
	parent = parent.simplify_path()
	if parent == _current_root or parent == parent.get_base_dir():
		return
	if parent.begins_with("res://") or parent.begins_with("user://"):
		return
	meta["artist"] = parent.get_file()


func _apply_chart_header(meta: Dictionary, notes_path: String) -> void:
	var header: Dictionary = preload("res://script/chart/DotChartParser.gd").parse_song_metadata(notes_path)
	for key in ["name", "artist", "album", "genre", "charter"]:
		var value: String = str(header.get(key, ""))
		if not value.is_empty():
			meta[key] = value
	var year: String = str(header.get("year", ""))
	if not year.is_empty():
		meta["year"] = _extract_year(year)
	var offset: String = str(header.get("offset", ""))
	if not offset.is_empty():
		meta["delay"] = int(offset)


func _apply_ini(meta: Dictionary, ini_path: String) -> void:
	if not _file_exists(ini_path):
		return
	var ini_data: Dictionary = _parse_ini(ini_path)
	for key in ini_data:
		var value: String = str(ini_data[key])
		if not value.is_empty():
			meta[key] = value


func _extract_year(raw: String) -> String:
	var digits: String = ""
	for i in raw.length():
		var c: String = raw[i]
		if c.is_valid_int():
			digits += c
		elif not digits.is_empty():
			break
	if digits.length() != 4:
		return raw.strip_edges()
	return digits


func _detect_song_difficulties(notes_path: String) -> Dictionary:
	var ext: String = notes_path.get_extension().to_lower()
	if ext == "chart":
		var DotChartParserClass = preload("res://script/chart/DotChartParser.gd")
		return DotChartParserClass.detect_difficulties_fast(notes_path, SettingsManager.use_guitar_fallback)
	var MidiParserClass = preload("res://script/chart/MidiParser.gd")
	return MidiParserClass.detect_difficulties_fast(notes_path, SettingsManager.use_guitar_fallback)


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
			var value: String = DotChartParser.strip_quotes(line.substr(eq_pos + 1))
			result[key] = value
	return result


func _detect_blocked_audio(song_path: String) -> bool:
	# Android does not decode .opus (AudioManager only falls back to a sibling .ogg).
	# Without that .ogg the song is listed but plays as silence.
	var opus_path: String = song_path.path_join("song.opus")
	if not _file_exists(opus_path):
		return false
	return not _file_exists(song_path.path_join("song.ogg"))


func get_stem_path(song_path: String, stem_name: String) -> String:
	for ext in SUPPORTED_FORMATS:
		var full: String = song_path.path_join(stem_name + "." + ext)
		if FileHelper.file_exists(full) or ResourceLoader.exists(full):
			return full
	return ""
