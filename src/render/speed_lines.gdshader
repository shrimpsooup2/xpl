shader_type canvas_item;
// Speed lines: thin white streaks at the screen edges pointing out from
// where you're heading, chunky like the rest of the picture. Stepped (the
// default): every line is redrawn at random several times a second, like
// hand-drawn anime lines. Smooth: dashes stream outward continuously.

// 0..1: how many lines, how long, how bright.
uniform float amount = 0.0;
// Where you're heading, in screen UV (can be off-screen).
uniform vec2 focus = vec2(0.5);
// +1 streams outward (moving toward the focus), -1 inward. Smooth only.
uniform float flow = 1.0;
// 1 = stepped redraws, 0 = smooth streaming.
uniform float stepped = 1.0;
// Redraws per second when stepped.
uniform float rate = 24.0;
// Radius (screen heights) around the focus that stays clear.
uniform float clear_radius = 0.34;
// Screen pixels per line pixel, to match the low-res 3D.
uniform float pixel = 3.0;

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 uv = (floor(SCREEN_UV * size / pixel) + 0.5) * pixel / size;
	vec2 d = (uv - focus) * vec2(size.x / size.y, 1.0);
	float r = length(d);
	float a = (atan(d.y, d.x) / 6.2831853 + 0.5) * 200.0;
	float cell = floor(a);
	float alpha;
	if (stepped > 0.5) {
		// Each redraw picks new lines: where they start and how long they are.
		float frame = floor(TIME * rate);
		float seed = hash(cell + frame * 37.31);
		float seed2 = hash(cell * 1.7 + frame * 11.13 + 5.0);
		float lit = step(1.0 - amount * 0.35, seed);
		float thin = step(abs(fract(a) - 0.5), 0.12 + 0.12 * seed2);
		float start = clear_radius + seed2 * 0.35;
		float len = 0.15 + 0.6 * amount * seed;
		float on = step(start, r) * step(r, start + len);
		alpha = lit * thin * on * (0.3 + 0.35 * amount);
	} else {
		float seed = hash(cell);
		float seed2 = hash(cell + 91.7);
		float thin = step(abs(fract(a) - 0.5), 0.1 + 0.12 * seed);
		float lit = step(1.0 - amount * 0.45, seed2);
		float t = fract(r * (1.2 + seed * 1.5) - flow * TIME * (1.8 + 2.5 * seed2) + seed * 9.0);
		float dash = smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.25 + 0.3 * amount, 0.7, t));
		float edge = smoothstep(clear_radius, clear_radius + 0.45, r);
		alpha = thin * lit * dash * edge * (0.2 + 0.35 * amount);
	}
	COLOR = vec4(1.0, 1.0, 1.0, alpha);
}
