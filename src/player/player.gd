class_name Player
extends CharacterBody3D
## The local player: samples input, runs the movement sim at the fixed tick,
## and drives a camera that is interpolated between ticks.
##
## Mouse look is applied on every input event, not on the tick, so aiming
## never waits for physics (GDD §10.3).

signal movement_event(event: Dictionary)
signal died
signal respawned

const DEGREES_PER_COUNT := 0.022
const MAX_PITCH := 1.5533430342749532  # 89 degrees
const EYE_HEIGHT_SPEED := 6.0  # m/s the camera moves when crouching
const DIP_PER_IMPACT := 0.006  # meters of landing dip per m/s of fall speed
const DIP_MAX := 0.12
const DIP_RECOVER := 1.2  # m/s
## Falling below this height kills you.
const KILL_Y := -40.0
## Debug third-person camera (F6): distance behind and height above the eyes.
const THIRD_PERSON_DISTANCE := 3.4
const THIRD_PERSON_HEIGHT := 0.5
## Camera punch (punch_camera()), at strength 1 and default screen shake:
## zoom-in (degrees of vertical FOV), roll and pitch kick, a shove back
## (meters), then a damped spring back. Slow enough that the view is still
## visibly punched in when an impact frame's held beats end, then swings
## out past rest into a recoil and settles in about half a second.
const PUNCH_FOV := 14.0
const PUNCH_ROLL := deg_to_rad(5.0)
const PUNCH_PITCH := deg_to_rad(2.0)
const PUNCH_YAW := deg_to_rad(1.0)
const PUNCH_PUSH := 0.12
const PUNCH_FREQUENCY := 12.0  # rad/s
const PUNCH_DAMPING := 0.45
const PUNCH_TIME := 0.7

# Camera reactions (GDD §10.3), at camera motion 1. The view only ever moves
# in answer to your movement; nothing sways on its own.
## Roll per m/s of sideways speed, and its limit.
const LEAN_PER_SPEED := deg_to_rad(0.3)
const LEAN_MAX := deg_to_rad(3.0)
## Sliding: roll into the slide, widen the view with speed, rumble.
const SLIDE_TILT := deg_to_rad(4.5)
const SLIDE_FOV := 10.0  # Extra horizontal degrees at 14 m/s.
const SLIDE_RUMBLE := 0.012  # Meters per 10 m/s.
## Smashdown: the view tightens during the hang, then stretches on the way
## down (extra horizontal degrees).
const SMASH_HANG_FOV := 8.0
const SMASH_FOV := 22.0
## Kicks ride one damped spring per channel: (vertical fov degrees, pitch,
## roll, drop in meters). KICK_GAIN turns a wanted peak into a spring
## impulse (for this stiffness and damping the peak is ~1/26 of it).
const KICK_STIFFNESS := 170.0
const KICK_DAMPING := 16.0
const KICK_GAIN := 26.0
## Shake at full trauma and default screen shake.
const SHAKE_POSITION := 0.05
const SHAKE_ROTATION := deg_to_rad(1.2)

@export var movement_params: MovementParams
@export var view_settings: ViewSettings
## Off for bots and tests: they call tick() themselves.
@export var human_controlled: bool = true

var state := MovementState.new()
var sim: MovementSim
var yaw: float = 0.0
var pitch: float = 0.0
var is_dead := false
var third_person := false
## The local player's death cinematic; null for bots, remote players and tests.
var death: DeathSequence

var _command := InputCommand.new()
var _pending_jump := false
var _pending_crouch := false
var _pending_dash := false
var _prev_position := Vector3.ZERO
var _curr_position := Vector3.ZERO
var _spawn := Transform3D.IDENTITY
var _eye_height := 1.6
var _dip := 0.0
var _roll := 0.0
var _shake := 0.0
var _fov := 0.0  # Smoothed FOV, before the punch.
var _punch_time := INF
var _punch_fov := 0.0
var _punch_rot := Vector3.ZERO
var _punch_push := 0.0
var _kick := Vector4.ZERO  # fov, pitch, roll, drop
var _kick_velocity := Vector4.ZERO
var _slide_look := 0.0  # 0..1 blend into the slide camera.
var _slide_side := 1.0
var _smash_look := 0.0  # -1 hang .. 1 descent.
var _shake_time := 0.0
var _smash_marker: MeshInstance3D

@onready var camera: Camera3D = $Camera
@onready var model: PlayerModel = $Model
@onready var _collision: CollisionShape3D = $Collision


