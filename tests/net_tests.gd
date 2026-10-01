extends "res://tests/test_suite.gd"
## Network tests (docs/NETWORKING.md): what goes over the wire comes back as
## it went, and anything else (wrong sizes, out of range, NaN, unknown bits,
## random junk, objects) is refused before the game sees it.


func cmd_with(move: Vector2, yaw: float, pitch: float, pressed: Array, switch_to := 0) -> InputCommand:
	var c := InputCommand.new()
	c.move = move
	c.yaw = yaw
	c.pitch = pitch
	for b: StringName in pressed:
		c.set(b, true)
	c.switch_to = switch_to
	return c


# --- Inputs ---------------------------------------------------------------------------

func test_inputs_go_over_the_wire_and_come_back() -> void:
	var a := cmd_with(Vector2(0.5, -1.0).limit_length(1.0), 12.25, -0.7, [&"jump_pressed", &"jump_held", &"fire_held"], 3)
	var b := cmd_with(Vector2(-0.2, 0.9), -3.0, 1.2, [&"crouch_held", &"dash_pressed", &"throw_pressed", &"interact_pressed"])
	a.view_tick = 1234.5625
	var bytes := NetCodec.encode_inputs([[41, a], [42, b]])
	check(bytes.size() == 1 + 2 * NetCodec.INPUT_SIZE, "two commands in %d bytes" % bytes.size())
	var back := NetCodec.decode_inputs(bytes)
	check(back.size() == 2 and back[0][0] == 41 and back[1][0] == 42, "ticks in order")
	var a2: InputCommand = back[0][1]
	var b2: InputCommand = back[1][1]
	check(a2.move.distance_to(a.move) < 0.001 and b2.move.distance_to(b.move) < 0.001, "move within 1/32767")
	check(absf(a2.yaw - a.yaw) < 1e-5 and absf(a2.pitch - a.pitch) < 1e-6 and absf(b2.yaw - b.yaw) < 1e-6, "view angles at float precision")
	check(a2.jump_pressed and a2.jump_held and a2.fire_held and not a2.fire_pressed and a2.switch_to == 3, "buttons and the switch")
	check(b2.crouch_held and b2.dash_pressed and b2.throw_pressed and b2.interact_pressed and not b2.jump_held, "the other buttons")
	check(a2.view_tick == 1234.5625 and b2.view_tick == -1.0, "the tick they saw everyone at (to 1/16), or none: %s, %s" % [a2.view_tick, b2.view_tick])


func test_bad_inputs_are_refused() -> void:
	var good := NetCodec.encode_inputs([[7, cmd_with(Vector2.ZERO, 0.0, 0.0, [])]])
	check(NetCodec.decode_inputs(PackedByteArray()).is_empty(), "empty")
	check(NetCodec.decode_inputs(good.slice(0, good.size() - 1)).is_empty(), "one byte short")
	var longer := good.duplicate()
	longer.append(0)
	check(NetCodec.decode_inputs(longer).is_empty(), "one byte long")
	var none := good.duplicate()
	none[0] = 0
	check(NetCodec.decode_inputs(none).is_empty(), "no commands")
	var too_many := NetCodec.encode_inputs([])
	too_many[0] = NetCodec.INPUT_REDUNDANCY + 2
	check(NetCodec.decode_inputs(too_many).is_empty(), "too many")
	for bad: Array in [[1e9, 0.0], [NAN, 0.0], [0.0, INF], [0.0, 2.0]]:
		var bytes := NetCodec.encode_inputs([[7, cmd_with(Vector2.ZERO, bad[0], bad[1], [])]])
		check(NetCodec.decode_inputs(bytes).is_empty(), "view angles %s refused" % [bad])
	var bits := good.duplicate()
	bits[1 + 17] = 0xFF  # The buttons' high byte: bits nothing uses.
	check(NetCodec.decode_inputs(bits).is_empty(), "unknown buttons")
	var sw := good.duplicate()
	sw[1 + 18] = 9
	check(NetCodec.decode_inputs(sw).is_empty(), "a switch that doesn't exist")
	var fast := good.duplicate()
	fast.encode_s16(1 + 4, 32767)
	fast.encode_s16(1 + 6, 32767)
	check(NetCodec.decode_inputs(fast).is_empty(), "a move longer than 1")


