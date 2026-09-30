shader_type sky;
// Gradient sky with a flat sun disc. `bands` above 0 steps the gradient into
// hard bands; 0 keeps it smooth. At night (a dressed map's sky) the sun is a
// moon with a halo round it, and `stars` scatters pixel stars. `eclipse`
// puts the moon in front of the sun: a black disc in a white corona with
// streamers fanning out, one bright bead on its rim.

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
uniform float eclipse = 0.0;

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
		float d = distance(EYEDIR, LIGHT0_DIRECTION);
		c += sun_color * halo * pow(to_light, 48.0);
		if (eclipse > 0.0) {
			vec3 side = normalize(cross(LIGHT0_DIRECTION, vec3(0.0, 1.0, 0.0)));
			vec3 up = cross(side, LIGHT0_DIRECTION);
			float a = atan(dot(EYEDIR, up), dot(EYEDIR, side));
			float out_of = max(d - sun_size, 0.0);
			// A tight ring round the disc, and streamers of every length.
			float streamers = max(0.6 + 0.4 * sin(a * 5.0 + 1.3) * sin(a * 3.0 - 0.4) + 0.3 * sin(a * 11.0), 0.05);
			float ring = exp(-out_of / (sun_size * 0.12));
			float rays = exp(-out_of / (sun_size * (0.35 + 1.3 * streamers)));
			c += sun_color * (ring * 3.0 + rays * 0.8) * eclipse;
			vec3 bead_dir = normalize(LIGHT0_DIRECTION + (side * cos(2.3) + up * sin(2.3)) * sun_size);
			c += sun_color * 4.0 * exp(-distance(EYEDIR, bead_dir) / (sun_size * 0.1)) * eclipse;
			if (d < sun_size) {
				c = mix(c, vec3(0.004, 0.003, 0.008), eclipse);
			}
		} else if (d < sun_size) {
			c = sun_color * 2.0;
		}
	}
	COLOR = c * world_light;
}
