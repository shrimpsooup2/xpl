class_name Player
extends CharacterBody3D
## The local player: samples input, runs the movement sim and its hands
## (WeaponHolder) at the fixed tick, and drives a camera that is
## interpolated between ticks, with the first-person arms (Viewmodel) on it.
##
## Mouse look is applied on every input event, not on the tick, so aiming
## never waits for physics (GDD §10.3).

signal movement_event(event: Dictionary)
signal died
signal respawned
## Health went up or down (hits, healing, respawning).
signal health_changed(health: float)
## It died: {attacker: Player or null, weapon: WeaponDef or null, heartshot}.
## A fall counts as the last hit's if that was recent (KNOCKED_OFF_TIME).
signal killed(info: Dictionary)

const DEGREES_PER_COUNT := 0.022
const MAX_PITCH := 1.5533430342749532  # 89 degrees
const EYE_HEIGHT_SPEED := 6.0  # m/s the camera moves when crouching
const DIP_PER_IMPACT := 0.006  # meters of landing dip per m/s of fall speed
const DIP_MAX := 0.12
const DIP_RECOVER := 1.2  # m/s
## Falling below this height kills you.
const KILL_Y := -40.0
## Debug third-person camera (F6): distance behind and height above the eyes.
## The camera is swept out from inside the capsule to where the view wants
## it as a ball this big (it covers the near plane at the widest FOV), and
## stops short of the world; it comes back out this fast once clear.
const CAMERA_PROBE := 0.15
const CAMERA_RECOVER := 4.0
const THIRD_PERSON_DISTANCE := 3.4
const THIRD_PERSON_HEIGHT := 0.5
## Camera punch (punch_camera()), at strength 1 and default screen shake:
## zoom-in (degrees of vertical FOV), roll and pitch kick, a shove back
## (meters), then a damped spring back. Snappy (camera smoothing 0): held
## through the impact frame's beats, then a fast snap back with a small
## recoil. Smooth (1): no hold, a slow swing out past rest.
const PUNCH_FOV := 14.0
const PUNCH_ROLL := deg_to_rad(5.0)
const PUNCH_PITCH := deg_to_rad(2.0)
const PUNCH_YAW := deg_to_rad(1.0)
const PUNCH_PUSH := 0.12
const PUNCH_HOLD := 0.08
const PUNCH_FREQUENCY := Vector2(26.0, 12.0)  # rad/s: (snappy, smooth).
const PUNCH_DAMPING := Vector2(0.55, 0.45)
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
## Kicks ride one spring per channel: (vertical fov degrees, pitch, roll,
## drop in meters). Snappy: a kick lands in full on the frame it happens and
## falls straight off (critically damped, gone in ~0.2 s). Smooth: it swells
## in from an impulse and settles with a little overshoot (~0.4 s); KICK_GAIN
## turns a wanted peak into that impulse. (snappy, smooth) pairs.
const KICK_STIFFNESS := Vector2(576.0, 170.0)
const KICK_DAMPING := Vector2(48.0, 16.0)
const KICK_GAIN := 26.0
## A smashdown impact holds its kick this long before letting go (snappy).
const IMPACT_HOLD := 0.05
## Shake at full trauma and default screen shake. Snappy shake is random
## jitter stepped at SHAKE_RATE; smooth shake is a sine wobble.
const SHAKE_POSITION := 0.05
const SHAKE_ROTATION := deg_to_rad(1.2)
const SHAKE_RATE := 30.0

## Players are hit by shots through their HitShapes, not their capsule, so
## they have a layer of their own: shots trace the world layer only.
const PLAYER_LAYER := 1 << 3
const MAX_HEALTH := 100.0
## A fall this soon after being hit is a kill for whoever hit you.
const KNOCKED_OFF_TIME := 5.0

