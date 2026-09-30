shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// A fake shaft of light (early-2000s style): an additive glow, strongest
// where it comes in at the top, fading down, soft at the sides.

global uniform float world_light;
uniform vec3 color : source_color = vec3(0.55, 0.65, 1.0);
uniform float strength = 0.35;
// UV metres: x across the face, y down it.
uniform vec2 size = vec2(3.0, 4.5);

void fragment() {
	float down = clamp(UV.y / size.y, 0.0, 1.0);
	float across = clamp(UV.x / size.x, 0.0, 1.0);
	float side = smoothstep(0.0, 0.3, across) * smoothstep(1.0, 0.7, across);
	float facing = abs(dot(NORMAL, VIEW));
	ALBEDO = color * strength * pow(1.0 - down, 1.6) * side * (0.35 + 0.65 * (1.0 - facing)) * world_light;
}