func test_random_junk_never_gets_through_or_breaks_anything() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var accepted := 0
	for i in 2000:
		var bytes := PackedByteArray()
		var n := rng.randi_range(0, 90) if i % 2 == 0 else 1 + rng.randi_range(1, 4) * NetCodec.INPUT_SIZE
		bytes.resize(n)
		for j in n:
			bytes[j] = rng.randi_range(0, 255)
		if i % 2 == 1:
			bytes[0] = (n - 1) / NetCodec.INPUT_SIZE
		var got := NetCodec.decode_inputs(bytes)
		for e: Array in got:
			var c: InputCommand = e[1]
			accepted += 1
			check(c.move.length() <= 1.0001 and is_finite(c.yaw) and absf(c.pitch) <= NetCodec.MAX_PITCH and c.switch_to <= 3,
					"anything let through is in range")
		NetCodec.decode_players(bytes)
		NetCodec.decode_owner(bytes)
		var loose := NetCodec.decode_pickups(bytes)
		for e: Dictionary in loose.get("pickups", []):
			check(e.position.is_finite() and e.rotation.is_normalized() and e.ammo <= 1000, "any loose weapon let through is sane")
	check(true, "2000 random packets decoded without breaking (%d commands passed the checks)" % accepted)


# --- Stalls and lag ---------------------------------------------------------------------

## MatchSync on the server: a client whose commands stop coming waits a few
## ticks, then carries on with its last command (its presses and trigger let
## go) for a moment rather than freezing on everyone's screen, then stops.
## The commands for the ticks it was guessed through are too late when they
## come; it picks up after them.
func test_a_stalled_player_carries_on_a_moment_then_stops() -> void:
	var sync := MatchSync.new()
	sync._inputs[5] = {"queue": {}, "next": -1, "ran": -1, "last": null, "waited": 0, "guessed": 0}
	check(sync._commands_for(5).is_empty(), "nothing to run before anything came")
	var walk := cmd_with(Vector2(0.3, 0.9), 0.5, 0.1, [&"fire_pressed", &"fire_held", &"alt_held", &"jump_pressed", &"crouch_held"], 2)
	sync.queue_commands(5, [[10, walk], [11, walk]])
	var first := sync._commands_for(5)
	var second := sync._commands_for(5)
	check(first.size() == 1 and second.size() == 1 and first[0] == walk, "its commands run, one a tick")
	var waited := 0
	while sync._commands_for(5).is_empty() and waited < 100:
		waited += 1
	check(waited == MatchSync.WAIT_TICKS, "it waits %d ticks for the next (%d)" % [MatchSync.WAIT_TICKS, waited])
	var guesses := [null]  # The one that ended the wait.
	for i in 60:
		guesses.append_array(sync._commands_for(5))
	check(guesses.size() == MatchSync.GUESS_TICKS, "then carries on for %d ticks and stops (%d)" % [MatchSync.GUESS_TICKS, guesses.size()])
	var g: InputCommand = guesses[1]
	check(g != walk and g.move == walk.move and g.yaw == walk.yaw and g.pitch == walk.pitch and g.crouch_held,
			"on the last command: the same move, view and holds")
	check(not g.fire_pressed and not g.fire_held and not g.alt_held and not g.jump_pressed and g.switch_to == 0,
			"its presses and trigger let go")
	var late := []
	for t in range(12, 12 + MatchSync.GUESS_TICKS + 2):
		late.append([t, walk])
	sync.queue_commands(5, late)
	var after := sync._commands_for(5)
	check(after.size() == 1 and sync._inputs[5].ran == 12 + MatchSync.GUESS_TICKS,
			"the late commands for the guessed ticks are dropped, and it picks up after them (ran %d)" % sync._inputs[5].ran)
	check(sync._commands_for(5).size() == 1 and sync._commands_for(5).is_empty(), "then waits again")
	sync.free()


