class_name BodyShape
extends RefCounted
## The player's body shape, shared by the runtime model and the offline
## generator (tools/gen_body.gd).
##
## Proportions: a blank, blobby, gingerbread-person figure. A big ball head,
## one flat slab of a torso, long tube arms, short stubby legs, no hands or
## feet, everything melted together with no visible joints. The Universal
## Animation Library rig is human-proportioned, so reshape_skeleton() moves
## its bones to fit before anything is built or animated.
##
## Rig space: the rig faces +Z and its left is +X.

const RIG_SCENE := preload("res://assets/third_party/quaternius_ual/AnimationLibrary_Godot_Standard.gltf")

## Lowers the hips (and all hips animation) so the legs get short.
const HIPS_SCALE := 0.654
## Stretches the spine so the torso gets long.
const SPINE_SCALE := 1.40
const THIGH_SCALE := 0.625
const SHIN_SCALE := 0.583
## Leg centres sit this far either side of the middle.
const LEG_SPREAD := 0.125

# Shape (meters, rig space after reshaping).
const HEAD_RADIUS := 0.165
const HEAD_OFFSET := Vector3(0.0, 0.095, 0.01)
const NECK_RADIUS := 0.115
const TORSO_CENTER := Vector3(0.0, 1.005, -0.02)
const TORSO_HALF := Vector3(0.215, 0.395, 0.12)
const TORSO_ROUNDING := 0.1
const UPPER_ARM_RADIUS := 0.118
const FOREARM_RADIUS := 0.11
## How far the rounded arm tip reaches past the hand bone.
const ARM_TIP := 0.07
const LEG_RADIUS := 0.103
# Smooth-union blend widths: how soft the joins are.
const BLEND_NECK := 0.05
const BLEND_HEAD := 0.04
const BLEND_ARM := 0.03
const BLEND_ARMS_TO_BODY := 0.08
const BLEND_LEGS_TO_BODY := 0.05

## The heart: chest front, a little to the character's left (GDD §6.2).
const HEART_RADIUS := 0.05
const HEART_BONE := "DEF-spine.003"
const HEART_OFFSET := Vector3(0.085, 0.13, 0.115)

const TORSO_BONES := ["DEF-hips", "DEF-spine.001", "DEF-spine.002", "DEF-spine.003", "DEF-neck", "DEF-head"]
const ARM_BONES := {"L": ["DEF-upper_arm.L", "DEF-forearm.L", "DEF-hand.L"], "R": ["DEF-upper_arm.R", "DEF-forearm.R", "DEF-hand.R"]}
const LEG_BONES := {"L": ["DEF-thigh.L", "DEF-shin.L", "DEF-foot.L"], "R": ["DEF-thigh.R", "DEF-shin.R", "DEF-foot.R"]}

static var _hips_animation_scaled := false


## Moves the rig's bones to the body's proportions.
static func reshape_skeleton(sk: Skeleton3D) -> void:
	_scale_rest(sk, "DEF-hips", HIPS_SCALE)
	for bone: String in ["DEF-spine.001", "DEF-spine.002", "DEF-spine.003", "DEF-neck"]:
		_scale_rest(sk, bone, SPINE_SCALE)
	for side: String in ["L", "R"]:
		var thigh := sk.find_bone("DEF-thigh." + side)
		var rest := sk.get_bone_rest(thigh)
		rest.origin.x = LEG_SPREAD * signf(rest.origin.x)
		sk.set_bone_rest(thigh, rest)
		_scale_rest(sk, "DEF-shin." + side, THIGH_SCALE)
		_scale_rest(sk, "DEF-foot." + side, SHIN_SCALE)
		_scale_rest(sk, "DEF-toe." + side, 0.5)
	sk.reset_bone_poses()


## Scales every animation's hips motion to the shorter legs. Animations are
## shared resources, so this happens once per run.
static func scale_hips_animation(anim: AnimationPlayer) -> void:
	if _hips_animation_scaled:
		return
	_hips_animation_scaled = true
	for clip_name in anim.get_animation_list():
		var clip := anim.get_animation(clip_name)
		for t in clip.get_track_count():
			if clip.track_get_type(t) == Animation.TYPE_POSITION_3D and String(clip.track_get_path(t)).ends_with(":DEF-hips"):
				for k in clip.track_get_key_count(t):
					clip.track_set_key_value(t, k, clip.track_get_key_value(t, k) * HIPS_SCALE)


static func _scale_rest(sk: Skeleton3D, bone_name: String, s: float) -> void:
	var i := sk.find_bone(bone_name)
	var rest := sk.get_bone_rest(i)
	rest.origin *= s
	sk.set_bone_rest(i, rest)


# --- Signed distance field ----------------------------------------------------

## Precomputes the shape's primitives from a reshaped skeleton's rest pose.
static func primitives(sk: Skeleton3D) -> Dictionary:
	var at := func(bone: String) -> Vector3: return sk.get_bone_global_rest(sk.find_bone(bone)).origin
	var prims := {
		"head": at.call("DEF-head") + HEAD_OFFSET,
		"neck_a": at.call("DEF-neck"),
		"neck_b": at.call("DEF-head") + Vector3(0, 0.05, 0),
	}
	for side: String in ["L", "R"]:
		var shoulder: Vector3 = at.call("DEF-upper_arm." + side)
		var elbow: Vector3 = at.call("DEF-forearm." + side)
		var hand: Vector3 = at.call("DEF-hand." + side)
		prims["arm_a_" + side] = shoulder
		prims["arm_b_" + side] = elbow
		prims["arm_c_" + side] = hand + (hand - elbow).normalized() * ARM_TIP
		prims["leg_a_" + side] = at.call("DEF-thigh." + side)
		prims["leg_b_" + side] = at.call("DEF-foot." + side)
	return prims


