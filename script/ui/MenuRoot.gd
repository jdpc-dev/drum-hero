class_name MenuRoot
extends CanvasLayer

const OUTER_PADDING_WIDE := 16.0
const OUTER_PADDING_COMPACT := 10.0
const CONTENT_MAX_WIDTH := 1180.0
const BAR_HEIGHT := 70.0
const DIFF_HEIGHT := 55.0
const DRAG_THRESHOLD := 8.0
const DIFFICULTY_OFFSETS := [60, 72, 84, 96, 120]
const DIFFICULTY_NAMES := {60: "Easy", 72: "Medium", 84: "Hard", 96: "Expert", 120: "Expert+"}

var _selected_song_index: int = -1
var _filtered_indices: Array[int] = []
var _settings_theme_revision: int = 0
var _search_text: String = ""
var _back_handled_time: float = 0.0

var _root: VBoxContainer
var _header_bar: PanelContainer
var _search_input: LineEdit
var _song_list_scroll: ScrollContainer
var _song_list_container: VBoxContainer
var _diff_container: HBoxContainer
var _settings_button: Button
var _difficulty_buttons: Dictionary = {}

var _loading_overlay: CanvasLayer
var _loading_bar: ProgressBar
var _loading_status: Label
var _loading_folder: Label
var _loading_cancel_button: Button
var _loading_is_scan: bool = false

var _quit_confirm_overlay: CanvasLayer

var _scan_pump_active: bool = false
# The overlay is built on the deferred call that starts the launch scan. The
# first batch is delayed one frame so the overlay is drawn before the disk walk;
# otherwise it only pops up after the work and the launch feels laggy.
var _scan_start_delay: int = 0

# Launch-only event: it must not replay when Gameplay returns to the menu.
# `static` survives the scene change; tests never set it because they do not
# make this menu the current scene.
static var _boot_intro_shown: bool = false

var _old_guitar_fallback: bool = false
var _old_library_state: Array = []
# Generation of SongLoader.song_list shown by this menu. A scan run inside
# Settings bumps it; the rows are rebuilt without walking the disks again.
var _library_generation: int = 0
var _is_switching_scene: bool = false
var _row_dragging: bool = false
var _row_drag_start: Vector2 = Vector2.ZERO

var _album_art: TextureRect
var _album_placeholder: Label
var _preview_player: AudioStreamPlayer
var _preview_song_path: String = ""
var _preview_loaded_stream: AudioStream = null
# Label of the selected row's title, where the loading dots are appended.
var _preview_title_label: Label
var _preview_dots_text: String = ""

const SCAN_OWNER: String = "menu"
const SCAN_START_DELAY_FRAMES: int = 1

const PREVIEW_STEM_NAMES := ["drums", "bass", "guitar", "keys", "rhythm", "vocals"]
var _preview_stem_paths: Array[String] = []
var _preview_stem_streams: Dictionary = {}
var _preview_stem_players: Array[AudioStreamPlayer] = []
var _preview_stem_thread: Thread
var _preview_stem_load_done: bool = false
var _preview_stem_load_result: Dictionary = {}

# The engine boot splash can only draw one still image, so its frame is reused
# as the first frame of this short intro. It is played by the menu itself, right
# after the engine hands over the window.
const BOOT_INTRO_FRAMES: Array[String] = [
	"res://asset/textures/app_secret_frame_0.png",
	"res://asset/textures/app_secret_frame_1.png",
	"res://asset/textures/app_secret_frame_2.png",
	"res://asset/textures/app_secret_frame_3.png",
	"res://asset/textures/app_secret_frame_4.png",
	"res://asset/textures/app_secret_frame_5.png",
]
const BOOT_INTRO_FRAME_TIME := 0.1
const BOOT_INTRO_FADE_TIME := 0.35
const BOOT_INTRO_LAYER := 30

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
	SettingsUI.setup_ui_scale(get_viewport().get_visible_rect().size.y)
	# Also covers closing an overlay that was never opened through this instance
	# (tests do this directly): only a theme chosen inside Settings should reload.
	_settings_theme_revision = Palette.revision
	GameManager.set_state(GameManager.GameState.MENU)
	get_tree().auto_accept_quit = false
	# A cached library is already in memory: the menu opens without a scan.
	# Applying the chart options is a memory pass, so it covers a fallback
	# changed while the menu was rebuilt (e.g. after Free Mode).
	SongLoader.apply_chart_options()
	_library_generation = SongLoader.library_generation
	# The setlist is rebuilt when returning from gameplay: restore the search
	# before building the UI so the LineEdit and the filter are already filled
	# in. The selected song is restored later, when the rows already exist.
	_search_text = GameManager.menu_search_text
	_preview_player = AudioStreamPlayer.new()
	_preview_player.name = "PreviewPlayer"
	_preview_player.bus = "Music"
	add_child(_preview_player)
	SettingsManager.preview_volume_changed.connect(_on_preview_volume_changed)
	SongLoader.scan_progress.connect(_on_scan_progress)
	_build_ui()
	_rebuild_filtered_list()
	_restore_selected_song()
	_restore_scroll_position()
	if SongLoader.song_list.is_empty() and not SongLoader.cache_loaded:
		_show_loading_screen()
		call_deferred("_refresh_song_list")
	_update_difficulty_visibility()
	_update_selection_ui()
	_maybe_show_boot_intro()


