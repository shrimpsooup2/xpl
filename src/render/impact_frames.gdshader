shader_type canvas_item;
// An impact frame: the screen redrawn as stark two-tone ink and paper, with
// outlines and speed lines bursting from the hit, like a held anime frame.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
// Swap ink and paper (the first, "negative" beat).
uniform bool negative = true;
uniform vec3 ink : source_color = vec3(0.05, 0.05, 0.06);
uniform vec3 paper : source_color = vec3(1.0);
// Where the hit is, in screen UV.
uniform vec2 center = vec2(0.5);
// How much of the frame gets speed lines (0..1), and a per-hit seed.
uniform float lines = 0.25;
uniform float seed = 0.0;
// Radius (in screen heights) around the hit kept clear of lines.
uniform float core = 0.22;
// Luminance jump that counts as an outline.
uniform float edge = 0.22;

float luma(vec2 uv) {
	return dot(texture(screen_tex, uv).rgb, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	// Split around the frame's own average, so dark and bright scenes both
	// come out half ink, half paper.
	float average = 0.0;
	for (int y = 0; y < 4; y++) {
		for (int x = 0; x < 4; x++) {
			average += luma((vec2(float(x), float(y)) + 0.5) / 4.0);
		}
	}
	average /= 16.0;
	float l = luma(SCREEN_UV);
	float v = step(mix(0.5, average, 0.75), l);

	// Outlines: a big step against any neighbour goes to ink.
	vec2 px = SCREEN_PIXEL_SIZE * 2.0;
	float g = max(max(abs(l - luma(SCREEN_UV + vec2(px.x, 0.0))), abs(l - luma(SCREEN_UV - vec2(px.x, 0.0)))),
			max(abs(l - luma(SCREEN_UV + vec2(0.0, px.y))), abs(l - luma(SCREEN_UV - vec2(0.0, px.y)))));
	v *= 1.0 - step(edge, g);

	// Speed lines: thin random wedges radiating from the hit, flipping tone.
	vec2 d = (SCREEN_UV - center) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float r = length(d);
	float a = (atan(d.y, d.x) / 6.2831853 + 0.5) * 160.0;
	float rnd = fract(sin(floor(a) * 12.9898 + seed * 78.233) * 43758.5453);
	float thin = step(abs(fract(a) - 0.5), 0.15 + 0.3 * rnd);
	float line = step(1.0 - lines, rnd) * thin * smoothstep(core, core + 0.2 * (1.0 - rnd), r);
	v = mix(v, 1.0 - v, line);

	if (negative) {
		v = 1.0 - v;
	}
	COLOR = vec4(mix(ink, paper, v), 1.0);
}
