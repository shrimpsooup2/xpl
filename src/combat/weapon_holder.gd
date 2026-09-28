class_name WeaponHolder
extends Node
## A player's hands (GDD §5.3, §7): fists, always, and one primary weapon
## picked up from the map. Runs at the physics tick after movement, from the
## tick's InputCommand, so it works the same for the local player, bots,
## and tests. Nothing here ever slows movement (GDD §5.4).
##
## Picking up: moving over a weapon while the primary slot is empty (or
## holds an empty gun) takes it; E swaps; the same gun tops yours up. Q
## throws the primary. An empty gun switches to fists after a moment.

signal equipped(def: WeaponDef, ammo: int)
signal fired(def: WeaponDef, shot: Dictionary)
signal ammo_changed(ammo: int, capacity: int)
signal hit_confirmed(result: Dictionary)
signal picked_up(def: WeaponDef, how: StringName)
signal thrown(def: WeaponDef)
signal dry_fired(def: WeaponDef)

const READY_TIME := 0.15
const EMPTY_SWITCH := 0.2
const PICKUP_RADIUS := 1.5
## A click this soon before a semi-automatic is ready still fires, on time.
const FIRE_BUFFER := 0.15
const THROW_SPEED := 18.0
const FAN_INTERVAL := 0.1
const FAN_SPREAD := 3.0
## Automatic spread recovers this many degrees per second once released.
const BLOOM_RECOVERY := 6.0
## Fists (GDD §7.3): +1 damage per m/s over run speed, up to +15. The hit
## lands this long into the swing, when the arm is out.
const PUNCH_SPEED_BONUS := 15.0
const PUNCH_LANDS := 0.07
const PUNCH_ASSIST := deg_to_rad(12.0)

var player: Player
var fists: WeaponDef = Weapons.get_def(Weapons.FISTS)
var primary: WeaponDef
var primary_ammo := 0
var using_primary := false
## Alt-fire zoom (1 = none), for the camera.
var zoom := 1.0
## A different gun in reach that E would swap for, or null.
var swap_candidate: WeaponPickup

var _cooldown := 0.0
var _ready_timer := 0.0
var _buffer := 0.0
var _bloom := 0.0
var _empty_timer := -1.0
var _fan_left := 0
var _fan_timer := 0.0
var _punch_left := true
var _punch_timer := -1.0
var _punch_damage := 0.0
var _ignore_pickup: WeaponPickup
var _ignore_timer := 0.0


## What's in hand.
var current: WeaponDef:
	get:
		return primary if using_primary and primary else fists

## Rounds in the primary in hand, or -1 for fists.
var ammo: int:
	get:
		return primary_ammo if using_primary and primary else -1


## Clears everything (spawn, respawn).
func reset() -> void:
	primary = null
	primary_ammo = 0
	using_primary = false
	_cooldown = 0.0
	_ready_timer = 0.0
	_fan_left = 0
	_empty_timer = -1.0
	_punch_timer = -1.0
	zoom = 1.0
	_equip()


## Puts `def` in the primary slot with `rounds` and switches to it.
func give(def: WeaponDef, rounds := -1) -> void:
	primary = def
	primary_ammo = def.ammo if rounds < 0 else rounds
	using_primary = true
	_ready_timer = READY_TIME
	_cooldown = 0.0
	_fan_left = 0
	_empty_timer = -1.0
	_equip()


func is_ready() -> bool:
	return _ready_timer <= 0.0 and _cooldown <= 0.0


## Seconds until the next shot can go.
func cooldown() -> float:
	return maxf(maxf(_cooldown, _ready_timer), 0.0)


## Current spread (degrees) of the weapon in hand.
func spread() -> float:
	var def := current
	return minf(def.spread + _bloom, maxf(def.spread_max, def.spread)) + (FAN_SPREAD if _fan_left > 0 else 0.0)