# The boot splash is a single still image, so the rest of the sequence is played
# here, over the menu, when the window is first handed to the game. It only runs
# when this menu is the app's main scene: tests instantiate Main.tscn under
# their own scene, so `current_scene` is not this node there. Returns from
# Gameplay are stopped by the static guard.
func _maybe_show_boot_intro() -> void:
	if _boot_intro_shown:
		return
	var current := get_tree().current_scene
	if current != null and current != self:
		return
	_boot_intro_shown = true

	var frames: Array[Texture2D] = []
	for path in BOOT_INTRO_FRAMES:
		# The sequence is used once: keeping its 1024x1024 textures in the
		# resource cache for the whole session would waste several MB on a phone.
		var texture := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
		if texture:
			frames.append(texture)
	if frames.is_empty():
		return

	var overlay := CanvasLayer.new()
	overlay.name = "BootIntro"
	overlay.layer = BOOT_INTRO_LAYER

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# The menu is already built underneath: a tap aimed at the splash must not
	# reach a song row or the search field.
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(root)

	var bg := ColorRect.new()
	bg.color = Palette.NIGHT_VOID
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	var image := TextureRect.new()
	image.set_anchors_preset(Control.PRESET_FULL_RECT)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.texture = frames[0]
	root.add_child(image)

	add_child(overlay)
	_play_boot_intro(overlay, root, image, frames)


