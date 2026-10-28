class_name SettingsRoot
extends CanvasLayer

var _label_settings: LabelSettings = preload("res://asset/fonts/label_settings.tres")

var _mode_buttons: Array[CheckBox] = []
var _custom_lane_container: VBoxContainer

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
	# Render above the menu layer so song list doesn't overlap
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
		margin.add_theme_constant_override("margin_" + side, 60)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	scroll.add_child(vbox)

	var title := Label.new()
	title.text = "SETTINGS"
	title.label_settings = _label_settings
	title.add_theme_font_size_override("font_size", 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(_spacer(20))
	_add_section_title(vbox, "CONTROL MODE")
	vbox.add_child(_spacer(10))

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

		vbox.add_child(hbox)

	vbox.add_child(_spacer(20))
	_add_section_title(vbox, "LANE ORDER (CUSTOM MODE)")
	vbox.add_child(_spacer(10))

	_custom_lane_container = VBoxContainer.new()
	_custom_lane_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_custom_lane_container)

	_rebuild_custom_lane_ui(SettingsManager.custom_lanes)

	vbox.add_child(_spacer(20))
	_add_section_title(vbox, "VISUAL")
	vbox.add_child(_spacer(10))

	var fps_hbox := HBoxContainer.new()
	fps_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fps_check := CheckBox.new()
	fps_check.text = "Show FPS"
	fps_check.add_theme_font_size_override("font_size", 22)
	fps_check.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	fps_check.set_pressed_no_signal(SettingsManager.show_fps)
	fps_check.toggled.connect(_on_fps_toggled)
	fps_hbox.add_child(fps_check)
	vbox.add_child(fps_hbox)

	vbox.add_child(_spacer(30))

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.custom_minimum_size = Vector2(200, 60)
	back_btn.pressed.connect(_on_back)
	btn_row.add_child(back_btn)

	vbox.add_child(btn_row)


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
	for i in 3:
		_mode_buttons[i].set_pressed_no_signal(i == current_mode)
	_custom_lane_container.visible = (current_mode == 2)


func _on_mode_toggled(toggled: bool, mode: int) -> void:
	if not toggled:
		return
	for i in 3:
		_mode_buttons[i].set_pressed_no_signal(i == mode)
	SettingsManager.game_mode = mode
	GameManager.mode = mode as GameManager.GameMode
	SettingsManager.save_settings()
	_custom_lane_container.visible = (mode == 2)


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


func _on_back() -> void:
	queue_free()
