class_name Lane
extends Node2D

var lane_index: int = 0
var hit_line_y: float = 0.0

var _pending_queue: Array = []
var _active_notes: Array = []

var highway_ref: Node

@export var note_scene: PackedScene
@export var lane_width: float = 0.0
@export var lane_color: Color = Color.WHITE

var _bg_rect: ColorRect
var _lane_color: Color

var _is_slashing: bool = false
var _slash_timer: float = 0.0
var _slash_duration: float = 0.12
var _slash_left: ColorRect
var _slash_right: ColorRect


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

	_slash_left = ColorRect.new()
	_slash_left.color = _lane_color
	_slash_left.color.a = 0.0
	_slash_left.z_index = 2
	_slash_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_slash_left)

	_slash_right = ColorRect.new()
	_slash_right.color = _lane_color
	_slash_right.color.a = 0.0
	_slash_right.z_index = 2
	_slash_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_slash_right)


func queue_note(event: ChartData.NoteEvent) -> void:
	_pending_queue.append(event)


func update_notes(delta: float, current_time: float) -> void:
	_spawn_pending(current_time)
	_update_active(delta, current_time)
	_update_highlight(delta)


func _spawn_pending(current_time: float) -> void:
	var spawn_time: float = current_time + 2.0
	var i: int = 0
	while i < _pending_queue.size():
		var event: ChartData.NoteEvent = _pending_queue[i]
		if event.time <= spawn_time:
			var note := note_scene.instantiate() as Note
			note.note_data = event
			note.lane_ref = self
			add_child(note)
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
		note.queue_free()


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
				nearest.queue_free()
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


func _update_highlight(delta: float) -> void:
	if not _is_slashing:
		return
	_slash_timer -= delta
	if _slash_timer <= 0.0:
		_is_slashing = false
		_slash_left.color.a = 0.0
		_slash_right.color.a = 0.0
		return

	var total: int = highway_ref.active_lane_count
	var lw: float = highway_ref.screen_w / float(total)
	var bg_h: float = highway_ref.highway_bottom_y - highway_ref.highway_top_y
	var vi: int = highway_ref.get_lane_visual_index(lane_index)
	var center_x: float = lw * vi + lw * 0.5
	var top_y: float = highway_ref.highway_top_y

	var t: float = _slash_timer / _slash_duration
	var progress: float = 1.0 - t
	var half_w: float = progress * lw * 0.5

	var alpha: float
	if progress < 0.15:
		alpha = progress / 0.15
	else:
		alpha = 1.0 - (progress - 0.15) / 0.85
	alpha = clampf(alpha, 0.0, 1.0) * 0.85

	_slash_left.color.a = alpha
	_slash_left.position = Vector2(center_x - half_w, top_y)
	_slash_left.size = Vector2(half_w, bg_h)

	_slash_right.color.a = alpha
	_slash_right.position = Vector2(center_x, top_y)
	_slash_right.size = Vector2(half_w, bg_h)


func clear() -> void:
	for note in _active_notes:
		note.queue_free()
	_active_notes.clear()
	_pending_queue.clear()
