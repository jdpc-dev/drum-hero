extends Node

# Test de integracion del fin de cancion sobre la escena real de gameplay.
# Comprueba la cadena completa:
#   carga de cancion -> countdown -> audio hasta el final -> song_ended ->
#   cola de 1.5 s -> estado RESULT -> ResultOverlay visible en pantalla.
# Uso: godot --headless --path . res://tools/test_song_end_e2e.tscn

const SONG_DIR: String = "res://Songs/Republica - Ready to Go"
const NOTES_OFFSET: int = 3
const SEEK_MARGIN: float = 1.0

var _failures: int = 0
var _gameplay: Node

var _scores_backup: PackedByteArray = PackedByteArray()
var _scores_existed: bool = false


func _check(label: String, ok: bool) -> void:
	if ok:
		print("  OK   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)


func _backup_scores() -> void:
	if FileAccess.file_exists(HighScoreStore.SCORES_PATH):
		_scores_existed = true
		var f := FileAccess.open(HighScoreStore.SCORES_PATH, FileAccess.READ)
		_scores_backup = f.get_buffer(f.get_length())
		f.close()


func _restore_scores() -> void:
	if not _scores_existed:
		DirAccess.remove_absolute(HighScoreStore.SCORES_PATH)
		return
	var f := FileAccess.open(HighScoreStore.SCORES_PATH, FileAccess.WRITE)
	f.store_buffer(_scores_backup)
	f.close()


func _ready() -> void:
	if not DirAccess.dir_exists_absolute(SONG_DIR):
		print("  SKIP no hay cancion de prueba en ", SONG_DIR)
		get_tree().quit(0)
		return

	GameManager.current_song_path = SONG_DIR
	GameManager.current_song_title = "Ready to Go"
	GameManager.current_song_artist = "Republica"
	GameManager.current_difficulty_name = "Experto"
	GameManager.current_difficulty_offset = NOTES_OFFSET
	GameManager.current_song_delay = 0.0
	GameManager.current_song_length = 341.542

	_backup_scores()

	var scene: PackedScene = load("res://scene/Gameplay.tscn")
	_gameplay = scene.instantiate()
	add_child(_gameplay)
	print("== gameplay real ==")

	# La escena carga chart y audio en segundo plano: esperamos a que arranque.
	var waited: int = 0
	while GameManager.state != GameManager.GameState.PLAYING and waited < 3000:
		await get_tree().process_frame
		waited += 1
	_check("el gameplay llega a PLAYING", GameManager.state == GameManager.GameState.PLAYING)
	if GameManager.state != GameManager.GameState.PLAYING:
		print("estado atascado en ", GameManager.state)
		_finish()
		return
	_check("el audio se cargo", AudioManager.loaded_any())
	_check("hay duracion de chart", TimingEngine.chart_duration > 1.0)
	print("  chart_duration=", TimingEngine.chart_duration, " audio_len=", AudioManager.get_length())

	# El countdown no debe bloquear el reloj: esperamos a que el reloj corra.
	waited = 0
	while TimingEngine.get_time() <= 0.05 and waited < 600:
		await get_tree().process_frame
		waited += 1
	_check("el reloj avanza durante el gameplay", TimingEngine.get_time() > 0.0)
	_check("no hay overlay de resultados antes de tiempo", _gameplay.find_child("ResultOverlay", true, false) == null)

	# Aceleramos el final: nos dejamos un segundo de musica. Simulamos unas notas
	# para que el score final no sea 0 y el record guardado sea significativo.
	ScoreManager.register_hit(0.0)
	ScoreManager.register_hit(0.0)
	var info = AudioManager._stems.get(AudioManager._base_stem_name())
	if info == null:
		_check("el stem base existe", false)
		_finish()
		return
	var player: AudioStreamPlayer = info.player
	player.seek(player.stream.get_length() - SEEK_MARGIN)

	# song_ended + cola de RESULT_TAIL_DELAY + un par de frames.
	var elapsed: float = 0.0
	while elapsed < 12.0 and GameManager.state != GameManager.GameState.RESULT:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1

	_check("el estado pasa a RESULT al acabar la cancion", GameManager.state == GameManager.GameState.RESULT)
	var overlay: Node = _gameplay.find_child("ResultOverlay", true, false)
	_check("el overlay de resultados aparece en pantalla", overlay != null)
	_check("el reloj queda congelado al final", is_equal_approx(TimingEngine.get_time(), TimingEngine.chart_duration))
	var stored: int = HighScoreStore.get_best(GameManager.current_song_path, GameManager.current_difficulty_offset)
	_check("el record de la cancion se guarda al terminar", stored == ScoreManager.score)
	_check("el record guardado no es 0", stored > 0)
	if overlay == null:
		_finish()
		return

	# El panel tiene que mostrar los datos de la partida y sus botones deben
	# funcionar de verdad (REPLAY vuelve a jugar, EXIT limpia el overlay).
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var bg: ColorRect = overlay.get_node_or_null("ResultBg") as ColorRect
	var panel: Control = overlay.get_node_or_null("ResultPanel") as Control
	_check("el panel se dibuja por encima del HUD", (overlay as CanvasLayer).layer == 15)
	_check("el fondo tapa la pantalla entera", bg != null and bg.size.x >= vp.x - 1.0 and bg.size.y >= vp.y - 1.0)
	_check("el panel cabe dentro de la pantalla", panel != null and panel.position.x >= 0.0 and panel.position.x + panel.size.x <= vp.x + 1.0 and panel.position.y >= 0.0)
	_check("el panel esta centrado horizontalmente", panel != null and absf(panel.position.x + panel.size.x * 0.5 - vp.x * 0.5) < 2.0)
	_check("el panel tiene contenido visible", panel != null and panel.get_combined_minimum_size().y < vp.y and panel.size.y > 0.0)
	var score_label: Label = overlay.find_child("ScoreValue", true, false) as Label
	_check("el panel muestra el score", score_label != null and score_label.text == ScoreData.format_score(ScoreManager.score))
	var song_label: Label = overlay.find_child("SongLabel", true, false) as Label
	_check("el panel muestra la cancion", song_label != null and song_label.text.contains("Ready to Go"))

	var retry_btn: Button = overlay.get_node_or_null("ResultPanel/RetryButton") as Button
	_check("el panel tiene boton de replay", retry_btn != null)
	if retry_btn != null:
		retry_btn.pressed.emit()
		elapsed = 0.0
		while elapsed < 10.0 and GameManager.state != GameManager.GameState.PLAYING:
			await get_tree().create_timer(0.1).timeout
			elapsed += 0.1
		await get_tree().process_frame
		_check("REPLAY vuelve a jugar", GameManager.state == GameManager.GameState.PLAYING)
		_check("REPLAY quita el panel de resultados", _gameplay.find_child("ResultOverlay", true, false) == null)
		_check("REPLAY rearma el reloj", TimingEngine.get_time() < 5.0)
		_finish()
		return

	_finish()


func _finish() -> void:
	if _gameplay != null:
		_gameplay.queue_free()
		_gameplay = null
	# Los players de AudioManager son un autoload: sin soltarlos, el proceso se
	# va con los streams ogg cargados todavia y Godot avisa de fugas al salir.
	AudioManager._clear_stems()
	# El test pisa user://scores.cfg al guardar el record de prueba.
	_restore_scores()
	await get_tree().process_frame
	if _failures == 0:
		print("\nOK: fin de cancion correcto en la escena real")
	else:
		print("\n", _failures, " comprobaciones fallidas en la escena real")
	get_tree().quit(1 if _failures > 0 else 0)