func _play_boot_intro(overlay: CanvasLayer, root: Control, image: TextureRect,
		frames: Array[Texture2D]) -> void:
	# One pass only: the sequence must not jump back to the first frame.
	for frame in frames:
		if not is_instance_valid(overlay):
			return
		image.texture = frame
		await get_tree().create_timer(BOOT_INTRO_FRAME_TIME).timeout
	if not is_instance_valid(overlay):
		return
	var fade := overlay.create_tween()
	fade.tween_property(root, "modulate:a", 0.0, BOOT_INTRO_FADE_TIME)
	await fade.finished
	if is_instance_valid(overlay):
		overlay.queue_free()


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
	_hide_quit_confirm()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _settings_is_open():
			return
		var now: float = Time.get_ticks_msec() / 1000.0
		if now - _back_handled_time < 0.5:
			return
		_handle_back()
		return
	if not _can_navigate_setlist():
		return
	# Up/Down are the built-in `ui_up`/`ui_down` actions: arrow keys on desktop
	# and the D-pad on a gamepad. Ignore key echo so holding an arrow moves one
	# row instead of scrolling through the whole list.
	if event.is_action_pressed("ui_down"):
		_navigate_song(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_navigate_song(-1)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _preview_animating:
		_preview_anim_timer += delta
		if _preview_anim_timer >= PREVIEW_ANIM_INTERVAL:
			_preview_anim_timer -= PREVIEW_ANIM_INTERVAL
			_preview_anim_frame = (_preview_anim_frame + 1) % PREVIEW_ANIM_FRAMES.size()
			_set_preview_dots(PREVIEW_ANIM_FRAMES[_preview_anim_frame])
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
					_set_preview_dots("")
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
		if _scan_start_delay > 0:
			_scan_start_delay -= 1
		else:
			_pump_scan()


# The library scan advances from here and not from an await: this way the menu
# can disappear in the middle of a batch without leaving SongLoader stuck with
# is_scanning = true, which would block the next scan forever.
func _pump_scan() -> void:
	if SongLoader.pump_scan(SongLoader.frame_deadline_usec(), SCAN_OWNER):
		_finish_song_list_refresh()


func _abort_scan() -> void:
	_scan_pump_active = false
	_scan_start_delay = 0
	SongLoader.abort_scan(SCAN_OWNER)


func _on_scan_progress(root_index: int, root_total: int, current_dir: String, _dirs_visited: int, songs_found: int) -> void:
	# Events reach everyone because SongLoader is a singleton: only paint the
	# overlay when what is on screen is a scan and not the loading of a song.
	if not _loading_is_scan or not is_instance_valid(_loading_status):
		return
	if is_instance_valid(_loading_bar):
		_loading_bar.value = ScanFeedback.progress_value(root_index, root_total) * 100.0
	_loading_status.text = ScanFeedback.status_text(root_index, root_total, songs_found)
	if is_instance_valid(_loading_folder):
		_loading_folder.text = ScanFeedback.folder_text(current_dir)


func _on_cancel_scan_pressed() -> void:
	if not SongLoader.is_scanning:
		# The overlay is on screen one frame before the walk starts. Cancelling
		# in that window must drop the queued scan instead of leaving the
		# overlay up until the scan starts anyway.
		if _scan_pump_active:
			_abort_scan()
			_hide_loading_screen()
		return
	SongLoader.cancel_scan()
	if is_instance_valid(_loading_status):
		_loading_status.text = "Cancelling..."


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Palette.NIGHT_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var edge: int = SettingsUI.px(OUTER_PADDING_COMPACT if OS.has_feature("mobile") else OUTER_PADDING_WIDE)
	var limit := SettingsUI.ContentLimit.new()
	limit.name = "ContentLimit"
	limit.max_width = float(SettingsUI.px(CONTENT_MAX_WIDTH))
	limit.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(limit)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, edge)
	limit.add_child(margin)

	_root = VBoxContainer.new()
	_root.name = "Root"
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_theme_constant_override("separation", SettingsUI.px(8))
	margin.add_child(_root)

	_build_header_bar()
	_build_song_list()
	_build_difficulty_bar()


func _build_header_bar() -> void:
	_header_bar = PanelContainer.new()
	_header_bar.name = "HeaderBar"
	_header_bar.custom_minimum_size.y = SettingsUI.px(BAR_HEIGHT)
	_header_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := SettingsUI.flat(Palette.SURFACE_1, 16)
	SettingsUI.pad(sb, SettingsUI.px(10), SettingsUI.px(8))
	_header_bar.add_theme_stylebox_override("panel", sb)
	_root.add_child(_header_bar)

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_theme_constant_override("separation", SettingsUI.px(10))
	_header_bar.add_child(hbox)

	var art_frame := PanelContainer.new()
	art_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var art_style := SettingsUI.flat(Palette.SURFACE_2, 14)
	art_frame.add_theme_stylebox_override("panel", art_style)
	art_frame.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(art_frame)

	_album_art = TextureRect.new()
	_album_art.name = "AlbumArt"
	_album_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_album_art.stretch_mode = TextureRect.STRETCH_SCALE
	_album_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_album_art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_album_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_album_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_frame.add_child(_album_art)

	_album_placeholder = SettingsUI.label("♪", 22, Palette.MUTED, 500)
	_album_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_album_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_album_placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_album_placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art_frame.add_child(_album_placeholder)

	var search_input := LineEdit.new()
	search_input.placeholder_text = "Search songs"
	SettingsUI.style_line_edit(search_input)
	search_input.add_theme_font_size_override("font_size", SettingsUI.px(18))
	search_input.custom_minimum_size.y = SettingsUI.px(46)
	search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_input.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	search_input.clear_button_enabled = true
	search_input.text = _search_text
	search_input.caret_column = search_input.text.length()
	search_input.text_changed.connect(_on_search_changed)
	hbox.add_child(search_input)
	_search_input = search_input

	_settings_button = SettingsUI.button("Settings", "secondary")
	_settings_button.custom_minimum_size = Vector2(SettingsUI.px(110), SettingsUI.px(46))
	_settings_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_settings_button.pressed.connect(_on_settings_pressed)
	hbox.add_child(_settings_button)

	# The inputs report their full height, stylebox content padding included.
	# Match the tallest one so the square cover lines up with the whole row.
	var row_height: float = maxf(
		search_input.get_combined_minimum_size().y,
		_settings_button.get_combined_minimum_size().y
	)
	art_frame.custom_minimum_size = Vector2(row_height, row_height)


