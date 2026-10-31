class_name SettingsRoot
extends CanvasLayer

# Ajustes no cambia de escena por su cuenta: emite la peticion y es MenuRoot
# (la pantalla que lo aloja) quien decide abrir el modo libre.
signal free_mode_requested()

var _label_settings: LabelSettings = preload("res://asset/fonts/label_settings.tres")

var _current_tab: int = 0
var _tab_buttons: Array[Button] = []
var _content_container: VBoxContainer

# CONTROLS tab elements
var _mode_buttons: Array[CheckBox] = []
var _custom_lane_container: VBoxContainer
var _haptic_sensitivity_label: Label
var _haptic_enabled_check: CheckBox

# HUD tab elements
var _hud_fps_check: CheckBox
var _fps_cap_slider: HSlider
var _fps_cap_label: Label
var _hud_shake_check: CheckBox
var _hud_feedback_check: CheckBox
var _note_speed_slider: HSlider
var _audio_offset_slider: HSlider
var _audio_offset_label: Label
var _note_speed_label: Label
var _countdown_slider: HSlider
var _countdown_label: Label

# SONGS tab elements
var _permission_status: Label
var _permission_button: Button
var _permission_was_granted: bool = false
var _preset_downloads_check: CheckBox
var _preset_documents_check: CheckBox
var _recursive_check: CheckBox
var _depth_option: OptionButton
var _roots_container: VBoxContainer
var _rescan_button: Button
var _cancel_scan_button: Button
var _scan_bar: ProgressBar
var _scan_status: Label
var _scan_folder: Label
var _scan_summary: Label
var _scan_pump_active: bool = false
var _songs_link_status: Label


# Experimental tab elements
var _fallback_check: CheckBox
var _free_mode_button: Button
var _sample_velocity_slider: HSlider
var _sample_velocity_label: Label
var _judgment_areas_check: CheckBox
var _menu_status_check: CheckBox
var _padding_check: CheckBox
var _padding_left_slider: HSlider
var _padding_left_label: Label
var _padding_right_slider: HSlider
var _padding_right_label: Label
var _padding_top_slider: HSlider
var _padding_top_label: Label
var _padding_bottom_slider: HSlider
var _padding_bottom_label: Label

const LANE_LABELS: PackedStringArray = [
	"HH", "CRASH", "SNARE", "KICK",
	"TOM 1", "TOM 2", "TOM 3", "RIDE",
]

const SONGS_TAB: int = 2
const SONGS_LINKTREE_URL: String = "https://linktr.ee/com.drum.hero"

const LANE_COLORS: Array[Color] = [
	Color(0.9, 0.8, 0.2),
	Color(1.0, 0.6, 0.0),
	Color(0.8, 0.2, 0.2),
	Color(0.6, 0.4, 0.8),
	Color(0.2, 0.7, 0.9),
	Color(0.2, 0.9, 0.5),
	Color(0.9, 0.3, 0.6),
	Color(0.5, 0.8, 0.3),
]


func _ready() -> void:
	layer = 10
	SongLoader.scan_progress.connect(_on_scan_progress)
	_build_ui()
	_load_current_settings()


func _exit_tree() -> void:
	# El escaneo vive en SongLoader, asi que hay que pararlo aqui o el menu se
	# encontraria is_scanning = true al volver. Este _exit_tree corre antes del
	# tree_exited que escucha MenuRoot, asi que su reescaneo ya sale limpio.
	_abort_scan()


func _process(_delta: float) -> void:
	# El recorrido avanza desde _process y no desde un await: asi el panel
	# puede cerrarse en mitad de un lote sin dejar nada colgando.
	if not _scan_pump_active:
		return
	if SongLoader.pump_scan(SongLoader.frame_deadline_usec()):
		_finish_scan()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		# Se vuelve de la pantalla de Ajustes del sistema: el permiso pudo
		# cambiar. Sin esto el panel seguiria diciendo "Not granted" y el usuario
		# creeria que el boton no hace nada.
		_refresh_permission_state()


func _refresh_permission_state() -> void:
	if not is_instance_valid(_permission_status):
		return
	var had_access: bool = _permission_was_granted
	var has_access: bool = AndroidBridge.has_all_files_access()
	_permission_was_granted = has_access
	_update_permission_section()
	if has_access and not had_access:
		_scan_summary_and_rescan()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Palette.NIGHT_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	var header_scroll := ScrollContainer.new()
	header_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_scroll.custom_minimum_size.y = 110
	header_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	header_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(header_scroll)

	var header_vbox := VBoxContainer.new()
	header_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_scroll.add_child(header_vbox)

	_build_header(header_vbox)
	_build_tab_bar(header_vbox)

	var content_scroll := ScrollContainer.new()
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(content_scroll)

	_content_container = VBoxContainer.new()
	_content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.add_child(_content_container)

	_build_tab_content()


