class_name NetCodec
extends RefCounted
## What goes over the wire, and checking what comes off it
## (docs/NETWORKING.md). Everything is plain bytes and numbers, packed by
## hand: nothing here ever decodes an object, and every decoder returns an
## empty result for anything that isn't exactly what it should be (wrong
## size, a number out of range, NaN or infinity, unknown bits), so junk off
## the network is dropped before the game sees it.
##
##   inputs (client → server, every tick): the last few commands, each
##     tick u32 · move 2×s16 · yaw, pitch f32 · buttons u16 · switch u8 ·
##     view tick u32 (sixteenths of a server tick; all ones for none)
##   players (server → clients, 30 Hz): level serial u16 · server tick u32 ·
##     count u8, then per player
##     id s32 · position 3×f32 · velocity 3×f32 · yaw, pitch f32 ·
##     mode u8 · flags u8 · health u8 · weapon u8
##   owner (server → one client, with players): the last input tick the
##     server ran u32 · your whole movement state, field by field (bool u8,
##     int s64, float f64, vector 3×f32) · position, velocity 3×f32 ·
##     ammo u16 · weapon u8
##   pickups (server → clients, with players, when any moved or changed):
##     level serial u16 · count u8, then per loose weapon lying about
##     id u16 · position 3×f32 · rotation 4×f32 (a quaternion) · ammo u16

## Bumped whenever any message changes shape: old and new builds refuse each
## other at the handshake.
const PROTOCOL := 5
const INPUT_SIZE := 23
## View ticks go in sixteenths of a tick; this means "none" (now).
const VIEW_STEPS := 16.0
const NO_VIEW := 0xFFFFFFFF
## Commands per input packet: the newest and the few before it, so one lost
## packet loses nothing.
const INPUT_REDUNDANCY := 3
const MAX_PLAYERS_PER_SNAPSHOT := 32
const PLAYER_SIZE := 40
const PICKUP_SIZE := 32
const MAX_PICKUPS_PER_PACKET := 64
const MOVE_SCALE := 32767.0
## View angles past this are junk (yaw can wind up, but not this far).
const MAX_YAW := 10000.0
const MAX_PITCH := 1.6
## Positions and speeds past these are junk.
const MAX_COORD := 100000.0
const MAX_SPEED := 1000.0

## Button flags, one bit each, in this order.
const BUTTONS := [&"jump_pressed", &"jump_held", &"crouch_pressed", &"crouch_held", &"dash_pressed", &"fire_pressed",
		&"fire_held", &"alt_pressed", &"alt_held", &"interact_pressed", &"throw_pressed"]

## Player flags.
const FLAG_ON_GROUND := 1
const FLAG_CROUCHED := 2
const FLAG_DEAD := 4

static var _types := PackedInt32Array()


# --- Inputs ---------------------------------------------------------------------------

## [[tick, InputCommand], ...], oldest first (at most INPUT_REDUNDANCY + 1).
static func encode_inputs(entries: Array) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.put_u8(entries.size())
	for e: Array in entries:
		_put_input(buf, e[0], e[1])
	return buf.data_array


## The commands in a packet, oldest first, or [] if it isn't a valid one.
static func decode_inputs(bytes: PackedByteArray) -> Array:
	if bytes.size() < 1:
		return []
	var count := bytes[0]
	if count < 1 or count > INPUT_REDUNDANCY + 1 or bytes.size() != 1 + count * INPUT_SIZE:
		return []
	var buf := StreamPeerBuffer.new()
	buf.data_array = bytes
	buf.seek(1)
	var out := []
	for i in count:
		var entry := _get_input(buf)
		if entry.is_empty():
			return []
		out.append(entry)
	return out


static func _put_input(buf: StreamPeerBuffer, tick: int, cmd: InputCommand) -> void:
	buf.put_u32(tick)
	var move := cmd.move.limit_length(1.0)
	buf.put_16(roundi(move.x * MOVE_SCALE))
	buf.put_16(roundi(move.y * MOVE_SCALE))
	buf.put_float(cmd.yaw)
	buf.put_float(cmd.pitch)
	var bits := 0
	for i in BUTTONS.size():
		if cmd.get(BUTTONS[i]):
			bits |= 1 << i
	buf.put_u16(bits)
	buf.put_u8(clampi(cmd.switch_to, 0, 3))
	var view := roundi(cmd.view_tick * VIEW_STEPS) if cmd.view_tick >= 0.0 and is_finite(cmd.view_tick) else NO_VIEW
	buf.put_u32(clampi(view, 0, NO_VIEW))


