extends Node

# Regression test for Rock Band MIDI difficulty decoding:
# - notes 120-124 are fill/BRE markers and must not create an Expert+ chart;
# - Expert+ is the Expert chart plus note-95 double kicks;
# - PART DRUMS_2X, when present, is the complete Expert+ chart.
# Usage: godot --headless --path . res://tools/test_expert_plus.tscn

var _failures: int = 0
var _dir: String = "/tmp/opencode/expert_plus_test"


func _check(label: String, ok: bool) -> void:
	if ok:
		print("  OK   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_dir)

	print("=== 1. los marcadores de fill/BRE no son notas ===")
	var markers_path: String = _dir.path_join("markers.mid")
	_write_midi(markers_path, [
		_track("PART DRUMS", [
			_note(0, 60), _note(120, 61), _note(240, 62), _note(360, 63),
			_note(480, 72), _note(600, 73), _note(720, 74), _note(840, 75),
			_note(960, 84), _note(1080, 85), _note(1200, 86), _note(1320, 87),
			_note(1440, 96), _note(1560, 97), _note(1680, 98), _note(1800, 99),
			_note(1920, 120), _note(1920, 121), _note(1920, 122),
			_note(1920, 123), _note(1920, 124),
		]),
	])
	var markers_info: Dictionary = MidiParser.detect_chart_info(markers_path)
	_check("Easy/Medium/Hard/Expert detectados", _offsets(markers_info.drum_difficulties) == [60, 72, 84, 96])
	_check("los marcadores no crean Expert+", not _offsets(markers_info.drum_difficulties).has(120))
	var markers_parser := MidiParser.new()
	markers_parser.load(markers_path, "", -1)
	_check("Expert+ no tiene notas", markers_parser.get_drum_notes_for_offset(120).is_empty())
	_check("Expert conserva sus 4 notas", markers_parser.get_drum_notes_for_offset(96).size() == 4)

	print("=== 2. Expert+ = Expert + kicks en la nota 95 ===")
	var plus_path: String = _dir.path_join("expert_plus.mid")
	_write_midi(plus_path, [
		_track("PART DRUMS", [
			_note(0, 96), _note(240, 95), _note(480, 97),
			_note(960, 98), _note(1440, 99),
		]),
	])
	var plus_info: Dictionary = MidiParser.detect_chart_info(plus_path)
	_check("Expert+ detectado", _offsets(plus_info.drum_difficulties).has(120))
	var plus_parser := MidiParser.new()
	plus_parser.load(plus_path, "", 120)
	var plus_notes: Array = plus_parser.get_drum_notes_for_offset(120)
	_check("Expert+ tiene 5 notas (4 Expert + 1 extra)", plus_notes.size() == 5)
	_check("el kick extra esta en el tick 240", _note_at(plus_notes, 240) != null)
	if _note_at(plus_notes, 240) != null:
		_check("el kick extra va al carril KICK", _note_at(plus_notes, 240).lane == 3)
	var expert_parser := MidiParser.new()
	expert_parser.load(plus_path, "", 96)
	var expert_notes: Array = expert_parser.get_drum_notes_for_offset(96)
	_check("Expert sigue teniendo 4 notas", expert_notes.size() == 4)
	_check("Expert no incluye el kick extra", _note_at(expert_notes, 240) == null)

	print("=== 3. PART DRUMS_2X es el chart Expert+ ===")
	var two_x_path: String = _dir.path_join("drums_2x.mid")
	_write_midi(two_x_path, [
		_track("PART DRUMS", [
			_note(0, 96), _note(480, 97), _note(960, 98), _note(1440, 99),
		]),
		_track("PART DRUMS_2X", [
			_note(0, 96), _note(240, 96), _note(480, 97),
			_note(960, 98), _note(1440, 99),
		]),
	])
	var two_x_info: Dictionary = MidiParser.detect_chart_info(two_x_path)
	_check("Expert+ detectado desde PART DRUMS_2X", _offsets(two_x_info.drum_difficulties).has(120))
	var two_x_parser := MidiParser.new()
	two_x_parser.load(two_x_path, "", -1)
	_check("Expert usa solo PART DRUMS (4 notas)", two_x_parser.get_drum_notes_for_offset(96).size() == 4)
	_check("Expert+ usa PART DRUMS_2X (5 notas)", two_x_parser.get_drum_notes_for_offset(120).size() == 5)
	var two_x_plus := MidiParser.new()
	two_x_plus.load(two_x_path, "", 120)
	_check("cargar Expert+ directamente da 5 notas", two_x_plus.get_drum_notes_for_offset(120).size() == 5)

	print("=== 4. canciones reales: los fills no inventan Expert+ ===")
	var real_songs: Array = [
		"res://songs/At the Drive-In - One Armed Scissor (Harmonix)/notes.mid",
		"res://songs/El Bananero - Ricardo/notes.mid",
		"res://songs/Republica - Ready to Go/notes.mid",
		"res://songs/System of a Down - Toxicity (Neversoft)/notes.mid",
	]
	for path in real_songs:
		if not FileAccess.file_exists(path):
			continue
		var song_info: Dictionary = MidiParser.detect_chart_info(path)
		var song_name: String = path.get_base_dir().get_file()
		_check(song_name + " no anuncia Expert+", not _offsets(song_info.drum_difficulties).has(120))
		var song_parser := MidiParser.new()
		song_parser.load(path, "", 96)
		_check(song_name + " carga Expert", not song_parser.get_drum_notes_for_offset(96).is_empty())

	if _failures == 0:
		print("\nOK: dificultades MIDI correctas")
	else:
		printerr("\n%d comprobaciones fallidas" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _offsets(difficulties: Array) -> Array:
	var out: Array = []
	for d in difficulties:
		out.append(int(d.get("offset", -1)))
	return out


func _note_at(notes: Array, tick: int) -> Variant:
	for n in notes:
		if n.tick == tick:
			return n
	return null


func _note(tick: int, note: int) -> Dictionary:
	return {"tick": tick, "note": note}


func _write_midi(path: String, tracks: Array) -> void:
	var out := PackedByteArray()
	out.append_array("MThd".to_ascii_buffer())
	_append_u32(out, 6)
	_append_u16(out, 0)
	_append_u16(out, tracks.size())
	_append_u16(out, 480)
	for track in tracks:
		out.append_array(track)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(out)
	f.close()


func _track(name: String, notes: Array) -> PackedByteArray:
	var events := PackedByteArray()
	_write_vlq(events, 0)
	events.append_array(PackedByteArray([0xFF, 0x03, name.length()]))
	events.append_array(name.to_ascii_buffer())
	_write_vlq(events, 0)
	events.append_array(PackedByteArray([0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20]))

	var last_tick: int = 0
	for note in notes:
		_write_vlq(events, note.tick - last_tick)
		last_tick = note.tick
		events.append_array(PackedByteArray([0x90, note.note, 100]))
		_write_vlq(events, 0)
		events.append_array(PackedByteArray([0x80, note.note, 0]))

	_write_vlq(events, 0)
	events.append_array(PackedByteArray([0xFF, 0x2F, 0x00]))

	var track := PackedByteArray()
	track.append_array("MTrk".to_ascii_buffer())
	_append_u32(track, events.size())
	track.append_array(events)
	return track


func _write_vlq(out: PackedByteArray, value: int) -> void:
	var chunks: Array[int] = []
	chunks.append(value & 0x7F)
	value >>= 7
	while value > 0:
		chunks.append((value & 0x7F) | 0x80)
		value >>= 7
	for i in range(chunks.size() - 1, -1, -1):
		out.append(chunks[i])


func _append_u32(out: PackedByteArray, value: int) -> void:
	out.append((value >> 24) & 0xFF)
	out.append((value >> 16) & 0xFF)
	out.append((value >> 8) & 0xFF)
	out.append(value & 0xFF)


func _append_u16(out: PackedByteArray, value: int) -> void:
	out.append((value >> 8) & 0xFF)
	out.append(value & 0xFF)
