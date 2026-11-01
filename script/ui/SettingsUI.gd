class_name SettingsUI
extends RefCounted

# Visual kit for the Settings panel. Everything that gives the screen its
# look lives here: surfaces, type scale, switches, sliders, nav items and the
# small composited icons. SettingsRoot only describes the content, so a style
# change does not have to be repeated in every builder.
#
# Colors come from Palette; no literal UI color is written outside of it.

const FONT_PATH: String = "res://asset/fonts/main_font.ttf"

const RADIUS_CARD: int = 18
const RADIUS_CONTROL: int = 12
const SWITCH_SIZE: Vector2 = Vector2(54, 30)

# Multiplier applied to type sizes and touch targets. SettingsRoot raises it
# on mobile before building, so the same design reads comfortably on a phone.
static var ui_scale: float = 1.0


static func px(value: float) -> int:
	return maxi(1, int(round(value * ui_scale)))


static func switch_size() -> Vector2:
	return Vector2(px(SWITCH_SIZE.x), px(SWITCH_SIZE.y))

# Nav icon kinds, drawn by NavButton.
const ICON_CONTROLS: int = 0
const ICON_GAMEPLAY: int = 1
const ICON_AUDIO: int = 2
const ICON_SONGS: int = 3
const ICON_ADVANCED: int = 4
const ICON_INFO: int = 5

static var _font_cache: Dictionary = {}
static var _switch_on: ImageTexture
static var _switch_off: ImageTexture
static var _switch_on_disabled: ImageTexture
static var _switch_off_disabled: ImageTexture
static var _empty_icon: ImageTexture
static var _grabber: ImageTexture


# --- Surfaces and type ------------------------------------------------------

