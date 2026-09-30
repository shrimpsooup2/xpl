shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
// gloss.gdshaderinc with the colour and finish on the material (see there
// and src/render/gloss.gd).

#define GLOSS_SHARED
#include "res://src/render/gloss.gdshaderinc"
