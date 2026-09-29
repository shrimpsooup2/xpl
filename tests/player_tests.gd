extends "res://tests/test_suite.gd"
## Movement tests. Each test builds a small world, drives a Player with
## scripted InputCommands one physics tick at a time, and checks the result
## against the numbers in GDD §4.

const DT := 1.0 / 60.0
const Mode := MovementState.Mode

var world: Node3D
var player: Player
var p: MovementParams


# --- Harness ----------------------------------------------------------------

func _setup() -> void:
	world = Node3D.new()
	add_child(world)
	box(Vector3(0, -0.5, 0), Vector3(400, 1, 400))
	player = load("res://scenes/player.tscn").instantiate()
	player.human_controlled = false
	player.movement_params = MovementParams.new()
	player.view_settings = ViewSettings.new()
	p = player.movement_params
	world.add_child(player)
	player.set_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame


func _teardown() -> void:
	world.queue_free()
	world = null
	player = null


func box(center: Vector3, size: Vector3, rot_deg := Vector3.ZERO) -> StaticBody3D:
	var b := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	b.add_child(col)
	b.position = center
	b.rotation_degrees = rot_deg
	world.add_child(b)
	return b


func place(pos: Vector3, vel := Vector3.ZERO) -> void:
	player.global_position = pos
	player.velocity = vel
	player.state.reset(p)
	player.state.mode = Mode.AIR


func cmd(move := Vector2.ZERO, yaw := 0.0) -> InputCommand:
	var c := InputCommand.new()
	c.move = move
	c.yaw = yaw
	return c


## Runs n ticks. Press flags on the command only last for the first tick.
func run(c: InputCommand, n := 1) -> void:
	for i in n:
		await get_tree().physics_frame
		player.tick(c, DT)
		c.clear_presses()


func settle() -> void:
	await run(cmd(), 20)


func hspeed() -> float:
	return player.horizontal_speed()


# --- Ground -----------------------------------------------------------------

func test_run_reaches_run_speed_quickly() -> void:
	place(Vector3.ZERO)
	await settle()
	var c := cmd(Vector2(0, 1))
	var ticks_to_90 := -1
	for i in 60:
		await run(c)
		if ticks_to_90 < 0 and hspeed() >= p.run_speed * 0.9:
			ticks_to_90 = i + 1
	near(hspeed(), p.run_speed, 0.05, "run speed")
	check(ticks_to_90 > 0 and ticks_to_90 <= 12, "reached 90%% of run speed in %d ticks" % ticks_to_90)
	check(player.global_position.z < -5.0, "moved forward (-Z)")


func test_friction_stops_player() -> void:
	place(Vector3.ZERO, Vector3(8.5, 0, 0))
	await run(cmd(), 30)
	check(hspeed() < 0.05, "stopped after 0.5 s, speed %.2f" % hspeed())


# --- Jump -------------------------------------------------------------------

func test_jump_height_and_airtime() -> void:
	place(Vector3.ZERO)
	await settle()
	var c := cmd()
	c.jump_pressed = true
	await run(c)
	var peak := player.global_position.y
	var ticks := 1
	while not player.state.on_ground and ticks < 120:
		await run(c)
		peak = maxf(peak, player.global_position.y)
		ticks += 1
	var expected := p.jump_velocity * p.jump_velocity / (2.0 * p.gravity)
	near(peak, expected, 0.03, "jump apex")
	near(ticks * DT, 2.0 * p.jump_velocity / p.gravity, 0.05, "airtime")


func test_jump_buffer_fires_on_landing() -> void:
	place(Vector3(0, 0.6, 0))
	var c := cmd()
	while player.global_position.y > 0.15:
		await run(c)  # Falling, press jump just before touching down.
	check(not player.state.on_ground, "still airborne before pressing")
	c.jump_pressed = true
	var jumped := false
	for i in 12:
		await run(c)
		if player.velocity.y > 3.0:
			jumped = true
			break
	check(jumped, "buffered jump fired on landing")


