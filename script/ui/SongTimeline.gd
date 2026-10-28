class_name SongTimeline
extends TextureProgressBar


func _ready() -> void:
    TimingEngine.time_updated.connect(_on_time_updated)
    max_value = 1.0
    value = 0.0


func _on_time_updated(time_sec: float) -> void:
    if ChartParser.get_duration_seconds() > 0.0:
        value = time_sec / ChartParser.get_duration_seconds()
