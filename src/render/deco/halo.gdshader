shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, shadows_disabled;
// The glow round neon: a soft additive haze behind the letters, bright
// enough in the middle to bloom.

global uniform float world_light;
global uniform float effects;
uniform vec3 color : source_color = vec3(1.0, 0.2, 0.3);
uniform float strength = 1.5;
// UV runs 0..size (metres) across the quad.
uniform vec2 size = vec2(4.0, 1.0);
uniform float flicker : hint_range(0.0, 1.0) = 0.0;

float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }

void fragment() {
	vec2 p = abs(UV / size * 2.0 - 1.0);
	float d = max(p.x * size.x / size.y * 0.35, p.y);
	float glow = pow(clamp(1.0 - d, 0.0, 1.0), 2.0);
	float on = 1.0;
	if (flicker > 0.0) {
		float t = TIME * effects;
		on = 1.0 - flicker * step(0.8, hash(floor(t * 0.9))) * step(0.5, hash(floor(t * 20.0)));
	}
	ALBEDO = color * strength * glow * on * world_light;
}
