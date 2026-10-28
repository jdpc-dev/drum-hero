class_name ComboCounter
extends Label

var _scale_tween: Tween


func _ready() -> void:
    ScoreManager.combo_changed.connect(_on_combo_changed)
    text = ""


func _on_combo_changed(new_combo: int) -> void:
    if new_combo > 1:
        text = str(new_combo)
        _animate_pop()
    else:
        text = ""


func _animate_pop() -> void:
    if _scale_tween and _scale_tween.is_running():
        _scale_tween.kill()
    scale = Vector2(1.3, 1.3)
    _scale_tween = create_tween()
    _scale_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_OUT)