func tick(cmd: InputCommand, delta: float) -> void:
	if player == null or player.is_dead:
		return
	# Kept going below zero for one tick, so a held automatic keeps its
	# exact rate instead of rounding each shot up to whole ticks.
	_cooldown = maxf(_cooldown - delta, -delta)
	_ready_timer = maxf(_ready_timer - delta, 0.0)
	_buffer = maxf(_buffer - delta, 0.0)
	_ignore_timer = maxf(_ignore_timer - delta, 0.0)
	var def := current
	if not (cmd.fire_held and def.automatic):
		_bloom = maxf(_bloom - BLOOM_RECOVERY * delta, 0.0)

	# Switching and throwing.
	match cmd.switch_to:
		1:
			_switch(true)
		2:
			_switch(false)
		3:
			_switch(not using_primary)
	if cmd.throw_pressed and primary:
		throw_primary()
	_update_pickups(cmd.interact_pressed)
	def = current

	# The punch lands a moment into the swing.
	if _punch_timer >= 0.0:
		_punch_timer -= delta
		if _punch_timer < 0.0:
			_land_punch()

	# Alt-fire.
	zoom = def.zoom if def.alt == &"zoom" and cmd.alt_held and using_primary else 1.0
	if cmd.alt_pressed and def.alt == &"fan" and ammo > 0 and _fan_left == 0 and _ready_timer <= 0.0:
		_fan_left = ammo
		_fan_timer = 0.0
	if _fan_left > 0:
		_fan_timer -= delta
		if _fan_timer <= 0.0 and ammo > 0:
			_fire(def, true)
			_fan_left -= 1
			_fan_timer = FAN_INTERVAL
		if ammo <= 0:
			_fan_left = 0
		return

	# Firing.
	if cmd.fire_pressed:
		_buffer = FIRE_BUFFER
	var wants := cmd.fire_held if def.automatic else _buffer > 0.0
	if wants and is_ready():
		if def.is_fists():
			_buffer = 0.0
			_swing()
		elif ammo > 0:
			_buffer = 0.0
			_fire(def, false)
		elif cmd.fire_pressed:
			_buffer = 0.0
			dry_fired.emit(def)
			_cooldown = 0.25

	# Empty: fists after a moment (GDD §7.2).
	if using_primary and primary and primary_ammo <= 0:
		if _empty_timer < 0.0:
			_empty_timer = EMPTY_SWITCH
		_empty_timer -= delta
		if _empty_timer <= 0.0:
			_empty_timer = -1.0
			_switch(false)


## Throws the primary (any ammo): it flies, hits for 25, and lands as a
## pickup with what's left in it. Switches to fists at once.
func throw_primary() -> void:
	if primary == null:
		return
	var def := primary
	var pickup := WeaponPickup.create(def, primary_ammo)
	player.get_parent().add_child(pickup)
	var forward := _aim_basis() * Vector3.FORWARD
	pickup.throw_from(eye_position() + forward * 0.4 + _aim_basis() * Vector3(0.15, -0.1, 0.0),
			forward * THROW_SPEED + player.velocity * 0.5 + Vector3.UP * 2.0, self, player)
	_ignore_pickup = pickup
	_ignore_timer = 0.6
	primary = null
	primary_ammo = 0
	using_primary = false
	_fan_left = 0
	_ready_timer = 0.0
	thrown.emit(def)
	_equip()


## On death the primary drops where you fell, with what's left in it.
func drop_on_death() -> void:
	if primary and primary_ammo > 0:
		var drop := WeaponPickup.create(primary, primary_ammo)
		player.get_parent().add_child(drop)
		drop.throw_from(player.global_position + Vector3.UP * 1.0, Vector3.UP * 2.0 + player.velocity * 0.3, null, player)
	primary = null
	primary_ammo = 0
	using_primary = false
	_fan_left = 0
	_punch_timer = -1.0


func eye_position() -> Vector3:
	var p := player.movement_params
	return player.global_position + Vector3.UP * (p.crouch_eye_height if player.state.crouched else p.stand_eye_height)


