shader_type canvas_item;
// Speed lines: white streaks racing outward from where you're heading, at
// the edges of the screen, chunky like the rest of the picture.

// 0..1: how many lines, how long, how bright.
uniform float amount = 0.0;
// Where you're heading, in screen UV (can be off-screen).
uniform vec2 focus = vec2(0.5);
// +1 streaks flow outward (moving toward the focus), -1 inward.
uniform float flow = 1.0;
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
	float a = (atan(d.y, d.x) / 6.2831853 + 0.5) * 120.0;
	float cell = floor(a);
	float seed = hash(cell);
	float seed2 = hash(cell + 91.7);
	// Thin lines inside their wedge, only some wedges lit.
	float thin = step(abs(fract(a) - 0.5), 0.1 + 0.12 * seed);
	float lit = step(1.0 - amount * 0.5, seed2);
	// Dashes streaming along the ray.
	float t = fract(r * (1.2 + seed * 1.5) - flow * TIME * (1.8 + 2.5 * seed2) + seed * 9.0);
	float dash = smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.25 + 0.3 * amount, 0.7, t));
	float edge = smoothstep(clear_radius, clear_radius + 0.45, r);
	COLOR = vec4(1.0, 1.0, 1.0, thin * lit * dash * edge * (0.2 + 0.35 * amount));
}