func _build_header(parent: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 60
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(header)

	var left_spacer := Control.new()
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(left_spacer)

	var title := Label.new()
	title.text = "SETTINGS"
	title.label_settings = _label_settings
	title.add_theme_font_size_override("font_size", 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)

	var right_spacer := Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(right_spacer)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(100, 40)
	back_btn.pressed.connect(_on_back)
	header.add_child(back_btn)


func _build_tab_bar(parent: VBoxContainer) -> void:
	var tab_bg := PanelContainer.new()
	tab_bg.custom_minimum_size.y = 50
	tab_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.NIGHT_PANEL
	tab_bg.add_theme_stylebox_override("panel", sb)
	parent.add_child(tab_bg)

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_bg.add_child(hbox)

	var tab_names := ["CONTROLS", "HUD", "SONGS", "Experimental", "CREDITS"]
	for i in tab_names.size():
		var btn := Button.new()
		btn.text = tab_names[i]
		btn.custom_minimum_size = Vector2(200, 40)
		btn.toggle_mode = true
		btn.pressed.connect(_on_tab_selected.bind(i))
		hbox.add_child(btn)
		_tab_buttons.append(btn)
		if i < tab_names.size() - 1:
			var sep := Control.new()
			sep.custom_minimum_size = Vector2(10, 0)
			hbox.add_child(sep)

	_tab_buttons[0].button_pressed = true


func _on_tab_selected(tab_index: int) -> void:
	_current_tab = tab_index
	for i in _tab_buttons.size():
		_tab_buttons[i].button_pressed = (i == tab_index)
	if _current_tab != SONGS_TAB:
		# El escaneo es de esta pestaña: si el jugador se va, se para. Los
		# widgets se destruyen con el contenido y no tiene sentido seguirlos.
		_abort_scan()
	_build_tab_content()


func _build_tab_content() -> void:
	for child in _content_container.get_children():
		child.queue_free()

	match _current_tab:
		0:
			_build_controls_content(_content_container)
		1:
			_build_hud_content(_content_container)
		SONGS_TAB:
			_build_songs_content(_content_container)
		3:
			_build_experimental_content(_content_container)
		4:
			_build_credits_content(_content_container)


func _build_controls_content(parent: VBoxContainer) -> void:
	_mode_buttons.clear()

	_add_section_title(parent, "CONTROL MODE")
	parent.add_child(_spacer(10))

	var modes: Array[Dictionary] = [
		{"label": "Default", "desc": "8 lanes — all drum parts visible", "mode": 0},
		{"label": "Haptic", "desc": "7 lanes — KICK via device motion sensor", "mode": 1},
		{"label": "Custom", "desc": "Reorder lanes manually", "mode": 2},
	]
	for m_data in modes:
		var hbox := HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var btn := CheckBox.new()
		btn.text = m_data.label
		btn.add_theme_font_size_override("font_size", 22)
		btn.add_theme_color_override("font_color", Palette.TEXT_DIM)
		btn.set_pressed_no_signal(m_data.mode == SettingsManager.game_mode)
		btn.toggled.connect(_on_mode_toggled.bind(m_data.mode))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(btn)
		_mode_buttons.append(btn)

		var desc := Label.new()
		desc.text = m_data.desc
		desc.add_theme_font_size_override("font_size", 14)
		desc.add_theme_color_override("font_color", Palette.ASH_DIM)
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(desc)

		parent.add_child(hbox)

	parent.add_child(_spacer(20))
	_add_section_title(parent, "LANE ORDER (CUSTOM MODE)")
	parent.add_child(_spacer(10))

	_custom_lane_container = VBoxContainer.new()
	_custom_lane_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(_custom_lane_container)

	_rebuild_custom_lane_ui(SettingsManager.custom_lanes)
	_custom_lane_container.visible = (SettingsManager.game_mode == 2)

	parent.add_child(_spacer(20))
	_add_section_title(parent, "HAPTIC")
	parent.add_child(_spacer(10))

	var haptic_enabled_hbox := HBoxContainer.new()
	haptic_enabled_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_haptic_enabled_check = CheckBox.new()
	_haptic_enabled_check.text = "Enable Haptic Kick"
	_haptic_enabled_check.add_theme_font_size_override("font_size", 22)
	_haptic_enabled_check.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_haptic_enabled_check.set_pressed_no_signal(SettingsManager.haptic_enabled)
	_haptic_enabled_check.toggled.connect(_on_haptic_enabled_toggled)
	_haptic_enabled_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_haptic_enabled_check.disabled = (SettingsManager.game_mode == 1)
	haptic_enabled_hbox.add_child(_haptic_enabled_check)
	parent.add_child(haptic_enabled_hbox)

	var haptic_sens_hbox := HBoxContainer.new()
	haptic_sens_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haptic_sens_hbox.add_theme_constant_override("separation", 10)
	var haptic_sens_label := Label.new()
	haptic_sens_label.text = "Sensitivity"
	haptic_sens_label.add_theme_font_size_override("font_size", 18)
	haptic_sens_label.add_theme_color_override("font_color", Palette.TEXT_DIM)
	haptic_sens_label.custom_minimum_size = Vector2(120, 0)
	haptic_sens_hbox.add_child(haptic_sens_label)

	var haptic_sensitivity_slider := HSlider.new()
	haptic_sensitivity_slider.min_value = 0.1
	haptic_sensitivity_slider.max_value = 3.0
	haptic_sensitivity_slider.step = 0.1
	haptic_sensitivity_slider.value = SettingsManager.haptic_sensitivity
	haptic_sensitivity_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haptic_sensitivity_slider.value_changed.connect(_on_haptic_sensitivity_changed)
	haptic_sensitivity_slider.drag_ended.connect(_on_haptic_sensitivity_drag_ended)
	haptic_sens_hbox.add_child(haptic_sensitivity_slider)

	_haptic_sensitivity_label = Label.new()
	_haptic_sensitivity_label.text = str(SettingsManager.haptic_sensitivity)
	_haptic_sensitivity_label.add_theme_font_size_override("font_size", 16)
	_haptic_sensitivity_label.add_theme_color_override("font_color", Palette.ASH_DIM)
	_haptic_sensitivity_label.custom_minimum_size = Vector2(40, 0)
	haptic_sens_hbox.add_child(_haptic_sensitivity_label)
	parent.add_child(haptic_sens_hbox)

	var haptic_desc := Label.new()
	haptic_desc.text = "Adjust how hard you need to tap for kick detection"
	haptic_desc.add_theme_font_size_override("font_size", 14)
	haptic_desc.add_theme_color_override("font_color", Palette.ASH_DIM)
	parent.add_child(haptic_desc)

	parent.add_child(_spacer(15))
	_add_section_title(parent, "ADVANCED HAPTIC TUNING")
	parent.add_child(_spacer(5))

	_haptic_add_threshold_slider(parent, "Activation", SettingsManager.haptic_activation_threshold, 0.5, 12.0, 0.5, _on_haptic_activation_changed, _on_haptic_any_drag_ended)
	_haptic_add_threshold_slider(parent, "Release", SettingsManager.haptic_release_threshold, 0.1, 8.0, 0.5, _on_haptic_release_changed, _on_haptic_any_drag_ended)
	_haptic_add_threshold_slider(parent, "Cooldown (s)", SettingsManager.haptic_cooldown_duration, 0.05, 0.5, 0.01, _on_haptic_cooldown_changed, _on_haptic_any_drag_ended)
	_haptic_add_threshold_slider(parent, "Min Interval (s)", SettingsManager.haptic_min_interval, 0.02, 0.3, 0.01, _on_haptic_min_interval_changed, _on_haptic_any_drag_ended)
	_haptic_add_threshold_slider(parent, "Smoothing", SettingsManager.haptic_smoothing_strength, 0.01, 0.5, 0.01, _on_haptic_smoothing_changed, _on_haptic_any_drag_ended)

	var advanced_desc := Label.new()
	advanced_desc.text = "Activation = lift threshold, Release = when kick resets ( ÷ by Sensitivity slider )."
	advanced_desc.add_theme_font_size_override("font_size", 14)
	advanced_desc.add_theme_color_override("font_color", Palette.ASH_DIM)
	parent.add_child(advanced_desc)

	parent.add_child(_spacer(20))
	_add_section_title(parent, "LAYOUT")
	parent.add_child(_spacer(10))

	var mirrored_check := CheckBox.new()
	mirrored_check.text = "Mirrored Layout"
	mirrored_check.add_theme_font_size_override("font_size", 22)
	mirrored_check.add_theme_color_override("font_color", Palette.TEXT_DIM)
	mirrored_check.set_pressed_no_signal(SettingsManager.mirrored)
	mirrored_check.toggled.connect(_on_mirrored_toggled)
	parent.add_child(mirrored_check)

	var left_handed_check := CheckBox.new()
	left_handed_check.text = "Left Handed Mode"
	left_handed_check.add_theme_font_size_override("font_size", 22)
	left_handed_check.add_theme_color_override("font_color", Palette.TEXT_DIM)
	left_handed_check.set_pressed_no_signal(SettingsManager.left_handed)
	left_handed_check.toggled.connect(_on_left_handed_toggled)
	parent.add_child(left_handed_check)

	parent.add_child(_spacer(30))
	_add_reset_section_button(parent, "CONTROLS", _on_reset_controls)


func _build_hud_content(parent: VBoxContainer) -> void:
	_add_section_title(parent, "VISUAL")
	parent.add_child(_spacer(10))

	_hud_fps_check = CheckBox.new()
	_hud_fps_check.text = "Show FPS"
	_hud_fps_check.add_theme_font_size_override("font_size", 22)
	_hud_fps_check.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_hud_fps_check.set_pressed_no_signal(SettingsManager.show_fps)
	_hud_fps_check.toggled.connect(_on_fps_toggled)
	parent.add_child(_hud_fps_check)

	var fps_cap_hbox := HBoxContainer.new()
	fps_cap_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fps_cap_hbox.add_theme_constant_override("separation", 10)
	var fps_cap_label_w := Label.new()
	fps_cap_label_w.text = "Max FPS"
	fps_cap_label_w.add_theme_font_size_override("font_size", 18)
	fps_cap_label_w.add_theme_color_override("font_color", Palette.TEXT_DIM)
	fps_cap_label_w.custom_minimum_size = Vector2(120, 0)
	fps_cap_hbox.add_child(fps_cap_label_w)

	_fps_cap_slider = HSlider.new()
	_fps_cap_slider.min_value = 0.0
	_fps_cap_slider.max_value = 120.0
	_fps_cap_slider.step = 10.0
	_fps_cap_slider.value = SettingsManager.max_fps
	_fps_cap_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fps_cap_slider.value_changed.connect(_on_fps_cap_changed)
	_fps_cap_slider.drag_ended.connect(_on_fps_cap_drag_ended)
	fps_cap_hbox.add_child(_fps_cap_slider)

	_fps_cap_label = Label.new()
	_fps_cap_label.text = _fps_cap_text(SettingsManager.max_fps)
	_fps_cap_label.add_theme_font_size_override("font_size", 16)
	_fps_cap_label.add_theme_color_override("font_color", Palette.ASH_DIM)
	_fps_cap_label.custom_minimum_size = Vector2(60, 0)
	fps_cap_hbox.add_child(_fps_cap_label)
	parent.add_child(fps_cap_hbox)

	_hud_shake_check = CheckBox.new()
	_hud_shake_check.text = "Screen Shake"
	_hud_shake_check.add_theme_font_size_override("font_size", 22)
	_hud_shake_check.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_hud_shake_check.set_pressed_no_signal(SettingsManager.screen_shake)
	_hud_shake_check.toggled.connect(_on_screen_shake_toggled)
	parent.add_child(_hud_shake_check)

	_hud_feedback_check = CheckBox.new()
	_hud_feedback_check.text = "Show Hit Feedback"
	_hud_feedback_check.add_theme_font_size_override("font_size", 22)
	_hud_feedback_check.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_hud_feedback_check.set_pressed_no_signal(SettingsManager.show_hit_feedback)
	_hud_feedback_check.toggled.connect(_on_hit_feedback_toggled)
	parent.add_child(_hud_feedback_check)

	var feedback_desc := Label.new()
	feedback_desc.text = "Show judgement text (PERFECT, GOOD, etc.) at the hit line"
	feedback_desc.add_theme_font_size_override("font_size", 14)
	feedback_desc.add_theme_color_override("font_color", Palette.ASH_DIM)
	parent.add_child(feedback_desc)

	parent.add_child(_spacer(20))
	_add_section_title(parent, "GAMEPLAY")
	parent.add_child(_spacer(10))

	var speed_hbox := HBoxContainer.new()
	speed_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed_hbox.add_theme_constant_override("separation", 10)
	var speed_label := Label.new()
	speed_label.text = "Note Speed"
	speed_label.add_theme_font_size_override("font_size", 18)
	speed_label.add_theme_color_override("font_color", Palette.TEXT_DIM)
	speed_label.custom_minimum_size = Vector2(120, 0)
	speed_hbox.add_child(speed_label)

	_note_speed_slider = HSlider.new()
	_note_speed_slider.min_value = 0.5
	_note_speed_slider.max_value = 3.0
	_note_speed_slider.step = 0.25
	_note_speed_slider.value = SettingsManager.note_speed
	_note_speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note_speed_slider.value_changed.connect(_on_note_speed_changed)
	_note_speed_slider.drag_ended.connect(_on_note_speed_drag_ended)
	speed_hbox.add_child(_note_speed_slider)

	_note_speed_label = Label.new()
	_note_speed_label.text = "x" + str(SettingsManager.note_speed)
	_note_speed_label.add_theme_font_size_override("font_size", 16)
	_note_speed_label.add_theme_color_override("font_color", Palette.ASH_DIM)
	_note_speed_label.custom_minimum_size = Vector2(40, 0)
	speed_hbox.add_child(_note_speed_label)
	parent.add_child(speed_hbox)

	var countdown_hbox := HBoxContainer.new()
	countdown_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	countdown_hbox.add_theme_constant_override("separation", 10)
	var countdown_label := Label.new()
	countdown_label.text = "Silence Countdown"
	countdown_label.add_theme_font_size_override("font_size", 18)
	countdown_label.add_theme_color_override("font_color", Palette.TEXT_DIM)
	countdown_label.custom_minimum_size = Vector2(120, 0)
	countdown_hbox.add_child(countdown_label)

	_countdown_slider = HSlider.new()
	_countdown_slider.min_value = 1.0
	_countdown_slider.max_value = 15.0
	_countdown_slider.step = 0.5
	_countdown_slider.value = SettingsManager.countdown_threshold
	_countdown_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_countdown_slider.value_changed.connect(_on_countdown_changed)
	_countdown_slider.drag_ended.connect(_on_countdown_drag_ended)
	countdown_hbox.add_child(_countdown_slider)

	_countdown_label = Label.new()
	_countdown_label.text = str(SettingsManager.countdown_threshold) + "s"
	_countdown_label.add_theme_font_size_override("font_size", 16)
	_countdown_label.add_theme_color_override("font_color", Palette.ASH_DIM)
	_countdown_label.custom_minimum_size = Vector2(40, 0)
	countdown_hbox.add_child(_countdown_label)
	parent.add_child(countdown_hbox)

	parent.add_child(_spacer(20))
	_add_section_title(parent, "JUDGEMENT WINDOWS")
	parent.add_child(_spacer(10))

	var judgement_data: Array[Dictionary] = [
		{"label": "Perfect", "key": "judgement_perfect_ms"},
		{"label": "Excellent", "key": "judgement_excellent_ms"},
		{"label": "Good", "key": "judgement_good_ms"},
		{"label": "Late", "key": "judgement_late_ms"},
		{"label": "Early", "key": "judgement_early_ms"},
		{"label": "Miss", "key": "judgement_miss_ms"},
	]
	for jd in judgement_data:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 10)
		var name_lbl := Label.new()
		name_lbl.text = jd.label
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Palette.TEXT_DIM)
		name_lbl.custom_minimum_size = Vector2(100, 0)
		row.add_child(name_lbl)

		var val_lbl := Label.new()
		var val: float = SettingsManager.get(jd.key)
		val_lbl.text = "±" + str(val) + " ms"
		val_lbl.add_theme_font_size_override("font_size", 16)
		val_lbl.add_theme_color_override("font_color", Palette.ASH_DIM)
		row.add_child(val_lbl)
		parent.add_child(row)

	parent.add_child(_spacer(20))
	_add_section_title(parent, "AUDIO CALIBRATION")
	parent.add_child(_spacer(10))

	_audio_offset_slider = HSlider.new()
	_audio_offset_slider.min_value = -200.0
	_audio_offset_slider.max_value = 200.0
	_audio_offset_slider.step = 1.0
	_audio_offset_slider.value = SettingsManager.audio_offset_ms
	_audio_offset_slider.custom_minimum_size = Vector2(200, 0)
	_audio_offset_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_audio_offset_slider.value_changed.connect(_on_audio_offset_changed)
	parent.add_child(_audio_offset_slider)

	var offset_row := HBoxContainer.new()
	offset_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var offset_name := Label.new()
	offset_name.text = "Note offset"
	offset_name.add_theme_font_size_override("font_size", 16)
	offset_name.add_theme_color_override("font_color", Palette.TEXT_DIM)
	offset_name.custom_minimum_size = Vector2(100, 0)
	offset_row.add_child(offset_name)
	_audio_offset_label = Label.new()
	_audio_offset_label.add_theme_font_size_override("font_size", 16)
	_audio_offset_label.add_theme_color_override("font_color", Palette.ASH_DIM)
	offset_row.add_child(_audio_offset_label)
	parent.add_child(offset_row)
	_update_audio_offset_label()

	var offset_desc := Label.new()
	offset_desc.text = "Raise it if notes feel early, lower it if they feel late. Added to the song delay."
	offset_desc.add_theme_font_size_override("font_size", 14)
	offset_desc.add_theme_color_override("font_color", Palette.ASH_DIM)
	parent.add_child(offset_desc)

	parent.add_child(_spacer(30))
	_add_reset_section_button(parent, "HUD", _on_reset_hud)


