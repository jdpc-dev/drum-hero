# Song Intro Countdown

## Overview

Many rhythm games, including **Clone Hero**, **YARG**, **Rock Band**, and **Guitar Hero**, display a countdown when there is a long period of silence before the first playable note.

Rather than forcing the player to wait while nothing happens, the game shows a timer indicating when the next note will arrive.

Example:

```
Next notes in

3...
2...
1...
```

or

```
4.8 s
```

Once the first note enters the highway, the countdown disappears automatically.

---

# Purpose

The countdown serves several purposes:

- Prevents players from thinking the song has frozen.
- Lets players know exactly when gameplay will begin.
- Reduces unnecessary waiting during long intros.
- Helps players prepare their hands before the first note.

This is especially useful in songs with:

- Long ambient introductions
- Slow orchestral openings
- Spoken intros
- Guitar-only or vocal-only intros
- Drumless sections

Some community charts have over a minute before the drummer begins playing.

---

# How It Works

When the chart is loaded, the engine determines the timestamp of the first playable note.

Example:

```
Song Start
↓

First Drum Note
↓

18.450 seconds
```

If the first note is sufficiently far away, the countdown is enabled.

Pseudo-code:

```text
firstNoteTime = getFirstPlayableNote()

if firstNoteTime > countdownThreshold
    showCountdown()
```

---

# Countdown Logic

During gameplay:

```
remainingTime = firstNoteTime - currentSongTime
```

The displayed value is updated every frame.

Example:

```
18.4

18.3

18.2

...

0.5

0.4

0.3
```

Once the first note reaches the note highway, the countdown is removed.

---

# Typical Threshold

Most games do not display the countdown for very short intros.

Example:

```
0–2 seconds
```

No countdown.

```
5+ seconds
```

Countdown appears.

The exact threshold depends on the game.

---

# Which Note Is Used?

The countdown is based on the **first playable note** for the selected instrument and difficulty.

Example chart:

```
Vocals

5 s

Guitar

12 s

Bass

18 s

Drums

42 s
```

If the player selects drums:

```
Countdown

42...

41...

40...
```

If the player selects guitar:

```
Countdown

12...

11...

10...
```

Each instrument calculates its own countdown independently.

---

# Difficulty Awareness

The countdown uses the selected difficulty.

Example:

```
Easy

First note
15.2 s
```

```
Expert

First note
11.8 s
```

Because every difficulty has its own chart, the first playable note may occur at different times.

---

# What Counts as a Playable Note?

Only notes that require player interaction.

Ignored events include:

- Tempo changes
- Time signature changes
- Lyrics
- Camera events
- Lighting events
- Background animations
- Section markers
- Star power phrases
- Practice sections

The engine searches only for the first note event belonging to the selected instrument and difficulty.

---

# Runtime Flow

```
Load chart

↓

Select instrument

↓

Select difficulty

↓

Find first playable note

↓

Is first note farther than threshold?

 ├── No
 │      ↓
 │   Start normally
 │
 └── Yes
        ↓
   Display countdown

        ↓

Update every frame

        ↓

First note reaches gameplay

        ↓

Hide countdown
```

---

# Benefits for Drum Hero

This mechanic is particularly valuable for **Drum Hero**, where players often need time to position both hands and feet before the first note.

A recommended implementation is:

- Compute the timestamp of the first playable note after loading the selected chart.
- Display a countdown only if the first note occurs after a configurable threshold (e.g., 5 seconds).
- Update the remaining time continuously while no notes are visible.
- Hide the countdown automatically as soon as the first note enters the visible note highway or reaches the spawn point.

This approach improves usability without affecting gameplay timing, and it scales naturally to every instrument, chart, and difficulty.
