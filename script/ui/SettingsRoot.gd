class_name SettingsRoot
extends CanvasLayer

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
var _hud_shake_check: CheckBox
var _hud_feedback_check: CheckBox
var _note_speed_slider: HSlider
var _note_speed_label: Label
var _countdown_slider: HSlider
var _countdown_label: Label

# Experimental tab elements
var _fallback_check: CheckBox
var _judgment_areas_check: CheckBox
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
	_build_ui()
	_load_current_settings()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12, 1.0)
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
	sb.bg_color = Color(0.05, 0.05, 0.08)
	tab_bg.add_theme_stylebox_override("panel", sb)
	parent.add_child(tab_bg)

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_bg.add_child(hbox)

	var tab_names := ["CONTROLS", "HUD", "Experimental", "CREDITS"]
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
	_build_tab_content()


func _build_tab_content() -> void:
	for child in _content_container.get_children():
		child.queue_free()

	match _current_tab:
		0:
			_build_controls_content(_content_container)
		1:
			_build_hud_content(_content_container)
		2:
			_build_experimental_content(_content_container)
		3:
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
		btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		btn.set_pressed_no_signal(m_data.mode == SettingsManager.game_mode)
		btn.toggled.connect(_on_mode_toggled.bind(m_data.mode))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(btn)
		_mode_buttons.append(btn)

		var desc := Label.new()
		desc.text = m_data.desc
		desc.add_theme_font_size_override("font_size", 14)
		desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
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
	_haptic_enabled_check.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
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
	haptic_sens_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
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
	_haptic_sensitivity_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
	_haptic_sensitivity_label.custom_minimum_size = Vector2(40, 0)
	haptic_sens_hbox.add_child(_haptic_sensitivity_label)
	parent.add_child(haptic_sens_hbox)

	var haptic_desc := Label.new()
	haptic_desc.text = "Adjust how hard you need to tap for kick detection"
	haptic_desc.add_theme_font_size_override("font_size", 14)
	haptic_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
	parent.add_child(haptic_desc)

	parent.add_child(_spacer(15))
	_add_section_title(parent, "ADVANCED HAPTIC TUNING")
	parent.add_child(_spacer(5))

	_haptic_add_threshold_slider(parent, "Activation", SettingsManager.haptic_activation_threshold, 0.5, 12.0, 0.5, _on_haptic_activation_changed, _on_haptic_any_drag_ended)
	_haptic_add_threshold_slider(parent, "Release", SettingsManager.haptic_release_threshold, 0.1, 8.0, 0.5, _on_haptic_release_changed, _on_haptic_any_drag_ended)
	_haptic_add_threshold_slider(parent, "Cooldown (s)", SettingsManager.haptic_cooldown_duration, 0.05, 0.5, 0.01, _on_haptic_cooldown_changed, _on_haptic_any_drag_ended)
	_haptic_add_threshold_slider(parent, "Min Interval (s)", SettingsManager.haptic_min_interval, 0.02, 0.3, 0.01, _on_haptic_min_interval_changed, _on_haptic_any_drag_ended)
	_haptic_add_threshold_slider(parent, "Smoothing", SettingsManager.haptic_smoothing_strength, 0.01, 0.5, 0.01, _on_haptic_smoothing_changed, _on_haptic_any_drag_ended)

	parent.add_child(_spacer(5))
	var haptic_debug_hbox := HBoxContainer.new()
	haptic_debug_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var haptic_debug_check := CheckBox.new()
	haptic_debug_check.text = "Show Haptic Debug"
	haptic_debug_check.add_theme_font_size_override("font_size", 18)
	haptic_debug_check.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	haptic_debug_check.set_pressed_no_signal(SettingsManager.haptic_show_debug)
	haptic_debug_check.toggled.connect(_on_haptic_debug_toggled)
	haptic_debug_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haptic_debug_hbox.add_child(haptic_debug_check)
	parent.add_child(haptic_debug_hbox)

	var advanced_desc := Label.new()
	advanced_desc.text = "Activation = lift threshold, Release = when kick resets ( ÷ by Sensitivity slider )."
	advanced_desc.add_theme_font_size_override("font_size", 14)
	advanced_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
	parent.add_child(advanced_desc)

	parent.add_child(_spacer(20))
	_add_section_title(parent, "LAYOUT")
	parent.add_child(_spacer(10))

	var mirrored_check := CheckBox.new()
	mirrored_check.text = "Mirrored Layout"
	mirrored_check.add_theme_font_size_override("font_size", 22)
	mirrored_check.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	mirrored_check.set_pressed_no_signal(SettingsManager.mirrored)
	mirrored_check.toggled.connect(_on_mirrored_toggled)
	parent.add_child(mirrored_check)

	var left_handed_check := CheckBox.new()
	left_handed_check.text = "Left Handed Mode"
	left_handed_check.add_theme_font_size_override("font_size", 22)
	left_handed_check.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	left_handed_check.set_pressed_no_signal(SettingsManager.left_handed)
	left_handed_check.toggled.connect(_on_left_handed_toggled)
	parent.add_child(left_handed_check)


