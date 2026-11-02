shader_type canvas_item;

// Screen-space pressure wave for CRASH hits. The bubble behaves like a lens:
// inside it the rendered image is magnified, the wavefront refracts it
// radially with a small chromatic fringe, and a low-frequency heat haze warps
// it like gas escaping. Everything below this CanvasLayer is sampled from the
// screen texture, so no gameplay node moves.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform int wave_count = 0;
// xy = origin in pixels, z = wave radius in pixels, w = distortion amplitude.
uniform vec4 waves[3];
// rgb = rim tint, a = rim alpha (also drives the interior shading).
uniform vec4 wave_rings[3];
// Per-wave interior magnification fraction (0 = flat, 0.06 = 6%).
uniform float wave_lens[3];
uniform float wave_width : hint_range(1.0, 400.0) = 150.0;
uniform float rim_core_width : hint_range(0.5, 40.0) = 5.0;
uniform float edge_softness : hint_range(1.0, 200.0) = 28.0;
uniform float falloff_distance : hint_range(1.0, 4000.0) = 1500.0;
// Radial refraction and interior gas-haze amounts, in amplitude units.
uniform float refraction_strength : hint_range(0.0, 6.0) = 3.5;
uniform float gas_strength : hint_range(0.0, 1.0) = 0.5;

float band(float distance, float radius, float width) {
	float x = (distance - radius) / max(width, 0.001);
	return exp(-x * x);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 pixel = uv * viewport_size;

	vec2 offset = vec2(0.0);
	float darken = 0.0;
	vec3 rim_color = vec3(0.0);
	float fringe = 0.0;

	for (int i = 0; i < 3; i++) {
		if (i >= wave_count) {
			break;
		}
		vec4 wave = waves[i];
		vec4 rim = wave_rings[i];
		vec2 delta = pixel - wave.xy;
		float distance = max(length(delta), 1.0);
		vec2 direction = delta / distance;

		// The wave loses energy as it expands: full strength near the crash
		// lane, roughly 40% at mid radius and nothing at the outer edge.
		float falloff = 1.0 - smoothstep(0.0, falloff_distance, wave.z);
		float amplitude = wave.w * falloff;

		// Organic, slightly non-circular wavefront: a pressure bubble is never
		// a perfect circle.
		float angle = atan(delta.y, delta.x);
		float wobble = 1.0
			+ 0.016 * sin(angle * 5.0 + TIME * 1.7)
			+ 0.009 * sin(angle * 3.0 - TIME * 2.4);
		float radius = wave.z * wobble;
		// The soft band is narrow on a small bubble and widens as it grows,
		// so the early impact keeps a clean circular rim instead of folding
		// the whole lane into the wavefront.
		float soft_width = clamp(radius * 0.35, 36.0, wave_width);

		float soft = band(distance, radius, soft_width);
		float core = band(distance, radius, rim_core_width);
		float inside = 1.0 - smoothstep(radius - edge_softness, radius + edge_softness, distance);

		// Magnifying lens: the screen inside the bubble is sampled toward its
		// center, so the picture appears enlarged. The inner part of the bubble
		// is fully magnified and the outer band eases back to normal, avoiding
		// a hard tear at the rim.
		float lens_profile = 1.0 - smoothstep(radius * 0.72, radius, distance);
		offset -= delta * (inside * lens_profile * wave_lens[i]);

		// Gas/heat haze: a slow two-axis ripple inside the bubble. Kept low so
		// notes and HUD text remain readable.
		float gas = sin(delta.x * 0.008 + TIME * 2.2) * cos(delta.y * 0.011 - TIME * 1.6);
		offset += vec2(gas, -gas) * (inside * amplitude * gas_strength);

		// Refracting wavefront: a signed radial push that compresses the image
		// just inside and just outside the rim, like a shockwave in air.
		float phase = (distance - radius) / soft_width;
		offset += direction * (-phase * soft * amplitude * refraction_strength);

		// Filled bubble: everything the wavefront has already crossed is
		// gently dimmed.
		darken += inside * rim.a * 0.38;

		// Thin, bright pressure edge riding the soft halo.
		rim_color += rim.rgb * (core + soft * 0.22) * rim.a;

		// Chromatic fringe at the refracting edge.
		fringe += core * amplitude * 0.12;
	}

	vec2 sample_uv = clamp(uv + offset / viewport_size, vec2(0.0), vec2(1.0));
	vec2 fringe_uv = vec2(fringe / viewport_size.x, 0.0);
	vec3 color;
	color.r = texture(screen_texture, clamp(sample_uv + fringe_uv, vec2(0.0), vec2(1.0))).r;
	color.g = texture(screen_texture, sample_uv).g;
	color.b = texture(screen_texture, clamp(sample_uv - fringe_uv, vec2(0.0), vec2(1.0))).b;
	color *= 1.0 - clamp(darken, 0.0, 0.32);
	color += rim_color;
	COLOR = vec4(color, 1.0);
}
