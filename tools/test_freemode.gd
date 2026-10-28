extends Node

# Test del modo libre (Settings > Experimental > Open Free Mode).
# Comprueba que la escena monta la Highway real, que ChartParser queda limpio,
# que cada golpe suena/ilumina sin chart, y que el boton de Ajustes esta
# conectado al menu.
# Uso: godot --headless --path . res://tools/test_freemode.tscn

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


# ChartParser es un autoload y sobrevive a los cambios de escena. El free mode
# tiene que vaciarlo el mismo: si no, las notas de la ultima cancion seguida
# bajarian por la pista y se contarian como falladas al instante.
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
	# Se siembra un chart viejo ANTES de instanciar: si FreeModeRoot no lo
	# limpiase, estas notas aparecerian y se fallarian solas.
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
	_check("el estado pasa a PLAYING", GameManager.state == GameManager.GameState.PLAYING)
	_check("el chart quedo limpio al entrar", ChartParser.note_data.is_empty())

	print("=== 3. las pistas heredan el modo de control ===")
	_check("modo DEFAULT = 8 pistas en orden", _lane_order(highway) == [0, 1, 2, 3, 4, 5, 6, 7])
	_check("cada pista tiene su zona tactil", _count_touch_zones(highway) == 8)
	_check("cada pista tiene etiqueta", _count_lane_labels(highway) == 8)
	_check("hay linea de golpeo", highway != null and highway.hit_line_ref != null)

	print("=== 4. en HAPTIC la pista del kick sale aparte ===")
	GameManager.mode = GameManager.GameMode.HAPTIC
	var probe: Highway = (load(HIGHWAY_SCENE) as PackedScene).instantiate() as Highway
	add_child(probe)
	await get_tree().process_frame
	var haptic_order: Array = _lane_order(probe)
	_check("modo HAPTIC = 7 pistas", haptic_order.size() == 7)
	_check("modo HAPTIC saca la pista del kick de la fila", not haptic_order.has(3))
	_check("modo HAPTIC anade la pista de kick aparte", probe.get_kick_lane() != null)
	probe.queue_free()
	GameManager.mode = GameManager.GameMode.DEFAULT
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

	print("=== 6. sin chart no hay fallos ni puntuacion ===")
	for i in 15:
		await get_tree().process_frame
	_check("no se registra ningun fallo", ScoreManager.misses == 0)
	_check("no se registra ningun acierto", ScoreManager.hits == 0)
	_check("la puntuacion sigue a cero", ScoreManager.score == 0)
	_check("no hay notas en la pista", _active_note_count(highway) == 0)

	print("=== 7. Ajustes > Experimental ofrece la entrada ===")
	await _check_settings_entry()

	print("=== 8. el menu conecta Ajustes con el cambio de escena ===")
	await _check_menu_wiring()

	# El test de salida va el ultimo y sin awaits: _exit_to_menu() pide el cambio
	# a Main.tscn y el nodo raiz del test se queda fuera del arbol en el acto, de
	# modo que get_tree() pasaria a devolver null. Se guarda la referencia al arbol
	# antes, y el cambio pendiente se aplica al final del frame, ya con el test
	# terminado.
	var tree: SceneTree = get_tree()
	print("=== 9. la pantalla se puede abandonar ===")
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


# Se monta el panel de Ajustes de verdad para comprobar el boton. La senal se
# captura con una conexion de un solo uso en vez de emitirla: MenuRoot reacciona
# cambiando de escena y el test se quedaria sin raiz.
func _check_settings_entry() -> void:
	var settings: SettingsRoot = (preload("res://scene/Settings.tscn") as PackedScene).instantiate() as SettingsRoot
	add_child(settings)
	await get_tree().process_frame

	_check("el panel de Ajustes expone free_mode_requested", settings.has_signal("free_mode_requested"))

	var tab: Button = _find_button(settings, "Experimental")
	_check("hay pestana Experimental", tab != null)
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
		# Con el cambio de escena en marcha, el cierre del panel ya no debe
		# reescanear la biblioteca: el arbol se esta tirando.
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
