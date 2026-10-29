# Drum Hero — Guía de desarrollo

## Stack

- **Motor:** Godot 4.7 (GDScript)
- **Resolución:** 1280×720, landscape, stretch `canvas_items` + `expand`
- **Renderizado:** `gl_compatibility`
- **Audio:** stems OGG nativos (`AudioStreamOggVorbis.load_from_file()`), con fallback `FileHelper.read_file()`. Opus decodificado vía `ffmpeg` a PCM → `AudioStreamWAV` (desktop only).
- **Gráficos de interfaz:** generación procedural vectorial (`Image.set_pixel`)

---

## Árbol de escenas (runtime)

```
Main (CanvasLayer)                      ← MenuRoot.gd
├── Background (ColorRect)
├── Root (VBoxContainer)               — con PADDING 40px
│   ├── HeaderBar (PanelContainer)     — AlbumArt + Search + Settings
│   │   └── hbox (HBoxContainer)
│   │       ├── AlbumArt (TextureRect) — 70×70, visible al seleccionar canción
│   │       ├── SearchInput (LineEdit) — placeholder "Search: "
│   │       ├── SettingsButton
│   │       └── Spacer
│   ├── SongListScroll (ScrollContainer) — lista scrolleable
│   │   └── SongListContainer (VBoxContainer)
│   │       ├── SongRow_N (PanelContainer)  — ► + artista + --,---pts
│   │       └── ...
│   ├── StatusLabel                    — "STATUS: chart OK - ..." (oculto por defecto; Show Menu Status en Ajustes > Experimental)
├── PreviewStatusLabel             — "♫ Artist - Song" (mientras se reproduce preview, oculto si no hay) | idle: "♫ Tap a song to preview"
│   └── DiffContainer (HBoxContainer)  — Easy/Medium/Hard/Expert/Expert+
│       └── [5 botones]                — desactivados si no disponibles

Settings (CanvasLayer, layer 10)       ← SettingsRoot.gd
├── Background (ColorRect)
├── MarginContainer (margins 40px)
│   └── VBoxContainer (root)
│       ├── HeaderScroll (ScrollContainer, no scroll, 110px)
│       │   └── VBoxContainer
│       │       ├── HeaderBar (HBoxContainer) — "SETTINGS" + Back
│       │       └── TabBar (PanelContainer)   — CONTROLS | HUD | Experimental
│       └── ContentScroll (ScrollContainer, scrollable)
│           └── ContentContainer (VBoxContainer) — contenido del tab activo
│
│   Tab CONTROLS:
│       ├── CONTROL MODE (Default / Haptic / Custom)
│       ├── LANE ORDER (solo Custom)
│       ├── HAPTIC (enable + sensitivity slider)
│       └── LAYOUT (Mirrored / Left Handed)
│
│   Tab HUD:
│       ├── VISUAL (Show FPS / Screen Shake)
│       ├── GAMEPLAY (Note Speed / Silence Countdown sliders)
│       └── JUDGEMENT WINDOWS (read-only ±ms)
│
│   Tab Experimental:
│       ├── FREE MODE (Open Free Mode)   — acceso directo a la pista vacía
│       ├── CHART FALLBACK (Use PART GUITAR)
│       ├── DEBUG (Show Judgment Areas)
│       └── GAMEPLAY PADDING (Enable + 4 sliders: Left/Right/Top/Bottom 0-200px)

Gameplay (Node2D)                       ← GameplayRoot.gd
├── Highway (Node2D)                    ← Highway.gd
│   ├── bg_sprite (Sprite2D)           ← highway_bg.png
│   ├── Lane_0 (Lane)                  ← Lane.gd (por cada lane activo)
│   │   ├── bg_rect (ColorRect)        ← color del lane (alpha 0.08)
│   │   ├── slash_left (ColorRect)     ← efecto de corte expansivo
│   │   ├── slash_right (ColorRect)    ← efecto de corte expansivo
│   │   └── Note (Note)                ← Note.gd (spawn dinámico)
│   ├── HitLine (Node2D)              ← HitLine.gd
│   │   └── lane_sprite_N (Sprite2D)  ← DrumGraphics (vector, por lane)
│   └── Label_HH (Label)              ← "HH", "CRASH", etc.
│       ... (un label por lane)
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
├── Highway (Node2D)                    ← Highway.tscn (instancia real)
├── HUD (CanvasLayer)
│   ├── TitleLabel / HintLabel
│   ├── PadNameLabel                    ← nombre del pad que acaba de sonar
│   ├── HitsLabel                       ← contador de golpes
│   ├── BackButton                      ← vuelve al menú
│   ├── FpsLabel                        ← solo si Show FPS
│   └── CalibrationLabel                ← solo con kick por sensor
└── TouchInput (Node)                   ← sin HitDetection
```

### Estado del setlist al volver del gameplay

El menú es una escena completa (`Main.tscn`), así que al jugar y volver se
reconstruye desde cero. Para no perder el contexto, `MenuRoot._save_menu_state()`
guarda la búsqueda, el `scroll_vertical` y la canción seleccionada en
`GameManager.menu_search_text` / `menu_scroll_position` /
`menu_selected_song_path` al salir de la escena (y justo antes de lanzar una
canción). Al montar el menú, `_ready()` restaura la búsqueda antes de crear las
filas, recupera la selección por ruta cuando las filas ya existen (relanzando su
preview) y aplica el scroll en cuanto el `ScrollContainer` conoce la altura real
del contenido. Es estado de sesión: no se escribe en `settings.cfg`.

Prueba: `godot --headless --path . res://tools/test_menu_state.tscn`

### Modo libre (drum testing)

Se entra desde **Ajustes → Experimental → Open Free Mode**. Es una escena
propia, no una canción sintética: no hay chart, puntuación, combo ni pantalla de
resultados, así que no puede ensuciar los récords de `user://scores.cfg`.

Reutiliza `Highway.tscn` a propósito, para que el orden de pistas, el layout, el
*gameplay padding* y la exclusión de gestos de Android sean exactamente los del
juego. Lo único que **no** monta frente a `Gameplay.tscn` son `HitDetection` y
`HapticKick`:

- `TouchInput` recibe `null` como `HitDetection`, de forma que su rama "no se
  acertó ninguna nota" es la que dispara el sample del pad. El sample no se
  reproduce por otra vía o sonaría dos veces.
- El kick del acelerómetro se escucha conectando `InputManager.kick_detected`
  directamente, porque `HapticKick` solo sabe reenviar a `HitDetection`, que aquí
  no existe. La conexión solo se hace si el kick está habilitado
  (`SettingsManager.haptic_enabled` o modo `HAPTIC`) y se comprueba
  `is_connected()` antes de desconectar en `_exit_to_menu()`.

El botón emite `SettingsRoot.free_mode_requested`; el cambio de escena lo hace
`MenuRoot` (el panel de Ajustes es un overlay suyo, no una escena):

```
SettingsRoot._on_free_mode_pressed() → free_mode_requested
MenuRoot._on_free_mode_requested()   → _stop_preview()
                                     _is_switching_scene = true
                                     change_scene_to_file(FreeMode.tscn)
```

`MenuRoot._is_switching_scene` protege `_on_settings_closed()`: al cambiar de
escena, el panel se desmonta con el menú y su `tree_exited` se dispara durante la
destrucción. Sin ese guard, ese cierre reescanearía la biblioteca de canciones
con el árbol ya a medio tirar.

**ChartParser es un autoload y sobrevive a los cambios de escena.** Por eso
`FreeModeRoot._ready()` llama a `ChartParser.clear()`: sin él, las notas de la
última canción seguida seguirían bajando por la pista y se contarían como
falladas al instante.

### Test

```
godot --headless --path . res://tools/test_freemode.tscn  # pista vacía + pads + salida
```

---

## Autoloads (singletons)

Registrados en `project.godot` bajo `[autoload]`. Se inicializan antes que cualquier escena.

| Autoload | Rol | Dependencias |
|---|---|---|
| `GameManager` | Máquina de estados (MENU / LOADING / PLAYING / PAUSED / RESULT). Contiene `current_song_path`, `mode`, `state`. Emite `hit_registered`, `miss_registered`, `game_state_changed`. | — |
| `AudioManager` | Carga stems multi-pista (song, drums, bass, guitar, rhythm, keys, vocals). Salta `song` si existen stems individuales para evitar duplicación. Decodifica `.opus` a estéreo vía `ffmpeg`. Ofrece `duck_drums()` para silenciar batería temporalmente. | — |
| `InputManager` | Ruteo de input táctil y pipeline de sensor háptico (acelerómetro para kick). Detección en dos fases: lift (pico en eje Z de pantalla) → cruce por cero → KICK. Estados: `KickState` (IDLE / KICK_DOWN / COOLDOWN). | — |
| `SettingsManager` | Persistencia de configuración (archivo `user://settings.cfg`). Juicios, sensibilidad, modo háptico, orden de lanes, fallback de guitarra. | — |
| `SongLoader` | Escanea una lista de raíces configurables (ver *Bibliotecas de canciones externas*), parsea `song.ini`, expone lista de canciones con metadatos. Detecta fuente del chart (PART DRUMS vs PART GUITAR). Cada song entry incluye `preview_path` (str), `preview_start_time` (int, en milisegundos, -1 si no definido), `song_length` (float). `get_stem_path()` y `_scan_song()` usan `FileHelper.file_exists() OR ResourceLoader.exists()` para encontrar archivos tanto en `user://` (FileAccess) como en `res://` empaquetados (ResourceLoader). `album_path` busca `album.jpg` primero y falla a `album.png` si no existe. El escaneo es interrumpible: `begin_scan()` / `scan_step()` / `pump_scan()` lo avanzan por lotes, `request_scan()` lo encola y `cancel_scan()` lo para sin perder lo encontrado (ver *Recorrido*). Emite `scan_progress` y `scan_finished`, y expone `unreadable_roots`, `truncated_roots` y `cancelled_roots` para diagnóstico. | — |
| `ChartParser` | Carga `notes.mid` (vía `MidiParser.gd`) o `notes.chart` (vía `DotChartParser.gd`) según extensión del archivo. Produce el mismo arreglo de `NoteEvent` para ambos formatos. Soporta fallback a PART GUITAR / `[ExpertSingle]` si no hay batería. `get_notes_in_range()` usa búsqueda binaria (`find_next_note_index`) para saltar al rango solicitado. `clear()` vacía el chart; lo llama el modo libre, que monta la Highway sin notas (ver *Modo libre*). | `ChartData.gd` (clases de datos) |
| `TimingEngine` | Reloj maestro. Si hay audio usa `AudioManager.get_position()`, sino delta de frames. Emite `time_updated`, `song_ended` (una sola vez, ver *Fin de canción*). `stop()` congela el reloj donde esté; `start()` lo rearma. | `AudioManager` |
| `ScoreManager` | Puntaje, combo, multiplicador, rachas. API: `register_hit(diff)`, `register_miss()`, `reset()`. | — |
| `EffectManager` | Pool de efectos visuales (`ParticleBurst`, `Shockwave`, `JudgementPopup`). Genera SFX (beeps programáticos). | — |
| `DrumGraphics` | Genera texturas vectoriales para notas y hit lines por lane (double cymbal, cymbal, drumstick, pedal). Texturas de 128×128 pre-generadas en `_ready()`. | — |
| `AndroidBridge` | Puente GDScript→Android nativo. Gestiona los plugins `GestureExclusion` (excluir bordes del back gesture) y `AllFilesAccess` (conceder *All files access* y sondear legibilidad de rutas). Solo activo en Android; no-op en desktop. | — |
| `HighScoreStore` | Mejores puntuaciones por canción+dificultad (archivo `user://scores.cfg`, ver *Mejores puntuaciones*). | — |

