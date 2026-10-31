class_name GameplayRoot
extends Node2D

const MAIN_SCENE := preload("res://scene/Main.tscn")

@onready var highway = $Highway
@onready var hit_detection = $HitDetection
@onready var touch_input = $TouchInput
@onready var haptic_kick = $HapticKick
@onready var hud = $HUD

# Margin between the end of the audio and the results screen. The clock is
# already frozen, so this time is only for the player to process how the song
# ended instead of seeing a hard cut.
const RESULT_TAIL_DELAY: float = 0.5

var _is_initialized: bool = false
var _debug_label: Label
var _pause_overlay: CanvasLayer
var _pause_button: Button
var _is_paused: bool = false
var _back_handled_time: float = 0.0
var _calibration_label: Label
var _result_overlay: ResultOverlay
var _result_pending: bool = false
var _is_result_shown: bool = false

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
	TimingEngine.song_ended.connect(_on_song_ended)
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
	bg.color = Palette.SCRIM_STRONG
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
	title.add_theme_color_override("font_color", Palette.BONE)
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer)

	_loading_status = Label.new()
	_loading_status.text = ""
	_loading_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_status.add_theme_font_size_override("font_size", 18)
	_loading_status.add_theme_color_override("font_color", Palette.CHROME)
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
		_debug_label.add_theme_color_override("font_color", Palette.BLOOD_BRIGHT)
		_debug_label.add_theme_color_override("font_shadow_color", Palette.INK)
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

	_update_loading(0.0, "Loading audio stems...")
	await get_tree().create_timer(0.0).timeout

	if not AudioManager.load_stems(song_path):
		_update_loading(0.25, "No audio found (silent gameplay)")
	else:
		_update_loading(0.4, "Audio loaded, reading chart...")
	await get_tree().create_timer(0.0).timeout

	var song_notes_path: String = _find_notes_file(song_path)
	if song_notes_path.is_empty():
		_update_loading(0.4, "ERROR: notes.mid or notes.chart not found")
		await get_tree().create_timer(1.5).timeout
		_hide_loading_screen()
		return

	# The chart is validated against the actual audio duration: it serves to
	# detect tempo maps written in a unit other than the expected one.
	var expected_duration: float = GameManager.current_song_length
	if expected_duration <= 0.0:
		expected_duration = AudioManager.get_length()

	var diff_off: int = GameManager.current_difficulty_offset
	if not ChartParser.load_chart(song_notes_path, "", diff_off, expected_duration):
		_update_loading(0.4, "ERROR: Failed to parse chart")
		push_error("Failed to load chart: ", song_notes_path)
		await get_tree().create_timer(1.5).timeout
		_hide_loading_screen()
		return

	highway.generate_beat_lines()
	_update_loading(0.9, "Preparing chart...")
	await get_tree().create_timer(0.0).timeout

	var duration: float = ChartParser.get_duration_seconds()
	if duration > 0.0:
		_update_loading(0.95, str(ChartParser.get_note_count()) + " notes loaded")
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
	_calibration_label.add_theme_color_override("font_color", Palette.BLOOD_GLOW)
	_calibration_label.add_theme_color_override("font_shadow_color", Palette.INK_SOFT)
	_calibration_label.add_theme_constant_override("shadow_offset_x", 1)
	_calibration_label.add_theme_constant_override("shadow_offset_y", 1)
	_calibration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_calibration_label.position = Vector2(0, highway.highway_top_y + 20)
	_calibration_label.size = Vector2(get_viewport_rect().size.x, 30)
	add_child(_calibration_label)


func _on_haptic_calibration_completed() -> void:
	if _calibration_label:
		_calibration_label.text = "READY"
		_calibration_label.add_theme_color_override("font_color", Palette.BONE)
		await get_tree().create_timer(0.5).timeout
		if _calibration_label:
			_calibration_label.queue_free()
			_calibration_label = null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var now: float = Time.get_ticks_msec() / 1000.0
		if now - _back_handled_time < 0.5:
			return
		_handle_back()


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
	var note_visible: bool = has_next and next_time <= time_sec + highway.get_travel_time()

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


# End of song. TimingEngine has already frozen the clock and the audio: here it
# only waits for the grace margin and moves to RESULT. During that margin the
# state is still PLAYING, so the player can still hit notes that fell within
# the hit window.
func _on_song_ended() -> void:
	if _result_pending or _is_result_shown:
		return
	_result_pending = true
	await get_tree().create_timer(RESULT_TAIL_DELAY).timeout
	# The state is still PLAYING while the game is being played: if it no
	# longer is, the scene changed while waiting (restart or exit) and this
	# result no longer belongs to any run. The flag is re-armed so the next end
	# of song can be shown.
	if GameManager.state != GameManager.GameState.PLAYING:
		_result_pending = false
		return
	_show_result()


