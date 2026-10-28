class_name MenuRoot
extends CanvasLayer

const BG_COLOR := Color(0.08, 0.08, 0.12)
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
var _song_list_scroll: ScrollContainer
var _song_list_container: VBoxContainer
var _status_label: Label
var _diff_container: HBoxContainer
var _settings_button: Button
var _difficulty_buttons: Dictionary = {}

var _loading_overlay: CanvasLayer
var _loading_bar: ProgressBar
var _loading_status: Label

var _row_dragging: bool = false
var _row_drag_start: Vector2 = Vector2.ZERO

var _preview_player: AudioStreamPlayer
var _preview_song_path: String = ""
var _preview_loaded_stream: AudioStream = null
var _preview_status_label: Label

const PREVIEW_ANIM_FRAMES := [".", "..", "..."]
const PREVIEW_ANIM_INTERVAL := 0.3
const PREVIEW_ANIM_DELAY := 1.5
const PREVIEW_MAX_DURATION := 30.0
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


func _ready() -> void:
	GameManager.set_state(GameManager.GameState.MENU)
	get_tree().auto_accept_quit = false
	_preview_player = AudioStreamPlayer.new()
	_preview_player.name = "PreviewPlayer"
	_preview_player.bus = "Music"
	add_child(_preview_player)
	_build_ui()
	_rebuild_filtered_list()
	if SongLoader.song_list.is_empty():
		_refresh_song_list()
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
	_stop_preview()


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
		if _preview_elapsed >= PREVIEW_MAX_DURATION:
			_stop_preview()
			_preview_status_label.text = "Preview ended"


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
	_root.offset_bottom = -PADDING
	add_child(_root)

	_build_header_bar()
	_build_song_list()
	_build_difficulty_bar()
	_build_status_bar()
	_build_preview_status()


func _build_header_bar() -> void:
	_header_bar = PanelContainer.new()
	_header_bar.name = "HeaderBar"
	_header_bar.custom_minimum_size.y = BAR_HEIGHT
	_header_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08)
	_header_bar.add_theme_stylebox_override("panel", sb)
	_root.add_child(_header_bar)

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_header_bar.add_child(hbox)

	var search_input := LineEdit.new()
	search_input.placeholder_text = "Search: "
	search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_input.size_flags_vertical = Control.SIZE_EXPAND_FILL
	search_input.add_theme_font_size_override("font_size", 20)
	search_input.text_changed.connect(_on_search_changed)
	hbox.add_child(search_input)

	_settings_button = Button.new()
	_settings_button.text = "Settings"
	_settings_button.custom_minimum_size = Vector2(120, 40)
	_settings_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_settings_button.pressed.connect(_on_settings_pressed)
	hbox.add_child(_settings_button)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(20, 0)
	hbox.add_child(spacer)

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
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_status_label.text = "Select a song"
	_root.add_child(_status_label)


func _build_preview_status() -> void:
	_preview_status_label = Label.new()
	_preview_status_label.name = "PreviewStatusLabel"
	_preview_status_label.custom_minimum_size.y = 28
	_preview_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_preview_status_label.add_theme_font_size_override("font_size", 16)
	_preview_status_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	_preview_status_label.text = ""
	_root.add_child(_preview_status_label)


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
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
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
	sb_normal.bg_color = Color(0.1, 0.1, 0.14)
	sb_normal.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb_normal)

	var sb_hover := StyleBoxFlat.new()
	sb_hover.bg_color = Color(0.18, 0.18, 0.24)
	sb_hover.set_content_margin_all(10)
	panel.add_theme_stylebox_override("hover", sb_hover)

	var sb_pressed := StyleBoxFlat.new()
	sb_pressed.bg_color = Color(0.25, 0.25, 0.35)
	sb_pressed.set_content_margin_all(10)
	panel.add_theme_stylebox_override("pressed", sb_pressed)

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	var selector_label := Label.new()
	selector_label.text = "  "
	selector_label.add_theme_font_size_override("font_size", 20)
	selector_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	hbox.add_child(selector_label)

	var song_label := Label.new()
	song_label.text = _format_duration(song.get("song_length", 0)) + " " + song.artist + " - " + song.name
	song_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	song_label.add_theme_font_size_override("font_size", 20)
	song_label.add_theme_color_override("font_color", Color.WHITE)
	hbox.add_child(song_label)

	var score_label := Label.new()
	score_label.text = "--,---pts"
	score_label.add_theme_font_size_override("font_size", 18)
	score_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
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
	_start_preview_animation(original_index)


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


