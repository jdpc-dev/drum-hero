extends Node

enum GameMode { DEFAULT, HAPTIC, CUSTOM }
enum GameState { MENU, LOADING, PLAYING, PAUSED, RESULT }

var mode: GameMode = GameMode.DEFAULT
var state: GameState = GameState.MENU

var current_song_path: String = ""
var current_song_title: String = ""
var current_song_artist: String = ""
var current_difficulty_offset: int = 0
var current_difficulty_name: String = "Expert"
var current_song_delay: float = 0.0
# Duracion real del audio en segundos (song.ini / cabecera [Song]). El chart se
# valida contra este valor para detectar si su mapa de tempo esta en la unidad
# equivocada. 0 = desconocida.
var current_song_length: float = 0.0

# Estado de navegacion del setlist. MenuRoot se reconstruye al volver del
# gameplay (cambio de escena), asi que la busqueda, el scroll y la cancion
# seleccionada viven aqui para que el jugador vuelva a donde estaba. Es estado
# de sesion, no de disco.
var menu_search_text: String = ""
var menu_scroll_position: int = 0
var menu_selected_song_path: String = ""

signal game_state_changed(new_state: GameState)
signal hit_registered(accuracy: int)
signal miss_registered()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mode = SettingsManager.game_mode as GameMode


func set_state(new_state: GameState) -> void:
	state = new_state
	game_state_changed.emit(state)


func change_scene(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