## Rewind (lag compensation): a shot is tested against the target where the
## shooter's screen showed it, a few ticks back, not where it is now; never
## further back than MAX_TICKS; and not at all where it was down.
func test_shots_are_tested_where_the_shooter_saw_the_target() -> void:
	var world := Node3D.new()
	add_child(world)
	var bodies: Array[Player] = []
	for at: Vector3 in [Vector3(0, 0.05, 0), Vector3(-2, 0.05, -8)]:
		var p: Player = load("res://scenes/player.tscn").instantiate()
		p.human_controlled = false
		p.movement_params = MovementParams.new()
		p.view_settings = ViewSettings.new()
		world.add_child(p)
		p.set_process(false)
		p.set_physics_process(false)
		p.spawn_at(Transform3D(Basis.IDENTITY, at))
		bodies.append(p)
	await get_tree().physics_frame
	var shooter := bodies[0]
	var target := bodies[1]
	var chest := target.model.global_transform.affine_inverse() * target.model.heart.global_position
	var rewind := Rewind.new()
	# The target strafes 0.2 m a tick: x = -2 at tick 100, 0 at 110, 1.8 now (119).
	for t in range(100, 120):
		target.global_position.x = -2.0 + 0.2 * (t - 100)
		target.model.follow(target.global_position, target.yaw)
		target.is_dead = t == 101
		rewind.record(t, [shooter, target])
	var eye := shooter.weapons.eye_position()
	var at_x := func(x: float) -> Vector3:
		var point := target.model.global_transform * chest + Vector3(x - target.global_position.x, 0, 0)
		return eye + (point - eye).normalized() * 30.0
	check(target.ray_test(eye, at_x.call(0.0)).is_empty(), "now, it isn't where the shooter saw it")
	var hit := rewind.ray_test(target, eye, at_x.call(0.0), 110.0)
	check(not hit.is_empty(), "but it's hit where the shooter saw it, 9 ticks back")
	check(rewind.ray_test(target, eye, at_x.call(1.8), 110.0).is_empty(), "and not where it is now")
	var between := rewind.ray_test(target, eye, at_x.call(0.1), 110.5)
	check(not between.is_empty() and absf(between.get("point", Vector3.ZERO).x - 0.1) < 0.2,
			"between ticks, in between, and the hit is where it was seen: %s" % between.get("point"))
	check(rewind.ray_test(target, eye, at_x.call(-2.0), 100.0).is_empty()
			and not rewind.ray_test(target, eye, at_x.call(1.8 - 0.2 * Rewind.MAX_TICKS), 100.0).is_empty(),
			"no further back than %d ticks" % Rewind.MAX_TICKS)
	var down_at := rewind.clamp_tick(101.0)
	check(down_at == 104.0, "a view that old is tested %d ticks back" % Rewind.MAX_TICKS)
	# A shooter online (its view_tick from its commands), through Ballistics.
	var ballistics := Ballistics.of(world)
	Rewind.active = rewind
	shooter.view_tick = 110.0
	var shot := ballistics.trace(eye, at_x.call(0.0), [], shooter.weapons)
	check(shot.get("target") == target, "a shot from someone online hits where they saw it")
	var now := ballistics.trace(eye, at_x.call(0.0), [], shooter.weapons, Ballistics.NOW)
	check(now.get("target") != target, "and a thrown gun (NOW) doesn't")
	shooter.view_tick = -1.0
	check(ballistics.trace(eye, at_x.call(1.8), [], shooter.weapons).get("target") == target, "someone playing here is tested against now")
	Rewind.active = null
	var gone := Rewind.new()
	for t in range(100, 104):
		target.is_dead = t < 102
		gone.record(t, [target])
	check(gone.ray_test(target, eye, at_x.call(1.8), 100.0).is_empty() and not gone.ray_test(target, eye, at_x.call(1.8), 103.0).is_empty(),
			"not where it was down")
	world.queue_free()


# --- Loose weapons ---------------------------------------------------------------------