func _build_hud_content(parent: VBoxContainer) -> void:
	_add_section_title(parent, "VISUAL")
	parent.add_child(_spacer(10))

	_hud_fps_check = CheckBox.new()
	_hud_fps_check.text = "Show FPS"
	_hud_fps_check.add_theme_font_size_override("font_size", 22)
	_hud_fps_check.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_hud_fps_check.set_pressed_no_signal(SettingsManager.show_fps)
	_hud_fps_check.toggled.connect(_on_fps_toggled)
	parent.add_child(_hud_fps_check)

	_hud_shake_check = CheckBox.new()
	_hud_shake_check.text = "Screen Shake"
	_hud_shake_check.add_theme_font_size_override("font_size", 22)
	_hud_shake_check.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_hud_shake_check.set_pressed_no_signal(SettingsManager.screen_shake)
	_hud_shake_check.toggled.connect(_on_screen_shake_toggled)
	parent.add_child(_hud_shake_check)

	_hud_feedback_check = CheckBox.new()
	_hud_feedback_check.text = "Show Hit Feedback"
	_hud_feedback_check.add_theme_font_size_override("font_size", 22)
	_hud_feedback_check.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_hud_feedback_check.set_pressed_no_signal(SettingsManager.show_hit_feedback)
	_hud_feedback_check.toggled.connect(_on_hit_feedback_toggled)
	parent.add_child(_hud_feedback_check)

	var feedback_desc := Label.new()
	feedback_desc.text = "Show judgement text (PERFECT, GOOD, etc.) at the hit line"
	feedback_desc.add_theme_font_size_override("font_size", 14)
	feedback_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
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
	speed_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
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
	_note_speed_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
	_note_speed_label.custom_minimum_size = Vector2(40, 0)
	speed_hbox.add_child(_note_speed_label)
	parent.add_child(speed_hbox)

	var countdown_hbox := HBoxContainer.new()
	countdown_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	countdown_hbox.add_theme_constant_override("separation", 10)
	var countdown_label := Label.new()
	countdown_label.text = "Silence Countdown"
	countdown_label.add_theme_font_size_override("font_size", 18)
	countdown_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
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
	_countdown_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
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
		name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		name_lbl.custom_minimum_size = Vector2(100, 0)
		row.add_child(name_lbl)

		var val_lbl := Label.new()
		var val: float = SettingsManager.get(jd.key)
		val_lbl.text = "±" + str(val) + " ms"
		val_lbl.add_theme_font_size_override("font_size", 16)
		val_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
		row.add_child(val_lbl)
		parent.add_child(row)


