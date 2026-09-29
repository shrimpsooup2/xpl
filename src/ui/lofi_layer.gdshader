shader_type canvas_item;
// The low-res UI canvas as it's blown up to the screen: a slow, faint
// warp (like the logo), plus the shake, punch, and extra warp of a kick.
// Only moves pixels around; never touches colour.

// Warp amplitude in canvas pixels.
uniform float warp = 0.3;
// Kick: offset in canvas pixels, and zoom about the centre.
uniform vec2 offset = vec2(0.0);
uniform float zoom = 1.0;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;  // One canvas pixel in UV.
	vec2 uv = (UV - 0.5) / zoom + 0.5 - offset * px;
	uv.x += sin(uv.y * 19.0 + TIME * 1.6) * warp * px.x;
	uv.y += sin(uv.x * 13.0 - TIME * 1.1) * warp * px.y * 0.7;
	COLOR = texture(TEXTURE, uv);
}