### Flujo de dependencias

```
InputManager ──→ TouchInput ──→ HitDetection ──→ Lane.try_hit()
                                                      │
                            ChartParser ←─────────────┤ (note_data)
                            TimingEngine ←────────────┤ (current_time)
                                                      │
                            ScoreManager ←────────────┤ (register_hit/miss)
                            EffectManager ←───────────┤ (SFX + visual FX)
                            AudioManager ←────────────┤ (duck_drums en miss)
```

---

## Sistema de audio

### Pipeline de stems

```
AudioManager.load_stems(song_path)
  │
  ├─ _find_stem_file() busca: {stem}.ogg → {stem}.opus → {stem}.wav → {stem}.mp3
  │                            → drums_1.ogg, drums_2.ogg, etc. (multi-archivo)
  │   (FileHelper.file_exists() OR ResourceLoader.exists() — cubre res:// + user://)
  │
  └─ _load_audio_stream()
       │
       ├─ .opus → _decode_opus_via_ffmpeg() → ffmpeg → AudioStreamWAV (PCM ~46MB)
       │   └─ Android: fallback a .ogg → AudioStreamOggVorbis
       │
       ├─ .ogg → AudioStreamOggVorbis.load_from_file() (~5MB compressed)
       │   (funciona en desktop + Android)
       │   └─ Si falla → ResourceLoader.exists()? → load()
       │       └─ fallback → FileHelper.read_file() → AudioStreamOggVorbis.new()
       │
       └─ .wav/.mp3 → ResourceLoader.exists()? → load()
           └─ fallback → FileHelper.read_file() → AudioStreamWAV
```

### Preview de canciones en el menú

Al seleccionar una canción en la lista del menú principal (`MenuRoot.gd`), se reproduce automáticamente un preview de la canción. El sistema usa `preview.opus` si existe en la carpeta de la canción, con fallback a `song.ogg`.

**Flujo de reproducción (step-by-step):**

```
_usuario toca SongRow
  │
  ├─ _on_song_row_input()
  │   ├─ InputEventScreenTouch.pressed → registra posición
  │   ├─ InputEventScreenTouch.release → si no hubo drag → _select_song()
  │   ├─ InputEventScreenDrag → si distance > 8px → _row_dragging = true (cancela)
  │   └─ InputEventMouseButton / InputEventMouseMotion → misma lógica (desktop)
  │
  └─ _select_song(original_index)
      ├─ Si misma canción ya seleccionada → return (sin recargar)
      ├─ _selected_song_index = original_index
      ├─ _update_selection_ui()          ← pone "► " en la fila seleccionada
      ├─ _update_status_for_song()       ← "STATUS: chart OK - audio OK"
      ├─ _update_difficulty_visibility() ← habilita/deshabilita botones
      ├─ _load_album_art(original_index) ← carga carátula en HeaderBar
      └─ _start_preview_animation(original_index)
```

**Inicio de animación (`_start_preview_animation()`):**

```
_start_preview_animation()
  ├─ _stop_preview()                    ← detiene cualquier preview anterior + thread
  ├─ _resolve_preview_path(song)
  │   ├─ Si song tiene "preview_path" → usar ese
  │   └─ Sino → SongLoader.get_stem_path(song.path, "song")
  │       (resulta en song.opus / song.ogg / song.wav / song.mp3)
  ├─ Si preview_path vacío → return (no hay preview)
  ├─ _preview_needs_load = true         ← flag: _process() debe cargar
  ├─ _preview_loaded_stream = null
  ├─ _preview_animating = true
  ├─ _preview_anim_frame = 0            ← "."
  ├─ _preview_anim_delay = 1.5          ← 1.5s antes de play real
  └─ PreviewStatusLabel.text = "."
```

**Proceso frame-by-frame (`_process()`):**

```
_process(delta)
  │
  ├─ SI _preview_animating:
  │   ├─ Dots animation: timer += delta, avanza frame cada 0.3s
  │   │
  │   ├─ Si _preview_needs_load:
  │   │   ├─ Buscar en _preview_cache (LRU) → si hit, stream listo
  │   │   └─ Si miss:
  │   │       ├─ Android: AudioManager._load_audio_stream() síncrono
  │   │       │   (mismo patrón que GameplayRoot que ya funciona)
  │   │       └─ Desktop: Thread.new().start(_preview_load_func)
  │   │           (carga asíncrona, NO bloquea hilo principal)
  │   │
  │   ├─ Si _preview_load_done (thread terminó, solo desktop):
  │   │   ├─ _preview_loaded_stream = _preview_load_result
  │   │   ├─ _preview_thread.wait_to_finish()
  │   │   ├─ _cache_stream(path, stream)  ← agrega al cache LRU
  │   │   └─ Delay adaptativo: si delay > 0.3s → reducir a 0.3s
  │   │
  │   └─ _preview_anim_delay -= delta
  │       ├─ delay > 0.0: espera (dots siguen animando)
  │       └─ delay <= 0.0:
  │           ├─ stream != null → _play_preview()
  │           └─ stream == null:
  │               ├─ timeout > 0 → timeout -= delta, delay = 0.0
  │               └─ timeout <= 0 → "Preview unavailable"
  │
  └─ SI _preview_player.playing:
      ├─ _preview_elapsed += delta
      └─ Si elapsed >= 30s → _stop_preview() + "Preview ended"
```

**Reproducción (`_play_preview()`):**

```
_play_preview()
  ├─ Si player está sonando → _preview_player.stop()
  ├─ _preview_player.stream = stream
  ├─ _preview_player.volume_db = linear_to_db(SettingsManager.preview_volume)
  ├─ _preview_player.play()                 ← en bus "Music"
  ├─ _preview_elapsed = 0.0                 ← reset timer duración
  ├─ Si no hay preview_path (usando song.ogg):
  │   ├─ preview_start_time > 0 → seek a preview_start_time / 1000 (ms→s)
  │   ├─ preview_start_time <= 0 o null → seek a segundo 30
  │   └─ Inicia carga asíncrona de stems (drums, bass, guitar, keys, rhythm, vocals)
  │       ├─ Desktop: en Thread separado
  │       ├─ Android: síncrono
  │       └─ Al terminar: crea AudioStreamPlayer por cada stem
  │           con volume_db = linear_to_db(preview_volume * 0.5),
  │           play() y seek() sincronizado al playback_position actual
  └─ PreviewStatusLabel.text = "♫  Queen - Bohemian Rhapsody"
```

**Detención:**

```
_stop_preview()                              ← llamado al:
  ├─ _preview_animating = false               ├─ cambiar a otra canción
  ├─ _preview_pending_index = -1              ├─ abrir settings
  ├─ _preview_needs_load = false              ├─ cambiar texto de búsqueda
  ├─ _preview_loaded_stream = null            ├─ presionar dificultad (iniciar juego)
  ├─ Thread.wait_to_finish() si activo        ├─ _exit_tree() (cerrar app)
  ├─ _preview_player.stop()                   ├─ preview > 30s (duración límite)
  ├─ _preview_player.stream = null            └─ _stop_preview() explícito
  ├─ _preview_elapsed = 0.0
  └─ PreviewStatusLabel.text = ""
```

**Árbol de nodos del preview:**

```
MenuRoot (CanvasLayer)
  ├── PreviewStatusLabel (Label)    ← ". → .. → ... → ♫  Artist - Song"
  ├── PreviewPlayer (AudioStreamPlayer)  ← bus = "Music"
  ├── StemPlayer_n (AudioStreamPlayer)   ← bus = "Music" (0..N, por cada stem cargado)
  ├── Thread (_preview_thread)      ← carga async de preview principal
  └── Thread (_preview_stem_thread) ← carga async de stems (solo fallback)
```

**Consideraciones técnicas:**

