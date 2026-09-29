class_name MatchSync
extends Node
## Keeps a networked game in step (docs/NETWORKING.md). It sits under the
## Match on every machine (the same path everywhere, so messages find it).
##
## On the server it:
##   runs every remote player's body on the inputs that player's client
##     sends (a queue per player, one command per tick; a missing one is
##     replaced by the last, its presses let go);
##   sends every client a snapshot of every player 30 times a second, and
##     each client its own player's full movement state and the last input
##     the server ran, to reconcile with;
##   sends events as they happen: maps loading, spawns, damage, deaths,
##     shots fired, what everyone's holding, pads, the match's state, scores,
##     kills, rounds and the result;
##   keeps clients' copies of the loose weapons lying about (dropped on
##     death, swapped out, thrown): each one's arrival, where it is while it
##     moves (with the snapshots), and when it's gone.
## On a client it applies all of that: its own player is predicted
## (Prediction), everyone else is a puppet (Puppet), and the Match follows
## the server's state and fires the same signals, so the UI works the same
## as offline. Nothing a client sends does more than ask; everything it's
## sent is checked.

const SNAPSHOT_EVERY := 2
## Commands the server keeps queued per player before it drops the oldest
## (a client running ahead, or a burst after a hitch).
const MAX_QUEUE := 12

var match_ref: Match
var server_tick := 0

## Server: peer id → {queue: {tick: InputCommand}, next: int, ran: int}.
var _inputs := {}
## Server: peer id → the level (serial) it last said it had loaded.
var _loaded := {}
## Loose weapons, by the id they have on the wire (this level's).
var _pickups := {}
## Server: pickup → [id, what was last sent (position, rotation, ammo)].
var _pickup_ids := {}
var _next_pickup := 0
## Client: pickup id → where the server last had it.
var _pickup_targets := {}
## A player whose queue has more than this runs two commands a tick until
## it's caught up (a burst after a hitch shouldn't turn into lasting lag).
const CATCH_UP_ABOVE := 3


func _ready() -> void:
	match_ref = get_parent() as Match
	if match_ref.authority:
		match_ref.state_changed.connect(func(_s: int) -> void: _send_state())
		match_ref.scores_changed.connect(_send_state)
		match_ref.kill_feed.connect(_on_kill_feed)
		match_ref.round_decided.connect(func(w: PlayerInfo) -> void: _round_decided.rpc(w.id if w else 0))
		match_ref.match_decided.connect(func(w: PlayerInfo, team: int) -> void: _match_decided.rpc(w.id if w else 0, team))
		match_ref.level_ready.connect(_on_server_level)
		match_ref.map_changing.connect(func(m: String, serial: int) -> void: _load_map.rpc(m, serial))
		match_ref.spawned.connect(_on_spawned)
		get_tree().node_added.connect(_on_node_added)


func _is_server() -> bool:
	return match_ref.authority and NetSession.active()


# --- Server: bodies, inputs, snapshots ----------------------------------------------------

func _on_server_level(_level: Node) -> void:
	_pickups.clear()
	_pickup_ids.clear()
	for info in match_ref.infos:
		on_body_added(info)
	for pad in Match._all_of(match_ref.level, "WeaponPad"):
		var path := match_ref.level.get_path_to(pad)
		pad.changed.connect(func(ready: bool) -> void: _pad.rpc(match_ref.serial, path, ready))
	for box in Match._all_of(match_ref.level, "AmmoBox"):
		var path := match_ref.level.get_path_to(box)
		box.changed.connect(func(ready: bool) -> void: _ammo_box.rpc(match_ref.serial, path, ready))


## Hooks a player's body up (the server): its hits, death, shots and hands
## are sent to the clients, and a client's player runs on its inputs.
func on_body_added(info: PlayerInfo) -> void:
	if not _is_server():
		return
	var body := info.player
	if body == null:
		return
	body.hurt.connect(_on_hurt.bind(info))
	body.killed.connect(_on_died.bind(info))
	body.weapons.fired.connect(_on_fired.bind(info))
	body.weapons.equipped.connect(func(_d: WeaponDef, _a: int) -> void: _send_loadout(info))
	body.weapons.ammo_changed.connect(func(_a: int, _c: int) -> void: _on_ammo(info))
	if info.id > 1:  # A client's player: run it on what that client sends.
		_inputs[info.id] = {"queue": {}, "next": -1, "ran": -1}
		body.drive_with(_commands_for.bind(info.id))


