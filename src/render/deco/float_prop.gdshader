shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx, cull_disabled;
// Pool inflatables adrift in the sky over the empty pool: glossy vinyl in
// its vertex colours, turning slowly and bobbing as if on water that isn't
// there.

global uniform float world_light;
global uniform float effects;
uniform sampler2D reflection_map : source_color, filter_nearest, repeat_disable;
uniform float spin = 0.15;
uniform float bob = 0.35;
uniform float bob_speed = 0.5;
uniform float tilt = 0.08;
uniform float phase = 0.0;

void vertex() {
	float t = TIME * effects;
	float a = t * spin + phase;
	mat2 r = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a)));
	VERTEX.xz = r * VERTEX.xz;
	NORMAL.xz = r * NORMAL.xz;
	float w = sin(t * bob_speed * 1.3 + phase) * tilt;
	VERTEX.y += VERTEX.x * w + sin(t * bob_speed + phase) * bob;
}

void fragment() {
	vec3 r = reflect(-VIEW, NORMAL);
	float m = 2.0 * sqrt(r.x * r.x + r.y * r.y + (r.z + 1.0) * (r.z + 1.0));
	vec3 env = texture(reflection_map, vec2(r.x / m + 0.5, 0.5 - r.y / m)).rgb;
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.15;
	SPECULAR = 0.8;
	EMISSION = env * COLOR.rgb * (0.25 + 0.8 * fresnel) * world_light;
}
