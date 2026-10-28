class_name Highway
extends Node2D

var lane_nodes: Array = []

@export var lane_scene: PackedScene
@export var hit_line_scene: PackedScene

var note_speed: float = 1.0
var active_lane_count: int = 8

var hit_line_y: float = 0.0
var hit_line_top_y: float = 0.0
var hit_line_bottom_y: float = 0.0
var highway_top_y: float = 0.0
var highway_bottom_y: float = 0.0
var labels_y: float = 0.0

var hit_line_ref: HitLine

var screen_w: float = 1280.0
var screen_h: float = 720.0
var pad_x: float = 0.0
var pad_y: float = 0.0

var _label_settings: LabelSettings
var _beat_line_pool: Array[ColorRect] = []
var _beat_timestamps: Array[Dictionary] = []

var _next_note_index: int = 0
var _beat_line_cursor: int = 0

var _bg_sprite: Sprite2D

signal lanes_built()


func _ready() -> void:
	_refresh_screen_size()
	_label_settings = preload("res://asset/fonts/label_settings.tres")
	_add_background()
	_build_lanes()


func generate_beat_lines() -> void:
	_generate_beat_timestamps()


func _refresh_screen_size() -> void:
	var vs: Vector2 = get_viewport_rect().size
	pad_x = SettingsManager.gameplay_padding_amount if SettingsManager.gameplay_padding_enabled else 0.0
	pad_y = pad_x
	position = Vector2(pad_x, pad_y)
	screen_w = vs.x - 2.0 * pad_x
	screen_h = vs.y - 2.0 * pad_y
	highway_top_y = screen_h * 0.025
	highway_bottom_y = screen_h * 0.65
	hit_line_top_y = screen_h * 0.65
	hit_line_bottom_y = screen_h * 0.72
	hit_line_y = (hit_line_top_y + hit_line_bottom_y) * 0.5
	labels_y = screen_h * 0.72


func _add_background() -> void:
	_bg_sprite = Sprite2D.new()
	_bg_sprite.texture = preload("res://asset/textures/highway_bg.png")
	_bg_sprite.centered = false
	var bg_h: float = highway_bottom_y - highway_top_y
	_bg_sprite.position = Vector2(0, highway_top_y)
	_bg_sprite.scale = Vector2(screen_w / _bg_sprite.texture.get_width(), bg_h / _bg_sprite.texture.get_height())
	_bg_sprite.z_index = -1
	add_child(_bg_sprite)


func _build_lanes() -> void:
	for child in get_children():
		if child is Lane:
			child.queue_free()
	lane_nodes.clear()

	var lane_order: Array[int] = _get_lane_order()
	active_lane_count = lane_order.size()

	for i in range(lane_order.size()):
		var lane := lane_scene.instantiate() as Lane
		lane.lane_index = lane_order[i]
		lane.highway_ref = self
		add_child(lane)
		lane_nodes.append(lane)

	var hit_line := hit_line_scene.instantiate() as HitLine
	add_child(hit_line)
	hit_line.setup(self)
	hit_line_ref = hit_line

	_build_touch_zones()
	if SettingsManager.gameplay_padding_enabled:
		AndroidBridge.set_lane_exclusion(pad_x, screen_w / float(active_lane_count), active_lane_count, pad_y, labels_y)
	lanes_built.emit()


func _build_touch_zones() -> void:
	var count: int = lane_nodes.size()
	var lane_w: float = screen_w / float(count)
	var lane_colors: Array[Color] = _get_lane_colors()

	for i in range(count):
		var lane_idx: int = lane_nodes[i].lane_index
		var zone := ColorRect.new()
		zone.name = "TouchZone_" + str(lane_idx)
		zone.position = Vector2(lane_w * i, labels_y)
		zone.size = Vector2(lane_w, screen_h - labels_y)
		zone.color = lane_colors[lane_idx]
		zone.color.a = 0.12
		zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(zone)

		var label := Label.new()
		label.text = DrumGraphics.LANE_LABELS[lane_idx]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.label_settings = _label_settings
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", lane_colors[lane_idx])
		label.position = Vector2(lane_w * i, labels_y)
		label.size = Vector2(lane_w, screen_h - labels_y)
		add_child(label)


func _generate_beat_timestamps() -> void:
	_beat_timestamps.clear()
	_beat_line_cursor = 0
	var tempos: Array = ChartParser.get_tempo_events()
	var resolution: int = ChartParser.get_resolution()
	var duration: float = ChartParser.get_duration_seconds()

	var tempo_idx: int = 0
	var ts_idx: int = 0
	var time_sigs: Array = ChartParser.get_time_signature_events()
	var current_tick: int = 0
	var current_time: float = 0.0
	var current_bpm: float = 120.0
	var current_mpt: float = 500000.0 / float(resolution)
	var current_denominator: int = 4
	var beats_per_bar: int = 4

	if not tempos.is_empty():
		current_bpm = tempos[0].bpm
		current_mpt = tempos[0].micros_per_tick

	while current_time < duration:
		var beat_duration: float = 4.0 / float(current_denominator)
		var beat_ticks: int = int(resolution * beat_duration)
		var seconds_per_beat: float = float(beat_ticks) * current_mpt / 1000000.0

		if ts_idx + 1 < time_sigs.size() and time_sigs[ts_idx + 1].tick <= current_tick:
			ts_idx += 1
			beats_per_bar = time_sigs[ts_idx].numerator
			current_denominator = time_sigs[ts_idx].denominator

		var bar_beat: int = 0
		while bar_beat < beats_per_bar:
			if tempo_idx + 1 < tempos.size() and tempos[tempo_idx + 1].tick <= current_tick:
				tempo_idx += 1
				current_bpm = tempos[tempo_idx].bpm
				current_mpt = tempos[tempo_idx].micros_per_tick
				beat_ticks = int(resolution * beat_duration)
				seconds_per_beat = float(beat_ticks) * current_mpt / 1000000.0

			_beat_timestamps.append({
				"time": current_time,
				"is_measure": bar_beat == 0
			})

			bar_beat += 1
			current_tick += beat_ticks
			current_time += seconds_per_beat

			if current_time > duration:
				break


