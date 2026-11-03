class_name Palette
extends RefCounted

# Single palette for "chrome" (everything around the game rather than the game
# itself). No other script should write a literal UI Color(...): these tokens
# are referenced. Changing a theme means changing the numbers in THEME_DATA.
#
# Three themes share the same token names and the same metallic-white text and
# borders. Only the black surfaces and the accent ramp change, so a theme
# switch never changes spacing, size or contrast rules.
#
# Lane colors deliberately do NOT live here. Highway / Note / SettingsRoot use
# the 8-tone game palette because they are a game code (the player distinguishes
# HH from CRASH from SNARE by tone), not decoration.

const THEME_BLOOD: String = "blood"
const THEME_TEAR: String = "tear"
const THEME_HACKER: String = "hacker"
const THEME_IDS: Array[String] = [THEME_BLOOD, THEME_TEAR, THEME_HACKER]

# The active theme and a counter the menu uses to notice that a theme was
# selected while the settings overlay was open.
static var current_theme: String = THEME_BLOOD
static var revision: int = 0

# --- Night: near-black surfaces, tinted per theme ---
static var NIGHT_VOID: Color = Color("#050304")
static var NIGHT_BG: Color = Color("#0A0709")
static var NIGHT_PANEL: Color = Color("#100B0E")
static var NIGHT_ROW: Color = Color("#161014")
static var NIGHT_ROW_HOVER: Color = Color("#20161B")
static var NIGHT_ROW_PRESSED: Color = Color("#2C1E24")

# --- Settings chrome: layered surfaces for cards, rows and controls ---
# They sit between NIGHT_PANEL and NIGHT_ROW so a card can hold a control
# without either one disappearing into the other.
static var SURFACE_0: Color = Color("#0E090B")
static var SURFACE_1: Color = Color("#120C0F")
static var SURFACE_2: Color = Color("#181014")
static var SURFACE_3: Color = Color("#1F151A")
static var SURFACE_4: Color = Color("#281C22")

# --- Accent: theme-specific ramp ---
# ACCENT is the fill; ACCENT_BRIGHT is hover; ACCENT_PRESSED is the pressed
# button fill. ACCENT_GLOW is for accent-colored text on dark surfaces.
static var ACCENT_DEEP: Color = Color("#5C0A12")
static var ACCENT: Color = Color("#C1121F")
static var ACCENT_BRIGHT: Color = Color("#D01A27")
static var ACCENT_PRESSED: Color = Color("#8C1020")
static var ACCENT_GLOW: Color = Color("#F26B73")
static var ACCENT_SOFT: Color = Color(0.757, 0.071, 0.122, 0.14)
static var ACCENT_FAINT: Color = Color(0.757, 0.071, 0.122, 0.07)
static var ACCENT_EDGE: Color = Color(0.757, 0.071, 0.122, 0.42)

# Opaque version of ACCENT_SOFT over the settings cards. Rounded pills use it
# instead of the translucent token so their antialiased corners do not pick up
# a different shade from whatever surface happens to sit behind them.
static var ACCENT_SURFACE: Color = Color("#2E0B11")
static var ACCENT_SURFACE_HOVER: Color = Color("#3C0F17")

# Fill color for text drawn on top of a primary accent button. Hacker uses the
# near-black ink so the bright green button keeps a strong contrast.
static var ON_ACCENT: Color = Color("#EEF0F4")

# --- Metal: metallic white, constant across themes ---
const STEEL_DARK: Color = Color(0.243, 0.263, 0.298)
const STEEL: Color = Color(0.463, 0.486, 0.529)
const CHROME: Color = Color(0.682, 0.710, 0.753)
const BONE: Color = Color(0.847, 0.863, 0.890)
const BONE_HI: Color = Color(0.933, 0.941, 0.957)

# Hairlines for cards and controls. Alpha keeps them readable on any surface.
const BORDER_SOFT: Color = Color(1.0, 1.0, 1.0, 0.055)
const BORDER: Color = Color(1.0, 1.0, 1.0, 0.10)
const BORDER_STRONG: Color = Color(1.0, 1.0, 1.0, 0.16)

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

# --- Overlay scrims: theme void with alpha already resolved ---
static var SCRIM_STRONG: Color = Color(0.020, 0.012, 0.016, 0.85)
static var SCRIM_SOFT: Color = Color(0.020, 0.012, 0.016, 0.6)
static var SCRIM_RESULT: Color = Color(0.020, 0.012, 0.016, 0.8)

# --- Highway beat lines ---
const BEAT_MEASURE: Color = Color(0.847, 0.863, 0.890, 0.4)
const BEAT_BEAT: Color = Color(0.847, 0.863, 0.890, 0.12)

# --- Hit line ---
# The base bar that crosses the highway width, behind the per-lane rects.
const HIT_LINE_BAR_DIM: Color = Color(0.463, 0.486, 0.529, 0.25)


