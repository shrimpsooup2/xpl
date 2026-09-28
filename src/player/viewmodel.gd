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

## Each arm is cut off this far down the upper arm from the shoulder joint.
const ARM_CUT_DEPTH := 0.1
## From the cut, each arm carries on (first person only) as the same tube,
## the same thickness, straight on up the upper arm, so an arm never shows an
## end, it just runs off screen. The viewmodel's shoulders sit close to the
## eye, though, and straight on would soon run into it, so once the tube is
## SLEEVE_BEND_DEPTH from the eye (by then off screen) it bends down and away
## from the line of sight (radius SLEEVE_BEND_RADIUS) and runs on for
## SLEEVE_TAIL. Lengths in rig meters, the depth in meters from the eye.
const SLEEVE_BEND_DEPTH := 0.2
const SLEEVE_MAX_STRAIGHT := 0.4
const SLEEVE_MIN_STRAIGHT := 0.03
const SLEEVE_BEND_RADIUS := 0.12
const SLEEVE_TAIL := 0.35
const SLEEVE_BEND_RINGS := 8
## Vertical field of view it's drawn with, and how much of the camera's FOV
## swings (speed, slides, punches) it still follows.
const FOV := 62.0
const FOV_FOLLOW := 0.3
## The arms are the body's, a bit smaller: the blob's arms are thick, and
## at full size they'd fill the corner of the screen.
const RIG_SCALE := 0.8
## Where the shoulders sit relative to the eye (only the arms are drawn, so
## they can go anywhere that looks right): low and back, so the upper arms
## rise from below the screen, away from the eye, and whatever's past the
## cut runs off the bottom. Empty-handed they sit a touch higher.
const SHOULDERS := Vector3(0.0, -0.36, -0.1)
const FISTS_SHOULDERS := Vector3(0.0, -0.32, -0.1)
## Empty-handed, the fists are held up in a guard by IK, like hands on a gun:
## where each fist sits (from the eye). A punch is all the way out when it
## lands (WeaponHolder.PUNCH_LANDS), holds a moment, and comes back. Each
## kind (WeaponHolder.PUNCH_KINDS) swings out along a curve through `via` to
## `to`, with the elbow leaning toward `pole`: a straight drives down the
## middle, a hook swings out wide with the elbow up and comes across, an
## uppercut dips and drives up.
const FIST_GUARD := {"L": Vector3(-0.13, -0.16, -0.42), "R": Vector3(0.15, -0.19, -0.36)}
const GUARD_POLE := Vector3(0.6, -1.0, 0.3)  # For the right arm; mirrored for the left.
const PUNCHES := {
	&"straight": {"via": Vector3(0.05, -0.1, -0.5), "to": Vector3(0.03, -0.08, -0.65), "pole": Vector3(0.6, -1.0, 0.3)},
	&"hook": {"via": Vector3(0.26, -0.06, -0.4), "to": Vector3(-0.02, -0.06, -0.5), "pole": Vector3(1.0, 0.4, 0.2)},
	&"uppercut": {"via": Vector3(0.09, -0.3, -0.36), "to": Vector3(0.04, 0.0, -0.45), "pole": Vector3(0.3, -1.0, 0.6)},
}
const PUNCH_OUT := 0.07
const PUNCH_HOLD := 0.04
const PUNCH_BACK := 0.16
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
var _sleeves: MeshInstance3D
var _sleeve_mesh := ArrayMesh.new()
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
var _punch := {"L": -1.0, "R": -1.0}  # Seconds into each fist's punch; -1 in the guard.
var _punch_kind := {"L": &"straight", "R": &"straight"}
var _fan := -1.0
var _top_up := -1.0
var _pending_casings: Array[float] = []
var _slide := 0.0
var _shoulder_rest := Vector3.ZERO  # Shoulders' midpoint, rig space turned and scaled.

