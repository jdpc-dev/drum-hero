extends Node

var note_data: Array = []
var _difficulty_offset: int = -1

var _tempo_map: Array = []
var _time_signature_map: Array = []
var _resolution: int = 480


func load_chart(path: String, root_path: String = "", difficulty_offset: int = -1) -> bool:
	note_data.clear()
	_tempo_map.clear()
	_time_signature_map.clear()
	_difficulty_offset = difficulty_offset
	var MidiParserClass = preload("res://script/chart/MidiParser.gd")
	var midi = MidiParserClass.new()
	var success: bool = midi.load(path, root_path, difficulty_offset, SettingsManager.use_guitar_fallback)
	if not success:
		return false
	_resolution = midi.get_ticks_per_beat()
	_tempo_map = midi.get_tempo_events()
	_time_signature_map = midi.get_time_signature_events()
	if difficulty_offset >= 0:
		note_data = midi.get_drum_notes_for_offset(difficulty_offset)
	else:
		note_data = midi.get_drum_notes()
	if note_data.is_empty():
		push_warning("ChartParser: No drum notes found in ", path)
	return true


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


func get_duration_seconds() -> float:
	if note_data.is_empty():
		return 0.0
	return note_data[-1].time


func get_tempo_events() -> Array:
	return _tempo_map.duplicate()


func get_time_signature_events() -> Array:
	return _time_signature_map.duplicate()