func test_coyote_jump_after_leaving_ledge() -> void:
	box(Vector3(0, 1, 0), Vector3(4, 2, 4))  # Platform top at y = 2, edge at z = -2.
	await get_tree().physics_frame
	place(Vector3(0, 2.0, 1.0))
	await settle()
	var left_ground_tick := -1
	var c := cmd(Vector2(0, 1))
	for i in 60:
		await run(c)
		if not player.state.on_ground:
			left_ground_tick = i
			break
	check(left_ground_tick >= 0, "ran off the ledge")
	await run(c, 2)  # ~50 ms after leaving: inside the 100 ms coyote window.
	c.jump_pressed = true
	await run(c)
	check(player.velocity.y > 5.0, "coyote jump worked, vy %.2f" % player.velocity.y)


# --- Slide ------------------------------------------------------------------

func test_slide_holds_its_speed() -> void:
	place(Vector3.ZERO, Vector3(0, 0, -12))
	player.state.mode = Mode.GROUND
	await run(cmd(), 2)
	var c := cmd()
	c.crouch_pressed = true
	c.crouch_held = true
	await run(c)
	c.crouch_pressed = false
	check(player.state.mode == Mode.SLIDE, "sliding")
	var start := hspeed()
	await run(c, 30)
	near(start - hspeed(), p.slide_friction * 0.5, 0.2, "speed lost over 0.5 s (%.2f -> %.2f)" % [start, hspeed()])


func test_slide_boost_decay_and_cooldown() -> void:
	place(Vector3.ZERO)
	await settle()
	var c := cmd(Vector2(0, 1))
	await run(c, 60)
	var before := hspeed()
	c.crouch_pressed = true
	c.crouch_held = true
	await run(c)
	check(player.state.mode == Mode.SLIDE, "sliding")
	check(hspeed() > before + p.slide_boost * 0.9, "slide boost: %.2f -> %.2f" % [before, hspeed()])
	check(player.state.crouched, "crouched while sliding")

	c.move = Vector2.ZERO
	var ticks := 0
	while player.state.mode == Mode.SLIDE and ticks < 300:
		await run(c)
		ticks += 1
	check(player.state.mode == Mode.GROUND and player.state.crouched, "slide decays into a crouch-walk")
	check(ticks > 40 and ticks < 150, "slide lasted %.2f s" % (ticks * DT))

	# Stand, run, and slide again: still inside the boost cooldown? Only if fast.
	c.crouch_held = false
	c.move = Vector2(0, 1)
	await run(c, 20)
	check(not player.state.crouched, "stood back up")


func test_second_slide_within_cooldown_gets_no_boost() -> void:
	place(Vector3.ZERO)
	await settle()
	var c := cmd(Vector2(0, 1))
	await run(c, 60)
	c.crouch_pressed = true
	c.crouch_held = true
	await run(c, 6)
	c.crouch_held = false
	await run(c, 12)  # Back to running, 0.3 s after the first slide.
	var before := hspeed()
	check(player.state.mode == Mode.GROUND, "running again")
	c.crouch_pressed = true
	c.crouch_held = true
	await run(c)
	check(player.state.mode == Mode.SLIDE, "second slide started")
	check(hspeed() <= before + 0.05, "no boost inside cooldown: %.2f -> %.2f" % [before, hspeed()])


func test_slide_hop_keeps_speed() -> void:
	place(Vector3.ZERO)
	await settle()
	var c := cmd(Vector2(0, 1))
	await run(c, 60)
	c.crouch_pressed = true
	c.crouch_held = true
	await run(c, 5)
	var sliding_speed := hspeed()
	c.move = Vector2.ZERO
	c.jump_pressed = true
	await run(c)
	check(player.state.mode == Mode.AIR, "airborne after slide-hop")
	near(hspeed(), sliding_speed, 0.25, "horizontal speed after slide-hop")


