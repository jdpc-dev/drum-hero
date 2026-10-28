# DRUM HERO

## ASCII GAMEPLAY REFERENCE

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

## ASCII MAIN MENU REFERENCE

+-----------------------------------------------------------------------------+
|                                DRUM HERO                           Settings |
+-----------------------------------------------------------------------------+
| Search: ________________________________________________________________ 🔍 |
+-----------------------------------------------------------------------------+
|                                                                             | s
| ► Through the Fire and Flames - DragonForce                     12,000pts   | c
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
| Easy            Medium            Hard            Expert            Expert+ |
+-----------------------------------------------------------------------------+

## ASCII SETTINGS MENU REFERENCE

+-----------------------------------------------------------------------------+
|                                SETTINGS                                Back |
+-----------------------------------------------------------------------------+
| CONTROLS | HUD | Experimental                                               |
+-----------------------------------------------------------------------------+
| CONTROLS TAB                                                                 |
|                                                                             |
| CONTROL MODE                                                                |
| Default    8 lanes — all drum parts visible                                 |
| Haptic     7 lanes — KICK via device motion sensor                          |
| Custom     Reorder lanes manually                                           |
|                                                                             |
| LANE ORDER (CUSTOM MODE)                                                    |
| ▲ ▼ [color] HH                                                              |
| ▲ ▼ [color] CRASH                                                           |
| ...                                                                         |
|                                                                             |
| HAPTIC                                                                      |
| Enable Haptic Kick                                                          |
| Sensitivity        [====o====================] 1.0                          |
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
| Use PART GUITAR as fallback                                                 |
| For songs without PART DRUMS, use PART GUITAR notes as a drum chart         |
+-----------------------------------------------------------------------------+

## PROJECT DESCRIPTION
Drum Hero its a mobile rhythm game similar to Rock Band, Guitar Hero, Clone Hero and YARG focused exclusively on the drum instrument.
Based on InstaDrum alternative play mode "gameplay.png" that shows a 8 lanes (drum parts):
HIH CLOSED & HIH OPEN, CRASH, SNARE, KICK, TOM 1, TOM 2, TOM 3, RIDE

## IN GAME SPECS
landscape orientation
shows a 8 lanes: HIH CLOSED & HIH OPEN, CRASH, SNARE, KICK, TOM 1, TOM 2, TOM 3, RIDE
offers 3 control settings: default (shows the 8 lanes in their original order), haptic (only shows 7 lanes, The KICK note goes down, covering all the lines, just like in Rock Band or Guitar Hero and its input its specified in "Haptic Kick Pedal Input.md"), custom (allows user to reorder drum lanes and switch haptics)
visible song timeline at the top of the screen
countdown indicator during long silences (intro and mid-song gaps)
combo counter
shock wave effect on CRASH note hit
compatible with community-created songs for Clone Hero and YARG:
/songs/artist-song/
.
├── album.jpg
├── background.jpg
├── bass.opus
├── drums.opus
├── guitar.opus
├── rhythm.opus
├── keys.opus
├── notes.mid
├── song.ini
├── song.opus
└── vocals.opus