- **Android `res://` fix:** en builds Android exportados, los archivos en `res://Songs/` están empaquetados en el PCK. `FileHelper.file_exists()` (basado en `FileAccess.open()`) no puede leerlos directamente. `SongLoader.get_stem_path()` y `_scan_song()` usan `FileHelper.file_exists() OR ResourceLoader.exists()` para encontrar archivos tanto en almacenamiento externo (`FileAccess`) como en `res://` empaquetados (`ResourceLoader`). `AudioManager._find_stem_file()` ya usaba ambos; el fix unifica el patrón en `SongLoader` para que el preview y la detección de metadatos funcionen igual que el gameplay.
- **Lazy loading:** las canciones no se precargan al inicio. Cada preview se carga bajo demanda al seleccionar, evitando OOM en Android con 30+ canciones.
- **Carga por plataforma:** en desktop, `_load_audio_stream()` se ejecuta en un `Thread` separado via `_preview_load_func()` (no bloquea el hilo principal). En Android, se ejecuta síncronamente en `_process()` (mismo patrón que `GameplayRoot._start_loading()` que ya funciona en Android).
- **Cache LRU:** los streams cargados se almacenan en `_preview_cache` (Dictionary path→AudioStream) con máximo `PREVIEW_CACHE_MAX = 5` entradas. Al scrollear entre canciones previamente escuchadas, la carga es instantánea (~25MB con .ogg nativo).
- **Delay adaptativo:** si el stream carga antes de que expire el delay de 1.5s, se reduce a `PREVIEW_ANIM_INTERVAL` (0.3s = un frame de dots). Con .ogg nativo (~10ms de carga), el preview arranca en ~0.3s en lugar de1.5s.
- **`.ogg` nativo:** `AudioStreamOggVorbis.load_from_file()` se usa en todas las plataformas (desktop + Android). Si falla, el fallback usa `FileHelper.read_file()` → `AudioStreamOggVorbis.new()`. En desktop, `load_from_file()` carga ~5MB compressed en lugar de ~46MB PCM (ffmpeg).
- **Limpieza de referencia:** `_stop_preview()` pone `_preview_player.stream = null` para liberar el AudioStream inmediatamente en lugar de esperar a que `_play_preview()` lo reemplace.
- **Duración limitada:** el preview se detiene automáticamente tras `PREVIEW_MAX_DURATION = 30s`. Evita reproducir la canción completa como preview.
- **Seek por preview_start_time:** cuando se usa `song.ogg` como fallback (sin `preview.ogg`), se aplica `_preview_player.seek()` al valor de `preview_start_time` de `song.ini` dividido por 1000 (está en milisegundos, seek usa segundos). Si el valor es -1, 0 o null, se busca al segundo 30. Con `preview.ogg` se reproduce desde el inicio (0s).
- **Stems en fallback:** al usar `song.ogg` como fallback, también se cargan los stems individuales (`drums.ogg`, `guitar.ogg`, `bass.ogg`, `keys.ogg`, `rhythm.ogg`, `vocals.ogg`) si existen. Se crea un `AudioStreamPlayer` por cada stem encontrado en el bus `"Music"` con volumen a 0.5× `preview_volume`. La carga es asíncrona (thread en desktop, síncrona en Android). Los stems se sincronizan con `_preview_player.get_playback_position()` para mantener coherencia temporal.
- **Android .opus skip:** en Android, `_resolve_preview_path()` ignora archivos `preview.opus` (ffmpeg no disponible) y cae a `song.ogg` via `get_stem_path()`. En desktop, `.opus` se decodifica normalmente. `SongLoader.get_stem_path()` usa `FileHelper.file_exists() OR ResourceLoader.exists()` para encontrar archivos tanto en almacenamiento externo como en `res://` empaquetados.
- **Timeout de carga:** si el stream no carga en `PREVIEW_LOAD_TIMEOUT = 5s`, la animación se detiene y muestra "Preview unavailable". Evita el loop infinito de dots en caso de error.
- **Anti-spam táctil:** `_select_song()` tiene early-return si la canción ya está seleccionada (`original_index == _selected_song_index`). `_on_song_row_input()` usa `InputEventScreenTouch` para distinguir tap de drag (threshold 8px).
- **Dots animation:** 3 frames (`.`, `..`, `...`) alternando cada 0.3s. Delay mínimo de 0.3s (un frame) para feedback visual, máximo 1.5s.
- **Fallback:** en desktop se usa `preview.opus` si existe (decodificado via ffmpeg). En Android se ignora `preview.opus` y se usa `song.ogg`. Si el stream no carga, el timeout de 5s muestra "Preview unavailable".
- **Volumen:** controlado por `SettingsManager.preview_volume` (default 0.8), aplicado como `linear_to_db()`.
- **Cleanup:** `_exit_tree()` llama `_stop_preview()` que espera al thread (si existe) y libera todos los recursos al cerrar la app.

En cada `miss`, `Lane.gd` llama a `AudioManager.duck_drums(-12 dB, 0.5 s)`. Solo afecta al stem `"drums"`. Si no existe stem de batería (canciones sin pista separada), no hace nada.

### SFX

`EffectManager` genera dos tonos programáticamente:

- **Hit:** 880 Hz, 80 ms, envelope linear descendente, −6 dB
- **Miss:** 220 Hz, 150 ms, envelope linear descendente, −9 dB

Se crean como `AudioStreamWAV` con datos PCM calculados en `_generate_beep()`.

---

## Gráficos vectoriales (DrumGraphics)

Todas las texturas de notas y hit lines se generan en código en lugar de usar bitmaps.

### Tamaño de textura

128×128 píxeles, formato `RGBA8`, fondo transparente.

### Formas por lane

| Lane | Parte | Forma de nota | Forma de hit line |
|---|---|---|---|
| 0 | HH Closed & Open | **double cymbal** — dos círculos solapados con vástago | dos semicírculos sobre barra |
| 1 | Crash | **cymbal** — círculo con soporte | semicírculo sobre barra |
| 2 | Snare | **drumstick** — baqueta vertical con punta | baqueta horizontal |
| 3 | Kick | **pedal** — rectángulo curvo con bisagras | pedal pequeño sobre barra |
| 4 | Tom 1 | **drumstick** | baqueta horizontal |
| 5 | Tom 2 | **drumstick** | baqueta horizontal |
| 6 | Tom 3 | **drumstick** | baqueta horizontal |
| 7 | Ride | **cymbal** | semicírculo sobre barra |

### Primitivas de dibujo

`DrumGraphics` implementa `_fill_circle()`, `_fill_rect()`, `_fill_round_rect()` directamente sobre un `Image`, operando píxel por píxel. No usa `_draw()` de `CanvasItem` ni texturas externas.

---

## Layout de pantalla

Basado en el `README.md` — ASCII GAMEPLAY REFERENCE.

```
y=0%    +---------------------------------------+
        |             SONG TIMELINE             |
y=2.5%  +----+----+----+----+----+----+----+----+
        | multiplier   |    |    |    |   score |  ^
        |    |    |    |  combo  |    |    |    |  |
        |    |    |    | accuracy|    |    |    |  highway (62.5%)
        |    (notas scrolleando hacia abajo)    |  |
        |    |    |    |    |    |    |    |    |  v 
y=65%   +----+----+----+----+----+----+----+----+
        |    |    |    |    |    |    |    |    |  ← hit line (per-lane)
y=72%   +----+----+----+----+----+----+----+----+  
        | HH | CR | SN | KI | T1 | T2 | T3 | RI |  ← lane labels
y=100%  +----+----+----+----+----+----+----+----+
```

- **Timeline:** 0–2.5 % (barra de progreso horizontal)
- **Highway:** 2.5–65 % (lienzo de notas)
- **Hit line:** 65-72 % (una sección por lane con icono del instrumento)
- **Labels:** 72-100 % (nombre corto del instrumento por lane + zona táctil)
- **HUD:** superpuesto (score, combo, multiplier)

### Gameplay padding (experimental)

Cuando `gameplay_padding_enabled` está activo, el Highway se posiciona en `(pad_left, pad_top)` y `screen_w`/`screen_h` se reducen a las dimensiones efectivas (`viewport - pad_left - pad_right`, `viewport - pad_top - pad_bottom`). Esto desplaza automáticamente lanes, notas, hit line, beat lines y touch zones. El HUD (CanvasLayer) se ajusta manualmente sumando los paddings individuales a los offsets de cada label. Cada lado se configura independientemente con un slider (0-100dp, default left/right=75, top/bottom=0). Los valores se almacenan en dp (density-independent pixels) y se convierten a píxeles lógicos de Godot al aplicarse. Solo disponible en Android — en desktop la UI se muestra deshabilitada.

### Android gesture exclusion (plugin nativo)

En Android, la navegación por gestos intercepta toques en los bordes de la pantalla antes de entregarlos a la app, causando delay en los toques de HH (lane 0) y RIDE (lane 7). Para mitigar esto, el proyecto incluye un plugin Android mínimo que llama a `View.setSystemGestureExclusionRects()` para excluir los bordes laterales del back gesture.

**Flujo:**
1. `Highway._build_lanes()` → llama a `AndroidBridge.set_lane_exclusion()` después de construir touch zones
2. `AndroidBridge` obtiene el singleton `GestureExclusion` vía `Engine.get_singleton()`
3. El plugin Java calcula los rectángulos de exclusión (max 200px por borde, max 4 rects)
4. Al salir del gameplay (`_exit_to_menu`, `stop_gameplay`) → `AndroidBridge.clear_exclusion()`
   - **Nota:** `_restart_song()` NO llama a `clear_exclusion()` porque no reconstruye lanes — las posiciones no cambian, los rects siguen siendo válidos

**Independencia del padding:** La exclusión de gestos funciona siempre que el plugin esté compilado y habilitado, independientemente de `gameplay_padding_enabled`. Los rects cubren los bordes de los lanes exteriores (HH y RIDE) para evitar interferencia del back gesture. Cuando el padding está desactivado, `pad_x` y `pad_y` son 0, pero los rects siguen cubriendo las zonas correctas.

**Limitaciones de la API Android:**
- `setSystemGestureExclusionRects()` solo afecta el **back gesture** (swipe lateral), NO el home/recents (swipe inferior)
- Máximo 200px desde cada borde, máximo 4 rectángulos
- El sistema puede ignorar los rects si detecta abuso
- En desktop/iOS, `AndroidBridge` es no-op

**Auto-habilitación en Android:** En el primer arranque (sin archivo de settings), `gameplay_padding_enabled` se establece automáticamente en `true` en Android para mitigar el problema de bordes.

**Prerequisitos para build:**
1. Instalar Android Build Template: `Project → Install Android Build Template...`
2. Habilitar Gradle build: `gradle_build/use_gradle_build=true` en export settings
3. Java 17 JDK instalado (Gradle 8.11.1 + AGP 8.6.1 no soportan Java <11 ni >22)
4. Compilar el `.aar` del plugin desde `GestureExclusionPlugin/` con Gradle:
   ```
   JAVA_HOME=/usr/lib/jvm/jdk-17.0.12-oracle-x64 ./gradlew :plugin:assembleDebug
   ```
5. Copiar `plugin/build/outputs/aar/plugin-debug.aar` → `addons/GestureExclusion/bin/debug/GestureExclusion.aar`
6. Habilitar plugin en `Project Settings → Plugins`

**Estructura del plugin (dos scripts):**
- `plugin.cfg` → apunta a `plugin_main.gd` (extends `EditorPlugin`)
- `plugin_main.gd` → wrapper que registra el export plugin via `add_export_plugin()`
- `export_plugin.gd` → (extends `EditorExportPlugin`) maneja inclusión del `.aar` en exports Android

**Nota sobre paths:** `_get_android_libraries()` retorna paths relativos a `res://addons/`, por lo que deben incluir el prefijo del directorio del plugin (`GestureExclusion/bin/debug/...`).

**Plugins deben estar registrados en `project.godot`:** el paso 6 ("Habilitar plugin en Project Settings → Plugins") no es opcional — sin escribir el `plugin.cfg` en `[editor_plugins] enabled=PackedStringArray(...)`, el `EditorExportPlugin` nunca se instancia, `_get_android_libraries()` no se llama, y el `.aar` no entra al APK. El síntoma es silencioso: `Engine.has_singleton("GestureExclusion")` devuelve `false` y la función affected queda como no-op sin ningún error.

### Android All files access (plugin nativo)

`MANAGE_EXTERNAL_STORAGE` está declarado en `export_presets.cfg` pero **no se concede solo**. No es un *dangerous permission* del modelo de runtime de Android (no se concede vía `requestPermissions()` ni `OS.request_permissions()`), sino un permiso especial de AppOps que el usuario activa en Ajustes del sistema. Además con `gradle_build/use_gradle_build=false` el template prebuilt no pide nada por su cuenta.

