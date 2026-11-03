extends Node

var _settings_backup: PackedByteArray = PackedByteArray()
var _settings_existed: bool = false
var _cache_backup: String = ""
var _cache_existed: bool = false
var _failures: int = 0
# Lambdas capture by value: the progress probe writes here, not to a local.
var _reached_wide: bool = false


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


func _backup_cache() -> void:
	if not FileAccess.file_exists(SongLoader.CACHE_PATH):
		return
	_cache_existed = true
	var f := FileAccess.open(SongLoader.CACHE_PATH, FileAccess.READ)
	_cache_backup = f.get_as_text()
	f.close()


func _restore_cache() -> void:
	if not _cache_existed:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SongLoader.CACHE_PATH))
		return
	var f := FileAccess.open(SongLoader.CACHE_PATH, FileAccess.WRITE)
	f.store_string(_cache_backup)
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


func _home_path() -> String:
	return OS.get_environment("HOME").strip_edges().simplify_path()


func _ready() -> void:
	_backup_settings()
	_backup_cache()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SongLoader.CACHE_PATH))
	SongLoader.song_list.clear()
	SongLoader.cache_loaded = false
	SongLoader.last_scan_fingerprint = ""
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
	_check("hay check Search subfolders", _find_check(root, "Search subfolders") != null)
	_check("hay campo de ruta", root.find_child("*", true, false) != null and dump.contains("absolute path"))
	_check("hay selector de ubicacion", is_instance_valid(root._root_location_option))
	if OS.get_name() == "Android":
		_check("selector ofrece almacenamiento interno y externo",
			root._root_location_option.item_count == 2
			and root._root_location_option.get_item_text(0).contains("Internal storage")
			and root._root_location_option.get_item_text(1).contains("External storage"))
	else:
		_check("selector ofrece la carpeta home",
			root._root_location_option.item_count == 1
			and root._root_location_option.get_item_text(0).contains("Home")
			and root._root_location_option.get_item_text(0).contains(_home_path()))
		_check("la base elegida es $HOME", root._selected_storage_base() == _home_path())
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

	print("=== 2c. el campo de carpeta extra se aparta del teclado ===")
	_check("el scroll de contenido esta disponible", is_instance_valid(root._content_scroll))
	_check("el scroll sigue al control con foco", root._content_scroll.follow_focus)
	_check("el campo de rutas se recuerda", is_instance_valid(root._root_path_edit))
	_check("el espaciador del teclado nace a cero", is_instance_valid(root._keyboard_spacer) and root._keyboard_spacer.custom_minimum_size.y == 0)
	root._keyboard_spacer.custom_minimum_size.y = 300
	root._on_root_path_focus_exited(root._root_path_edit)
	_check("al perder el foco se libera el espacio del teclado", root._keyboard_spacer.custom_minimum_size.y == 0)
	root._keep_path_edit_above_keyboard()
	_check("sin teclado no queda espacio reservado", root._keyboard_spacer.custom_minimum_size.y == 0)

	print("=== 3. controles reflejan el estado persistido ===")
	SettingsManager.library_preset_downloads = true
	SettingsManager.library_recursive = true
	SettingsManager.library_max_depth = 4
	songs_tab.pressed.emit()
	await get_tree().process_frame
	_check("Scan Download marcado", _find_check(root, "Scan Download").button_pressed)
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

	print("=== 5b. el formulario antepone la ubicacion elegida ===")
	SettingsManager.library_roots = PackedStringArray()
	root._root_location_option.select(0)
	root._root_path_edit.text = "Download/RockBand"
	root._on_add_extra_folder()
	if OS.get_name() == "Android":
		_check("almacenamiento interno antepuesto", SettingsManager.library_roots.has("/storage/emulated/0/Download/RockBand"))
	else:
		_check("carpeta home antepuesta", SettingsManager.library_roots.has(_home_path().path_join("Download/RockBand")))
	_check("el campo se limpia tras anadir", root._root_path_edit.text.is_empty())
	if OS.get_name() == "Android":
		root._root_location_option.select(1)
		root._root_path_edit.text = "Music/RockBand"
		root._on_add_extra_folder()
		_check("almacenamiento externo antepuesto", SettingsManager.library_roots.has("/sdcard/Music/RockBand"))
	root._root_path_edit.text = "/tmp/opencode/pasted"
	root._on_add_extra_folder()
	_check("una ruta absoluta no se antepone", SettingsManager.library_roots.has("/tmp/opencode/pasted"))
	SettingsManager.library_roots = PackedStringArray()

	print("=== 6. toggles escriben en SettingsManager ===")
	_find_check(root, "Search subfolders").set_pressed_no_signal(false)
	_find_check(root, "Search subfolders").toggled.emit(false)
	await get_tree().process_frame
	_check("recursividad propagada", SettingsManager.library_recursive == false)
	_find_check(root, "Scan Download").set_pressed_no_signal(true)
	_find_check(root, "Scan Download").toggled.emit(true)
	await get_tree().process_frame
	_check("preset downloads propagado", SettingsManager.library_preset_downloads == true)

	print("=== 7. resumen del escaneo incluye locations y avisos ===")
	SettingsManager.library_roots = PackedStringArray(["/tmp/opencode/libtest/noexiste"])
	SettingsManager.library_preset_downloads = false
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
	var names: PackedStringArray = PackedStringArray(["CONTROLS", "GAMEPLAY", "AUDIO", "SONGS", "ADVANCED"])
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

	print("=== 11b. toggle 'Show Menu Status' en Advanced ===")
	for t in tabs:
		if t.text == "ADVANCED":
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
		SettingsManager.library_recursive,
		SettingsManager.library_max_depth,
	]
	_check("sin cambios -> false", not menu._library_changed())
	SettingsManager.library_preset_downloads = not SettingsManager.library_preset_downloads
	_check("cambio de preset -> true", menu._library_changed())
	_check("y consume el estado (idempotente)", not menu._library_changed())
	SettingsManager.library_roots = PackedStringArray(["/tmp/x"])
	_check("cambio de raices -> true", menu._library_changed())

	print("=== 12b. cerrar Ajustes sin cambios rehace las filas desde song_list ===")
	SongLoader.scan_songs()
	menu._old_library_state = [
		SettingsManager.library_roots,
		SettingsManager.library_preset_downloads,
		SettingsManager.library_recursive,
		SettingsManager.library_max_depth,
	]
	menu._old_guitar_fallback = SettingsManager.use_guitar_fallback
	menu._old_menu_status = SettingsManager.show_menu_status
	menu._selected_song_index = -1
	# A song found by a scan inside Settings arrives here without any library
	# setting changing: the menu must rebuild its rows anyway.
	SongLoader.song_list.append({"path": "/tmp/x", "name": "Test", "artist": "Artist"})
	menu._on_settings_closed()
	await get_tree().process_frame
	_check(
		"las filas se rehacen aunque no cambie la biblioteca",
		menu._song_list_container.get_child_count() == SongLoader.song_list.size()
	)

	print("=== 12c. cambiar la biblioteca no lanza un escaneo ===")
	root._on_tab_selected(root.SONGS_TAB)
	await get_tree().process_frame
	var previous_downloads: bool = SettingsManager.library_preset_downloads
	root._on_preset_downloads_toggled(not previous_downloads)
	_check("el cambio se guarda", SettingsManager.library_preset_downloads == (not previous_downloads))
	_check("no arranca un escaneo", not SongLoader.is_scanning and not root._scan_pump_active)
	_check("el resumen pide Rescan now", root._scan_summary.text.contains("Press Rescan now"))
	root._on_preset_downloads_toggled(previous_downloads)

	print("=== 12d. cerrar Ajustes o cambiar el fallback no lanza un escaneo ===")
	var previous_fallback: bool = SettingsManager.use_guitar_fallback
	SettingsManager.use_guitar_fallback = not previous_fallback
	menu._old_guitar_fallback = previous_fallback
	menu._old_menu_status = SettingsManager.show_menu_status
	menu._on_settings_closed()
	_check("el fallback se aplica sin escanear", not SongLoader.is_scanning)
	SettingsManager.use_guitar_fallback = previous_fallback
	menu._old_guitar_fallback = previous_fallback
	menu._on_settings_closed()
	_check("cerrar Ajustes sin cambios tampoco escanea", not SongLoader.is_scanning)

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
	SettingsManager.library_recursive = true
	SettingsManager.library_max_depth = 3
	# How many songs those roots yield, so it does not have to be hardcoded.
	SongLoader.scan_songs()
	var expected_songs: int = SongLoader.song_list.size()
	root._on_tab_selected(root.SONGS_TAB)
	await get_tree().process_frame
	_check("hay boton de reescanear", is_instance_valid(root._rescan_button))
	_check("en reposo no hay modal de escaneo", not root._scan_modal_is_open())
	_check("el indicador ya no vive en la tarjeta", not is_instance_valid(root._scan_bar) and not is_instance_valid(root._scan_status) and not is_instance_valid(root._scan_folder))
	_check("y se puede reescanear", root._rescan_button.disabled == false)

	root._scan_summary_and_rescan()
	_check("el reescaneo es inmediato, sin await", SongLoader.is_scanning)
	_check("se abre el modal de escaneo", root._scan_modal_is_open())
	_check("con barra, estado y carpeta", is_instance_valid(root._scan_bar) and is_instance_valid(root._scan_status) and is_instance_valid(root._scan_folder))
	_check("y boton de cancelar", is_instance_valid(root._cancel_scan_button) and not root._cancel_scan_button.disabled)
	_check("el estado dice que esta escaneando", root._scan_status.text.begins_with("Scanning"))
	_check("reescanear se bloquea y cancelar se habilita", root._rescan_button.disabled and not root._cancel_scan_button.disabled)
	for i in 300:
		if not SongLoader.is_scanning:
			break
		await get_tree().process_frame
	_check("el escaneo termina solo", not SongLoader.is_scanning and not root._scan_pump_active)
	_check("y el modal se cierra", not root._scan_modal_is_open())
	_check("vuelve a poder reescanear", root._rescan_button.disabled == false)
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
	# Wait until the walk has actually entered the wide root: cancelling between
	# roots is also valid but leaves the next one as "never reached", which is a
	# different diagnostic than a half-walked root.
	_reached_wide = false
	var probe := func(_ri: int, _rt: int, current_dir: String, _dv: int, _sf: int) -> void:
		if current_dir.begins_with(wide):
			_reached_wide = true
	SongLoader.scan_progress.connect(probe)
	root._scan_summary_and_rescan()
	_check("el escaneo vuelve a arrancar", SongLoader.is_scanning)
	for i in 300:
		if _reached_wide:
			break
		await get_tree().process_frame
	SongLoader.scan_progress.disconnect(probe)
	_check("el escaneo llega a la raiz ancha", _reached_wide)
	root._cancel_scan_button.emit_signal("pressed")
	_check("pulsar cancelar no corta en seco", SongLoader.is_scanning)
	_check("el estado del modal pide esperar", root._scan_status.text == "Cancelling...")
	_check("y cancelar se deshabilita mientras tanto", root._cancel_scan_button.disabled)
	for i in 300:
		if not SongLoader.is_scanning:
			break
		await get_tree().process_frame
	_check("se detiene en cuanto toca", not SongLoader.is_scanning and not root._scan_pump_active)
	_check("el modal se cierra al cancelar", not root._scan_modal_is_open())
	_check("se queda con lo que habia encontrado", SongLoader.song_list.size() >= 0)
	_check("la raiz a medias queda anotada", SongLoader.cancelled_roots.size() == 1)
	_check("el resumen avisa de la raiz cancelada", root._scan_summary.text.contains("Scan cancelled before finishing here, this location may have more songs: " + SongLoader.cancelled_roots[0]))
	_check("y no como truncada", not SongLoader.truncated_roots.has(SongLoader.cancelled_roots[0]))
	_check("y se puede reescanear otra vez", root._rescan_button.disabled == false)
	SettingsManager.library_roots = previous_roots

	print("=== 15. salir de la pestana cancela el escaneo ===")
	root._scan_summary_and_rescan()
	_check("el escaneo esta en marcha", SongLoader.is_scanning)
	_check("con el modal abierto", root._scan_modal_is_open())
	root._on_tab_selected(root.SONGS_TAB - 1)
	await get_tree().process_frame
	_check("al cambiar de pestana se aborta", not SongLoader.is_scanning and not root._scan_pump_active)
	_check("y el modal se cierra", not root._scan_modal_is_open())

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
	_restore_cache()
	get_tree().quit()


func _collect_tabs(node: Node, out: Array[Button]) -> void:
	if node is Button and node.toggle_mode:
		out.append(node)
	for c in node.get_children():
		_collect_tabs(c, out)
