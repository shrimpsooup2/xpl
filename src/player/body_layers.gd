class_name BodyLayers
extends SkeletonModifier3D
## Procedural animation laid over whatever the AnimationPlayer posed this
## frame, so one body can run on its legs while its arms aim, punch, or take
## a hit. In order:
##
## 1. Poses: clips held at a set time and weight, driven every frame by the
##    owner (an aim pose that follows the view pitch).
## 2. Actions: clips played once over some bones, fading in and out (a hit
##    reaction, a punch, a throw).
## 3. Arm IK: an arm reaches its hand to a target (a gun's grip) with an
##    analytic two-bone solve, the elbow bending toward a pole.
## 4. Flinches: bones knocked away from a hit on damped springs, and the
##    hips dipping, so a hit anywhere reads where it landed.
##
## The skeleton restores the animation's poses after every update, so
## nothing here accumulates between frames.

## Bones an upper-body clip is laid over: the chest up, arms and fingers.
const UPPER_BODY := ["DEF-spine.002", "DEF-spine.003", "DEF-neck", "DEF-head",
		"DEF-shoulder.L", "DEF-upper_arm.L", "DEF-forearm.L", "DEF-hand.L",
		"DEF-shoulder.R", "DEF-upper_arm.R", "DEF-forearm.R", "DEF-hand.R"]
const ARMS := {
	"L": ["DEF-shoulder.L", "DEF-upper_arm.L", "DEF-forearm.L", "DEF-hand.L"],
	"R": ["DEF-shoulder.R", "DEF-upper_arm.R", "DEF-forearm.R", "DEF-hand.R"],
}
const BOTH_ARMS := ["DEF-shoulder.L", "DEF-upper_arm.L", "DEF-forearm.L", "DEF-hand.L",
		"DEF-shoulder.R", "DEF-upper_arm.R", "DEF-forearm.R", "DEF-hand.R"]
## Flinch springs: (stiffness, damping). Underdamped, so a hit wobbles once
## before settling, like a punching bag.
const FLINCH_SPRING := Vector2(260.0, 11.0)
const FLINCH_MAX := 1.2  # Radians.
## A flinch lands partly on the frame and swings out the rest of the way:
## the share that snaps in, and the speed (rad/s per radian) it swings with.
const FLINCH_SNAP := 0.45
const FLINCH_SWING := 14.0

## Rotation tracks by clip, then bone name.
static var _tracks := {}


## A clip laid over some bones.
class Layer:
	var clip: Animation
	var bones := {}  # bone index -> weight
	var time := 0.0
	var weight := 1.0
	# Actions only:
	var speed := 1.0
	var end := 0.0
	var fade_in := 0.06
	var fade_out := 0.12
	var blend := 0.0
	var done := false

	## How far this action is through (0..1).
	func progress() -> float:
		return clampf(time / maxf(end, 0.001), 0.0, 1.0)


class Spring:
	var angle := Vector3.ZERO  # Axis × angle, skeleton space.
	var velocity := Vector3.ZERO


var _poses := {}  # key -> Layer
var _actions: Array[Layer] = []
var _ik := {}  # side -> {target: Transform3D (world), weight, pole: Vector3 (world), hand: bool}
var _flinch := {}  # bone index -> Spring
var _dip := Vector3.ZERO
var _dip_velocity := Vector3.ZERO
var _player_cache: AnimationPlayer


## Holds `clip_name` at `time` over `bones` (names -> weight, or an array of
## names) with `weight`. Call every frame it should apply; weight 0 or
## clear_pose() removes it.
func set_pose(key: StringName, clip_name: StringName, time: float, weight: float, bones: Variant = UPPER_BODY) -> void:
	if weight <= 0.0:
		_poses.erase(key)
		return
	var layer: Layer = _poses.get(key)
	if layer == null or layer.clip != _clip(clip_name):
		layer = _layer(clip_name, bones)
		if layer == null:
			return
		_poses[key] = layer
	layer.time = time
	layer.weight = weight


func clear_pose(key: StringName) -> void:
	_poses.erase(key)


## Plays `clip_name` once over `bones`, from `from` to `to` seconds of the
## clip (to <= 0: its end), fading in and out. A new action on the same
## clip replaces the old one.
func play(clip_name: StringName, bones: Variant = UPPER_BODY, speed := 1.0, from := 0.0, to := 0.0,
		fade_in := 0.06, fade_out := 0.12, weight := 1.0) -> Layer:
	var layer := _layer(clip_name, bones)
	if layer == null:
		return null
	for old in _actions:
		if old.clip == layer.clip:
			old.done = true
	layer.time = from
	layer.end = to if to > 0.0 else layer.clip.length
	layer.speed = speed
	layer.fade_in = fade_in
	layer.fade_out = fade_out
	layer.weight = weight
	_actions.append(layer)
	return layer


func is_playing(clip_name: StringName) -> bool:
	var clip := _clip(clip_name)
	for a in _actions:
		if a.clip == clip and not a.done:
			return true
	return false


func stop_actions() -> void:
	_actions.clear()


