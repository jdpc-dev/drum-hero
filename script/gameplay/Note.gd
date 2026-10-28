class_name Note
extends Node2D

var note_data: ChartData.NoteEvent
var lane_ref: Lane
var _hit: bool = false
var _missed: bool = false

var _sprite: Sprite2D
var _style: String = "drumstick"


func _ready() -> void:
    var lane: int = note_data.lane
    _sprite = Sprite2D.new()
    _sprite.texture = DrumGraphics.get_note_texture(lane)
    _sprite.modulate = _get_color_for_lane(lane)
    _sprite.centered = true

    var total_lanes: int = 8
    if lane_ref and lane_ref.highway_ref:
        total_lanes = lane_ref.highway_ref.lane_nodes.size()
    var target_width: float = get_viewport_rect().size.x / float(total_lanes) * 0.75
    var tex_w: float = _sprite.texture.get_width()
    if tex_w > 0:
        _sprite.scale = Vector2(target_width / tex_w, target_width / tex_w)

    add_child(_sprite)


func update_position(current_time: float) -> void:
    if not lane_ref:
        return
    var highway: Node = lane_ref.highway_ref
    var pos: Vector2 = highway.call("note_position",
        note_data.tick, lane_ref.lane_index, note_data.time, current_time
    )
    global_position = pos


func _on_hit() -> void:
    _hit = true
    _sprite.modulate = Color.WHITE


func _on_miss() -> void:
    _missed = true
    _sprite.modulate = Color(0.5, 0.5, 0.5, 0.3)


static func _get_color_for_lane(lane: int) -> Color:
    match lane:
        0: return Color(0.9, 0.8, 0.2)
        1: return Color(1.0, 0.6, 0.0)
        2: return Color(0.8, 0.2, 0.2)
        3: return Color(0.6, 0.4, 0.8)
        4: return Color(0.2, 0.7, 0.9)
        5: return Color(0.2, 0.9, 0.5)
        6: return Color(0.9, 0.3, 0.6)
        7: return Color(0.5, 0.8, 0.3)
        _: return Color.WHITE
