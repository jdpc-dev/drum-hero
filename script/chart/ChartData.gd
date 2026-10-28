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

    func _init(t: int, l: int, nt: NoteType, len: int = 0, vel: int = 100, diff_off: int = 0):
        tick = t
        time = 0.0
        lane = l
        note_type = nt
        length = len
        velocity = vel
        difficulty_offset = diff_off

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
	1: 2,   # Snare (Red) -> SNARE lane
	2: 0,   # Hi-Hat Closed (Yellow) -> HH lane
	3: 7,   # Ride (Blue) -> RIDE lane
	4: 1,   # Crash (Green) -> CRASH lane
	5: 2,   # Snare (alt) -> SNARE lane
	6: 0,   # Hi-Hat Open -> HH lane
	7: 7,   # Ride (bell/edge) -> RIDE lane
	8: 1,   # Crash (alt) -> CRASH lane
	9: 4,   # Tom 1 -> TOM 1 lane
	10: 5,  # Tom 2 -> TOM 2 lane
	11: 6,  # Tom 3 -> TOM 3 lane
}

const OPEN_HIHAT_NOTES: Array[int] = [6]
const CRASH_NOTES: Array[int] = [4, 8]
