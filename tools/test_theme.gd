extends Node

# Theme engine regression test.
# Usage: godot --headless --path . res://tools/test_theme.tscn

var _failures: int = 0
var _settings_backup: PackedByteArray = PackedByteArray()
var _settings_existed: bool = false


func _check(label: String, ok: bool) -> void:
	if ok:
		print("  OK   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)


func _backup_settings() -> void:
	if FileAccess.file_exists(SettingsManager.SETTINGS_PATH):
		_settings_existed = true
		var f := FileAccess.open(SettingsManager.SETTINGS_PATH, FileAccess.READ)
		_settings_backup = f.get_buffer(f.get_length())
		f.close()


func _restore_settings() -> void:
	if not _settings_existed:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SettingsManager.SETTINGS_PATH))
		return
	var f := FileAccess.open(SettingsManager.SETTINGS_PATH, FileAccess.WRITE)
	f.store_buffer(_settings_backup)
	f.close()


func _text_dump(node: Node) -> String:
	var out: String = ""
	if node is Label or node is Button or node is CheckBox:
		out += "[%s] " % node.text
	for c in node.get_children():
		out += _text_dump(c)
	return out


func _linear_channel(value: float) -> float:
	return value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4)


func _contrast(a: Color, b: Color) -> float:
	var la: float = 0.2126 * _linear_channel(a.r) + 0.7152 * _linear_channel(a.g) + 0.0722 * _linear_channel(a.b)
	var lb: float = 0.2126 * _linear_channel(b.r) + 0.7152 * _linear_channel(b.g) + 0.0722 * _linear_channel(b.b)
	var hi: float = maxf(la, lb)
	var lo: float = minf(la, lb)
	return (hi + 0.05) / (lo + 0.05)


func _primary_contrast_ok() -> bool:
	return _contrast(Palette.ACCENT, Palette.ON_ACCENT) >= 4.5 \
		and _contrast(Palette.ACCENT_BRIGHT, Palette.ON_ACCENT) >= 4.5 \
		and _contrast(Palette.ACCENT_PRESSED, Palette.ON_ACCENT) >= 4.5


