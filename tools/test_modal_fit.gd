extends Node

# Mobile modal layout regression test.
# The DPI-aware UI scale can make the pause and results cards taller than the
# viewport. Their ModalBody must keep the scroll area on screen instead of
# drawing the cards past the top and bottom edges.
# Usage: godot --headless --path . res://tools/test_modal_fit.tscn

const MOBILE_SCALE: float = 1.9

var _failures: int = 0


func _check(label: String, ok: bool) -> void:
	if ok:
		print("  OK   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)


func _check_modal(label: String, modal: SettingsUI.ModalBody, vp: Rect2) -> void:
	_check(label + " builds its modal body", modal != null)
	if modal == null:
		return
	var outer: Rect2 = modal.get_global_rect()
	_check(label + " modal fills the screen", outer.position.x <= 1.0 and outer.position.y <= 1.0 and outer.size.x >= vp.size.x - 1.0 and outer.size.y >= vp.size.y - 1.0)
	var scroll: Rect2 = modal.scroll.get_global_rect()
	_check(label + " scroll area stays inside the screen", scroll.position.x >= -1.0 and scroll.position.y >= -1.0 and scroll.end.x <= vp.end.x + 1.0 and scroll.end.y <= vp.end.y + 1.0)


func _ready() -> void:
	get_viewport().size = Vector2i(1280, 720)
	var vp: Rect2 = get_viewport().get_visible_rect()

	var result := ResultOverlay.new()
	add_child(result)
	await get_tree().process_frame
	# _ready() resets the desktop scale, so rebuild with the mobile one.
	for child in result.get_children():
		child.queue_free()
	await get_tree().process_frame
	SettingsUI.ui_scale = MOBILE_SCALE
	result._build()
	await get_tree().process_frame
	var result_modal: SettingsUI.ModalBody = result.find_child("ResultModal", true, false)
	var result_card: Control = result.find_child("ResultCard", true, false)
	_check_modal("results", result_modal, vp)
	_check("results card is taller than the screen at mobile scale", result_card != null and result_card.get_combined_minimum_size().y > result_modal.scroll.size.y)
	_check("results can be scrolled", result_modal.scroll.get_v_scroll_bar().max_value > result_modal.scroll.size.y)
	result.queue_free()
	await get_tree().process_frame

	GameManager.current_song_title = "A Very Long Song Title That Might Wrap A Lot"
	GameManager.current_song_artist = "Some Artist"
	GameManager.current_difficulty_name = "Expert+"
	SettingsUI.ui_scale = MOBILE_SCALE
	var game: Node = load("res://script/gameplay/GameplayRoot.gd").new()
	game._show_pause_overlay()
	var overlay: CanvasLayer = game._pause_overlay
	game.remove_child(overlay)
	add_child(overlay)
	await get_tree().process_frame
	var pause_modal: SettingsUI.ModalBody = overlay.find_child("PauseModal", true, false)
	var pause_main: Control = overlay.find_child("PauseMenu", true, false)
	_check_modal("pause", pause_modal, vp)
	_check("pause card fits at mobile scale", pause_main != null and pause_main.get_combined_minimum_size().y <= pause_modal.scroll.size.y)
	_check("pause does not need scrolling", pause_modal.scroll.get_v_scroll_bar().max_value <= pause_modal.scroll.size.y + 1.0)
	overlay.queue_free()
	game.free()
	SettingsUI.ui_scale = 1.0
	await get_tree().process_frame

	if _failures == 0:
		print("\nOK: pause and results modals stay on screen on mobile")
	else:
		print("\n", _failures, " modal layout checks failed")
	get_tree().quit(1 if _failures > 0 else 0)
