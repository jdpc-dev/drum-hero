extends Node

# Mejores puntuaciones por cancion y dificultad. Cada cancion guarda, por
# dificultad, su score mas alto; la fila del menu muestra el mayor de todos.
#
# Se persiste en un ConfigFile propio (user://scores.cfg) a proposito: no se
# aprovecha SettingsManager porque save_settings() regenera el fichero con sus
# claves conocidas y borraria cualquier seccion que no conozca.

const SCORES_PATH: String = "user://scores.cfg"
const SCORES_SECTION: String = "scores"

var _best: Dictionary = {}


func _ready() -> void:
	_load_scores()


# Comitea un resultado. Solo toca el disco si supera el record anterior, y
# devuelve el mejor valor de la partida (el score almacenado tras el guardado).
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


# Mayor score de una cancion entre varias dificultades (las que ofrece su
# chart). 0 si no hay ningun record.
func get_best_for_song(song_path: String, difficulty_offsets: Array) -> int:
	var best: int = 0
	for offset in difficulty_offsets:
		best = maxi(best, get_best(song_path, int(offset)))
	return best


# Clave plana: hash del path (los nombres de carpeta pueden llevar cualquier
# caracter, y ConfigFile corta en los '=') mas el offset de dificultad.
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