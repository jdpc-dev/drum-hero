extends Node

var _settings_backup: PackedByteArray = PackedByteArray()
var _settings_existed: bool = false


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


func _show(root_rel: String) -> void:
	SettingsManager.library_preset_downloads = false
	SettingsManager.library_preset_documents = false
	SettingsManager.library_roots = PackedStringArray(["/tmp/opencode/libtest/" + root_rel])
	SettingsManager.library_recursive = true
	SettingsManager.library_max_depth = 4
	SongLoader.scan_songs()
	for s in SongLoader.song_list:
		var p: String = s.get("path", "")
		if not p.begins_with("/tmp/"):
			continue
		print("  name=%-22s artist=%-16s charter=%-14s album=%-14s genre=%-11s year=%-6s len=%-7s delay=%s" % [
			str(s.get("name", "?")), str(s.get("artist", "?")),
			str(s.get("charter", "-")), str(s.get("album", "-")),
			str(s.get("genre", "-")), str(s.get("year", "-")),
			str(s.get("song_length", "-")), str(s.get("delay", "-")),
		])
		print("      difficulties=%s has_drum_chart=%s" % [str(s.get("difficulties", [])), str(s.get("has_drum_chart", false))])


func _ready() -> void:
	_backup_settings()

	print("=== 1. sin song.ini: metadatos del nombre de carpeta ===")
	_show("meta")
	print("  esperado: 'Artist Three - Zeta (charterY)' -> artist=Artist Three name=Zeta charter=charterY")
	print("  esperado: 'NoIni NoDash Folder' -> name=carpeta, artist=Unknown Artist")
	print("  esperado: 'Artist Four - Song Delta Test' -> artist=Artist Four name=Song Delta Test")

	print("=== 2. song.ini tiene PRECEDENCIA sobre el chart y el nombre ===")
	print("  esperado: IniName / IniArtist / iniCharter, delay=-50 (del ini, no -120 del chart)")

	print("=== 3. chart [Song] sin song.ini ===")
	print("  esperado: ChartName / ChartArtist / chartCharter, year=1998 (de ', 1998'), delay=-120")

	print("=== 4. chart con chart mal formado (sin [Song]) ===")
	SettingsManager.library_roots = PackedStringArray(["/tmp/opencode/libtest/rootA/Artist One/Song Beta/charts"])
	SongLoader.scan_songs()
	print("  canciones=", SongLoader.song_list.size() - 2, " (Song Beta/charts: notes.chart sin cabecera [Song])")

	print("=== 5. song.ini con comillas: se desenvuelven ===")
	SettingsManager.library_roots = PackedStringArray(["/tmp/opencode/libtest/rootA/Artist One/Song Gamma (c)"])
	SongLoader.scan_songs()
	for s in SongLoader.song_list:
		if str(s.get("path", "")).contains("/tmp/"):
			print("  name='", s.get("name", "?"), "' artist='", s.get("artist", "?"), "' (sin comillas: esperado)")

	print("=== 6. Notes.mid con mayuscula ahora se detecta ===")
	SettingsManager.library_roots = PackedStringArray(["/tmp/opencode/libtest/rootA/Artist One/Song Delta Upper"])
	SongLoader.scan_songs()
	for s in SongLoader.song_list:
		if str(s.get("path", "")).contains("/tmp/"):
			print("  ", s.get("name", "?"), " @ ", s.get("path", "?"))
			print("  notes_path=", s.get("notes_path", "?"))

	print("=== 7. cancion sin song.ini conserva duracion 0 -> MenuRoot omite el prefijo ===")
	print("  (song_length=0 cuando no hay song.ini; sin audio cargado no se puede saber)")

	print("=== DONE ===")
	_restore_settings()
	get_tree().quit()
