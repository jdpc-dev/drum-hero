extends Node

var score: int = 0
var combo: int = 0
var max_combo: int = 0
var multiplier: int = 1
var hits: int = 0
var misses: int = 0

signal combo_changed(new_combo: int)
signal multiplier_changed(new_mult: int)
signal score_changed(new_score: int)

const MULT_THRESHOLDS: Dictionary = {
    10: 2,
    20: 3,
    30: 4,
    40: 5,
    50: 6,
    60: 7,
    70: 8,
}


func reset() -> void:
    score = 0
    combo = 0
    max_combo = 0
    multiplier = 1
    hits = 0
    misses = 0
    _emit_all()


func register_hit(accuracy: float) -> void:
    hits += 1
    combo += 1
    if combo > max_combo:
        max_combo = combo
    _update_multiplier()
    var base_score: int = 50
    var accuracy_bonus: float = 1.0 - abs(accuracy) / 0.135
    accuracy_bonus = clampf(accuracy_bonus, 0.0, 1.0)
    var earned: int = ceili(float(base_score) * (1.0 + accuracy_bonus) * float(multiplier))
    score += earned
    score_changed.emit(score)
    combo_changed.emit(combo)


func register_miss() -> void:
    misses += 1
    combo = 0
    multiplier = 1
    combo_changed.emit(combo)
    multiplier_changed.emit(multiplier)


func _update_multiplier() -> void:
    var new_mult: int = 1
    for threshold in MULT_THRESHOLDS:
        if combo >= threshold:
            new_mult = MULT_THRESHOLDS[threshold]
    if new_mult != multiplier:
        multiplier = new_mult
        multiplier_changed.emit(multiplier)


func get_score() -> int:
    return score


func get_combo() -> int:
    return combo


func get_multiplier() -> int:
    return multiplier


func get_accuracy_pct() -> float:
    var total: int = hits + misses
    if total == 0:
        return 100.0
    return float(hits) / float(total) * 100.0


func _emit_all() -> void:
    score_changed.emit(score)
    combo_changed.emit(combo)
    multiplier_changed.emit(multiplier)
