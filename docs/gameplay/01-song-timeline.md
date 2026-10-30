# Song Timeline System

## Overview

The Song Timeline is the central time reference used by Drum Hero.

Every gameplay element is synchronized using a single continuously increasing timestamp that represents the current playback position of the song.

Rather than moving notes based on frame count or animation time, the game determines each object's position by comparing its timestamp against the current song time.

```
Song Audio

↓

Current Song Time

↓

Gameplay Timeline

↓

Notes
Beat Lines
Countdown
Judgments
Events
```

This guarantees perfect synchronization between gameplay and audio.

---

# Timeline Origin

The timeline begins when audio playback starts.

```
0.000 s
```

represents the first sample of the song.

Every object in the chart references this timeline.

Example:

| Event | Timestamp |
|--------|----------:|
| Song Start | 0.000 s |
| Beat Line | 1.500 s |
| Snare Note | 2.000 s |
| Crash Note | 2.750 s |
| BPM Change | 18.000 s |
| Measure Marker | 20.000 s |

---

# Timeline Components

Every gameplay event is timestamp-based.

Examples include:

- Notes
- Beat Lines
- Measure Lines
- BPM changes
- Time signature changes
- Countdown calculations
- Practice sections
- Camera events (future)
- Background animations (future)

The timeline acts as the master clock for every gameplay system.

---

# Current Song Time

The audio engine continuously provides the current playback position.

Example:

```
currentSongTime

↓

12.483 seconds
```

Every gameplay system reads this value.

The timeline itself never pauses or advances independently of the audio.

---

# Note Position

Notes are not animated manually.

Instead, their position is calculated every frame.

```
remainingTime

=

note.timestamp

-

currentSongTime
```

Example:

```
Current Time

10.200 s
```

```
Note Time

12.200 s
```

```
Remaining

2.000 s
```

Since the note is exactly two seconds away, it should appear at the spawn position.

One second later:

```
Current

11.200 s
```

```
Remaining

1.000 s
```

The note is now halfway down the highway.

When:

```
remainingTime = 0
```

the note reaches the hit line.

---

# Scroll Speed

The timeline never changes speed.

Instead, the note position is calculated using the current scroll speed.

Conceptually:

```
remainingTime

↓

Travel Distance

↓

Highway Position
```

Changing the highway speed only changes the visual mapping between time and distance.

The song timeline remains unchanged.

---

# Beat Lines

Beat Lines are generated from timestamps.

Example:

```
Beat

15.000 s
```

Current time:

```
13.000 s
```

Remaining:

```
2.000 s
```

The Beat Line appears at the same vertical position that a note scheduled for 15.000 seconds would occupy.

This guarantees perfect synchronization between notes and timing guides.

---

# Countdown System

The countdown also uses the timeline.

```
Next Note Time

42.500 s
```

Current time:

```
36.200 s
```

Remaining:

```
6.300 s
```

Countdown:

```
6.3 s
```

No special countdown timer exists.

It is simply another calculation based on the timeline.

---

# Hit Detection

When the player performs an input:

```
offset

=

inputTime

-

note.timestamp
```

The resulting offset determines the hit judgment.

Because both timestamps belong to the same timeline, hit accuracy is independent of frame rate and rendering speed.

---

# BPM Changes

Tempo changes do not modify the timeline.

Instead, they affect how beat timestamps are generated.

Example:

```
Timeline

──────────────►

0 s

10 s

20 s

30 s
```

At:

```
15.000 s
```

the chart may define a BPM change.

The timeline continues increasing normally.

Only the spacing between future Beat Lines changes.

---

# Seeking

Because every gameplay object is timestamp-based, seeking becomes straightforward.

Example:

```
Seek

↓

45.000 s
```

The engine immediately computes:

- Visible notes
- Beat Lines
- Countdown
- Measure markers

using the new timeline position.

No gameplay state needs to be replayed from the beginning.

---

# Pausing

When gameplay is paused:

```
Audio

↓

Paused

↓

Timeline

↓

Frozen
```

Since the timeline no longer advances, every gameplay object remains stationary.

Upon resuming, the timeline continues from the exact same timestamp.

---

# Advantages

A timeline-driven architecture provides several benefits:

- Perfect synchronization with audio.
- Frame rate independence.
- Resolution independence.
- Scroll speed independence.
- Simple support for seeking and practice mode.
- Automatic synchronization of all gameplay systems.
- Consistent behavior across all songs and BPM values.

---

# Architecture

```
Song Audio
      │
      ▼
Current Song Time
      │
      ├───────────────┐
      │               │
      ▼               ▼
 Note System     Beat Line System
      │               │
      ├───────────────┤
      ▼               ▼
Countdown       Hit Detection
      │               │
      └───────────────┘
              │
              ▼
         Gameplay State
```

## Design Principle

The Song Timeline is the single source of truth for gameplay timing.

Every interactive and visual gameplay element should derive its state from the current song time rather than maintaining independent timers or animations. This ensures deterministic behavior, perfect synchronization with the music, and a simplified gameplay architecture.
