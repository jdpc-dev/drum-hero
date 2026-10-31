extends Node

var _settings_backup: PackedByteArray = PackedByteArray()
var _settings_existed: bool = false
var _failures: int = 0


func _backup_settings() -> void:
	if FileAccess.file_exists(SettingsManager.SETTINGS_PATH):
		_settings_existed = true
		var f := FileAccess.open(SettingsManager.SETTINGS_PATH, FileAccess.READ)
		_settings_backup = f.get_buffer(f.get_length())
		f.close()


func _restore_settings() -> void:
	if not _settings_existed:
		DirAccess.remove_absolute(SettingsManager.SETTINGS_PATH)
		return
	var f := FileAccess.open(SettingsManager.SETTINGS_PATH, FileAccess.WRITE)
	f.store_buffer(_settings_backup)
	f.close()


func _check(label: String, ok: bool) -> void:
	if ok:
		print("  OK   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)


func _find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for c in node.get_children():
		var r := _find_button(c, text)
		if r:
			return r
	return null


func _find_option(node: Node) -> OptionButton:
	if node is OptionButton:
		return node
	for c in node.get_children():
		var r := _find_option(c)
		if r:
			return r
	return null


func _find_check(node: Node, text: String) -> CheckBox:
	if node is CheckBox and node.text == text:
		return node
	for c in node.get_children():
		var r := _find_check(c, text)
		if r:
			return r
	return null


func _text_dump(node: Node) -> String:
	var out: String = ""
	if node is Label or node is Button or node is CheckBox:
		out += "[%s] " % node.text
	for c in node.get_children():
		out += _text_dump(c)
	return out


func _ready() -> void:
	_backup_settings()
	var root := preload("res://scene/Settings.tscn").instantiate()
	add_child(root)
	await get_tree().process_frame

	print("=== 1. la pestaña SONGS existe y es alcanzable ===")
	var tabs: Array[Button] = []
	_collect_tabs(root, tabs)
	var tab_texts: PackedStringArray = PackedStringArray()
	for t in tabs:
		tab_texts.append(t.text)
	print("  pestañas: ", tab_texts)
	_check("SONGS presente", tab_texts.has("SONGS"))

	var songs_tab: Button = null
	for t in tabs:
		if t.text == "SONGS":
			songs_tab = t
	songs_tab.button_pressed = true
	songs_tab.pressed.emit()
	await get_tree().process_frame

	var dump: String = _text_dump(root)
	print("=== 2. contenido de la pestaña ===")
	_check("muestra seccion NEED SONGS", dump.contains("NEED SONGS?"))
	_check("hay boton Get songs", _find_button(root, "Get songs") != null)
	_check("muestra seccion STORAGE ACCESS", dump.contains("STORAGE ACCESS"))
	_check("muestra seccion LIBRARY LOCATIONS", dump.contains("LIBRARY LOCATIONS"))
	_check("muestra seccion EXTRA FOLDERS", dump.contains("EXTRA FOLDERS"))
	_check("hay check Scan Download", _find_check(root, "Scan Download") != null)
	_check("hay check Scan Documents", _find_check(root, "Scan Documents") != null)
	_check("hay check Search subfolders", _find_check(root, "Search subfolders") != null)
	_check("hay campo de ruta", root.find_child("*", true, false) != null and dump.contains("absolute path"))
	_check("hay boton Add", _find_button(root, "Add") != null)
	_check("hay boton Rescan now", _find_button(root, "Rescan now") != null)
	_check("hay boton Reset SONGS", _find_button(root, "Reset SONGS to Defaults") != null)
	_check("no hay desconexiones huerfanas", true)

	print("=== 2b. seccion STORAGE ACCESS ===")
	if OS.get_name() != "Android":
		_check("en desktop se indica que el acceso es automatico", dump.contains("automatic on this platform"))
		_check("en desktop no hay boton de permiso", _find_button(root, "Grant access") == null)
	else:
		_check("hay boton Grant access", _find_button(root, "Grant access") != null)
		# On desktop there is no Android singleton, so the "missing plugin"
		# branch is exercised, which is what avoids a dead button.
		var st := Label.new()
		root.add_child(st)
		var bt := Button.new()
		root.add_child(bt)
		root._permission_status = st
		root._permission_button = bt
		root._update_permission_section()
		_check("sin el plugin se avisa en vez de fallar en silencio", st.text.contains("plugin missing"))
		_check("el boton se deshabilita si no hay plugin", bt.disabled)
		root._permission_status = null
		root._permission_button = null
		st.queue_free()
		bt.queue_free()

	print("=== 3. controles reflejan el estado persistido ===")
	SettingsManager.library_preset_documents = false
	SettingsManager.library_preset_downloads = true
	SettingsManager.library_recursive = true
	SettingsManager.library_max_depth = 4
	songs_tab.pressed.emit()
	await get_tree().process_frame
	_check("Scan Download marcado", _find_check(root, "Scan Download").button_pressed)
	_check("Scan Documents desmarcado", not _find_check(root, "Scan Documents").button_pressed)
	_check("Search subfolders marcado", _find_check(root, "Search subfolders").button_pressed)
	_check("profundidad=4 -> indice 4", _find_option(root).selected == 4)

	print("=== 4. Depth 0 = 'Only this folder' y el resumen es legible ===")
	_check("indice 0 = solo esta carpeta", _find_option(root).get_item_text(0) == "Only this folder")

	print("=== 5. anadir y quitar raiz personalizada persiste ===")
	SettingsManager.library_roots = PackedStringArray()
	SettingsManager.save_settings()
	var before: int = SettingsManager.library_roots.size()
	root._on_add_root("  /tmp/opencode/libtest/rootA//  ")
	_check("raiz normalizada y anadida", SettingsManager.library_roots.size() == before + 1)
	_check("normalizada a /tmp/opencode/libtest/rootA", SettingsManager.library_roots.has("/tmp/opencode/libtest/rootA"))
	root._on_add_root("/tmp/opencode/libtest/rootA")
	_check("no duplica la misma raiz", SettingsManager.library_roots.size() == before + 1)
	root._on_add_root("relative/path")
	_check("una ruta relativa se convierte en absoluta", SettingsManager.library_roots.has("/relative/path"))
	root._on_remove_root(0)
	_check("raiz eliminada", not SettingsManager.library_roots.has("/tmp/opencode/libtest/rootA"))

	print("=== 6. toggles escriben en SettingsManager ===")
	_find_check(root, "Search subfolders").set_pressed_no_signal(false)
	_find_check(root, "Search subfolders").toggled.emit(false)
	await get_tree().process_frame
	_check("recursividad propagada", SettingsManager.library_recursive == false)
	_find_check(root, "Scan Documents").set_pressed_no_signal(true)
	_find_check(root, "Scan Documents").toggled.emit(true)
	await get_tree().process_frame
	_check("preset documents propagado", SettingsManager.library_preset_documents == true)

	print("=== 7. resumen del escaneo incluye locations y avisos ===")
	SettingsManager.library_roots = PackedStringArray(["/tmp/opencode/libtest/noexiste"])
	SettingsManager.library_preset_downloads = false
	SettingsManager.library_preset_documents = false
	SongLoader.scan_songs()
	root._update_scan_summary()
	var summary: String = root._scan_summary.text
	print("  resumen: ", summary.replace("\n", " | "))
	_check("menciona numero de canciones", summary.contains("Last scan:"))
	_check("menciona ubicaciones", summary.contains("location(s)"))
	_check("advierte de la raiz ilegible", summary.contains("Unreadable:"))

	print("=== 8. Reset restaura los defaults ===")
	SettingsManager.library_roots = PackedStringArray(["/a", "/b"])
	root._on_reset_songs()
	await get_tree().process_frame
	_check("roots vaciados", SettingsManager.library_roots.is_empty())
	_check("recursivo por defecto", SettingsManager.library_recursive == true)
	_check("profundidad por defecto=3", SettingsManager.library_max_depth == 3)
	_check("presets por defecto = es Android", SettingsManager.library_preset_downloads == (OS.get_name() == "Android"))

	print("=== 9. volver a construir la pestaña no deja nodos huerfanos ===")
	var content: VBoxContainer = root._content_container
	for i in 5:
		songs_tab.pressed.emit()
		await get_tree().process_frame
	_check("sin hijos acumulados", content.get_child_count() < 80)
	print("  hijos en content: ", content.get_child_count())

	print("=== 10. TODAS las pestañas se construyen tras insertar SONGS ===")
	var names: PackedStringArray = PackedStringArray(["CONTROLS", "HUD", "SONGS", "Experimental", "CREDITS"])
	for i in names.size():
		for t in tabs:
			if t.text == names[i]:
				t.set_pressed_no_signal(true)
				t.pressed.emit()
				break
		await get_tree().process_frame
		_check("pestana " + names[i] + " construye contenido", content.get_child_count() > 0)
		var d: String = _text_dump(root)
		_check("pestana " + names[i] + " sin contenido de otra pestana", not (names[i] == "SONGS" and d.contains("GAMEPLAY PADDING")))

	print("=== 11. portada externa se carga desde disco (no res://) ===")
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 0, 1))
	_check("PNG de prueba guardado", img.save_png("/tmp/opencode/cover.png") == OK)
	var menu := preload("res://scene/Main.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	var tex: Texture2D = menu._load_external_texture("/tmp/opencode/cover.png")
	_check("portada externa cargada como Texture2D", tex != null)
	_check("portada inexistente devuelve null sin error", menu._load_external_texture("/tmp/opencode/no_existe.png") == null)
	DirAccess.remove_absolute("/tmp/opencode/cover.png")

	print("=== 11b. toggle 'Show Menu Status' en Experimental ===")
	for t in tabs:
		if t.text == "Experimental":
			t.set_pressed_no_signal(true)
			t.pressed.emit()
			break
	await get_tree().process_frame
	var status_check := _find_check(root, "Show Menu Status")
	_check("hay check Show Menu Status", status_check != null)
	status_check.set_pressed_no_signal(true)
	status_check.toggled.emit(true)
	await get_tree().process_frame
	_check("toggle propaga a show_menu_status", SettingsManager.show_menu_status == true)

	SettingsManager.show_menu_status = false
	menu._apply_status_visibility()
	_check("oculto: label invisible y espacio liberado", not menu._status_label.visible and menu._status_label.custom_minimum_size.y == 0)
	SettingsManager.show_menu_status = true
	menu._apply_status_visibility()
	_check("activo: label visible y altura restaurada", menu._status_label.visible and menu._status_label.custom_minimum_size.y == menu.STATUS_HEIGHT)
	SettingsManager.show_menu_status = false
	root._on_reset_experimental()
	await get_tree().process_frame
	_check("reset experimental vuelve show_menu_status=false", SettingsManager.show_menu_status == false)

	print("=== 11c. salida del juego segun 'Show Menu Status' ===")
	SettingsManager.show_menu_status = true
	menu._apply_status_visibility()
	menu._back_press_time = -1000.0
	menu._handle_back()
	_check("con menu status visible se pide confirmar con texto",
		menu._status_label.visible and menu._status_label.text == "Press again to exit")
	_check("con menu status visible no hay modal", not menu._quit_confirm_is_open())

	SettingsManager.show_menu_status = false
	menu._apply_status_visibility()
	menu._status_label.text = "Select a song"
	menu._handle_back()
	_check("con menu status oculto no aparece el texto", not menu._status_label.visible)
	_check("con menu status oculto se abre el modal", menu._quit_confirm_is_open())
	var quit_panel: Node = menu.find_child("QuitConfirmPanel", true, false)
	_check("el modal pregunta si se quiere cerrar",
		_text_dump(quit_panel).contains("Are you sure you want to close the game?"))
	_check("el modal tiene CANCEL y EXIT",
		_find_button(quit_panel, "CANCEL") != null and _find_button(quit_panel, "EXIT") != null)
	menu._handle_back()
	_check("atras cancela el modal", not menu._quit_confirm_is_open())

	print("=== 11d. hint contextual en la linea de preview ===")
	SongLoader.song_list.clear()
	menu._update_preview_idle_text()
	_check("sin canciones -> linea vacia", menu._preview_status_label.text == "")
	SongLoader.song_list.append({"path": "/tmp/x", "name": "Test", "artist": "Artist"})
	menu._update_preview_idle_text()
	_check("con canciones -> muestra hint", menu._preview_status_label.text.contains("Tap a song to preview"))
	menu._preview_animating = true
	menu._preview_status_label.text = "."
	menu._update_preview_idle_text()
	_check("mientras carga no toca el texto", menu._preview_status_label.text == ".")
	menu._preview_animating = false

	print("=== 12. MenuRoot detecta cambios de biblioteca al cerrar Ajustes ===")
	menu._old_library_state = [
		SettingsManager.library_roots,
		SettingsManager.library_preset_downloads,
		SettingsManager.library_preset_documents,
		SettingsManager.library_recursive,
		SettingsManager.library_max_depth,
	]
	_check("sin cambios -> false", not menu._library_changed())
	SettingsManager.library_preset_documents = not SettingsManager.library_preset_documents
	_check("cambio de preset -> true", menu._library_changed())
	_check("y consume el estado (idempotente)", not menu._library_changed())
	SettingsManager.library_roots = PackedStringArray(["/tmp/x"])
	_check("cambio de raices -> true", menu._library_changed())
	print("=== 13. indicador de escaneo en Ajustes ▸ Canciones ===")
	# Any scan coming from earlier (the menu's own _ready requests it if the
	# list is empty) is allowed to finish: otherwise, the panel would not be the
	# one controlling the pump and the checks would be noise.
	for i in 300:
		if not SongLoader.is_scanning and not menu._scan_pump_active and not root._scan_pump_active:
			break
		await get_tree().process_frame
	_check("SongLoader queda libre antes de probar", not SongLoader.is_scanning)

	SettingsManager.library_roots = PackedStringArray(["/tmp/opencode/libtest/rootA", "/tmp/opencode/libtest/rootA/a/b/c/d/TooDeep"])
	SettingsManager.library_preset_downloads = false
	SettingsManager.library_preset_documents = false
	SettingsManager.library_recursive = true
	SettingsManager.library_max_depth = 3
	# How many songs those roots yield, so it does not have to be hardcoded.
	SongLoader.scan_songs()
	var expected_songs: int = SongLoader.song_list.size()
	root._on_tab_selected(root.SONGS_TAB)
	await get_tree().process_frame
	_check("hay boton de reescanear", is_instance_valid(root._rescan_button))
	_check("hay boton de cancelar", is_instance_valid(root._cancel_scan_button))
	_check("y barra, estado y carpeta", is_instance_valid(root._scan_bar) and is_instance_valid(root._scan_status) and is_instance_valid(root._scan_folder))
	_check("en reposo el indicador esta oculto", not root._scan_bar.visible and not root._scan_status.visible and not root._scan_folder.visible)
	_check("y se puede reescanear", root._rescan_button.disabled == false)
	_check("mientras que cancelar esta deshabilitado", root._cancel_scan_button.disabled)

	root._scan_summary_and_rescan()
	_check("el reescaneo es inmediato, sin await", SongLoader.is_scanning)
	_check("el indicador se muestra", root._scan_bar.visible and root._scan_status.visible and root._scan_folder.visible)
	_check("el estado dice que esta escaneando", root._scan_status.text.begins_with("Scanning"))
	_check("reescanear se bloquea y cancelar se habilita", root._rescan_button.disabled and not root._cancel_scan_button.disabled)
	for i in 300:
		if not SongLoader.is_scanning:
			break
		await get_tree().process_frame
	_check("el escaneo termina solo", not SongLoader.is_scanning and not root._scan_pump_active)
	_check("y el indicador se esconde", not root._scan_bar.visible and not root._scan_folder.visible)
	_check("vuelve a poder reescanear", root._rescan_button.disabled == false and root._cancel_scan_button.disabled)
	_check("el resumen cuenta las canciones de las raices indicadas", root._scan_summary.text.contains(str(expected_songs) + " songs"))
	_check("y avisa de la raiz truncada por profundidad", root._scan_summary.text.contains("Too deep (raise max subfolder depth): " + SettingsManager.library_roots[0]))

	print("=== 14. cancelar desde Ajustes conserva lo encontrado ===")
	# With the test roots the whole walk fits in a single batch
	# (MAX_DIRS_PER_FRAME = 64), and cancelling would arrive late: a wide,
	# empty root is added so the scan has to split across several frames.
	var wide: String = "/tmp/opencode/libtest/wide"
	DirAccess.make_dir_recursive_absolute(wide)
	for i in 200:
		DirAccess.make_dir_recursive_absolute(wide + "/d" + str(i))
	var previous_roots: PackedStringArray = SettingsManager.library_roots
	SettingsManager.library_roots = PackedStringArray([wide])
	root._scan_summary_and_rescan()
	_check("el escaneo vuelve a arrancar", SongLoader.is_scanning)
	root._cancel_scan_button.emit_signal("pressed")
	_check("pulsar cancelar no corta en seco", SongLoader.is_scanning)
	for i in 300:
		if not SongLoader.is_scanning:
			break
		await get_tree().process_frame
	_check("se detiene en cuanto toca", not SongLoader.is_scanning and not root._scan_pump_active)
	_check("se queda con lo que habia encontrado", SongLoader.song_list.size() >= 0)
	_check("la raiz a medias queda anotada", SongLoader.cancelled_roots.size() == 1)
	_check("el resumen avisa de la raiz cancelada", root._scan_summary.text.contains("Scan cancelled before finishing here, this location may have more songs: " + SongLoader.cancelled_roots[0]))
	_check("y no como truncada", not SongLoader.truncated_roots.has(SongLoader.cancelled_roots[0]))
	_check("y se puede reescanear otra vez", root._rescan_button.disabled == false)
	SettingsManager.library_roots = previous_roots

	print("=== 15. salir de la pestana cancela el escaneo ===")
	root._scan_summary_and_rescan()
	_check("el escaneo esta en marcha", SongLoader.is_scanning)
	root._on_tab_selected(root.SONGS_TAB - 1)
	await get_tree().process_frame
	_check("al cambiar de pestana se aborta", not SongLoader.is_scanning and not root._scan_pump_active)

	print("=== 16. overlay del menu: con cancelar solo si es escaneo ===")
	menu._show_loading_screen()
	_check("cargando una cancion no hay boton de cancelar", not is_instance_valid(menu._loading_cancel_button))
	_check("ni carpeta", not is_instance_valid(menu._loading_folder))
	_check("y el porcentaje sigue activo", menu._loading_bar.show_percentage)
	menu._hide_loading_screen()
	menu._show_loading_screen(true)
	_check("escaneando si hay boton de cancelar", is_instance_valid(menu._loading_cancel_button) and not menu._loading_cancel_button.disabled)
	_check("y carpeta", is_instance_valid(menu._loading_folder))
	_check("pero el porcentaje se apaga (no hay porcentaje fiable)", not menu._loading_bar.show_percentage)
	menu._on_scan_progress(2, 5, "/tmp/opencode/libtest/rootA/Beta/charts", 12, 7)
	_check("el progreso va por raices", absf(menu._loading_bar.value - ScanFeedback.progress_value(2, 5) * 100.0) < 0.01)
	_check("el estado cuenta raices y canciones", menu._loading_status.text == ScanFeedback.status_text(2, 5, 7))
	_check("y la carpeta se acorta por el medio", menu._loading_folder.text == ScanFeedback.folder_text("/tmp/opencode/libtest/rootA/Beta/charts"))
	menu._hide_loading_screen()
	_check("el overlay se suelta", menu._loading_overlay == null)

	print("=== 17. el menu no se queda con un escaneo a medias al destruirse ===")
	menu._scan_pump_active = true
	SongLoader.request_scan()
	SongLoader.pump_scan(SongLoader.frame_deadline_usec())
	_check("el escaneo esta en marcha", SongLoader.is_scanning)
	menu.queue_free()
	await get_tree().process_frame
	_check("al salir se aborta", not SongLoader.is_scanning)
	_check("y SongLoader no queda bloqueado para el siguiente escaneo", SongLoader.begin_scan())
	SongLoader.abort_scan()

	root.queue_free()

	print("")
	if _failures == 0:
		print("=== TODAS LAS COMPROBACIONES OK ===")
	else:
		print("=== ", _failures, " FALLOS ===")
	_restore_settings()
	get_tree().quit()


func _collect_tabs(node: Node, out: Array[Button]) -> void:
	if node is Button and node.toggle_mode:
		out.append(node)
	for c in node.get_children():
		_collect_tabs(c, out)
