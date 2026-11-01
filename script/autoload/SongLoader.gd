extends Node

# Scanning can be observed in two ways. `scan_songs()` walks the whole library
# in one go (used by tests and callers that do not need UI). Callers with
# something on screen call `begin_scan()` and then `scan_step()` once per frame
# from their `_process`: the walk is split into batches, the UI responds between
# batches, and `cancel_scan()` stops it without losing what was already found.
#
# Results are collected in a staging list and only published to `song_list`
# when the walk ends. An aborted scan (`abort_scan()`, used when a panel
# disappears mid-walk) is discarded and the previous library stays visible:
# clearing `song_list` at the start left the menu empty when a scan was cut
# short, which looked exactly like "no songs on this device".
signal scan_progress(root_index: int, root_total: int, current_dir: String, dirs_visited: int, songs_found: int)
signal scan_finished(songs_found: int, cancelled: bool)

var song_list: Array[Dictionary] = []
var unreadable_roots: PackedStringArray = PackedStringArray()
var truncated_roots: PackedStringArray = PackedStringArray()
var cancelled_roots: PackedStringArray = PackedStringArray()
# Roots the walk actually finished (or reached) in the last scan, and the ones
# it never got to. The summary uses these instead of counting configured roots,
# which made a cancelled scan claim it had checked all of them.
var visited_roots: PackedStringArray = PackedStringArray()
var unvisited_roots: PackedStringArray = PackedStringArray()
# Human-readable trace of the last scan. It is printed to stdout (logcat on
# Android) so a device report can show which roots were unreadable, which
# settings were active, and who started/aborted the walk.
var last_scan_log: PackedStringArray = PackedStringArray()
var is_scanning: bool = false
# The library is persisted so a launch can show it without walking the disks.
# `last_scan_fingerprint` describes the roots/settings the published list was
# built with; `library_rescan_reason()` tells the UI when it is stale.
var last_scan_at: int = 0
var last_scan_fingerprint: String = ""
var last_scan_cancelled: bool = false
# True once a cached list (even an empty one) has been restored: the menu uses
# it to open without scanning on every launch.
var cache_loaded: bool = false
var last_scan_access: bool = false
# Bumped every time `song_list` is replaced (scan finish, cancel, cache load).
# The menu compares it across a Settings visit to know whether to rebuild.
var library_generation: int = 0

const SUPPORTED_FORMATS = ["ogg", "opus", "wav", "mp3"]
const CACHE_PATH: String = "user://song_library.json"
# Bumped when the shape of an entry changes. Schema 1 caches could have empty
# album/preview paths for packaged songs (imported files are not listed by
# DirAccess in exported builds), so they are discarded and rescanned once.
const CACHE_SCHEMA: int = 2
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
# Staging list: `song_list` is only replaced on a natural finish or a user
# cancel, never while the walk is running.
var _scan_results: Array[Dictionary] = []
# Who owns the walk ("menu", "settings", ...). `abort_scan(owner)` must not
# cancel a scan started by another surface: closing Settings used to abort the
# menu's scan and leave the list half-built.
var _scan_owner: String = ""
var _requested_owner: String = ""
var _scan_aborted: bool = false
# Stats of the root being walked, for the trace.
var _root_dirs_start: int = 0
var _root_songs_start: int = 0
var _root_unreadable: bool = false
# Fingerprint of the scan in progress and of the published list.
var _scan_fingerprint: String = ""
var _scan_app_version: String = ""
var _scan_access: bool = false
var _library_app_version: String = ""


func _ready() -> void:
	load_library_cache()


func begin_scan(owner: String = "") -> bool:
	# Returns false if a scan is already running: SongLoader is a singleton and
	# only allows one, so the second caller must wait for it to finish instead
	# of overwriting the first one's half-built song_list.
	if is_scanning:
		return false
	_scan_results = []
	unreadable_roots = PackedStringArray()
	truncated_roots = PackedStringArray()
	cancelled_roots = PackedStringArray()
	visited_roots = PackedStringArray()
	unvisited_roots = PackedStringArray()
	last_scan_log = PackedStringArray()
	_scanned_paths = {}
	_scan_roots = get_scan_roots()
	_scan_fingerprint = _fingerprint_for_roots(_scan_roots)
	_scan_app_version = _app_version()
	_scan_access = AndroidBridge.has_all_files_access()
	_scan_root_index = 0
	_scan_current_dir = ""
	_scan_stack = []
	_scan_cancelled = false
	_scan_requested = false
	_scan_aborted = false
	_scan_owner = owner
	_scan_dirs_total = 0
	_root_dirs_start = 0
	_root_songs_start = 0
	_root_unreadable = false
	# The current root is cleared so closing the previous scan does not get
	# attached to the next one.
	_current_root = ""
	_depth_truncated = false
	is_scanning = true
	last_scan_log.append("begin owner='%s' locations=%d recursive=%s max_depth=%d access=%s" % [
		owner,
		_scan_roots.size(),
		"on" if SettingsManager.library_recursive else "off",
		SettingsManager.library_max_depth,
		"granted" if AndroidBridge.has_all_files_access() else "not granted",
	])
	return true