El plugin `AllFilesAccess` expone en GDScript:
- `has_all_files_access()` → `Environment.isExternalStorageManager()` (API 30+; en `< 30` devuelve `true`, donde `READ/WRITE_EXTERNAL_STORAGE` ya bastan)
- `requestAllFilesAccess()` → lanza el intent `Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION` apuntando al propio paquete, con fallback a `ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION`
- `isPathReadable(path)` / `isDirectory(path)` → `File.canRead()` / `File.isDirectory()`, más fiable que `DirAccess` bajo scoped storage

Concedido el permiso, `DirAccess` y `FileAccess` funcionan sobre rutas absolutas de `/storage/emulated/0/...` (All files access ignora scoped storage), que es lo que permite escanear bibliotecas de canciones arbitrarias sin copiarlas. El fallback `content://` de `FileHelper` queda como red de seguridad para cuando el permiso no está concedido.

**Prerequisitos para build** (idénticos a `GestureExclusion`): Android Build Template instalado, JDK 17, y compilar desde `AllFilesAccessPlugin/`:
```
./gradlew :plugin:assembleDebug
./gradlew :plugin:assembleRelease
```
y copiar los `.aar` a `addons/AllFilesAccess/bin/{debug,release}/AllFilesAccess.aar`.

**Nota de toolchain:** el build usa `compileSdk = 34` con `buildToolsVersion = "37.0.0"` (el SDK instalado no tiene build-tools 34.0.0) y AGP 8.5.2.

### Spawn de notas

`Highway._process()` mantiene un cursor `_next_note_index` que avanza secuencialmente sobre `ChartParser.note_data`. Cada nota se encola **una sola vez** cuando entra en la ventana de spawn (`current_time + 2.0s`), evitando escanear todo el arreglo cada frame.

### Cálculo de posición de nota

```
lane_w = screen_width / lane_count
x = lane_w * lane_index + lane_w / 2
scroll_distance = (highway_bottom_y - highway_top_y) * note_speed  (0.625 × note_speed por defecto)
y_offset = (note_time - current_time) * scroll_distance / 2.0
y = hit_line_y - y_offset
```

El juicio se calcula usando el **tiempo** de la nota (no su posición visual). El `ColorRect` de la nota es `lane_w × 0.95` de ancho por `lane_w × 0.25` de alto, centrado en la posición calculada. El judgment usa `note_data.time - current_time` (delta temporal del centro de la nota), no el solapamiento visual con las bandas de juicio.

---

## Countdown entre notas

El juego muestra un countdown cuando hay un silencio prolongado entre notas. Cubre dos casos:

- **Intro de canción:** cuando la primera nota está lejos del inicio.
- **Silencios internos:** cuando hay un gap largo entre notas consecutivas.

Ambos casos usan el mismo código en `GameplayRoot.gd:_on_countdown_update()`.

### Comportamiento

Cada frame, `GameplayRoot._on_countdown_update()` (conectado a `TimingEngine.time_updated`):

1. Busca la siguiente nota ejecutable vía `ChartParser.find_next_note_index(time_sec)` (búsqueda binaria, O(log n)).
2. Calcula `remaining = next_note.time - current_time`.
3. Si `remaining > countdown_threshold (5s)` y la nota aún no es visible (está a más de `NOTE_TRAVEL_TIME = 2.0s` de distancia), muestra `"X.X s"`.
4. En cuanto la nota entra en la ventana de spawn (≤ 2.0s), el countdown desaparece automáticamente.

### Visual

`CountdownLabel` (CanvasLayer, layer 5) es un overlay centrado con:
- **Título:** "Next notes in" (fuente 24px, semitransparente)
- **Temporizador:** `"%.1f s"` (fuente 64px, blanco con sombra)

Se instancia dinámicamente desde `GameplayRoot` y se destruye al ocultarse. No tiene pooling porque solo existe una instancia a la vez.

### Archivos involucrados

| Archivo | Rol |
|---|---|
| `scene/UI/CountdownLabel.tscn` | Escena del overlay |
| `script/ui/CountdownLabel.gd` | Clase `CountdownLabel` (CanvasLayer) |
| `script/gameplay/GameplayRoot.gd` | Lógica de activación/actualización vía `time_updated` |
| `script/autoload/ChartParser.gd` | `find_next_note_index()` — búsqueda binaria |
| `script/autoload/SettingsManager.gd` | `countdown_threshold` — persistencia |

### Umbral configurable

`SettingsManager.countdown_threshold = 5.0` — se persiste en `user://settings.cfg` como `gameplay/countdown_threshold`.

### NOTE_TRAVEL_TIME

Constante `NOTE_TRAVEL_TIME := 2.0` en `GameplayRoot.gd`. Coincide con la ventana de spawn de notas en `Lane._spawn_pending()`. Si se modifica la velocidad del highway en el futuro, basta con actualizar esta constante.

### Arquitectura

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

## Fin de canción

### Qué marca el final

La canción termina con el **audio**, no con las notas. `GameplayRoot._start_loading()` pasa a `TimingEngine.start(ChartParser.get_duration_seconds(), delay)`, y esa duración es `max(última nota, duración real del audio)`: las notas suelen acabar antes que la música y la barra de tiempo tiene que llegar al 100 % con el audio todavía sonando.

`TimingEngine._process()` declara el fin en cuanto se cumple cualquiera de estas dos condiciones:

1. `audio_position >= chart_duration` (caso normal, y también el caso sin audio, donde el reloj avanza con delta).
2. `AudioManager.is_stream_finished()`: el stream base llegó a su final aunque `_is_playing` siga en `true`.

La segunda cubre el `song.ini` con una duración equivocada: sin ella el reloj se quedaba clavado en la posición del último sample y `song_ended` no llegaba nunca.

Antes de emitir, `audio_position` se clampa a `chart_duration`, así que el último `time_updated` lleva el valor exacto de fin de canción y la `SongTimeline` queda al 100 %.

#### Cómo se detecta el final del stream (y por qué no se lee la posición)

`AudioManager.is_stream_finished()` devuelve un latch que enciende la **señal `finished`** del player del stem base (`_on_stem_finished`), no una consulta al player. Es la única forma fiable, porque en el frame exacto en que el stream acaba las dos consultas disponibles mienten:

| Consulta | Al final natural del stream | Motivo |
|---|---|---|
| `player.get_playback_position()` | devuelve **0.0** | Godot reinicia la posición al terminar el stream |
| `player.playing` | `false` | …pero también es `false` con `stream_paused`, así que un `stop()` de la pausa parecería un final de canción |

La posición a 0 es lo que rompía el flujo: una guarda del tipo `raw_position > 0.0 and is_stream_finished()` nunca se cumplía en el frame del final (0 no es > 0), así que el reloj saltaba a ~0, `audio_position >= chart_duration` no volvía a darse y **la canción se quedaba colgada sin llegar nunca a `song_ended`**. La señal `finished` solo se emite al acabar el stream de forma natural: ni `stop()` ni la pausa la emiten, así que no hay falsos positivos al pausar, reiniciar o cambiar de canción. El latch se rearma en `AudioManager.play()`.

Para que el reloj y el final hablen siempre del mismo stream, `get_position()`, `get_length()` e `is_stream_finished()` resuelven el stem base con `_base_stem_name()`.

### Reloj congelado

`TimingEngine` tiene dos guardas además de `_paused`:

| Guarda | Qué significa | La pone / la quita |
|---|---|---|
| `_running` | El reloj corre entre `start()` y `stop()`. Arranca en `true` para que el tiempo fluya también en el menú. | `start()` / `stop()` |
| `_finished` | El fin ya se anunció; no se vuelve a emitir `song_ended`. | `_finish()` / `start()` |

Sin `_running`, `stop()` dejaba el reloj en su rama de `audio_position += delta` (ya no hay ni pausa ni audio reproduciéndose) y la barra de tiempo volvía a llenarse desde cero por debajo de la pantalla de resultados.

### Secuencia hasta la pantalla de resultados

```
TimingEngine._process()   audio_position >= chart_duration
  → _finish()                                  (una sola vez)
    → song_ended
      → GameplayRoot._on_song_ended()
        → await RESULT_TAIL_DELAY (0.5 s)      (estado aún PLAYING)
          → GameplayRoot._show_result()
            → Highway.flush_unjudged_notes()   (notas sin juzgar = misses)
            → GameManager.set_state(RESULT)
              → GameplayRoot._on_state_changed()
                → TimingEngine.stop()           (reloj y audio congelados)
            → ResultOverlay (CanvasLayer, layer 15)
```

Durante el margen de 1.5 s el estado sigue siendo `PLAYING`: el jugador todavía puede acertar las notas que quedaron dentro de la ventana de golpe, y el reloj no avanza (ya está en `_finished`).

### Notas sin juzgar

`Highway.flush_unjudged_notes()` → `Lane.flush_as_miss()` cuenta como falladas las notas que siguen en pantalla. Sin audio, `chart_duration` coincide con la última nota, así que esas notas nunca pasan por la ventana de miss de `Lane._update_active()` y el recuento final quedaría corto. No muestran popup de juicio: no hubo golpe que juzgar.

No es lo mismo que `Highway.restart()`, que descarta las notas sin puntuar (replay).

### Pantalla de resultados

`ResultOverlay` (CanvasLayer, layer 15) se construye entero por código e imprime `ScoreManager` (score, precisión, combo máximo, hits/misses) más el título de la canción y la dificultad. Emite `retry_requested` y `exit_requested`; el callback es `GameplayRoot._restart_song()` / `_exit_to_menu()`. El overlay de pausa vive en la layer 10 y el de carga en la 20.

`AndroidBridge.clear_exclusion()` **no** se llama al terminar: seguimos dentro del gameplay y las zonas táctiles no han cambiado. Solo se limpia al salir (`_exit_to_menu`, `stop_gameplay`).

El botón de atrás (Android y `ui_cancel`) pasa por `GameplayRoot._handle_back()`: con el panel visible sale al menú, si la canción ya terminó pero el panel todavía no aparece no hace nada, y en cualquier otro caso pausa.

### Archivos involucrados

| Archivo | Rol |
|---|---|
| `script/autoload/TimingEngine.gd` | Guardas `_running` / `_finished`, clamp y `_finish()` |
| `script/autoload/AudioManager.gd` | `is_stream_finished()` — latch de la señal `finished` del stem base, y `_base_stem_name()` |
| `script/gameplay/GameplayRoot.gd` | `song_ended` → tail → `RESULT` → overlay; `RESULT_TAIL_DELAY` |
| `script/ui/ResultOverlay.gd` | Panel de resultados |
| `script/gameplay/Highway.gd` / `Lane.gd` | `flush_unjudged_notes()` / `flush_as_miss()` |
| `script/autoload/GameManager.gd` | `current_song_title` / `current_song_artist` para el panel |