func _update_status_text() -> void:
	if SongLoader.song_list.size() > 0:
		_status_label.text = str(SongLoader.song_list.size()) + " songs found"
	else:
		_status_label.text = "Put songs in: " + SongLoader.get_user_song_dir()


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
		_status_label.text = "Select a song first"
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
	_stop_preview()
	_show_loading_screen()
	_update_loading(0.0, "Loading " + found.name + "...")
	GameManager.current_song_path = song.path
	GameManager.current_difficulty_offset = found.offset
	GameManager.current_difficulty_name = found.name
	get_tree().change_scene_to_file("res://scene/Gameplay.tscn")

func _on_search_changed(new_text: String) -> void:
	_search_text = new_text
	_selected_song_index = -1
	_stop_preview()
	_update_difficulty_visibility()
	_rebuild_filtered_list()


func _refresh_song_list() -> void:
	_show_loading_screen()
	_update_loading(0.0, "Scanning songs...")
	SongLoader.scan_songs()
	_update_loading(1.0, "Updating list...")
	_update_status_text()
	_rebuild_filtered_list()
	_update_difficulty_visibility()
	_update_selection_ui()
	_hide_loading_screen()


func _show_loading_screen() -> void:
	if _loading_overlay:
		return
	_loading_overlay = CanvasLayer.new()
	_loading_overlay.name = "LoadingOverlay"
	_loading_overlay.layer = 20

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
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
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer)

	_loading_status = Label.new()
	_loading_status.text = ""
	_loading_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_status.add_theme_font_size_override("font_size", 18)
	_loading_status.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(_loading_status)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 15)
	vbox.add_child(spacer2)

	_loading_bar = ProgressBar.new()
	_loading_bar.custom_minimum_size = Vector2(300, 25)
	_loading_bar.show_percentage = true
	_loading_bar.value = 0
	vbox.add_child(_loading_bar)

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
	_preview_song_path = song.path
	_preview_player.stream = _preview_loaded_stream
	_preview_player.volume_db = linear_to_db(SettingsManager.preview_volume)
	_preview_player.play()
	_preview_elapsed = 0.0
	var preview_path: String = song.get("preview_path", "")
	if preview_path.is_empty():
		var start_time: int = song.get("preview_start_time", -1)
		var seek_pos: float = 30.0 if start_time <= 0 else float(start_time)
		_preview_player.seek(seek_pos)
	_preview_status_label.text = "♫  " + song.artist + " - " + song.name


func _stop_preview() -> void:
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
	_preview_song_path = ""
	_preview_elapsed = 0.0
	_preview_status_label.text = ""


func _preview_load_func(path: String) -> void:
	_preview_load_result = AudioManager._load_audio_stream(path)
	_preview_load_done = true


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
		_status_label.text = "Closing..."
		get_tree().quit()
	else:
		_back_press_time = now
		_status_label.text = "Press again to exit"


func _settings_is_open() -> bool:
	for child in get_children():
		if child is SettingsRoot:
			return true
	return false


func _on_settings_pressed() -> void:
	if _settings_is_open():
		return
	_root.hide()
	var settings := preload("res://scene/Settings.tscn").instantiate() as SettingsRoot
	settings.tree_exited.connect(_on_settings_closed)
	add_child(settings)


func _on_settings_closed() -> void:
	_root.show()
