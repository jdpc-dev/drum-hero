class_name Multiplier
extends Label


func _ready() -> void:
    ScoreManager.multiplier_changed.connect(_on_multiplier_changed)
    text = ""


func _on_multiplier_changed(new_mult: int) -> void:
    if new_mult > 1:
        text = "x" + str(new_mult)
    else:
        text = ""
