class_name Palette
extends RefCounted

# Single palette for "chrome" (everything around the game rather than the game
# itself). No other script should write a literal UI Color(...): these tokens
# are referenced. Changing the theme means changing the numbers here.
#
# Lane colors deliberately do NOT live here. Highway / Note / SettingsRoot use
# the 8-tone palette because they are a game code (the player distinguishes HH
# from CRASH from SNARE by tone), not decoration.
#
# The palette is only color: no token affects position, size or margins.

# --- Night: near-black blue-violet, so red reads as hot ---
const NIGHT_VOID: Color = Color(0.020, 0.020, 0.031)
const NIGHT_BG: Color = Color(0.039, 0.039, 0.063)
const NIGHT_PANEL: Color = Color(0.063, 0.063, 0.094)
const NIGHT_ROW: Color = Color(0.086, 0.086, 0.122)
const NIGHT_ROW_HOVER: Color = Color(0.125, 0.125, 0.173)
const NIGHT_ROW_PRESSED: Color = Color(0.173, 0.173, 0.227)

# --- Blood: red ramp, from dry oxblood to hot red ---
const BLOOD_DEEP: Color = Color(0.306, 0.039, 0.071)
const BLOOD: Color = Color(0.549, 0.063, 0.125)
const BLOOD_BRIGHT: Color = Color(0.757, 0.071, 0.122)
const BLOOD_GLOW: Color = Color(0.902, 0.224, 0.275)

# --- Metal: metallic white, from gunmetal to specular white ---
const STEEL_DARK: Color = Color(0.243, 0.263, 0.298)
const STEEL: Color = Color(0.463, 0.486, 0.529)
const CHROME: Color = Color(0.682, 0.710, 0.753)
const BONE: Color = Color(0.847, 0.863, 0.890)
const BONE_HI: Color = Color(0.933, 0.941, 0.957)

# --- Text ---
const INK: Color = Color(0.020, 0.020, 0.031)
const INK_SOFT: Color = Color(0.020, 0.020, 0.031, 0.8)
const ASH: Color = Color(0.541, 0.565, 0.600)
const TEXT: Color = Color(0.894, 0.906, 0.925)

# --- Pairs with alpha already resolved ---
# The code repeated them in dozens of places, so they live here so a tone
# change propagates by itself.
const TEXT_DIM: Color = Color(0.894, 0.906, 0.925, 0.9)
const TEXT_SOFT: Color = Color(0.894, 0.906, 0.925, 0.7)
const ASH_DIM: Color = Color(0.541, 0.565, 0.600, 0.8)
const MUTED: Color = Color(0.400, 0.420, 0.455)
const MUTED_DIM: Color = Color(0.400, 0.420, 0.455, 0.8)

# --- Overlay scrims ---
const SCRIM_STRONG: Color = Color(0.020, 0.020, 0.031, 0.85)
const SCRIM_SOFT: Color = Color(0.020, 0.020, 0.031, 0.6)
const SCRIM_RESULT: Color = Color(0.020, 0.020, 0.031, 0.8)

# --- Highway beat lines ---
const BEAT_MEASURE: Color = Color(0.847, 0.863, 0.890, 0.4)
const BEAT_BEAT: Color = Color(0.847, 0.863, 0.890, 0.12)

# --- Hit line ---
# The base bar that crosses the highway width, behind the per-lane rects.
const HIT_LINE_BAR_DIM: Color = Color(0.463, 0.486, 0.529, 0.25)
