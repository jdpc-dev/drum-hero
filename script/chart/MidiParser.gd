class_name MidiParser
extends RefCounted

var _ChartData = preload("res://script/chart/ChartData.gd")

var _notes: Array = []
var _notes_by_offset: Dictionary = {}
var _tempo_events: Array = []
var _time_sig_events: Array = []
var _ticks_per_beat: int = 480
var _total_ticks: int = 0


func load(path: String, root_path: String = "", difficulty_offset: int = -1) -> bool:
	var data: PackedByteArray = FileHelper.read_file(path)
	if data.is_empty():
		push_error("MidiParser: Cannot open file: ", path)
		return false
	_notes.clear()
	_notes_by_offset.clear()
	_tempo_events.clear()
	_time_sig_events.clear()
	return _parse(data, difficulty_offset)


func _parse(data: PackedByteArray, difficulty_offset: int = -1) -> bool:
	var offset: int = 0
	var header: String = data.slice(offset, offset + 4).get_string_from_ascii()
	offset += 4
	if header != "MThd":
		push_error("MidiParser: Invalid header")
		return false
	var header_len: int = _read32(data, offset)
	offset += 4
	var _format: int = _read16(data, offset)
	offset += 2
	var num_tracks: int = _read16(data, offset)
	offset += 2
	_ticks_per_beat = _read16(data, offset)
	offset += 2
	offset += header_len - 6

	for track_idx in range(num_tracks):
		if not _parse_track(data, offset, difficulty_offset):
			return false
		var track_len: int = _read32(data, offset + 4)
		offset += track_len + 8

	_calculate_timing()

	return true