func test_loose_weapons_go_over_the_wire_and_junk_is_refused() -> void:
	var turn := Quaternion(Vector3.UP, 1.2) * Quaternion(Vector3.RIGHT, 0.3)
	var entries := [{"id": 7, "position": Vector3(3, 0.2, -40), "rotation": turn, "ammo": 12},
			{"id": 65535, "position": Vector3(-1, 5, 2), "rotation": Quaternion.IDENTITY, "ammo": 0}]
	var bytes := NetCodec.encode_pickups(3, entries)
	check(bytes.size() == 3 + 2 * NetCodec.PICKUP_SIZE, "two in %d bytes" % bytes.size())
	var back := NetCodec.decode_pickups(bytes)
	check(back.serial == 3 and back.pickups.size() == 2 and back.pickups[0].id == 7 and back.pickups[1].id == 65535, "ids")
	check(back.pickups[0].position == Vector3(3, 0.2, -40) and back.pickups[0].rotation.is_equal_approx(turn) and back.pickups[0].ammo == 12,
			"where, which way up, and what's left in it")
	check(NetCodec.decode_pickups(bytes.slice(0, bytes.size() - 1)).is_empty(), "short")
	for field: Array in [["position", Vector3(INF, 0, 0)], ["position", Vector3(0, 0, 1e7)], ["rotation", Quaternion(0, 0, 0, 2)],
			["rotation", Quaternion(NAN, 0, 0, 1)], ["ammo", 5000]]:
		var bad: Dictionary = entries[0].duplicate()
		bad[field[0]] = field[1]
		check(NetCodec.decode_pickups(NetCodec.encode_pickups(1, [bad])).is_empty(), "%s = %s refused" % field)


# --- Addresses ------------------------------------------------------------------------

func test_addresses_are_read_like_people_type_them() -> void:
	var port := NetSession.DEFAULT_PORT
	for case: Array in [["192.168.1.20", ["192.168.1.20", port]], ["example.com:27961", ["example.com", 27961]],
			["  10.0.0.5:4000 ", ["10.0.0.5", 4000]], ["[::1]:27962", ["::1", 27962]], ["[fe80::1]", ["fe80::1", port]],
			["::1", ["::1", port]], ["", []], ["host:", []], ["host:port", []], ["host:70000", []], ["host:0", []],
			["[::1]:x", []], ["[::1", []], ["two words", []]]:
		check(NetSession.parse_address(case[0]) == case[1], "%s → %s (got %s)" % [case[0], case[1], NetSession.parse_address(case[0])])


# --- Snapshots ------------------------------------------------------------------------

func test_player_snapshots_go_over_the_wire_and_come_back() -> void:
	var entries := [
		{"id": 1, "position": Vector3(1.5, 2, -3), "velocity": Vector3(8, -1, 0.25), "yaw": 1.0, "pitch": -0.3,
				"mode": MovementState.Mode.SLIDE, "flags": NetCodec.FLAG_ON_GROUND | NetCodec.FLAG_CROUCHED, "health": 73, "weapon": 4},
		{"id": -3, "position": Vector3(-50, 0, 90), "velocity": Vector3.ZERO, "yaw": -2.0, "pitch": 0.0,
				"mode": MovementState.Mode.AIR, "flags": NetCodec.FLAG_DEAD, "health": 0, "weapon": 0},
	]
	var bytes := NetCodec.encode_players(12, 3456, entries)
	check(bytes.size() == 7 + 2 * NetCodec.PLAYER_SIZE, "two players in %d bytes" % bytes.size())
	var back := NetCodec.decode_players(bytes)
	check(back.serial == 12 and back.tick == 3456 and back.players.size() == 2, "header")
	var p: Dictionary = back.players[0]
	check(p.id == 1 and p.position == Vector3(1.5, 2, -3) and p.velocity == Vector3(8, -1, 0.25), "position and speed")
	check(p.mode == MovementState.Mode.SLIDE and p.flags == 3 and p.health == 73 and p.weapon == 4, "mode, flags, health, weapon")
	check(back.players[1].id == -3 and back.players[1].flags == NetCodec.FLAG_DEAD, "a bot's negative id")
	check(NetCodec.weapon_of(4) == Weapons.get_def(Weapons.GUNS[3]) and NetCodec.weapon_of(0) == null and NetCodec.weapon_of(99) == null,
			"weapon ids")


