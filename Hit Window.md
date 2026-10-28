# Hit Window (Timing Window)

## Overview

A **Hit Window** (also called a **Timing Window** or **Judgment Window**) is the time interval around the hit line during which a note can be successfully hit.

Instead of requiring the player to strike the note at the exact instant it crosses the hit line, the game accepts inputs occurring slightly **before** or **after** the ideal timing.

```
    Too Early       Early       Perfect       Late      Too Late

---------------|------------|------------|------------|---------------

      Miss        Accepted     Accepted     Accepted      Miss
```

Without a hit window, rhythm games would be virtually impossible to play consistently due to human reaction time, input latency, display latency, and audio latency.

---

# Hit Line

The hit line represents the **ideal timing point**.

```
          Highway

              │
              │
              │
              ▼

         ● Note

═══════════════════════
       Hit Line
═══════════════════════
```

The exact moment the center of the note aligns with the hit line is called the **Perfect Time**.

```
perfectTime = note.timestamp
```

---

# Timing Window

Instead of requiring:

```
currentTime == note.timestamp
```

the engine accepts:

```
note.timestamp - hitWindow

        ≤

currentTime

        ≤

note.timestamp + hitWindow
```

Example:

```
Perfect Time

10.000 s
```

Hit Window:

```
±70 ms
```

Accepted hits:

```
9.930 s

↓

10.000 s

↓

10.070 s
```

Everything outside that interval results in a **Miss**.

---

# Visual Representation

```
            Miss

----------------------------

      Early (Accepted)

============================

         Perfect

============================

      Late (Accepted)

----------------------------

            Miss
```

A player may therefore hit:

- Slightly early (accepted)
- Exactly on time
- Slightly late (accepted)

---

# Timing Judgments

Many rhythm games divide the hit window into multiple judgment regions.

Example:

```
Early Miss

Early Good

Early Great

Perfect

Late Great

Late Good

Late Miss
```

Conceptually:

```
<----------- Early -----------|----------- Late ----------->
```

The closer the input is to the center of the hit window, the better the judgment.

---

# Example

Perfect timestamp:

```
25.000 s
```

Player input:

```
24.985 s
```

Offset:

```
-15 ms
```

Result:

```
Perfect (Early)
```

Another example:

```
25.055 s
```

Offset:

```
+55 ms
```

Result:

```
Good (Late)
```

---

# Internal Calculation

The engine calculates the timing offset:

```
offset = inputTime - note.timestamp
```

Example:

```
Input

12.438 s
```

```
Note

12.400 s
```

```
Offset

+38 ms
```

The absolute value determines the judgment:

```
abs(offset)
```

while the sign indicates the timing direction:

- Negative → Early
- Zero → Perfect timing
- Positive → Late

---

# Typical Timing Windows

Each rhythm game defines its own timing windows.

Example:

| Judgment | Window |
|----------|--------|
| Perfect | ±20 ms |
| Great | ±45 ms |
| Good | ±70 ms |
| Miss | >70 ms |

The exact values vary from game to game.

---

# Early and Late

**Early** and **Late** are **not judgments**.

They simply describe whether the player hit **before** or **after** the perfect timestamp while still remaining inside the hit window.

Example:

```
Perfect Time

10000 ms
```

Player A:

```
9980 ms

Offset = -20 ms

Perfect (Early)
```

Player B:

```
10020 ms

Offset = +20 ms

Perfect (Late)
```

Both players receive the same **Perfect** judgment because their timing error has the same magnitude.

Likewise:

```
9962 ms

Offset = -38 ms

Great (Early)
```

and

```
10038 ms

Offset = +38 ms

Great (Late)
```

Both receive **Great**.

The game may only display:

```
Perfect
```

or

```
Great
```

while internally recording whether the hit was Early or Late for statistics and calibration purposes.

---

# Visual Notes Continue Moving

The note does **not** stop when it enters the hit window.

It continues scrolling normally.

The hit window exists only as a timing comparison performed by the gameplay engine.

```
Visual Position

↓

Current Song Time

↓

Timing Comparison

↓

Judgment
```

---

# Hit Detection Algorithm

Whenever the player performs an input:

```
Locate the earliest unhit note

↓

Compute timing offset

↓

Is offset inside the hit window?

        │
   Yes ─┴─ No
    │        │
Hit Note   Ignore or Miss
```

Once a note is successfully hit, it is removed from the active note list and the engine advances to the next note.

---

# Application to Drum Hero

For **Drum Hero**, hit detection should be based entirely on **time**, not screen position.

Each note stores an exact timestamp synchronized with the song.

When the player performs an input:

```
offset = input_time - note.timestamp
```

The **magnitude** of the offset determines the judgment:

- Perfect
- Great
- Good
- Miss

The **sign** of the offset indicates the timing direction:

- Early
- On Time
- Late

Separating these two concepts provides several advantages:

- Gameplay feedback displays only the judgment (Perfect, Great, Good, Miss).
- Statistics can show whether the player tends to hit early or late.
- Calibration tools can detect systematic timing bias.
- Practice mode can visualize timing consistency.

Since judgments are calculated from timestamps rather than pixel overlap, gameplay remains accurate regardless of frame rate, display resolution, highway length, or note scrolling speed. The highway serves only as a visual timing aid, while the engine always evaluates precision using the song timeline.