### Test

```
godot --headless --path . res://tools/test_song_end.tscn   # reloj + overlay + audio real
godot --headless --path . res://tools/test_song_end_e2e.tscn # escena Gameplay.tscn de verdad
```

`test_song_end` cubre: `song_ended` se emite una sola vez, el reloj se detiene en `chart_duration`, la barra no se vacía tras `stop()`, `start()` rearma el reloj, el panel vuelca los stats de `ScoreManager` y —con los stems reales de una canción— que el fin de stream se detecta aunque la posición vuelva a 0, que la pausa no lo dispara y que una segunda pasada vuelve a terminar.

`test_song_end_e2e` monta `scene/Gameplay.tscn` con una canción real, la deja llegar al final (saltando el player cerca del final) y comprueba la cadena completa: `PLAYING` → `song_ended` → cola de 1.5 s → `RESULT` → `ResultOverlay` en pantalla con los datos de la partida, y que **REPLAY** vuelve a jugar y desmonta el panel.

---

## Sistema de entrada

### Táctil / mouse

`TouchInput._input()` maneja `InputEventScreenTouch` y `InputEventMouseButton`. Convierte la coordenada X a lane index así:

1. **Posición local**: `_get_highway_local_pos()` transforma coordenadas de pantalla al espacio local del highway (Node2D).
2. **Columna visual**: `_touch_to_lane()` divide `pos.x` por el ancho del carril, donde `lane_w = highway.screen_w / lane_count`.  
   Esto usa el ancho real del viewport (`get_viewport_rect().size.x`) propagado por `Highway.screen_w`, no el valor estático `display/window/size/viewport_width`.
3. **Resolución lógica**: el índice de columna visual se mapea al `lane_index` lógico real a través de `highway.lane_nodes[visual_idx].lane_index`, garantizando el funcionamiento correcto con órdenes de lane alternativos (Haptic y Custom mode).

**Protección Android**: En dispositivos táctiles (`DisplayServer.is_touchscreen_available()`), se salta el bloque `InputEventMouseButton` para evitar que el evento de mouse emulado por Android duplique el procesamiento del mismo toque. Sin esta guarda, el segundo evento (mouse emulado) encuentra la nota ya eliminada por el primer evento (touch), causando que `try_hit_lane()` retorne `false` y reproduzca `DrumSfxManager.play_for_lane()` incorrectamente.

**Optimización de rendimiento**: Las llamadas a `EffectManager.trigger_particle_burst()` y `EffectManager.show_judgement()` dentro de `Lane.try_hit()` se ejecutan mediante `call_deferred()`. Esto saca la creación de nodos de efectos visuales de la fase de `_input()` y las mueve al final del frame, evitando bloqueos del frame en dispositivos móviles cuando el jugador toca la pantalla. La lógica crítica (hit detection, scoring, audio) permanece sincrónica.

**Touch zones cacheadas**: Las zonas táctiles (`TouchZone_*`) se cachean en `_touch_zones` (Array[ColorRect]) durante `setup()` mediante `_cache_touch_zones()`. Cada zona almacena su `lane_idx` en metadata (`set_meta("lane_idx", ...)`) para evitar búsqueda por nombre y parseo de strings en `_update_touch_zones()`. El array cacheado se actualiza solo si se reconstruyen los lanes.

**Señal `lane_pressed`**: `TouchInput` emite `lane_pressed(lane_index, position)` en
las tres rutas de entrada (teclado, touch y mouse), justo antes de la llamada a
`HitDetection`. Sirve para que quien monta la escena reciba el golpe aunque no
haya hit detection, que es el caso del modo libre (ver *Modo libre*).

**Hit detection opcional**: las llamadas a `HitDetection` comprueban que el
`_hit_detection` no sea `null`, para permitir montar `TouchInput` sin nodo de
judgement. Con `null` solo suena el sample del pad.

### InputManager

`InputManager.handle_touch_event()` recibe el `lane_index` ya resuelto desde `TouchInput` y evita recalcularlo.

### Teclado (desktop)

Teclas **1–8** del teclado numérico mapean a lanes **0–7**. Implementado en `TouchInput._input()` como `InputEventKey`, llama a `HitDetection.try_hit_lane()` exactamente igual que el input táctil.

### Hit detection optimizada

`Lane.try_hit()` incluye una optimización para reducir el loop de búsqueda: solo considera notas cuyo tiempo esté dentro del rango `[current_time - miss_ms, current_time + miss_ms]`, saltándose notas demasiado tempranas o tardías que no podrían ser acertadas de todas formas. Esto evita recorrer todo el arreglo de notas activas cuando hay acumulación de notas en el highway.

### Kick háptico (acelerómetro)

`HapticKick.gd` se conecta a `InputManager.kick_detected`. El pipeline de detección está en `InputManager._process()`:

1. **Sensor**: `Input.get_accelerometer()` en el eje +Z del dispositivo (normal de la pantalla, `Vector3.BACK`). Fallback a `Input.get_gravity()` si el acelerómetro devuelve ceros.
2. **Gravity removal**: `linear_accel = filtered_accel - gravity_estimate`. La gravedad se obtiene de `Input.get_gravity()` o de un filtro pasabajos sobre el acelerómetro.
3. **Smoothing**: Filtro exponencial `lerp_factor = 1.0 - pow(1.0 - strength, delta * 60.0)`, default `strength = 0.4`.
4. **Detección en dos fases**:
   - **Lift**: cuando `toward > eff_activation` se marca `_lift_detected` (con `eff_activation = haptic_activation_threshold / sensitivity`).
   - **Abort**: si `toward < eff_release` antes del cruce por cero, se resetea `_lift_detected`.
   - **KICK**: cuando `toward <= 0.0` y `_lift_detected` es true, se dispara `kick_detected`. Así el kick ocurre al inicio del retorno.
5. **Calibración**: al empezar la canción, captura la orientación actual (~0.5 s si hay sensor de gravedad, ~1.5 s si no). Eje de detección siempre es `Vector3.BACK` (no depende de la orientación).

---

## Bibliotecas de canciones externas

Además de las canciones empaquetadas en `res://Songs/`, el jugador puede apuntar el juego a bibliotecas propias (Clone Hero, YARG, Rock Band, Phase Shift) **sin copiar los archivos**: se referencian in situ.

### Raíces de escaneo

`SongLoader.get_scan_roots()` construye la lista de raíces, en este orden:
1. `res://Songs` (siempre)
2. `get_user_song_dir()` — la carpeta propia de la app (se crea si no existe)
3. `SYSTEM_DIR_DOWNLOADS` y/o `SYSTEM_DIR_DOCUMENTS`, según `library_preset_downloads` / `library_preset_documents`
4. `SettingsManager.library_roots` — rutas tecleadas por el usuario

Todas pasan por `_append_root()`, que las normaliza con `simplify_path()` y descarta duplicados. Las rutas relativas se expanden con `ProjectSettings.globalize_path()`.

En primera ejecución en Android los presets se activan solos (junto a `gameplay_padding_enabled`); en desktop arrancan desactivados para no escanear `~/Downloads` sin que el usuario lo pida. Configuración persistida en la sección `[library]` de `user://settings.cfg`: `roots`, `preset_downloads`, `preset_documents`, `recursive`, `max_depth`.

### Recorrido

El recorrido es **interrumpible**: `SongLoader` no tiene una función recursiva que barra el disco entero de una sentada, sino un recorrido por lotes que la UI avanza frame a frame.

- `begin_scan()` deja `SongLoader` listo (limpia `song_list` y el diagnóstico, calcula las raíces) y devuelve `false` si ya había un escaneo en marcha. Como es singleton solo admite uno: el segundo llamante espera, no machaca la lista a medio construir.
- `scan_step(dir_budget, deadline_usec)` camina hasta `dir_budget` directorios o hasta pasar `deadline_usec`, y devuelve `true` cuando el escaneo ha terminado.
- `pump_scan(deadline_usec)` es el atajo para quien tiene UI delante: un frame de escaneo con `MAX_DIRS_PER_FRAME` (64) y `SCAN_FRAME_BUDGET_MS` (8), y devuelve `true` solo cuando no queda nada pendiente —ni escaneo en marcha ni otro encolado detrás—. El escaneo se sirve, se pausa o se cancela en un frame, no en un bloque.
- `request_scan()` encola un escaneo para cuando `SongLoader` quede libre (Ajustes pidiendo un reescaneo mientras el menú escanea). `abort_scan()` es la salida de emergencia: limpia la petición y cierra el escaneo a medias, para que `is_scanning` nunca quede en `true` y bloquee el siguiente.
- `scan_songs()` es el modo de una sentada (`scan_step` sin tope) para los tests y cualquier llamante sin UI que responder.
- `cancel_scan()` se respeta en el siguiente lote, como muy tarde un frame después. Lo ya encontrado se queda en `song_list`, y `scan_finished` sale con `cancelled = true`.

El estado del recorrido vive en una pila explícita (`[ruta, profundidad]`), no en la recursión de GDScript: así un lote puede cortarse entre directorios sin dejar frames a medias en la pila. El orden de visita es el mismo que con recursión (las subcarpetas se apilan invertidas para salir en orden alfabético), y una raíz solo se cierra —y con ella su marca de truncado— cuando la pila se vacía (`_close_current_root()`).

`_scan_one_dir()` es el cuerpo del recorrido y devuelve solo por estado:

- Una carpeta es canción si contiene `notes.mid` o `notes.chart` como **hijo directo**. Si lo es, se registra y **no** se desciende en ella.
- Si no, se desciende a sus subdirectorios hasta `library_max_depth` (por defecto 3). Al agotar la profundidad se marca `_depth_truncated`.
- Las entradas que empiezan por `.` se ignoran.
- `_scanned_paths` deduplica por ruta canónica, así que raíces solapadas (p. ej. `Download/` y `Download/MiLib/`) no producen canciones duplicadas, y los symlinks que formen ciclos no cuelgan el escaneo.
- `MAX_DIRS_PER_ROOT` (4000) cota el trabajo por raíz; al alcanzarlo también se marca truncado.

El listado se hace **una sola vez por directorio**: `notes.mid` / `notes.chart` se detectan sobre las entradas ya listadas, en vez de sondear con `FileAccess.open()`. Esto evita hasta 2 aperturas fallidas (y 2 más del fallback `content://` de `FileHelper` en Android) por cada carpeta de un árbol profundo.

### Progreso y cancelación en la UI

`SongLoader` emite `scan_progress(root_index, root_total, current_dir, dirs_visited, songs_found)` al final de cada lote y `scan_finished(songs_found, cancelled)` al cerrar. El primer evento ya cuenta el recorrido entero, para que el último número que ve la UI sea el bueno. `script/ui/ScanFeedback.gd` es el sitio único donde se formatea ese progreso, y lo comparten las dos superficies:

