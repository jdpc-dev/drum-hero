class_name MenuRoot
extends CanvasLayer

const BG_COLOR: Color = Palette.NIGHT_BG
const PADDING := 40.0
const BAR_HEIGHT := 70.0
const STATUS_HEIGHT := 45.0
const DIFF_HEIGHT := 55.0
const SONG_ROW_HEIGHT := 40.0
const DRAG_THRESHOLD := 8.0
const DIFFICULTY_OFFSETS := [60, 72, 84, 96, 120]
const DIFFICULTY_NAMES := {60: "Easy", 72: "Medium", 84: "Hard", 96: "Expert", 120: "Expert+"}

var _selected_song_index: int = -1
var _filtered_indices: Array[int] = []
var _search_text: String = ""
var _back_press_time: float = 0.0
var _back_cooldown: float = 2.0
var _back_handled_time: float = 0.0

var _root: VBoxContainer
var _header_bar: PanelContainer
var _search_input: LineEdit
var _song_list_scroll: ScrollContainer
var _song_list_container: VBoxContainer
var _status_label: Label
var _diff_container: HBoxContainer
var _settings_button: Button
var _difficulty_buttons: Dictionary = {}

var _loading_overlay: CanvasLayer
var _loading_bar: ProgressBar
var _loading_status: Label
var _loading_folder: Label
var _loading_cancel_button: Button
var _loading_is_scan: bool = false

var _scan_pump_active: bool = false

var _old_guitar_fallback: bool = false
var _old_menu_status: bool = false
var _old_library_state: Array = []
var _is_switching_scene: bool = false
var _row_dragging: bool = false
var _row_drag_start: Vector2 = Vector2.ZERO

var _album_art: TextureRect
var _preview_player: AudioStreamPlayer
var _preview_song_path: String = ""
var _preview_loaded_stream: AudioStream = null
var _preview_status_label: Label

const PREVIEW_STEM_NAMES := ["drums", "bass", "guitar", "keys", "rhythm", "vocals"]
var _preview_stem_paths: Array[String] = []
var _preview_stem_streams: Dictionary = {}
var _preview_stem_players: Array[AudioStreamPlayer] = []
var _preview_stem_thread: Thread
var _preview_stem_load_done: bool = false
var _preview_stem_load_result: Dictionary = {}

const PREVIEW_ANIM_FRAMES := [".", "..", "..."]
const PREVIEW_ANIM_INTERVAL := 0.3
const PREVIEW_ANIM_DELAY := 1.5
const PREVIEW_MAX_DURATION := 30.0
const PREVIEW_FADE_IN_DURATION := 1.5
const PREVIEW_FADE_OUT_DURATION := 1.0
const PREVIEW_CACHE_MAX := 5
const PREVIEW_LOAD_TIMEOUT := 5.0
var _preview_anim_frame: int = 0
var _preview_anim_timer: float = 0.0
var _preview_anim_delay: float = 0.0
var _preview_animating: bool = false
var _preview_pending_index: int = -1
var _preview_pending_path: String = ""
var _preview_needs_load: bool = false
var _preview_elapsed: float = 0.0
var _preview_load_timeout: float = 0.0
var _preview_cache: Dictionary = {}
var _preview_cache_order: Array[String] = []
var _preview_thread: Thread
var _preview_load_result: AudioStream = null
var _preview_load_done: bool = false
var _preview_fade_tween: Tween
var _preview_fading_out: bool = false


func _ready() -> void:
	GameManager.set_state(GameManager.GameState.MENU)
	get_tree().auto_accept_quit = false
	# El setlist se reconstruye al volver del gameplay: recuperar la busqueda
	# antes de montar la UI para que el LineEdit y el filtro nazcan ya llenos.
	# La cancion seleccionada se restaura despues, cuando ya existen las filas.
	_search_text = GameManager.menu_search_text
	_preview_player = AudioStreamPlayer.new()
	_preview_player.name = "PreviewPlayer"
	_preview_player.bus = "Music"
	add_child(_preview_player)
	SongLoader.scan_progress.connect(_on_scan_progress)
	_build_ui()
	_rebuild_filtered_list()
	_restore_selected_song()
	_restore_scroll_position()
	if SongLoader.song_list.is_empty():
		_show_loading_screen()
		call_deferred("_refresh_song_list")
	elif _selected_song_index >= 0:
		_update_status_for_song(_selected_song_index)
	else:
		_update_status_text()
	_update_difficulty_visibility()
	_update_selection_ui()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back_handled_time = Time.get_ticks_msec() / 1000.0
		if not _settings_is_open():
			_handle_back()
		get_viewport().set_input_as_handled()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()


