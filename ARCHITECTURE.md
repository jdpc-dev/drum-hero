# Drum Hero — Guía de desarrollo

## Stack

- **Motor:** Godot 4.7 (GDScript)
- **Resolución:** 1280×720, landscape, stretch `canvas_items` + `expand`
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
| `AudioManager` | Carga stems multi-pista (song, drums, bass, guitar, rhythm, keys, vocals). Salta `song` si existen stems individuales para evitar duplicación. Decodifica `.opus` a estéreo vía `ffmpeg`. Ofrece `duck_drums()` para silenciar batería temporalmente. | — |
| `InputManager` | Ruteo de input táctil y pipeline de sensor háptico (acelerómetro para kick). Estado interno `KickState` (IDLE / KICK_DOWN / COOLDOWN). | — |
| `SettingsManager` | Persistencia de configuración (archivo `user://settings.cfg`). Juicios, sensibilidad, modo háptico, orden de lanes. | — |
| `SongLoader` | Escanea `res://Songs/` y `user://Songs/`, parsea `song.ini`, expone lista de canciones con metadatos. | — |
| `ChartParser` | Carga `notes.mid` vía `MidiParser.gd`, construye arreglo de `NoteEvent` con tiempo en segundos. `get_notes_in_range()` usa búsqueda binaria (`find_next_note_index`) para saltar al rango solicitado. | `ChartData.gd` (clases de datos) |
| `TimingEngine` | Reloj maestro. Si hay audio usa `AudioManager.get_position()`, sino delta de frames. Emite `time_updated`, `song_ended`. | `AudioManager` |
| `ScoreManager` | Puntaje, combo, multiplicador, rachas. API: `register_hit(diff)`, `register_miss()`, `reset()`. | — |
| `EffectManager` | Pool de efectos visuales (`ParticleBurst`, `Shockwave`, `JudgementPopup`). Genera SFX (beeps programáticos). | — |
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
            ├─ ffmpeg -y -i <opus> -f s16le -acodec pcm_s16le -ar 44100 -ac 2 <tmp.raw>
            ├─ FileAccess.read() del raw PCM
             ├─ AudioStreamWAV.new() con stereo=true, format=FORMAT_16_BITS, mix_rate=44100
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
y=0%   +---------------------------------------+
       |             SONG TIMELINE             |
y=5%   +----+----+----+----+----+----+----+----+
       | multiplier   |    |    |    |   score |  ^
       |    |    |    |  combo  |    |    |    |  |
       |    |    |    | accuracy|    |    |    |  highway (67%)
       |    (notas scrolleando hacia abajo)    |  |
       |    |    |    |    |    |    |    |    |  v 
y=72%  +----+----+----+----+----+----+----+----+
       |    |    |    |    |    |    |    |    |  ← hit line (per-lane)
y=77%  +----+----+----+----+----+----+----+----+  
       | HH | CR | SN | KI | T1 | T2 | T3 | RI |  ← lane labels
y=100% +----+----+----+----+----+----+----+----+
```

- **Timeline:** 0–5% (barra de progreso horizontal)
- **Highway:** 5–72% (lienzo de notas)
- **Hit line:** 72-77% (una sección por lane con icono del instrumento)
- **Labels:** 77-100% (nombre corto del instrumento por lane)
- **HUD:** superpuesto (score, combo, multiplier)

### Spawn de notas

`Highway._process()` mantiene un cursor `_next_note_index` que avanza secuencialmente sobre `ChartParser.note_data`. Cada nota se encola **una sola vez** cuando entra en la ventana de spawn (`current_time + 2.0s`), evitando escanear todo el arreglo cada frame.

### Cálculo de posición de nota

```
lane_w = screen_width / lane_count
x = lane_w * lane_index + lane_w / 2
scroll_distance = screen_height * 0.55 * note_speed
y_offset = (note_time - current_time) * scroll_distance / 2.0
y = hit_line_y - y_offset
```

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

### InputManager

`InputManager.handle_touch_event()` recibe el `lane_index` ya resuelto desde `TouchInput` y evita recalcularlo.

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
├── rhythm.opus        ← guitarra rítmica (opcional)
├── keys.opus          ← solo teclado (opcional)
├── vocals.opus        ← solo voces (opcional)
├── album.jpg          ← carátula
└── background.jpg     ← fondo de pantalla
```

Los stems pueden tener formas alternativas: `drums_1.opus`, `drums_2.opus` (multi-mic). El `_find_stem_file()` busca con sufijo numérico si no encuentra el archivo base.

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
| `countdown_threshold` | 5.0 | Gap mínimo (s) para mostrar countdown |
| `show_fps` | false | Mostrar contador FPS en pantalla |

---

## Efectos visuales

### Feedback al acertar una nota

Cuando el jugador acierta una nota, se disparan simultáneamente los siguientes efectos visuales. **No se reproduce ningún sonido local (`DrumSfxManager`)**: el audio percibido proviene exclusivamente de los stems de batería de la canción (`drums_1`, `drums_2`, etc.).

1. **HitLine flash** — El `ColorRect` del hit line correspondiente se vuelve blanco y retorna a su color original (0.1s). Implementado en `HitLine.gd`.
2. **Slash effect** — Dos `ColorRect` se expanden desde el centro del carril hacia los bordes con el color característico del lane (0.12s). Implementado en `Lane.gd` (`_slash_left`, `_slash_right`).
3. **ParticleBurst** — 16 partículas explotan desde el punto de impacto con el color del lane (0.4s). Pool en `EffectManager`.
4. **Lane background highlight** — El `bg_rect` del lane incrementa su alpha brevemente.

### Efectos con pooling (EffectManager)

Se implementan con pooling en `EffectManager` (máx. 16 instancias):

| Efecto | Escena | Activación |
|---|---|---|
| ParticleBurst | `scene/UI/Effects/ParticleBurst.tscn` | `trigger_particle_burst(pos, color, parent)` en cada hit |
| Shockwave | `scene/UI/Effects/Shockwave.tscn` | `trigger_shockwave(pos, parent)` — implementado, sin conectar |
| JudgementPopup | `scene/UI/Effects/JudgementPopup.tscn` | `show_judgement(accuracy, pos, parent)` — implementado, sin conectar |

### Feedback visual adicional

- **Combo counter** — animación de "pop" (escala 1.3→1.0) cuando el combo cambia (`ComboCounter.gd`).
- **Accuracy text** — texto "PERFECT"/"EXCELLENT"/"GOOD"/"LATE"/"EARLY" con fade in/out (HUD.show_accuracy).
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
