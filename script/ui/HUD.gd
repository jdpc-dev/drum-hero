class_name HUD
extends CanvasLayer

@onready var score_label: Label = %ScoreLabel
@onready var combo_label: Label = %ComboLabel
@onready var multiplier_label: Label = %MultiplierLabel
var _fps_label: Label


func _ready() -> void:
	ScoreManager.score_changed.connect(_on_score_changed)
	ScoreManager.combo_changed.connect(_on_combo_changed)
	ScoreManager.multiplier_changed.connect(_on_multiplier_changed)
	if SettingsManager.show_fps:
		_ensure_fps_label()
	_apply_padding()


func _process(_delta: float) -> void:
	if SettingsManager.show_fps:
		if _fps_label:
			_fps_label.text = "FPS: %d" % roundi(Engine.get_frames_per_second())
		else:
			_ensure_fps_label()
	elif _fps_label:
		_fps_label.queue_free()
		_fps_label = null


func _ensure_fps_label() -> void:
	if _fps_label:
		return
	_fps_label = Label.new()
	_fps_label.name = "FPSLabel"
	_fps_label.position = Vector2(10, 20)
	_fps_label.add_theme_font_size_override("font_size", 14)
	_fps_label.add_theme_color_override("font_color", Color(0, 1, 0, 0.7))
	add_child(_fps_label)


func _apply_padding() -> void:
	if not SettingsManager.gameplay_padding_enabled:
		return
	var pl: float = SettingsManager.gameplay_padding_left
	var pr: float = SettingsManager.gameplay_padding_right
	var pt: float = SettingsManager.gameplay_padding_top
	if score_label:
		score_label.offset_right -= pr
		score_label.offset_top += pt
	if multiplier_label:
		multiplier_label.offset_left += pl
		multiplier_label.offset_top += pt
	if combo_label:
		combo_label.offset_top += pt
	if has_node("SongTimeline"):
		var timeline: Control = get_node("SongTimeline") as Control
		timeline.offset_left += pl
		timeline.offset_right -= pr
		timeline.offset_top += pt
	if _fps_label:
		_fps_label.position = Vector2(10 + pl, 20 + pt)

func _on_score_changed(new_score: int) -> void:
	if score_label:
		score_label.text = ScoreData.format_score(new_score)

func _on_combo_changed(new_combo: int) -> void:
	if combo_label:
		combo_label.text = str(new_combo) + "x" if new_combo > 0 else ""

func _on_multiplier_changed(new_mult: int) -> void:
	if multiplier_label:
		if new_mult > 1:
			multiplier_label.text = "x" + str(new_mult)
		else:
			multiplier_label.text = ""
