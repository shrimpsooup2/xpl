class_name WeaponPickup
extends RigidBody3D
## A weapon lying in the world with the ammo left in it: floating on a pad
## (frozen, turning slowly), or loose after being thrown or dropped. A
## thrown one hits the first body in its way for 25 damage and bounces off
## (GDD §7.2). An empty gun lies where it landed until the next gun from its
## pad is taken, then dissolves; one that never came off a pad dissolves
## EMPTY_LIFE after it lands.

const GROUP := &"weapon_pickups"
const THROW_DAMAGE := 25.0
const THROW_KNOCKBACK := 6.0
const EMPTY_LIFE := 3.0
const DISSOLVE_TIME := 0.4
const SPIN_SPEED := 1.4  # rad/s on a pad.
const BOB := 0.06
const LAYER := 1 << 1  # With the body fragments: never blocks players.

var def: WeaponDef
var ammo := 0
## On a pad now (and frozen there).
var pad: WeaponPad
## The pad it first came from, and which of that pad's guns it was.
var origin: WeaponPad
var origin_generation := 0
var model: WeaponModel

var _spinner := Node3D.new()

var _flying := false
var _thrower: WeaponHolder
var _landed_time := -1.0
var _taken := false
var _age := 0.0
var _last_position := Vector3.ZERO
var _center := Vector3.ZERO
var _half_length := 0.2
var _last_velocity := Vector3.ZERO


static func create(weapon: WeaponDef, rounds: int) -> WeaponPickup:
	var p := WeaponPickup.new()
	p.def = weapon
	p.ammo = rounds
	return p


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = LAYER
	collision_mask = 1 | TargetDummy.BODY_LAYER
	mass = 2.0
	continuous_cd = true
	var material := PhysicsMaterial.new()
	material.bounce = 0.25
	material.friction = 0.8
	physics_material_override = material
	model = WeaponModel.new(def)
	add_child(_spinner)
	_spinner.add_child(model)
	# A box around the gun, centred on it.
	var aabb := _model_aabb()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = aabb.size.max(Vector3(0.05, 0.05, 0.05))
	col.shape = box
	add_child(col)
	_center = aabb.get_center()
	_half_length = aabb.get_longest_axis_size() * 0.5
	model.position = -_center
	_last_position = global_position


## Can be picked up now.
func is_available() -> bool:
	return not _taken and ammo > 0 and model.visible


## Takes `rounds` out; the pickup goes once it's emptied.
func take(rounds: int) -> void:
	ammo -= rounds
	if ammo > 0:
		return
	_taken = true
	if pad:
		pad.taken(self)
	queue_free()


## Sends it flying from `at` with `velocity`, spinning. `thrower` (or
## null) marks it as a thrown weapon that can hit someone. It passes
## through `from_body`, whoever let go of it.
func throw_from(at: Vector3, velocity: Vector3, thrower: WeaponHolder, from_body: PhysicsBody3D = null) -> void:
	if from_body:
		add_collision_exception_with(from_body)
	freeze = false
	global_position = at
	_last_position = at
	_last_velocity = velocity
	linear_velocity = velocity
	angular_velocity = Vector3(randf_range(-4, 4), randf_range(-12, 12), randf_range(-4, 4))
	if velocity.length() > 0.1:
		global_basis = Basis.looking_at(velocity.normalized(), Vector3.UP if absf(velocity.normalized().y) < 0.95 else Vector3.RIGHT)
	_flying = thrower != null
	_thrower = thrower


## Pops in from small (respawning on a pad).
func pop_in() -> void:
	_spinner.scale = Vector3.ONE * 0.2
	_spinner.create_tween().tween_property(_spinner, "scale", Vector3.ONE, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## On a pad: frozen in place, turning.
func rest_on_pad(at: Vector3, from_pad: WeaponPad) -> void:
	pad = from_pad
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	global_position = at
	_last_position = at


func _physics_process(delta: float) -> void:
	_age += delta
	if pad:
		_spinner.rotation.y = _age * SPIN_SPEED
		_spinner.position.y = sin(_age * 2.0) * BOB
		return
	if _flying:
		_check_throw_hit(delta)
	_last_position = global_position
	_last_velocity = linear_velocity
	var resting := linear_velocity.length() < 0.3 and _age > 0.3
	if resting:
		_flying = false
		if _landed_time < 0.0:
			_landed_time = _age
	if ammo <= 0 and _landed_time >= 0.0 and NetSession.authority() and past_its_time():
		_dissolve()


## Whether it's had its time: its pad's next gun has been taken (or, if it
## never came off a pad, it's lain here EMPTY_LIFE).
func past_its_time() -> bool:
	if origin and is_instance_valid(origin):
		return origin.outlived(origin_generation)
	return _landed_time >= 0.0 and _age - _landed_time > EMPTY_LIFE


func _check_throw_hit(delta: float) -> void:
	var ballistics := Ballistics.of(get_parent())
	var holder := _thrower
	var exclude: Array[RID] = [get_rid()]
	if holder and is_instance_valid(holder.player):
		exclude.append(holder.player.get_rid())
	# Swept along the way it was flying, ahead of its centre by its length
	# and a bit: its nose meets the target (and may already have bounced off
	# it) before its centre gets there.
	var dir := _last_velocity.normalized()
	var reach := _last_velocity.length() * delta + _half_length + 0.4
	var hit := ballistics.trace(_last_position, _last_position + dir * reach, exclude,
			holder if is_instance_valid(holder) else null)
	if hit.is_empty() or hit.target == null:
		return
	_flying = false
	var info := {
		"damage": THROW_DAMAGE,
		"zone": &"head" if hit.zone == &"head" else &"body",
		"part": hit.part,
		"point": hit.point,
		"normal": hit.normal,
		"direction": dir,
		"heartshot": false,
		"weapon": def,
		"attacker": holder.player if holder and is_instance_valid(holder) else null,
		"knockback": THROW_KNOCKBACK,
	}
	var result: Dictionary = hit.target.take_hit(info)
	CombatFx.body_hit(get_parent(), hit.point, dir, false, 1.2)
	if holder and is_instance_valid(holder) and not result.is_empty():
		result.thrown = true
		holder.confirm_hit(result)
	# Bounce off.
	linear_velocity = -dir * 3.0 + Vector3.UP * 3.0
	angular_velocity *= 1.5


func _dissolve() -> void:
	if _taken:
		return
	_taken = true
	var t := create_tween()
	t.tween_method(model.set_fade, 1.0, 0.0, DISSOLVE_TIME)
	t.tween_callback(queue_free)


func _model_aabb() -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var xf := _relative_transform(mi)
		var b := xf * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _relative_transform(node: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n and n != model:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf
