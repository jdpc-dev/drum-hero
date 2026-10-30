# Implementing `notes.chart` Support

## Objective

Add full support for the **Feedback `.chart` format** used by Clone Hero, Guitar Hero, Phase Shift, and many community-authored rhythm game charts.

The importer should support both:

- `notes.mid`
- `notes.chart`

Both importers must produce the exact same internal Drum Hero chart representation.

---

# Supported Files

A song directory may contain either:

```text
notes.mid
```

or

```text
notes.chart
```

The loader should detect the available format automatically.

Priority:

```
notes.mid

↓

otherwise

↓

notes.chart
```

If neither exists:

```
Import Error
```

---

# Architecture

Create a dedicated parser.

```
ChartImporter

├── MidiImporter
└── ChartImporter
```

Both importers should output the same structures.

Example:

```text
Song

↓

Chart

↓

Difficulty

↓

Note Events
```

Gameplay should never know whether the source was MIDI or CHART.

---

# Feedback (.chart) Format

A `.chart` file is a plain text INI-like document.

Example:

```text
[Song]
{
  Name = "Song"
  Resolution = 192
}

[SyncTrack]
{
  ...
}

[Events]
{
  ...
}

[ExpertSingle]
{
  ...
}

[ExpertDrums]
{
  ...
}
```

Only a subset is required for Drum Hero.

---

# Required Sections

## Song

Read:

```
Resolution
```

Example:

```
Resolution = 192
```

Used for tick → time conversion.

---

## SyncTrack

Read:

```
B
```

Tempo changes.

Example:

```
0 = B 120000
```

Ignore unsupported events.

---

## ExpertDrums

Read drum notes.

Example:

```
384 = N 0 0
```

Meaning:

```
Tick = 384

Type = Note

Lane = 0

Length = 0
```

---

# Ignore

These sections can be ignored initially:

```
Events

Lyrics

Sections

Star Power

FaceOff

Boss Battle

Camera

Venue
```

Support may be added later.

---

# Drum Difficulties

Read every drum difficulty if present.

```
EasyDrums

MediumDrums

HardDrums

ExpertDrums
```

Each becomes one Drum Hero difficulty.

---

# Parsing Notes

General format:

```
Tick = N Lane Length
```

Example:

```
1536 = N 3 0
```

Meaning:

```
Tick

↓

Lane

↓

Sustain Length
```

Drum notes normally have

```
Length = 0
```

---

# Lane Mapping

Map Feedback drum lanes into Drum Hero components.

| CHART Lane | Drum Hero Component |
|------------|---------------------|
| 0 | Kick |
| 1 | Red / Snare |
| 2 | Yellow |
| 3 | Blue |
| 4 | Green |

These correspond to standard community drum charts.

---

# 4-Lane vs Pro Drums

Unlike MIDI, `.chart` files encode cymbals using separate lane values rather than modifier notes.

The importer must correctly distinguish:

- Yellow Tom
- Hi-Hat
- Blue Tom
- Ride
- Green Tom
- Crash

Investigate the Feedback specification and implement support for the drum lane values used by Clone Hero and Phase Shift for Pro Drums.

Do **not** assume every Yellow, Blue, or Green note is a cymbal.

The importer should produce the same Drum Hero components regardless of whether the source is `.mid` or `.chart`.

---

# Timing

Use:

```
Resolution

+

Tempo Map

↓

Tick

↓

Seconds
```

This must produce timestamps identical to the MIDI importer.

---

# Internal Representation

Both importers must output identical note objects.

Example:

```text
DrumNote

timestamp

component

difficulty

length
```

Gameplay should never need to know whether the chart originated from MIDI or CHART.

---

# Validation

Verify that importing the same song as both `.mid` and `.chart` produces:

- identical note count
- identical timestamps
- identical drum components
- identical difficulty separation

The only acceptable differences are insignificant floating-point rounding errors.

---

# Error Handling

Gracefully report:

- malformed sections
- invalid lane values
- unsupported chart versions
- missing tempo map
- missing resolution
- missing drum track

The importer should never crash because of a malformed community chart.

---

# Future Support

Design the parser so additional events can easily be added later:

- Star Power
- Drum fills
- Practice sections
- Lyrics
- Events
- Camera
- Venue
- Open notes
- Extended drum articulations

The parser should remain modular and independent from gameplay logic.