static var _arms_mesh: ArrayMesh
## Where each arm is cut, for the sleeves: [{bone (the upper arm), along
## (shoulder to elbow, rest), points, normals (the cut's rim, in order),
## bones, weights, per (weights per vertex)}].
static var _arm_ends: Array[Dictionary] = []


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
	_sleeves = MeshInstance3D.new()
	_sleeves.name = "Sleeves"
	_sleeves.mesh = _sleeve_mesh
	skeleton.add_child(_sleeves)
	for mi: MeshInstance3D in [_arms, _sleeves]:
		mi.material_override = WeaponModel.material(true)
		mi.set_instance_shader_parameter(&"color", PlayerModel.BODY_COLOR)
		mi.set_instance_shader_parameter(&"gloss", 0.25)
		mi.set_instance_shader_parameter(&"rim_amount", 0.3)
		mi.set_instance_shader_parameter(&"roughness_amount", 0.2)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layers = BodyLayers.new()
	layers.name = "Layers"
	skeleton.add_child(layers)
	layers.modification_processed.connect(_update_sleeves)
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
	# Scoping in drops the arms out of the way; fully in, only the scope shows.
	var scoped := clampf((player.zoom_amount() - 1.0) / 0.6, 0.0, 1.0) if player else 0.0
	_root.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-25.0) * scoped), Vector3(0.0, -0.3, 0.1) * scoped) * _offset(motion)
	_root.visible = scoped < 0.95
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
		var kind: StringName = shot.get("kind", &"straight")
		var side := "L" if left else "R"
		_punch[side] = 0.0
		_punch_kind[side] = kind if PUNCHES.has(kind) else &"straight"
		# The clips turn the shoulders into the punch; the fists go by IK.
		if left:
			layers.play(&"Punch_Jab", BodyLayers.UPPER_BODY, 1.4, 0.1, 0.75, 0.02, 0.12)
		else:
			layers.play(&"Punch_Cross", BodyLayers.UPPER_BODY, 2.0, 0.15, 0.95, 0.02, 0.12)
		var across := 1.0 if left else -1.0  # Which way the view swings with it.
		match _punch_kind[side]:
			&"hook":
				_add_recoil(Vector3(0, 0, -0.02), Vector3(0.0, 0.09 * across, 0.06 * across))
			&"uppercut":
				_add_recoil(Vector3(0, 0.01, -0.02), Vector3(deg_to_rad(4.0), 0.02 * across, 0.0))
			_:
				_add_recoil(Vector3(0, 0, -0.03), Vector3(0.0, 0.045 * across, 0.0))
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
	# A throwing arm: the right hand flings forward (the gun is already gone
	# into the world).
	layers.play(&"Punch_Cross", BodyLayers.UPPER_BODY, 1.6, 0.05, 0.9, 0.02, 0.15)
	_punch["R"] = 0.0
	_punch_kind["R"] = &"straight"
	_add_recoil(Vector3(0, 0, -0.04), Vector3(deg_to_rad(-6.0), deg_to_rad(-6.0), 0))
	def = weapon


func _place_gun(delta: float) -> void:
	if gun == null:
		_place_fists(delta)
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


## Fists: up in the guard by IK, thrown out and back on a punch, raised into
## view like a gun when they come out.
func _place_fists(delta: float) -> void:
	_rig.position = FISTS_SHOULDERS - _shoulder_rest
	var raise := Vector3(0.0, -0.28, 0.12) * (1.0 - _draw_curve(_draw))
	for side: String in ["L", "R"]:
		var mirror := Vector3(-1.0, 1.0, 1.0) if side == "L" else Vector3.ONE
		var guard: Vector3 = FIST_GUARD[side]
		var at := guard
		var pole := GUARD_POLE
		var t: float = _punch[side]
		if t >= 0.0:
			var punch: Dictionary = PUNCHES[_punch_kind[side]]
			var to: Vector3 = (punch.to as Vector3) * mirror
			var out := smoothstep(0.0, PUNCH_OUT, t) - smoothstep(PUNCH_OUT + PUNCH_HOLD, PUNCH_OUT + PUNCH_HOLD + PUNCH_BACK, t)
			if t < PUNCH_OUT + PUNCH_HOLD:
				# Out along the curve through `via`; straight back after.
				var via: Vector3 = (punch.via as Vector3) * mirror
				at = guard.lerp(via, out).lerp(via.lerp(to, out), out)
			else:
				at = guard.lerp(to, out)
			pole = GUARD_POLE.lerp(punch.pole, out)
			_punch[side] = t + delta if t < PUNCH_OUT + PUNCH_HOLD + PUNCH_BACK else -1.0
		layers.set_arm_ik(side, _root.global_transform * Transform3D(Basis.IDENTITY, at + raise), 1.0,
				_root.global_basis * (pole * mirror), false, true)


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
		move_target += Vector3(-local.x * 0.0025, clampf(-player.velocity.y * 0.002, -0.03, 0.025), clampf(local.z * 0.0015, -0.02, 0.03))
		turn_target.z += clampf(local.x * 0.006, -0.08, 0.08)
		# Sliding: tucked in low, rolled over.
		var sliding := player.state.mode == MovementState.Mode.SLIDE
		_slide = move_toward(_slide, 1.0 if sliding else 0.0, delta * lerpf(14.0, 6.0, smooth))
		move_target += Vector3(-0.04, -0.035, 0.02) * _slide
		turn_target += Vector3(deg_to_rad(4.0), deg_to_rad(6.0), deg_to_rad(18.0)) * _slide
		match player.state.mode:
			# Braced for the slam: pulled in during the hang, pushed out and
			# down on the way down (the fall itself lifts it a little).
			MovementState.Mode.SMASH_WINDUP:
				move_target += Vector3(0.0, 0.01, 0.04)
				turn_target.x += deg_to_rad(5.0)
			MovementState.Mode.SMASH:
				move_target += Vector3(0.0, -0.035, -0.02)
				turn_target.x += deg_to_rad(-4.0)
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


