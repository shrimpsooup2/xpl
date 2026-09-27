shader_type canvas_item;
// Final screen pass over the upscaled 3D image: cuts colour depth (32 levels
// per channel is 15/16-bit colour) with a 4×4 ordered dither aligned to the
// low-res pixel grid. The HUD draws on a higher layer and stays sharp.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
// Screen pixels per rendered pixel.
uniform float pixel_size = 3.0;
// Levels per colour channel. 0 turns the effect off.
uniform float color_levels = 32.0;
uniform float dither_strength : hint_range(0.0, 1.0) = 1.0;

const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec3 c = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	if (color_levels > 0.0) {
		ivec2 cell = ivec2(floor(FRAGCOORD.xy / pixel_size)) % 4;
		float threshold = (BAYER[cell.y * 4 + cell.x] + 0.5) / 16.0 - 0.5;
		float steps = color_levels - 1.0;
		c = floor(c * steps + 0.5 + threshold * dither_strength) / steps;
	}
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