## Runs up, then hops off `hops` landings: pressing jump `early` ticks
## before each landing (it fires just after touching down, by the buffer),
## or with `early` <= 0, that many ticks after it. Holds `move` while
## hopping. Returns how many hops were timed (from the jump events).
func hop_run(hops: int, early: int, move := Vector2(0, 1)) -> int:
	place(Vector3.ZERO)
	await settle()
	var c := cmd()
	c.jump_pressed = true
	await run(c)  # A jump on the spot, to time the airtime.
	var airtime := 0
	while not player.state.on_ground:
		await run(c)
		airtime += 1
	var timed := [0]
	player.movement_event.connect(func(e: Dictionary) -> void:
		if e.type == &"jump" and e.get("timed", false):
			timed[0] += 1)
	c.move = Vector2(0, 1)
	await run(c, 60)  # Up to run speed, forward.
	c.move = move
	c.jump_pressed = true
	await run(c)  # The first hop, from the run: no landing to time it to.
	for i in hops:
		var ticks := 0
		while not player.state.on_ground:
			ticks += 1
			if early > 0 and ticks == airtime - early:
				c.jump_pressed = true
			await run(c)
		if early <= 0:
			await run(c, -early)
			c.jump_pressed = true
		await run(c)  # Off this landing.
	return timed[0]


func test_timed_hops_build_speed_up_to_the_hop_cap() -> void:
	var timed := await hop_run(3, 0)
	check(timed == 3 and player.state.mode == Mode.AIR, "three hops right on landing, all timed (%d)" % timed)
	near(hspeed(), p.run_speed + 3.0 * p.hop_boost, 0.3, "each adds hop_boost")
	await hop_run(3, 3)
	near(hspeed(), p.run_speed + 3.0 * p.hop_boost, 0.3, "pressed a moment before landing counts too")
	await hop_run(12, 0)
	near(hspeed(), p.hop_speed_cap, 0.25, "they build up to the hop cap")
	check(hspeed() <= p.hop_speed_cap + 0.05, "and no further")


func test_mistimed_hops_only_keep_speed() -> void:
	var timed := await hop_run(4, 6)
	check(timed == 0 and player.state.mode == Mode.AIR, "pressed too early: still hops (the buffer), but plainly (%d timed)" % timed)
	check(hspeed() <= p.run_speed + 0.2, "keeping speed, not adding: %.2f" % hspeed())
	timed = await hop_run(4, -5)
	check(timed == 0 and hspeed() <= p.run_speed + 0.2, "late ones (after the landing grace) add nothing: %.2f" % hspeed())


func test_timed_hops_need_you_pushing_your_way() -> void:
	var timed := await hop_run(4, 0, Vector2.ZERO)
	check(timed == 0 and hspeed() <= p.run_speed + 0.05, "no input: speed kept, nothing added (%.2f)" % hspeed())
	timed = await hop_run(4, 0, Vector2(1, 0))
	check(timed == 0 and hspeed() < p.run_speed + 1.0, "strafing across your way doesn't count (%.2f)" % hspeed())


func test_slide_gains_speed_downhill() -> void:
	# 35° slope going down toward -Z from y = 16.
	var length := 40.0
	var angle := 35.0
	var top := 16.0
	var top_mid := Vector3(0, top - length * 0.5 * sin(deg_to_rad(angle)), -length * 0.5 * cos(deg_to_rad(angle)))
	var up := Basis.from_euler(Vector3(deg_to_rad(-angle), 0, 0)) * Vector3.UP
	box(top_mid - up * 0.5, Vector3(6, 1, length), Vector3(-angle, 0, 0))
	await get_tree().physics_frame
	place(Vector3(0, top - tan(deg_to_rad(angle)) + 0.05, -1.0), Vector3(0, 0, -6.2))
	var c := cmd()
	c.crouch_held = true
	for i in 30:
		await run(c)
		if player.state.on_ground:
			break
	check(player.state.mode == Mode.SLIDE, "landed into a slide (mode %s)" % Mode.keys()[player.state.mode])
	var speed_start := hspeed()
	await run(c, 45)
	check(player.state.mode == Mode.SLIDE, "still sliding after 0.75 s")
	check(hspeed() > speed_start + 0.5, "slide sped up downhill: %.2f -> %.2f" % [speed_start, hspeed()])


# --- Dash -------------------------------------------------------------------

