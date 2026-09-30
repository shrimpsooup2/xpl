shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// Skylight glass: nearly clear head on, catching the sky at a slant, grime
// blotched over it and gathered along each pane's lower edge where the
// rain ran down and dried.

global uniform float world_light;
uniform sampler2D reflection_map : source_color, filter_nearest, repeat_disable;
uniform sampler2D grime : hint_default_black, filter_linear, repeat_enable;
uniform vec3 tint : source_color = vec3(0.70, 0.80, 0.86);
uniform vec3 dirt : source_color = vec3(0.30, 0.27, 0.24);
uniform float opacity = 0.1;
// UV metres per pane (DecoKit faces start their UV at each pane's corner).
uniform vec2 pane = vec2(4.0, 3.0);

void fragment() {
	vec2 p = UV / pane;
	float low = smoothstep(0.7, 1.0, fract(p.y));
	float blotch = texture(grime, UV * 0.22).r;
	float grimy = clamp(blotch * 0.8 + low * (0.4 + 0.6 * blotch), 0.0, 1.0);
	vec3 r = reflect(-VIEW, NORMAL);
	float m = 2.0 * sqrt(r.x * r.x + r.y * r.y + (r.z + 1.0) * (r.z + 1.0));
	vec3 env = texture(reflection_map, vec2(r.x / m + 0.5, 0.5 - r.y / m)).rgb;
	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), 3.0);
	ALBEDO = mix(tint * (0.25 + env), dirt, grimy) * world_light;
	ALPHA = clamp(opacity + fresnel * 0.45 + grimy * 0.45, 0.0, 0.8);
}
