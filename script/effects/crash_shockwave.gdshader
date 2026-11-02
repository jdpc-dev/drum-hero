shader_type canvas_item;

// Screen-space pressure wave for CRASH hits. Everything below this CanvasLayer
// is already in the screen texture; the shader dims the area inside the
// expanding bubble, lights its rim and displaces the rendered image
// horizontally along the wavefront, so the impact bends the picture without
// touching a single gameplay node.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform int wave_count = 0;
// xy = origin in pixels, z = wave radius in pixels, w = horizontal amplitude.
uniform vec4 waves[3];
// rgb = rim tint, a = rim alpha (also drives the interior shading).
uniform vec4 wave_rings[3];
uniform float wave_width : hint_range(1.0, 400.0) = 115.0;
uniform float rim_core_width : hint_range(0.5, 40.0) = 5.0;
uniform float edge_softness : hint_range(1.0, 200.0) = 28.0;
uniform float falloff_distance : hint_range(1.0, 4000.0) = 1500.0;

float band(float distance, float radius, float width) {
	float x = (distance - radius) / max(width, 0.001);
	return exp(-x * x);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 pixel = uv * viewport_size;

	float horizontal_offset = 0.0;
	float darken = 0.0;
	vec3 rim_color = vec3(0.0);

	for (int i = 0; i < 3; i++) {
		if (i >= wave_count) {
			break;
		}
		vec4 wave = waves[i];
		vec4 rim = wave_rings[i];
		vec2 delta = pixel - wave.xy;
		float distance = max(length(delta), 1.0);

		// The wave loses energy as it expands: full strength near the crash
		// lane, roughly 40% at mid radius and nothing at the outer edge.
		float falloff = 1.0 - smoothstep(0.0, falloff_distance, wave.z);

		// Horizontal-only displacement: pixels are pushed away from the
		// origin along x, which reads as a ripple crossing the screen. The
		// same wide band also feeds the soft halo around the pressure edge.
		float soft = band(distance, wave.z, wave_width);
		horizontal_offset += soft * wave.w * falloff * (delta.x / distance);

		// Filled bubble: everything the wavefront has already crossed is
		// gently dimmed, like a pressure front passing through the scene.
		float inside = 1.0 - smoothstep(wave.z - edge_softness, wave.z + edge_softness, distance);
		darken += inside * rim.a * 0.5;

		// Thin, bright pressure edge riding the soft halo.
		float core = band(distance, wave.z, rim_core_width);
		rim_color += rim.rgb * (core + soft * 0.22) * rim.a;
	}

	vec2 sample_uv = clamp(uv + vec2(horizontal_offset / viewport_size.x, 0.0), vec2(0.0), vec2(1.0));
	vec3 color = texture(screen_texture, sample_uv).rgb;
	color *= 1.0 - clamp(darken, 0.0, 0.40);
	color += rim_color;
	COLOR = vec4(color, 1.0);
}
