# Drum Hero Documentation

This directory contains the design specifications and development notes for Drum Hero. The [root README](../README.md) covers installation, controls, song folders and building the project; the documents here explain how the systems work.

New to the codebase? Read [architecture.md](architecture.md) first, then follow the gameplay systems below in order.

## Reading order

| # | Document | Topic |
|:--:|---|---|
| 1 | [architecture.md](architecture.md) | Runtime scene tree, autoloads, audio pipeline, input handling, chart formats, Android builds and settings (Spanish). |
| 2 | [gameplay/01-song-timeline.md](gameplay/01-song-timeline.md) | The master song clock that drives every gameplay element. |
| 3 | [gameplay/02-hit-window.md](gameplay/02-hit-window.md) | Timing windows, judgments and late/early behavior. |
| 4 | [gameplay/03-beat-lines-system.md](gameplay/03-beat-lines-system.md) | Measure lines and beat lines on the highway. |
| 5 | [gameplay/04-beat-line-placement.md](gameplay/04-beat-line-placement.md) | Generating beat line positions from the tempo map. |
| 6 | [gameplay/05-song-intro-countdown.md](gameplay/05-song-intro-countdown.md) | Countdown before the first playable note. |
| 7 | [gameplay/06-next-notes-countdown.md](gameplay/06-next-notes-countdown.md) | Countdown during long rests between notes. |
| 8 | [gameplay/07-crash-shockwave.md](gameplay/07-crash-shockwave.md) | CRASH hit shockwave effect specification. |
| 9 | [gameplay/08-drum-sfx-system.md](gameplay/08-drum-sfx-system.md) | Local drum samples and their relationship to song stems. |
| 10 | [input/01-haptic-kick-pedal.md](input/01-haptic-kick-pedal.md) | Accelerometer gesture detection for the kick pedal. |
| 11 | [charts/01-drums-in-rhythm-games.md](charts/01-drums-in-rhythm-games.md) | Drum controller and lane layouts across rhythm games. |
| 12 | [charts/02-drums-difficulty-system.md](charts/02-drums-difficulty-system.md) | How each difficulty is stored in `.mid` and `.chart` charts. |
| 13 | [charts/03-rock-band-drums-system.md](charts/03-rock-band-drums-system.md) | Detecting 4-lane drums vs. Pro Drums through tom markers. |
| 14 | [charts/04-implementing-notes-chart.md](charts/04-implementing-notes-chart.md) | `.chart` importer specification and lane mapping. |
| 15 | [charts/05-example-midi-drum-events.md](charts/05-example-midi-drum-events.md) | Worked examples of MIDI drum events and markers. |
| 16 | [ui-reference.md](ui-reference.md) | ASCII layouts for gameplay, menus, settings and Free Mode. |

## By topic

### Development

- [architecture.md](architecture.md) — full development guide (Spanish).
- [ui-reference.md](ui-reference.md) — screen and menu layout specifications.

### Gameplay

- [gameplay/01-song-timeline.md](gameplay/01-song-timeline.md)
- [gameplay/02-hit-window.md](gameplay/02-hit-window.md)
- [gameplay/03-beat-lines-system.md](gameplay/03-beat-lines-system.md)
- [gameplay/04-beat-line-placement.md](gameplay/04-beat-line-placement.md)
- [gameplay/05-song-intro-countdown.md](gameplay/05-song-intro-countdown.md)
- [gameplay/06-next-notes-countdown.md](gameplay/06-next-notes-countdown.md)
- [gameplay/07-crash-shockwave.md](gameplay/07-crash-shockwave.md)
- [gameplay/08-drum-sfx-system.md](gameplay/08-drum-sfx-system.md)

### Input

- [input/01-haptic-kick-pedal.md](input/01-haptic-kick-pedal.md)

### Charts and song format

- [charts/01-drums-in-rhythm-games.md](charts/01-drums-in-rhythm-games.md)
- [charts/02-drums-difficulty-system.md](charts/02-drums-difficulty-system.md)
- [charts/03-rock-band-drums-system.md](charts/03-rock-band-drums-system.md)
- [charts/04-implementing-notes-chart.md](charts/04-implementing-notes-chart.md)
- [charts/05-example-midi-drum-events.md](charts/05-example-midi-drum-events.md)

## Related

- [Project README](../README.md)
- [License](../LICENSE)