func _update_audio_offset_label() -> void:
	if _audio_offset_label == null:
		return
	var val: float = SettingsManager.audio_offset_ms
	var sign_txt: String = "+" if val > 0.0 else ""
	_audio_offset_label.text = sign_txt + str(val) + " ms"


func _on_audio_offset_changed(value: float) -> void:
	SettingsManager.audio_offset_ms = value
	_update_audio_offset_label()
	SettingsManager.save_settings()


func _build_experimental_content(parent: VBoxContainer) -> void:
	_add_section_title(parent, "FREE MODE")
	parent.add_child(_spacer(10))

	_free_mode_button = Button.new()
	_free_mode_button.name = "FreeModeButton"
	_free_mode_button.text = "Open Free Mode"
	_free_mode_button.custom_minimum_size = Vector2(280, 40)
	_free_mode_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_free_mode_button.pressed.connect(_on_free_mode_pressed)
	parent.add_child(_free_mode_button)

	var free_mode_desc := Label.new()
	free_mode_desc.name = "FreeModeDesc"
	free_mode_desc.text = "Drum testing without a song: hit any pad to hear it and check lane order, layout and the haptic pedal"
	free_mode_desc.add_theme_font_size_override("font_size", 14)
	free_mode_desc.add_theme_color_override("font_color", Palette.ASH_DIM)
	free_mode_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	free_mode_desc.custom_minimum_size = Vector2(280, 0)
	parent.add_child(free_mode_desc)

	parent.add_child(_spacer(20))
	_add_section_title(parent, "DRUM SAMPLES")
	parent.add_child(_spacer(10))

	var velocity_hbox := HBoxContainer.new()
	velocity_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	velocity_hbox.add_theme_constant_override("separation", 10)
	var velocity_name := Label.new()
	velocity_name.text = "Default Velocity"
	velocity_name.add_theme_font_size_override("font_size", 18)
	velocity_name.add_theme_color_override("font_color", Palette.TEXT_DIM)
	velocity_name.custom_minimum_size = Vector2(140, 0)
	velocity_hbox.add_child(velocity_name)

	_sample_velocity_slider = HSlider.new()
	_sample_velocity_slider.min_value = 0.0
	_sample_velocity_slider.max_value = 127.0
	_sample_velocity_slider.step = 1.0
	_sample_velocity_slider.value = SettingsManager.default_sample_velocity
	_sample_velocity_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sample_velocity_slider.value_changed.connect(_on_sample_velocity_changed)
	velocity_hbox.add_child(_sample_velocity_slider)

	_sample_velocity_label = Label.new()
	_sample_velocity_label.text = str(SettingsManager.default_sample_velocity)
	_sample_velocity_label.add_theme_font_size_override("font_size", 16)
	_sample_velocity_label.add_theme_color_override("font_color", Palette.ASH_DIM)
	_sample_velocity_label.custom_minimum_size = Vector2(40, 0)
	velocity_hbox.add_child(_sample_velocity_label)
	parent.add_child(velocity_hbox)

	var velocity_desc := Label.new()
	velocity_desc.text = "Velocity (0-127) for pads without a real one. Kick layers: 0-20 softest, 105-127 hardest. Clone Hero uses 100 by default."
	velocity_desc.add_theme_font_size_override("font_size", 14)
	velocity_desc.add_theme_color_override("font_color", Palette.ASH_DIM)
	velocity_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	velocity_desc.custom_minimum_size = Vector2(280, 0)
	parent.add_child(velocity_desc)

	parent.add_child(_spacer(20))
	_add_section_title(parent, "CHART FALLBACK")
	parent.add_child(_spacer(10))

	_fallback_check = CheckBox.new()
	_fallback_check.text = "Use PART GUITAR as fallback"
	_fallback_check.add_theme_font_size_override("font_size", 22)
	_fallback_check.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_fallback_check.set_pressed_no_signal(SettingsManager.use_guitar_fallback)
	_fallback_check.toggled.connect(_on_fallback_toggled)
	parent.add_child(_fallback_check)

	var fallback_desc := Label.new()
	fallback_desc.text = "For songs without PART DRUMS, use PART GUITAR notes as a drum chart"
	fallback_desc.add_theme_font_size_override("font_size", 14)
	fallback_desc.add_theme_color_override("font_color", Palette.ASH_DIM)
	parent.add_child(fallback_desc)

	parent.add_child(_spacer(20))
	_add_section_title(parent, "DEBUG")
	parent.add_child(_spacer(10))

	_judgment_areas_check = CheckBox.new()
	_judgment_areas_check.text = "Show Judgment Areas"
	_judgment_areas_check.add_theme_font_size_override("font_size", 22)
	_judgment_areas_check.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_judgment_areas_check.set_pressed_no_signal(SettingsManager.show_judgment_areas)
	_judgment_areas_check.toggled.connect(_on_judgment_areas_toggled)
	parent.add_child(_judgment_areas_check)

	var areas_desc := Label.new()
	areas_desc.text = "Draw colored zones at the hit line showing each judgment timing window"
	areas_desc.add_theme_font_size_override("font_size", 14)
	areas_desc.add_theme_color_override("font_color", Palette.ASH_DIM)
	parent.add_child(areas_desc)

	parent.add_child(_spacer(10))
	var haptic_debug_check := CheckBox.new()
	haptic_debug_check.text = "Show Haptic Debug"
	haptic_debug_check.add_theme_font_size_override("font_size", 22)
	haptic_debug_check.add_theme_color_override("font_color", Palette.TEXT_DIM)
	haptic_debug_check.set_pressed_no_signal(SettingsManager.haptic_show_debug)
	haptic_debug_check.toggled.connect(_on_haptic_debug_toggled)
	parent.add_child(haptic_debug_check)

	var haptic_debug_desc := Label.new()
	haptic_debug_desc.text = "Visualize accelerometer data and haptic kick detection state"
	haptic_debug_desc.add_theme_font_size_override("font_size", 14)
	haptic_debug_desc.add_theme_color_override("font_color", Palette.ASH_DIM)
	parent.add_child(haptic_debug_desc)

	parent.add_child(_spacer(20))
	_add_section_title(parent, "MENU")
	parent.add_child(_spacer(10))

	_menu_status_check = CheckBox.new()
	_menu_status_check.text = "Show Menu Status"
	_menu_status_check.add_theme_font_size_override("font_size", 22)
	_menu_status_check.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_menu_status_check.set_pressed_no_signal(SettingsManager.show_menu_status)
	_menu_status_check.toggled.connect(_on_menu_status_toggled)
	parent.add_child(_menu_status_check)

	var menu_status_desc := Label.new()
	menu_status_desc.text = "Show the song/chart status line on the main menu"
	menu_status_desc.add_theme_font_size_override("font_size", 14)
	menu_status_desc.add_theme_color_override("font_color", Palette.ASH_DIM)
	parent.add_child(menu_status_desc)

	parent.add_child(_spacer(20))
	_add_section_title(parent, "GAMEPLAY PADDING")
	parent.add_child(_spacer(10))

	_padding_check = CheckBox.new()
	_padding_check.text = "Enable Gameplay Padding"
	_padding_check.add_theme_font_size_override("font_size", 22)
	_padding_check.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_padding_check.set_pressed_no_signal(SettingsManager.gameplay_padding_enabled)
	_padding_check.toggled.connect(_on_padding_enabled_toggled)
	parent.add_child(_padding_check)

	var padding_desc := Label.new()
	padding_desc.text = "Condense gameplay and HUD to avoid edge touch issues on some devices (gesture navigation)"
	padding_desc.add_theme_font_size_override("font_size", 14)
	padding_desc.add_theme_color_override("font_color", Palette.ASH_DIM)
	parent.add_child(padding_desc)

	parent.add_child(_spacer(10))

	_padding_left_slider = _make_padding_slider(parent, "Left", SettingsManager.gameplay_padding_left, _on_padding_left_changed)
	_padding_right_slider = _make_padding_slider(parent, "Right", SettingsManager.gameplay_padding_right, _on_padding_right_changed)
	_padding_top_slider = _make_padding_slider(parent, "Top", SettingsManager.gameplay_padding_top, _on_padding_top_changed)
	_padding_bottom_slider = _make_padding_slider(parent, "Bottom", SettingsManager.gameplay_padding_bottom, _on_padding_bottom_changed)

	_apply_padding_sliders_editable(SettingsManager.gameplay_padding_enabled)

	if OS.get_name() != "Android":
		_padding_check.disabled = true
		for s in [_padding_left_slider, _padding_right_slider, _padding_top_slider, _padding_bottom_slider]:
			if is_instance_valid(s):
				s.editable = false

	parent.add_child(_spacer(30))
	_add_reset_section_button(parent, "EXPERIMENTAL", _on_reset_experimental)