func _ready() -> void:
	if movement_params == null:
		movement_params = _load_tuning("res://data/movement_params.tres")
	if view_settings == null:
		view_settings = _load_tuning("res://data/view_settings.tres")
	# Each player resizes its own capsule when crouching.
	var col := $Collision as CollisionShape3D
	col.shape = col.shape.duplicate()

	sim = MovementSim.new(movement_params)
	state.reset(movement_params)
	_spawn = global_transform
	yaw = rotation.y
	rotation = Vector3.ZERO
	_prev_position = global_position
	_curr_position = global_position
	_eye_height = movement_params.stand_eye_height

	camera.top_level = true
	camera.current = human_controlled
	if human_controlled:
		add_to_group(&"local_player")
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		death = DeathSequence.new()
		death.player = self
		add_child(death)
		death.finished.connect(respawn)
	else:
		set_physics_process(false)
	_update_model_visibility()
	model.follow(global_position, yaw)


func _unhandled_input(event: InputEvent) -> void:
	if not human_controlled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var delta: Vector2 = (event as InputEventMouseMotion).screen_relative
		var k := deg_to_rad(DEGREES_PER_COUNT * view_settings.sensitivity)
		yaw = wrapf(yaw - delta.x * k, -PI, PI)
		var dy := -delta.y if view_settings.invert_y else delta.y
		pitch = clampf(pitch - dy * k, -MAX_PITCH, MAX_PITCH)
	elif event.is_action_pressed(&"jump"):
		_pending_jump = true
	elif event.is_action_pressed(&"crouch"):
		_pending_crouch = true
	elif event.is_action_pressed(&"dash"):
		_pending_dash = true
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	tick(_sample_command(), delta)


## Runs one simulation tick with the given command.
func tick(cmd: InputCommand, delta: float) -> void:
	if is_dead:
		return
	_prev_position = global_position
	sim.step(self, state, cmd, delta)
	_curr_position = global_position
	for e in state.events:
		_react(e)
		movement_event.emit(e)
	model.follow(global_position, yaw)
	if global_position.y < KILL_Y:
		die()


## Stops the player and falls apart. The local player gets the full death
## cinematic; everyone else just sees the body crumble.
func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector3.ZERO
	_collision.set_deferred(&"disabled", true)
	model.visible = true
	died.emit()
	if death:
		death.play()
	else:
		var forward := Basis(Vector3.UP, yaw) * Vector3.FORWARD
		model.fall_apart(false, global_position + forward * 3.0)


func respawn() -> void:
	if death:
		death.stop()
	model.reassemble()
	var was_dead := is_dead
	is_dead = false
	_collision.set_deferred(&"disabled", false)
	global_transform = _spawn
	velocity = Vector3.ZERO
	state.reset(movement_params)
	_prev_position = global_position
	_curr_position = global_position
	model.follow(global_position, yaw)
	_update_model_visibility()
	if was_dead:
		respawned.emit()


func set_third_person(on: bool) -> void:
	third_person = on
	_update_model_visibility()


## Your own body is hidden in first person; others always see it.
func _update_model_visibility() -> void:
	model.visible = is_dead or third_person or not human_controlled


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func _sample_command() -> InputCommand:
	var c := _command
	c.clear_presses()
	c.yaw = yaw
	c.pitch = pitch
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# Menus and the tuning panel have the keyboard.
		c.move = Vector2.ZERO
		c.jump_held = false
		c.crouch_held = false
		_pending_jump = false
		_pending_crouch = false
		_pending_dash = false
		return c
	c.move = Input.get_vector(&"move_left", &"move_right", &"move_back", &"move_forward")
	c.jump_pressed = _pending_jump
	c.jump_held = Input.is_action_pressed(&"jump")
	c.crouch_pressed = _pending_crouch
	c.crouch_held = Input.is_action_pressed(&"crouch")
	c.dash_pressed = _pending_dash
	_pending_jump = false
	_pending_crouch = false
	_pending_dash = false
	return c


# --- Camera -----------------------------------------------------------------

