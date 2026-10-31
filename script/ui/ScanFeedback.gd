class_name ScanFeedback
extends RefCounted

# Single source for the scan indicator's text and appearance. It is used by the
# menu loading screen and the SONGS tab in Settings, so the player reads the
# same thing wherever they are looking.
#
# The bar has no percentage: it is not known how many directories a library has
# before walking it, so it counts finished locations and the live detail goes
# in the labels. A percentage here would be a lie.

const FOLDER_MAX_CHARS: int = 46


static func make_status_label() -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Palette.CHROME)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


static func make_folder_label() -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Palette.ASH_DIM)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


static func make_progress_bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.value = 0.0
	return bar


static func progress_value(root_index: int, root_total: int) -> float:
	# FINISHED locations, not the current one: otherwise, the bar would jump to
	# the end when starting the last one and promise an ending that has not
	# happened yet.
	if root_total <= 0:
		return 0.0
	return clampf(float(root_index - 1) / float(root_total), 0.0, 1.0)


static func status_text(root_index: int, root_total: int, songs_found: int) -> String:
	return "Scanning " + str(root_index) + "/" + str(root_total) + " locations - " + str(songs_found) + " songs found"


static func folder_text(dir_path: String) -> String:
	# Long paths are trimmed from the center: the useful part is the end, which
	# is exactly the folder the scan was entering.
	if dir_path.length() <= FOLDER_MAX_CHARS:
		return dir_path
	var tail: int = (FOLDER_MAX_CHARS - 3) / 2
	return dir_path.substr(0, FOLDER_MAX_CHARS - 3 - tail) + "..." + dir_path.substr(dir_path.length() - tail)


static func finished_text(songs_found: int) -> String:
	return str(songs_found) + " songs found"


static func cancelled_text(songs_found: int) -> String:
	return "Scan cancelled - " + str(songs_found) + " songs kept"
