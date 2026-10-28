class_name ScoreData
extends RefCounted

static func format_score(value: int) -> String:
    var s: String = str(value)
    var result: String = ""
    var count: int = 0
    for i in range(s.length() - 1, -1, -1):
        if count > 0 and count % 3 == 0:
            result = "," + result
        result = s[i] + result
        count += 1
    return result
