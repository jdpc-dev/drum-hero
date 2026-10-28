class_name AccuracyFeedback
extends Label

var _fade_tween: Tween


func _ready() -> void:
    modulate.a = 0.0
    GameManager.hit_registered.connect(_on_hit)


func _on_hit(accuracy: int) -> void:
    text = Judgement.accuracy_name(accuracy)
    _animate()


func _animate() -> void:
    if _fade_tween and _fade_tween.is_running():
        _fade_tween.kill()
    modulate.a = 1.0
    _fade_tween = create_tween()
    _fade_tween.tween_interval(0.3)
    _fade_tween.tween_property(self, "modulate:a", 0.0, 0.4)
