shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
// Glossy props: guns, pickups, shell casings. A flat colour per instance,
// shiny highlights and a fake sphere-map reflection, like the world's
// surfaces (retro_surface.gdshader). With `viewmodel` on it draws as part of
// the first-person view (viewmodel.gdshaderinc).

#include "res://src/render/viewmodel.gdshaderinc"

global uniform float world_light;
uniform sampler2D reflection_map : source_color, filter_nearest, repeat_disable;
uniform bool viewmodel = false;
instance uniform vec3 color : source_color = vec3(1.0);
// Reflection strength head-on; grazing angles get more.
instance uniform float gloss = 0.3;
instance uniform float rim_amount = 0.0;
instance uniform float glow = 0.0;
instance uniform float roughness_amount = 0.25;
// 0..1: fades the part out (dissolving pickups).
instance uniform float fade = 1.0;

void vertex() {
	// Written either way: once a shader writes POSITION, it's always used.
	POSITION = viewmodel ? viewmodel_position(VERTEX, MODELVIEW_MATRIX, PROJECTION_MATRIX)
			: PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
}

void fragment() {
	if (fade < 0.999 && fade > 0.0) {
		// Screen-door fade on the low-res pixel grid.
		float d = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))) * 43758.5453);
		if (d > fade) {
			discard;
		}
	}
	vec3 r = reflect(-VIEW, NORMAL);
	float m = 2.0 * sqrt(r.x * r.x + r.y * r.y + (r.z + 1.0) * (r.z + 1.0));
	vec3 env = texture(reflection_map, vec2(r.x / m + 0.5, 0.5 - r.y / m)).rgb;
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = color;
	ROUGHNESS = roughness_amount;
	SPECULAR = 0.7;
	RIM = rim_amount;
	RIM_TINT = 0.3;
	EMISSION = env * mix(color, vec3(1.0), 0.3) * gloss * (0.6 + 1.4 * fresnel) * world_light + color * glow;
}
