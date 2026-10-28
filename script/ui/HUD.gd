class_name HUD
extends CanvasLayer

@onready var score_label: Label = %ScoreLabel
@onready var combo_label: Label = %ComboLabel
@onready var multiplier_label: Label = %MultiplierLabel
@onready var accuracy_label: Label = %AccuracyLabel
@onready var timeline_bar: TextureProgressBar = %SongTimeline


func _ready() -> void:
    ScoreManager.score_changed.connect(_on_score_changed)
    ScoreManager.combo_changed.connect(_on_combo_changed)
    ScoreManager.multiplier_changed.connect(_on_multiplier_changed)
    TimingEngine.time_updated.connect(_on_time_updated)


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


func _on_time_updated(time_sec: float) -> void:
    if timeline_bar and ChartParser.get_duration_seconds() > 0.0:
        timeline_bar.value = time_sec / ChartParser.get_duration_seconds()


func show_accuracy(accuracy: int) -> void:
    if accuracy_label:
        accuracy_label.text = Judgement.accuracy_name(accuracy)
        var tween: Tween = create_tween()
        tween.tween_property(accuracy_label, "modulate:a", 1.0, 0.0)
        tween.tween_interval(0.3)
        tween.tween_property(accuracy_label, "modulate:a", 0.0, 0.4)