func _exit_tree() -> void:
	_save_menu_state()
	_stop_preview()
	_abort_scan()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _settings_is_open():
			return
		var now: float = Time.get_ticks_msec() / 1000.0
		if now - _back_handled_time < 0.5:
			return
		_handle_back()


func _process(delta: float) -> void:
	if _preview_animating:
		_preview_anim_timer += delta
		if _preview_anim_timer >= PREVIEW_ANIM_INTERVAL:
			_preview_anim_timer -= PREVIEW_ANIM_INTERVAL
			_preview_anim_frame = (_preview_anim_frame + 1) % PREVIEW_ANIM_FRAMES.size()
			_preview_status_label.text = PREVIEW_ANIM_FRAMES[_preview_anim_frame]
		if _preview_needs_load:
			_preview_needs_load = false
			_preview_loaded_stream = _get_cached_stream(_preview_pending_path)
			if not _preview_loaded_stream:
				if OS.get_name() == "Android":
					_preview_loaded_stream = AudioManager._load_audio_stream(_preview_pending_path)
					if _preview_loaded_stream:
						_cache_stream(_preview_pending_path, _preview_loaded_stream)
					if _preview_loaded_stream and _preview_anim_delay > PREVIEW_ANIM_INTERVAL:
						_preview_anim_delay = PREVIEW_ANIM_INTERVAL
				else:
					_preview_load_result = null
					_preview_load_done = false
					_preview_thread = Thread.new()
					_preview_thread.start(_preview_load_func.bind(_preview_pending_path))
		if _preview_load_done:
			_preview_loaded_stream = _preview_load_result
			_preview_load_done = false
			if _preview_thread:
				_preview_thread.wait_to_finish()
				_preview_thread = null
			if _preview_loaded_stream:
				_cache_stream(_preview_pending_path, _preview_loaded_stream)
			if _preview_loaded_stream and _preview_anim_delay > PREVIEW_ANIM_INTERVAL:
				_preview_anim_delay = PREVIEW_ANIM_INTERVAL
		_preview_anim_delay -= delta
		if _preview_anim_delay <= 0.0:
			if _preview_loaded_stream:
				_preview_animating = false
				_play_preview(_preview_pending_index)
			else:
				_preview_load_timeout -= delta
				if _preview_load_timeout <= 0.0:
					_preview_animating = false
					_preview_status_label.text = "Preview unavailable"
				else:
					_preview_anim_delay = 0.0
	if _preview_player.playing:
		_preview_elapsed += delta
		if _preview_elapsed >= PREVIEW_MAX_DURATION - PREVIEW_FADE_OUT_DURATION and not _preview_fading_out:
			_start_preview_fade_out()
		if _preview_stem_load_done and not _preview_stem_load_result.is_empty():
			_preview_stem_load_done = false
			if _preview_stem_thread and _preview_stem_thread.is_started():
				_preview_stem_thread.wait_to_finish()
				_preview_stem_thread = null
			for path in _preview_stem_load_result:
				var stream: AudioStream = _preview_stem_load_result[path]
				if not stream:
					continue
				var current_pos: float = _preview_player.get_playback_position()
				var player := AudioStreamPlayer.new()
				player.stream = stream
				player.bus = "Music"
				player.volume_db = linear_to_db(SettingsManager.preview_volume)
				add_child(player)
				player.play(current_pos)
				_preview_stem_players.append(player)
				if _preview_elapsed < PREVIEW_FADE_IN_DURATION:
					player.volume_db = _preview_player.volume_db
					var remaining_fade_in: float = PREVIEW_FADE_IN_DURATION - _preview_elapsed
					var fade_tween := create_tween()
					fade_tween.tween_property(player, "volume_db", linear_to_db(SettingsManager.preview_volume), remaining_fade_in).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
			_preview_stem_load_result = {}
	if _scan_pump_active:
		_pump_scan()


# El escaneo de la biblioteca avanza desde aqui y no desde un await: asi el menu
# puede desaparecer en mitad de un lote sin dejar SongLoader colgado con
# is_scanning = true, que bloquearia el siguiente escaneo para siempre.
func _pump_scan() -> void:
	if SongLoader.pump_scan(SongLoader.frame_deadline_usec()):
		_finish_song_list_refresh()


func _abort_scan() -> void:
	_scan_pump_active = false
	SongLoader.abort_scan()


