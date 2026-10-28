extends Node

var note_data: Array = []
var _difficulty_offset: int = -1
var _expected_duration: float = 0.0

var _tempo_map: Array = []
var _time_signature_map: Array = []
var _resolution: int = 480


func load_chart(path: String, root_path: String = "", difficulty_offset: int = -1, expected_duration: float = 0.0) -> bool:
	note_data.clear()
	_tempo_map.clear()
	_time_signature_map.clear()
	_difficulty_offset = difficulty_offset
	_expected_duration = maxf(0.0, expected_duration)
	var ext: String = path.get_extension().to_lower()
	var parser
	if ext == "mid":
		var MidiParserClass = preload("res://script/chart/MidiParser.gd")
		parser = MidiParserClass.new()
	elif ext == "chart":
		var DotChartParserClass = preload("res://script/chart/DotChartParser.gd")
		parser = DotChartParserClass.new()
	else:
		push_error("ChartParser: Unsupported format: ", ext)
		return false
	var success: bool = parser.load(path, root_path, difficulty_offset, SettingsManager.use_guitar_fallback, _expected_duration)
	if not success:
		return false
	_resolution = parser.get_ticks_per_beat()
	_tempo_map = parser.get_tempo_events()
	_time_signature_map = parser.get_time_signature_events()
	if difficulty_offset >= 0:
		note_data = parser.get_drum_notes_for_offset(difficulty_offset)
	else:
		note_data = parser.get_drum_notes()
	if note_data.is_empty():
		push_warning("ChartParser: No drum notes found in ", path)
	return true


# Descarta el chart cargado. El free mode entra a proposito con la pista vacia:
# sin esto, Highway._process() seguiría lanzando las notas de la ultima cancion
# jugada y las contaria como falladas al instante.
func clear() -> void:
	note_data.clear()
	_tempo_map.clear()
	_time_signature_map.clear()
	_resolution = 480
	_expected_duration = 0.0
	_difficulty_offset = -1


func get_notes_in_range(start_time: float, end_time: float) -> Array:
	var result: Array = []
	var start_idx: int = find_next_note_index(start_time)
	for i in range(start_idx, note_data.size()):
		var note = note_data[i]
		if note.time > end_time:
			break
		result.append(note)
	return result


func get_note_count() -> int:
	return note_data.size()


func has_data() -> bool:
	return not note_data.is_empty()


func get_tempo_at(tick: int) -> float:
	var last_tempo: float = 120.0
	for entry in _tempo_map:
		if entry.tick <= tick:
			last_tempo = entry.bpm
		else:
			break
	return last_tempo


func get_time_signature_at(tick: int) -> Vector2i:
	var last_ts: Vector2i = Vector2i(4, 4)
	for entry in _time_signature_map:
		if entry.tick <= tick:
			last_ts = Vector2i(entry.numerator, entry.denominator)
		else:
			break
	return last_ts


func find_next_note_index(from_time: float) -> int:
	if note_data.is_empty():
		return 0
	var lo := 0
	var hi := note_data.size() - 1
	while lo <= hi:
		var mid := (lo + hi) / 2
		if note_data[mid].time < from_time:
			lo = mid + 1
		else:
			hi = mid - 1
	return lo


func get_resolution() -> int:
	return _resolution


# Ultimo instante covered por el chart: el tick de la ultima nota. Sirve para
# diagnostico; el final real de la cancion lo incluye el audio.
func get_chart_end_seconds() -> float:
	if note_data.is_empty():
		return 0.0
	return note_data[-1].time


# Duracion total de la cancion. La ultima nota del chart suele caer antes del
# final del audio (intro/outro), asi que se toma el maximo de ambos: usar solo el
# tick de la ultima nota vaciaba la barra de tiempo antes de tiempo.
func get_duration_seconds() -> float:
	return maxf(get_chart_end_seconds(), _expected_duration)


func get_tempo_events() -> Array:
	return _tempo_map.duplicate()


func get_time_signature_events() -> Array:
	return _time_signature_map.duplicate()
