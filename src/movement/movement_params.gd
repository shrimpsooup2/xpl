class_name MovementParams
extends Resource
## Tuning values for the movement simulation.
##
## Defaults match GDD §4.3 and §4.4. Units are meters, seconds, and m/s.
## Edit live in-game with the tuning panel (F1); saving writes this resource
## back to res://data/movement_params.tres when running from the editor.

@export_group("Body")
@export_range(0.2, 0.6, 0.01) var capsule_radius: float = 0.35
@export_range(1.0, 2.5, 0.01) var stand_height: float = 1.8
@export_range(0.7, 1.5, 0.01) var crouch_height: float = 0.9
@export_range(0.5, 2.2, 0.01) var stand_eye_height: float = 1.6
@export_range(0.3, 1.4, 0.01) var crouch_eye_height: float = 0.75
@export_range(0.0, 0.8, 0.01) var step_height: float = 0.4
@export_range(10.0, 80.0, 0.5) var max_floor_angle_deg: float = 50.0

@export_group("Ground")
@export_range(1.0, 30.0, 0.1) var run_speed: float = 8.5
@export_range(0.0, 50.0, 0.5) var ground_accel: float = 10.0
@export_range(0.0, 20.0, 0.1) var ground_friction: float = 6.0
@export_range(0.0, 10.0, 0.1) var stop_speed: float = 2.5
@export_range(0.5, 15.0, 0.1) var crouch_speed: float = 4.0
## Friction is skipped for this long after landing so well-timed hops keep speed.
@export_range(0.0, 0.3, 0.005) var landing_grace: float = 0.05

@export_group("Air")
@export_range(1.0, 60.0, 0.5) var gravity: float = 20.0
@export_range(0.0, 20.0, 0.1) var jump_velocity: float = 7.0
@export_range(0.0, 0.3, 0.005) var coyote_time: float = 0.1
@export_range(0.0, 0.3, 0.005) var jump_buffer: float = 0.12
@export_range(0.0, 100.0, 0.5) var air_accel: float = 12.0
## Quake-style cap on air wishspeed. This is what makes strafe gain possible.
@export_range(0.0, 10.0, 0.05) var air_wishspeed_cap: float = 1.0
@export_range(5.0, 50.0, 0.5) var soft_speed_cap: float = 16.0
## Extra deceleration per 1 m/s of horizontal speed above the soft cap.
@export_range(0.0, 10.0, 0.1) var soft_cap_drag: float = 2.0
@export_range(10.0, 100.0, 1.0) var terminal_velocity: float = 40.0

@export_group("Slide")
@export_range(0.0, 20.0, 0.1) var slide_min_speed: float = 6.0
@export_range(0.0, 10.0, 0.1) var slide_boost: float = 3.0
@export_range(0.0, 5.0, 0.05) var slide_boost_cooldown: float = 1.5
## Deceleration while sliding, in m/s² (constant, not proportional to speed,
## so fast slides carry). Slopes steeper than about 10° pull harder than this.
@export_range(0.0, 20.0, 0.1) var slide_friction: float = 3.5
@export_range(0.0, 10.0, 0.1) var slide_exit_speed: float = 4.0

@export_group("Dash")
@export_range(0, 5, 1) var dash_charges: int = 2
@export_range(0.1, 10.0, 0.05) var dash_recharge: float = 2.25
@export_range(1.0, 50.0, 0.5) var dash_speed: float = 18.0
@export_range(0.02, 0.5, 0.01) var dash_duration: float = 0.15
@export_range(0.0, 30.0, 0.5) var dash_exit_min_speed: float = 10.0
## A dash always bursts at least this much faster than you were going.
@export_range(0.0, 10.0, 0.5) var dash_min_gain: float = 3.0
## Share of the burst (over your speed going in) you keep when a dash ends:
## on the ground, and in the air, where it carries you on much further.
@export_range(0.0, 1.0, 0.05) var dash_keep_ground: float = 0.35
@export_range(0.0, 1.0, 0.05) var dash_keep_air: float = 0.75
## Upward speed an air dash ends with: a little lift, so it flies.
@export_range(0.0, 5.0, 0.1) var dash_air_lift: float = 1.5
## After a dash, speed above run speed fades at dash_carry_drag for this long
## on the ground (an air dash's waits until you land) instead of friction
## stopping it: you stay faster for a moment.
@export_range(0.0, 2.0, 0.05) var dash_carry_time: float = 0.6
@export_range(0.0, 30.0, 0.5) var dash_carry_drag: float = 5.0

@export_group("Wall")
@export_range(0.0, 20.0, 0.1) var wallride_min_speed: float = 5.0
@export_range(0.1, 5.0, 0.05) var wallride_duration: float = 1.2
## Gravity during a ride eases from this fraction back to full: a ride holds
## height early and sinks late. The curve exponent shapes that ease.
@export_range(0.0, 1.0, 0.05) var wallride_gravity_start: float = 0.0
@export_range(0.5, 4.0, 0.1) var wallride_gravity_curve: float = 2.0
## Vertical speed is clamped into this range when a wall ride starts.
@export_range(-10.0, 0.0, 0.1) var wallride_attach_min_vy: float = -1.0
@export_range(0.0, 10.0, 0.1) var wallride_attach_max_vy: float = 2.0
@export_range(0, 10, 1) var wall_jumps: int = 3
@export_range(0.0, 20.0, 0.1) var wall_jump_out: float = 6.0
@export_range(0.0, 20.0, 0.1) var wall_jump_up: float = 6.5
@export_range(0.0, 0.5, 0.01) var wall_coyote_time: float = 0.15

@export_group("Mantle")
@export_range(0.0, 2.0, 0.05) var mantle_min_height: float = 0.5
@export_range(0.5, 3.0, 0.05) var mantle_max_height_air: float = 2.0
@export_range(0.5, 3.0, 0.05) var mantle_max_height_ground: float = 1.2
## How far past the capsule surface a ledge can be and still be grabbed.
@export_range(0.1, 1.5, 0.05) var mantle_reach: float = 0.6
@export_range(0.05, 1.0, 0.01) var mantle_duration: float = 0.2
@export_range(0.0, 1.5, 0.05) var mantle_speed_keep: float = 0.8
@export_range(0.0, 15.0, 0.5) var mantle_min_exit_speed: float = 3.0

@export_group("Smashdown")
@export_range(0.0, 10.0, 0.1) var smash_min_clearance: float = 1.5
@export_range(0.0, 0.5, 0.01) var smash_windup: float = 0.1
@export_range(5.0, 100.0, 1.0) var smash_speed: float = 40.0
@export_range(0.0, 1.0, 0.01) var smash_bounce_window: float = 0.2
@export_range(0.0, 30.0, 0.5) var smash_bounce_base: float = 9.0
@export_range(0.0, 3.0, 0.05) var smash_bounce_per_meter: float = 0.75
@export_range(0.0, 50.0, 0.5) var smash_bounce_max: float = 22.0
## Horizontal speed a slam bounce adds, toward your input (or along the
## banked direction without input).
@export_range(0.0, 10.0, 0.5) var smash_bounce_boost: float = 3.0
@export_range(0.0, 20.0, 0.5) var smash_slide_bonus: float = 4.0

@export_group("Input")
## How long dash and crouch presses are remembered before they can act.
@export_range(0.0, 0.3, 0.005) var input_buffer: float = 0.12
