class_name TargetDummy
extends Node3D
## A practice dummy: the player's own blob body on a little stand, with a
## heart and a blue team hat. Hits land where they're aimed (HitShapes) and the body reacts to
## the part that was hit (PlayerModel.react_to_hit). A heartshot, or
## running out of health, and it falls apart like a player does; then it
## pulls itself back together. Health comes back after a moment untouched.
##
## Dummies can pace back and forth along `patrol` for moving practice.

signal killed(heartshot: bool)

const BODY_LAYER := 1 << 2  # Blocks players; shots test the body instead.
const MAX_HEALTH := 100.0
const RESPAWN_TIME := 2.5
const REGEN_DELAY := 2.0
const BAR_WIDTH := 0.5

## Offset (from where it's placed) it walks to and back; zero stands still.
@export var patrol := Vector3.ZERO
@export var patrol_speed := 2.0
## Facing, radians (0 looks down -Z like the player).
@export var facing := 0.0
## Dummies play for blue; `hat` is one of Hats.ALL (none: the team triangle).
@export var team := Hats.Team.BLUE
@export var hat := Cosmetics.DEFAULT_HAT
## Over its head and in the killfeed.
@export var display_name := "dummy"

var model: PlayerModel
var health := MAX_HEALTH
var dead := false

var _home := Vector3.ZERO
var _body: StaticBody3D
var _stand: MeshInstance3D
var _bar: Node3D
var _bar_fill: MeshInstance3D
var _bar_shown := 0.0
var _since_hit := INF
var _patrol_t := 0.0
var _patrol_dir := 1.0
var _yaw := 0.0
var _placing := false


func _ready() -> void:
	add_to_group(Ballistics.GROUP)
	_home = global_position
	_yaw = facing
	model = PlayerModel.new()
	model.name = "Model"
	add_child(model)
	model.dress(hat, Hats.team_color(team))
	model.set_nametag(display_name, Hats.team_color(team))
	_body = StaticBody3D.new()
	_body.collision_layer = BODY_LAYER
	_body.collision_mask = 0
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.75
	col.shape = capsule
	col.position.y = 0.875
	_body.add_child(col)
	add_child(_body)
	_build_stand()
	_build_bar()
	_place()
	set_notify_transform(true)


func _notification(what: int) -> void:
	# Moved by hand (the editor, a test): stand there from now on.
	if what == NOTIFICATION_TRANSFORM_CHANGED and model and not _placing:
		_home = global_position - patrol * _patrol_t
		_place()


func _process(delta: float) -> void:
	_since_hit += delta
	if not dead and _since_hit > REGEN_DELAY and health < MAX_HEALTH:
		health = MAX_HEALTH
	_bar_shown = move_toward(_bar_shown, 1.0 if health < MAX_HEALTH and not dead else 0.0, delta * 6.0)
	_bar.visible = _bar_shown > 0.01
	_bar_fill.scale.x = maxf(health / MAX_HEALTH, 0.001)
	_bar_fill.position.x = -BAR_WIDTH * 0.5 * (1.0 - _bar_fill.scale.x)
	var cam := get_viewport().get_camera_3d()
	if cam and _bar.visible:
		_bar.global_basis = cam.global_basis.scaled(Vector3.ONE * _bar_shown)


func _physics_process(delta: float) -> void:
	if dead or patrol == Vector3.ZERO:
		return
	var length := patrol.length()
	_patrol_t += _patrol_dir * patrol_speed * delta / length
	if _patrol_t >= 1.0 or _patrol_t <= 0.0:
		_patrol_t = clampf(_patrol_t, 0.0, 1.0)
		_patrol_dir = -_patrol_dir
	var heading := patrol.normalized() * _patrol_dir
	_yaw = lerp_angle(_yaw, atan2(-heading.x, -heading.z), minf(delta * 8.0, 1.0))
	_placing = true
	global_position = _home + patrol * _patrol_t
	_placing = false
	_place()


## The first body part the segment hits, or {} (Ballistics).
func ray_test(from: Vector3, to: Vector3) -> Dictionary:
	if dead:
		return {}
	return model.ray_test(from, to)