@export var movement_params: MovementParams
@export var view_settings: ViewSettings
## Off for bots and tests: they call tick() themselves.
@export var human_controlled: bool = true
## Its side (GDD §11.4). The local player wears the hat and goes by the name
## picked on the title screen (Cosmetics); anyone else wears `hat`.
@export var team := Hats.Team.RED
@export var hat := Cosmetics.DEFAULT_HAT
## Its name, over its head (to everyone else) and in the killfeed.
@export var player_name := Cosmetics.DEFAULT_NAME
## The colour of its hat or marker (free-for-all: the colour it picked);
## left clear, it wears its team's.
@export var tint := Color(0, 0, 0, 0)

var state := MovementState.new()
var sim: MovementSim
var yaw: float = 0.0
var pitch: float = 0.0
var is_dead := false
var third_person := false
var health := MAX_HEALTH
var max_health := MAX_HEALTH
## Seconds untouched before health comes back, and how fast (0: never; set
## by the game's rules).
var regen_delay := 0.0
var regen_rate := 25.0
## Respawns itself when the death sequence ends (the sandbox). In a game the
## match decides when (see Match).
var auto_respawn := true
var _since_hit := INF
var _last_hit := {}
## The local player's death cinematic; null for bots, remote players and tests.
var death: DeathSequence
var weapons: WeaponHolder
## First-person arms and gun; null for bots, remote players and tests.
var viewmodel: Viewmodel

var _command := InputCommand.new()
var _pending_jump := false
var _pending_crouch := false
var _pending_dash := false
var _pending_fire := false
var _pending_alt := false
var _pending_interact := false
var _pending_throw := false
var _pending_switch := 0
var _zoom := 1.0
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
var _kick_hold := 0.0
var _jitter := Vector3.ZERO
var _jitter_timer := 0.0
var _slide_look := 0.0  # 0..1 blend into the slide camera.
var _slide_side := 1.0
var _smash_look := 0.0  # -1 hang .. 1 descent.
var _shake_time := 0.0
var _smash_marker: MeshInstance3D
var _camera_reach := 1.0
var _probe := SphereShape3D.new()

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
	collision_layer = PLAYER_LAYER
	collision_mask = 1 | TargetDummy.BODY_LAYER
	add_to_group(Ballistics.GROUP)
	weapons = WeaponHolder.new()
	weapons.name = "Weapons"
	weapons.player = self
	add_child(weapons)
	weapons.equipped.connect(func(def: WeaponDef, _ammo: int) -> void: model.hold(def))
	weapons.fired.connect(_on_fired)
	weapons.thrown.connect(func(_def: WeaponDef) -> void: model.throw_pose())
	if human_controlled:
		viewmodel = Viewmodel.new()
		viewmodel.name = "Viewmodel"
		viewmodel.player = self
		viewmodel.holder = weapons
		add_child(viewmodel)
		add_to_group(&"local_player")
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		death = DeathSequence.new()
		death.player = self
		add_child(death)
		death.finished.connect(func() -> void:
			if auto_respawn:
				respawn())
	else:
		set_physics_process(false)
	if human_controlled:
		Cosmetics.load_saved()
		hat = Cosmetics.hat
		player_name = Cosmetics.player_name
	refresh_look()
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
	elif event.is_action_pressed(&"fire"):
		_pending_fire = true
	elif event.is_action_pressed(&"alt_fire"):
		_pending_alt = true
	elif event.is_action_pressed(&"interact"):
		_pending_interact = true
	elif event.is_action_pressed(&"throw_weapon"):
		_pending_throw = true
	elif event.is_action_pressed(&"weapon_primary"):
		_pending_switch = 3 if event is InputEventMouseButton else 1
	elif event.is_action_pressed(&"weapon_fists"):
		_pending_switch = 2
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	tick(_sample_command(), delta)


## Runs one simulation tick with the given command.
func tick(cmd: InputCommand, delta: float) -> void:
	if is_dead:
		return
	_since_hit += delta
	if regen_delay > 0.0 and _since_hit > regen_delay and health < max_health:
		heal(regen_rate * delta)
	_prev_position = global_position
	sim.step(self, state, cmd, delta)
	_curr_position = global_position
	for e in state.events:
		_react(e)
		movement_event.emit(e)
	weapons.tick(cmd, delta)
	model.follow(global_position, yaw)
	if global_position.y < KILL_Y:
		die()


