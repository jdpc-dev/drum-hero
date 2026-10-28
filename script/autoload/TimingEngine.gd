extends Node

var audio_position: float = 0.0
var chart_duration: float = 0.0
var audio_offset: float = 0.0
var _paused: bool = false
var _has_audio: bool = false

signal time_updated(time_sec: float)
signal song_ended()


func _process(delta: float) -> void:
    if _paused:
        return
    if _has_audio and AudioManager.is_playing():
        audio_position = AudioManager.get_position() - audio_offset
    else:
        audio_position += delta
    time_updated.emit(audio_position)
    if chart_duration > 0.0 and audio_position >= chart_duration:
        audio_position = chart_duration
        song_ended.emit()


func start(duration: float, offset: float = 0.0) -> void:
    chart_duration = duration
    audio_offset = offset
    audio_position = max(0.0, -offset)
    _paused = false
    _has_audio = AudioManager.loaded_any()
    AudioManager.play()


func pause() -> void:
    _paused = true
    AudioManager.pause()


func resume() -> void:
    _paused = false
    AudioManager.resume()


func stop() -> void:
    _paused = false
    audio_position = 0.0
    audio_offset = 0.0
    AudioManager.stop()


func is_paused() -> bool:
    return _paused


func get_time() -> float:
    return audio_position
