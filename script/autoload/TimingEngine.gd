extends Node

var audio_position: float = 0.0
var chart_duration: float = 0.0
var audio_offset: float = 0.0
var _paused: bool = false
var _has_audio: bool = false
# El reloj corre entre start() y stop(). Por defecto arranca activo para que el
# tiempo fluya tambien antes de la primera cancion (menu, previsualizaciones).
var _running: bool = true
# El fin de cancion se anuncia una sola vez: sin esta guarda song_ended se
# reemitia en cada frame mientras audio_position >= chart_duration.
var _finished: bool = false
# El stream base llego a su final natural. El reloj se salta al final real del
# audio aunque chart_duration no llegue (o valga 0).
var _audio_exhausted: bool = false

signal time_updated(time_sec: float)
signal song_ended()


func _process(delta: float) -> void:
    if _paused or not _running or _finished:
        return
    if _has_audio and AudioManager.is_playing():
        # El audio manda: la posicion del reloj es la del stream. Si el stream
        # se agota antes de chart_duration (song.ini con duracion equivocada, o
        # audio_offset descuadrado) la cancion termina aqui mismo, porque el
        # final real de la cancion es el final del audio, no el del chart.
        #
        # El final se detecta con la senal finished del stem base, no leyendo la
        # posicion: al acabar el stream Godot reinicia
        # get_playback_position() a 0, asi que en el frame del final la posicion
        # parece la de un player que aun no ha arrancado.
        if AudioManager.is_stream_finished():
            _audio_exhausted = true
            audio_position = chart_duration
        else:
            audio_position = AudioManager.get_position() - audio_offset
    else:
        audio_position += delta
    if chart_duration > 0.0 and audio_position >= chart_duration:
        # Clamp antes de emitir: el ultimo time_updated lleva el valor exacto de
        # fin de cancion, que es lo que deja la barra de tiempo al 100 %.
        audio_position = chart_duration
    time_updated.emit(audio_position)
    if _audio_exhausted or (chart_duration > 0.0 and audio_position >= chart_duration):
        _finish()


func _finish() -> void:
    if _finished:
        return
    _finished = true
    song_ended.emit()


func start(duration: float, offset: float = 0.0) -> void:
    chart_duration = duration
    # offset = delay de la cancion (song.ini "delay" / Offset del chart).
    # Se le suma la calibracion global del jugador, en la misma direccion:
    # positiva -> las notas se juzgan mas tarde de lo que suenan.
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
    AudioManager.pause()


func resume() -> void:
    _paused = false
    AudioManager.resume()


# Congela el reloj: sin esto el reloj seguia sumando delta (no hay ni _paused
# ni audio reproduciendose) y la barra de tiempo volvia a llenarse desde cero
# por debajo de la pantalla de resultados.
#
# audio_position NO se pone a cero a proposito: se queda clavado en el valor del
# fin de cancion para que get_time() siga devolviendo el final real. start() es
# quien reinicia el reloj para la siguiente cancion.
func stop() -> void:
    _paused = false
    _running = false
    audio_offset = 0.0
    AudioManager.stop()


func is_paused() -> bool:
    return _paused


func get_time() -> float:
    return audio_position