## A client's commands, oldest first, newest last.
@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _client_inputs(bytes: PackedByteArray) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not _is_server() or not _inputs.has(id):
		return
	var entries := NetCodec.decode_inputs(bytes)
	if entries.is_empty():
		NetSession.current.strike(id, "bad input packet")
		return
	var q: Dictionary = _inputs[id]
	for e: Array in entries:
		var tick: int = e[0]
		if tick <= q.ran or q.queue.has(tick):
			continue  # Already run, or a repeat.
		q.queue[tick] = e[1]
	while q.queue.size() > MAX_QUEUE:
		var oldest: int = q.queue.keys().min()
		q.queue.erase(oldest)
		q.next = maxi(q.next, oldest + 1)


## The commands to run client `id`'s player on this tick, in order: its
## next one, two while it's catching up, or none while the next hasn't come
## (the player waits for it rather than the server guessing: prediction and
## the server then run exactly the same commands). A command that never came
## (no later packet carried it) is skipped.
func _commands_for(id: int) -> Array:
	var q: Dictionary = _inputs.get(id, {})
	if q.is_empty() or q.queue.is_empty():
		return []
	var first: int = q.queue.keys().min()
	if q.next < 0 or first > q.next:
		q.next = first
	var out := []
	for i in (2 if q.queue.size() > CATCH_UP_ABOVE else 1):
		if not q.queue.has(q.next):
			break
		out.append(q.queue[q.next])
		q.queue.erase(q.next)
		q.ran = q.next
		q.next += 1
	return out


func _physics_process(_delta: float) -> void:
	if not _is_server() or match_ref.level == null or match_ref.state == Match.State.LOADING:
		return
	server_tick += 1
	if server_tick % SNAPSHOT_EVERY != 0:
		return
	var entries := []
	for info in match_ref.infos:
		if info.player and is_instance_valid(info.player):
			entries.append(NetCodec.player_entry(info.id, info.player))
	var bytes := NetCodec.encode_players(match_ref.serial, server_tick, entries)
	_send_moved_pickups()
	for id: int in multiplayer.get_peers():
		var mine := match_ref.info_by_id(id)
		var owner := PackedByteArray()
		if mine and mine.player and is_instance_valid(mine.player) and _inputs.has(id):
			owner = NetCodec.encode_owner(_inputs[id].ran, mine.player)
		_snapshot.rpc_id(id, bytes, owner)


# --- Server: loose weapons ---------------------------------------------------------------

func _on_node_added(node: Node) -> void:
	if node is WeaponPickup and _is_server():
		_track_pickup.call_deferred(node)  # Once it's been thrown or put on a pad.


## A weapon just appeared in the level: a loose one gets an id, and the
## clients get a copy.
func _track_pickup(pickup: WeaponPickup) -> void:
	if not is_instance_valid(pickup) or pickup.pad or match_ref.level == null or not match_ref.level.is_ancestor_of(pickup):
		return
	_next_pickup = (_next_pickup + 1) % 65536
	var id := _next_pickup
	var serial := match_ref.serial
	_pickups[id] = pickup
	_pickup_ids[pickup] = [id, _pickup_record(id, pickup)]
	pickup.tree_exiting.connect(func() -> void:
		_pickups.erase(id)
		_pickup_ids.erase(pickup)
		if _is_server() and match_ref.serial == serial:  # Not when the whole level goes.
			_pickup_gone.rpc(serial, id))
	_pickup_new.rpc(match_ref.serial, id, NetCodec.weapon_id(pickup.def), pickup.ammo, pickup.global_position,
			pickup.global_basis.get_rotation_quaternion(), pickup.linear_velocity)


func _pickup_record(id: int, pickup: WeaponPickup) -> Dictionary:
	return {"id": id, "position": pickup.global_position, "rotation": pickup.global_basis.get_rotation_quaternion(), "ammo": pickup.ammo}


