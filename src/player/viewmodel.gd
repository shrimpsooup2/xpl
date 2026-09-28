class_name Viewmodel
extends Node3D
## First person: your own blobby arms and whatever they hold, drawn over
## the world with a steady field of view (viewmodel.gdshaderinc).
##
## The arms are the body's own mesh, cut down to the arms and posed by the
## same rig. Holding a gun, both hands are put on it by IK (the right on
## the grip, the left on the foregrip or pump), and the gun itself is
## animated: it kicks, its slide or bolt or pump cycles, the right hand
## works a bolt, the left hand fans a revolver's hammer. Empty-handed, the
## rig's own clips do the work: a guard, jabs and crosses. Topping up plays
## the pistol reload on the left arm.
##
## Like the camera (GDD §10.3) it never moves on its own, only in answer to
## what you do: looking drags it, landing drops it, slides tilt it, dashes
## swing it, smashdowns pull it up and slam it down.

## Vertical field of view it's drawn with, and how much of the camera's FOV
## swings (speed, slides, punches) it still follows.
const FOV := 62.0
const FOV_FOLLOW := 0.3
## The arms are the body's, a bit smaller: the blob's arms are thick, and
## at full size they'd fill the corner of the screen.
const RIG_SCALE := 0.8
## Where the shoulders sit relative to the eye (only the arms are drawn, so
## they can go anywhere that looks right): low, so the upper arms stay out
## of view. Empty-handed they come up and forward into a guard.
const SHOULDERS := Vector3(0.0, -0.36, -0.1)
const FISTS_SHOULDERS := Vector3(0.0, -0.25, -0.24)
## Hand targets sit this far back from the grip, so the round arm tip
## wraps it instead of swallowing the gun.
const GRIP_BACK := 0.045
## Look drag: radians of turn per rad/s of look, and its limit.
const LOOK_DRAG := 0.012
const LOOK_DRAG_MAX := 0.09
## Motion springs: (stiffness, damping) for (snappy, smooth).
const SPRING_STIFFNESS := Vector2(420.0, 160.0)
const SPRING_DAMPING := Vector2(34.0, 13.0)
## Recoil spring: always a snap, with one small overshoot.
const RECOIL_STIFFNESS := 520.0
const RECOIL_DAMPING := 26.0
const DRAW_TIME := 0.16
const THROW_TIME := 0.22
## Fanning: the left hand's swipe over the hammer.
const FAN_FROM := Vector3(-0.05, 0.2, 0.1)
const FAN_TO := Vector3(0.04, 0.11, 0.1)

var player: Player
var holder: WeaponHolder
var skeleton: Skeleton3D
var anim: AnimationPlayer
var layers: BodyLayers
var gun: WeaponModel
var def: WeaponDef

var _root := Node3D.new()
var _rig: Node3D
var _arms: MeshInstance3D
var _last_look := Vector2.ZERO
var _has_look := false
# Springs: position (m) and rotation (rad), each with a velocity.
var _move := Vector3.ZERO
var _move_v := Vector3.ZERO
var _turn := Vector3.ZERO
var _turn_v := Vector3.ZERO
var _recoil := Vector3.ZERO
var _recoil_v := Vector3.ZERO
var _shove := Vector3.ZERO
var _shove_v := Vector3.ZERO
var _draw := 1.0
var _throw := -1.0
var _fan := -1.0
var _top_up := -1.0
var _pending_casings: Array[float] = []
var _slide := 0.0
var _shoulder_rest := Vector3.ZERO  # Shoulders' midpoint, rig space turned and scaled.

static var _arms_mesh: ArrayMesh


