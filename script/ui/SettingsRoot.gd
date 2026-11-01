class_name SettingsRoot
extends CanvasLayer

# Settings does not change scene on its own: it emits the request and MenuRoot
# (the screen hosting it) decides to open free mode.
signal free_mode_requested()

var _current_tab: int = 0
var _tab_buttons: Array[Button] = []
var _content_container: VBoxContainer
var _content_scroll: ScrollContainer
var _page_title_label: Label
var _page_subtitle_label: Label
var _wide_layout: bool = true
var _about_overlay: Control
var _custom_lane_card: Control

# CONTROLS tab elements
var _mode_buttons: Array[CheckBox] = []
var _mode_desc_label: Label
var _custom_lane_container: VBoxContainer
var _haptic_enabled_check: CheckBox

# GAMEPLAY tab elements
var _fps_cap_slider: HSlider

# SONGS tab elements
var _permission_status: Label
var _permission_button: Button
var _permission_was_granted: bool = false
var _roots_container: VBoxContainer
var _rescan_button: Button
var _cancel_scan_button: Button
var _scan_bar: ProgressBar
var _scan_status: Label
var _scan_folder: Label
var _scan_summary: Label
var _scan_pump_active: bool = false
var _songs_link_status: Label
var _library_section: VBoxContainer
var _root_path_edit: LineEdit
var _root_location_option: OptionButton
var _storage_locations: Array[Dictionary] = []
var _keyboard_spacer: Control
var _keyboard_base_viewport_h: float = 0.0
var _keyboard_last_height: int = 0
var _keyboard_last_viewport: Vector2 = Vector2.ZERO
var _keyboard_poll_accum: float = 0.0
var _keyboard_settle_frames: int = 0
var _field_touch_active: bool = false
var _field_touch_dragging: bool = false
var _field_touch_start: Vector2 = Vector2.ZERO
var _field_scroll_start: int = 0

# ADVANCED tab elements
var _padding_check: CheckBox
var _padding_left_slider: HSlider
var _padding_right_slider: HSlider
var _padding_top_slider: HSlider
var _padding_bottom_slider: HSlider

const LANE_LABELS: PackedStringArray = [
	"HH", "CRASH", "SNARE", "KICK",
	"TOM 1", "TOM 2", "TOM 3", "RIDE",
]

const SONGS_TAB: int = 3
const TAB_COUNT: int = 5
const WIDE_BREAKPOINT: float = 1000.0
const CONTENT_MAX_WIDTH: float = 1180.0
const MOBILE_ROW_TARGET_DP: float = 19.0
const MOBILE_BASE_ROW_UNITS: float = 19.0
const MOBILE_UI_SCALE_MIN: float = 1.2
const MOBILE_UI_SCALE_MAX: float = 1.9
const MOBILE_UI_SCALE_FALLBACK: float = 1.5
const SCAN_OWNER: String = "settings"
const SONGS_LINKTREE_URL: String = "https://linktr.ee/com.drum.hero"

const TAB_NAMES: Array[String] = ["CONTROLS", "GAMEPLAY", "AUDIO", "SONGS", "ADVANCED"]
const TAB_ICONS: Array[int] = [
	SettingsUI.ICON_CONTROLS,
	SettingsUI.ICON_GAMEPLAY,
	SettingsUI.ICON_AUDIO,
	SettingsUI.ICON_SONGS,
	SettingsUI.ICON_ADVANCED,
]
const PAGE_INFO: Array[Dictionary] = [
	{
		"title": "Controls",
		"subtitle": "How the pads play, how the lanes are arranged and how the haptic kick responds.",
	},
	{
		"title": "Gameplay",
		"subtitle": "Speed, timing and the feedback shown on the highway.",
	},
	{
		"title": "Audio",
		"subtitle": "Music, drums and menu previews. Changes apply immediately.",
	},
	{
		"title": "Songs",
		"subtitle": "Where Drum Hero looks for charts, audio stems and album art.",
	},
	{
		"title": "Advanced",
		"subtitle": "Compatibility, debugging tools and edge padding for gesture navigation.",
	},
]
const MODE_DESCRIPTIONS: Array[String] = [
	"8 lanes - every drum part is visible and playable on the highway.",
	"7 lanes - the kick lane is replaced by a short forward tilt of the device.",
	"Reorders the highway by hand. Arrange the lanes below, kick included.",
]

# Bases offered by the extra-folder form on Android. Picking one keeps the
# player from typing the mount point every time; the folder field only takes the
# path inside it. Desktop builds use $HOME instead (see _resolve_storage_locations).
# An absolute path typed in the field still wins, so pasted paths from a file
# manager keep working.
const STORAGE_LOCATIONS: Array[Dictionary] = [
	{"label": "Internal storage", "path": "/storage/emulated/0"},
	{"label": "External storage", "path": "/sdcard"},
]

const LANE_COLORS: Array[Color] = [
	Color(0.9, 0.8, 0.2),
	Color(1.0, 0.6, 0.0),
	Color(0.8, 0.2, 0.2),
	Color(0.6, 0.4, 0.8),
	Color(0.2, 0.7, 0.9),
	Color(0.2, 0.9, 0.5),
	Color(0.9, 0.3, 0.6),
	Color(0.5, 0.8, 0.3),
]


func _ready() -> void:
	layer = 10
	SettingsUI.ui_scale = _mobile_ui_scale()
	_wide_layout = _is_wide_layout()
	SongLoader.scan_progress.connect(_on_scan_progress)
	_build_ui()
	_load_current_settings()
	get_viewport().size_changed.connect(_on_viewport_resized)


func _exit_tree() -> void:
	# The scan lives in SongLoader, so it must be stopped here or the menu would
	# find is_scanning = true on return. This _exit_tree runs before the
	# tree_exited that MenuRoot listens to, so its rescan comes out clean.
	_abort_scan()


func _process(delta: float) -> void:
	_follow_path_edit_keyboard(delta)
	# The walk advances from _process and not from an await: this way the panel
	# can be closed in the middle of a batch without leaving anything hanging.
	if not _scan_pump_active:
		return
	if SongLoader.pump_scan(SongLoader.frame_deadline_usec(), SCAN_OWNER):
		_finish_scan()


func _follow_path_edit_keyboard(delta: float) -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return
	if not is_instance_valid(_root_path_edit) or not _root_path_edit.has_focus():
		return
	# Polling slowly is enough: the keyboard animation lasts a few frames and
	# querying the OS height every frame spends JNI calls for nothing.
	_keyboard_poll_accum += delta
	if _keyboard_poll_accum >= 0.1:
		_keyboard_poll_accum = 0.0
		var keyboard_height: int = DisplayServer.virtual_keyboard_get_height()
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		if keyboard_height != _keyboard_last_height or viewport_size != _keyboard_last_viewport:
			_keyboard_last_height = keyboard_height
			_keyboard_last_viewport = viewport_size
			# The scrollbar maximum is updated in a deferred layout pass. Keep
			# applying the position for a few frames so the field ends at the
			# final offset instead of the old maximum.
			_keyboard_settle_frames = 8
	if _keyboard_settle_frames <= 0:
		return
	_keyboard_settle_frames -= 1
	_keep_path_edit_above_keyboard()


func _keep_path_edit_above_keyboard() -> void:
	if not is_instance_valid(_root_path_edit) or not is_instance_valid(_content_scroll):
		return
	var edit := _root_path_edit
	var scroll := _content_scroll
	# The OS reports the keyboard in physical pixels. The screen transform
	# converts it to the units used by the scroll container and the spacer.
	var screen_scale_y: float = maxf(scroll.get_screen_transform().get_scale().y, 0.001)
	var keyboard_h: float = float(DisplayServer.virtual_keyboard_get_height()) / screen_scale_y
	# With adjustResize the window may already have shrunk by the keyboard, so
	# only the part of the keyboard that still covers the window is inset.
	var covered_h: float = maxf(0.0, _keyboard_base_viewport_h - get_viewport().get_visible_rect().size.y)
	var inset: float = maxf(0.0, keyboard_h - covered_h)

	if inset <= 0.0:
		if is_instance_valid(_keyboard_spacer):
			_keyboard_spacer.custom_minimum_size.y = 0.0
		scroll.ensure_control_visible(edit)
		return

	# The tab may end right below the input (scan controls, reset button), so
	# without extra room the ScrollContainer cannot lift the field above the
	# keyboard. The spacer is only bottom padding: the field does not move.
	if is_instance_valid(_keyboard_spacer):
		_keyboard_spacer.custom_minimum_size.y = inset + 24.0

	scroll.ensure_control_visible(edit)
	# ensure_control_visible() only guarantees the field is inside the scroll
	# viewport, which can still sit behind an overlaying keyboard. Scroll the
	# remaining distance explicitly.
	var row_top: float = edit.get_global_rect().position.y - scroll.get_global_rect().position.y + scroll.scroll_vertical
	var row_bottom: float = row_top + edit.size.y
	var usable_bottom: float = scroll.scroll_vertical + scroll.size.y - inset - 16.0
	if row_bottom > usable_bottom:
		scroll.scroll_vertical += int(ceil(row_bottom - usable_bottom))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _about_is_open():
			_close_about()
		else:
			_on_back()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		# Returning from the system Settings screen: the permission may have
		# changed. Without this the panel would keep saying "Not granted" and
		# the user would think the button does nothing.
		_refresh_permission_state()


