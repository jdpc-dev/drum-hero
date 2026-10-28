class_name CountdownLabel
extends CanvasLayer

var _title_label: Label
var _time_label: Label

var _screen_size: Vector2


func _ready() -> void:
	_screen_size = get_viewport().get_visible_rect().size
	layer = 5

	var pl: float = SettingsManager.gameplay_padding_left if SettingsManager.gameplay_padding_enabled else 0.0
	var pr: float = SettingsManager.gameplay_padding_right if SettingsManager.gameplay_padding_enabled else 0.0
	var pt: float = SettingsManager.gameplay_padding_top if SettingsManager.gameplay_padding_enabled else 0.0
	var content_w: float = _screen_size.x - pl - pr

	_title_label = Label.new()
	_title_label.text = "Next notes in"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	_title_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_title_label.add_theme_constant_override("shadow_offset_x", 2)
	_title_label.add_theme_constant_override("shadow_offset_y", 2)
	_title_label.position = Vector2(pl, pt + _screen_size.y * 0.35)
	_title_label.size = Vector2(content_w, 40)
	add_child(_title_label)

	_time_label = Label.new()
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_time_label.add_theme_font_size_override("font_size", 64)
	_time_label.add_theme_color_override("font_color", Color.WHITE)
	_time_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_time_label.add_theme_constant_override("shadow_offset_x", 3)
	_time_label.add_theme_constant_override("shadow_offset_y", 3)
	_time_label.position = Vector2(pl, pt + _screen_size.y * 0.42)
	_time_label.size = Vector2(content_w, 80)
	add_child(_time_label)

	hide()


func update_display(remaining: float) -> void:
	_time_label.text = "%.1f s" % remaining
	if not visible:
		show()


func clear() -> void:
	hide()
	_time_label.text = ""
	_title_label.text = ""
