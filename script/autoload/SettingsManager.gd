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
var haptic_activation_threshold: float = 1.0
var haptic_release_threshold: float = 0.5
var haptic_cooldown_duration: float = 0.15
var haptic_min_interval: float = 0.08
var haptic_smoothing_strength: float = 0.4
var haptic_calibration_duration: float = 1.5
var haptic_show_debug: bool = false
var game_mode: int = 0  # GameManager.GameMode.DEFAULT
var custom_lanes: Array = []
var mirrored: bool = false
var left_handed: bool = false
var screen_shake: bool = false
var show_fps: bool = false
var show_hit_feedback: bool = true
var countdown_threshold: float = 5.0
var use_guitar_fallback: bool = false
var show_judgment_areas: bool = false
var preview_volume: float = 0.8
var gameplay_padding_enabled: bool = false
var gameplay_padding_left: float = 40.0
var gameplay_padding_right: float = 40.0
var gameplay_padding_top: float = 40.0
var gameplay_padding_bottom: float = 40.0


func _ready() -> void:
    load_settings()


func load_settings() -> void:
    var cfg := ConfigFile.new()
    var err := cfg.load(SETTINGS_PATH)
    if err != OK:
        if OS.get_name() == "Android":
            gameplay_padding_enabled = true
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
    game_mode = cfg.get_value("gameplay", "mode", 0)
    haptic_sensitivity = cfg.get_value("haptic", "sensitivity", 1.0)
    haptic_enabled = cfg.get_value("haptic", "enabled", false)
    haptic_activation_threshold = cfg.get_value("haptic", "activation_threshold", 1.0)
    haptic_release_threshold = cfg.get_value("haptic", "release_threshold", 0.5)
    haptic_cooldown_duration = cfg.get_value("haptic", "cooldown_duration", 0.15)
    haptic_min_interval = cfg.get_value("haptic", "min_interval", 0.08)
    haptic_smoothing_strength = cfg.get_value("haptic", "smoothing_strength", 0.4)
    haptic_calibration_duration = cfg.get_value("haptic", "calibration_duration", 1.5)
    haptic_show_debug = cfg.get_value("haptic", "show_debug", false)
    custom_lanes = cfg.get_value("layout", "custom_lanes", [])
    mirrored = cfg.get_value("layout", "mirrored", false)
    left_handed = cfg.get_value("layout", "left_handed", false)
    screen_shake = cfg.get_value("visual", "screen_shake", false)
    show_fps = cfg.get_value("visual", "show_fps", false)
    show_hit_feedback = cfg.get_value("visual", "show_hit_feedback", true)
    countdown_threshold = cfg.get_value("gameplay", "countdown_threshold", 5.0)
    use_guitar_fallback = cfg.get_value("gameplay", "use_guitar_fallback", false)
    show_judgment_areas = cfg.get_value("visual", "show_judgment_areas", false)
    preview_volume = cfg.get_value("audio", "preview_volume", 0.8)
    gameplay_padding_enabled = cfg.get_value("experimental", "gameplay_padding_enabled", false)
    gameplay_padding_left = cfg.get_value("experimental", "gameplay_padding_left", cfg.get_value("experimental", "gameplay_padding_amount", 40.0))
    gameplay_padding_right = cfg.get_value("experimental", "gameplay_padding_right", cfg.get_value("experimental", "gameplay_padding_amount", 40.0))
    gameplay_padding_top = cfg.get_value("experimental", "gameplay_padding_top", cfg.get_value("experimental", "gameplay_padding_amount", 40.0))
    gameplay_padding_bottom = cfg.get_value("experimental", "gameplay_padding_bottom", cfg.get_value("experimental", "gameplay_padding_amount", 40.0))


func save_settings() -> void:
    var cfg := ConfigFile.new()

    cfg.set_value("gameplay", "mode", game_mode)
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
    cfg.set_value("haptic", "activation_threshold", haptic_activation_threshold)
    cfg.set_value("haptic", "release_threshold", haptic_release_threshold)
    cfg.set_value("haptic", "cooldown_duration", haptic_cooldown_duration)
    cfg.set_value("haptic", "min_interval", haptic_min_interval)
    cfg.set_value("haptic", "smoothing_strength", haptic_smoothing_strength)
    cfg.set_value("haptic", "calibration_duration", haptic_calibration_duration)
    cfg.set_value("haptic", "show_debug", haptic_show_debug)
    cfg.set_value("layout", "custom_lanes", custom_lanes)
    cfg.set_value("layout", "mirrored", mirrored)
    cfg.set_value("layout", "left_handed", left_handed)
    cfg.set_value("visual", "screen_shake", screen_shake)
    cfg.set_value("visual", "show_fps", show_fps)
    cfg.set_value("visual", "show_hit_feedback", show_hit_feedback)
    cfg.set_value("gameplay", "countdown_threshold", countdown_threshold)
    cfg.set_value("gameplay", "use_guitar_fallback", use_guitar_fallback)
    cfg.set_value("visual", "show_judgment_areas", show_judgment_areas)
    cfg.set_value("audio", "preview_volume", preview_volume)
    cfg.set_value("experimental", "gameplay_padding_enabled", gameplay_padding_enabled)
    cfg.set_value("experimental", "gameplay_padding_left", gameplay_padding_left)
    cfg.set_value("experimental", "gameplay_padding_right", gameplay_padding_right)
    cfg.set_value("experimental", "gameplay_padding_top", gameplay_padding_top)
    cfg.set_value("experimental", "gameplay_padding_bottom", gameplay_padding_bottom)

    cfg.save(SETTINGS_PATH)
