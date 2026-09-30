shader_type spatial;
render_mode unshaded, shadows_disabled;
// The sea of cloud (tools/maps/rift_deco.gd): a billowing surface, lit
// warm on the sides turned to the sun, lavender in the hollows, soft
// billows drifting slowly over it.

global uniform float world_light;
global uniform float effects;
uniform sampler2D billows : filter_linear_mipmap, repeat_enable;
uniform vec3 to_sun = vec3(0.9, 0.2, 0.3);
uniform vec3 lit : source_color = vec3(1.0, 0.88, 0.78);
uniform vec3 shade : source_color = vec3(0.56, 0.58, 0.72);
uniform vec3 top : source_color = vec3(0.86, 0.86, 0.92);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	vec3 n = normalize(world_normal);
	float t = TIME * effects;
	float a = texture(billows, world_pos.xz / 170.0 + vec2(t * 0.002, t * 0.001)).r;
	float b = texture(billows, world_pos.xz / 60.0 - vec2(t * 0.003, -t * 0.002)).r;
	float fluff = a * 0.6 + b * 0.4;
	float sun = clamp(dot(n, normalize(to_sun)) * 1.4 + (fluff - 0.5) * 0.6, 0.0, 1.0);
	vec3 c = mix(shade, top, clamp(n.y * 0.8 + fluff * 0.3, 0.0, 1.0));
	c = mix(c, lit, sun * 0.8);
	// The billows' own light and shade.
	c *= 0.86 + fluff * 0.26;
	ALBEDO = c * world_light;
}
