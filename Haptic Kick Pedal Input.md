# Haptic Kick Pedal Input System

## Overview

Drum Hero implements the bass drum (KICK) as a gesture-based haptic input using the smartphone's inertial sensors instead of a dedicated touch lane.

The system recognizes a short, intentional movement that simulates pressing a real drum kick pedal while the player holds the device in both hands during gameplay.

This mechanism must behave consistently across different smartphones, player postures, and device orientations.

---

# Required Sensors

## Mandatory

* Accelerometer

## Recommended

* Gravity sensor (provides faster calibration)

The implementation falls back to `Input.get_gravity()` if `Input.get_accelerometer()` is unavailable.

---

# Device Orientation

The game runs exclusively in **Landscape** orientation.

Players naturally hold the device at varying angles (typically between 30° and 60° relative to the ground).

The kick detection axis is the **screen normal** (`Vector3.BACK = (0, 0, 1)` in device coordinates, which always points toward the user). This is a fixed hardware axis in device coordinates, not a world-space axis — it works regardless of grip angle because the user's face is always in front of the screen.

---

# Detection Principle

The KICK input represents a **gesture**, not a position.

The objective is **not** to measure how far the device moved, but to recognize a short impulse that resembles the action of pressing a bass drum pedal.

The algorithm detects:

* rapid acceleration toward the user (lift toward face)
* short duration
* zero-crossing of the acceleration (transition from lift to return)
* immediate return toward the resting state

Continuous movement or sustained displacement must never generate repeated KICK events.

---

# Reference Frame

Motion analysis uses the device's **screen normal** (+Z axis, `Vector3.BACK` in Godot) as the detection axis. This axis points out of the screen toward the player at all times.

Linear acceleration is obtained by subtracting the gravity estimate from the raw accelerometer reading:

```
linear_accel = filtered_accel - gravity_estimate
```

The gravity estimate comes from `Input.get_gravity()` when available, or from a low-pass filter over the accelerometer during calibration.

---

# Detection Pipeline

```
raw accelerometer
  │
  ├─ (fallback) gravity sensor if accelerometer is zero
  │
  ▼
low-pass exponential filter (smoothing_strength = 0.4)
  │
  ▼
gravity removal → linear_accel
  │
  ▼
project onto screen normal (+Z → `_toward_axis = Vector3.BACK`)
  │
  ▼
toward_accel
  │
  ▼
two-phase gesture detection:
  Phase 1 (lift): toward > 1.0 → mark _lift_detected
  Phase 2 (zero-cross): toward <= 0.0 && _lift_detected → emit KICK
  Abort: toward < 0.5 && _lift_detected → reset lift
```

## Calibration

On song start:

1. Get `Input.get_gravity()` — if available, calibrate in ~0.5 s.
2. If no gravity sensor, calibrate in `haptic_calibration_duration` (default 1.5 s) using a low-pass estimate.
3. The detection axis is always `Vector3.BACK` (screen normal) — calibration only captures the gravity direction for proper gravity removal.

---

# State Machine

The detector behaves as a finite state machine with two phases (lift tracking + three states):

```
IDLE phase:
  [toward > 1.0] → _lift_detected = true
  [_lift_detected && toward <= 0.0] → transition to KICK_DOWN, emit KICK
  [_lift_detected && toward < 0.5] → _lift_detected = false (abort)

IDLE → [lift detected] → IDLE (lift flag set) → [zero crossing] → KICK_DOWN → COOLDOWN → IDLE
                                   ↘ [abort] → IDLE (lift flag reset)
```

A KICK event is generated only at the transition **IDLE → KICK_DOWN**.

While the detector remains inside KICK_DOWN or COOLDOWN, no additional KICK events may be generated.

The detector returns to IDLE only after the gesture has finished and the cooldown period has expired.

Cooldown default: 0.15 s. Minimum interval between kicks: 0.08 s.

---

# Gesture Recognition

A valid kick gesture is a motion along the screen normal axis (+Z):

1. **Lift**: phone moves toward face → positive acceleration on Z axis.
2. **Return**: phone moves back → acceleration crosses zero (negative during return stroke).
3. **KICK fires** at the zero crossing — the moment the acceleration transitions from positive to negative, which corresponds to the beginning of the return stroke (the "stomp").

