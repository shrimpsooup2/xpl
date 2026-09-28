shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// Additive, unlit flashes: muzzle flashes, tracers, sparks. With
// `viewmodel` on it draws as part of the first-person view.

#include "res://src/render/viewmodel.gdshaderinc"

uniform bool viewmodel = false;
instance uniform vec4 tint : source_color = vec4(1.0);

void vertex() {
	// Written either way: once a shader writes POSITION, it's always used.
	POSITION = viewmodel ? viewmodel_position(VERTEX, MODELVIEW_MATRIX, PROJECTION_MATRIX)
			: PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
}

void fragment() {
	ALBEDO = tint.rgb * tint.a;
}
