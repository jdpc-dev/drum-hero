extends Node

var _particle_pool: Array[Node] = []
var _shockwave_pool: Array[Node] = []
var _judgement_pool: Array[Node] = []

var max_pool_size: int = 16

var _hit_sfx: AudioStreamPlayer
var _miss_sfx: AudioStreamPlayer


func _ready() -> void:
    _hit_sfx = AudioStreamPlayer.new()
    _hit_sfx.stream = _generate_beep(880.0, 0.08)
    _hit_sfx.name = "HitSFX"
    _hit_sfx.volume_db = -6.0
    add_child(_hit_sfx)

    _miss_sfx = AudioStreamPlayer.new()
    _miss_sfx.stream = _generate_beep(220.0, 0.15)
    _miss_sfx.name = "MissSFX"
    _miss_sfx.volume_db = -9.0
    add_child(_miss_sfx)


func play_hit_sfx() -> void:
    if _hit_sfx:
        _hit_sfx.stop()
        _hit_sfx.play()


func play_miss_sfx() -> void:
    if _miss_sfx:
        _miss_sfx.stop()
        _miss_sfx.play()


static func _generate_beep(freq: float, duration: float) -> AudioStreamWAV:
    var sample_rate: int = 22050
    var num_samples: int = int(sample_rate * duration)
    var data: PackedByteArray = PackedByteArray()
    data.resize(num_samples * 2)

    for i in range(num_samples):
        var t: float = float(i) / float(sample_rate)
        var envelope: float = 1.0 - (float(i) / float(num_samples))
        var sample: float = sin(2.0 * PI * freq * t) * envelope * 0.5
        var s16: int = int(clamp(sample * 32767.0, -32768.0, 32767.0))
        data.encode_s16(i * 2, s16)

    var wav := AudioStreamWAV.new()
    wav.data = data
    wav.format = AudioStreamWAV.FORMAT_16_BITS
    wav.mix_rate = sample_rate
    wav.stereo = false
    return wav


func trigger_particle_burst(position: Vector2, color: Color, parent: Node) -> void:
    var burst: Node = _get_from_pool(_particle_pool, preload("res://scene/UI/Effects/ParticleBurst.tscn"))
    if burst:
        parent.add_child(burst)
        burst.global_position = position
        burst.call("play", color)


func trigger_shockwave(position: Vector2, parent: Node) -> void:
    var shock: Node = _get_from_pool(_shockwave_pool, preload("res://scene/UI/Effects/Shockwave.tscn"))
    if shock:
        parent.add_child(shock)
        shock.global_position = position
        shock.call("play")


func show_judgement(accuracy: int, position: Vector2, parent: Node) -> void:
    var popup: Node = _get_from_pool(_judgement_pool, preload("res://scene/UI/Effects/JudgementPopup.tscn"))
    if popup:
        parent.add_child(popup)
        popup.global_position = position
        popup.call("show_judgement", accuracy)


func _get_from_pool(pool: Array, scene: PackedScene) -> Node:
    for child in pool:
        if not child.is_inside_tree():
            pool.erase(child)
            child.queue_free()
            break
    if pool.size() < max_pool_size:
        var instance := scene.instantiate()
        instance.tree_exited.connect(_on_effect_exited.bind(pool, instance))
        pool.append(instance)
        return instance
    return null


func _on_effect_exited(pool: Array, instance: Node) -> void:
    pool.erase(instance)



