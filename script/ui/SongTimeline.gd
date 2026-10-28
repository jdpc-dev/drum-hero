class_name SongTimeline
extends Control

# La banda 0-2.5 % de la pantalla es la linea de tiempo: el Highway arranca su
# pista en screen_h * 0.025, asi que la barra se dibuja justo encima de ella,
# con el mismo ancho y el mismo gameplay padding.
const BAND_RATIO: float = 0.025

var _fill: ColorRect
var _ratio: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_fill()
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	TimingEngine.time_updated.connect(_on_time_updated)


# TextureProgressBar dibujaba texture_under / texture_progress a su tamano nativo
# (2x2 px) en vez de estirarlas al rect del control, asi que el relleno se
# quedaba en un cuadro de 2 px en la esquina superior izquierda. La barra se
# construye con un ColorRect anclado: su geometria no depende de la resolucion
# ni del tamano de ningun recurso.
func _build_fill() -> void:
	_fill = ColorRect.new()
	_fill.name = "Fill"
	_fill.color = Palette.CHROME
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.anchor_right = 0.0
	_fill.anchor_bottom = 1.0
	add_child(_fill)


# La barra se alinea con el tablero de juego: mismo padding lateral y superior,
# y alto de banda igual a screen_h * 0.025 para que su base toque la pista.
func _apply_layout() -> void:
	var vs: Vector2 = get_viewport_rect().size
	var pad: Vector4 = _get_padding()
	var band_height: float = maxf(0.0, (vs.y - pad.y - pad.w) * BAND_RATIO)
	offset_left = pad.x
	offset_right = -pad.z
	offset_top = pad.y
	offset_bottom = pad.y + band_height


# (izquierda, arriba, derecha, abajo) en pixeles logicos de Godot.
func _get_padding() -> Vector4:
	if not SettingsManager.gameplay_padding_enabled:
		return Vector4.ZERO
	return Vector4(
		SettingsManager.dp_to_godot_px(SettingsManager.gameplay_padding_left),
		SettingsManager.dp_to_godot_px(SettingsManager.gameplay_padding_top),
		SettingsManager.dp_to_godot_px(SettingsManager.gameplay_padding_right),
		SettingsManager.dp_to_godot_px(SettingsManager.gameplay_padding_bottom)
	)


# Prioridad: la duracion que ya usa el reloj maestro, luego la del chart, luego
# la del audio. Se resuelve en cada tick en vez de cachearse en _ready(), que se
# ejecuta antes de TimingEngine.start() y se quedaria con la duracion de la
# cancion anterior: la barra tiene que representar el tiempo de la cancion que
# se esta reproduciendo. Con audio cargado solo es una lectura de chart_duration.
# Si las tres son 0 (sin song.ini y sin audio) la barra se queda vacia en lugar
# de congelarse en un 0 que parece tiempo real.
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
