extends Node

var _failures: int = 0


func _check(label: String, ok: bool) -> void:
	if ok:
		print("  OK   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)


func _populate_songs() -> void:
	SongLoader.song_list.clear()
	var songs: Array[Dictionary] = [
		{
			"path": "/tmp/opencode/async_song_0",
			"name": "Async 0",
			"artist": "Artist",
			"notes_path": "/tmp/opencode/async_song_0/notes.mid",
			"preview_path": "res://asset/drumSfx/vel2pad8smp0.ogg",
			"has_drum_chart": true,
			"song_length": 1000,
			"difficulties": [{"offset": 60, "name": "Easy"}],
		},
		{
			"path": "/tmp/opencode/async_song_1",
			"name": "Async 1",
			"artist": "Artist",
			"notes_path": "/tmp/opencode/async_song_1/notes.mid",
			"preview_path": "res://asset/drumSfx/vel4pad5smp0.ogg",
			"has_drum_chart": true,
			"song_length": 1000,
			"difficulties": [{"offset": 60, "name": "Easy"}],
		},
		{
			"path": "/tmp/opencode/async_song_2",
			"name": "Async 2",
			"artist": "Artist",
			"notes_path": "/tmp/opencode/async_song_2/notes.mid",
			"preview_path": "res://asset/drumSfx/vel2pad8smp0.ogg",
			"album_path": "res://songs/Godsmack - Voodoo/album.png",
			"has_drum_chart": true,
			"song_length": 1000,
			"difficulties": [{"offset": 60, "name": "Easy"}],
		},
	]
	SongLoader.song_list.assign(songs)


func _slow_work() -> void:
	OS.delay_msec(600)


func _slow_thread() -> Thread:
	var thread := Thread.new()
	thread.start(_slow_work)
	return thread


func _wait_until_loaded(menu: MenuRoot, frames: int = 90) -> bool:
	for _i in frames:
		await get_tree().process_frame
		if menu._preview_loaded_stream != null:
			return true
	return menu._preview_loaded_stream != null


func _ready() -> void:
	_populate_songs()
	var menu := preload("res://scene/Main.tscn").instantiate() as MenuRoot
	add_child(menu)
	for _i in 8:
		await get_tree().process_frame

	print("=== 1. la carga del preview no bloquea la seleccion ===")
	var started: int = Time.get_ticks_msec()
	menu._select_song(0)
	var select_ms: int = Time.get_ticks_msec() - started
	_check("elegir una cancion vuelve sin decodificar audio", select_ms < 250)
	# The first _process() starts the worker; the next one only reaps it.
	menu._process(0.016)
	_check("el preview se carga en un hilo", menu._preview_thread != null)
	_check("el preview acaba cargando", await _wait_until_loaded(menu))

	print("=== 2. parar el preview no espera al hilo en curso ===")
	menu._stop_preview(true)
	var slow := _slow_thread()
	menu._preview_thread = slow
	menu._preview_thread_path = "/tmp/opencode/slow_preview.ogg"
	started = Time.get_ticks_msec()
	menu._stop_preview()
	_check("_stop_preview no bloquea", Time.get_ticks_msec() - started < 250)
	_check("el hilo sigue vivo despues de parar", slow.is_alive())
	started = Time.get_ticks_msec()
	menu._process(0.016)
	_check("_process no espera a un hilo vivo", Time.get_ticks_msec() - started < 250)

	print("=== 3. una seleccion en cola espera y luego carga ===")
	menu._select_song(1)
	_check("la seleccion espera al hilo en curso", menu._preview_thread == slow)
	await get_tree().create_timer(0.7).timeout
	for _i in 8:
		await get_tree().process_frame
	_check("el hilo terminado se recoge", menu._preview_thread != slow)
	_check("la seleccion en cola carga su preview", await _wait_until_loaded(menu))

	print("=== 4. la portada se decodifica fuera del hilo principal ===")
	menu._stop_preview(true)
	started = Time.get_ticks_msec()
	menu._select_song(2)
	var album_ms: int = Time.get_ticks_msec() - started
	_check("elegir una cancion con portada no bloquea", album_ms < 250)
	_check("la portada se carga en un hilo", menu._album_art_thread != null)
	for _i in 90:
		await get_tree().process_frame
		if menu._album_art.texture != null:
			break
	_check("la portada termina aplicandose", menu._album_art.texture != null)
	_check("la portada queda en la cache",
		menu._album_art_cache.has("res://songs/Godsmack - Voodoo/album.png"))

	print("=== 5. los stems de fallback tambien se cargan en un hilo ===")
	menu._stop_preview(true)
	SongLoader.song_list.append({
		"path": "res://songs/Godsmack - Voodoo",
		"name": "Stem fallback",
		"artist": "Artist",
		"notes_path": "res://songs/Godsmack - Voodoo/notes.mid",
		"preview_path": "",
		"preview_start_time": 0,
		"has_drum_chart": true,
		"song_length": 1000,
		"difficulties": [{"offset": 60, "name": "Easy"}],
	})
	var stem_index: int = SongLoader.song_list.size() - 1
	menu._rebuild_filtered_list()
	menu._select_song(stem_index)
	_check("el fallback carga el preview principal", await _wait_until_loaded(menu))
	for _i in 120:
		await get_tree().process_frame
		if menu._preview_stem_thread != null or not menu._preview_stem_players.is_empty():
			break
	_check("los stems se cargan en un hilo",
		menu._preview_stem_thread != null or not menu._preview_stem_players.is_empty())
	for _i in 120:
		await get_tree().process_frame
		if not menu._preview_stem_players.is_empty():
			break
	_check("los stems terminan aplicandose", not menu._preview_stem_players.is_empty())
	menu._stop_preview(true)

	menu.queue_free()
	for _i in 4:
		await get_tree().process_frame
	print("FALLOS: ", _failures)
	get_tree().quit(0 if _failures == 0 else 1)
