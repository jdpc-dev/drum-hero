# Drum SFX System

## Overview

Drum Hero uses a local drum sample set (the YARG samples for most pads, plus the full Clone Hero freestyle hi-hat, crash, kick and snare for pad4, pad6, pad8 and pad7) as **local drum input feedback**, not as a replacement for the song's drum audio.

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
vel{velocity}pad{pad}smp{variation}.ogg
```

Example:

```text
vel2pad5smp1.ogg
```

| Field | Description |
|--------|-------------|
| `velocity` | Velocity layer (0–2 most pads, 0–4 hi-hat/crash, 0–5 kick/snare) |
| `pad` | Drum component index (0–8) |
| `variation` | Sample variation (0–2) |

Samples are stored as Ogg Vorbis at 44.1 kHz stereo. The original `.opus`
sources are only decoded at runtime on desktop as a fallback when no `.ogg`
exists; Android always needs the `.ogg`.

---

# Sample Variations

Each drum component includes three different recordings for every velocity layer.

Example:

```text
vel2pad3smp0.ogg
vel2pad3smp1.ogg
vel2pad3smp2.ogg
```

The playback system cycles through these variations so repeated hits never use
the exact same recording twice in a row:

- **Hi-hat (pad4), crash (pad6), kick (pad8) and snare (pad7)**: strict
  round-robin (`0, 1, 2, 0, …`) per velocity layer, matching Clone Hero. No
  random pitch shift.
- **Rest of the pads**: pseudo-random selection that avoids repeating the last
  variation, with a small random pitch shift.

The objective is to avoid the "machine gun effect" caused by repeatedly playing the exact same recording.

Repeated hits on the same drum component should sound slightly different, closely resembling the natural variation produced by a real drummer.

---

# Velocity Layers

The kick and the snare use the full Clone Hero freestyle sets: **6 velocity
layers × 3 variations** each. The kick comes from `FreestyleDrums/Kick/`
(`Kick 1` … `Kick 6`) and the snare from `FreestyleDrums/Snare/`
(`Snare 1` … `Snare 6`). The hi-hat and the crash use **5 velocity layers ×
3 variations** from `FreestyleDrums/Hihat/` and `FreestyleDrums/Crash/`
(`Hihat 1` … `Hihat 5`, `Crash 1` … `Crash 5`). Layer 0 is the softest
recording and the last layer the hardest.

The layer is selected with the same formula as Clone Hero:

```text
divisor = 127 / layer_count      # integer division, 21 for the kick
layer   = min(velocity / divisor, layer_count - 1)
```

For the kick and snare (`layer_count = 6`):

| Velocity | Layer |
|----------|-------|
| 0–20     | 0 (`Kick 1` / `Snare 1`) |
| 21–41    | 1 (`Kick 2` / `Snare 2`) |
| 42–62    | 2 (`Kick 3` / `Snare 3`) |
| 63–83    | 3 (`Kick 4` / `Snare 4`) |
| 84–104   | 4 (`Kick 5` / `Snare 5`) |
| 105–127  | 5 (`Kick 6` / `Snare 6`) |

For the hi-hat and crash (`layer_count = 5`):

| Velocity | Layer |
|----------|-------|
| 0–24     | 0 (`Hihat 1` / `Crash 1`) |
| 25–49    | 1 (`Hihat 2` / `Crash 2`) |
| 50–74    | 2 (`Hihat 3` / `Crash 3`) |
| 75–99    | 3 (`Hihat 4` / `Crash 4`) |
| 100–127  | 4 (`Hihat 5` / `Crash 5`) |

The remaining pads keep their 3 layers and use the same formula with
`layer_count = 3`.

Drum Hero's inputs (keyboard, touch, haptic kick) do not report a real
velocity, so they use the **Default Velocity** setting
(`Settings › Experimental › Drum Samples`, 0–127). The default is `100`, the
same value Clone Hero uses for `Default Sample Velocity`. If a layer has no
loaded samples, playback falls back to the nearest lower non-empty layer.

---

# Pad Mapping

The sample pack indices are not the gameplay lane order. `DrumSfxManager`
maps each lane to its sample pad:

| Pad | Drum Hero Component | Gameplay lane |
|-----|----------------------|---------------|
| pad0 | Tom 1 | 4 |
| pad1 | — (unused) | — |
| pad2 | Tom 2 | 5 |
| pad3 | Tom 3 | 6 |
| pad4 | Closed Hi-Hat | 0 |
| pad5 | Ride | 7 |
| pad6 | Crash | 1 |
| pad7 | Snare | 2 |
| pad8 | Kick | 3 |

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

- User-selectable drum kits.
- Custom sample packs.
- Stereo positioning.
- Per-component volume controls.
- True MIDI velocity input (currently the Default Velocity setting stands in
  for it).
- Round-robin playback for the rest of the pads, not just the kick.
