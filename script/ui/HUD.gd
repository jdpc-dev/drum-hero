class_name HUD
extends CanvasLayer

@onready var score_label: Label = %ScoreLabel
@onready var combo_label: Label = %ComboLabel
@onready var multiplier_label: Label = %MultiplierLabel
var _fps_label: Label


func _ready() -> void:
	ScoreManager.score_changed.connect(_on_score_changed)
	ScoreManager.combo_changed.connect(_on_combo_changed)
	ScoreManager.multiplier_changed.connect(_on_multiplier_changed)
	_apply_label_colors()
	if SettingsManager.show_fps:
		_ensure_fps_label()
	_apply_padding()
	call_deferred("_warm_up_text")


# ScoreLabel and MultiplierLabel bring label_settings, and in Godot that
# resource wins over theme_override_colors: if the color is left in the scene,
# the override is silently ignored. That is why the color goes in a duplicated
# LabelSettings.
func _apply_label_colors() -> void:
	_tint_label(score_label, Palette.TEXT)
	_tint_label(multiplier_label, Palette.CHROME)
	# ComboLabel has no LabelSettings, so it takes the accent directly. The
	# scene used to carry a literal red override; keeping it here makes the
	# combo follow the active theme.
	combo_label.add_theme_color_override("font_color", Palette.ACCENT)
	combo_label.add_theme_color_override("font_outline_color", Color(Palette.INK, 0.5))


func _tint_label(label: Label, color: Color) -> void:
	if label == null or label.label_settings == null:
		return
	var settings: LabelSettings = label.label_settings.duplicate()
	settings.font_color = color
	label.label_settings = settings


func _wait_for_draw() -> void:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw


func _warm_up_text() -> void:
	# Rasterise the score/combo digits once, off-screen and almost transparent,
	# so the first hit does not pay the font-atlas upload on Android.
	var samples: Array[Label] = []
	if score_label and score_label.label_settings:
		samples.append(_make_text_sample(score_label.label_settings, "0123456789"))
	if multiplier_label and multiplier_label.label_settings:
		samples.append(_make_text_sample(multiplier_label.label_settings, "x0123456789"))
	if combo_label:
		var combo := Label.new()
		combo.add_theme_font_override("font", combo_label.get_theme_font("font"))
		combo.add_theme_font_size_override("font_size", combo_label.get_theme_font_size("font_size"))
		combo.text = "0123456789x"
		combo.size = Vector2(800, 120)
		combo.modulate.a = 0.01
		combo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(combo)
		samples.append(combo)

	await _wait_for_draw()
	await _wait_for_draw()
	for label in samples:
		label.queue_free()


func _make_text_sample(settings: LabelSettings, text: String) -> Label:
	var label := Label.new()
	label.label_settings = settings.duplicate()
	label.text = text
	label.size = Vector2(800, 120)
	label.modulate.a = 0.01
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _process(_delta: float) -> void:
	if SettingsManager.show_fps:
		if _fps_label:
			_fps_label.text = "FPS: %d" % roundi(Engine.get_frames_per_second())
		else:
			_ensure_fps_label()
	elif _fps_label:
		_fps_label.queue_free()
		_fps_label = null


func _ensure_fps_label() -> void:
	if _fps_label:
		return
	_fps_label = Label.new()
	_fps_label.name = "FPSLabel"
	_fps_label.position = Vector2(10, 20)
	_fps_label.add_theme_font_size_override("font_size", 14)
	_fps_label.add_theme_color_override("font_color", Palette.ASH_DIM)
	add_child(_fps_label)


func _apply_padding() -> void:
	if not SettingsManager.gameplay_padding_enabled:
		return
	var pl: float = SettingsManager.dp_to_godot_px(SettingsManager.gameplay_padding_left)
	var pr: float = SettingsManager.dp_to_godot_px(SettingsManager.gameplay_padding_right)
	var pt: float = SettingsManager.dp_to_godot_px(SettingsManager.gameplay_padding_top)
	if score_label:
		score_label.offset_left += pl
		score_label.offset_right -= pr
		score_label.offset_top += pt
	if multiplier_label:
		multiplier_label.offset_left += pl
		multiplier_label.offset_top += pt
	if combo_label:
		combo_label.offset_top += pt
	if _fps_label:
		_fps_label.position = Vector2(10 + pl, 20 + pt)

func _on_score_changed(new_score: int) -> void:
	if score_label:
		score_label.text = ScoreData.format_score(new_score)

func _on_combo_changed(new_combo: int) -> void:
	if combo_label:
		combo_label.text = str(new_combo) + "x" if new_combo > 0 else ""

func _on_multiplier_changed(new_mult: int) -> void:
	if multiplier_label:
		if new_mult > 1:
			multiplier_label.text = "x" + str(new_mult)
		else:
			multiplier_label.text = ""
