extends Node

# Verifies the persistent library cache and the "scan only when asked" policy:
#   1. A complete scan writes user://song_library.json.
#   2. A simulated launch rehydrates the list from it with no disk walk.
#   3. MenuRoot opens with the cached rows and does not start a scan.
#   4. Changing roots only marks the library as stale (no scan).
#   5. The guitar fallback switches difficulty sets in memory.
#   6. An empty library is remembered too (otherwise every launch would scan).
# Usage: godot --headless --path . res://tools/test_library_cache.tscn

const FIXTURE: String = "/tmp/opencode/cachetest"

var _settings_backup: PackedByteArray = PackedByteArray()
var _settings_existed: bool = false
var _cache_backup: String = ""
var _cache_existed: bool = false
var _failures: int = 0


func _check(label: String, ok: bool) -> void:
	if ok:
		print("  OK   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)


func _backup_settings() -> void:
	if FileAccess.file_exists(SettingsManager.SETTINGS_PATH):
		_settings_existed = true
		var f := FileAccess.open(SettingsManager.SETTINGS_PATH, FileAccess.READ)
		_settings_backup = f.get_buffer(f.get_length())
		f.close()


func _restore_settings() -> void:
	if not _settings_existed:
		DirAccess.remove_absolute(SettingsManager.SETTINGS_PATH)
		return
	var f := FileAccess.open(SettingsManager.SETTINGS_PATH, FileAccess.WRITE)
	f.store_buffer(_settings_backup)
	f.close()


func _backup_cache() -> void:
	if not FileAccess.file_exists(SongLoader.CACHE_PATH):
		return
	_cache_existed = true
	var f := FileAccess.open(SongLoader.CACHE_PATH, FileAccess.READ)
	_cache_backup = f.get_as_text()
	f.close()


func _restore_cache() -> void:
	if not _cache_existed:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SongLoader.CACHE_PATH))
		return
	var f := FileAccess.open(SongLoader.CACHE_PATH, FileAccess.WRITE)
	f.store_string(_cache_backup)
	f.close()


func _make_song(dir_path: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir_path)
	# Valid, empty MIDI header: the fast detector only needs the first bytes.
	var midi := PackedByteArray()
	midi.append_array("MThd".to_ascii_buffer())
	midi.append_array(PackedByteArray([0, 0, 0, 6, 0, 1, 0, 1, 0, 96]))
	var midi_file := FileAccess.open(dir_path.path_join("notes.mid"), FileAccess.WRITE)
	midi_file.store_buffer(midi)
	midi_file.close()
	var audio := FileAccess.open(dir_path.path_join("song.ogg"), FileAccess.WRITE)
	audio.store_buffer(PackedByteArray())
	audio.close()


func _ensure_fixture() -> void:
	_make_song(FIXTURE + "/one")
	_make_song(FIXTURE + "/two")


func _names() -> PackedStringArray:
	var out := PackedStringArray()
	for song in SongLoader.song_list:
		out.append(str(song.get("path", "")))
	return out


