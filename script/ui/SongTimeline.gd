class_name SongTimeline
extends Control

# The 0-2.5 % band of the screen is the timeline: Highway starts its track at
# screen_h * 0.025, so the bar is drawn right above it, with the same width and
# the same gameplay padding.
const BAND_RATIO: float = 0.025

var _fill: ColorRect
var _ratio: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_fill()
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	TimingEngine.time_updated.connect(_on_time_updated)


# TextureProgressBar drew texture_under / texture_progress at their native size
# (2x2 px) instead of stretching them to the control's rect, so the fill ended
# up as a 2 px square in the top-left corner. The bar is built with an anchored
# ColorRect: its geometry does not depend on the resolution or the size of any
# resource.
func _build_fill() -> void:
	_fill = ColorRect.new()
	_fill.name = "Fill"
	_fill.color = Palette.CHROME
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.anchor_right = 0.0
	_fill.anchor_bottom = 1.0
	add_child(_fill)


# The bar aligns with the game board: same side and top padding, and band
# height equal to screen_h * 0.025 so its base touches the track.
func _apply_layout() -> void:
	var vs: Vector2 = get_viewport_rect().size
	var pad: Vector4 = _get_padding()
	var band_height: float = maxf(0.0, (vs.y - pad.y - pad.w) * BAND_RATIO)
	offset_left = pad.x
	offset_right = -pad.z
	offset_top = pad.y
	offset_bottom = pad.y + band_height


# (left, top, right, bottom) in Godot logical pixels.
func _get_padding() -> Vector4:
	if not SettingsManager.gameplay_padding_enabled:
		return Vector4.ZERO
	return Vector4(
		SettingsManager.dp_to_godot_px(SettingsManager.gameplay_padding_left),
		SettingsManager.dp_to_godot_px(SettingsManager.gameplay_padding_top),
		SettingsManager.dp_to_godot_px(SettingsManager.gameplay_padding_right),
		SettingsManager.dp_to_godot_px(SettingsManager.gameplay_padding_bottom)
	)


# Priority: the duration already used by the master clock, then the chart's,
# then the audio's. It is resolved on every tick instead of cached in _ready(),
# which runs before TimingEngine.start() and would keep the previous song's
# duration: the bar must represent the time of the song being played. With
# audio loaded it is only a read of chart_duration.
# If all three are 0 (no song.ini and no audio) the bar stays empty instead of
# freezing at a 0 that looks like real time.
func _resolve_duration() -> float:
	var duration: float = TimingEngine.chart_duration
	if duration <= 0.0:
		duration = ChartParser.get_duration_seconds()
	if duration <= 0.0:
		duration = AudioManager.get_length()
	return maxf(0.0, duration)


func _on_time_updated(time_sec: float) -> void:
	var duration: float = _resolve_duration()
	if duration <= 0.0 or _fill == null:
		return
	_ratio = clampf(time_sec / duration, 0.0, 1.0)
	_fill.anchor_right = _ratio
