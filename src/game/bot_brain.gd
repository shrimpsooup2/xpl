class_name BotBrain
extends Node
## A practice opponent: drives its Player with the same InputCommands a
## person's keys make, so it moves and fights by the same rules. Kept simple
## (no navigation mesh): it runs straight at what it wants, jumps what's in
## the way, won't walk off into the void, and gets itself unstuck by trying
## somewhere else for a moment.
##   empty-handed: to the nearest gun lying about (walking over one takes it);
##   armed: at the nearest enemy it can see, strafing and shooting, with a
##     human-ish reaction time and aim error; hunting the nearest enemy it
##     can't see.

## Degrees of aim error, seconds before it reacts to someone new, turn rate.
@export var aim_error := 3.0
@export var reaction := 0.35
@export var turn_speed := deg_to_rad(320.0)

var player: Player
var match_ref: Match

var _target: Player
var _seen_for := 0.0
var _goal := Vector3.ZERO
var _has_goal := false
var _think := 0.0
var _strafe := 1.0
var _strafe_timer := 0.0
var _error := Vector2.ZERO
var _stuck_check := 0.0
var _last_position := Vector3.ZERO
var _detour := 0.0
var _fire_hold := 0


func _physics_process(delta: float) -> void:
	if player == null or player.is_dead or not player.is_inside_tree():
		return
	_think -= delta
	if _think <= 0.0:
		_think = 0.2
		_choose()
	var cmd := InputCommand.new()
	var eye := player.weapons.eye_position()
	var sees := _target != null and _visible(_target)
	_seen_for = _seen_for + delta if sees else 0.0

	# Where to look: at the target (once it's reacted), else where it's going.
	var look_at := eye + _heading() * 10.0
	if sees and _seen_for > reaction:
		look_at = _target.global_position + Vector3.UP * 1.1
	var want := look_at - eye
	var want_yaw := atan2(-want.x, -want.z) + deg_to_rad(_error.x)
	var want_pitch := atan2(want.y, Vector2(want.x, want.z).length()) + deg_to_rad(_error.y)
	player.yaw = rotate_toward(player.yaw, want_yaw, turn_speed * delta)
	player.pitch = clampf(move_toward(player.pitch, want_pitch, turn_speed * delta), -1.4, 1.4)
	cmd.yaw = player.yaw
	cmd.pitch = player.pitch

	# Where to go.
	var move := Vector3.ZERO
	if _has_goal:
		move = _goal - player.global_position
		move.y = 0.0
		if move.length() < 1.0:
			move = Vector3.ZERO
		move = move.normalized()
	if sees and _seen_for > reaction and player.weapons.using_primary:
		# In a fight: close to mid range and strafe.
		_strafe_timer -= delta
		if _strafe_timer <= 0.0:
			_strafe_timer = randf_range(0.5, 1.4)
			_strafe = -_strafe
		var side := Vector3(cos(player.yaw), 0, -sin(player.yaw)) * _strafe
		var distance := player.global_position.distance_to(_target.global_position)
		move = (move * (1.0 if distance > 12.0 else 0.0) + side).normalized()
	if move != Vector3.ZERO and player.state.on_ground and _void_ahead(move):
		move = Vector3.ZERO
		_detour = 0.0
		_has_goal = false
	var forward := Vector3(-sin(player.yaw), 0, -cos(player.yaw))
	var right := Vector3(cos(player.yaw), 0, -sin(player.yaw))
	cmd.move = Vector2(move.dot(right), move.dot(forward)).limit_length(1.0)
	if move != Vector3.ZERO and player.state.on_ground and (_blocked(move, 0.5) or _blocked(move, 2.0)):
		cmd.jump_pressed = true
		cmd.jump_held = true

	# Shooting: when the aim is close enough and it's in range.
	if sees and _seen_for > reaction:
		var def := player.weapons.current
		var off := rad_to_deg(forward.angle_to(Vector3(want.x, 0, want.z).normalized())) if want.length() > 0.1 else 0.0
		var in_range := player.global_position.distance_to(_target.global_position) < (2.4 if def.is_fists() else def.max_range * 0.8)
		if off < 6.0 and in_range:
			_fire_hold += 1
			cmd.fire_held = true
			cmd.fire_pressed = _fire_hold % 8 == 1
		else:
			_fire_hold = 0
	player.tick(cmd, delta)


## Picks what to do next: a new target, a goal, a new aim error; notices
## when it's stuck and tries somewhere else for a moment.
func _choose() -> void:
	var enemies := _enemies()
	var nearest_seen: Player = null
	var nearest_any: Player = null
	for e in enemies:
		var d := player.global_position.distance_to(e.global_position)
		if nearest_any == null or d < player.global_position.distance_to(nearest_any.global_position):
			nearest_any = e
		if d < 90.0 and _visible(e) and (nearest_seen == null or d < player.global_position.distance_to(nearest_seen.global_position)):
			nearest_seen = e
	if nearest_seen != _target:
		_seen_for = 0.0
	_target = nearest_seen
	_error = Vector2(randfn(0.0, aim_error), randfn(0.0, aim_error * 0.6))

	_stuck_check += 0.2
	if _stuck_check >= 1.5:
		_stuck_check = 0.0
		if _has_goal and player.global_position.distance_to(_last_position) < 0.8 and _detour <= 0.0:
			var a := randf() * TAU
			_goal = player.global_position + Vector3(sin(a), 0, cos(a)) * 8.0
			_detour = 2.0
		_last_position = player.global_position
	if _detour > 0.0:
		_detour -= 0.2
		return

	_has_goal = true
	if not player.weapons.using_primary or player.weapons.primary == null:
		var gun := _nearest_gun()
		if gun:
			_goal = gun.global_position
			return
	if _target:
		_goal = _target.global_position
	elif nearest_any:
		_goal = nearest_any.global_position
	else:
		_has_goal = false


func _enemies() -> Array[Player]:
	var out: Array[Player] = []
	if match_ref == null:
		return out
	var me := match_ref.info_of(player)
	for info in match_ref.infos:
		if info == me or not info.alive():
			continue
		if match_ref.rules.is_teams() and me and info.team == me.team:
			continue
		out.append(info.player)
	return out


func _nearest_gun() -> Node3D:
	var best: Node3D = null
	for n: Node in get_tree().get_nodes_in_group(WeaponPickup.GROUP):
		var p := n as WeaponPickup
		if p and p.is_available() and (best == null or player.global_position.distance_to(p.global_position) < player.global_position.distance_to(best.global_position)):
			best = p
	return best


func _heading() -> Vector3:
	if _has_goal:
		var d := _goal - player.global_position
		d.y = 0.0
		if d.length() > 0.5:
			return d.normalized()
	return Vector3(-sin(player.yaw), 0, -cos(player.yaw))


func _visible(other: Player) -> bool:
	var from := player.weapons.eye_position()
	var to := other.global_position + Vector3.UP * 1.1
	var hit := player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
	return hit.is_empty()


func _blocked(dir: Vector3, height: float) -> bool:
	var from := player.global_position + Vector3.UP * height
	var hit := player.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(from, from + dir * 1.2, 1, [player.get_rid()]))
	return not hit.is_empty() and absf(hit.normal.y) < 0.5


## Nothing to land on within 8 m below, a step ahead: the void, or a drop
## it shouldn't take.
func _void_ahead(dir: Vector3) -> bool:
	var from := player.global_position + dir * 1.2 + Vector3.UP * 0.5
	return player.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 8.5, 1, [player.get_rid()])).is_empty()