func _refresh_permission_state() -> void:
	if not is_instance_valid(_permission_status):
		return
	var had_access: bool = _permission_was_granted
	var has_access: bool = AndroidBridge.has_all_files_access()
	_permission_was_granted = has_access
	_update_permission_section()
	if has_access == had_access:
		return
	_apply_library_access()
	if has_access:
		# A grant changes which songs a scan could find, but walking the disks
		# is the player's call now: the summary reports the change and points at
		# the Rescan button instead of starting a scan behind their back.
		_update_scan_summary()
	else:
		# The library controls just disappeared: a walk started while they were
		# visible would keep running with no way to cancel it from this tab.
		_abort_scan()


func _input(event: InputEvent) -> void:
	if _handle_field_scroll(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if _about_is_open():
			_close_about()
		else:
			_on_back()
		get_viewport().set_input_as_handled()


# A LineEdit accepts the touch press to focus itself, so the ScrollContainer
# never receives it and cannot start its own drag. Vertical swipes that begin
# on the folder field are therefore handled here, while horizontal swipes are
# left to the field for caret placement.
func _handle_field_scroll(event: InputEvent) -> bool:
	if _about_is_open():
		_field_touch_active = false
		_field_touch_dragging = false
		return false
	if not is_instance_valid(_root_path_edit) or not is_instance_valid(_content_scroll):
		_field_touch_active = false
		_field_touch_dragging = false
		return false
	if event is InputEventScreenTouch:
		if event.pressed:
			_field_touch_active = _root_path_edit.get_global_rect().has_point(event.position)
			if _field_touch_active:
				_field_touch_start = event.position
				_field_scroll_start = _content_scroll.scroll_vertical
				_field_touch_dragging = false
			return false
		if _field_touch_active:
			var dragged: bool = _field_touch_dragging
			_field_touch_active = false
			_field_touch_dragging = false
			return dragged
		return false
	if _field_touch_dragging:
		# These are the emulated mouse events Android derives from the touch.
		# Swallow them so the field does not select text while scrolling.
		if event is InputEventMouseMotion or event is InputEventMouseButton:
			return true
	if event is InputEventScreenDrag and _field_touch_active:
		var delta: Vector2 = event.position - _field_touch_start
		if not _field_touch_dragging:
			if absf(delta.y) > 12.0 and absf(delta.y) > absf(delta.x):
				_field_touch_dragging = true
				if _root_path_edit.has_focus():
					_root_path_edit.release_focus()
		if _field_touch_dragging:
			_content_scroll.scroll_vertical = int(_field_scroll_start - delta.y)
			return true
	return false


# --- shell ------------------------------------------------------------------

func _is_wide_layout() -> bool:
	# Phones always get the compact top navigation; the sidebar is a desktop
	# affordance. The width check still covers small desktop windows.
	if OS.has_feature("mobile"):
		return false
	var window_width: float = float(DisplayServer.window_get_size().x)
	if window_width <= 0.0:
		window_width = get_viewport().get_visible_rect().size.x
	return window_width >= WIDE_BREAKPOINT


func _mobile_ui_scale() -> float:
	# The canvas is 720 units tall on a landscape phone, so on a dense screen
	# the default text ends up physically tiny. Bring the 19-unit row titles up
	# to roughly 19dp, independent of resolution, while keeping the scale inside
	# sane bounds. Mobile always uses the compact top navigation.
	if not OS.has_feature("mobile"):
		return 1.0
	var dpi: float = float(DisplayServer.screen_get_dpi())
	var window_height: float = float(DisplayServer.window_get_size().y)
	var viewport_height: float = get_viewport().get_visible_rect().size.y
	if dpi <= 0.0 or window_height <= 0.0 or viewport_height <= 0.0:
		return MOBILE_UI_SCALE_FALLBACK
	var canvas_scale: float = window_height / viewport_height
	var units_per_dp: float = (dpi / 160.0) / maxf(canvas_scale, 0.01)
	var target_units: float = MOBILE_ROW_TARGET_DP * units_per_dp
	return clampf(target_units / MOBILE_BASE_ROW_UNITS, MOBILE_UI_SCALE_MIN, MOBILE_UI_SCALE_MAX)


func _on_viewport_resized() -> void:
	var wide := _is_wide_layout()
	if wide == _wide_layout:
		return
	# The navigation moves between the side and the top, so the shell is
	# rebuilt rather than re-parented. The active tab survives.
	_wide_layout = wide
	_about_overlay = null
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_tab_buttons.clear()
	_content_container = null
	_content_scroll = null
	_page_title_label = null
	_page_subtitle_label = null
	_build_ui()
	_load_current_settings()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Palette.NIGHT_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var edge: int = SettingsUI.px(26 if _wide_layout else 16)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, edge)
	add_child(margin)

	if _wide_layout:
		var shell := HBoxContainer.new()
		shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		shell.add_theme_constant_override("separation", 22)
		margin.add_child(shell)
		shell.add_child(_build_sidebar())
		var wide_content := SettingsUI.ContentLimit.new()
		wide_content.max_width = float(SettingsUI.px(CONTENT_MAX_WIDTH))
		wide_content.add_child(_build_main_column(false))
		shell.add_child(wide_content)
	else:
		var shell := VBoxContainer.new()
		shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		shell.add_theme_constant_override("separation", SettingsUI.px(10))
		margin.add_child(shell)
		var compact_content := SettingsUI.ContentLimit.new()
		compact_content.max_width = float(SettingsUI.px(CONTENT_MAX_WIDTH))
		compact_content.add_child(_build_main_column(true))
		shell.add_child(compact_content)

	_update_page_header()
	_build_tab_content()


func _build_sidebar() -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 258
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_style_scroll(scroll)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb := SettingsUI.flat(Palette.SURFACE_0, 20)
	SettingsUI.pad(sb, SettingsUI.px(14), SettingsUI.px(18))
	panel.add_theme_stylebox_override("panel", sb)
	scroll.add_child(panel)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)

	var brand := VBoxContainer.new()
	brand.mouse_filter = Control.MOUSE_FILTER_PASS
	brand.add_theme_constant_override("separation", 0)
	var wordmark := SettingsUI.label("DRUM HERO", 11, Palette.ACCENT, 600)
	brand.add_child(wordmark)
	brand.add_child(SettingsUI.label("Settings", 30, Palette.BONE_HI, 600))
	var brand_pad := MarginContainer.new()
	brand_pad.mouse_filter = Control.MOUSE_FILTER_PASS
	brand_pad.add_theme_constant_override("margin_left", 8)
	brand_pad.add_theme_constant_override("margin_bottom", 12)
	brand_pad.add_child(brand)
	column.add_child(brand_pad)

	var nav := VBoxContainer.new()
	nav.add_theme_constant_override("separation", 4)
	nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(nav)
	for i in TAB_COUNT:
		var button := _build_nav_button(i, false)
		nav.add_child(button)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.custom_minimum_size.y = 16
	spacer.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(spacer)

	column.add_child(SettingsUI.divider())
	var about := SettingsUI.button("About Drum Hero", "quiet")
	about.alignment = HORIZONTAL_ALIGNMENT_LEFT
	about.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	about.pressed.connect(_show_about)
	column.add_child(about)

	var version: String = str(ProjectSettings.get_setting("application/config/version", "1.0.0"))
	var version_label := SettingsUI.label("Version " + version, 11, Palette.MUTED)
	var version_pad := MarginContainer.new()
	version_pad.mouse_filter = Control.MOUSE_FILTER_PASS
	version_pad.add_theme_constant_override("margin_left", 16)
	version_pad.add_child(version_label)
	column.add_child(version_pad)
	return scroll


func _build_main_column(compact_nav: bool) -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_theme_constant_override("separation", SettingsUI.px(12))
	column.add_child(_build_page_header())
	if compact_nav:
		column.add_child(_build_nav_strip())
	column.add_child(_build_content_scroll())
	return column


func _build_page_header() -> Control:
	var header_scroll := ScrollContainer.new()
	header_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	header_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_style_scroll(header_scroll)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.mouse_filter = Control.MOUSE_FILTER_PASS
	header.add_theme_constant_override("separation", SettingsUI.px(18))
	header_scroll.add_child(header)

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titles.mouse_filter = Control.MOUSE_FILTER_PASS
	titles.add_theme_constant_override("separation", SettingsUI.px(2))
	_page_title_label = SettingsUI.title("Controls")
	_page_title_label.add_theme_font_size_override("font_size", SettingsUI.px(34 if _wide_layout else 28))
	_page_subtitle_label = SettingsUI.subtitle("")
	titles.add_child(_page_title_label)
	titles.add_child(_page_subtitle_label)
	header.add_child(titles)

	var back := SettingsUI.button("Back", "ghost")
	back.custom_minimum_size = Vector2(SettingsUI.px(104), SettingsUI.px(46))
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_on_back)
	if not _wide_layout:
		var about := SettingsUI.button("About", "quiet")
		about.custom_minimum_size = Vector2(SettingsUI.px(88), SettingsUI.px(46))
		about.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		about.pressed.connect(_show_about)
		header.add_child(about)
	header.add_child(back)
	return header_scroll