func _build_experimental_content(parent: VBoxContainer) -> void:
	_add_section_title(parent, "CHART FALLBACK")
	parent.add_child(_spacer(10))

	_fallback_check = CheckBox.new()
	_fallback_check.text = "Use PART GUITAR as fallback"
	_fallback_check.add_theme_font_size_override("font_size", 22)
	_fallback_check.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_fallback_check.set_pressed_no_signal(SettingsManager.use_guitar_fallback)
	_fallback_check.toggled.connect(_on_fallback_toggled)
	parent.add_child(_fallback_check)

	var fallback_desc := Label.new()
	fallback_desc.text = "For songs without PART DRUMS, use PART GUITAR notes as a drum chart"
	fallback_desc.add_theme_font_size_override("font_size", 14)
	fallback_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
	parent.add_child(fallback_desc)

	parent.add_child(_spacer(20))
	_add_section_title(parent, "DEBUG")
	parent.add_child(_spacer(10))

	_judgment_areas_check = CheckBox.new()
	_judgment_areas_check.text = "Show Judgment Areas"
	_judgment_areas_check.add_theme_font_size_override("font_size", 22)
	_judgment_areas_check.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_judgment_areas_check.set_pressed_no_signal(SettingsManager.show_judgment_areas)
	_judgment_areas_check.toggled.connect(_on_judgment_areas_toggled)
	parent.add_child(_judgment_areas_check)

	var areas_desc := Label.new()
	areas_desc.text = "Draw colored zones at the hit line showing each judgment timing window"
	areas_desc.add_theme_font_size_override("font_size", 14)
	areas_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
	parent.add_child(areas_desc)

	parent.add_child(_spacer(20))
	_add_section_title(parent, "GAMEPLAY PADDING")
	parent.add_child(_spacer(10))

	_padding_check = CheckBox.new()
	_padding_check.text = "Enable Gameplay Padding"
	_padding_check.add_theme_font_size_override("font_size", 22)
	_padding_check.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_padding_check.set_pressed_no_signal(SettingsManager.gameplay_padding_enabled)
	_padding_check.toggled.connect(_on_padding_enabled_toggled)
	parent.add_child(_padding_check)

	var padding_desc := Label.new()
	padding_desc.text = "Condense gameplay and HUD to avoid edge touch issues on some devices (gesture navigation)"
	padding_desc.add_theme_font_size_override("font_size", 14)
	padding_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
	parent.add_child(padding_desc)

	parent.add_child(_spacer(10))

	_padding_left_slider = _make_padding_slider(parent, "Left", SettingsManager.gameplay_padding_left, _on_padding_left_changed)
	_padding_right_slider = _make_padding_slider(parent, "Right", SettingsManager.gameplay_padding_right, _on_padding_right_changed)
	_padding_top_slider = _make_padding_slider(parent, "Top", SettingsManager.gameplay_padding_top, _on_padding_top_changed)
	_padding_bottom_slider = _make_padding_slider(parent, "Bottom", SettingsManager.gameplay_padding_bottom, _on_padding_bottom_changed)

	_apply_padding_sliders_editable(SettingsManager.gameplay_padding_enabled)


func _build_credits_content(parent: VBoxContainer) -> void:
	_add_section_title(parent, "CREDITS")
	parent.add_child(_spacer(10))

	var version_label := Label.new()
	var app_version: String = ProjectSettings.get_setting("application/config/version", "1.0.0")
	version_label.text = "Drum Hero v" + app_version
	version_label.add_theme_font_size_override("font_size", 28)
	version_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0, 1))
	parent.add_child(version_label)

	parent.add_child(_spacer(5))

	var dev_label := Label.new()
	dev_label.text = "Developed by jdpc.dev"
	dev_label.add_theme_font_size_override("font_size", 22)
	dev_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
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
		name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		name_lbl.custom_minimum_size = Vector2(180, 0)
		hbox.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = entry.desc
		desc_lbl.add_theme_font_size_override("font_size", 16)
		desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
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
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	label.custom_minimum_size = Vector2(120, 0)
	hbox.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 200.0
	slider.step = 5.0
	slider.value = initial_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(callback)
	slider.drag_ended.connect(_on_padding_any_drag_ended)
	hbox.add_child(slider)

	var value_label := Label.new()
	value_label.text = str(int(initial_value)) + "px"
	value_label.add_theme_font_size_override("font_size", 16)
	value_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
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
	label.add_theme_color_override("font_color", Color(0.5, 0.8, 1, 1))
	parent.add_child(label)


static func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


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
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 0.8))
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
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
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


func _on_fps_toggled(toggled: bool) -> void:
	SettingsManager.show_fps = toggled
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
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	label.custom_minimum_size = Vector2(140, 0)
	hbox.add_child(label)

	var value_label := Label.new()
	value_label.text = str(initial_value)
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
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
		_padding_left_slider.get_meta("value_label").text = str(int(value)) + "px"


func _on_padding_right_changed(value: float) -> void:
	SettingsManager.gameplay_padding_right = value
	if is_instance_valid(_padding_right_slider):
		_padding_right_slider.get_meta("value_label").text = str(int(value)) + "px"


func _on_padding_top_changed(value: float) -> void:
	SettingsManager.gameplay_padding_top = value
	if is_instance_valid(_padding_top_slider):
		_padding_top_slider.get_meta("value_label").text = str(int(value)) + "px"


func _on_padding_bottom_changed(value: float) -> void:
	SettingsManager.gameplay_padding_bottom = value
	if is_instance_valid(_padding_bottom_slider):
		_padding_bottom_slider.get_meta("value_label").text = str(int(value)) + "px"


func _on_padding_any_drag_ended(value_changed: bool) -> void:
	if value_changed:
		SettingsManager.save_settings()


func _on_back() -> void:
	queue_free()