## Takes a hit (see Ballistics._land for the fields). Returns what it did.
func take_hit(hit: Dictionary) -> Dictionary:
	if dead:
		return {}
	var amount: float = hit.damage
	var lethal: bool = hit.get("heartshot", false)
	if lethal:
		amount = maxf(amount, health)
	health -= amount
	_since_hit = 0.0
	var world := get_parent()
	DamageNumber.add(world, self, hit.point, amount, &"heart" if lethal else hit.zone)
	var killed_now := health <= 0.0
	if killed_now:
		_die(hit, lethal)
	else:
		model.react_to_hit(hit.part, hit.point, hit.direction, amount / 40.0 + (hit.get("knockback", 0.0) as float) * 0.05)
	return {
		"target": self,
		"name": display_name,
		"damage": amount,
		"zone": &"heart" if lethal else hit.zone,
		"part": hit.part,
		"heartshot": lethal,
		"killed": killed_now,
		"weapon": hit.get("weapon"),
	}


func _die(hit: Dictionary, heartshot: bool) -> void:
	dead = true
	health = 0.0
	_body.process_mode = Node.PROCESS_MODE_DISABLED
	var attacker: Node3D = hit.get("attacker")
	var look_from: Vector3 = attacker.global_position if attacker else global_position - (hit.direction as Vector3) * 3.0
	model.fall_apart(false, look_from)
	killed.emit(heartshot)
	var t := create_tween()
	t.tween_interval(RESPAWN_TIME)
	t.tween_callback(_respawn)


func _respawn() -> void:
	model.reassemble()
	dead = false
	health = MAX_HEALTH
	_body.process_mode = Node.PROCESS_MODE_INHERIT
	# Pulls itself together: pops up from squashed.
	model.scale = Vector3(1.3, 0.2, 1.3)
	var t := model.create_tween()
	t.tween_property(model, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_place()


func _place() -> void:
	model.follow(global_position + Vector3.UP * 0.08, _yaw)
	if model.anim:
		var moving := patrol != Vector3.ZERO and not dead
		var clip := (PlayerModel.ANIM_JOG if patrol_speed > 3.0 else PlayerModel.ANIM_WALK) if moving else PlayerModel.ANIM_IDLE
		if model.anim.current_animation != clip:
			model.anim.play(clip, PlayerModel.BLEND)
		if moving:
			model.anim.speed_scale = patrol_speed / (PlayerModel.JOG_CLIP_SPEED if patrol_speed > 3.0 else PlayerModel.WALK_CLIP_SPEED)
	_body.global_position = global_position
	_stand.global_position = global_position
	_bar.global_position = global_position + Vector3.UP * 2.05


func _build_stand() -> void:
	_stand = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.34
	cyl.bottom_radius = 0.4
	cyl.height = 0.08
	cyl.radial_segments = 12
	cyl.rings = 1
	_stand.mesh = cyl
	_stand.material_override = WeaponModel.material(false)
	_stand.set_instance_shader_parameter(&"color", Color(0.9, 0.35, 0.2))
	_stand.set_instance_shader_parameter(&"gloss", 0.5)
	_stand.top_level = true
	add_child(_stand)


## A little health bar over the head, facing the camera, shown while hurt.
func _build_bar() -> void:
	_bar = Node3D.new()
	_bar.top_level = true
	add_child(_bar)
	var back := MeshInstance3D.new()
	back.mesh = _bar_quad(Vector2(BAR_WIDTH + 0.04, 0.09))
	back.material_override = _bar_material(Color(0.08, 0.06, 0.12))
	_bar.add_child(back)
	_bar_fill = MeshInstance3D.new()
	_bar_fill.mesh = _bar_quad(Vector2(BAR_WIDTH, 0.05))
	_bar_fill.material_override = _bar_material(Color(1, 1, 1))
	_bar_fill.position.z = 0.005
	_bar.add_child(_bar_fill)
	_bar.visible = false


static func _bar_quad(size: Vector2) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = size
	return q


static func _bar_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = true
	m.albedo_color = color
	m.render_priority = 1 if color == Color(1, 1, 1) else 0
	return m