## The body mesh cut down to the arms: each arm sliced off cleanly across
## the upper arm (triangles on the cut are split, the hole capped), and
## rebound to the arm's bones alone, so nothing stretches back toward the
## chest and an arm pointing back at the camera shows a smooth round end
## rather than the rim of an open tube. Shared, built once.
static func arms_only(sk: Skeleton3D) -> ArrayMesh:
	if _arms_mesh:
		return _arms_mesh
	_arm_ends.clear()
	var arm_bones := {}
	var cuts := {}  # Side -> [origin, direction] of the upper arm, rest pose.
	for side: String in ["L", "R"]:
		var names: Array = BodyShape.ARM_BONES[side]
		for bone: String in names:
			arm_bones[sk.find_bone(bone)] = true
		var shoulder := sk.get_bone_global_rest(sk.find_bone(names[0])).origin
		var elbow := sk.get_bone_global_rest(sk.find_bone(names[1])).origin
		cuts[side] = [shoulder, (elbow - shoulder).normalized()]
	var upper_arm := {"L": sk.find_bone(BodyShape.ARM_BONES.L[0]), "R": sk.find_bone(BodyShape.ARM_BONES.R[0])}
	var source: ArrayMesh = PlayerModel.BODY_MESH
	_arms_mesh = ArrayMesh.new()
	for s in source.get_surface_count():
		var arrays := source.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var vertex_count := verts.size()
		var per := bones.size() / vertex_count
		# Rebind to the arm alone.
		for v in vertex_count:
			var w := 0.0
			for k in per:
				if arm_bones.has(bones[v * per + k]):
					w += weights[v * per + k]
			for k in per:
				var i := v * per + k
				if w > 0.0:
					weights[i] = weights[i] / w if arm_bones.has(bones[i]) else 0.0
				else:
					bones[i] = upper_arm["L" if verts[v].x > 0.0 else "R"] if k == 0 else 0
					weights[i] = 1.0 if k == 0 else 0.0
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		# Signed distance past each arm's cut, and whether it's on the arm at all.
		var past := PackedFloat32Array()
		var near := PackedByteArray()
		past.resize(vertex_count)
		near.resize(vertex_count)
		for v in vertex_count:
			var cut: Array = cuts["L" if verts[v].x > 0.0 else "R"]
			var rel: Vector3 = verts[v] - cut[0]
			var along := rel.dot(cut[1])
			past[v] = along - ARM_CUT_DEPTH
			near[v] = 1 if (rel - (cut[1] as Vector3) * along).length() <= BodyShape.ARM_RADIUS + 0.02 and along > -0.1 else 0
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var kept := PackedInt32Array()
		var split := {}  # Edge -> new vertex on the cut.
		for i in range(0, indices.size(), 3):
			var tri := [indices[i], indices[i + 1], indices[i + 2]]
			if not (near[tri[0]] and near[tri[1]] and near[tri[2]]):
				continue
			var inside := tri.filter(func(v: int) -> bool: return past[v] > 0.0).size()
			if inside == 3:
				kept.append_array(tri)
			elif inside > 0:
				# Clip to the kept side, keeping the winding.
				var poly: Array[int] = []
				for k in 3:
					var a: int = tri[k]
					var b: int = tri[(k + 1) % 3]
					if past[a] > 0.0:
						poly.append(a)
					if (past[a] > 0.0) != (past[b] > 0.0):
						poly.append(_split_edge(arrays, past, split, a, b))
				for k in range(1, poly.size() - 1):
					kept.append_array([poly[0], poly[k], poly[k + 1]])
		for loop in _cap_holes(arrays, kept):
			_remember_end(arrays, loop, cuts, upper_arm, per)
		arrays[Mesh.ARRAY_INDEX] = kept
		_arms_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, source.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
	return _arms_mesh