func test_dash_charges_and_exit_speed() -> void:
	place(Vector3(0, 30, 0))  # Airborne so friction doesn't hide the exit speed.
	var c := cmd()
	c.dash_pressed = true
	await run(c)
	check(player.state.mode == Mode.DASH, "dashing")
	check(player.state.dash_charges == p.dash_charges - 1, "used a charge")
	var y_before := player.global_position.y
	await run(c, roundi(p.dash_duration / DT))
	check(player.state.mode == Mode.AIR, "dash ended")
	near(hspeed(), p.dash_exit_min_speed, 0.05, "exit speed from a standstill")
	check(absf(player.global_position.y - y_before) < 0.05, "no gravity during the dash")

	c.dash_pressed = true
	await run(c)
	check(player.state.dash_charges == 0, "second charge used")
	await run(c, 12)
	c.dash_pressed = true
	await run(c)
	check(player.state.mode != Mode.DASH, "no third dash without charges")

	await run(c, roundi(p.dash_recharge / DT))
	check(player.state.dash_charges == 1, "one charge back after %.2f s" % p.dash_recharge)


func test_dash_redirects_momentum() -> void:
	place(Vector3(0, 30, 0), Vector3(0, 0, -14))  # Moving forward at 14 m/s.
	var c := cmd(Vector2(1, 0))  # Dash right.
	c.dash_pressed = true
	await run(c, 1 + roundi(p.dash_duration / DT))
	check(player.velocity.x > 13.5, "kept 14 m/s, now to the right: %s" % player.velocity)


func test_dash_jump_keeps_exit_speed() -> void:
	place(Vector3.ZERO)
	await settle()
	var c := cmd(Vector2(0, 1))
	c.dash_pressed = true
	await run(c, 3)
	c.jump_pressed = true
	await run(c)
	check(player.state.mode == Mode.AIR and player.velocity.y > 5.0, "dash-jump left the ground")
	check(hspeed() >= p.dash_exit_min_speed - 0.2, "kept dash exit speed: %.2f" % hspeed())


# --- Step and mantle ----------------------------------------------------------

func test_steps_up_to_step_height() -> void:
	for h: float in [0.2, 0.3, 0.4]:
		var face := -1.0 - 20.0 * roundf(h * 10.0 - 2.0)
		box(Vector3(0, h * 0.5, face - 6.0), Vector3(3, h, 12))
	await get_tree().physics_frame
	# Walk up each step in its own lane: run from just in front of it.
	var z_starts := {0.2: -0.5, 0.3: -20.5, 0.4: -40.5}
	for h: float in [0.2, 0.3, 0.4]:
		place(Vector3(0, 0, z_starts[h]))
		await settle()
		await run(cmd(Vector2(0, 1)), 40)
		near(player.global_position.y, h, 0.03, "stood on the %.1f m step" % h)


func test_does_not_step_above_step_height() -> void:
	box(Vector3(0, 0.225, -3), Vector3(3, 0.45, 4))
	await get_tree().physics_frame
	place(Vector3.ZERO)
	await settle()
	await run(cmd(Vector2(0, 1)), 40)
	check(player.global_position.y < 0.05, "blocked by a 0.45 m step, y %.2f" % player.global_position.y)


func test_stairs_cost_little_speed() -> void:
	for i in 8:
		var h := 0.25 * (i + 1)
		box(Vector3(0, h * 0.5, -3 - 0.35 * i - 0.175), Vector3(4, h, 0.35))
	box(Vector3(0, 1.0, -5.8 - 10.0), Vector3(4, 2, 20))
	await get_tree().physics_frame
	place(Vector3.ZERO)
	await settle()
	var c := cmd(Vector2(0, 1))
	var mantled := false
	for i in 90:
		await run(c)
		mantled = mantled or player.state.mode == Mode.MANTLE
	check(not mantled, "stairs never trigger a mantle")
	near(player.global_position.y, 2.0, 0.05, "reached the top of the stairs")
	check(player.global_position.z < -10.5, "kept pace on the stairs (z %.2f after 1.5 s)" % player.global_position.z)


func test_ground_mantle_onto_waist_high_block() -> void:
	box(Vector3(0, 0.5, -7.0), Vector3(3, 1.0, 10))
	await get_tree().physics_frame
	place(Vector3.ZERO)
	await settle()
	var c := cmd(Vector2(0, 1))
	var mantled := false
	for i in 60:
		await run(c)
		mantled = mantled or player.state.mode == Mode.MANTLE
	check(mantled, "mantled")
	near(player.global_position.y, 1.0, 0.05, "on top of the 1.0 m block")
	check(player.state.mode == Mode.GROUND, "back on the ground after mantling")