func _parse_track(data: PackedByteArray, start: int, difficulty_offset: int = -1) -> bool:
	var offset: int = start
	var chunk_id: String = data.slice(offset, offset + 4).get_string_from_ascii()
	offset += 4
	if chunk_id != "MTrk":
		return false
	var track_len: int = _read32(data, offset)
	offset += 4
	var track_end: int = offset + track_len
	var absolute_tick: int = 0
	var running_status: int = -1
	var track_name: String = ""
	var is_drum_track: bool = false

	while offset < track_end:
		var delta_result: Dictionary = _read_vlq(data, offset)
		var delta: int = delta_result.value
		offset = delta_result.next_offset
		absolute_tick += delta

		var event_byte: int = data[offset]
		offset += 1

		if event_byte == 0xFF:
			var meta_type: int = data[offset]
			offset += 1
			var meta_len_result: Dictionary = _read_vlq(data, offset)
			var meta_len: int = meta_len_result.value
			offset = meta_len_result.next_offset
			if meta_type == 0x03:
				track_name = data.slice(offset, offset + meta_len).get_string_from_ascii()
				is_drum_track = track_name.begins_with("PART DRUMS")
			elif meta_type == 0x51:
				var micros_per_quarter: int = _read24(data, offset)
				var bpm: float = 60000000.0 / float(micros_per_quarter)
				var mpt: float = float(micros_per_quarter) / float(_ticks_per_beat)
				var ev = _ChartData.TempoEvent.new(absolute_tick, bpm, mpt)
				_tempo_events.append(ev)
			elif meta_type == 0x58:
				var num: int = data[offset]
				var den_pow: int = data[offset + 1]
				var den: int = 1 << den_pow
				var ev = _ChartData.TimeSignatureEvent.new(absolute_tick, num, den)
				_time_sig_events.append(ev)
			elif meta_type == 0x2F:
				break
			offset += meta_len
			continue

		if not is_drum_track:
			if (event_byte & 0xF0) == 0x90 or (event_byte & 0xF0) == 0x80:
				offset += 2
			elif (event_byte & 0xF0) == 0xB0 or (event_byte & 0xF0) == 0xE0:
				offset += 2
			elif (event_byte & 0xF0) == 0xC0 or (event_byte & 0xF0) == 0xD0:
				offset += 1
			elif (event_byte & 0xF0) == 0xF0:
				if event_byte == 0xF0 or event_byte == 0xF7:
					var sys_len_result: Dictionary = _read_vlq(data, offset)
					offset = sys_len_result.next_offset
					offset += sys_len_result.value
			elif running_status >= 0 and (event_byte & 0x80) == 0:
				if (running_status & 0xF0) == 0x90 or (running_status & 0xF0) == 0x80:
					offset += 2
				else:
					offset += 1
			continue

		elif (event_byte & 0xF0) == 0x90:
			running_status = event_byte
			var note: int = data[offset]
			offset += 1
			var velocity: int = data[offset]
			offset += 1
			var note_type: int = _ChartData.NoteType.NORMAL
			var lane: int = -1
			var diff_off: int = -1
			if velocity > 0:
				diff_off = _resolve_difficulty(note)
				if diff_off >= 0 and _ChartData.LANE_MAP.has(note - diff_off):
					lane = _ChartData.LANE_MAP[note - diff_off]
					if (note - diff_off) in _ChartData.OPEN_HIHAT_NOTES:
						note_type = _ChartData.NoteType.OPEN_HIHAT
					if (note - diff_off) in _ChartData.CRASH_NOTES:
						note_type = _ChartData.NoteType.CRASH_ACCENT
				if (note - diff_off) == 0:
					note_type = _ChartData.NoteType.KICK
			if lane >= 0 and (difficulty_offset < 0 or diff_off == difficulty_offset):
				var ev = _ChartData.NoteEvent.new(absolute_tick, lane, note_type, 0, velocity, diff_off)
				_notes.append(ev)
				if not _notes_by_offset.has(diff_off):
					_notes_by_offset[diff_off] = []
				_notes_by_offset[diff_off].append(ev)
			elif velocity == 0:
				_find_and_end_note(absolute_tick, note)

		elif (event_byte & 0xF0) == 0x80:
			running_status = event_byte
			var note: int = data[offset]
			offset += 1
			offset += 1
			_find_and_end_note(absolute_tick, note)

		elif (event_byte & 0xF0) == 0xB0:
			running_status = event_byte
			offset += 2
		elif (event_byte & 0xF0) == 0xC0:
			running_status = event_byte
			offset += 1
		elif (event_byte & 0xF0) == 0xD0:
			running_status = event_byte
			offset += 1
		elif (event_byte & 0xF0) == 0xE0:
			running_status = event_byte
			offset += 2
		elif (event_byte & 0xF0) == 0xF0:
			if event_byte == 0xF0:
				var sys_len_result: Dictionary = _read_vlq(data, offset)
				offset = sys_len_result.next_offset
				offset += sys_len_result.value
			elif event_byte == 0xF7:
				var sys_len2_result: Dictionary = _read_vlq(data, offset)
				offset = sys_len2_result.next_offset
				offset += sys_len2_result.value
			else:
				pass
		else:
			if running_status >= 0 and (event_byte & 0x80) == 0:
				offset -= 1
				if (running_status & 0xF0) == 0x90:
					var note: int = data[offset]
					offset += 1
					var velocity: int = data[offset]
					offset += 1
					var note_type: int = _ChartData.NoteType.NORMAL
					var lane: int = -1
					var diff_off: int = -1
					if velocity > 0:
						diff_off = _resolve_difficulty(note)
						if diff_off >= 0 and _ChartData.LANE_MAP.has(note - diff_off):
							lane = _ChartData.LANE_MAP[note - diff_off]
							if (note - diff_off) in _ChartData.OPEN_HIHAT_NOTES:
								note_type = _ChartData.NoteType.OPEN_HIHAT
							if (note - diff_off) in _ChartData.CRASH_NOTES:
								note_type = _ChartData.NoteType.CRASH_ACCENT
						if (note - diff_off) == 0:
							note_type = _ChartData.NoteType.KICK
						if lane >= 0 and (difficulty_offset < 0 or diff_off == difficulty_offset):
							var ev = _ChartData.NoteEvent.new(absolute_tick, lane, note_type, 0, velocity, diff_off)
							_notes.append(ev)
							if not _notes_by_offset.has(diff_off):
								_notes_by_offset[diff_off] = []
							_notes_by_offset[diff_off].append(ev)
					elif velocity == 0:
						_find_and_end_note(absolute_tick, note)
				elif (running_status & 0xF0) == 0x80:
					var note: int = data[offset]
					offset += 1
					offset += 1
					_find_and_end_note(absolute_tick, note)
				else:
					offset += 1

	return true


