shader_type spatial;
render_mode blend_mix, specular_schlick_ggx, depth_draw_never, shadows_disabled;
// A puddle: a dark, glassy film on the floor with a ragged edge, rippling a
// little, catching the fake sky reflection and the lamps' highlights.

global uniform float world_light;
global uniform float effects;
uniform sampler2D reflection_map : source_color, filter_nearest, repeat_disable;
uniform sampler2D noise : hint_default_black, filter_linear, repeat_enable;
// UV runs 0..size (metres) across the quad.
uniform vec2 size = vec2(2.0, 2.0);
uniform vec3 color : source_color = vec3(0.05, 0.10, 0.14);
uniform float opacity = 0.75;

void fragment() {
	vec2 c = UV / size * 2.0 - 1.0;
	float n = texture(noise, UV * 0.35).r;
	float edge = 1.0 - smoothstep(0.55, 0.95, length(c) + (n - 0.5) * 0.6);
	float t = TIME * effects;
	vec2 ripple = vec2(sin(UV.x * 9.0 + t * 1.3), cos(UV.y * 8.0 - t * 1.1)) * 0.03;
	vec3 r = reflect(-VIEW, normalize(NORMAL + vec3(ripple.x, 0.0, ripple.y)));
	float m = 2.0 * sqrt(r.x * r.x + r.y * r.y + (r.z + 1.0) * (r.z + 1.0));
	vec3 env = texture(reflection_map, vec2(r.x / m + 0.5, 0.5 - r.y / m)).rgb;
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = color;
	ROUGHNESS = 0.08;
	SPECULAR = 0.8;
	EMISSION = env * (0.25 + 0.6 * fresnel) * world_light;
	ALPHA = edge * opacity;
}
