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
│   ├── HeaderBar (PanelContainer)     — título "DRUM HERO" + Settings
│   ├── SearchBar (PanelContainer)     — LineEdit con filtro
│   ├── SongListScroll (ScrollContainer) — lista scrolleable
│   │   └── SongListContainer (VBoxContainer)
│   │       ├── SongRow_N (PanelContainer)  — ► + artista + --,---pts
│   │       └── ...
│   ├── StatusLabel                    — "STATUS: chart OK - ..."
├── PreviewStatusLabel             — "♫ Artist - Song" (mientras se reproduce preview, oculto si no hay)
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
│   └── SongTimeline (TextureProgressBar)
├── HitDetection (Node)                 ← HitDetection.gd
├── TouchInput (Node)                   ← TouchInput.gd
└── HapticKick (Node)                   ← HapticKick.gd
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
| `SongLoader` | Escanea `res://Songs/` y `user://DrumHero`, parsea `song.ini`, expone lista de canciones con metadatos. Detecta fuente del chart (PART DRUMS vs PART GUITAR). Cada song entry incluye `preview_path` (str), `preview_start_time` (int, en milisegundos, -1 si no definido), `song_length` (float). `get_stem_path()` y `_scan_song()` usan `FileHelper.file_exists() OR ResourceLoader.exists()` para encontrar archivos tanto en `user://` (FileAccess) como en `res://` empaquetados (ResourceLoader). | — |
| `ChartParser` | Carga `notes.mid` vía `MidiParser.gd`, construye arreglo de `NoteEvent` con tiempo en segundos. Soporta fallback a PART GUITAR si PART DRUMS no existe. `get_notes_in_range()` usa búsqueda binaria (`find_next_note_index`) para saltar al rango solicitado. | `ChartData.gd` (clases de datos) |
| `TimingEngine` | Reloj maestro. Si hay audio usa `AudioManager.get_position()`, sino delta de frames. Emite `time_updated`, `song_ended`. | `AudioManager` |
| `ScoreManager` | Puntaje, combo, multiplicador, rachas. API: `register_hit(diff)`, `register_miss()`, `reset()`. | — |
| `EffectManager` | Pool de efectos visuales (`ParticleBurst`, `Shockwave`, `JudgementPopup`). Genera SFX (beeps programáticos). | — |
| `DrumGraphics` | Genera texturas vectoriales para notas y hit lines por lane (double cymbal, cymbal, drumstick, pedal). Texturas de 128×128 pre-generadas en `_ready()`. | — |
| `AndroidBridge` | Puente GDScript→Android nativo. Gestiona `GestureExclusion` plugin para excluir bordes del back gesture. Solo activo en Android; no-op en desktop. | — |

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

Cuando `gameplay_padding_enabled` está activo, el Highway se posiciona en `(pad_left, pad_top)` y `screen_w`/`screen_h` se reducen a las dimensiones efectivas (`viewport - pad_left - pad_right`, `viewport - pad_top - pad_bottom`). Esto desplaza automáticamente lanes, notas, hit line, beat lines y touch zones. El HUD (CanvasLayer) se ajusta manualmente sumando los paddings individuales a los offsets de cada label. Cada lado se configura independientemente con un slider (0-200px, default 40).

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

## Formato de canciones

Las canciones incluidas en el APK están en `res://Songs/` con archivos `.ogg` (convertidos desde `.opus` por `tools/convert_opus_to_ogg.sh` antes del build). Las canciones del usuario van en `user://DrumHero` (desktop) o almacenamiento externo (Android) con `.opus` o `.ogg`.

```
Songs/<artist> - <song>/
├── song.ini           ← metadatos (artista, nombre, dificultad, etc.)
├── notes.mid          ← chart MIDI (mapeo Clone Hero / YARG)
├── song.ogg           ← mezcla completa
├── preview.ogg        ← preview corto (opcional, 30s — fallback a song.ogg si no existe)
├── drums.ogg          ← solo batería (opcional)
├── bass.ogg           ← solo bajo (opcional)
├── guitar.ogg         ← solo guitarra (opcional)
├── rhythm.ogg         ← guitarra rítmica (opcional)
├── keys.ogg           ← solo teclado (opcional)
├── vocals.ogg         ← solo voces (opcional)
├── album.jpg          ← carátula
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

### Detección de fuente del chart (PART DRUMS / PART GUITAR)

El parser (`MidiParser.gd`) busca pistas MIDI cuyo nombre comience con `"PART DRUMS"`. Si no se encuentran notas de batería y la opción `use_guitar_fallback` está activada, el parser re-intenta con pistas `"PART GUITAR"`.

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

**Detección de dificultades:**

`MidiParser.detect_difficulties()` retorna un diccionario con:

```gdscript
{
    "difficulties": [...],          # Array de dificultades disponibles
    "has_drum_chart": bool,         # Si existía PART DRUMS
    "guitar_fallback_used": bool    # Si se usó PART GUITAR
}
```

`SongLoader` almacena estos campos en cada entrada de la lista de canciones, y `MenuRoot` los muestra en la etiqueta de estado:

- **Sin PART DRUMS y sin fallback** → muestra "no drum chart"
- **Sin PART DRUMS pero con fallback activo** → muestra "using guitar chart"
- **Con PART DRUMS** → sin mensaje adicional

**Nota:** Si un MIDI tiene ambas pistas (PART DRUMS y PART GUITAR), se prioriza PART DRUMS siempre. El fallback solo se activa cuando PART DRUMS no produce notas.

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
| `gameplay_padding_enabled` | false | Condensar gameplay con padding para evitar toques en bordes |
| `gameplay_padding_left` | 40.0 | Padding izquierdo en px (0-200) |
| `gameplay_padding_right` | 40.0 | Padding derecho en px (0-200) |
| `gameplay_padding_top` | 40.0 | Padding superior en px (0-200) |
| `gameplay_padding_bottom` | 40.0 | Padding inferior en px (0-200) |

### Layout del menú de Settings

El menú de configuración (`SettingsRoot.gd`) usa un layout con **tabs** para organizar las opciones:

- **CONTROLS** — Modo de control (Default/Haptic/Custom), orden de lanes, ajustes hápticos, layout (mirrored/left handed). Incluye botón "Reset CONTROLS to Defaults".
- **HUD** — Opciones visuales (FPS, screen shake, hit feedback), gameplay (note speed, countdown), ventanas de juicio (read-only). Incluye botón "Reset HUD to Defaults".
- **Experimental** — Fallback de chart (PART GUITAR), áreas de juicio (debug), overlay háptico (Show Haptic Debug), gameplay padding. Incluye botón "Reset EXPERIMENTAL to Defaults".

Cada botón "Reset [SECTION] to Defaults" restaura todos los valores de esa sección a sus valores por defecto y reconstruye la UI del tab activo.

**Métodos de reseteo en `SettingsManager.gd`:**
- `reset_controls_to_defaults()` — restablece `game_mode`, `custom_lanes`, `haptic_*`, `mirrored`, `left_handed` y sincroniza `GameManager.mode`.
- `reset_hud_to_defaults()` — restablece `show_fps`, `screen_shake`, `show_hit_feedback`, `note_speed`, `countdown_threshold`.
- `reset_experimental_to_defaults()` — restablece `use_guitar_fallback`, `show_judgment_areas`, `haptic_show_debug`, `gameplay_padding_*`.

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