func _build_nav_strip() -> Control:
	var nav_scroll := ScrollContainer.new()
	nav_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_scroll.custom_minimum_size.y = SettingsUI.px(58)
	nav_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	nav_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var sb := SettingsUI.flat(Palette.SURFACE_0, 14)
	SettingsUI.pad(sb, SettingsUI.px(4), SettingsUI.px(4))
	nav_scroll.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", SettingsUI.px(4))
	nav_scroll.add_child(row)
	for i in TAB_COUNT:
		row.add_child(_build_nav_button(i, true))
	return nav_scroll


func _build_nav_button(index: int, compact: bool) -> Button:
	var button := SettingsUI.nav_button(TAB_NAMES[index], TAB_ICONS[index], compact)
	button.button_pressed = (index == _current_tab)
	button.pressed.connect(_on_tab_selected.bind(index))
	_tab_buttons.append(button)
	return button


func _build_content_scroll() -> Control:
	var content_scroll := ScrollContainer.new()
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content_scroll.follow_focus = true
	_style_scroll(content_scroll)
	_content_scroll = content_scroll

	var wrapper := MarginContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.mouse_filter = Control.MOUSE_FILTER_PASS
	wrapper.add_theme_constant_override("margin_bottom", SettingsUI.px(24))
	content_scroll.add_child(wrapper)

	_content_container = VBoxContainer.new()
	_content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_container.mouse_filter = Control.MOUSE_FILTER_PASS
	_content_container.add_theme_constant_override("separation", SettingsUI.px(16))
	wrapper.add_child(_content_container)
	return content_scroll


func _style_scroll(scroll: ScrollContainer) -> void:
	scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_style_scroll_bar(scroll.get_v_scroll_bar())
	_style_scroll_bar(scroll.get_h_scroll_bar())


func _style_scroll_bar(bar: ScrollBar) -> void:
	if bar is VScrollBar:
		bar.custom_minimum_size.x = SettingsUI.px(10)
	else:
		bar.custom_minimum_size.y = SettingsUI.px(10)
	bar.add_theme_stylebox_override("scroll", SettingsUI.flat(Color.TRANSPARENT, 4))
	bar.add_theme_stylebox_override("grabber", SettingsUI.flat(Color(1, 1, 1, 0.14), 4))
	bar.add_theme_stylebox_override("grabber_highlight", SettingsUI.flat(Color(1, 1, 1, 0.26), 4))
	bar.add_theme_stylebox_override("grabber_pressed", SettingsUI.flat(Color(1, 1, 1, 0.34), 4))


func _update_page_header() -> void:
	if not is_instance_valid(_page_title_label) or not is_instance_valid(_page_subtitle_label):
		return
	var page: Dictionary = PAGE_INFO[clampi(_current_tab, 0, PAGE_INFO.size() - 1)]
	_page_title_label.text = str(page["title"])
	_page_subtitle_label.text = str(page["subtitle"])


func _on_tab_selected(tab_index: int) -> void:
	_current_tab = tab_index
	for i in _tab_buttons.size():
		_tab_buttons[i].set_pressed_no_signal(i == tab_index)
		_tab_buttons[i].queue_redraw()
	if _current_tab != SONGS_TAB:
		# The scan belongs to this tab: if the player leaves, it stops. The
		# widgets are destroyed with the content and there is no point in
		# continuing to track them.
		_abort_scan()
	_update_page_header()
	_build_tab_content()


func _build_tab_content() -> void:
	# The tab widgets are destroyed with the content. Clearing the references
	# here keeps the keyboard follow-up from touching a node queued for free.
	_root_path_edit = null
	_root_location_option = null
	_keyboard_spacer = null
	_library_section = null
	_permission_status = null
	_permission_button = null
	_custom_lane_container = null
	_custom_lane_card = null
	_haptic_enabled_check = null
	_mode_desc_label = null
	_fps_cap_slider = null
	_padding_check = null
	_padding_left_slider = null
	_padding_right_slider = null
	_padding_top_slider = null
	_padding_bottom_slider = null
	_keyboard_settle_frames = 0
	_field_touch_active = false
	_field_touch_dragging = false
	for child in _content_container.get_children():
		_content_container.remove_child(child)
		child.queue_free()

	match _current_tab:
		0:
			_build_controls_content(_content_container)
		1:
			_build_gameplay_content(_content_container)
		2:
			_build_audio_content(_content_container)
		SONGS_TAB:
			_build_songs_content(_content_container)
		4:
			_build_advanced_content(_content_container)

	if is_instance_valid(_content_container):
		_content_container.modulate.a = 0.0
		var fade := create_tween()
		fade.tween_property(_content_container, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_content_scroll):
		_content_scroll.scroll_vertical = 0


func _build_controls_content(parent: VBoxContainer) -> void:
	_mode_buttons.clear()

	var mode_card := SettingsUI.section("CONTROL MODE")
	mode_card.body.add_child(SettingsUI.description("Choose the layout the highway opens with."))
	var segmented := SettingsUI.Segmented.new(["Default", "Haptic", "Custom"])
	for i in segmented.buttons.size():
		segmented.buttons[i].button_pressed = (i == SettingsManager.game_mode)
		segmented.buttons[i].toggled.connect(_on_mode_toggled.bind(i))
		_mode_buttons.append(segmented.buttons[i])
	mode_card.body.add_child(segmented)
	_mode_desc_label = SettingsUI.description(MODE_DESCRIPTIONS[clampi(SettingsManager.game_mode, 0, 2)])
	mode_card.body.add_child(_mode_desc_label)
	parent.add_child(mode_card)

	var lane_card := SettingsUI.section("LANE ORDER", "Arrange the highway from left to right. The kick is a lane here too.")
	_custom_lane_card = lane_card
	lane_card.visible = (SettingsManager.game_mode == 2)
	parent.add_child(lane_card)
	_custom_lane_container = VBoxContainer.new()
	_custom_lane_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_custom_lane_container.mouse_filter = Control.MOUSE_FILTER_PASS
	_custom_lane_container.add_theme_constant_override("separation", SettingsUI.px(8))
	lane_card.body.add_child(_custom_lane_container)
	_rebuild_custom_lane_ui(SettingsManager.custom_lanes)

	var layout_card := SettingsUI.section("LAYOUT")
	parent.add_child(layout_card)
	SettingsUI.add_toggle(layout_card.body, "Mirrored layout", "Flip the highway from left to right.", SettingsManager.mirrored, _on_mirrored_toggled)
	SettingsUI.add_toggle(layout_card.body, "Left-handed mode", "Put the most-used pads under the left hand.", SettingsManager.left_handed, _on_left_handed_toggled)

	var haptic_card := SettingsUI.section("HAPTIC KICK", "Play the kick by tilting the device instead of tapping a pad.")
	parent.add_child(haptic_card)
	_haptic_enabled_check = SettingsUI.add_toggle(haptic_card.body, "Enable haptic kick", "A short forward tilt fires the kick.", SettingsManager.haptic_enabled, _on_haptic_enabled_toggled)
	_haptic_enabled_check.disabled = (SettingsManager.game_mode == 1)
	if SettingsManager.game_mode == 1:
		haptic_card.body.add_child(SettingsUI.description("Haptic mode always enables the motion kick."))
	SettingsUI.add_slider_row(haptic_card.body, "Sensitivity", "How much movement is needed for kick detection.", 0.1, 3.0, 0.1, SettingsManager.haptic_sensitivity, _fmt_number, _on_haptic_sensitivity_changed, _on_haptic_sensitivity_drag_ended)

	var tuning := _add_disclosure(haptic_card.body, "Advanced tuning", "Activation, release, cooldown and smoothing.")
	SettingsUI.add_slider_row(tuning, "Activation", "Lift threshold before a kick is detected.", 0.5, 12.0, 0.5, SettingsManager.haptic_activation_threshold, _fmt_number, _on_haptic_activation_changed, _on_haptic_any_drag_ended)
	SettingsUI.add_slider_row(tuning, "Release", "When the kick resets after firing.", 0.1, 8.0, 0.5, SettingsManager.haptic_release_threshold, _fmt_number, _on_haptic_release_changed, _on_haptic_any_drag_ended)
	SettingsUI.add_slider_row(tuning, "Cooldown", "Minimum time between two kicks.", 0.05, 0.5, 0.01, SettingsManager.haptic_cooldown_duration, _fmt_seconds, _on_haptic_cooldown_changed, _on_haptic_any_drag_ended)
	SettingsUI.add_slider_row(tuning, "Min interval", "Ignore taps closer together than this.", 0.02, 0.3, 0.01, SettingsManager.haptic_min_interval, _fmt_seconds, _on_haptic_min_interval_changed, _on_haptic_any_drag_ended)
	SettingsUI.add_slider_row(tuning, "Smoothing", "Higher values are steadier but slower to react.", 0.01, 0.5, 0.01, SettingsManager.haptic_smoothing_strength, _fmt_number, _on_haptic_smoothing_changed, _on_haptic_any_drag_ended)
	tuning.add_child(SettingsUI.description("Activation is divided by the sensitivity above."))

	var free_card := SettingsUI.section("FREE MODE", "Check the pads and the haptic pedal without loading a song.")
	parent.add_child(free_card)
	var open := SettingsUI.button("Open Free Mode", "secondary")
	open.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	open.pressed.connect(_on_free_mode_pressed)
	free_card.body.add_child(open)
	free_card.body.add_child(SettingsUI.description("Drum testing without a song: hit any pad to hear it and check the lane order, layout and haptic pedal."))

	_add_reset_section_button(parent, "CONTROLS", _on_reset_controls)


