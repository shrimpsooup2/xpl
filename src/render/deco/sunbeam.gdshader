shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// A shaft of sun far off, slanting down out of a break in the cloud: a
// faint additive sheet, soft at its sides and both ends, fainter face on.
// No fog (fog on an additive sheet would only add to it).

global uniform float world_light;
uniform vec3 color : source_color = vec3(1.0, 0.8, 0.55);
uniform float strength = 0.06;
// UV metres: x across, y down it.
uniform vec2 size = vec2(24.0, 320.0);
// Where down it (0..1) it starts to fade out, and is gone.
uniform vec2 end_fade = vec2(0.55, 1.0);

void fragment() {
	float down = clamp(UV.y / size.y, 0.0, 1.0);
	float across = clamp(UV.x / size.x, 0.0, 1.0);
	float side = smoothstep(0.0, 0.5, across) * smoothstep(1.0, 0.5, across);
	float ends = smoothstep(0.0, 0.15, down) * (1.0 - smoothstep(end_fade.x, end_fade.y, down));
	float facing = abs(dot(NORMAL, VIEW));
	ALBEDO = color * strength * side * ends * (0.3 + 0.7 * (1.0 - facing)) * world_light;
}
