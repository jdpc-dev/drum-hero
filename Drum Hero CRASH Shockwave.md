# Drum Hero – CRASH Shockwave Effect Specification

## Objective

Implement an **exclusive visual effect** for the **CRASH cymbal**. Every successful CRASH hit should generate a **shockwave distortion** that temporarily warps the gameplay scene, giving the player the feeling of a powerful physical impact.

This effect is intended to make the CRASH cymbal the most satisfying drum component to hit.

---

# Trigger Conditions

The effect must only be triggered when:

- The player successfully hits a **CRASH** note.
- The hit judgment is:
  - Perfect
  - Great
  - Good

The effect **must not** trigger for:

- Miss
- Overhit
- Ghost hit
- Late or early inputs outside the scoring window

---

# Origin

The shockwave must originate from the **actual screen position of the CRASH pad**.

Do **not** use the center of the screen.

The origin should always match the current world/screen position of the CRASH drum component.

---

# Sequence

## 1. Impact Flash

Duration:

- 70–120 ms

Effects:

- Increase pad brightness.
- Slightly increase saturation.
- Add a warm orange glow.
- Keep the pad size unchanged.

The flash should feel instantaneous and energetic.

---

## 2. Shockwave Generation

Immediately after the flash, generate a translucent expanding shockwave.

Characteristics:

- Soft edges
- Semi-transparent
- Slightly organic
- Not perfectly circular
- No visible texture
- No smoke
- No fire

The wave should resemble a pressure wave moving through the air.

Recommended duration:

250–450 ms

---

## 3. Screen Distortion

As the shockwave expands, it should temporarily distort the gameplay scene.

Affected elements include:

- Falling notes
- Hold notes
- Combo counter
- Judgment text
- Highway lanes
- Drum pads
- Gameplay particles
- Gameplay lighting

The distortion should be implemented using **screen-space UV displacement** (or an equivalent post-processing technique).

Do **not** move gameplay objects.

Only distort how they are rendered.

Once the wave passes, every element immediately returns to its normal appearance.

---

# Propagation

The wave expands radially from the CRASH pad.

Since the CRASH pad is positioned on the left side of the drum kit, most of the visible distortion naturally propagates toward the center of the gameplay.

Do not artificially bias or redirect the wave.

Always use the CRASH pad position as the source.

---

# Distortion Strength

The distortion should be noticeable without affecting gameplay readability.

Recommended displacement:

- Minimum: 4 px
- Typical: 6–10 px
- Maximum: 12 px

Never exceed approximately 15 px.

Players should perceive vibration rather than chaos.

---

# Intensity Curve

The wave strength should follow this progression:

```
0%
↓
100%
↓
0%
```

The intensity must smoothly ramp up and fade out.

Avoid constant strength.

The animation should feel elastic rather than linear.

---

# Oscillation

Include a subtle oscillation in the displacement.

Example:

- Initial compression
- Small rebound
- Fade out

Only one primary oscillation is needed.

Avoid multiple repetitive ripples.

---

# Distance Falloff

Distortion strength decreases as the wave expands.

Recommended behavior:

- Center → 100%
- Mid radius → 40%
- Outer edge → 0%

Use smooth exponential or smoothstep falloff.

---

# Visual Style

The effect should communicate:

- Physical impact
- Pressure wave
- Energy release
- Vibration
- Elasticity

It should **not** resemble:

- Fire
- Explosion
- Smoke
- Magic
- Electricity
- Water ripple

The player should feel as if the cymbal released a burst of pressure through the gameplay scene.

---

# Rendering Requirements

Implement the distortion using a **single full-screen gameplay shader**.

Avoid:

- Individual shaders per note
- Per-object mesh deformation
- Sprite duplication
- Expensive CPU calculations

The distortion should operate on the rendered gameplay framebuffer.

---

# Multiple Consecutive Hits

When multiple CRASH hits occur in quick succession:

- Do not abruptly restart the animation.
- Allow shockwaves to overlap naturally.
- Refresh the amplitude with each hit.
- Update the origin using the latest CRASH position.
- Blend overlapping waves smoothly.

The transition should remain fluid.

---

# Timing

Expected order of events:

**Frame 0**

CRASH note is hit.

**Frame 1**

Orange flash appears.

**Frame 2**

Shockwave begins expanding.

**Following Frames**

The wave distorts gameplay while traveling outward.

**Final Frames**

The distortion smoothly fades until it completely disappears.

---

# Configurable Parameters

```ini
enabled = true

duration = 0.35

max_radius = 2200

strength = 0.06

flash_duration = 0.09

glow_strength = 1.2

edge_softness = 0.35

falloff = exponential

wave_speed = 2800

oscillation = 1

noise_amount = 0.08
```

---

# Performance Requirements

- The effect must remain smooth on mid-range Android devices.
- Avoid allocations during gameplay.
- Reuse shader uniforms and materials whenever possible.
- Prefer GPU-based calculations over CPU-side transformations.
- The effect should have negligible impact on frame time.

---

# Artistic Direction

The CRASH cymbal should become the most visually impactful drum component in **Drum Hero**.

Each successful hit should feel like releasing a burst of kinetic energy that travels across the gameplay scene, briefly bending and warping the interface before everything naturally settles back into place.

The distortion should be dramatic enough to reinforce the impact, while remaining subtle enough to preserve gameplay clarity and note readability.