static func flat(bg: Color, radius: int = RADIUS_CONTROL, border: int = 0, border_color: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(px(radius))
	if border > 0:
		sb.set_border_width_all(border)
		sb.border_color = border_color
	sb.anti_aliasing = true
	return sb


static func pad(sb: StyleBoxFlat, horizontal: float, vertical: float) -> StyleBoxFlat:
	sb.content_margin_left = horizontal
	sb.content_margin_right = horizontal
	sb.content_margin_top = vertical
	sb.content_margin_bottom = vertical
	return sb


static func font_weight(weight: int) -> Font:
	if _font_cache.has(weight):
		return _font_cache[weight]
	var base: FontFile = load(FONT_PATH)
	var variation := FontVariation.new()
	variation.base_font = base
	variation.variation_opentype = {"wght": float(weight)}
	_font_cache[weight] = variation
	return variation


static func label(text: String, font_size: int, color: Color, weight: int = 400) -> Label:
	var node := Label.new()
	node.text = text
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	node.add_theme_font_override("font", font_weight(weight))
	node.add_theme_font_size_override("font_size", px(font_size))
	node.add_theme_color_override("font_color", color)
	return node


static func kicker(text: String) -> Label:
	var node := label(text.to_upper(), 12, Palette.ASH, 600)
	node.set_meta("kicker", true)
	return node


static func description(text: String, color: Color = Palette.ASH_DIM) -> Label:
	var node := label(text, 13, color, 400)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


static func title(text: String) -> Label:
	return label(text, 34, Palette.BONE_HI, 600)


static func subtitle(text: String) -> Label:
	var node := label(text, 15, Palette.ASH_DIM, 400)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node


static func divider() -> Control:
	var line := ColorRect.new()
	line.color = Palette.BORDER_SOFT
	line.custom_minimum_size.y = 1
	line.mouse_filter = Control.MOUSE_FILTER_PASS
	return line


# A raised panel with a title kicker and a body that rows are appended to.
class Section extends PanelContainer:
	var body: VBoxContainer

	func _init(title_text: String = "", subtitle_text: String = "") -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		var sb := SettingsUI.flat(Palette.SURFACE_1, SettingsUI.RADIUS_CARD)
		SettingsUI.pad(sb, SettingsUI.px(22), SettingsUI.px(20))
		add_theme_stylebox_override("panel", sb)

		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_PASS
		column.add_theme_constant_override("separation", SettingsUI.px(12))
		add_child(column)

		if not title_text.is_empty():
			column.add_child(SettingsUI.kicker(title_text))
		if not subtitle_text.is_empty():
			column.add_child(SettingsUI.description(subtitle_text))

		body = VBoxContainer.new()
		body.mouse_filter = Control.MOUSE_FILTER_PASS
		body.add_theme_constant_override("separation", SettingsUI.px(16))
		column.add_child(body)


static func section(title_text: String = "", subtitle_text: String = "") -> Section:
	return Section.new(title_text, subtitle_text)


# Keeps the main settings column at a comfortable reading width and centers it
# in the remaining space. On a phone the viewport can be much wider than the
# 1280 design width; without this the cards would stretch edge to edge.
class ContentLimit extends Container:
	var max_width: float = 1180.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL

	func _get_minimum_size() -> Vector2:
		if get_child_count() == 0:
			return Vector2.ZERO
		return (get_child(0) as Control).get_combined_minimum_size()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_SORT_CHILDREN:
			if get_child_count() == 0:
				return
			var child := get_child(0) as Control
			if child == null:
				return
			var width: float = minf(size.x, max_width)
			var x: float = floorf((size.x - width) * 0.5)
			fit_child_in_rect(child, Rect2(Vector2(x, 0.0), Vector2(width, size.y)))


# --- Rows -------------------------------------------------------------------

static func row(title_text: String, desc: String = "", control: Control = null) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	node.add_theme_constant_override("separation", SettingsUI.px(18))
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var text_column := VBoxContainer.new()
	text_column.mouse_filter = Control.MOUSE_FILTER_PASS
	text_column.add_theme_constant_override("separation", SettingsUI.px(3))
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_column.add_child(label(title_text, 19, Palette.TEXT, 500))
	if not desc.is_empty():
		text_column.add_child(description(desc))
	node.add_child(text_column)

	if control != null:
		control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		node.add_child(control)
	return node


# --- Buttons ----------------------------------------------------------------

static func button(text: String, kind: String = "secondary") -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = px(46)
	node.add_theme_font_override("font", font_weight(500))
	node.add_theme_font_size_override("font_size", px(17))

	var normal := flat(Color.TRANSPARENT, RADIUS_CONTROL)
	var hover := flat(Color.TRANSPARENT, RADIUS_CONTROL)
	var pressed := flat(Color.TRANSPARENT, RADIUS_CONTROL)
	var disabled := flat(Color.TRANSPARENT, RADIUS_CONTROL)
	var font_color: Color = Palette.TEXT

	match kind:
		"primary":
			normal = pad(flat(Palette.ACCENT, RADIUS_CONTROL), px(22), px(12))
			hover = pad(flat(Palette.ACCENT_BRIGHT, RADIUS_CONTROL), px(22), px(12))
			pressed = pad(flat(Palette.BLOOD_BRIGHT, RADIUS_CONTROL), px(22), px(12))
			font_color = Palette.BONE_HI
		"ghost":
			normal = pad(flat(Palette.SURFACE_1, RADIUS_CONTROL), px(20), px(12))
			hover = pad(flat(Palette.SURFACE_2, RADIUS_CONTROL), px(20), px(12))
			pressed = pad(flat(Palette.SURFACE_3, RADIUS_CONTROL), px(20), px(12))
			font_color = Palette.CHROME
		"quiet":
			normal = pad(flat(Color.TRANSPARENT, RADIUS_CONTROL), px(16), px(12))
			hover = pad(flat(Palette.SURFACE_2, RADIUS_CONTROL), px(16), px(12))
			pressed = pad(flat(Palette.SURFACE_3, RADIUS_CONTROL), px(16), px(12))
			font_color = Palette.CHROME
		"danger":
			normal = pad(flat(Palette.SURFACE_1, RADIUS_CONTROL), px(20), px(12))
			hover = pad(flat(Palette.ACCENT_FAINT, RADIUS_CONTROL), px(20), px(12))
			pressed = pad(flat(Palette.ACCENT_SOFT, RADIUS_CONTROL), px(20), px(12))
			font_color = Palette.BLOOD_GLOW
		_:
			normal = pad(flat(Palette.SURFACE_3, RADIUS_CONTROL), px(22), px(12))
			hover = pad(flat(Palette.SURFACE_4, RADIUS_CONTROL), px(22), px(12))
			pressed = pad(flat(Palette.SURFACE_2, RADIUS_CONTROL), px(22), px(12))
			font_color = Palette.BONE

	disabled = normal
	node.add_theme_stylebox_override("normal", normal)
	node.add_theme_stylebox_override("hover", hover)
	node.add_theme_stylebox_override("pressed", pressed)
	node.add_theme_stylebox_override("disabled", disabled)
	node.add_theme_stylebox_override("focus", hover)
	node.add_theme_color_override("font_color", font_color)
	node.add_theme_color_override("font_hover_color", Palette.BONE_HI)
	node.add_theme_color_override("font_pressed_color", Palette.BONE_HI)
	node.add_theme_color_override("font_focus_color", font_color)
	node.add_theme_color_override("font_disabled_color", Palette.MUTED_DIM)
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return node


static func icon_button(text: String) -> Button:
	var node := button(text, "secondary")
	node.custom_minimum_size = Vector2(px(46), px(46))
	node.add_theme_font_size_override("font_size", px(15))
	return node


# --- Switches ---------------------------------------------------------------

# A CheckBox is kept instead of a custom button: it already carries the
# pressed state, keyboard focus and the toggled signal. Only its icon is
# replaced, so the row reads as a modern switch while the accessible text
# stays in `text`.
static func switch_check(text: String, pressed: bool) -> CheckBox:
	var node := CheckBox.new()
	node.text = text
	node.button_pressed = pressed
	node.custom_minimum_size.y = px(44)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_font_override("font", font_weight(500))
	node.add_theme_font_size_override("font_size", px(19))
	node.add_theme_color_override("font_color", Palette.TEXT)
	node.add_theme_color_override("font_hover_color", Palette.BONE_HI)
	node.add_theme_color_override("font_pressed_color", Palette.BONE_HI)
	node.add_theme_color_override("font_focus_color", Palette.TEXT)
	node.add_theme_color_override("font_disabled_color", Palette.MUTED)
	node.add_theme_constant_override("h_separation", px(14))
	node.add_theme_icon_override("checked", switch_texture(true, false))
	node.add_theme_icon_override("unchecked", switch_texture(false, false))
	node.add_theme_icon_override("checked_disabled", switch_texture(true, true))
	node.add_theme_icon_override("unchecked_disabled", switch_texture(false, true))
	node.add_theme_stylebox_override("focus", pad(flat(Color(1, 1, 1, 0.04), RADIUS_CONTROL), px(6), px(4)))
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return node


static func add_toggle(parent: VBoxContainer, title_text: String, desc: String, pressed: bool, callback: Callable) -> CheckBox:
	var wrap := VBoxContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_PASS
	wrap.add_theme_constant_override("separation", SettingsUI.px(2))
	var check := switch_check(title_text, pressed)
	check.toggled.connect(callback)
	wrap.add_child(check)
	if not desc.is_empty():
		var indent := MarginContainer.new()
		indent.mouse_filter = Control.MOUSE_FILTER_PASS
		indent.add_theme_constant_override("margin_left", int(switch_size().x) + px(14))
		indent.add_child(description(desc))
		wrap.add_child(indent)
	parent.add_child(wrap)
	return check


static func switch_texture(on: bool, disabled: bool) -> ImageTexture:
	if on and disabled and _switch_on_disabled != null:
		return _switch_on_disabled
	if not on and disabled and _switch_off_disabled != null:
		return _switch_off_disabled
	if on and not disabled and _switch_on != null:
		return _switch_on
	if not on and not disabled and _switch_off != null:
		return _switch_off

	var size := switch_size()
	var w: int = int(size.x)
	var h: int = int(size.y)
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var radius: float = h * 0.5
	var track: Color = Palette.ACCENT if on else Color(0.220, 0.220, 0.245)
	if disabled:
		track = Color(track.r, track.g, track.b, track.a * 0.45)
	var knob_center := Vector2(w - radius, radius) if on else Vector2(radius, radius)
	var knob: Color = Palette.BONE_HI if not disabled else Palette.CHROME

	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var track_cov := _coverage(_round_box_sdf(p, Vector2(w, h), radius))
			_blend(image, x, y, Color(track.r, track.g, track.b, track.a * track_cov))
			var shadow_cov := _coverage(p.distance_to(knob_center + Vector2(0, 1)) - (radius - 3.5))
			_blend(image, x, y, Color(0, 0, 0, 0.35 * shadow_cov * (0.0 if disabled else 1.0)))
			var knob_cov := _coverage(p.distance_to(knob_center) - (radius - 4.0))
			_blend(image, x, y, Color(knob.r, knob.g, knob.b, knob.a * knob_cov))

	var texture := ImageTexture.create_from_image(image)
	if disabled:
		if on:
			_switch_on_disabled = texture
		else:
			_switch_off_disabled = texture
	elif on:
		_switch_on = texture
	else:
		_switch_off = texture
	return texture


static func _round_box_sdf(p: Vector2, size: Vector2, radius: float) -> float:
	var half := size * 0.5
	var d: Vector2 = p - half
	d = Vector2(absf(d.x), absf(d.y)) - (half - Vector2(radius, radius))
	return Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length() + minf(maxf(d.x, d.y), 0.0) - radius


static func _coverage(distance: float) -> float:
	return clampf(0.5 - distance, 0.0, 1.0)


static func _blend(image: Image, x: int, y: int, color: Color) -> void:
	if color.a <= 0.0:
		return
	var dst: Color = image.get_pixel(x, y)
	var out_a: float = color.a + dst.a * (1.0 - color.a)
	if out_a <= 0.0001:
		image.set_pixel(x, y, Color(0, 0, 0, 0))
		return
	var rgb: Vector3 = (Vector3(color.r, color.g, color.b) * color.a + Vector3(dst.r, dst.g, dst.b) * dst.a * (1.0 - color.a)) / out_a
	image.set_pixel(x, y, Color(rgb.x, rgb.y, rgb.z, out_a))


# --- Segmented choice -------------------------------------------------------

class Segmented extends PanelContainer:
	var buttons: Array[CheckBox] = []

	func _init(options: Array) -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		var track := SettingsUI.flat(Palette.SURFACE_2, 14)
		SettingsUI.pad(track, SettingsUI.px(4), SettingsUI.px(4))
		add_theme_stylebox_override("panel", track)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_theme_constant_override("separation", SettingsUI.px(4))
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(row)
		for option in options:
			var choice := _segment(str(option))
			row.add_child(choice)
			buttons.append(choice)

	func _segment(text: String) -> CheckBox:
		var node := CheckBox.new()
		node.text = text
		node.alignment = HORIZONTAL_ALIGNMENT_CENTER
		node.custom_minimum_size.y = SettingsUI.px(44)
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		node.add_theme_font_override("font", SettingsUI.font_weight(500))
		node.add_theme_font_size_override("font_size", SettingsUI.px(16))
		node.add_theme_color_override("font_color", Palette.CHROME)
		node.add_theme_color_override("font_hover_color", Palette.BONE_HI)
		node.add_theme_color_override("font_pressed_color", Palette.BONE_HI)
		node.add_theme_color_override("font_focus_color", Palette.BONE_HI)
		node.add_theme_icon_override("checked", SettingsUI._empty())
		node.add_theme_icon_override("unchecked", SettingsUI._empty())
		node.add_theme_icon_override("checked_disabled", SettingsUI._empty())
		node.add_theme_icon_override("unchecked_disabled", SettingsUI._empty())
		node.add_theme_stylebox_override("normal", SettingsUI.flat(Color.TRANSPARENT, 10))
		node.add_theme_stylebox_override("hover", SettingsUI.flat(Palette.SURFACE_3, 10))
		node.add_theme_stylebox_override("pressed", SettingsUI.flat(Palette.ACCENT_SURFACE, 10))
		node.add_theme_stylebox_override("hover_pressed", SettingsUI.flat(Palette.ACCENT_SURFACE_HOVER, 10))
		node.add_theme_stylebox_override("focus", SettingsUI.flat(Palette.ACCENT_SURFACE_HOVER, 10))
		node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		return node


# 1x1 transparent icon, used to hide the CheckBox glyph in segmented choices.
static func _empty() -> ImageTexture:
	if _empty_icon != null:
		return _empty_icon
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color(0, 0, 0, 0))
	_empty_icon = ImageTexture.create_from_image(image)
	return _empty_icon