func _build_songs_content(parent: VBoxContainer) -> void:
	_add_section_title(parent, "NEED SONGS?")
	parent.add_child(_spacer(10))

	var songs_hint := Label.new()
	songs_hint.text = "Don't know where to get songs? Browse community song folders and packs from the Drum Hero link tree."
	songs_hint.add_theme_font_size_override("font_size", 14)
	songs_hint.add_theme_color_override("font_color", Palette.ASH_DIM)
	songs_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(songs_hint)

	parent.add_child(_spacer(10))
	var get_songs_button := Button.new()
	get_songs_button.name = "GetSongsButton"
	get_songs_button.text = "Get songs"
	get_songs_button.custom_minimum_size = Vector2(280, 40)
	get_songs_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	get_songs_button.pressed.connect(_on_get_songs_pressed)
	parent.add_child(get_songs_button)

	_songs_link_status = Label.new()
	_songs_link_status.add_theme_font_size_override("font_size", 14)
	_songs_link_status.add_theme_color_override("font_color", Palette.BLOOD_BRIGHT)
	_songs_link_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_songs_link_status.visible = false
	parent.add_child(_songs_link_status)

	parent.add_child(_spacer(20))
	_add_section_title(parent, "STORAGE ACCESS")
	parent.add_child(_spacer(10))
	_build_permission_section(parent)

	parent.add_child(_spacer(20))
	_add_section_title(parent, "LIBRARY LOCATIONS")
	parent.add_child(_spacer(5))
	var intro := Label.new()
	intro.text = "Songs are read in place from these folders. Nothing is copied or imported."
	intro.add_theme_font_size_override("font_size", 14)
	intro.add_theme_color_override("font_color", Palette.ASH_DIM)
	parent.add_child(intro)
	parent.add_child(_spacer(10))

	_preset_downloads_check = _make_library_check(parent, "Scan Download", SettingsManager.library_preset_downloads, _on_preset_downloads_toggled)
	parent.add_child(_spacer(5))
	_preset_documents_check = _make_library_check(parent, "Scan Documents", SettingsManager.library_preset_documents, _on_preset_documents_toggled)

	parent.add_child(_spacer(15))
	var depth_hbox := HBoxContainer.new()
	depth_hbox.add_theme_constant_override("separation", 10)
	var depth_label := Label.new()
	depth_label.text = "Max subfolder depth"
	depth_label.add_theme_font_size_override("font_size", 18)
	depth_label.add_theme_color_override("font_color", Palette.TEXT_DIM)
	depth_label.custom_minimum_size = Vector2(280, 0)
	depth_hbox.add_child(depth_label)

	_depth_option = OptionButton.new()
	_depth_option.add_theme_font_size_override("font_size", 18)
	for i in 6:
		_depth_option.add_item(("Only this folder" if i == 0 else "Up to " + str(i) + " levels"), i)
	_depth_option.select(clampi(SettingsManager.library_max_depth, 0, 5))
	_depth_option.item_selected.connect(_on_depth_selected)
	depth_hbox.add_child(_depth_option)
	parent.add_child(depth_hbox)

	parent.add_child(_spacer(5))
	_recursive_check = _make_library_check(parent, "Search subfolders", SettingsManager.library_recursive, _on_recursive_toggled)

	parent.add_child(_spacer(20))
	_add_section_title(parent, "EXTRA FOLDERS")
	parent.add_child(_spacer(10))
	_roots_container = VBoxContainer.new()
	_roots_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(_roots_container)
	_rebuild_roots_list()
	parent.add_child(_spacer(15))

	var add_hbox := HBoxContainer.new()
	add_hbox.add_theme_constant_override("separation", 10)
	var path_edit := LineEdit.new()
	path_edit.placeholder_text = "/storage/emulated/0/Download/RockBand"
	path_edit.add_theme_font_size_override("font_size", 18)
	path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_edit.text_submitted.connect(_on_root_path_submitted)
	add_hbox.add_child(path_edit)
	var add_btn := Button.new()
	add_btn.text = "Add"
	add_btn.custom_minimum_size = Vector2(110, 40)
	add_btn.pressed.connect(func() -> void: _on_add_root(path_edit.text))
	add_hbox.add_child(add_btn)
	parent.add_child(add_hbox)

	var add_hint := Label.new()
	add_hint.text = "Type the absolute path, or paste a folder path copied from a file manager."
	add_hint.add_theme_font_size_override("font_size", 14)
	add_hint.add_theme_color_override("font_color", Palette.ASH_DIM)
	parent.add_child(add_hint)

	parent.add_child(_spacer(20))
	var scan_buttons := HBoxContainer.new()
	scan_buttons.add_theme_constant_override("separation", 10)

	_rescan_button = Button.new()
	_rescan_button.name = "RescanButton"
	_rescan_button.text = "Rescan now"
	_rescan_button.custom_minimum_size = Vector2(280, 40)
	_rescan_button.pressed.connect(_on_rescan_pressed)
	scan_buttons.add_child(_rescan_button)

	_cancel_scan_button = Button.new()
	_cancel_scan_button.name = "CancelScanButton"
	_cancel_scan_button.text = "Cancel"
	_cancel_scan_button.custom_minimum_size = Vector2(140, 40)
	_cancel_scan_button.pressed.connect(_on_cancel_scan_pressed)
	scan_buttons.add_child(_cancel_scan_button)
	parent.add_child(scan_buttons)

	# Indicador de escaneo. El resumen de abajo solo se actualiza cuando el
	# recorrido acaba, asi que sin esto el panel se queda mudo durante todo el
	# walk, que en una biblioteca grande son varios segundos sin pistas.
	_scan_bar = ScanFeedback.make_progress_bar()
	_scan_bar.name = "ScanBar"
	parent.add_child(_scan_bar)

	_scan_status = ScanFeedback.make_status_label()
	_scan_status.name = "ScanStatus"
	_scan_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(_scan_status)

	_scan_folder = ScanFeedback.make_folder_label()
	_scan_folder.name = "ScanFolder"
	_scan_folder.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(_scan_folder)

	_scan_summary = Label.new()
	_scan_summary.add_theme_font_size_override("font_size", 15)
	_scan_summary.add_theme_color_override("font_color", Palette.ASH_DIM)
	_scan_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_scan_summary)
	_refresh_scan_widgets()
	_update_scan_summary()

	parent.add_child(_spacer(30))
	_add_reset_section_button(parent, "SONGS", _on_reset_songs)


