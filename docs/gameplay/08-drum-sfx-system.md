# Drum SFX System

## Overview

Drum Hero uses the YARG drum samples as **local drum input feedback**, not as a replacement for the song's drum audio.

Every song contains its own synchronized drum stems (e.g., `drums_1`, `drums_2`, `drums_3`, etc.), which represent the actual drum performance heard during gameplay.

The purpose of `drumSfx` is to simulate the physical sound of striking a drum component immediately when the player performs an input, providing tactile and auditory confirmation similar to hitting a real electronic drum pad.

Because the song's drum stems already reproduce the actual performance, the local drum samples are primarily noticeable during situations where the player's input is **not synchronized with a charted note**, such as:

- Free play before the song begins.
- Practice mode.
- Long rests between notes.
- Missed notes.
- Extra inputs that do not correspond to charted notes.

During successful gameplay, the player's perceived drum sound is dominated by the song's drum stems, while the local drum samples provide immediate input feedback with minimal latency.

---

# Design Goals

The local drum SFX system should:

- Provide instant auditory confirmation for every drum input.
- Simulate the sound of striking the corresponding drum component.
- Have extremely low latency.
- Never replace or interfere with the song's drum stems.
- Sound natural during repeated hits.

The system should feel similar to playing an electronic drum kit while listening to the backing track.

---

# File Naming Convention

Each filename follows the pattern:

```text
vel{velocity}pad{pad}smp{variation}.opus
```

Example:

```text
vel2pad5smp1.opus
```

| Field | Description |
|--------|-------------|
| `velocity` | Velocity layer (0–2) |
| `pad` | Drum component index (0–7) |
| `variation` | Sample variation (0–2) |

---

# Sample Variations

Each drum component includes three different recordings for every velocity layer.

Example:

```text
vel2pad3smp0.opus
vel2pad3smp1.opus
vel2pad3smp2.opus
```

The playback system should cycle through these variations in a pseudo-random manner.

The objective is to avoid the "machine gun effect" caused by repeatedly playing the exact same recording.

Repeated hits on the same drum component should sound slightly different, closely resembling the natural variation produced by a real drummer.

Whenever possible, the playback system should avoid selecting the same variation twice consecutively.

Example:

```
Snare

↓

Variation 1

↓

Variation 0

↓

Variation 2

↓

Variation 1
```

---

# Pad Mapping

The YARG samples are mapped to Drum Hero's eight gameplay lanes.

| Pad | Drum Hero Component |
|-----|----------------------|
| pad0 | Closed Hi-Hat |
| pad1 | Open Hi-Hat |
| pad2 | Crash |
| pad3 | Snare |
| pad4 | Tom 1 |
| pad5 | Tom 2 |
| pad6 | Tom 3 |
| pad7 | Ride |

---

# Playback Behavior

Every player input that represents striking a drum component triggers its corresponding local drum sample **only when the input does not correspond to a charted note**.

```
Player Input

↓

Determine Drum Component

↓

HitDetection.try_hit_lane()

├── Note hit (PERFECT / EXCELLENT / GOOD / LATE / EARLY)
│   └── No local drum SFX — only visual feedback (particles, hit line flash, slash effect)
│
└── No note hit (empty lane, late miss, extra input)
    ├── Select Velocity Layer
    ├── Select Sample Variation
    └── Play Local Drum SFX
```

This playback is **dependent on gameplay judgment**: the sample only plays when the input misses or when no note is present.

When the input successfully hits a note, the song's drum stems already reproduce the corresponding sound, so the local drum SFX is intentionally omitted to avoid layering duplicate hits. Only visual feedback (particles, hit line flash, slash effect, HUD accuracy text) is provided on successful hits.

The sample represents the physical act of hitting the drum pad when it does not coincide with a charted drum event.

Gameplay judgment affects scoring, combo logic, and determines whether visual feedback or audio feedback is provided.

---

# Audio Relationship

Two independent audio systems coexist during gameplay.

## Song Drum Stems

```
Song Audio

↓

drums_1
drums_2
drums_3
...
```

These stems contain the recorded drum performance that belongs to the song.

They are synchronized with the chart and represent what the drummer actually plays.

## Local Drum SFX

```
Player Input

↓

drumSfx

↓

Immediate Playback
```

These sounds exist solely to provide instantaneous feedback for the player's physical input.

Because both systems are played simultaneously, the local drum SFX is generally masked by the song's drums when notes are hit correctly, but becomes much more noticeable whenever the player strikes the drums outside of charted notes or during silent drum sections.

---

# Polyphony

Multiple drum samples must be able to play simultaneously.

Example:

```
Crash

+

Snare

+

Tom 1
```

All three samples should overlap naturally.

The playback system must therefore use multiple simultaneous audio voices rather than a single reusable player.

---

# Future Extensions

The architecture should support future enhancements such as:

- Velocity-sensitive playback.
- User-selectable drum kits.
- Custom sample packs.
- Stereo positioning.
- Per-component volume controls.
- Pitch variation.
- Advanced anti-repetition algorithms.
- MIDI electronic drum kits.