func _process(delta: float) -> void:
	if is_dead:
		return  # The death sequence has the camera.
	var p := movement_params
	var v := view_settings
	var f := Engine.get_physics_interpolation_fraction()
	var pos := _prev_position.lerp(_curr_position, f)
	model.follow(pos, yaw)
	model.animate_movement(state, velocity)

	var target_eye := p.crouch_eye_height if state.crouched else p.stand_eye_height
	_eye_height = move_toward(_eye_height, target_eye, EYE_HEIGHT_SPEED * delta)
	_dip = move_toward(_dip, 0.0, DIP_RECOVER * delta)
	var motion := v.camera_motion
	var local := Basis(Vector3.UP, yaw).inverse() * velocity
	var hspeed := horizontal_speed()

	# Roll: lean into sideways motion, into the slide, and off walls.
	var target_roll := clampf(-local.x * LEAN_PER_SPEED, -LEAN_MAX, LEAN_MAX) * motion
	var sliding := state.mode == MovementState.Mode.SLIDE
	if sliding and _slide_look == 0.0:
		_slide_side = -signf(local.x) if absf(local.x) > 0.5 else 1.0
	_slide_look = move_toward(_slide_look, 1.0 if sliding else 0.0, delta * (7.0 if sliding else 3.0))
	target_roll += SLIDE_TILT * _slide_side * _slide_look * motion
	if state.mode == MovementState.Mode.WALLRIDE:
		var right := Basis(Vector3.UP, yaw) * Vector3.RIGHT
		target_roll = -signf(state.wallride_normal.dot(right)) * deg_to_rad(v.wallride_tilt)
	_roll = lerpf(_roll, target_roll, 1.0 - exp(-10.0 * delta))

	# Smashdown hang and descent.
	var smash_target := 0.0
	match state.mode:
		MovementState.Mode.SMASH_WINDUP:
			smash_target = -1.0
		MovementState.Mode.SMASH:
			smash_target = 1.0
			_shake = maxf(_shake, 0.4)  # The descent rattles.
	_smash_look = move_toward(_smash_look, smash_target, delta * 10.0)
	_update_smash_marker()

	_step_kicks(delta)

	# Shake: trauma squared, in position and rotation. Slides rumble.
	_shake = maxf(_shake - delta * 2.2, 0.0)
	_shake_time += delta
	var t := _shake_time
	var noise := Vector3(sin(t * 71.0) + 0.6 * sin(t * 43.0 + 0.7), sin(t * 59.0 + 1.3) + 0.6 * sin(t * 37.0), sin(t * 53.0 + 2.1)) / 1.6
	var trauma := _shake * _shake * clampf(v.screen_shake / 0.3, 0.0, 3.0)
	var shake_offset := Vector3(noise.x, noise.y, 0.0) * SHAKE_POSITION * trauma
	var shake_rot := Vector3(noise.y, noise.x, noise.z) * SHAKE_ROTATION * trauma
	shake_offset.y += sin(t * 97.0) * SLIDE_RUMBLE * hspeed / 10.0 * _slide_look * motion

	# FOV: speed, slides, and the smashdown stretch, plus kicks.
	var speed_t := clampf(inverse_lerp(p.run_speed, p.soft_speed_cap, hspeed), 0.0, 1.0)
	var hfov := v.fov_horizontal + v.speed_fov_kick * speed_t
	hfov += SLIDE_FOV * _slide_look * clampf(inverse_lerp(6.0, 14.0, hspeed), 0.0, 1.0) * motion
	hfov += _smash_look * (SMASH_FOV if _smash_look > 0.0 else SMASH_HANG_FOV) * motion
	if _fov <= 0.0:
		_fov = camera.fov
	_fov = lerpf(_fov, vfov_from_hfov_16_9(hfov), 1.0 - exp(-10.0 * delta))
	_punch_time += delta
	var punch := punch_spring(_punch_time)
	camera.fov = _fov + _kick.x + _punch_fov * punch

	# These only move the view; aim still follows yaw and pitch.
	var basis := Basis.from_euler(Vector3(pitch + _kick.y, yaw, _roll + _kick.z) + _punch_rot * punch + shake_rot)
	var eye := pos + Vector3.UP * (_eye_height - _dip - _kick.w)
	if third_person:
		eye += basis * Vector3(0.0, THIRD_PERSON_HEIGHT, THIRD_PERSON_DISTANCE)
	# Shoved back and a little down by an impact frame's hit.
	var push := Vector3(0.0, -0.4, 1.0) * PUNCH_PUSH * _punch_push * punch
	camera.global_transform = Transform3D(basis, eye + basis * (shake_offset + push))


## Snaps the view into a zoom and twists it, then lets it spring back past
## rest and settle: the camera's half of an impact frame. side (-1..1) is
## where the hit is across the screen; the view rolls toward it. Scales
## with the screen shake setting (the default gives the designed punch; 0
## turns it off).
func punch_camera(strength: float, side := 0.0) -> void:
	var s := strength * clampf(view_settings.screen_shake / 0.3, 0.0, 1.5)
	if s <= 0.0:
		return
	var roll_sign := signf(side) if absf(side) > 0.05 else (1.0 if randf() < 0.5 else -1.0)
	_punch_time = 0.0
	_punch_fov = -PUNCH_FOV * s
	_punch_rot = Vector3(PUNCH_PITCH, -side * PUNCH_YAW, roll_sign * PUNCH_ROLL) * s
	_punch_push = s
	_shake = maxf(_shake, 0.5 + 0.5 * s)


