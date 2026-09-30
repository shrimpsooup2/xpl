shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, shadows_disabled;
// A pool of lamplight faked on a floor or a wall (early-2000s style): an
// additive glow, round and soft, brightest under the lamp. Cheaper than a
// light, so a lamp can have one whether or not it's a real light.

global uniform float world_light;
uniform vec3 color : source_color = vec3(1.0, 0.8, 0.55);
uniform float strength = 0.35;
// UV runs 0..size (metres) across the quad.
uniform vec2 size = vec2(4.0, 4.0);

void fragment() {
	vec2 p = UV / size * 2.0 - 1.0;
	float glow = pow(clamp(1.0 - length(p), 0.0, 1.0), 2.2);
	ALBEDO = color * strength * glow * world_light;
}
