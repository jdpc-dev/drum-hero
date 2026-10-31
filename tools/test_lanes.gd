extends Node

var _failures: int = 0


func _check(label: String, ok: bool) -> void:
	if ok:
		print("  OK   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)


func _load(path: String, off: int) -> DotChartParser:
	var p := DotChartParser.new()
	p.load(path, "", off, false)
	return p


func _lane_of(notes: Array, chart_lane: int) -> int:
	for n in notes:
		if n.relative_note == chart_lane:
			return n.lane
	return -1


func _ready() -> void:
	var path: String = "/tmp/opencode/libtest/lanes/notes.chart"

	print("=== 1. los toms 66/67/68 ya NO se descartan ===")
	var p := _load(path, 96)
	_check("chart cargado", p._notes.size() > 0)
	_check("65 y 99 se descartan", p._skipped_lanes.size() == 2)
	_check("65 x3 descartado", p._skipped_lanes.get(65, 0) == 3)
	_check("99 x1 descartado", p._skipped_lanes.get(99, 0) == 1)
	_check("66/67/68 ya no aparecen como descartados", not p._skipped_lanes.has(66) and not p._skipped_lanes.has(67) and not p._skipped_lanes.has(68))

	print("=== 2. mapeo completo de carriles ===")
	_check("0 kick->3", _lane_of(p._notes, 0) == 3)
	_check("1 snare->2", _lane_of(p._notes, 1) == 2)
	_check("2 yellow->0 HH", _lane_of(p._notes, 2) == 0)
	_check("3 blue->7 RIDE", _lane_of(p._notes, 3) == 7)
	_check("4 green->1 CRASH", _lane_of(p._notes, 4) == 1)
	_check("5 yellow tom->4 TOM1", _lane_of(p._notes, 5) == 4)
	_check("6 blue tom->5 TOM2", _lane_of(p._notes, 6) == 5)
	_check("7 green tom->6 TOM3", _lane_of(p._notes, 7) == 6)
	_check("66 tom->4 TOM1", _lane_of(p._notes, 66) == 4)
	_check("67 tom->5 TOM2", _lane_of(p._notes, 67) == 5)
	_check("68 tom->6 TOM3", _lane_of(p._notes, 68) == 6)
	var used: Dictionary = {}
	for n in p._notes:
		used[n.lane] = true
	_check("las 8 carriles del juego se usan", used.size() == 8)

	print("=== 3. cancion real: Caos - La Planta ===")
	var song_path: String = "res://Songs/Caos - La Planta (jdpc.dev)/notes.chart"
	if not FileAccess.file_exists(song_path):
		print("  (omitida: cancion no presente)")
	else:
		SettingsManager.library_preset_downloads = false
		SettingsManager.library_preset_documents = false
		SettingsManager.library_roots = PackedStringArray()
		SongLoader.scan_songs()
		var song: Dictionary = {}
		for s in SongLoader.song_list:
			if str(s.get("name", "")) == "La Planta":
				song = s
		_check("la cancion aparece en la lista", not song.is_empty())
		if not song.is_empty():
			print("  ", song.get("artist"), " - ", song.get("name"), " | ", song.get("album"), " | ", song.get("year"), " | len=", song.get("song_length"))
			_check("artista de song.ini", song.get("artist") == "Caos")
			_check("album de song.ini", song.get("album") == "La Vida Gacha")
			_check("cancion con chart de bateria", song.get("has_drum_chart") == true)
			_check("no marcada como audio bloqueado (.ogg presente)", song.get("audio_blocked") == false)
			var diffs: Array = song.get("difficulties", [])
			_check("4 dificultades de bateria", diffs.size() == 4)
			var offs: Array = []
			for d in diffs:
				offs.append(d.offset)
			offs.sort()
			_check("dificultades 60/72/84/96", offs == [60, 72, 84, 96])
			# The chart has 2027 notes in Expert: 1309 in lanes 0-4 and 718 in toms 66/67/68.
			var ex := _load(song_path, 96)
			_check("Expert carga las 2027 notas (antes 1309)", ex._notes.size() == 2027)
			_check("Expert no descarta notas", ex._skipped_lanes.is_empty())
			var by_lane: Dictionary = {}
			for n in ex._notes:
				by_lane[n.lane] = int(by_lane.get(n.lane, 0)) + 1
			_check("Expert usa las 8 carriles", by_lane.size() == 8)
			print("  Expert por carril: ", by_lane)

	print("=== 4. deteccion de audio .opus bloqueado ===")
	SettingsManager.library_preset_downloads = false
	SettingsManager.library_preset_documents = false
	SettingsManager.library_roots = PackedStringArray(["/tmp/opencode/libtest/opustest"])
	SongLoader.scan_songs()
	var by_name: Dictionary = {}
	for s in SongLoader.song_list:
		by_name[str(s.get("name", ""))] = s
	_check("solo song.opus se marca bloqueado", by_name.get("OnlyOpus", {}).get("audio_blocked", false) == true)
	_check("song.opus + song.ogg NO se marca", by_name.get("OpusAndOgg", {}).get("audio_blocked", false) == false)
	_check("solo song.ogg NO se marca", by_name.get("OnlyOgg", {}).get("audio_blocked", false) == false)
	_check("sin audio NO se marca", by_name.get("NoAudio", {}).get("audio_blocked", false) == false)

	print("")
	if _failures == 0:
		print("=== TODAS LAS COMPROBACIONES OK ===")
	else:
		print("=== ", _failures, " FALLOS ===")
	get_tree().quit()
