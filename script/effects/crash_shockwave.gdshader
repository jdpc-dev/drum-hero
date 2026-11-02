shader_type canvas_item;

// Screen-space pressure wave for CRASH hits. Everything below this CanvasLayer
// is already in the screen texture; the shader only displaces that texture
// horizontally along each expanding ring, so the waveform bends the rendered
// image without touching a single gameplay node.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform int wave_count = 0;
// xy = origin in pixels, z = wave radius in pixels, w = horizontal amplitude.
uniform vec4 waves[3];
// rgb = ring tint, a = tint alpha at the wavefront.
uniform vec4 wave_rings[3];
uniform float wave_width : hint_range(1.0, 300.0) = 68.0;
uniform float falloff_distance : hint_range(1.0, 4000.0) = 1500.0;

float ring_band(vec2 pixel, vec2 origin, float radius) {
	float distance = length(pixel - origin);
	float x = (distance - radius) / max(wave_width, 0.001);
	return exp(-x * x);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 pixel = uv * viewport_size;

	float horizontal_offset = 0.0;
	vec3 ring_color = vec3(0.0);

	for (int i = 0; i < 3; i++) {
		if (i >= wave_count) {
			break;
		}
		vec4 wave = waves[i];
		vec2 delta = pixel - wave.xy;
		float distance = max(length(delta), 1.0);
		float band = ring_band(pixel, wave.xy, wave.z);
		// The wave loses energy as it expands: full strength near the crash
		// lane, roughly 40% at mid radius and nothing at the outer edge.
		float falloff = 1.0 - smoothstep(0.0, falloff_distance, wave.z);
		// Horizontal-only displacement: pixels are pushed away from the
		// origin along x, which reads as a ripple crossing the screen.
		horizontal_offset += band * wave.w * falloff * (delta.x / distance);

		vec4 ring = wave_rings[i];
		ring_color += ring.rgb * band * ring.a;
	}

	vec2 sample_uv = clamp(uv + vec2(horizontal_offset / viewport_size.x, 0.0), vec2(0.0), vec2(1.0));
	vec3 color = texture(screen_texture, sample_uv).rgb + ring_color;
	COLOR = vec4(color, 1.0);
}