## The vertex where edge a–b crosses the cut (made once per edge).
static func _split_edge(arrays: Array, past: PackedFloat32Array, split: Dictionary, a: int, b: int) -> int:
	var key := Vector2i(mini(a, b), maxi(a, b))
	if split.has(key):
		return split[key]
	var t := past[a] / (past[a] - past[b])
	var inner := a if past[a] > 0.0 else b
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var index := verts.size()
	verts.append(verts[a].lerp(verts[b], t))
	normals.append(normals[a].lerp(normals[b], t).normalized())
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	for slot: int in [Mesh.ARRAY_TANGENT, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS]:
		if arrays[slot] == null:
			continue
		var values: Variant = arrays[slot]  # A packed array: copied, so set back.
		var stride: int = values.size() / index
		for k in stride:
			values.append(values[inner * stride + k])
		arrays[slot] = values
	split[key] = index
	return index


## Keeps the rim of an arm's cut (`loop`, in the order the triangles run it)
## for its sleeve.
static func _remember_end(arrays: Array, loop: Array, cuts: Dictionary, upper_arm: Dictionary, per: int) -> void:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var center := Vector3.ZERO
	for v: int in loop:
		center += verts[v]
	center /= loop.size()
	var side := "L" if center.x > 0.0 else "R"
	var cut: Array = cuts[side]
	if absf((center - (cut[0] as Vector3)).dot(cut[1]) - ARM_CUT_DEPTH) > 0.03:
		return  # Not the cut.
	var end := {"bone": upper_arm[side], "along": cut[1], "per": per,
			"points": PackedVector3Array(), "normals": PackedVector3Array(),
			"bones": PackedInt32Array(), "weights": PackedFloat32Array()}
	for v: int in loop:
		end.points.append(verts[v])
		end.normals.append(normals[v])
		for k in per:
			end.bones.append(bones[v * per + k])
			end.weights.append(weights[v * per + k])
	_arm_ends.append(end)


## Closes every hole in the triangle list `indices` (appending to it and to
## the vertex arrays) with a fan around the hole's centre. The fan runs
## against the boundary edges' direction, so it faces outward like the rest.
## Returns the holes' rims, each in the order the triangles run it.
static func _cap_holes(arrays: Array, indices: PackedInt32Array) -> Array[Array]:
	var loops: Array[Array] = []
	var count := {}
	for i in range(0, indices.size(), 3):
		for k in 3:
			var a := indices[i + k]
			var b := indices[i + (k + 1) % 3]
			var key := Vector2i(mini(a, b), maxi(a, b))
			count[key] = count.get(key, 0) + 1
	var next := {}  # Boundary edges as the triangles run them: a -> b.
	for i in range(0, indices.size(), 3):
		for k in 3:
			var a := indices[i + k]
			var b := indices[i + (k + 1) % 3]
			if count[Vector2i(mini(a, b), maxi(a, b))] == 1:
				next[a] = b
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	while not next.is_empty():
		var start: int = next.keys()[0]
		var loop: Array[int] = []
		var v := start
		while next.has(v):
			loop.append(v)
			var n: int = next[v]
			next.erase(v)
			v = n
		if loop.size() < 3:
			continue
		loops.append(loop)
		var center := Vector3.ZERO
		for i in loop:
			center += verts[i]
		center /= loop.size()
		var c := verts.size()
		verts.append(center)
		# Skinned like the loop's first vertex; faces along the arm, outward.
		var outward := Vector3.ZERO
		for i in loop.size():
			var a := loop[i]
			var b := loop[(i + 1) % loop.size()]
			indices.append_array([b, a, c])
			outward += (verts[a] - center).cross(verts[b] - center)
		normals.append(-outward.normalized())
		for slot: int in [Mesh.ARRAY_TANGENT, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS]:
			if arrays[slot] == null:
				continue
			var values: Variant = arrays[slot]  # A packed array: copied, so set back.
			var stride: int = values.size() / (verts.size() - 1)
			for k in stride:
				values.append(values[loop[0] * stride + k])
			arrays[slot] = values
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	return loops


