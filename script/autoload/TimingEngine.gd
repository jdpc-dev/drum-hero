extends Node

var audio_position: float = 0.0
var chart_duration: float = 0.0
var audio_offset: float = 0.0
var _paused: bool = false
var _has_audio: bool = false
# The clock runs between start() and stop(). It starts active by default so time
# also flows before the first song (menu, previews).
var _running: bool = true
# The end of the song is announced only once: without this guard song_ended
# would be re-emitted every frame while audio_position >= chart_duration.
var _finished: bool = false
# The base stream reached its natural end. It stops being authoritative: if the
# chart still has notes, the clock keeps running with delta (a truncated or
# preview-length audio file must not cut the run short). If chart_duration is 0
# or already covered, the end is announced immediately.
var _audio_exhausted: bool = false

signal time_updated(time_sec: float)
signal song_ended()


func _process(delta: float) -> void:
    if _paused or not _running or _finished:
        return
    if _has_audio and not _audio_exhausted and AudioManager.is_playing():
        # Audio is authoritative while it exists: the clock position is the
        # stream's. The end is detected with the base stem's finished signal,
        # not by reading the position: when the stream ends Godot resets
        # get_playback_position() to 0, so on the final frame the position
        # looks like that of a player that has not started yet.
        if AudioManager.is_stream_finished():
            _audio_exhausted = true
            # The audio stops being authoritative here. Release the players so
            # pause/resume cannot rewind them to the start, and keep the clock
            # at the real end of the audio before continuing with delta.
            AudioManager.stop()
            audio_position = maxf(audio_position, AudioManager.get_length() - audio_offset)
            if chart_duration > 0.0 and audio_position < chart_duration:
                audio_position += delta
        else:
            audio_position = AudioManager.get_position() - audio_offset
    else:
        audio_position += delta
    if chart_duration > 0.0 and audio_position >= chart_duration:
        # Clamp before emitting: the last time_updated carries the exact
        # end-of-song value, which is what leaves the time bar at 100 %.
        audio_position = chart_duration
    time_updated.emit(audio_position)
    if chart_duration > 0.0:
        if audio_position >= chart_duration:
            _finish()
    elif _audio_exhausted:
        # There is no chart duration to wait for: the end of the audio is the
        # end of the song.
        _finish()


func _finish() -> void:
    if _finished:
        return
    _finished = true
    song_ended.emit()


func start(duration: float, offset: float = 0.0) -> void:
    chart_duration = duration
    # offset = song delay (song.ini "delay" / chart Offset).
    # The player's global calibration is added to it, in the same direction:
    # positive -> notes are judged later than they sound.
    audio_offset = offset + SettingsManager.audio_offset_ms / 1000.0
    audio_position = max(0.0, -audio_offset)
    _paused = false
    _running = true
    _finished = false
    _audio_exhausted = false
    _has_audio = AudioManager.loaded_any()
    AudioManager.play()


func pause() -> void:
    _paused = true
    # Once the audio is over there is nothing to pause. Calling pause()/resume()
    # anyway would make AudioManager remember a position of 0 and restart the
    # stream from the beginning when the run is resumed.
    if not _audio_exhausted:
        AudioManager.pause()


func resume() -> void:
    _paused = false
    if not _audio_exhausted:
        AudioManager.resume()


# Freezes the clock: without this the clock kept adding delta (there is neither
# _paused nor audio playing) and the time bar filled up again from zero below
# the results screen.
#
# audio_position is deliberately NOT reset to zero: it stays pinned at the
# end-of-song value so get_time() keeps returning the actual end. start() is
# what resets the clock for the next song.
func stop() -> void:
    _paused = false
    _running = false
    audio_offset = 0.0
    AudioManager.stop()


func is_paused() -> bool:
    return _paused


func get_time() -> float:
    return audio_position
