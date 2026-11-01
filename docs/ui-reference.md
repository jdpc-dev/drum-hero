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
|  Settings > Advanced)                                                       |
+-----------------------------------------------------------------------------+
| Easy            Medium            Hard            Expert            Expert+ |
+-----------------------------------------------------------------------------+
```

## ASCII SETTINGS MENU REFERENCE
```
+-----------------------------------------------------------------------------+
| +---------------+  Controls                                   [ Back ]      |
| | DRUM HERO     |  How the pads play, how the lanes are arranged...        |
| | Settings      |                                                          |
| |               |  +-----------------------------------------------------+ |
| | > CONTROLS    |  | CONTROL MODE                                        | |
| |   GAMEPLAY    |  | [ Default ] [ Haptic ] [ Custom ]                   | |
| |   AUDIO       |  | 8 lanes - every drum part is visible...             | |
| |   SONGS       |  +-----------------------------------------------------+ |
| |   ADVANCED    |  +-----------------------------------------------------+ |
| |               |  | LAYOUT                                              | |
| |               |  | (o) Mirrored layout                                 | |
| |               |  |      Flip the highway from left to right.           | |
| |               |  | ( ) Left-handed mode                                | |
| |               |  +-----------------------------------------------------+ |
| | About Drum    |  +-----------------------------------------------------+ |
| | Hero          |  | HAPTIC KICK                                         | |
| | Version 7.0.0 |  | (o) Enable haptic kick                              | |
| +---------------+  | Sensitivity                            [ 1.0 ]      | |
|                    | [==========o=====================]                   | |
|                    | Advanced tuning  +                                  | |
|                    +-----------------------------------------------------+ |
|                    +-----------------------------------------------------+ |
|                    | FREE MODE                                           | |
|                    | [ Open Free Mode ]                                  | |
|                    +-----------------------------------------------------+ |
+-----------------------------------------------------------------------------+
```
```
Compact layout (< 1000 px physical width):
+-----------------------------------------------------------------------------+
| Controls                                             [ About ] [ Back ]     |
| How the pads play...                                                        |
| +------------------+------------------+------------------+-----------------+ |
| | CONTROLS         | GAMEPLAY         | AUDIO            | SONGS ...       | |
| +------------------+------------------+------------------+-----------------+ |
| +-------------------------------------------------------------------------+ |
| | CONTROL MODE                                                            | |
| | [ Default ] [ Haptic ] [ Custom ]                                       | |
| +-------------------------------------------------------------------------+ |
```
```
Tabs and content:
- CONTROLS: mode, lane order (Custom), layout, haptic kick, Free Mode, reset.
- GAMEPLAY: speed & pacing, feedback, performance, timing & calibration, reset.
- AUDIO: master/music/drums/previews, drum samples, reset.
- SONGS: need songs, storage access, library locations, extra folders, scan, reset.
- ADVANCED: compatibility, debug, screen padding, reset.
- About: modal with version and credits (opened from the sidebar/header).
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
