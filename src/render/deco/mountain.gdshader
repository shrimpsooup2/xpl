shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Mountains (tools/maps/rift_deco.gd): rock on the steep faces, snow
// lying where the slope is gentle enough to hold it and the ground high
// enough, scree low down. Textured from the world (triplanar, the rock's
// beds level and its joints running down; pixel-sharp like every other
// surface), at two scales so it doesn't repeat, with broad changes of tone over it; lit by the sun like
// everything else, so the faces turned to it glow.

global uniform float world_light;
uniform sampler2D rock : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D snow : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D scree : source_color, filter_nearest_mipmap, repeat_enable;
uniform float rock_meters = 32.0;
uniform float snow_meters = 60.0;
// Where snow starts (world y), and how far over the line it takes to
// cover everything flat enough.
uniform float snowline = -70.0;
uniform float snow_fade = 60.0;
// Below this, scree.
uniform float scree_line = -120.0;
// The rock's own colour against the snow: dark granite.
uniform vec3 rock_tint : source_color = vec3(0.55, 0.53, 0.56);
// How much of the sky's light reaches the rock (the faces away from the
// sun go dark, the snow less so).
uniform float sky_light = 0.55;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

vec3 triplanar(sampler2D t, vec3 p, vec3 n, float meters) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec2 across = vec2(p.z, -p.y) / meters;
	vec2 along = vec2(p.x, -p.y) / meters;
	return texture(t, across).rgb * w.x + texture(t, p.xz / meters).rgb * w.y + texture(t, along).rgb * w.z;
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 near = triplanar(rock, world_pos, n, rock_meters);
	vec3 wide = triplanar(rock, world_pos + vec3(37.0, 11.0, 53.0), n, rock_meters * 2.7);
	// Broad tone: the rock's own light and dark, blown up huge.
	float broad = dot(triplanar(rock, world_pos, n, rock_meters * 9.0), vec3(0.33));
	vec3 r = mix(near, wide, 0.4) * rock_tint * (0.75 + broad * 0.55);
	vec3 s = triplanar(snow, world_pos, n, snow_meters);
	vec3 sc = triplanar(scree, world_pos, n, rock_meters * 0.6);
	// A little noise in the lines, from the rock itself.
	float grain = dot(near, vec3(0.33)) - 0.45;
	float high = smoothstep(snowline, snowline + snow_fade, world_pos.y + grain * 40.0 + (broad - 0.45) * 50.0);
	// Snow lies where it's flat enough, less so low down; the steep faces
	// stay bare rock all the way up.
	float flat_enough = smoothstep(0.6 - high * 0.16, 0.76 - high * 0.16, n.y + grain * 0.3);
	float cover = clamp(high * flat_enough, 0.0, 1.0);
	vec3 ground = mix(sc, r, smoothstep(scree_line, scree_line + 40.0, world_pos.y));
	ALBEDO = mix(ground, s, cover) * world_light;
	AO = mix(sky_light, 1.0, cover * 0.6);
	AO_LIGHT_AFFECT = 0.0;
	ROUGHNESS = 1.0;
}
