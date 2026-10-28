class_name GameplayRoot
extends Node2D

const MAIN_SCENE := preload("res://scene/Main.tscn")
const NOTE_TRAVEL_TIME := 2.0

@onready var highway = $Highway
@onready var hit_detection = $HitDetection
@onready var touch_input = $TouchInput
@onready var haptic_kick = $HapticKick
@onready var hud = $HUD

var _is_initialized: bool = false
var _debug_label: Label
var _pause_overlay: CanvasLayer
var _pause_button: Button
var _is_paused: bool = false
var _back_handled_time: float = 0.0
var _calibration_label: Label

# Loading overlay
var _loading_overlay: CanvasLayer
var _loading_bar: ProgressBar
var _loading_status: Label

# Countdown
var _countdown_label: CountdownLabel
var _countdown_threshold: float


func _ready() -> void:
	GameManager.game_state_changed.connect(_on_state_changed)
	_is_initialized = true
	get_tree().auto_accept_quit = false
	_countdown_threshold = SettingsManager.countdown_threshold
	TimingEngine.time_updated.connect(_on_countdown_update)
	_setup_pause_button()
	await _setup_input_when_ready()
	_start_loading()


func _setup_input_when_ready() -> void:
	if highway.lane_nodes.size() > 0:
		_setup_input()
		return
	highway.lanes_built.connect(_setup_input, CONNECT_ONE_SHOT)


func _show_loading_screen() -> void:
	if _loading_overlay:
		return
	_loading_overlay = CanvasLayer.new()
	_loading_overlay.name = "LoadingOverlay"
	_loading_overlay.layer = 20

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_overlay.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -160
	vbox.offset_top = -120
	vbox.offset_right = 160
	vbox.offset_bottom = 120
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_loading_overlay.add_child(vbox)

	var title := Label.new()
	title.text = "LOADING"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer)

	_loading_status = Label.new()
	_loading_status.text = ""
	_loading_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_status.add_theme_font_size_override("font_size", 18)
	_loading_status.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(_loading_status)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 15)
	vbox.add_child(spacer2)

	_loading_bar = ProgressBar.new()
	_loading_bar.custom_minimum_size = Vector2(300, 25)
	_loading_bar.show_percentage = true
	_loading_bar.value = 0
	vbox.add_child(_loading_bar)

	add_child(_loading_overlay)


func _update_loading(progress: float, status: String) -> void:
	if _loading_bar:
		_loading_bar.value = progress * 100.0
	if _loading_status:
		_loading_status.text = status


func _hide_loading_screen() -> void:
	if _loading_overlay:
		_loading_overlay.queue_free()
		_loading_overlay = null
		_loading_bar = null
		_loading_status = null


func _show_debug(msg: String) -> void:
	if not _debug_label:
		_debug_label = Label.new()
		_debug_label.name = "DebugLabel"
		_debug_label.position = Vector2(20, 80)
		_debug_label.z_index = 10
		_debug_label.add_theme_font_size_override("font_size", 18)
		_debug_label.add_theme_color_override("font_color", Color(0, 1, 0))
		_debug_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
		_debug_label.add_theme_constant_override("shadow_offset_x", 2)
		_debug_label.add_theme_constant_override("shadow_offset_y", 2)
		add_child(_debug_label)
	_debug_label.text = msg


func _process(_delta: float) -> void:
	if SettingsManager.haptic_show_debug:
		_show_debug(InputManager.get_haptic_debug_string())
	elif _debug_label:
		_debug_label.text = ""
		_debug_label.queue_free()
		_debug_label = null


func _setup_input() -> void:
	hit_detection.highway_ref = highway
	touch_input.setup(highway, hit_detection)
	haptic_kick.setup(hit_detection)


