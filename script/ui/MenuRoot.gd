class_name MenuRoot
extends CanvasLayer

@onready var select_folder_button: Button = $SelectFolderButton
@onready var add_files_button: Button = $AddFilesButton
@onready var clear_folder_button: Button = $ClearFolderButton
@onready var song_list: ItemList = $SongList
@onready var status_label: Label = $StatusLabel
@onready var difficulty_container: HBoxContainer = $DifficultyContainer

var _file_dialog: FileDialog
var _selected_song_path: String = ""
var _selected_song_difficulties: Array = []
var _back_press_time: float = 0.0
var _back_cooldown: float = 2.0
var _back_handled_time: float = 0.0

# Loading overlay
var _loading_overlay: CanvasLayer
var _loading_bar: ProgressBar
var _loading_status: Label


func _ready() -> void:
	select_folder_button.pressed.connect(_on_select_folder_pressed)
	add_files_button.pressed.connect(_on_add_files_pressed)
	clear_folder_button.pressed.connect(_on_clear_folder_pressed)
	song_list.item_selected.connect(_on_song_selected)
	GameManager.set_state(GameManager.GameState.MENU)
	_update_clear_visibility()
	if SongLoader.song_list.is_empty():
		_refresh_song_list()
	else:
		_update_song_list_ui()
	get_tree().auto_accept_quit = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back_handled_time = Time.get_ticks_msec() / 1000.0
		_handle_back()
		get_viewport().set_input_as_handled()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _file_dialog and is_instance_valid(_file_dialog):
			return
		var now: float = Time.get_ticks_msec() / 1000.0
		if now - _back_handled_time < 0.5:
			return
		_handle_back()


func _handle_back() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _back_press_time < _back_cooldown:
		status_label.text = "Cerrando..."
		get_tree().quit()
	else:
		_back_press_time = now
		status_label.text = "Pulsa una vez mas para cerrar el juego"


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


func _refresh_song_list() -> void:
	_show_loading_screen()
	_update_loading(0.0, "Scanning songs...")
	SongLoader.scan_songs()
	_update_loading(1.0, "Updating list...")
	_update_song_list_ui()
	_hide_loading_screen()


func _update_song_list_ui() -> void:
	_update_clear_visibility()
	song_list.clear()
	for song in SongLoader.song_list:
		var label: String = song.artist + " - " + song.name
		song_list.add_item(label)
	var count: int = SongLoader.song_list.size()
	if count > 0:
		status_label.text = str(count) + " songs found"
		song_list.select(0)
		_on_song_selected(0)
	else:
		var lines = ["Put songs in: " + SongLoader.get_user_song_dir()]
		if not SongLoader.custom_song_path.is_empty():
			lines.append("Custom folder: " + SongLoader.custom_song_path)
		if not SongLoader.custom_song_dirs.is_empty():
			lines.append("+ " + str(SongLoader.custom_song_dirs.size()) + " individual dirs")
		if SongLoader.custom_song_path.is_empty() and SongLoader.custom_song_dirs.is_empty():
			lines.append("Tap 'Select Folder' or 'Pick song.ini files'")
		status_label.text = "\n".join(lines)
	difficulty_container.hide()
	_clear_difficulty_buttons()


func _clear_difficulty_buttons() -> void:
	for child in difficulty_container.get_children():
		child.queue_free()


func _update_clear_visibility() -> void:
	clear_folder_button.visible = not SongLoader.custom_song_path.is_empty() or not SongLoader.custom_song_dirs.is_empty()


func _on_song_selected(index: int) -> void:
	if index >= 0 and index < SongLoader.song_list.size():
		var song: Dictionary = SongLoader.song_list[index]
		_selected_song_path = song.path
		_selected_song_difficulties = song.get("difficulties", [])
		var parts: Array[String] = []
		if not song.notes_path.is_empty():
			parts.append("chart OK")
		else:
			parts.append("missing notes.mid")
		if SongLoader.get_stem_path(song.path, "song").is_empty():
			parts.append("missing audio")
		else:
			parts.append("audio OK")
		status_label.text = " - ".join(parts)

		_rebuild_difficulty_buttons()


func _rebuild_difficulty_buttons() -> void:
	_clear_difficulty_buttons()
	if _selected_song_difficulties.is_empty():
		difficulty_container.hide()
		return
	for diff in _selected_song_difficulties:
		var btn: Button = Button.new()
		btn.text = diff.name
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.custom_minimum_size = Vector2(100, 50)
		btn.pressed.connect(_on_difficulty_pressed.bind(diff.offset, diff.name))
		difficulty_container.add_child(btn)
	difficulty_container.show()


func _on_difficulty_pressed(offset: int, name: String) -> void:
	if _selected_song_path.is_empty():
		status_label.text = "Select a song first"
		return
	_show_loading_screen()
	_update_loading(0.0, "Loading " + name + "...")
	GameManager.current_song_path = _selected_song_path
	GameManager.current_difficulty_offset = offset
	GameManager.current_difficulty_name = name
	get_tree().change_scene_to_file("res://scene/Gameplay.tscn")


func _on_select_folder_pressed() -> void:
	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_file_dialog.title = "Select a folder with songs"
	_file_dialog.dir_selected.connect(_on_folder_selected)
	_file_dialog.canceled.connect(_on_folder_canceled)
	add_child(_file_dialog)
	_file_dialog.popup_centered()


func _on_add_files_pressed() -> void:
	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	_file_dialog.title = "Select song.ini or notes.mid files"
	_file_dialog.filters = PackedStringArray(["Song Config ; song.ini", "MIDI Chart ; notes.mid,*.mid"])
	_file_dialog.files_selected.connect(_on_files_selected)
	_file_dialog.canceled.connect(_on_folder_canceled)
	add_child(_file_dialog)
	_file_dialog.popup_centered()


func _on_folder_selected(dir: String) -> void:
	SongLoader.custom_song_path = dir
	SongLoader._save_custom_path()
	if _file_dialog:
		_file_dialog.queue_free()
	status_label.text = "Scanning: " + dir
	_refresh_song_list()
	if SongLoader.song_list.size() == 0:
		status_label.text = "No subfolders with song.ini in:\n" + dir


func _on_files_selected(paths: PackedStringArray) -> void:
	if _file_dialog:
		_file_dialog.queue_free()
	status_label.text = "Adding " + str(paths.size()) + " songs..."
	var added: int = 0
	for p in paths:
		var parent: String = p.get_base_dir()
		SongLoader.add_song_dir(parent)
		added += 1
	SongLoader._save_custom_paths()
	_refresh_song_list()


func _on_folder_canceled() -> void:
	if _file_dialog:
		_file_dialog.queue_free()


func _on_clear_folder_pressed() -> void:
	SongLoader.clear_all_custom()
	_refresh_song_list()
