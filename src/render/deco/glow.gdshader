shader_type spatial;
render_mode unshaded;
// A lamp's lit part (a fluorescent tube, a pool light's lens, neon, an exit
// sign): flat colour bright enough to bloom. `flicker` makes it stutter
// like a failing tube; `blink` turns it on and off (aviation lights).
// Goes dark with the world in the death sequence.

global uniform float world_light;
global uniform float effects;
uniform vec3 color : source_color = vec3(1.0);
uniform float energy = 2.0;
uniform float flicker : hint_range(0.0, 1.0) = 0.0;
uniform float blink_period = 0.0;

float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }

void fragment() {
	float t = TIME * effects;
	float on = 1.0;
	if (flicker > 0.0) {
		// Mostly on; now and then a stutter of dropouts.
		float burst = step(0.82, hash(floor(t * 0.7)));
		on = 1.0 - flicker * burst * step(0.45, hash(floor(t * 24.0)));
	}
	if (blink_period > 0.0) {
		on *= step(fract(t / blink_period), 0.18);
	}
	ALBEDO = color * energy * on * world_light;
}
