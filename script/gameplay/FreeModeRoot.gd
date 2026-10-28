class_name FreeModeRoot
extends Node2D

# Modo libre de pruebas de bateria. Se entra desde Ajustes > Experimental y no
# hay cancion, chart ni puntuacion: la pista aparece vacia y cada golpe suena su
# sample, destella la linea de golpeo y lanza particulas.
#
# Reutiliza la Highway de verdad a proposito, para que el orden de pistas, el
# layout, el padding del gameplay y la exclusion de gestos de Android sean
# exactamente los del juego. Lo unico que no se monta aqui es HitDetection: sin
# chart no hay nada que juzgar, asi que TouchInput recibe null y su rama de
# "no se acerto ninguna nota" es la que se encarga de sonar el sample.

const MAIN_SCENE := preload("res://scene/Main.tscn")
const BASE_LABEL_SETTINGS := preload("res://asset/fonts/label_settings.tres")

@onready var highway = $Highway
@onready var touch_input = $TouchInput
@onready var hud = $HUD

var _total_hits: int = 0
var _haptic_active: bool = false
var _back_handled_time: float = 0.0
var _is_leaving: bool = false

var _pad_name_label: Label
var _hits_label: Label
var _fps_label: Label
var _calibration_label: Label


func _ready() -> void:
	get_tree().auto_accept_quit = false
	# El autoload ChartParser sobrevive a los cambios de escena: sin limpiarlo, la
	# ultima cancion jugada dejaria notas bajando por la pista y contadas como
	# falladas al instante.
	ChartParser.clear()
	ScoreManager.reset()
	GameManager.set_state(GameManager.GameState.PLAYING)
	_setup_hud()
	_setup_haptic()
	_setup_input_when_ready()


func _setup_input_when_ready() -> void:
	if highway.lane_nodes.size() > 0:
		_setup_input()
		return
	highway.lanes_built.connect(_setup_input, CONNECT_ONE_SHOT)


func _setup_input() -> void:
	touch_input.setup(highway, null)
	touch_input.lane_pressed.connect(_on_lane_pressed)


# El kick por sensor se escucha aqui en vez de montar el nodo HapticKick del
# gameplay: ese nodo solo sabe reenviar a HitDetection, que aqui no existe.
func _setup_haptic() -> void:
	_haptic_active = SettingsManager.haptic_enabled or GameManager.mode == GameManager.GameMode.HAPTIC
	InputManager.haptic_kick_enabled = _haptic_active
	if not _haptic_active:
		return
	InputManager.kick_detected.connect(_on_kick_pressed)
	InputManager.start_calibration()
	InputManager.calibration_completed.connect(_on_calibration_completed, CONNECT_ONE_SHOT)
	_show_calibration_label()


func _on_kick_pressed() -> void:
	if GameManager.state != GameManager.GameState.PLAYING:
		return
	if not _haptic_active:
		return
	# El sample lo suena TouchInput en el resto de casos; el kick no pasa por ahi.
	DrumSfxManager.play_for_lane(3)
	_on_lane_pressed(3, Vector2.ZERO)


func _on_lane_pressed(lane_index: int, _position: Vector2) -> void:
	_total_hits += 1
	_update_pad_readout(lane_index)
	highway.flash_hit_line(lane_index)
	EffectManager.call_deferred("trigger_particle_burst",
		highway.get_hit_global_position(lane_index),
		Highway._get_lane_colors()[lane_index],
		highway)


func _update_pad_readout(lane_index: int) -> void:
	if _pad_name_label == null:
		return
	var colors: Array[Color] = Highway._get_lane_colors()
	var name_idx: int = clampi(lane_index, 0, DrumGraphics.LANE_FULL_LABELS.size() - 1)
	_pad_name_label.text = DrumGraphics.LANE_FULL_LABELS[name_idx]
	# El color va en LabelSettings y no como theme override: cuando un Label tiene
	# label_settings, ese recurso manda sobre los overrides del tema.
	_pad_name_label.label_settings.font_color = colors[name_idx]


# ---------------------------------------------------------------- HUD


func _setup_hud() -> void:
	_pad_name_label = _make_label("", 64, Palette.TEXT_DIM)
	_pad_name_label.name = "PadNameLabel"
	_pad_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pad_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud.add_child(_pad_name_label)

	_hits_label = _make_label("0 hits", 22, Palette.ASH)
	_hits_label.name = "HitsLabel"
	_hits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hits_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud.add_child(_hits_label)

	_layout_hud()

	var back_btn := Button.new()
	back_btn.name = "BackButton"
	back_btn.text = "BACK TO MENU"
	back_btn.custom_minimum_size = Vector2(160, 44)
	back_btn.anchor_left = 1.0
	back_btn.anchor_right = 1.0
	back_btn.offset_left = -180.0
	back_btn.offset_top = 24.0
	back_btn.offset_right = -20.0
	back_btn.offset_bottom = 68.0
	back_btn.pressed.connect(_exit_to_menu)
	hud.add_child(back_btn)