func cancel_scan() -> void:
	# It does not stop abruptly: it is honored in the next batch, at most one
	# frame later. What was already found stays in song_list.
	_scan_cancelled = true


func request_scan(owner: String = "") -> void:
	# Requests a scan as soon as SongLoader is free. Since it is a singleton and
	# only allows one at a time, a second rescan (Settings over the menu, or
	# returning from the permissions screen) is queued instead of overwriting
	# the first one's half-built song_list.
	_scan_requested = true
	_requested_owner = owner


func frame_deadline_usec() -> int:
	# The deadline passed to pump_scan() so as not to spend more than
	# SCAN_FRAME_BUDGET_MS in one batch.
	return Time.get_ticks_usec() + SCAN_FRAME_BUDGET_MS * 1000


func pump_scan(deadline_usec: int, owner: String = "") -> bool:
	# A scan frame for callers with UI on screen: advances the walk (or starts
	# it if it was queued) and returns true only when nothing remains, neither a
	# running scan nor another one queued behind it. A rescan queued during the
	# current scan is served on the next frame, where the UI can already refresh
	# the previous list; meanwhile, the overlay stays up and does not flicker.
	#
	# `owner` is optional for tests and one-shot callers. A UI only advances the
	# scan it requested, so two panels cannot step the same walk at once; the
	# owner keeps pumping from its own `_process`.
	if not is_scanning:
		if not _scan_requested:
			return true
		_scan_requested = false
		var requested_by: String = _requested_owner
		_requested_owner = ""
		begin_scan(requested_by)
		return false
	if not _owns_scan(owner):
		return false
	return scan_step(MAX_DIRS_PER_FRAME, deadline_usec) and not _scan_requested


func abort_scan(owner: String = "") -> void:
	# Leaves SongLoader as it was before starting: no pending request and no
	# half-finished scan. If is_scanning = true were left behind, the next
	# begin_scan() would always fail and the library would freeze.
	#
	# With an explicit owner, only that surface's request/scan is affected: a
	# panel closing must not cancel the walk another screen is showing.
	if _scan_requested and _owns_request(owner):
		_scan_requested = false
		_requested_owner = ""
	if not is_scanning:
		return
	if not _owns_scan(owner):
		return
	_scan_aborted = true
	cancel_scan()
	# A batch of 0 only serves to close the just-cancelled scan, without
	# walking anything.
	scan_step(0)


func _owns_scan(owner: String) -> bool:
	# An empty owner means "whoever" (tests, one-shot callers).
	return owner.is_empty() or _scan_owner.is_empty() or owner == _scan_owner


func _owns_request(owner: String) -> bool:
	return owner.is_empty() or _requested_owner.is_empty() or owner == _requested_owner


func get_scanned_song_count() -> int:
	# Songs found by the walk in progress. The UI reads progress from
	# `scan_progress`; this is for callers that need the count mid-scan.
	return _scan_results.size()


func scan_fingerprint() -> String:
	# Everything that changes which songs a scan would find. Read-only for the
	# UI: the scan settings only take effect when the player asks for a rescan.
	return _fingerprint_for_roots(get_scan_roots())


func library_rescan_reason() -> String:
	# Empty when the published list matches the current roots and settings.
	# The UI shows this instead of scanning by itself.
	if song_list.is_empty() and last_scan_at <= 0:
		return "No library has been scanned yet."
	if _library_app_version != _app_version():
		return "The app was updated since the last scan."
	if last_scan_cancelled:
		return "The last scan was cancelled before finishing."
	if last_scan_access != AndroidBridge.has_all_files_access():
		return "Storage access changed since the last scan."
	if scan_fingerprint() != last_scan_fingerprint:
		return "Library locations or scan settings changed."
	return ""


func library_needs_rescan() -> bool:
	return not library_rescan_reason().is_empty()