func _build_gameplay_content(parent: VBoxContainer) -> void:
	var pacing := SettingsUI.section("SPEED & PACING")
	parent.add_child(pacing)
	SettingsUI.add_slider_row(pacing.body, "Note speed", "How fast notes travel down the highway.", 0.5, 3.0, 0.25, SettingsManager.note_speed, _fmt_speed, _on_note_speed_changed, _on_note_speed_drag_ended)
	SettingsUI.add_slider_row(pacing.body, "Silence countdown", "Start the countdown after this much silence.", 1.0, 15.0, 0.5, SettingsManager.countdown_threshold, _fmt_seconds, _on_countdown_changed, _on_countdown_drag_ended)

	var feedback := SettingsUI.section("FEEDBACK")
	parent.add_child(feedback)
	SettingsUI.add_toggle(feedback.body, "Show hit feedback", "Judgement text (PERFECT, GOOD...) at the hit line.", SettingsManager.show_hit_feedback, _on_hit_feedback_toggled)
	SettingsUI.add_toggle(feedback.body, "Screen shake", "Shake the highway on hard hits.", SettingsManager.screen_shake, _on_screen_shake_toggled)

	var performance := SettingsUI.section("PERFORMANCE")
	parent.add_child(performance)
	SettingsUI.add_toggle(performance.body, "Show FPS", "Display the frame rate while playing.", SettingsManager.show_fps, _on_fps_toggled)
	_fps_cap_slider = SettingsUI.add_slider_row(performance.body, "Max FPS", "0 means unlimited.", 0.0, 120.0, 10.0, SettingsManager.max_fps, _fmt_fps, _on_fps_cap_changed, _on_fps_cap_drag_ended)

	var timing := SettingsUI.section("TIMING & CALIBRATION")
	parent.add_child(timing)
	SettingsUI.add_slider_row(timing.body, "Note offset", "Raise it if notes feel early, lower it if they feel late.", -200.0, 200.0, 1.0, SettingsManager.audio_offset_ms, _fmt_ms, _on_audio_offset_changed, _on_audio_setting_drag_ended)
	var windows := _add_disclosure(timing.body, "Judgement windows", "The timing windows used to score every hit.")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	grid.add_theme_constant_override("h_separation", SettingsUI.px(8))
	grid.add_theme_constant_override("v_separation", SettingsUI.px(8))
	var judgement_data: Array[Dictionary] = [
		{"label": "Perfect", "key": "judgement_perfect_ms"},
		{"label": "Excellent", "key": "judgement_excellent_ms"},
		{"label": "Good", "key": "judgement_good_ms"},
		{"label": "Late", "key": "judgement_late_ms"},
		{"label": "Early", "key": "judgement_early_ms"},
		{"label": "Miss", "key": "judgement_miss_ms"},
	]
	for jd in judgement_data:
		_add_stat_chip(grid, str(jd["label"]), "+/-" + str(SettingsManager.get(jd["key"])) + " ms")
	windows.add_child(grid)

	_add_reset_section_button(parent, "GAMEPLAY", _on_reset_hud)


func _build_audio_content(parent: VBoxContainer) -> void:
	var volume := SettingsUI.section("VOLUME")
	parent.add_child(volume)
	SettingsUI.add_slider_row(volume.body, "Master", "Overall output level.", 0.0, 1.0, 0.05, SettingsManager.master_volume, _fmt_percent, _on_master_volume_changed, _on_audio_setting_drag_ended)
	SettingsUI.add_slider_row(volume.body, "Music", "Song stems and gameplay audio.", 0.0, 1.0, 0.05, SettingsManager.music_volume, _fmt_percent, _on_music_volume_changed, _on_audio_setting_drag_ended)
	SettingsUI.add_slider_row(volume.body, "Drums & effects", "Drum pads and interface sounds.", 0.0, 1.0, 0.05, SettingsManager.sfx_volume, _fmt_percent, _on_sfx_volume_changed, _on_audio_setting_drag_ended)
	SettingsUI.add_slider_row(volume.body, "Menu previews", "The automatic song preview on the main menu.", 0.0, 1.0, 0.05, SettingsManager.preview_volume, _fmt_percent, _on_preview_volume_changed, _on_audio_setting_drag_ended)

	var samples := SettingsUI.section("DRUM SAMPLES", "How pads without a velocity sensor are played.")
	parent.add_child(samples)
	SettingsUI.add_slider_row(samples.body, "Default Velocity", "0-20 is the softest kick layer, 105-127 the hardest.", 0.0, 127.0, 1.0, float(SettingsManager.default_sample_velocity), _fmt_velocity, _on_sample_velocity_changed, _on_sample_velocity_drag_ended)
	samples.body.add_child(SettingsUI.description("Clone Hero uses 100 by default. Kick layers: 0-20 softest, 105-127 hardest."))

	_add_reset_section_button(parent, "AUDIO", _on_reset_audio)


func _build_advanced_content(parent: VBoxContainer) -> void:
	var compatibility := SettingsUI.section("COMPATIBILITY")
	parent.add_child(compatibility)
	SettingsUI.add_toggle(compatibility.body, "Use PART GUITAR as fallback", "For songs without PART DRUMS, play the guitar chart as drums.", SettingsManager.use_guitar_fallback, _on_fallback_toggled)

	var debug_card := SettingsUI.section("DEBUG")
	parent.add_child(debug_card)
	SettingsUI.add_toggle(debug_card.body, "Show Judgment Areas", "Draw the timing windows on the hit line.", SettingsManager.show_judgment_areas, _on_judgment_areas_toggled)
	SettingsUI.add_toggle(debug_card.body, "Show Haptic Debug", "Visualize accelerometer data and kick detection.", SettingsManager.haptic_show_debug, _on_haptic_debug_toggled)
	SettingsUI.add_toggle(debug_card.body, "Show Menu Status", "Show the song and chart status line on the main menu.", SettingsManager.show_menu_status, _on_menu_status_toggled)

	var padding_card := SettingsUI.section("SCREEN PADDING", "Condense gameplay and the HUD away from gesture edges.")
	parent.add_child(padding_card)
	_padding_check = SettingsUI.add_toggle(padding_card.body, "Enable Gameplay Padding", "Keeps the highway clear of the edge-swipe area.", SettingsManager.gameplay_padding_enabled, _on_padding_enabled_toggled)
	_padding_left_slider = SettingsUI.add_slider_row(padding_card.body, "Left", "", 0.0, 100.0, 1.0, SettingsManager.gameplay_padding_left, _fmt_dp, _on_padding_left_changed, _on_padding_any_drag_ended)
	_padding_right_slider = SettingsUI.add_slider_row(padding_card.body, "Right", "", 0.0, 100.0, 1.0, SettingsManager.gameplay_padding_right, _fmt_dp, _on_padding_right_changed, _on_padding_any_drag_ended)
	_padding_top_slider = SettingsUI.add_slider_row(padding_card.body, "Top", "", 0.0, 100.0, 1.0, SettingsManager.gameplay_padding_top, _fmt_dp, _on_padding_top_changed, _on_padding_any_drag_ended)
	_padding_bottom_slider = SettingsUI.add_slider_row(padding_card.body, "Bottom", "", 0.0, 100.0, 1.0, SettingsManager.gameplay_padding_bottom, _fmt_dp, _on_padding_bottom_changed, _on_padding_any_drag_ended)
	_apply_padding_sliders_editable(SettingsManager.gameplay_padding_enabled)
	if OS.get_name() != "Android":
		_padding_check.disabled = true
		padding_card.body.add_child(SettingsUI.description("Padding is only applied on Android."))
		_apply_padding_sliders_editable(false)

	_add_reset_section_button(parent, "ADVANCED", _on_reset_experimental)


func _add_disclosure(parent: VBoxContainer, title_text: String, subtitle_text: String) -> VBoxContainer:
	var toggle := SettingsUI.button(title_text + "   +", "quiet")
	toggle.toggle_mode = true
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	toggle.custom_minimum_size.y = SettingsUI.px(44)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", SettingsUI.px(16))
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	body.visible = false
	toggle.toggled.connect(func(on: bool) -> void:
		body.visible = on
		toggle.text = title_text + ("   -" if on else "   +")
	)
	parent.add_child(SettingsUI.TapRow.new(toggle, subtitle_text, 0))
	parent.add_child(body)
	return body