func _on_scan_progress(root_index: int, root_total: int, current_dir: String, _dirs_visited: int, songs_found: int) -> void:
	# Los eventos llegan a todo el mundo porque SongLoader es singleton: solo
	# pinta el overlay cuando lo que hay en pantalla es un escaneo y no la
	# carga de una cancion.
	if not _loading_is_scan or not is_instance_valid(_loading_status):
		return
	if is_instance_valid(_loading_bar):
		_loading_bar.value = ScanFeedback.progress_value(root_index, root_total) * 100.0
	_loading_status.text = ScanFeedback.status_text(root_index, root_total, songs_found)
	if is_instance_valid(_loading_folder):
		_loading_folder.text = ScanFeedback.folder_text(current_dir)


func _on_cancel_scan_pressed() -> void:
	if not SongLoader.is_scanning:
		return
	SongLoader.cancel_scan()
	if is_instance_valid(_loading_status):
		_loading_status.text = "Cancelling..."


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_root = VBoxContainer.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.offset_left = PADDING
	_root.offset_right = -PADDING
	_root.offset_top = PADDING
	_root.offset_bottom = 0.0
	add_child(_root)

	_build_header_bar()
	_build_song_list()
	_build_difficulty_bar()
	_build_status_bar()
	_build_preview_status()
	_apply_status_visibility()


func _build_header_bar() -> void:
	_header_bar = PanelContainer.new()
	_header_bar.name = "HeaderBar"
	_header_bar.custom_minimum_size.y = BAR_HEIGHT
	_header_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.NIGHT_PANEL
	sb.set_content_margin_all(0)
	_header_bar.add_theme_stylebox_override("panel", sb)
	_root.add_child(_header_bar)

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 0)
	_header_bar.add_child(hbox)

	_album_art = TextureRect.new()
	_album_art.name = "AlbumArt"
	_album_art.custom_minimum_size = Vector2(70, 70)
	_album_art.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_album_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_album_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	hbox.add_child(_album_art)

	var search_input := LineEdit.new()
	search_input.placeholder_text = "Search: "
	search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_input.size_flags_vertical = Control.SIZE_EXPAND_FILL
	search_input.add_theme_font_size_override("font_size", 20)
	search_input.text = _search_text
	search_input.caret_column = search_input.text.length()
	search_input.text_changed.connect(_on_search_changed)
	var search_sb := StyleBoxFlat.new()
	search_sb.bg_color = Palette.NIGHT_ROW
	search_sb.set_content_margin_all(0)
	search_sb.content_margin_left = 16
	search_input.add_theme_stylebox_override("normal", search_sb)
	search_input.add_theme_stylebox_override("focus", search_sb)
	hbox.add_child(search_input)
	_search_input = search_input

	_settings_button = Button.new()
	_settings_button.text = "Settings"
	_settings_button.custom_minimum_size = Vector2(120, 0)
	_settings_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_settings_button.pressed.connect(_on_settings_pressed)
	hbox.add_child(_settings_button)

func _build_song_list() -> void:
	_song_list_scroll = ScrollContainer.new()
	_song_list_scroll.name = "SongListScroll"
	_song_list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_song_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_song_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_song_list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_song_list_scroll.follow_focus = true
	_root.add_child(_song_list_scroll)

	_song_list_container = VBoxContainer.new()
	_song_list_container.name = "SongListContainer"
	_song_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_song_list_scroll.add_child(_song_list_container)


func _build_status_bar() -> void:
	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.custom_minimum_size.y = STATUS_HEIGHT
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Palette.ASH)
	_status_label.text = "Select a song"
	_root.add_child(_status_label)


func _apply_status_visibility() -> void:
	if not is_instance_valid(_status_label):
		return
	if SettingsManager.show_menu_status:
		_status_label.visible = true
		_status_label.custom_minimum_size.y = STATUS_HEIGHT
	else:
		_status_label.visible = false
		_status_label.custom_minimum_size.y = 0


func _show_transient_status(text: String) -> void:
	if not is_instance_valid(_status_label):
		return
	_status_label.text = text
	_status_label.visible = true
	_status_label.custom_minimum_size.y = STATUS_HEIGHT


func _build_preview_status() -> void:
	_preview_status_label = Label.new()
	_preview_status_label.name = "PreviewStatusLabel"
	_preview_status_label.custom_minimum_size.y = 28
	_preview_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_preview_status_label.add_theme_font_size_override("font_size", 16)
	_preview_status_label.add_theme_color_override("font_color", Palette.BLOOD_BRIGHT)
	_root.add_child(_preview_status_label)
	_update_preview_idle_text()