func _build_song_list() -> void:
	_song_list_scroll = ScrollContainer.new()
	_song_list_scroll.name = "SongListScroll"
	_song_list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_song_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_song_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_song_list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_song_list_scroll.follow_focus = true
	SettingsUI.style_scroll(_song_list_scroll)
	_root.add_child(_song_list_scroll)

	_song_list_container = VBoxContainer.new()
	_song_list_container.name = "SongListContainer"
	_song_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_song_list_container.mouse_filter = Control.MOUSE_FILTER_PASS
	_song_list_container.add_theme_constant_override("separation", SettingsUI.px(8))
	_song_list_scroll.add_child(_song_list_container)


# The dots live in the selected row's own title so they sit right next to the
# song they refer to, instead of in a separate status line under the setlist.
func _set_preview_dots(text: String) -> void:
	_preview_dots_text = text
	_paint_preview_dots()


func _paint_preview_dots() -> void:
	if not is_instance_valid(_preview_title_label):
		_preview_title_label = null
		return
	var base_text: String = str(_preview_title_label.get_meta("base_text", ""))
	var dots: String = "" if _preview_dots_text.is_empty() else "  " + _preview_dots_text
	_preview_title_label.text = base_text + dots


func _build_difficulty_bar() -> void:
	_diff_container = HBoxContainer.new()
	_diff_container.name = "DiffContainer"
	_diff_container.custom_minimum_size.y = SettingsUI.px(DIFF_HEIGHT)
	_diff_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_diff_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_diff_container.add_theme_constant_override("separation", SettingsUI.px(10))
	_root.add_child(_diff_container)

	for off in DIFFICULTY_OFFSETS:
		var btn := SettingsUI.button(DIFFICULTY_NAMES[off], "secondary")
		btn.custom_minimum_size = Vector2(SettingsUI.px(120), SettingsUI.px(46))
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
		# Remove immediately so the rebuilt rows can keep the SongRow_N names;
		# queue_free() alone leaves the old names taken for the rest of the frame.
		_song_list_container.remove_child(child)
		child.queue_free()

	if _filtered_indices.is_empty():
		var text: String = ""
		if not _search_text.is_empty():
			text = "No songs found"
		elif not SongLoader.library_rescan_reason().is_empty():
			# Cached-empty or stale library: the player must ask for a rescan.
			text = "No songs yet. Open Settings > Songs and press Rescan now."
		else:
			text = "Put songs in: " + SongLoader.get_user_song_dir()
		var empty_card := PanelContainer.new()
		empty_card.name = "EmptyState"
		empty_card.mouse_filter = Control.MOUSE_FILTER_PASS
		var empty_style := SettingsUI.flat(Palette.SURFACE_1, 14)
		SettingsUI.pad(empty_style, SettingsUI.px(24), SettingsUI.px(20))
		empty_card.add_theme_stylebox_override("panel", empty_style)
		var empty_label := SettingsUI.label(text, 16, Palette.MUTED, 400)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.custom_minimum_size.y = SettingsUI.px(48)
		empty_card.add_child(empty_label)
		_song_list_container.add_child(empty_card)
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
	panel.custom_minimum_size = Vector2(0, SettingsUI.px(56))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.name = "SongRow_" + str(original_index)
	panel.add_theme_stylebox_override("panel", _song_row_style(false, false))
	panel.set_meta("selected", false)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_theme_constant_override("separation", SettingsUI.px(10))
	panel.add_child(hbox)

	var song_length: int = int(song.get("song_length", 0))
	var prefix: String = (_format_duration(song_length) + "  ") if song_length > 0 else ""
	var title_text: String = prefix + song.artist + " - " + song.name
	var song_label := SettingsUI.label(title_text, 18, Palette.BONE, 500)
	song_label.name = "SongTitle"
	song_label.set_meta("base_text", title_text)
	song_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	song_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	song_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hbox.add_child(song_label)

	# Best score for the song across the difficulties its chart offers; the
	# placeholder "--,---pts" is kept if there is no record yet.
	var best: int = HighScoreStore.get_best_for_song(song.path, song.get("difficulties", []).map(func(d: Dictionary) -> int: return d.offset))
	var score_label := SettingsUI.label((ScoreData.format_score(best) + " pts") if best > 0 else "--,---pts", 14, Palette.ASH, 500)
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(score_label)

	panel.gui_input.connect(_on_song_row_input.bind(original_index))
	panel.mouse_entered.connect(_on_song_row_hover.bind(panel, true))
	panel.mouse_exited.connect(_on_song_row_hover.bind(panel, false))
	return panel