static func sdf(p: Vector3, prims: Dictionary) -> float:
	var torso := _round_box(p - TORSO_CENTER, TORSO_HALF, TORSO_ROUNDING)
	var upper := _smin(torso, _capsule(p, prims.neck_a, prims.neck_b, NECK_RADIUS), BLEND_NECK)
	upper = _smin(upper, p.distance_to(prims.head) - HEAD_RADIUS, BLEND_HEAD)
	var arms := INF
	var legs := INF
	for side: String in ["L", "R"]:
		var arm := _smin(
				_capsule(p, prims["arm_a_" + side], prims["arm_b_" + side], UPPER_ARM_RADIUS),
				_capsule(p, prims["arm_b_" + side], prims["arm_c_" + side], FOREARM_RADIUS), BLEND_ARM)
		arms = minf(arms, arm)
		# Legs join with a hard min so the slit between them stays open.
		legs = minf(legs, _capsule(p, prims["leg_a_" + side], prims["leg_b_" + side], LEG_RADIUS))
	var body := _smin(upper, arms, BLEND_ARMS_TO_BODY)
	return _smin(body, legs, BLEND_LEGS_TO_BODY)


static func gradient(p: Vector3, prims: Dictionary, eps := 0.004) -> Vector3:
	var dx := sdf(p + Vector3(eps, 0, 0), prims) - sdf(p - Vector3(eps, 0, 0), prims)
	var dy := sdf(p + Vector3(0, eps, 0), prims) - sdf(p - Vector3(0, eps, 0), prims)
	var dz := sdf(p + Vector3(0, 0, eps), prims) - sdf(p - Vector3(0, 0, eps), prims)
	return Vector3(dx, dy, dz).normalized()


static func _smin(a: float, b: float, k: float) -> float:
	var h := maxf(k - absf(a - b), 0.0) / k
	return minf(a, b) - h * h * k * 0.25


static func _capsule(p: Vector3, a: Vector3, b: Vector3, r: float) -> float:
	var pa := p - a
	var ba := b - a
	var h := clampf(pa.dot(ba) / ba.dot(ba), 0.0, 1.0)
	return (pa - ba * h).length() - r


static func _round_box(p: Vector3, half: Vector3, r: float) -> float:
	var q := p.abs() - (half - Vector3(r, r, r))
	return q.max(Vector3.ZERO).length() + minf(maxf(q.x, maxf(q.y, q.z)), 0.0) - r


# --- Skin weights -------------------------------------------------------------

## Bone segments (index, head, tail) used for skinning.
static func bone_segments(sk: Skeleton3D) -> Dictionary:
	var seg := func(bone: String, tail: Vector3) -> Array:
		var i := sk.find_bone(bone)
		return [i, sk.get_bone_global_rest(i).origin, tail]
	var at := func(bone: String) -> Vector3: return sk.get_bone_global_rest(sk.find_bone(bone)).origin
	var torso: Array = []
	for n in TORSO_BONES.size():
		var bone: String = TORSO_BONES[n]
		var tail: Vector3 = at.call(TORSO_BONES[n + 1]) if n + 1 < TORSO_BONES.size() else at.call(bone) + Vector3(0, 0.3, 0)
		torso.append(seg.call(bone, tail))
	var groups := {"torso": torso}
	for side: String in ["L", "R"]:
		var a: Array = ARM_BONES[side]
		groups["arm_" + side] = [
			seg.call(a[0], at.call(a[1])),
			seg.call(a[1], at.call(a[2])),
			seg.call(a[2], at.call(a[2]) + (at.call(a[2]) - at.call(a[1])).normalized() * 0.15)]
		var l: Array = LEG_BONES[side]
		groups["leg_" + side] = [
			seg.call(l[0], at.call(l[1])),
			seg.call(l[1], at.call(l[2])),
			seg.call(l[2], at.call(l[2]) + Vector3(0, -0.12, 0))]
	return groups


## Up to four (bone, weight) pairs for a rest-space point. Arms and legs
## fade in over a band so the blob bends smoothly where limbs meet the body.
static func skin(p: Vector3, groups: Dictionary) -> Array:
	var arm_side := "L" if p.x > 0.0 else "R"
	var arm := smoothstep(0.17, 0.27, absf(p.x)) * smoothstep(0.95, 1.12, p.y)
	var leg := 1.0 - smoothstep(0.52, 0.7, p.y)
	leg *= 1.0 - arm
	var torso := maxf(1.0 - arm - leg, 0.0)
	var weights := {}
	_distribute(p, groups.torso, torso, weights)
	_distribute(p, groups["arm_" + arm_side], arm, weights)
	_distribute(p, groups["leg_" + ("L" if p.x > 0.0 else "R")], leg, weights)
	var pairs: Array = []
	for bone: int in weights:
		pairs.append([bone, weights[bone]])
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	pairs = pairs.slice(0, 4)
	var total := 0.0
	for pair in pairs:
		total += pair[1]
	for pair in pairs:
		pair[1] /= maxf(total, 1e-6)
	while pairs.size() < 4:
		pairs.append([0, 0.0])
	return pairs


static func _distribute(p: Vector3, segments: Array, share: float, out: Dictionary) -> void:
	if share <= 0.0001:
		return
	var raw: Array[float] = []
	var sum := 0.0
	for s: Array in segments:
		var d := _segment_distance(p, s[1], s[2])
		var w := 1.0 / pow(d + 0.02, 4.0)
		raw.append(w)
		sum += w
	for n in segments.size():
		var bone: int = segments[n][0]
		out[bone] = out.get(bone, 0.0) + share * raw[n] / sum


static func _segment_distance(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.dot(ab), 1e-9), 0.0, 1.0)
	return p.distance_to(a + ab * t)
