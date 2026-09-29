shader_type spatial;
// The heart's screen (HeartScreen): a tiny CRT glowing heart pink, with a
// pixel heart beating on it. Coarse pixels behind scanlines on bulging
// glass. Hurt, the picture tears and snows; near death it rolls; an
// ordinary death loses the signal to static; a heartshot switches the set
// off (the picture collapses to a bright line, then a dot, then black) and
// cracks the glass.
render_mode cull_back, specular_schlick_ggx;

uniform vec3 pink : source_color = vec3(1.0, 0.22, 0.42);
uniform float energy = 2.6;
// 0..1 through the current beat: the "lub" at 0, the "dub" just after.
uniform float beat_phase = 0.0;
uniform float health = 1.0;
// 1 just after a hit, easing to 0.
uniform float hurt = 0.0;
// Heartshot: 0 on .. 1 switched off.
uniform float off = 0.0;
// Ordinary death: 0 .. 1 all static.
uniform float lost = 0.0;
uniform float crack = 0.0;
uniform float seed = 0.0;
// The glass's width over its height.
uniform float aspect = 1.28;

const vec2 GRID = vec2(13.0, 10.0);
// A pixel heart, 7 wide and 6 tall, top row first: .XX.XX. XXXXXXX
// XXXXXXX .XXXXX. ..XXX.. ...X...
const int HEART[6] = int[6](54, 127, 127, 62, 28, 8);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.0) * 43758.5453);
}

bool in_heart(ivec2 q) {
	if (q.x < 0 || q.x > 6 || q.y < 0 || q.y > 5) {
		return false;
	}
	return ((HEART[q.y] >> (6 - q.x)) & 1) == 1;
}

// The two thumps of a heartbeat, 0..1.
float thump(float t) {
	float lub = exp(-pow(t / 0.06, 2.0));
	float dub = 0.7 * exp(-pow((t - 0.24) / 0.06, 2.0));
	return max(lub, dub);
}

// Distance from p to the segment a-b.
float segment(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float h = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
	return length(p - a - ab * h);
}

void fragment() {
	// Centred, -1..1 each way, bulging like a tube's face.
	vec2 c = UV * 2.0 - 1.0;
	c *= 1.0 + 0.07 * dot(c, c);
	// The glass is a rounded rectangle; the set's plastic shows past it.
	vec2 corner = max(abs(c) - vec2(0.72), 0.0);
	if (length(corner) > 0.28) {
		discard;
	}

	float t = TIME;
	float beat = thump(beat_phase);
	vec3 col = vec3(0.0);
	float lit = 1.0;

	// Switching off: the picture squashes to a line, then the line to a dot.
	float squash_y = mix(1.0, 0.015, smoothstep(0.0, 0.45, off));
	float squash_x = mix(1.0, 0.02, smoothstep(0.45, 0.8, off));
	vec2 pc = c / vec2(squash_x, squash_y);
	if (abs(pc.x) > 1.0 || abs(pc.y) > 1.0) {
		lit = 0.0;
	}

	// Tearing when hit, rolling when nearly dead.
	float weak = clamp(1.0 - health, 0.0, 1.0);
	pc.x += hurt * 0.12 * sin(pc.y * 23.0 + t * 70.0) * step(0.5, hash(vec2(floor(pc.y * 6.0), floor(t * 30.0))));
	pc.y = fract((pc.y * 0.5 + 0.5) + pow(weak, 3.0) * t * 0.35) * 2.0 - 1.0;

	vec2 cell = floor((pc * 0.5 + 0.5) * GRID);
	// The heart sits in the middle of the grid (x 3..9, y 2..7 from the top).
	ivec2 q = ivec2(int(cell.x) - 3, int(cell.y) - 2);
	bool heart = in_heart(q);
	bool ring = false;
	if (!heart && beat > 0.35) {
		// On each thump the heart swells by a pixel all round.
		for (int dy = -1; dy <= 1; dy++) {
			for (int dx = -1; dx <= 1; dx++) {
				ring = ring || in_heart(q + ivec2(dx, dy));
			}
		}
	}
	vec3 back = pink * (0.55 + 0.2 * beat);
	vec3 front = mix(pink * 1.35, vec3(1.0, 0.85, 0.9) * 1.6, beat * 0.7);
	col = heart ? front : (ring ? pink * (1.0 + 0.4 * beat) : back);

	// Snow: a little when hurt, more near death, all of it when the signal's lost.
	float snow = max(max(lost, hurt * 0.6), weak * weak * 0.35 * step(0.4, hash(vec2(floor(t * 12.0), 3.0))));
	float n = hash(cell + floor(t * 30.0) * vec2(1.7, 9.2));
	col = mix(col, vec3(n) * mix(pink, vec3(1.0), 0.5) * 0.9, snow);

	// Scanlines and a soft edge, like a real tube.
	// (Faded out once they're too fine to draw, so they never shimmer.)
	float line_width = fwidth(UV.y) * GRID.y * 3.0;
	float lines = 1.0 - 0.22 * (1.0 - smoothstep(0.25, 0.6, line_width)) * (0.5 - 0.5 * sin((UV.y * GRID.y * 3.0) * 6.2832));
	col *= lines * (1.0 - 0.35 * dot(c, c) * 0.5);

	// The collapsing line and dot burn white-hot as they shrink.
	col = mix(col, vec3(1.0, 0.95, 0.97) * 3.0, smoothstep(0.1, 0.45, off) * lit);
	col *= lit * (1.0 - smoothstep(0.85, 1.0, off));

	// A heartshot's cracks: rays from where it went in, catching the light.
	float cracks = 0.0;
	if (crack > 0.0) {
		vec2 hit = vec2(hash(vec2(seed, 1.0)) - 0.5, hash(vec2(seed, 2.0)) - 0.5) * 0.6;
		for (int i = 0; i < 7; i++) {
			float a = float(i) * 0.9 + hash(vec2(seed, float(i))) * 1.4;
			vec2 dir = vec2(cos(a), sin(a) * aspect);
			vec2 mid = hit + dir * 0.45 + vec2(hash(vec2(float(i), seed)) - 0.5) * 0.25;
			float d = min(segment(c, hit, mid), segment(c, mid, mid + dir * 0.7));
			cracks = max(cracks, 1.0 - smoothstep(0.0, 0.03, d));
		}
		cracks *= crack;
	}

	float glow = energy * (0.85 + 0.3 * beat);
	ALBEDO = vec3(0.02) + vec3(0.5) * cracks;
	EMISSION = col * glow;
	ROUGHNESS = mix(0.06, 0.4, cracks);
	SPECULAR = 0.9;
}
