class_name DotChartParser
extends RefCounted

var _ChartData = preload("res://script/chart/ChartData.gd")

var _notes: Array = []
var _notes_by_offset: Dictionary = {}
var _tempo_events: Array = []
var _time_sig_events: Array = []
var _skipped_lanes: Dictionary = {}
var _ticks_per_beat: int = 480
var _total_ticks: int = 0
var has_drum_track: bool = false
var using_guitar_fallback: bool = false

const _DIFF_SECTIONS: Dictionary = {
	"EasyDrums": 60,
	"MediumDrums": 72,
	"HardDrums": 84,
	"ExpertDrums": 96,
	"ExpertPlusDrums": 120,
}

# El formato .chart oficial (Phase Shift / Clone Hero) escribe `B` en
# microsegundos por beat. Otros exportadores (jdpc.dev) escriben `B` como
# BPM * 1000. Las dos lecturas son reciprocas (bpm_estandar * bpm_alterno == 60000),
# asi que ningun factor de escala constante sirve: hay que elegir la lectura.
const _MIN_PLAUSIBLE_BPM: float = 40.0
const _MAX_PLAUSIBLE_BPM: float = 260.0
# micros_por_beat = 60_000_000 / (B / 1000)
const _ALT_MICROS_FACTOR: float = 60000000000.0


func load(path: String, root_path: String = "", difficulty_offset: int = -1, use_guitar_fallback: bool = false, expected_duration: float = 0.0) -> bool:
	var data: PackedByteArray = FileHelper.read_file(path)
	if data.is_empty():
		push_error("DotChartParser: Cannot open file: ", path)
		return false
	_notes.clear()
	_notes_by_offset.clear()
	_tempo_events.clear()
	_time_sig_events.clear()
	_skipped_lanes.clear()
	has_drum_track = false
	using_guitar_fallback = false

	var content: String = data.get_string_from_utf8()
	if content.is_empty():
		push_error("DotChartParser: Empty or non-text file: ", path)
		return false

	if not _parse(content, difficulty_offset):
		return false

	if _notes.is_empty() and use_guitar_fallback:
		_notes.clear()
		_notes_by_offset.clear()
		_skipped_lanes.clear()
		var success: bool = _parse_as_guitar(content, difficulty_offset)
		if not success:
			return false
		if not _notes.is_empty():
			using_guitar_fallback = true

	_resolve_tempo_unit(expected_duration)
	_calculate_timing()
	_warn_skipped_lanes()
	return true



func _parse(content: String, difficulty_offset: int = -1) -> bool:
	var sections: Dictionary = _split_sections(content)
	if sections.is_empty():
		push_error("DotChartParser: No sections found")
		return false

	if not sections.has("Song"):
		push_error("DotChartParser: Missing [Song] section")
		return false
	_parse_song(sections["Song"])

	if sections.has("SyncTrack"):
		_parse_sync_track(sections["SyncTrack"])

	var drum_parsed: bool = false
	for section_name in sections.keys():
		if _DIFF_SECTIONS.has(section_name):
			drum_parsed = true
			var off: int = _DIFF_SECTIONS[section_name]
			if difficulty_offset < 0 or off == difficulty_offset:
				_parse_drum_section(sections[section_name], off)

	if drum_parsed:
		has_drum_track = true

	return true


func _parse_as_guitar(content: String, difficulty_offset: int = -1) -> bool:
	var sections: Dictionary = _split_sections(content)
	if sections.is_empty():
		return false

	# El fallback de guitarra se disparaba con el mapa de tempo vacio y la
	# Resolution por defecto, es decir con tiempos inventados. Se vuelve a leer
	# la cabecera para que la conversion tick -> segundos sea la real.
	_tempo_events.clear()
	_time_sig_events.clear()
	if sections.has("Song"):
		_parse_song(sections["Song"])
	if sections.has("SyncTrack"):
		_parse_sync_track(sections["SyncTrack"])

	var guitar_parsed: bool = false
	for section_name in sections.keys():
		if section_name.ends_with("Single"):
			var off: int = _guitar_section_offset(section_name)
			if off < 0:
				continue
			guitar_parsed = true
			if difficulty_offset < 0 or off == difficulty_offset:
				_parse_drum_section(sections[section_name], off, true)

	return guitar_parsed