func test_bad_snapshots_are_refused() -> void:
	var one := {"id": 1, "position": Vector3.ZERO, "velocity": Vector3.ZERO, "yaw": 0.0, "pitch": 0.0, "mode": 0, "flags": 0, "health": 100, "weapon": 0}
	var good := NetCodec.encode_players(1, 1, [one])
	check(not NetCodec.decode_players(good).is_empty(), "the good one's fine")
	check(NetCodec.decode_players(good.slice(0, good.size() - 1)).is_empty(), "short")
	for field: Array in [["position", Vector3(NAN, 0, 0)], ["velocity", Vector3(1e6, 0, 0)], ["position", Vector3(0, 1e9, 0)],
			["mode", 99], ["flags", 200], ["weapon", 50], ["pitch", 3.0]]:
		var bad := one.duplicate()
		bad[field[0]] = field[1]
		check(NetCodec.decode_players(NetCodec.encode_players(1, 1, [bad])).is_empty(), "%s = %s refused" % field)
	var liar := good.duplicate()
	liar[6] = 40  # Says 40 players, carries one.
	check(NetCodec.decode_players(liar).is_empty(), "a count that doesn't match")


func test_the_owners_state_round_trips_and_junk_is_refused() -> void:
	var st := MovementState.new()
	st.reset(MovementParams.new())
	st.mode = MovementState.Mode.WALLRIDE
	st.wallride_timer = 0.4
	st.wallride_normal = Vector3(1, 0, 0)
	st.dash_charges = 1
	var copy := MovementState.new()
	check(copy.from_array(st.to_array()) and copy.mode == st.mode and copy.wallride_timer == 0.4 and copy.dash_charges == 1
			and copy.wallride_normal == Vector3(1, 0, 0), "the whole movement state comes back")
	var arr := st.to_array()
	var short := arr.slice(0, arr.size() - 1)
	check(not copy.from_array(short), "too short")
	var wrong := arr.duplicate()
	wrong[0] = "ground"
	check(not copy.from_array(wrong), "a field of the wrong type")
	var nan := arr.duplicate()
	for i in nan.size():
		if nan[i] is float:
			nan[i] = NAN
			break
	check(not copy.from_array(nan), "NaN")
	var mode := arr.duplicate()
	mode[0] = 42
	check(not copy.from_array(mode), "a mode that doesn't exist")
	check(copy.mode == st.mode, "and nothing was set by the bad ones")
	var packet := NetCodec.pack_owner(77, st, Vector3(1, 2, 3), Vector3(4, 5, 6), 12, 3)
	var got := NetCodec.decode_owner(packet)
	check(got.size() == 6 and got.ack == 77 and got.position == Vector3(1, 2, 3) and got.velocity == Vector3(4, 5, 6)
			and got.ammo == 12 and got.weapon == 3, "a well-formed owner packet")
	var back := MovementState.new()
	check(back.from_array(got.state) and back.to_array() == st.to_array(), "and the state inside it is exactly the server's")
	check(NetCodec.decode_owner(packet.slice(0, packet.size() - 1)).is_empty(), "short")
	check(NetCodec.decode_owner(packet + PackedByteArray([0])).is_empty(), "long")
	check(NetCodec.decode_owner(NetCodec.pack_owner(1, st, Vector3.ZERO, Vector3(1e7, 0, 0), 5, 0)).is_empty(), "impossible speed")
	check(NetCodec.decode_owner(NetCodec.pack_owner(1, st, Vector3.ZERO, Vector3.ZERO, 5, 99)).is_empty(), "an unknown weapon")
	check(NetCodec.decode_owner(var_to_bytes("hello")).is_empty(), "not even the right size")


# --- Prediction ------------------------------------------------------------------------

