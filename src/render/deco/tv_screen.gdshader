shader_type spatial;
render_mode unshaded, shadows_disabled;
// An old telly left on, looping: colour bars, then snow, then a blue
// "welcome" screen with lines of text crawling up; scanlines and a slow
// roll bar over it all.

global uniform float world_light;
global uniform float effects;
// UV runs 0..size (metres) across the screen.
uniform vec2 size = vec2(0.5, 0.38);
uniform float offset = 0.0;
uniform float energy = 1.3;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV / size;
	float t = TIME * effects + offset;
	float phase = mod(t, 18.0);
	vec3 c;
	if (phase < 7.0) {
		int bar = int(floor(uv.x * 7.0));
		vec3 bars[7] = vec3[](vec3(0.75), vec3(0.75, 0.75, 0.0), vec3(0.0, 0.75, 0.75), vec3(0.0, 0.75, 0.0),
				vec3(0.75, 0.0, 0.75), vec3(0.75, 0.0, 0.0), vec3(0.0, 0.0, 0.75));
		c = uv.y > 0.75 ? vec3(0.08) : bars[clamp(bar, 0, 6)];
	} else if (phase < 10.0) {
		c = vec3(hash(floor(uv * vec2(48.0, 36.0)) + floor(t * 24.0)));
	} else {
		c = vec3(0.08, 0.18, 0.72);
		float line = floor(uv.y * 10.0 + (phase - 10.0) * 1.5);
		float len = 0.3 + hash(vec2(line, 3.0)) * 0.5;
		float text = step(0.15, uv.x) * step(uv.x, len) * step(0.35, fract(uv.y * 10.0 + (phase - 10.0) * 1.5));
		c = mix(c, vec3(0.9), text * step(0.4, hash(vec2(floor(uv.x * 30.0), line))));
	}
	c *= 0.82 + 0.18 * step(0.5, fract(uv.y * 36.0));
	c *= 1.0 - 0.3 * smoothstep(0.0, 0.08, 0.08 - abs(fract(uv.y - t * 0.12) - 0.5));
	float edge = smoothstep(0.0, 0.08, min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)));
	ALBEDO = c * energy * edge * world_light;
}