func apply_chart_options() -> void:
	# Difficulty sets are stored per source during the scan, so switching the
	# guitar fallback is a memory pass instead of a disk walk.
	for entry in song_list:
		_apply_chart_options_to_entry(entry)


func load_library_cache() -> bool:
	if not FileAccess.file_exists(CACHE_PATH):
		return false
	var file := FileAccess.open(CACHE_PATH, FileAccess.READ)
	if not file:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	if int(data.get("schema", 0)) != CACHE_SCHEMA:
		return false
	var songs: Variant = data.get("songs", [])
	if not (songs is Array):
		return false
	var loaded: Array[Dictionary] = []
	for item in songs:
		if item is Dictionary:
			_normalize_cached_entry(item)
			loaded.append(item)
	# A scanned-empty library is still a valid cache: without it the menu would
	# walk the disks on every launch just to find nothing again.
	var scanned_at: int = int(data.get("scanned_at", 0))
	if loaded.is_empty() and scanned_at <= 0:
		return false
	song_list.assign(loaded)
	last_scan_fingerprint = str(data.get("fingerprint", ""))
	last_scan_at = scanned_at
	_library_app_version = str(data.get("app_version", ""))
	last_scan_access = bool(data.get("access", false))
	last_scan_cancelled = false
	cache_loaded = true
	cancelled_roots = PackedStringArray()
	visited_roots = _to_packed_strings(data.get("visited_roots", []))
	unreadable_roots = _to_packed_strings(data.get("unreadable_roots", []))
	truncated_roots = _to_packed_strings(data.get("truncated_roots", []))
	library_generation += 1
	apply_chart_options()
	return true


func _save_library_cache() -> void:
	var file := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if not file:
		return
	var data: Dictionary = {
		"schema": CACHE_SCHEMA,
		"app_version": _app_version(),
		"fingerprint": last_scan_fingerprint,
		"scanned_at": last_scan_at,
		"access": last_scan_access,
		"songs": song_list,
		"visited_roots": _to_array(visited_roots),
		"unreadable_roots": _to_array(unreadable_roots),
		"truncated_roots": _to_array(truncated_roots),
	}
	file.store_string(JSON.stringify(data))
	file.close()


func _normalize_cached_entry(entry: Dictionary) -> void:
	# JSON has no integer type: restore the integers the menu compares with
	# (difficulty offsets are dictionary keys, so 60.0 and 60 must not mix).
	for key in ["diff_drums", "preview_start_time", "song_length", "delay"]:
		if entry.has(key):
			entry[key] = int(entry[key])
	for key in ["has_drum_chart", "guitar_fallback_used", "audio_blocked"]:
		if entry.has(key):
			entry[key] = bool(entry[key])
	for key in ["difficulties", "drum_difficulties", "guitar_difficulties"]:
		var diffs: Variant = entry.get(key, [])
		if diffs is Array:
			for diff in diffs:
				if diff is Dictionary and diff.has("offset"):
					diff["offset"] = int(diff["offset"])


func _apply_chart_options_to_entry(entry: Dictionary) -> void:
	# Entries built by hand (tests, older data) may not carry the split arrays.
	# In that case leave their `difficulties` untouched instead of wiping them.
	var has_drum_info: bool = entry.has("drum_difficulties")
	var has_guitar_info: bool = entry.has("guitar_difficulties")
	if not has_drum_info and not has_guitar_info:
		return
	var has_drum: bool = bool(entry.get("has_drum_chart", false))
	var guitar: Array = entry.get("guitar_difficulties", [])
	if has_drum:
		entry["difficulties"] = entry.get("drum_difficulties", [])
		entry["guitar_fallback_used"] = false
	elif SettingsManager.use_guitar_fallback and not guitar.is_empty():
		entry["difficulties"] = guitar
		entry["guitar_fallback_used"] = true
	else:
		entry["difficulties"] = []
		entry["guitar_fallback_used"] = false


func _fingerprint_for_roots(roots: PackedStringArray) -> String:
	var parts := PackedStringArray()
	for root in roots:
		var readable: DirAccess = DirAccess.open(root)
		parts.append("%s:%s" % [root, "1" if readable != null else "0"])
	return "%d|%s|%s|recursive=%s|depth=%d|access=%s" % [
		CACHE_SCHEMA,
		_app_version(),
		"|".join(parts),
		"on" if SettingsManager.library_recursive else "off",
		SettingsManager.library_max_depth,
		"granted" if AndroidBridge.has_all_files_access() else "not granted",
	]