func _ready() -> void:
	top_level = true
	add_child(_root)
	_rig = BodyShape.RIG_SCENE.instantiate()
	_rig.rotation.y = PI
	_rig.scale = Vector3.ONE * RIG_SCALE
	_root.add_child(_rig)
	anim = _rig.find_children("*", "AnimationPlayer", true, false)[0]
	skeleton = _rig.find_children("*", "Skeleton3D", true, false)[0]
	for mesh in skeleton.find_children("*", "MeshInstance3D", false, false):
		mesh.visible = false
	BodyShape.reshape_skeleton(skeleton)
	BodyShape.scale_hips_animation(anim)
	anim.play(PlayerModel.ANIM_IDLE)
	anim.seek(0.0, true)
	anim.pause()
	var right := skeleton.get_bone_global_rest(skeleton.find_bone("DEF-upper_arm.R")).origin
	var left := skeleton.get_bone_global_rest(skeleton.find_bone("DEF-upper_arm.L")).origin
	_shoulder_rest = _rig.transform.basis * ((right + left) * 0.5)
	_arms = MeshInstance3D.new()
	_arms.name = "Arms"
	_arms.mesh = arms_only(skeleton)
	skeleton.add_child(_arms)
	_arms.skin = skeleton.create_skin_from_rest_transforms()
	_arms.skeleton = _arms.get_path_to(skeleton)
	_arms.material_override = WeaponModel.material(true)
	_arms.set_instance_shader_parameter(&"color", PlayerModel.BODY_COLOR)
	_arms.set_instance_shader_parameter(&"gloss", 0.25)
	_arms.set_instance_shader_parameter(&"rim_amount", 0.3)
	_arms.set_instance_shader_parameter(&"roughness_amount", 0.2)
	_arms.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layers = BodyLayers.new()
	layers.name = "Layers"
	skeleton.add_child(layers)
	if holder:
		holder.equipped.connect(_on_equipped)
		holder.fired.connect(_on_fired)
		holder.dry_fired.connect(_on_dry_fired)
		holder.picked_up.connect(_on_picked_up)
		holder.thrown.connect(_on_thrown)
		_on_equipped(holder.current, holder.ammo)
	if player:
		player.movement_event.connect(_on_movement)


## Places the viewmodel for this frame; the player calls it once the camera
## is placed.
func follow(camera: Camera3D, delta: float) -> void:
	var smooth := player.view_settings.camera_smoothing if player else 0.0
	var motion := player.view_settings.camera_motion if player else 1.0
	_step(delta, smooth, motion)
	global_transform = camera.global_transform
	_root.transform = _offset(motion)
	_place_gun(delta)
	_set_projection(camera)


## Where the muzzle appears to be, in the world: for tracers to start from.
func muzzle_point(camera: Camera3D) -> Vector3:
	if gun == null or not gun.visible:
		return camera.global_position + camera.global_basis * Vector3(0.15, -0.15, -0.5)
	var local := camera.global_transform.affine_inverse() * gun.muzzle.global_position
	var scale := _fov_scale(camera)
	return camera.global_transform * Vector3(local.x * scale, local.y * scale, local.z)


# --- Holding --------------------------------------------------------------------

func _on_equipped(weapon: WeaponDef, _ammo: int) -> void:
	if gun:
		gun.queue_free()
		gun = null
	def = weapon
	layers.stop_actions()
	layers.clear_pose(&"guard")
	layers.set_arm_ik("L", Transform3D(), 0.0, Vector3.DOWN)
	layers.set_arm_ik("R", Transform3D(), 0.0, Vector3.DOWN)
	_fan = -1.0
	_top_up = -1.0
	_pending_casings.clear()
	if weapon.is_fists():
		layers.set_pose(&"guard", &"Punch_Enter", 0.8, 1.0, BodyLayers.BOTH_ARMS)
	else:
		gun = WeaponModel.new(weapon, true)
		_root.add_child(gun)
	# Raised into view: from below, turned, snapping up past its place.
	_draw = 0.0
	_throw = -1.0


func _on_fired(weapon: WeaponDef, shot: Dictionary) -> void:
	if weapon.is_fists():
		var left: bool = shot.get("left", true)
		if left:
			layers.play(&"Punch_Jab", BodyLayers.UPPER_BODY, 1.4, 0.1, 0.75, 0.02, 0.12)
		else:
			layers.play(&"Punch_Cross", BodyLayers.UPPER_BODY, 2.0, 0.15, 0.95, 0.02, 0.12)
		_add_recoil(Vector3(0, 0, -0.03), Vector3(0.0, (0.04 if left else -0.05), 0.0))
		return
	if gun == null:
		return
	var fanned: bool = shot.get("fanned", false)
	gun.fire(fanned)
	var r := weapon.recoil
	var yaw := deg_to_rad(randf_range(-r.y, r.y))
	_add_recoil(Vector3(0.0, r.z * 0.25, r.z), Vector3(deg_to_rad(r.x), yaw, yaw * 0.6))
	CombatFx.muzzle_flash(gun.muzzle, true, 1.4 if weapon.pellets > 1 else (1.2 if weapon.recoil.x > 20.0 else 0.9),
			muzzle_point(get_viewport().get_camera_3d()) if get_viewport().get_camera_3d() else null)
	if weapon.ejects:
		_pending_casings.append(gun.eject_time())
	if fanned:
		_fan = 0.0