func _song_row_style(selected: bool, hovered: bool) -> StyleBoxFlat:
	var color: Color = Palette.ACCENT_SURFACE if selected else (Palette.SURFACE_2 if hovered else Palette.SURFACE_1)
	var sb := SettingsUI.flat(color, 12)
	SettingsUI.pad(sb, SettingsUI.px(14), SettingsUI.px(10))
	return sb


func _on_song_row_hover(panel: PanelContainer, entered: bool) -> void:
	if not is_instance_valid(panel) or bool(panel.get_meta("selected", false)):
		return
	panel.add_theme_stylebox_override("panel", _song_row_style(false, entered))


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
		# Selecting the same song again is a quick rewind of its preview: it
		# must not stop and reload the stream.
		_rewind_preview(original_index)
		return
	_selected_song_index = original_index
	_update_selection_ui()
	_update_difficulty_visibility()
	_load_album_art(original_index)
	_start_preview_animation(original_index)


func _rewind_preview(original_index: int) -> void:
	if original_index < 0 or original_index >= SongLoader.song_list.size():
		return
	var song: Dictionary = SongLoader.song_list[original_index]
	# Nothing loaded to rewind (still loading, ended, or failed): fall back to
	# the normal path, but leave an in-flight load alone instead of restarting it.
	if _preview_player.stream == null or _preview_song_path != song.path:
		if not _preview_animating:
			_start_preview_animation(original_index)
		return
	# A rewind during the 30s fade-out must cancel it; killing the tween also
	# stops its `finished` callback from clearing the preview.
	if _preview_fading_out:
		if _preview_fade_tween:
			_preview_fade_tween.kill()
			_preview_fade_tween = null
		_preview_fading_out = false
		var target_db: float = linear_to_db(maxf(SettingsManager.preview_volume, 0.0001))
		_preview_player.volume_db = target_db
		for player in _preview_stem_players:
			if is_instance_valid(player):
				player.volume_db = target_db
	var preview_path: String = song.get("preview_path", "")
	var seek_pos: float = 0.0
	if preview_path.is_empty():
		var start_time: int = song.get("preview_start_time", -1)
		seek_pos = 30.0 if start_time < 0 else float(start_time) / 1000.0
	if _preview_player.playing:
		_preview_player.seek(seek_pos)
	else:
		_preview_player.play(seek_pos)
	# Keep the fallback stems aligned with the rewound preview.
	for player in _preview_stem_players:
		if not is_instance_valid(player) or player.stream == null:
			continue
		if player.playing:
			player.seek(seek_pos)
		else:
			player.play(seek_pos)
	_preview_elapsed = 0.0
	_set_preview_dots("")


func _can_navigate_setlist() -> bool:
	if _is_switching_scene or _settings_is_open() or _quit_confirm_is_open():
		return false
	if _loading_overlay != null or has_node("BootIntro"):
		return false
	return true


func _navigate_song(direction: int) -> void:
	if _filtered_indices.is_empty():
		return
	var position: int = _filtered_indices.find(_selected_song_index)
	var next_position: int
	if position < 0:
		# The selection may be hidden by the current search: start from the
		# nearest visible end instead of trying to step a row that is not there.
		next_position = 0 if direction > 0 else _filtered_indices.size() - 1
	else:
		next_position = clampi(position + direction, 0, _filtered_indices.size() - 1)
	if next_position == position:
		return
	_select_song(_filtered_indices[next_position])
	_scroll_selected_song_into_view()


func _scroll_selected_song_into_view() -> void:
	if not is_instance_valid(_song_list_scroll) or not is_instance_valid(_song_list_container):
		return
	var row := _song_list_container.get_node_or_null("SongRow_" + str(_selected_song_index)) as Control
	if row != null:
		_song_list_scroll.ensure_control_visible(row)