func _build_permission_section(parent: VBoxContainer) -> void:
	if OS.get_name() != "Android":
		var desktop_note := Label.new()
		desktop_note.text = "External storage access is automatic on this platform."
		desktop_note.add_theme_font_size_override("font_size", 15)
		desktop_note.add_theme_color_override("font_color", Palette.CHROME)
		desktop_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(desktop_note)
		return

	_permission_status = Label.new()
	_permission_status.add_theme_font_size_override("font_size", 18)
	_permission_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_permission_status.custom_minimum_size.y = 52
	parent.add_child(_permission_status)

	_permission_button = Button.new()
	_permission_button.custom_minimum_size = Vector2(280, 40)
	_permission_button.pressed.connect(_on_permission_pressed)
	parent.add_child(_permission_button)
	_permission_was_granted = AndroidBridge.has_all_files_access()
	_update_permission_section()


func _update_permission_section() -> void:
	if not is_instance_valid(_permission_status):
		return
	if not AndroidBridge.is_storage_plugin_available():
		_permission_status.text = "Storage plugin missing from this build. The Android export did not include the AllFilesAccess plugin, so external folders cannot be read."
		_permission_status.add_theme_color_override("font_color", Palette.BLOOD_BRIGHT)
		_permission_button.text = "Unavailable"
		_permission_button.disabled = true
		return
	_permission_button.disabled = false
	if AndroidBridge.has_all_files_access():
		_permission_status.text = "Granted. Folders outside the app sandbox can be scanned."
		_permission_status.add_theme_color_override("font_color", Palette.CHROME)
		_permission_button.text = "Open Android settings"
		return
	_permission_status.text = "Not granted. Without it, only folders inside the app sandbox are visible."
	_permission_status.add_theme_color_override("font_color", Palette.BLOOD)
	_permission_button.text = "Grant access"


