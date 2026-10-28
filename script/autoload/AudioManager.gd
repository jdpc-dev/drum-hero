extends Node

class StemInfo:
	var bus: String
	var stream: AudioStream
	var player: AudioStreamPlayer
	var volume: float = 1.0

var _stems: Dictionary = {}
var _master_player: AudioStreamPlayer
var _is_playing: bool = false
# Latch de "el stream base llego a su final". Lo enciende la senal finished del
# player, que solo salta al acabar el stream de forma natural: ni stop() ni la
# pausa interna emiten finished, asi que no hay falsos positivos al pausar,
# reiniciar o cambiar de cancion.
var _stream_finished: bool = false

const STEM_FILES: Dictionary = {
	"song": "song",
	"drums": "drums",
	"bass": "bass",
	"guitar": "guitar",
	"keys": "keys",
	"rhythm": "rhythm",
	"vocals": "vocals",
}

const AUDIO_EXTS = ["ogg", "opus", "wav", "mp3"]

func _ready() -> void:
	_master_player = AudioStreamPlayer.new()
	_master_player.name = "MasterAudio"
	add_child(_master_player)
	_master_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_master_volume()


func _apply_master_volume() -> void:
	var idx: int = AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(SettingsManager.master_volume))


func _apply_music_volume() -> void:
	var idx: int = AudioServer.get_bus_index("Music")
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(SettingsManager.music_volume))


func _load_stem(song_path: String, stem_name: String, stem_base: String, volume_scale: float = 1.0) -> bool:
	var stem_path: String = _find_stem_file(song_path, stem_base)
	if stem_path.is_empty():
		return false
	var stream: AudioStream = _load_audio_stream(stem_path)
	if not stream:
		return false
	var info := StemInfo.new()
	info.stream = stream
	info.player = AudioStreamPlayer.new()
	info.player.stream = stream
	info.player.name = "Stem_" + stem_name
	info.player.bus = "Music"
	if volume_scale < 1.0:
		info.player.volume_db = linear_to_db(volume_scale)
	add_child(info.player)
	info.player.finished.connect(_on_stem_finished.bind(stem_name))
	_stems[stem_name] = info
	return true


func _on_stem_finished(stem_name: String) -> void:
	# El reloj sigue al stream base, asi que su final es el final de la cancion.
	if stem_name == _base_stem_name():
		_stream_finished = true


func load_stems(song_path: String) -> bool:
	_clear_stems()
	var loaded_any: bool = false

	# Always load song.ogg as the base mix (provides full instrumentation)
	loaded_any = _load_stem(song_path, "song", "song") or loaded_any

	# Load individual stems alongside the full mix
	for stem_name in STEM_FILES:
		if stem_name == "song":
			continue
		var stem_base: String = STEM_FILES[stem_name]
		var vol: float = 1.0
		if _load_stem(song_path, stem_name, stem_base, vol):
			loaded_any = true

	# Load multi-layer drum variants (drums_2, drums_3)
	if _stems.has("drums"):
		for i in [2, 3]:
			var vol: float = 1.0
			if _load_stem(song_path, "drums_" + str(i), "drums_" + str(i), vol):
				loaded_any = true

	if loaded_any:
		_apply_music_volume()
	return loaded_any


func _load_audio_stream(path: String) -> AudioStream:
	var ext: String = path.get_extension().to_lower()

	if ext == "opus":
		var stream: AudioStream = _decode_opus_via_ffmpeg(path)
		if stream:
			return stream
		if OS.get_name() == "Android":
			var ogg_path: String = path.get_basename() + ".ogg"
			return _load_audio_stream(ogg_path)

	if ResourceLoader.exists(path):
		var stream: AudioStream = load(path)
		if stream:
			return stream

	if ext == "ogg":
		var stream: AudioStream = AudioStreamOggVorbis.load_from_file(path)
		if stream:
			return stream

	if ext == "opus":
		return null

	var raw_data: PackedByteArray = FileHelper.read_file(path)
	if raw_data.is_empty():
		return null

	match ext:
		"ogg":
			var stream := AudioStreamOggVorbis.new()
			stream.data = raw_data
			return stream

	return null


func _decode_opus_via_ffmpeg(path: String) -> AudioStream:
	if OS.get_name() == "Android":
		return null
	return _decode_to_wav(path)


