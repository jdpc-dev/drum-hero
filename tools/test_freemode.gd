extends Node

# Free mode test (Settings > Controls > Open Free Mode).
# Checks that the scene sets up the real Highway, that ChartParser is cleared,
# that each hit plays/lights up without a chart, and that the Settings button
# is wired to the menu.
# Usage: godot --headless --path . res://tools/test_freemode.tscn

const FREE_MODE_SCENE := "res://scene/FreeMode.tscn"
const HIGHWAY_SCENE := "res://scene/UI/Highway.tscn"

var _failures: int = 0
var _free_mode: FreeModeRoot


func _check(label: String, ok: bool) -> void:
	if ok:
		print("  OK   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)


# ChartParser is an autoload and survives scene changes. Free mode must clear it
# itself: otherwise, the last song's notes would keep falling down the track and
# be counted as missed instantly.
func _seed_stale_chart() -> void:
	for i in 40:
		var ev := ChartData.NoteEvent.new(i * 480, i % 8, ChartData.NoteType.NORMAL)
		ev.time = 0.05 * i
		ChartParser.note_data.append(ev)
	ChartParser._tempo_map.append(ChartData.TempoEvent.new(0, 120.0, 500000.0, 500000.0))
	ChartParser._time_signature_map.append(ChartData.TimeSignatureEvent.new(0, 4, 4))
	ChartParser._expected_duration = 300.0


func _ready() -> void:
	SettingsManager.game_mode = 0
	GameManager.mode = GameManager.GameMode.DEFAULT

	print("=== 1. ChartParser.clear() vacia el estado heredado ===")
	_seed_stale_chart()
	_check("el chart sembrado tiene notas", ChartParser.note_data.size() == 40)
	ChartParser.clear()
	_check("no quedan notas", ChartParser.note_data.is_empty())
	_check("no queda mapa de tempo", ChartParser.get_tempo_events().is_empty())
	_check("no quedan firmas de compas", ChartParser.get_time_signature_events().is_empty())
	_check("no queda duracion esperada", ChartParser.get_duration_seconds() == 0.0)
	_check("no hay chart que recorrer", ChartParser.has_data() == false)

	print("=== 2. la escena del free mode monta la Highway real ===")
	# A stale chart is seeded BEFORE instantiating: if FreeModeRoot did not
	# clear it, these notes would appear and fail on their own.
	_seed_stale_chart()
	var scene: PackedScene = load(FREE_MODE_SCENE)
	_check("la escena existe", scene != null)
	_free_mode = scene.instantiate() as FreeModeRoot
	add_child(_free_mode)
	await get_tree().process_frame
	await get_tree().process_frame

	var highway: Highway = _free_mode.get_node_or_null("Highway") as Highway
	_check("hay nodo Highway", highway != null)
	_check("la Highway construye 8 pistas", highway != null and highway.lane_nodes.size() == 8)
	_check("no reserva la banda del timeline", highway != null and is_zero_approx(highway.highway_top_y))
	_check("el estado pasa a PLAYING", GameManager.state == GameManager.GameState.PLAYING)
	_check("el chart quedo limpio al entrar", ChartParser.note_data.is_empty())

	print("=== 3. las pistas heredan el modo de control ===")
	_check("modo DEFAULT = 8 pistas en orden", _lane_order(highway) == [0, 1, 2, 3, 4, 5, 6, 7])
	_check("cada pista tiene su zona tactil", _count_touch_zones(highway) == 8)
	_check("cada pista tiene etiqueta", _count_lane_labels(highway) == 8)
	_check("hay linea de golpeo", highway != null and highway.hit_line_ref != null)

	print("=== 3b. las zonas tactiles comparten bordes enteros ===")
	# 1350 px is the highway width of the mobile test device (1650 minus the
	# 150 px gameplay padding on both sides). With 8 or 7 lanes the shared
	# edges fall on fractions, which used to double-blend a 1 px seam.
	for lane_count in [8, 7]:
		var lane_width: float = 1350.0
		var previous_right: float = 0.0
		var whole_pixels: bool = true
		var tiles: bool = true
		for i in range(lane_count):
			var bounds: Vector2 = Highway.touch_zone_bounds(i, lane_count, lane_width)
			if not is_equal_approx(bounds.x, roundf(bounds.x)):
				whole_pixels = false
			if not is_equal_approx(bounds.y, roundf(bounds.y)):
				whole_pixels = false
			if not is_equal_approx(previous_right, bounds.x):
				tiles = false
			previous_right = bounds.y
		_check("con %d pistas los bordes caen en pixeles enteros" % lane_count, whole_pixels)
		_check("con %d pistas las zonas tactiles no se solapan" % lane_count, tiles)
		_check("con %d pistas las zonas cubren todo el ancho" % lane_count,
			is_zero_approx(Highway.touch_zone_bounds(0, lane_count, lane_width).x)
			and is_equal_approx(previous_right, lane_width))

	print("=== 4. en HAPTIC la pista del kick sale aparte ===")
	GameManager.mode = GameManager.GameMode.HAPTIC
	var probe: Highway = (load(HIGHWAY_SCENE) as PackedScene).instantiate() as Highway
	add_child(probe)
	await get_tree().process_frame
	var haptic_order: Array = _lane_order(probe)
	_check("modo HAPTIC = 7 pistas", haptic_order.size() == 7)
	_check("modo HAPTIC saca la pista del kick de la fila", not haptic_order.has(3))
	_check("modo HAPTIC anade la pista de kick aparte", probe.get_kick_lane() != null)

	var haptic_kick_lane: Lane = probe.get_kick_lane()
	haptic_kick_lane._highlight()
	haptic_kick_lane._update_highlight(0.0)
	var slash_left: float = haptic_kick_lane._slash_center_x - haptic_kick_lane._slash_lw * 0.5
	var slash_right: float = haptic_kick_lane._slash_center_x + haptic_kick_lane._slash_lw * 0.5
	_check("el slash del kick cubre toda la autopista",
		is_zero_approx(slash_left) and is_equal_approx(slash_right, probe.screen_w))
	_check("el slash del kick arranca sobre la banda del timeline",
		is_zero_approx(haptic_kick_lane._slash_top_y)
		and is_equal_approx(haptic_kick_lane._slash_bg_h, probe.highway_bottom_y))

	var kick_note: Note = (load("res://scene/UI/Note.tscn") as PackedScene).instantiate() as Note
	kick_note.lane_ref = haptic_kick_lane
	haptic_kick_lane.add_child(kick_note)
	var kick_event := ChartData.NoteEvent.new(0, 3, ChartData.NoteType.NORMAL)
	kick_event.time = 0.0
	kick_note.reset(kick_event)
	_check("la nota del kick sigue ocupando toda la autopista", kick_note._is_kick_full_width)
	kick_note.queue_free()

	var haptic_keys := TouchInput.new()
	add_child(haptic_keys)
	haptic_keys.setup(probe, null)
	var haptic_key_hits: Array = []
	haptic_keys.lane_pressed.connect(func(lane_index: int, _position: Vector2) -> void:
		haptic_key_hits.append(lane_index)
	)
	for i in 8:
		var key_event := InputEventKey.new()
		key_event.keycode = KEY_1 + i
		key_event.pressed = true
		haptic_keys._unhandled_input(key_event)
	_check("en HAPTIC las teclas 1-7 siguen las columnas visibles", haptic_key_hits == [0, 1, 2, 4, 5, 6, 7])
	haptic_keys.queue_free()
	probe.queue_free()
	GameManager.mode = GameManager.GameMode.DEFAULT
	await get_tree().process_frame

	print("=== 4b. CUSTOM usa el orden editable y tolera datos invalidos ===")
	var saved_lanes: Array = SettingsManager.custom_lanes.duplicate()
	SettingsManager.custom_lanes = [3, 2, 1, 0, 7, 6, 5, 4]
	GameManager.mode = GameManager.GameMode.CUSTOM
	var custom_probe: Highway = (load(HIGHWAY_SCENE) as PackedScene).instantiate() as Highway
	add_child(custom_probe)
	await get_tree().process_frame
	_check("modo CUSTOM respeta el orden guardado", _lane_order(custom_probe) == [3, 2, 1, 0, 7, 6, 5, 4])
	_check("modo CUSTOM mantiene las 8 pistas", custom_probe.lane_nodes.size() == 8)

	var key_input := TouchInput.new()
	add_child(key_input)
	key_input.setup(custom_probe, null)
	var key_hits: Array = []
	key_input.lane_pressed.connect(func(lane_index: int, _position: Vector2) -> void:
		key_hits.append(lane_index)
	)
	for i in 8:
		var key_event := InputEventKey.new()
		key_event.keycode = KEY_1 + i
		key_event.pressed = true
		key_input._unhandled_input(key_event)
	_check("las teclas 1-8 siguen el orden visual", key_hits == [3, 2, 1, 0, 7, 6, 5, 4])
	key_input.queue_free()
	custom_probe.queue_free()

	SettingsManager.custom_lanes = []
	var empty_probe: Highway = (load(HIGHWAY_SCENE) as PackedScene).instantiate() as Highway
	add_child(empty_probe)
	await get_tree().process_frame
	_check("sin orden guardado usa el orden estandar", _lane_order(empty_probe) == [0, 1, 2, 3, 4, 5, 6, 7])
	empty_probe.queue_free()

	SettingsManager.custom_lanes = [0, 0, 1, 2, 3, 4, 5, 9]
	var invalid_probe: Highway = (load(HIGHWAY_SCENE) as PackedScene).instantiate() as Highway
	add_child(invalid_probe)
	await get_tree().process_frame
	_check("un orden invalido vuelve al orden estandar", _lane_order(invalid_probe) == [0, 1, 2, 3, 4, 5, 6, 7])
	_check("no se construyen pistas de mas", invalid_probe.lane_nodes.size() == 8)
	invalid_probe.queue_free()
	_check("un orden con pistas repetidas no es valido",
		not SettingsManager.is_valid_lane_order([0, 0, 1, 2, 3, 4, 5, 6]))
	_check("una permutacion de las 8 pistas es valida",
		SettingsManager.is_valid_lane_order([7, 6, 5, 4, 3, 2, 1, 0]))

	SettingsManager.custom_lanes = saved_lanes
	GameManager.mode = GameManager.GameMode.DEFAULT
	await get_tree().process_frame

	print("=== 4c. el editor horizontal reordena al arrastrar ===")
	var row := LaneOrderRow.new()
	add_child(row)
	row.size = Vector2(800, 120)
	row.set_order([0, 1, 2, 3, 4, 5, 6, 7])
	var emitted: Array = []
	row.order_changed.connect(func(order: Array) -> void: emitted.append(order))
	row._begin(Vector2(50, 60))
	row._update_drag(Vector2(250, 60))
	row._end(Vector2(250, 60))
	_check("arrastrar una pista la mueve a la posicion destino",
		row.get_order() == [1, 2, 0, 3, 4, 5, 6, 7])
	_check("el editor emite el orden una sola vez", emitted.size() == 1)

	row.set_order([0, 1, 2, 3, 4, 5, 6, 7])
	row._begin(Vector2(50, 60))
	row._update_drag(Vector2(50, 110))
	row._end(Vector2(50, 110))
	_check("un gesto vertical no reordena (deja pasar el scroll)",
		row.get_order() == [0, 1, 2, 3, 4, 5, 6, 7])
	row.queue_free()
	await get_tree().process_frame

	print("=== 5. tocar un pad da feedback sin chart ===")
	var touch_input: TouchInput = _free_mode.get_node_or_null("TouchInput") as TouchInput
	_check("hay nodo TouchInput", touch_input != null)
	_check("TouchInput expone lane_pressed", touch_input.has_signal("lane_pressed"))
	_check("TouchInput se monto sin deteccion de hits", touch_input._hit_detection == null)
	_check("hay HUD", _free_mode.get_node_or_null("HUD") != null)

	var pad_label: Label = _free_mode.find_child("PadNameLabel", true, false) as Label
	var hits_label: Label = _free_mode.find_child("HitsLabel", true, false) as Label
	_check("el HUD tiene el cartel del pad", pad_label != null)
	_check("el HUD tiene el contador de golpes", hits_label != null)

	touch_input.lane_pressed.emit(2, Vector2(100, 100))
	await get_tree().process_frame
	_check("el total de golpes sube", _free_mode._total_hits == 1)
	_check("el HUD nombra el pad (SNARE)", pad_label != null and pad_label.text == "SNARE")
	_check("el golpe lanza particulas", _count_effects(_free_mode) > 0)

	touch_input.lane_pressed.emit(3, Vector2.ZERO)
	await get_tree().process_frame
	_check("el kick tambien cuenta", _free_mode._total_hits == 2)
	_check("el HUD cambia a KICK", pad_label != null and pad_label.text == "KICK")
	_check("el HUD muestra el contador", hits_label != null and hits_label.text.contains("2"))

	print("=== 5a. el debug haptico sigue al ajuste ===")
	var previous_debug: bool = SettingsManager.haptic_show_debug
	SettingsManager.haptic_show_debug = false
	_free_mode._process(0.0)
	_check("apagado no hay overlay", _free_mode._debug_label == null)
	SettingsManager.haptic_show_debug = true
	_free_mode._process(0.0)
	var debug_label: Label = _free_mode.find_child("DebugLabel", true, false) as Label
	_check("encendido aparece el overlay", debug_label != null)
	_check("el overlay muestra el estado haptico",
		debug_label != null and debug_label.text.contains("HAPTIC DEBUG"))
	SettingsManager.haptic_show_debug = false
	_free_mode._process(0.0)
	_check("al apagarlo el overlay se libera", _free_mode._debug_label == null)
	SettingsManager.haptic_show_debug = previous_debug

	print("=== 5b. el metronomo se alterna desde la esquina superior izquierda ===")
	var metronome = _free_mode.get_node_or_null("Metronome")
	var metronome_button: Button = _free_mode.find_child("MetronomeButton", true, false) as Button
	_check("hay nodo Metronome", metronome != null)
	_check("hay boton Metronome", metronome_button != null)
	if metronome != null and metronome_button != null:
		var viewport_width: float = _free_mode.get_viewport_rect().size.x
		_check("el boton esta arriba a la izquierda",
			metronome_button.position.x < viewport_width * 0.5 and metronome_button.position.y < 100.0)
		var title_label: Label = _free_mode.find_child("TitleLabel", true, false) as Label
		_check("hay titulo FREE MODE", title_label != null)
		if title_label != null:
			_check("el metronomo queda a la altura del titulo",
				absf(title_label.position.y - metronome_button.position.y) <= 4.0)
		_check("el metronomo tiene margen superior", metronome_button.position.y >= 3.0)
		var padding_left: float = 0.0
		if SettingsManager.gameplay_padding_enabled:
			padding_left = SettingsManager.dp_to_godot_px(SettingsManager.gameplay_padding_left)
		_check("el margen izquierdo coincide con el superior",
			absf((metronome_button.position.x - padding_left) - metronome_button.position.y) <= 0.5)
		_check("el metronomo usa un boton de icono", metronome_button.text.is_empty())
		_check("el metronomo mide 38 x 38",
			absf(metronome_button.size.x - 38.0) < 1.0
			and absf(metronome_button.size.y - 38.0) < 1.0)
		_check("el metronomo empieza apagado", not metronome.is_running())
		metronome_button.button_pressed = true
		_check("encender arranca el metronomo", metronome.is_running())
		metronome_button.button_pressed = false
		_check("apagar detiene el metronomo", not metronome.is_running())
		metronome_button.button_pressed = true
		_free_mode._pause_game()
		_check("pausar detiene el metronomo", not metronome.is_running())
		_free_mode._resume_game()
		_check("reanudar restaura el metronomo activo", metronome.is_running())
		metronome_button.button_pressed = false

	print("=== 6. sin chart no hay fallos ni puntuacion ===")
	for i in 15:
		await get_tree().process_frame
	_check("no se registra ningun fallo", ScoreManager.misses == 0)
	_check("no se registra ningun acierto", ScoreManager.hits == 0)
	_check("la puntuacion sigue a cero", ScoreManager.score == 0)
	_check("no hay notas en la pista", _active_note_count(highway) == 0)

	print("=== 7. todos los pads jugables usan los sets de Clone Hero ===")
	var kick_layers: Dictionary = DrumSfxManager._samples.get(8, {})
	var kick_variations: bool = true
	for layer in range(6):
		if kick_layers.get(layer, []).size() != 3:
			kick_variations = false
	_check("el kick tiene 6 capas", kick_layers.size() == 6)
	_check("cada capa del kick trae 3 variaciones", kick_variations)

	var snare_layers: Dictionary = DrumSfxManager._samples.get(7, {})
	var snare_variations: bool = true
	for layer in range(6):
		if snare_layers.get(layer, []).size() != 3:
			snare_variations = false
	_check("el snare tiene 6 capas", snare_layers.size() == 6)
	_check("cada capa del snare trae 3 variaciones", snare_variations)

	var crash_layers: Dictionary = DrumSfxManager._samples.get(6, {})
	var crash_variations: bool = true
	for layer in range(5):
		if crash_layers.get(layer, []).size() != 3:
			crash_variations = false
	_check("el crash tiene 5 capas", crash_layers.size() == 5)
	_check("cada capa del crash trae 3 variaciones", crash_variations)

	var hihat_layers: Dictionary = DrumSfxManager._samples.get(4, {})
	var hihat_variations: bool = true
	for layer in range(5):
		if hihat_layers.get(layer, []).size() != 3:
			hihat_variations = false
	_check("el hh tiene 5 capas", hihat_layers.size() == 5)
	_check("cada capa del hh trae 3 variaciones", hihat_variations)

	var ride_layers: Dictionary = DrumSfxManager._samples.get(5, {})
	var ride_variations: bool = true
	for layer in range(5):
		if ride_layers.get(layer, []).size() != 3:
			ride_variations = false
	_check("el ride tiene 5 capas", ride_layers.size() == 5)
	_check("cada capa del ride trae 3 variaciones", ride_variations)

	var tom1_layers: Dictionary = DrumSfxManager._samples.get(0, {})
	var tom1_variations: bool = true
	for layer in range(5):
		if tom1_layers.get(layer, []).size() != 3:
			tom1_variations = false
	_check("el tom 1 tiene 5 capas", tom1_layers.size() == 5)
	_check("cada capa del tom 1 trae 3 variaciones", tom1_variations)

	var tom2_layers: Dictionary = DrumSfxManager._samples.get(2, {})
	var tom2_variations: bool = true
	for layer in range(5):
		if tom2_layers.get(layer, []).size() != 3:
			tom2_variations = false
	_check("el tom 2 tiene 5 capas", tom2_layers.size() == 5)
	_check("cada capa del tom 2 trae 3 variaciones", tom2_variations)

	var tom3_layers: Dictionary = DrumSfxManager._samples.get(3, {})
	var tom3_variations: bool = true
	for layer in range(5):
		if tom3_layers.get(layer, []).size() != 3:
			tom3_variations = false
	_check("el tom 3 tiene 5 capas", tom3_layers.size() == 5)
	_check("cada capa del tom 3 trae 3 variaciones", tom3_variations)
	_check("un pad sin set mantiene 3 capas", DrumSfxManager._layer_count(1) == 3)

	_check("velocity 0 -> capa 0", DrumSfxManager.velocity_to_layer(0, 6) == 0)
	_check("velocity 20 -> capa 0", DrumSfxManager.velocity_to_layer(20, 6) == 0)
	_check("velocity 21 -> capa 1", DrumSfxManager.velocity_to_layer(21, 6) == 1)
	_check("velocity 62 -> capa 2", DrumSfxManager.velocity_to_layer(62, 6) == 2)
	_check("velocity 100 -> capa 4", DrumSfxManager.velocity_to_layer(100, 6) == 4)
	_check("velocity 127 -> capa 5", DrumSfxManager.velocity_to_layer(127, 6) == 5)
	_check("con 3 capas, velocity 100 -> capa 2", DrumSfxManager.velocity_to_layer(100, 3) == 2)
	_check("con 5 capas, velocity 24 -> capa 0", DrumSfxManager.velocity_to_layer(24, 5) == 0)
	_check("con 5 capas, velocity 25 -> capa 1", DrumSfxManager.velocity_to_layer(25, 5) == 1)
	_check("con 5 capas, velocity 74 -> capa 2", DrumSfxManager.velocity_to_layer(74, 5) == 2)
	_check("con 5 capas, velocity 100 -> capa 4", DrumSfxManager.velocity_to_layer(100, 5) == 4)

	DrumSfxManager._layer_cursor.clear()
	var round_robin: Array = []
	for i in 4:
		DrumSfxManager.play_for_lane(3, 100)
		round_robin.append(DrumSfxManager._layer_cursor.get("8:4", -1))
	_check("round-robin 0,1,2,0 en la capa 4 del kick", round_robin == [0, 1, 2, 0])

	DrumSfxManager._layer_cursor.clear()
	var snare_round_robin: Array = []
	for i in 3:
		DrumSfxManager.play_for_lane(2, 100)
		snare_round_robin.append(DrumSfxManager._layer_cursor.get("7:4", -1))
	_check("round-robin 0,1,2 en la capa 4 del snare", snare_round_robin == [0, 1, 2])

	DrumSfxManager._layer_cursor.clear()
	var crash_round_robin: Array = []
	for i in 3:
		DrumSfxManager.play_for_lane(1, 100)
		crash_round_robin.append(DrumSfxManager._layer_cursor.get("6:4", -1))
	_check("round-robin 0,1,2 en la capa 4 del crash", crash_round_robin == [0, 1, 2])

	DrumSfxManager._layer_cursor.clear()
	var hihat_round_robin: Array = []
	for i in 3:
		DrumSfxManager.play_for_lane(0, 100)
		hihat_round_robin.append(DrumSfxManager._layer_cursor.get("4:4", -1))
	_check("round-robin 0,1,2 en la capa 4 del hh", hihat_round_robin == [0, 1, 2])

	DrumSfxManager._layer_cursor.clear()
	var ride_round_robin: Array = []
	for i in 3:
		DrumSfxManager.play_for_lane(7, 100)
		ride_round_robin.append(DrumSfxManager._layer_cursor.get("5:4", -1))
	_check("round-robin 0,1,2 en la capa 4 del ride", ride_round_robin == [0, 1, 2])

	DrumSfxManager._layer_cursor.clear()
	var tom1_round_robin: Array = []
	for i in 3:
		DrumSfxManager.play_for_lane(4, 100)
		tom1_round_robin.append(DrumSfxManager._layer_cursor.get("0:4", -1))
	_check("round-robin 0,1,2 en la capa 4 del tom 1", tom1_round_robin == [0, 1, 2])

	DrumSfxManager._layer_cursor.clear()
	var tom2_round_robin: Array = []
	for i in 3:
		DrumSfxManager.play_for_lane(5, 100)
		tom2_round_robin.append(DrumSfxManager._layer_cursor.get("2:4", -1))
	_check("round-robin 0,1,2 en la capa 4 del tom 2", tom2_round_robin == [0, 1, 2])

	DrumSfxManager._layer_cursor.clear()
	var tom3_round_robin: Array = []
	for i in 3:
		DrumSfxManager.play_for_lane(6, 100)
		tom3_round_robin.append(DrumSfxManager._layer_cursor.get("3:4", -1))
	_check("round-robin 0,1,2 en la capa 4 del tom 3", tom3_round_robin == [0, 1, 2])

	var previous_velocity: int = SettingsManager.default_sample_velocity
	SettingsManager.default_sample_velocity = 30
	DrumSfxManager._layer_cursor.clear()
	DrumSfxManager.play_for_lane(3)
	_check("sin velocidad explicita usa el ajuste (capa 1)", DrumSfxManager._layer_cursor.has("8:1"))
	SettingsManager.default_sample_velocity = previous_velocity

	print("=== 8. Ajustes > Controls ofrece la entrada al modo libre ===")
	await _check_settings_entry()

	print("=== 9. el menu conecta Ajustes con el cambio de escena ===")
	await _check_menu_wiring()

	# The exit test goes last and without awaits: _exit_to_menu() requests the
	# change to Main.tscn and the test root node leaves the tree immediately, so
	# get_tree() would start returning null. The tree reference is saved before,
	# and the pending change is applied at the end of the frame, with the test
	# already finished.
	var tree: SceneTree = get_tree()
	print("=== 10. la pantalla se puede abandonar ===")
	_free_mode._exit_to_menu()
	_check("el estado vuelve a MENU", GameManager.state == GameManager.GameState.MENU)
	_check("el kick por sensor se apaga", InputManager.haptic_kick_enabled == false)
	_check("la salida queda armada", _free_mode._is_leaving)
	_free_mode._exit_to_menu()
	_check("una segunda salida no repite el cambio", _free_mode._is_leaving)
	_check("la senal del kick queda desconectada",
		not InputManager.kick_detected.is_connected(_free_mode._on_kick_pressed))

	print("")
	if _failures == 0:
		print("OK: modo libre correcto")
	else:
		print(_failures, " comprobaciones fallidas")
	tree.quit(1 if _failures > 0 else 0)


# The Settings panel is actually set up to check the button. The signal is
# captured with a one-shot connection instead of emitting it: MenuRoot reacts by
# changing scene and the test would be left without a root.
func _check_settings_entry() -> void:
	var settings: SettingsRoot = (preload("res://scene/Settings.tscn") as PackedScene).instantiate() as SettingsRoot
	add_child(settings)
	await get_tree().process_frame

	_check("el panel de Ajustes expone free_mode_requested", settings.has_signal("free_mode_requested"))

	var tab: Button = _find_button(settings, "CONTROLS")
	_check("hay pestana CONTROLS", tab != null)
	if tab == null:
		settings.queue_free()
		await get_tree().process_frame
		return
	tab.pressed.emit()
	await get_tree().process_frame

	var open_btn: Button = _find_button(settings, "Open Free Mode")
	_check("hay boton Open Free Mode", open_btn != null)
	_check("hay seccion FREE MODE", _find_label(settings, "FREE MODE") != null)
	_check("el boton explica para que sirve", _find_label(settings, "Drum testing without a song") != null)
	if open_btn != null:
		var seen: Array = []
		settings.free_mode_requested.connect(func() -> void: seen.append(true), CONNECT_ONE_SHOT)
		open_btn.pressed.emit()
		_check("el boton pide abrir el modo libre", seen.size() == 1)

	var custom_btn: Button = _find_button(settings, "Custom")
	_check("hay opcion de modo Custom", custom_btn != null)
	if custom_btn != null:
		var saved_mode: int = SettingsManager.game_mode
		var saved_lanes: Array = SettingsManager.custom_lanes.duplicate()
		custom_btn.button_pressed = true
		await get_tree().process_frame
		_check("el modo Custom muestra el editor horizontal",
			settings._custom_lane_card != null and settings._custom_lane_card.visible)
		_check("el editor horizontal arranca con las 8 pistas",
			settings._custom_lane_row != null and settings._custom_lane_row.get_order().size() == 8)
		_check("el editor guarda el orden al soltar",
			settings._custom_lane_row != null and settings._custom_lane_row.order_changed.is_connected(settings._on_lane_order_changed))
		_check("hay boton para resetear el orden", _find_button(settings, "Reset to Default") != null)
		SettingsManager.game_mode = saved_mode
		SettingsManager.custom_lanes = saved_lanes
		SettingsManager.save_settings()

	var audio_tab: Button = _find_button(settings, "AUDIO")
	_check("hay pestana AUDIO", audio_tab != null)
	if audio_tab != null:
		audio_tab.pressed.emit()
		await get_tree().process_frame
		_check("hay ajuste de Default Velocity", _find_label(settings, "Default Velocity") != null)
	settings.queue_free()
	await get_tree().process_frame


func _check_menu_wiring() -> void:
	var menu: MenuRoot = (preload("res://scene/Main.tscn") as PackedScene).instantiate() as MenuRoot
	add_child(menu)
	await get_tree().process_frame
	menu._on_settings_pressed()
	await get_tree().process_frame

	var panel: SettingsRoot = null
	for child in menu.get_children():
		if child is SettingsRoot:
			panel = child
			break
	_check("el menu abre Ajustes como overlay", panel != null)
	if panel != null:
		_check("el menu esta suscrito a free_mode_requested",
			panel.is_connected("free_mode_requested", Callable(menu, "_on_free_mode_requested")))
		# With the scene change in progress, closing the panel must no longer
		# rescan the library: the tree is being torn down.
		menu._is_switching_scene = true
		var before: int = SongLoader.song_list.size()
		menu._on_settings_closed()
		_check("el cierre durante el cambio no toca la biblioteca", SongLoader.song_list.size() == before)
		menu._is_switching_scene = false
	menu.queue_free()
	await get_tree().process_frame


func _lane_order(highway: Highway) -> Array:
	var out: Array = []
	if highway == null:
		return out
	for lane in highway.lane_nodes:
		out.append(lane.lane_index)
	return out


func _count_touch_zones(highway: Highway) -> int:
	var n: int = 0
	if highway == null:
		return 0
	for child in highway.get_children():
		if child is ColorRect and child.name.begins_with("TouchZone_"):
			n += 1
	return n


func _count_lane_labels(highway: Highway) -> int:
	var n: int = 0
	if highway == null:
		return 0
	for child in highway.get_children():
		if child is Label:
			n += 1
	return n


func _active_note_count(highway: Highway) -> int:
	var n: int = 0
	if highway == null:
		return 0
	for lane in highway.lane_nodes:
		n += lane._active_notes.size()
	return n


func _count_effects(node: Node) -> int:
	var n: int = 0
	for child in node.get_children():
		if child.name.begins_with("ParticleBurst") or child.name.begins_with("Shockwave"):
			n += 1
		n += _count_effects(child)
	return n


func _find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for c in node.get_children():
		var r: Button = _find_button(c, text)
		if r:
			return r
	return null


func _find_label(node: Node, text: String) -> Label:
	if node is Label and node.text.contains(text):
		return node
	for c in node.get_children():
		var r: Label = _find_label(c, text)
		if r:
			return r
	return null