## The loose weapons that moved (or were partly emptied) since last time.
func _send_moved_pickups() -> void:
	var moved := []
	for pickup: WeaponPickup in _pickup_ids.keys():
		if not is_instance_valid(pickup):
			continue
		var entry: Array = _pickup_ids[pickup]
		var now := _pickup_record(entry[0], pickup)
		var was: Dictionary = entry[1]
		if now.ammo != was.ammo or now.position.distance_to(was.position) > 0.005 or now.rotation.angle_to(was.rotation) > 0.01:
			entry[1] = now
			moved.append(now)
	if not moved.is_empty():
		_pickups_moved.rpc(NetCodec.encode_pickups(match_ref.serial, moved))


# --- Server: events -----------------------------------------------------------------------

func _send_state() -> void:
	if not _is_server():
		return
	var scores := []
	for info in match_ref.infos:
		scores.append([info.id, info.kills, info.deaths, info.heartshots, info.round_wins])
	_state.rpc(match_ref.serial, match_ref.state, match_ref.timer, match_ref.round_number, match_ref.team_scores.duplicate(),
			scores, match_ref.history.duplicate(true))


func _on_kill_feed(killer: PlayerInfo, victim: PlayerInfo, weapon_name: String, heartshot: bool) -> void:
	if _is_server():
		_kill.rpc(killer.id if killer else 0, victim.id, weapon_name, heartshot)


func _on_spawned(info: PlayerInfo, at: Transform3D) -> void:
	if _is_server():
		_spawned.rpc(match_ref.serial, info.id, at.origin, at.basis.get_euler().y, NetCodec.weapon_id(info.player.weapons.primary),
				info.player.weapons.primary_ammo)


func _on_hurt(hit: Dictionary, amount: float, info: PlayerInfo) -> void:
	if not _is_server():
		return
	var attacker: Player = hit.get("attacker")
	var by := match_ref.info_of(attacker)
	_hurt.rpc(match_ref.serial, info.id, by.id if by else 0, info.player.health, amount, hit.get("point", Vector3.ZERO),
			hit.get("direction", Vector3.FORWARD), String(hit.get("zone", &"body")), String(hit.get("part", &"chest")),
			bool(hit.get("heartshot", false)))


func _on_died(kill: Dictionary, info: PlayerInfo) -> void:
	if _is_server():
		_died.rpc(match_ref.serial, info.id)


func _on_fired(def: WeaponDef, shot: Dictionary, info: PlayerInfo) -> void:
	if not _is_server():
		return
	var body := info.player
	var aim := body.weapons.aim_direction()
	for id: int in multiplayer.get_peers():
		if id != info.id:  # The shooter drew its own shot already.
			_shot.rpc_id(id, match_ref.serial, info.id, NetCodec.weapon_id(def), body.weapons.eye_position(), aim,
					bool(shot.get("fanned", false)))


func _send_loadout(info: PlayerInfo) -> void:
	if _is_server() and info.player and is_instance_valid(info.player):
		var w := info.player.weapons
		_loadout.rpc(match_ref.serial, info.id, NetCodec.weapon_id(w.primary), w.primary_ammo, w.using_primary)


func _on_ammo(info: PlayerInfo) -> void:
	# Refills and pickups change ammo without a new weapon; shots do too,
	# but the shooter's own client already counted those.
	var w := info.player.weapons if info.player and is_instance_valid(info.player) else null
	if _is_server() and w and w.primary and w.primary_ammo == w.primary.ammo:
		_send_loadout(info)


## Tells a client that just joined the game in progress which map to load
## and the state; the rest once it's loaded (_level_loaded).
func catch_up(id: int) -> void:
	if not _is_server() or match_ref.map_name == "":
		return
	_load_map.rpc_id(id, match_ref.map_name, match_ref.serial)
	_send_state()