func _find_and_end_note(tick: int, midi_note: int) -> void:
	var diff_off: int = _resolve_difficulty(midi_note)
	if diff_off < 0 or not _ChartData.LANE_MAP.has(midi_note - diff_off):
		return
	var lane: int = _ChartData.LANE_MAP[midi_note - diff_off]
	for i in range(_notes.size() - 1, -1, -1):
		var n = _notes[i]
		if n.lane == lane and n.difficulty_offset == diff_off and n.length == 0 and n.tick < tick:
			n.length = tick - n.tick
			break


func _calculate_timing() -> void:
	if _tempo_events.is_empty():
		var ev = _ChartData.TempoEvent.new(0, 120.0, 500000.0 / float(_ticks_per_beat))
		_tempo_events.append(ev)

	if _time_sig_events.is_empty():
		var ev = _ChartData.TimeSignatureEvent.new(0, 4, 4)
		_time_sig_events.append(ev)

	_notes.sort_custom(func(a, b): return a.tick < b.tick)

	var current_mpt: float = 500000.0 / float(_ticks_per_beat)
	var tempo_idx: int = 0
	var current_tick: int = 0
	var current_time: float = 0.0

	for note in _notes:
		if tempo_idx + 1 < _tempo_events.size():
			var next_tempo_tick: int = _tempo_events[tempo_idx + 1].tick
			while note.tick >= next_tempo_tick:
				current_time += float(next_tempo_tick - current_tick) * current_mpt / 1000000.0
				current_tick = next_tempo_tick
				tempo_idx += 1
				current_mpt = _tempo_events[tempo_idx].micros_per_tick
				if tempo_idx + 1 >= _tempo_events.size():
					break
				next_tempo_tick = _tempo_events[tempo_idx + 1].tick

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


func _resolve_difficulty(midi_note: int) -> int:
	for off in _ChartData.DIFFICULTY_OFFSETS:
		var rel: int = midi_note - off
		if rel >= 0 and rel < 12 and _ChartData.LANE_MAP.has(rel):
			return off
	return -1


func get_available_offsets() -> Dictionary:
	var counts: Dictionary = {}
	for off in _ChartData.DIFFICULTY_OFFSETS:
		if _notes_by_offset.has(off):
			var uniq: Dictionary = {}
			for n in _notes_by_offset[off]:
				uniq[n.lane] = true
			counts[off] = uniq.size()
	return counts


static func detect_difficulties(path: String) -> Array:
	var midi = MidiParser.new()
	var success: bool = midi.load(path)
	if not success:
		return []
	var counts: Dictionary = midi.get_available_offsets()
	
	if counts.is_empty():
		return []
	
	var ChartData = preload("res://script/chart/ChartData.gd")
	var result: Array = []
	for off in ChartData.DIFFICULTY_OFFSETS:
		if counts.get(off, 0) >= 3:
			var diff_name: String = ChartData.DIFFICULTY_NAMES.get(off, "Unknown")
			result.append({"offset": off, "name": diff_name})
	return result


func _read_vlq(data: PackedByteArray, offset: int) -> Dictionary:
	var value: int = 0
	var i: int = offset
	while i < data.size():
		var byte: int = data[i]
		value = (value << 7) | (byte & 0x7F)
		i += 1
		if not (byte & 0x80):
			break
	return {"value": value, "next_offset": i}


func _read16(data: PackedByteArray, offset: int) -> int:
	return (data[offset] << 8) | data[offset + 1]


func _read24(data: PackedByteArray, offset: int) -> int:
	return (data[offset] << 16) | (data[offset + 1] << 8) | data[offset + 2]


func _read32(data: PackedByteArray, offset: int) -> int:
	return (data[offset] << 24) | (data[offset + 1] << 16) | (data[offset + 2] << 8) | data[offset + 3]
