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
# The centred pause button occupies y 38-86, so the calibration banner starts
# just below it instead of overlapping the icon.
const CALIBRATION_LABEL_TOP: float = 94.0

var _is_initialized: bool = false
var _debug_label: Label
var _pause_overlay: CanvasLayer
var _pause_modal_layer: CanvasLayer
var _pause_button: Button
var _pause_modal: SettingsUI.ModalBody
var _pause_main_menu: Control
var _pause_difficulty_menu: Control
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
var _is_loading: bool = false

# Countdown
var _countdown_label: CountdownLabel
var _countdown_threshold: float


func _ready() -> void:
	SettingsUI.setup_ui_scale(get_viewport().get_visible_rect().size.y)
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
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_loading_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(SettingsUI.px(420), 0)
	var panel_style := SettingsUI.flat(Palette.SURFACE_1, 18)
	SettingsUI.pad(panel_style, SettingsUI.px(28), SettingsUI.px(24))
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SettingsUI.px(10))
	panel.add_child(vbox)

	var title := SettingsUI.label("LOADING", 24, Palette.BONE_HI, 600)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_loading_status = SettingsUI.label("", 14, Palette.CHROME, 400)
	_loading_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_loading_status)

	_loading_bar = ProgressBar.new()
	_loading_bar.custom_minimum_size = Vector2(SettingsUI.px(320), 0)
	SettingsUI.style_progress(_loading_bar)
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
	_is_loading = false
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
		_debug_label.add_theme_color_override("font_color", Palette.ACCENT_GLOW)
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


func _start_loading(reload_audio: bool = true) -> void:
	_is_loading = true
	_show_loading_screen()
	await get_tree().create_timer(0.0).timeout

	var song_path: String = GameManager.current_song_path
	if song_path.is_empty():
		_update_loading(0.0, "ERROR: No song path set")
		push_error("No song path set")
		await get_tree().create_timer(1.5).timeout
		_hide_loading_screen()
		return

	if reload_audio:
		_update_loading(0.0, "Loading audio stems...")
		await get_tree().create_timer(0.0).timeout

		if not AudioManager.load_stems(song_path):
			_update_loading(0.25, "No audio found (silent gameplay)")
		else:
			_update_loading(0.4, "Audio loaded, reading chart...")
		await get_tree().create_timer(0.0).timeout
	else:
		# Changing difficulty reuses the stems already in memory: only the chart
		# has to be read again.
		_update_loading(0.4, "Reading chart...")
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

	_begin_run(duration)

	_update_loading(1.0, "Ready!")
	await get_tree().create_timer(0.0).timeout
	_hide_loading_screen()


# Starts a run from the data already in memory. It is shared by the first load
# and by restart (rewind): both need the same clock, state and haptic setup.
func _begin_run(duration: float) -> void:
	GameManager.set_state(GameManager.GameState.PLAYING)
	TimingEngine.start(duration, GameManager.current_song_delay / 1000.0)

	if SettingsManager.haptic_enabled or GameManager.mode == GameManager.GameMode.HAPTIC:
		InputManager.haptic_kick_enabled = true
		InputManager.start_calibration()
		# A restart may happen while the previous calibration is still pending:
		# connecting the one-shot again would be an error.
		if not InputManager.calibration_completed.is_connected(_on_haptic_calibration_completed):
			InputManager.calibration_completed.connect(_on_haptic_calibration_completed, CONNECT_ONE_SHOT)
		_show_calibration_label()
	else:
		InputManager.haptic_kick_enabled = false


