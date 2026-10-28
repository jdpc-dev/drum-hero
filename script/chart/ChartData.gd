class_name ChartData
extends RefCounted

enum NoteType {
    NORMAL,
    HOLD,
    KICK,
    OPEN_HIHAT,
    CRASH_ACCENT,
}

const DIFFICULTY_OFFSETS: Array = [0, 12, 24, 36, 48, 60]
const DIFFICULTY_NAMES: Dictionary = {
    0: "Expert",
    12: "Hard",
    24: "Medium",
    36: "Easy",
    48: "Expert+",
    60: "Extreme+",
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
    36: 3,  # Kick -> lane 3
    38: 2,  # Snare -> lane 2
    40: 2,  # Snare (extra) -> lane 2
    42: 0,  # Hi-Hat Closed -> lane 0
    44: 0,  # Hi-Hat Closed (extra) -> lane 0
    46: 0,  # Hi-Hat Open -> lane 0
    48: 4,  # Tom 1 (High) -> lane 4
    50: 4,  # Tom 1 (extra) -> lane 4
    45: 5,  # Tom 2 (Mid) -> lane 5
    47: 5,  # Tom 2 (extra) -> lane 5
    41: 6,  # Tom 3 (Low) -> lane 6
    43: 6,  # Tom 3 (extra) -> lane 6
    49: 1,  # Crash -> lane 1
    52: 1,  # Crash (extra) -> lane 1
    55: 7,  # Ride -> lane 7
    51: 7,  # Ride (extra) -> lane 7
    53: 7,  # Ride (extra) -> lane 7
    57: 1,  # Crash (extra) -> lane 1
    59: 7,  # Ride (extra) -> lane 7
}

const OPEN_HIHAT_NOTES: Array[int] = [46, 26]
const CRASH_NOTES: Array[int] = [49, 57, 52]
