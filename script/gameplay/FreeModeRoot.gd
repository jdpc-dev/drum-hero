class_name FreeModeRoot
extends Node2D

# Free drum practice mode. Entered from Settings > Experimental and there is no
# song, chart or score: the track appears empty and each hit plays its sample,
# flashes the hit line and launches particles.
#
# It intentionally reuses the real Highway so the lane order, layout, gameplay
# padding and Android gesture exclusion are exactly those of the game. The only
# thing not set up here is HitDetection: without a chart there is nothing to
# judge, so TouchInput receives null and its "no note was hit" branch is what
# triggers the sample.

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
	# The ChartParser autoload survives scene changes: without clearing it, the
	# last played song would leave notes falling down the track and counted as
	# missed instantly.
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


# The sensor kick is handled here instead of setting up the HapticKick node
# from gameplay: that node only knows how to forward to HitDetection, which
# does not exist here.
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
	# TouchInput plays the sample in the other cases; the kick does not go through it.
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
	# The color goes in LabelSettings and not as a theme override: when a Label
	# has label_settings, that resource takes precedence over theme overrides.
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


# The pad that was hit is shown in the center of the track, which is exactly
# where notes would fall. The title lives in the timeline band.
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
	# Duplicated LabelSettings instead of theme overrides: the base resource
	# already brings the game font and outline (see ResultOverlay._make_label).
	var settings := BASE_LABEL_SETTINGS.duplicate() as LabelSettings
	settings.font_size = font_size
	settings.font_color = color
	label.label_settings = settings
	label.text = text
	return label


# ---------------------------------------------------------------- Haptic calibration


func _show_calibration_label() -> void:
	if _calibration_label:
		return
	_calibration_label = _make_label("CALIBRATING...", 20, Palette.BLOOD_GLOW)
	_calibration_label.name = "CalibrationLabel"
	_calibration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_calibration_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_calibration_label.position = Vector2(0, highway.highway_top_y + 20)
	_calibration_label.size = Vector2(get_viewport_rect().size.x, 30)
	# In the HUD, not at the root: this way the banner goes above the track
	# instead of competing with the notes on the same drawing layer.
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


# ---------------------------------------------------------------- Exit


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
	# With the kick off the signal was never connected, and disconnecting an
	# unconnected Callable is an error in Godot: it is checked beforehand.
	if InputManager.kick_detected.is_connected(_on_kick_pressed):
		InputManager.kick_detected.disconnect(_on_kick_pressed)
	AndroidBridge.clear_exclusion()
	ScoreManager.reset()
	GameManager.set_state(GameManager.GameState.MENU)
	get_tree().change_scene_to_packed(MAIN_SCENE)