## Reaches an arm ("L" or "R") for `target` (world space: its origin is
## where the hand bone goes, its basis the hand's orientation when
## `orient`). The elbow bends toward `pole` (a world direction). With
## `reach`, a target beyond the arm's length pulls the shoulder after it
## (for arms drawn without a body). Weight 0 lets go.
func set_arm_ik(side: String, target: Transform3D, weight: float, pole: Vector3, orient := true, reach := false) -> void:
	if weight <= 0.0:
		_ik.erase(side)
		return
	_ik[side] = {"target": target, "weight": clampf(weight, 0.0, 1.0), "pole": pole, "orient": orient, "reach": reach}


## Knocks `bone_name` (and everything below it) around `axis` (world
## space) by `angle` radians; it springs back.
func flinch(bone_name: String, axis: Vector3, angle: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or axis.length_squared() < 1e-8:
		return
	var bone := skeleton.find_bone(bone_name)
	if bone < 0:
		return
	var local_axis := (skeleton.global_basis.inverse() * axis).normalized()
	var s: Spring = _flinch.get_or_add(bone, Spring.new())
	s.angle = (s.angle + local_axis * angle * FLINCH_SNAP).limit_length(FLINCH_MAX)
	s.velocity += local_axis * angle * FLINCH_SWING


## Drops the hips by `offset` (world space); they spring back.
func dip(offset: Vector3) -> void:
	var skeleton := get_skeleton()
	if skeleton:
		var local := skeleton.global_basis.inverse() * offset
		_dip += local * FLINCH_SNAP
		_dip_velocity += local * FLINCH_SWING


func is_settled() -> bool:
	return _actions.is_empty() and _flinch.is_empty() and _dip.length() < 0.001


func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	for key: StringName in _poses:
		var layer: Layer = _poses[key]
		_apply(skeleton, layer, layer.weight)
	_step_actions(skeleton, delta)
	for side: String in _ik:
		_solve_arm(skeleton, side, _ik[side])
	_step_flinches(skeleton, delta)


func _step_actions(skeleton: Skeleton3D, delta: float) -> void:
	for layer in _actions:
		if layer.done:
			continue
		layer.time += delta * layer.speed
		layer.blend = minf(layer.blend + delta / maxf(layer.fade_in, 0.001), 1.0)
		var left := (layer.end - layer.time) / maxf(layer.speed, 0.001)
		if left <= 0.0:
			layer.done = true
			continue
		var fade := clampf(left / maxf(layer.fade_out, 0.001), 0.0, 1.0)
		_apply(skeleton, layer, layer.weight * minf(layer.blend, fade))
	_actions = _actions.filter(func(l: Layer) -> bool: return not l.done)


func _apply(skeleton: Skeleton3D, layer: Layer, weight: float) -> void:
	if weight <= 0.0:
		return
	var tracks: Dictionary = _tracks[layer.clip]
	var t := clampf(layer.time, 0.0, layer.clip.length)
	for bone: int in layer.bones:
		var track: int = tracks.get(bone, -1)
		if track < 0:
			continue
		var w: float = weight * layer.bones[bone]
		var rot := layer.clip.rotation_track_interpolate(track, t)
		var current := skeleton.get_bone_pose_rotation(bone)
		skeleton.set_bone_pose_rotation(bone, current.slerp(rot, w) if w < 1.0 else rot)


## Analytic two-bone IK: upper arm and forearm, the hand on the target.
func _solve_arm(skeleton: Skeleton3D, side: String, ik: Dictionary) -> void:
	var names: Array = ARMS[side]
	var shoulder := skeleton.find_bone(names[0])
	var upper := skeleton.find_bone(names[1])
	var fore := skeleton.find_bone(names[2])
	var hand := skeleton.find_bone(names[3])
	var to_skeleton := skeleton.global_transform.affine_inverse()
	var target: Transform3D = to_skeleton * (ik.target as Transform3D)
	var pole: Vector3 = (to_skeleton.basis * (ik.pole as Vector3)).normalized()
	var weight: float = ik.weight

	var parent := skeleton.get_bone_global_pose(shoulder)
	var upper_local := skeleton.get_bone_pose(upper)
	var fore_local := skeleton.get_bone_pose(fore)
	var hand_local := skeleton.get_bone_pose(hand)
	var upper_global := parent * upper_local
	var fore_global := upper_global * fore_local
	var hand_global := fore_global * hand_local
	var a := upper_global.origin
	var b := fore_global.origin
	var c := hand_global.origin
	var l1 := a.distance_to(b)
	var l2 := b.distance_to(c)
	var to_target := target.origin - a
	var excess := to_target.length() - (l1 + l2) * 0.97
	if ik.reach and excess > 0.0:
		# Slide the shoulder toward the target by what the arm can't reach.
		var move := to_target.normalized() * excess * weight
		var grand := skeleton.get_bone_global_pose(skeleton.get_bone_parent(shoulder))
		skeleton.set_bone_pose_position(shoulder, skeleton.get_bone_pose_position(shoulder) + grand.basis.inverse() * move)
		parent.origin += move
		upper_global.origin += move
		fore_global.origin += move
		a += move
		b += move
		c += move
		to_target = target.origin - a
	var d := clampf(to_target.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	var dir := to_target.normalized() if to_target.length() > 1e-5 else (c - a).normalized()
	var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var bend := pole - dir * pole.dot(dir)
	bend = bend.normalized() if bend.length() > 1e-5 else dir.cross(Vector3.RIGHT).normalized()
	var elbow := a + dir * (l1 * cos_a) + bend * (l1 * sqrt(1.0 - cos_a * cos_a))
	var hand_at := a + dir * d

	# Upper arm: swing its bone direction onto the elbow.
	var swing := Quaternion((b - a).normalized(), (elbow - a).normalized())
	var new_upper := Basis(swing) * upper_global.basis.orthonormalized()
	var new_upper_local := (parent.basis.orthonormalized().inverse() * new_upper).get_rotation_quaternion()
	var upper_rot := upper_local.basis.get_rotation_quaternion().slerp(new_upper_local, weight)
	skeleton.set_bone_pose_rotation(upper, upper_rot)
	# Forearm, from the upper arm as it now is.
	upper_global = parent * Transform3D(Basis(upper_rot).scaled(upper_local.basis.get_scale()), upper_local.origin)
	fore_global = upper_global * fore_local
	b = fore_global.origin
	c = (fore_global * hand_local).origin
	var swing2 := Quaternion((c - b).normalized(), (hand_at - b).normalized() if weight >= 1.0 else ((hand_at - b).normalized().slerp((c - b).normalized(), 1.0 - weight)))
	var new_fore := Basis(swing2) * fore_global.basis.orthonormalized()
	var fore_rot := (upper_global.basis.orthonormalized().inverse() * new_fore).get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(fore, fore_rot)
	if ik.orient:
		fore_global = upper_global * Transform3D(Basis(fore_rot).scaled(fore_local.basis.get_scale()), fore_local.origin)
		var hand_rot := (fore_global.basis.orthonormalized().inverse() * target.basis.orthonormalized()).get_rotation_quaternion()
		skeleton.set_bone_pose_rotation(hand, hand_local.basis.get_rotation_quaternion().slerp(hand_rot, weight))


func _step_flinches(skeleton: Skeleton3D, delta: float) -> void:
	var steps := maxi(1, ceili(delta * 240.0))
	var h := delta / steps
	for bone: int in _flinch.keys():
		var s: Spring = _flinch[bone]
		for i in steps:
			s.velocity += (-s.angle * FLINCH_SPRING.x - s.velocity * FLINCH_SPRING.y) * h
			s.angle += s.velocity * h
		if s.angle.length() < 0.001 and s.velocity.length() < 0.01:
			_flinch.erase(bone)
			continue
		var global := skeleton.get_bone_global_pose(bone)
		var axis_local := global.basis.orthonormalized().inverse() * s.angle.normalized()
		var rot := skeleton.get_bone_pose_rotation(bone) * Quaternion(axis_local.normalized(), s.angle.length())
		skeleton.set_bone_pose_rotation(bone, rot)
	if _dip.length() > 0.0005 or _dip_velocity.length() > 0.005:
		for i in steps:
			_dip_velocity += (-_dip * FLINCH_SPRING.x - _dip_velocity * FLINCH_SPRING.y) * h
			_dip += _dip_velocity * h
		var hips := skeleton.find_bone("DEF-hips")
		var parent := skeleton.get_bone_global_pose(skeleton.get_bone_parent(hips))
		skeleton.set_bone_pose_position(hips, skeleton.get_bone_pose_position(hips) + parent.basis.inverse() * _dip)
	else:
		_dip = Vector3.ZERO
		_dip_velocity = Vector3.ZERO


func _layer(clip_name: StringName, bones: Variant) -> Layer:
	var clip := _clip(clip_name)
	var skeleton := get_skeleton()
	if clip == null or skeleton == null:
		return null
	if not _tracks.has(clip):
		var by_bone := {}
		for t in clip.get_track_count():
			if clip.track_get_type(t) == Animation.TYPE_ROTATION_3D:
				var bone := skeleton.find_bone(clip.track_get_path(t).get_concatenated_subnames())
				if bone >= 0:
					by_bone[bone] = t
		_tracks[clip] = by_bone
	var layer := Layer.new()
	layer.clip = clip
	var weights: Dictionary = bones if bones is Dictionary else {}
	if bones is Array:
		for n: String in bones:
			weights[n] = 1.0
	for n: String in weights:
		var bone := skeleton.find_bone(n)
		if bone >= 0:
			layer.bones[bone] = weights[n]
	return layer


## Clips come from the rig's AnimationPlayer, found up the tree from the
## skeleton (in the imported rig it's the skeleton's grandparent's child).
func _clip(clip_name: StringName) -> Animation:
	if _player_cache == null:
		var node: Node = get_skeleton()
		while node and _player_cache == null:
			node = node.get_parent()
			if node:
				for child in node.get_children():
					if child is AnimationPlayer:
						_player_cache = child
						break
	if _player_cache and _player_cache.has_animation(clip_name):
		return _player_cache.get_animation(clip_name)
	return null
