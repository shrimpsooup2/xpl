shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
// Surface shader for world geometry: point-filtered low-res textures,
// box-projected so any box tiles cleanly, plus a fake env-map reflection
// for that glossy early-2000s look.
//
// Dressed maps (GDD §9.3) use more of it: a different texture on the top
// and the bottom of a block (a pool's tiles on top, a concrete ceiling
// underneath), mesh UVs in metres instead of the box projection (decor),
// lane lines painted across the tops, water caustics, and indoor zones
// where the sky's light doesn't reach (AmbientZone).

// 1 normally; the death sequence fades it to 0 so only real lights remain.
global uniform float world_light;
// The level's indoor zone (AmbientZone): inside this box the sky's ambient
// light is cut down to `indoor_ambient`, so rooms are lit by their lamps.
global uniform vec3 indoor_min;
global uniform vec3 indoor_max;
global uniform float indoor_ambient;
// 1 animates caustics and the like; 0 holds them still (the effects setting).
global uniform float effects;

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D reflection_map : source_color, filter_nearest, repeat_disable;
uniform vec3 tint : source_color = vec3(1.0);
// World meters covered by one repeat of the texture.
uniform float meters_per_repeat = 2.0;
// Strength of the fake reflection, head-on and at grazing angles.
uniform float gloss : hint_range(0.0, 1.0) = 0.25;
uniform float gloss_grazing : hint_range(0.0, 1.0) = 0.6;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.35;
uniform float specular_value : hint_range(0.0, 1.0) = 0.6;

// Up-facing and down-facing faces can have their own texture.
uniform bool use_top = false;
uniform sampler2D top_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec3 top_tint : source_color = vec3(1.0);
uniform float top_meters = 2.0;
uniform bool use_bottom = false;
uniform sampler2D bottom_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform float bottom_meters = 2.0;

// Decor meshes carry UVs in metres along each face; use those instead of
// projecting.
uniform bool use_uv = false;

// Lane lines painted on the tops (a pool): lines along z, one every
// `lane_period` metres in x, `lane_width` wide, running `lane_length` either
// side of the middle and ending in a T. Strength in lane_color.a.
uniform vec4 lane_color : source_color = vec4(0.0);
uniform float lane_period = 2.75;
uniform float lane_width = 0.25;
uniform float lane_length = 9.0;

// Caustics: light as if through moving water, even with none there.
uniform sampler2D caustics_texture : hint_default_black, filter_nearest, repeat_enable;
uniform float caustics = 0.0;
uniform vec3 caustics_color : source_color = vec3(0.55, 0.95, 1.0);
uniform float caustics_meters = 3.0;

varying vec3 box_pos;
varying vec3 box_normal;
varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	// Texture coordinates follow the box's rotation but the world's position,
	// so neighbouring boxes line up and ramps are textured along their slope.
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	mat3 rot = mat3(MODEL_MATRIX);
	box_pos = transpose(rot) * world;
	box_normal = NORMAL;
	world_pos = world;
	world_normal = normalize(rot * NORMAL);
}

// Painted lanes: 0..1 of paint at world (x, z).
float lanes(vec2 p) {
	float along = abs(p.y);
	float lane = p.x / lane_period;
	float from_line = abs(fract(lane) - 0.5) * lane_period;
	float line = step(from_line, lane_width * 0.5) * step(along, lane_length);
	float bar = step(from_line, 0.5) * step(lane_length - lane_width, along) * step(along, lane_length);
	return max(line, bar);
}

void fragment() {
	vec3 n = abs(box_normal);
	vec2 uv;
	if (n.y >= n.x && n.y >= n.z) {
		uv = box_pos.xz;
	} else if (n.x >= n.z) {
		uv = vec2(box_pos.z * sign(box_normal.x), -box_pos.y);
	} else {
		uv = vec2(-box_pos.x * sign(box_normal.z), -box_pos.y);
	}
	if (use_uv) {
		uv = UV;
	}
	bool top = world_normal.y > 0.6;
	bool bottom = world_normal.y < -0.6;
	vec3 albedo;
	if (top && use_top) {
		albedo = texture(top_texture, uv / top_meters).rgb * top_tint;
		if (lane_color.a > 0.0) {
			albedo = mix(albedo, lane_color.rgb, lanes(world_pos.xz) * lane_color.a);
		}
	} else if (bottom && use_bottom) {
		albedo = texture(bottom_texture, uv / bottom_meters).rgb;
	} else {
		albedo = texture(albedo_texture, uv / meters_per_repeat).rgb * tint;
	}

	// Sphere-map reflection in view space.
	vec3 r = reflect(-VIEW, NORMAL);
	float m = 2.0 * sqrt(r.x * r.x + r.y * r.y + (r.z + 1.0) * (r.z + 1.0));
	vec2 env_uv = vec2(r.x / m + 0.5, 0.5 - r.y / m);
	vec3 env = texture(reflection_map, env_uv).rgb;
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);

	vec3 glow = vec3(0.0);
	if (caustics > 0.0 && !bottom) {
		// Two layers drifting different ways; where both are bright, light.
		vec2 cp = (top ? world_pos.xz : uv) / caustics_meters;
		float t = TIME * effects;
		float a = texture(caustics_texture, cp + vec2(t * 0.031, t * 0.017)).r;
		float b = texture(caustics_texture, cp * 0.83 + vec2(-t * 0.022, t * 0.029)).r;
		glow = caustics_color * min(a, b) * caustics * albedo;
	}

	// The indoor zone, with a soft quarter-metre edge.
	vec3 into = min(world_pos - indoor_min, indoor_max - world_pos);
	float inside = clamp(min(into.x, min(into.y, into.z)) / 0.25, 0.0, 1.0);

	ALBEDO = albedo;
	ROUGHNESS = roughness_value;
	SPECULAR = specular_value;
	AO = mix(1.0, indoor_ambient, inside);
	AO_LIGHT_AFFECT = 0.0;
	EMISSION = (env * albedo * mix(gloss, gloss_grazing, fresnel) * mix(1.0, indoor_ambient, inside * 0.7) + glow) * world_light;
}
