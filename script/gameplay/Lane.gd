class_name Lane
extends Node2D

var lane_index: int = 0
var hit_line_y: float = 0.0

var _pending_queue: Array = []
var _active_notes: Array = []
var _note_pool: Array[Note] = []

var highway_ref: Node

@export var note_scene: PackedScene
@export var lane_width: float = 0.0
@export var lane_color: Color = Color.WHITE

var _bg_rect: ColorRect
var _lane_color: Color

var _is_slashing: bool = false
var _slash_timer: float = 0.0
var _slash_duration: float = 0.12
var _slash_alpha: float = 0.0
var _slash_lw: float = 0.0
var _slash_center_x: float = 0.0
var _slash_top_y: float = 0.0
var _slash_bg_h: float = 0.0


func _ready() -> void:
	hit_line_y = highway_ref.hit_line_y

	var total: int = highway_ref.active_lane_count
	var lw: float = highway_ref.screen_w / float(total)
	var bg_h: float = highway_ref.highway_bottom_y - highway_ref.highway_top_y
	var vi: int = highway_ref.get_lane_visual_index(lane_index)
	_lane_color = Highway._get_lane_colors()[lane_index]

	_bg_rect = ColorRect.new()
	_bg_rect.position = Vector2(lw * vi, highway_ref.highway_top_y)
	_bg_rect.size = Vector2(lw, bg_h)
	_bg_rect.color = _lane_color
	_bg_rect.color.a = 0.08
	_bg_rect.z_index = -1
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_rect)


func queue_note(event: ChartData.NoteEvent) -> void:
	_pending_queue.append(event)


func update_notes(delta: float, current_time: float) -> void:
	_spawn_pending(current_time)
	_update_active(delta, current_time)
	_update_highlight(delta)


func _spawn_pending(current_time: float) -> void:
	var spawn_time: float = current_time + highway_ref.get_travel_time()
	var i: int = 0
	while i < _pending_queue.size():
		var event: ChartData.NoteEvent = _pending_queue[i]
		if event.time <= spawn_time:
			var note: Note = _get_note()
			note.lane_ref = self
			note.reset(event)
			_active_notes.append(note)
			_pending_queue.remove_at(i)
		else:
			i += 1


func _update_active(delta: float, current_time: float) -> void:
	var hit_time: float = current_time
	var miss_threshold: float = SettingsManager.judgement_miss_ms / 1000.0

	var i: int = 0
	while i < _active_notes.size():
		var note: Note = _active_notes[i]
		note.update_position(current_time)

		var time_diff: float = note.note_data.time - hit_time
		if time_diff < -miss_threshold:
			note._on_miss()
			ScoreManager.register_miss()
			GameManager.miss_registered.emit()
			if SettingsManager.show_hit_feedback:
				EffectManager.show_judgement(Judgement.TimingAccuracy.MISS, highway_ref.get_hit_global_position(lane_index), highway_ref)
			_remove_note(i)
		else:
			i += 1


func _remove_note(index: int) -> void:
	if index < _active_notes.size():
		var note: Note = _active_notes[index]
		_active_notes.remove_at(index)
		_return_note(note)


func try_hit(current_time: float, touch_position: Vector2) -> bool:
	if _active_notes.is_empty():
		return false

	var nearest: Note = null
	var nearest_diff: float = INF
	var miss_ms: float = SettingsManager.judgement_miss_ms
	var miss_sec: float = miss_ms / 1000.0
	var search_earliest: float = current_time - miss_sec
	var search_latest: float = current_time + miss_sec

	for note in _active_notes:
		var nt: float = note.note_data.time
		if nt < search_earliest or nt > search_latest:
			continue
		var diff: float = abs(nt - current_time)
		if diff < nearest_diff:
			nearest_diff = diff
			nearest = note

	if nearest:
		if nearest_diff * 1000.0 <= miss_ms:
			var accuracy: int = Judgement.evaluate(nearest.note_data.time - current_time, SettingsManager)
			if Judgement.is_hit(accuracy):
				nearest._on_hit()
				ScoreManager.register_hit(nearest_diff)
				GameManager.hit_registered.emit(accuracy)
				_active_notes.erase(nearest)
				_return_note(nearest)
				highway_ref.flash_hit_line(lane_index)
				_highlight()
				EffectManager.call_deferred("trigger_particle_burst",
					highway_ref.get_hit_global_position(lane_index),
					Highway._get_lane_colors()[lane_index],
					highway_ref)
				if SettingsManager.show_hit_feedback:
					EffectManager.call_deferred("show_judgement",
						accuracy,
						highway_ref.get_hit_global_position(lane_index),
						highway_ref)
				return true
			else:
				_remove_note(_active_notes.find(nearest))
				return false

	return false


func _highlight() -> void:
	_is_slashing = true
	_slash_timer = _slash_duration


func _draw() -> void:
	if not _is_slashing or _slash_alpha <= 0.0:
		return
	var half_w: float = (1.0 - _slash_timer / _slash_duration) * _slash_lw * 0.5
	var left_rect := Rect2(_slash_center_x - half_w, _slash_top_y, half_w, _slash_bg_h)
	var right_rect := Rect2(_slash_center_x, _slash_top_y, half_w, _slash_bg_h)
	draw_rect(left_rect, Color(_lane_color.r, _lane_color.g, _lane_color.b, _slash_alpha))
	draw_rect(right_rect, Color(_lane_color.r, _lane_color.g, _lane_color.b, _slash_alpha))


func _update_highlight(delta: float) -> void:
	if not _is_slashing:
		return
	_slash_timer -= delta
	if _slash_timer <= 0.0:
		_is_slashing = false
		_slash_alpha = 0.0
		queue_redraw()
		return

	var total: int = highway_ref.active_lane_count
	_slash_lw = highway_ref.screen_w / float(total)
	_slash_bg_h = highway_ref.highway_bottom_y - highway_ref.highway_top_y
	var vi: int = highway_ref.get_lane_visual_index(lane_index)
	_slash_center_x = _slash_lw * vi + _slash_lw * 0.5
	_slash_top_y = highway_ref.highway_top_y

	var t: float = _slash_timer / _slash_duration
	var progress: float = 1.0 - t

	if progress < 0.15:
		_slash_alpha = progress / 0.15
	else:
		_slash_alpha = 1.0 - (progress - 0.15) / 0.85
	_slash_alpha = clampf(_slash_alpha, 0.0, 1.0) * 0.85

	queue_redraw()


func _get_note() -> Note:
	for note in _note_pool:
		if not note.visible:
			return note
	var note := note_scene.instantiate() as Note
	add_child(note)
	_note_pool.append(note)
	return note


func _return_note(note: Note) -> void:
	note.visible = false
	note._rect.visible = false


func clear() -> void:
	for note in _active_notes:
		_return_note(note)
	_active_notes.clear()
	_pending_queue.clear()


# Records the notes still on screen as missed and clears the lane. Called at
# the end of the song: without audio, chart_duration matches the last note, so
# those notes never reach the miss window and the final count would fall short.
# It does not show a judgement popup: there was no hit to judge.
func flush_as_miss() -> int:
	var flushed: int = _active_notes.size()
	for note in _active_notes:
		note._on_miss()
		ScoreManager.register_miss()
		GameManager.miss_registered.emit()
	clear()
	return flushed
