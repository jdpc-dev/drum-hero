shader_type canvas_item;

// Subtle whole-screen feedback for non-CRASH lanes. The image is sampled with
// a small translation (hat/snare shake) and a top-edge lift (kick), then the
// top edge gets a faint neutral highlight so the movement reads on dark scenes.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform vec2 screen_offset = vec2(0.0, 0.0);
uniform float top_lift = 0.0;
uniform float top_glow = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 pixel = uv * viewport_size;

	// The top corners rise a little more than the center, like the shell of
	// the kit flexing when the pedal is struck.
	float top_mask = 1.0 - smoothstep(0.0, 0.38, uv.y);
	float corner = 0.65 + 0.35 * pow(abs(uv.x - 0.5) * 2.0, 1.4);
	pixel.y += top_lift * top_mask * top_mask * corner;
	pixel += screen_offset;

	vec2 sample_uv = clamp(pixel / viewport_size, vec2(0.0), vec2(1.0));
	vec3 color = texture(screen_texture, sample_uv).rgb;

	// The shared black background makes the lifted pixels nearly invisible:
	// both the sample and its source are black. Draw a light band that follows
	// the lift instead, with a soft falloff and a brighter edge line. The
	// corner weight matches the lift so the flex reads strongest at the edges.
	float edge = 1.0 - smoothstep(0.0, 0.28, uv.y);
	float line = 1.0 - smoothstep(0.0, 0.010, uv.y);
	float highlight = (edge * 0.12 + line * 0.18) * corner;
	color += vec3(0.92, 0.89, 1.0) * (top_glow * highlight);

	COLOR = vec4(color, 1.0);
}
