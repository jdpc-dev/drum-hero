extends Node

const SETTINGS_PATH: String = "user://settings.cfg"

var note_speed: float = 1.0
var lane_config: Dictionary = {}

var judgement_perfect_ms: float = 22.5
var judgement_excellent_ms: float = 45.0
var judgement_good_ms: float = 75.0
var judgement_late_ms: float = 100.0
var judgement_early_ms: float = 100.0
var judgement_miss_ms: float = 135.0

var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 1.0

var haptic_sensitivity: float = 1.0
var haptic_enabled: bool = false
var custom_lanes: Array = []
var mirrored: bool = false
var left_handed: bool = false
var screen_shake: bool = false


func _ready() -> void:
    load_settings()


func load_settings() -> void:
    var cfg := ConfigFile.new()
    var err := cfg.load(SETTINGS_PATH)
    if err != OK:
        return

    note_speed = cfg.get_value("gameplay", "note_speed", 1.0)
    judgement_perfect_ms = cfg.get_value("timing", "perfect_ms", 22.5)
    judgement_excellent_ms = cfg.get_value("timing", "excellent_ms", 45.0)
    judgement_good_ms = cfg.get_value("timing", "good_ms", 75.0)
    judgement_late_ms = cfg.get_value("timing", "late_ms", 100.0)
    judgement_early_ms = cfg.get_value("timing", "early_ms", 100.0)
    judgement_miss_ms = cfg.get_value("timing", "miss_ms", 135.0)
    master_volume = cfg.get_value("audio", "master_volume", 1.0)
    sfx_volume = cfg.get_value("audio", "sfx_volume", 1.0)
    music_volume = cfg.get_value("audio", "music_volume", 1.0)
    haptic_sensitivity = cfg.get_value("haptic", "sensitivity", 1.0)
    haptic_enabled = cfg.get_value("haptic", "enabled", false)
    custom_lanes = cfg.get_value("layout", "custom_lanes", [])
    mirrored = cfg.get_value("layout", "mirrored", false)
    left_handed = cfg.get_value("layout", "left_handed", false)
    screen_shake = cfg.get_value("visual", "screen_shake", false)


func save_settings() -> void:
    var cfg := ConfigFile.new()

    cfg.set_value("gameplay", "note_speed", note_speed)
    cfg.set_value("timing", "perfect_ms", judgement_perfect_ms)
    cfg.set_value("timing", "excellent_ms", judgement_excellent_ms)
    cfg.set_value("timing", "good_ms", judgement_good_ms)
    cfg.set_value("timing", "late_ms", judgement_late_ms)
    cfg.set_value("timing", "early_ms", judgement_early_ms)
    cfg.set_value("timing", "miss_ms", judgement_miss_ms)
    cfg.set_value("audio", "master_volume", master_volume)
    cfg.set_value("audio", "sfx_volume", sfx_volume)
    cfg.set_value("audio", "music_volume", music_volume)
    cfg.set_value("haptic", "sensitivity", haptic_sensitivity)
    cfg.set_value("haptic", "enabled", haptic_enabled)
    cfg.set_value("layout", "custom_lanes", custom_lanes)
    cfg.set_value("layout", "mirrored", mirrored)
    cfg.set_value("layout", "left_handed", left_handed)
    cfg.set_value("visual", "screen_shake", screen_shake)

    cfg.save(SETTINGS_PATH)
