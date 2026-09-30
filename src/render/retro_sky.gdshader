shader_type sky;
// Gradient sky with a flat sun disc. `bands` above 0 steps the gradient into
// hard bands; 0 keeps it smooth. At night (a dressed map's sky) the sun is a
// moon with a halo round it, and `stars` scatters pixel stars.

global uniform float world_light;

uniform vec3 top_color : source_color = vec3(0.24, 0.16, 0.42);
uniform vec3 upper_color : source_color = vec3(0.56, 0.38, 0.72);
uniform vec3 horizon_color : source_color = vec3(1.0, 0.56, 0.48);
uniform vec3 ground_color : source_color = vec3(0.16, 0.10, 0.20);
uniform float bands = 0.0;
uniform vec3 sun_color : source_color = vec3(1.0, 0.92, 0.70);
uniform float sun_size = 0.035;
uniform float halo = 0.0;
uniform float stars = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void sky() {
	float h = EYEDIR.y;
	vec3 c;
	if (h < 0.0) {
		c = mix(horizon_color * 0.6, ground_color, clamp(-h * 6.0, 0.0, 1.0));
	} else {
		float t = pow(h, 0.6);
		if (bands > 0.0) {
			t = floor(t * bands) / bands;
		}
		c = t < 0.5 ? mix(horizon_color, upper_color, t * 2.0) : mix(upper_color, top_color, t * 2.0 - 1.0);
	}
	if (stars > 0.0 && h > 0.02) {
		vec2 cell = floor(vec2(atan(EYEDIR.z, EYEDIR.x) * cos(asin(h)), asin(h)) * 260.0);
		float s = hash(cell);
		c += vec3(0.85, 0.9, 1.0) * step(0.9965, s) * (0.3 + 0.7 * fract(s * 91.0)) * stars * smoothstep(0.02, 0.3, h);
	}
	if (LIGHT0_ENABLED) {
		float to_light = max(dot(EYEDIR, LIGHT0_DIRECTION), 0.0);
		c += sun_color * halo * pow(to_light, 48.0);
		if (distance(EYEDIR, LIGHT0_DIRECTION) < sun_size) {
			c = sun_color * 2.0;
		}
	}
	COLOR = c * world_light;
}
