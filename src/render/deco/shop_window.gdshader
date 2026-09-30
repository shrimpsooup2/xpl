shader_type spatial;
render_mode unshaded, shadows_disabled;
// A shop window with no shop behind it: the room is worked out from where
// you look through the glass (interior mapping), so it has depth and shifts
// as you move. Each pane gets its own shop from where it is: most closed
// and dim (a green exit sign at the back), some stripped bare, a few still
// lit. The glass over it catches the sky and is grubby.
//
// Faces must be upright. UV runs in metres from the pane's top-left
// corner (DecoKit.face()).

global uniform float world_light;
uniform sampler2D reflection_map : source_color, filter_nearest, repeat_disable;
uniform sampler2D grime : hint_default_black, filter_linear, repeat_enable;
// The pane's height; the room's floor is a little under it, its ceiling a
// little over, its back wall `depth` in.
uniform float pane_height = 2.6;
uniform float depth = 4.0;
uniform vec3 wall : source_color = vec3(0.55, 0.50, 0.46);
uniform vec3 lamp : source_color = vec3(1.0, 0.86, 0.62);
// How many of the shops are still lit (0..1), and how many stripped bare.
uniform float lit_share = 0.25;
uniform float bare_share = 0.3;
uniform float reflectance = 0.35;

varying vec3 wpos;
varying vec3 wnormal;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 n = normalize(wnormal);
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), n));
	// Which shop: from the pane's top-left corner, the same all over it.
	float along = dot(wpos, right) - UV.x;
	vec2 key = vec2(floor(along + 0.5) + floor(dot(wpos, n) + 0.5) * 7.0, floor(wpos.y + UV.y + 0.5));
	float kind = hash(key);
	bool lit = kind < lit_share;
	bool bare = !lit && kind < lit_share + bare_share;
	vec3 hue = mix(vec3(1.0), vec3(hash(key + 3.1), hash(key + 5.7), hash(key + 9.2)), 0.35);

	// The ray into the room: x along the wall, y up from the pane's foot, z in.
	vec3 d = normalize(wpos - CAMERA_POSITION_WORLD);
	vec3 r = vec3(dot(d, right), d.y, -dot(d, n));
	vec3 p = vec3(UV.x, pane_height - UV.y, 0.0);
	float floor_y = -0.25;
	float ceil_y = pane_height + 0.5;
	float ty = r.y > 0.0 ? (ceil_y - p.y) / r.y : (floor_y - p.y) / min(r.y, -1e-4);
	float tz = depth / max(r.z, 1e-4);
	float t = min(ty, tz);
	vec3 h = p + r * t;

	float light = lit ? 1.0 : (bare ? 0.12 : 0.22);
	vec3 c;
	if (tz <= ty) {
		// The back wall: shelves of stock (or bare), a green exit sign in the
		// dark ones.
		c = wall * hue;
		if (!bare) {
			float shelf = fract(h.y / 0.55);
			vec2 slot = vec2(floor(h.x / 0.22), floor(h.y / 0.55));
			vec3 stock = vec3(hash(slot + key), hash(slot + key + 1.3), hash(slot + key + 2.9));
			float filled = step(0.3, hash(slot * 1.7 + key)) * step(0.12, shelf) * step(shelf, 0.7) * step(0.3, h.y) * step(h.y, 2.4);
			c = mix(c, stock * 0.9, filled);
			c = mix(c, c * 0.45, step(0.9, shelf));
		}
		if (!lit) {
			vec2 e = vec2(fract(h.x / 6.0) * 6.0 - 1.2, h.y - (ceil_y - 0.35));
			float exit_sign = step(abs(e.x), 0.2) * step(abs(e.y), 0.08);
			c = mix(c * light, vec3(0.3, 1.6, 0.5), exit_sign);
			light = 1.0;
		}
		c *= 1.0 - 0.3 * (1.0 - smoothstep(0.0, 1.0, h.y + 0.25));
	} else if (r.y < 0.0) {
		// The floor: big tiles, darker far in.
		vec2 f = floor(vec2(h.x, h.z) / 0.6);
		c = wall * 0.55 * (0.85 + 0.15 * mod(f.x + f.y, 2.0));
	} else {
		// The ceiling: panels, lit ones glowing.
		vec2 f = fract(vec2(h.x / 1.8, h.z / 1.2));
		float panel = step(abs(f.x - 0.5), 0.2) * step(abs(f.y - 0.5), 0.25);
		c = wall * 0.35 + (lit ? lamp * panel * 2.2 : vec3(0.0));
	}
	// Lit from the front ceiling, falling off toward the back.
	c *= light * (lit ? 1.25 - 0.45 * clamp(h.z / depth, 0.0, 1.0) : 1.0);
	c *= lit ? lamp : vec3(1.0);

	// The glass: the sky in it, grime on it.
	vec3 rv = reflect(-VIEW, NORMAL);
	float m = 2.0 * sqrt(rv.x * rv.x + rv.y * rv.y + (rv.z + 1.0) * (rv.z + 1.0));
	vec3 env = texture(reflection_map, vec2(rv.x / m + 0.5, 0.5 - rv.y / m)).rgb;
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float dirt = texture(grime, UV * 0.4).r;
	c = mix(c, env, clamp(reflectance * (0.4 + 0.6 * fresnel), 0.0, 1.0));
	c *= 1.0 - dirt * 0.35;
	ALBEDO = c * world_light;
}