func _decode_to_wav(path: String) -> AudioStream:
	if OS.get_name() == "Android":
		return null
	var fs_path: String = ProjectSettings.globalize_path(path)
	var tmp_name: String = "tmp_pcm_" + path.get_file().md5_text() + ".raw"
	var tmp_path: String = ProjectSettings.globalize_path("user://" + tmp_name)
	var args: PackedStringArray = [
		"-y", "-i", fs_path,
		"-f", "s16le",
		"-acodec", "pcm_s16le",
		"-ar", "48000",
		"-ac", "2",
		tmp_path
	]
	var exit_code: int = OS.execute("ffmpeg", args, [], true)
	if exit_code != 0:
		return null

	var raw_pcm: PackedByteArray = FileHelper.read_file("user://" + tmp_name)
	if raw_pcm.is_empty():
		return null
	DirAccess.remove_absolute(tmp_path)

	if raw_pcm.is_empty():
		return null

	var wav := AudioStreamWAV.new()
	wav.data = raw_pcm
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 48000
	wav.stereo = true
	return wav


func _find_stem_file(song_path: String, stem_base: String) -> String:
	for ext in AUDIO_EXTS:
		var p: String = song_path.path_join(stem_base + "." + ext)
		if FileHelper.file_exists(p) or ResourceLoader.exists(p):
			return p
	var i: int = 1
	while i <= 9:
		for ext in AUDIO_EXTS:
			var p: String = song_path.path_join(stem_base + "_" + str(i) + "." + ext)
			if FileHelper.file_exists(p) or ResourceLoader.exists(p):
				return p
		i += 1
	return ""


var _pause_positions: Dictionary = {}


func play() -> void:
	if _stems.is_empty():
		return
	_is_playing = true
	_stream_finished = false
	for stem_name in _stems:
		var info: StemInfo = _stems[stem_name]
		info.player.play()


func pause() -> void:
	_pause_positions.clear()
	for stem_name in _stems:
		_pause_positions[stem_name] = _stems[stem_name].player.get_playback_position()
		_stems[stem_name].player.stop()


func resume() -> void:
	if _stems.is_empty():
		return
	_is_playing = true
	for stem_name in _stems:
		var pos: float = _pause_positions.get(stem_name, 0.0)
		_stems[stem_name].player.play(pos)
	_pause_positions.clear()


func stop() -> void:
	_is_playing = false
	_pause_positions.clear()
	for stem_name in _stems:
		_stems[stem_name].player.stop()


# La mezcla base manda; si no existe, el primer stem cargado. Todo el reloj del
# gameplay depende de este valor, asi que is_stream_finished() usa el mismo stem.
func _base_stem_name() -> String:
	if _stems.has("song"):
		return "song"
	var keys: Array = _stems.keys()
	if keys.is_empty():
		return ""
	return keys[0]


func get_position() -> float:
	var info: StemInfo = _stems.get(_base_stem_name())
	if info == null:
		return 0.0
	return info.player.get_playback_position()


# Duracion del stream mas largo (la mezcla base si existe). Se usa para validar
# el chart contra el audio real.
func get_length() -> float:
	var longest: float = 0.0
	for stem_name in _stems:
		var info: StemInfo = _stems[stem_name]
		if info.stream == null:
			continue
		var length: float = info.stream.get_length()
		if length > longest:
			longest = length
	return longest


func set_volume(stem_name: String, vol: float) -> void:

	if _stems.has(stem_name):
		_stems[stem_name].volume = clamp(vol, 0.0, 2.0)
		_stems[stem_name].player.volume_db = linear_to_db(_stems[stem_name].volume)


func set_latency(ms: float) -> void:
	# La latencia de salida real no se puede medir desde el script, asi que no
	# se corrige aqui. La calibracion vive en un solo sitio
	# (SettingsManager.audio_offset_ms) y la aplica TimingEngine; este metodo se
	# conserva como punto de entrada compatible.
	SettingsManager.audio_offset_ms = ms


func _clear_stems() -> void:
	for stem_name in _stems:
		var info: StemInfo = _stems[stem_name]
		if info.player:
			info.player.stop()
			remove_child(info.player)
			info.player.queue_free()
	_stems.clear()
	_stream_finished = false


func is_playing() -> bool:
	return _is_playing


# El stream base dejo de sonar aunque el flag manual siga en true. is_playing()
# responde a play()/pause()/stop() del juego, no al estado real del player: si el
# audio se acaba antes que el chart, el reloj se quedaria clavado.
#
# Se usa la senal finished y no "not player.playing" porque playing tambien es
# false con el player en pausa (stream_paused) y get_playback_position() vuelve
# a 0 justo cuando el stream termina: las dos consultables mienten en el
# instante preciso del fin de cancion.
func is_stream_finished() -> bool:
	return _stream_finished


func loaded_any() -> bool:
	return not _stems.is_empty()
