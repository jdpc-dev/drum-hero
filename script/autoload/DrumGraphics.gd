extends Node

const TEXTURE_SIZE: int = 128
const LANE_LABELS: PackedStringArray = [
    "HH", "CRASH", "SNARE", "KICK", "TOM 1", "TOM 2", "TOM 3", "RIDE"
]
const LANE_FULL_LABELS: PackedStringArray = [
    "HH CLOSED & OPEN", "CRASH", "SNARE", "KICK", "TOM 1", "TOM 2", "TOM 3", "RIDE"
]

var _note_textures: Dictionary = {}
var _hit_line_textures: Dictionary = {}


func _ready() -> void:
    call_deferred("_generate_all")


func _generate_all() -> void:
    for i in 8:
        _note_textures[i] = _generate_for_lane(i, "_draw_note")
        _hit_line_textures[i] = _generate_for_lane(i, "_draw_hit_line")


func get_note_texture(lane_index: int) -> Texture2D:
    if _note_textures.is_empty():
        _generate_all()
    return _note_textures.get(lane_index, _note_textures[0])


func get_hit_line_texture(lane_index: int) -> Texture2D:
    if _hit_line_textures.is_empty():
        _generate_all()
    return _hit_line_textures.get(lane_index, _hit_line_textures[0])


func _generate_for_lane(lane: int, draw_method: String) -> ImageTexture:
    var img := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
    img.fill(Color.TRANSPARENT)
    var s: float = float(TEXTURE_SIZE)
    match lane:
        0: call(draw_method, img, s, "double_cymbal")
        1: call(draw_method, img, s, "cymbal")
        2: call(draw_method, img, s, "drumstick")
        3: call(draw_method, img, s, "pedal")
        4: call(draw_method, img, s, "drumstick")
        5: call(draw_method, img, s, "drumstick")
        6: call(draw_method, img, s, "drumstick")
        7: call(draw_method, img, s, "cymbal")
    return ImageTexture.create_from_image(img)


func _draw_note(img: Image, s: float, variant: String) -> void:
    match variant:
        "double_cymbal":
            _fill_circle(img, s * 0.35, s * 0.45, s * 0.28, Color(0.95, 0.75, 0.1))
            _fill_circle(img, s * 0.65, s * 0.45, s * 0.28, Color(0.85, 0.65, 0.15))
            _fill_circle(img, s * 0.35, s * 0.45, s * 0.08, Color(0.6, 0.5, 0.1))
            _fill_circle(img, s * 0.65, s * 0.45, s * 0.08, Color(0.6, 0.5, 0.1))
            _fill_rect(img, Rect2(s * 0.48, s * 0.65, s * 0.04, s * 0.2), Color(0.55, 0.55, 0.55))
        "cymbal":
            _fill_circle(img, s * 0.5, s * 0.42, s * 0.35, Color(0.95, 0.75, 0.1))
            _fill_circle(img, s * 0.5, s * 0.42, s * 0.1, Color(0.8, 0.6, 0.05))
            _fill_rect(img, Rect2(s * 0.47, s * 0.68, s * 0.06, s * 0.18), Color(0.55, 0.55, 0.55))
        "drumstick":
            var cx: float = s * 0.5
            _fill_round_rect(img, Rect2(cx - s * 0.08, s * 0.12, s * 0.16, s * 0.5), s * 0.04, Color(0.85, 0.75, 0.55))
            _fill_circle(img, cx, s * 0.12, s * 0.09, Color(0.92, 0.82, 0.4))
            _fill_rect(img, Rect2(cx - s * 0.03, s * 0.62, s * 0.06, s * 0.15), Color(0.35, 0.3, 0.25, 0.4))
        "pedal":
            _fill_round_rect(img, Rect2(s * 0.2, s * 0.3, s * 0.6, s * 0.35), s * 0.06, Color(0.35, 0.35, 0.35))
            _fill_round_rect(img, Rect2(s * 0.25, s * 0.32, s * 0.5, s * 0.28), s * 0.04, Color(0.5, 0.5, 0.5))
            _fill_circle(img, s * 0.2, s * 0.62, s * 0.05, Color(0.65, 0.65, 0.65))
            _fill_circle(img, s * 0.8, s * 0.62, s * 0.05, Color(0.65, 0.65, 0.65))
            _fill_rect(img, Rect2(s * 0.42, s * 0.15, s * 0.16, s * 0.18), Color(0.4, 0.4, 0.4))
            _fill_circle(img, s * 0.5, s * 0.15, s * 0.04, Color(0.7, 0.7, 0.7))


