# Drum Difficulty System

## Overview

In **Clone Hero** and **YARG**, drum difficulties are inherited from the **Rock Band** charting standard. The game engine does **not** dynamically modify notes based on the selected difficulty. Instead, each difficulty is stored as an **independent note chart** within the song file.

The selected difficulty determines **which note track is loaded**, while gameplay mechanics remain identical.

---

# Chart Formats

Community songs are generally distributed in one of two formats:

- `.chart` (Clone Hero native format)
- `.mid` (Rock Band / C3 / YARG standard)

Both formats store a separate note chart for each difficulty.

---

# `.chart` Format

A `.chart` file contains a dedicated section for every instrument and difficulty.

Example:

```ini
[ExpertDrums]
{
    0 = N 0 0
    192 = N 1 0
    ...
}

[HardDrums]
{
    ...
}

[MediumDrums]
{
    ...
}

[EasyDrums]
{
    ...
}
```

Each section contains only the notes that belong to that specific difficulty.

If a note exists in **Expert** but not in **Hard**, the Hard chart simply has no corresponding event.

---

# `.mid` Format

The MIDI format follows the same concept.

The drum instrument contains independent note tracks (or difficulty-specific note ranges according to the Rock Band MIDI specification).

Conceptually:

```
PART DRUMS

Easy
Medium
Hard
Expert
```

Each difficulty is authored independently.

When the song starts, the game loads only the selected difficulty.

---

# Gameplay Flow

When the player selects a difficulty:

```
Player selects:

Hard Drums
```

The engine performs something conceptually similar to:

```
Load song

↓

Locate Hard Drum Track

↓

Spawn only Hard notes

↓

Ignore Easy, Medium, and Expert tracks
```

The remaining difficulty tracks are never processed during gameplay.

---

# How Difficulties Affect Notes

The selected difficulty **does not modify note behavior**.

A note always represents the same drum component.

Example:

### Expert

```
Red
Yellow
Blue
Kick
```

### Hard

```
Red
Blue
Kick
```

The yellow note was not transformed or hidden.

It simply does not exist in the Hard chart.

---

# What Actually Changes

Only the chart content changes.

## Note Density

Expert

```
HH HH HH HH HH HH HH HH
```

Medium

```
HH    HH    HH    HH
```

Fewer notes are authored.

---

## Apparent Speed

The song tempo never changes.

Instead, the player encounters fewer notes per second.

Expert

```
x x x x x x x x
```

Easy

```
x     x     x
```

---

## Limb Coordination

Expert

```
HH HH HH HH
SN    SN
K K K K
```

Easy

```
HH    HH
SN
K
```

Simpler coordination between hands and foot.

---

## Instrument Usage

Lower difficulties often remove secondary drum components.

Expert

```
Hi-Hat
Ride
Crash
Tom 1
Tom 2
Tom 3
```

Easy

```
Hi-Hat
Snare
Kick
```

This reduces player complexity while preserving the song's rhythmic structure.

---

## Drum Fills

Expert

```
T1 T2 T3 CR SN
```

Easy

```
T1 SN
```

Large fills are simplified into recognizable but easier patterns.

---

## Double Kick (Expert+)

Some community charts provide an additional **Expert+** version.

Example:

Expert

```
K   K   K
```

Expert+

```
K K K K K K K K
```

The only difference is the kick drum pattern.

Hand notes remain identical.

---

# The Engine Does Not Know What "Difficulty" Means

An important design principle is that the game engine does **not** calculate or interpret chart difficulty.

There are no parameters such as:

```json
{
    "difficulty": 4,
    "noteDensity": 0.85,
    "speedMultiplier": 1.5
}
```

Difficulty is entirely determined by the notes authored in the selected chart.

The engine simply renders and evaluates whatever notes are present.

---

# Design Implications for Drum Hero

Drum Hero can adopt the same architecture.

Each song stores up to five independent drum charts:

- Easy
- Medium
- Hard
- Expert
- Expert+ (double kick, opcional)

Each chart contains only the notes intended for that difficulty.

At runtime:

```
Song

├── Easy Chart
├── Medium Chart
├── Hard Chart
├── Expert Chart
└── Expert+ Chart (opcional)
```

The player selects one difficulty before gameplay begins.

The engine loads only that chart, while scoring, hit windows, timing logic, lane behavior, note speed, and gameplay rules remain identical across all difficulties.

This architecture keeps the gameplay engine simple, allows chart authors complete control over difficulty progression, and ensures compatibility with existing rhythm game charting workflows.