func test_no_ground_mantle_on_tall_block() -> void:
	box(Vector3(0, 1.1, -3.5), Vector3(3, 2.2, 3))
	await get_tree().physics_frame
	place(Vector3.ZERO)
	await settle()
	await run(cmd(Vector2(0, 1)), 60)
	check(player.global_position.y < 0.05, "stayed on the floor next to a 2.2 m block")


func test_air_mantle_onto_high_ledge() -> void:
	box(Vector3(0, 0.9, -6.0), Vector3(3, 1.8, 10))
	await get_tree().physics_frame
	place(Vector3.ZERO)
	await settle()
	var c := cmd(Vector2(0, 1))
	c.jump_pressed = true
	var mantled := false
	for i in 60:
		await run(c)
		mantled = mantled or player.state.mode == Mode.MANTLE
	check(mantled, "mantled from a jump")
	near(player.global_position.y, 1.8, 0.05, "on top of the 1.8 m ledge")


# --- Wall ride and wall jump ------------------------------------------------

func _wall_on_left() -> void:
	box(Vector3(-1.0, 4, -30), Vector3(1, 8, 60))  # Face at x = -0.5.
	await get_tree().physics_frame


## Run at the wall at a shallow angle and jump, the way a player would.
func _approach_wall() -> InputCommand:
	await _wall_on_left()
	place(Vector3(1.5, 0, 0))
	await settle()
	var c := cmd(Vector2(0, 1), 0.25)  # Facing ~14° left of the wall's direction.
	await run(c, 30)
	return c


func test_wallride_extends_airtime() -> void:
	var c: InputCommand = await _approach_wall()
	c.jump_pressed = true
	var rode := false
	var ticks := 0
	while ticks < 180:
		await run(c)
		ticks += 1
		rode = rode or player.state.mode == Mode.WALLRIDE
		if player.state.on_ground and ticks > 5:
			break
	check(rode, "started a wall ride")
	check(ticks * DT > 1.0, "airtime %.2f s is longer than a plain jump" % (ticks * DT))


func test_wall_jump_pushes_away_and_counts() -> void:
	var c: InputCommand = await _approach_wall()
	c.jump_pressed = true
	for i in 30:
		await run(c)
		if player.state.mode == Mode.WALLRIDE:
			break
	check(player.state.mode == Mode.WALLRIDE, "riding before the wall jump")
	c.jump_pressed = true
	await run(c)
	check(player.velocity.x > 4.0, "pushed away from the wall: vx %.2f" % player.velocity.x)
	check(player.velocity.y > 5.0, "pushed up: vy %.2f" % player.velocity.y)
	check(player.state.wall_jumps_left == p.wall_jumps - 1, "used one wall jump")

	# Steer back into the same wall: no second ride on it this airtime.
	c.yaw = 0.0
	c.move = Vector2(-1, 0)
	var rode_again := false
	for i in 30:
		await run(c)
		rode_again = rode_again or player.state.mode == Mode.WALLRIDE
	check(not rode_again, "can't ride the same wall twice in one airtime")


# --- Smashdown --------------------------------------------------------------

func test_smashdown_banks_speed_and_bounces() -> void:
	place(Vector3(0, 10, 0), Vector3(0, 0, -8))
	var c := cmd()
	await run(c)
	c.crouch_pressed = true
	await run(c)
	check(player.state.mode == Mode.SMASH_WINDUP, "smashdown windup")
	var impact := {}
	for i in 60:
		await run(c)
		if player.state.mode == Mode.SMASH:
			near(player.velocity.y, -p.smash_speed, 0.01, "descent speed")
		for e in player.state.events:
			if e.type == &"smash_impact":
				impact = e
		if not impact.is_empty():
			break
	check(not impact.is_empty(), "impact happened")
	near(impact.get("drop", 0.0), 10.0, 0.4, "drop height")
	near(hspeed(), 8.0, 0.05, "banked speed restored on impact")

	c.jump_pressed = true
	await run(c)
	var expected := minf(p.smash_bounce_base + p.smash_bounce_per_meter * float(impact.drop), p.smash_bounce_max)
	near(player.velocity.y, expected - p.gravity * DT, 0.1, "slam bounce velocity")
	near(hspeed(), 8.0 + p.smash_bounce_boost, 0.1, "bounce kicks you on")


