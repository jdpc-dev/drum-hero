extends Node

# Click track for Free Mode. There is no song (and no chart tempo) to follow,
# so the click is synthesized once into a seamless 4/4 loop and played by
# AudioStreamPlayer. Using the player's own loop instead of a Timer/_process
# avoids drift and keeps the pulse sample-accurate.
#
# The first beat of the bar is accented so the player can hear where the bar
# starts. The loop is a plain AudioStream so no asset is needed.

const BPM: float = 120.0
const BEATS_PER_BAR: int = 4
const SAMPLE_RATE: int = 22050
const CLICK_DURATION: float = 0.035
const ACCENT_FREQ: float = 1568.0
const BEAT_FREQ: float = 1046.5
const CLICK_GAIN: float = 0.5

var _player: AudioStreamPlayer
var _running: bool = false


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "MetronomePlayer"
	_player.bus = "SFX"
	_player.stream = _build_loop()
	add_child(_player)


func is_running() -> bool:
	return _running


func get_bpm() -> float:
	return BPM


func start() -> void:
	if _running:
		return
	_running = true
	# Always restart on the downbeat: toggling the metronome on should give
	# the player a clear reference instead of joining mid-bar.
	_player.play(0.0)


func stop() -> void:
	_running = false
	if _player:
		_player.stop()


func _build_loop() -> AudioStreamWAV:
	var beat_samples: int = int(SAMPLE_RATE * 60.0 / BPM)
	var total_samples: int = beat_samples * BEATS_PER_BAR
	var data: PackedByteArray = PackedByteArray()
	data.resize(total_samples * 2)

	var click_samples: int = int(SAMPLE_RATE * CLICK_DURATION)
	for beat in BEATS_PER_BAR:
		var freq: float = ACCENT_FREQ if beat == 0 else BEAT_FREQ
		var start_sample: int = beat * beat_samples
		for i in click_samples:
			var t: float = float(i) / float(SAMPLE_RATE)
			# Squared decay: a short percussive tick with no tail over the next
			# beat, even at fast tempos.
			var envelope: float = pow(1.0 - float(i) / float(click_samples), 2.0)
			var sample: float = sin(TAU * freq * t) * envelope * CLICK_GAIN
			var s16: int = int(clampf(sample * 32767.0, -32768.0, 32767.0))
			data.encode_s16((start_sample + i) * 2, s16)

	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = total_samples
	return wav
