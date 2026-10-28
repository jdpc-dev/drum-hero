# Beat Line Placement

## Overview

Beat Lines are **not generated from notes**.

Instead, they are generated from the song's **tempo map**, which contains all BPM and time signature changes.

This ensures that Beat Lines accurately represent the musical rhythm, even during sections with no playable notes.

---

## Required Chart Data

The chart provides two independent timing systems:

- Tempo Events (BPM changes)
- Time Signature Events

```
0.000 s
120 BPM
4/4

65.732 s
180 BPM

98.114 s
3/4
```

The Beat Line generator reads these events before gameplay begins, triggered by `highway.generate_beat_lines()` from `GameplayRoot` after the chart is loaded.

---

## Beat Duration

For each time signature section, the beat interval depends on both the tempo and the denominator:

```
beatDuration = 4.0 / denominator      // fraction of a quarter note per beat
secondsPerBeat = 60.0 / BPM * 4.0 / denominator
```

Examples:

| Time Signature | Denominator Factor | Formula @ 120 BPM | Seconds per Beat |
|----------------|--------------------|--------------------|------------------|
| 4/4            | 4/4 = 1.0          | 60/120 * 1.0       | 0.500            |
| 3/4            | 4/4 = 1.0          | 60/120 * 1.0       | 0.500            |
| 6/8            | 4/8 = 0.5          | 60/120 * 0.5       | 0.250            |
| 2/2            | 4/2 = 2.0          | 60/120 * 2.0       | 1.000            |

Internally, the implementation works in MIDI ticks:

```
beatTicks = resolution * 4.0 / denominator
secondsPerBeat = beatTicks * microsPerTick / 1000000
```

`microsPerTick` already encodes the tempo from the MIDI tempo event, so no separate BPM factor appears in the tick calculation.

---

## Beat Generation

Starting from tick 0 and time 0, the generator walks through the song beat by beat, handling BPM and time signature changes as they occur.

```
currentTime = 0.0
currentTick = 0

for each bar:
    update time signature (numerator = beats per bar, denominator -> beat interval)
    for each beat in bar:
        check for tempo change at currentTick
        record beat at currentTime
        currentTick += beatTicks
        currentTime += secondsPerBeat
```

Each beat is stored as:

```
{"time": currentTime, "is_measure": barBeat == 0}
```

Measure lines and beat lines are generated in a single pass — there is no separate measure generation step.

---

## Measure Lines

The time signature's numerator determines which beats become Measure Lines (beat 1 of each bar).

Example 4/4:

```
Beat 1   Measure Line
Beat 2   Beat Line
Beat 3   Beat Line
Beat 4   Beat Line
```

Example 3/4:

```
Beat 1   Measure Line
Beat 2   Beat Line
Beat 3   Beat Line
```

Example 5/4:

```
Beat 1   Measure Line
Beat 2   Beat Line
Beat 3   Beat Line
Beat 4   Beat Line
Beat 5   Beat Line
```

---

## Screen Position

Each Beat Line has only one important property:

```
timestamp
```

During gameplay its position is calculated exactly like a note, sharing the same scroll formula:

```
timeAhead = beat.timestamp - currentSongTime
scrollDistance = (highwayBottomY - highwayTopY) * noteSpeed
screenY = hitLineY - (timeAhead * scrollDistance) / 2.0
```

Beat Lines and notes always remain perfectly synchronized because both use the same scrolling function.

---

## Visible Range

Only Beat Lines within a visible window are rendered each frame:

```
visibleRangeStart = currentSongTime + bottomCutoff
visibleRangeEnd   = currentSongTime + 2.0
```

`bottomCutoff` is computed dynamically from the scroll distance so that beat lines disappear exactly at the top of the hit zone (`highwayBottomY`), never overlapping the hit lane or lane labels:

```
bottomCutoff = 2.0 * (hitLineY - highwayBottomY) / scrollDistance
```

A cursor (`_beat_line_cursor`) tracks the current position in the sorted timestamp array across frames, avoiding re-scanning of past beats.

---

## BPM Changes

When the tempo changes, Beat Lines automatically become closer together or farther apart. No special rendering logic is required — the timestamps are simply generated using the new `microsPerTick` value at the point of change.

---

## Z-Order

Beat Lines render at `z_index = -1` (the same depth layer as the background), ensuring they always appear behind notes (which use the default `z_index = 0`).

---

## Visual Style

| Type | Height | Color |
|------|--------|-------|
| Measure Line | 2 px | White, 40% opacity |
| Beat Line | 1 px | White, 12% opacity |

Both span the full screen width.

---

## Performance

- **Pre-generation**: Beat timestamps are computed once per song load, not per frame.
- **Object pooling**: ColorRect nodes are reused via a pool. Each frame, all pool entries are hidden first, then only visible ones are shown. New entries are created on demand when the pool is exhausted.
- **Cursor scan**: A monotonic cursor avoids re-scanning past beats.
- **Per-frame work**: Only visible beat lines (typically < 10) are updated each frame.

---

## Why Not Generate Them from Notes?

Notes do not necessarily occur on every beat:

```
Beat  1  2  3  4
Kick  1
Snare     3
```

If Beat Lines were generated from notes, beats 2 and 4 would be missing — the player would lose the rhythmic reference.

Generating Beat Lines from the tempo map guarantees a complete and accurate representation of the song's rhythm, regardless of note density.

---

## Implementation Reference

| File | Role |
|------|------|
| `script/gameplay/Highway.gd` | Beat generation, per-frame update, object pool, positioning |
| `script/gameplay/GameplayRoot.gd` | Triggers `generate_beat_lines()` after chart load |
| `script/autoload/ChartParser.gd` | Stores tempo map, time signature map, note data |
| `script/chart/MidiParser.gd` | Binary MIDI parser, tick-to-seconds conversion |
| `script/chart/ChartData.gd` | Data classes: TempoEvent, TimeSignatureEvent, NoteEvent |
| `script/autoload/TimingEngine.gd` | Master clock driven by audio position |