## The first body part the segment hits, or {} (Ballistics).
func ray_test(from: Vector3, to: Vector3) -> Dictionary:
	if is_dead:
		return {}
	return model.ray_test(from, to)


## Takes a hit (see Ballistics._land for the fields): loses health, reacts
## where it was hit, and dies at zero, or at once through the heart. A hit
## the game says can't land (a teammate's, see Game.can_damage) does
## nothing. Returns what it did, for the shooter's feedback.
func take_hit(hit: Dictionary) -> Dictionary:
	if is_dead:
		return {}
	var attacker: Player = hit.get("attacker")
	if attacker == self:
		return {}
	if attacker and not Game.can_damage(attacker, self):
		return {}
	var amount: float = hit.damage
	var lethal: bool = hit.get("heartshot", false)
	if lethal:
		amount = maxf(amount, health)
	health = maxf(health - amount, 0.0)
	_since_hit = 0.0
	_last_hit = {"attacker": attacker, "weapon": hit.get("weapon"), "heartshot": lethal, "time": Time.get_ticks_msec()}
	health_changed.emit(health)
	DamageNumber.add(get_parent(), self, hit.point, amount, &"heart" if lethal else hit.zone)
	var killed_now := health <= 0.0
	if killed_now:
		die()
	else:
		model.react_to_hit(hit.part, hit.point, hit.direction, amount / 40.0 + (hit.get("knockback", 0.0) as float) * 0.05)
	return {
		"target": self,
		"name": player_name,
		"damage": amount,
		"zone": &"heart" if lethal else hit.zone,
		"part": hit.part,
		"heartshot": lethal,
		"killed": killed_now,
		"weapon": hit.get("weapon"),
	}


## Gains `amount` health, up to its maximum.
func heal(amount: float) -> void:
	var before := health
	health = minf(health + amount, max_health)
	if health != before:
		health_changed.emit(health)


## Stops the player and falls apart. The local player gets the full death
## cinematic; everyone else just sees the body crumble. Whoever hit it last
## gets the kill if that was recent (a fall after a hit counts).
func die() -> void:
	if is_dead:
		return
	var info := {"attacker": null, "weapon": null, "heartshot": false}
	if not _last_hit.is_empty() and Time.get_ticks_msec() - int(_last_hit.time) <= KNOCKED_OFF_TIME * 1000.0:
		info = {"attacker": _last_hit.attacker, "weapon": _last_hit.weapon, "heartshot": _last_hit.heartshot and health <= 0.0}
	if info.attacker != null and not is_instance_valid(info.attacker):
		info.attacker = null
	health = 0.0
	is_dead = true
	velocity = Vector3.ZERO
	weapons.drop_on_death()
	_collision.set_deferred(&"disabled", true)
	model.visible = true
	if viewmodel:
		viewmodel.visible = false
	killed.emit(info)
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
	weapons.reset()
	health = max_health
	_since_hit = INF
	_last_hit = {}
	health_changed.emit(health)
	_prev_position = global_position
	_curr_position = global_position
	model.follow(global_position, yaw)
	_update_model_visibility()
	if was_dead:
		respawned.emit()


## Brings it back (alive, full health, empty-handed) at `at`, facing the way
## `at` faces. It keeps coming back there until told otherwise.
func spawn_at(at: Transform3D) -> void:
	_spawn = Transform3D(Basis.IDENTITY, at.origin)
	yaw = at.basis.get_euler().y
	pitch = 0.0
	respawn()


## The colour it wears: its own pick, or its team's.
func look_color() -> Color:
	return tint if tint.a > 0.0 else Hats.team_color(team)


## Dresses it again after its hat, team or colour changed, and floats its
## name over its head for everyone but itself (a teammate's `through_walls`).
func refresh_look(through_walls := false) -> void:
	model.dress(hat, look_color())
	model.set_nametag("" if human_controlled else player_name, look_color(), through_walls)


