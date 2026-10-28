class_name ChartData
extends RefCounted

enum NoteType {
    NORMAL,
    HOLD,
    KICK,
    OPEN_HIHAT,
    CRASH_ACCENT,
}

const DIFFICULTY_OFFSETS: Array = [60, 72, 84, 96, 120]
const DIFFICULTY_NAMES: Dictionary = {
	60: "Easy",
	72: "Medium",
	84: "Hard",
	96: "Expert",
	120: "Expert+",
}

class NoteEvent:
    var tick: int
    var time: float
    var lane: int
    var note_type: NoteType
    var length: int
    var velocity: int
    var difficulty_offset: int
    var relative_note: int

    func _init(t: int, l: int, nt: NoteType, len: int = 0, vel: int = 100, diff_off: int = 0, rel: int = -1):
        tick = t
        time = 0.0
        lane = l
        note_type = nt
        length = len
        velocity = vel
        difficulty_offset = diff_off
        relative_note = rel

class TempoEvent:
    var tick: int
    var bpm: float
    var micros_per_tick: float

    func _init(t: int, b: float, mpt: float):
        tick = t
        bpm = b
        micros_per_tick = mpt

class TimeSignatureEvent:
    var tick: int
    var numerator: int
    var denominator: int

    func _init(t: int, num: int, den: int):
        tick = t
        numerator = num
        denominator = den

const LANE_MAP: Dictionary = {
	0: 3,   # Kick -> KICK lane
	1: 2,   # Red (Snare) -> SNARE lane
	2: 0,   # Yellow -> HH lane (cymbal default)
	3: 7,   # Blue -> RIDE lane (cymbal default)
	4: 1,   # Green -> CRASH lane (cymbal default)
}

const TOM_MARKERS: Dictionary = {
	110: 2,  # Yellow tom marker -> affects Yellow drum note (relative 2)
	111: 3,  # Blue tom marker -> affects Blue drum note (relative 3)
	112: 4,  # Green tom marker -> affects Green drum note (relative 4)
}

const TOM_LANE_MAP: Dictionary = {
	2: 4,   # Yellow + tom marker -> TOM 1 lane
	3: 5,   # Blue + tom marker -> TOM 2 lane
	4: 6,   # Green + tom marker -> TOM 3 lane
}
