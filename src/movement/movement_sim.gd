class_name MovementSim
extends RefCounted
## Fixed-tick movement simulation (GDD §4).
##
## Works on a CharacterBody3D with its feet at the origin and a child named
## "Collision" holding a CapsuleShape3D. Everything besides position and
## velocity lives in MovementState, so a tick is a function of
## (body transform, velocity, state, command, dt) and can be replayed.

const Mode := MovementState.Mode

## A surface counts as a wall when its normal is within this of horizontal.
const WALL_MAX_NORMAL_Y := 0.3
## Wall rides end when speed along the wall drops below this fraction of the
## minimum attach speed.
const WALLRIDE_KEEP_FRACTION := 0.6
## Small inward velocity that keeps the capsule touching the wall while riding.
const WALLRIDE_STICK := 1.0
## Share of the mantle spent rising before moving over the ledge.
const MANTLE_RISE_FRACTION := 0.6
const MANTLE_COOLDOWN := 0.2
## Timers compare against this instead of zero so float error can't add a tick.
const TIMER_EPSILON := 0.0001

var p: MovementParams

## Gravity to apply this tick, split half before and half after the move so
## jump arcs are exact at any tick rate.
var _gravity_now: float = 0.0
var _stand_shape := CapsuleShape3D.new()
var _crouch_shape := CapsuleShape3D.new()


func _init(params: MovementParams) -> void:
	p = params


# --- Public -----------------------------------------------------------------

func configure_body(body: CharacterBody3D) -> void:
	body.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	body.up_direction = Vector3.UP
	body.floor_max_angle = deg_to_rad(p.max_floor_angle_deg)
	body.floor_snap_length = p.step_height + 0.05
	body.floor_stop_on_slope = true
	body.floor_constant_speed = false
	body.floor_block_on_wall = true
	body.max_slides = 6


func step(body: CharacterBody3D, st: MovementState, cmd: InputCommand, dt: float) -> void:
	st.events.clear()
	configure_body(body)
	_tick_timers(st, cmd, dt)

	if st.mode == Mode.DASH and st.dash_timer <= TIMER_EPSILON:
		_end_dash(body, st)

	if st.mode == Mode.MANTLE:
		_tick_mantle(body, st, dt)
		return

	var wish := wish_vector(cmd)
	_try_actions(body, st, cmd, wish)
	if st.mode == Mode.MANTLE:
		_tick_mantle(body, st, dt)
		return

	_gravity_now = 0.0
	match st.mode:
		Mode.GROUND, Mode.SLIDE:
			_tick_ground(body, st, cmd, wish, dt)
		Mode.AIR:
			_tick_air(body, wish, dt)
		Mode.DASH:
			_tick_dash(body, st)
		Mode.WALLRIDE:
			_tick_wallride(body, st, wish, dt)
		Mode.SMASH_WINDUP, Mode.SMASH:
			_tick_smash(body, st, dt)

	_apply_soft_cap(body, st, dt)
	_move(body, st, dt)
	_post_move(body, st, cmd)
	_update_capsule(body, st, cmd)


## Horizontal wish direction in world space, length 0..1.
static func wish_vector(cmd: InputCommand) -> Vector3:
	var local := Vector3(cmd.move.x, 0.0, -cmd.move.y).limit_length(1.0)
	return Basis(Vector3.UP, cmd.yaw) * local


static func forward_from_yaw(yaw: float) -> Vector3:
	return Basis(Vector3.UP, yaw) * Vector3.FORWARD