func aim_direction() -> Vector3:
	return _aim_basis() * Vector3.FORWARD


## A body the shots hit reported back (from Ballistics or a punch).
func confirm_hit(result: Dictionary) -> void:
	hit_confirmed.emit(result)


func _aim_basis() -> Basis:
	return Basis.from_euler(Vector3(player.pitch, player.yaw, 0.0))


func _switch(to_primary: bool) -> void:
	if to_primary and primary == null:
		return
	if to_primary == using_primary:
		return
	using_primary = to_primary
	_ready_timer = READY_TIME
	_fan_left = 0
	_empty_timer = -1.0
	_equip()


func _equip() -> void:
	equipped.emit(current, ammo)
	ammo_changed.emit(ammo, current.ammo)


func _fire(def: WeaponDef, fanned: bool) -> void:
	primary_ammo -= 1
	_cooldown = minf(_cooldown, 0.0) + def.fire_interval
	var origin := eye_position()
	var basis := _aim_basis()
	var visual := player.muzzle_position()
	var exclude: Array[RID] = [player.get_rid()]
	var ballistics := Ballistics.of(player.get_parent())
	var cone := deg_to_rad(spread())
	var results: Array[Dictionary] = []
	for i in def.pellets:
		var dir := basis * _spread_direction(cone, i, def.pellets)
		if def.delivery == WeaponDef.Delivery.HITSCAN:
			var r := ballistics.fire_hitscan(self, def, origin, dir, visual, def.damage, def.heartshot and not fanned, exclude)
			if not r.is_empty():
				results.append(r)
		else:
			ballistics.fire_projectile(self, def, origin, dir, visual, def.damage, def.heartshot and not fanned, exclude)
	_bloom = minf(_bloom + def.bloom_per_shot, maxf(def.spread_max - def.spread, 0.0))
	fired.emit(def, {"fanned": fanned, "ammo": primary_ammo})
	ammo_changed.emit(primary_ammo, def.ammo)


## A point in a cone of half-angle `cone` around -Z. Pellets make a
## pattern you can read: one in the middle, a tight inner ring, the rest on
## an outer ring, each jittered a little. Single shots land anywhere inside.
func _spread_direction(cone: float, index: int, count: int) -> Vector3:
	if cone <= 0.0:
		return Vector3.FORWARD
	var angle: float
	var radius: float
	if count > 1:
		var inner := (count - 1) / 3
		if index == 0:
			return (Basis(Vector3.UP, randf_range(-0.1, 0.1) * cone) * Vector3.FORWARD).normalized()
		elif index <= inner:
			angle = TAU * float(index - 1) / inner
			radius = 0.45
		else:
			angle = TAU * float(index - 1 - inner) / (count - 1 - inner) + PI / (count - 1 - inner)
			radius = 0.9
		angle += randf_range(-0.25, 0.25)
		radius = cone * (radius + randf_range(-0.1, 0.1))
	else:
		angle = randf() * TAU
		radius = cone * sqrt(randf())
	return (Basis(Vector3.UP, sin(angle) * radius) * Basis(Vector3.RIGHT, cos(angle) * radius) * Vector3.FORWARD).normalized()


func _swing() -> void:
	_cooldown = minf(_cooldown, 0.0) + fists.fire_interval
	var p := player.movement_params
	var bonus := clampf(player.horizontal_speed() - p.run_speed, 0.0, PUNCH_SPEED_BONUS)
	_punch_damage = fists.damage + bonus
	_punch_timer = PUNCH_LANDS
	fired.emit(fists, {"left": _punch_left})
	_punch_left = not _punch_left