func _add_stat_chip(parent: GridContainer, name_text: String, value_text: String) -> void:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb := SettingsUI.flat(Palette.SURFACE_2, 10)
	SettingsUI.pad(sb, SettingsUI.px(12), SettingsUI.px(7))
	chip.add_theme_stylebox_override("panel", sb)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row_box := HBoxContainer.new()
	row_box.mouse_filter = Control.MOUSE_FILTER_PASS
	row_box.add_theme_constant_override("separation", SettingsUI.px(8))
	var name_label := SettingsUI.label(name_text, 13, Palette.ASH, 400)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_box.add_child(name_label)
	row_box.add_child(SettingsUI.label(value_text, 13, Palette.BONE, 500))
	chip.add_child(row_box)
	parent.add_child(chip)


# --- Formatting -------------------------------------------------------------

func _fmt_number(value: float) -> String:
	return str(snappedf(value, 0.01))


func _fmt_speed(value: float) -> String:
	return "x" + str(snappedf(value, 0.01))


func _fmt_seconds(value: float) -> String:
	return str(snappedf(value, 0.01)) + "s"


func _fmt_fps(value: float) -> String:
	return "Unlimited" if value <= 0.0 else str(int(value)) + " FPS"


func _fmt_dp(value: float) -> String:
	return str(int(value)) + " dp"


func _fmt_percent(value: float) -> String:
	return str(int(round(value * 100.0))) + "%"


func _fmt_ms(value: float) -> String:
	var prefix: String = "+" if value > 0.0 else ""
	return prefix + str(int(value)) + " ms"


func _fmt_velocity(value: float) -> String:
	return str(int(value))


func _build_songs_content(parent: VBoxContainer) -> void:
	var songs_card := SettingsUI.section("NEED SONGS?")
	parent.add_child(songs_card)
	songs_card.body.add_child(SettingsUI.description("Browse community song folders and packs from the Drum Hero link tree."))
	var get_songs_button := SettingsUI.button("Get songs", "secondary")
	get_songs_button.name = "GetSongsButton"
	get_songs_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	get_songs_button.pressed.connect(_on_get_songs_pressed)
	songs_card.body.add_child(get_songs_button)
	_songs_link_status = SettingsUI.description("", Palette.BLOOD_GLOW)
	_songs_link_status.visible = false
	songs_card.body.add_child(_songs_link_status)

	var storage_card := SettingsUI.section("STORAGE ACCESS")
	parent.add_child(storage_card)
	_build_permission_section(storage_card.body)

	# Everything below only makes sense once the app can actually read external
	# folders. On Android before the grant, the tab keeps the two ways out
	# (Get songs and Grant access) and nothing else.
	_library_section = VBoxContainer.new()
	_library_section.name = "LibrarySection"
	_library_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_library_section.mouse_filter = Control.MOUSE_FILTER_PASS
	_library_section.add_theme_constant_override("separation", SettingsUI.px(16))
	parent.add_child(_library_section)
	_apply_library_access()

	var locations_card := SettingsUI.section("LIBRARY LOCATIONS", "Songs are read in place from these folders. Nothing is copied or imported.")
	_library_section.add_child(locations_card)
	SettingsUI.add_toggle(locations_card.body, "Scan Download", "Include the device Download folder in the scan.", SettingsManager.library_preset_downloads, _on_preset_downloads_toggled)
	locations_card.body.add_child(SettingsUI.divider())

	var depth_option := OptionButton.new()
	depth_option.add_theme_font_size_override("font_size", SettingsUI.px(16))
	for i in 6:
		depth_option.add_item(("Only this folder" if i == 0 else "Up to " + str(i) + " levels"), i)
	depth_option.select(clampi(SettingsManager.library_max_depth, 0, 5))
	depth_option.item_selected.connect(_on_depth_selected)
	SettingsUI.style_option(depth_option)
	locations_card.body.add_child(SettingsUI.row("Max subfolder depth", "How far below each location the scan looks.", depth_option))

	SettingsUI.add_toggle(locations_card.body, "Search subfolders", "Look inside the folders below each location.", SettingsManager.library_recursive, _on_recursive_toggled)

	var folders_card := SettingsUI.section("EXTRA FOLDERS", "Add any folder from internal or external storage.")
	_library_section.add_child(folders_card)
	_roots_container = VBoxContainer.new()
	_roots_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roots_container.mouse_filter = Control.MOUSE_FILTER_PASS
	_roots_container.add_theme_constant_override("separation", SettingsUI.px(8))
	folders_card.body.add_child(_roots_container)
	_rebuild_roots_list()

	var add_hbox := HBoxContainer.new()
	add_hbox.add_theme_constant_override("separation", SettingsUI.px(8))
	add_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	var location_option := OptionButton.new()
	location_option.name = "StorageLocationOption"
	_storage_locations = _resolve_storage_locations()
	for location in _storage_locations:
		location_option.add_item("%s (%s)" % [location["label"], location["path"]])
	location_option.select(0)
	location_option.custom_minimum_size.x = SettingsUI.px(210)
	SettingsUI.style_option(location_option)
	add_hbox.add_child(location_option)
	_root_location_option = location_option
	var path_edit := LineEdit.new()
	path_edit.name = "ExtraFolderPathEdit"
	path_edit.placeholder_text = "Download/RockBand"
	SettingsUI.style_line_edit(path_edit)
	path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_edit.text_submitted.connect(_on_root_path_submitted)
	path_edit.focus_entered.connect(_on_root_path_focus_entered.bind(path_edit))
	path_edit.focus_exited.connect(_on_root_path_focus_exited.bind(path_edit))
	add_hbox.add_child(path_edit)
	_root_path_edit = path_edit
	var add_btn := SettingsUI.button("Add", "primary")
	add_btn.custom_minimum_size = Vector2(SettingsUI.px(96), SettingsUI.px(46))
	add_btn.pressed.connect(_on_add_extra_folder)
	add_hbox.add_child(add_btn)
	folders_card.body.add_child(add_hbox)
	folders_card.body.add_child(SettingsUI.description("Pick a storage location, then type the folder inside it (for example Download/RockBand). An absolute path is still accepted."))

	var scan_card := SettingsUI.section("LIBRARY SCAN", "The list is cached, so scanning only runs when you ask for it.")
	_library_section.add_child(scan_card)
	var scan_buttons := HBoxContainer.new()
	scan_buttons.add_theme_constant_override("separation", SettingsUI.px(10))
	scan_buttons.mouse_filter = Control.MOUSE_FILTER_PASS
	_rescan_button = SettingsUI.button("Rescan now", "primary")
	_rescan_button.name = "RescanButton"
	_rescan_button.pressed.connect(_on_rescan_pressed)
	scan_buttons.add_child(_rescan_button)
	_cancel_scan_button = SettingsUI.button("Cancel", "ghost")
	_cancel_scan_button.name = "CancelScanButton"
	_cancel_scan_button.custom_minimum_size.x = SettingsUI.px(120)
	_cancel_scan_button.pressed.connect(_on_cancel_scan_pressed)
	scan_buttons.add_child(_cancel_scan_button)
	scan_card.body.add_child(scan_buttons)

	# Scan indicator. The summary below only updates when the walk finishes, so
	# without this the panel stays mute for the whole walk, which in a large
	# library is several seconds with no feedback.
	_scan_bar = ScanFeedback.make_progress_bar()
	_scan_bar.name = "ScanBar"
	SettingsUI.style_progress(_scan_bar)
	scan_card.body.add_child(_scan_bar)

	_scan_status = ScanFeedback.make_status_label()
	_scan_status.name = "ScanStatus"
	_scan_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_scan_status.add_theme_font_size_override("font_size", SettingsUI.px(15))
	scan_card.body.add_child(_scan_status)

	_scan_folder = ScanFeedback.make_folder_label()
	_scan_folder.name = "ScanFolder"
	_scan_folder.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_scan_folder.add_theme_font_size_override("font_size", SettingsUI.px(14))
	scan_card.body.add_child(_scan_folder)

	_scan_summary = SettingsUI.description("")
	_scan_summary.add_theme_font_size_override("font_size", SettingsUI.px(13))
	scan_card.body.add_child(_scan_summary)
	_refresh_scan_widgets()
	_update_scan_summary()

	_add_reset_section_button(parent, "SONGS", _on_reset_songs)

	# Extra bottom room while the keyboard is open. The input itself keeps its
	# place in the tab; this only lets the ScrollContainer move it into view.
	_keyboard_spacer = Control.new()
	_keyboard_spacer.name = "KeyboardSpacer"
	_keyboard_spacer.custom_minimum_size.y = 0.0
	_keyboard_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_library_section.add_child(_keyboard_spacer)

func _library_access_granted() -> bool:
	if OS.get_name() != "Android":
		return true
	# A build without the plugin has nothing to grant; hiding the controls would
	# leave the tab with no way forward at all.
	if not AndroidBridge.is_storage_plugin_available():
		return true
	return AndroidBridge.has_all_files_access()


func _apply_library_access() -> void:
	if is_instance_valid(_library_section):
		_library_section.visible = _library_access_granted()


