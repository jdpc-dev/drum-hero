class_name ScanFeedback
extends RefCounted

# Una sola fuente para el texto y el aspecto del indicador de escaneo. Lo usan
# la pantalla de carga del menu y la pestaña SONGS de Ajustes, para que el
# jugador lea lo mismo este donde este mirando.
#
# La barra no lleva porcentaje: no se sabe cuantos directorios tiene una
# biblioteca antes de recorrerla, asi que cuenta ubicaciones terminadas y el
# detalle vivo va en las etiquetas. Un porcentaje aqui seria mentira.

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
	# Ubicaciones TERMINADAS, no la actual: si no, la barra saltaria al final
	# al empezar la ultima y prometeria un final que todavia no ha ocurrido.
	if root_total <= 0:
		return 0.0
	return clampf(float(root_index - 1) / float(root_total), 0.0, 1.0)


static func status_text(root_index: int, root_total: int, songs_found: int) -> String:
	return "Scanning " + str(root_index) + "/" + str(root_total) + " locations - " + str(songs_found) + " songs found"


static func folder_text(dir_path: String) -> String:
	# Las rutas largas se recortan por el centro: lo util es el final, que es
	# justo la carpeta en la que se estaba metiendo el escaneo.
	if dir_path.length() <= FOLDER_MAX_CHARS:
		return dir_path
	var tail: int = (FOLDER_MAX_CHARS - 3) / 2
	return dir_path.substr(0, FOLDER_MAX_CHARS - 3 - tail) + "..." + dir_path.substr(dir_path.length() - tail)


static func finished_text(songs_found: int) -> String:
	return str(songs_found) + " songs found"


static func cancelled_text(songs_found: int) -> String:
	return "Scan cancelled - " + str(songs_found) + " songs kept"
