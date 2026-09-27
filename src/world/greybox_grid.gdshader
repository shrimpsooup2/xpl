shader_type spatial;
// World-space grid for greybox geometry. Minor lines every meter, major lines
// every four, so speed and distance are easy to read while moving.

uniform vec3 base_color : source_color = vec3(0.8, 0.76, 0.7);
uniform vec3 line_color : source_color = vec3(0.45, 0.42, 0.5);
uniform float minor_size = 1.0;
uniform float major_size = 4.0;
uniform float line_width = 0.02;
uniform float roughness_value = 0.35;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float grid(vec2 p, float size, float width) {
	vec2 cell = abs(fract(p / size - 0.5) - 0.5) * size;
	vec2 fw = fwidth(p);
	vec2 lines = 1.0 - smoothstep(vec2(width) - fw, vec2(width) + fw, cell);
	return max(lines.x, lines.y);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 uv = n.y > 0.577 ? world_pos.xz : (n.x > n.z ? world_pos.zy : world_pos.xy);
	float minor = grid(uv, minor_size, line_width);
	float major = grid(uv, major_size, line_width * 2.0);
	ALBEDO = mix(base_color, line_color, max(minor * 0.45, major));
	ROUGHNESS = roughness_value;
	SPECULAR = 0.6;
}