# El pad que sonó se muestra en el centro de la pista, que es justo donde
# bajarian las notas. El titulo vive en la banda de la linea de tiempo.
func _layout_hud() -> void:
	var vs: Vector2 = get_viewport_rect().size
	var pl: float = SettingsManager.dp_to_godot_px(SettingsManager.gameplay_padding_left) if SettingsManager.gameplay_padding_enabled else 0.0
	var pr: float = SettingsManager.dp_to_godot_px(SettingsManager.gameplay_padding_right) if SettingsManager.gameplay_padding_enabled else 0.0
	var pt: float = SettingsManager.dp_to_godot_px(SettingsManager.gameplay_padding_top) if SettingsManager.gameplay_padding_enabled else 0.0
	var content_w: float = vs.x - pl - pr

	var title := _make_label("FREE MODE", 28, Palette.BLOOD_GLOW)
	title.name = "TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.position = Vector2(pl, pt + vs.y * 0.035)
	title.size = Vector2(content_w, 36)
	hud.add_child(title)

	var hint := _make_label("Tap a pad or press 1-8  -  no song, no score", 18, Palette.ASH_DIM)
	hint.name = "HintLabel"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.position = Vector2(pl, pt + vs.y * 0.075)
	hint.size = Vector2(content_w, 26)
	hud.add_child(hint)

	var mid_y: float = pt + (vs.y - pt) * 0.30
	_pad_name_label.position = Vector2(pl, mid_y)
	_pad_name_label.size = Vector2(content_w, 80)

	_hits_label.position = Vector2(pl, mid_y + 84.0)
	_hits_label.size = Vector2(content_w, 32)


func _update_hits_label() -> void:
	if _hits_label:
		_hits_label.text = str(_total_hits) + (" hits" if _total_hits != 1 else " hit")


func _process(_delta: float) -> void:
	_update_hits_label()
	if SettingsManager.show_fps:
		_ensure_fps_label()
	elif _fps_label:
		_fps_label.queue_free()
		_fps_label = null


func _ensure_fps_label() -> void:
	if _fps_label and is_instance_valid(_fps_label):
		_fps_label.text = "FPS: %d" % roundi(Engine.get_frames_per_second())
		return
	_fps_label = _make_label("FPS: 0", 16, Palette.ASH_DIM)
	_fps_label.name = "FpsLabel"
	_fps_label.position = Vector2(10, 76)
	hud.add_child(_fps_label)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	# LabelSettings duplicado en vez de theme overrides: el recurso base ya trae la
	# fuente del juego y el contorno (ver ResultOverlay._make_label).
	var settings := BASE_LABEL_SETTINGS.duplicate() as LabelSettings
	settings.font_size = font_size
	settings.font_color = color
	label.label_settings = settings
	label.text = text
	return label


# ---------------------------------------------------------------- Calibracion haptic


func _show_calibration_label() -> void:
	if _calibration_label:
		return
	_calibration_label = _make_label("CALIBRATING...", 20, Palette.BLOOD_GLOW)
	_calibration_label.name = "CalibrationLabel"
	_calibration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_calibration_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_calibration_label.position = Vector2(0, highway.highway_top_y + 20)
	_calibration_label.size = Vector2(get_viewport_rect().size.x, 30)
	# En el HUD, no en la raiz: asi el cartel va por encima de la pista en vez de
	# competir con las notas en la misma capa de dibujo.
	hud.add_child(_calibration_label)


func _on_calibration_completed() -> void:
	if not _calibration_label:
		return
	_calibration_label.text = "READY"
	_calibration_label.label_settings.font_color = Palette.BONE
	await get_tree().create_timer(0.5).timeout
	if _calibration_label:
		_calibration_label.queue_free()
		_calibration_label = null


# ---------------------------------------------------------------- Salida


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var now: float = Time.get_ticks_msec() / 1000.0
		if now - _back_handled_time < 0.5:
			return
		_back_handled_time = now
		_exit_to_menu()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back_handled_time = Time.get_ticks_msec() / 1000.0
		_exit_to_menu()
		get_viewport().set_input_as_handled()


func _exit_to_menu() -> void:
	if not is_inside_tree() or _is_leaving:
		return
	_is_leaving = true
	InputManager.haptic_kick_enabled = false
	# Con el kick apagado nunca se conecto la senal, y desconectar un Callable no
	# conectado es un error en Godot: se comprueba antes.
	if InputManager.kick_detected.is_connected(_on_kick_pressed):
		InputManager.kick_detected.disconnect(_on_kick_pressed)
	AndroidBridge.clear_exclusion()
	ScoreManager.reset()
	GameManager.set_state(GameManager.GameState.MENU)
	get_tree().change_scene_to_packed(MAIN_SCENE)
