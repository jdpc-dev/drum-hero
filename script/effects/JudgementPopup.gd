class_name JudgementPopup
extends Node2D

var _label: Label
var _timer: float = 0.0
var _duration: float = 0.6
var _accuracy_names: Dictionary = {
	0: { "text": "PERFECT", "color": Color(1, 0.9, 0.2) },
	1: { "text": "EXCELLENT", "color": Color(0.2, 1, 0.2) },
	2: { "text": "GOOD", "color": Color(0.2, 0.6, 1) },
	3: { "text": "LATE", "color": Color(1, 0.5, 0) },
	4: { "text": "EARLY", "color": Color(1, 0.5, 0) },
	5: { "text": "MISS", "color": Color(1, 0.2, 0.2) },
}

var _label_settings: LabelSettings


func _ready() -> void:
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.position = Vector2(-100, -16)
	_label.size = Vector2(200, 32)
	add_child(_label)

	_label_settings = LabelSettings.new()
	_label_settings.font_size = 28
	_label.label_settings = _label_settings


func show_judgement(accuracy: int) -> void:
	var info: Dictionary = _accuracy_names.get(accuracy, { "text": "", "color": Color.WHITE })
	_label.text = info.text
	_label_settings.font_color = info.color
	_timer = _duration
	modulate.a = 1.0
	scale = Vector2.ONE


func _process(delta: float) -> void:
	if _timer <= 0.0:
		return
	_timer -= delta
	position.y -= 60.0 * delta
	var alpha: float = clampf(_timer / _duration * 2.0, 0.0, 1.0)
	modulate.a = alpha
	scale = Vector2(1.0 + (1.0 - _timer / _duration) * 0.2, 1.0 + (1.0 - _timer / _duration) * 0.2)
	if _timer <= 0.0:
		if get_parent():
			get_parent().remove_child(self)