## A client has the current level loaded: everything it missed while it
## loaded, which it would have dropped (where everyone is and what they
## hold, who's down, the pads, the state).
@rpc("any_peer", "call_remote", "reliable")
func _level_loaded(serial: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not _is_server() or not NetSession.current.allow_request(id):
		return
	if serial != match_ref.serial or match_ref.level == null or match_ref.info_by_id(id) == null:
		return
	_loaded[id] = serial
	for info in match_ref.infos:
		var body := info.player
		if body == null or not is_instance_valid(body):
			continue
		_spawned.rpc_id(id, serial, info.id, body.global_position, wrapf(body.yaw, -PI, PI),
				NetCodec.weapon_id(body.weapons.primary), body.weapons.primary_ammo)
		if body.is_dead:
			_died.rpc_id(id, serial, info.id)
	for pad in Match._all_of(match_ref.level, "WeaponPad"):
		_pad.rpc_id(id, serial, match_ref.level.get_path_to(pad), pad.pickup != null)
	for box in Match._all_of(match_ref.level, "AmmoBox"):
		_ammo_box.rpc_id(id, serial, match_ref.level.get_path_to(box), box.available)
	for pickup_id: int in _pickups:
		var pickup: WeaponPickup = _pickups[pickup_id]
		if is_instance_valid(pickup):
			_pickup_new.rpc_id(id, serial, pickup_id, NetCodec.weapon_id(pickup.def), pickup.ammo, pickup.global_position,
					pickup.global_basis.get_rotation_quaternion(), Vector3.ZERO)
	_send_state()


## Whether every client in the game has the current level loaded (the
## server holds the countdown until then, for a while: Match.LOAD_WAIT).
func everyone_loaded() -> bool:
	for id: int in multiplayer.get_peers():
		if match_ref.info_by_id(id) and _loaded.get(id, 0) != match_ref.serial:
			return false
	return true


## The client: this level's loaded, so the server can catch it up (and
## hear which gun you've picked, in games where you pick).
func level_loaded() -> void:
	_pickups.clear()
	_pickup_targets.clear()
	if not match_ref.authority and NetSession.active():
		_level_loaded.rpc_id(1, match_ref.serial)
		if match_ref.rules.loadout:
			send_gun(Cosmetics.gun)


## The client: tells the server the gun you've picked.
func send_gun(id: StringName) -> void:
	if not match_ref.authority and NetSession.active():
		_choose_gun.rpc_id(1, NetCodec.weapon_id(Weapons.get_def(id)))


## A client picked its gun (games where you pick): one of the guns, or
## nothing happens.
@rpc("any_peer", "call_remote", "reliable")
func _choose_gun(weapon: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not _is_server() or not NetSession.current.allow_request(id):
		return
	var def := NetCodec.weapon_of(weapon)
	var info := match_ref.info_by_id(id)
	if def == null or info == null or not def.id in Weapons.GUNS:
		return
	match_ref.choose_gun(info, def.id)


# --- Client: receiving ---------------------------------------------------------------------

func _from_server() -> bool:
	return not match_ref.authority and multiplayer.get_remote_sender_id() == 1


func _current(serial: int) -> bool:
	return _from_server() and serial == match_ref.serial and match_ref.level != null


@rpc("authority", "call_remote", "reliable")
func _load_map(map: String, serial: int) -> void:
	if not _from_server() or Maps.scene_of(map) == "" or serial < match_ref.serial:
		return  # Only maps from the game's own list, by name.
	match_ref.load_map(map, serial)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _snapshot(players: PackedByteArray, owner: PackedByteArray) -> void:
	if not _from_server() or match_ref.level == null:
		return
	var snap := NetCodec.decode_players(players)
	if snap.is_empty() or snap.serial != (match_ref.serial & 0xFFFF):
		return
	for e: Dictionary in snap.players:
		var info := match_ref.info_by_id(e.id)
		if info == null or info.player == null or not is_instance_valid(info.player):
			continue
		if info.local:
			var mine := NetCodec.decode_owner(owner) if not owner.is_empty() else {}
			var pred := info.player.get_node_or_null(^"Prediction") as Prediction
			if pred and not mine.is_empty():
				pred.reconcile(mine)
			info.player.health = e.health
		else:
			var puppet := info.player.get_node_or_null(^"Puppet") as Puppet
			if puppet:
				puppet.push(snap.tick, e)


@rpc("authority", "call_remote", "reliable")
func _state(serial: int, state: int, timer: float, round_number: int, team_scores: Array, scores: Array, history: Array) -> void:
	if not _from_server() or serial != match_ref.serial:
		return
	if state < 0 or state >= Match.State.size() or not is_finite(timer) or team_scores.size() != 2 or scores.size() > 64 or history.size() > 64:
		return
	match_ref.apply_state(state, clampf(timer, 0.0, 100000.0), clampi(round_number, 0, 1000), [int(team_scores[0]), int(team_scores[1])],
			scores.filter(func(s: Variant) -> bool: return s is Array and (s as Array).size() == 5 and (s as Array).all(func(v: Variant) -> bool: return v is int)),
			history.filter(func(h: Variant) -> bool: return h is Array and (h as Array).size() == 2 and h[0] is String and h[1] is String))


@rpc("authority", "call_remote", "reliable")
func _kill(killer_id: int, victim_id: int, weapon_name: String, heartshot: bool) -> void:
	if not _from_server():
		return
	var victim := match_ref.info_by_id(victim_id)
	if victim:
		match_ref.kill_feed.emit(match_ref.info_by_id(killer_id), victim, weapon_name.left(32), heartshot)


@rpc("authority", "call_remote", "reliable")
func _round_decided(winner_id: int) -> void:
	if _from_server():
		match_ref.round_decided.emit(match_ref.info_by_id(winner_id))


@rpc("authority", "call_remote", "reliable")
func _match_decided(winner_id: int, team: int) -> void:
	if _from_server() and team >= -1 and team <= 1:
		match_ref.match_decided.emit(match_ref.info_by_id(winner_id), team)


@rpc("authority", "call_remote", "reliable")
func _spawned(serial: int, id: int, at: Vector3, yaw: float, weapon: int, ammo: int) -> void:
	if not _current(serial) or not at.is_finite() or not is_finite(yaw):
		return
	var info := match_ref.info_by_id(id)
	if info == null or info.player == null:
		return
	var body := info.player
	body.spawn_at(Transform3D(Basis(Vector3.UP, yaw), at))
	_apply_loadout(body, weapon, ammo, weapon != 0)
	var pred := body.get_node_or_null(^"Prediction") as Prediction
	if pred:
		pred.reset()
	var puppet := body.get_node_or_null(^"Puppet") as Puppet
	if puppet:
		puppet.reset()


@rpc("authority", "call_remote", "reliable")
func _hurt(serial: int, id: int, attacker_id: int, health: float, amount: float, point: Vector3, direction: Vector3,
		zone: String, part: String, heartshot: bool) -> void:
	if not _current(serial) or not point.is_finite() or not direction.is_finite() or not is_finite(health) or not is_finite(amount):
		return
	var info := match_ref.info_by_id(id)
	if info == null or info.player == null:
		return
	var body := info.player
	var attacker := match_ref.info_by_id(attacker_id)
	body.show_hurt(clampf(health, 0.0, body.max_health), clampf(amount, 0.0, 1000.0), point, direction,
			StringName(zone.left(16)), StringName(part.left(16)), heartshot, attacker != null and attacker.local)
	if attacker and attacker.local and attacker.player:
		# Your hit: the server says it landed.
		attacker.player.weapons.confirm_hit({"target": body, "name": info.player_name, "damage": amount, "zone": StringName(zone.left(16)),
				"heartshot": heartshot, "killed": health <= 0.0, "weapon": attacker.player.weapons.current})


@rpc("authority", "call_remote", "reliable")
func _died(serial: int, id: int) -> void:
	if not _current(serial):
		return
	var info := match_ref.info_by_id(id)
	if info and info.player and not info.player.is_dead:
		info.player.die()


@rpc("authority", "call_remote", "unreliable_ordered", 3)
func _shot(serial: int, id: int, weapon: int, origin: Vector3, direction: Vector3, fanned: bool) -> void:
	if not _current(serial) or not origin.is_finite() or not direction.is_finite() or direction.length() < 0.5:
		return
	var info := match_ref.info_by_id(id)
	var def := NetCodec.weapon_of(weapon)
	if info and info.player and def and not info.local:
		info.player.weapons.show_shot(def, origin, direction.normalized(), fanned)


@rpc("authority", "call_remote", "reliable")
func _loadout(serial: int, id: int, weapon: int, ammo: int, using_primary: bool) -> void:
	if not _current(serial) or weapon < 0 or weapon > Weapons.GUNS.size() or ammo < 0 or ammo > 1000:
		return
	var info := match_ref.info_by_id(id)
	if info and info.player:
		_apply_loadout(info.player, weapon, ammo, using_primary)


func _apply_loadout(body: Player, weapon: int, ammo: int, using_primary: bool) -> void:
	var def := NetCodec.weapon_of(weapon)
	var w := body.weapons
	if def == null:
		if w.primary != null:
			w.reset()
		return
	if w.primary != def or w.primary_ammo != ammo:
		w.give(def, ammo)
	if w.using_primary != using_primary:
		w.set_using_primary(using_primary)


@rpc("authority", "call_remote", "reliable")
func _ammo_box(serial: int, path: NodePath, ready: bool) -> void:
	if not _current(serial) or str(path).length() > 128 or str(path).begins_with("/") or ".." in str(path):
		return
	var box := match_ref.level.get_node_or_null(path) as AmmoBox
	if box:
		box.set_ready(ready)


@rpc("authority", "call_remote", "reliable")
func _pad(serial: int, path: NodePath, ready: bool) -> void:
	if not _current(serial) or str(path).length() > 128 or str(path).begins_with("/") or ".." in str(path):
		return
	var pad := match_ref.level.get_node_or_null(path) as WeaponPad
	if pad:
		pad.set_ready(ready)


## A loose weapon appeared on the server: a copy here, which the server
## moves (it doesn't fall or hit anyone on its own).
@rpc("authority", "call_remote", "reliable")
func _pickup_new(serial: int, id: int, weapon: int, ammo: int, at: Vector3, rotation: Quaternion, velocity: Vector3) -> void:
	var def := NetCodec.weapon_of(weapon)
	if not _current(serial) or def == null or ammo < 0 or ammo > 1000 or not at.is_finite() or not velocity.is_finite() \
			or not rotation.is_finite() or absf(rotation.length() - 1.0) > 0.01 or _pickups.size() >= 256:
		return
	var old: WeaponPickup = _pickups.get(id)
	if old and is_instance_valid(old):
		old.queue_free()
	var pickup := WeaponPickup.create(def, ammo)
	match_ref.level.add_child(pickup)
	pickup.freeze = true
	pickup.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	pickup.global_transform = Transform3D(Basis(rotation.normalized()), at)
	_pickups[id] = pickup
	_pickup_targets[id] = [at, rotation.normalized()]


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _pickups_moved(bytes: PackedByteArray) -> void:
	if not _from_server() or match_ref.level == null:
		return
	var got := NetCodec.decode_pickups(bytes)
	if got.is_empty() or got.serial != (match_ref.serial & 0xFFFF):
		return
	for e: Dictionary in got.pickups:
		var pickup: WeaponPickup = _pickups.get(e.id)
		if pickup and is_instance_valid(pickup):
			pickup.ammo = e.ammo
			_pickup_targets[e.id] = [e.position, e.rotation]


@rpc("authority", "call_remote", "reliable")
func _pickup_gone(serial: int, id: int) -> void:
	if not _current(serial):
		return
	var pickup: WeaponPickup = _pickups.get(id)
	_pickups.erase(id)
	_pickup_targets.erase(id)
	if pickup and is_instance_valid(pickup):
		pickup.queue_free()


## Client: loose weapons glide to where the server last had them.
func _process(delta: float) -> void:
	if match_ref.authority or _pickup_targets.is_empty():
		return
	var k := minf(delta * 20.0, 1.0)
	for id: int in _pickup_targets:
		var pickup: WeaponPickup = _pickups.get(id)
		if pickup == null or not is_instance_valid(pickup):
			continue
		var target: Array = _pickup_targets[id]
		var xf := pickup.global_transform
		pickup.global_transform = Transform3D(Basis(xf.basis.get_rotation_quaternion().slerp(target[1], k)), xf.origin.lerp(target[0], k))


# --- Client: sending --------------------------------------------------------------------------

## Sends the server the newest commands (called by Prediction every tick).
func send_inputs(bytes: PackedByteArray) -> void:
	if not match_ref.authority and NetSession.active():
		_client_inputs.rpc_id(1, bytes)