func _on_permission_pressed() -> void:
	var ok: bool = false
	if AndroidBridge.has_all_files_access():
		ok = AndroidBridge.open_all_files_settings()
	else:
		ok = AndroidBridge.request_all_files_access()
	if not ok:
		_permission_status.text = "Could not open Android settings (" + AndroidBridge.get_storage_last_error() + "). Grant \"All files access\" manually for Drum Hero in Android Settings > Apps."
		_permission_status.add_theme_color_override("font_color", Palette.BLOOD_BRIGHT)
		return
	_update_permission_section()


func _make_library_check(parent: VBoxContainer, text: String, pressed: bool, callback: Callable) -> CheckBox:
	var check := CheckBox.new()
	check.text = text
	check.add_theme_font_size_override("font_size", 22)
	check.add_theme_color_override("font_color", Palette.TEXT_DIM)
	check.set_pressed_no_signal(pressed)
	check.toggled.connect(callback)
	parent.add_child(check)
	return check


func _rebuild_roots_list() -> void:
	if not is_instance_valid(_roots_container):
		return
	for child in _roots_container.get_children():
		child.queue_free()

	if SettingsManager.library_roots.is_empty():
		var empty := Label.new()
		empty.text = "(no extra folders)"
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", Palette.MUTED_DIM)
		_roots_container.add_child(empty)
		return

	for i in SettingsManager.library_roots.size():
		var path: String = SettingsManager.library_roots[i]
		var hbox := HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_theme_constant_override("separation", 10)

		var path_label := Label.new()
		path_label.text = path
		path_label.add_theme_font_size_override("font_size", 16)
		path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if not DirAccess.dir_exists_absolute(path):
			path_label.add_theme_color_override("font_color", Palette.BLOOD)
		hbox.add_child(path_label)

		var remove_btn := Button.new()
		remove_btn.text = "Remove"
		remove_btn.custom_minimum_size = Vector2(130, 40)
		remove_btn.pressed.connect(_on_remove_root.bind(i))
		hbox.add_child(remove_btn)

		_roots_container.add_child(hbox)


func _update_scan_summary() -> void:
	if not is_instance_valid(_scan_summary):
		return
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Last scan: " + str(SongLoader.song_list.size()) + " songs from " + str(SongLoader.get_scan_roots().size()) + " location(s).")
	var blocked: int = 0
	for song in SongLoader.song_list:
		if song.get("audio_blocked", false):
			blocked += 1
	if blocked > 0:
		lines.append("Audio: " + str(blocked) + " song(s) have song.opus with no song.ogg. Android cannot decode .opus, so these play silent. Convert them with tools/convert_opus_to_ogg.sh.")
	for path in SongLoader.unreadable_roots:
		lines.append("Unreadable: " + path)
	for path in SongLoader.truncated_roots:
		lines.append("Too deep (raise max subfolder depth): " + path)
	for path in SongLoader.cancelled_roots:
		lines.append("Scan cancelled before finishing here, this location may have more songs: " + path)
	_scan_summary.text = "\n".join(lines)


func _on_add_root(raw_path: String) -> void:
	var path: String = raw_path.strip_edges()
	if path.is_empty():
		return
	if not path.begins_with("/"):
		path = "/" + path
	path = path.simplify_path()
	if SettingsManager.library_roots.has(path):
		return
	SettingsManager.library_roots.append(path)
	SettingsManager.save_settings()
	_rebuild_roots_list()


func _on_root_path_submitted(text: String) -> void:
	_on_add_root(text)


func _on_remove_root(index: int) -> void:
	if index < 0 or index >= SettingsManager.library_roots.size():
		return
	SettingsManager.library_roots.remove_at(index)
	SettingsManager.save_settings()
	_rebuild_roots_list()


func _on_preset_downloads_toggled(toggled: bool) -> void:
	SettingsManager.library_preset_downloads = toggled
	SettingsManager.save_settings()


func _on_preset_documents_toggled(toggled: bool) -> void:
	SettingsManager.library_preset_documents = toggled
	SettingsManager.save_settings()


func _on_recursive_toggled(toggled: bool) -> void:
	SettingsManager.library_recursive = toggled
	SettingsManager.save_settings()


func _on_depth_selected(index: int) -> void:
	SettingsManager.library_max_depth = index
	SettingsManager.save_settings()


func _on_rescan_pressed() -> void:
	_scan_summary_and_rescan()


func _on_cancel_scan_pressed() -> void:
	if not SongLoader.is_scanning:
		return
	SongLoader.cancel_scan()
	if is_instance_valid(_scan_status):
		_scan_status.text = "Cancelling..."


func _scan_summary_and_rescan() -> void:
	# El permiso puede concederse con el panel en cualquier pestana, y ahi no
	# hay indicador que mostrar: el escaneo sigue, y al acabar actualiza el
	# resumen, que es lo unico que se lee de esta pestana.
	if _scan_pump_active:
		return
	_scan_pump_active = true
	_set_scan_widgets_visible(true)
	if is_instance_valid(_scan_status):
		_scan_status.text = "Scanning..."
	SongLoader.request_scan()
	if SongLoader.pump_scan(SongLoader.frame_deadline_usec()):
		_finish_scan()


func _on_scan_progress(root_index: int, root_total: int, current_dir: String, _dirs_visited: int, songs_found: int) -> void:
	if not _scan_pump_active or not is_instance_valid(_scan_status):
		return
	if is_instance_valid(_scan_bar):
		_scan_bar.value = ScanFeedback.progress_value(root_index, root_total) * 100.0
	_scan_status.text = ScanFeedback.status_text(root_index, root_total, songs_found)
	if is_instance_valid(_scan_folder):
		_scan_folder.text = ScanFeedback.folder_text(current_dir)


