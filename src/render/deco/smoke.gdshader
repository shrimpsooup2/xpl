shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, shadows_disabled, cull_disabled;
// A puff of smoke that always faces you (a chimney's, a brazier's): a
// soft lumpy blot in coarse pixels, fading as the particle's colour's
// alpha says (CPUParticles3D's ramp).

global uniform float world_light;
uniform vec3 color : source_color = vec3(0.62, 0.66, 0.72);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 cell = floor(UV * 12.0);
	vec2 p = (cell + 0.5) / 12.0 - 0.5;
	float r = length(p) * 2.0 + (hash(cell + floor(COLOR.r * 50.0)) - 0.5) * 0.35;
	float puff = 1.0 - smoothstep(0.35, 0.95, r);
	ALBEDO = color * world_light;
	ALPHA = puff * COLOR.a;
}
