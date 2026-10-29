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
	for i in 40:
		SongLoader.song_list.append({
			"path": "/tmp/opencode/fake_song_" + str(i),
			"name": "Song 1 Song 2 " + str(i),
			"artist": "Artist",
			"notes_path": "/tmp/opencode/fake_song_" + str(i) + "/notes.mid",
			"preview_path": "res://asset/drumSfx/kick-a.wav",
			"has_drum_chart": true,
			"song_length": 1000,
			"difficulties": [{"offset": 60, "name": "Easy"}],
		})


func _ready() -> void:
	_populate_songs()
	GameManager.menu_search_text = "Song 1"
	GameManager.menu_scroll_position = 200
	GameManager.menu_selected_song_path = SongLoader.song_list[5].path

	var menu := preload("res://scene/Main.tscn").instantiate()
	add_child(menu)
	for _i in 8:
		await get_tree().process_frame

	_check("el LineEdit nace con la busqueda guardada", menu._search_input.text == "Song 1")
	_check("el filtro usa la busqueda guardada", menu._search_text == "Song 1")
	_check("solo se listan las coincidencias", menu._filtered_indices.size() == 40)
	_check("el scroll vuelve a la posicion guardada", menu._song_list_scroll.scroll_vertical == 200)
	_check("la cancion seleccionada se recupera", menu._selected_song_index == 5)
	_check("su preview se relanza", menu._preview_pending_index == 5)
	var selected_row: PanelContainer = menu.find_child("SongRow_5", true, false)
	var selector: Label = (selected_row.get_child(0) as HBoxContainer).get_child(0) as Label
	_check("la fila recuperada queda marcada", selector.text == "► ")
	_check("las dificultades de la cancion quedan activas", not menu._difficulty_buttons[60].disabled)
	_check("las no disponibles siguen desactivadas", menu._difficulty_buttons[72].disabled)

	menu._on_search_changed("Song 2")
	for _i in 4:
		await get_tree().process_frame
	menu._selected_song_index = 7
	menu._song_list_scroll.scroll_vertical = 160
	for _i in 2:
		await get_tree().process_frame
	menu.queue_free()
	for _i in 4:
		await get_tree().process_frame

	_check("al salir se guarda la busqueda actual", GameManager.menu_search_text == "Song 2")
	_check("al salir se guarda el scroll actual", GameManager.menu_scroll_position == 160)
	_check("al salir se guarda la cancion seleccionada",
		GameManager.menu_selected_song_path == SongLoader.song_list[7].path)

	var menu2 := preload("res://scene/Main.tscn").instantiate()
	add_child(menu2)
	for _i in 8:
		await get_tree().process_frame
	_check("al volver se recupera la busqueda", menu2._search_input.text == "Song 2")
	_check("al volver se recupera el scroll", menu2._song_list_scroll.scroll_vertical == 160)
	_check("al volver se recupera la seleccion", menu2._selected_song_index == 7)
	_check("al volver se relanza el preview", menu2._preview_pending_index == 7)

	menu2.queue_free()
	await get_tree().process_frame
	print("FALLOS: ", _failures)
	get_tree().quit(0 if _failures == 0 else 1)