func _update_preview_idle_text() -> void:
	if not is_instance_valid(_preview_status_label):
		return
	if _preview_animating or _preview_player.playing:
		return
	if SongLoader.song_list.size() > 0:
		_preview_status_label.text = "♫  Tap a song to preview"
	else:
		_preview_status_label.text = ""


func _build_difficulty_bar() -> void:
	_diff_container = HBoxContainer.new()
	_diff_container.name = "DiffContainer"
	_diff_container.custom_minimum_size.y = DIFF_HEIGHT
	_diff_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_diff_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_diff_container.add_theme_constant_override("separation", 20)
	_root.add_child(_diff_container)

	for off in DIFFICULTY_OFFSETS:
		var btn := Button.new()
		btn.text = DIFFICULTY_NAMES[off]
		btn.custom_minimum_size = Vector2(140, 40)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.disabled = true
		btn.pressed.connect(_on_difficulty_pressed.bind(off))
		_diff_container.add_child(btn)
		_difficulty_buttons[off] = btn


func _rebuild_filtered_list() -> void:
	_filtered_indices.clear()
	for i in SongLoader.song_list.size():
		if _search_text.is_empty():
			_filtered_indices.append(i)
		else:
			var song: Dictionary = SongLoader.song_list[i]
			var label_text: String = (song.artist + " - " + song.name).to_lower()
			if _search_text.to_lower() in label_text:
				_filtered_indices.append(i)
	_rebuild_song_rows()


func _rebuild_song_rows() -> void:
	for child in _song_list_container.get_children():
		child.queue_free()

	if _filtered_indices.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No songs found" if not _search_text.is_empty() else "Put songs in: " + SongLoader.get_user_song_dir()
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 20)
		empty_label.add_theme_color_override("font_color", Palette.MUTED)
		empty_label.custom_minimum_size = Vector2(0, 60)
		_song_list_container.add_child(empty_label)
		return

	for fi in _filtered_indices:
		var song: Dictionary = SongLoader.song_list[fi]
		var row := _create_song_row(fi, song)
		_song_list_container.add_child(row)


func _format_duration(ms: int) -> String:
	if ms <= 0:
		return "--:--"
	var total_seconds: int = ms / 1000
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]


func _create_song_row(original_index: int, song: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, SONG_ROW_HEIGHT)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.name = "SongRow_" + str(original_index)

	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = Palette.NIGHT_ROW
	sb_normal.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb_normal)

	var sb_hover := StyleBoxFlat.new()
	sb_hover.bg_color = Palette.NIGHT_ROW_HOVER
	sb_hover.set_content_margin_all(10)
	panel.add_theme_stylebox_override("hover", sb_hover)

	var sb_pressed := StyleBoxFlat.new()
	sb_pressed.bg_color = Palette.NIGHT_ROW_PRESSED
	sb_pressed.set_content_margin_all(10)
	panel.add_theme_stylebox_override("pressed", sb_pressed)

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	var selector_label := Label.new()
	selector_label.text = "  "
	selector_label.add_theme_font_size_override("font_size", 20)
	selector_label.add_theme_color_override("font_color", Palette.BLOOD_BRIGHT)
	hbox.add_child(selector_label)

	var song_length: int = int(song.get("song_length", 0))
	var prefix: String = (_format_duration(song_length) + " ") if song_length > 0 else ""
	var song_label := Label.new()
	song_label.text = prefix + song.artist + " - " + song.name
	song_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	song_label.add_theme_font_size_override("font_size", 20)
	song_label.add_theme_color_override("font_color", Palette.BONE)
	hbox.add_child(song_label)

	# Mejor score de la cancion entre las dificultades que ofrece su chart; el
	# placeholder "--,---pts" se mantiene si todavia no hay ningun record.
	var best: int = HighScoreStore.get_best_for_song(song.path, song.get("difficulties", []).map(func(d: Dictionary) -> int: return d.offset))
	var score_label := Label.new()
	score_label.text = (ScoreData.format_score(best) + "pts") if best > 0 else "--,---pts"
	score_label.add_theme_font_size_override("font_size", 18)
	score_label.add_theme_color_override("font_color", Palette.ASH)
	hbox.add_child(score_label)

	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.gui_input.connect(_on_song_row_input.bind(original_index))
	return panel


func _on_song_row_input(event: InputEvent, original_index: int) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_row_dragging = false
			_row_drag_start = event.position
		elif not _row_dragging:
			_select_song(original_index)
	elif event is InputEventScreenDrag:
		if event.position.distance_to(_row_drag_start) > DRAG_THRESHOLD:
			_row_dragging = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_row_dragging = false
			_row_drag_start = event.position
		elif not _row_dragging:
			_select_song(original_index)
	elif event is InputEventMouseMotion and event.button_mask == MOUSE_BUTTON_MASK_LEFT:
		if event.position.distance_to(_row_drag_start) > DRAG_THRESHOLD:
			_row_dragging = true