func _guitar_section_offset(name: String) -> int:
	match name:
		"EasySingle": return 60
		"MediumSingle": return 72
		"HardSingle": return 84
		"ExpertSingle": return 96
	return -1


func _split_sections(content: String) -> Dictionary:
	var result: Dictionary = {}
	var lines: Array = content.split("\n", false)
	var current_section: String = ""
	var collecting: bool = false
	var section_lines: Array = []

	for raw_line in lines:
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with(";") or line.begins_with("#"):
			if collecting:
				section_lines.append(line)
			continue

		if not collecting:
			var bracket_open: int = line.find("[")
			var bracket_close: int = line.find("]")
			if bracket_open >= 0 and bracket_close > bracket_open:
				if current_section != "" and not result.has(current_section):
					result[current_section] = "\n".join(section_lines)
					section_lines.clear()
				current_section = line.substr(bracket_open + 1, bracket_close - bracket_open - 1)
				section_lines.clear()
				var brace_idx: int = line.find("{", bracket_close)
				if brace_idx >= 0:
					collecting = true
					var rest: String = line.substr(brace_idx + 1).strip_edges()
					if rest.length() > 0:
						if rest.begins_with("}"):
							collecting = false
							result[current_section] = ""
							current_section = ""
						else:
							section_lines.append(rest)
				else:
					collecting = false
			elif line == "{" and current_section != "":
				collecting = true
			continue

		if line == "}" and collecting:
			result[current_section] = "\n".join(section_lines)
			section_lines.clear()
			current_section = ""
			collecting = false
		elif collecting:
			var content_line: String = line
			var close_idx: int = line.find("}")
			if close_idx >= 0:
				content_line = line.substr(0, close_idx).strip_edges()
				if not content_line.is_empty():
					section_lines.append(content_line)
				result[current_section] = "\n".join(section_lines)
				section_lines.clear()
				current_section = ""
				collecting = false
			else:
				section_lines.append(line)

	if current_section != "" and not result.has(current_section):
		result[current_section] = "\n".join(section_lines)

	return result


func _parse_song(content: String) -> void:
	var lines: Array = content.split("\n", false)
	for raw_line in lines:
		var line: String = raw_line.strip_edges()
		var eq_pos: int = line.find("=")
		if eq_pos < 0:
			continue
		var key: String = line.substr(0, eq_pos).strip_edges()
		var value: String = line.substr(eq_pos + 1).strip_edges()
		if key == "Resolution" or key == "resolution":
			_ticks_per_beat = int(value)


func _parse_sync_track(content: String) -> void:
	var lines: Array = content.split("\n", false)
	for raw_line in lines:
		var line: String = raw_line.strip_edges()
		if line.is_empty():
			continue
		var eq_pos: int = line.find("=")
		if eq_pos < 0:
			continue
		var tick_str: String = line.substr(0, eq_pos).strip_edges()
		var tick: int = int(tick_str)
		var rest: String = line.substr(eq_pos + 1).strip_edges()
		var parts: Array = rest.split(" ", false)
		if parts.size() < 2:
			continue
		var event_type: String = parts[0]
		if event_type == "B":
			var raw_beat: int = int(parts[1])
			# La unidad se decide despues en _resolve_tempo_unit(); aqui solo se
			# conserva el valor crudo, sin interpretarlo.
			var ev = _ChartData.TempoEvent.new(tick, 0.0, 0.0, float(raw_beat))
			_tempo_events.append(ev)
		elif event_type == "TS":
			# "TS 4" (2 campos, denominador implicito 4) es la forma que usan la
			# mayoria de los charts exportados; "TS 3 4" tambien aparece.
			var num: int = int(parts[1])
			var den: int = int(parts[2]) if parts.size() >= 3 else 4
			if den <= 0:
				den = 4
			var ev = _ChartData.TimeSignatureEvent.new(tick, num, den)
			_time_sig_events.append(ev)


