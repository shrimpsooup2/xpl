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
