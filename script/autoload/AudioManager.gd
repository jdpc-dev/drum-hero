extends Node

class StemInfo:
	var bus: String
	var stream: AudioStream
	var player: AudioStreamPlayer
	var muted: bool = false
	var solo: bool = false
	var volume: float = 1.0

var _stems: Dictionary = {}
var _master_player: AudioStreamPlayer
var _is_playing: bool = false
var _latency_ms: float = 0.0

const STEM_FILES: Dictionary = {
	"song": "song",
	"drums": "drums",
	"bass": "bass",
	"guitar": "guitar",
	"keys": "keys",
	"vocals": "vocals",
}

const AUDIO_EXTS = ["ogg", "opus", "wav", "mp3"]

func _ready() -> void:
	_master_player = AudioStreamPlayer.new()
	_master_player.name = "MasterAudio"
	add_child(_master_player)
	_master_player.process_mode = Node.PROCESS_MODE_ALWAYS


func load_stems(song_path: String) -> bool:
	_clear_stems()
	var loaded_any: bool = false
	for stem_name in STEM_FILES:
		var stem_path: String = _find_stem_file(song_path, STEM_FILES[stem_name])
		if stem_path.is_empty():
			continue
		var stream: AudioStream = _load_audio_stream(stem_path)
		if stream:
			var info := StemInfo.new()
			info.stream = stream
			info.player = AudioStreamPlayer.new()
			info.player.stream = stream
			info.player.name = "Stem_" + stem_name
			add_child(info.player)
			_stems[stem_name] = info
			loaded_any = true
	return loaded_any


func _load_audio_stream(path: String) -> AudioStream:
	var ext: String = path.get_extension().to_lower()

	if ResourceLoader.exists(path):
		var stream: AudioStream = load(path)
		if stream:
			return stream

	if ext == "opus":
		return _decode_opus_via_ffmpeg(path)

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
	var tmp_path: String = "user://tmp_pcm_" + path.get_file().md5_text() + ".raw"
	var args: PackedStringArray = [
		"-y", "-i", path,
		"-f", "s16le",
		"-acodec", "pcm_s16le",
		"-ar", "44100",
		"-ac", "1",
		tmp_path
	]
	var exit_code: int = OS.execute("ffmpeg", args, [], true)
	if exit_code != 0:
		return null

	var raw_pcm: PackedByteArray = FileHelper.read_file(tmp_path)
	if raw_pcm.is_empty():
		return null
	DirAccess.remove_absolute(tmp_path)

	if raw_pcm.is_empty():
		return null

	var wav := AudioStreamWAV.new()
	wav.data = raw_pcm
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.stereo = false
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


func get_position() -> float:
	if _stems.is_empty():
		return 0.0
	var first_key = _stems.keys()[0]
	return _stems[first_key].player.get_playback_position()


func set_volume(stem_name: String, vol: float) -> void:
	if _stems.has(stem_name):
		_stems[stem_name].volume = clamp(vol, 0.0, 2.0)
		_stems[stem_name].player.volume_db = linear_to_db(_stems[stem_name].volume)


func mute_stem(stem_name: String, muted: bool) -> void:
	if _stems.has(stem_name):
		_stems[stem_name].muted = muted
		_update_mute_solo()


func solo_stem(stem_name: String, soloed: bool) -> void:
	if _stems.has(stem_name):
		_stems[stem_name].solo = soloed
		_update_mute_solo()


func _update_mute_solo() -> void:
	var any_solo: bool = false
	for sn in _stems:
		if _stems[sn].solo:
			any_solo = true
			break
	for sn in _stems:
		var info: StemInfo = _stems[sn]
		if any_solo:
			info.player.volume_db = linear_to_db(info.volume if info.solo else 0.0)
		else:
			info.player.volume_db = linear_to_db(0.0 if info.muted else info.volume)


func set_latency(ms: float) -> void:
	_latency_ms = ms


func duck_drums(amount_db: float = -12.0, duration: float = 0.5) -> void:
	if not _stems.has("drums"):
		return
	var info: StemInfo = _stems["drums"]
	if not info.player.playing:
		return
	var target_db: float = info.player.volume_db + amount_db
	var tween: Tween = create_tween()
	tween.tween_method(_set_drums_volume_db, info.player.volume_db, target_db, 0.05)
	tween.tween_interval(duration)
	tween.tween_method(_set_drums_volume_db, target_db, linear_to_db(info.volume), 0.15)


func _set_drums_volume_db(db: float) -> void:
	if _stems.has("drums"):
		_stems["drums"].player.volume_db = db


func _clear_stems() -> void:
	for stem_name in _stems:
		var info: StemInfo = _stems[stem_name]
		if info.player:
			info.player.stop()
			remove_child(info.player)
			info.player.queue_free()
	_stems.clear()


func is_playing() -> bool:
	return _is_playing


func loaded_any() -> bool:
	return not _stems.is_empty()
