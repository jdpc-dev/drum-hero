extends Node

# Best scores per song and difficulty. Each song stores, per difficulty, its
# highest score; the menu row shows the highest of all.
#
# It is persisted in its own ConfigFile (user://scores.cfg) on purpose: it does
# not use SettingsManager because save_settings() regenerates the file with its
# known keys and would delete any section it does not know about.

const SCORES_PATH: String = "user://scores.cfg"
const SCORES_SECTION: String = "scores"

var _best: Dictionary = {}


func _ready() -> void:
	_load_scores()


# Commits a result. It only touches disk if it beats the previous record, and
# returns the best value for the run (the score stored after saving).
func record_score(song_path: String, difficulty_offset: int, score: int) -> int:
	if song_path.is_empty():
		return 0
	score = maxi(score, 0)
	var key: String = _key(song_path, difficulty_offset)
	var previous: int = int(_best.get(key, 0))
	if score <= previous:
		return previous
	_best[key] = score
	_save_scores()
	return score


func get_best(song_path: String, difficulty_offset: int) -> int:
	if song_path.is_empty():
		return 0
	return int(_best.get(_key(song_path, difficulty_offset), 0))


# Highest score for a song across several difficulties (the ones its chart
# offers). 0 if there is no record.
func get_best_for_song(song_path: String, difficulty_offsets: Array) -> int:
	var best: int = 0
	for offset in difficulty_offsets:
		best = maxi(best, get_best(song_path, int(offset)))
	return best


# Flat key: hash of the path (folder names can contain any character, and
# ConfigFile splits on '=') plus the difficulty offset.
func _key(song_path: String, difficulty_offset: int) -> String:
	return song_path.md5_text() + "|" + str(difficulty_offset)


func _load_scores() -> void:
	_best.clear()
	var cfg := ConfigFile.new()
	if cfg.load(SCORES_PATH) != OK or not cfg.has_section(SCORES_SECTION):
		return
	for key in cfg.get_section_keys(SCORES_SECTION):
		_best[str(key)] = int(cfg.get_value(SCORES_SECTION, key, 0))


func _save_scores() -> void:
	var cfg := ConfigFile.new()
	for key in _best:
		cfg.set_value(SCORES_SECTION, key, _best[key])
	cfg.save(SCORES_PATH)