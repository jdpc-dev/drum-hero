extends Node

# Verifica el fin de cancion:
#   1. song_ended se emite una sola vez al cruzar chart_duration.
#   2. El ultimo time_updated lleva el valor exacto de fin de cancion.
#   3. Tras stop() el reloj NO sigue sumando delta: la barra de tiempo se queda
#      al 100 % en vez de volver a llenarse desde cero.
#   4. start() rearma el reloj (no queda pegado en finished).
#   5. ResultOverlay vuelca los stats de ScoreManager.
#   6. Con audio real: el fin de stream se detecta aunque
#      get_playback_position() vuelva a 0 al acabar (el bug que dejaba la
#      cancion sin terminar nunca) y la pausa no lo dispara.
# Uso: godot --headless --path . res://tools/test_song_end.tscn


class ProbeTimeline extends SongTimeline:
	pass


# Las lambdas de GDScript capturan las variables locales por valor, asi que los
# contadores de senal viven aqui, no en locales de _ready().
var _failures: int = 0
var _song_ended_count: int = 0
var _retry_count: int = 0
var _exit_count: int = 0

var _timeline: ProbeTimeline
var _fill: ColorRect


func _check(label: String, ok: bool) -> void:
	if ok:
		print("  OK   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)


func _ready() -> void:
	# La calibracion global desplazaria audio_position al arrancar start().
	SettingsManager.audio_offset_ms = 0.0
	TimingEngine.song_ended.connect(_on_song_ended_probe)
	await _build_timeline_probe()
	# El caso de reloj se repite: asi un fallo que solo se manifieste en un
	# frame suelto (un delta enorme en headless) no puede colarse.
	for attempt in 2:
		print("\n== reloj, intento ", attempt + 1, " ==")
		await _run_clock_case()
	print("\n== overlay ==")
	await _run_overlay_case()
	print("\n== audio real ==")
	await _run_real_audio_case()
	if _failures == 0:
		print("\nOK: fin de cancion correcto")
	else:
		printerr("\n%d comprobaciones fallidas" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _on_song_ended_probe() -> void:
	_song_ended_count += 1


func _on_retry_probe() -> void:
	_retry_count += 1


func _on_exit_probe() -> void:
	_exit_count += 1


func _build_timeline_probe() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	_timeline = ProbeTimeline.new()
	_timeline.anchor_right = 1.0
	root.add_child(_timeline)
	await get_tree().process_frame
	_fill = _timeline.get_node("Fill") as ColorRect


# No hay audio cargado en el test, asi que el reloj avanza con delta: sirve para
# comprobar el mismo final de cancion que en el juego.
func _run_clock_case() -> void:
	_song_ended_count = 0
	TimingEngine.start(0.05)
	await _wait_for_song_end(0)
	_check("song_ended se emite al terminar la cancion", _song_ended_count == 1)
	_check("el reloj se detiene en chart_duration", is_equal_approx(TimingEngine.get_time(), 0.05))

	# song_ended no debe reemitirse: se dejan pasar muchos frames mas.
	for i in 30:
		await get_tree().process_frame
	_check("song_ended solo se emite una vez", _song_ended_count == 1)
	_check("el reloj sigue congelado", is_equal_approx(TimingEngine.get_time(), 0.05))
	_check("barra al 100 %", absf(_fill.size.x - _timeline.size.x) < 1.0)

	# El bug reportado: stop() dejaba el reloj sumando delta y la barra se
	# rellenaba otra vez por debajo de la pantalla de resultados.
	TimingEngine.stop()
	var frozen: float = TimingEngine.get_time()
	for i in 60:
		await get_tree().process_frame
	_check("tras stop() el reloj no avanza", is_equal_approx(TimingEngine.get_time(), frozen))
	_check("tras stop() la barra no se vacia", absf(_fill.size.x - _timeline.size.x) < 1.0)
	_check("song_ended no se reemite por stop()", _song_ended_count == 1)

	# Replay: start() tiene que rearmar el reloj. Se usa una cancion mas larga
	# para que el rearmado sea observable sin depender de como de grande es el
	# delta de un frame suelto en headless.
	var ticks: Array[float] = []
	var probe := func(t: float) -> void: ticks.append(t)
	TimingEngine.start(0.5)
	TimingEngine.time_updated.connect(probe)
	for i in 5:
		await get_tree().process_frame
	TimingEngine.time_updated.disconnect(probe)
	_check("start() rearma el reloj: vuelve a emitir tiempo", not ticks.is_empty())
	_check("la nueva cancion vuelve a contar desde 0", not ticks.is_empty() and ticks[0] >= 0.0 and ticks[0] < 0.5)
	await _wait_for_song_end(1)
	_check("la segunda cancion tambien termina", _song_ended_count == 2)
	_check("el reloj vuelve a terminar en chart_duration", is_equal_approx(TimingEngine.get_time(), 0.5))


# Espera frames hasta que song_ended haya saltado expected_count + 1 veces.
func _wait_for_song_end(expected_count: int) -> void:
	var waited: int = 0
	while _song_ended_count < expected_count + 1 and waited < 3000:
		await get_tree().process_frame
		waited += 1


func _run_overlay_case() -> void:
	ScoreManager.reset()
	ScoreManager.register_hit(0.01)
	ScoreManager.register_hit(0.02)
	ScoreManager.register_hit(0.0)
	ScoreManager.register_miss()
	GameManager.current_song_title = "Test Song"
	GameManager.current_song_artist = "Test Artist"
	GameManager.current_difficulty_name = "Expert"

	var overlay := ResultOverlay.new()
	add_child(overlay)
	await get_tree().process_frame

	_check("el panel monta su fondo", overlay.get_node_or_null("ResultBg") != null)
	_check("el panel monta el boton de replay", overlay.get_node_or_null("ResultPanel/RetryButton") is Button)
	_check("el panel monta el boton de salir", overlay.get_node_or_null("ResultPanel/ExitButton") is Button)

	var score_label: Label = _find_value_label(overlay, "ScoreValue")
	var accuracy_label: Label = _find_value_label(overlay, "AccuracyValue")
	var combo_label: Label = _find_value_label(overlay, "MaxComboValue")
	var counts_label: Label = _find_value_label(overlay, "NotesValue")
	var song_label: Label = _find_value_label(overlay, "SongLabel")
	if score_label == null or accuracy_label == null or combo_label == null or counts_label == null or song_label == null:
		_check("el panel monta todas las filas de stats", false)
		overlay.queue_free()
		await get_tree().process_frame
		return
	print("  score=", score_label.text, "  accuracy=", accuracy_label.text, "  combo=", combo_label.text, "  notas=", counts_label.text)
	_check("score con separador de miles", score_label.text == ScoreData.format_score(ScoreManager.score))
	_check("precision calculada", accuracy_label.text == "%.1f %%" % ScoreManager.get_accuracy_pct())
	_check("combo maximo", combo_label.text == str(ScoreManager.max_combo) + "x")
	_check("hits y misses", counts_label.text == str(ScoreManager.hits) + " hit / " + str(ScoreManager.misses) + " miss")
	_check("titulo de la cancion", song_label.text == "Test Artist - Test Song  (Expert)")

	_retry_count = 0
	_exit_count = 0
	overlay.retry_requested.connect(_on_retry_probe)
	overlay.exit_requested.connect(_on_exit_probe)
	(overlay.get_node("ResultPanel/RetryButton") as Button).pressed.emit()
	(overlay.get_node("ResultPanel/ExitButton") as Button).pressed.emit()
	_check("el boton de replay emite retry_requested", _retry_count == 1)
	_check("el boton de salir emite exit_requested", _exit_count == 1)

	# El panel se construye con el estado ya volcado; refrescar despues de un
	# reset lo vuelve a leer, que es lo que permite reusarlo.
	ScoreManager.reset()
	overlay.refresh()
	_check("refresh() vuelve a leer ScoreManager", _find_value_label(overlay, "ScoreValue").text == ScoreData.format_score(0))

	overlay.queue_free()
	await get_tree().process_frame


func _find_value_label(overlay: ResultOverlay, name: String) -> Label:
	return overlay.find_child(name, true, false) as Label


# Caso con audio de verdad. Reproduce el fallo original: al acabar el stream,
# Godot reinicia get_playback_position() a 0, asi que un detector que mire la
# posicion nunca ve el final y la cancion se queda colgada.
func _run_real_audio_case() -> void:
	var song_path: String = "res://Songs/Republica - Ready to Go"
	if not DirAccess.dir_exists_absolute(song_path):
		print("  SKIP no hay cancion de prueba en ", song_path)
		return
	if not AudioManager.load_stems(song_path):
		print("  SKIP no se pudieron cargar los stems de prueba")
		return
	var info = AudioManager._stems.get(AudioManager._base_stem_name())
	if info == null or info.player == null:
		print("  SKIP el stem base no existe")
		AudioManager._clear_stems()
		return
	var player: AudioStreamPlayer = info.player
	var length: float = AudioManager.get_length()
	_check("los stems se cargan y el stem base tiene longitud", length > 1.0)

	var baseline: int = _song_ended_count
	TimingEngine.start(length)
	await get_tree().create_timer(0.3).timeout
	var pos_before_pause: float = AudioManager.get_position()

	# La pausa no puede acabar la cancion: player.stop() no emite finished.
	TimingEngine.pause()
	await get_tree().create_timer(0.2).timeout
	var clock_paused: float = TimingEngine.get_time()
	_check("pausar no dispara el fin de cancion", _song_ended_count == baseline)
	await get_tree().process_frame
	_check("la pausa congela el reloj", is_equal_approx(TimingEngine.get_time(), clock_paused))

	TimingEngine.resume()
	await get_tree().create_timer(0.3).timeout
	_check("el reloj sigue vivo tras reanudar", _song_ended_count == baseline and TimingEngine.get_time() > clock_paused)
	_check("el audio continua desde donde estaba", AudioManager.get_position() >= pos_before_pause)

	# Aceleramos el final real: nos colocamos a un segundo del fin.
	player.seek(length - 1.0)
	await _wait_for_song_end(baseline)
	_check("con audio real song_ended se emite al acabar el stream", _song_ended_count == baseline + 1)
	_check("el reloj termina en chart_duration", is_equal_approx(TimingEngine.get_time(), length))
	_check("el stream queda marcado como acabado", AudioManager.is_stream_finished())

	# Reproducir tras el fin debe rearmar el latch y volver a terminar.
	TimingEngine.start(length)
	_check("start() rearma el latch del stream", not AudioManager.is_stream_finished())
	player.seek(length - 1.0)
	await _wait_for_song_end(baseline + 1)
	_check("la segunda pasada con audio vuelve a terminar", _song_ended_count == baseline + 2)

	TimingEngine.stop()
	AudioManager._clear_stems()