func _on_dry_fired(_weapon: WeaponDef) -> void:
	if gun:
		gun.fire(true)
	_add_recoil(Vector3(0, 0, 0.005), Vector3(deg_to_rad(-2.0), 0, deg_to_rad(3.0)))


func _on_picked_up(_weapon: WeaponDef, how: StringName) -> void:
	if how == &"top_up":
		# The left hand drops to the belt for the rounds and slaps them in.
		_top_up = 0.0
		layers.play(&"Pistol_Reload", BodyLayers.ARMS["L"], 1.8, 0.1, 1.0, 0.05, 0.12)
		_add_recoil(Vector3(0, 0.01, 0), Vector3(deg_to_rad(-6.0), 0, deg_to_rad(-10.0)))


func _on_thrown(weapon: WeaponDef) -> void:
	# A throwing arm: the right hand winds up and flings (the gun is already
	# gone into the world).
	layers.play(&"Punch_Cross", BodyLayers.UPPER_BODY, 1.6, 0.05, 0.9, 0.02, 0.15)
	_add_recoil(Vector3(0, 0, -0.04), Vector3(deg_to_rad(-6.0), deg_to_rad(-6.0), 0))
	def = weapon


func _place_gun(delta: float) -> void:
	if gun == null:
		# Fists: arms free, the rig raised into the guard.
		_rig.position = FISTS_SHOULDERS - _shoulder_rest
		return
	_rig.position = SHOULDERS - _shoulder_rest
	var d := gun.def
	var draw := _draw_curve(_draw)
	var basis := Basis.from_euler(d.view_rotation * (PI / 180.0))
	# Recoil pivots at the grip: pitch up, twist, push back.
	var recoil_turn := Basis.from_euler(_recoil)
	var lowered := Vector3(0.0, -0.28, 0.12) * (1.0 - draw)
	var lowered_turn := Basis.from_euler(Vector3(deg_to_rad(-50.0), deg_to_rad(20.0), 0.0) * (1.0 - draw))
	var top_up := _top_up_tilt()
	gun.transform = Transform3D(basis * lowered_turn * top_up * recoil_turn,
			d.view_offset + lowered + _shove)
	# Hands on the gun.
	var pole_r := _root.global_basis * Vector3(0.7, -1.0, 0.4)
	var pole_l := _root.global_basis * Vector3(-0.7, -1.0, 0.4)
	var grip := gun.global_transform * Transform3D(Basis.IDENTITY, gun.right_hand + Vector3(0, 0, GRIP_BACK))
	layers.set_arm_ik("R", grip, 1.0, pole_r, false, true)
	if d.hold == WeaponDef.Hold.TWO_HAND and not layers.is_playing(&"Pistol_Reload"):
		var fore := gun.fore.global_transform
		fore.origin += gun.global_basis * Vector3(0.0, -0.02, GRIP_BACK * 0.5)
		layers.set_arm_ik("L", fore, 1.0, pole_l, false, true)
	elif _fan >= 0.0 and _fan < 1.0:
		_fan += delta / WeaponHolder.FAN_INTERVAL
		var swipe := FAN_FROM.lerp(FAN_TO, smoothstep(0.0, 0.6, _fan))
		layers.set_arm_ik("L", gun.global_transform * Transform3D(Basis.IDENTITY, swipe), 1.0 - smoothstep(0.7, 1.0, _fan), pole_l, false, true)
	else:
		layers.set_arm_ik("L", Transform3D(), 0.0, pole_l)
	# Casings fly when the action throws them.
	for i in range(_pending_casings.size() - 1, -1, -1):
		_pending_casings[i] -= delta
		if _pending_casings[i] <= 0.0:
			_pending_casings.remove_at(i)
			var shell := d.action == WeaponDef.Action.PUMP
			CombatFx.casing(self, global_transform.affine_inverse() * gun.eject.global_position,
					(global_transform.affine_inverse().basis * gun.global_basis) * Vector3.RIGHT,
					(global_transform.affine_inverse().basis * gun.global_basis) * Vector3.UP,
					shell, d.accent if shell else CombatFx.BRASS)


