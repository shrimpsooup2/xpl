// Draws a first-person viewmodel with its own fixed field of view, pulled
// in front of the world so it never clips into walls. Lighting still uses
// the real positions; only rasterising changes.

// tan(camera fov / 2) / tan(viewmodel fov / 2): 1 keeps the camera's FOV.
uniform float fov_scale = 1.0;
// The camera's near plane. Viewmodel depths are squeezed just past it.
uniform float near_plane = 0.05;

vec4 viewmodel_position(vec3 vertex, mat4 modelview, mat4 projection) {
	vec3 v = (modelview * vec4(vertex, 1.0)).xyz;
	mat4 p = projection;
	p[0][0] *= fov_scale;
	p[1][1] *= fov_scale;
	vec4 clip = p * vec4(v, 1.0);
	// 0..2 m in front of the eye becomes near..near * 2.
	float squeezed = near_plane * (1.05 + clamp(-v.z, 0.0, 2.0) * 0.5);
	vec4 z = projection * vec4(0.0, 0.0, -squeezed, 1.0);
	clip.z = z.z / z.w * clip.w;
	return clip;
}