static func horizontal(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func can_stand(body: CharacterBody3D) -> bool:
	return _shape_fits(body, body.global_position, false)


# --- Timers and actions -----------------------------------------------------

func _tick_timers(st: MovementState, cmd: InputCommand, dt: float) -> void:
	st.jump_buffer_timer = p.jump_buffer if cmd.jump_pressed else maxf(st.jump_buffer_timer - dt, 0.0)
	st.dash_buffer_timer = p.input_buffer if cmd.dash_pressed else maxf(st.dash_buffer_timer - dt, 0.0)
	st.crouch_buffer_timer = p.input_buffer if cmd.crouch_pressed else maxf(st.crouch_buffer_timer - dt, 0.0)
	st.coyote_timer = maxf(st.coyote_timer - dt, 0.0)
	st.landing_grace_timer = maxf(st.landing_grace_timer - dt, 0.0)
	st.slide_boost_cooldown = maxf(st.slide_boost_cooldown - dt, 0.0)
	st.wall_coyote_timer = maxf(st.wall_coyote_timer - dt, 0.0)
	st.bounce_window_timer = maxf(st.bounce_window_timer - dt, 0.0)
	st.mantle_cooldown = maxf(st.mantle_cooldown - dt, 0.0)
	st.dash_timer -= dt

	if st.dash_charges < p.dash_charges:
		st.dash_recharge_timer += dt
		if st.dash_recharge_timer >= p.dash_recharge:
			st.dash_recharge_timer -= p.dash_recharge
			st.dash_charges += 1
	else:
		st.dash_charges = p.dash_charges
		st.dash_recharge_timer = 0.0


func _try_actions(body: CharacterBody3D, st: MovementState, cmd: InputCommand, wish: Vector3) -> void:
	var smashing := st.mode == Mode.SMASH_WINDUP or st.mode == Mode.SMASH

	if not smashing and st.mantle_cooldown <= 0.0 and wish.length_squared() > 0.01:
		if _try_start_mantle(body, st, wish):
			return

	if st.jump_buffer_timer > 0.0 and not smashing:
		if st.on_ground or st.coyote_timer > 0.0:
			_ground_jump(body, st, wish)
		elif (st.mode == Mode.WALLRIDE or st.wall_coyote_timer > 0.0) and st.wall_jumps_left > 0:
			_wall_jump(body, st)

	if st.dash_buffer_timer > 0.0 and st.dash_charges > 0 and not smashing and st.mode != Mode.DASH:
		_start_dash(body, st, cmd, wish)

	if st.crouch_buffer_timer > 0.0 and not st.on_ground \
			and (st.mode == Mode.AIR or st.mode == Mode.WALLRIDE or st.mode == Mode.DASH):
		if _has_clearance_below(body, p.smash_min_clearance):
			_start_smash(body, st)
		elif st.mode == Mode.WALLRIDE:
			st.mode = Mode.AIR  # Too low to slam: crouch just drops off the wall.


func _ground_jump(body: CharacterBody3D, st: MovementState, wish := Vector3.ZERO) -> void:
	var v := body.velocity
	if st.bounce_window_timer > 0.0:
		v.y = minf(p.smash_bounce_base + p.smash_bounce_per_meter * st.last_drop_height, p.smash_bounce_max)
		# The bounce also kicks you on, toward your input.
		var h := horizontal(v)
		var dir := horizontal(wish).normalized() if wish.length_squared() > 0.01 else h.normalized()
		v += dir * p.smash_bounce_boost
		_event(st, &"slam_bounce", {"velocity": v.y})
	else:
		v.y = maxf(v.y, 0.0) + p.jump_velocity
		_event(st, &"jump")
	if st.mode == Mode.DASH:
		# Dash-jump: keep the dash's exit speed instead of its burst speed.
		var h := st.dash_dir * st.dash_exit_speed
		v.x = h.x
		v.z = h.z
	body.velocity = v
	st.mode = Mode.AIR
	st.on_ground = false
	st.coyote_timer = 0.0
	st.jump_buffer_timer = 0.0
	st.bounce_window_timer = 0.0


func _wall_jump(body: CharacterBody3D, st: MovementState) -> void:
	var n := st.wallride_normal if st.mode == Mode.WALLRIDE else st.wall_normal
	var h := horizontal(body.velocity)
	var along := h - n * h.dot(n)
	var v := along + n * p.wall_jump_out
	v.y = p.wall_jump_up
	body.velocity = v
	st.wall_jumps_left -= 1
	st.used_wall_normal = n
	st.mode = Mode.AIR
	st.wall_coyote_timer = 0.0
	st.jump_buffer_timer = 0.0
	_event(st, &"wall_jump", {"normal": n})


# --- Ground and slide -------------------------------------------------------

func _tick_ground(body: CharacterBody3D, st: MovementState, cmd: InputCommand, wish: Vector3, dt: float) -> void:
	var hspeed := horizontal(body.velocity).length()

	if st.mode == Mode.GROUND and st.crouch_buffer_timer > 0.0 and hspeed >= p.slide_min_speed:
		_start_slide(body, st)

	if st.mode == Mode.SLIDE:
		if not cmd.crouch_held and can_stand(body):
			st.mode = Mode.GROUND
			_event(st, &"slide_end")
		else:
			_tick_slide(body, st, wish, dt)
			return

	st.crouched = cmd.crouch_held or (st.crouched and not can_stand(body))
	var max_speed := p.crouch_speed if st.crouched else p.run_speed
	var h := horizontal(body.velocity)
	if st.landing_grace_timer <= 0.0:
		h = _friction(h, p.ground_friction, dt)
	var wish_dir := wish.normalized()
	h = _accelerate(h, wish_dir, max_speed * wish.length(), p.ground_accel, dt)
	body.velocity = h


func _start_slide(body: CharacterBody3D, st: MovementState) -> void:
	var h := horizontal(body.velocity)
	var boosted := false
	if st.slide_boost_cooldown <= 0.0 and h.length() > 0.1:
		h += h.normalized() * p.slide_boost
		st.slide_boost_cooldown = p.slide_boost_cooldown
		boosted = true
	body.velocity = h
	st.mode = Mode.SLIDE
	st.crouched = true
	st.crouch_buffer_timer = 0.0
	_event(st, &"slide_start", {"boosted": boosted})


## Slides work in horizontal velocity, like running: on the floor,
## move_and_slide drops the vertical part of velocity and floor snap follows
## the slope. Slopes add the horizontal share of gravity along the surface.
func _tick_slide(body: CharacterBody3D, st: MovementState, wish: Vector3, dt: float) -> void:
	var n := st.floor_normal
	var g := Vector3.DOWN * p.gravity
	var h := horizontal(body.velocity)
	h += horizontal(g - n * g.dot(n)) * dt  # Downhill pull.
	h = h.move_toward(Vector3.ZERO, p.slide_friction * dt)
	h = _air_accelerate(h, wish, dt)  # Light steering, same rules as air.
	body.velocity = h
	st.crouched = true
	if h.length() < p.slide_exit_speed:
		st.mode = Mode.GROUND
		_event(st, &"slide_end")


# --- Air --------------------------------------------------------------------

func _tick_air(body: CharacterBody3D, wish: Vector3, dt: float) -> void:
	body.velocity = _air_accelerate(body.velocity, wish, dt)
	_gravity_now = p.gravity


func _apply_soft_cap(body: CharacterBody3D, st: MovementState, dt: float) -> void:
	if st.mode in [Mode.DASH, Mode.SMASH_WINDUP, Mode.SMASH, Mode.MANTLE]:
		return
	var v := body.velocity
	var h := Vector2(v.x, v.z)
	var speed := h.length()
	if speed <= p.soft_speed_cap:
		return
	var new_speed := maxf(speed - p.soft_cap_drag * (speed - p.soft_speed_cap) * dt, p.soft_speed_cap)
	h *= new_speed / speed
	body.velocity = Vector3(h.x, v.y, h.y)


# --- Dash -------------------------------------------------------------------

func _start_dash(body: CharacterBody3D, st: MovementState, cmd: InputCommand, wish: Vector3) -> void:
	var dir := horizontal(wish)
	if dir.length_squared() < 0.01:
		dir = forward_from_yaw(cmd.yaw)
	dir = dir.normalized()
	var pre := horizontal(body.velocity).length()
	st.dash_dir = dir
	st.dash_speed = maxf(p.dash_speed, pre)
	st.dash_exit_speed = maxf(pre, p.dash_exit_min_speed)
	st.dash_timer = p.dash_duration
	st.dash_charges -= 1
	st.dash_buffer_timer = 0.0
	st.mode = Mode.DASH
	_event(st, &"dash", {"direction": dir})


func _tick_dash(body: CharacterBody3D, st: MovementState) -> void:
	body.velocity = st.dash_dir * st.dash_speed


func _end_dash(body: CharacterBody3D, st: MovementState) -> void:
	body.velocity = st.dash_dir * st.dash_exit_speed
	st.mode = Mode.GROUND if st.on_ground else Mode.AIR
	_event(st, &"dash_end")


# --- Wall ride --------------------------------------------------------------

func _try_start_wallride(body: CharacterBody3D, st: MovementState) -> void:
	var col := _find_wall_collision(body)
	if col == null:
		return
	var n := horizontal(col.get_normal()).normalized()
	var id := col.get_collider_id()
	if st.used_wall_id == id and st.used_wall_normal.dot(n) > 0.95:
		return
	var v := body.velocity
	var h := horizontal(v)
	var along := h - n * h.dot(n)
	if along.length() < p.wallride_min_speed:
		return
	st.mode = Mode.WALLRIDE
	st.wallride_timer = 0.0
	st.wallride_normal = n
	st.used_wall_normal = n
	st.used_wall_id = id
	body.velocity = along + Vector3.UP * clampf(v.y, p.wallride_attach_min_vy, p.wallride_attach_max_vy)
	_event(st, &"wallride_start", {"normal": n})


func _tick_wallride(body: CharacterBody3D, st: MovementState, wish: Vector3, dt: float) -> void:
	st.wallride_timer += dt
	var hit := _wall_probe(body, st.wallride_normal)
	if hit.is_empty() or st.wallride_timer >= p.wallride_duration:
		_end_wallride(st)
		_tick_air(body, wish, dt)
		return

	var n := horizontal(hit.normal).normalized()
	st.wallride_normal = n
	st.wall_normal = n
	st.wall_coyote_timer = p.wall_coyote_time

	var v := body.velocity
	var h := horizontal(v)
	var along := h - n * h.dot(n)
	along = _air_accelerate(along, wish - n * wish.dot(n), dt)
	if along.length() < p.wallride_min_speed * WALLRIDE_KEEP_FRACTION:
		_end_wallride(st)
		_tick_air(body, wish, dt)
		return

	var t := clampf(st.wallride_timer / p.wallride_duration, 0.0, 1.0)
	_gravity_now = p.gravity * lerpf(p.wallride_gravity_start, 1.0, pow(t, p.wallride_gravity_curve))
	body.velocity = along - n * WALLRIDE_STICK + Vector3.UP * v.y


func _end_wallride(st: MovementState) -> void:
	st.mode = Mode.AIR
	_event(st, &"wallride_end")


func _find_wall_collision(body: CharacterBody3D) -> KinematicCollision3D:
	for i in body.get_slide_collision_count():
		var col := body.get_slide_collision(i)
		if absf(col.get_normal().y) < WALL_MAX_NORMAL_Y:
			return col
	return null


func _wall_probe(body: CharacterBody3D, normal: Vector3) -> Dictionary:
	var from := body.global_position + Vector3.UP * (_current_height(body) * 0.5)
	var to := from - normal * (p.capsule_radius + 0.3)
	var hit := _ray(body, from, to)
	if hit.is_empty() or absf(hit.normal.y) >= WALL_MAX_NORMAL_Y:
		return {}
	return hit


# --- Smashdown --------------------------------------------------------------

func _start_smash(body: CharacterBody3D, st: MovementState) -> void:
	st.banked_velocity = horizontal(body.velocity)
	st.smash_start_y = body.global_position.y
	st.smash_timer = p.smash_windup
	st.crouch_buffer_timer = 0.0
	st.mode = Mode.SMASH_WINDUP
	body.velocity = Vector3.ZERO
	_event(st, &"smash_start")


func _tick_smash(body: CharacterBody3D, st: MovementState, dt: float) -> void:
	if st.mode == Mode.SMASH_WINDUP:
		st.smash_timer -= dt
		if st.smash_timer > TIMER_EPSILON:
			body.velocity = Vector3.ZERO
			return
		st.mode = Mode.SMASH
		st.smash_start_y = body.global_position.y
	body.velocity = Vector3.DOWN * p.smash_speed


func _smash_impact(body: CharacterBody3D, st: MovementState, cmd: InputCommand) -> void:
	var drop := maxf(st.smash_start_y - body.global_position.y, 0.0)
	st.last_drop_height = drop
	st.bounce_window_timer = p.smash_bounce_window
	_refill_on_landing(st)
	var h := st.banked_velocity
	if cmd.crouch_held:
		var dir := h.normalized() if h.length() > 0.5 else forward_from_yaw(cmd.yaw)
		body.velocity = dir * (h.length() + p.smash_slide_bonus)
		st.mode = Mode.SLIDE
		st.crouched = true
	else:
		body.velocity = h
		st.mode = Mode.GROUND
	_event(st, &"smash_impact", {"position": body.global_position, "drop": drop, "slide": cmd.crouch_held})


# --- Mantle -----------------------------------------------------------------

func _try_start_mantle(body: CharacterBody3D, st: MovementState, wish: Vector3) -> bool:
	if st.mode == Mode.MANTLE:
		return false
	var dir := horizontal(wish).normalized()
	var pos := body.global_position
	var reach := p.capsule_radius + p.mantle_reach
	var max_h := p.mantle_max_height_ground if st.on_ground else p.mantle_max_height_air

	# 1. Find the nearest obstacle in front, probing from low to high. The
	#    lowest hit decides: on stairs that is the first riser, whose top is
	#    too low to count as a ledge, so stairs never trigger a mantle.
	var wall := {}
	for probe_h: float in [0.2, 0.7, 1.2, 1.7]:
		if probe_h > max_h:
			break
		var from := pos + Vector3.UP * probe_h
		var hit := _ray(body, from, from + dir * reach)
		if not hit.is_empty():
			wall = hit
			break
	if wall.is_empty() or absf(wall.normal.y) >= WALL_MAX_NORMAL_Y or dir.dot(-wall.normal) < 0.6:
		return false

	# 2. Find the ledge top just behind that face.
	var n := horizontal(wall.normal).normalized()
	var column: Vector3 = wall.position - n * 0.15
	var top := _ray(body,
			Vector3(column.x, pos.y + max_h + 0.1, column.z),
			Vector3(column.x, pos.y + p.mantle_min_height, column.z))
	if top.is_empty() or top.normal.angle_to(Vector3.UP) > deg_to_rad(p.max_floor_angle_deg):
		return false
	var ledge_h: float = top.position.y - pos.y
	if ledge_h < p.mantle_min_height or ledge_h > max_h:
		return false

	# 3. Make sure we fit on top, standing or crouched.
	var target: Vector3 = top.position + Vector3.UP * 0.02 - n * p.capsule_radius
	var crouch := false
	if not _shape_fits(body, target, false):
		if not _shape_fits(body, target, true):
			return false
		crouch = true

	var keep := horizontal(body.velocity).length() * p.mantle_speed_keep
	st.mantle_from = pos
	st.mantle_to = target
	st.mantle_timer = 0.0
	st.mantle_exit_velocity = dir * maxf(keep, p.mantle_min_exit_speed)
	st.crouched = crouch
	st.mode = Mode.MANTLE
	body.velocity = Vector3.ZERO
	_event(st, &"mantle", {"height": ledge_h})
	return true


func _tick_mantle(body: CharacterBody3D, st: MovementState, dt: float) -> void:
	st.mantle_timer += dt
	var t := clampf(st.mantle_timer / p.mantle_duration, 0.0, 1.0)
	var ty := ease(minf(t / MANTLE_RISE_FRACTION, 1.0), 0.5)
	var txz := smoothstep(0.2, 1.0, t)
	var from := st.mantle_from
	var to := st.mantle_to
	body.global_position = Vector3(lerpf(from.x, to.x, txz), lerpf(from.y, to.y, ty), lerpf(from.z, to.z, txz))
	_update_capsule(body, st, null)
	if t < 1.0:
		return
	body.velocity = st.mantle_exit_velocity
	body.apply_floor_snap()
	st.mode = Mode.GROUND
	st.on_ground = true
	st.mantle_cooldown = MANTLE_COOLDOWN
	_refill_on_landing(st)
	_event(st, &"mantle_end")


# --- Moving and landing -----------------------------------------------------

func _move(body: CharacterBody3D, st: MovementState, dt: float) -> void:
	var half_g := _gravity_now * dt * 0.5
	body.velocity.y -= half_g
	st.pre_move_velocity = body.velocity
	var was_grounded := st.on_ground and (st.mode == Mode.GROUND or st.mode == Mode.SLIDE or st.mode == Mode.DASH)
	var start := body.global_position
	body.move_and_slide()
	if was_grounded and p.step_height > 0.0 and body.is_on_wall():
		_try_step_up(body, st, start, dt)
	if not body.is_on_floor():
		body.velocity.y = maxf(body.velocity.y - half_g, -p.terminal_velocity)


## When a ground move is stopped by a low riser, lift the body onto it and
## finish the move from there, so stairs cost no speed.
func _try_step_up(body: CharacterBody3D, st: MovementState, start: Vector3, dt: float) -> void:
	var h_vel := horizontal(st.pre_move_velocity)
	var full_motion := h_vel * dt
	if full_motion.length_squared() < 1e-6:
		return
	var dir := h_vel.normalized()
	var base := body.global_transform
	var col := KinematicCollision3D.new()

	var up := Vector3.UP * p.step_height
	if body.test_move(base, up, col):
		up = col.get_travel()
	var raised := base.translated(up)
	# Probe only a short way forward: far enough that the capsule rests on the
	# riser's edge at a walkable angle, but short of the next riser on tight
	# stairs, whose edge would read as too steep.
	var probe := dir * clampf(full_motion.length(), 0.12, 0.3)
	if body.test_move(raised, probe, col):
		probe = col.get_travel()
		if horizontal(probe).length() < 0.05:
			return  # Still blocked up high: a real wall, not a step.
	var over := raised.translated(probe)
	if not body.test_move(over, Vector3.DOWN * (up.y + 0.05), col):
		return
	if col.get_normal().angle_to(Vector3.UP) > body.floor_max_angle:
		return
	if col.get_position().y - base.origin.y > p.step_height + 0.01:
		return  # Resting on the edge of something taller than a step.
	var rise := up.y + col.get_travel().y
	if rise < 0.02 or rise > p.step_height + 0.001:
		return

	var travelled := horizontal(base.origin - start).length()
	var remaining := clampf(1.0 - travelled / full_motion.length(), 0.0, 1.0)
	body.global_position += Vector3.UP * (rise + 0.01)
	body.velocity = h_vel * remaining
	body.move_and_slide()
	body.velocity = h_vel
	_event(st, &"step", {"height": rise})


func _post_move(body: CharacterBody3D, st: MovementState, cmd: InputCommand) -> void:
	var grounded := body.is_on_floor()
	if grounded:
		st.floor_normal = body.get_floor_normal()

	var wall_col := _find_wall_collision(body)
	if wall_col != null:
		st.wall_normal = horizontal(wall_col.get_normal()).normalized()
		st.wall_coyote_timer = p.wall_coyote_time

	match st.mode:
		Mode.SMASH:
			if grounded:
				_smash_impact(body, st, cmd)
		Mode.GROUND, Mode.SLIDE:
			if not grounded:
				st.mode = Mode.AIR
				st.coyote_timer = p.coyote_time
		Mode.AIR, Mode.WALLRIDE:
			if grounded:
				_land(body, st, cmd)
			elif st.mode == Mode.AIR:
				_try_start_wallride(body, st)
		Mode.DASH:
			if grounded and not st.on_ground:
				_refill_on_landing(st)
	st.on_ground = grounded
	if grounded and st.mode != Mode.SLIDE:
		st.crouch_buffer_timer = 0.0


func _land(body: CharacterBody3D, st: MovementState, cmd: InputCommand) -> void:
	var impact := -st.pre_move_velocity.y
	_refill_on_landing(st)
	var hspeed := horizontal(body.velocity).length()
	var wants_slide := cmd.crouch_held or st.crouch_buffer_timer > 0.0
	_event(st, &"land", {"impact_speed": impact})
	if wants_slide and hspeed >= p.slide_min_speed:
		_start_slide(body, st)
	else:
		st.mode = Mode.GROUND


func _refill_on_landing(st: MovementState) -> void:
	st.wall_jumps_left = p.wall_jumps
	st.used_wall_normal = Vector3.ZERO
	st.used_wall_id = 0
	st.landing_grace_timer = p.landing_grace


# --- Capsule ----------------------------------------------------------------

func _update_capsule(body: CharacterBody3D, st: MovementState, cmd: InputCommand) -> void:
	if cmd != null and st.mode != Mode.SLIDE and st.mode != Mode.GROUND and st.mode != Mode.MANTLE:
		# In the air you stand back up as soon as there is room.
		st.crouched = st.crouched and not can_stand(body)
	var col := body.get_node(^"Collision") as CollisionShape3D
	var capsule := col.shape as CapsuleShape3D
	var height := p.crouch_height if st.crouched else p.stand_height
	if not is_equal_approx(capsule.height, height) or not is_equal_approx(capsule.radius, p.capsule_radius):
		capsule.radius = p.capsule_radius
		capsule.height = height
		col.position = Vector3(0.0, height * 0.5, 0.0)


func _current_height(body: CharacterBody3D) -> float:
	var col := body.get_node(^"Collision") as CollisionShape3D
	return (col.shape as CapsuleShape3D).height


# --- Physics queries --------------------------------------------------------

func _ray(body: CharacterBody3D, from: Vector3, to: Vector3) -> Dictionary:
	var exclude: Array[RID] = [body.get_rid()]
	var q := PhysicsRayQueryParameters3D.create(from, to, body.collision_mask, exclude)
	return body.get_world_3d().direct_space_state.intersect_ray(q)


func _has_clearance_below(body: CharacterBody3D, distance: float) -> bool:
	var from := body.global_position + Vector3.UP * 0.05
	return _ray(body, from, from + Vector3.DOWN * (distance + 0.05)).is_empty()


## True if a standing (or crouched) capsule with its feet at `feet` overlaps nothing.
func _shape_fits(body: CharacterBody3D, feet: Vector3, crouched: bool) -> bool:
	var shape := _crouch_shape if crouched else _stand_shape
	shape.radius = p.capsule_radius - 0.02
	shape.height = p.crouch_height if crouched else p.stand_height
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * (shape.height * 0.5 + 0.03))
	q.collision_mask = body.collision_mask
	var exclude: Array[RID] = [body.get_rid()]
	q.exclude = exclude
	return body.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


