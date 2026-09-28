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
	elif event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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

	var target_roll := 0.0
	if state.mode == MovementState.Mode.WALLRIDE:
		var right := Basis(Vector3.UP, yaw) * Vector3.RIGHT
		target_roll = -signf(state.wallride_normal.dot(right)) * deg_to_rad(v.wallride_tilt)
	_roll = lerpf(_roll, target_roll, 1.0 - exp(-12.0 * delta))

	var shake_offset := Vector3.ZERO
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 4.0, 0.0)
		var amount := _shake * _shake * 0.15 * v.screen_shake
		shake_offset = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * amount

	var speed_t := inverse_lerp(p.run_speed, p.soft_speed_cap, horizontal_speed())
	var hfov := v.fov_horizontal + v.speed_fov_kick * clampf(speed_t, 0.0, 1.0)
	camera.fov = lerpf(camera.fov, vfov_from_hfov_16_9(hfov), 1.0 - exp(-8.0 * delta))

	var basis := Basis.from_euler(Vector3(pitch, yaw, _roll))
	var eye := pos + Vector3.UP * (_eye_height - _dip)
	if third_person:
		eye += basis * Vector3(0.0, THIRD_PERSON_HEIGHT, THIRD_PERSON_DISTANCE)
	camera.global_transform = Transform3D(basis, eye + basis * shake_offset)


func _react(e: Dictionary) -> void:
	match e.type:
		&"land":
			if view_settings.landing_dip:
				_dip = minf(_dip + e.impact_speed * DIP_PER_IMPACT, DIP_MAX)
		&"smash_impact":
			_shake = clampf(0.4 + e.drop * 0.06, 0.0, 1.0)
			if view_settings.landing_dip:
				_dip = DIP_MAX


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
