# Haptic Kick Pedal Input System

## Overview

Drum Hero implements the bass drum (KICK) as a gesture-based haptic input using the smartphone's inertial sensors instead of a dedicated touch lane.

The system recognizes a short, intentional movement that simulates pressing a real drum kick pedal while the player holds the device in both hands during gameplay.

This mechanism must behave consistently across different smartphones, player postures, and device orientations.

---

# Required Sensors

## Mandatory

* Accelerometer
* Gyroscope

## Recommended

* Linear Acceleration
* Rotation Vector (or any equivalent orientation estimation sensor)

If Linear Acceleration or Rotation Vector are unavailable on the target platform, they should be derived through sensor fusion using the accelerometer and gyroscope.

The implementation should always prefer the highest-level motion APIs provided by the operating system.

---

# Device Orientation

The game runs exclusively in **Landscape** orientation.

Players naturally hold the device at varying angles (typically between 30° and 60° relative to the ground), therefore the implementation **must never assume a fixed physical orientation**.

The kick detection algorithm must remain independent of the device's absolute orientation.

---

# Detection Principle

The KICK input represents a **gesture**, not a position.

The objective is **not** to measure how far the device moved, but to recognize a short impulse that resembles the action of pressing a bass drum pedal.

The algorithm should detect:

* rapid acceleration
* short duration
* immediate return toward the resting state

Continuous movement or sustained displacement must never generate repeated KICK events.

---

# Reference Frame

Motion analysis should be performed relative to the device's current orientation.

The implementation should:

1. Obtain the current device orientation.
2. Transform linear acceleration into the chosen reference frame.
3. Evaluate the impulse along the screen's forward (normal) direction rather than relying on a fixed hardware axis (X, Y or Z).

This approach guarantees consistent behavior regardless of how the player holds the device.

---

# State Machine

The detector should behave as a finite state machine.

Suggested states:

* Idle
* KickDown
* Cooldown

A KICK event is generated only during the transition:

Idle → KickDown

While the detector remains inside KickDown or Cooldown, no additional KICK events may be generated.

The detector returns to Idle only after the gesture has finished and the cooldown period has expired.

---

# Gesture Recognition

A valid kick gesture should satisfy all of the following characteristics:

* sudden acceleration impulse
* expected movement direction
* short temporal duration
* return to the resting state

The algorithm should recognize motion patterns instead of absolute positions.

---

# Initial Calibration

Before gameplay begins, the system should automatically calibrate itself.

Suggested procedure:

1. Ask the player to hold the device naturally for approximately 1–2 seconds.
2. Record the current orientation as the neutral reference.
3. Use this orientation for subsequent motion analysis.

The player should never be required to hold the device perfectly horizontal or perfectly vertical.

---

# Motion Filtering

The detector should reject:

* device vibration
* screen tap vibration
* slow orientation changes
* hand repositioning
* posture adjustments
* oscillations after the primary impulse
* accidental movements during gameplay

Recommended processing pipeline:

* orientation estimation
* gravity removal (or Linear Acceleration sensor)
* temporal smoothing
* gesture detection window
* activation/release hysteresis

---

# False Positive Prevention

The system must not generate a KICK event when the player:

* slightly tilts the device
* performs lateral movements
* taps any drum lane
* adjusts grip
* experiences minor hand tremors
* performs slow continuous movements

Only a deliberate kick-like impulse should be accepted.

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

All detection parameters should be externally configurable.

Minimum configurable values:

* gesture sensitivity
* activation threshold
* release threshold
* minimum interval between consecutive KICK events
* cooldown duration
* gesture validation window
* minimum impulse magnitude
* maximum acceptable impulse magnitude
* smoothing strength
* calibration duration

No gameplay logic should depend on hardcoded values.

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

Instead, they should simply perform a natural kick-like motion while the algorithm recognizes the corresponding inertial pattern through sensor fusion.

