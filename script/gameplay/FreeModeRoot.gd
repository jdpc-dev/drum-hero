class_name FreeModeRoot
extends Node2D

# Free drum practice mode. Entered from Settings > Controls > Free Mode and there is no
# song, chart or score: the track appears empty and each hit plays its sample,
# flashes the hit line and launches particles.
#
# It intentionally reuses the real Highway so the lane order, gameplay padding
# and Android gesture exclusion are exactly those of the game. The one layout
# difference is the timeline band: without a song there is no clock to show, so
# the scene disables it and the track starts at the top edge.
#
# HitDetection is not set up: without a chart there is nothing to judge, so
# TouchInput receives null and its "no note was hit" branch is what triggers
# the sample.

const MAIN_SCENE := preload("res://scene/Main.tscn")
const BASE_LABEL_SETTINGS := preload("res://asset/fonts/label_settings.tres")
const METRONOME_SCRIPT := preload("res://script/gameplay/Metronome.gd")

@onready var highway = $Highway
@onready var touch_input = $TouchInput
@onready var hud = $HUD

var _total_hits: int = 0
var _haptic_active: bool = false
var _back_handled_time: float = 0.0
var _is_leaving: bool = false
var _is_paused: bool = false

var _pad_name_label: Label
var _hits_label: Label
var _fps_label: Label
var _debug_label: Label
var _calibration_label: Label
var _metronome
var _metronome_button: Button
var _pause_button: Button
var _pause_overlay: CanvasLayer


func _ready() -> void:
	SettingsUI.setup_ui_scale(get_viewport().get_visible_rect().size.y)
	get_tree().auto_accept_quit = false
	# The ChartParser autoload survives scene changes: without clearing it, the
	# last played song would leave notes falling down the track and counted as
	# missed instantly.
	ChartParser.clear()
	ScoreManager.reset()
	GameManager.set_state(GameManager.GameState.PLAYING)
	_setup_hud()
	_setup_metronome()
	_setup_haptic()
	_setup_input_when_ready()
	_setup_pause_button()


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
	var hit_position: Vector2 = highway.get_hit_global_position(lane_index)
	var lane_color: Color = Highway._get_lane_colors()[lane_index]
	EffectManager.trigger_particle_burst(
		hit_position,
		lane_color,
		highway,
		lane_index)

	# The same lane feedback used in gameplay; free mode is where the pads are
	# tested, so it should feel consistent.
	match lane_index:
		1:
			EffectManager.trigger_crash_impact(hit_position, highway, lane_color)
			EffectManager.trigger_crash_shockwave(hit_position, lane_color)
		0, 2, 3:
			EffectManager.trigger_drum_pulse(lane_index)
		4, 5, 6:
			EffectManager.trigger_lane_pulse("tom", hit_position, highway, lane_color)
		7:
			EffectManager.trigger_lane_pulse("ride", hit_position, highway, lane_color)


func _wait_for_draw() -> void:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw


func _warm_up_text() -> void:
	# The pad name and hit counter first get text on the first hit. Rasterise
	# their glyphs once at startup so that first hit stays smooth on Android.
	var samples: Array[Label] = []
	samples.append(_make_text_sample("HH CLOSED & OPEN TOM 1 2 3", 64, Palette.TEXT_DIM))
	samples.append(_make_text_sample("0123456789 hits", 22, Palette.ASH))
	await _wait_for_draw()
	await _wait_for_draw()
	for label in samples:
		label.queue_free()


func _make_text_sample(text: String, font_size: int, color: Color) -> Label:
	var label := _make_label(text, font_size, color)
	label.size = Vector2(1200, 120)
	label.modulate.a = 0.01
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(label)
	return label


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


# The pad that was hit is shown in the center of the track, which is exactly
# where notes would fall. The title sits just inside the top of the track,
# since free mode does not reserve the timeline band.
func _layout_hud() -> void:
	var vs: Vector2 = get_viewport_rect().size
	var pl: float = SettingsManager.dp_to_godot_px(SettingsManager.gameplay_padding_left) if SettingsManager.gameplay_padding_enabled else 0.0
	var pr: float = SettingsManager.dp_to_godot_px(SettingsManager.gameplay_padding_right) if SettingsManager.gameplay_padding_enabled else 0.0
	var pt: float = SettingsManager.dp_to_godot_px(SettingsManager.gameplay_padding_top) if SettingsManager.gameplay_padding_enabled else 0.0
	var content_w: float = vs.x - pl - pr

	var title := _make_label("FREE MODE", 18, Palette.BLOOD_GLOW)
	title.name = "TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.position = Vector2(pl, 1.0)
	title.size = Vector2(content_w, 22)
	hud.add_child(title)

	var hint := _make_label("Tap a pad or press 1-8", 13, Palette.ASH_DIM)
	hint.name = "HintLabel"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.position = Vector2(pl, 19.0)
	hint.size = Vector2(content_w, 20)
	hud.add_child(hint)

	var mid_y: float = pt + (vs.y - pt) * 0.30
	_pad_name_label.position = Vector2(pl, mid_y)
	_pad_name_label.size = Vector2(content_w, 80)

	_hits_label.position = Vector2(pl, mid_y + 84.0)
	_hits_label.size = Vector2(content_w, 32)


