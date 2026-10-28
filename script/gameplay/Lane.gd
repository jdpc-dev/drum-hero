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

var _is_highlighted: bool = false
var _highlight_timer: float = 0.0
var _highlight_duration: float = 0.08

var _bg_sprite: Sprite2D
var _screen_size: Vector2


func _ready() -> void:
    _screen_size = get_viewport_rect().size
    hit_line_y = highway_ref.hit_line_y

    _bg_sprite = Sprite2D.new()
    _bg_sprite.texture = preload("res://asset/textures/lane_bg.png")
    _bg_sprite.centered = false
    var total: int = highway_ref.lane_nodes.size()
    if total == 0:
        total = 8
    var lw: float = _screen_size.x / float(total)
    _bg_sprite.position = Vector2(lw * lane_index, highway_ref.highway_top_y)
    _bg_sprite.scale = Vector2(lw / _bg_sprite.texture.get_width(), (highway_ref.highway_bottom_y - highway_ref.highway_top_y) / _bg_sprite.texture.get_height())
    _bg_sprite.modulate = Color(1, 1, 1, 0.3)
    _bg_sprite.z_index = -1
    add_child(_bg_sprite)


func queue_note(event: ChartData.NoteEvent) -> void:
    for existing in _pending_queue:
        if existing.tick == event.tick:
            return
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
            EffectManager.play_miss_sfx()
            AudioManager.duck_drums()
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

    for note in _active_notes:
        var diff: float = abs(note.note_data.time - current_time)
        if diff < nearest_diff:
            nearest_diff = diff
            nearest = note

    if nearest:
        var miss_ms: float = SettingsManager.judgement_miss_ms
        if nearest_diff * 1000.0 <= miss_ms:
            var accuracy: int = Judgement.evaluate(nearest.note_data.time - current_time, SettingsManager)
            if Judgement.is_hit(accuracy):
                nearest._on_hit()
                ScoreManager.register_hit(nearest_diff)
                GameManager.hit_registered.emit(accuracy)
                EffectManager.play_hit_sfx()
                EffectManager.trigger_lane_flash(lane_index, highway_ref)
                _highlight()
                _active_notes.erase(nearest)
                nearest.queue_free()
                return true
            else:
                _remove_note(_active_notes.find(nearest))
                return false

    return false


func _highlight() -> void:
    _is_highlighted = true
    _highlight_timer = _highlight_duration


func _update_highlight(delta: float) -> void:
    if _is_highlighted:
        _highlight_timer -= delta
        if _highlight_timer <= 0.0:
            _is_highlighted = false
            _highlight_timer = 0.0
    if _is_highlighted:
        _bg_sprite.modulate = Color(1, 1, 1, 0.6)
    else:
        _bg_sprite.modulate = Color(1, 1, 1, 0.3)


func get_highlight_intensity() -> float:
    if not _is_highlighted:
        return 0.0
    return clampf(_highlight_timer / _highlight_duration, 0.0, 1.0)


func clear() -> void:
    for note in _active_notes:
        note.queue_free()
    _active_notes.clear()
    _pending_queue.clear()