func _build_permission_section(parent: VBoxContainer) -> void:
	if OS.get_name() != "Android":
		var desktop_note := SettingsUI.description("External storage access is automatic on this platform.", Palette.CHROME)
		parent.add_child(desktop_note)
		return

	_permission_status = SettingsUI.label("", 15, Palette.CHROME, 400)
	_permission_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_permission_status)

	_permission_button = SettingsUI.button("", "secondary")
	_permission_button.custom_minimum_size.x = SettingsUI.px(240)
	_permission_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_permission_button.pressed.connect(_on_permission_pressed)
	parent.add_child(_permission_button)
	_permission_was_granted = AndroidBridge.has_all_files_access()
	_update_permission_section()


func _update_permission_section() -> void:
	if not is_instance_valid(_permission_status):
		return
	if not AndroidBridge.is_storage_plugin_available():
		_permission_status.text = "Storage plugin missing from this build. The Android export did not include the AllFilesAccess plugin, so external folders cannot be read."
		_permission_status.add_theme_color_override("font_color", Palette.BLOOD_GLOW)
		_permission_button.text = "Unavailable"
		_permission_button.disabled = true
		return
	_permission_button.disabled = false
	if AndroidBridge.has_all_files_access():
		_permission_status.text = "Granted. Folders outside the app sandbox can be scanned."
		_permission_status.add_theme_color_override("font_color", Palette.CHROME)
		_permission_button.text = "Open Android settings"
		return
	_permission_status.text = "Not granted. Grant access to choose the folders where songs are read from."
	_permission_status.add_theme_color_override("font_color", Palette.BLOOD_GLOW)
	_permission_button.text = "Grant access"


func _on_permission_pressed() -> void:
	var ok: bool = false
	if AndroidBridge.has_all_files_access():
		ok = AndroidBridge.open_all_files_settings()
	else:
		ok = AndroidBridge.request_all_files_access()
	if not ok:
		_permission_status.text = "Could not open Android settings (" + AndroidBridge.get_storage_last_error() + "). Grant \"All files access\" manually for Drum Hero in Android Settings > Apps."
		_permission_status.add_theme_color_override("font_color", Palette.BLOOD_GLOW)
		return
	_update_permission_section()


func _rebuild_roots_list() -> void:
	if not is_instance_valid(_roots_container):
		return
	for child in _roots_container.get_children():
		_roots_container.remove_child(child)
		child.queue_free()

	if SettingsManager.library_roots.is_empty():
		var empty := SettingsUI.description("(no extra folders)", Palette.MUTED)
		_roots_container.add_child(empty)
		return

	for i in SettingsManager.library_roots.size():
		var path: String = SettingsManager.library_roots[i]
		var item := PanelContainer.new()
		item.mouse_filter = Control.MOUSE_FILTER_PASS
		var sb := SettingsUI.flat(Palette.SURFACE_2, 12)
		SettingsUI.pad(sb, SettingsUI.px(14), SettingsUI.px(8))
		item.add_theme_stylebox_override("panel", sb)
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var hbox := HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.mouse_filter = Control.MOUSE_FILTER_PASS
		hbox.add_theme_constant_override("separation", SettingsUI.px(12))
		item.add_child(hbox)

		var path_label := SettingsUI.label(path, 14, Palette.BONE, 400)
		path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if not DirAccess.dir_exists_absolute(path):
			path_label.add_theme_color_override("font_color", Palette.BLOOD_GLOW)
		hbox.add_child(path_label)

		var remove_btn := SettingsUI.button("Remove", "quiet")
		remove_btn.custom_minimum_size.y = SettingsUI.px(40)
		remove_btn.add_theme_color_override("font_color", Palette.ASH)
		remove_btn.pressed.connect(_on_remove_root.bind(i))
		hbox.add_child(remove_btn)

		_roots_container.add_child(item)


func _update_scan_summary() -> void:
	if not is_instance_valid(_scan_summary):
		return
	var lines: PackedStringArray = PackedStringArray()
	# Visited locations, not configured ones: a scan that was cancelled (or cut
	# short by leaving this tab) never reached the remaining roots, and claiming
	# otherwise made a missing library look like a scan that had found nothing.
	var last_scan: String = _format_last_scan()
	lines.append("Last scan: %s - %d songs from %d of %d location(s) (recursive=%s, depth=%d)." % [
		last_scan,
		SongLoader.song_list.size(),
		SongLoader.visited_roots.size(),
		SongLoader.get_scan_roots().size(),
		"on" if SettingsManager.library_recursive else "off",
		SettingsManager.library_max_depth,
	])
	# Scanning is explicit: this is the only place that tells the player the
	# cached list no longer matches the current roots/settings. While a scan is
	# running the progress widgets already explain what is happening.
	var stale_reason: String = "" if SongLoader.is_scanning else SongLoader.library_rescan_reason()
	if not stale_reason.is_empty():
		lines.append(stale_reason + " Press Rescan now to refresh the library.")
	var blocked: int = 0
	for song in SongLoader.song_list:
		if song.get("audio_blocked", false):
			blocked += 1
	if blocked > 0:
		lines.append("Audio: " + str(blocked) + " song(s) have song.opus with no song.ogg. Android cannot decode .opus, so these play silent. Convert them with tools/convert_opus_to_ogg.sh.")
	for path in SongLoader.unreadable_roots:
		lines.append("Unreadable: " + path)
	for path in SongLoader.truncated_roots:
		lines.append("Too deep (raise max subfolder depth): " + path)
	for path in SongLoader.cancelled_roots:
		lines.append("Scan cancelled before finishing here, this location may have more songs: " + path)
	for path in SongLoader.unvisited_roots:
		if SongLoader.cancelled_roots.has(path):
			continue
		lines.append("Not scanned, this location was never reached: " + path)
	_scan_summary.text = "\n".join(lines)


func _format_last_scan() -> String:
	# Relative age is locale-free and easier to read than a UTC timestamp.
	if SongLoader.last_scan_at <= 0:
		return "never"
	var age: int = int(Time.get_unix_time_from_system()) - SongLoader.last_scan_at
	if age < 60:
		return "just now"
	if age < 3600:
		return str(age / 60) + " min ago"
	if age < 86400:
		return str(age / 3600) + " h ago"
	return str(age / 86400) + " day(s) ago"


func _resolve_storage_locations() -> Array[Dictionary]:
	# Android has fixed public mount points. On desktop $HOME is the useful
	# base: it always exists and the common Music/Downloads folders live
	# directly below it, so the player only types the part after it.
	if OS.get_name() == "Android":
		return STORAGE_LOCATIONS
	var home: String = OS.get_environment("HOME").strip_edges()
	if home.is_empty():
		return STORAGE_LOCATIONS
	return [{"label": "Home", "path": home.simplify_path()}]


func _selected_storage_base() -> String:
	var locations: Array[Dictionary] = _storage_locations if not _storage_locations.is_empty() else STORAGE_LOCATIONS
	if is_instance_valid(_root_location_option) and _root_location_option.selected >= 0:
		var index: int = clampi(_root_location_option.selected, 0, locations.size() - 1)
		return str(locations[index]["path"])
	return str(locations[0]["path"])


func _compose_root_path(folder: String) -> String:
	var typed: String = folder.strip_edges()
	if typed.is_empty():
		return ""
	# Pasted absolute paths keep working, so the form is not limited to the two
	# presets (a file manager may hand out any mount point).
	if typed.begins_with("/"):
		return typed
	# A missing leading slash before a well-known mount point is treated as an
	# absolute path instead of nesting it under the selected location.
	if typed == "sdcard" or typed.begins_with("sdcard/") or typed.begins_with("storage/emulated/"):
		return "/" + typed
	return _selected_storage_base().path_join(typed)


func _on_add_extra_folder() -> void:
	if not is_instance_valid(_root_path_edit):
		return
	var path: String = _compose_root_path(_root_path_edit.text)
	if path.is_empty():
		return
	if _on_add_root(path):
		_root_path_edit.text = ""


func _on_add_root(raw_path: String) -> bool:
	var path: String = raw_path.strip_edges()
	if path.is_empty():
		return false
	if not path.begins_with("/"):
		path = "/" + path
	path = path.simplify_path()
	if SettingsManager.library_roots.has(path):
		return false
	SettingsManager.library_roots.append(path)
	SettingsManager.save_settings()
	_rebuild_roots_list()
	_update_scan_summary()
	return true


func _on_root_path_submitted(_text: String) -> void:
	_on_add_extra_folder()


func _on_root_path_focus_entered(edit: LineEdit) -> void:
	if edit != _root_path_edit:
		return
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return
	# The baseline is taken before the keyboard appears: the difference with the
	# current viewport tells how much of the keyboard Android already made room
	# for through adjustResize.
	_keyboard_base_viewport_h = get_viewport().get_visible_rect().size.y
	_keyboard_last_height = DisplayServer.virtual_keyboard_get_height()
	_keyboard_last_viewport = get_viewport().get_visible_rect().size
	_keyboard_poll_accum = 0.0
	_keyboard_settle_frames = 8
	_keep_path_edit_above_keyboard.call_deferred()


func _on_root_path_focus_exited(edit: LineEdit) -> void:
	if edit != _root_path_edit:
		return
	_keyboard_settle_frames = 0
	if is_instance_valid(_keyboard_spacer):
		_keyboard_spacer.custom_minimum_size.y = 0.0
	_keyboard_last_height = DisplayServer.virtual_keyboard_get_height()
	_keyboard_last_viewport = get_viewport().get_visible_rect().size