## Prediction's promise (Prediction): when the server's word on an old tick
## arrives (between physics ticks, as network messages do), going back to it
## and replaying the commands since lands exactly where the server will be.
## A "server" body and a predicted "client" body run the same commands,
## sliding along a wall; the client is knocked off course once, is put right,
## and from then on agrees with the server to the millimetre.
func test_prediction_puts_itself_right_and_then_agrees_with_the_server() -> void:
	var world := Node3D.new()
	add_child(world)
	for part: Array in [["Floor", Vector3(0, -0.5, 0), Vector3(40, 1, 40)], ["WallL", Vector3(-1.5, 1, 0), Vector3(0.4, 2, 40)],
			["WallR", Vector3(1.5, 1, 0), Vector3(0.4, 2, 40)]]:
		var body := StaticBody3D.new()
		body.name = part[0]
		var col := CollisionShape3D.new()
		col.shape = BoxShape3D.new()
		(col.shape as BoxShape3D).size = part[2]
		body.add_child(col)
		body.position = part[1]
		world.add_child(body)
	var bodies: Array[Player] = []
	for i in 2:
		var p: Player = load("res://scenes/player.tscn").instantiate()
		p.human_controlled = false
		p.movement_params = MovementParams.new()
		p.view_settings = ViewSettings.new()
		world.add_child(p)
		p.set_process(false)
		p.set_physics_process(true)  # Ticking on its own, like your own player.
		p.spawn_at(Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 10)))
		bodies.append(p)
	var server := bodies[0]
	var client := bodies[1]
	# Forward and a little to the side: into the right-hand wall, then along it.
	var walk := func() -> InputCommand:
		var c := InputCommand.new()
		c.move = Vector2(0.35, 1.0).limit_length(1.0)
		c.yaw = 0.0
		return c
	server.input_override = walk
	client.input_override = walk
	var owners := {}
	var ran := [0]
	server.after_tick = func(_cmd: InputCommand) -> void:
		ran[0] += 1
		owners[ran[0]] = NetCodec.encode_owner(ran[0], server)
	var pred := Prediction.new()
	pred.player = client
	client.add_child(pred)
	const LATENCY := 4
	var knocked := false
	var late := -1
	var frame := 0
	while pred.tick < 150 and frame < 100000:
		await get_tree().process_frame
		frame += 1
		if pred.tick >= 20 and not knocked:
			knocked = true
			client.global_position += Vector3(0.3, 0, 0.2)  # A spawn raced a command, say.
		if pred.tick >= 100 and late < 0:
			late = pred.corrections
		if pred.tick > LATENCY and frame % 2 == 0 and owners.has(pred.tick - LATENCY):
			pred.reconcile(NetCodec.decode_owner(owners[pred.tick - LATENCY]))
	check(pred.tick == ran[0], "the two ran in step (%d and %d ticks)" % [pred.tick, ran[0]])
	check(server.global_position.z < 5.0 and server.global_position.x > 0.8, "they walked up the corridor against the wall: %s" % server.global_position)
	check(pred.corrections >= 1 and pred.corrections <= 3, "put right after the knock (%d corrections)" % pred.corrections)
	check(pred.corrections == late, "and none after that")
	check(client.global_position.distance_to(server.global_position) < 0.001,
			"agreeing with the server: %s and %s" % [client.global_position, server.global_position])
	world.queue_free()


# --- Finding public games -------------------------------------------------------------

