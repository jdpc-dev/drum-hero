extends Node

const SFX_DIR: String = "res://asset/drumSfx/"

const LANE_TO_PAD: Dictionary = {
	0: 4,  # HH Closed -> pad4
	1: 6,  # Crash -> pad6
	2: 7,  # Snare -> pad7
	3: 8,  # Kick -> pad8
	4: 0,  # Tom 1 -> pad0
	5: 2,  # Tom 2 -> pad2
	6: 3,  # Tom 3 -> pad3
	7: 5,  # Ride -> pad5
}

var _samples: Dictionary = {}
var _player_pool: Array[AudioStreamPlayer] = []
var _player_index: int = 0
var _last_variation: Dictionary = {}

const POOL_SIZE: int = 16


func _ready() -> void:
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "DrumSfxPlayer_" + str(i)
		p.bus = "SFX"
		add_child(p)
		_player_pool.append(p)
	_apply_sfx_volume()


func _apply_sfx_volume() -> void:
	var idx: int = AudioServer.get_bus_index("SFX")
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(SettingsManager.sfx_volume))


func _load_all_samples() -> void:
	for pad in range(9):
		_samples[pad] = {}
		for vel in range(3):
			_samples[pad][vel] = []
			for smp in range(3):
				var stream: AudioStream = _load_sfx_file(pad, vel, smp)
				if stream:
					_samples[pad][vel].append(stream)


func _load_sfx_file(pad: int, vel: int, smp: int) -> AudioStream:
	var name_base: String = "vel" + str(vel) + "pad" + str(pad) + "smp" + str(smp)

	var ogg_path: String = SFX_DIR + name_base + ".ogg"
	if ResourceLoader.exists(ogg_path):
		return load(ogg_path)
	var raw_ogg: PackedByteArray = FileHelper.read_file(ogg_path)
	if not raw_ogg.is_empty():
		var stream := AudioStreamOggVorbis.new()
		stream.data = raw_ogg
		if stream:
			return stream

	var opus_path: String = SFX_DIR + name_base + ".opus"
	if ResourceLoader.exists(opus_path):
		return load(opus_path)
	# Solo se decodifica si el .opus existe: lanzar ffmpeg por un archivo que
	# falta bloquea el hilo principal ~0.2s por intento. El kick (pad8) solo
	# trae samples vel2, asi que el primer KICK en PC intentaba decodificar seis
	# .opus inexistentes y congelaba el juego alrededor de un segundo.
	if OS.get_name() != "Android" and FileHelper.file_exists(opus_path):
		return _decode_opus_to_wav(opus_path)

	return null


func _decode_opus_to_wav(path: String) -> AudioStream:
	var fs_path: String = ProjectSettings.globalize_path(path)
	var tmp_name: String = "tmp_drumsfx_" + path.get_file().md5_text() + ".raw"
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
	DirAccess.remove_absolute(tmp_path)
	if raw_pcm.is_empty():
		return null
	var wav := AudioStreamWAV.new()
	wav.data = raw_pcm
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 48000
	wav.stereo = true
	return wav


func _load_pad_samples(pad: int) -> void:
	if _samples.has(pad):
		return
	_samples[pad] = {}
	for vel in range(3):
		_samples[pad][vel] = []
		for smp in range(3):
			var stream: AudioStream = _load_sfx_file(pad, vel, smp)
			if stream:
				_samples[pad][vel].append(stream)


func play_for_lane(lane_index: int, velocity: int = 2) -> void:
	var pad: int = LANE_TO_PAD.get(lane_index, -1)
	if pad < 0:
		return
	_load_pad_samples(pad)
	var vel_samples: Array = _samples.get(pad, {}).get(velocity, [])
	if vel_samples.is_empty():
		return

	var variation: int = randi() % vel_samples.size()
	if _last_variation.has(pad):
		var last: int = _last_variation[pad]
		if vel_samples.size() > 1:
			while variation == last:
				variation = randi() % vel_samples.size()
	_last_variation[pad] = variation

	var stream: AudioStream = vel_samples[variation]
	if not stream:
		return

	var player: AudioStreamPlayer = _get_player()
	player.stream = stream
	player.pitch_scale = 1.0 + (randf() - 0.5) * 0.08
	player.play()


func _get_player() -> AudioStreamPlayer:
	var p: AudioStreamPlayer = _player_pool[_player_index]
	_player_index = (_player_index + 1) % POOL_SIZE
	return p