func _start_loading() -> void:
	_show_loading_screen()
	await get_tree().create_timer(0.0).timeout

	var song_path: String = GameManager.current_song_path
	if song_path.is_empty():
		_update_loading(0.0, "ERROR: No song path set")
		push_error("No song path set")
		await get_tree().create_timer(1.5).timeout
		_hide_loading_screen()
		return

	_update_loading(0.0, "Loading MIDI chart...")
	await get_tree().create_timer(0.0).timeout

	var song_notes_path: String = song_path.path_join("notes.mid")
	if not FileHelper.file_exists(song_notes_path):
		_update_loading(0.0, "ERROR: MIDI not found")
		await get_tree().create_timer(1.5).timeout
		_hide_loading_screen()
		return

	var diff_off: int = GameManager.current_difficulty_offset
	if not ChartParser.load_chart(song_notes_path, "", diff_off):
		_update_loading(0.0, "ERROR: Failed to parse MIDI")
		push_error("Failed to load chart: ", song_notes_path)
		await get_tree().create_timer(1.5).timeout
		_hide_loading_screen()
		return

	highway.generate_beat_lines()
	_update_loading(0.35, "Loading audio stems...")
	await get_tree().create_timer(0.0).timeout

	if not AudioManager.load_stems(song_path):
		_update_loading(0.35, "No audio found (silent gameplay)")
	else:
		_update_loading(0.75, "Audio loaded, preparing...")
	await get_tree().create_timer(0.0).timeout

	var duration: float = ChartParser.get_duration_seconds()
	if duration > 0.0:
		_update_loading(0.9, str(ChartParser.get_note_count()) + " notes loaded")
		await get_tree().create_timer(0.0).timeout

	GameManager.set_state(GameManager.GameState.PLAYING)
	TimingEngine.start(duration, GameManager.current_song_delay / 1000.0)

	if SettingsManager.haptic_enabled or GameManager.mode == GameManager.GameMode.HAPTIC:
		InputManager.haptic_kick_enabled = true
		InputManager.start_calibration()
		InputManager.calibration_completed.connect(_on_haptic_calibration_completed, CONNECT_ONE_SHOT)
		_show_calibration_label()
	else:
		InputManager.haptic_kick_enabled = false

	_update_loading(1.0, "Ready!")
	await get_tree().create_timer(0.0).timeout
	_hide_loading_screen()


func _show_calibration_label() -> void:
	if _calibration_label:
		return
	_calibration_label = Label.new()
	_calibration_label.name = "CalibrationLabel"
	_calibration_label.text = "CALIBRATING..."
	_calibration_label.add_theme_font_size_override("font_size", 18)
	_calibration_label.add_theme_color_override("font_color", Color(1, 1, 0, 0.9))
	_calibration_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_calibration_label.add_theme_constant_override("shadow_offset_x", 1)
	_calibration_label.add_theme_constant_override("shadow_offset_y", 1)
	_calibration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_calibration_label.position = Vector2(0, highway.highway_top_y + 20)
	_calibration_label.size = Vector2(get_viewport_rect().size.x, 30)
	add_child(_calibration_label)


func _on_haptic_calibration_completed() -> void:
	if _calibration_label:
		_calibration_label.text = "READY"
		_calibration_label.add_theme_color_override("font_color", Color(0, 1, 0, 0.9))
		await get_tree().create_timer(0.5).timeout
		if _calibration_label:
			_calibration_label.queue_free()
			_calibration_label = null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var now: float = Time.get_ticks_msec() / 1000.0
		if now - _back_handled_time < 0.5:
			return
		_toggle_pause()


func _on_countdown_update(time_sec: float) -> void:
	if GameManager.state != GameManager.GameState.PLAYING:
		_hide_countdown()
		return
	if not ChartParser.has_data():
		_hide_countdown()
		return

	var next_idx: int = ChartParser.find_next_note_index(time_sec)
	var has_next: bool = next_idx < ChartParser.note_data.size()
	var next_time: float = ChartParser.note_data[next_idx].time if has_next else -1.0
	var remaining: float = next_time - time_sec if has_next else -1.0
	var note_visible: bool = has_next and next_time <= time_sec + NOTE_TRAVEL_TIME

	if remaining > _countdown_threshold and not note_visible:
		_show_countdown()
		_countdown_label.update_display(remaining)
	elif _countdown_label != null and _countdown_label.visible:
		_hide_countdown()


func _show_countdown() -> void:
	if _countdown_label != null:
		return
	_countdown_label = preload("res://scene/UI/CountdownLabel.tscn").instantiate()
	_countdown_label.name = "CountdownLabel"
	add_child(_countdown_label)