# --- Sliders ----------------------------------------------------------------

static func slider(min_value: float, max_value: float, step: float, value: float) -> HSlider:
	var node := HSlider.new()
	node.min_value = min_value
	node.max_value = max_value
	node.step = step
	node.value = value
	node.custom_minimum_size.y = px(44)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_stylebox_override("slider", pad(flat(Color(1, 1, 1, 0.10), 3), 0, px(3)))
	node.add_theme_stylebox_override("grabber_area", pad(flat(Palette.ACCENT, 3), 0, px(3)))
	node.add_theme_stylebox_override("grabber_area_highlight", pad(flat(Palette.ACCENT_BRIGHT, 3), 0, px(3)))
	node.add_theme_icon_override("grabber", grabber_texture())
	node.add_theme_icon_override("grabber_highlight", grabber_texture())
	node.add_theme_stylebox_override("focus", flat(Color.TRANSPARENT, 4))
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return node


static func grabber_texture() -> ImageTexture:
	if _grabber != null:
		return _grabber
	var size: int = px(30)
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5)
			var shadow := _coverage(p.distance_to(center + Vector2(0, 1.5 * ui_scale)) - 10.5 * ui_scale)
			_blend(image, x, y, Color(0, 0, 0, 0.35 * shadow))
			var body := _coverage(p.distance_to(center) - 10.0 * ui_scale)
			_blend(image, x, y, Color(Palette.BONE_HI.r, Palette.BONE_HI.g, Palette.BONE_HI.b, body))
			var ring := _coverage(absf(p.distance_to(center) - 6.2 * ui_scale) - 1.0 * ui_scale)
			_blend(image, x, y, Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.85 * ring))
	_grabber = ImageTexture.create_from_image(image)
	return _grabber