- **Ajustes ▸ Canciones** — `Rescan now` dispara `_scan_summary_and_rescan()`, que pide el escaneo y lo bombea desde `_process`. El panel muestra barra, `i/N` con las canciones encontradas y la carpeta actual, con `Cancel` al lado. Al terminar, `_update_scan_summary()` añade el aviso por raíz cancelada.
- **Menú** — `_refresh_song_list()` usa el mismo overlay de carga, pero solo con `Cancel` y carpeta cuando lo que se está cargando es la biblioteca; al cargar una canción se mantiene el porcentaje, que sí es fiable, y el escaneo no lo enseña porque `i/N` no es un porcentaje.

El botón de cancelar no corta en seco: pide `cancel_scan()` y muestra "Cancelling...". La lista se reconstruye con lo encontrado, que es un prefijo exacto del recorrido completo.

Cualquier escaneo en marcha se aborta en `_exit_tree()` y al cambiar de pestaña en Ajustes: si la UI desaparece a mitad, `SongLoader` no debe quedar con `is_scanning = true`.

### Diagnóstico

- `SongLoader.unreadable_roots` — raíces que no se pudieron abrir. En Android sin *All files access* concedido es el síntoma típico: `Download/` y `Documents/` no son listables bajo scoped storage.
- `SongLoader.truncated_roots` — raíces cuyo recorrido se cortó por `max_depth` o por `MAX_DIRS_PER_ROOT`, o sea que puede haber canciones más profundas sin descubrir.
- `SongLoader.cancelled_roots` — raíces a medio recorrer cuando se canceló. Van aparte de las truncadas porque el aviso es distinto: ahí el jugador sabe que paró él.

### Permiso requerido

En Android 11+ (`API 30`) leer `/storage/emulated/0/...` fuera de las carpetas propias exige *All files access* (`MANAGE_EXTERNAL_STORAGE`). Ver la sección del plugin `AllFilesAccess`. Sin el permiso concedido las raíces/user-defined devuelven `unreadable_roots` y la biblioteca aparece vacía — de ahí que la UI deba reportar esas raíces explícitamente en vez de mostrar "0 canciones".

### Requisito de `song.ini`

`song.ini` ya **no es obligatorio**: una carpeta con `notes.mid` o `notes.chart` entra en la lista aunque no tenga metadatos. Antes se descartaba silenciosamente, lo que hacía inútil una biblioteca de Clone Hero cruda.

`_derive_metadata()` combina tres fuentes, aplicando **precedencia campo a campo** (cada campo no vacío de una fuente de mayor prioridad pisa al de las anteriores):

| Prioridad | Fuente | Aporta |
|---|---|---|
| 1 (menor) | Nombre de carpeta | `name`, `artist`, `charter` |
| 2 | Cabecera `[Song]` del `.chart` | `name`, `artist`, `album`, `genre`, `year`, `charter`, `delay` (desde `Offset`) |
| 3 (mayor) | `song.ini` | todo lo anterior + `song_length`, `preview_start_time`, `diff_drums` |

Las claves de `song.ini` de Clone Hero coinciden con las que ya leía el juego, así que se usan tal cual.

**Nombre de carpeta.** Se parsea con la convención `"<Artist> - <Song> (<Charter>)"`. Si el nombre **no** contiene `" - "`, se usa el nombre de la **carpeta padre** como artista — cubre el layout anidado `biblioteca/Artista/Canción`, que es el más común. El padre solo se usa si no es la propia raíz del escaneo (si no, `Download/Canción` daría artista `Download`) y si no está bajo `res://` o `user://`.

Un trailing `(...)` **no** se separa como charter cuando no hay `" - "`: muchos títulos reales lo llevan (`Song (Remix)`, `Song (Live)`) y `charter` no se muestra en la UI, así que no merece el riesgo de mutilar títulos.

**`song.ini` con comillas.** `_parse_ini` desenvuelve las comillas que envuelven el valor (usando `DotChartParser.strip_quotes()`). Antes `"Crystal Castles"` se mostraba en la lista con las comillas incluidas.

**`Year` corrupto.** Charts reales traen valores como `Year = ", 2008"`. `_extract_year()` extrae los primeros 4 dígitos; si no encuentra exactamente 4, devuelve el valor original sin tocar.

**`song_length`.** Solo proviene de `song.ini`. Sin él queda en 0 y `MenuRoot` **omite el prefijo de duración** en vez de mostrar `0:00`. No se deriva del chart porque exigiría parsear el tempo map completo en cada canción durante el escaneo, a cambio de un dato puramente decorativo.

### Pestaña SONGS (Settings)

`SettingsRoot` tiene una pestaña **SONGS** entre HUD y Experimental. Contiene:

- **STORAGE ACCESS** — estado de All Files Access. En Android muestra *Grant access* mientras no se haya concedido y *Open Android settings* una vez concedida. En otras plataformas muestra que el acceso es automático.
- **LIBRARY LOCATIONS** — checks de `Download`/`Documents`, profundidad máxima (0 = solo esa carpeta) y *Search subfolders*.
- **EXTRA FOLDERS** — lista de raíces personalizadas con botón *Remove*, más un `LineEdit` para añadir rutas absolutas. Las rutas se normalizan con `simplify_path()`, se anteponen `/` si faltan y se descartan duplicados. Las rutas que no existen se muestran en rojo en la lista.
- **Rescan now** y **Cancel**, con barra de progreso, `i/N` de ubicaciones, canciones encontradas y carpeta actual mientras dura el escaneo (ver *Progreso y cancelación en la UI*).
- Un resumen del último escaneo que reporta el número de canciones, el número de ubicaciones, y las raíces ilegibles, truncadas por profundidad o canceladas a medias.
- **Reset SONGS to Defaults**.

Cambios de biblioteca persisten al instante (`SettingsManager.save_settings()`), pero el reescaneo no ocurre en cada toggle: `MenuRoot._library_changed()` compara un snapshot y solo refresca la lista al cerrar Ajustes. Rescanear por cada toggle sería un walk del disco por cada checkbox.

`AndroidBridge` es un autoload; `OS.request_permissions()` no se usa para All Files Access porque no incluye `MANAGE_EXTERNAL_STORAGE`.

### Carriles de batería en charts `.chart`

`CHART_LANE_MAP` (ChartData.gd) mapea los carriles del chart a las 8 carriles del juego (HH, CRASH, SNARE, KICK, TOM 1, TOM 2, TOM 3, RIDE):

| Chart | Juego | |
|---|---|---|
| 0 | KICK | |
| 1 | SNARE | |
| 2 | HH | |
| 3 | RIDE | |
| 4 | CRASH | |
| 5, 66 | TOM 1 | |
| 6, 67 | TOM 2 | |
| 7, 68 | TOM 3 | |

**Toms en 66/67/68.** Los charts `.chart` de Clone Hero/Phase Shift codifican los toms en los carriles 66, 67 y 68, no en 5/6/7. Esto se dedujo de `Songs/Caos - La Planta (jdpc.dev)/notes.chart`, el único chart del proyecto con batería: usa 0-4 y 66/67/68, exactamente 8 carriles que encajan uno a uno con las carriles del juego. Antes esos toms se descartaban, dejando fuera 718 de las 2027 notas de Expert.

El carril **65** se deja sin mapear a propósito: no aparece en ningún chart del proyecto y el juego solo tiene 3 toms, así que no hay carril donde colocar un posible cuarto tom. Se descarta y aparece en el aviso de carriles desconocidos.

**Aviso de carriles descartados.** `_warn_skipped_lanes()` acumula los descartes por carril y emite **un** `push_warning` por chart (`lane 65 x3, lane 99 x1`). Antes `DotChartParser` avisaba por nota, lo que generaba miles de líneas de log idénticas en charts con muchos carriles desconocidos. El diccionario `_skipped_lanes` se conserva tras `load()` para diagnóstico.

### Audio `.opus` no reproducible

`AudioManager._load_audio_stream()` no decodifica `.opus` en Android (`_decode_opus_via_ffmpeg()` devuelve `null` a propósito) y solo cae a un `song.ogg`/`preview.ogg` hermano. Una biblioteca de Clone Hero con `song.opus` entraba en la lista pero **sonaba en silencio sin ningún aviso**.

`SongLoader._detect_blocked_audio()` marca la entrada con `audio_blocked: true` cuando existe `song.opus` y no `song.ogg`. Se informa en dos sitios: el resumen de la pestaña SONGS ("N song(s) ... convert them with tools/convert_opus_to_ogg.sh") y la barra de estado de la lista de canciones, para que sea visible sin abrir Ajustes. Convertir con `tools/convert_opus_to_ogg.sh --remove-opus` deja el aviso en cero, porque al existir `song.ogg` la función devuelve `false` aunque el `.opus` siga ahí.

### Permiso de All Files Access en la UI

`AndroidBridge` expone cuatro operaciones al singleton `AllFilesAccess`:

| Método | Efecto |
|---|---|
| `has_all_files_access()` | `Environment.isExternalStorageManager()` (siempre `true` en Android ≤10) |
| `request_all_files_access()` | Concede el permiso; en Android ≤10 **abre Ajustes** en vez de no hacer nada |
| `open_all_files_settings()` | Abre siempre la pantalla de Ajustes, tenga o no el permiso |
| `is_storage_plugin_available()` | Si el singleton llegó al APK |
| `get_storage_last_error()` | `no_activity`, `no_settings_activity`, `no_app_details_activity`, `plugin_missing` o `""` |

**Por qué el botón "Open Android settings" no abría nada.** `requestAllFilesAccess()` hacía `return true` sin lanzar ningún intent en dos casos: Android ≤10 y permiso ya concedido. El botón etiquetado "Open Android settings" por tanto era un botón muerto. Se separaron las dos responsabilidades en `requestAllFilesAccess()` (conceder) y `openAllFilesSettings()` (abrir Ajustes siempre), y la etiqueta del botón decide a cuál llamar.

**Ningún fallo es silencioso.** `_on_permission_pressed()` comprueba el retorno booleano; si no se pudo abrir nada, el panel muestra el motivo (`get_storage_last_error()`) e indica la ruta manual. Si el singleton no está en el APK, el panel lo dice y deshabilita el botón en vez de dejar un control inerte.

**Refresco al volver.** `SettingsRoot` reevalúa el permiso en `NOTIFICATION_APPLICATION_FOCUS_IN` y `NOTIFICATION_WM_WINDOW_FOCUS_IN`, porque regresar de Ajustes no dispara ninguna señal de Godot. Si el permiso pasó a estar concedido, reescanea la biblioteca. En Android 11+ el sistema puede matar el proceso al conceder el permiso; en ese caso el estado se lee correctamente al reabrir la app.