func _ready() -> void:
	_backup_settings()
	var original_theme: String = SettingsManager.theme

	print("=== 1. las tres paletas aplican sus tokens ===")
	var blood: String = Palette.apply_theme(Palette.THEME_BLOOD)
	_check("Blood normalizado", blood == Palette.THEME_BLOOD)
	_check("Blood usa el rojo oxblood", Palette.ACCENT == Color("#C1121F"))
	_check("Blood usa el fondo negro compartido", Palette.NIGHT_BG == Color.BLACK)
	_check("Blood mantiene contraste en el botón primario", _primary_contrast_ok())
	var metal: Color = Palette.BONE
	_check("Blood conserva el metal", Palette.BONE == metal)

	var tear: String = Palette.apply_theme(Palette.THEME_TEAR)
	_check("Tear normalizado", tear == Palette.THEME_TEAR)
	_check("Tear usa el azul de fondo marino", Palette.ACCENT == Color("#23718A"))
	_check("Tear comparte el mismo fondo negro", Palette.NIGHT_BG == Color.BLACK)
	_check("Tear conserva el metal", Palette.BONE == metal)
	_check("Tear usa texto metal sobre el acento", Palette.ON_ACCENT == Palette.BONE_HI)
	_check("Tear mantiene contraste en el botón primario", _primary_contrast_ok())

	var hacker: String = Palette.apply_theme(Palette.THEME_HACKER)
	_check("Hacker normalizado", hacker == Palette.THEME_HACKER)
	_check("Hacker usa el verde terminal", Palette.ACCENT == Color("#1FAF4B"))
	_check("Hacker comparte el mismo fondo negro", Palette.NIGHT_BG == Color.BLACK)
	_check("el launch comparte el mismo fondo negro",
		ProjectSettings.get_setting("application/boot_splash/bg_color", Color.RED) == Color.BLACK)
	_check("Hacker conserva el metal", Palette.BONE == metal)
	_check("Hacker usa tinta negra sobre el acento", Palette.ON_ACCENT == Palette.INK)
	_check("Hacker mantiene contraste en el botón primario", _primary_contrast_ok())

	_check("ids desconocidos caen en Blood", Palette.normalize_theme("nope") == Palette.THEME_BLOOD)
	_check("los ids ignoran espacios y mayúsculas", Palette.normalize_theme("  TeAr ") == Palette.THEME_TEAR)
	var swatches: Array[Color] = Palette.theme_swatches(Palette.THEME_HACKER)
	_check("la vista previa tiene superficie, acento y metal",
		swatches.size() == 3 and swatches[0] == Palette.NIGHT_BG and swatches[2] == Palette.BONE)
	var base_keys: Array = Palette.THEME_DATA[Palette.THEME_BLOOD].keys()
	base_keys.sort()
	var same_keys: bool = true
	for id in Palette.THEME_IDS:
		var keys: Array = Palette.THEME_DATA[id].keys()
		keys.sort()
		if keys != base_keys:
			same_keys = false
	_check("las tres paletas declaran los mismos tokens", same_keys)

	print("=== 2. persistencia y reset ===")
	var before_revision: int = Palette.revision
	SettingsManager.set_theme(Palette.THEME_TEAR)
	_check("set_theme aplica y guarda", SettingsManager.theme == Palette.THEME_TEAR and Palette.current_theme == Palette.THEME_TEAR)
	_check("la revisión avanza", Palette.revision > before_revision)

	SettingsManager.theme = Palette.THEME_BLOOD
	Palette.apply_theme(Palette.THEME_BLOOD)
	SettingsManager.load_settings()
	_check("load_settings recupera el tema guardado", SettingsManager.theme == Palette.THEME_TEAR)

	SettingsManager.reset_experimental_to_defaults()
	_check("reset ADVANCED vuelve a Blood",
		SettingsManager.theme == Palette.THEME_BLOOD and Palette.current_theme == Palette.THEME_BLOOD)

	print("=== 3. la tarjeta THEME encabeza ADVANCED ===")
	var root := preload("res://scene/Settings.tscn").instantiate()
	add_child(root)
	await get_tree().process_frame
	root._on_tab_selected(4)
	await get_tree().process_frame

	var first_card: Node = null
	if root._content_container != null and root._content_container.get_child_count() > 0:
		first_card = root._content_container.get_child(0)
	_check("la primera tarjeta es THEME", first_card != null and _text_dump(first_card).contains("THEME"))
	var dump: String = _text_dump(root).to_upper()
	_check("las tres opciones están visibles",
		dump.contains("BLOOD") and dump.contains("TEAR") and dump.contains("HACKER"))
	_check("la descripción del tema está visible", dump.contains("OXBLOOD"))

	root._on_theme_toggled(true, 1)
	for _i in 4:
		await get_tree().process_frame
	_check("la selección desde la UI aplica Tear", SettingsManager.theme == Palette.THEME_TEAR and Palette.current_theme == Palette.THEME_TEAR)
	_check("ADVANCED sigue activo tras reconstruir", int(root._current_tab) == 4)
	_check("la tarjeta THEME sigue arriba", _text_dump(root).contains("THEME"))
	var shell_bg := root.get_child(0) as ColorRect
	_check("el fondo del panel sigue siendo el negro compartido",
		shell_bg != null and shell_bg.color == Palette.NIGHT_BG and shell_bg.color == Color.BLACK)

	root.queue_free()
	await get_tree().process_frame

	# Leave the process and settings file as they were.
	SettingsManager.set_theme(original_theme)
	_restore_settings()
	Palette.apply_theme(original_theme)

	print("")
	if _failures == 0:
		print("=== TODAS LAS COMPROBACIONES OK ===")
	else:
		print("=== ", _failures, " FALLOS ===")
	get_tree().quit(0 if _failures == 0 else 1)