static func value_badge(text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb := flat(Palette.SURFACE_2, 9)
	pad(sb, px(10), px(4))
	panel.add_theme_stylebox_override("panel", sb)
	var node := label(text, 14, Palette.BONE, 500)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.custom_minimum_size.x = px(58)
	panel.add_child(node)
	panel.set_meta("value_label", node)
	return panel


static func add_slider_row(parent: VBoxContainer, title_text: String, desc: String, min_value: float, max_value: float, step: float, value: float, formatter: Callable, on_change: Callable, on_drag_ended: Callable = Callable()) -> HSlider:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", SettingsUI.px(6))
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.mouse_filter = Control.MOUSE_FILTER_PASS

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", SettingsUI.px(12))
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.mouse_filter = Control.MOUSE_FILTER_PASS
	var name_label := label(title_text, 17, Palette.TEXT, 500)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(name_label)
	var badge := value_badge(str(formatter.call(value)) if formatter.is_valid() else str(value))
	head.add_child(badge)
	wrap.add_child(head)

	var value_label: Label = badge.get_meta("value_label")
	var control := slider(min_value, max_value, step, value)
	control.value_changed.connect(func(new_value: float) -> void:
		value_label.text = str(formatter.call(new_value)) if formatter.is_valid() else str(new_value)
		if on_change.is_valid():
			on_change.call(new_value)
	)
	if on_drag_ended.is_valid():
		control.drag_ended.connect(func(changed: bool) -> void: on_drag_ended.call(changed))
	wrap.add_child(control)

	if not desc.is_empty():
		wrap.add_child(description(desc))
	parent.add_child(wrap)
	return control


# --- Progress ---------------------------------------------------------------

static func style_progress(bar: ProgressBar) -> void:
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	bar.add_theme_stylebox_override("background", pad(flat(Color(1, 1, 1, 0.08), 4), 0, px(4)))
	bar.add_theme_stylebox_override("fill", pad(flat(Palette.ACCENT, 4), 0, px(4)))
	bar.custom_minimum_size.y = px(10)


# --- Inputs -----------------------------------------------------------------

static func style_line_edit(edit: LineEdit) -> void:
	edit.custom_minimum_size.y = px(46)
	edit.add_theme_font_override("font", font_weight(450))
	edit.add_theme_font_size_override("font_size", px(16))
	edit.add_theme_color_override("font_color", Palette.TEXT)
	edit.add_theme_color_override("font_placeholder_color", Palette.MUTED)
	edit.add_theme_color_override("caret_color", Palette.ACCENT)
	edit.add_theme_color_override("selection_color", Palette.ACCENT_SOFT)
	var normal := pad(flat(Palette.SURFACE_2, RADIUS_CONTROL), px(14), px(10))
	var focus := pad(flat(Palette.SURFACE_3, RADIUS_CONTROL), px(14), px(10))
	var read_only := pad(flat(Palette.SURFACE_1, RADIUS_CONTROL), px(14), px(10))
	edit.add_theme_stylebox_override("normal", normal)
	edit.add_theme_stylebox_override("focus", focus)
	edit.add_theme_stylebox_override("read_only", read_only)


static func style_option(option: OptionButton) -> void:
	option.custom_minimum_size.y = px(44)
	option.alignment = HORIZONTAL_ALIGNMENT_LEFT
	option.add_theme_font_override("font", font_weight(500))
	option.add_theme_font_size_override("font_size", px(16))
	option.add_theme_color_override("font_color", Palette.BONE)
	option.add_theme_color_override("font_hover_color", Palette.BONE_HI)
	option.add_theme_color_override("font_pressed_color", Palette.BONE_HI)
	option.add_theme_color_override("font_focus_color", Palette.BONE)
	option.add_theme_stylebox_override("normal", pad(flat(Palette.SURFACE_2, 10), px(14), px(9)))
	option.add_theme_stylebox_override("hover", pad(flat(Palette.SURFACE_3, 10), px(14), px(9)))
	option.add_theme_stylebox_override("pressed", pad(flat(Palette.SURFACE_3, 10), px(14), px(9)))
	option.add_theme_stylebox_override("focus", pad(flat(Palette.SURFACE_3, 10), px(14), px(9)))
	option.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Let a drag that starts on the selector reach the ScrollContainer instead
	# of being swallowed by the button; a tap still opens the popup.
	option.mouse_filter = Control.MOUSE_FILTER_PASS


# --- Navigation -------------------------------------------------------------

class NavButton extends Button:
	var icon_kind: int = SettingsUI.ICON_CONTROLS
	var draw_icon: bool = true

	func _init(text_value: String, kind: int, compact: bool = false) -> void:
		text = text_value.to_upper()
		icon_kind = kind
		toggle_mode = true
		focus_mode = Control.FOCUS_ALL
		alignment = HORIZONTAL_ALIGNMENT_CENTER if compact else HORIZONTAL_ALIGNMENT_LEFT
		draw_icon = not compact
		custom_minimum_size.y = SettingsUI.px(50)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_theme_font_override("font", SettingsUI.font_weight(500))
		add_theme_font_size_override("font_size", SettingsUI.px(16 if compact else 17))
		add_theme_color_override("font_color", Palette.ASH)
		add_theme_color_override("font_hover_color", Palette.BONE_HI)
		add_theme_color_override("font_pressed_color", Palette.BONE_HI)
		add_theme_color_override("font_focus_color", Palette.BONE_HI)

		var side_pad: int = SettingsUI.px(14 if compact else 54)
		var normal := SettingsUI.pad(SettingsUI.flat(Color.TRANSPARENT, 12), side_pad, SettingsUI.px(8))
		var hover := SettingsUI.pad(SettingsUI.flat(Palette.SURFACE_2, 12), side_pad, SettingsUI.px(8))
		var active := SettingsUI.flat(Palette.ACCENT_SURFACE, 12)
		active.content_margin_left = side_pad
		active.content_margin_right = side_pad
		active.content_margin_top = SettingsUI.px(8)
		active.content_margin_bottom = SettingsUI.px(8)
		add_theme_stylebox_override("normal", normal)
		add_theme_stylebox_override("hover", hover)
		add_theme_stylebox_override("pressed", active)
		add_theme_stylebox_override("hover_pressed", active)
		add_theme_stylebox_override("focus", SettingsUI.pad(SettingsUI.flat(Color.TRANSPARENT, 12), side_pad, SettingsUI.px(8)))
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		toggled.connect(func(_on: bool) -> void: queue_redraw())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		if not draw_icon:
			return
		var color: Color = Palette.ACCENT if button_pressed else (Palette.BONE if is_hovered() else Palette.ASH)
		var origin := Vector2(float(SettingsUI.px(24)), size.y * 0.5)
		match icon_kind:
			SettingsUI.ICON_CONTROLS:
				for i in 3:
					var y: float = -6.0 + float(i) * 6.0
					draw_line(origin + Vector2(-8.0, y), origin + Vector2(8.0, y), color, 1.8, true)
				draw_circle(origin + Vector2(-3.0, -6.0), 2.4, color, true, -1.0, true)
				draw_circle(origin + Vector2(4.0, 0.0), 2.4, color, true, -1.0, true)
				draw_circle(origin + Vector2(-5.0, 6.0), 2.4, color, true, -1.0, true)
			SettingsUI.ICON_GAMEPLAY:
				draw_colored_polygon(PackedVector2Array([
					origin + Vector2(-5.0, -7.5),
					origin + Vector2(7.5, 0.0),
					origin + Vector2(-5.0, 7.5),
				]), color)
			SettingsUI.ICON_AUDIO:
				draw_colored_polygon(PackedVector2Array([
					origin + Vector2(-8.0, -3.0),
					origin + Vector2(-4.0, -3.0),
					origin + Vector2(1.0, -7.5),
					origin + Vector2(1.0, 7.5),
					origin + Vector2(-4.0, 3.0),
					origin + Vector2(-8.0, 3.0),
				]), color)
				draw_arc(origin + Vector2(2.0, 0.0), 6.0, -0.85, 0.85, 14, color, 1.8, true)
				draw_arc(origin + Vector2(2.0, 0.0), 9.0, -0.75, 0.75, 16, Color(color.r, color.g, color.b, color.a * 0.55), 1.6, true)
			SettingsUI.ICON_SONGS:
				var folder := PackedVector2Array([
					origin + Vector2(-9.0, -6.0),
					origin + Vector2(-3.0, -6.0),
					origin + Vector2(-0.5, -3.0),
					origin + Vector2(9.0, -3.0),
					origin + Vector2(9.0, 7.0),
					origin + Vector2(-9.0, 7.0),
					origin + Vector2(-9.0, -6.0),
				])
				draw_polyline(folder, color, 1.8, true)
			SettingsUI.ICON_ADVANCED:
				draw_arc(origin, 6.0, 0.0, TAU, 24, color, 1.8, true)
				draw_circle(origin, 2.0, color, true, -1.0, true)
				for i in 8:
					var angle: float = TAU * float(i) / 8.0
					draw_line(origin + Vector2(cos(angle), sin(angle)) * 8.0, origin + Vector2(cos(angle), sin(angle)) * 10.0, color, 1.8, true)
			SettingsUI.ICON_INFO:
				draw_arc(origin, 8.0, 0.0, TAU, 24, color, 1.8, true)
				draw_circle(origin + Vector2(0, -3.5), 1.2, color, true, -1.0, true)
				draw_line(origin + Vector2(0, -0.5), origin + Vector2(0, 5.0), color, 1.8, true)


static func nav_button(text_value: String, icon_kind: int, compact: bool = false) -> NavButton:
	return NavButton.new(text_value, icon_kind, compact)