func _parse_drum_section(content: String, difficulty_offset: int, is_guitar: bool = false) -> void:
	if not is_guitar:
		has_drum_track = true

	var lines: Array = content.split("\n", false)
	for raw_line in lines:
		var line: String = raw_line.strip_edges()
		if line.is_empty():
			continue
		var eq_pos: int = line.find("=")
		if eq_pos < 0:
			continue
		var tick_str: String = line.substr(0, eq_pos).strip_edges()
		var tick: int = int(tick_str)
		var rest: String = line.substr(eq_pos + 1).strip_edges()
		var parts: Array = rest.split(" ", false)
		if parts.size() < 2:
			continue
		var event_type: String = parts[0]
		if event_type != "N":
			continue
		if parts.size() < 3:
			continue
		var chart_lane: int = int(parts[1])
		var length: int = int(parts[2]) if parts.size() >= 3 else 0

		var lane_map: Dictionary = _ChartData.CHART_LANE_MAP if not is_guitar else _guitar_lane_map()
		if not lane_map.has(chart_lane):
			# Se acumula: un chart con miles de notas en carriles desconocidos
			# generaria miles de lineas de log identicas.
			if not _skipped_lanes.has(chart_lane):
				_skipped_lanes[chart_lane] = 0
			_skipped_lanes[chart_lane] += 1
			continue

		var lane: int = lane_map[chart_lane]
		var note_type: int = _ChartData.NoteType.NORMAL
		if chart_lane == 0:
			note_type = _ChartData.NoteType.KICK
		if length > 0:
			note_type = _ChartData.NoteType.HOLD

		var nev = _ChartData.NoteEvent.new(tick, lane, note_type, length, 100, difficulty_offset, chart_lane)
		_notes.append(nev)
		if not _notes_by_offset.has(difficulty_offset):
			_notes_by_offset[difficulty_offset] = []
		_notes_by_offset[difficulty_offset].append(nev)


func _warn_skipped_lanes() -> void:
	if _skipped_lanes.is_empty():
		return
	var parts: PackedStringArray = PackedStringArray()
	for lane in _skipped_lanes:
		parts.append("lane " + str(lane) + " x" + str(_skipped_lanes[lane]))
	push_warning("DotChartParser: dropped notes on unmapped chart lanes: " + ", ".join(parts))


func _guitar_lane_map() -> Dictionary:
	return {
		0: 2,
		1: 0,
		2: 7,
		3: 1,
		4: 3,
	}


func _micros_per_tick_for(raw_value: float, alt_unit: bool) -> float:
	if raw_value <= 0.0:
		return 500000.0 / float(_ticks_per_beat)
	if alt_unit:
		return _ALT_MICROS_FACTOR / raw_value / float(_ticks_per_beat)
	return raw_value / float(_ticks_per_beat)


func _is_plausible_bpm(bpm: float) -> bool:
	return bpm >= _MIN_PLAUSIBLE_BPM and bpm <= _MAX_PLAUSIBLE_BPM


func _end_tick() -> int:
	var last: int = 0
	# _notes todavia no esta ordenado cuando se resuelve la unidad de tempo.
	for note in _notes:
		if note.tick > last:
			last = note.tick
	if not _tempo_events.is_empty():
		last = maxi(last, _tempo_events[_tempo_events.size() - 1].tick)
	return last


func _time_at_tick(tick: int, alt_unit: bool) -> float:
	var tempo_idx: int = 0
	var current_tick: int = 0
	var current_time: float = 0.0
	var current_mpt: float

	if _tempo_events[0].tick <= 0:
		current_mpt = _micros_per_tick_for(_tempo_events[0].raw_value, alt_unit)
	else:
		current_mpt = 500000.0 / float(_ticks_per_beat)
		tempo_idx = -1

	while tempo_idx + 1 < _tempo_events.size() and tick >= _tempo_events[tempo_idx + 1].tick:
		var next_ev = _tempo_events[tempo_idx + 1]
		current_time += float(next_ev.tick - current_tick) * current_mpt / 1000000.0
		current_tick = next_ev.tick
		tempo_idx += 1
		current_mpt = _micros_per_tick_for(next_ev.raw_value, alt_unit)

	return current_time + float(tick - current_tick) * current_mpt / 1000000.0


func _tick_weighted_bpm(alt_unit: bool) -> float:
	var end_tick: int = _end_tick()
	var current_tick: int = 0
	var weighted: float = 0.0
	var total_ticks: float = 0.0

	if _tempo_events[0].tick > 0:
		var lead_ticks: float = float(_tempo_events[0].tick)
		weighted += 120.0 * lead_ticks
		total_ticks += lead_ticks
		current_tick = _tempo_events[0].tick

	for i in range(_tempo_events.size()):
		var segment_end: int = _tempo_events[i + 1].tick if i + 1 < _tempo_events.size() else end_tick
		if segment_end <= current_tick:
			continue
		var mpt: float = _micros_per_tick_for(_tempo_events[i].raw_value, alt_unit)
		var bpm: float = 60000000.0 / (mpt * float(_ticks_per_beat))
		var span: float = float(segment_end - current_tick)
		weighted += bpm * span
		total_ticks += span
		current_tick = segment_end

	if total_ticks <= 0.0:
		return 0.0
	return weighted / total_ticks