func _load_album_art(index: int) -> void:
	if index < 0 or index >= SongLoader.song_list.size():
		_set_album_texture(null)
		return
	var song: Dictionary = SongLoader.song_list[index]
	var album_path: String = song.get("album_path", "")
	if album_path.is_empty():
		_set_album_texture(null)
		return
	var tex: Texture2D = ResourceLoader.load(album_path)
	if tex == null:
		tex = _load_external_texture(album_path)
	_set_album_texture(tex)


func _set_album_texture(tex: Texture2D) -> void:
	var rounded: Texture2D = SettingsUI.rounded_cover(tex)
	if is_instance_valid(_album_art):
		_album_art.texture = rounded
	if is_instance_valid(_album_placeholder):
		_album_placeholder.visible = rounded == null


func _load_external_texture(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _update_selection_ui() -> void:
	var selected_title: Label = null
	for i in _song_list_container.get_child_count():
		var row = _song_list_container.get_child(i)
		if not row is PanelContainer:
			continue
		var original_index: int = int(row.name.replace("SongRow_", ""))
		var selected: bool = original_index == _selected_song_index
		row.set_meta("selected", selected)
		row.add_theme_stylebox_override("panel", _song_row_style(selected, false))
		if selected:
			selected_title = row.find_child("SongTitle", true, false) as Label
	_preview_title_label = selected_title
	_paint_preview_dots()


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
	# Save before changing scene: on return, the setlist must keep the search,
	# scroll and selected song with which the player chose the difficulty.
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
	# Searching filters the view, it does not discard the current selection.
	# Keeping it lets the list return to the song when the search is cleared.
	_rebuild_filtered_list()
	_update_selection_ui()
	_update_difficulty_visibility()
	if new_text.is_empty() and _selected_song_index >= 0:
		_scroll_to_selected_song.call_deferred()


func _scroll_to_selected_song() -> void:
	if not is_inside_tree():
		return
	# Rows are recreated on this frame and the scrollbar maximum is updated on
	# the next layout pass.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree() or not is_instance_valid(_song_list_scroll) or not is_instance_valid(_song_list_container):
		return
	var row := _song_list_container.get_node_or_null("SongRow_" + str(_selected_song_index)) as Control
	if row != null:
		_song_list_scroll.ensure_control_visible(row)


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
		# If the current filter no longer shows it, an invisible selection is
		# not restored: the saved state should always be coherent, but a
		# rescanned library may have changed in between.
		if not _filtered_indices.has(i):
			return
		# It is restored as if the player had just chosen it, which also
		# relaunches the automatic song preview.
		_select_song(i)
		return


func _restore_scroll_position() -> void:
	var target: int = GameManager.menu_scroll_position
	if target <= 0 or not is_instance_valid(_song_list_scroll):
		return
	var saved_search: String = _search_text
	# The rows have just been created: the ScrollContainer does not yet know
	# the real height of its content. It is retried for a few frames until the
	# value is applied (or the layout limits it to the maximum available).
	for _i in 3:
		await get_tree().process_frame
		if not is_instance_valid(_song_list_scroll) or _search_text != saved_search:
			return
		_song_list_scroll.scroll_vertical = target
		if _song_list_scroll.scroll_vertical == target:
			return


func _refresh_song_list() -> void:
	# Only the first run reaches here (no cached library). Every later refresh
	# is explicit through Settings ▸ Songs ▸ Rescan now.
	if _scan_pump_active:
		return
	_scan_pump_active = true
	_scan_start_delay = SCAN_START_DELAY_FRAMES
	_show_loading_screen(true)
	_update_loading(0.0, "Scanning songs...")
	SongLoader.request_scan(SCAN_OWNER)


func _finish_song_list_refresh() -> void:
	_scan_pump_active = false
	_scan_start_delay = 0
	var kept: int = SongLoader.song_list.size()
	# It is read from SongLoader and not from a local flag: pump_scan() can
	# chain the queued rescan in the same call, and a local flag would keep the
	# previous scan's result.
	var final_text: String = ScanFeedback.cancelled_text(kept) if not SongLoader.cancelled_roots.is_empty() else ScanFeedback.finished_text(kept)
	_update_loading(1.0, final_text)
	_rebuild_filtered_list()
	_update_difficulty_visibility()
	_update_selection_ui()
	_hide_loading_screen()


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
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_loading_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(SettingsUI.px(420), 0)
	var panel_style := SettingsUI.flat(Palette.SURFACE_1, 18)
	SettingsUI.pad(panel_style, SettingsUI.px(28), SettingsUI.px(24))
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SettingsUI.px(10))
	panel.add_child(vbox)

	var title := SettingsUI.label("LOADING", 26, Palette.BONE_HI, 600)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_loading_status = SettingsUI.label("", 14, Palette.CHROME, 400)
	_loading_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_loading_status)

	if allow_cancel:
		# The folder the scan is entering: in a large library it is the only
		# thing that tells whether it is still advancing or has got stuck in a
		# slow tree.
		_loading_folder = ScanFeedback.make_folder_label()
		_loading_folder.custom_minimum_size = Vector2(SettingsUI.px(300), SettingsUI.px(18))
		_loading_folder.add_theme_font_size_override("font_size", SettingsUI.px(12))
		vbox.add_child(_loading_folder)

	_loading_bar = ProgressBar.new()
	_loading_bar.custom_minimum_size = Vector2(SettingsUI.px(320), 0)
	SettingsUI.style_progress(_loading_bar)
	# The scan cannot promise a percentage, but loading a song does have real
	# stages.
	_loading_bar.show_percentage = not allow_cancel
	_loading_bar.value = 0
	vbox.add_child(_loading_bar)

	if allow_cancel:
		_loading_cancel_button = SettingsUI.button("Cancel", "secondary")
		_loading_cancel_button.custom_minimum_size = Vector2(SettingsUI.px(140), SettingsUI.px(46))
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
	_set_preview_dots(PREVIEW_ANIM_FRAMES[0])
	var song_preview_path: String = song.get("preview_path", "")
	if song_preview_path.is_empty():
		_preview_stem_paths.clear()
		for stem in PREVIEW_STEM_NAMES:
			var stem_path: String = SongLoader.get_stem_path(song.path, stem)
			if not stem_path.is_empty():
				_preview_stem_paths.append(stem_path)


