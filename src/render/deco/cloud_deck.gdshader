shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// An overcast deck of cloud seen from under it (tools/maps/rift_deco.gd):
// grey-lavender where it's thick, lighter where it thins, lit gold at the
// edges on the sun's side, fading out toward the horizon where the sky
// shows through under it.

global uniform float world_light;
global uniform float effects;
uniform sampler2D billows : filter_linear_mipmap, repeat_enable;
uniform vec3 to_sun = vec3(0.9, 0.2, 0.3);
uniform vec3 thick : source_color = vec3(0.40, 0.40, 0.50);
uniform vec3 thin : source_color = vec3(0.72, 0.70, 0.78);
uniform vec3 lining : source_color = vec3(1.0, 0.72, 0.46);
uniform float cover = 0.7;
// Where the deck fades (metres from its middle).
uniform float reach = 460.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME * effects;
	float a = texture(billows, world_pos.xz / 520.0 + vec2(t * 0.0015, 0.0)).r;
	float b = texture(billows, world_pos.xz / 190.0 + vec2(t * 0.003, t * 0.001)).r;
	float d = clamp(a * 0.65 + b * 0.35 + (cover - 0.5), 0.0, 1.0);
	float density = smoothstep(0.3, 0.75, d);
	vec3 view = normalize(world_pos - CAMERA_POSITION_WORLD);
	float toward = pow(max(dot(view, normalize(to_sun)), 0.0), 3.0);
	vec3 c = mix(thin, thick, density);
	// Thin cloud toward the sun is lit through.
	c = mix(c, lining, toward * (1.0 - density * 0.7));
	float fade = 1.0 - smoothstep(reach * 0.55, reach, length(world_pos.xz));
	ALBEDO = c * world_light;
	ALPHA = clamp(density * 0.95 + 0.25, 0.0, 0.97) * fade;
}