func set_third_person(on: bool) -> void:
	third_person = on
	_update_model_visibility()


## Your own body is hidden in first person; others always see it.
func _update_model_visibility() -> void:
	model.visible = is_dead or third_person or not human_controlled
	if viewmodel:
		viewmodel.visible = not model.visible


## Where shots appear to leave the gun: the viewmodel's muzzle in first
## person, the held gun's otherwise.
func muzzle_position() -> Vector3:
	if viewmodel and viewmodel.visible:
		return viewmodel.muzzle_point(camera)
	if model.held:
		return model.held.muzzle.global_position
	return weapons.eye_position()


## How far the camera is zoomed in (1 = not at all).
func zoom_amount() -> float:
	return _zoom


## 0..1: how far into the slide look the camera is.
func slide_look() -> float:
	return _slide_look


func _on_fired(def: WeaponDef, shot: Dictionary) -> void:
	if def.is_fists():
		model.punch(shot.get("left", true), shot.get("kind", &"straight"))
		_kick_camera(1.0, 0.0, 1.5 if shot.get("left", true) else -1.5, 0.0)
		return
	model.fire_pose()
	# The view kicks with the shot; aim stays put (GDD §5.4, no recoil).
	_kick_camera(def.view_kick.x, def.view_kick.y, randf_range(-0.3, 0.3) * def.view_kick.y, 0.0)


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
		_clear_combat_presses()
		c.fire_held = false
		c.alt_held = false
		return c
	c.move = Input.get_vector(&"move_left", &"move_right", &"move_back", &"move_forward")
	c.jump_pressed = _pending_jump
	c.jump_held = Input.is_action_pressed(&"jump")
	c.crouch_pressed = _pending_crouch
	c.crouch_held = Input.is_action_pressed(&"crouch")
	c.dash_pressed = _pending_dash
	c.fire_pressed = _pending_fire
	c.fire_held = Input.is_action_pressed(&"fire")
	c.alt_pressed = _pending_alt
	c.alt_held = Input.is_action_pressed(&"alt_fire")
	c.interact_pressed = _pending_interact
	c.throw_pressed = _pending_throw
	c.switch_to = _pending_switch
	_pending_jump = false
	_pending_crouch = false
	_pending_dash = false
	_clear_combat_presses()
	return c


