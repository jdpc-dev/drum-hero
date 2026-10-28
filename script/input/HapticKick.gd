class_name HapticKick
extends Node

var _hit_detection


func setup(hit_detection) -> void:
    _hit_detection = hit_detection


func _ready() -> void:
    InputManager.kick_detected.connect(_on_kick_detected)


func _on_kick_detected() -> void:
    if GameManager.state != GameManager.GameState.PLAYING:
        return
    if not SettingsManager.haptic_enabled and GameManager.mode != GameManager.GameMode.HAPTIC:
        return
    if _hit_detection:
        _hit_detection.try_kick()
