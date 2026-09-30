shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// Water falling in a thin sheet (the drain spilling into the room below):
// streaks scrolling down, fading in at the lip and out at the bottom.

global uniform float world_light;
global uniform float effects;
uniform sampler2D streaks : hint_default_white, filter_nearest, repeat_enable;
uniform vec3 color : source_color = vec3(0.70, 0.92, 1.0);
uniform float opacity = 0.55;
uniform float speed = 1.6;
// UV metres per texture repeat.
uniform vec2 meters = vec2(0.8, 1.6);
uniform float height = 4.5;

void fragment() {
	float t = TIME * effects;
	vec2 uv = UV / meters;
	float a = texture(streaks, uv + vec2(0.0, -t * speed / meters.y)).r;
	float b = texture(streaks, uv * vec2(1.7, 0.8) + vec2(0.31, -t * speed * 1.3 / meters.y)).r;
	float s = max(a, b * 0.8);
	float fade = smoothstep(0.0, 0.25, UV.y) * (1.0 - smoothstep(height - 0.5, height, UV.y));
	ALBEDO = color * (0.6 + s * 0.8) * world_light;
	ALPHA = clamp(s * opacity * fade, 0.0, 1.0);
}
