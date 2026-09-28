class_name DamageNumber
extends Label3D
## The damage you're doing to one target, as a single number over it. Hits
## that land while it's still up (a burst, a string of shots, pellets,
## anything on a far target) add to it instead of spawning more: the number
## rolls up, pops, and grows with the total. It follows the target, and
## fades a moment after the last hit. White for the body, yellow once a
## hit lands on the head, pink with a heart for a heartshot.

## It stays this long after the last hit, then fades out.
const HOLD := 0.8
const FADE := 0.2
## Drift up over its life, meters per second, up to RISE_MAX.
const RISE := 0.3
const RISE_MAX := 0.35
## Size: 1 at BASE_DAMAGE, growing with the log of the total, capped.
const BASE_DAMAGE := 15.0
const GROWTH := 0.35
const MAX_SIZE := 2.3
## Each hit pops it this much bigger for a moment.
const POP := 0.45
const POP_DECAY := 9.0
const COLORS := {&"body": Color.WHITE, &"head": Color(1.0, 0.9, 0.3), &"heart": Color(1.0, 0.35, 0.55)}
const RANK := {&"body": 0, &"head": 1, &"heart": 2}

static var _active := {}  # Target instance id -> DamageNumber.

var total := 0.0
var zone := &"body"
var target: Node3D

var _shown := 0.0
var _since_hit := 0.0
var _pop := 0.0
var _offset := Vector3.ZERO  # From the target.
var _rise := 0.0


## Adds `amount` to the number over `target` (a new one if it has none up)
## at `point`, the hit. Returns the number.
static func add(world: Node, hit_target: Node3D, point: Vector3, amount: float, hit_zone: StringName) -> DamageNumber:
	var key := hit_target.get_instance_id()
	var number := over(hit_target)
	if number == null:
		number = DamageNumber.new()
		number.target = hit_target
		world.add_child(number)
		number._offset = point - hit_target.global_position + Vector3.UP * 0.15
		_active[key] = number
	number._hit(point, amount, hit_zone)
	return number


## The number showing over `hit_target`, or null.
static func over(hit_target: Node) -> DamageNumber:
	var number: Variant = _active.get(hit_target.get_instance_id())
	if number == null or not is_instance_valid(number) or (number as Node).is_queued_for_deletion():
		return null
	return number


func _init() -> void:
	font = preload("res://assets/fonts/LiberationSans-Regular.ttf")
	font_size = 48
	outline_size = 12
	outline_modulate = Color(0.1, 0.07, 0.15)
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	fixed_size = true
	pixel_size = 0.0009
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST


func _hit(point: Vector3, amount: float, hit_zone: StringName) -> void:
	total += amount
	if _shown <= 0.0:
		_shown = total  # The first hit shows at once; later ones roll up.
	if RANK.get(hit_zone, 0) > RANK.get(zone, 0):
		zone = hit_zone
	_since_hit = 0.0
	_pop = 1.0
	# Drift toward where this hit landed, so it stays by the action.
	var to := point - target.global_position + Vector3.UP * 0.15 if is_instance_valid(target) else _offset
	_offset = _offset.lerp(to, 0.35)
	modulate = COLORS.get(zone, Color.WHITE)
	outline_modulate.a = 1.0
	_update(0.0)


func _process(delta: float) -> void:
	_update(delta)


func _update(delta: float) -> void:
	_since_hit += delta
	_rise = minf(_rise + RISE * delta, RISE_MAX)
	_pop = maxf(_pop - POP_DECAY * delta, 0.0)
	# Roll up to the total quickly.
	_shown = move_toward(_shown, total, maxf(total - _shown, 1.0) * delta * 18.0)
	text = ("♥ " if zone == &"heart" else "") + str(roundi(_shown))
	var size := clampf(1.0 + GROWTH * log(maxf(total, 1.0) / BASE_DAMAGE) / log(2.0), 0.9, MAX_SIZE)
	scale = Vector3.ONE * size * (1.0 + POP * _pop * _pop)
	if is_instance_valid(target):
		global_position = target.global_position + _offset + Vector3.UP * _rise
	var fade := clampf((_since_hit - HOLD) / FADE, 0.0, 1.0)
	modulate.a = 1.0 - fade
	outline_modulate.a = 1.0 - fade
	if fade >= 1.0:
		queue_free()
