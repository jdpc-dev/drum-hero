# Beat Lines System

## Overview

The Beat Lines System renders horizontal timing guides across the note highway to visually represent the rhythmic structure of the song.

These lines are purely visual references and do not participate in hit detection. Their purpose is to help players anticipate note timing, recognize rhythmic patterns, and maintain synchronization with the music.

---

# Types of Beat Lines

Two types of timing markers are rendered.

## Measure Lines

Measure Lines indicate the **first beat of every measure (bar)**.

They should be visually emphasized by using increased thickness, opacity, brightness, or a different color.

Example:

```
══════════════════════════════
```

---

## Beat Lines

Beat Lines represent the remaining beats within the current measure.

Example:

```
──────────────────────────────
```

---

# Example (4/4 Time Signature)

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

# Rendering

Beat Lines scroll down the highway at exactly the same speed as notes.

Their vertical position is calculated from the song timeline rather than the current screen position.

Conceptually:

```
Song Time

↓

Beat Timestamp

↓

Highway Position

↓

Render Beat Line
```

Because they share the same timing system as notes, Beat Lines remain perfectly synchronized regardless of BPM changes or scroll speed.

---

# Beat Generation

Beat Lines are generated from the song's tempo map.

For each tempo section:

```
Tempo (BPM)

↓

Time Signature

↓

Generate Beat Timestamps

↓

Generate Measure Timestamps

↓

Render Beat Lines
```

The system must correctly support:

- BPM changes
- Time signature changes
- Variable measure lengths

---

# Spacing

The distance between Beat Lines is determined by the current BPM.

Higher BPM values produce smaller spacing.

Lower BPM values produce larger spacing.

Example:

```
Slow Tempo

══════════════

──────────────

──────────────

──────────────

══════════════
```

```
Fast Tempo

══════════════
──────────────
──────────────
──────────────
══════════════
```

The visual spacing changes automatically while preserving musical timing.

---

# Relationship with Notes

Beat Lines are independent from note rendering.

Notes do not snap to Beat Lines during gameplay.

Instead, both are positioned from their timestamps.

```
Song Timeline

↓

Beat Timestamp
        │
        ├── Render Beat Line
        │
Note Timestamp
        │
        └── Render Note
```

This guarantees perfect synchronization between notes and timing guides.

---

# Visibility

Only Beat Lines inside or slightly outside the visible highway should be rendered.

As Beat Lines leave the screen, they should be recycled or regenerated using the same rendering strategy as notes.

---

# Hit Detection

Beat Lines have **no gameplay interaction**.

They:

- Cannot be hit.
- Cannot be missed.
- Do not affect scoring.
- Do not affect combo.
- Do not affect note timing.

They exist solely as visual timing references.

---

# Performance

Beat Lines should be treated as lightweight visual objects.

Recommended implementation:

- Generate beat timestamps during chart loading.
- Reuse Beat Line nodes through object pooling.
- Update only visible Beat Lines.
- Render using the same scrolling calculations as notes.

---

# Design Goals

The Beat Lines System should:

- Visually communicate the song's rhythmic structure.
- Improve player timing and readability.
- Remain synchronized with notes at all times.
- Correctly handle BPM and time signature changes.
- Distinguish measures from regular beats through visual emphasis.
- Have no direct impact on gameplay logic or scoring.