func _finish_scan() -> void:
	_scan_pump_active = false
	_set_scan_widgets_visible(false)
	_update_scan_summary()


func _abort_scan() -> void:
	if not (_scan_pump_active or SongLoader.is_scanning):
		return
	_scan_pump_active = false
	SongLoader.abort_scan()
	_set_scan_widgets_visible(false)


func _set_scan_widgets_visible(visible_state: bool) -> void:
	if is_instance_valid(_rescan_button):
		_rescan_button.disabled = visible_state
	if is_instance_valid(_cancel_scan_button):
		_cancel_scan_button.disabled = not visible_state
	for widget in [_scan_bar, _scan_status, _scan_folder]:
		if is_instance_valid(widget):
			widget.visible = visible_state
	if not visible_state:
		if is_instance_valid(_scan_status):
			_scan_status.text = ""
		if is_instance_valid(_scan_folder):
			_scan_folder.text = ""
		if is_instance_valid(_scan_bar):
			_scan_bar.value = 0.0


func _refresh_scan_widgets() -> void:
	# Al reconstruir la pestana a mitad de escaneo los widgets son nuevos: se
	# reapuntan al estado real en vez de quedarse a la espera del primer evento.
	_set_scan_widgets_visible(SongLoader.is_scanning)
	if SongLoader.is_scanning and is_instance_valid(_scan_status) and _scan_status.text.is_empty():
		_scan_status.text = "Scanning..."


func _on_get_songs_pressed() -> void:
	var err: Error = OS.shell_open(SONGS_LINKTREE_URL)
	if not is_instance_valid(_songs_link_status):
		return
	if err == OK:
		_songs_link_status.visible = false
		return
	_songs_link_status.text = "Could not open the browser. Visit " + SONGS_LINKTREE_URL
	_songs_link_status.visible = true


func _on_reset_songs() -> void:
	_abort_scan()
	SettingsManager.reset_library_to_defaults()
	SettingsManager.save_settings()
	_build_tab_content()


func _build_credits_content(parent: VBoxContainer) -> void:
	_add_section_title(parent, "CREDITS")
	parent.add_child(_spacer(10))

	var version_label := Label.new()
	var app_version: String = ProjectSettings.get_setting("application/config/version", "1.0.0")
	version_label.text = "Drum Hero v" + app_version
	version_label.add_theme_font_size_override("font_size", 28)
	version_label.add_theme_color_override("font_color", Palette.BLOOD_BRIGHT)
	parent.add_child(version_label)

	parent.add_child(_spacer(5))

	var dev_label := Label.new()
	dev_label.text = "Developed by jdpc.dev"
	dev_label.add_theme_font_size_override("font_size", 22)
	dev_label.add_theme_color_override("font_color", Palette.TEXT_DIM)
	parent.add_child(dev_label)

	parent.add_child(_spacer(25))
	_add_section_title(parent, "MADE POSSIBLE BY")
	parent.add_child(_spacer(10))

	var credits: Array[Dictionary] = [
		{"name": "Godot Engine", "desc": "The game engine that powers this project"},
		{"name": "Freesound.org", "desc": "Drum sound effects and audio samples"},
		{"name": "Google Fonts", "desc": "Typography and font assets"},
	]
	for entry in credits:
		var hbox := HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_theme_constant_override("separation", 10)

		var name_lbl := Label.new()
		name_lbl.text = entry.name
		name_lbl.add_theme_font_size_override("font_size", 20)
		name_lbl.add_theme_color_override("font_color", Palette.TEXT_DIM)
		name_lbl.custom_minimum_size = Vector2(180, 0)
		hbox.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = entry.desc
		desc_lbl.add_theme_font_size_override("font_size", 16)
		desc_lbl.add_theme_color_override("font_color", Palette.ASH_DIM)
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(desc_lbl)

		parent.add_child(hbox)

	parent.add_child(_spacer(30))


func _make_padding_slider(parent: VBoxContainer, label_text: String, initial_value: float, callback: Callable) -> HSlider:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 10)

	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Palette.TEXT_DIM)
	label.custom_minimum_size = Vector2(120, 0)
	hbox.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = initial_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(callback)
	slider.drag_ended.connect(_on_padding_any_drag_ended)
	hbox.add_child(slider)

	var value_label := Label.new()
	value_label.text = str(int(initial_value)) + "dp"
	value_label.add_theme_font_size_override("font_size", 16)
	value_label.add_theme_color_override("font_color", Palette.ASH_DIM)
	value_label.custom_minimum_size = Vector2(40, 0)
	hbox.add_child(value_label)

	# Store label ref in slider metadata for callback to update
	slider.set_meta("value_label", value_label)

	parent.add_child(hbox)
	return slider


func _apply_padding_sliders_editable(enabled: bool) -> void:
	for s in [_padding_left_slider, _padding_right_slider, _padding_top_slider, _padding_bottom_slider]:
		if is_instance_valid(s):
			s.editable = enabled


func _add_section_title(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.label_settings = _label_settings
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Palette.BLOOD_BRIGHT)
	parent.add_child(label)