static func _get_input(buf: StreamPeerBuffer) -> Array:
	var tick := buf.get_u32()
	var move := Vector2(buf.get_16() / MOVE_SCALE, buf.get_16() / MOVE_SCALE)
	var yaw := buf.get_float()
	var pitch := buf.get_float()
	var bits := buf.get_u16()
	var switch_to := buf.get_u8()
	var view := buf.get_u32()
	if not is_finite(yaw) or not is_finite(pitch) or absf(yaw) > MAX_YAW or absf(pitch) > MAX_PITCH:
		return []
	if bits >> BUTTONS.size() != 0 or switch_to > 3 or move.length() > 1.001:
		return []
	var cmd := InputCommand.new()
	cmd.move = move.limit_length(1.0)
	cmd.yaw = yaw
	cmd.pitch = pitch
	for i in BUTTONS.size():
		cmd.set(BUTTONS[i], bits & (1 << i) != 0)
	cmd.switch_to = switch_to
	cmd.view_tick = -1.0 if view == NO_VIEW else view / VIEW_STEPS
	return [tick, cmd]


# --- Players --------------------------------------------------------------------------

## A snapshot of players: entries are dictionaries with id, position,
## velocity, yaw, pitch, mode, flags, health and weapon.
static func encode_players(serial: int, server_tick: int, entries: Array) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.put_u16(serial & 0xFFFF)
	buf.put_u32(server_tick)
	buf.put_u8(mini(entries.size(), MAX_PLAYERS_PER_SNAPSHOT))
	for i in mini(entries.size(), MAX_PLAYERS_PER_SNAPSHOT):
		var e: Dictionary = entries[i]
		buf.put_32(e.id)
		for v: Vector3 in [e.position, e.velocity]:
			buf.put_float(v.x)
			buf.put_float(v.y)
			buf.put_float(v.z)
		buf.put_float(e.yaw)
		buf.put_float(e.pitch)
		buf.put_u8(e.mode)
		buf.put_u8(e.flags)
		buf.put_u8(clampi(roundi(e.health), 0, 255))
		buf.put_u8(e.weapon)
	return buf.data_array


