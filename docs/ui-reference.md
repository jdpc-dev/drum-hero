# UI Reference

ASCII references for the gameplay screen, main menu, settings tabs and Free Mode. These are layout specifications, not screenshots.

---

## ASCII GAMEPLAY REFERENCE
```
+-------------------------------------------------------------------------------------------------------+
|                                             SONG TIMELINE                                             |
+------------+------------+------------+------------+------------+------------+------------+------------+
|            |            |            |            |            |            |            |            |h
|            |            |            |            |            |            |            |            |i
|            |            |            |            |            |            |            |            |g
|            |            |            |            |            |            |            |            |h
|            |            |            |            |            |            |            |            |w
|            |            |            |            |            |            |            |            |a
|            |            |            |            |            |            |            |            |y
+------------+------------+------------+------------+------------+------------+------------+------------+
|  HIT LINE  |  HIT LINE  |  HIT LINE  |  HIT LINE  |  HIT LINE  |  HIT LINE  |  HIT LINE  |  HIT LINE  |
+------------+------------+------------+------------+------------+------------+------------+------------+
| HIH CLOSED |            |            |            |            |            |            |            |
|      &     |    CRASH   |    SNARE   |    KICK    |    TOM 1   |    TOM 2   |    TOM 3   |    RIDE    |
|  HIH OPEN  |            |            |            |            |            |            |            |
+------------+------------+------------+------------+------------+------------+------------+------------+
```

## ASCII MAIN MENU REFERENCE
```
+-----------------------------------------------------------------------------+
|                                DRUM HERO                           Settings |
+-----------------------------------------------------------------------------+
| Search: ________________________________________________________________ 🔍 |
+-----------------------------------------------------------------------------+
|                                                                             | s
| ► Through the Fire and Flames - DragonForce                     12,000pts  | c
|   Everlong - Foo Fighters                                        8,000pts   | r
|   Battery - Metallica                                           --,---pts   | o
|   Chop Suey! - System of a Down                                 60,000pts   | l
|   Welcome Home - Coheed and Cambria                             --,---pts   | l 
|   The Pretender - Foo Fighters                                  --,---pts   | a
|   Panic Attack - Dream Theater                                  12,000pts   | b
|   Painkiller - Judas Priest                                    200,000pts   | l
|   Free Bird - Lynyrd Skynyrd                                    30,000pts   | e
|                                                                             |
+-----------------------------------------------------------------------------+
|                      STATUS: chart OK - missing audio                       |
+-----------------------------------------------------------------------------+
| (status row hidden by default; enabled with "Show Menu Status" in           |
|  Settings > Experimental)                                                   |
+-----------------------------------------------------------------------------+
| Easy            Medium            Hard            Expert            Expert+ |
+-----------------------------------------------------------------------------+
```

## ASCII SETTINGS MENU REFERENCE
```
+-----------------------------------------------------------------------------+
|                                SETTINGS                                Back |
+-----------------------------------------------------------------------------+
| CONTROLS | HUD | Experimental                                               |
+-----------------------------------------------------------------------------+
| CONTROLS TAB                                                                |
|                                                                             |
| CONTROL MODE                                                                |
| Default    8 lanes — all drum parts visible                                 |
| Haptic     7 lanes — KICK via device motion sensor (two-phase detection: lift → zero-cross → fire) |
| Custom     Reorder lanes manually                                           |
|                                                                             |
| LANE ORDER (CUSTOM MODE)                                                    |
| ▲ ▼ [color] HH                                                             |
| ▲ ▼ [color] CRASH                                                          |
| ...                                                                         |
|                                                                             |
| HAPTIC                                                                      |
| Enable Haptic Kick                                                          |
| Sensitivity        [====o====================] 1.0                          |
| ADVANCED HAPTIC TUNING                                                      |
| Activation          [====o====================] 1.5                         |
| Release             [====o====================] 0.3                         |
| Cooldown (s)        [====o====================] 0.15                        |
| Min Interval (s)    [====o====================] 0.08                        |
| Smoothing           [====o====================] 0.4                         |
| Show Haptic Debug   [ ]                                                     |
|                                                                             |
| LAYOUT                                                                      |
| Mirrored Layout                                                             |
| Left Handed Mode                                                            |
+-----------------------------------------------------------------------------+
| HUD TAB                                                                     |
+-----------------------------------------------------------------------------+
| VISUAL                                                                      |
| Show FPS                                                                    |
| Screen Shake                                                                |
|                                                                             |
| GAMEPLAY                                                                    |
| Note Speed           [========o=============] x1.0                          |
| Silence Countdown    [===o==================] 5.0s                          |
|                                                                             |
| JUDGEMENT WINDOWS                                                           |
| Perfect      ±22.5 ms                                                       |
| Excellent    ±45.0 ms                                                       |
| Good         ±75.0 ms                                                       |
| Late         ±100.0 ms                                                      |
| Early        ±100.0 ms                                                      |
| Miss         ±135.0 ms                                                      |
+-----------------------------------------------------------------------------+
| EXPERIMENTAL TAB                                                            |
+-----------------------------------------------------------------------------+
| FREE MODE                                                                   |
| [ Open Free Mode ]                                                          |
| Drum testing without a song: empty highway, tap any pad to hear it.         |
|                                                                             |
| Use PART GUITAR as fallback                                                 |
| For songs without PART DRUMS, use PART GUITAR notes as a drum chart         |
+-----------------------------------------------------------------------------+
```

## ASCII FREE MODE REFERENCE
```
+-----------------------------------------------------------------------------+
|                                 FREE MODE                   [ BACK TO MENU ] |
|                                                                             |
|      Tap a pad or press 1-8  -  no song, no score                           |
|                                                                             |
|                                    SNARE                                    |
|                                  3 hits                                     |
|                                                                             |
|  |  HH  | CRASH | SNARE |  KICK  | TOM 1 | TOM 2 | TOM 3 |  RIDE  |         |
|  +------+-------+-------+--------+-------+-------+-------+--------+         |
|  ========================================================================   |
+-----------------------------------------------------------------------------+
| Tap any pad (or press 1-8) to play its sample. The pad name and a hit       |
| counter appear in the middle; the kick also fires from the motion sensor    |
| when haptic kick is enabled. No notes, no score, no results.                |
+-----------------------------------------------------------------------------+
```