static func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _add_reset_section_button(parent: VBoxContainer, section_name: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = "Reset " + section_name + " to Defaults"
	btn.custom_minimum_size = Vector2(280, 40)
	btn.pressed.connect(callback)
	parent.add_child(btn)


func _load_current_settings() -> void:
	var current_mode: int = SettingsManager.game_mode
	for i in _mode_buttons.size():
		_mode_buttons[i].set_pressed_no_signal(i == current_mode)
	if is_instance_valid(_custom_lane_container):
		_custom_lane_container.visible = (current_mode == 2)


func _on_mode_toggled(toggled: bool, mode: int) -> void:
	if not toggled:
		return
	for i in _mode_buttons.size():
		_mode_buttons[i].set_pressed_no_signal(i == mode)
	SettingsManager.game_mode = mode
	GameManager.mode = mode as GameManager.GameMode
	SettingsManager.save_settings()
	if is_instance_valid(_custom_lane_container):
		_custom_lane_container.visible = (mode == 2)
	if is_instance_valid(_haptic_enabled_check):
		if mode == 1:
			_haptic_enabled_check.set_pressed_no_signal(true)
			_haptic_enabled_check.disabled = true
		else:
			_haptic_enabled_check.set_pressed_no_signal(SettingsManager.haptic_enabled)
			_haptic_enabled_check.disabled = false


func _rebuild_custom_lane_ui(lanes: Array) -> void:
	for child in _custom_lane_container.get_children():
		child.queue_free()

	var count: int = lanes.size()
	if count == 0:
		var empty := Label.new()
		empty.text = "(no custom order set — using default)"
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", Palette.MUTED_DIM)
		_custom_lane_container.add_child(empty)
		return

	for i in count:
		var lane_idx: int = lanes[i]
		var hbox := HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var move_up := Button.new()
		move_up.text = "▲"
		move_up.custom_minimum_size = Vector2(40, 40)
		move_up.disabled = (i == 0)
		move_up.pressed.connect(_on_move_lane.bind(i, -1))
		hbox.add_child(move_up)

		var move_down := Button.new()
		move_down.text = "▼"
		move_down.custom_minimum_size = Vector2(40, 40)
		move_down.disabled = (i == count - 1)
		move_down.pressed.connect(_on_move_lane.bind(i, 1))
		hbox.add_child(move_down)

		var color_rect := ColorRect.new()
		color_rect.custom_minimum_size = Vector2(20, 40)
		color_rect.color = LANE_COLORS[lane_idx] if lane_idx < LANE_COLORS.size() else Color.WHITE
		hbox.add_child(color_rect)

		var lbl := Label.new()
		lbl.text = LANE_LABELS[lane_idx] if lane_idx < LANE_LABELS.size() else "Lane " + str(lane_idx)
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", Palette.TEXT_DIM)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl)

		_custom_lane_container.add_child(hbox)

	var reset_btn := Button.new()
	reset_btn.text = "Reset to Default"
	reset_btn.custom_minimum_size = Vector2(200, 40)
	reset_btn.pressed.connect(_on_reset_lanes)
	_custom_lane_container.add_child(reset_btn)


func _on_move_lane(index: int, direction: int) -> void:
	var lanes: Array = SettingsManager.custom_lanes.duplicate()
	if lanes.is_empty():
		return
	var target: int = index + direction
	if target < 0 or target >= lanes.size():
		return
	var tmp = lanes[index]
	lanes[index] = lanes[target]
	lanes[target] = tmp
	SettingsManager.custom_lanes = lanes
	SettingsManager.save_settings()
	_rebuild_custom_lane_ui(lanes)


func _on_reset_lanes() -> void:
	SettingsManager.custom_lanes = [0, 1, 2, 3, 4, 5, 6, 7]
	SettingsManager.save_settings()
	_rebuild_custom_lane_ui(SettingsManager.custom_lanes)


func _on_reset_controls() -> void:
	SettingsManager.reset_controls_to_defaults()
	_build_tab_content()


func _on_reset_hud() -> void:
	SettingsManager.reset_hud_to_defaults()
	_build_tab_content()


func _on_reset_experimental() -> void:
	SettingsManager.reset_experimental_to_defaults()
	_build_tab_content()


func _on_free_mode_pressed() -> void:
	free_mode_requested.emit()


func _on_sample_velocity_changed(value: float) -> void:
	SettingsManager.default_sample_velocity = int(value)
	if _sample_velocity_label:
		_sample_velocity_label.text = str(int(value))
	SettingsManager.save_settings()


func _on_fps_toggled(toggled: bool) -> void:
	SettingsManager.show_fps = toggled
	SettingsManager.save_settings()


func _fps_cap_text(val: float) -> String:
	return "Unlimited" if val <= 0.0 else str(int(val)) + " FPS"


func _on_fps_cap_changed(value: float) -> void:
	_fps_cap_label.text = _fps_cap_text(value)


func _on_fps_cap_drag_ended(value_changed: bool) -> void:
	if value_changed:
		SettingsManager.max_fps = int(_fps_cap_slider.value)
		Engine.max_fps = SettingsManager.max_fps
		SettingsManager.save_settings()


func _on_screen_shake_toggled(toggled: bool) -> void:
	SettingsManager.screen_shake = toggled
	SettingsManager.save_settings()


func _on_hit_feedback_toggled(toggled: bool) -> void:
	SettingsManager.show_hit_feedback = toggled
	SettingsManager.save_settings()


func _on_fallback_toggled(toggled: bool) -> void:
	SettingsManager.use_guitar_fallback = toggled
	SettingsManager.save_settings()


func _on_judgment_areas_toggled(toggled: bool) -> void:
	SettingsManager.show_judgment_areas = toggled
	SettingsManager.save_settings()


func _on_menu_status_toggled(toggled: bool) -> void:
	SettingsManager.show_menu_status = toggled
	SettingsManager.save_settings()


func _on_haptic_enabled_toggled(toggled: bool) -> void:
	SettingsManager.haptic_enabled = toggled
	SettingsManager.save_settings()


func _on_haptic_sensitivity_changed(value: float) -> void:
	SettingsManager.haptic_sensitivity = value
	_haptic_sensitivity_label.text = str(value)


func _on_haptic_sensitivity_drag_ended(value_changed: bool) -> void:
	if value_changed:
		SettingsManager.save_settings()


func _haptic_add_threshold_slider(parent: VBoxContainer, label_text: String, initial_value: float, min_val: float, max_val: float, step_val: float, change_callback: Callable, drag_callback: Callable) -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Palette.TEXT)
	label.custom_minimum_size = Vector2(140, 0)
	hbox.add_child(label)

	var value_label := Label.new()
	value_label.text = str(initial_value)
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.add_theme_color_override("font_color", Palette.ASH_DIM)
	hbox.add_child(value_label)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step_val
	slider.value = initial_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(change_callback.bind(value_label))
	slider.drag_ended.connect(drag_callback)
	hbox.add_child(slider)

	parent.add_child(hbox)


func _on_haptic_activation_changed(value: float, label: Label) -> void:
	SettingsManager.haptic_activation_threshold = value
	label.text = str(value)


func _on_haptic_release_changed(value: float, label: Label) -> void:
	SettingsManager.haptic_release_threshold = value
	label.text = str(value)


func _on_haptic_cooldown_changed(value: float, label: Label) -> void:
	SettingsManager.haptic_cooldown_duration = value
	label.text = str(value)


func _on_haptic_min_interval_changed(value: float, label: Label) -> void:
	SettingsManager.haptic_min_interval = value
	label.text = str(value)


func _on_haptic_smoothing_changed(value: float, label: Label) -> void:
	SettingsManager.haptic_smoothing_strength = value
	label.text = str(value)


func _on_haptic_any_drag_ended(value_changed: bool) -> void:
	if value_changed:
		SettingsManager.save_settings()


func _on_haptic_debug_toggled(toggled: bool) -> void:
	SettingsManager.haptic_show_debug = toggled
	SettingsManager.save_settings()


func _on_note_speed_changed(value: float) -> void:
	SettingsManager.note_speed = value
	_note_speed_label.text = "x" + str(value)


func _on_note_speed_drag_ended(value_changed: bool) -> void:
	if value_changed:
		SettingsManager.save_settings()


func _on_countdown_changed(value: float) -> void:
	SettingsManager.countdown_threshold = value
	_countdown_label.text = str(value) + "s"


func _on_countdown_drag_ended(value_changed: bool) -> void:
	if value_changed:
		SettingsManager.save_settings()


func _on_mirrored_toggled(toggled: bool) -> void:
	SettingsManager.mirrored = toggled
	SettingsManager.save_settings()


func _on_left_handed_toggled(toggled: bool) -> void:
	SettingsManager.left_handed = toggled
	SettingsManager.save_settings()


func _on_padding_enabled_toggled(toggled: bool) -> void:
	SettingsManager.gameplay_padding_enabled = toggled
	SettingsManager.save_settings()
	_apply_padding_sliders_editable(toggled)


func _on_padding_left_changed(value: float) -> void:
	SettingsManager.gameplay_padding_left = value
	if is_instance_valid(_padding_left_slider):
		_padding_left_slider.get_meta("value_label").text = str(int(value)) + "dp"


func _on_padding_right_changed(value: float) -> void:
	SettingsManager.gameplay_padding_right = value
	if is_instance_valid(_padding_right_slider):
		_padding_right_slider.get_meta("value_label").text = str(int(value)) + "dp"


func _on_padding_top_changed(value: float) -> void:
	SettingsManager.gameplay_padding_top = value
	if is_instance_valid(_padding_top_slider):
		_padding_top_slider.get_meta("value_label").text = str(int(value)) + "dp"


func _on_padding_bottom_changed(value: float) -> void:
	SettingsManager.gameplay_padding_bottom = value
	if is_instance_valid(_padding_bottom_slider):
		_padding_bottom_slider.get_meta("value_label").text = str(int(value)) + "dp"


func _on_padding_any_drag_ended(value_changed: bool) -> void:
	if value_changed:
		SettingsManager.save_settings()


func _on_back() -> void:
	queue_free()