# Theme data. Keep the keys identical across all three themes: apply_theme()
# copies them into the static tokens above.
static var THEME_DATA: Dictionary = {
	THEME_BLOOD: {
		"name": "Blood",
		"description": "Oxblood, black and bare steel. Gore, hate and pain.",
		"void": Color("#050304"),
		"bg": Color("#0A0709"),
		"panel": Color("#100B0E"),
		"row": Color("#161014"),
		"row_hover": Color("#20161B"),
		"row_pressed": Color("#2C1E24"),
		"surface_0": Color("#0E090B"),
		"surface_1": Color("#120C0F"),
		"surface_2": Color("#181014"),
		"surface_3": Color("#1F151A"),
		"surface_4": Color("#281C22"),
		"accent_deep": Color("#5C0A12"),
		"accent": Color("#C1121F"),
		"accent_bright": Color("#D01A27"),
		"accent_pressed": Color("#8C1020"),
		"accent_glow": Color("#F26B73"),
		"accent_surface": Color("#2E0B11"),
		"accent_surface_hover": Color("#3C0F17"),
		"on_accent": BONE_HI,
	},
	THEME_TEAR: {
		"name": "Tear",
		"description": "Deep-ocean blue, black and cold steel. Melancholy, sadness and depression.",
		"void": Color("#030507"),
		"bg": Color("#06090E"),
		"panel": Color("#0A0F16"),
		"row": Color("#0E151E"),
		"row_hover": Color("#141E2A"),
		"row_pressed": Color("#1C2937"),
		"surface_0": Color("#070B11"),
		"surface_1": Color("#0A1018"),
		"surface_2": Color("#0E1620"),
		"surface_3": Color("#131E2A"),
		"surface_4": Color("#1A2837"),
		"accent_deep": Color("#0C3346"),
		"accent": Color("#23718A"),
		"accent_bright": Color("#1F6B82"),
		"accent_pressed": Color("#17566B"),
		"accent_glow": Color("#86CBE0"),
		"accent_surface": Color("#0B2532"),
		"accent_surface_hover": Color("#103141"),
		"on_accent": BONE_HI,
	},
	THEME_HACKER: {
		"name": "Hacker",
		"description": "Terminal green, black and steel. Systems, the underground and illegality.",
		"void": Color("#020503"),
		"bg": Color("#050907"),
		"panel": Color("#080F0B"),
		"row": Color("#0C1610"),
		"row_hover": Color("#12211A"),
		"row_pressed": Color("#192D23"),
		"surface_0": Color("#060B08"),
		"surface_1": Color("#09110C"),
		"surface_2": Color("#0D1812"),
		"surface_3": Color("#12221A"),
		"surface_4": Color("#182D22"),
		"accent_deep": Color("#063D1A"),
		"accent": Color("#1FAF4B"),
		"accent_bright": Color("#3ED36F"),
		"accent_pressed": Color("#2BC15B"),
		"accent_glow": Color("#7BE89B"),
		"accent_surface": Color("#082615"),
		"accent_surface_hover": Color("#0C341D"),
		"on_accent": INK,
	},
}


static func normalize_theme(theme_id: String) -> String:
	var id: String = theme_id.strip_edges().to_lower()
	return id if THEME_DATA.has(id) else THEME_BLOOD


static func theme_name(theme_id: String) -> String:
	return str(THEME_DATA[normalize_theme(theme_id)]["name"])


static func theme_description(theme_id: String) -> String:
	return str(THEME_DATA[normalize_theme(theme_id)]["description"])


static func theme_swatches(theme_id: String) -> Array[Color]:
	var data: Dictionary = THEME_DATA[normalize_theme(theme_id)]
	var colors: Array[Color] = [data["bg"], data["accent"], BONE]
	return colors


static func apply_theme(theme_id: String) -> String:
	var id: String = normalize_theme(theme_id)
	var data: Dictionary = THEME_DATA[id]

	NIGHT_VOID = data["void"]
	NIGHT_BG = data["bg"]
	NIGHT_PANEL = data["panel"]
	NIGHT_ROW = data["row"]
	NIGHT_ROW_HOVER = data["row_hover"]
	NIGHT_ROW_PRESSED = data["row_pressed"]

	SURFACE_0 = data["surface_0"]
	SURFACE_1 = data["surface_1"]
	SURFACE_2 = data["surface_2"]
	SURFACE_3 = data["surface_3"]
	SURFACE_4 = data["surface_4"]

	ACCENT_DEEP = data["accent_deep"]
	ACCENT = data["accent"]
	ACCENT_BRIGHT = data["accent_bright"]
	ACCENT_PRESSED = data["accent_pressed"]
	ACCENT_GLOW = data["accent_glow"]
	ACCENT_SOFT = _with_alpha(ACCENT, 0.14)
	ACCENT_FAINT = _with_alpha(ACCENT, 0.07)
	ACCENT_EDGE = _with_alpha(ACCENT, 0.42)
	ACCENT_SURFACE = data["accent_surface"]
	ACCENT_SURFACE_HOVER = data["accent_surface_hover"]
	ON_ACCENT = data["on_accent"]

	SCRIM_STRONG = _with_alpha(NIGHT_VOID, 0.85)
	SCRIM_SOFT = _with_alpha(NIGHT_VOID, 0.6)
	SCRIM_RESULT = _with_alpha(NIGHT_VOID, 0.8)

	# Re-applying the same theme (for example the ADVANCED reset while Blood is
	# already active) must not make the menu think the palette changed.
	if current_theme != id:
		current_theme = id
		revision += 1
	return id


static func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)
