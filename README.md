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
