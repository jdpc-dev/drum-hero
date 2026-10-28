# Drum Hero — Guía de desarrollo

## Stack

- **Motor:** Godot 4.7 (GDScript)
- **Resolución:** 1920×1080, landscape, stretch `canvas_items` + `keep`
- **Renderizado:** `gl_compatibility`
- **Audio:** stems Opus decodificados vía `ffmpeg` a PCM → `AudioStreamWAV`
- **Gráficos de interfaz:** generación procedural vectorial (`Image.set_pixel`)

---

## Árbol de escenas (runtime)

```
Main (CanvasLayer)                      ← MenuRoot.gd
└── Background (ColorRect)
└── Title (Label) "DRUM HERO"
└── StatusLabel
└── PlayButton
└── SongList (ItemList)

Gameplay (Node2D)                       ← GameplayRoot.gd
├── Highway (Node2D)                    ← Highway.gd
│   ├── bg_sprite (Sprite2D)           ← highway_bg.png
│   ├── Lane_0 (Lane)                  ← Lane.gd (por cada lane activo)
│   │   ├── bg_sprite (Sprite2D)       ← lane_bg.png (por lane)
│   │   └── Note (Note)                ← Note.gd (spawn dinámico)
│   ├── HitLine (Node2D)              ← HitLine.gd
│   │   └── lane_sprite_N (Sprite2D)  ← DrumGraphics (vector, por lane)
│   └── Label_HH (Label)              ← "HH", "CRASH", etc.
│       ... (un label por lane)
├── HUD (CanvasLayer)                   ← HUD.gd
│   ├── ScoreLabel
│   ├── ComboLabel
│   ├── MultiplierLabel
│   ├── AccuracyLabel
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
| `AudioManager` | Carga y reproduce stems multi-pista. Decodifica `.opus` vía `ffmpeg` si `load()` falla. Ofrece `duck_drums()` para silenciar batería temporalmente. | — |
| `InputManager` | Ruteo de input táctil y pipeline de sensor háptico (acelerómetro para kick). Estado interno `KickState` (IDLE / KICK_DOWN / COOLDOWN). | — |
| `SettingsManager` | Persistencia de configuración (archivo `user://settings.cfg`). Juicios, sensibilidad, modo háptico, orden de lanes. | — |
| `SongLoader` | Escanea `res://Songs/` y `user://Songs/`, parsea `song.ini`, expone lista de canciones con metadatos. | — |
| `ChartParser` | Carga `notes.mid` vía `MidiParser.gd`, construye arreglo de `NoteEvent` con tiempo en segundos. | `ChartData.gd` (clases de datos) |
| `TimingEngine` | Reloj maestro. Si hay audio usa `AudioManager.get_position()`, sino delta de frames. Emite `time_updated`, `song_ended`. | `AudioManager` |
| `ScoreManager` | Puntaje, combo, multiplicador, rachas. API: `register_hit(diff)`, `register_miss()`, `reset()`. | — |
| `EffectManager` | Pool de efectos visuales (`LaneFlash`, `ParticleBurst`, `Shockwave`, `JudgementPopup`). Genera SFX (beeps programáticos). | — |
| `DrumGraphics` | Genera texturas vectoriales para notas y hit lines por lane (double cymbal, cymbal, drumstick, pedal). Texturas de 128×128 pre-generadas en `_ready()`. | — |

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
  ├─ _find_stem_file() busca: {stem}.opus → {stem}.ogg → {stem}.wav → {stem}.mp3
  │                            → drums_1.opus, drums_2.opus, etc. (multi-archivo)
  │
  └─ _load_audio_stream()
       │
       ├─ ResourceLoader.exists()? → load() (para .ogg/.wav/.mp3 nativos)
       │
       └─ .opus y ffmpeg disponible? → _decode_opus_via_ffmpeg()
            │
            ├─ ffmpeg -y -i <opus> -f s16le -acodec pcm_s16le -ar 44100 -ac 1 <tmp.raw>
            ├─ FileAccess.read() del raw PCM
            ├─ AudioStreamWAV.new() con los datos
            └─ Se elimina el temporal