### Requisito de build: "Use Gradle Build" debe estar activo

Los plugins Android (`AllFilesAccess`, `GestureExclusion`) se distribuyen como AAR y **solo llegan al APK si el export usa Gradle**. Con `gradle_build/use_gradle_build=false` Godot empaqueta el APK precompilado e inyecta solo el PCK: no hay build donde fusionar los AAR, así que el singleton Java no existe y `AndroidBridge` devuelve `false` en silencio. El síntoma era un botón "Grant access" inerte y ningún crash.

Tres condiciones deben cumplirse:

1. **Plantilla de build instalada.** `android/build/` debe contener el `build.gradle` raíz. En un clon nuevo hay que usar *Project > Install Android Build Template* (o `godot --headless --install-android-build-template --quit`); `android/build/` está en `.gitignore`, así que no viaja en el repo.
2. **`gradle_build/use_gradle_build=true`** en `export_presets.cfg`. Dejar `gradle_build/gradle_build_directory` **vacío**: con un valor explícito como `res://android/build` la validación de plantilla de Godot falla.
3. **Java 11 o superior.** AGP 8.6.1 rechaza un JVM 8. Se ajusta en *Editor Settings > Export > Android > Java SDK Path*.

**Ruta del AAR.** `_get_android_libraries()` debe devolver rutas `res://` completas y con el prefijo del addon, p. ej. `res://addons/AllFilesAccess/bin/debug/AllFilesAccess.aar`. Antes ambos plugins devolvían `AllFilesAccess/bin/debug/...`, sin `res://` ni `addons/`, y el path no resolvía.

El `build.gradle` de la plantilla recoge los plugins de dos formas: `implementation files(pluginsBinaries)` con lo que devuelve `_get_android_libraries()`, y un `fileTree` **no recursivo** sobre `addons/` (`include: ['*.jar', '*.aar']`), que no alcanza un AAR en `addons/<plugin>/bin/debug/`. Por eso la ruta importa.

**Verificación.** Un export de debug con la configuración correcta produce un APK que contiene los paquetes `com.drum.hero.allfilesaccess` y `com.drum.hero.gestureexclusion`, y en el manifest:

```
org.godotengine.plugin.v2.AllFilesAccess  ->  com.drum.hero.allfilesaccess.AllFilesAccessPlugin
org.godotengine.plugin.v2.GestureExclusion -> com.drum.hero.gestureexclusion.GestureExclusionPlugin
```

Ese `meta-data` es lo que hace que Godot registre el singleton en `Engine.has_singleton()`.

### Limitaciones conocidas

- El chart debe ser hijo directo de la carpeta de la canción (la convención de Clone Hero/YARG y la documentada en `README.md`). Un layout `cancion/charts/notes.mid` no se detecta.
- El nombre del chart se compara sin distinguir mayúsculas durante el escaneo, y el nombre real del archivo encontrado se pasa a `_scan_song()`, así que `Notes.MID` también funciona.
- El audio `.opus` no se decodifica en Android; la biblioteca necesita `.ogg` (o `.wav`/`.mp3` empaquetado).

---

## Formato de canciones