func _show_result() -> void:
	if _is_result_shown or not is_inside_tree():
		return
	_is_result_shown = true
	_result_pending = false
	_is_paused = false
	_hide_pause_overlay()
	_hide_countdown()
	# Notes still on screen never go through the miss window (without audio,
	# chart_duration matches the last note): they are missed here so the final
	# count matches the chart.
	highway.flush_unjudged_notes()
	# At this point ScoreManager already has the final result of the run: the
	# song+difficulty record is committed before moving to RESULT.
	if not GameManager.current_song_path.is_empty():
		HighScoreStore.record_score(
			GameManager.current_song_path,
			GameManager.current_difficulty_offset,
			ScoreManager.score,
		)
	InputManager.haptic_kick_enabled = false
	# AndroidBridge.clear_exclusion() is NOT called here: we are still inside
	# gameplay, the touch zones remain the same.
	GameManager.set_state(GameManager.GameState.RESULT)
	_show_result_overlay()


func _show_result_overlay() -> void:
	if _result_overlay:
		return
	_result_overlay = ResultOverlay.new()
	_result_overlay.name = "ResultOverlay"
	_result_overlay.retry_requested.connect(_restart_song)
	_result_overlay.exit_requested.connect(_exit_to_menu)
	add_child(_result_overlay)


func _hide_result_overlay() -> void:
	if _result_overlay:
		_result_overlay.queue_free()
		_result_overlay = null
	_is_result_shown = false
	_result_pending = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back_handled_time = Time.get_ticks_msec() / 1000.0
		_handle_back()
		get_viewport().set_input_as_handled()


# The back button depends on where the game is: with the results screen visible
# it exits the song, and if the song already ended but the panel has not
# appeared yet it does nothing (it would pause a run that no longer exists).
func _handle_back() -> void:
	if _is_result_shown:
		_exit_to_menu()
	elif _result_pending:
		return
	else:
		_toggle_pause()


func _create_pause_icon(size: int = 24) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)

	var bar_width := maxi(1, int(size * 0.25))
	var gap := maxi(1, int(size * 0.15))
	var bar_height := int(size * 0.6)
	var y_offset := (size - bar_height) / 2

	var color := Palette.TEXT_DIM

	for y in size:
		if y < y_offset or y >= y_offset + bar_height:
			continue
		for x in size:
			if (x >= gap and x < gap + bar_width) or (x >= size - gap - bar_width and x < size - gap):
				img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)


func _setup_pause_button() -> void:
	_pause_button = Button.new()
	_pause_button.name = "PauseButton"
	_pause_button.icon = _create_pause_icon(24)
	_pause_button.expand_icon = true
	_pause_button.custom_minimum_size = Vector2(48, 48)
	_pause_button.anchor_left = 0.5
	_pause_button.anchor_top = 0.0
	_pause_button.anchor_right = 0.5
	_pause_button.anchor_bottom = 0.0
	_pause_button.offset_left = -24
	_pause_button.offset_top = 38
	_pause_button.offset_right = 24
	_pause_button.offset_bottom = 86
	_pause_button.pressed.connect(_toggle_pause)
	hud.add_child(_pause_button)


func _toggle_pause() -> void:
	if _is_result_shown or _result_pending:
		return
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
	_hide_result_overlay()
	TimingEngine.stop()
	highway.restart()
	ScoreManager.reset()
	_start_loading()


func _exit_to_menu() -> void:
	_is_paused = false
	_hide_pause_overlay()
	_hide_countdown()
	_hide_result_overlay()
	_show_loading_screen()
	_update_loading(0.5, "Returning to menu...")
	await get_tree().create_timer(0.0).timeout
	_do_exit_to_menu()


func _do_exit_to_menu() -> void:
	if not is_inside_tree():
		return
	_hide_countdown()
	_hide_result_overlay()
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
	bg.color = Palette.SCRIM_SOFT
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
	title.add_theme_color_override("font_color", Palette.BONE)
	title.add_theme_color_override("font_shadow_color", Palette.INK)
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


func _find_notes_file(song_path: String) -> String:
	var mid_path: String = song_path.path_join("notes.mid")
	if FileHelper.file_exists(mid_path) or ResourceLoader.exists(mid_path):
		return mid_path
	var chart_path: String = song_path.path_join("notes.chart")
	if FileHelper.file_exists(chart_path) or ResourceLoader.exists(chart_path):
		return chart_path
	return ""


func stop_gameplay() -> void:
	_hide_countdown()
	_hide_result_overlay()
	AndroidBridge.clear_exclusion()
	TimingEngine.stop()
	highway.restart()
	ScoreManager.reset()
	GameManager.set_state(GameManager.GameState.MENU)
