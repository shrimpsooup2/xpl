shader_type spatial;
render_mode unshaded, shadows_disabled;
// The city outside: towers far off, drawn flat (their lit windows are the
// only light they need) and left to the fog.

global uniform float world_light;
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float meters_per_repeat = 12.0;

void fragment() {
	ALBEDO = texture(albedo_texture, UV / meters_per_repeat).rgb * tint * world_light;
}