func _show_calibration_label() -> void:
	if _calibration_label:
		return
	_calibration_label = Label.new()
	_calibration_label.name = "CalibrationLabel"
	_calibration_label.text = "CALIBRATING..."
	_calibration_label.add_theme_font_size_override("font_size", 18)
	_calibration_label.add_theme_color_override("font_color", Palette.ACCENT_GLOW)
	_calibration_label.add_theme_color_override("font_shadow_color", Palette.INK_SOFT)
	_calibration_label.add_theme_constant_override("shadow_offset_x", 1)
	_calibration_label.add_theme_constant_override("shadow_offset_y", 1)
	_calibration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_calibration_label.position = Vector2(0, CALIBRATION_LABEL_TOP)
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
	if _pause_button:
		_pause_button.hide()
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
		# Restart is synchronous now: hide it before queue_free() so the result
		# panel is not drawn over the first frame of the new run.
		_result_overlay.visible = false
		_result_overlay.queue_free()
		_result_overlay = null
	_is_result_shown = false
	_result_pending = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back_handled_time = Time.get_ticks_msec() / 1000.0
		_handle_back()
		get_viewport().set_input_as_handled()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		# _ready() disables auto_accept_quit, so the window close button and
		# the desktop close shortcut are only honored if this branch quits.
		get_tree().quit()


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
	if _pause_button:
		_pause_button.hide()
	GameManager.set_state(GameManager.GameState.PAUSED)
	_show_pause_overlay()


func _resume_game() -> void:
	_is_paused = false
	if _pause_button:
		_pause_button.show()
	_hide_pause_overlay()
	GameManager.set_state(GameManager.GameState.PLAYING)
	TimingEngine.resume()


func _restart_song() -> void:
	# The initial load is already replacing everything: restarting on top of it
	# would start two runs.
	if _is_loading:
		return
	_reset_run_state()

	# The audio stems and the parsed chart are still in memory, so a retry only
	# needs to rewind the run instead of reading the song from disk again.
	# TimingEngine.start() resets the clock and AudioManager.play() starts every
	# stem from position 0. Fall back to a full load only if the chart is missing.
	if ChartParser.has_data():
		_begin_run(ChartParser.get_duration_seconds())
	else:
		_start_loading()


# Clears the state of the current run. It is shared by restart and by a
# difficulty change, which also restarts the song from the beginning.
func _reset_run_state() -> void:
	_is_paused = false
	if _pause_button:
		_pause_button.show()
	_hide_pause_overlay()
	_hide_countdown()
	_hide_result_overlay()
	TimingEngine.stop()
	highway.restart()
	ScoreManager.reset()


# Difficulty of the current song: first from the scanned library (already in
# memory), then by reading the chart if the gameplay was started without it.
func _get_available_difficulties() -> Array:
	for song in SongLoader.song_list:
		if String(song.get("path", "")) == GameManager.current_song_path:
			var diffs: Array = song.get("difficulties", [])
			if not diffs.is_empty():
				return diffs
			break

	var notes_path: String = _find_notes_file(GameManager.current_song_path)
	if notes_path.is_empty():
		return []
	var info: Dictionary
	if notes_path.get_extension().to_lower() == "chart":
		info = preload("res://script/chart/DotChartParser.gd").detect_difficulties_fast(
			notes_path, SettingsManager.use_guitar_fallback
		)
	else:
		info = preload("res://script/chart/MidiParser.gd").detect_difficulties_fast(
			notes_path, SettingsManager.use_guitar_fallback
		)
	return info.get("difficulties", [])


# Changing difficulty needs a new chart, so it reloads the chart but keeps the
# audio stems that are already loaded.
func _on_pause_difficulty_pressed(offset: int, difficulty_name: String) -> void:
	if _is_loading or offset == GameManager.current_difficulty_offset:
		return
	GameManager.current_difficulty_offset = offset
	GameManager.current_difficulty_name = difficulty_name
	_reset_run_state()
	_start_loading(false)


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
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_overlay.add_child(bg)

	# The card lives in its own layer. The scroll container clips its content
	# to the card area, and in a single layer that clip also leaves the scrim
	# undrawn in the bottom margin on Android, so the screen edge below the
	# modal shows the gameplay without the dark overlay.
	_pause_modal_layer = CanvasLayer.new()
	_pause_modal_layer.name = "PauseModalLayer"
	_pause_modal_layer.layer = 11
	_pause_overlay.add_child(_pause_modal_layer)

	var modal := SettingsUI.ModalBody.new()
	modal.name = "PauseModal"
	_pause_modal = modal
	_pause_modal_layer.add_child(modal)

	var difficulties: Array = _get_available_difficulties()
	_pause_main_menu = _build_pause_main_menu(difficulties)
	_pause_difficulty_menu = _build_pause_difficulty_menu(difficulties)
	modal.add_card(_pause_main_menu)
	modal.add_card(_pause_difficulty_menu)

	add_child(_pause_overlay)


