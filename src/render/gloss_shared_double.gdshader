shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx, cull_disabled;
// gloss_shared.gdshader drawn from both sides (a hat's brim).

#define GLOSS_SHARED
#include "res://src/render/gloss.gdshaderinc"