func _apply_tempo_unit(alt_unit: bool) -> void:
	for ev in _tempo_events:
		var mpt: float = _micros_per_tick_for(ev.raw_value, alt_unit)
		ev.micros_per_tick = mpt
		ev.bpm = 60000000.0 / (mpt * float(_ticks_per_beat))


# Elige si `B` se lee como microsegundos por beat (estandar Phase Shift /
# Clone Hero) o como BPM * 1000 (jdpc.dev). Tratar siempre la lectura
# estandar comprime el chart entero cuando la unidad es la otra: las notas
# llegan antes, se apilan y el chart se agota a mitad de la cancion.
func _resolve_tempo_unit(expected_duration: float) -> void:
	if _tempo_events.is_empty() or _ticks_per_beat <= 0:
		return

	_tempo_events.sort_custom(func(a, b): return a.tick < b.tick)

	var use_alt: bool = false
	if expected_duration > 0.0:
		# Senal mas fuerte: el chart debe acabar cerca del audio.
		var std_err: float = absf(_time_at_tick(_end_tick(), false) - expected_duration)
		var alt_err: float = absf(_time_at_tick(_end_tick(), true) - expected_duration)
		if alt_err * 1.25 < std_err:
			use_alt = true
		elif std_err * 1.25 < alt_err:
			use_alt = false
		else:
			use_alt = _unit_from_bpm()
	else:
		use_alt = _unit_from_bpm()

	_apply_tempo_unit(use_alt)


func _unit_from_bpm() -> bool:
	var std_bpm: float = _tick_weighted_bpm(false)
	var alt_bpm: float = _tick_weighted_bpm(true)
	return not _is_plausible_bpm(std_bpm) and _is_plausible_bpm(alt_bpm)


func _calculate_timing() -> void:
	if _tempo_events.is_empty():
		var ev = _ChartData.TempoEvent.new(0, 120.0, 500000.0 / float(_ticks_per_beat), 500000.0)
		_tempo_events.append(ev)

	if _time_sig_events.is_empty():
		var ev = _ChartData.TimeSignatureEvent.new(0, 4, 4)
		_time_sig_events.append(ev)

	_notes.sort_custom(func(a, b): return a.tick < b.tick)
	_tempo_events.sort_custom(func(a, b): return a.tick < b.tick)
	# get_time_signature_at() y la generacion de lineas de compas asumen orden.
	_time_sig_events.sort_custom(func(a, b): return a.tick < b.tick)

	var current_mpt: float
	var tempo_idx: int = 0
	var current_tick: int = 0
	var current_time: float = 0.0

	if _tempo_events.size() > 0 and _tempo_events[0].tick <= 0:
		current_mpt = _tempo_events[0].micros_per_tick
	else:
		current_mpt = 500000.0 / float(_ticks_per_beat)
		tempo_idx = -1

	for note in _notes:
		while tempo_idx + 1 < _tempo_events.size() and note.tick >= _tempo_events[tempo_idx + 1].tick:
			current_time += float(_tempo_events[tempo_idx + 1].tick - current_tick) * current_mpt / 1000000.0
			current_tick = _tempo_events[tempo_idx + 1].tick
			tempo_idx += 1
			current_mpt = _tempo_events[tempo_idx].micros_per_tick

		note.time = current_time + float(note.tick - current_tick) * current_mpt / 1000000.0

	_total_ticks = _notes[-1].tick if _notes.size() > 0 else 0


func get_drum_notes() -> Array:
	return _notes.duplicate()


func get_drum_notes_for_offset(offset: int) -> Array:
	if _notes_by_offset.has(offset):
		return _notes_by_offset[offset].duplicate()
	return []


func get_tempo_events() -> Array:
	return _tempo_events.duplicate()


func get_time_signature_events() -> Array:
	return _time_sig_events.duplicate()


func get_ticks_per_beat() -> int:
	return _ticks_per_beat