func _play_preview(original_index: int) -> void:
	if original_index < 0 or original_index >= SongLoader.song_list.size():
		_set_preview_dots("")
		return
	var song: Dictionary = SongLoader.song_list[original_index]
	if not _preview_loaded_stream:
		_set_preview_dots("")
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
	# Playback started: the dots were only a loading indicator.
	_set_preview_dots("")


func _on_preview_volume_changed(volume: float) -> void:
	# The slider is in Settings, which is opened over this menu: an already
	# playing preview has to follow the new level instead of waiting for the
	# next selected song.
	if not is_instance_valid(_preview_player) or _preview_fading_out:
		return
	if _preview_fade_tween != null:
		_preview_fade_tween.kill()
		_preview_fade_tween = null
	var target_db: float = linear_to_db(maxf(volume, 0.0001))
	if _preview_player.playing:
		_preview_player.volume_db = target_db
	for player in _preview_stem_players:
		if is_instance_valid(player) and player.playing:
			player.volume_db = target_db


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
	_set_preview_dots("")


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
	if _quit_confirm_is_open():
		_hide_quit_confirm()
		return
	_show_quit_confirm()


func _quit_confirm_is_open() -> bool:
	return is_instance_valid(_quit_confirm_overlay)


# Same visual language as the pause overlay and the results panel: full-screen
# scrim and a centered VBox with the buttons. It is built in code because the
# menu does not have its own modal scene.
func _show_quit_confirm() -> void:
	if _quit_confirm_is_open():
		return
	_quit_confirm_overlay = CanvasLayer.new()
	_quit_confirm_overlay.name = "QuitConfirmOverlay"
	_quit_confirm_overlay.layer = 25

	var bg: ColorRect = ColorRect.new()
	bg.name = "QuitConfirmBg"
	bg.color = Palette.SCRIM_SOFT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_quit_confirm_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quit_confirm_overlay.add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.name = "QuitConfirmPanel"
	panel.custom_minimum_size = Vector2(SettingsUI.px(440), 0)
	var panel_style := SettingsUI.flat(Palette.SURFACE_1, 18)
	SettingsUI.pad(panel_style, SettingsUI.px(28), SettingsUI.px(24))
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", SettingsUI.px(10))
	panel.add_child(content)

	var title: Label = SettingsUI.label("EXIT GAME?", 26, Palette.BONE_HI, 600)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	var message: Label = SettingsUI.label("Are you sure you want to close the game?", 15, Palette.ASH, 400)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(message)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", SettingsUI.px(10))
	content.add_child(buttons)

	var cancel_btn: Button = SettingsUI.button("CANCEL", "secondary")
	cancel_btn.name = "CancelButton"
	cancel_btn.custom_minimum_size = Vector2(0, SettingsUI.px(48))
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.pressed.connect(_hide_quit_confirm)
	buttons.add_child(cancel_btn)

	var exit_btn: Button = SettingsUI.button("EXIT", "primary")
	exit_btn.name = "ExitButton"
	exit_btn.custom_minimum_size = Vector2(0, SettingsUI.px(48))
	exit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exit_btn.pressed.connect(_confirm_quit)
	buttons.add_child(exit_btn)

	add_child(_quit_confirm_overlay)