func _on_remove_root(index: int) -> void:
	if index < 0 or index >= SettingsManager.library_roots.size():
		return
	SettingsManager.library_roots.remove_at(index)
	SettingsManager.save_settings()
	_rebuild_roots_list()
	_update_scan_summary()


func _on_preset_downloads_toggled(toggled: bool) -> void:
	SettingsManager.library_preset_downloads = toggled
	SettingsManager.save_settings()
	_update_scan_summary()


func _on_recursive_toggled(toggled: bool) -> void:
	SettingsManager.library_recursive = toggled
	SettingsManager.save_settings()
	_update_scan_summary()


func _on_depth_selected(index: int) -> void:
	SettingsManager.library_max_depth = index
	SettingsManager.save_settings()
	_update_scan_summary()


func _on_rescan_pressed() -> void:
	_scan_summary_and_rescan()


func _on_cancel_scan_pressed() -> void:
	if not SongLoader.is_scanning:
		return
	SongLoader.cancel_scan()
	if is_instance_valid(_scan_status):
		_scan_status.text = "Cancelling..."


func _scan_summary_and_rescan() -> void:
	# The only explicit way to walk the disks. Nothing else starts a scan:
	# library changes and permission grants just update the summary.
	if _scan_pump_active:
		# A rescan requested here (Rescan now, or returning from the system
		# permission screen) used to be dropped silently while another walk was
		# running. Queue it so pump_scan() serves it when the current one ends.
		SongLoader.request_scan(SCAN_OWNER)
		return
	_scan_pump_active = true
	_set_scan_widgets_visible(true)
	if is_instance_valid(_scan_status):
		_scan_status.text = "Scanning..."
	SongLoader.request_scan(SCAN_OWNER)
	if SongLoader.pump_scan(SongLoader.frame_deadline_usec(), SCAN_OWNER):
		_finish_scan()


func _on_scan_progress(root_index: int, root_total: int, current_dir: String, _dirs_visited: int, songs_found: int) -> void:
	if not _scan_pump_active or not is_instance_valid(_scan_status):
		return
	if is_instance_valid(_scan_bar):
		_scan_bar.value = ScanFeedback.progress_value(root_index, root_total) * 100.0
	_scan_status.text = ScanFeedback.status_text(root_index, root_total, songs_found)
	if is_instance_valid(_scan_folder):
		_scan_folder.text = ScanFeedback.folder_text(current_dir)


func _finish_scan() -> void:
	_scan_pump_active = false
	_set_scan_widgets_visible(false)
	_update_scan_summary()


func _abort_scan() -> void:
	if not (_scan_pump_active or SongLoader.is_scanning):
		return
	_scan_pump_active = false
	# Only a walk started from this panel is cancelled: leaving Settings must
	# not cut the scan the menu is showing underneath.
	SongLoader.abort_scan(SCAN_OWNER)
	_set_scan_widgets_visible(false)


func _set_scan_widgets_visible(visible_state: bool) -> void:
	if is_instance_valid(_rescan_button):
		_rescan_button.disabled = visible_state
	if is_instance_valid(_cancel_scan_button):
		_cancel_scan_button.disabled = not visible_state
	for widget in [_scan_bar, _scan_status, _scan_folder]:
		if is_instance_valid(widget):
			widget.visible = visible_state
	if not visible_state:
		if is_instance_valid(_scan_status):
			_scan_status.text = ""
		if is_instance_valid(_scan_folder):
			_scan_folder.text = ""
		if is_instance_valid(_scan_bar):
			_scan_bar.value = 0.0


func _refresh_scan_widgets() -> void:
	# When rebuilding the tab mid-scan the widgets are new: they are re-pointed
	# to the real state instead of waiting for the first event.
	_set_scan_widgets_visible(SongLoader.is_scanning)
	if SongLoader.is_scanning and is_instance_valid(_scan_status) and _scan_status.text.is_empty():
		_scan_status.text = "Scanning..."


func _on_get_songs_pressed() -> void:
	var err: Error = OS.shell_open(SONGS_LINKTREE_URL)
	if not is_instance_valid(_songs_link_status):
		return
	if err == OK:
		_songs_link_status.visible = false
		return
	_songs_link_status.text = "Could not open the browser. Visit " + SONGS_LINKTREE_URL
	_songs_link_status.visible = true


func _on_reset_songs() -> void:
	_abort_scan()
	SettingsManager.reset_library_to_defaults()
	SettingsManager.save_settings()
	_build_tab_content()


func _about_is_open() -> bool:
	return is_instance_valid(_about_overlay)


