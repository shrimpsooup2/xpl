shader_type spatial;
// The heart as a loading spinner (HeartScreen, SPINNER style): eight chunky
// light dots round a round glass glowing pink (so it glows from afar, like
// the TV), the lead one white, stepping round like an old buffering wheel.
// The script turns it (faster at speed; it hitches when hit and stutters
// near death). A heartshot flashes white, drops the dots out of the ring
// one by one and leaves a dim cross ("not responding"); any other death
// greys it out as it winds down.
render_mode cull_back, specular_schlick_ggx;

uniform vec3 pink : source_color = vec3(1.0, 0.22, 0.42);
uniform float energy = 2.6;
// Where the lead dot is, in radians (stepped to the dots here).
uniform float angle = 0.0;
uniform float health = 1.0;
uniform float hurt = 0.0;
// Heartshot: 0 on .. 1 gone.
uniform float off = 0.0;
// Ordinary death: 0 .. 1 greyed out.
uniform float lost = 0.0;
uniform float seed = 0.0;

const float GRID = 21.0;
const int DOTS = 8;
const float RING = 0.62;
const float DOT = 0.15;

float hash(float n) {
	return fract(sin(n * 91.7 + seed * 13.0) * 43758.5453);
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;  // y runs down the glass
	if (length(c) > 0.98) {
		discard;
	}
	// Chunky pixels: everything is drawn at the middle of its cell.
	vec2 cc = (floor((c * 0.5 + 0.5) * GRID) + 0.5) / GRID * 2.0 - 1.0;

	float step_angle = 6.2832 / float(DOTS);
	int head = int(floor(fract(angle / 6.2832) * float(DOTS)));
	// A lit pink face (so it glows from afar, like the TV) with light dots.
	vec3 col = pink * 0.5 * (1.0 - off);
	for (int i = 0; i < DOTS; i++) {
		// Clockwise from the top.
		float a = -1.5708 + float(i) * step_angle;
		vec2 at = RING * vec2(cos(a), sin(a));
		// A heartshot drops them out of the ring, one after another.
		float fall = clamp((off - float(i) * 0.05) * 1.6, 0.0, 1.0);
		at.y += fall * fall * (1.4 + hash(float(i)) * 0.8);
		at.x += fall * (hash(float(i) + 7.0) - 0.5) * 0.6;
		int behind = (head - i + DOTS) % DOTS;
		float b = 1.0 - float(behind) / float(DOTS) * 0.85;
		// The tail's dots are smaller as well as dimmer.
		if (length(cc - at) < DOT * (0.7 + 0.3 * b)) {
			// The lead white, the tail fading back into the pink.
			vec3 dot_col = mix(pink * 0.55, vec3(1.0, 0.9, 0.94) * 0.42, b * b);
			col = dot_col * (1.0 - fall);
		}
	}
	// Hit: a grey flicker, like a stall.
	float grey = dot(col, vec3(0.33));
	col = mix(col, vec3(grey), hurt * 0.7);
	// Near death it flickers.
	float weak = clamp(1.0 - health, 0.0, 1.0);
	col *= 1.0 - weak * weak * 0.5 * step(0.5, hash(floor(TIME * 14.0)));
	// Timed out: greys and dims as it winds down.
	col = mix(col, vec3(dot(col, vec3(0.33))) * 0.6, lost);
	// Not responding: a dim cross where the ring was.
	if (off > 0.0) {
		float x = step(abs(abs(cc.x) - abs(cc.y)), 0.1) * step(length(cc), 0.42);
		col = max(col, pink * 0.55 * x * smoothstep(0.55, 0.9, off));
		col += vec3(1.0, 0.95, 0.97) * 2.5 * (1.0 - smoothstep(0.0, 0.15, off));
	}
	// A soft edge to the glass.
	col *= 1.0 - 0.3 * smoothstep(0.6, 0.98, length(c));

	ALBEDO = vec3(0.02);
	EMISSION = col * energy;
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
}
