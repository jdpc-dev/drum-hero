class_name ResultOverlay
extends CanvasLayer

# End-of-song results panel. It is built entirely in code (like the pause
# overlay in GameplayRoot) to avoid depending on another scene. The buttons do
# nothing on their own: they emit signals and GameplayRoot decides whether to
# restart or return to the menu.

signal retry_requested()
signal exit_requested()

const PANEL_WIDTH: float = 520.0
const ROW_HEIGHT: float = 24.0

var _song_label: Label
var _score_label: Label
var _accuracy_label: Label
var _combo_label: Label
var _counts_label: Label


func _ready() -> void:
	SettingsUI.setup_ui_scale(get_viewport().get_visible_rect().size.y)
	layer = 15
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.name = "ResultBg"
	bg.color = Palette.SCRIM_RESULT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# See the pause overlay: the card scroll layer must not share a CanvasLayer
	# with the scrim, or its clip leaves the bottom margin undimmed on Android.
	var modal_layer := CanvasLayer.new()
	modal_layer.name = "ResultModalLayer"
	modal_layer.layer = layer + 1
	add_child(modal_layer)

	var modal := SettingsUI.ModalBody.new()
	modal.name = "ResultModal"
	modal_layer.add_child(modal)

	var card := PanelContainer.new()
	card.name = "ResultCard"
	card.custom_minimum_size = Vector2(SettingsUI.px(PANEL_WIDTH + 48.0), 0)
	# PASS so a drag on the card background reaches the scroll layer; the scrim
	# below still stops input from reaching gameplay.
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var card_style := SettingsUI.flat(Palette.SURFACE_1, 20)
	SettingsUI.pad(card_style, SettingsUI.px(22), SettingsUI.px(14))
	card.add_theme_stylebox_override("panel", card_style)
	modal.add_card(card)

	var vbox := VBoxContainer.new()
	vbox.name = "ResultPanel"
	# PASS so touch drags over the rows reach the modal's scroll layer. Buttons
	# are PASS too (see SettingsUI.button), so a swipe works on top of them.
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_theme_constant_override("separation", SettingsUI.px(3))
	card.add_child(vbox)

	var title := SettingsUI.label("RESULTS", 28, Palette.BONE_HI, 600)
	title.name = "TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Trim the font's empty leading so the song line sits close to the heading.
	SettingsUI.fit_line_height(title, SettingsUI.px(32))
	vbox.add_child(title)

	_song_label = SettingsUI.label("", 14, Palette.ASH, 400)
	_song_label.name = "SongLabel"
	_song_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Long titles ("Artist - Song (Difficulty)") are split into two lines
	# instead of overflowing the panel.
	_song_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SettingsUI.fit_line_height(_song_label, SettingsUI.px(18))
	vbox.add_child(_song_label)

	vbox.add_child(SettingsUI.divider())

	_score_label = _add_row(vbox, "SCORE", 30, Palette.ACCENT)
	vbox.add_child(SettingsUI.divider())
	_accuracy_label = _add_row(vbox, "ACCURACY", 20, Palette.BONE)
	_combo_label = _add_row(vbox, "MAX COMBO", 20, Palette.CHROME)
	_counts_label = _add_row(vbox, "NOTES", 14, Palette.ASH)

	var buttons := HBoxContainer.new()
	buttons.name = "ResultButtons"
	buttons.add_theme_constant_override("separation", SettingsUI.px(10))
	vbox.add_child(buttons)

	var exit_btn := SettingsUI.button("EXIT", "secondary")
	exit_btn.name = "ExitButton"
	exit_btn.custom_minimum_size = Vector2(0, SettingsUI.px(44))
	exit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exit_btn.pressed.connect(func() -> void: exit_requested.emit())
	buttons.add_child(exit_btn)

	var retry_btn := SettingsUI.button("REPLAY", "primary")
	retry_btn.name = "RetryButton"
	retry_btn.custom_minimum_size = Vector2(0, SettingsUI.px(44))
	retry_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retry_btn.pressed.connect(func() -> void: retry_requested.emit())
	buttons.add_child(retry_btn)

	refresh()


# Dumps ScoreManager's state. It is built with the notes already missed
# (Highway.flush_unjudged_notes() runs before instantiating the panel) and can
# be called again if fresh values are needed.
func refresh() -> void:
	if _score_label == null:
		return
	_score_label.text = ScoreData.format_score(ScoreManager.score)
	_accuracy_label.text = "%.1f %%" % ScoreManager.get_accuracy_pct()
	_combo_label.text = str(ScoreManager.max_combo) + "x"
	_counts_label.text = str(ScoreManager.hits) + " hit / " + str(ScoreManager.misses) + " miss"
	var song_title: String = GameManager.current_song_title
	if not GameManager.current_song_artist.is_empty():
		song_title = GameManager.current_song_artist + " - " + song_title
	_song_label.text = song_title + "  (" + GameManager.current_difficulty_name + ")"


func _add_row(parent: VBoxContainer, caption: String, font_size: int, color: Color) -> Label:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, SettingsUI.px(ROW_HEIGHT))
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(row)

	var left := SettingsUI.label(caption, 13, Palette.MUTED, 500)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(left)

	var value := SettingsUI.label("-", font_size, color, 500)
	value.name = caption.capitalize().replace(" ", "") + "Value"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value)
	return value