## Raising a gun: eases out past its place and settles back.
static func _draw_curve(t: float) -> float:
	var c := clampf(t, 0.0, 1.0) - 1.0
	return 1.0 + 2.2 * c * c * c + 1.2 * c * c


func _top_up_tilt() -> Basis:
	if _top_up < 0.0:
		return Basis.IDENTITY
	var t := clampf(_top_up / 0.5, 0.0, 1.0)
	var tilt := sin(t * PI)
	return Basis.from_euler(Vector3(deg_to_rad(12.0) * tilt, 0.0, deg_to_rad(-28.0) * tilt))


# --- Motion ---------------------------------------------------------------------

func _step(delta: float, smooth: float, _motion: float) -> void:
	_draw = minf(_draw + delta / DRAW_TIME, 1.0)
	if _top_up >= 0.0:
		_top_up += delta
		if _top_up > 0.5:
			_top_up = -1.0
	if _fan >= 1.0:
		_fan = -1.0
	var stiffness := lerpf(SPRING_STIFFNESS.x, SPRING_STIFFNESS.y, smooth)
	var damping := lerpf(SPRING_DAMPING.x, SPRING_DAMPING.y, smooth)
	# What the motion springs are pulled toward this frame.
	var move_target := Vector3.ZERO
	var turn_target := Vector3.ZERO
	if player:
		var look := Vector2(player.yaw, player.pitch)
		if _has_look and delta > 0.0:
			var rate := Vector2(wrapf(look.x - _last_look.x, -PI, PI), look.y - _last_look.y) / delta
			turn_target += Vector3(-rate.y, -rate.x, -rate.x * 0.5) * LOOK_DRAG
			turn_target = turn_target.limit_length(LOOK_DRAG_MAX)
		_last_look = look
		_has_look = true
		var local := Basis(Vector3.UP, player.yaw).inverse() * player.velocity
		move_target += Vector3(-local.x * 0.0025, clampf(-player.velocity.y * 0.003, -0.05, 0.05), clampf(local.z * 0.0015, -0.02, 0.03))
		turn_target.z += clampf(local.x * 0.006, -0.08, 0.08)
		# Sliding: tucked in low, rolled over.
		var sliding := player.state.mode == MovementState.Mode.SLIDE
		_slide = move_toward(_slide, 1.0 if sliding else 0.0, delta * lerpf(14.0, 6.0, smooth))
		move_target += Vector3(-0.04, -0.035, 0.02) * _slide
		turn_target += Vector3(deg_to_rad(4.0), deg_to_rad(6.0), deg_to_rad(18.0)) * _slide
		match player.state.mode:
			MovementState.Mode.SMASH_WINDUP:
				move_target += Vector3(0.0, 0.06, 0.04)
				turn_target.x += deg_to_rad(18.0)
			MovementState.Mode.SMASH:
				move_target += Vector3(0.0, 0.08, 0.06)
				turn_target.x += deg_to_rad(28.0)
			MovementState.Mode.WALLRIDE:
				var right := Basis(Vector3.UP, player.yaw) * Vector3.RIGHT
				turn_target.z += signf(player.state.wallride_normal.dot(right)) * deg_to_rad(10.0)
	var steps := maxi(1, ceili(delta * 240.0))
	var h := delta / steps
	for i in steps:
		_move_v += ((move_target - _move) * stiffness - _move_v * damping) * h
		_move += _move_v * h
		_turn_v += ((turn_target - _turn) * stiffness - _turn_v * damping) * h
		_turn += _turn_v * h
		_recoil_v += (-_recoil * RECOIL_STIFFNESS - _recoil_v * RECOIL_DAMPING) * h
		_recoil += _recoil_v * h
		_shove_v += (-_shove * RECOIL_STIFFNESS - _shove_v * RECOIL_DAMPING) * h
		_shove += _shove_v * h


func _offset(motion: float) -> Transform3D:
	var turn := Basis.from_euler(_turn * motion)
	return Transform3D(turn, _move * motion)


