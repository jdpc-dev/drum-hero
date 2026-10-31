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

# Capas de velocidad por pad. La mayoria usa los sets de Clone Hero: tom 3,
# hi-hat, crash y ride con 5 capas x 3 variaciones; kick y snare con 6 x 3. Los
# toms 1-2 usan el motor de YARG (3 capas), y un pad fuera del mapa conserva el
# comportamiento antiguo de 3 capas con variacion aleatoria.
const PAD_LAYER_COUNTS: Dictionary = {3: 5, 4: 5, 5: 5, 6: 5, 7: 6, 8: 6}
const DEFAULT_LAYER_COUNT: int = 3

# Pads que usan el motor de YARG: 3 capas con umbrales y volumen escalado por
# golpe, en vez de la formula de capas de Clone Hero.
const YARG_PADS: Array = [0, 2]
const YARG_VELOCITY_THRESHOLD: float = 0.35
const YARG_ACCENT_THRESHOLD: float = 0.7  # YARG: VelocityThreshold * 2

var _samples: Dictionary = {}
var _player_pool: Array[AudioStreamPlayer] = []
var _player_index: int = 0
var _last_variation: Dictionary = {}
# Round-robin de Clone Hero: "pad:capa" -> ultima variacion usada (arranca en -1).
var _layer_cursor: Dictionary = {}

const POOL_SIZE: int = 16


func _ready() -> void:
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "DrumSfxPlayer_" + str(i)
		p.bus = "SFX"
		add_child(p)
		_player_pool.append(p)
	_apply_sfx_volume()
	# Los sets de Clone Hero y YARG tienen varios samples por capa y son las
	# piezas donde mas duele un hitch: se precargan para que el primer golpe no
	# cargue todos los archivos en el frame.
	for pad in PAD_LAYER_COUNTS:
		_load_pad_samples(pad)
	for pad in YARG_PADS:
		_load_pad_samples(pad)


func _apply_sfx_volume() -> void:
	var idx: int = AudioServer.get_bus_index("SFX")
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(SettingsManager.sfx_volume))


func _load_all_samples() -> void:
	for pad in range(9):
		_samples[pad] = {}
		for vel in range(_layer_count(pad)):
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
	# falta bloquea el hilo principal ~0.2s por intento, y antes el kick tenia
	# capas sin .opus que congelaban el primer golpe en PC.
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
	for vel in range(_layer_count(pad)):
		_samples[pad][vel] = []
		for smp in range(3):
			var stream: AudioStream = _load_sfx_file(pad, vel, smp)
			if stream:
				_samples[pad][vel].append(stream)


func _layer_count(pad: int) -> int:
	return int(PAD_LAYER_COUNTS.get(pad, DEFAULT_LAYER_COUNT))


# Mismo mapeo que Clone Hero: divisor = 127 / capas (division entera) y la
# capa se satura a la ultima. Con 6 capas -> 0-20, 21-41, 42-62, 63-83,
# 84-104 y 105-127.
func velocity_to_layer(velocity: int, layer_count: int) -> int:
	if layer_count <= 1:
		return 0
	var divisor: int = maxi(1, floori(127.0 / float(layer_count)))
	return mini(floori(float(velocity) / float(divisor)), layer_count - 1)


# Motor de YARG para el tom 1: la velocidad MIDI se normaliza a 0-1 y se
# compara con sus umbrales (0.35 y 0.7). Devuelve la capa y el volumen lineal
# con el que YARG escala el sample (no solo elige la capa).
func yarg_layer_and_volume(velocity: int) -> Dictionary:
	var v: float = clampf(float(velocity) / 127.0, 0.0, 1.0)
	if v > YARG_ACCENT_THRESHOLD:
		return {"layer": 2, "volume": v}
	if v > YARG_VELOCITY_THRESHOLD:
		return {"layer": 1, "volume": v / YARG_ACCENT_THRESHOLD}
	return {"layer": 0, "volume": v / YARG_VELOCITY_THRESHOLD}


# Si faltara una capa, usa la inferior no vacia mas cercana (y si no, la
# superior) para no quedarse en silencio.
func _resolve_layer(pad: int, layer: int, layer_count: int) -> int:
	var pad_samples: Dictionary = _samples.get(pad, {})
	for i in range(layer, -1, -1):
		if not pad_samples.get(i, []).is_empty():
			return i
	for i in range(layer + 1, layer_count):
		if not pad_samples.get(i, []).is_empty():
			return i
	return -1


func play_for_lane(lane_index: int, velocity: int = -1) -> void:
	var pad: int = LANE_TO_PAD.get(lane_index, -1)
	if pad < 0:
		return
	_load_pad_samples(pad)

	if velocity < 0:
		velocity = SettingsManager.default_sample_velocity
	velocity = clampi(velocity, 0, 127)

	var layer_count: int = _layer_count(pad)
	var is_yarg: bool = YARG_PADS.has(pad)
	var volume: float = 1.0
	var target_layer: int
	if is_yarg:
		var yarg_info: Dictionary = yarg_layer_and_volume(velocity)
		target_layer = int(yarg_info.layer)
		volume = float(yarg_info.volume)
	else:
		target_layer = velocity_to_layer(velocity, layer_count)
	var layer: int = _resolve_layer(pad, target_layer, layer_count)
	if layer < 0:
		return
	var vel_samples: Array = _samples.get(pad, {}).get(layer, [])
	if vel_samples.is_empty():
		return

	var round_robin: bool = PAD_LAYER_COUNTS.has(pad) or is_yarg
	var variation: int = 0
	if round_robin:
		# Clone Hero rota por capa; YARG usa un unico cursor por pieza, asi que
		# la rotacion continua aunque cambie la capa de velocidad.
		var key: String = (str(pad) + ":yarg") if is_yarg else (str(pad) + ":" + str(layer))
		var cursor: int = _layer_cursor.get(key, -1)
		cursor = (cursor + 1) % vel_samples.size()
		_layer_cursor[key] = cursor
		variation = cursor
	else:
		# Resto de pads: random sin repetir, como antes.
		variation = randi() % vel_samples.size()
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
	# Clone Hero y YARG no desafinan: la variacion sale del round-robin. En el
	# resto de pads se mantiene el pitch random de siempre.
	player.pitch_scale = 1.0 if round_robin else 1.0 + (randf() - 0.5) * 0.08
	# YARG ajusta el volumen segun la velocidad; el resto suena a nivel nominal.
	player.volume_db = linear_to_db(maxf(volume, 0.0001)) if is_yarg else 0.0
	player.play()


func _get_player() -> AudioStreamPlayer:
	var p: AudioStreamPlayer = _player_pool[_player_index]
	_player_index = (_player_index + 1) % POOL_SIZE
	return p