## Rebuilds the sleeves on this frame's pose (see SLEEVE_BEND_DEPTH): the
## cut's rim, exactly where the skinned arm puts it, carried straight on back
## up the upper arm, then bent away out of view, the same shape all the way.
func _update_sleeves() -> void:
	_sleeve_mesh.clear_surfaces()
	if _arm_ends.is_empty() or not _root.visible:
		return
	var skin := {}  # Bone -> its pose from rest, this frame.
	var to_view := global_transform.affine_inverse() * skeleton.global_transform
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for end: Dictionary in _arm_ends:
		var points: PackedVector3Array = end.points
		var count := points.size()
		var per: int = end.per
		var rim := PackedVector3Array()
		var rim_normals := PackedVector3Array()
		var center := Vector3.ZERO
		for i in count:
			var p := Vector3.ZERO
			var n := Vector3.ZERO
			for k in per:
				var w: float = end.weights[i * per + k]
				if w <= 0.0:
					continue
				var b: int = end.bones[i * per + k]
				if not skin.has(b):
					skin[b] = skeleton.get_bone_global_pose(b) * skeleton.get_bone_global_rest(b).affine_inverse()
				var m: Transform3D = skin[b]
				p += (m * points[i]) * w
				n += (m.basis * (end.normals[i] as Vector3)) * w
			rim.append(p)
			rim_normals.append(n.normalized())
			center += p
		center /= count
		var bone: int = end.bone
		var from_rest := skeleton.get_bone_global_pose(bone).basis * skeleton.get_bone_global_rest(bone).basis.inverse()
		var back := -(from_rest * (end.along as Vector3)).normalized()
		# Straight on until it's SLEEVE_BEND_DEPTH from the eye.
		var center_view := to_view * center
		var toward_eye := (to_view.basis * back).z  # View depth lost per rig meter.
		var straight := SLEEVE_MIN_STRAIGHT
		if toward_eye > 0.01:
			straight = clampf((-center_view.z - SLEEVE_BEND_DEPTH) / toward_eye, SLEEVE_MIN_STRAIGHT, SLEEVE_MAX_STRAIGHT)
		# Then down and out, away from the line of sight.
		var away_view := Vector3(signf(center_view.x) * 0.4, -1.0, 0.0)
		var away := (to_view.basis.inverse() * away_view).normalized()
		# The path: (center, heading, turn) at each ring after the rim.
		var path: Array[Array] = []
		var at := center + back * straight
		path.append([at, Quaternion.IDENTITY])
		var angle := back.angle_to(away)
		if angle > 0.01:
			var side := (away - back * back.dot(away)).normalized()
			var axis := back.cross(side).normalized()
			for j in range(1, SLEEVE_BEND_RINGS + 1):
				var phi := angle * j / SLEEVE_BEND_RINGS
				path.append([at + (back * sin(phi) + side * (1.0 - cos(phi))) * SLEEVE_BEND_RADIUS, Quaternion(axis, phi)])
		var last: Array = path[-1]
		path.append([(last[0] as Vector3) + away * SLEEVE_TAIL, last[1]])
		var previous := rim
		var previous_turn := Quaternion.IDENTITY
		for step: Array in path:
			var ring_at: Vector3 = step[0]
			var turn: Quaternion = step[1]
			var ring := PackedVector3Array()
			for i in count:
				ring.append(ring_at + turn * (rim[i] - center))
			for i in count:
				var i1 := (i + 1) % count
				verts.append_array([previous[i1], previous[i], ring[i], previous[i1], ring[i], ring[i1]])
				normals.append_array([previous_turn * rim_normals[i1], previous_turn * rim_normals[i], turn * rim_normals[i],
						previous_turn * rim_normals[i1], turn * rim_normals[i], turn * rim_normals[i1]])
			previous = ring
			previous_turn = turn
		# Close the far end (off screen).
		var tip: Vector3 = path[-1][0]
		for i in count:
			verts.append_array([previous[(i + 1) % count], previous[i], tip])
			normals.append_array([away, away, away])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	_sleeve_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