func _draw_hit_line(img: Image, s: float, variant: String) -> void:
    var cy: float = s * 0.5
    match variant:
        "double_cymbal":
            _draw_hit_line_base(img, s, cy)
            _fill_circle(img, s * 0.3, cy, s * 0.14, Color(0.95, 0.75, 0.1, 0.7))
            _fill_circle(img, s * 0.7, cy, s * 0.14, Color(0.85, 0.65, 0.15, 0.7))
            _fill_circle(img, s * 0.3, cy, s * 0.04, Color(0.6, 0.5, 0.1))
            _fill_circle(img, s * 0.7, cy, s * 0.04, Color(0.6, 0.5, 0.1))
        "cymbal":
            _draw_hit_line_base(img, s, cy)
            _fill_circle(img, s * 0.5, cy, s * 0.18, Color(0.95, 0.75, 0.1, 0.7))
            _fill_circle(img, s * 0.5, cy, s * 0.05, Color(0.8, 0.6, 0.05))
        "drumstick":
            _draw_hit_line_base(img, s, cy)
            _fill_round_rect(img, Rect2(s * 0.38, cy - s * 0.14, s * 0.24, s * 0.28), s * 0.04, Color(0.85, 0.75, 0.55, 0.7))
            _fill_circle(img, s * 0.5, cy - s * 0.14, s * 0.06, Color(0.92, 0.82, 0.4))
        "pedal":
            _draw_hit_line_base(img, s, cy)
            _fill_round_rect(img, Rect2(s * 0.25, cy - s * 0.12, s * 0.5, s * 0.24), s * 0.04, Color(0.45, 0.45, 0.45, 0.7))


func _draw_hit_line_base(img: Image, s: float, cy: float) -> void:
    _fill_rect(img, Rect2(0, cy - s * 0.02, s, s * 0.04), Color(1, 1, 1, 0.5))
    _fill_rect(img, Rect2(0, cy - s * 0.015, s, s * 0.03), Color(1, 0.95, 0.7, 0.3))


static func _fill_circle(img: Image, cx: float, cy: float, r: float, color: Color) -> void:
    var min_x: int = maxi(0, int(floor(cx - r)))
    var max_x: int = mini(img.get_width() - 1, int(ceil(cx + r)))
    var min_y: int = maxi(0, int(floor(cy - r)))
    var max_y: int = mini(img.get_height() - 1, int(ceil(cy + r)))
    var rr: float = r * r
    for y in range(min_y, max_y + 1):
        for x in range(min_x, max_x + 1):
            var dx: float = float(x) + 0.5 - cx
            var dy: float = float(y) + 0.5 - cy
            if dx * dx + dy * dy <= rr:
                img.set_pixel(x, y, color)


static func _fill_rect(img: Image, rect: Rect2, color: Color) -> void:
    var min_x: int = maxi(0, int(floor(rect.position.x)))
    var max_x: int = mini(img.get_width() - 1, int(ceil(rect.position.x + rect.size.x)) - 1)
    var min_y: int = maxi(0, int(floor(rect.position.y)))
    var max_y: int = mini(img.get_height() - 1, int(ceil(rect.position.y + rect.size.y)) - 1)
    for y in range(min_y, max_y + 1):
        for x in range(min_x, max_x + 1):
            img.set_pixel(x, y, color)


static func _fill_round_rect(img: Image, rect: Rect2, corner_r: float, color: Color) -> void:
    var min_x: int = maxi(0, int(floor(rect.position.x)))
    var max_x: int = mini(img.get_width() - 1, int(ceil(rect.position.x + rect.size.x)) - 1)
    var min_y: int = maxi(0, int(floor(rect.position.y)))
    var max_y: int = mini(img.get_height() - 1, int(ceil(rect.position.y + rect.size.y)) - 1)
    var r2: float = corner_r * corner_r
    for y in range(min_y, max_y + 1):
        for x in range(min_x, max_x + 1):
            var px: float = float(x) + 0.5
            var py: float = float(y) + 0.5
            var in_rect: bool = true
            if px < rect.position.x + corner_r:
                if py < rect.position.y + corner_r:
                    in_rect = (px - rect.position.x - corner_r) * (px - rect.position.x - corner_r) + (py - rect.position.y - corner_r) * (py - rect.position.y - corner_r) <= r2
                elif py > rect.end.y - corner_r:
                    in_rect = (px - rect.position.x - corner_r) * (px - rect.position.x - corner_r) + (py - rect.end.y + corner_r) * (py - rect.end.y + corner_r) <= r2
            elif px > rect.end.x - corner_r:
                if py < rect.position.y + corner_r:
                    in_rect = (px - rect.end.x + corner_r) * (px - rect.end.x + corner_r) + (py - rect.position.y - corner_r) * (py - rect.position.y - corner_r) <= r2
                elif py > rect.end.y - corner_r:
                    in_rect = (px - rect.end.x + corner_r) * (px - rect.end.x + corner_r) + (py - rect.end.y + corner_r) * (py - rect.end.y + corner_r) <= r2
            if in_rect:
                img.set_pixel(x, y, color)