func get_available_offsets() -> Dictionary:
	var counts: Dictionary = {}
	for off in _ChartData.DIFFICULTY_OFFSETS:
		if _notes_by_offset.has(off):
			var uniq: Dictionary = {}
			for n in _notes_by_offset[off]:
				uniq[n.lane] = true
			counts[off] = uniq.size()
	return counts


static func detect_difficulties(path: String, use_guitar_fallback: bool = false) -> Dictionary:
	var parser = DotChartParser.new()
	var success: bool = parser.load(path, "", -1, use_guitar_fallback)
	if not success:
		return {"difficulties": [], "has_drum_chart": false, "guitar_fallback_used": false}
	var counts: Dictionary = parser.get_available_offsets()
	var has_drum: bool = parser.has_drum_track
	var guitar_used: bool = parser.using_guitar_fallback

	if counts.is_empty():
		return {"difficulties": [], "has_drum_chart": has_drum, "guitar_fallback_used": guitar_used}

	var ChartData = preload("res://script/chart/ChartData.gd")
	var result: Array = []
	for off in ChartData.DIFFICULTY_OFFSETS:
		if counts.get(off, 0) >= 3:
			var diff_name: String = ChartData.DIFFICULTY_NAMES.get(off, "Unknown")
			result.append({"offset": off, "name": diff_name})
	return {"difficulties": result, "has_drum_chart": has_drum, "guitar_fallback_used": guitar_used}


static func detect_difficulties_fast(path: String, use_guitar_fallback: bool = false) -> Dictionary:
	var data: PackedByteArray = FileHelper.read_file(path)
	if data.is_empty():
		return {"difficulties": [], "has_drum_chart": false, "guitar_fallback_used": false}
	var content: String = data.get_string_from_utf8()
	if content.is_empty():
		return {"difficulties": [], "has_drum_chart": false, "guitar_fallback_used": false}

	var has_drum: bool = false
	var difficulties: Array = []

	if content.find("[EasyDrums]") >= 0:
		has_drum = true
		difficulties.append({"offset": 60, "name": "Easy"})
	if content.find("[MediumDrums]") >= 0:
		has_drum = true
		difficulties.append({"offset": 72, "name": "Medium"})
	if content.find("[HardDrums]") >= 0:
		has_drum = true
		difficulties.append({"offset": 84, "name": "Hard"})
	if content.find("[ExpertDrums]") >= 0:
		has_drum = true
		difficulties.append({"offset": 96, "name": "Expert"})
	if content.find("[ExpertPlusDrums]") >= 0:
		has_drum = true
		difficulties.append({"offset": 120, "name": "Expert+"})

	if not has_drum and use_guitar_fallback:
		if content.find("[EasySingle]") >= 0:
			difficulties.append({"offset": 60, "name": "Easy"})
		if content.find("[MediumSingle]") >= 0:
			difficulties.append({"offset": 72, "name": "Medium"})
		if content.find("[HardSingle]") >= 0:
			difficulties.append({"offset": 84, "name": "Hard"})
		if content.find("[ExpertSingle]") >= 0:
			difficulties.append({"offset": 96, "name": "Expert"})
		if not difficulties.is_empty():
			return {"difficulties": difficulties, "has_drum_chart": false, "guitar_fallback_used": true}

	return {"difficulties": difficulties, "has_drum_chart": has_drum, "guitar_fallback_used": false}


static func strip_quotes(value: String) -> String:
	var v: String = value.strip_edges()
	if v.length() >= 2 and v.begins_with("\"") and v.ends_with("\""):
		return v.substr(1, v.length() - 2)
	return v


static func parse_song_metadata(path: String) -> Dictionary:
	var result: Dictionary = {}
	var data: PackedByteArray = FileHelper.read_file(path)
	if data.is_empty():
		return result
	var content: String = data.get_string_from_utf8()
	if content.is_empty():
		return result
	var start: int = content.find("[Song]")
	if start < 0:
		return result
	var header_end: int = content.find("\n", start)
	if header_end < 0:
		return result
	for raw_line in content.substr(header_end + 1).split("\n", false):
		var line: String = raw_line.strip_edges()
		if line.begins_with("["):
			break
		if line == "{" or line == "}":
			continue
		var eq_pos: int = line.find("=")
		if eq_pos <= 0:
			continue
		var key: String = line.substr(0, eq_pos).strip_edges().to_lower()
		var value: String = strip_quotes(line.substr(eq_pos + 1))
		if key.is_empty() or value.is_empty():
			continue
		result[key] = value
	return result