func _update_hits_label() -> void:
	if _hits_label:
		_hits_label.text = str(_total_hits) + (" hits" if _total_hits != 1 else " hit")


# ---------------------------------------------------------------- Metronome


# Same square icon button as the pause control, with an M drawn from vector
# lines instead of a generated texture. Keeping the M in _draw() means it
# scales cleanly and can change tone with the toggle/hover state.
class MetronomeIconButton extends Button:
	func _init() -> void:
		toggle_mode = true
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		toggled.connect(func(_enabled: bool) -> void: queue_redraw())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var color: Color = Palette.ACCENT if button_pressed else (
			Palette.BONE if is_hovered() else Palette.TEXT_DIM
		)
		var scale: float = minf(size.x, size.y) / 48.0
		var center: Vector2 = size * 0.5
		var points := PackedVector2Array([
			center + Vector2(-8.0, 9.0) * scale,
			center + Vector2(-8.0, -9.0) * scale,
			center + Vector2(0.0, 2.0) * scale,
			center + Vector2(8.0, -9.0) * scale,
			center + Vector2(8.0, 9.0) * scale,
		])
		draw_polyline(points, color, maxf(1.5, 3.2 * scale), true)


# Free mode has no song or chart tempo, so the metronome runs at a fixed 120
# BPM. The button is the only control: it lives in the top-left corner, away
# from the centred pause button and the track labels.
func _setup_metronome() -> void:
	_metronome = METRONOME_SCRIPT.new()
	_metronome.name = "Metronome"
	add_child(_metronome)

	_metronome_button = MetronomeIconButton.new()
	_metronome_button.name = "MetronomeButton"
	_metronome_button.custom_minimum_size = Vector2(38, 38)
	_metronome_button.tooltip_text = "Metronome (%d BPM)" % int(_metronome.get_bpm())
	_metronome_button.toggled.connect(_on_metronome_toggled)
	hud.add_child(_metronome_button)

	var pl: float = 0.0
	if SettingsManager.gameplay_padding_enabled:
		pl = SettingsManager.dp_to_godot_px(SettingsManager.gameplay_padding_left)
	var inset: float = SettingsUI.px(4)
	_metronome_button.anchor_left = 0.0
	_metronome_button.anchor_top = 0.0
	_metronome_button.anchor_right = 0.0
	_metronome_button.anchor_bottom = 0.0
	_metronome_button.offset_left = pl + inset
	_metronome_button.offset_top = inset
	_metronome_button.offset_right = _metronome_button.offset_left + 38.0
	_metronome_button.offset_bottom = _metronome_button.offset_top + 38.0


func _on_metronome_toggled(enabled: bool) -> void:
	if _metronome == null:
		return
	if enabled:
		_metronome.start()
	else:
		_metronome.stop()


func _process(_delta: float) -> void:
	_update_haptic_debug()
	if _is_paused:
		return
	_update_hits_label()
	if SettingsManager.show_fps:
		_ensure_fps_label()
	elif _fps_label:
		_fps_label.queue_free()
		_fps_label = null


# Free mode is where the haptic kick is tested, so the same accelerometer
# readout shown in gameplay is available here whenever the setting is on.
func _update_haptic_debug() -> void:
	if SettingsManager.haptic_show_debug:
		_show_debug(InputManager.get_haptic_debug_string())
	elif _debug_label:
		_debug_label.text = ""
		_debug_label.queue_free()
		_debug_label = null


func _show_debug(msg: String) -> void:
	if not _debug_label:
		var pl: float = 0.0
		if SettingsManager.gameplay_padding_enabled:
			pl = SettingsManager.dp_to_godot_px(SettingsManager.gameplay_padding_left)
		_debug_label = _make_label(msg, 14, Palette.BLOOD_BRIGHT)
		_debug_label.name = "DebugLabel"
		# Below the FPS readout and clear of the centred pause button.
		_debug_label.position = Vector2(10.0 + pl, 100.0)
		hud.add_child(_debug_label)
	else:
		_debug_label.text = msg


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