This two-phase detection prevents false positives from single-direction impulses and ensures the kick feels connected to the return motion.

## Hysteresis

* Lift threshold: `toward > 1.0` (hardcoded, not affected by sensitivity slider)
* Abort threshold: `toward < 0.5` (hardcoded — if lift fades before crossing zero, reset)
* KICK_DOWN release: `toward < effective_release` where `effective_release = haptic_release_threshold / sensitivity`

---

# Motion Filtering

The detector rejects:

* device vibration
* screen tap vibration
* slow orientation changes
* hand repositioning
* posture adjustments
* oscillations after the primary impulse
* accidental movements during gameplay

Processing pipeline:

* gravity removal (using gravity sensor or low-pass estimate)
* exponential smoothing (`lerp_factor = 1.0 - pow(1.0 - strength, delta * 60.0)`, default `strength = 0.4`)
* two-phase gesture detection with hysteresis

---

# Sensitivity Control

The Sensitivity slider (range 0.1–3.0, default 1.0) is applied as a **divisor**:

```
effective_threshold = base_threshold / sensitivity
```

Higher sensitivity = lower effective threshold = easier to trigger kick.

The sensitivity affects only the KICK_DOWN release threshold. The lift and abort thresholds (1.0 and 0.5) are fixed to match natural gesture acceleration values.

---

# False Positive Prevention

The system must not generate a KICK event when the player:

* slightly tilts the device
* performs lateral movements
* taps any drum lane
* adjusts grip
* experiences minor hand tremors
* performs slow continuous movements

Only a deliberate kick-like impulse should be accepted. The two-phase detection (lift → zero-cross → kick) inherently rejects single-direction jolts.

---

# Double Kick Support

The system does **not** distinguish between left and right kick pedals.

Smartphone inertial sensors describe the motion of the device as a single rigid body and cannot determine which hand or side generated the movement.

Double bass patterns are therefore interpreted as two independent kick gestures.

Each valid impulse generates exactly one KICK event.

If two valid impulses occur within the timing constraints defined by the chart and game difficulty, both must be registered independently.

The implementation should never introduce separate concepts such as Left Kick or Right Kick.

---

# Configurable Parameters

All detection parameters are externally configurable through the settings UI and saved to `user://settings.cfg`.

| Parameter | Default | Description |
|---|---|---|
| `haptic_sensitivity` | 1.0 | Divisor applied to release threshold (higher = more sensitive) |
| `haptic_activation_threshold` | 1.5 | Base activation threshold (not directly used in lift detection — lift uses fixed 1.0) |
| `haptic_release_threshold` | 0.3 | Release threshold for KICK_DOWN state |
| `haptic_smoothing_strength` | 0.4 | Filter responsiveness (0 = max smoothing, 1 = no filter) |
| `haptic_cooldown_duration` | 0.15 | Time in COOLDOWN state (s) |
| `haptic_min_interval` | 0.08 | Minimum interval between consecutive KICK events (s) |
| `haptic_calibration_duration` | 1.5 | Calibration time without gravity sensor (s) |
| `haptic_show_debug` | false | Show on-screen haptic debug overlay |

## Lift / abort thresholds (hardcoded)

| Threshold | Value | Purpose |
|---|---|---|
| Lift activation | 1.0 | `toward > 1.0` marks `_lift_detected` |
| Lift abort | 0.5 | `toward < 0.5` resets `_lift_detected` without firing |
| Zero-crossing | 0.0 | `toward <= 0.0` + `_lift_detected` fires the KICK |

---

# Debug Overlay

Toggleable via **Settings → Haptic → Show Haptic Debug** or `haptic_show_debug = true`.

Displays on screen:

* State machine state (IDLE / KICK_DOWN / COOLDOWN)
* Sensor source (ACCEL / GRAVITY / DESKTOP)
* `_lift_detected` flag
* Raw accelerometer and gravity values
* Filtered linear acceleration
* Current `toward_accel` value

---

# Design Goals

The kick detection system should provide reliable and consistent gameplay regardless of:

* smartphone model
* device weight
* screen size
* player posture
* natural grip angle
* dominant hand

Players should never be required to learn a precise movement along a specific hardware axis.

Instead, they should simply perform a natural kick-like motion while the algorithm recognizes the corresponding inertial pattern through the two-phase detection pipeline.