func _app_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))


func _to_packed_strings(value: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if value is Array:
		for item in value:
			out.append(str(item))
	return out


func _to_array(values: PackedStringArray) -> Array:
	var out: Array = []
	for value in values:
		out.append(value)
	return out


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
		_root_dirs_start = _scan_dirs_total
		_root_songs_start = _scan_results.size()
		_root_unreadable = false
		_scan_stack.append([root, 0])
		return true
	return false


func _close_current_root() -> void:
	# Closes the previous root: if it was left due to the depth or directory
	# limit, a warning is reported. Called once per root, when the stack empties.
	if _current_root.is_empty():
		return
	var root_path: String = _current_root
	_current_root = ""
	if _depth_truncated and not truncated_roots.has(root_path):
		truncated_roots.append(root_path)
	if not visited_roots.has(root_path):
		visited_roots.append(root_path)
	if _root_unreadable:
		last_scan_log.append("  location '%s': unreadable" % root_path)
		return
	var dirs: int = _scan_dirs_total - _root_dirs_start
	var songs: int = _scan_results.size() - _root_songs_start
	last_scan_log.append("  location '%s': dirs=%d songs=%d%s" % [
		root_path, dirs, songs, " (truncated)" if _depth_truncated else ""
	])


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
			_root_unreadable = true
		return
	_dirs_visited += 1

	var is_song: bool = false
	var chart_filename: String = ""
	var subdirs: PackedStringArray = PackedStringArray()
	# Lowercased file name -> real name. Passing this to _scan_song() avoids up
	# to nine additional FileAccess/ResourceLoader probes per song for previews,
	# album art, backgrounds and audio on Android external storage.
	var files: Dictionary = {}
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if not name.begins_with("."):
			if dir.current_is_dir():
				subdirs.append(name)
			else:
				var lower_name: String = name.to_lower()
				files[lower_name] = name
				for filename in CHART_FILENAMES:
					if lower_name == filename:
						is_song = true
						chart_filename = name
						break
		name = dir.get_next()
	dir.list_dir_end()

	if is_song:
		_scan_song(dir_path, chart_filename, files)
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
	scan_progress.emit(
		_scan_root_index, _scan_roots.size(), _scan_current_dir,
		_scan_dirs_total, _scan_results.size()
	)


func _finish_scan() -> void:
	if not is_scanning:
		return
	if _scan_cancelled and not _scan_stack.is_empty() and not _current_root.is_empty():
		# Half-walked root: it is recorded separately from truncated_roots
		# because there the warning is "increase the depth" and here the scan
		# was stopped on purpose.
		if not cancelled_roots.has(_current_root):
			cancelled_roots.append(_current_root)
		if not unvisited_roots.has(_current_root):
			unvisited_roots.append(_current_root)
		last_scan_log.append("  location '%s': cancelled" % _current_root)
	else:
		_close_current_root()
	# Roots after the one that was in progress never got a single directory.
	for i in range(_scan_root_index, _scan_roots.size()):
		var root: String = _scan_roots[i]
		if not root.is_empty() and not unvisited_roots.has(root):
			unvisited_roots.append(root)
	_current_root = ""
	_scan_stack = []
	is_scanning = false
	if _scan_aborted:
		# As if the scan had never started: the previous library is published.
		_scan_results.clear()
		unreadable_roots = PackedStringArray()
		truncated_roots = PackedStringArray()
		cancelled_roots = PackedStringArray()
		visited_roots = PackedStringArray()
		unvisited_roots = PackedStringArray()
		last_scan_log.append("aborted owner='%s'" % _scan_owner)
	else:
		# Staging -> published. Copied so the next begin_scan() can reuse the
		# staging array without clearing the visible library.
		song_list.assign(_scan_results)
		library_generation += 1
		last_scan_at = int(Time.get_unix_time_from_system())
		last_scan_cancelled = _scan_cancelled
		if not _scan_cancelled:
			last_scan_fingerprint = _scan_fingerprint
			_library_app_version = _scan_app_version
			last_scan_access = _scan_access
			cache_loaded = true
			# Only a complete walk is cached: a cancelled prefix would hide the
			# songs the player has not scanned yet.
			_save_library_cache()
		last_scan_log.append("end songs=%d cancelled=%s" % [song_list.size(), str(_scan_cancelled)])
	for line in last_scan_log:
		print("[SongLoader] " + line)
	scan_finished.emit(song_list.size(), _scan_cancelled)


func get_scan_roots() -> PackedStringArray:
	var roots := PackedStringArray()
	roots.append("res://songs")
	var own_dir: String = get_user_song_dir()
	if not own_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(own_dir)
		roots.append(own_dir)
	if SettingsManager.library_preset_downloads:
		_append_system_dir(roots, OS.SYSTEM_DIR_DOWNLOADS)
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


func get_user_song_dir() -> String:
	return ProjectSettings.globalize_path("user://DrumHero")


func _optional_file(song_path: String, files: Dictionary, lower_name: String) -> String:
	# The directory listing covers external libraries without extra stat calls.
	# Packaged songs are special: images and audio are imported, and DirAccess
	# does not necessarily list their source names in an exported build. For
	# `res://` the old ResourceLoader probe is kept so album art and previews
	# still resolve there (a handful of bundled songs).
	if files.has(lower_name):
		return song_path.path_join(str(files[lower_name]))
	if song_path.begins_with("res://") and _file_exists(song_path.path_join(lower_name)):
		return song_path.path_join(lower_name)
	return ""


func _file_exists(path: String) -> bool:
	return FileHelper.file_exists(path) or ResourceLoader.exists(path)


func _scan_song(song_path: String, notes_filename: String, files: Dictionary) -> void:
	var notes_path: String = song_path.path_join(notes_filename)
	var meta: Dictionary = _derive_metadata(song_path, notes_path, files)
	var preview_path: String = ""
	for ext in SUPPORTED_FORMATS:
		preview_path = _optional_file(song_path, files, "preview." + ext)
		if not preview_path.is_empty():
			break

	var album_path: String = _optional_file(song_path, files, "album.jpg")
	if album_path.is_empty():
		album_path = _optional_file(song_path, files, "album.png")
	var background_path: String = _optional_file(song_path, files, "background.jpg")
	var opus_path: String = _optional_file(song_path, files, "song.opus")
	var ogg_path: String = _optional_file(song_path, files, "song.ogg")
	var entry: Dictionary = {
		"path": song_path,
		"name": meta.get("name", song_path.get_file()),
		"artist": meta.get("artist", "Unknown Artist"),
		"album": meta.get("album", ""),
		"genre": meta.get("genre", ""),
		"year": meta.get("year", ""),
		"charter": meta.get("charter", ""),
		"diff_drums": meta.get("diff_drums", 0),
		"album_path": album_path,
		"background_path": background_path,
		"notes_path": notes_path,
		"preview_path": preview_path,
		"preview_start_time": int(meta.get("preview_start_time", -1)),
		"song_length": int(meta.get("song_length", 0)),
		"delay": int(meta.get("delay", 0)),
		# Android does not decode .opus; a sibling .ogg avoids silent playback.
		"audio_blocked": not opus_path.is_empty() and ogg_path.is_empty(),
	}
	var chart_info: Dictionary = _detect_chart_info(notes_path)
	entry["drum_difficulties"] = chart_info.drum_difficulties
	entry["guitar_difficulties"] = chart_info.guitar_difficulties
	entry["has_drum_chart"] = chart_info.has_drum_chart
	_apply_chart_options_to_entry(entry)
	_scan_results.append(entry)


func _derive_metadata(song_path: String, notes_path: String, files: Dictionary) -> Dictionary:
	var meta: Dictionary = {}
	_apply_folder_name(meta, song_path)
	if notes_path.get_extension().to_lower() == "chart":
		_apply_chart_header(meta, notes_path)
	var ini_path: String = _optional_file(song_path, files, "song.ini")
	if not ini_path.is_empty():
		_apply_ini(meta, ini_path)
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


func _detect_chart_info(notes_path: String) -> Dictionary:
	var empty: Dictionary = {
		"drum_difficulties": [],
		"guitar_difficulties": [],
		"has_drum_chart": false,
	}
	if notes_path.is_empty():
		return empty
	var ext: String = notes_path.get_extension().to_lower()
	if ext == "chart":
		var DotChartParserClass = preload("res://script/chart/DotChartParser.gd")
		return DotChartParserClass.detect_chart_info(notes_path)
	var MidiParserClass = preload("res://script/chart/MidiParser.gd")
	return MidiParserClass.detect_chart_info(notes_path)


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


func get_stem_path(song_path: String, stem_name: String) -> String:
	for ext in SUPPORTED_FORMATS:
		var full: String = song_path.path_join(stem_name + "." + ext)
		if FileHelper.file_exists(full) or ResourceLoader.exists(full):
			return full
	return ""