func _clear_combat_presses() -> void:
	_pending_fire = false
	_pending_alt = false
	_pending_interact = false
	_pending_throw = false
	_pending_switch = 0


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
	model.aim(pitch, weapons.current.is_fists())

	var smooth := v.camera_smoothing
	var target_eye := p.crouch_eye_height if state.crouched else p.stand_eye_height
	_eye_height = move_toward(_eye_height, target_eye, lerpf(10.0, EYE_HEIGHT_SPEED, smooth) * delta)
	_dip = move_toward(_dip, 0.0, DIP_RECOVER * delta)
	var motion := v.camera_motion
	var local := Basis(Vector3.UP, yaw).inverse() * velocity
	var hspeed := horizontal_speed()

	# Roll: lean into sideways motion, into the slide, and off walls.
	var target_roll := clampf(-local.x * LEAN_PER_SPEED, -LEAN_MAX, LEAN_MAX) * motion
	var sliding := state.mode == MovementState.Mode.SLIDE
	if sliding and _slide_look == 0.0:
		_slide_side = -signf(local.x) if absf(local.x) > 0.5 else 1.0
	var slide_rate := lerpf(30.0, 7.0, smooth) if sliding else lerpf(14.0, 3.0, smooth)
	_slide_look = move_toward(_slide_look, 1.0 if sliding else 0.0, delta * slide_rate)
	target_roll += SLIDE_TILT * _slide_side * _slide_look * motion
	if state.mode == MovementState.Mode.WALLRIDE:
		var right := Basis(Vector3.UP, yaw) * Vector3.RIGHT
		target_roll = -signf(state.wallride_normal.dot(right)) * deg_to_rad(v.wallride_tilt)
	_roll = lerpf(_roll, target_roll, 1.0 - exp(-lerpf(22.0, 10.0, smooth) * delta))

	# Smashdown hang and descent.
	var smash_target := 0.0
	match state.mode:
		MovementState.Mode.SMASH_WINDUP:
			smash_target = -1.0
		MovementState.Mode.SMASH:
			smash_target = 1.0
			_shake = maxf(_shake, 0.4)  # The descent rattles.
	_smash_look = move_toward(_smash_look, smash_target, delta * lerpf(30.0, 10.0, smooth))
	_update_smash_marker()

	_step_kicks(delta, smooth)

	# Shake: trauma squared, in position and rotation. Slides rumble.
	_shake = maxf(_shake - delta * lerpf(4.0, 2.2, smooth), 0.0)
	_shake_time += delta
	_jitter_timer -= delta
	if _jitter_timer <= 0.0:
		_jitter_timer = 1.0 / SHAKE_RATE
		_jitter = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
	var t := _shake_time
	var wobble := Vector3(sin(t * 71.0) + 0.6 * sin(t * 43.0 + 0.7), sin(t * 59.0 + 1.3) + 0.6 * sin(t * 37.0), sin(t * 53.0 + 2.1)) / 1.6
	var noise := _jitter.lerp(wobble, smooth)
	var trauma := _shake * _shake * clampf(v.screen_shake / 0.3, 0.0, 3.0)
	var shake_offset := Vector3(noise.x, noise.y, 0.0) * SHAKE_POSITION * trauma
	var shake_rot := Vector3(noise.y, noise.x, noise.z) * SHAKE_ROTATION * trauma
	shake_offset.y += noise.z * SLIDE_RUMBLE * hspeed / 10.0 * _slide_look * motion

	# FOV: speed eases (speed itself changes gradually); slides and the
	# smashdown come in as fast as their looks do; kicks on top.
	var speed_t := clampf(inverse_lerp(p.run_speed, p.soft_speed_cap, hspeed), 0.0, 1.0)
	if _fov <= 0.0:
		_fov = camera.fov
	var base_h := v.fov_horizontal + v.speed_fov_kick * speed_t
	_fov = lerpf(_fov, vfov_from_hfov_16_9(base_h), 1.0 - exp(-6.0 * delta))
	var extra_h := SLIDE_FOV * _slide_look * clampf(inverse_lerp(6.0, 14.0, hspeed), 0.0, 1.0) * motion
	extra_h += _smash_look * (SMASH_FOV if _smash_look > 0.0 else SMASH_HANG_FOV) * motion
	var extra := vfov_from_hfov_16_9(base_h + extra_h) - vfov_from_hfov_16_9(base_h)
	_punch_time += delta
	var punch := punch_spring(_punch_time, smooth)
	# A scoped weapon's alt-fire zooms (GDD §5.4).
	_zoom = lerpf(_zoom, weapons.zoom, 1.0 - exp(-lerpf(30.0, 14.0, smooth) * delta))
	var fov := _fov + extra + _kick.x + _punch_fov * punch
	camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(fov) * 0.5) / _zoom))

	# These only move the view; aim still follows yaw and pitch.
	var basis := Basis.from_euler(Vector3(pitch + _kick.y, yaw, _roll + _kick.z) + _punch_rot * punch + shake_rot)
	var eye := pos + Vector3.UP * (_eye_height - _dip - _kick.w)
	# Sweep out from a point surely inside the capsule (below its top, which
	# drops at once when crouching while the eye takes a moment).
	var capsule_top := movement_params.crouch_height if state.crouched else movement_params.stand_height
	var anchor := pos + Vector3.UP * clampf(eye.y - pos.y, CAMERA_PROBE + 0.05, capsule_top - CAMERA_PROBE - 0.05)
	if third_person:
		eye += basis * Vector3(0.0, THIRD_PERSON_HEIGHT, THIRD_PERSON_DISTANCE)
	# Shoved back and a little down by an impact frame's hit.
	var push := Vector3(0.0, -0.4, 1.0) * PUNCH_PUSH * _punch_push * punch
	var want := eye + basis * (shake_offset + push)
	# Bumps against walls and ceilings instead of going through: pulled in
	# at once, easing back out.
	var reach := reach_toward(anchor, want)
	_camera_reach = reach if reach < _camera_reach else move_toward(_camera_reach, reach, CAMERA_RECOVER * delta)
	camera.global_transform = Transform3D(basis, anchor.lerp(want, _camera_reach))
	if viewmodel and viewmodel.visible:
		viewmodel.follow(camera, delta)


