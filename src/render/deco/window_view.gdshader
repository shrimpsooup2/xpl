shader_type spatial;
render_mode unshaded, shadows_disabled;
// A window onto the city at night, with no hole in the wall: the view is
// worked out from which way you look through the glass (so it shifts right
// as you move, like something far away): a night sky, a skyline of towers
// with windows lit here and there, the city's haze at the horizon, and a
// grubby pane over it all.

global uniform float world_light;
uniform vec3 sky_top : source_color = vec3(0.03, 0.04, 0.12);
uniform vec3 sky_horizon : source_color = vec3(0.30, 0.18, 0.36);
uniform vec3 tower : source_color = vec3(0.03, 0.035, 0.07);
uniform vec3 window_warm : source_color = vec3(1.0, 0.74, 0.44);
uniform vec3 window_cool : source_color = vec3(0.60, 0.80, 1.0);
uniform sampler2D grime : hint_default_black, filter_linear, repeat_enable;
uniform float seed = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 d = normalize(wpos - CAMERA_POSITION_WORLD);
	float az = (atan(d.z, d.x) + PI) / TAU;
	float el = asin(clamp(d.y, -1.0, 1.0));
	vec3 col = mix(sky_horizon, sky_top, smoothstep(-0.02, 0.55, el));
	// Towers: one per slice of the view, a random height; a nearer, darker
	// row in front of a farther, hazier one.
	for (int layer = 0; layer < 2; layer++) {
		float bins = layer == 0 ? 60.0 : 110.0;
		float b = floor(az * bins);
		float top = (layer == 0 ? 0.04 : 0.015) + pow(hash(vec2(b, seed + float(layer))), 2.2) * (layer == 0 ? 0.26 : 0.12);
		if (el < top) {
			vec3 body = mix(tower, sky_horizon * 0.5, layer == 0 ? 0.1 : 0.45);
			vec2 cell = vec2(az * bins * 5.0, el * (layer == 0 ? 90.0 : 150.0));
			vec2 f = fract(cell);
			float win = step(0.25, f.x) * step(f.x, 0.75) * step(0.3, f.y) * step(f.y, 0.75);
			float roll = hash(floor(cell) + b * 3.1);
			vec3 lit = roll < 0.18 ? window_warm : (roll < 0.24 ? window_cool : vec3(0.0));
			col = body + win * lit * (layer == 0 ? 0.9 : 0.45);
			break;
		}
	}
	// The city's glow along the horizon.
	col += sky_horizon * 0.5 * exp(-abs(el) * 18.0);
	// The pane: a faint grubby film and a cold tint.
	float g = texture(grime, UV * 0.5).r;
	col = mix(col, vec3(0.12, 0.16, 0.2), 0.15 + g * 0.2);
	ALBEDO = col * world_light;
}