func _ready() -> void:
	_backup_settings()
	_backup_cache()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SongLoader.CACHE_PATH))
	SongLoader.song_list.clear()
	SongLoader.cache_loaded = false
	SongLoader.last_scan_at = 0
	SongLoader.last_scan_fingerprint = ""
	_ensure_fixture()

	SettingsManager.library_preset_downloads = false
	SettingsManager.library_recursive = true
	SettingsManager.library_max_depth = 3
	SettingsManager.library_roots = PackedStringArray([FIXTURE])

	print("=== 1. un escaneo completo escribe la cache ===")
	SongLoader.scan_songs()
	var scanned: PackedStringArray = _names()
	_check("encuentra las canciones de prueba", scanned.has(FIXTURE + "/one") and scanned.has(FIXTURE + "/two"))
	_check("la cache existe", FileAccess.file_exists(SongLoader.CACHE_PATH))
	_check("cache_loaded se activa", SongLoader.cache_loaded)
	_check("no queda un rescan pendiente", not SongLoader.library_needs_rescan())
	_check("el motivo esta vacio", SongLoader.library_rescan_reason().is_empty())

	print("=== 1b. los covers empaquetados se resuelven aunque el listado no los traiga ===")
	# In an exported build DirAccess may not list imported images/audio by their
	# source name; _optional_file falls back to ResourceLoader for res://.
	var res_dir: String = "res://songs/Caos - La Planta (jdpc.dev)"
	var fallback_art: String = SongLoader._optional_file(res_dir, {}, "album.png")
	_check(
		"el fallback res:// encuentra el cover",
		not fallback_art.is_empty() and ResourceLoader.load(fallback_art) != null
	)
	var bundled_art: int = 0
	for song in SongLoader.song_list:
		if not str(song.get("path", "")).begins_with("res://"):
			continue
		var art: String = str(song.get("album_path", ""))
		if not art.is_empty() and ResourceLoader.load(art) != null:
			bundled_art += 1
	_check("las canciones empaquetadas guardan un cover valido", bundled_art > 0)

	print("=== 2. un arranque simulado rehidrata sin recorrer el disco ===")
	SongLoader.song_list.clear()
	SongLoader.cache_loaded = false
	SongLoader.last_scan_at = 0
	SongLoader.last_scan_fingerprint = ""
	_check("load_library_cache() encuentra la lista", SongLoader.load_library_cache())
	_check("mismas canciones y orden", _names() == scanned)
	_check("cache_loaded", SongLoader.cache_loaded)
	_check("sin rescan pendiente", not SongLoader.library_needs_rescan())
	var cached_art: int = 0
	for song in SongLoader.song_list:
		if str(song.get("path", "")).begins_with("res://") and not str(song.get("album_path", "")).is_empty():
			cached_art += 1
	_check("los covers sobreviven a la cache", cached_art > 0)

	print("=== 3. el menu abre desde la cache y no escanea ===")
	GameManager.menu_search_text = ""
	GameManager.menu_selected_song_path = ""
	GameManager.menu_scroll_position = 0
	var menu := preload("res://scene/Main.tscn").instantiate()
	add_child(menu)
	for i in 4:
		await get_tree().process_frame
	_check("no hay escaneo en marcha", not SongLoader.is_scanning and not menu._scan_pump_active)
	_check("las filas salen de la cache", menu._filtered_indices.size() == SongLoader.song_list.size())
	_check("el menu no muestra la linea de texto de preview", menu.find_child("PreviewStatusLabel", true, false) == null)
	menu.queue_free()
	await get_tree().process_frame

	print("=== 4. cambiar la biblioteca solo marca la lista como obsoleta ===")
	SettingsManager.library_roots = PackedStringArray([FIXTURE + "/one"])
	_check("hay un motivo de rescan", SongLoader.library_rescan_reason().contains("changed"))
	_check("no se ha lanzado un escaneo", not SongLoader.is_scanning)
	SettingsManager.library_roots = PackedStringArray([FIXTURE])
	_check("volver a la configuracion guardada lo deja limpio", not SongLoader.library_needs_rescan())

	print("=== 5. el fallback de guitarra cambia las dificultades en memoria ===")
	var fake: Dictionary = {
		"path": "/tmp/opencode/cachetest/fake",
		"name": "Fake",
		"artist": "Artist",
		"has_drum_chart": false,
		"drum_difficulties": [],
		"guitar_difficulties": [{"offset": 96, "name": "Expert"}],
		"difficulties": [],
		"guitar_fallback_used": false,
	}
	SongLoader.song_list.append(fake)
	SettingsManager.use_guitar_fallback = false
	SongLoader.apply_chart_options()
	_check("sin fallback no ofrece dificultades", fake.difficulties.is_empty())
	SettingsManager.use_guitar_fallback = true
	SongLoader.apply_chart_options()
	_check("con fallback ofrece las de guitarra", fake.difficulties.size() == 1)
	_check("y lo marca como fallback", fake.guitar_fallback_used)
	_check("no hubo que escanear", not SongLoader.is_scanning)
	SongLoader.song_list.erase(fake)
	SettingsManager.use_guitar_fallback = false

	print("=== 6. una biblioteca vacia tambien se recuerda ===")
	var payload: Dictionary = {
		"schema": SongLoader.CACHE_SCHEMA,
		"app_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"fingerprint": SongLoader.scan_fingerprint(),
		"scanned_at": int(Time.get_unix_time_from_system()),
		"access": AndroidBridge.has_all_files_access(),
		"songs": [],
		"visited_roots": [],
		"unreadable_roots": [],
		"truncated_roots": [],
	}
	var cache_file := FileAccess.open(SongLoader.CACHE_PATH, FileAccess.WRITE)
	cache_file.store_string(JSON.stringify(payload))
	cache_file.close()
	SongLoader.song_list.clear()
	SongLoader.cache_loaded = false
	_check("la cache vacia se carga", SongLoader.load_library_cache())
	_check("sin canciones pero recordada", SongLoader.song_list.is_empty() and SongLoader.cache_loaded)
	_check("no vuelve a pedir el primer escaneo", not SongLoader.library_rescan_reason().contains("No library"))

	print("")
	if _failures == 0:
		print("=== TODAS LAS COMPROBACIONES OK ===")
	else:
		print("=== ", _failures, " FALLOS ===")
	print("=== DONE ===")
	_restore_settings()
	_restore_cache()
	get_tree().quit()
