# Drum Hero — Development guide

## Stack

- **Engine:** Godot 4.7 (GDScript)
- **Resolution:** 1280×720, landscape, stretch `canvas_items` + `expand`
- **Rendering:** `gl_compatibility`
- **Audio:** native OGG stems (`AudioStreamOggVorbis.load_from_file()`), with a `FileHelper.read_file()` fallback. Opus decoded via `ffmpeg` to PCM → `AudioStreamWAV` (desktop only).
- **UI graphics:** procedural vector generation (`Image.set_pixel`)

---

## Scene tree (runtime)

```
Main (CanvasLayer)                      ← MenuRoot.gd
├── Background (ColorRect)
├── Root (VBoxContainer)               — with 40px PADDING
│   ├── HeaderBar (PanelContainer)     — AlbumArt + Search + Settings
│   │   └── hbox (HBoxContainer)
│   │       ├── AlbumArt (TextureRect) — 70×70, visible when a song is selected
│   │       ├── SearchInput (LineEdit) — placeholder "Search: "
│   │       ├── SettingsButton
│   │       └── Spacer
│   ├── SongListScroll (ScrollContainer) — scrollable list
│   │   └── SongListContainer (VBoxContainer)
│   │       ├── SongRow_N (PanelContainer)  — ► + artist + --,---pts
│   │       └── ...
│   ├── StatusLabel                    — "STATUS: chart OK - ..." (hidden by default; Show Menu Status in Settings > Experimental)
├── PreviewStatusLabel             — "♫ Artist - Song" (while the preview plays, hidden otherwise) | idle: "♫ Tap a song to preview"
│   └── DiffContainer (HBoxContainer)  — Easy/Medium/Hard/Expert/Expert+
│       └── [5 buttons]                — disabled if unavailable

Settings (CanvasLayer, layer 10)       ← SettingsRoot.gd
├── Background (ColorRect)
├── MarginContainer (margins 40px)
│   └── VBoxContainer (root)
│       ├── HeaderScroll (ScrollContainer, no scroll, 110px)
│       │   └── VBoxContainer
│       │       ├── HeaderBar (HBoxContainer) — "SETTINGS" + Back
│       │       └── TabBar (PanelContainer)   — CONTROLS | HUD | Experimental
│       └── ContentScroll (ScrollContainer, scrollable)
│           └── ContentContainer (VBoxContainer) — active tab content
│
│   CONTROLS tab:
│       ├── CONTROL MODE (Default / Haptic / Custom)
│       ├── LANE ORDER (Custom only)
│       ├── HAPTIC (enable + sensitivity slider)
│       └── LAYOUT (Mirrored / Left Handed)
│
│   HUD tab:
│       ├── VISUAL (Show FPS / Screen Shake)
│       ├── GAMEPLAY (Note Speed / Silence Countdown sliders)
│       └── JUDGEMENT WINDOWS (read-only ±ms)
│
│   Experimental tab:
│       ├── FREE MODE (Open Free Mode)   — shortcut to the empty track
│       ├── CHART FALLBACK (Use PART GUITAR)
│       ├── DEBUG (Show Judgment Areas)
│       └── GAMEPLAY PADDING (Enable + 4 sliders: Left/Right/Top/Bottom 0-200px)

Gameplay (Node2D)                       ← GameplayRoot.gd
├── Highway (Node2D)                    ← Highway.gd
│   ├── bg_sprite (Sprite2D)           ← highway_bg.png
│   ├── Lane_0 (Lane)                  ← Lane.gd (for each active lane)
│   │   ├── bg_rect (ColorRect)        ← lane color (alpha 0.08)
│   │   ├── slash_left (ColorRect)     ← expanding slash effect
│   │   ├── slash_right (ColorRect)    ← expanding slash effect
│   │   └── Note (Note)                ← Note.gd (dynamic spawn)
│   ├── HitLine (Node2D)              ← HitLine.gd
│   │   └── lane_sprite_N (Sprite2D)  ← DrumGraphics (vector, per lane)
│   └── Label_HH (Label)              ← "HH", "CRASH", etc.
│       ... (one label per lane)
├── CountdownLabel (CanvasLayer)        ← CountdownLabel.gd (layer 5)
├── HUD (CanvasLayer)                   ← HUD.gd
│   ├── ScoreLabel
│   ├── ComboLabel
│   ├── MultiplierLabel
│   └── SongTimeline (Control)
├── HitDetection (Node)                 ← HitDetection.gd
├── TouchInput (Node)                   ← TouchInput.gd
└── HapticKick (Node)                   ← HapticKick.gd

FreeMode (Node2D)                       ← FreeModeRoot.gd
├── Highway (Node2D)                    ← Highway.tscn (real instance)
├── HUD (CanvasLayer)
│   ├── TitleLabel / HintLabel
│   ├── PadNameLabel                    ← name of the pad that just sounded
│   ├── HitsLabel                       ← hit counter
│   ├── BackButton                      ← returns to the menu
│   ├── FpsLabel                        ← only if Show FPS
│   └── CalibrationLabel                ← only with sensor kick
└── TouchInput (Node)                   ← no HitDetection
```

### Setlist state when returning from gameplay

The menu is a full scene (`Main.tscn`), so playing a song and coming back rebuilds
it from scratch. To preserve context, `MenuRoot._save_menu_state()` stores the
search, `scroll_vertical` and selected song in `GameManager.menu_search_text` /
`menu_scroll_position` / `menu_selected_song_path` when leaving the scene (and
right before launching a song). When the menu is built, `_ready()` restores the
search before creating the rows, restores the selection by path once the rows
exist, and applies the scroll as soon as the `ScrollContainer` knows the real
content height. Restoring the selection also relaunches the automatic preview,
as if the player had just chosen the song. This is session state: it is not
written to `settings.cfg`.

