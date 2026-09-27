shader_type sky;
// Gradient sky with a flat sun disc. `bands` above 0 steps the gradient into
// hard bands; 0 keeps it smooth.

uniform vec3 top_color : source_color = vec3(0.24, 0.16, 0.42);
uniform vec3 upper_color : source_color = vec3(0.56, 0.38, 0.72);
uniform vec3 horizon_color : source_color = vec3(1.0, 0.56, 0.48);
uniform vec3 ground_color : source_color = vec3(0.16, 0.10, 0.20);
uniform float bands = 0.0;
uniform vec3 sun_color : source_color = vec3(1.0, 0.92, 0.70);
uniform float sun_size = 0.035;

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
	if (LIGHT0_ENABLED && distance(EYEDIR, LIGHT0_DIRECTION) < sun_size) {
		c = sun_color * 2.0;
	}
	COLOR = c;
}
