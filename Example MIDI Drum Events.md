# Example MIDI Drum Events

## Snare

```
Time: 12.500

Red Note
```

Result:

```
Snare
```

---

## Kick

```
Time: 12.750

Kick Note
```

Result:

```
Kick
```

---

## Hi-Hat (Cymbal, Default)

```
Time: 13.000

Yellow Drum Note
(no tom marker)
```

Result:

```
Hi-Hat
```

---

## Yellow Tom

```
Time: 13.000

Yellow Drum Note

Yellow Tom Marker (MIDI 110)
```

Result:

```
Tom 1
```

---

## Ride (Cymbal, Default)

```
Time: 13.500

Blue Drum Note
(no tom marker)
```

Result:

```
Ride
```

---

## Blue Tom

```
Time: 13.500

Blue Drum Note

Blue Tom Marker (MIDI 111)
```

Result:

```
Tom 2
```

---

## Crash (Cymbal, Default)

```
Time: 14.000

Green Drum Note
(no tom marker)
```

Result:

```
Crash
```

---

## Green Tom

```
Time: 14.000

Green Drum Note

Green Tom Marker (MIDI 112)
```

Result:

```
Tom 3
```

---

# Mixed Example

A fill could appear as:

```
14.000
Yellow Drum Note
(no marker -> Hi-Hat)

14.250
Blue Drum Note
Blue Tom Marker (MIDI 111 -> Tom 2)

14.500
Green Drum Note
(no marker -> Crash)

14.750
Red Note

15.000
Kick Note
```

The importer interprets it as:

```
Hi-Hat

↓

Tom 2

↓

Crash

↓

Snare

↓

Kick
```

---

# Internal Representation

The MIDI itself never stores separate "Tom 1", "Ride", "Crash", or "Hi-Hat" notes.

Instead, it stores drum notes at fixed positions (Yellow, Blue, Green) and optional tom markers.

**In MIDI, notes are cymbals by default.** A Yellow note without a tom marker is a Hi-Hat. A Yellow note with a tom marker is a Tom 1.

The importer is responsible for converting those combinations into drum components.

---

# Drum Hero Import Mapping

| MIDI Event | Drum Hero Component |
|------------|---------------------|
| Red | Snare |
| Kick | Kick |
| Yellow (no marker) | Hi-Hat |
| Yellow + Tom Marker (110) | Tom 1 |
| Blue (no marker) | Ride |
| Blue + Tom Marker (111) | Tom 2 |
| Green (no marker) | Crash |
| Green + Tom Marker (112) | Tom 3 |
