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
# Global audio calibration. Positive = notes are judged later than they sound
# (use if notes feel early). It is added to the per-song delay
# (song.ini / chart Offset).
var audio_offset_ms: float = 0.0

var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 1.0
# MIDI velocity (0-127) for pads that do not report a real one. This is
# Clone Hero's "Default Sample Velocity", which uses 100 by default.
var default_sample_velocity: int = 100

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
var max_fps: int = 60
var show_hit_feedback: bool = true
var countdown_threshold: float = 5.0
var use_guitar_fallback: bool = false
var show_judgment_areas: bool = false
var show_menu_status: bool = false
var preview_volume: float = 0.8
var gameplay_padding_enabled: bool = false
var gameplay_padding_left: float = 75.0   # dp
var gameplay_padding_right: float = 75.0  # dp
var gameplay_padding_top: float = 0.0     # dp
var gameplay_padding_bottom: float = 0.0  # dp

var library_roots: PackedStringArray = PackedStringArray()
var library_preset_downloads: bool = false
var library_preset_documents: bool = false
var library_recursive: bool = true
var library_max_depth: int = 3


func dp_to_godot_px(dp_value: float) -> float:
	if OS.get_name() != "Android":
		return 0.0
	var dpi: int = DisplayServer.screen_get_dpi()
	if dpi <= 0:
		return 0.0
	var density: float = dpi / 160.0
	var physical_px: float = dp_value * density
	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size.x <= 0 or window_size.y <= 0:
		return 0.0
	var viewport_size: Vector2 = get_viewport().size
	var scale: float = min(viewport_size.x / window_size.x, viewport_size.y / window_size.y)
	return physical_px * scale


func _ready() -> void:
	load_settings()
	Engine.max_fps = max_fps


func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK:
		if OS.get_name() == "Android":
			gameplay_padding_enabled = true
			library_preset_downloads = true
			library_preset_documents = true
		return

	note_speed = cfg.get_value("gameplay", "note_speed", 1.0)
	judgement_perfect_ms = cfg.get_value("timing", "perfect_ms", 22.5)
	judgement_excellent_ms = cfg.get_value("timing", "excellent_ms", 45.0)
	judgement_good_ms = cfg.get_value("timing", "good_ms", 75.0)
	judgement_late_ms = cfg.get_value("timing", "late_ms", 100.0)
	judgement_early_ms = cfg.get_value("timing", "early_ms", 100.0)
	judgement_miss_ms = cfg.get_value("timing", "miss_ms", 135.0)
	audio_offset_ms = cfg.get_value("timing", "audio_offset_ms", 0.0)
	master_volume = cfg.get_value("audio", "master_volume", 1.0)
	sfx_volume = cfg.get_value("audio", "sfx_volume", 1.0)
	music_volume = cfg.get_value("audio", "music_volume", 1.0)
	default_sample_velocity = int(cfg.get_value("audio", "default_sample_velocity", 100))
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
	max_fps = cfg.get_value("visual", "max_fps", 60)
	show_hit_feedback = cfg.get_value("visual", "show_hit_feedback", true)
	countdown_threshold = cfg.get_value("gameplay", "countdown_threshold", 5.0)
	use_guitar_fallback = cfg.get_value("gameplay", "use_guitar_fallback", false)
	show_judgment_areas = cfg.get_value("visual", "show_judgment_areas", false)
	show_menu_status = cfg.get_value("visual", "show_menu_status", false)
	preview_volume = cfg.get_value("audio", "preview_volume", 0.8)
	gameplay_padding_enabled = cfg.get_value("experimental", "gameplay_padding_enabled", false)
	gameplay_padding_left = cfg.get_value("experimental", "gameplay_padding_left", cfg.get_value("experimental", "gameplay_padding_amount", 75.0))
	gameplay_padding_right = cfg.get_value("experimental", "gameplay_padding_right", cfg.get_value("experimental", "gameplay_padding_amount", 75.0))
	gameplay_padding_top = cfg.get_value("experimental", "gameplay_padding_top", cfg.get_value("experimental", "gameplay_padding_amount", 0.0))
	gameplay_padding_bottom = cfg.get_value("experimental", "gameplay_padding_bottom", cfg.get_value("experimental", "gameplay_padding_amount", 0.0))
	library_roots = cfg.get_value("library", "roots", PackedStringArray())
	library_preset_downloads = cfg.get_value("library", "preset_downloads", false)
	library_preset_documents = cfg.get_value("library", "preset_documents", false)
	library_recursive = cfg.get_value("library", "recursive", true)
	library_max_depth = cfg.get_value("library", "max_depth", 3)


func reset_controls_to_defaults() -> void:
	game_mode = 0
	custom_lanes = []
	haptic_enabled = false
	haptic_sensitivity = 1.0
	haptic_activation_threshold = 1.0
	haptic_release_threshold = 0.5
	haptic_cooldown_duration = 0.15
	haptic_min_interval = 0.08
	haptic_smoothing_strength = 0.4
	haptic_calibration_duration = 1.5
	mirrored = false
	left_handed = false
	GameManager.mode = GameManager.GameMode.DEFAULT
	save_settings()


func reset_hud_to_defaults() -> void:
	show_fps = false
	max_fps = 60
	screen_shake = false
	show_hit_feedback = true
	note_speed = 1.0
	countdown_threshold = 5.0
	audio_offset_ms = 0.0
	save_settings()


func reset_library_to_defaults() -> void:
	library_roots = PackedStringArray()
	library_preset_downloads = OS.get_name() == "Android"
	library_preset_documents = OS.get_name() == "Android"
	library_recursive = true
	library_max_depth = 3
	save_settings()


func reset_experimental_to_defaults() -> void:
	use_guitar_fallback = false
	show_judgment_areas = false
	show_menu_status = false
	haptic_show_debug = false
	default_sample_velocity = 100
	gameplay_padding_enabled = false
	gameplay_padding_left = 75.0
	gameplay_padding_right = 75.0
	gameplay_padding_top = 0.0
	gameplay_padding_bottom = 0.0
	save_settings()


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
	cfg.set_value("timing", "audio_offset_ms", audio_offset_ms)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "default_sample_velocity", default_sample_velocity)
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
	cfg.set_value("visual", "max_fps", max_fps)
	cfg.set_value("visual", "show_hit_feedback", show_hit_feedback)
	cfg.set_value("gameplay", "countdown_threshold", countdown_threshold)
	cfg.set_value("gameplay", "use_guitar_fallback", use_guitar_fallback)
	cfg.set_value("visual", "show_judgment_areas", show_judgment_areas)
	cfg.set_value("visual", "show_menu_status", show_menu_status)
	cfg.set_value("audio", "preview_volume", preview_volume)
	cfg.set_value("experimental", "gameplay_padding_enabled", gameplay_padding_enabled)
	cfg.set_value("experimental", "gameplay_padding_left", gameplay_padding_left)
	cfg.set_value("experimental", "gameplay_padding_right", gameplay_padding_right)
	cfg.set_value("experimental", "gameplay_padding_top", gameplay_padding_top)
	cfg.set_value("experimental", "gameplay_padding_bottom", gameplay_padding_bottom)
	cfg.set_value("library", "roots", library_roots)
	cfg.set_value("library", "preset_downloads", library_preset_downloads)
	cfg.set_value("library", "preset_documents", library_preset_documents)
	cfg.set_value("library", "recursive", library_recursive)
	cfg.set_value("library", "max_depth", library_max_depth)

	cfg.save(SETTINGS_PATH)
