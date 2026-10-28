# Detecting 4-Lane Drums vs Pro Drums in MIDI

## Overview

Rock Band, Clone Hero, and YARG do **not** use separate MIDI tracks for 4-Lane Drums and Pro Drums.

Both chart types are authored in the same track:

```text
PART DRUMS
```

The distinction is made entirely through **tom marker notes**.

---

# 4-Lane Drums

A standard 4-Lane drum chart contains only the basic drum note events.

Example:

```
Red
Yellow
Blue
Green
Kick
```

In MIDI, **notes are cymbals by default**. The game interprets:

- Yellow as the Yellow Cymbal Lane (Hi-Hat)
- Blue as the Blue Cymbal Lane (Ride)
- Green as the Green Cymbal Lane (Crash)

No distinction is made between toms and cymbals.

---

# Pro Drums

A Pro Drums chart uses the exact same drum notes but adds **tom marker notes**.

Conceptually:

```
Yellow Drum Note
+
Yellow Tom Marker (MIDI 110)
=
Tom 1
```

Without the marker:

```
Yellow Drum Note
(no tom marker)
=
Hi-Hat (cymbal, default)
```

The same logic applies to Blue and Green.

**Important:** In MIDI, notes are cymbals by default. Tom markers transform notes into toms. Drum Hero's `.chart` importer (`DotChartParser.gd`) uses a different convention: **the lane number itself encodes tom vs cymbal**. Lanes 2–4 (Yellow, Blue, Green) are always cymbals; lanes 5–7 are always toms. No modifier markers needed.

*(Note: Some engines interpret `.chart` format as "notes are toms by default, cymbal markers transform them into cymbals". Drum Hero does not follow that convention — separate lane values are used instead, matching the Feedback/Clone Hero Pro Drums spec.)*

---

# Tom Marker Mapping

| Lane | Without Tom Marker (Cymbal) | With Tom Marker (Tom) |
|------|-----------------------------|----------------------|
| Yellow | Hi-Hat | Tom 1 |
| Blue | Ride | Tom 2 |
| Green | Crash | Tom 3 |

The tom marker MIDI notes are:

| MIDI Note | Description |
|-----------|-------------|
| 110 | Yellow tom marker |
| 111 | Blue tom marker |
| 112 | Green tom marker |

These are absolute MIDI note numbers (not relative to difficulty).

This allows a single MIDI track to represent both traditional 4-Lane gameplay and Pro Drums.

---

# Mixed Charts

A chart may freely mix toms and cymbals.

Example:

```
Yellow (no marker -> Hi-Hat)

Blue (with tom marker -> Tom 2)

Green (no marker -> Crash)
```

The engine interprets it as:

```
Hi-Hat

↓

Tom 2

↓

Crash
```

No additional track is required.

---

# Detection Logic

When importing a MIDI file:

```
Read PART DRUMS

↓

Read drum note

↓

Does a tom marker exist at the same tick?

        │
   Yes ─┴─ No
    │        │
   Tom     Cymbal (default)
```

If no tom markers are found anywhere in the chart, it behaves as a standard 4-Lane chart (all notes are cymbals).

If one or more tom markers are present, the chart should be treated as a Pro Drums chart.

---

# Internal Representation

The importer converts MIDI notes into Drum Hero's internal drum components.

Mapping:

| MIDI Interpretation | Drum Hero Component |
|---------------------|---------------------|
| Yellow (no marker) | Hi-Hat |
| Yellow (with marker) | Tom 1 |
| Blue (no marker) | Ride |
| Blue (with marker) | Tom 2 |
| Green (no marker) | Crash |
| Green (with marker) | Tom 3 |
| Red | Snare |
| Kick | Kick |

---

# Implementation Notes

- There is only one `PART DRUMS` MIDI track.
- 4-Lane and Pro Drums share the same drum note events.
- Pro Drums are identified solely by tom marker notes (MIDI 110, 111, 112).
- In MIDI, notes are cymbals by default; tom markers transform them into toms.
- The importer scans for tom markers while parsing the drum track.
- If no tom markers exist, the chart is treated as a standard 4-Lane drum chart (all notes are cymbals).
- If tom markers are present, notes with markers are mapped to toms and notes without markers are mapped to cymbals.
