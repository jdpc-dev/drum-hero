# Beat Lines System

## Overview

The Beat Lines System renders horizontal timing guides across the note highway to visually represent the rhythmic structure of the song.

These lines are purely visual references and do not participate in hit detection. Their purpose is to help players anticipate note timing, recognize rhythmic patterns, and maintain synchronization with the music.

---

## Types of Beat Lines

Two types of timing markers are rendered:

### Measure Lines
Indicate the **first beat of every measure (bar)**. Rendered at 2px height, white at 40% opacity, full screen width.

```
══════════════════════════════
```

### Beat Lines
Represent the remaining beats within the current measure. Rendered at 1px height, white at 12% opacity, full screen width.

```
──────────────────────────────
```

---

## Example (4/4 Time Signature)

```
══════════════════════════════
Beat 1 (Measure Line)

──────────────────────────────
Beat 2

──────────────────────────────
Beat 3

──────────────────────────────
Beat 4

══════════════════════════════
Beat 1 (Next Measure)
```

---

## Data Flow

```
notes.mid (binary MIDI file)
    ↓
MidiParser
  - Extracts tempo events (BPM), time signature events, time resolution
  - Converts note ticks to seconds
    ↓
ChartParser (singleton)
  - Stores tempo map, time signature map, note data
  - Queried by Highway via get_tempo_events(), get_time_signature_events(), etc.
    ↓
GameplayRoot._start_loading()
  → ChartParser.load_chart()          ← chart data loaded
  → highway.generate_beat_lines()     ← beat generation triggered here
  → TimingEngine.start(duration)      ← clock starts after generation
    ↓
Highway._generate_beat_timestamps()
  - Iterates through full song duration beat-by-beat
  - Uses tempo map + time signature map
  - Handles BPM changes, time signature changes, variable measure lengths
  - Stores _beat_timestamps: Array[{time: float, is_measure: bool}]
    ↓
Highway._process() per frame
  → _update_beat_lines(TimingEngine.get_time())
    → filters _beat_timestamps to visible window [time + bottom_cutoff, time + 2.0]
    → positions each beat line using inline Y calculation
    → renders via object pool (ColorRect nodes)
```

Beat generation is **not** triggered in `Highway._ready()` — it runs on demand after `ChartParser` is populated, avoiding a race condition where tempo data is not yet available.

---

## Beat Generation Algorithm

Located in `Highway._generate_beat_timestamps()`.

### Inputs
- Tempo events (BPM + microseconds per tick)
- Time signature events (numerator / denominator)
- MIDI resolution (ticks per quarter note)
- Song duration (seconds of last note)

### Parameters per bar
```
beat_duration  = 4.0 / current_denominator
beat_ticks     = int(resolution * beat_duration)
seconds_per_beat = beat_ticks * micros_per_tick / 1000000
```

`micros_per_tick` already encodes the tempo (from the MIDI tempo event), so no separate BPM factor is needed in the tick calculation.

The `beat_duration` factor ensures correct spacing for any time signature:
- 4/4 → `4.0 / 4 = 1.0` → quarter-note spacing
- 6/8 → `4.0 / 8 = 0.5` → eighth-note spacing (6 per bar)
- 2/2 → `4.0 / 2 = 2.0` → half-note spacing (2 per bar)

### Fallback
If no tempo events exist in the MIDI, defaults to 120 BPM with standard quarter-note resolution.

---

## Spacing

The distance between Beat Lines is determined by the current BPM and time signature denominator.

Higher BPM values produce smaller spacing. Lower BPM values produce larger spacing.

The visual spacing changes automatically while preserving musical timing.

---

## Relationship with Notes

Beat Lines are independent from note rendering. Both are positioned from their timestamps using the same scroll calculation, guaranteeing perfect synchronization between notes and timing guides.

Beat Lines do **not** use `note_position()` — they inline the Y calculation directly, avoiding a redundant X computation.

---

## Visibility

Only Beat Lines inside the visible window `[current_time + bottom_cutoff, current_time + 2.0s]` are rendered.

`bottom_cutoff` is computed dynamically from the scroll distance so that beat lines disappear exactly at `highway_bottom_y` (the top of the hit zone), never overlapping the hit lane or lane labels.

### Cursor optimization
A `_beat_line_cursor` tracks the current position in `_beat_timestamps` across frames. Instead of scanning from index 0 each frame, the cursor advances monotonically through the sorted timestamp array. Previous entries are never re-scanned.

### Z-order
Beat lines render at `z_index = -1` (same layer as the background), ensuring they always appear behind notes (which use the default `z_index = 0`).

---

## Performance

- **Pre-generation**: Beat timestamps are computed once per song load, not per frame.
- **Object pooling**: ColorRect nodes are reused via a pool. Each frame all entries are hidden first, then only visible ones are shown.
- **Cursor scan**: Visible range filtering advances a cursor rather than scanning from the start.
- **Inline Y calculation**: Avoids calling `note_position()` and discarding its X result.
- **Per-frame work**: Only visible beat lines (typically < 10) are updated each frame.

---

## Hit Detection

Beat Lines have **no gameplay interaction**. They:
- Cannot be hit.
- Cannot be missed.
- Do not affect scoring, combo, or note timing.

They exist solely as visual timing references.

---

## Design Goals

- Visually communicate the song's rhythmic structure.
- Improve player timing and readability.
- Remain synchronized with notes at all times.
- Correctly handle BPM and time signature changes, including compound meters (6/8, 9/8, 12/8) and simple meters (2/4, 3/4, 4/4, 5/4, 2/2).
- Distinguish measures from regular beats through visual emphasis.
- Have no direct impact on gameplay logic or scoring.
- Gracefully handle missing tempo data with a 120 BPM fallback.

---

## Implementation Reference

| File | Role |
|------|------|
| `script/gameplay/Highway.gd` | Beat timestamp generation, per-frame update, object pool, positioning |
| `script/gameplay/GameplayRoot.gd` | Triggers `generate_beat_lines()` after chart load |
| `script/autoload/ChartParser.gd` | Singleton storing tempo map, time sig map, note data |
| `script/chart/MidiParser.gd` | Binary MIDI parser, tick-to-seconds conversion |
| `script/chart/ChartData.gd` | Data classes: TempoEvent, TimeSignatureEvent, NoteEvent |
| `script/autoload/TimingEngine.gd` | Master clock driven by audio position |
