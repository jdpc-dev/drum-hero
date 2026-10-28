extends Node

# Verifica la geometria de SongTimeline: la barra debe ocupar la banda 0-2.5 %
# de la pantalla alineada con el tablero de juego, y el relleno blanco debe
# crecer de izquierda a derecha en proporcion al tiempo de la cancion.
# Uso: godot --headless --path . --script res://tools/test_timeline.gd


class ProbeTimeline extends SongTimeline:
	var pad_override: Vector4 = Vector4(-1, -1, -1, -1)

	func _get_padding() -> Vector4:
		if pad_override.x >= 0.0:
			return pad_override
		return super()


var _failures: int = 0


func _check(label: String, ok: bool) -> void:
	if ok:
		print("  OK   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)


func _ready() -> void:
	_check_scene_node()
	await _run_case(Vector4(0, 0, 0, 0), "sin padding")
	await _run_case(Vector4(75, 0, 75, 0), "con padding lateral")
	await _run_case(Vector4(75, 20, 75, 30), "con padding en los cuatro lados")
	if _failures == 0:
		print("\nOK: SongTimeline correcto")
	else:
		printerr("\n%d comprobaciones fallidas" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check_scene_node() -> void:
	print("== escena ==")
	var packed: PackedScene = load("res://scene/Gameplay.tscn")
	_check("Gameplay.tscn carga", packed != null)
	# No se agrega al arbol: GameplayRoot._ready() arrancaria la carga de una
	# cancion. Los offsets del nodo se leen sin necesidad de instanciarlo.
	var root: Node = packed.instantiate()
	var tl: Control = root.get_node("HUD/SongTimeline") as Control
	_check("SongTimeline es un Control (no TextureProgressBar)", tl is Control and not (tl is TextureProgressBar))
	_check("ancho completo", is_equal_approx(tl.anchor_left, 0.0) and is_equal_approx(tl.anchor_right, 1.0))
	_check("no intercepta el raton", tl.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var txt: String = FileAccess.get_file_as_string("res://scene/Gameplay.tscn")
	_check("sin tint_under/tint_progress heredados", not txt.contains("tint_under") and not txt.contains("texture_progress"))
	root.free()


func _run_case(pad: Vector4, label: String) -> void:
	print("\n== ", label, " ==")
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	var tl := ProbeTimeline.new()
	tl.pad_override = pad
	tl.anchor_right = 1.0
	root.add_child(tl)
	TimingEngine.chart_duration = 200.0
	# TimingEngine emite time_updated en cada _process: se desconecta para poder
	# fijar el tiempo a mano y medir la geometria de forma determinista.
	TimingEngine.time_updated.disconnect(tl._on_time_updated)

	var vs: Vector2 = get_viewport().get_visible_rect().size
	await get_tree().process_frame
	await get_tree().process_frame
	print("  viewport=", vs, " timeline=", tl.get_rect())

	var band_h: float = (vs.y - pad.y - pad.w) * SongTimeline.BAND_RATIO
	_check("ancho = viewport - padding lateral", is_equal_approx(tl.size.x, vs.x - pad.x - pad.z))
	_check("alto = banda 2.5%", is_equal_approx(tl.size.y, band_h))
	_check("pegado al borde superior", is_equal_approx(tl.position.y, pad.y))
	_check("la base toca el inicio de la pista", is_equal_approx(tl.position.y + tl.size.y, pad.y + (vs.y - pad.y - pad.w) * SongTimeline.BAND_RATIO))

	var fill: ColorRect = tl.get_node("Fill") as ColorRect
	_check("existe el ColorRect del relleno", fill != null)
	_check("el relleno cubre todo el alto", is_equal_approx(fill.size.y, tl.size.y))
	_check("inicio: relleno vacio", is_equal_approx(fill.size.x, 0.0))

	tl._on_time_updated(100.0)
	print("  t=100s de 200s -> ancho del relleno=", fill.size.x)
	_check("mitad: relleno a la mitad del ancho", is_equal_approx(fill.size.x, tl.size.x * 0.5))
	_check("mitad: arranca en el borde izquierdo", is_equal_approx(fill.position.x, 0.0))
	_check("mitad: mantiene el alto completo", is_equal_approx(fill.size.y, tl.size.y))

	tl._on_time_updated(200.0)
	print("  t=200s de 200s -> ancho del relleno=", fill.size.x)
	_check("final: ancho completo", is_equal_approx(fill.size.x, tl.size.x))
	_check("final: alto completo del timeline", is_equal_approx(fill.size.y, tl.size.y))
	_check("final: no se sale por la derecha", is_equal_approx(fill.position.x + fill.size.x, tl.size.x))

	# Con el reloj maestro real: el relleno sigue al tiempo de reproducción.
	TimingEngine.time_updated.connect(tl._on_time_updated)
	TimingEngine.audio_position = 150.0
	await get_tree().process_frame
	_check("señal real: 150 de 200 s -> 3/4 del ancho", absf(fill.size.x - tl.size.x * 0.75) < 1.0)

	# Cambiar de cancion reescala la barra: la duracion se resuelve en cada tick,
	# no se cachea en _ready() (que corre antes de TimingEngine.start()).
	TimingEngine.chart_duration = 100.0
	TimingEngine.audio_position = 50.0
	await get_tree().process_frame
	_check("cambio de cancion: 50 de 100 s -> mitad del ancho", absf(fill.size.x - tl.size.x * 0.5) < 1.0)
	TimingEngine.chart_duration = 200.0

	tl.queue_free()
	layer.queue_free()
	await get_tree().process_frame