func test_smashdown_slam_slide() -> void:
	place(Vector3(0, 6, 0), Vector3(0, 0, -8))
	var c := cmd()
	await run(c)
	c.crouch_pressed = true
	c.crouch_held = true
	for i in 60:
		await run(c)
		if player.state.on_ground:
			break
	check(player.state.mode == Mode.SLIDE, "slam slide after impact")
	check(hspeed() > 8.0 + p.smash_slide_bonus - 0.3, "slam slide speed %.2f" % hspeed())


func test_no_smashdown_close_to_ground() -> void:
	place(Vector3(0, 1.0, 0))
	var c := cmd()
	c.crouch_pressed = true
	await run(c)
	check(player.state.mode != Mode.SMASH_WINDUP and player.state.mode != Mode.SMASH, "no smash 1 m above the floor")


# --- Air control ------------------------------------------------------------

func test_air_strafe_gains_speed() -> void:
	place(Vector3(0, 100, 0), Vector3(0, 0, -8.5))
	var c := cmd(Vector2(1, 0))
	for i in 30:
		var v := player.velocity
		c.yaw = atan2(-v.x, -v.z)  # Look along velocity, strafe right.
		await run(c)
	check(hspeed() > 9.5, "strafe gain: 8.5 -> %.2f" % hspeed())


func test_soft_cap_drags_back_toward_cap() -> void:
	place(Vector3(0, 200, 0), Vector3(25, 0, 0))
	await run(cmd(), 60)
	var expected := p.soft_speed_cap + (25.0 - p.soft_speed_cap) * exp(-p.soft_cap_drag * 1.0)
	near(hspeed(), expected, 0.25, "speed after 1 s above the cap")


# --- Crouch -----------------------------------------------------------------

func test_stays_crouched_under_low_ceiling() -> void:
	box(Vector3(0, 1.45, -8), Vector3(4, 0.5, 8))  # Ceiling at 1.2 m from z = -4 to -12.
	await get_tree().physics_frame
	place(Vector3.ZERO)
	await settle()
	var c := cmd(Vector2(0, 1))
	await run(c, 25)
	c.crouch_pressed = true
	c.crouch_held = true
	await run(c, 20)
	check(player.global_position.z < -4.5, "slid under the ceiling (z %.2f)" % player.global_position.z)
	c.crouch_held = false
	await run(c, 5)
	if player.global_position.z > -12.0:
		check(player.state.crouched, "still crouched under the ceiling")
	await run(c, 180)
	check(player.global_position.z < -12.5, "came out the other side (z %.2f)" % player.global_position.z)
	check(not player.state.crouched, "stood up after the tunnel")


# --- Death --------------------------------------------------------------------

## Enough pieces to read as "diced", not just a few limbs.
const MIN_PIECES := 40


func _wait_for_pieces(max_frames := 240) -> void:
	for i in max_frames:
		await get_tree().physics_frame
		if player.model.fragments().size() >= MIN_PIECES:
			return


func test_death_stops_player_and_body_falls_apart() -> void:
	place(Vector3.ZERO)
	await settle()
	player.die()
	check(player.is_dead, "dead after die()")
	var start := player.global_position
	await run(cmd(Vector2(0, 1)), 10)
	check(player.global_position.is_equal_approx(start), "no movement while dead")
	await _wait_for_pieces()
	check(player.model.fragments().size() >= MIN_PIECES,
			"diced into lots of pieces: %d" % player.model.fragments().size())
	check(not player.model.body.visible, "the whole body was swapped for pieces")
	for i in 150:
		await get_tree().physics_frame
	var resting := 0
	for f in player.model.fragments():
		if f.global_position.y > -0.2 and f.global_position.y < 2.5:
			resting += 1
	check(resting == player.model.fragments().size(), "pieces landed on the floor (%d resting)" % resting)


func test_respawn_mid_collapse_reassembles_cleanly() -> void:
	place(Vector3.ZERO)
	await settle()
	player.die()
	for i in 12:
		await get_tree().physics_frame
	player.respawn()
	for i in 120:
		await get_tree().physics_frame  # Long enough for any leftover pops.
	check(not player.is_dead, "alive after respawn")
	check(player.model.fragments().is_empty(), "no fragments after respawn (%d)" % player.model.fragments().size())
	check(player.model.body.visible and player.model.heart.visible, "body and heart back")
	check(player.model.heart.ending() == &"on" and player.model.heart.get_parent().name == &"HeartMount",
			"the heart back in the chest and on")
	await run(cmd(Vector2(0, 1)), 30)
	check(hspeed() > 5.0, "can move again after respawn")


