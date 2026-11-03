extends Node

# Verifies that text survives every stage of the pipeline: legacy files are
# decoded without U+FFFD, metadata keeps accented/Unicode characters through
# parsing and the library cache, and writes are always valid UTF-8.

const FIXTURE: String = "/tmp/opencode/encodingtest"
const SAMPLE: String = "áéíóúñü ÁÉÍÓÚÑÜ €£¥ ±×÷ ¿¡«» «Señor» ♫♪"
const CP1252_SPECIAL: Dictionary = {
	0x20AC: 0x80,  # €
	0x201A: 0x82,  # ‚
	0x0192: 0x83,  # ƒ
	0x201E: 0x84,  # „
	0x2026: 0x85,  # …
	0x2020: 0x86,  # †
	0x2021: 0x87,  # ‡
	0x02C6: 0x88,  # ˆ
	0x2030: 0x89,  # ‰
	0x0160: 0x8A,  # Š
	0x2039: 0x8B,  # ‹
	0x0152: 0x8C,  # Œ
	0x017D: 0x8E,  # Ž
	0x2018: 0x91,  # ‘
	0x2019: 0x92,  # ’
	0x201C: 0x93,  # “
	0x201D: 0x94,  # ”
	0x2022: 0x95,  # •
	0x2013: 0x96,  # –
	0x2014: 0x97,  # —
	0x02DC: 0x98,  # ˜
	0x2122: 0x99,  # ™
	0x0161: 0x9A,  # š
	0x203A: 0x9B,  # ›
	0x0153: 0x9C,  # œ
	0x017E: 0x9E,  # ž
	0x0178: 0x9F,  # Ÿ
}

var _failures: int = 0
var _settings_backup: PackedByteArray = PackedByteArray()
var _settings_existed: bool = false
var _cache_backup: String = ""
var _cache_existed: bool = false