## Reach 2.2 m, with a little aim assist toward bodies near the crosshair.
func _land_punch() -> void:
	var origin := eye_position()
	var dir := aim_direction()
	var ballistics := Ballistics.of(player.get_parent())
	var exclude: Array[RID] = [player.get_rid()]
	var hit := ballistics.trace(origin, origin + dir * fists.max_range, exclude, self)
	if hit.is_empty() or hit.target == null:
		var assisted := _assist(origin, dir)
		if not assisted.is_empty():
			hit = assisted
	if hit.is_empty():
		return
	if hit.target == null:
		CombatFx.impact(player.get_parent(), hit.point, hit.normal, 0.6)
		return
	var info := {
		"damage": _punch_damage,
		"zone": &"head" if hit.zone == &"head" else &"body",
		"part": hit.part,
		"point": hit.point,
		"normal": hit.normal,
		"direction": dir,
		"heartshot": false,
		"weapon": fists,
		"attacker": player,
		"knockback": fists.knockback,
	}
	var result: Dictionary = hit.target.take_hit(info)
	CombatFx.body_hit(player.get_parent(), hit.point, dir, false, 1.3)
	if not result.is_empty():
		confirm_hit(result)


## The nearest body within reach and PUNCH_ASSIST of the aim, hit where the
## aim ray passes closest to it (its chest when that misses too).
func _assist(origin: Vector3, dir: Vector3) -> Dictionary:
	var ballistics := Ballistics.of(player.get_parent())
	var exclude: Array[RID] = [player.get_rid()]
	for target: Node in get_tree().get_nodes_in_group(Ballistics.GROUP):
		if not target is Node3D or target == player:
			continue
		var chest := (target as Node3D).global_position + Vector3.UP * 1.1
		var to := chest - origin
		if to.length() > fists.max_range + 0.4 or to.angle_to(dir) > PUNCH_ASSIST:
			continue
		var h := ballistics.trace(origin, origin + to.normalized() * (fists.max_range + 0.5), exclude, self)
		if not h.is_empty() and h.target == target:
			return h
	return {}


func _update_pickups(interact: bool) -> void:
	var nearest: WeaponPickup
	var nearest_distance := PICKUP_RADIUS
	var center := player.global_position + Vector3.UP * 0.9
	for node: Node in get_tree().get_nodes_in_group(WeaponPickup.GROUP):
		var pickup := node as WeaponPickup
		if pickup == null or not pickup.is_available() or (pickup == _ignore_pickup and _ignore_timer > 0.0):
			continue
		var d := pickup.global_position.distance_to(center)
		if d > PICKUP_RADIUS:
			continue
		# Same gun: top up (GDD §7.1), up to a full gun.
		if primary and pickup.def == primary and primary_ammo < primary.ammo and pickup.ammo > 0:
			var taken := mini(pickup.ammo, primary.ammo - primary_ammo)
			primary_ammo += taken
			pickup.take(taken)
			if not using_primary:
				_switch(true)
			picked_up.emit(primary, &"top_up")
			ammo_changed.emit(ammo, current.ammo)
			continue
		if d < nearest_distance and pickup.def != primary:
			nearest = pickup
			nearest_distance = d
	swap_candidate = nearest if nearest and primary and primary_ammo > 0 else null
	if nearest == null:
		return
	if primary == null or primary_ammo <= 0:
		_take(nearest, &"auto")
	elif interact:
		swap_candidate = null
		_take(nearest, &"swap")


func _take(pickup: WeaponPickup, how: StringName) -> void:
	var old := primary
	var old_ammo := primary_ammo
	var def := pickup.def
	var rounds := pickup.ammo
	pickup.take(rounds)
	# The old gun drops with what's left in it; an empty one is just gone.
	if old and old_ammo > 0:
		var drop := WeaponPickup.create(old, old_ammo)
		player.get_parent().add_child(drop)
		drop.throw_from(player.global_position + Vector3.UP * 1.0, player.velocity * 0.5 + Vector3.UP * 2.5, null, player)
		_ignore_pickup = drop
		_ignore_timer = 1.0
	give(def, rounds)
	picked_up.emit(def, how)