## A shot's kick: a turn (radians: pitch up, yaw, roll) and a shove (meters:
## up, back), landing in full this frame.
func _add_recoil(push: Vector3, turn: Vector3) -> void:
	_recoil += turn
	_shove += push


## Movement knocks it around (GDD §10.3 reactions).
func _on_movement(e: Dictionary) -> void:
	var smooth := player.view_settings.camera_smoothing if player else 0.0
	var knock := func(pos: Vector3, rot: Vector3) -> void:
		_move += pos * (1.0 - smooth)
		_turn += rot * (1.0 - smooth)
		_move_v += pos * smooth * 18.0
		_turn_v += rot * smooth * 18.0
	match e.type:
		&"jump", &"wall_jump":
			knock.call(Vector3(0, -0.03, 0), Vector3(deg_to_rad(-5.0), 0, 0))
		&"land":
			var s := clampf(e.impact_speed / 12.0, 0.1, 1.2)
			knock.call(Vector3(0, -0.06 * s, 0.01), Vector3(deg_to_rad(-8.0) * s, 0, 0))
		&"dash":
			var local := Basis(Vector3.UP, player.yaw).inverse() * (e.direction as Vector3)
			knock.call(Vector3(-local.x * 0.06, 0, -local.z * 0.04), Vector3(0, local.x * deg_to_rad(10.0), -local.x * deg_to_rad(8.0)))
		&"slide_start":
			knock.call(Vector3(0, -0.03, 0), Vector3(deg_to_rad(-4.0), 0, 0))
		&"mantle":
			knock.call(Vector3(0, -0.07, 0.02), Vector3(deg_to_rad(-12.0), 0, deg_to_rad(6.0)))
		&"smash_impact":
			var s := clampf(0.5 + e.drop / 10.0, 0.5, 1.4)
			knock.call(Vector3(0, -0.14 * s, 0.03), Vector3(deg_to_rad(-22.0) * s, 0, deg_to_rad(8.0)))
		&"slam_bounce":
			knock.call(Vector3(0, -0.05, 0), Vector3(deg_to_rad(12.0), 0, 0))


func _set_projection(camera: Camera3D) -> void:
	var scale := _fov_scale(camera)
	for m: ShaderMaterial in [WeaponModel.material(true), CombatFx.flash_material(true)]:
		m.set_shader_parameter(&"fov_scale", scale)
		m.set_shader_parameter(&"near_plane", camera.near)


func _fov_scale(camera: Camera3D) -> float:
	var base := Player.vfov_from_hfov_16_9(player.view_settings.fov_horizontal) if player else camera.fov
	var fov := FOV + (camera.fov - base) * FOV_FOLLOW
	return tan(deg_to_rad(camera.fov) * 0.5) / tan(deg_to_rad(clampf(fov, 20.0, 120.0)) * 0.5)


## The body mesh cut down to the arms (every triangle mostly skinned to an
## upper arm, forearm or hand). Shared, built once.
static func arms_only(sk: Skeleton3D) -> ArrayMesh:
	if _arms_mesh:
		return _arms_mesh
	var arm_bones := {}
	for side: String in ["L", "R"]:
		for bone: String in BodyShape.ARM_BONES[side]:
			arm_bones[sk.find_bone(bone)] = true
	var source: ArrayMesh = PlayerModel.BODY_MESH
	_arms_mesh = ArrayMesh.new()
	for s in source.get_surface_count():
		var arrays := source.surface_get_arrays(s)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var vertex_count := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var per := bones.size() / vertex_count
		var on_arm := PackedByteArray()
		on_arm.resize(vertex_count)
		for v in vertex_count:
			var w := 0.0
			for k in per:
				if arm_bones.has(bones[v * per + k]):
					w += weights[v * per + k]
			on_arm[v] = 1 if w >= 0.35 else 0
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(vertex_count))
		var kept := PackedInt32Array()
		for i in range(0, indices.size(), 3):
			if on_arm[indices[i]] and on_arm[indices[i + 1]] and on_arm[indices[i + 2]]:
				kept.append_array([indices[i], indices[i + 1], indices[i + 2]])
		arrays[Mesh.ARRAY_INDEX] = kept
		_arms_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, source.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
	return _arms_mesh