func _check(label: String, ok: bool) -> void:
	if ok:
		print("  OK   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)


func _cp1252(text: String) -> PackedByteArray:
	var out := PackedByteArray()
	for i in text.length():
		var code: int = text.unicode_at(i)
		if code <= 0x7F or (code >= 0xA0 and code <= 0xFF):
			out.append(code)
		else:
			out.append(int(CP1252_SPECIAL.get(code, 0x3F)))
	return out


func _utf16(text: String, little_endian: bool = true) -> PackedByteArray:
	var out := PackedByteArray()
	if little_endian:
		out.append_array(PackedByteArray([0xFF, 0xFE]))
	else:
		out.append_array(PackedByteArray([0xFE, 0xFF]))
	for i in text.length():
		var code: int = text.unicode_at(i)
		var units: Array[int] = []
		if code < 0x10000:
			units.append(code)
		else:
			code -= 0x10000
			units.append(0xD800 + (code >> 10))
			units.append(0xDC00 + (code & 0x3FF))
		for unit in units:
			if little_endian:
				out.append(unit & 0xFF)
				out.append((unit >> 8) & 0xFF)
			else:
				out.append((unit >> 8) & 0xFF)
				out.append(unit & 0xFF)
	return out


func _utf32(text: String, little_endian: bool = true) -> PackedByteArray:
	var out := PackedByteArray()
	if little_endian:
		out.append_array(PackedByteArray([0xFF, 0xFE, 0x00, 0x00]))
	else:
		out.append_array(PackedByteArray([0x00, 0x00, 0xFE, 0xFF]))
	for i in text.length():
		var code: int = text.unicode_at(i)
		for shift in ([0, 8, 16, 24] if little_endian else [24, 16, 8, 0]):
			out.append((code >> shift) & 0xFF)
	return out


func _write_bytes(path: String, data: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_buffer(data)
		file.close()


func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		var child: String = path.path_join(name)
		if dir.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(child)
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


func _make_song(dir_name: String, ini_text: String = "", ini_encoding: String = "utf-8", chart_text: String = "") -> void:
	var song_dir: String = FIXTURE.path_join(dir_name)
	DirAccess.make_dir_recursive_absolute(song_dir)
	if not chart_text.is_empty():
		_write_bytes(song_dir.path_join("notes.chart"), _cp1252(chart_text))
	else:
		var midi := PackedByteArray()
		midi.append_array("MThd".to_ascii_buffer())
		midi.append_array(PackedByteArray([0, 0, 0, 6, 0, 1, 0, 1, 0, 96]))
		_write_bytes(song_dir.path_join("notes.mid"), midi)
	_write_bytes(song_dir.path_join("song.ogg"), PackedByteArray())
	if ini_text.is_empty():
		return
	var data: PackedByteArray
	match ini_encoding:
		"cp1252":
			data = _cp1252(ini_text)
		"utf-8-bom":
			data = PackedByteArray([0xEF, 0xBB, 0xBF]) + ini_text.to_utf8_buffer()
		"utf-16le":
			data = _utf16(ini_text, true)
		"utf-16be":
			data = _utf16(ini_text, false)
		_:
			data = ini_text.to_utf8_buffer()
	_write_bytes(song_dir.path_join("song.ini"), data)


func _ensure_fixture() -> void:
	_remove_tree(FIXTURE)
	_make_song(
		"CP1252 Artist - Corazón Partío",
		"[Song]\r\nname = Corazón Partío\r\nartist = Alejandro Sanz\r\nalbum = Más — €5 ± × ÷\r\ncharter = Señor «Ñ»\r\nsong_length = 123000\r\n",
		"cp1252")
	_make_song(
		"UTF8 BOM Artist - Añoranza",
		"[Song]\nname = Añoranza ¿¡«»?\nartist = Niño Ñandú\nalbum = Corazón\ncharter = Autora\n",
		"utf-8-bom")
	_make_song(
		"UTF16 Artist - Lugar",
		"[song]\nname = En Algún Lugar\nartist = Duncan Dhu\nalbum = El Grito del Tiempo\n",
		"utf-16le")
	_make_song(
		"UTF16BE Artist - Canción",
		"[Song]\nname = Canción del Mariachi\nartist = Antonio Banderas & Los Lobos\nalbum = Desperado\n",
		"utf-16be")
	_make_song(
		"Chart Artist - Volcán",
		"",
		"utf-8",
		"[Song]\n{\n  Name = El Nervio del Volcán\n  Artist = Caifanes\n  Charter = Señor\n  Year = 1994\n}\n[SyncTrack]\n{\n  0 = TS 4\n}\n[ExpertDrums]\n{\n  0 = N 0 0\n}\n")
	_make_song(
		"UTF8 Artist - 夜に駆ける",
		"[Song]\nname = 夜に駆ける\nartist = YOASOBI\nalbum = € £ ¥ ± × ÷ ¿ ¡ « »\n",
		"utf-8")


func _backup_settings() -> void:
	if FileAccess.file_exists(SettingsManager.SETTINGS_PATH):
		_settings_existed = true
		var file := FileAccess.open(SettingsManager.SETTINGS_PATH, FileAccess.READ)
		_settings_backup = file.get_buffer(file.get_length())
		file.close()


func _restore_settings() -> void:
	if not _settings_existed:
		DirAccess.remove_absolute(SettingsManager.SETTINGS_PATH)
		return
	var file := FileAccess.open(SettingsManager.SETTINGS_PATH, FileAccess.WRITE)
	file.store_buffer(_settings_backup)
	file.close()


func _backup_cache() -> void:
	if not FileAccess.file_exists(SongLoader.CACHE_PATH):
		return
	_cache_existed = true
	var file := FileAccess.open(SongLoader.CACHE_PATH, FileAccess.READ)
	_cache_backup = file.get_as_text()
	file.close()


func _restore_cache() -> void:
	if not _cache_existed:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SongLoader.CACHE_PATH))
		return
	var file := FileAccess.open(SongLoader.CACHE_PATH, FileAccess.WRITE)
	file.store_string(_cache_backup)
	file.close()


func _by_folder() -> Dictionary:
	var result: Dictionary = {}
	for song in SongLoader.song_list:
		var path: String = str(song.get("path", ""))
		if path.begins_with(FIXTURE):
			result[path.get_file()] = song
	return result


