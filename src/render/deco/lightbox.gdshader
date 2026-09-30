shader_type spatial;
render_mode unshaded, shadows_disabled;
// A lit panel with a picture on it: a menu board, a vending machine's
// front, a mall directory. Its own light, bright enough to bloom where the
// picture is pale; `flicker` makes it stutter like a failing tube.

global uniform float world_light;
global uniform float effects;
uniform sampler2D picture : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float energy = 1.2;
// UV metres per picture across the face.
uniform vec2 size = vec2(1.0, 1.0);
uniform float flicker : hint_range(0.0, 1.0) = 0.0;

float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }

void fragment() {
	float on = 1.0;
	if (flicker > 0.0) {
		float t = TIME * effects;
		on = 1.0 - flicker * step(0.8, hash(floor(t * 0.8))) * step(0.5, hash(floor(t * 22.0)));
	}
	ALBEDO = texture(picture, UV / size).rgb * tint * energy * on * world_light;
}
