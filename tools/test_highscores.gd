extends Node

# Verifica HighScoreStore (best scores) y su reflejo en la fila del menu:
#   1. record_score / get_best solo guardan el maximo por cancion+dificultad.
#   2. get_best_for_song devuelve el mejor entre varias dificultades.
#   3. La persistencia sobrevive a una recarga (nuevo store leyendo el fichero).
#   4. MenuRoot muestra ScoreData.format_score(best) en la fila de la cancion,
#      y el placeholder "--,---pts" cuando no hay record.
# Uso: godot --headless --path . res://tools/test_highscores.tscn

const TEST_PATH: String = "res://Songs/Test Song"

var _backup: PackedByteArray = PackedByteArray()
var _existed: bool = false
var _failures: int = 0


func _check(label: String, ok: bool) -> void:
	if ok:
		print("  OK   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)


func _backup_scores() -> void:
	if FileAccess.file_exists(HighScoreStore.SCORES_PATH):
		_existed = true
		var f := FileAccess.open(HighScoreStore.SCORES_PATH, FileAccess.READ)
		_backup = f.get_buffer(f.get_length())
		f.close()


func _restore_scores() -> void:
	if not _existed:
		DirAccess.remove_absolute(HighScoreStore.SCORES_PATH)
		return
	var f := FileAccess.open(HighScoreStore.SCORES_PATH, FileAccess.WRITE)
	f.store_buffer(_backup)
	f.close()


func _ready() -> void:
	_backup_scores()
	# Punto de partida limpio: fichero vacio recargado.
	var empty := FileAccess.open(HighScoreStore.SCORES_PATH, FileAccess.WRITE)
	empty.store_string("")
	empty.close()
	HighScoreStore._load_scores()

	print("== store ==")
	_check("record_score devuelve el valor guardado", HighScoreStore.record_score(TEST_PATH, 60, 3500) == 3500)
	_check("get_best lee el valor guardado", HighScoreStore.get_best(TEST_PATH, 60) == 3500)

	var before: int = HighScoreStore.record_score(TEST_PATH, 60, 3500)
	_check("repetir el mismo score no lo sube", HighScoreStore.get_best(TEST_PATH, 60) == 3500 and before == 3500)
	_check("un score inferior no pisa el record", HighScoreStore.record_score(TEST_PATH, 60, 1200) == 3500 and HighScoreStore.get_best(TEST_PATH, 60) == 3500)
	_check("un score superior si actualiza el record", HighScoreStore.record_score(TEST_PATH, 60, 84500) == 84500 and HighScoreStore.get_best(TEST_PATH, 60) == 84500)
	_check("path vacio se ignora", HighScoreStore.record_score("", 60, 999999) == 0 and HighScoreStore.get_best("", 60) == 0)
	_check("la dificultad es parte de la clave", HighScoreStore.get_best(TEST_PATH, 72) == 0)

	HighScoreStore.record_score(TEST_PATH, 72, 84500)
	HighScoreStore.record_score(TEST_PATH, 96, 400)
	_check("misma cifra en otra dificultad no es un record mayor", HighScoreStore.get_best_for_song(TEST_PATH, [60, 72]) == 84500)
	HighScoreStore.record_score(TEST_PATH, 96, 100000)
	HighScoreStore.record_score(TEST_PATH, 84, 50000)
	print("  best_for_song([84, 96])=", HighScoreStore.get_best_for_song(TEST_PATH, [84, 96]))
	_check("best_for_song toma el maximo entre dificultades", HighScoreStore.get_best_for_song(TEST_PATH, [84, 96]) == 100000)
	_check("best_for_song devuelve 0 sin records", HighScoreStore.get_best_for_song("res://Songs/Otra", [60, 72]) == 0)

	print("== persistencia ==")
	var store2 = load("res://script/autoload/HighScoreStore.gd").new()
	store2._load_scores()
	_check("recarga desde disco: max en 60", store2.get_best(TEST_PATH, 60) == 84500)
	_check("recarga desde disco: max en 96", store2.get_best(TEST_PATH, 96) == 100000)

	print("== fila del menu ==")
	# SongLoader escanea res://Songs en _ready; usamos su primera cancion real.
	if SongLoader.song_list.is_empty():
		SongLoader.scan_songs()
	if SongLoader.song_list.is_empty():
		print("  SKIP no hay canciones escaneadas para probar la fila")
		_restore_scores()
		get_tree().quit(0 if _failures == 0 else 1)
		return
	var song: Dictionary = SongLoader.song_list[0]
	var difficulties: Array = song.get("difficulties", [])
	var menu_score: int = 0
	if not difficulties.is_empty():
		var off: int = int(difficulties[0].offset)
		HighScoreStore.record_score(song.path, off, 777777)
		menu_score = HighScoreStore.get_best_for_song(song.path, difficulties.map(func(d: Dictionary) -> int: return d.offset))

	var menu := preload("res://scene/Main.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	var row := menu.find_child("SongRow_0", true, false)
	var expected: String = (ScoreData.format_score(menu_score) + "pts") if menu_score > 0 else "--,---pts"
	if row == null:
		_check("el menu monta la fila 0", false)
	else:
		var label: Label = (row.get_child(0) as HBoxContainer).get_child(2) as Label
		_check("el menu monta la fila 0 con su label de score", label != null)
		if label:
			print("  fila[0] texto=", label.text)
			_check("la fila muestra el mejor score formateado", label.text == expected)

	# Una cancion sin records debe conservar el placeholder.
	var placeholder_row: Node = menu.find_child("SongRow_1", true, false)
	if placeholder_row == null:
		print("  SKIP no hay una segunda cancion para probar el placeholder")
	else:
		var plabel: Label = (placeholder_row.get_child(0) as HBoxContainer).get_child(2) as Label
		_check("la fila sin record conserva el placeholder", plabel.text == "--,---pts")

	menu.queue_free()
	await get_tree().process_frame

	print("")
	_restore_scores()
	if _failures == 0:
		print("OK: mejores puntuaciones correctas")
	else:
		print(_failures, " comprobaciones fallidas")
	get_tree().quit(1 if _failures > 0 else 0)