# --- Quake-style acceleration ------------------------------------------------

func _friction(v: Vector3, friction: float, dt: float) -> Vector3:
	var speed := v.length()
	if speed < 0.001:
		return Vector3.ZERO
	var drop := maxf(speed, p.stop_speed) * friction * dt
	return v * (maxf(speed - drop, 0.0) / speed)


func _accelerate(v: Vector3, dir: Vector3, wishspeed: float, accel: float, dt: float) -> Vector3:
	if wishspeed <= 0.0 or dir.length_squared() < 0.001:
		return v
	var add := wishspeed - v.dot(dir)
	if add <= 0.0:
		return v
	return v + dir * minf(accel * wishspeed * dt, add)


## Air control: acceleration uses the full wishspeed but the target speed is
## capped, which allows steering and strafe gain but not raw air speed.
func _air_accelerate(v: Vector3, wish: Vector3, dt: float) -> Vector3:
	var wishspeed := p.run_speed * wish.length()
	if wishspeed <= 0.0:
		return v
	var dir := wish.normalized()
	var add := minf(wishspeed, p.air_wishspeed_cap) - v.dot(dir)
	if add <= 0.0:
		return v
	return v + dir * minf(p.air_accel * wishspeed * dt, add)


func _event(st: MovementState, type: StringName, data: Dictionary = {}) -> void:
	var e := data.duplicate()
	e.type = type
	st.events.append(e)
