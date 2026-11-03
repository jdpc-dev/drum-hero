class_name LaneOrderRow
extends Control

# Horizontal custom lane-order editor. It mirrors the highway: one coloured
# block per visual column. Dragging a block left or right moves that lane and
# the blocks in between shift, like reordering a physical row of pads.
signal order_changed(lanes: Array)

const TILE_HEIGHT: float = 88.0
const DRAG_THRESHOLD: float = 8.0
const OUTER_RADIUS: int = 12

var lanes: Array[int] = []

var _pressed: bool = false
var _dragging: bool = false
var _drag_index: int = -1
var _press_position: Vector2 = Vector2.ZERO
var _changed: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	custom_minimum_size.y = SettingsUI.px(TILE_HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func set_order(order: Array) -> void:
	lanes = SettingsManager.normalize_lane_order(order)
	_pressed = false
	_dragging = false
	_drag_index = -1
	_changed = false
	queue_redraw()


func get_order() -> Array[int]:
	return lanes.duplicate()


func _gui_input(event: InputEvent) -> void:
	if lanes.is_empty():
		return

	# Keep the same touch/mouse split as the rest of the panel: Android also
	# emits an emulated mouse event for touches, and processing both would
	# start the drag twice.
	if DisplayServer.is_touchscreen_available():
		if event is InputEventScreenTouch:
			if event.pressed:
				_begin(event.position)
			else:
				_end(event.position)
		elif event is InputEventScreenDrag and _pressed:
			_update_drag(event.position)
	else:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_begin(event.position)
			else:
				_end(event.position)
		elif event is InputEventMouseMotion and _pressed and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_update_drag(event.position)


func _begin(position: Vector2) -> void:
	_pressed = true
	_dragging = false
	_changed = false
	_press_position = position
	_drag_index = _index_at(position)
	queue_redraw()


func _update_drag(position: Vector2) -> void:
	if not _pressed:
		return
	if not _dragging:
		var delta := position - _press_position
		if absf(delta.x) < SettingsUI.px(DRAG_THRESHOLD):
			return
		# A vertical swipe belongs to the settings ScrollContainer.
		if absf(delta.x) <= absf(delta.y):
			return
		_dragging = true

	if not _dragging:
		return
	var target: int = _index_at(position)
	if target >= 0 and target != _drag_index:
		var lane: int = lanes[_drag_index]
		lanes.remove_at(_drag_index)
		lanes.insert(target, lane)
		_drag_index = target
		_changed = true
		queue_redraw()
	accept_event()


func _end(position: Vector2) -> void:
	if not _pressed:
		return
	if _dragging:
		_update_drag(position)
		var changed: bool = _changed
		_pressed = false
		_dragging = false
		_drag_index = -1
		_changed = false
		queue_redraw()
		if changed:
			order_changed.emit(get_order())
			accept_event()
		return
	_pressed = false
	_drag_index = -1
	queue_redraw()


func _index_at(position: Vector2) -> int:
	if lanes.is_empty() or size.x <= 0.0:
		return -1
	var tile_w: float = size.x / float(lanes.size())
	return clampi(int(position.x / tile_w), 0, lanes.size() - 1)


func _draw() -> void:
	if lanes.is_empty():
		return

	var count: int = lanes.size()
	var tile_w: float = size.x / float(count)
	var colors: Array[Color] = Highway._get_lane_colors()
	var font: Font = SettingsUI.font_weight(600)

	for i in count:
		var lane: int = lanes[i]
		var rect := Rect2(tile_w * i, 0.0, tile_w, size.y)
		var lane_color: Color = colors[lane] if lane < colors.size() else Palette.BONE
		var bg: Color = Palette.SURFACE_2.lerp(lane_color, 0.35)
		var lifted: bool = _dragging and i == _drag_index
		if lifted:
			bg = bg.lightened(0.08)

		var style := StyleBoxFlat.new()
		style.bg_color = bg
		style.anti_aliasing = true
		var radius: int = SettingsUI.px(OUTER_RADIUS)
		if i == 0:
			style.corner_radius_top_left = radius
			style.corner_radius_bottom_left = radius
		if i == count - 1:
			style.corner_radius_top_right = radius
			style.corner_radius_bottom_right = radius
		if lifted:
			style.border_width_left = SettingsUI.px(2)
			style.border_width_top = SettingsUI.px(2)
			style.border_width_right = SettingsUI.px(2)
			style.border_width_bottom = SettingsUI.px(2)
			style.border_color = Palette.ACCENT_EDGE
		draw_style_box(style, rect)

		var text: String = DrumGraphics.LANE_LABELS[lane] if lane < DrumGraphics.LANE_LABELS.size() else str(lane)
		var font_size: int = clampi(int(tile_w * 0.24), SettingsUI.px(11), SettingsUI.px(20))
		var ascent: float = font.get_ascent(font_size)
		var descent: float = font.get_descent(font_size)
		var baseline: float = rect.position.y + (rect.size.y + ascent - descent) * 0.5
		draw_string(
			font,
			Vector2(rect.position.x, baseline),
			text,
			HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x,
			font_size,
			Palette.BONE_HI)