func test_falling_out_of_the_world_kills() -> void:
	place(Vector3(0, Player.KILL_Y + 1.0, 0) + Vector3(300, 0, 0))
	await run(cmd(), 30)
	check(player.is_dead, "died below the kill height")


# --- Camera ---------------------------------------------------------------------

## Whether a camera-sized ball at the camera would be inside the world.
func camera_in_wall() -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	ball.radius = Player.CAMERA_PROBE * 0.8
	q.shape = ball
	q.transform = Transform3D(Basis.IDENTITY, player.camera.global_position)
	q.collision_mask = 1
	q.exclude = [player.get_rid()]
	return not player.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func test_the_third_person_camera_bumps_against_a_wall_behind() -> void:
	box(Vector3(0, 2, 1.2), Vector3(10, 4, 0.5))  # A wall 1 m behind (the camera sits behind, +Z).
	place(Vector3(0, 0.05, 0))
	player.set_process(true)
	player.set_third_person(true)
	await run(cmd(), 10)
	await get_tree().process_frame
	var cam := player.camera.global_position
	check(not camera_in_wall(), "the camera isn't in the wall (at %s)" % cam)
	check(cam.z < 0.95 and cam.z > 0.0, "it's pulled in on this side of it (z %.2f)" % cam.z)
	# Wall gone: it eases back out to full distance.
	for c in world.get_children():
		if c is StaticBody3D and c.position.z > 1.0:
			c.free()
	for i in 90:
		await get_tree().process_frame
	check(player.camera.global_position.z > 3.0, "and back out once it's clear (z %.2f)" % player.camera.global_position.z)
	player.set_third_person(false)


func test_the_eye_never_ends_up_in_a_low_ceiling() -> void:
	# Duck under a 1.2 m slab at the last moment: the capsule shrinks at
	# once and the eye drops over a moment (quickly enough on its own; the
	# camera sweep is there if it ever isn't). It must stay under the slab.
	box(Vector3(0, 1.45, -8), Vector3(6, 0.5, 8))  # Underside at 1.2 m, from z -4 to -12.
	place(Vector3(0, 0.05, 8))
	player.set_process(true)
	# Run at it and only duck at the last moment, at the mouth.
	for i in 120:
		await run(cmd(Vector2(0, 1)))
		if player.global_position.z < -3.55:
			break
	var slide := cmd(Vector2(0, 1))
	slide.crouch_pressed = true
	slide.crouch_held = true
	var worst := 0.0
	for i in 60:
		await run(slide)
		slide.crouch_held = true
		await get_tree().process_frame
		if player.camera.global_position.z < -4.0:  # Under the slab.
			worst = maxf(worst, player.camera.global_position.y)
	check(player.global_position.z < -5.0, "slid in under it (z %.1f)" % player.global_position.z)
	check(worst > 0.0 and worst < 1.2 - Player.CAMERA_PROBE * 0.5, "the camera stayed under the ceiling (highest %.2f m)" % worst)


func test_the_death_camera_stays_out_of_walls() -> void:
	# Die facing a wall 1.5 m away: the death camera's spot (3 m in front)
	# is inside it, so it stops short.
	player.queue_free()
	await get_tree().process_frame
	player = load("res://scenes/player.tscn").instantiate()
	player.movement_params = MovementParams.new()
	player.view_settings = ViewSettings.new()
	world.add_child(player)
	box(Vector3(0, 2, -1.9), Vector3(10, 4, 0.8))  # Front face at z -1.5.
	player.spawn_at(Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	await get_tree().physics_frame
	player.die()
	var worst_in := false
	for i in 90:
		await get_tree().process_frame
		worst_in = worst_in or camera_in_wall()
	check(player.camera.global_position.z > -1.5 + Player.CAMERA_PROBE * 0.5, "the camera stays this side of the wall (z %.2f)" % player.camera.global_position.z)
	check(not worst_in, "never inside it")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