static func _get_lane_colors() -> Array[Color]:
	return [
		Color(0.9, 0.8, 0.2),
		Color(1.0, 0.6, 0.0),
		Color(0.8, 0.2, 0.2),
		Color(0.6, 0.4, 0.8),
		Color(0.2, 0.7, 0.9),
		Color(0.2, 0.9, 0.5),
		Color(0.9, 0.3, 0.6),
		Color(0.5, 0.8, 0.3),
	]


func _get_lane_order() -> Array[int]:
	var mode: int = GameManager.mode
	if mode == GameManager.GameMode.HAPTIC:
		return [0, 1, 2, 4, 5, 6, 7]
	match mode:
		GameManager.GameMode.CUSTOM:
			var custom: Array = SettingsManager.custom_lanes
			if custom.size() > 0:
				return custom
	return [0, 1, 2, 3, 4, 5, 6, 7]


func _process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.PLAYING:
		return
	var time: float = TimingEngine.get_time()
	var all_notes: Array = ChartParser.note_data
	var spawn_window: float = time + 2.0

	while _next_note_index < all_notes.size():
		var note_data = all_notes[_next_note_index]
		if note_data.time > spawn_window:
			break
		for lane in lane_nodes:
			if lane.lane_index == note_data.lane:
				lane.queue_note(note_data)
				break
		_next_note_index += 1

	for lane in lane_nodes:
		lane.update_notes(delta, time)

	_update_beat_lines(time)


func _update_beat_lines(current_time: float) -> void:
	for bl in _beat_line_pool:
		bl.hide()

	var scroll_distance: float = (highway_bottom_y - highway_top_y) * note_speed
	var bottom_cutoff: float = 2.0 * (hit_line_y - highway_bottom_y) / scroll_distance if scroll_distance > 0 else 0.0
	var visible_range_start: float = current_time + bottom_cutoff
	var visible_range_end: float = current_time + 2.0

	var i: int = _beat_line_cursor
	while i < _beat_timestamps.size() and _beat_timestamps[i].time < visible_range_start:
		i += 1
	_beat_line_cursor = i

	while i < _beat_timestamps.size():
		var bt = _beat_timestamps[i]
		if bt.time > visible_range_end:
			break

		var line: ColorRect = _get_beat_line()
		var time_ahead: float = bt.time - current_time
		var y: float = hit_line_y - (time_ahead * scroll_distance) / 2.0
		line.position = Vector2(0, y)
		line.size = Vector2(screen_w, 2.0 if bt.is_measure else 1.0)
		line.color = Color(1, 1, 1, 0.4 if bt.is_measure else 0.12)
		line.show()
		i += 1


func _get_beat_line() -> ColorRect:
	for cl in _beat_line_pool:
		if not cl.visible:
			return cl
	var new_line := ColorRect.new()
	new_line.color = Color.WHITE
	new_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	new_line.z_index = -1
	add_child(new_line)
	_beat_line_pool.append(new_line)
	return new_line


func restart() -> void:
	_next_note_index = 0
	_beat_line_cursor = 0
	for lane in lane_nodes:
		lane.clear()
	for bl in _beat_line_pool:
		bl.hide()


func get_lane_screen_rect(lane_index: int) -> Rect2:
	var total_lanes: int = lane_nodes.size()
	var lane_w: float = screen_w / float(total_lanes)
	return Rect2(lane_w * lane_index, highway_top_y, lane_w, highway_bottom_y - highway_top_y)


func flash_hit_line(lane_index: int) -> void:
	if hit_line_ref:
		hit_line_ref.flash(lane_index)


func get_hit_global_position(lane_index: int) -> Vector2:
	var total: int = lane_nodes.size()
	if total == 0:
		return global_position
	var lane_w: float = screen_w / float(total)
	for i in range(total):
		if lane_nodes[i].lane_index == lane_index:
			return global_position + Vector2(lane_w * i + lane_w * 0.5, hit_line_y)
	return global_position + Vector2(lane_w * lane_index + lane_w * 0.5, hit_line_y)


func note_position(tick: int, lane_index: int, note_time: float, current_time: float) -> Vector2:
	var total_lanes: int = lane_nodes.size()
	var lane_w: float = screen_w / float(total_lanes)
	var x: float = lane_w * lane_index + lane_w * 0.5

	var time_ahead: float = note_time - current_time
	var scroll_distance: float = (highway_bottom_y - highway_top_y) * note_speed
	var y_offset: float = (time_ahead * scroll_distance) / 2.0
	var y: float = hit_line_y - y_offset

	return Vector2(x, y)