func _missing_glyphs(font: Font) -> String:
	var missing: String = ""
	var seen: Dictionary = {}
	for i in SAMPLE.length():
		var character: String = SAMPLE[i]
		if character == " " or seen.has(character):
			continue
		seen[character] = true
		if not font.has_char(ord(character)):
			missing += character
	return missing


func _ready() -> void:
	_backup_settings()
	_backup_cache()
	_ensure_fixture()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SongLoader.CACHE_PATH))
	SongLoader.song_list.clear()
	SongLoader.cache_loaded = false

	print("=== 1. decodificacion directa (input) ===")
	_check("UTF-8 se conserva intacto", FileHelper.decode_text(SAMPLE.to_utf8_buffer()) == SAMPLE)
	_check("UTF-8 con BOM pierde solo el BOM", FileHelper.decode_text(
		PackedByteArray([0xEF, 0xBB, 0xBF]) + SAMPLE.to_utf8_buffer()) == SAMPLE)
	var legacy_sample: String = "Canción – €5 ± × ÷ «Señor»"
	var legacy: String = FileHelper.decode_text(_cp1252(legacy_sample))
	_check("Windows-1252 se decodifica", legacy == legacy_sample)
	_check("Windows-1252 no deja U+FFFD", not legacy.contains(String.chr(0xFFFD)))
	_check("UTF-16 LE se decodifica", FileHelper.decode_text(_utf16(SAMPLE, true)) == SAMPLE)
	_check("UTF-16 BE se decodifica", FileHelper.decode_text(_utf16(SAMPLE, false)) == SAMPLE)
	_check("UTF-32 LE se decodifica", FileHelper.decode_text(_utf32(SAMPLE, true)) == SAMPLE)
	_check("UTF-32 BE se decodifica", FileHelper.decode_text(_utf32(SAMPLE, false)) == SAMPLE)
	var accidental_pair: String = FileHelper.decode_text(PackedByteArray([0xD1, 0xBB, 0xE1]))
	_check("un par CP1252 valido como UTF-8 no se confunde", accidental_pair == "Ñ»á")

	print("=== 2. escritura y lectura (storage) ===")
	var roundtrip_path: String = FIXTURE.path_join("roundtrip.txt")
	_check("write_text() escribe", FileHelper.write_text(roundtrip_path, SAMPLE))
	var raw: PackedByteArray = FileHelper.read_file(roundtrip_path)
	_check("el archivo escrito es UTF-8 valido", FileHelper.is_valid_utf8(raw))
	_check("sin BOM por defecto", not (raw.size() >= 3 and raw[0] == 0xEF and raw[1] == 0xBB and raw[2] == 0xBF))
	_check("read_text() devuelve el mismo texto", FileHelper.read_text(roundtrip_path) == SAMPLE)

	print("=== 3. song.ini y .chart heredados (processing) ===")
	SettingsManager.library_preset_downloads = false
	SettingsManager.library_roots = PackedStringArray([FIXTURE])
	SettingsManager.library_recursive = true
	SettingsManager.library_max_depth = 2
	SongLoader.scan_songs()
	var songs: Dictionary = _by_folder()
	_check("se encontraron las seis canciones", songs.size() == 6)
	var cp: Dictionary = songs.get("CP1252 Artist - Corazón Partío", {})
	_check("song.ini CP1252: titulo", str(cp.get("name", "")) == "Corazón Partío")
	_check("song.ini CP1252: artista", str(cp.get("artist", "")) == "Alejandro Sanz")
	_check("song.ini CP1252: album con simbolos", str(cp.get("album", "")) == "Más — €5 ± × ÷")
	_check("song.ini CP1252: charter", str(cp.get("charter", "")) == "Señor «Ñ»")
	var bom: Dictionary = songs.get("UTF8 BOM Artist - Añoranza", {})
	_check("song.ini UTF-8 BOM: titulo", str(bom.get("name", "")) == "Añoranza ¿¡«»?")
	_check("song.ini UTF-8 BOM: artista", str(bom.get("artist", "")) == "Niño Ñandú")
	var utf16: Dictionary = songs.get("UTF16 Artist - Lugar", {})
	_check("song.ini UTF-16 LE: titulo", str(utf16.get("name", "")) == "En Algún Lugar")
	var utf16be: Dictionary = songs.get("UTF16BE Artist - Canción", {})
	_check("song.ini UTF-16 BE: titulo", str(utf16be.get("name", "")) == "Canción del Mariachi")
	var chart: Dictionary = songs.get("Chart Artist - Volcán", {})
	_check(".chart CP1252: titulo", str(chart.get("name", "")) == "El Nervio del Volcán")
	_check(".chart CP1252: artista", str(chart.get("artist", "")) == "Caifanes")
	_check(".chart CP1252: anio", str(chart.get("year", "")) == "1994")
	_check(".chart CP1252: dificultad detectada", int(chart.get("difficulties", []).size()) == 1)
	var wide: Dictionary = songs.get("UTF8 Artist - 夜に駆ける", {})
	_check("UTF-8 sin BOM: titulo no latino", str(wide.get("name", "")) == "夜に駆ける")
	_check("UTF-8 sin BOM: simbolos", str(wide.get("album", "")) == "€ £ ¥ ± × ÷ ¿ ¡ « »")

	print("=== 4. cache en disco y recarga (storage) ===")
	_check("la cache se escribio", FileAccess.file_exists(SongLoader.CACHE_PATH))
	var cache_raw: PackedByteArray = FileHelper.read_file(SongLoader.CACHE_PATH)
	_check("la cache es UTF-8 valida", FileHelper.is_valid_utf8(cache_raw))
	var cache_text: String = FileHelper.read_text(SongLoader.CACHE_PATH)
	_check("la cache no contiene U+FFFD", not cache_text.contains(String.chr(0xFFFD)))
	_check("la cache conserva el titulo acentuado", cache_text.contains("Corazón Partío"))
	_check("la cache conserva el titulo no latino", cache_text.contains("夜に駆ける"))
	SongLoader.song_list.clear()
	_check("load_library_cache() relee", SongLoader.load_library_cache())
	songs = _by_folder()
	_check("la recarga conserva los metadatos", str(songs.get("CP1252 Artist - Corazón Partío", {}).get("name", "")) == "Corazón Partío")
	_check("la recarga conserva Unicode", str(songs.get("UTF8 Artist - 夜に駆ける", {}).get("name", "")) == "夜に駆ける")

	print("=== 5. configuracion persistida (storage) ===")
	var unicode_root: String = "/tmp/opencode/Canciones de José/Éxitos"
	SettingsManager.library_roots = PackedStringArray([unicode_root])
	SettingsManager.save_settings()
	var settings_raw: PackedByteArray = FileHelper.read_file(SettingsManager.SETTINGS_PATH)
	_check("settings.cfg es UTF-8 valido", FileHelper.is_valid_utf8(settings_raw))
	SettingsManager.library_roots = PackedStringArray()
	SettingsManager.load_settings()
	_check("la ruta acentuada sobrevive a ConfigFile", SettingsManager.library_roots == PackedStringArray([unicode_root]))

	print("=== 6. fuente de la interfaz (output) ===")
	var ui_font: Font = load("res://asset/fonts/main_font.tres")
	var missing: String = _missing_glyphs(ui_font)
	_check("la fuente principal cubre los caracteres de la muestra", missing.is_empty())
	if not missing.is_empty():
		print("  faltan: ", missing)
	var weighted_missing: String = _missing_glyphs(SettingsUI.font_weight(600))
	_check("la variacion de peso conserva el fallback", weighted_missing.is_empty())
	if not weighted_missing.is_empty():
		print("  faltan en la variacion: ", weighted_missing)

	print("")
	if _failures == 0:
		print("=== TODAS LAS COMPROBACIONES OK ===")
	else:
		print("=== ", _failures, " FALLOS ===")
	print("=== DONE ===")
	_restore_settings()
	_restore_cache()
	_remove_tree(FIXTURE)
	get_tree().quit()