Las canciones incluidas en el APK están en `res://Songs/` con archivos `.ogg` (convertidos desde `.opus` por `tools/convert_opus_to_ogg.sh` antes del build). Ese script acepta `--remove-opus` para borrar el `.opus` una vez existe un `.ogg` válido, y solo borra bajo `Songs/`: los `.opus` de `asset/drumSfx/` están versionados en git y se conservan siempre. El borrado exige que el `.ogg` no esté vacío y empiece por los bytes mágicos `OggS`, se pide confirmación una vez antes del primer borrado (`--yes` la omite) y `DRY_RUN=true` no borra nada. Las canciones del usuario van en `user://DrumHero` (desktop) o almacenamiento externo (Android) con `.opus` o `.ogg`. Se pueden añadir raíces propias —ver [Bibliotecas de canciones externas](#bibliotecas-de-canciones-externas).

```
Songs/<artist> - <song>/
├── song.ini           ← metadatos (opcional; el nombre de carpeta y la cabecera [Song] del .chart cubren el resto)
├── notes.mid          ← chart MIDI (mapeo Rock Band / Clone Hero) — prioridad
├── notes.chart        ← chart .chart (Feedback format, Clone Hero) — fallback si no hay .mid
├── song.ogg           ← mezcla completa
├── preview.ogg        ← preview corto (opcional, 30s — fallback a song.ogg si no existe)
├── drums.ogg          ← solo batería (opcional)
├── bass.ogg           ← solo bajo (opcional)
├── guitar.ogg         ← solo guitarra (opcional)
├── rhythm.ogg         ← guitarra rítmica (opcional)
├── keys.ogg           ← solo teclado (opcional)
├── vocals.ogg         ← solo voces (opcional)
├── album.jpg          ← carátula (prioritario)
├── album.png          ← carátula (fallback si no hay album.jpg)
└── background.jpg     ← fondo de pantalla
```

Los stems pueden tener formas alternativas: `drums_1.ogg`, `drums_2.ogg` (multi-mic). El `_find_stem_file()` busca con sufijo numérico si no encuentra el archivo base. En desktop, `.opus` se soporta igualmente (decodificado vía ffmpeg).

### notas.mid

El formato sigue el estándar **Rock Band MIDI**: cada dificultad ocupa una octava MIDI. El parser (`MidiParser.gd`) resta el offset de dificultad y mapea la nota relativa (0–11) al lane interno, definido en `ChartData.gd`:

| Octava MIDI | Offset | Dificultad |
|---|---|---|
| 60–71 | 60 | Easy |
| 72–83 | 72 | Medium |
| 84–95 | 84 | Hard |
| 96–107 | 96 | Expert |
| 120–127 | 120 | Expert+ |

| Relativa | Instrumento (Rock Band) | Lane (interno) |
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

Notas fuera de estos rangos (GM raw 36–51, special 110+) se ignoran. El `_resolve_difficulty()` itera `DIFFICULTY_OFFSETS = [60, 72, 84, 96, 120]` y la primera coincidencia en rango 0–11 determina la dificultad y el lane.

### Detección de fuente del chart (.mid / .chart)

`SongLoader` detecta automáticamente el formato: busca `notes.mid` primero; si no existe, busca `notes.chart`. `ChartParser.load_chart()` delega en el parser según la extensión del archivo.

#### MIDI (`MidiParser.gd`)

Busca pistas MIDI cuyo nombre comience con `"PART DRUMS"`. Si no se encuentran notas de batería y la opción `use_guitar_fallback` está activada, el parser re-intenta con pistas `"PART GUITAR"`.

**Flujo de detección:**

```
MidiParser.load(path, ..., use_guitar_fallback)
  │
  ├─ 1. Parsear MIDI buscando "PART DRUMS"
  │     → ¿Se encontraron notas?
  │       ├─ SÍ → usar esas notas (has_drum_track = true)
  │       └─ NO → continuar
  │
  └─ 2. ¿use_guitar_fallback activado?
        ├─ SÍ → Re-parsear MIDI buscando "PART GUITAR"
        │       → ¿Se encontraron notas?
        │         ├─ SÍ → usar esas notas (using_guitar_fallback = true)
        │         └─ NO → sin notas
        └─ NO → sin notas
```

**Propiedades expuestas por MidiParser:**

| Propiedad | Tipo | Descripción |
|---|---|---|
| `has_drum_track` | `bool` | `true` si se encontró una pista "PART DRUMS" |
| `using_guitar_fallback` | `bool` | `true` si se usó PART GUITAR como fallback |

#### .chart (`DotChartParser.gd`)

El parser identifica secciones `[EasyDrums]`, `[MediumDrums]`, `[HardDrums]`, `[ExpertDrums]`, `[ExpertPlusDrums]`. Cada sección contiene las notas de esa dificultad en formato `tick = N lane length`. El mapeo de lanes usa `ChartData.CHART_LANE_MAP`: lanes 0–4 para batería básica (Kick, Snare, HH, Ride, Crash) y lanes 5–7 para toms (Pro Drums). Soporta guitarra como fallback buscando secciones `[EasySingle]`–`[ExpertSingle]`.

**Diferencia clave con MIDI:** En `.chart` el número de lane codifica directamente si es tom o platillo (no se necesitan tom markers). Lanes 2–4 son siempre platillos; lanes 5–7 son siempre toms.

**Detección de dificultades:**

Ambos parsers exponen `detect_difficulties()` que retorna un diccionario con:

```gdscript
{
    "difficulties": [...],          # Array de dificultades disponibles
    "has_drum_chart": bool,         # Si existía PART DRUMS / sección Drums
    "guitar_fallback_used": bool    # Si se usó PART GUITAR / [Single] como fallback
}
```

`SongLoader` almacena estos campos en cada entrada de la lista de canciones, y `MenuRoot` los muestra en la etiqueta de estado:

- **Sin pista de batería y sin fallback** → muestra "no drum chart"
- **Sin pista de batería pero con fallback activo** → muestra "using guitar chart"
- **Con pista de batería** → sin mensaje adicional

**Nota (MIDI):** Si un MIDI tiene ambas pistas (PART DRUMS y PART GUITAR), se prioriza PART DRUMS siempre. El fallback solo se activa cuando PART DRUMS no produce notas.

---

## Clases de datos

### `ChartData.NoteEvent`

| Campo | Tipo | Descripción |
|---|---|---|
| `tick` | `int` | Posición en ticks MIDI |
| `time` | `float` | Tiempo en segundos (convertido con mapa de tempo) |
| `lane` | `int` | Lane interno 0–7 |
| `note_type` | `enum NoteType` | NORMAL, KICK, OPEN_HIHAT, CRASH_ACCENT, HOLD |
| `velocity` | `int` | Velocidad MIDI 0–127 |
| `length_ticks` | `int` | Duración en ticks (holds) |

### `ChartData.TempoEvent`

| Campo | Tipo | Descripción |
|---|---|---|
| `tick` | `int` | Tick donde ocurre el cambio |
| `bpm` | `float` | Beats per minute |
| `time` | `float` | Tiempo en segundos precalculado |

---

## Configuración

## Mejores puntuaciones

`HighScoreStore` guarda el mejor score por pareja canción+dificultad en `user://scores.cfg` (un `ConfigFile` propio, a propósito: `SettingsManager.save_settings()` regenera su fichero con solo sus claves y borraría secciones ajenas).

- **Clave**: `md5(song.path) + "|" + difficulty_offset`. `song.path` es la identidad de la canción (`res://Songs/...` o ruta absoluta); el hash evita caracteres que romperían el formato INI de `ConfigFile`. La dificultad usa el código de chart (60/72/84/96/120), el mismo que expone `song.difficulties` y que `GameManager.current_difficulty_offset` recibe en la partida real.
- **Cuándo se guarda**: `GameplayRoot._show_result()`, justo después de `Highway.flush_unjudged_notes()` (el score ya es definitivo) y antes de `set_state(RESULT)`. Solo toca disco si supera el récord anterior.
- **Cuándo se muestra**: `MenuRoot._create_song_row()` pinta en la etiqueta de score de cada fila `ScoreData.format_score(get_best_for_song(path, difficulties))`; sin récord mantiene el placeholder `--,---pts`. `get_best_for_song` devuelve el máximo entre las dificultades del chart.
- El store es un autoload que carga el fichero en `_ready()`; al volver del gameplay `Main.tscn` se re-instancia y las filas ya muestran el récord recién logrado.

`SettingsManager` persiste en `user://settings.cfg` usando `ConfigFile`. Valores por defecto:

| Clave | Default | Descripción |
|---|---|---|
| `judgement_perfect_ms` | 22.5 | Ventana de perfect (±ms) |
| `judgement_excellent_ms` | 45.0 | Ventana de excellent (±ms) |
| `judgement_good_ms` | 75.0 | Ventana de good (±ms) |
| `judgement_late_ms` | 100.0 | Ventana de late (±ms) |
| `judgement_early_ms` | 100.0 | Ventana de early (±ms) |
| `judgement_miss_ms` | 135.0 | Umbral de miss (±ms) |
| `master_volume` | 1.0 | Volumen master |
| `sfx_volume` | 1.0 | Volumen de efectos |
| `music_volume` | 1.0 | Volumen de música |
| `haptic_enabled` | false | Kick por sensor |
| `haptic_sensitivity` | 1.0 | Sensibilidad del sensor (÷, más alto = más sensible) |
| `haptic_activation_threshold` | 1.0 | Umbral base de activación (÷ por sensibilidad) |
| `haptic_release_threshold` | 0.5 | Umbral de liberación post-kick (÷ por sensibilidad) |
| `haptic_smoothing_strength` | 0.4 | Filtro exponencial (0=suavizado máximo, 1=sin filtro) |
| `haptic_cooldown_duration` | 0.15 | Tiempo mínimo en COOLDOWN (s) |
| `haptic_min_interval` | 0.08 | Intervalo mínimo entre kicks (s) |
| `haptic_calibration_duration` | 1.5 | Duración de calibración sin sensor de gravedad (s) |
| `haptic_show_debug` | false | Overlay debug en pantalla |
| `game_mode` | 0 | Modo de juego (0=Default, 1=Haptic, 2=Custom) |
| `custom_lanes` | [] | Orden personalizado de lanes |
| `mirrored` | false | Layout espejo |
| `left_handed` | false | Modo zurdo |
| `screen_shake` | false | Efecto de sacudida en pantalla |
| `show_fps` | false | Mostrar contador FPS en pantalla |
| `show_hit_feedback` | true | Mostrar texto de juicio en cada hit line |
| `countdown_threshold` | 5.0 | Gap mínimo (s) para mostrar countdown |
| `preview_volume` | 0.8 | Volumen del preview de canción en el menú principal |
| `use_guitar_fallback` | false | Usar PART GUITAR como fallback si falta PART DRUMS |
| `note_speed` | 1.0 | Velocidad de scroll de notas |
| `show_judgment_areas` | false | Dibujar zonas de juicio en el hit line |
| `show_menu_status` | false | Mostrar la línea de status del menú principal (chart/audio de la canción seleccionada, canciones encontradas) |
| `gameplay_padding_enabled` | false | Condensar gameplay con padding para evitar toques en bordes |
| `gameplay_padding_left` | 75.0 | Padding izquierdo en dp (0-100, solo Android) |
| `gameplay_padding_right` | 75.0 | Padding derecho en dp (0-100, solo Android) |
| `gameplay_padding_top` | 0.0 | Padding superior en dp (0-100, solo Android) |
| `gameplay_padding_bottom` | 0.0 | Padding inferior en dp (0-100, solo Android) |

### Layout del menú de Settings

El menú de configuración (`SettingsRoot.gd`) usa un layout con **tabs** para organizar las opciones:

- **CONTROLS** — Modo de control (Default/Haptic/Custom), orden de lanes, ajustes hápticos, layout (mirrored/left handed). Incluye botón "Reset CONTROLS to Defaults".
- **HUD** — Opciones visuales (FPS, screen shake, hit feedback), gameplay (note speed, countdown), ventanas de juicio (read-only). Incluye botón "Reset HUD to Defaults".
- **Experimental** — Fallback de chart (PART GUITAR), áreas de juicio (debug), overlay háptico (Show Haptic Debug), status del menú principal (Show Menu Status), gameplay padding. Incluye botón "Reset EXPERIMENTAL to Defaults".

Cada botón "Reset [SECTION] to Defaults" restaura todos los valores de esa sección a sus valores por defecto y reconstruye la UI del tab activo.

**Métodos de reseteo en `SettingsManager.gd`:**
- `reset_controls_to_defaults()` — restablece `game_mode`, `custom_lanes`, `haptic_*`, `mirrored`, `left_handed` y sincroniza `GameManager.mode`.
- `reset_hud_to_defaults()` — restablece `show_fps`, `screen_shake`, `show_hit_feedback`, `note_speed`, `countdown_threshold`.
- `reset_experimental_to_defaults()` — restablece `use_guitar_fallback`, `show_judgment_areas`, `show_menu_status`, `haptic_show_debug`, `gameplay_padding_*`.

**Nota técnica:** En Android, los `Control` nodes hijos de un `CanvasLayer` que no están dentro de un `ScrollContainer` no se renderizan correctamente. Para solucionarlo, el header y tab bar usan un `ScrollContainer` fijo (sin scroll) mientras el contenido usa un `ScrollContainer` scrolleable.

---

## Efectos visuales

### Feedback al acertar una nota

Cuando el jugador acierta una nota, se disparan simultáneamente los siguientes efectos visuales. **No se reproduce ningún sonido local (`DrumSfxManager`)**: el audio percibido proviene exclusivamente de los stems de batería de la canción (`drums_1`, `drums_2`, etc.).

1. **HitLine flash** — El `ColorRect` del hit line correspondiente se vuelve blanco y retorna a su color original (0.1s). Implementado en `HitLine.gd`.
2. **Slash effect** — Dos `ColorRect` se expanden desde el centro del carril hacia los bordes con el color característico del lane (0.12s). Implementado en `Lane.gd` (`_slash_left`, `_slash_right`).
3. **ParticleBurst** — 16 partículas explotan desde el punto de impacto con el color del lane (0.4s). Pool en `EffectManager`.
4. **JudgementPopup** — Texto de juicio ("PERFECT", "EXCELLENT", "GOOD", "LATE", "EARLY", "MISS") aparece en el hit line del lane correspondiente, flota hacia arriba y se desvanece (0.6s). Pool en `EffectManager`. Controlado por `show_hit_feedback`.
5. **Lane background highlight** — El `bg_rect` del lane incrementa su alpha brevemente.

Cuando una nota pasa el hit line sin ser golpeada, se muestra "MISS" en el hit line del lane correspondiente (mismos efectos 4 y 5).

### Efectos con pooling (EffectManager)

Implementados con pooling en `EffectManager` (máx. 16 instancias por tipo).

| Efecto | Escena | Activación |
|---|---|---|
| ParticleBurst | `scene/UI/Effects/ParticleBurst.tscn` | `trigger_particle_burst(pos, color, parent)` en cada hit |
| Shockwave | `scene/UI/Effects/Shockwave.tscn` | `trigger_shockwave(pos, parent)` — implementado, sin conectar |
| JudgementPopup | `scene/UI/Effects/JudgementPopup.tscn` | `show_judgement(accuracy, pos, parent)` — activo en cada hit (controlado por `show_hit_feedback`) |

**Mecanismo de pooling (`_borrow`):**

1. Recorre el pool y elimina referencias inválidas con `is_instance_valid()`.
2. Busca una instancia fuera del árbol de escena (`is_inside_tree() == false`) para reusarla.
3. Si no hay disponible y no se alcanzó `MAX_POOL_SIZE` (16), crea una nueva instancia.
4. Si el pool está lleno, retorna `null` (el efecto se omite silenciosamente).

Cada efecto, al finalizar su animación, llama a `get_parent().remove_child(self)` en lugar de `queue_free()`. Esto lo desengancha del árbol pero lo mantiene en memoria para su reutilización posterior, eliminando la creación y destrucción constante de nodos en el hot path del gameplay.

**ParticleBurst** (partículas con `ColorRect`): 16 partículas pre-creadas en la primera llamada a `play()`. Cada partícula es un `ColorRect` que se posiciona y anima sin necesidad de `queue_redraw()` ni `draw_circle()`, reduciendo la carga de renderizado por CPU en móviles.

**JudgementPopup** (texto de juicio): cachea una instancia de `LabelSettings` creada en `_ready()` en lugar de instanciar una nueva en cada `show_judgement()`, eliminando allocaciones por frame.

### Feedback visual adicional

- **Combo counter** — animación de "pop" (escala 1.3→1.0) cuando el combo cambia (`ComboCounter.gd`).
- **Hit feedback** — texto de juicio ("PERFECT"/"EXCELLENT"/"GOOD"/"LATE"/"EARLY"/"MISS") en cada hit line via `JudgementPopup` (configurable con `show_hit_feedback`). Miss se muestra cuando la nota pasa el hit line sin ser golpeada.
- **Judgment areas** — bandas de color asimétricas en el hit line que muestran las ventanas de timing (configurable con `show_judgment_areas` en Experimental). EARLY→GOOD→EXCELLENT→PERFECT→LATE→MISS de arriba hacia abajo.
- **Touch zone highlight** — las zonas táctiles en la base de cada carril se iluminan al presionar (`TouchInput.gd`).

---

## Cómo agregar un lane nuevo

1. Agregar la nota MIDI al mapeo en `MidiParser.get_drum_notes()`
2. Agregar el label en `DrumGraphics.LANE_LABELS` y `LANE_FULL_LABELS`
3. Agregar la forma vectorial en `DrumGraphics._generate_for_lane()` → `_draw_note()` y `_draw_hit_line()`
4. Agregar color en `Note._get_color_for_lane()` (o `Highway._get_lane_colors()`)
5. Si el lane requiere un NoteType nuevo (ej. HOLD), extender `ChartData.NoteType`

---

## Dependencias externas

- **ffmpeg** (con `--enable-libopus`) — necesario para decodificar stems `.opus`. Se detecta automáticamente al cargar una canción.
- **Godot 4.7 stable** — build de Linux sin módulo opus nativo (por eso se usa ffmpeg).