# ---------------------------------------------------------------- Pause


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
	if _is_paused:
		_resume_game()
	else:
		_pause_game()


func _pause_game() -> void:
	_is_paused = true
	if _metronome:
		_metronome.stop()
	if _pause_button:
		_pause_button.hide()
	if _metronome_button:
		_metronome_button.hide()
	GameManager.set_state(GameManager.GameState.PAUSED)
	_show_pause_overlay()


func _resume_game() -> void:
	_is_paused = false
	if _pause_button:
		_pause_button.show()
	if _metronome_button:
		_metronome_button.show()
	_hide_pause_overlay()
	_resume_metronome_if_enabled()
	GameManager.set_state(GameManager.GameState.PLAYING)


func _resume_metronome_if_enabled() -> void:
	if _metronome and _metronome_button and _metronome_button.button_pressed:
		_metronome.start()


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

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "PauseMenu"
	panel.custom_minimum_size = Vector2(SettingsUI.px(360), 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := SettingsUI.flat(Palette.SURFACE_1, 18)
	SettingsUI.pad(panel_style, SettingsUI.px(26), SettingsUI.px(22))
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SettingsUI.px(8))
	panel.add_child(vbox)

	var title: Label = SettingsUI.label("PAUSED", 26, Palette.BONE_HI, 600)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle: Label = SettingsUI.description("Free mode - no song or score", Palette.ASH_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	var resume_btn: Button = SettingsUI.button("RESUME", "primary")
	resume_btn.name = "ResumeButton"
	resume_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resume_btn.pressed.connect(_resume_game)
	vbox.add_child(resume_btn)

	var restart_btn: Button = SettingsUI.button("RESTART", "secondary")
	restart_btn.name = "RestartButton"
	restart_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart_btn.pressed.connect(_restart_free_mode)
	vbox.add_child(restart_btn)

	var exit_btn: Button = SettingsUI.button("EXIT", "secondary")
	exit_btn.name = "ExitButton"
	exit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exit_btn.add_theme_color_override("font_color", Palette.BLOOD_GLOW)
	exit_btn.add_theme_color_override("font_hover_color", Palette.BLOOD_GLOW)
	exit_btn.add_theme_color_override("font_pressed_color", Palette.BLOOD_GLOW)
	exit_btn.pressed.connect(_exit_to_menu)
	vbox.add_child(exit_btn)

	add_child(_pause_overlay)


func _restart_free_mode() -> void:
	_is_paused = false
	_hide_pause_overlay()
	if _pause_button:
		_pause_button.show()
	if _metronome_button:
		_metronome_button.show()
	_resume_metronome_if_enabled()
	GameManager.set_state(GameManager.GameState.PLAYING)
	# Reset state
	_total_hits = 0
	_update_hits_label()
	if _pad_name_label:
		_pad_name_label.text = ""


func _hide_pause_overlay() -> void:
	if _pause_overlay:
		_pause_overlay.visible = false
		_pause_overlay.queue_free()
		_pause_overlay = null


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
		if _is_paused:
			_resume_game()
		else:
			_toggle_pause()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back_handled_time = Time.get_ticks_msec() / 1000.0
		if _is_paused:
			_resume_game()
		else:
			_toggle_pause()
		get_viewport().set_input_as_handled()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		# _ready() disables auto_accept_quit, so the window close button and
		# the desktop close shortcut are only honored if this branch quits:
		# otherwise free mode has no way out but the in-game pause menu.
		if _metronome:
			_metronome.stop()
		get_tree().quit()


func _exit_to_menu() -> void:
	if not is_inside_tree() or _is_leaving:
		return
	_is_leaving = true
	_hide_pause_overlay()
	if _metronome:
		_metronome.stop()
	if _pause_button:
		_pause_button.hide()
	if _metronome_button:
		_metronome_button.hide()
	_is_paused = false
	InputManager.haptic_kick_enabled = false
	# With the kick off the signal was never connected, and disconnecting an
	# unconnected Callable is an error in Godot: it is checked beforehand.
	if InputManager.kick_detected.is_connected(_on_kick_pressed):
		InputManager.kick_detected.disconnect(_on_kick_pressed)
	AndroidBridge.clear_exclusion()
	ScoreManager.reset()
	GameManager.set_state(GameManager.GameState.MENU)
	get_tree().change_scene_to_packed(MAIN_SCENE)
