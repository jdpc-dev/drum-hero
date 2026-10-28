class_name HitLine
extends Node2D

var _screen_size: Vector2
var _lane_sprites: Array[Sprite2D] = []


func setup(highway: Node) -> void:
    _screen_size = get_viewport_rect().size
    var line_y: float = _screen_size.y * 0.72
    position.y = line_y

    var lane_nodes: Array = highway.lane_nodes
    var count: int = lane_nodes.size()
    var lane_w: float = _screen_size.x / float(count)

    for i in range(count):
        var lane_idx: int = lane_nodes[i].lane_index
        var sprite := Sprite2D.new()
        sprite.texture = DrumGraphics.get_hit_line_texture(lane_idx)
        sprite.centered = false
        sprite.position = Vector2(lane_w * i, 0)
        sprite.scale = Vector2(lane_w / sprite.texture.get_width(), 1)
        add_child(sprite)
        _lane_sprites.append(sprite)
