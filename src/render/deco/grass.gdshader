shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;
// Tufts of grass (tools/maps/rift_deco.gd): blades in their vertex
// colours, darker at the root, swaying in the wind by how far up the
// blade they are (UV.y: 0 at the root, 1 at the tip).

global uniform float world_light;
global uniform float effects;
uniform float sway = 0.06;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * effects;
	float gust = sin(t * 1.3 + world.x * 0.25 + world.z * 0.18) * 0.7 + sin(t * 2.9 + world.x * 0.9) * 0.3;
	float bend = UV.y * UV.y * sway;
	VERTEX.x += gust * bend;
	VERTEX.z += gust * bend * 0.5;
}

void fragment() {
	ALBEDO = COLOR.rgb * world_light;
	ROUGHNESS = 1.0;
}