func _select_song(original_index: int) -> void:
	if original_index == _selected_song_index:
		return
	_selected_song_index = original_index
	_update_selection_ui()
	_update_status_for_song(original_index)
	_update_difficulty_visibility()
	_load_album_art(original_index)
	_start_preview_animation(original_index)


func _load_album_art(index: int) -> void:
	if index < 0 or index >= SongLoader.song_list.size():
		_album_art.texture = null
		return
	var song: Dictionary = SongLoader.song_list[index]
	var album_path: String = song.get("album_path", "")
	if album_path.is_empty():
		_album_art.texture = null
		return
	var tex: Texture2D = ResourceLoader.load(album_path)
	if tex == null:
		tex = _load_external_texture(album_path)
	_album_art.texture = tex


func _load_external_texture(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _update_selection_ui() -> void:
	for i in _song_list_container.get_child_count():
		var row = _song_list_container.get_child(i)
		if not row is PanelContainer:
			continue
		var hbox = row.get_child(0)
		if not hbox is HBoxContainer:
			continue
		var selector = hbox.get_child(0)
		if not selector is Label:
			continue
		var original_index: int = int(row.name.replace("SongRow_", ""))
		if original_index == _selected_song_index:
			selector.text = "► "
		else:
			selector.text = "  "


func _update_status_for_song(original_index: int) -> void:
	if original_index < 0 or original_index >= SongLoader.song_list.size():
		_status_label.text = "Select a song"
		_apply_status_visibility()
		return
	var song: Dictionary = SongLoader.song_list[original_index]
	var parts: Array[String] = []
	if not song.notes_path.is_empty():
		parts.append("chart OK")
	else:
		parts.append("missing notes.mid")
	if SongLoader.get_stem_path(song.path, "song").is_empty():
		parts.append("missing audio")
	else:
		parts.append("audio OK")
	if not song.get("has_drum_chart", true):
		if song.get("guitar_fallback_used", false):
			parts.append("using guitar chart")
		else:
			parts.append("no drum chart")
	_status_label.text = "STATUS: " + " - ".join(parts)
	_apply_status_visibility()


func _update_status_text() -> void:
	if SongLoader.song_list.size() > 0:
		var roots: PackedStringArray = SongLoader.get_scan_roots()
		_status_label.text = str(SongLoader.song_list.size()) + " songs found from " + str(roots.size()) + " location(s)"
	else:
		_status_label.text = ""
	_apply_status_visibility()
	_update_preview_idle_text()


func _update_difficulty_visibility() -> void:
	var available_offsets: Dictionary = {}
	if _selected_song_index >= 0 and _selected_song_index < SongLoader.song_list.size():
		var song: Dictionary = SongLoader.song_list[_selected_song_index]
		var difficulties: Array = song.get("difficulties", [])
		for diff in difficulties:
			available_offsets[diff.offset] = true
	for off in DIFFICULTY_OFFSETS:
		var btn: Button = _difficulty_buttons.get(off)
		if btn:
			btn.disabled = not available_offsets.has(off)


func _on_difficulty_pressed(offset: int) -> void:
	if _selected_song_index < 0 or _selected_song_index >= SongLoader.song_list.size():
		_show_transient_status("Select a song first")
		return
	var song: Dictionary = SongLoader.song_list[_selected_song_index]
	var difficulties: Array = song.get("difficulties", [])
	var found: Dictionary = {}
	for diff in difficulties:
		if diff.offset == offset:
			found = diff
			break
	if found.is_empty():
		return
	# Guardar antes de cambiar de escena: al volver, el setlist debe conservar
	# la busqueda, el scroll y la cancion seleccionada con la que el jugador
	# eligio la dificultad.
	_save_menu_state()
	_stop_preview()
	_show_loading_screen()
	_update_loading(0.0, "Loading " + found.name + "...")
	GameManager.current_song_path = song.path
	GameManager.current_song_title = song.name
	GameManager.current_song_artist = song.artist
	GameManager.current_difficulty_offset = found.offset
	GameManager.current_difficulty_name = found.name
	GameManager.current_song_delay = float(song.get("delay", 0))
	GameManager.current_song_length = float(song.get("song_length", 0)) / 1000.0
	get_tree().change_scene_to_file("res://scene/Gameplay.tscn")

func _on_search_changed(new_text: String) -> void:
	_search_text = new_text
	_selected_song_index = -1
	_stop_preview()
	_update_difficulty_visibility()
	_rebuild_filtered_list()


func _save_menu_state() -> void:
	GameManager.menu_search_text = _search_text
	GameManager.menu_selected_song_path = ""
	if _selected_song_index >= 0 and _selected_song_index < SongLoader.song_list.size():
		GameManager.menu_selected_song_path = SongLoader.song_list[_selected_song_index].path
	if is_instance_valid(_song_list_scroll):
		GameManager.menu_scroll_position = _song_list_scroll.scroll_vertical


func _restore_selected_song() -> void:
	var selected_path: String = GameManager.menu_selected_song_path
	if selected_path.is_empty():
		return
	for i in SongLoader.song_list.size():
		if SongLoader.song_list[i].path != selected_path:
			continue
		# Si el filtro actual ya no la muestra, no se restaura una seleccion
		# invisible: el estado guardado siempre deberia ser coherente, pero una
		# biblioteca reescaneada puede haber cambiado entre medias.
		if not _filtered_indices.has(i):
			return
		# Se restaura la seleccion y se relanza su preview: al volver del
		# gameplay el jugador debe recuperar el mismo contexto sonoro.
		_selected_song_index = i
		_load_album_art(i)
		_start_preview_animation(i)
		return


func _restore_scroll_position() -> void:
	var target: int = GameManager.menu_scroll_position
	if target <= 0 or not is_instance_valid(_song_list_scroll):
		return
	var saved_search: String = _search_text
	# Las filas se acaban de crear: el ScrollContainer aun no conoce la altura
	# real de su contenido. Se reintenta unos frames hasta que el valor quede
	# aplicado (o el layout lo limite al maximo disponible).
	for _i in 3:
		await get_tree().process_frame
		if not is_instance_valid(_song_list_scroll) or _search_text != saved_search:
			return
		_song_list_scroll.scroll_vertical = target
		if _song_list_scroll.scroll_vertical == target:
			return


func _refresh_song_list() -> void:
	if _scan_pump_active:
		return
	_scan_pump_active = true
	_show_loading_screen(true)
	_update_loading(0.0, "Scanning songs...")
	SongLoader.request_scan()
	_pump_scan()


func _finish_song_list_refresh() -> void:
	_scan_pump_active = false
	var kept: int = SongLoader.song_list.size()
	# Se lee de SongLoader y no de un flag propio: pump_scan() puede encadenar el
	# reescaneo encolado en la misma llamada, y un flag propio se quedaria con el
	# resultado del escaneo anterior.
	var final_text: String = ScanFeedback.cancelled_text(kept) if not SongLoader.cancelled_roots.is_empty() else ScanFeedback.finished_text(kept)
	_update_loading(1.0, final_text)
	_update_status_text()
	_rebuild_filtered_list()
	_update_difficulty_visibility()
	_update_selection_ui()
	_hide_loading_screen()
	if not SongLoader.cancelled_roots.is_empty():
		_show_transient_status(final_text)


func _show_loading_screen(allow_cancel: bool = false) -> void:
	if _loading_overlay:
		return
	_loading_overlay = CanvasLayer.new()
	_loading_overlay.name = "LoadingOverlay"
	_loading_overlay.layer = 20
	_loading_is_scan = allow_cancel

	var bg := ColorRect.new()
	bg.color = Palette.SCRIM_STRONG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_overlay.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -160
	vbox.offset_top = -100
	vbox.offset_right = 160
	vbox.offset_bottom = 100
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_loading_overlay.add_child(vbox)

	var title := Label.new()
	title.text = "LOADING"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Palette.BONE)
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer)

	_loading_status = Label.new()
	_loading_status.text = ""
	_loading_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_status.add_theme_font_size_override("font_size", 18)
	_loading_status.add_theme_color_override("font_color", Palette.CHROME)
	vbox.add_child(_loading_status)

	if allow_cancel:
		# La carpeta en la que se esta metiendo el escaneo: en una biblioteca
		# grande es lo unico que dice si sigue avanzando o si se ha quedado
		# atascado en un arbol lento.
		_loading_folder = ScanFeedback.make_folder_label()
		_loading_folder.custom_minimum_size = Vector2(300, 20)
		vbox.add_child(_loading_folder)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 15)
	vbox.add_child(spacer2)

	_loading_bar = ProgressBar.new()
	_loading_bar.custom_minimum_size = Vector2(300, 25)
	# El escaneo no puede prometer porcentaje, pero la carga de una cancion si
	# tiene etapas reales.
	_loading_bar.show_percentage = not allow_cancel
	_loading_bar.value = 0
	vbox.add_child(_loading_bar)

	if allow_cancel:
		_loading_cancel_button = Button.new()
		_loading_cancel_button.text = "Cancel"
		_loading_cancel_button.custom_minimum_size = Vector2(140, 40)
		_loading_cancel_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_loading_cancel_button.pressed.connect(_on_cancel_scan_pressed)
		vbox.add_child(_loading_cancel_button)

	add_child(_loading_overlay)