func _hide_quit_confirm() -> void:
	if _quit_confirm_overlay:
		_quit_confirm_overlay.queue_free()
	_quit_confirm_overlay = null


func _confirm_quit() -> void:
	_hide_quit_confirm()
	get_tree().quit()


func _settings_is_open() -> bool:
	for child in get_children():
		if child is SettingsRoot:
			return true
	return false


func _on_settings_pressed() -> void:
	if _settings_is_open():
		return
	_settings_theme_revision = Palette.revision
	_old_guitar_fallback = SettingsManager.use_guitar_fallback
	_old_library_state = [
		SettingsManager.library_roots,
		SettingsManager.library_preset_downloads,
		SettingsManager.library_recursive,
		SettingsManager.library_max_depth,
	]
	_root.hide()
	var settings := preload("res://scene/Settings.tscn").instantiate() as SettingsRoot
	settings.tree_exited.connect(_on_settings_closed)
	settings.free_mode_requested.connect(_on_free_mode_requested)
	add_child(settings)


# The Settings panel requests opening free mode and it is this menu that
# changes scene: the panel lives as a child of MenuRoot, it is not a scene.
func _on_free_mode_requested() -> void:
	_stop_preview()
	_is_switching_scene = true
	get_tree().change_scene_to_file("res://scene/FreeMode.tscn")


# When changing scene the menu is dismantled with the Settings panel inside, so
# its tree_exited fires during destruction: continuing to react there would
# launch a library scan while the tree is already being torn down.
func _on_settings_closed() -> void:
	# Closing Settings never starts a scan. Changes to the library are applied
	# only through "Rescan now"; this method just reflects what SongLoader
	# already has in memory.
	if _is_switching_scene or not is_inside_tree():
		return
	# A theme selected in Settings repainted the overlay in place. The menu
	# underneath was hidden the whole time, so rebuild it through the normal
	# scene path; `_exit_tree`/`_ready` already preserve search, selection and
	# scroll position across this reload.
	if Palette.revision != _settings_theme_revision:
		get_tree().call_deferred("reload_current_scene")
		return
	_root.show()
	_library_changed()
	var fallback_changed: bool = SettingsManager.use_guitar_fallback != _old_guitar_fallback
	if fallback_changed:
		# Difficulties are stored per chart source, so the fallback is a memory
		# pass instead of a disk walk.
		SongLoader.apply_chart_options()
	var library_changed: bool = SongLoader.library_generation != _library_generation
	_library_generation = SongLoader.library_generation
	if fallback_changed or library_changed:
		_rebuild_from_library()


func _rebuild_from_library() -> void:
	# Rebuilds rows from the current `song_list`, keeping the selected song by
	# path (a rescan can insert or remove songs before it).
	var selected_path: String = ""
	if _selected_song_index >= 0 and _selected_song_index < SongLoader.song_list.size():
		selected_path = SongLoader.song_list[_selected_song_index].path
	_rebuild_filtered_list()
	_selected_song_index = -1
	if not selected_path.is_empty():
		for i in SongLoader.song_list.size():
			if SongLoader.song_list[i].path == selected_path and _filtered_indices.has(i):
				_selected_song_index = i
				break
	_update_difficulty_visibility()
	_update_selection_ui()


func _library_changed() -> bool:
	var current := [
		SettingsManager.library_roots,
		SettingsManager.library_preset_downloads,
		SettingsManager.library_recursive,
		SettingsManager.library_max_depth,
	]
	if current == _old_library_state:
		return false
	_old_library_state = current
	return true