## Runs frames until `cond` holds (at most `max_frames`). Whether it did.
func until_frames(cond: Callable, max_frames := 600) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func test_what_anyone_says_about_a_game_is_checked() -> void:
	var good := {"id": "abc", "name": "  my\ngame  ", "style": "teams", "map": "depot", "players": 3.0, "bots": 2.0,
			"max": 8.0, "locked": true, "protocol": float(NetCodec.PROTOCOL), "port": 27960.0}
	var g := ServerList.clean(good, "192.168.1.5", true)
	check(g.name == "mygame" and g.style == "teams" and g.map == "depot", "names cleaned, style and map kept: %s" % g)
	check(g.players == 3 and g.bots == 2 and g.max == 8 and g.locked and g.port == 27960, "numbers made whole")
	check(g.address == "192.168.1.5" and g.lan and g.id == "abc", "where it is, and that it's on this network")
	check(ServerList.clean(good, "not an address").is_empty(), "a bad address is refused")
	for port: Variant in [0.0, 70000.0, "27960", NAN, null]:
		var bad := good.duplicate()
		bad.port = port
		check(ServerList.clean(bad, "10.0.0.1").is_empty(), "so is port %s" % [port])
	var odd := good.duplicate()
	odd.merge({"style": "hax", "map": "../../etc/passwd", "players": 1e12, "max": NAN, "locked": "yes", "name": "x".repeat(500),
			"id": "y".repeat(100)}, true)
	var o := ServerList.clean(odd, "10.0.0.1")
	check(o.style == "" and o.map == "" and o.players == NetSession.PLAYER_LIMIT and o.max == 1 and not o.locked,
			"out of range or unknown: made safe (%s)" % o)
	check((o.name as String).length() <= 32 and o.id == "10.0.0.1:27960", "long names cut, long ids replaced")
	check(ServerList.clean([1, 2], "10.0.0.1").is_empty() and ServerList.clean("x", "10.0.0.1").is_empty(), "not a game at all")
	var survived := 0
	for i in 2000:
		var junk := {}
		for k in randi() % 12:
			var keys := ["id", "name", "style", "map", "players", "bots", "max", "locked", "protocol", "port", "zzz"]
			var values: Array = [randf() * 1e6 - 5e5, randi(), "s", true, null, [1], {}, NAN, INF, "teams", "stack", 27960.0]
			junk[keys.pick_random()] = values.pick_random()
		var c := ServerList.clean(junk, "10.0.0.2")
		if c.is_empty() or (c.port >= 1 and c.port <= 65535 and (c.name as String).length() <= 32 and c.max >= 1):
			survived += 1
	check(survived == 2000, "random junk never gets through wrong (%d/2000)" % survived)
	check(ServerList.is_local("192.168.0.9") and ServerList.is_local("127.0.0.1") and ServerList.is_local("172.20.1.1")
			and not ServerList.is_local("8.8.8.8") and not ServerList.is_local("172.40.0.1"), "local addresses are told apart")


func test_the_search_box_and_list_server_addresses() -> void:
	var g := {"name": "Friday Night Frag", "style": "teams", "map": "depot"}
	check(ServerList.matches(g, "") and ServerList.matches(g, "friday") and ServerList.matches(g, "TEAMS  depot")
			and not ServerList.matches(g, "rift") and not ServerList.matches(g, "friday rift"), "every word typed must be in it somewhere")
	check(ServerList.list_address("") == [] and ServerList.list_address("a b") == [], "no list server, or nonsense")
	check(ServerList.list_address("lists.example.com") == ["lists.example.com", ServerList.LIST_PORT], "no port: the list server's")
	check(ServerList.list_address("1.2.3.4:9000") == ["1.2.3.4", 9000], "or the one given")
	check(ServerList.list_address("::1") == ["::1", ServerList.LIST_PORT] and ServerList.list_address("[::1]:9000") == ["::1", 9000],
			"IPv6 too")
	var conn := {"buf": '{"a": 1}\nnot json\n{"b"'.to_utf8_buffer()}
	var lines := ServerList.take_lines(conn)
	check(lines.size() == 2 and lines[0] is Dictionary and lines[0].a == 1.0 and lines[1] == null, "whole lines come out, junk as null")
	check((conn.buf as PackedByteArray).get_string_from_utf8() == '{"b"', "and the rest waits")
	var long := {"buf": "x".repeat(ServerList.MAX_LINE + 1).to_utf8_buffer()}
	check(ServerList.take_lines(long) == [false], "a line too long says to hang up")