func _update_loading(progress: float, status: String) -> void:
	if _loading_bar:
		_loading_bar.value = progress * 100.0
	if _loading_status:
		_loading_status.text = status


func _hide_loading_screen() -> void:
	if _loading_overlay:
		_loading_overlay.queue_free()
	_loading_overlay = null
	_loading_bar = null
	_loading_status = null
	_loading_folder = null
	_loading_cancel_button = null
	_loading_is_scan = false


func _resolve_preview_path(song: Dictionary) -> String:
	var preview_path: String = song.get("preview_path", "")
	if not preview_path.is_empty():
		if OS.get_name() != "Android" or not preview_path.ends_with(".opus"):
			return preview_path
	return SongLoader.get_stem_path(song.path, "song")


func _start_preview_animation(original_index: int) -> void:
	_stop_preview()
	if original_index < 0 or original_index >= SongLoader.song_list.size():
		return
	var song: Dictionary = SongLoader.song_list[original_index]
	var preview_path: String = _resolve_preview_path(song)
	if preview_path.is_empty():
		return
	_preview_pending_index = original_index
	_preview_pending_path = preview_path
	_preview_needs_load = true
	_preview_loaded_stream = null
	_preview_animating = true
	_preview_anim_frame = 0
	_preview_anim_timer = 0.0
	_preview_anim_delay = PREVIEW_ANIM_DELAY
	_preview_load_timeout = PREVIEW_LOAD_TIMEOUT
	_preview_status_label.text = PREVIEW_ANIM_FRAMES[0]
	var song_preview_path: String = song.get("preview_path", "")
	if song_preview_path.is_empty():
		_preview_stem_paths.clear()
		for stem in PREVIEW_STEM_NAMES:
			var stem_path: String = SongLoader.get_stem_path(song.path, stem)
			if not stem_path.is_empty():
				_preview_stem_paths.append(stem_path)