```

### Ducking de batería

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
y=0%   +----------------------------------------------------------------+
       |                    SONG TIMELINE                                |
y=5%   +----+----+----+----+----+----+----+----+
       |    |    |    |    |    |    |    |    |  ^
       |    |    |    |    |    |    |    |    |  |
       |  (notas scrolleando hacia abajo)      |  highway (67%)
       |    |    |    |    |    |    |    |    |  |
       |    |    |    |    |    |    |    |    |  |
       |    |    |    |    |    |    |    |    |  v
y=72%  +----+----+----+----+----+----+----+----+  ← hit line (per-lane)
y=74%  | HH | CR | SN | KI | T1 | T2 | T3 | RI |  ← lane labels
y=79%  +----+----+----+----+----+----+----+----+
       |          score / combo / accuracy       |
y=100% +----------------------------------------------------------------+
```

- **Timeline:** 0–5% (barra de progreso horizontal)
- **Highway:** 5–72% (lienzo de notas)
- **Hit line:** ~72% (una sección por lane con icono del instrumento)
- **Labels:** ~74% (nombre corto del instrumento por lane)
- **HUD:** superpuesto (score, combo, multiplicador)

### Cálculo de posición de nota

```
lane_w = screen_width / lane_count
x = lane_w * lane_index + lane_w / 2
scroll_distance = screen_height * 0.55 * note_speed
y_offset = (note_time - current_time) * scroll_distance / 2.0
y = hit_line_y - y_offset
```

---

## Sistema de entrada

### Táctil / mouse

`TouchInput._input()` maneja `InputEventScreenTouch` y `InputEventMouseButton`. Convierte la coordenada X a lane index usando el ancho virtual de la pantalla.

### Teclado (desktop)

Teclas **1–8** del teclado numérico mapean a lanes **0–7**. Implementado en `TouchInput._input()` como `InputEventKey`, llama a `HitDetection.try_hit_lane()` exactamente igual que el input táctil.

### Kick háptico (acelerómetro)

`HapticKick.gd` se conecta a `InputManager.kick_detected`. El pipeline de detección está en `InputManager._process()`: aplica filtro de suavizado, estimación de gravedad, y detecta picos en el eje forward. La calibración dura 1.5 s.

---

## Formato de canciones

```
Songs/<artist> - <song>/
├── song.ini           ← metadatos (artista, nombre, dificultad, etc.)
├── notes.mid          ← chart MIDI (mapeo Clone Hero / YARG)
├── song.opus          ← mezcla completa
├── drums.opus         ← solo batería (opcional)
├── bass.opus          ← solo bajo (opcional)
├── guitar.opus        ← solo guitarra (opcional)
├── keys.opus          ← solo teclado (opcional)
├── vocals.opus        ← solo voces (opcional)
├── album.jpg          ← carátula
└── background.jpg     ← fondo de pantalla
```

Los stems pueden tener formas alternativas: `drums_1.opus`, `drums_2.opus` (multi-mic). El `_find_stem_file()` busca con sufijo numérico si no encuentra el archivo base.

### notas.mid

Mapeo de percusión General MIDI a lanes internos (definido en `MidiParser.gd`):

| Nota MIDI | Lámina (Rock Band) | Lane |
|---|---|---|
| 44 | HH Closed | 0 |
| 46 | HH Open | 0 |
| 49 | Crash 1 | 1 |
| 57 | Crash 2 | 1 |
| 48 | Snare | 2 |
| 47 | Snare (rim) | 2 |
| 43 | Kick | 3 |
| 45 | Tom 1 | 4 |
| 41 | Tom 2 | 5 |
| 38 | Tom 3 | 6 |
| 51 | Ride | 7 |

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
| `judgement_perfect_ms` | 25 | Ventana de perfect (±ms) |
| `judgement_good_ms` | 55 | Ventana de good (±ms) |
| `judgement_miss_ms` | 120 | Umbral de miss (±ms) |
| `haptic_enabled` | false | Kick por sensor |
| `custom_lanes` | [] | Orden personalizado de lanes |

---

## Efectos visuales

Se implementan con pooling en `EffectManager`:

| Efecto | Escena | Activación |
|---|---|---|
| LaneFlash | `scene/UI/Effects/LaneFlash.tscn` | `EffectManager.trigger_lane_flash(lane, highway)` en cada hit |
| ParticleBurst | `scene/UI/Effects/ParticleBurst.tscn` | `trigger_particle_burst(pos, color, parent)` |
| Shockwave | `scene/UI/Effects/Shockwave.tscn` | `trigger_shockwave(pos, parent)` en notas CRASH |
| JudgementPopup | `scene/UI/Effects/JudgementPopup.tscn` | `show_judgement(accuracy, pos, parent)` |

Cada escena se instancia desde un pool (máx. 16 instancias) y se recicla al salir del árbol.

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
