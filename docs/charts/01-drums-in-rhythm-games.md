# Drum Controller Types

Most rhythm games categorize drum controllers by the number of playable lanes (pads/cymbals) and the supported hardware. While naming varies between games, nearly all layouts are derived from the Rock Band and Guitar Hero drum controllers or from MIDI electronic drum kits.

---

# 4-Lane Drums (Rock Band)

The original Rock Band drum layout.

## Layout

| Lane | Instrument |
|------|------------|
| Red | Snare |
| Yellow | Hi-Hat / Tom 1 |
| Blue | Tom 2 |
| Green | Floor Tom / Crash |
| Kick | Bass Drum |

**Hardware**
- 4 pads
- 1 kick pedal

**Used by**
- Rock Band
- Clone Hero
- YARG

---

# 4-Lane Pro Drums

Adds cymbal differentiation while keeping the same four drum pads.

## Pads

| Color | Instrument |
|--------|------------|
| Red | Snare |
| Yellow | Tom 1 |
| Blue | Tom 2 |
| Green | Floor Tom |

## Cymbals

| Color | Instrument |
|--------|------------|
| Yellow | Hi-Hat |
| Blue | Ride |
| Green | Crash |

## Kick

- Bass Drum

**Hardware**
- 4 pads
- 3 cymbals
- 1 kick pedal

This is the standard layout for most electronic drum kits configured for Rock Band.

---

# 5-Lane Drums (Guitar Hero)

Introduced with Guitar Hero World Tour.

## Layout

| Lane | Instrument |
|------|------------|
| Red | Drum Pad |
| Yellow | Drum Pad |
| Blue | Drum Pad |
| Orange | Drum Pad |
| Green | Drum Pad |
| Kick | Bass Drum |

Unlike Rock Band Pro Drums, lanes do not distinguish between toms and cymbals.

**Hardware**
- 5 pads
- 1 kick pedal

---

# 5-Lane Pro (Community Layout)

An unofficial layout sometimes used by community projects.

Example mapping:

| Lane | Instrument |
|------|------------|
| Red | Snare |
| Yellow | Hi-Hat |
| Blue | Tom |
| Orange | Ride |
| Green | Crash |
| Kick | Bass Drum |

There is no official standard.

---

# 6-Lane Drums

Rarely implemented.

Typical mapping:

- Hi-Hat
- Crash
- Snare
- Tom 1
- Tom 2
- Floor Tom
- Kick

Mostly found in experimental rhythm engines.

---

# 7-Lane Drums

A common custom layout among electronic drum users.

Typical mapping:

| Lane |
|------|
| Hi-Hat |
| Crash |
| Snare |
| Tom 1 |
| Tom 2 |
| Tom 3 |
| Ride |
| Kick |

Separates Ride and Crash into independent lanes.

---

# 8-Lane Drums

Common in advanced drum simulators.

Typical mapping:

| Lane |
|------|
| Closed Hi-Hat |
| Open Hi-Hat |
| Crash |
| Snare |
| Tom 1 |
| Tom 2 |
| Tom 3 |
| Ride |
| Kick |

This closely resembles a simplified acoustic drum kit while remaining suitable for rhythm gameplay.

---

# 9-Lane Drums

Adds a second crash cymbal.

Typical mapping:

| Lane |
|------|
| Closed Hi-Hat |
| Open Hi-Hat |
| Crash Left |
| Crash Right |
| Snare |
| Tom 1 |
| Tom 2 |
| Tom 3 |
| Ride |
| Kick |

---

# Full MIDI / Electronic Drum Kits

No fixed lane count.

Possible inputs include:

- Closed Hi-Hat
- Open Hi-Hat
- Continuous Hi-Hat Position
- Splash
- Crash Left
- Crash Right
- China
- Ride Bow
- Ride Edge
- Ride Bell
- Snare Center
- Snare Rim
- Cross Stick
- Tom 1
- Tom 2
- Tom 3
- Tom 4
- Single Kick
- Double Kick
- Auxiliary Pads

Every input can be freely mapped by the user.

---

# Supported Layouts by Game

| Game | 4-Lane | Pro Drums | 5-Lane | MIDI / E-Drums |
|------|:------:|:---------:|:------:|:--------------:|
| Clone Hero | ✅ | ✅ | ✅ | ✅ |
| YARG | ✅ | ✅ | ✅ | ✅ |
| Rock Band | ✅ | ✅ | ❌ | ✅ |
| Guitar Hero World Tour | ❌ | ❌ | ✅ | Limited |

---

# Drum Hero (Proposed Layout)

Drum Hero uses a custom **8-Lane Hybrid Drum Kit** designed to bridge the gap between traditional rhythm games and real drum performance.

## Layout

| Lane | Instrument |
|------|------------|
| 1 | Closed Hi-Hat |
| 2 | Open Hi-Hat |
| 3 | Crash |
| 4 | Snare |
| 5 | Tom 1 |
| 6 | Tom 2 |
| 7 | Tom 3 |
| 8 | Ride |
| Kick | Bass Drum (Haptic or Physical Pedal) |

Unlike most rhythm games, **Closed Hi-Hat** and **Open Hi-Hat** occupy independent lanes, allowing charts to represent hi-hat articulations without relying on modifiers or note states. Double-kick support is treated as an input configuration rather than an additional gameplay lane, preserving visual simplicity while supporting advanced players.