func _build_pause_main_menu(difficulties: Array) -> Control:
	var panel := PanelContainer.new()
	panel.name = "PauseMenu"
	panel.custom_minimum_size = Vector2(SettingsUI.px(360), 0)
	# PASS so a drag on the empty card area reaches the scroll layer that keeps
	# the modal inside the viewport on small screens. The scrim below still
	# stops clicks from reaching gameplay.
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var panel_style := SettingsUI.flat(Palette.SURFACE_1, 18)
	SettingsUI.pad(panel_style, SettingsUI.px(22), SettingsUI.px(14))
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	# PASS so touch drags over the card reach the modal's scroll layer. Buttons
	# are PASS too (see SettingsUI.button), so a swipe works on top of them.
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_theme_constant_override("separation", SettingsUI.px(4))
	panel.add_child(vbox)

	var title: Label = SettingsUI.label("PAUSED", 26, Palette.BONE_HI, 600)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Trim the font's empty leading so the song line sits close to the heading.
	SettingsUI.fit_line_height(title, SettingsUI.px(30))
	vbox.add_child(title)

	var track: String = GameManager.current_song_title
	if track.is_empty():
		track = GameManager.current_song_artist
	var subtitle: Label = SettingsUI.description(
		(track + "  ·  " + GameManager.current_difficulty_name) if not track.is_empty() else "Gameplay paused",
		Palette.ASH_DIM
	)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SettingsUI.fit_line_height(subtitle, SettingsUI.px(18))
	vbox.add_child(subtitle)

	var resume_btn: Button = SettingsUI.button("RESUME", "primary")
	resume_btn.name = "ResumeButton"
	resume_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resume_btn.pressed.connect(_resume_game)
	vbox.add_child(resume_btn)

	var restart_btn: Button = SettingsUI.button("RESTART", "secondary")
	restart_btn.name = "RestartButton"
	restart_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart_btn.pressed.connect(_restart_song)
	vbox.add_child(restart_btn)

	var change_difficulty_btn: Button = SettingsUI.button("CHANGE DIFFICULTY", "secondary")
	change_difficulty_btn.name = "ChangeDifficultyButton"
	change_difficulty_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	change_difficulty_btn.disabled = difficulties.is_empty()
	change_difficulty_btn.pressed.connect(_show_pause_difficulty_menu)
	vbox.add_child(change_difficulty_btn)

	var exit_btn: Button = SettingsUI.button("EXIT", "secondary")
	exit_btn.name = "ExitButton"
	exit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exit_btn.add_theme_color_override("font_color", Palette.ACCENT_GLOW)
	exit_btn.add_theme_color_override("font_hover_color", Palette.ACCENT_GLOW)
	exit_btn.add_theme_color_override("font_pressed_color", Palette.ACCENT_GLOW)
	exit_btn.pressed.connect(_exit_to_menu)
	vbox.add_child(exit_btn)

	return panel


