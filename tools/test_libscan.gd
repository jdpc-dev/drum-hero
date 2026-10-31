extends Node

var _settings_backup: PackedByteArray = PackedByteArray()
var _settings_existed: bool = false
var _failures: int = 0
# Lambda counters live here: GDScript captures by value and a
# `finished += 1` inside the lambda would not be seen from outside.
var _finishes: int = 0


func _check(label: String, ok: bool) -> void:
	if ok:
		print("  OK   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)


func _reset(max_depth: int, recursive: bool, roots: PackedStringArray) -> void:
	SettingsManager.library_preset_downloads = false
	SettingsManager.library_preset_documents = false
	SettingsManager.library_roots = roots
	SettingsManager.library_recursive = recursive
	SettingsManager.library_max_depth = max_depth


# The tree this test walks used to live in /tmp and does not travel in the
# repo: without it all checks would compare empty lists against empty lists and
# pass without checking anything. It is always built, not only when missing.
func _ensure_fixture() -> void:
	var base: String = "/tmp/opencode/libtest"
	_make_song(base + "/rootA/Alpha")
	_make_song(base + "/rootA/Artist One/Song Gamma (c)")
	_make_song(base + "/rootA/Beta/charts")
	_make_song(base + "/rootA/a/b/c/d/TooDeep")
	_make_song(base + "/rootB/Solo Song")
	# Wide root with songs: forces the walk to be split into several batches and
	# leaves songs unseen when cancelling, so it shows in the list.
	for i in 100:
		_make_song(base + "/wide/d" + str(i))
	# Beta has the chart in a subdirectory, so Beta is not a song.
	_write_text(base + "/rootA/Beta/song.ini", "[Song]\nname = Beta\n")


func _make_song(dir_path: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir_path)
	# Valid, empty MIDI header: MidiParser.detect_difficulties_fast() only needs
	# the first bytes to avoid misreading the chart.
	var midi := PackedByteArray()
	midi.append_array("MThd".to_ascii_buffer())
	midi.append_array(PackedByteArray([0, 0, 0, 6, 0, 1, 0, 1, 0, 96]))
	_write_file(dir_path.path_join("notes.mid"), midi)
	_write_file(dir_path.path_join("song.ogg"), PackedByteArray())


func _write_file(path: String, data: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_buffer(data)
		f.close()


func _write_text(path: String, text: String) -> void:
	_write_file(path, text.to_utf8_buffer())


func _names() -> PackedStringArray:
	var out := PackedStringArray()
	for s in SongLoader.song_list:
		var p: String = s.get("path", "")
		if not p.begins_with("/tmp/"):
			continue
		out.append(s.get("name", "?") + " [" + p.split("/libtest/")[1] + "]")
	return out


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


func _ready() -> void:
	_backup_settings()
	_ensure_fixture()
	var A := "/tmp/opencode/libtest/rootA"
	var B := "/tmp/opencode/libtest/rootB"
	var SOLO := "/tmp/opencode/libtest/rootB/Solo Song"
	var DEEP := "/tmp/opencode/libtest/rootA/a/b/c/d/TooDeep"
	var WIDE := "/tmp/opencode/libtest/wide"

	print("=== 1. normalizacion y dedup de roots ===")
	_reset(3, true, PackedStringArray([A, B, SOLO, A + "/../rootA", "   ", "/tmp/opencode/libtest/noexiste", B + "/"]))
	for r in SongLoader.get_scan_roots():
		print("  root: ", r)
	SongLoader.scan_songs()
	print("  unreadable=", SongLoader.unreadable_roots, " (esperado: solo noexiste)")
	print("  ", _names())

	print("=== 1b. raiz sobre un FICHERO, no un directorio ===")
	_reset(3, true, PackedStringArray(["/tmp/opencode/libtest/rootA/Artist One/Song Gamma (c)/song.ogg"]))
	SongLoader.scan_songs()
	print("  unreadable=", SongLoader.unreadable_roots)

	print("=== 2. max_depth=3 y song.ini opcional ===")
	_reset(3, true, PackedStringArray([A]))
	SongLoader.scan_songs()
	print("  ", _names())
	print("  (esperado: Alpha prof1 y Gamma prof2. Beta NO: su chart esta en charts/, y esa subcarpeta entra como cancion porque un notes.mid ya basta)")
	print("  truncated=", SongLoader.truncated_roots, " (esperado: rootA por limite de profundidad)")

	print("=== 3. max_depth=5 alcanza TooDeep ===")
	_reset(5, true, PackedStringArray([DEEP]))
	SongLoader.scan_songs()
	print("  como root: ", _names(), " (esperado: TooDeep; al ser root se escanea a prof0)")
	_reset(3, true, PackedStringArray([A]))
	SongLoader.scan_songs()
	print("  bajo rootA con max_depth=3: ", _names(), " (esperado: sin TooDeep, esta a prof5)")

	print("=== 4. recursive=false no inspecciona subcarpetas ===")
	_reset(3, false, PackedStringArray([A]))
	SongLoader.scan_songs()
	print("  ", _names(), " (esperado: vacio)")

	print("=== 5. root que es directamente una cancion ===")
	_reset(3, true, PackedStringArray([SOLO]))
	SongLoader.scan_songs()
	print("  ", _names(), " (esperado: Solo)")

	print("=== 6. raiz anidada solapada: B y SOLO a la vez, sin duplicar ===")
	_reset(3, true, PackedStringArray([B, SOLO]))
	SongLoader.scan_songs()
	print("  ", _names(), " (esperado: Solo UNA vez, pese a estar bajo B y como root)")
	_reset(3, true, PackedStringArray([SOLO]))
	SongLoader.scan_songs()
	print("  solo como root: ", _names())

	print("=== 7. idempotencia del rescan ===")
	_reset(3, true, PackedStringArray([A]))
	SongLoader.scan_songs()
	var a: int = SongLoader.song_list.size()
	SongLoader.scan_songs()
	var b: int = SongLoader.song_list.size()
	SongLoader.scan_songs()
	var c: int = SongLoader.song_list.size()
	print("  ", a, " / ", b, " / ", c, " (esperado iguales; incluye las de res://Songs)")

	print("=== 7b. persistencia de [library] en settings.cfg ===")
	SettingsManager.library_roots = PackedStringArray(["/tmp/one", "/tmp/dos"])
	SettingsManager.library_preset_downloads = false
	SettingsManager.library_preset_documents = true
	SettingsManager.library_recursive = false
	SettingsManager.library_max_depth = 7
	SettingsManager.save_settings()
	SettingsManager.library_roots = PackedStringArray()
	SettingsManager.library_preset_downloads = true
	SettingsManager.library_preset_documents = false
	SettingsManager.library_recursive = true
	SettingsManager.library_max_depth = 1
	SettingsManager.load_settings()
	print("  roots=", SettingsManager.library_roots, " (esperado /tmp/one,/tmp/dos)")
	print("  downloads=", SettingsManager.library_preset_downloads, " documents=", SettingsManager.library_preset_documents)
	print("  recursive=", SettingsManager.library_recursive, " max_depth=", SettingsManager.library_max_depth)
	print("  roots(tipo)=", typeof(SettingsManager.library_roots))

	print("=== 8. ruta de juego real (res://Songs) intacta ===")
	_reset(3, true, PackedStringArray())
	SongLoader.scan_songs()
	for s in SongLoader.song_list:
		print("  - ", s.get("name", "?"), " @ ", s.get("path", "?"))
	print("  total=", SongLoader.song_list.size())

	var MIX := PackedStringArray([A, B, DEEP, WIDE])
	_reset(3, true, MIX)
	SongLoader.scan_songs()
	var whole: Array[Dictionary] = SongLoader.song_list.duplicate(true)
	var whole_names: PackedStringArray = _names()
	var whole_unreadable: PackedStringArray = SongLoader.unreadable_roots.duplicate()
	var whole_truncated: PackedStringArray = SongLoader.truncated_roots.duplicate()
	_check("el recorrido completo encuentra canciones de prueba", whole.size() > 0)

	print("=== 9. por lotes da el MISMO resultado y el mismo orden ===")
	var events: Array[Dictionary] = []
	var on_progress := func(root_index: int, root_total: int, current_dir: String, dirs_visited: int, songs_found: int) -> void:
		events.append({
			"root_index": root_index, "root_total": root_total,
			"current_dir": current_dir, "dirs": dirs_visited, "songs": songs_found,
		})
	SongLoader.scan_progress.connect(on_progress)
	_reset(3, true, MIX)
	_check("begin_scan() arranca", SongLoader.begin_scan())
	_check("is_scanning durante el recorrido", SongLoader.is_scanning)
	_check("un segundo begin_scan() se rechaza", not SongLoader.begin_scan())
	# One directory per batch: the worst case for batch fragmentation.
	var steps: int = 0
	while not SongLoader.scan_step(1) and steps < 5000:
		steps += 1
	SongLoader.scan_progress.disconnect(on_progress)
	_check("el recorrido por lotes termina", SongLoader.is_scanning == false)
	_check("mismas canciones que el de una sentada", SongLoader.song_list == whole)
	_check("mismo orden", _names() == whole_names)
	_check("mismas raices ilegibles", SongLoader.unreadable_roots == whole_unreadable)
	_check("mismas raices truncadas", SongLoader.truncated_roots == whole_truncated)
	_check("nada se marco como cancelado", SongLoader.cancelled_roots.is_empty())
	_check("hubo eventos de progreso", events.size() > 0)
	var monotonic: bool = true
	var in_range: bool = true
	var last_dirs: int = -1
	for e in events:
		if int(e.dirs) <= last_dirs:
			monotonic = false
		last_dirs = int(e.dirs)
		if int(e.root_index) < 1 or int(e.root_index) > int(e.root_total):
			in_range = false
	_check("los directorios recorridos crecen", monotonic)
	_check("root_index siempre dentro del rango", in_range)
	_check("el ultimo evento cuenta todas las canciones", int(events[-1].songs) == whole.size())
	print("  eventos=", events.size(), " steps=", steps)

	print("=== 10. cancelar conserva lo ya encontrado ===")
	# MIX includes a root with 100 songs: a batch is 64 directories, so
	# cancelling halfway lands squarely and leaves songs unseen.
	_reset(3, true, MIX)
	SongLoader.begin_scan()
	SongLoader.scan_step(1)
	SongLoader.scan_step(1)
	var partial: int = SongLoader.song_list.size()
	SongLoader.cancel_scan()
	_check("cancel_scan() no corta en seco", SongLoader.is_scanning)
	_check("el lote siguiente cierra el escaneo", SongLoader.scan_step(64))
	_check("is_scanning se apaga", not SongLoader.is_scanning)
	_check("no se pierden las canciones ya encontradas", SongLoader.song_list.size() >= partial)
	_check("la lista es exactamente el principio del recorrido completo", SongLoader.song_list == whole.slice(0, SongLoader.song_list.size()))
	_check("y se ha quedado corta", SongLoader.song_list.size() < whole.size())
	_check("se anota la raiz a medias en cancelled_roots", SongLoader.cancelled_roots.size() == 1)
	_check("y no como truncada", not SongLoader.truncated_roots.has(SongLoader.cancelled_roots[0] if SongLoader.cancelled_roots.size() > 0 else ""))
	print("  parcial=", partial, "->", SongLoader.song_list.size(), " de ", whole.size(), " ; cancelada=", SongLoader.cancelled_roots)

	print("=== 11. abort_scan() deja SongLoader como estaba ===")
	_reset(3, true, MIX)
	SongLoader.request_scan()
	SongLoader.pump_scan(SongLoader.frame_deadline_usec())
	_check("pump_scan() arranca el escaneo pedido", SongLoader.is_scanning)
	SongLoader.abort_scan()
	_check("abort_scan() apaga is_scanning", not SongLoader.is_scanning)
	_check("y no deja peticiones pendientes", SongLoader.pump_scan(SongLoader.frame_deadline_usec()))

	print("=== 12. el pump de la UI completa el recorrido ===")
	_reset(3, true, MIX)
	SongLoader.request_scan()
	var frames: int = 0
	while not SongLoader.pump_scan(SongLoader.frame_deadline_usec()) and frames < 5000:
		frames += 1
	_check("el pump por frames termina el escaneo", not SongLoader.is_scanning)
	_check("y deja la misma lista", SongLoader.song_list == whole)
	print("  frames=", frames)

	print("=== 13. un reescaneo encolado no pisa el que esta en marcha ===")
	# Reference rescan with a single root, to compare at the end.
	_reset(3, true, PackedStringArray([A]))
	SongLoader.scan_songs()
	var expected: Array[Dictionary] = SongLoader.song_list.duplicate(true)
	var expected_truncated: PackedStringArray = SongLoader.truncated_roots.duplicate()
	_finishes = 0
	var on_finished := func(_songs_found: int, _was_cancelled: bool) -> void:
		_finishes += 1
	SongLoader.scan_finished.connect(on_finished)
	_reset(3, true, PackedStringArray([A]))
	SongLoader.request_scan()
	SongLoader.pump_scan(SongLoader.frame_deadline_usec())
	_check("el primer reescaneo arranca", SongLoader.is_scanning)
	SongLoader.request_scan()
	frames = 0
	while _finishes < 2 and frames < 5000:
		frames += 1
		SongLoader.pump_scan(SongLoader.frame_deadline_usec())
	SongLoader.scan_finished.disconnect(on_finished)
	_check("los dos reescaneos se sirven", _finishes == 2)
	_check("y SongLoader queda libre", not SongLoader.is_scanning)
	_check("con la lista de un reescaneo con una sola raiz", SongLoader.song_list == expected)
	_check("truncated_roots no se duplica al reescanear", SongLoader.truncated_roots == expected_truncated)
	print("  ", SongLoader.truncated_roots)

	print("")
	if _failures == 0:
		print("=== TODAS LAS COMPROBACIONES OK ===")
	else:
		print("=== ", _failures, " FALLOS ===")
	print("=== DONE ===")
	_restore_settings()
	get_tree().quit()
