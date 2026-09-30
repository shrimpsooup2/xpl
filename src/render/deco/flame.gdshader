shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// A flame (tools/maps/boulevard_deco.gd: hearths, braziers, lanterns): a
// teardrop of fire on a sheet (a few sheets crossed), white-yellow at its
// heart, orange at its edge, licking and swaying. Held still with the
// effects setting off.

global uniform float world_light;
global uniform float effects;
uniform vec3 core : source_color = vec3(1.0, 0.86, 0.52);
uniform vec3 edge : source_color = vec3(1.0, 0.38, 0.08);
uniform float energy = 2.2;
// UV metres of one sheet: x across, y down.
uniform vec2 size = vec2(0.5, 0.8);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = UV / size;
	float t = TIME * effects;
	float phase = dot(world_pos, vec3(3.1, 1.7, 2.3));
	float up = 1.0 - uv.y;
	// Licking: the flame sways more toward its tip, and breathes.
	float x = (uv.x - 0.5) * 2.0 + sin(up * 5.0 - t * 8.0 + phase) * 0.22 * up;
	float tall = 0.85 + 0.15 * sin(t * 5.3 + phase * 1.7);
	float width = mix(0.9, 0.05, clamp(up / tall, 0.0, 1.0));
	float body = 1.0 - smoothstep(width * 0.55, width, abs(x));
	body *= smoothstep(0.0, 0.15, uv.y) * (1.0 - smoothstep(tall * 0.7, tall, up));
	float heart = body * (1.0 - smoothstep(0.0, 0.6, up / tall)) * (1.0 - smoothstep(0.0, 0.5, abs(x) / max(width, 0.01)));
	ALBEDO = (edge * body + core * heart) * energy * world_light;
}
