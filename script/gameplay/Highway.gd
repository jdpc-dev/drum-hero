class_name Highway
extends Node2D

var lane_nodes: Array = []

@export var lane_scene: PackedScene
@export var hit_line_scene: PackedScene

var note_speed: float = 1.0
var active_lane_count: int = 8

var hit_line_y: float = 0.0
var spawn_y: float = 0.0
var highway_top_y: float = 0.0
var highway_bottom_y: float = 0.0

var _screen_size: Vector2
var _bg_sprite: Sprite2D
var _label_settings: LabelSettings


func _ready() -> void:
    _screen_size = get_viewport_rect().size
    highway_top_y = _screen_size.y * 0.05
    highway_bottom_y = _screen_size.y * 0.72
    hit_line_y = highway_bottom_y
    spawn_y = highway_top_y

    _label_settings = preload("res://asset/fonts/label_settings.tres")

    _add_background()
    _build_lanes()


func _add_background() -> void:
    _bg_sprite = Sprite2D.new()
    _bg_sprite.texture = preload("res://asset/textures/highway_bg.png")
    _bg_sprite.centered = false
    var bg_h: float = highway_bottom_y - highway_top_y
    _bg_sprite.position = Vector2(0, highway_top_y)
    _bg_sprite.scale = Vector2(_screen_size.x / _bg_sprite.texture.get_width(), bg_h / _bg_sprite.texture.get_height())
    _bg_sprite.z_index = -1
    add_child(_bg_sprite)


func _build_lanes() -> void:
    for child in get_children():
        if child is Lane:
            child.queue_free()
    lane_nodes.clear()

    var lane_order: Array[int] = _get_lane_order()

    for i in range(lane_order.size()):
        var lane := lane_scene.instantiate() as Lane
        lane.lane_index = lane_order[i]
        lane.highway_ref = self
        add_child(lane)
        lane_nodes.append(lane)

    var hit_line := hit_line_scene.instantiate() as HitLine
    add_child(hit_line)
    hit_line.setup(self)

    _add_lane_labels()


func _add_lane_labels() -> void:
    var labels_y: float = highway_bottom_y + _screen_size.y * 0.02
    var count: int = lane_nodes.size()
    var lane_w: float = _screen_size.x / float(count)
    var lane_colors: Array[Color] = _get_lane_colors()

    for i in range(count):
        var lane_idx: int = lane_nodes[i].lane_index
        var label := Label.new()
        label.text = DrumGraphics.LANE_LABELS[lane_idx]
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        label.label_settings = _label_settings
        label.add_theme_font_size_override("font_size", 16)
        label.add_theme_color_override("font_color", lane_colors[lane_idx])
        label.position = Vector2(lane_w * i, labels_y)
        label.size = Vector2(lane_w, _screen_size.y * 0.05)
        add_child(label)


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
    var upcoming: Array = ChartParser.get_notes_in_range(time - 0.1, time + 2.0)

    for note_data in upcoming:
        var lane_idx: int = note_data.lane
        for lane in lane_nodes:
            if lane.lane_index == lane_idx:
                lane.queue_note(note_data)
                break

    for lane in lane_nodes:
        lane.update_notes(delta, time)


func restart() -> void:
    for lane in lane_nodes:
        lane.clear()


func get_lane_screen_rect(lane_index: int) -> Rect2:
    var total_lanes: int = lane_nodes.size()
    var lane_w: float = _screen_size.x / float(total_lanes)
    return Rect2(lane_w * lane_index, highway_top_y, lane_w, highway_bottom_y - highway_top_y)


func note_position(tick: int, lane_index: int, note_time: float, current_time: float) -> Vector2:
    var total_lanes: int = lane_nodes.size()
    var lane_w: float = _screen_size.x / float(total_lanes)
    var x: float = lane_w * lane_index + lane_w * 0.5

    var time_ahead: float = note_time - current_time
    var scroll_distance: float = (_screen_size.y * 0.55) * note_speed
    var y_offset: float = (time_ahead * scroll_distance) / 2.0
    var y: float = hit_line_y - y_offset

    return Vector2(x, y)