func _play_preview(original_index: int) -> void:
	if original_index < 0 or original_index >= SongLoader.song_list.size():
		_preview_status_label.text = ""
		return
	var song: Dictionary = SongLoader.song_list[original_index]
	if not _preview_loaded_stream:
		_preview_status_label.text = ""
		return
	if _preview_player.playing:
		_preview_player.stop()
	if _preview_fade_tween:
		_preview_fade_tween.kill()
		_preview_fade_tween = null
	_preview_fading_out = false
	_preview_song_path = song.path
	_preview_player.stream = _preview_loaded_stream
	_preview_player.volume_db = -60.0
	_preview_elapsed = 0.0
	var preview_path: String = song.get("preview_path", "")
	if preview_path.is_empty():
		var start_time: int = song.get("preview_start_time", -1)
		var seek_pos: float = 30.0 if start_time < 0 else float(start_time) / 1000.0
		_preview_player.play(seek_pos)
		if not _preview_stem_paths.is_empty():
			_preview_stem_load_done = false
			_preview_stem_load_result = {}
			if OS.get_name() == "Android":
				_preview_load_stems_func(_preview_stem_paths)
			else:
				_preview_stem_thread = Thread.new()
				_preview_stem_thread.start(_preview_load_stems_func.bind(_preview_stem_paths.duplicate()))
	else:
		_preview_player.play()
	_preview_fade_tween = create_tween()
	_preview_fade_tween.tween_property(_preview_player, "volume_db", linear_to_db(SettingsManager.preview_volume), PREVIEW_FADE_IN_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_preview_status_label.text = "♫  " + song.artist + " - " + song.name


func _stop_preview() -> void:
	if _preview_fade_tween:
		_preview_fade_tween.kill()
		_preview_fade_tween = null
	_preview_fading_out = false
	_preview_animating = false
	_preview_pending_index = -1
	_preview_pending_path = ""
	_preview_needs_load = false
	_preview_loaded_stream = null
	if _preview_thread and _preview_thread.is_started():
		_preview_thread.wait_to_finish()
		_preview_thread = null
	_preview_load_result = null
	_preview_load_done = false
	if _preview_player.playing:
		_preview_player.stop()
	_preview_player.stream = null
	for player in _preview_stem_players:
		if player.playing:
			player.stop()
		remove_child(player)
		player.queue_free()
	_preview_stem_players.clear()
	_preview_stem_paths.clear()
	_preview_stem_streams.clear()
	_preview_stem_load_result = {}
	_preview_stem_load_done = false
	if _preview_stem_thread and _preview_stem_thread.is_started():
		_preview_stem_thread.wait_to_finish()
		_preview_stem_thread = null
	_preview_song_path = ""
	_preview_elapsed = 0.0
	_update_preview_idle_text()


func _start_preview_fade_out() -> void:
	if _preview_fading_out:
		return
	_preview_fading_out = true
	if _preview_fade_tween:
		_preview_fade_tween.kill()
	_preview_fade_tween = create_tween()
	_preview_fade_tween.set_parallel()
	_preview_fade_tween.tween_property(_preview_player, "volume_db", -80.0, PREVIEW_FADE_OUT_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	for player in _preview_stem_players:
		_preview_fade_tween.tween_property(player, "volume_db", -80.0, PREVIEW_FADE_OUT_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	_preview_fade_tween.finished.connect(_on_preview_fade_out_finished)


func _on_preview_fade_out_finished() -> void:
	if not _preview_fading_out:
		return
	_preview_fading_out = false
	_preview_status_label.text = "Preview ended"
	_stop_preview()


func _preview_load_func(path: String) -> void:
	_preview_load_result = AudioManager._load_audio_stream(path)
	_preview_load_done = true


func _preview_load_stems_func(paths: Array[String]) -> void:
	var results: Dictionary = {}
	for path in paths:
		results[path] = AudioManager._load_audio_stream(path)
	_preview_stem_load_result = results
	_preview_stem_load_done = true


func _get_cached_stream(path: String) -> AudioStream:
	if _preview_cache.has(path):
		_preview_cache_order.erase(path)
		_preview_cache_order.append(path)
		return _preview_cache[path]
	return null


func _cache_stream(path: String, stream: AudioStream) -> void:
	if _preview_cache.has(path):
		return
	if _preview_cache_order.size() >= PREVIEW_CACHE_MAX:
		var old_path: String = _preview_cache_order.pop_front()
		_preview_cache.erase(old_path)
	_preview_cache[path] = stream
	_preview_cache_order.append(path)


func _handle_back() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _back_press_time < _back_cooldown:
		_show_transient_status("Closing...")
		get_tree().quit()
	else:
		_back_press_time = now
		_show_transient_status("Press again to exit")


func _settings_is_open() -> bool:
	for child in get_children():
		if child is SettingsRoot:
			return true
	return false


func _on_settings_pressed() -> void:
	if _settings_is_open():
		return
	_old_guitar_fallback = SettingsManager.use_guitar_fallback
	_old_menu_status = SettingsManager.show_menu_status
	_old_library_state = [
		SettingsManager.library_roots,
		SettingsManager.library_preset_downloads,
		SettingsManager.library_preset_documents,
		SettingsManager.library_recursive,
		SettingsManager.library_max_depth,
	]
	_root.hide()
	var settings := preload("res://scene/Settings.tscn").instantiate() as SettingsRoot
	settings.tree_exited.connect(_on_settings_closed)
	settings.free_mode_requested.connect(_on_free_mode_requested)
	add_child(settings)


# El panel de Ajustes pide abrir el modo libre y es este menu quien hace el
# cambio de escena: el panel vive como hijo de MenuRoot, no es una escena.
func _on_free_mode_requested() -> void:
	_stop_preview()
	_is_switching_scene = true
	get_tree().change_scene_to_file("res://scene/FreeMode.tscn")


# Al cambiar de escena el menu se desmonta con el panel de Ajustes dentro, asi
# que su tree_exited se dispara durante la destruccion: seguir reacting ahi
# lanzaria un escaneo de la biblioteca mientras el arbol ya se esta tirando.
func _on_settings_closed() -> void:
	if _is_switching_scene or not is_inside_tree():
		return
	if SettingsManager.use_guitar_fallback != _old_guitar_fallback or _library_changed():
		_refresh_song_list()
	if SettingsManager.show_menu_status != _old_menu_status:
		_apply_status_visibility()
	_root.show()


func _library_changed() -> bool:
	var current := [
		SettingsManager.library_roots,
		SettingsManager.library_preset_downloads,
		SettingsManager.library_preset_documents,
		SettingsManager.library_recursive,
		SettingsManager.library_max_depth,
	]
	if current == _old_library_state:
		return false
	_old_library_state = current
	return true