## How far (0..1) a camera can move from `from` toward `to` before it would
## touch the world (see CAMERA_PROBE). 1 when the way is clear.
func reach_toward(from: Vector3, to: Vector3) -> float:
	if from.is_equal_approx(to) or not is_inside_tree():
		return 1.0
	_probe.radius = CAMERA_PROBE
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _probe
	q.transform = Transform3D(Basis.IDENTITY, from)
	q.motion = to - from
	q.collision_mask = 1
	q.exclude = [get_rid()]
	var r := get_world_3d().direct_space_state.cast_motion(q)
	return r[0] if r.size() == 2 else 1.0


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


## The punch's curve: 1 at the hit (held for PUNCH_HOLD when snappy), then
## a damped spring swinging through 0 into a recoil, settled by PUNCH_TIME.
## The HUD rides the same curve so it moves with the camera.
static func punch_spring(t: float, smoothing := 0.0) -> float:
	var hold := PUNCH_HOLD * (1.0 - smoothing)
	if t < hold:
		return 1.0
	t -= hold
	if t >= PUNCH_TIME:
		return 0.0
	var frequency := lerpf(PUNCH_FREQUENCY.x, PUNCH_FREQUENCY.y, smoothing)
	var damping := lerpf(PUNCH_DAMPING.x, PUNCH_DAMPING.y, smoothing)
	var ringing := frequency * sqrt(1.0 - damping * damping)
	return exp(-damping * frequency * t) * cos(ringing * t)


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
			_kick_hold = IMPACT_HOLD * (1.0 - view_settings.camera_smoothing)
			_shake = clampf(0.55 + e.drop * 0.05, 0.0, 1.0)
			if view_settings.landing_dip:
				_dip = DIP_MAX
			SmashFx.shockwave(get_parent(), e.position, e.drop / 10.0)
		&"slam_bounce":
			# Launch: the view whooshes wide and tips up as you're fired off.
			_kick_camera(12.0, 5.0, 0.0, -0.12)
			_shake = maxf(_shake, 0.35)
			SmashFx.launch(get_parent(), global_position)


## Adds a kick to the camera: wanted peaks in vertical fov degrees, pitch
## and roll degrees, and drop meters (positive drops the view). Snappy kicks
## land as displacement right away; smooth ones as an impulse that swells.
## Scales with camera motion.
func _kick_camera(fov: float, pitch_deg: float, roll_deg: float, drop: float) -> void:
	var peak := Vector4(fov, deg_to_rad(pitch_deg), deg_to_rad(roll_deg), drop) * view_settings.camera_motion
	var smooth := view_settings.camera_smoothing
	_kick += peak * (1.0 - smooth)
	_kick_velocity += peak * smooth * KICK_GAIN


func _step_kicks(delta: float, smooth: float) -> void:
	if _kick_hold > 0.0:
		_kick_hold -= delta
		return
	var stiffness := lerpf(KICK_STIFFNESS.x, KICK_STIFFNESS.y, smooth)
	var damping := lerpf(KICK_DAMPING.x, KICK_DAMPING.y, smooth)
	var steps := maxi(1, ceili(delta * 240.0))
	var h := delta / steps
	for i in steps:
		_kick_velocity += (-_kick * stiffness - _kick_velocity * damping) * h
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
