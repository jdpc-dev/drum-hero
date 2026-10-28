class_name Judgement
extends RefCounted

enum TimingAccuracy {
    PERFECT,
    EXCELLENT,
    GOOD,
    LATE,
    EARLY,
    MISS,
}

static func evaluate(delta_seconds: float, settings: SettingsManager) -> TimingAccuracy:
    var delta_ms: float = abs(delta_seconds) * 1000.0
    var sign: float = sign(delta_seconds)

    if delta_ms <= settings.judgement_perfect_ms:
        return TimingAccuracy.PERFECT
    if delta_ms <= settings.judgement_excellent_ms:
        return TimingAccuracy.EXCELLENT
    if delta_ms <= settings.judgement_good_ms:
        return TimingAccuracy.GOOD

    if sign > 0.0:
        return TimingAccuracy.EARLY
    else:
        return TimingAccuracy.LATE


static func is_hit(acc: TimingAccuracy) -> bool:
    return acc != TimingAccuracy.MISS


static func accuracy_name(acc: TimingAccuracy) -> String:
    match acc:
        TimingAccuracy.PERFECT:
            return "PERFECT"
        TimingAccuracy.EXCELLENT:
            return "EXCELLENT"
        TimingAccuracy.GOOD:
            return "GOOD"
        TimingAccuracy.LATE:
            return "LATE"
        TimingAccuracy.EARLY:
            return "EARLY"
        TimingAccuracy.MISS:
            return "MISS"
    return ""
