# Next Notes Countdown

## Overview

In games such as **Clone Hero**, **YARG**, and **Rock Band**, the countdown is **not limited to the beginning of a song**. It can appear **any time there is a sufficiently long gap between playable notes** for the currently selected instrument.

The feature informs the player that no input is required for several seconds and indicates when the next playable note will arrive.

Example:

```
Next Notes

3...

2...

1...
```

or

```
4.8 s
```

---

# Purpose

This mechanic improves gameplay by:

- Informing the player that the current silence is intentional.
- Preventing players from expecting notes during long rests.
- Giving players time to relax their hands or reposition.
- Making long breaks feel intentional instead of appearing as missing notes.

This is especially useful for drum charts, where many songs contain extended rests while vocals, guitars, keyboards, or other instruments continue playing.

---

# How It Works

Instead of checking only the first note, the engine continuously evaluates the distance between the **current playback position** and the **next playable note**.

```
Current Song Time

↓

Find next playable note

↓

Compute remaining time

↓

If gap exceeds threshold

↓

Display countdown
```

---

# Runtime Logic

Every frame (or at regular intervals), the engine searches for the next note after the current playback position.

Pseudo-code:

```text
nextNote = getNextPlayableNote(currentTime)

remainingTime = nextNote.time - currentTime

if remainingTime > countdownThreshold
    showCountdown(remainingTime)
else
    hideCountdown()
```

---

# Example

```
0 s
Kick

2 s
Snare

4 s
Crash

----------------------------------

Next note

15 s
Ride
```

Current playback:

```
5.0 s
```

Remaining time:

```
15 - 5 = 10 seconds
```

If the countdown threshold is 5 seconds:

```
10 > 5

↓

Display

10...

9...

8...
```

The countdown disappears automatically once the Ride note enters the visible note highway.

---

# Instrument-Specific Behavior

The countdown is calculated **only from the currently selected instrument**.

Example:

```
Song Timeline

0 s
Vocals

5 s
Guitar

8 s
Bass

30 s
Drums
```

If the player is performing drums:

```
Countdown

30...

29...

28...
```

Although other instruments are active, the drum player has nothing to play until 30 seconds.

---

# Difficulty-Specific Behavior

The countdown also depends on the selected difficulty.

Example:

```
Expert

8 s
Kick

9 s
Snare

10 s
Crash
```

```
Easy

15 s
Kick
```

Because each difficulty contains different note charts, the next playable note may occur at different times.

---

# Visibility Rules

The countdown is typically shown only when:

- No playable notes are currently visible.
- The next playable note is farther away than a configurable threshold.
- The player has no required input during the waiting period.

It disappears immediately when:

- A note enters the visible note highway.
- The remaining time falls below the configured threshold.
- Gameplay resumes.

---

# Recommended Implementation

Maintain a sorted list of note timestamps for the selected instrument and difficulty.

During gameplay:

```
Current Time

↓

Next Note

↓

Remaining Time

↓

Remaining Time > Threshold?

        │
   Yes ─┴─ No
    │        │
Show      Hide
Countdown Countdown
```

Since notes are already ordered chronologically, the engine only needs to keep an index pointing to the next unplayed note. This makes the feature extremely efficient, requiring constant-time updates during gameplay rather than repeatedly searching the entire chart.

---

# Application to Drum Hero

For **Drum Hero**, the countdown should be treated as a general gameplay feature rather than an intro-only feature.

It should appear whenever:

- The selected drum chart contains a long rest.
- No upcoming notes are currently visible on the highway.
- The next playable note is farther away than a configurable threshold (for example, 5 seconds).

This allows players to comfortably relax during long instrumental breaks while maintaining awareness of exactly when gameplay will resume.
