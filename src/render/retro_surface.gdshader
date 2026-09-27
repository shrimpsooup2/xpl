shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
// Surface shader for world geometry: point-filtered low-res textures,
// box-projected so any box tiles cleanly, plus a fake env-map reflection
// for that glossy early-2000s look.

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D reflection_map : source_color, filter_nearest, repeat_disable;
uniform vec3 tint : source_color = vec3(1.0);
// World meters covered by one repeat of the texture.
uniform float meters_per_repeat = 2.0;
// Strength of the fake reflection, head-on and at grazing angles.
uniform float gloss : hint_range(0.0, 1.0) = 0.25;
uniform float gloss_grazing : hint_range(0.0, 1.0) = 0.6;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.35;
uniform float specular_value : hint_range(0.0, 1.0) = 0.6;

varying vec3 box_pos;
varying vec3 box_normal;

void vertex() {
	// Texture coordinates follow the box's rotation but the world's position,
	// so neighbouring boxes line up and ramps are textured along their slope.
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	mat3 rot = mat3(MODEL_MATRIX);
	box_pos = transpose(rot) * world;
	box_normal = NORMAL;
}

void fragment() {
	vec3 n = abs(box_normal);
	vec2 uv;
	if (n.y >= n.x && n.y >= n.z) {
		uv = box_pos.xz;
	} else if (n.x >= n.z) {
		uv = vec2(box_pos.z * sign(box_normal.x), -box_pos.y);
	} else {
		uv = vec2(-box_pos.x * sign(box_normal.z), -box_pos.y);
	}
	vec3 albedo = texture(albedo_texture, uv / meters_per_repeat).rgb * tint;

	// Sphere-map reflection in view space.
	vec3 r = reflect(-VIEW, NORMAL);
	float m = 2.0 * sqrt(r.x * r.x + r.y * r.y + (r.z + 1.0) * (r.z + 1.0));
	vec2 env_uv = vec2(r.x / m + 0.5, 0.5 - r.y / m);
	vec3 env = texture(reflection_map, env_uv).rgb;
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);

	ALBEDO = albedo;
	ROUGHNESS = roughness_value;
	SPECULAR = specular_value;
	EMISSION = env * albedo * mix(gloss, gloss_grazing, fresnel);
}
