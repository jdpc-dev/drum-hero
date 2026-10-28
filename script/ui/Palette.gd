class_name Palette
extends RefCounted

# Paleta unica de "chrome" (todo lo que rodea al juego en vez de ser el juego).
# Ningun otro script deberia escribir un Color(...) literal de interfaz: se
# referencian estos tokens. Cambiar el tema es cambiar los numeros de aqui.
#
# Los colores de carril NO viven aqui a proposito. Highway / Note / SettingsRoot
# usan la paleta de 8 tonos porque son un codigo de juego (el jugador distingue
# HH de CRASH de SNARE por tono), no decoracion.
#
# La paleta es solo color: ningun token afecta posicion, tamano ni margenes.

# --- Noche: azul-violeta casi negro, para que el rojo se lea como caliente ---
const NIGHT_VOID: Color = Color(0.020, 0.020, 0.031)
const NIGHT_BG: Color = Color(0.039, 0.039, 0.063)
const NIGHT_PANEL: Color = Color(0.063, 0.063, 0.094)
const NIGHT_ROW: Color = Color(0.086, 0.086, 0.122)
const NIGHT_ROW_HOVER: Color = Color(0.125, 0.125, 0.173)
const NIGHT_ROW_PRESSED: Color = Color(0.173, 0.173, 0.227)

# --- Sangre: rampa de rojo, de oxblood seco a rojo caliente ---
const BLOOD_DEEP: Color = Color(0.306, 0.039, 0.071)
const BLOOD: Color = Color(0.549, 0.063, 0.125)
const BLOOD_BRIGHT: Color = Color(0.757, 0.071, 0.122)
const BLOOD_GLOW: Color = Color(0.902, 0.224, 0.275)

# --- Metal: blanco metalico, de gunmetal a blanco specular ---
const STEEL_DARK: Color = Color(0.243, 0.263, 0.298)
const STEEL: Color = Color(0.463, 0.486, 0.529)
const CHROME: Color = Color(0.682, 0.710, 0.753)
const BONE: Color = Color(0.847, 0.863, 0.890)
const BONE_HI: Color = Color(0.933, 0.941, 0.957)

# --- Texto ---
const INK: Color = Color(0.020, 0.020, 0.031)
const INK_SOFT: Color = Color(0.020, 0.020, 0.031, 0.8)
const ASH: Color = Color(0.541, 0.565, 0.600)
const TEXT: Color = Color(0.894, 0.906, 0.925)

# --- Pares con alfa ya resueltos ---
# Los repetia el codigo en decenas de sitios, asi que viven aqui para que un
# cambio de tono se propague solo.
const TEXT_DIM: Color = Color(0.894, 0.906, 0.925, 0.9)
const TEXT_SOFT: Color = Color(0.894, 0.906, 0.925, 0.7)
const ASH_DIM: Color = Color(0.541, 0.565, 0.600, 0.8)
const MUTED: Color = Color(0.400, 0.420, 0.455)
const MUTED_DIM: Color = Color(0.400, 0.420, 0.455, 0.8)

# --- Velos (scrims) de los overlays ---
const SCRIM_STRONG: Color = Color(0.020, 0.020, 0.031, 0.85)
const SCRIM_SOFT: Color = Color(0.020, 0.020, 0.031, 0.6)
const SCRIM_RESULT: Color = Color(0.020, 0.020, 0.031, 0.8)

# --- Lineas de pulso del highway ---
const BEAT_MEASURE: Color = Color(0.847, 0.863, 0.890, 0.4)
const BEAT_BEAT: Color = Color(0.847, 0.863, 0.890, 0.12)

# --- Linea de golpeo ---
# La barra base que cruza el ancho del highway, detras de los rects por carril.
const HIT_LINE_BAR_DIM: Color = Color(0.463, 0.486, 0.529, 0.25)