func _show_about() -> void:
	if _about_is_open():
		return
	_about_overlay = Control.new()
	_about_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_about_overlay)

	var scrim := ColorRect.new()
	scrim.color = Palette.SCRIM_STRONG
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(_on_about_scrim_input)
	_about_overlay.add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_about_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(SettingsUI.px(520), 0)
	var sb := SettingsUI.flat(Palette.SURFACE_1, 22)
	SettingsUI.pad(sb, SettingsUI.px(30), SettingsUI.px(26))
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_theme_constant_override("separation", SettingsUI.px(10))
	panel.add_child(column)

	var icon := TextureRect.new()
	icon.texture = load("res://asset/textures/app_icon.png") as Texture2D
	icon.custom_minimum_size = Vector2(SettingsUI.px(64), SettingsUI.px(64))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	column.add_child(icon)

	var app_name := SettingsUI.label("Drum Hero", 30, Palette.BONE_HI, 600)
	app_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(app_name)

	var app_version: String = str(ProjectSettings.get_setting("application/config/version", "1.0.0"))
	var version := SettingsUI.label("VERSION " + app_version, 11, Palette.ACCENT, 600)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(version)

	var tagline := SettingsUI.description("A drum-only rhythm game for Android and desktop. Developed by jdpc.dev.", Palette.ASH)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tagline)
	column.add_child(SettingsUI.divider())

	var made_by := SettingsUI.kicker("MADE POSSIBLE BY")
	made_by.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(made_by)
	var credits: Array[Dictionary] = [
		{"name": "Godot Engine", "desc": "The engine that powers this project"},
		{"name": "Freesound.org", "desc": "Drum samples and sound effects"},
		{"name": "Google Fonts", "desc": "Typography and font assets"},
	]
	for entry in credits:
		var credit_row := HBoxContainer.new()
		credit_row.add_theme_constant_override("separation", SettingsUI.px(14))
		var credit_name := SettingsUI.label(str(entry["name"]), 15, Palette.BONE, 500)
		credit_name.custom_minimum_size.x = SettingsUI.px(150)
		credit_row.add_child(credit_name)
		var credit_desc := SettingsUI.description(str(entry["desc"]))
		credit_row.add_child(credit_desc)
		column.add_child(credit_row)

	column.add_child(SettingsUI.divider())
	var done := SettingsUI.button("Done", "primary")
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done.pressed.connect(_close_about)
	column.add_child(done)
	done.call_deferred("grab_focus")

	_about_overlay.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(_about_overlay, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_about_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_about()
	elif event is InputEventScreenTouch and event.pressed:
		_close_about()


func _close_about() -> void:
	if not is_instance_valid(_about_overlay):
		return
	var overlay := _about_overlay
	_about_overlay = null
	var fade := create_tween()
	fade.tween_property(overlay, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fade.tween_callback(overlay.queue_free)


func _apply_padding_sliders_editable(enabled: bool) -> void:
	for s in [_padding_left_slider, _padding_right_slider, _padding_top_slider, _padding_bottom_slider]:
		if is_instance_valid(s):
			s.editable = enabled
			s.modulate = Color(1, 1, 1, 1) if enabled else Color(1, 1, 1, 0.42)
			var knob: Node = s.get_node_or_null("SliderKnob")
			if knob is Control:
				knob.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func _add_reset_section_button(parent: VBoxContainer, section_name: String, callback: Callable) -> void:
	var card := SettingsUI.section("")
	card.body.add_child(SettingsUI.description("Restore every option on this page to its default value."))
	var btn := SettingsUI.button("Reset " + section_name + " to Defaults", "danger")
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	btn.pressed.connect(callback)
	card.body.add_child(btn)
	parent.add_child(card)


func _load_current_settings() -> void:
	var current_mode: int = SettingsManager.game_mode
	for i in _mode_buttons.size():
		_mode_buttons[i].set_pressed_no_signal(i == current_mode)
	if is_instance_valid(_custom_lane_card):
		_custom_lane_card.visible = (current_mode == 2)


func _on_mode_toggled(toggled: bool, mode: int) -> void:
	if not toggled:
		# A segmented control is a radio group: tapping the active option
		# must not leave the highway with no mode selected.
		for i in _mode_buttons.size():
			_mode_buttons[i].set_pressed_no_signal(i == SettingsManager.game_mode)
		return
	for i in _mode_buttons.size():
		_mode_buttons[i].set_pressed_no_signal(i == mode)
	SettingsManager.game_mode = mode
	GameManager.mode = mode as GameManager.GameMode
	SettingsManager.save_settings()
	if is_instance_valid(_custom_lane_card):
		_custom_lane_card.visible = (mode == 2)
	if is_instance_valid(_mode_desc_label):
		_mode_desc_label.text = MODE_DESCRIPTIONS[clampi(mode, 0, 2)]
	if is_instance_valid(_haptic_enabled_check):
		if mode == 1:
			_haptic_enabled_check.set_pressed_no_signal(true)
			_haptic_enabled_check.disabled = true
		else:
			_haptic_enabled_check.set_pressed_no_signal(SettingsManager.haptic_enabled)
			_haptic_enabled_check.disabled = false


func _rebuild_custom_lane_ui(lanes: Array) -> void:
	if not is_instance_valid(_custom_lane_container):
		return
	for child in _custom_lane_container.get_children():
		_custom_lane_container.remove_child(child)
		child.queue_free()

	var count: int = lanes.size()
	if count == 0:
		_custom_lane_container.add_child(SettingsUI.description("(no custom order set - using default)", Palette.MUTED))
		return

	for i in count:
		var lane_idx: int = lanes[i]
		var item := PanelContainer.new()
		item.mouse_filter = Control.MOUSE_FILTER_PASS
		var sb := SettingsUI.flat(Palette.SURFACE_2, 12)
		SettingsUI.pad(sb, SettingsUI.px(10), SettingsUI.px(6))
		item.add_theme_stylebox_override("panel", sb)
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var hbox := HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.mouse_filter = Control.MOUSE_FILTER_PASS
		hbox.add_theme_constant_override("separation", SettingsUI.px(10))
		item.add_child(hbox)

		var color_chip := PanelContainer.new()
		color_chip.mouse_filter = Control.MOUSE_FILTER_PASS
		color_chip.custom_minimum_size = Vector2(SettingsUI.px(6), SettingsUI.px(28))
		var chip_style := SettingsUI.flat(LANE_COLORS[lane_idx] if lane_idx < LANE_COLORS.size() else Color.WHITE, 3)
		color_chip.add_theme_stylebox_override("panel", chip_style)
		hbox.add_child(color_chip)

		var lbl := SettingsUI.label(LANE_LABELS[lane_idx] if lane_idx < LANE_LABELS.size() else "Lane " + str(lane_idx), 17, Palette.BONE, 500)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl)

		var move_up := SettingsUI.icon_button("▲")
		move_up.disabled = (i == 0)
		move_up.pressed.connect(_on_move_lane.bind(i, -1))
		hbox.add_child(move_up)

		var move_down := SettingsUI.icon_button("▼")
		move_down.disabled = (i == count - 1)
		move_down.pressed.connect(_on_move_lane.bind(i, 1))
		hbox.add_child(move_down)

		_custom_lane_container.add_child(item)

	var reset_btn := SettingsUI.button("Reset to Default", "ghost")
	reset_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset_btn.pressed.connect(_on_reset_lanes)
	_custom_lane_container.add_child(reset_btn)


func _on_move_lane(index: int, direction: int) -> void:
	var lanes: Array = SettingsManager.custom_lanes.duplicate()
	if lanes.is_empty():
		return
	var target: int = index + direction
	if target < 0 or target >= lanes.size():
		return
	var tmp = lanes[index]
	lanes[index] = lanes[target]
	lanes[target] = tmp
	SettingsManager.custom_lanes = lanes
	SettingsManager.save_settings()
	_rebuild_custom_lane_ui(lanes)


func _on_reset_lanes() -> void:
	SettingsManager.custom_lanes = [0, 1, 2, 3, 4, 5, 6, 7]
	SettingsManager.save_settings()
	_rebuild_custom_lane_ui(SettingsManager.custom_lanes)


func _on_reset_controls() -> void:
	SettingsManager.reset_controls_to_defaults()
	_build_tab_content()


func _on_reset_hud() -> void:
	SettingsManager.reset_hud_to_defaults()
	Engine.max_fps = SettingsManager.max_fps
	_build_tab_content()


func _on_reset_audio() -> void:
	SettingsManager.reset_audio_to_defaults()
	AudioManager.apply_volume_settings()
	DrumSfxManager.apply_volume_settings()
	_build_tab_content()


func _on_reset_experimental() -> void:
	SettingsManager.reset_experimental_to_defaults()
	_build_tab_content()


func _on_free_mode_pressed() -> void:
	free_mode_requested.emit()


func _on_sample_velocity_changed(value: float) -> void:
	SettingsManager.default_sample_velocity = int(value)


func _on_sample_velocity_drag_ended(value_changed: bool) -> void:
	if value_changed:
		SettingsManager.save_settings()


func _on_fps_toggled(toggled: bool) -> void:
	SettingsManager.show_fps = toggled
	SettingsManager.save_settings()


func _on_fps_cap_changed(value: float) -> void:
	SettingsManager.max_fps = int(value)
	Engine.max_fps = SettingsManager.max_fps


func _on_fps_cap_drag_ended(value_changed: bool) -> void:
	if value_changed:
		SettingsManager.save_settings()


func _on_screen_shake_toggled(toggled: bool) -> void:
	SettingsManager.screen_shake = toggled
	SettingsManager.save_settings()


func _on_hit_feedback_toggled(toggled: bool) -> void:
	SettingsManager.show_hit_feedback = toggled
	SettingsManager.save_settings()


func _on_fallback_toggled(toggled: bool) -> void:
	SettingsManager.use_guitar_fallback = toggled
	SettingsManager.save_settings()


func _on_judgment_areas_toggled(toggled: bool) -> void:
	SettingsManager.show_judgment_areas = toggled
	SettingsManager.save_settings()


func _on_menu_status_toggled(toggled: bool) -> void:
	SettingsManager.show_menu_status = toggled
	SettingsManager.save_settings()


func _on_haptic_enabled_toggled(toggled: bool) -> void:
	SettingsManager.haptic_enabled = toggled
	SettingsManager.save_settings()


func _on_haptic_sensitivity_changed(value: float) -> void:
	SettingsManager.haptic_sensitivity = value


func _on_haptic_sensitivity_drag_ended(value_changed: bool) -> void:
	if value_changed:
		SettingsManager.save_settings()


func _on_haptic_activation_changed(value: float) -> void:
	SettingsManager.haptic_activation_threshold = value


func _on_haptic_release_changed(value: float) -> void:
	SettingsManager.haptic_release_threshold = value


func _on_haptic_cooldown_changed(value: float) -> void:
	SettingsManager.haptic_cooldown_duration = value


func _on_haptic_min_interval_changed(value: float) -> void:
	SettingsManager.haptic_min_interval = value


func _on_haptic_smoothing_changed(value: float) -> void:
	SettingsManager.haptic_smoothing_strength = value


func _on_haptic_any_drag_ended(value_changed: bool) -> void:
	if value_changed:
		SettingsManager.save_settings()


func _on_haptic_debug_toggled(toggled: bool) -> void:
	SettingsManager.haptic_show_debug = toggled
	SettingsManager.save_settings()


func _on_note_speed_changed(value: float) -> void:
	SettingsManager.note_speed = value


func _on_note_speed_drag_ended(value_changed: bool) -> void:
	if value_changed:
		SettingsManager.save_settings()


func _on_countdown_changed(value: float) -> void:
	SettingsManager.countdown_threshold = value


func _on_countdown_drag_ended(value_changed: bool) -> void:
	if value_changed:
		SettingsManager.save_settings()


func _on_mirrored_toggled(toggled: bool) -> void:
	SettingsManager.mirrored = toggled
	SettingsManager.save_settings()


func _on_left_handed_toggled(toggled: bool) -> void:
	SettingsManager.left_handed = toggled
	SettingsManager.save_settings()


func _on_master_volume_changed(value: float) -> void:
	SettingsManager.master_volume = value
	AudioManager.apply_volume_settings()


func _on_music_volume_changed(value: float) -> void:
	SettingsManager.music_volume = value
	AudioManager.apply_volume_settings()


func _on_sfx_volume_changed(value: float) -> void:
	SettingsManager.sfx_volume = value
	DrumSfxManager.apply_volume_settings()


func _on_preview_volume_changed(value: float) -> void:
	SettingsManager.update_preview_volume(value)


func _on_audio_offset_changed(value: float) -> void:
	SettingsManager.audio_offset_ms = value


func _on_audio_setting_drag_ended(value_changed: bool) -> void:
	if value_changed:
		SettingsManager.save_settings()


func _on_padding_enabled_toggled(toggled: bool) -> void:
	SettingsManager.gameplay_padding_enabled = toggled
	SettingsManager.save_settings()
	_apply_padding_sliders_editable(toggled)


func _on_padding_left_changed(value: float) -> void:
	SettingsManager.gameplay_padding_left = value


func _on_padding_right_changed(value: float) -> void:
	SettingsManager.gameplay_padding_right = value


func _on_padding_top_changed(value: float) -> void:
	SettingsManager.gameplay_padding_top = value


func _on_padding_bottom_changed(value: float) -> void:
	SettingsManager.gameplay_padding_bottom = value


func _on_padding_any_drag_ended(value_changed: bool) -> void:
	if value_changed:
		SettingsManager.save_settings()


func _on_back() -> void:
	queue_free()
