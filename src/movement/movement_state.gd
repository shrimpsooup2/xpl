class_name MovementState
extends RefCounted
## Everything the movement simulation remembers between ticks, apart from the
## body's position and velocity. Keeping it in one plain object means a tick
## can be snapshotted and replayed for client prediction (GDD §15.2).

enum Mode { GROUND, AIR, SLIDE, DASH, WALLRIDE, SMASH_WINDUP, SMASH, MANTLE }

var mode: Mode = Mode.AIR
var on_ground: bool = false
var crouched: bool = false
var floor_normal: Vector3 = Vector3.UP

# Input buffers and grace windows (seconds remaining).
var jump_buffer_timer: float = 0.0
var dash_buffer_timer: float = 0.0
var crouch_buffer_timer: float = 0.0
var coyote_timer: float = 0.0
var landing_grace_timer: float = 0.0

var slide_boost_cooldown: float = 0.0

var dash_charges: int = 2
var dash_recharge_timer: float = 0.0
var dash_timer: float = 0.0
var dash_dir: Vector3 = Vector3.ZERO
var dash_speed: float = 0.0
var dash_exit_speed: float = 0.0

var wall_jumps_left: int = 3
var wall_coyote_timer: float = 0.0
## Horizontal normal of the last wall touched.
var wall_normal: Vector3 = Vector3.ZERO
var wallride_timer: float = 0.0
var wallride_normal: Vector3 = Vector3.ZERO
## The wall already ridden (or jumped off) this airtime. Cleared on landing.
var used_wall_normal: Vector3 = Vector3.ZERO
var used_wall_id: int = 0

var smash_timer: float = 0.0
var smash_start_y: float = 0.0
## Horizontal velocity stored during a smashdown and given back on impact.
var banked_velocity: Vector3 = Vector3.ZERO
var bounce_window_timer: float = 0.0
var last_drop_height: float = 0.0

var mantle_timer: float = 0.0
var mantle_from: Vector3 = Vector3.ZERO
var mantle_to: Vector3 = Vector3.ZERO
var mantle_exit_velocity: Vector3 = Vector3.ZERO
var mantle_cooldown: float = 0.0

## Velocity at the start of the last move, before collisions changed it.
var pre_move_velocity: Vector3 = Vector3.ZERO

## Things that happened this tick, for camera, audio, and VFX to react to.
## Each entry is { "type": StringName, ... }. Cleared at the start of each tick.
var events: Array[Dictionary] = []


func reset(params: MovementParams) -> void:
	var fresh := MovementState.new()
	for prop in get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			set(prop.name, fresh.get(prop.name))
	dash_charges = params.dash_charges
	wall_jumps_left = params.wall_jumps
	events = []