Leaving the menu (Android back button or `ui_cancel`) depends on **Show Menu
Status**. With the status line visible, the double tap is preserved ("Press
again to exit" → "Closing..." if pressed within `_back_cooldown`). With the line
hidden there is nowhere to show that warning, so the first back opens a
confirmation modal (same scrim and centered VBox as the pause and results
overlays) with CANCEL/EXIT; back on the modal closes it.

Test: `godot --headless --path . res://tools/test_menu_state.tscn`

### Free mode (drum testing)

Entered from **Settings → Experimental → Open Free Mode**. It is its own scene,
not a synthetic song: there is no chart, score, combo or results screen, so it
cannot pollute the records in `user://scores.cfg`.

It intentionally reuses `Highway.tscn` so the lane order, layout, *gameplay
padding* and Android gesture exclusion are exactly those of the game. The only
things it does **not** set up compared with `Gameplay.tscn` are `HitDetection`
and `HapticKick`:

- `TouchInput` receives `null` as `HitDetection`, so its "no note was hit"
  branch is what triggers the pad sample. The sample is not played through any
  other path or it would sound twice.
- The accelerometer kick is handled by connecting
  `InputManager.kick_detected` directly, because `HapticKick` only knows how to
  forward to `HitDetection`, which does not exist here. The connection is only
  made if the kick is enabled (`SettingsManager.haptic_enabled` or `HAPTIC`
  mode) and `is_connected()` is checked before disconnecting in
  `_exit_to_menu()`.

The button emits `SettingsRoot.free_mode_requested`; the scene change is done by
`MenuRoot` (the Settings panel is an overlay of its own, not a scene):

```
SettingsRoot._on_free_mode_pressed() → free_mode_requested
MenuRoot._on_free_mode_requested()   → _stop_preview()
                                     _is_switching_scene = true
                                     change_scene_to_file(FreeMode.tscn)
```

`MenuRoot._is_switching_scene` guards `_on_settings_closed()`: when changing
scene, the panel is dismantled together with the menu and its `tree_exited` fires
during destruction. Without that guard, that close would rescan the song library
while the tree is already half torn down.

**ChartParser is an autoload and survives scene changes.** That is why
`FreeModeRoot._ready()` calls `ChartParser.clear()`: without it, the notes from
the last played song would keep falling down the track and be counted as missed
instantly.

### Test

```
godot --headless --path . res://tools/test_freemode.tscn  # empty track + pads + exit
```

---

## Autoloads (singletons)

Registered in `project.godot` under `[autoload]`. They are initialized before
any scene.

| Autoload | Role | Dependencies |
|---|---|---|
| `GameManager` | State machine (MENU / LOADING / PLAYING / PAUSED / RESULT). Holds `current_song_path`, `mode`, `state`. Emits `hit_registered`, `miss_registered`, `game_state_changed`. | — |
| `AudioManager` | Loads multi-track stems (song, drums, bass, guitar, rhythm, keys, vocals). Skips `song` if individual stems exist to avoid duplication. Decodes `.opus` to stereo via `ffmpeg`. Provides `duck_drums()` to mute drums temporarily. | — |
| `InputManager` | Touch input routing and haptic sensor pipeline (accelerometer for kick). Two-phase detection: lift (peak on the screen's Z axis) → zero crossing → KICK. States: `KickState` (IDLE / KICK_DOWN / COOLDOWN). | — |
| `SettingsManager` | Settings persistence (`user://settings.cfg`). Judgements, sensitivity, haptic mode, lane order, guitar fallback. | — |
| `SongLoader` | Scans a list of configurable roots (see *External song libraries*), parses `song.ini`, exposes the song list with metadata. Detects the chart source (PART DRUMS vs PART GUITAR). Each song entry includes `preview_path` (str), `preview_start_time` (int, in milliseconds, -1 if undefined), `song_length` (float). `get_stem_path()` and `_scan_song()` use `FileHelper.file_exists() OR ResourceLoader.exists()` to find files both in `user://` (FileAccess) and in packaged `res://` (ResourceLoader). `album_path` looks for `album.jpg` first and falls back to `album.png` if missing. Scanning is interruptible: `begin_scan()` / `scan_step()` / `pump_scan()` advance it in batches, `request_scan()` queues it and `cancel_scan()` stops it without losing what was found (see *Walk*). Emits `scan_progress` and `scan_finished`, and exposes `unreadable_roots`, `truncated_roots` and `cancelled_roots` for diagnostics. | — |
| `ChartParser` | Loads `notes.mid` (via `MidiParser.gd`) or `notes.chart` (via `DotChartParser.gd`) depending on the file extension. Produces the same `NoteEvent` array for both formats. Supports fallback to PART GUITAR / `[ExpertSingle]` when there are no drums. `get_notes_in_range()` uses binary search (`find_next_note_index`) to jump to the requested range. `clear()` empties the chart; free mode calls it, since it builds the Highway without notes (see *Free mode*). | `ChartData.gd` (data classes) |
| `TimingEngine` | Master clock. With audio it uses `AudioManager.get_position()`, otherwise frame delta. Emits `time_updated`, `song_ended` (only once, see *End of song*). `stop()` freezes the clock wherever it is; `start()` re-arms it. | `AudioManager` |
| `ScoreManager` | Score, combo, multiplier, streaks. API: `register_hit(diff)`, `register_miss()`, `reset()`. | — |
| `EffectManager` | Pool of visual effects (`ParticleBurst`, `Shockwave`, `JudgementPopup`). Generates SFX (programmatic beeps). | — |
| `DrumGraphics` | Generates vector textures for notes and per-lane hit lines (double cymbal, cymbal, drumstick, pedal). 128×128 textures pre-generated in `_ready()`. | — |
| `AndroidBridge` | GDScript→native Android bridge. Manages the `GestureExclusion` plugin (exclude back-gesture edges) and `AllFilesAccess` (grant *All files access* and probe path readability). Only active on Android; no-op on desktop. | — |
| `HighScoreStore` | Best scores per song+difficulty (`user://scores.cfg`, see *Best scores*). | — |

### Dependency flow

```
InputManager ──→ TouchInput ──→ HitDetection ──→ Lane.try_hit()
                                                      │
                            ChartParser ←─────────────┤ (note_data)
                            TimingEngine ←────────────┤ (current_time)
                                                      │
                            ScoreManager ←────────────┤ (register_hit/miss)
                            EffectManager ←───────────┤ (SFX + visual FX)
                            AudioManager ←────────────┤ (duck_drums on miss)
```

---

## Audio system

### Stem pipeline

```
AudioManager.load_stems(song_path)
  │
  ├─ _find_stem_file() looks for: {stem}.ogg → {stem}.opus → {stem}.wav → {stem}.mp3
  │                            → drums_1.ogg, drums_2.ogg, etc. (multi-file)
  │   (FileHelper.file_exists() OR ResourceLoader.exists() — covers res:// + user://)
  │
  └─ _load_audio_stream()
       │
       ├─ .opus → _decode_opus_via_ffmpeg() → ffmpeg → AudioStreamWAV (PCM ~46MB)
       │   └─ Android: fallback to .ogg → AudioStreamOggVorbis
       │
       ├─ .ogg → AudioStreamOggVorbis.load_from_file() (~5MB compressed)
       │   (works on desktop + Android)
       │   └─ If it fails → ResourceLoader.exists()? → load()
       │       └─ fallback → FileHelper.read_file() → AudioStreamOggVorbis.new()
       │
       └─ .wav/.mp3 → ResourceLoader.exists()? → load()
           └─ fallback → FileHelper.read_file() → AudioStreamWAV
```

### Song previews in the menu

When a song is selected in the main menu list (`MenuRoot.gd`), a preview of the
song plays automatically. The system uses `preview.opus` if it exists in the song
folder, with a fallback to `song.ogg`.

**Playback flow (step-by-step):**

```
_user taps SongRow
  │
  ├─ _on_song_row_input()
  │   ├─ InputEventScreenTouch.pressed → records position
  │   ├─ InputEventScreenTouch.release → if there was no drag → _select_song()
  │   ├─ InputEventScreenDrag → if distance > 8px → _row_dragging = true (cancels)
  │   └─ InputEventMouseButton / InputEventMouseMotion → same logic (desktop)
  │
  └─ _select_song(original_index)
      ├─ If the same song is already selected → return (without reloading)
      ├─ _selected_song_index = original_index
      ├─ _update_selection_ui()          ← puts "► " on the selected row
      ├─ _update_status_for_song()       ← "STATUS: chart OK - audio OK"
      ├─ _update_difficulty_visibility() ← enables/disables buttons
      ├─ _load_album_art(original_index) ← loads cover art into HeaderBar
      └─ _start_preview_animation(original_index)
```

**Starting the animation (`_start_preview_animation()`):**

```
_start_preview_animation()
  ├─ _stop_preview()                    ← stops any previous preview + thread
  ├─ _resolve_preview_path(song)
  │   ├─ If the song has "preview_path" → use it
  │   └─ Otherwise → SongLoader.get_stem_path(song.path, "song")
  │       (results in song.opus / song.ogg / song.wav / song.mp3)
  ├─ If preview_path is empty → return (no preview)
  ├─ _preview_needs_load = true         ← flag: _process() must load
  ├─ _preview_loaded_stream = null
  ├─ _preview_animating = true
  ├─ _preview_anim_frame = 0            ← "."
  ├─ _preview_anim_delay = 1.5          ← 1.5s before actual play
  └─ PreviewStatusLabel.text = "."
```

**Frame-by-frame processing (`_process()`):**

```
_process(delta)
  │
  ├─ IF _preview_animating:
  │   ├─ Dots animation: timer += delta, advances frame every 0.3s
  │   │
  │   ├─ If _preview_needs_load:
  │   │   ├─ Look in _preview_cache (LRU) → on hit, stream is ready
  │   │   └─ On miss:
  │   │       ├─ Android: AudioManager._load_audio_stream() synchronously
  │   │       │   (same pattern as GameplayRoot, which already works)
  │   │       └─ Desktop: Thread.new().start(_preview_load_func)
  │   │           (asynchronous load, does NOT block the main thread)
  │   │
  │   ├─ If _preview_load_done (thread finished, desktop only):
  │   │   ├─ _preview_loaded_stream = _preview_load_result
  │   │   ├─ _preview_thread.wait_to_finish()
  │   │   ├─ _cache_stream(path, stream)  ← adds to LRU cache
  │   │   └─ Adaptive delay: if delay > 0.3s → reduce to 0.3s
  │   │
  │   └─ _preview_anim_delay -= delta
  │       ├─ delay > 0.0: wait (dots keep animating)
  │       └─ delay <= 0.0:
  │           ├─ stream != null → _play_preview()
  │           └─ stream == null:
  │               ├─ timeout > 0 → timeout -= delta, delay = 0.0
  │               └─ timeout <= 0 → "Preview unavailable"
  │
  └─ IF _preview_player.playing:
      ├─ _preview_elapsed += delta
      └─ If elapsed >= 30s → _stop_preview() + "Preview ended"
```

**Playback (`_play_preview()`):**

```
_play_preview()
  ├─ If player is playing → _preview_player.stop()
  ├─ _preview_player.stream = stream
  ├─ _preview_player.volume_db = linear_to_db(SettingsManager.preview_volume)
  ├─ _preview_player.play()                 ← on bus "Music"
  ├─ _preview_elapsed = 0.0                 ← reset duration timer
  ├─ If there is no preview_path (using song.ogg):
  │   ├─ preview_start_time > 0 → seek to preview_start_time / 1000 (ms→s)
  │   ├─ preview_start_time <= 0 or null → seek to second 30
  │   └─ Starts asynchronous stem loading (drums, bass, guitar, keys, rhythm, vocals)
  │       ├─ Desktop: in a separate Thread
  │       ├─ Android: synchronously
  │       └─ On finish: creates an AudioStreamPlayer for each stem
  │           with volume_db = linear_to_db(preview_volume * 0.5),
  │           play() and seek() synchronized to the current playback_position
  └─ PreviewStatusLabel.text = "♫  Queen - Bohemian Rhapsody"
```

**Stopping:**

```
_stop_preview()                              ← called when:
  ├─ _preview_animating = false               ├─ switching to another song
  ├─ _preview_pending_index = -1              ├─ opening settings
  ├─ _preview_needs_load = false              ├─ changing the search text
  ├─ _preview_loaded_stream = null            ├─ pressing a difficulty (starting the game)
  ├─ Thread.wait_to_finish() if active        ├─ _exit_tree() (closing the app)
  ├─ _preview_player.stop()                   ├─ preview > 30s (duration limit)
  ├─ _preview_player.stream = null            └─ explicit _stop_preview()
  ├─ _preview_elapsed = 0.0
  └─ PreviewStatusLabel.text = ""
```

**Preview node tree:**

```
MenuRoot (CanvasLayer)
  ├── PreviewStatusLabel (Label)    ← ". → .. → ... → ♫  Artist - Song"
  ├── PreviewPlayer (AudioStreamPlayer)  ← bus = "Music"
  ├── StemPlayer_n (AudioStreamPlayer)   ← bus = "Music" (0..N, for each loaded stem)
  ├── Thread (_preview_thread)      ← async load of the main preview
  └── Thread (_preview_stem_thread) ← async stem load (fallback only)
```

**Technical considerations:**

- **Android `res://` fix:** in exported Android builds, files under `res://Songs/` are packed into the PCK. `FileHelper.file_exists()` (based on `FileAccess.open()`) cannot read them directly. `SongLoader.get_stem_path()` and `_scan_song()` use `FileHelper.file_exists() OR ResourceLoader.exists()` to find files both in external storage (`FileAccess`) and in packaged `res://` (`ResourceLoader`). `AudioManager._find_stem_file()` already used both; the fix unifies the pattern in `SongLoader` so previews and metadata detection work the same as gameplay.
- **Lazy loading:** songs are not preloaded at startup. Each preview is loaded on demand when selected, avoiding OOM on Android with 30+ songs.
- **Per-platform loading:** on desktop, `_load_audio_stream()` runs in a separate `Thread` via `_preview_load_func()` (does not block the main thread). On Android, it runs synchronously in `_process()` (same pattern as `GameplayRoot._start_loading()`, which already works on Android).
- **LRU cache:** loaded streams are stored in `_preview_cache` (Dictionary path→AudioStream) with a maximum of `PREVIEW_CACHE_MAX = 5` entries. When scrolling between previously heard songs, loading is instant (~25MB with native .ogg).
- **Adaptive delay:** if the stream loads before the 1.5s delay expires, it is reduced to `PREVIEW_ANIM_INTERVAL` (0.3s = one dots frame). With native .ogg (~10ms load), the preview starts in ~0.3s instead of 1.5s.
- **Native `.ogg`:** `AudioStreamOggVorbis.load_from_file()` is used on all platforms (desktop + Android). If it fails, the fallback uses `FileHelper.read_file()` → `AudioStreamOggVorbis.new()`. On desktop, `load_from_file()` loads ~5MB compressed instead of ~46MB PCM (ffmpeg).
- **Reference cleanup:** `_stop_preview()` sets `_preview_player.stream = null` to release the AudioStream immediately instead of waiting for `_play_preview()` to replace it.
- **Limited duration:** the preview stops automatically after `PREVIEW_MAX_DURATION = 30s`. This avoids playing the full song as a preview.
- **Seek by preview_start_time:** when `song.ogg` is used as fallback (no `preview.ogg`), `_preview_player.seek()` is applied to the `preview_start_time` value from `song.ini` divided by 1000 (it is in milliseconds, seek uses seconds). If the value is -1, 0 or null, it seeks to second 30. With `preview.ogg` it plays from the beginning (0s).
- **Stems in fallback:** when using `song.ogg` as fallback, individual stems (`drums.ogg`, `guitar.ogg`, `bass.ogg`, `keys.ogg`, `rhythm.ogg`, `vocals.ogg`) are also loaded if they exist. An `AudioStreamPlayer` is created for each stem found on the `"Music"` bus with volume at 0.5× `preview_volume`. Loading is asynchronous (thread on desktop, synchronous on Android). The stems are synchronized with `_preview_player.get_playback_position()` to keep them temporally coherent.
- **Android .opus skip:** on Android, `_resolve_preview_path()` ignores `preview.opus` files (ffmpeg unavailable) and falls back to `song.ogg` via `get_stem_path()`. On desktop, `.opus` is decoded normally. `SongLoader.get_stem_path()` uses `FileHelper.file_exists() OR ResourceLoader.exists()` to find files both in external storage and in packaged `res://`.
- **Load timeout:** if the stream does not load within `PREVIEW_LOAD_TIMEOUT = 5s`, the animation stops and shows "Preview unavailable". This avoids an infinite dots loop on error.
- **Touch anti-spam:** `_select_song()` has an early return if the song is already selected (`original_index == _selected_song_index`). `_on_song_row_input()` uses `InputEventScreenTouch` to distinguish tap from drag (8px threshold).
- **Dots animation:** 3 frames (`.`, `..`, `...`) alternating every 0.3s. Minimum delay of 0.3s (one frame) for visual feedback, maximum 1.5s.
- **Fallback:** on desktop, `preview.opus` is used if it exists (decoded via ffmpeg). On Android, `preview.opus` is ignored and `song.ogg` is used. If the stream does not load, the 5s timeout shows "Preview unavailable".
- **Volume:** controlled by `SettingsManager.preview_volume` (default 0.8), applied as `linear_to_db()`.
- **Cleanup:** `_exit_tree()` calls `_stop_preview()`, which waits for the thread (if it exists) and releases all resources when the app closes.

On each `miss`, `Lane.gd` calls `AudioManager.duck_drums(-12 dB, 0.5 s)`. It only affects the `"drums"` stem. If there is no drum stem (songs without a separate track), it does nothing.

### SFX

`EffectManager` generates two tones programmatically:

- **Hit:** 880 Hz, 80 ms, descending linear envelope, −6 dB
- **Miss:** 220 Hz, 150 ms, descending linear envelope, −9 dB

They are created as `AudioStreamWAV` with PCM data calculated in `_generate_beep()`.

---

## Vector graphics (DrumGraphics)

All note and hit-line textures are generated in code instead of using bitmaps.

### Texture size

128×128 pixels, `RGBA8` format, transparent background.

### Shapes per lane

| Lane | Part | Note shape | Hit-line shape |
|---|---|---|---|
| 0 | HH Closed & Open | **double cymbal** — two overlapping circles with a stem | two semicircles over a bar |
| 1 | Crash | **cymbal** — circle with a stand | semicircle over a bar |
| 2 | Snare | **drumstick** — vertical stick with a tip | horizontal stick |
| 3 | Kick | **pedal** — curved rectangle with hinges | small pedal over a bar |
| 4 | Tom 1 | **drumstick** | horizontal stick |
| 5 | Tom 2 | **drumstick** | horizontal stick |
| 6 | Tom 3 | **drumstick** | horizontal stick |
| 7 | Ride | **cymbal** | semicircle over a bar |

### Drawing primitives

`DrumGraphics` implements `_fill_circle()`, `_fill_rect()`, `_fill_round_rect()`
directly on an `Image`, operating pixel by pixel. It does not use
`CanvasItem._draw()` or external textures.

---

## Screen layout

Based on [`ui-reference.md`](ui-reference.md) — ASCII GAMEPLAY REFERENCE.

```
y=0%    +---------------------------------------+
        |             SONG TIMELINE             |
y=2.5%  +----+----+----+----+----+----+----+----+
        | multiplier   |    |    |    |   score |  ^
        |    |    |    |  combo  |    |    |    |  |
        |    |    |    | accuracy|    |    |    |  highway (62.5%)
        |    (notes scrolling downward)          |  |
        |    |    |    |    |    |    |    |    |  v 
y=65%   +----+----+----+----+----+----+----+----+
        |    |    |    |    |    |    |    |    |  ← hit line (per-lane)
y=72%   +----+----+----+----+----+----+----+----+  
        | HH | CR | SN | KI | T1 | T2 | T3 | RI |  ← lane labels
y=100%  +----+----+----+----+----+----+----+----+
```

- **Timeline:** 0–2.5 % (horizontal progress bar)
- **Highway:** 2.5–65 % (note canvas)
- **Hit line:** 65-72 % (one section per lane with the instrument icon)
- **Labels:** 72-100 % (short instrument name per lane + touch zone)
- **HUD:** overlaid (score, combo, multiplier)

### Gameplay padding (experimental)

When `gameplay_padding_enabled` is active, the Highway is positioned at
`(pad_left, pad_top)` and `screen_w`/`screen_h` are reduced to the effective
dimensions (`viewport - pad_left - pad_right`, `viewport - pad_top -
pad_bottom`). This automatically shifts lanes, notes, hit line, beat lines and
touch zones. The HUD (CanvasLayer) is adjusted manually by adding the individual
paddings to each label's offsets. Each side is configured independently with a
slider (0-100dp, default left/right=75, top/bottom=0). Values are stored in dp
(density-independent pixels) and converted to Godot logical pixels when applied.
Only available on Android — on desktop the UI is shown disabled.

### Android gesture exclusion (native plugin)

On Android, gesture navigation intercepts touches at the screen edges before
delivering them to the app, causing delay on HH (lane 0) and RIDE (lane 7) taps.
To mitigate this, the project includes a minimal Android plugin that calls
`View.setSystemGestureExclusionRects()` to exclude the side edges from the back
gesture.

**Flow:**
1. `Highway._build_lanes()` → calls `AndroidBridge.set_lane_exclusion()` after building touch zones
2. `AndroidBridge` gets the `GestureExclusion` singleton via `Engine.get_singleton()`
3. The Java plugin calculates the exclusion rectangles (max 200px per edge, max 4 rects)
4. When leaving gameplay (`_exit_to_menu`, `stop_gameplay`) → `AndroidBridge.clear_exclusion()`
   - **Note:** `_restart_song()` does NOT call `clear_exclusion()` because it does not rebuild lanes — positions do not change, the rects remain valid

**Padding independence:** gesture exclusion works whenever the plugin is compiled
and enabled, regardless of `gameplay_padding_enabled`. The rects cover the edges
of the outer lanes (HH and RIDE) to avoid back-gesture interference. When padding
is disabled, `pad_x` and `pad_y` are 0, but the rects still cover the correct
zones.

**Android API limitations:**
- `setSystemGestureExclusionRects()` only affects the **back gesture** (side swipe), NOT home/recents (bottom swipe)
- Maximum 200px from each edge, maximum 4 rectangles
- The system may ignore the rects if it detects abuse
- On desktop/iOS, `AndroidBridge` is a no-op

**Auto-enable on Android:** on first launch (no settings file),
`gameplay_padding_enabled` is automatically set to `true` on Android to mitigate
the edge problem.

**Build prerequisites:**
1. Install the Android Build Template: `Project → Install Android Build Template...`
2. Enable Gradle build: `gradle_build/use_gradle_build=true` in export settings
3. Java 17 JDK installed (Gradle 8.11.1 + AGP 8.6.1 do not support Java <11 or >22)
4. Build the plugin `.aar` from `GestureExclusionPlugin/` with Gradle:
   ```
   JAVA_HOME=/usr/lib/jvm/jdk-17.0.12-oracle-x64 ./gradlew :plugin:assembleDebug
   ```
5. Copy `plugin/build/outputs/aar/plugin-debug.aar` → `addons/GestureExclusion/bin/debug/GestureExclusion.aar`
6. Enable the plugin in `Project Settings → Plugins`

**Plugin structure (two scripts):**
- `plugin.cfg` → points to `plugin_main.gd` (extends `EditorPlugin`)
- `plugin_main.gd` → wrapper that registers the export plugin via `add_export_plugin()`
- `export_plugin.gd` → (extends `EditorExportPlugin`) handles inclusion of the `.aar` in Android exports

**Note on paths:** `_get_android_libraries()` returns paths relative to
`res://addons/`, so they must include the plugin directory prefix
(`GestureExclusion/bin/debug/...`).

**Plugins must be registered in `project.godot`:** step 6 ("Enable plugin in
Project Settings → Plugins") is not optional — without writing the `plugin.cfg`
into `[editor_plugins] enabled=PackedStringArray(...)`, the `EditorExportPlugin`
is never instantiated, `_get_android_libraries()` is not called, and the `.aar`
does not enter the APK. The symptom is silent: `Engine.has_singleton("GestureExclusion")`
returns `false` and the affected function stays a no-op without any error.

### Android All files access (native plugin)

`MANAGE_EXTERNAL_STORAGE` is declared in `export_presets.cfg` but **is not granted
by itself**. It is not a *dangerous permission* from Android's runtime model (it
is not granted via `requestPermissions()` or `OS.request_permissions()`), but a
special AppOps permission that the user enables in system Settings. Also, with
`gradle_build/use_gradle_build=false` the prebuilt template asks for nothing on
its own.

The `AllFilesAccess` plugin exposes the following in GDScript:
- `has_all_files_access()` → `Environment.isExternalStorageManager()` (API 30+; on `< 30` returns `true`, where `READ/WRITE_EXTERNAL_STORAGE` is enough)
- `requestAllFilesAccess()` → launches the `Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION` intent targeting its own package, with fallback to `ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION`
- `isPathReadable(path)` / `isDirectory(path)` → `File.canRead()` / `File.isDirectory()`, more reliable than `DirAccess` under scoped storage

Once the permission is granted, `DirAccess` and `FileAccess` work on absolute
paths under `/storage/emulated/0/...` (All files access ignores scoped storage),
which is what allows scanning arbitrary song libraries without copying them.
`FileHelper`'s `content://` fallback remains as a safety net for when the
permission is not granted.

**Build prerequisites** (identical to `GestureExclusion`): Android Build Template
installed, JDK 17, and build from `AllFilesAccessPlugin/`:
```
./gradlew :plugin:assembleDebug
./gradlew :plugin:assembleRelease
```
and copy the `.aar` files to
`addons/AllFilesAccess/bin/{debug,release}/AllFilesAccess.aar`.

**Toolchain note:** the build uses `compileSdk = 34` with
`buildToolsVersion = "37.0.0"` (the installed SDK does not have build-tools
34.0.0) and AGP 8.5.2.

### Note spawning

`Highway._process()` keeps a `_next_note_index` cursor that advances sequentially
over `ChartParser.note_data`. Each note is enqueued **once** when it enters the
spawn window (`current_time + 2.0s`), avoiding scanning the entire array every
frame.

### Note position calculation

```
lane_w = screen_width / lane_count
x = lane_w * lane_index + lane_w / 2
scroll_distance = (highway_bottom_y - highway_top_y) * note_speed  (0.625 × note_speed by default)
y_offset = (note_time - current_time) * scroll_distance / 2.0
y = hit_line_y - y_offset
```

Judgement is calculated using the note's **time** (not its visual position). The
note's `ColorRect` is `lane_w × 0.95` wide by `lane_w × 0.25` high, centered on
the calculated position. Judgement uses `note_data.time - current_time` (the
temporal delta from the note center), not visual overlap with the judgement
bands.

---

## Countdown between notes

The game shows a countdown when there is a prolonged silence between notes. It
covers two cases:

- **Song intro:** when the first note is far from the start.
- **Internal silences:** when there is a long gap between consecutive notes.

Both cases use the same code in `GameplayRoot.gd:_on_countdown_update()`.

### Behavior

Every frame, `GameplayRoot._on_countdown_update()` (connected to
`TimingEngine.time_updated`):

1. Finds the next playable note via `ChartParser.find_next_note_index(time_sec)` (binary search, O(log n)).
2. Calculates `remaining = next_note.time - current_time`.
3. If `remaining > countdown_threshold (5s)` and the note is not yet visible (it is more than `NOTE_TRAVEL_TIME = 2.0s` away), shows `"X.X s"`.
4. As soon as the note enters the spawn window (≤ 2.0s), the countdown disappears automatically.

### Visual

`CountdownLabel` (CanvasLayer, layer 5) is a centered overlay with:
- **Title:** "Next notes in" (24px font, semi-transparent)
- **Timer:** `"%.1f s"` (64px font, white with shadow)

It is instantiated dynamically from `GameplayRoot` and destroyed when hidden. It
has no pooling because only one instance exists at a time.

### Files involved

| File | Role |
|---|---|
| `scene/UI/CountdownLabel.tscn` | Overlay scene |
| `script/ui/CountdownLabel.gd` | `CountdownLabel` class (CanvasLayer) |
| `script/gameplay/GameplayRoot.gd` | Activation/update logic via `time_updated` |
| `script/autoload/ChartParser.gd` | `find_next_note_index()` — binary search |
| `script/autoload/SettingsManager.gd` | `countdown_threshold` — persistence |

### Configurable threshold

`SettingsManager.countdown_threshold = 5.0` — persisted in `user://settings.cfg`
as `gameplay/countdown_threshold`.

### NOTE_TRAVEL_TIME

Constant `NOTE_TRAVEL_TIME := 2.0` in `GameplayRoot.gd`. It matches the note spawn
window in `Lane._spawn_pending()`. If the highway speed is changed in the future,
updating this constant is enough.

### Architecture

```
GameplayRoot
  └── CountdownLabel (CanvasLayer, layer 5)
        ├── _title_label: "Next notes in"
        └── _time_label: "%.1f s"

TimingEngine.time_updated
  → GameplayRoot._on_countdown_update()
    → ChartParser.find_next_note_index()  (binary search)
    → CountdownLabel.update_display()
    → CountdownLabel.hide()
```

---

## End of song

### What marks the end

The song ends with the **audio**, not with the notes.
`GameplayRoot._start_loading()` calls
`TimingEngine.start(ChartParser.get_duration_seconds(), delay)`, and that duration
is `max(last note, actual audio duration)`: notes usually end before the music,
and the time bar must reach 100 % while the audio is still playing.

`TimingEngine._process()` declares the end as soon as either of these two
conditions is met:

1. `audio_position >= chart_duration` (normal case, and also the no-audio case, where the clock advances with delta).
2. `AudioManager.is_stream_finished()`: the base stream reached its end even if `_is_playing` is still `true`.

The second covers `song.ini` with a wrong duration: without it, the clock would
get stuck at the last sample's position and `song_ended` would never arrive.

Before emitting, `audio_position` is clamped to `chart_duration`, so the last
`time_updated` carries the exact end-of-song value and `SongTimeline` stays at
100 %.

#### How the end of the stream is detected (and why the position is not read)

`AudioManager.is_stream_finished()` returns a latch set by the **`finished`
signal** of the base stem's player (`_on_stem_finished`), not by querying the
player. It is the only reliable way, because on the exact frame the stream ends,
both available queries lie:

| Query | At the natural end of the stream | Reason |
|---|---|---|
| `player.get_playback_position()` | returns **0.0** | Godot resets the position when the stream ends |
| `player.playing` | `false` | …but it is also `false` with `stream_paused`, so a pause `stop()` would look like the end of the song |

The position at 0 is what broke the flow: a guard such as
`raw_position > 0.0 and is_stream_finished()` was never satisfied on the final
frame (0 is not > 0), so the clock jumped to ~0, `audio_position >=
chart_duration` was never true again and **the song hung without ever reaching
`song_ended`**. The `finished` signal is only emitted when the stream ends
naturally: neither `stop()` nor pause emit it, so there are no false positives
when pausing, restarting or changing songs. The latch is re-armed in
`AudioManager.play()`.

So that the clock and the ending always refer to the same stream,
`get_position()`, `get_length()` and `is_stream_finished()` resolve the base stem
with `_base_stem_name()`.

### Frozen clock

`TimingEngine` has two guards in addition to `_paused`:

| Guard | What it means | Set / cleared by |
|---|---|---|
| `_running` | The clock runs between `start()` and `stop()`. It starts as `true` so time also flows in the menu. | `start()` / `stop()` |
| `_finished` | The end was already announced; `song_ended` is not emitted again. | `_finish()` / `start()` |

Without `_running`, `stop()` left the clock in its `audio_position += delta`
branch (there is no longer a pause or audio playing) and the time bar filled up
again from zero below the results screen.

### Sequence to the results screen

```
TimingEngine._process()   audio_position >= chart_duration
  → _finish()                                  (only once)
    → song_ended
      → GameplayRoot._on_song_ended()
        → await RESULT_TAIL_DELAY (0.5 s)      (state still PLAYING)
          → GameplayRoot._show_result()
            → Highway.flush_unjudged_notes()   (unjudged notes = misses)
            → GameManager.set_state(RESULT)
              → GameplayRoot._on_state_changed()
                → TimingEngine.stop()           (clock and audio frozen)
            → ResultOverlay (CanvasLayer, layer 15)
```

During the 1.5 s margin the state is still `PLAYING`: the player can still hit
notes that fell within the hit window, and the clock does not advance (it is
already in `_finished`).

### Unjudged notes

`Highway.flush_unjudged_notes()` → `Lane.flush_as_miss()` counts the notes still
on screen as missed. Without audio, `chart_duration` matches the last note, so
those notes never pass through the miss window in `Lane._update_active()` and the
final count would fall short. They do not show a judgement popup: there was no
hit to judge.

It is not the same as `Highway.restart()`, which discards notes without scoring
(replay).

### Results screen

`ResultOverlay` (CanvasLayer, layer 15) is built entirely in code and prints
`ScoreManager` (score, accuracy, max combo, hits/misses) plus the song title and
difficulty. It emits `retry_requested` and `exit_requested`; the callback is
`GameplayRoot._restart_song()` / `_exit_to_menu()`. The pause overlay lives on
layer 10 and the loading overlay on layer 20.

`AndroidBridge.clear_exclusion()` is **not** called when the song ends: we are
still inside gameplay and the touch zones have not changed. It is only cleared
when leaving (`_exit_to_menu`, `stop_gameplay`).

The back button (Android and `ui_cancel`) goes through
`GameplayRoot._handle_back()`: with the panel visible it exits to the menu, if the
song already ended but the panel has not appeared yet it does nothing, and in any
other case it pauses.

### Files involved

| File | Role |
|---|---|
| `script/autoload/TimingEngine.gd` | `_running` / `_finished` guards, clamp and `_finish()` |
| `script/autoload/AudioManager.gd` | `is_stream_finished()` — latch for the base stem's `finished` signal, and `_base_stem_name()` |
| `script/gameplay/GameplayRoot.gd` | `song_ended` → tail → `RESULT` → overlay; `RESULT_TAIL_DELAY` |
| `script/ui/ResultOverlay.gd` | Results panel |
| `script/gameplay/Highway.gd` / `Lane.gd` | `flush_unjudged_notes()` / `flush_as_miss()` |
| `script/autoload/GameManager.gd` | `current_song_title` / `current_song_artist` for the panel |

### Test

```
godot --headless --path . res://tools/test_song_end.tscn   # clock + overlay + real audio
godot --headless --path . res://tools/test_song_end_e2e.tscn # real Gameplay.tscn scene
```

`test_song_end` covers: `song_ended` is emitted only once, the clock stops at
`chart_duration`, the bar does not empty after `stop()`, `start()` re-arms the
clock, the panel dumps `ScoreManager` stats and — with a song's real stems — that
the end of the stream is detected even when the position returns to 0, that pause
does not trigger it, and that a second pass ends again.

`test_song_end_e2e` sets up `scene/Gameplay.tscn` with a real song, lets it reach
the end (seeking the player near the end) and checks the full chain: `PLAYING` →
`song_ended` → 1.5 s tail → `RESULT` → `ResultOverlay` on screen with the run's
data, and that **REPLAY** plays again and dismantles the panel.

---

## Input system

### Touch / mouse

`TouchInput._input()` handles `InputEventScreenTouch` and
`InputEventMouseButton`. It converts the X coordinate to a lane index like this:

1. **Local position**: `_get_highway_local_pos()` transforms screen coordinates into the highway's local space (Node2D).
2. **Visual column**: `_touch_to_lane()` divides `pos.x` by the lane width, where `lane_w = highway.screen_w / lane_count`.
   This uses the actual viewport width (`get_viewport_rect().size.x`) propagated by `Highway.screen_w`, not the static `display/window/size/viewport_width` value.
3. **Logical resolution**: the visual column index is mapped to the real logical `lane_index` through `highway.lane_nodes[visual_idx].lane_index`, guaranteeing correct behavior with alternative lane orders (Haptic and Custom mode).

**Android protection:** on touch devices
(`DisplayServer.is_touchscreen_available()`), the `InputEventMouseButton` block is
skipped to prevent the mouse event emulated by Android from processing the same
touch twice. Without this guard, the second event (emulated mouse) finds the note
already removed by the first event (touch), causing `try_hit_lane()` to return
`false` and to play `DrumSfxManager.play_for_lane()` incorrectly.

**Performance optimization:** calls to `EffectManager.trigger_particle_burst()`
and `EffectManager.show_judgement()` inside `Lane.try_hit()` are executed via
`call_deferred()`. This moves visual effect node creation out of the `_input()`
phase and to the end of the frame, avoiding frame hitches on mobile devices when
the player touches the screen. Critical logic (hit detection, scoring, audio)
stays synchronous.

**Cached touch zones:** touch zones (`TouchZone_*`) are cached in `_touch_zones`
(Array[ColorRect]) during `setup()` via `_cache_touch_zones()`. Each zone stores
its `lane_idx` in metadata (`set_meta("lane_idx", ...)`) to avoid name lookup and
string parsing in `_update_touch_zones()`. The cached array is only updated if
the lanes are rebuilt.

**`lane_pressed` signal:** `TouchInput` emits `lane_pressed(lane_index,
position)` on all three input paths (keyboard, touch and mouse), right before
calling `HitDetection`. This lets whoever builds the scene receive the hit even
without hit detection, which is the case for free mode (see *Free mode*).

**Optional hit detection:** calls to `HitDetection` check that `_hit_detection`
is not `null`, so `TouchInput` can be set up without a judgement node. With
`null` only the pad sample plays.

### InputManager

`InputManager.handle_touch_event()` receives the already-resolved `lane_index`
from `TouchInput` and avoids recalculating it.

### Keyboard (desktop)

Keys **1–8** on the numeric row map to lanes **0–7**. Implemented in
`TouchInput._input()` as `InputEventKey`, it calls
`HitDetection.try_hit_lane()` exactly like touch input.

### Optimized hit detection

`Lane.try_hit()` includes an optimization to reduce the search loop: it only
considers notes whose time is within the range `[current_time - miss_ms,
current_time + miss_ms]`, skipping notes that are too early or too late and could
not be hit anyway. This avoids walking the entire active-note array when notes
pile up on the highway.

### Haptic kick (accelerometer)

`HapticKick.gd` connects to `InputManager.kick_detected`. The detection pipeline
is in `InputManager._process()`:

1. **Sensor**: `Input.get_accelerometer()` on the device's +Z axis (screen normal, `Vector3.BACK`). Falls back to `Input.get_gravity()` if the accelerometer returns zeros.
2. **Gravity removal**: `linear_accel = filtered_accel - gravity_estimate`. Gravity comes from `Input.get_gravity()` or from a low-pass filter over the accelerometer.
3. **Smoothing**: exponential filter `lerp_factor = 1.0 - pow(1.0 - strength, delta * 60.0)`, default `strength = 0.4`.
4. **Two-phase detection**:
   - **Lift**: when `toward > eff_activation`, `_lift_detected` is set (with `eff_activation = haptic_activation_threshold / sensitivity`).
   - **Abort**: if `toward < eff_release` before the zero crossing, `_lift_detected` is reset.
   - **KICK**: when `toward <= 0.0` and `_lift_detected` is true, `kick_detected` fires. This way the kick occurs at the start of the return.
5. **Calibration**: when the song starts, it captures the current orientation (~0.5 s if there is a gravity sensor, ~1.5 s if not). The detection axis is always `Vector3.BACK` (it does not depend on orientation).

---

## External song libraries

In addition to the songs packaged in `res://Songs/`, the player can point the game
at their own libraries (Clone Hero, YARG, Rock Band, Phase Shift) **without
copying the files**: they are referenced in place.

### Scan roots

`SongLoader.get_scan_roots()` builds the root list in this order:
1. `res://Songs` (always)
2. `get_user_song_dir()` — the app's own folder (created if it does not exist)
3. `SYSTEM_DIR_DOWNLOADS` and/or `SYSTEM_DIR_DOCUMENTS`, depending on `library_preset_downloads` / `library_preset_documents`
4. `SettingsManager.library_roots` — paths typed by the user

All go through `_append_root()`, which normalizes them with `simplify_path()` and
discards duplicates. Relative paths are expanded with
`ProjectSettings.globalize_path()`.

On first run on Android the presets enable themselves (along with
`gameplay_padding_enabled`); on desktop they start disabled so `~/Downloads` is
not scanned without the user asking. Configuration is persisted in the
`[library]` section of `user://settings.cfg`: `roots`, `preset_downloads`,
`preset_documents`, `recursive`, `max_depth`.

### Walk

The walk is **interruptible**: `SongLoader` does not have a recursive function
that sweeps the whole disk in one go, but a batched walk that the UI advances
frame by frame.

- `begin_scan()` leaves `SongLoader` ready (clears `song_list` and diagnostics, calculates the roots) and returns `false` if a scan was already running. Since it is a singleton it only allows one: the second caller waits, it does not overwrite the half-built list.
- `scan_step(dir_budget, deadline_usec)` walks up to `dir_budget` directories or until `deadline_usec` passes, and returns `true` when the scan has finished.
- `pump_scan(deadline_usec)` is the shortcut for callers with UI on screen: one scan frame with `MAX_DIRS_PER_FRAME` (64) and `SCAN_FRAME_BUDGET_MS` (8), and returns `true` only when nothing remains pending — neither a running scan nor another one queued behind it. The scan is served, paused or cancelled within a frame, not in one block.
- `request_scan()` queues a scan for when `SongLoader` is free (Settings requesting a rescan while the menu is scanning). `abort_scan()` is the emergency exit: it clears the request and closes a half-finished scan, so `is_scanning` never stays `true` and blocks the next one.
- `scan_songs()` is the one-shot mode (`scan_step` with no limit) for tests and any caller with no UI to respond.
- `cancel_scan()` is honored in the next batch, at most one frame later. What was already found stays in `song_list`, and `scan_finished` exits with `cancelled = true`.

The walk state lives in an explicit stack (`[path, depth]`), not in GDScript
recursion: this way a batch can be cut between directories without leaving
half-finished frames on the stack. The visit order is the same as with
recursion (subfolders are pushed in reverse so they come out in alphabetical
order), and a root is only closed — with its truncated mark — when the stack
empties (`_close_current_root()`).

`_scan_one_dir()` is the body of the walk and returns only by state:

- A folder is a song if it contains `notes.mid` or `notes.chart` as a **direct child**. If it is, it is recorded and the walk does **not** descend into it.
- If not, it descends into its subdirectories up to `library_max_depth` (default 3). When the depth runs out, `_depth_truncated` is set.
- Entries starting with `.` are ignored.
- `_scanned_paths` deduplicates by canonical path, so overlapping roots (e.g. `Download/` and `Download/MyLib/`) do not produce duplicate songs, and symlinks that form cycles do not hang the scan.
- `MAX_DIRS_PER_ROOT` (4000) bounds the work per root; reaching it also marks the root as truncated.

Listing is done **once per directory**: `notes.mid` / `notes.chart` are detected
on the already-listed entries instead of probing with `FileAccess.open()`. This
avoids up to 2 failed opens (and 2 more from `FileHelper`'s `content://` fallback
on Android) for each folder of a deep tree.

### Progress and cancellation in the UI

`SongLoader` emits `scan_progress(root_index, root_total, current_dir,
dirs_visited, songs_found)` at the end of each batch and
`scan_finished(songs_found, cancelled)` when closing. The first event already
counts the entire walk, so the last number the UI sees is the correct one.
`script/ui/ScanFeedback.gd` is the single place where that progress is formatted,
and both surfaces share it:

- **Settings ▸ Songs** — `Rescan now` triggers `_scan_summary_and_rescan()`, which requests the scan and pumps it from `_process`. The panel shows a bar, `i/N` with the songs found and the current folder, with `Cancel` next to it. When finished, `_update_scan_summary()` adds the warning for cancelled roots.
- **Menu** — `_refresh_song_list()` uses the same loading overlay, but only with `Cancel` and the folder when what is loading is the library; when loading a song it keeps the percentage, which is reliable, and the scan does not show it because `i/N` is not a percentage.

The cancel button does not cut abruptly: it requests `cancel_scan()` and shows
"Cancelling...". The list is rebuilt with what was found, which is an exact
prefix of the full walk.

Any running scan is aborted in `_exit_tree()` and when changing tabs in Settings:
if the UI disappears mid-scan, `SongLoader` must not be left with `is_scanning =
true`.

### Diagnostics

- `SongLoader.unreadable_roots` — roots that could not be opened. On Android without *All files access* granted this is the typical symptom: `Download/` and `Documents/` are not listable under scoped storage.
- `SongLoader.truncated_roots` — roots whose walk was cut by `max_depth` or `MAX_DIRS_PER_ROOT`, meaning there may be deeper songs left undiscovered.
- `SongLoader.cancelled_roots` — roots halfway through the walk when it was cancelled. They are kept separate from truncated ones because the warning is different: there the player knows they stopped it.

### Required permission

On Android 11+ (`API 30`), reading `/storage/emulated/0/...` outside the app's own
folders requires *All files access* (`MANAGE_EXTERNAL_STORAGE`). See the
`AllFilesAccess` plugin section. Without the permission granted, user-defined
roots return `unreadable_roots` and the library appears empty — which is why the
UI must report those roots explicitly instead of showing "0 songs".

### `song.ini` requirement

`song.ini` is **no longer mandatory**: a folder with `notes.mid` or `notes.chart`
enters the list even without metadata. It used to be silently discarded, which
made a raw Clone Hero library useless.

`_derive_metadata()` combines three sources, applying **field-by-field
precedence** (each non-empty field from a higher-priority source overrides the
previous one):

| Priority | Source | Provides |
|---|---|---|
| 1 (lowest) | Folder name | `name`, `artist`, `charter` |
| 2 | `[Song]` header of the `.chart` | `name`, `artist`, `album`, `genre`, `year`, `charter`, `delay` (from `Offset`) |
| 3 (highest) | `song.ini` | all of the above + `song_length`, `preview_start_time`, `diff_drums` |

Clone Hero's `song.ini` keys match the ones the game already read, so they are
used as-is.

**Folder name.** It is parsed with the `"<Artist> - <Song> (<Charter>)"`
convention. If the name does **not** contain `" - "`, the **parent folder** name
is used as the artist — this covers the nested `library/Artist/Song` layout,
which is the most common. The parent is only used if it is not the scan root
itself (otherwise `Download/Song` would give artist `Download`) and if it is not
under `res://` or `user://`.

A trailing `(...)` is **not** split off as charter when there is no `" - "`: many
real titles include it (`Song (Remix)`, `Song (Live)`) and `charter` is not shown
in the UI, so it is not worth the risk of mangling titles.

**`song.ini` with quotes.** `_parse_ini` unwraps the quotes around the value
(using `DotChartParser.strip_quotes()`). Previously `"Crystal Castles"` appeared
in the list with the quotes included.

**Corrupt `Year`.** Real charts contain values like `Year = ", 2008"`.
`_extract_year()` extracts the first 4 digits; if it does not find exactly 4, it
returns the original value untouched.

**`song_length`.** It only comes from `song.ini`. Without it, it stays 0 and
`MenuRoot` **omits the duration prefix** instead of showing `0:00`. It is not
derived from the chart because that would require parsing the full tempo map for
every song during the scan, in exchange for purely decorative data.

### SONGS tab (Settings)

`SettingsRoot` has a **SONGS** tab between HUD and Experimental. It contains:

- **STORAGE ACCESS** — All Files Access status. On Android it shows *Grant access* while it has not been granted and *Open Android settings* once granted. On other platforms it shows that access is automatic.
- **LIBRARY LOCATIONS** — `Download`/`Documents` checks, maximum depth (0 = only that folder) and *Search subfolders*.
- **EXTRA FOLDERS** — list of custom roots with a *Remove* button, plus a `LineEdit` to add absolute paths. Paths are normalized with `simplify_path()`, prefixed with `/` if missing and duplicates are discarded. Paths that do not exist are shown in red in the list.
- **Rescan now** and **Cancel**, with a progress bar, `i/N` locations, songs found and current folder while the scan lasts (see *Progress and cancellation in the UI*).
- A summary of the last scan reporting the number of songs, the number of locations, and roots that were unreadable, truncated by depth or cancelled halfway.
- **Reset SONGS to Defaults**.

Library changes persist instantly (`SettingsManager.save_settings()`), but the
rescan does not happen on every toggle: `MenuRoot._library_changed()` compares a
snapshot and only refreshes the list when Settings closes. Rescanning on every
toggle would be a disk walk per checkbox.

`AndroidBridge` is an autoload; `OS.request_permissions()` is not used for All
Files Access because it does not include `MANAGE_EXTERNAL_STORAGE`.

### Drum lanes in `.chart` charts

`CHART_LANE_MAP` (ChartData.gd) maps the chart lanes to the game's 8 lanes (HH,
CRASH, SNARE, KICK, TOM 1, TOM 2, TOM 3, RIDE):

| Chart | Game | |
|---|---|---|
| 0 | KICK | |
| 1 | SNARE | |
| 2 | HH | |
| 3 | RIDE | |
| 4 | CRASH | |
| 5, 66 | TOM 1 | |
| 6, 67 | TOM 2 | |
| 7, 68 | TOM 3 | |

**Toms at 66/67/68.** Clone Hero/Phase Shift `.chart` charts encode toms in lanes
66, 67 and 68, not 5/6/7. This was deduced from
`Songs/Caos - La Planta (jdpc.dev)/notes.chart`, the only chart in the project
with drums: it uses 0-4 and 66/67/68, exactly 8 lanes that fit one-to-one with
the game's lanes. Previously those toms were discarded, leaving out 718 of the
2027 notes in Expert.

Lane **65** is deliberately left unmapped: it does not appear in any chart in the
project and the game only has 3 toms, so there is no lane where a possible fourth
tom could go. It is discarded and appears in the unknown-lanes warning.

**Discarded-lanes warning.** `_warn_skipped_lanes()` accumulates discards per
lane and emits **one** `push_warning` per chart (`lane 65 x3, lane 99 x1`).
Previously `DotChartParser` warned per note, which generated thousands of
identical log lines in charts with many unknown lanes. The `_skipped_lanes`
dictionary is kept after `load()` for diagnostics.

### Unplayable `.opus` audio

`AudioManager._load_audio_stream()` does not decode `.opus` on Android
(`_decode_opus_via_ffmpeg()` returns `null` on purpose) and only falls back to a
sibling `song.ogg`/`preview.ogg`. A Clone Hero library with `song.opus` entered
the list but **played as silence with no warning**.

`SongLoader._detect_blocked_audio()` flags the entry with `audio_blocked: true`
when `song.opus` exists and `song.ogg` does not. It is reported in two places:
the SONGS tab summary ("N song(s) ... convert them with
tools/convert_opus_to_ogg.sh") and the song list status bar, so it is visible
without opening Settings. Converting with
`tools/convert_opus_to_ogg.sh --remove-opus` brings the warning to zero, because
when `song.ogg` exists the function returns `false` even if the `.opus` is still
there.

### All Files Access permission in the UI

`AndroidBridge` exposes four operations on the `AllFilesAccess` singleton:

| Method | Effect |
|---|---|
| `has_all_files_access()` | `Environment.isExternalStorageManager()` (always `true` on Android ≤10) |
| `request_all_files_access()` | Grants the permission; on Android ≤10 **opens Settings** instead of doing nothing |
| `open_all_files_settings()` | Always opens the Settings screen, whether or not the permission is granted |
| `is_storage_plugin_available()` | Whether the singleton made it into the APK |
| `get_storage_last_error()` | `no_activity`, `no_settings_activity`, `no_app_details_activity`, `plugin_missing` or `""` |

**Why the "Open Android settings" button did nothing.** `requestAllFilesAccess()`
did `return true` without launching any intent in two cases: Android ≤10 and
permission already granted. The button labeled "Open Android settings" was
therefore a dead button. The two responsibilities were split into
`requestAllFilesAccess()` (grant) and `openAllFilesSettings()` (always open
Settings), and the button label decides which one to call.

**No failure is silent.** `_on_permission_pressed()` checks the boolean return;
if nothing could be opened, the panel shows the reason
(`get_storage_last_error()`) and indicates the manual path. If the singleton is
not in the APK, the panel says so and disables the button instead of leaving an
inert control.

**Refresh on return.** `SettingsRoot` re-evaluates the permission on
`NOTIFICATION_APPLICATION_FOCUS_IN` and `NOTIFICATION_WM_WINDOW_FOCUS_IN`,
because returning from Settings does not emit any Godot signal. If the
permission became granted, it rescans the library. On Android 11+ the system may
kill the process when granting the permission; in that case the state is read
correctly when the app is reopened.

### Build requirement: "Use Gradle Build" must be enabled

The Android plugins (`AllFilesAccess`, `GestureExclusion`) are distributed as AARs
and **only reach the APK if the export uses Gradle**. With
`gradle_build/use_gradle_build=false` Godot packages the prebuilt APK and injects
only the PCK: there is no build where the AARs can be merged, so the Java
singleton does not exist and `AndroidBridge` silently returns `false`. The
symptom was an inert "Grant access" button and no crash.

Three conditions must be met:

1. **Build template installed.** `android/build/` must contain the root `build.gradle`. In a fresh clone you must use *Project > Install Android Build Template* (or `godot --headless --install-android-build-template --quit`); `android/build/` is in `.gitignore`, so it does not travel in the repo.
2. **`gradle_build/use_gradle_build=true`** in `export_presets.cfg`. Leave `gradle_build/gradle_build_directory` **empty**: with an explicit value such as `res://android/build` Godot's template validation fails.
3. **Java 11 or higher.** AGP 8.6.1 rejects a JVM 8. It is set in *Editor Settings > Export > Android > Java SDK Path*.

**AAR path.** `_get_android_libraries()` must return full `res://` paths with
the addon prefix, e.g. `res://addons/AllFilesAccess/bin/debug/AllFilesAccess.aar`.
Previously both plugins returned `AllFilesAccess/bin/debug/...`, without `res://`
or `addons/`, and the path did not resolve.

The template's `build.gradle` picks up plugins in two ways:
`implementation files(pluginsBinaries)` with what `_get_android_libraries()`
returns, and a **non-recursive** `fileTree` over `addons/` (`include: ['*.jar',
'*.aar']`), which does not reach an AAR in `addons/<plugin>/bin/debug/`. That is
why the path matters.

**Verification.** A debug export with the correct configuration produces an APK
containing the packages `com.drum.hero.allfilesaccess` and
`com.drum.hero.gestureexclusion`, and in the manifest:

```
org.godotengine.plugin.v2.AllFilesAccess  ->  com.drum.hero.allfilesaccess.AllFilesAccessPlugin
org.godotengine.plugin.v2.GestureExclusion -> com.drum.hero.gestureexclusion.GestureExclusionPlugin
```

That `meta-data` is what makes Godot register the singleton in
`Engine.has_singleton()`.

### Known limitations

- The chart must be a direct child of the song folder (the Clone Hero/YARG convention and the one documented in the root `README.md`). A `song/charts/notes.mid` layout is not detected.
- The chart name is compared case-insensitively during the scan, and the actual name of the found file is passed to `_scan_song()`, so `Notes.MID` also works.
- `.opus` audio is not decoded on Android; the library needs `.ogg` (or packaged `.wav`/`.mp3`).

---

## Song format

Songs included in the APK are in `res://Songs/` with `.ogg` files (converted from
`.opus` by `tools/convert_opus_to_ogg.sh` before the build). That script accepts
`--remove-opus` to delete the `.opus` once a valid `.ogg` exists, and only deletes
under `Songs/`: the `.opus` files in `asset/drumSfx/` are versioned in git and
are always kept. Deletion requires the `.ogg` to be non-empty and to start with
the `OggS` magic bytes, asks for confirmation once before the first deletion
(`--yes` skips it) and `DRY_RUN=true` deletes nothing. User songs go in
`user://DrumHero` (desktop) or external storage (Android) with `.opus` or `.ogg`.
Custom roots can be added — see [External song libraries](#external-song-libraries).

```
Songs/<artist> - <song>/
├── song.ini           ← metadata (optional; folder name and the .chart [Song] header cover the rest)
├── notes.mid          ← MIDI chart (Rock Band / Clone Hero mapping) — priority
├── notes.chart        ← .chart chart (Feedback format, Clone Hero) — fallback if there is no .mid
├── song.ogg           ← full mix
├── preview.ogg        ← short preview (optional, 30s — falls back to song.ogg if missing)
├── drums.ogg          ← drums only (optional)
├── bass.ogg           ← bass only (optional)
├── guitar.ogg         ← guitar only (optional)
├── rhythm.ogg         ← rhythm guitar (optional)
├── keys.ogg           ← keys only (optional)
├── vocals.ogg         ← vocals only (optional)
├── album.jpg          ← cover art (preferred)
├── album.png          ← cover art (fallback if there is no album.jpg)
└── background.jpg     ← background image
```

Stems can have alternative forms: `drums_1.ogg`, `drums_2.ogg` (multi-mic).
`_find_stem_file()` searches with a numeric suffix if it does not find the base
file. On desktop, `.opus` is also supported (decoded via ffmpeg).

### notes.mid

The format follows the **Rock Band MIDI** standard: each difficulty occupies a
MIDI octave. The parser (`MidiParser.gd`) subtracts the difficulty offset and maps
the relative note (0–11) to the internal lane, defined in `ChartData.gd`:

| MIDI octave | Offset | Difficulty |
|---|---|---|
| 60–71 | 60 | Easy |
| 72–83 | 72 | Medium |
| 84–95 | 84 | Hard |
| 96–107 | 96 | Expert |
| 120–127 | 120 | Expert+ |

| Relative | Instrument (Rock Band) | Lane (internal) |
|---|---|---|
| 0 | Kick | 3 |
| 1 | Red (Snare) | 2 |
| 2 | Yellow (Hi-Hat Closed) | 0 |
| 3 | Blue (Ride) | 7 |
| 4 | Green (Crash) | 1 |
| 5 | Snare (alt) | 2 |
| 6 | Hi-Hat Open | 0 |
| 7 | Ride (bell/edge) | 7 |
| 8 | Crash (alt) | 1 |
| 9 | Tom 1 | 4 |
| 10 | Tom 2 | 5 |
| 11 | Tom 3 | 6 |

Notes outside these ranges (GM raw 36–51, special 110+) are ignored.
`_resolve_difficulty()` iterates `DIFFICULTY_OFFSETS = [60, 72, 84, 96, 120]` and
the first match in range 0–11 determines the difficulty and lane.

### Chart source detection (.mid / .chart)

`SongLoader` detects the format automatically: it looks for `notes.mid` first; if
it does not exist, it looks for `notes.chart`. `ChartParser.load_chart()` delegates
to the parser based on the file extension.

#### MIDI (`MidiParser.gd`)

It looks for MIDI tracks whose name starts with `"PART DRUMS"`. If no drum notes
are found and the `use_guitar_fallback` option is enabled, the parser retries
with `"PART GUITAR"` tracks.

**Detection flow:**

```
MidiParser.load(path, ..., use_guitar_fallback)
  │
  ├─ 1. Parse MIDI looking for "PART DRUMS"
  │     → Were notes found?
  │       ├─ YES → use those notes (has_drum_track = true)
  │       └─ NO → continue
  │
  └─ 2. Is use_guitar_fallback enabled?
        ├─ YES → Re-parse MIDI looking for "PART GUITAR"
        │       → Were notes found?
        │         ├─ YES → use those notes (using_guitar_fallback = true)
        │         └─ NO → no notes
        └─ NO → no notes
```

**Properties exposed by MidiParser:**

| Property | Type | Description |
|---|---|---|
| `has_drum_track` | `bool` | `true` if a "PART DRUMS" track was found |
| `using_guitar_fallback` | `bool` | `true` if PART GUITAR was used as fallback |

#### .chart (`DotChartParser.gd`)

The parser identifies `[EasyDrums]`, `[MediumDrums]`, `[HardDrums]`,
`[ExpertDrums]`, `[ExpertPlusDrums]` sections. Each section contains that
difficulty's notes in `tick = N lane length` format. Lane mapping uses
`ChartData.CHART_LANE_MAP`: lanes 0–4 for basic drums (Kick, Snare, HH, Ride,
Crash) and lanes 5–7 for toms (Pro Drums). It supports guitar as fallback by
looking for `[EasySingle]`–`[ExpertSingle]` sections.

**Key difference from MIDI:** in `.chart` the lane number directly encodes whether
it is a tom or a cymbal (no tom markers are needed). Lanes 2–4 are always
cymbals; lanes 5–7 are always toms.

**Difficulty detection:**

Both parsers expose `detect_difficulties()`, which returns a dictionary with:

```gdscript
{
    "difficulties": [...],          # Array of available difficulties
    "has_drum_chart": bool,         # Whether PART DRUMS / a Drums section existed
    "guitar_fallback_used": bool    # Whether PART GUITAR / [Single] was used as fallback
}
```

`SongLoader` stores these fields in each song-list entry, and `MenuRoot` shows
them in the status label:

- **No drum track and no fallback** → shows "no drum chart"
- **No drum track but fallback active** → shows "using guitar chart"
- **With drum track** → no additional message

**Note (MIDI):** if a MIDI has both tracks (PART DRUMS and PART GUITAR), PART
DRUMS is always prioritized. The fallback only activates when PART DRUMS produces
no notes.

---

## Data classes

### `ChartData.NoteEvent`

| Field | Type | Description |
|---|---|---|
| `tick` | `int` | Position in MIDI ticks |
| `time` | `float` | Time in seconds (converted with the tempo map) |
| `lane` | `int` | Internal lane 0–7 |
| `note_type` | `enum NoteType` | NORMAL, KICK, OPEN_HIHAT, CRASH_ACCENT, HOLD |
| `velocity` | `int` | MIDI velocity 0–127 |
| `length_ticks` | `int` | Duration in ticks (holds) |

### `ChartData.TempoEvent`

| Field | Type | Description |
|---|---|---|
| `tick` | `int` | Tick where the change occurs |
| `bpm` | `float` | Beats per minute |
| `time` | `float` | Precalculated time in seconds |

---

## Configuration

## Best scores

`HighScoreStore` stores the best score per song+difficulty pair in
`user://scores.cfg` (its own `ConfigFile`, on purpose:
`SettingsManager.save_settings()` regenerates its file with only its own keys and
would delete foreign sections).

- **Key**: `md5(song.path) + "|" + difficulty_offset`. `song.path` is the song identity (`res://Songs/...` or an absolute path); the hash avoids characters that would break `ConfigFile`'s INI format. The difficulty uses the chart code (60/72/84/96/120), the same one exposed by `song.difficulties` and received by `GameManager.current_difficulty_offset` in the real run.
- **When it is saved**: `GameplayRoot._show_result()`, right after `Highway.flush_unjudged_notes()` (the score is already final) and before `set_state(RESULT)`. It only touches disk if it beats the previous record.
- **When it is shown**: `MenuRoot._create_song_row()` paints `ScoreData.format_score(get_best_for_song(path, difficulties))` in each row's score label; without a record it keeps the `--,---pts` placeholder. `get_best_for_song` returns the maximum across the chart's difficulties.
- The store is an autoload that loads the file in `_ready()`; when returning from gameplay `Main.tscn` is re-instantiated and the rows already show the newly achieved record.

`SettingsManager` persists to `user://settings.cfg` using `ConfigFile`. Default
values:

| Key | Default | Description |
|---|---|---|
| `judgement_perfect_ms` | 22.5 | Perfect window (±ms) |
| `judgement_excellent_ms` | 45.0 | Excellent window (±ms) |
| `judgement_good_ms` | 75.0 | Good window (±ms) |
| `judgement_late_ms` | 100.0 | Late window (±ms) |
| `judgement_early_ms` | 100.0 | Early window (±ms) |
| `judgement_miss_ms` | 135.0 | Miss threshold (±ms) |
| `master_volume` | 1.0 | Master volume |
| `sfx_volume` | 1.0 | Effects volume |
| `music_volume` | 1.0 | Music volume |
| `haptic_enabled` | false | Sensor kick |
| `haptic_sensitivity` | 1.0 | Sensor sensitivity (÷, higher = more sensitive) |
| `haptic_activation_threshold` | 1.0 | Base activation threshold (÷ by sensitivity) |
| `haptic_release_threshold` | 0.5 | Post-kick release threshold (÷ by sensitivity) |
| `haptic_smoothing_strength` | 0.4 | Exponential filter (0=max smoothing, 1=no filter) |
| `haptic_cooldown_duration` | 0.15 | Minimum time in COOLDOWN (s) |
| `haptic_min_interval` | 0.08 | Minimum interval between kicks (s) |
| `haptic_calibration_duration` | 1.5 | Calibration duration without a gravity sensor (s) |
| `haptic_show_debug` | false | On-screen debug overlay |
| `game_mode` | 0 | Game mode (0=Default, 1=Haptic, 2=Custom) |
| `custom_lanes` | [] | Custom lane order |
| `mirrored` | false | Mirrored layout |
| `left_handed` | false | Left-handed mode |
| `screen_shake` | false | Screen shake effect |
| `show_fps` | false | Show FPS counter on screen |
| `show_hit_feedback` | true | Show judgement text at each hit line |
| `countdown_threshold` | 5.0 | Minimum gap (s) to show the countdown |
| `preview_volume` | 0.8 | Song preview volume in the main menu |
| `use_guitar_fallback` | false | Use PART GUITAR as fallback if PART DRUMS is missing |
| `note_speed` | 1.0 | Note scroll speed |
| `show_judgment_areas` | false | Draw judgement zones on the hit line |
| `show_menu_status` | false | Show the main menu status line (chart/audio of the selected song, songs found) |
| `gameplay_padding_enabled` | false | Condense gameplay with padding to avoid edge touches |
| `gameplay_padding_left` | 75.0 | Left padding in dp (0-100, Android only) |
| `gameplay_padding_right` | 75.0 | Right padding in dp (0-100, Android only) |
| `gameplay_padding_top` | 0.0 | Top padding in dp (0-100, Android only) |
| `gameplay_padding_bottom` | 0.0 | Bottom padding in dp (0-100, Android only) |

### Settings menu layout

The settings menu (`SettingsRoot.gd`) uses a **tabbed** layout to organize the
options:

- **CONTROLS** — Control mode (Default/Haptic/Custom), lane order, haptic settings, layout (mirrored/left handed). Includes a "Reset CONTROLS to Defaults" button.
- **HUD** — Visual options (FPS, screen shake, hit feedback), gameplay (note speed, countdown), judgement windows (read-only). Includes a "Reset HUD to Defaults" button.
- **Experimental** — Chart fallback (PART GUITAR), judgement areas (debug), haptic overlay (Show Haptic Debug), main menu status (Show Menu Status), gameplay padding. Includes a "Reset EXPERIMENTAL to Defaults" button.

Each "Reset [SECTION] to Defaults" button restores all values in that section to
their defaults and rebuilds the active tab's UI.

**Reset methods in `SettingsManager.gd`:**
- `reset_controls_to_defaults()` — resets `game_mode`, `custom_lanes`, `haptic_*`, `mirrored`, `left_handed` and syncs `GameManager.mode`.
- `reset_hud_to_defaults()` — resets `show_fps`, `screen_shake`, `show_hit_feedback`, `note_speed`, `countdown_threshold`.
- `reset_experimental_to_defaults()` — resets `use_guitar_fallback`, `show_judgment_areas`, `show_menu_status`, `haptic_show_debug`, `gameplay_padding_*`.

**Technical note:** on Android, `Control` nodes that are children of a
`CanvasLayer` and not inside a `ScrollContainer` do not render correctly. To fix
this, the header and tab bar use a fixed `ScrollContainer` (no scroll) while the
content uses a scrollable `ScrollContainer`.

---

## Visual effects

### Feedback when hitting a note

When the player hits a note, the following visual effects fire simultaneously.
**No local sound is played (`DrumSfxManager`)**: the perceived audio comes
exclusively from the song's drum stems (`drums_1`, `drums_2`, etc.).

1. **HitLine flash** — The corresponding hit line's `ColorRect` turns white and returns to its original color (0.1s). Implemented in `HitLine.gd`.
2. **Slash effect** — Two `ColorRect`s expand from the lane center toward the edges with the lane's characteristic color (0.12s). Implemented in `Lane.gd` (`_slash_left`, `_slash_right`).
3. **ParticleBurst** — 16 particles explode from the impact point with the lane color (0.4s). Pool in `EffectManager`.
4. **JudgementPopup** — Judgement text ("PERFECT", "EXCELLENT", "GOOD", "LATE", "EARLY", "MISS") appears at the corresponding lane's hit line, floats upward and fades (0.6s). Pool in `EffectManager`. Controlled by `show_hit_feedback`.
5. **Lane background highlight** — The lane's `bg_rect` briefly increases its alpha.

When a note passes the hit line without being hit, "MISS" is shown at the
corresponding lane's hit line (same effects 4 and 5).

### Pooled effects (EffectManager)

Implemented with pooling in `EffectManager` (max. 16 instances per type).

| Effect | Scene | Activation |
|---|---|---|
| ParticleBurst | `scene/UI/Effects/ParticleBurst.tscn` | `trigger_particle_burst(pos, color, parent)` on each hit |
| Shockwave | `scene/UI/Effects/Shockwave.tscn` | `trigger_shockwave(pos, parent)` — implemented, not connected |
| JudgementPopup | `scene/UI/Effects/JudgementPopup.tscn` | `show_judgement(accuracy, pos, parent)` — active on each hit (controlled by `show_hit_feedback`) |

**Pooling mechanism (`_borrow`):**

1. Walks the pool and removes invalid references with `is_instance_valid()`.
2. Looks for an instance outside the scene tree (`is_inside_tree() == false`) to reuse it.
3. If none is available and `MAX_POOL_SIZE` (16) has not been reached, creates a new instance.
4. If the pool is full, returns `null` (the effect is silently skipped).

Each effect, when its animation ends, calls `get_parent().remove_child(self)`
instead of `queue_free()`. This detaches it from the tree but keeps it in memory
for later reuse, eliminating constant node creation and destruction in the
gameplay hot path.

**ParticleBurst** (particles with `ColorRect`): 16 particles pre-created on the
first `play()` call. Each particle is a `ColorRect` that is positioned and
animated without needing `queue_redraw()` or `draw_circle()`, reducing CPU
rendering load on mobile.

**JudgementPopup** (judgement text): caches a `LabelSettings` instance created in
`_ready()` instead of instantiating a new one on each `show_judgement()`,
eliminating per-frame allocations.

### Additional visual feedback

- **Combo counter** — "pop" animation (scale 1.3→1.0) when the combo changes (`ComboCounter.gd`).
- **Hit feedback** — judgement text ("PERFECT"/"EXCELLENT"/"GOOD"/"LATE"/"EARLY"/"MISS") at each hit line via `JudgementPopup` (configurable with `show_hit_feedback`). Miss is shown when the note passes the hit line without being hit.
- **Judgment areas** — asymmetric color bands on the hit line showing the timing windows (configurable with `show_judgment_areas` in Experimental). EARLY→GOOD→EXCELLENT→PERFECT→LATE→MISS from top to bottom.
- **Touch zone highlight** — touch zones at the base of each lane light up when pressed (`TouchInput.gd`).

---

## How to add a new lane

1. Add the MIDI note to the mapping in `MidiParser.get_drum_notes()`
2. Add the label in `DrumGraphics.LANE_LABELS` and `LANE_FULL_LABELS`
3. Add the vector shape in `DrumGraphics._generate_for_lane()` → `_draw_note()` and `_draw_hit_line()`
4. Add the color in `Note._get_color_for_lane()` (or `Highway._get_lane_colors()`)
5. If the lane requires a new NoteType (e.g. HOLD), extend `ChartData.NoteType`

---

## External dependencies

- **ffmpeg** (with `--enable-libopus`) — required to decode `.opus` stems. Detected automatically when loading a song.
- **Godot 4.7 stable** — Linux build without the native opus module (which is why ffmpeg is used).