func test_public_games_are_found_on_this_network_and_on_a_list_server() -> void:
	var list := MasterServer.new()
	list.port = 27952
	check(list.start() == OK, "a list server")
	add_child(list)
	var rules := GameRules.teams()
	rules.max_health = 150.0
	check(NetSession.host(get_tree(), 27983, rules, 8, "secret", false, "find me") == OK, "hosting")
	await get_tree().process_frame
	var s := NetSession.current
	s.advertise(true, "127.0.0.1:27952")
	check(await until_frames(func() -> bool: return list.games().size() == 1), "it lists itself")
	var listed: Dictionary = list.games()[0] if not list.games().is_empty() else {}
	check(listed.get("name") == "find me" and listed.get("locked") == true and listed.get("port") == 27983
			and listed.get("style") == "teams" and listed.get("players") == 1, "as it is: %s" % listed)
	check(await until_frames(func() -> bool: return s.advert.listed_as == "127.0.0.1:27983"), "and hears where (%s)" % s.advert.listed_as)
	var browser := ServerBrowser.new()
	add_child(browser)
	# (Only this one counts: any other public game about is found too.)
	var mine := func() -> Array: return browser.found.filter(func(g: Dictionary) -> bool: return g.name == "find me")
	browser.refresh("127.0.0.1:27952")
	check(await until_frames(func() -> bool: return not browser.searching), "the browser looks")
	check(browser.list_error == "" and mine.call().size() == 1, "and finds it once, from here and from the list (%s)" % [browser.found])
	var found: Dictionary = mine.call()[0] if not mine.call().is_empty() else {}
	check(found.get("lan") == true and found.get("locked") == true and found.get("name") == "find me", "on this network, locked")
	check(browser.matching("FIND").size() == 1 and browser.matching("teams find me").size() == 1
			and browser.matching("find me rift").is_empty(), "search narrows it down")
	s.add_bots(2)
	check(await until_frames(func() -> bool: return list.games().size() == 1 and list.games()[0].bots == 2, 900),
			"the list hears when things change")
	# Junk at the list server: hung up on.
	for junk: String in ["not json\n", '{"op": "host", "port": 0}\n', '{"op": "boom"}\n', "x".repeat(ServerList.MAX_LINE + 10)]:
		var peer := StreamPeerTCP.new()
		peer.connect_to_host("127.0.0.1", 27952)
		await until_frames(func() -> bool:
			peer.poll()
			return peer.get_status() == StreamPeerTCP.STATUS_CONNECTED)
		peer.put_data(junk.to_utf8_buffer())
		check(await until_frames(func() -> bool:
			peer.poll()
			return peer.get_status() != StreamPeerTCP.STATUS_CONNECTED), "hung up on: %s" % junk.left(24))
	check(list.games().size() == 1, "and the real one's still listed")
	# Private again: gone from the list, and from this network.
	s.advertise(false)
	check(await until_frames(func() -> bool: return list.games().is_empty()), "off the list once it's private")
	browser.refresh("127.0.0.1:27952")
	check(await until_frames(func() -> bool: return not browser.searching), "looked again")
	check(mine.call().is_empty(), "and it's not found (%s)" % [browser.found])
	browser.refresh("127.0.0.1:27953")
	check(await until_frames(func() -> bool: return not browser.searching, 900), "a list server that isn't there")
	check(browser.list_error != "", "says so (%s)" % browser.list_error)
	NetSession.leave(get_tree())
	browser.queue_free()
	list.queue_free()
	await get_tree().process_frame


func test_a_dedicated_servers_options_come_from_its_config_and_command_line() -> void:
	var path := "user://test_server.cfg"
	var cfg := ConfigFile.new()
	cfg.set_value("server", "public", true)
	cfg.set_value("server", "list", "lists.example.com")
	cfg.set_value("rules", "max_health", 150)
	cfg.set_value("rules", "guns", ["rifle", "nuke"])
	cfg.set_value("rules", "regen_delay", "soon")
	cfg.set_value("rules", "round_wins", 3)
	cfg.save(path)
	var s := DedicatedServer.settings(PackedStringArray(["--config", ProjectSettings.globalize_path(path), "--round-time", "45",
			"--rounds", "7"]))
	check(s.public and s.list == "lists.example.com", "public, on the list server it names")
	var r := DedicatedServer.rules_for(s.mode, s.rules)
	check(r.max_health == 150.0 and r.guns == PackedStringArray(["rifle"]), "the config's options, checked (%s, %s)" % [r.max_health, r.guns])
	check(r.round_time == 45.0 and r.round_wins == 7, "the command line's win")
	check(r.regen_delay == GameRules.free_for_all().regen_delay, "and nonsense is ignored")
	var teams := DedicatedServer.rules_for("teams", {"score": "x", "score_to_win": "30", "time_limit": "300"})
	check(teams.is_teams() and teams.score_to_win == 30 and teams.time_limit == 300.0, "teams too")
	check(not DedicatedServer.settings(PackedStringArray()).public, "private unless it's asked")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