func _build_pause_difficulty_menu(difficulties: Array) -> Control:
	var panel := PanelContainer.new()
	panel.name = "DifficultyMenu"
	panel.custom_minimum_size = Vector2(SettingsUI.px(360), 0)
	# See the main pause menu: PASS lets card drags scroll the modal body.
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.visible = false
	var panel_style := SettingsUI.flat(Palette.SURFACE_1, 18)
	SettingsUI.pad(panel_style, SettingsUI.px(22), SettingsUI.px(14))
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	# See the main pause menu: PASS lets card drags scroll the modal body.
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_theme_constant_override("separation", SettingsUI.px(4))
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_PASS
	header.add_theme_constant_override("separation", SettingsUI.px(10))
	vbox.add_child(header)

	var back_width: int = SettingsUI.px(70)
	var back_btn: Button = SettingsUI.button("BACK", "secondary")
	back_btn.name = "DifficultyBackButton"
	back_btn.custom_minimum_size = Vector2(back_width, SettingsUI.px(30))
	# Trim the default control padding so the button matches the heading's line
	# height and reads as part of the header instead of a large control.
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var back_style := back_btn.get_theme_stylebox(state) as StyleBoxFlat
		back_style.content_margin_left = SettingsUI.px(12)
		back_style.content_margin_right = SettingsUI.px(12)
		back_style.content_margin_top = SettingsUI.px(4)
		back_style.content_margin_bottom = SettingsUI.px(4)
	back_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back_btn.pressed.connect(_show_pause_main_menu)
	header.add_child(back_btn)

	var title: Label = SettingsUI.label("DIFFICULTY", 24, Palette.BONE_HI, 600)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	# Match the back button's width so the heading stays centred in the card.
	var header_spacer := Control.new()
	header_spacer.custom_minimum_size.x = back_width
	header_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(header_spacer)

	var list: VBoxContainer = VBoxContainer.new()
	list.name = "DifficultyList"
	list.alignment = BoxContainer.ALIGNMENT_CENTER
	list.mouse_filter = Control.MOUSE_FILTER_PASS
	list.add_theme_constant_override("separation", SettingsUI.px(4))
	vbox.add_child(list)

	# Only the difficulties present in this song, in Easy -> Expert+ order.
	var by_offset: Dictionary = {}
	for diff in difficulties:
		var off: int = int(diff.get("offset", -1))
		if off >= 0:
			by_offset[off] = diff
	var offsets: Array = by_offset.keys()
	offsets.sort()

	var group := ButtonGroup.new()
	for off in offsets:
		var diff: Dictionary = by_offset[off]
		var btn: Button = SettingsUI.button(String(diff.get("name", ChartData.DIFFICULTY_NAMES.get(off, str(off)))), "secondary")
		btn.name = "Difficulty" + str(off)
		btn.custom_minimum_size = Vector2(0, SettingsUI.px(44))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode = true
		btn.button_group = group
		btn.button_pressed = off == GameManager.current_difficulty_offset
		# Keep the same content margins as the "secondary" style so the selected
		# button doesn't shrink relative to the rest of the list.
		btn.add_theme_stylebox_override("pressed", SettingsUI.pad(SettingsUI.flat(Palette.ACCENT_SURFACE, 12), SettingsUI.px(22), SettingsUI.px(12)))
		btn.add_theme_stylebox_override("hover_pressed", SettingsUI.pad(SettingsUI.flat(Palette.ACCENT_SURFACE_HOVER, 12), SettingsUI.px(22), SettingsUI.px(12)))
		btn.add_theme_color_override("font_pressed_color", Palette.BONE_HI)
		btn.add_theme_color_override("font_hover_pressed_color", Palette.BONE_HI)
		btn.pressed.connect(_on_pause_difficulty_pressed.bind(off, btn.text))
		list.add_child(btn)

	return panel


func _show_pause_difficulty_menu() -> void:
	if is_instance_valid(_pause_main_menu):
		_pause_main_menu.hide()
	if is_instance_valid(_pause_difficulty_menu):
		_pause_difficulty_menu.show()
	if _pause_modal:
		_pause_modal.reset_scroll()


func _show_pause_main_menu() -> void:
	if is_instance_valid(_pause_main_menu):
		_pause_main_menu.show()
	if is_instance_valid(_pause_difficulty_menu):
		_pause_difficulty_menu.hide()
	if _pause_modal:
		_pause_modal.reset_scroll()


func _hide_pause_overlay() -> void:
	if _pause_overlay:
		# Restart is synchronous now: avoid drawing the pause menu over the
		# first frame of the new run.
		_pause_overlay.visible = false
		_pause_overlay.queue_free()
		_pause_overlay = null
	if _pause_modal_layer:
		_pause_modal_layer.visible = false
		_pause_modal_layer.queue_free()
		_pause_modal_layer = null
	_pause_modal = null
	_pause_main_menu = null
	_pause_difficulty_menu = null


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