## Damped spring released from full displacement: 1 at the hit, swinging
## through 0 into a recoil, settled by PUNCH_TIME. The HUD rides the same
## curve so it moves with the camera.
static func punch_spring(t: float) -> float:
	if t >= PUNCH_TIME:
		return 0.0
	var ringing := PUNCH_FREQUENCY * sqrt(1.0 - PUNCH_DAMPING * PUNCH_DAMPING)
	return exp(-PUNCH_DAMPING * PUNCH_FREQUENCY * t) * cos(ringing * t)


func _react(e: Dictionary) -> void:
	var local := func(dir: Vector3) -> Vector3: return Basis(Vector3.UP, yaw).inverse() * dir
	match e.type:
		&"jump":
			_kick_camera(0.0, 1.0, 0.0, 0.04)
		&"land":
			if view_settings.landing_dip:
				_dip = minf(_dip + e.impact_speed * DIP_PER_IMPACT, DIP_MAX)
			_kick_camera(0.0, -minf(e.impact_speed * 0.15, 3.0), 0.0, 0.0)
			if e.impact_speed > 12.0:
				_shake = maxf(_shake, (e.impact_speed - 12.0) / 20.0)
		&"slide_start":
			_kick_camera(3.0, -1.2, 0.0, 0.05)
		&"dash":
			_kick_camera(6.0, 0.0, -local.call(e.direction).x * 2.5, 0.0)
		&"wall_jump":
			_kick_camera(3.0, 1.5, -local.call(e.normal).x * 3.0, 0.0)
		&"wallride_start":
			_kick_camera(0.0, 0.0, 0.0, 0.03)
		&"mantle":
			_kick_camera(0.0, -2.5, 0.0, 0.08)
		&"smash_start":
			_kick_camera(-3.0, 2.0, 0.0, -0.04)
		&"smash_impact":
			# The heavy one: the view slams down, pitches in, twists, snaps in.
			var s := clampf(0.5 + e.drop / 10.0, 0.5, 1.4)
			_kick_camera(-10.0 * s, -6.0 * s, (3.5 if randf() < 0.5 else -3.5) * s, 0.38 * s)
			_shake = clampf(0.55 + e.drop * 0.05, 0.0, 1.0)
			if view_settings.landing_dip:
				_dip = DIP_MAX
			SmashFx.shockwave(get_parent(), e.position, e.drop / 10.0)
		&"slam_bounce":
			# Launch: the view whooshes wide and tips up as you're fired off.
			_kick_camera(12.0, 5.0, 0.0, -0.12)
			_shake = maxf(_shake, 0.35)
			SmashFx.launch(get_parent(), global_position)


## Adds a kick to the camera spring: wanted peaks in vertical fov degrees,
## pitch and roll degrees, and drop meters (positive drops the view).
## Scales with camera motion.
func _kick_camera(fov: float, pitch_deg: float, roll_deg: float, drop: float) -> void:
	var peak := Vector4(fov, deg_to_rad(pitch_deg), deg_to_rad(roll_deg), drop)
	_kick_velocity += peak * KICK_GAIN * view_settings.camera_motion


func _step_kicks(delta: float) -> void:
	var steps := maxi(1, ceili(delta * 240.0))
	var h := delta / steps
	for i in steps:
		_kick_velocity += (-_kick * KICK_STIFFNESS - _kick_velocity * KICK_DAMPING) * h
		_kick += _kick_velocity * h


## During a smashdown, a ring on the ground where you'll land, tightening as
## you get close (GDD §4.4 tells).
func _update_smash_marker() -> void:
	var smashing := state.mode == MovementState.Mode.SMASH_WINDUP or state.mode == MovementState.Mode.SMASH
	if not smashing:
		if _smash_marker:
			_smash_marker.visible = false
		return
	var from := global_position + Vector3.UP * 0.5
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 80.0, collision_mask, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	if _smash_marker == null:
		_smash_marker = SmashFx.make_marker()
		add_child(_smash_marker)
	var height := global_position.y - (hit.position as Vector3).y
	var radius := lerpf(0.7, 2.4, clampf(height / 10.0, 0.0, 1.0))
	_smash_marker.visible = true
	_smash_marker.global_position = (hit.position as Vector3) + Vector3.UP * 0.05
	_smash_marker.scale = Vector3(radius, 1.0, radius)


## Exported builds can't write to res://, so the tuning panel saves to
## user:// there. Prefer that copy when it exists.
static func _load_tuning(path: String) -> Resource:
	var saved := "user://" + path.get_file()
	if not OS.has_feature("editor") and ResourceLoader.exists(saved):
		return load(saved)
	return load(path)


static func vfov_from_hfov_16_9(hfov_deg: float) -> float:
	var half := deg_to_rad(hfov_deg) * 0.5
	return rad_to_deg(2.0 * atan(tan(half) * 9.0 / 16.0))