func _hide_countdown() -> void:
	if _countdown_label == null:
		return
	_countdown_label.clear()
	_countdown_label.queue_free()
	_countdown_label = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back_handled_time = Time.get_ticks_msec() / 1000.0
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _setup_pause_button() -> void:
	_pause_button = Button.new()
	_pause_button.name = "PauseButton"
	_pause_button.text = "⏸"
	_pause_button.custom_minimum_size = Vector2(48, 48)
	_pause_button.anchor_left = 0.5
	_pause_button.anchor_top = 0.0
	_pause_button.anchor_right = 0.5
	_pause_button.anchor_bottom = 0.0
	_pause_button.offset_left = -24
	_pause_button.offset_top = 38
	_pause_button.offset_right = 24
	_pause_button.offset_bottom = 86
	_pause_button.add_theme_font_size_override("font_size", 24)
	_pause_button.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_pause_button.pressed.connect(_toggle_pause)
	hud.add_child(_pause_button)


func _toggle_pause() -> void:
	if _is_paused:
		_resume_game()
	else:
		_pause_game()


func _on_state_changed(new_state: GameManager.GameState) -> void:
	match new_state:
		GameManager.GameState.PLAYING:
			pass
		GameManager.GameState.PAUSED:
			TimingEngine.pause()
		GameManager.GameState.RESULT:
			TimingEngine.stop()


func _pause_game() -> void:
	_is_paused = true
	GameManager.set_state(GameManager.GameState.PAUSED)
	_show_pause_overlay()


func _resume_game() -> void:
	_is_paused = false
	_hide_pause_overlay()
	GameManager.set_state(GameManager.GameState.PLAYING)
	TimingEngine.resume()


func _restart_song() -> void:
	_is_paused = false
	_hide_pause_overlay()
	_hide_countdown()
	TimingEngine.stop()
	highway.restart()
	ScoreManager.reset()
	_start_loading()


func _exit_to_menu() -> void:
	_is_paused = false
	_hide_pause_overlay()
	_show_loading_screen()
	_update_loading(0.5, "Returning to menu...")
	await get_tree().create_timer(0.0).timeout
	_do_exit_to_menu()


func _do_exit_to_menu() -> void:
	if not is_inside_tree():
		return
	_hide_countdown()
	AndroidBridge.clear_exclusion()
	TimingEngine.stop()
	highway.restart()
	ScoreManager.reset()
	GameManager.set_state(GameManager.GameState.MENU)
	get_tree().change_scene_to_packed(MAIN_SCENE)


func _show_pause_overlay() -> void:
	if _pause_overlay:
		return
	_pause_overlay = CanvasLayer.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.layer = 10

	var bg: ColorRect = ColorRect.new()
	bg.name = "PauseBg"
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(bg)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "PauseMenu"
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -120
	vbox.offset_top = -120
	vbox.offset_right = 120
	vbox.offset_bottom = 120
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_pause_overlay.add_child(vbox)

	var title: Label = Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_shadow_color", Color.BLACK)
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(title)

	var spacing := Control.new()
	spacing.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacing)

	var resume_btn: Button = Button.new()
	resume_btn.text = "RESUME"
	resume_btn.custom_minimum_size = Vector2(200, 50)
	resume_btn.pressed.connect(_resume_game)
	vbox.add_child(resume_btn)

	var restart_btn: Button = Button.new()
	restart_btn.text = "RESTART"
	restart_btn.custom_minimum_size = Vector2(200, 50)
	restart_btn.pressed.connect(_restart_song)
	vbox.add_child(restart_btn)

	var exit_btn: Button = Button.new()
	exit_btn.text = "EXIT"
	exit_btn.custom_minimum_size = Vector2(200, 50)
	exit_btn.pressed.connect(_exit_to_menu)
	vbox.add_child(exit_btn)

	add_child(_pause_overlay)


func _hide_pause_overlay() -> void:
	if _pause_overlay:
		_pause_overlay.queue_free()
		_pause_overlay = null


func stop_gameplay() -> void:
	_hide_countdown()
	AndroidBridge.clear_exclusion()
	TimingEngine.stop()
	highway.restart()
	ScoreManager.reset()
	GameManager.set_state(GameManager.GameState.MENU)
