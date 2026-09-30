shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
// Glacier ice (tools/maps/boulevard_deco.gd): the cave's walls, vault and
// floor, icicles, spikes, the frozen canal. Point-filtered and painted
// like every other surface (`ice`), with what ice has on top:
//
// - Its surface melted into scallops (`scallops`, a normal map), lit by
//   the lamps like anything else, so a lantern's light catches on every
//   ridge.
// - Looked into: what's inside (`inner`: bubbles, fracture planes) is read
//   at a few depths along the view, so it sits in the ice and slides as you
//   move.
// - Lit from behind: daylight coming through the ice (EMISSION), more
//   where it's thin (`glow_meters` patches) and higher up, a hint of violet
//   where it's darkest; the cave glows with no lamp at all.
// - A fake reflection at grazing angles, and glints that flash as the view
//   moves.
// Textured from the world (triplanar).

global uniform float world_light;
uniform sampler2D ice : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D scallops : filter_nearest_mipmap, repeat_enable;
uniform sampler2D inner : filter_nearest_mipmap, repeat_enable;
uniform sampler2D reflection_map : source_color, filter_nearest, repeat_disable;
// Metres a repeat: the ice, and what's inside.
uniform float meters = 3.0;
uniform float inner_meters = 5.0;
// How bumpy the scallops look (0: smooth, polished ice).
uniform float bump = 1.0;
uniform vec3 tint : source_color = vec3(1.0);
// A hint of violet where the ice is darkest (and deep where it's thick).
uniform vec3 violet = vec3(1.3, 0.78, 1.28);
uniform float violet_amount = 0.3;
// What's inside, seen through.
uniform vec3 frost : source_color = vec3(0.80, 0.93, 1.0);
// How much light comes through; how big its thick and thin patches are.
uniform float glow = 0.8;
uniform float glow_meters = 40.0;
// How deep the layers inside sit (metres), and how much they show.
uniform float depth = 0.8;
uniform float inside = 1.0;
// The surface under the lamps, and its shine.
uniform float albedo_amount = 0.4;
uniform float gloss = 0.35;
uniform float roughness_value = 0.25;
uniform float sparkle = 1.0;
// Brighter toward the top (the vault, where the daylight is): the glow at
// world y below and above these.
uniform vec2 glow_heights = vec2(0.0, 30.0);
uniform float glow_low = 0.45;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

// The plane a world point is read in, by the (geometric) normal: the
// dominant axis, y down the picture on the walls.
vec2 plane(vec3 p, vec3 n) {
	vec3 a = abs(n);
	if (a.y >= a.x && a.y >= a.z) {
		return p.xz;
	} else if (a.x >= a.z) {
		return vec2(p.z * sign(n.x), -p.y);
	}
	return vec2(-p.x * sign(n.z), -p.y);
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 to_eye = normalize(CAMERA_POSITION_WORLD - world_pos);

	// The three planes, blended.
	vec3 w = pow(abs(n), vec3(6.0));
	w /= (w.x + w.y + w.z);
	vec2 ux = vec2(world_pos.z * sign(n.x), -world_pos.y) / meters;
	vec2 uy = world_pos.xz / meters;
	vec2 uz = vec2(-world_pos.x * sign(n.z), -world_pos.y) / meters;
	vec3 colour = (texture(ice, ux).rgb * w.x + texture(ice, uy).rgb * w.y + texture(ice, uz).rgb * w.z) * tint;
	float luma = dot(colour, vec3(0.3, 0.5, 0.2));
	colour = mix(colour, colour * violet, (1.0 - smoothstep(0.12, 0.4, luma)) * violet_amount);
	vec2 dx = texture(scallops, ux).rg * 2.0 - 1.0;
	vec2 dy = texture(scallops, uy).rg * 2.0 - 1.0;
	vec2 dz = texture(scallops, uz).rg * 2.0 - 1.0;
	// Each plane's x and y back into the world (y down the picture = −world y).
	vec3 bend = w.x * vec3(0.0, -dx.y, dx.x * sign(n.x))
			+ w.y * vec3(dy.x, 0.0, dy.y)
			+ w.z * vec3(-dz.x * sign(n.z), -dz.y, 0.0);
	vec3 bumped = normalize(n + bend * bump);

	// How thin the ice is here: broad patches, and more light higher up.
	float thick = texture(inner, plane(world_pos, n) / glow_meters).b;
	float high = mix(glow_low, 1.0, smoothstep(glow_heights.x, glow_heights.y, world_pos.y));
	float thinness = smoothstep(0.25, 0.8, 1.0 - thick);
	vec3 through = colour * (0.5 + thinness * 0.9) * high;
	through = mix(through, through * violet, (1.0 - thinness) * violet_amount * 0.5);

	// Inside: bubbles and fractures at four depths, fading as they go.
	vec3 into = -to_eye;
	vec3 seen = vec3(0.0);
	for (int k = 0; k < 4; k++) {
		float d = depth * (float(k) + 0.6) / 4.0;
		vec3 p = world_pos + into * d / max(dot(to_eye, n), 0.35);
		vec2 uv = plane(p, n) / (inner_meters * (1.0 + float(k) * 0.37)) + vec2(float(k) * 0.29, float(k) * 0.53);
		vec4 t = texture(inner, uv);
		seen += frost * (t.r * 0.45 + t.g * 0.6) * (1.0 - float(k) * 0.2);
	}
	seen *= inside * (0.3 + thinness * 0.7) * high;

	// Glints: specks that flash as the view moves over them.
	float speck = texture(inner, plane(world_pos, n) / 0.7 + vec2(0.13, 0.71)).r;
	float flash = pow(max(sin(dot(to_eye, vec3(31.0, 47.0, 23.0)) + speck * 40.0), 0.0), 24.0);
	vec3 glint = frost * flash * speck * sparkle;

	// The fake reflection, at grazing angles.
	vec3 view_n = normalize((VIEW_MATRIX * vec4(bumped, 0.0)).xyz);
	vec3 r = reflect(-VIEW, view_n);
	float m = 2.0 * sqrt(r.x * r.x + r.y * r.y + (r.z + 1.0) * (r.z + 1.0));
	vec3 env = texture(reflection_map, vec2(r.x / m + 0.5, 0.5 - r.y / m)).rgb;
	float fresnel = pow(1.0 - clamp(dot(bumped, to_eye), 0.0, 1.0), 3.0);

	ALBEDO = colour * albedo_amount;
	NORMAL = view_n;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.6;
	EMISSION = ((through + seen) * glow + env * mix(gloss * 0.3, gloss, fresnel) + glint) * world_light;
}