## {serial, tick, players: [...]} or {} if it isn't a valid snapshot.
static func decode_players(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 7:
		return {}
	var buf := StreamPeerBuffer.new()
	buf.data_array = bytes
	var serial := buf.get_u16()
	var tick := buf.get_u32()
	var count := buf.get_u8()
	if count > MAX_PLAYERS_PER_SNAPSHOT or bytes.size() != 7 + count * PLAYER_SIZE:
		return {}
	var players := []
	for i in count:
		var e := {"id": buf.get_32()}
		var pos := Vector3(buf.get_float(), buf.get_float(), buf.get_float())
		var vel := Vector3(buf.get_float(), buf.get_float(), buf.get_float())
		var yaw := buf.get_float()
		var pitch := buf.get_float()
		e.mode = buf.get_u8()
		e.flags = buf.get_u8()
		e.health = buf.get_u8()
		e.weapon = buf.get_u8()
		if not pos.is_finite() or not vel.is_finite() or not is_finite(yaw) or not is_finite(pitch):
			return {}
		if absf(pos.x) > MAX_COORD or absf(pos.y) > MAX_COORD or absf(pos.z) > MAX_COORD or vel.length() > MAX_SPEED:
			return {}
		if absf(yaw) > MAX_YAW or absf(pitch) > MAX_PITCH or e.mode >= MovementState.Mode.size() or e.flags > 7:
			return {}
		if e.weapon > Weapons.GUNS.size():
			return {}
		e.position = pos
		e.velocity = vel
		e.yaw = yaw
		e.pitch = pitch
		players.append(e)
	return {"serial": serial, "tick": tick, "players": players}


## A player's snapshot entry.
static func player_entry(id: int, p: Player) -> Dictionary:
	var flags := 0
	if p.state.on_ground:
		flags |= FLAG_ON_GROUND
	if p.state.crouched:
		flags |= FLAG_CROUCHED
	if p.is_dead:
		flags |= FLAG_DEAD
	return {"id": id, "position": p.global_position, "velocity": p.velocity, "yaw": wrapf(p.yaw, -PI, PI),
			"pitch": p.pitch, "mode": p.state.mode, "flags": flags, "health": p.health, "weapon": weapon_id(p.weapons.primary)}


## A weapon on the wire: 0 for none (fists), else its place in Weapons.GUNS + 1.
static func weapon_id(def: WeaponDef) -> int:
	if def == null or def.is_fists():
		return 0
	return Weapons.GUNS.find(def.id) + 1


## The weapon a wire id stands for, or null (none, or an unknown id).
static func weapon_of(id: int) -> WeaponDef:
	if id <= 0 or id > Weapons.GUNS.size():
		return null
	return Weapons.get_def(Weapons.GUNS[id - 1])


# --- Loose weapons -------------------------------------------------------------------

## [{id, position, rotation: Quaternion, ammo}, ...] for level `serial`.
static func encode_pickups(serial: int, entries: Array) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.put_u16(serial & 0xFFFF)
	buf.put_u8(mini(entries.size(), MAX_PICKUPS_PER_PACKET))
	for e: Dictionary in entries.slice(0, MAX_PICKUPS_PER_PACKET):
		buf.put_u16(e.id)
		_put_vector(buf, e.position)
		var q: Quaternion = e.rotation
		for v in [q.x, q.y, q.z, q.w]:
			buf.put_float(v)
		buf.put_u16(clampi(e.ammo, 0, 65535))
	return buf.data_array


## {serial, pickups: [...]} or {} if it isn't a valid packet.
static func decode_pickups(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 3:
		return {}
	var count := bytes[2]
	if count > MAX_PICKUPS_PER_PACKET or bytes.size() != 3 + count * PICKUP_SIZE:
		return {}
	var buf := StreamPeerBuffer.new()
	buf.data_array = bytes
	var serial := buf.get_u16()
	buf.seek(3)
	var out := []
	for i in count:
		var e := {"id": buf.get_u16(), "position": _get_vector(buf)}
		var q := Quaternion(buf.get_float(), buf.get_float(), buf.get_float(), buf.get_float())
		e.ammo = buf.get_u16()
		var pos: Vector3 = e.position
		if not pos.is_finite() or absf(pos.x) > MAX_COORD or absf(pos.y) > MAX_COORD or absf(pos.z) > MAX_COORD:
			return {}
		if not q.is_finite() or absf(q.length() - 1.0) > 0.01 or e.ammo > 1000:
			return {}
		e.rotation = q.normalized()
		out.append(e)
	return {"serial": serial, "pickups": out}


# --- Your own player ------------------------------------------------------------------

## What the server tells a client about its own player, to reconcile with.
static func encode_owner(ack_tick: int, p: Player) -> PackedByteArray:
	return pack_owner(ack_tick, p.state, p.global_position, p.velocity, p.weapons.primary_ammo, weapon_id(p.weapons.primary))


static func pack_owner(ack_tick: int, st: MovementState, pos: Vector3, vel: Vector3, ammo: int, weapon: int) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.put_u32(ack_tick)
	for v: Variant in st.to_array():
		match typeof(v):
			TYPE_BOOL:
				buf.put_u8(1 if v else 0)
			TYPE_INT:
				buf.put_64(v)
			TYPE_FLOAT:
				buf.put_double(v)
			TYPE_VECTOR3:
				_put_vector(buf, v)
	_put_vector(buf, pos)
	_put_vector(buf, vel)
	buf.put_u16(clampi(ammo, 0, 65535))
	buf.put_u8(weapon)
	return buf.data_array


## {ack, state, position, velocity, ammo, weapon} or {} if it isn't valid.
## The state (an Array, MovementState.to_array's shape) is checked field by
## field when it's applied (MovementState.from_array).
static func decode_owner(bytes: PackedByteArray) -> Dictionary:
	var types := _state_types()
	if bytes.size() != _owner_size(types):
		return {}
	var buf := StreamPeerBuffer.new()
	buf.data_array = bytes
	var ack := buf.get_u32()
	var st := []
	for t: int in types:
		match t:
			TYPE_BOOL:
				var b := buf.get_u8()
				if b > 1:
					return {}
				st.append(b == 1)
			TYPE_INT:
				st.append(buf.get_64())
			TYPE_FLOAT:
				st.append(buf.get_double())
			TYPE_VECTOR3:
				st.append(_get_vector(buf))
	var pos := _get_vector(buf)
	var vel := _get_vector(buf)
	var ammo := buf.get_u16()
	var weapon := buf.get_u8()
	if not pos.is_finite() or not vel.is_finite() or vel.length() > MAX_SPEED or absf(pos.x) > MAX_COORD \
			or absf(pos.y) > MAX_COORD or absf(pos.z) > MAX_COORD or ammo > 1000 or weapon > Weapons.GUNS.size():
		return {}
	return {"ack": ack, "state": st, "position": pos, "velocity": vel, "ammo": ammo, "weapon": weapon}


## The type of each MovementState field, in to_array() order.
static func _state_types() -> PackedInt32Array:
	if _types.is_empty():
		for v: Variant in MovementState.new().to_array():
			_types.append(typeof(v))
	return _types


static func _owner_size(types: PackedInt32Array) -> int:
	var n := 4 + 12 + 12 + 2 + 1
	for t in types:
		n += {TYPE_BOOL: 1, TYPE_INT: 8, TYPE_FLOAT: 8, TYPE_VECTOR3: 12}.get(t, 0)
	return n


static func _put_vector(buf: StreamPeerBuffer, v: Vector3) -> void:
	buf.put_float(v.x)
	buf.put_float(v.y)
	buf.put_float(v.z)


static func _get_vector(buf: StreamPeerBuffer) -> Vector3:
	return Vector3(buf.get_float(), buf.get_float(), buf.get_float())
