class_name ResultOverlay
extends CanvasLayer

# Panel de resultados de fin de cancion. Se construye entero por codigo (igual
# que el overlay de pausa de GameplayRoot) para no depender de una escena mas.
# Los botones no hacen nada por su cuenta: emiten señales y es GameplayRoot quien
# decide si toca reiniciar o volver al menu.

signal retry_requested()
signal exit_requested()

const PANEL_WIDTH: float = 520.0
const ROW_HEIGHT: float = 38.0
const BASE_LABEL_SETTINGS := preload("res://asset/fonts/label_settings.tres")

var _song_label: Label
var _score_label: Label
var _accuracy_label: Label
var _combo_label: Label
var _counts_label: Label


func _ready() -> void:
	layer = 15
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.name = "ResultBg"
	bg.color = Palette.SCRIM_RESULT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.name = "ResultPanel"
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -PANEL_WIDTH * 0.5
	vbox.offset_right = PANEL_WIDTH * 0.5
	vbox.offset_top = -320.0
	vbox.offset_bottom = 320.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	var title := _make_label("RESULTS", 48, Palette.BONE)
	title.name = "TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_song_label = _make_label("", 20, Palette.ASH)
	_song_label.name = "SongLabel"
	_song_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Los titulos largos ("Artista - Cancion (Dificultad)") se parten en dos
	# lineas en vez de salirse del panel.
	_song_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_song_label)

	vbox.add_child(_spacer(14))

	_score_label = _add_row(vbox, "SCORE", 34, Palette.BONE_HI)
	_accuracy_label = _add_row(vbox, "ACCURACY", 24, Palette.BONE)
	_combo_label = _add_row(vbox, "MAX COMBO", 24, Palette.CHROME)
	_counts_label = _add_row(vbox, "NOTES", 20, Palette.ASH)

	vbox.add_child(_spacer(18))

	var retry_btn := Button.new()
	retry_btn.name = "RetryButton"
	retry_btn.text = "REPLAY"
	retry_btn.custom_minimum_size = Vector2(PANEL_WIDTH, 50)
	retry_btn.pressed.connect(func() -> void: retry_requested.emit())
	vbox.add_child(retry_btn)

	var exit_btn := Button.new()
	exit_btn.name = "ExitButton"
	exit_btn.text = "EXIT"
	exit_btn.custom_minimum_size = Vector2(PANEL_WIDTH, 50)
	exit_btn.pressed.connect(func() -> void: exit_requested.emit())
	vbox.add_child(exit_btn)

	refresh()


# Vuelca el estado de ScoreManager. Se construye con las notas ya falladas
# (Highway.flush_unjudged_notes() corre antes de instanciar el panel) y se puede
# volver a llamar si hacen falta valores frescos.
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
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	parent.add_child(row)

	var left := _make_label(caption, 18, Palette.MUTED)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(left)

	var value := _make_label("-", font_size, color)
	value.name = caption.capitalize().replace(" ", "") + "Value"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value)
	return value


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	# LabelSettings duplicado en vez de theme overrides: el recurso base ya trae
	# la fuente del juego y el contorno, y cada etiqueta decide su tamano y su
	# color sin depender de que prevalezca uno u otro.
	var settings := BASE_LABEL_SETTINGS.duplicate() as LabelSettings
	settings.font_size = font_size
	settings.font_color = color
	label.label_settings = settings
	return label


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer
