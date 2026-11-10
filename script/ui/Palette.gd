class_name Palette
extends RefCounted

# Single palette for "chrome" (everything around the game rather than the game
# itself). No other script should write a literal UI Color(...): these tokens
# are referenced. Changing a theme means changing the numbers in THEME_DATA.
#
# Three themes share the same black background, surface layers, metallic-white
# text and borders. Only the accent ramp and on-accent ink change, so a theme
# switch never changes the foundation, spacing, size or contrast rules.
#
# Lane colors deliberately do NOT live here. Highway / Note / SettingsRoot use
# the 8-tone game palette because they are a game code (the player distinguishes
# HH from CRASH from SNARE by tone), not decoration.

const THEME_BLOOD: String = "blood"
const THEME_TEAR: String = "tear"
const THEME_VIRUS: String = "virus"
const THEME_IDS: Array[String] = [THEME_BLOOD, THEME_TEAR, THEME_VIRUS]

# Saved settings from before the rename. normalize_theme() maps it forward so
# an existing selection survives the id change instead of falling back to Blood.
const LEGACY_THEME_HACKER: String = "hacker"

# The active theme and a counter the menu uses to notice that a theme was
# selected while the settings overlay was open.
static var current_theme: String = THEME_BLOOD
static var revision: int = 0

# --- Shared black foundation ---
# The same values are used by every theme and by the launch splash. Themes
# differ only in the accent ramp, so switching one never changes the canvas.
const NIGHT_VOID: Color = Color("#000000")
const NIGHT_BG: Color = Color("#000000")
const NIGHT_PANEL: Color = Color("#0C0C0C")
const NIGHT_ROW: Color = Color("#121212")
const NIGHT_ROW_HOVER: Color = Color("#1A1A1A")
const NIGHT_ROW_PRESSED: Color = Color("#252525")

# --- Settings chrome: layered surfaces for cards, rows and controls ---
# They sit between NIGHT_PANEL and NIGHT_ROW so a card can hold a control
# without either one disappearing into the other.
const SURFACE_0: Color = Color("#0A0A0A")
const SURFACE_1: Color = Color("#0E0E0E")
const SURFACE_2: Color = Color("#141414")
const SURFACE_3: Color = Color("#1B1B1B")
const SURFACE_4: Color = Color("#242424")

# --- Accent: theme-specific ramp ---
# ACCENT is the fill; ACCENT_BRIGHT is hover; ACCENT_PRESSED is the pressed
# button fill. ACCENT_GLOW is for accent-colored text on dark surfaces.
static var ACCENT_DEEP: Color = Color("#5C0008")
static var ACCENT: Color = Color("#BC000E")
static var ACCENT_BRIGHT: Color = Color("#D40012")
static var ACCENT_PRESSED: Color = Color("#7A0006")
static var ACCENT_GLOW: Color = Color("#FF3B3B")
static var ACCENT_SOFT: Color = Color(0.737, 0.000, 0.055, 0.14)
static var ACCENT_FAINT: Color = Color(0.737, 0.000, 0.055, 0.07)
static var ACCENT_EDGE: Color = Color(0.737, 0.000, 0.055, 0.42)

# Opaque version of ACCENT_SOFT over the settings cards. Rounded pills use it
# instead of the translucent token so their antialiased corners do not pick up
# a different shade from whatever surface happens to sit behind them.
static var ACCENT_SURFACE: Color = Color("#3A0008")
static var ACCENT_SURFACE_HOVER: Color = Color("#4F000C")

# Fill color for text drawn on top of a primary accent button. Virus uses the
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

# --- Overlay scrims: shared void with alpha already resolved ---
const SCRIM_STRONG: Color = Color(0.0, 0.0, 0.0, 0.85)
const SCRIM_SOFT: Color = Color(0.0, 0.0, 0.0, 0.6)
const SCRIM_RESULT: Color = Color(0.0, 0.0, 0.0, 0.8)

# --- Highway beat lines ---
const BEAT_MEASURE: Color = Color(0.847, 0.863, 0.890, 0.4)
const BEAT_BEAT: Color = Color(0.847, 0.863, 0.890, 0.12)

# --- Hit line ---
# The base bar that crosses the highway width, behind the per-lane rects.
const HIT_LINE_BAR_DIM: Color = Color(0.463, 0.486, 0.529, 0.25)
# Neutral base for the hit zone (hit lanes + note input pads). Their colors are
# translucent, so a white backing at low opacity lifts them off the black
# highway without washing them out.
const HIT_ZONE_BACKING: Color = Color(1.0, 1.0, 1.0, 0.20)


# Theme data. Each theme owns only the accent ramp and on-accent ink; the black
# foundation above is shared. Keep the accent keys identical across all themes.
static var THEME_DATA: Dictionary = {
	THEME_BLOOD: {
		"name": "Blood",
		"description": "Oxblood, black and bare steel. Gore, hate and pain.",
		"accent_deep": Color("#5C0008"),
		"accent": Color("#BC000E"),
		"accent_bright": Color("#D40012"),
		"accent_pressed": Color("#7A0006"),
		"accent_glow": Color("#FF3B3B"),
		"accent_surface": Color("#3A0008"),
		"accent_surface_hover": Color("#4F000C"),
		"on_accent": BONE_HI,
	},
	THEME_TEAR: {
		"name": "Tear",
		"description": "Deep-ocean blue, black and cold steel. Melancholy, sadness and depression.",
		"accent_deep": Color("#00245C"),
		"accent": Color("#0052D9"),
		"accent_bright": Color("#0066E6"),
		"accent_pressed": Color("#002E73"),
		"accent_glow": Color("#5AA9FF"),
		"accent_surface": Color("#001E4D"),
		"accent_surface_hover": Color("#002B6B"),
		"on_accent": BONE_HI,
	},
	THEME_VIRUS: {
		"name": "Virus",
		"description": "Terminal green, black and steel. Systems, the underground and illegality.",
		"accent_deep": Color("#005C1A"),
		"accent": Color("#00E63C"),
		"accent_bright": Color("#00FF41"),
		"accent_pressed": Color("#00A82E"),
		"accent_glow": Color("#66FF66"),
		"accent_surface": Color("#00330F"),
		"accent_surface_hover": Color("#004A17"),
		"on_accent": INK,
	},
}


static func normalize_theme(theme_id: String) -> String:
	var id: String = theme_id.strip_edges().to_lower()
	if id == LEGACY_THEME_HACKER:
		id = THEME_VIRUS
	return id if THEME_DATA.has(id) else THEME_BLOOD


static func theme_name(theme_id: String) -> String:
	return str(THEME_DATA[normalize_theme(theme_id)]["name"])


static func theme_description(theme_id: String) -> String:
	return str(THEME_DATA[normalize_theme(theme_id)]["description"])


static func theme_swatches(theme_id: String) -> Array[Color]:
	var data: Dictionary = THEME_DATA[normalize_theme(theme_id)]
	var colors: Array[Color] = [NIGHT_BG, data["accent"], BONE]
	return colors


static func apply_theme(theme_id: String) -> String:
	var id: String = normalize_theme(theme_id)
	var data: Dictionary = THEME_DATA[id]

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

	# Re-applying the same theme (for example the ADVANCED reset while Blood is
	# already active) must not make the menu think the palette changed.
	if current_theme != id:
		current_theme = id
		revision += 1
	return id


static func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)
