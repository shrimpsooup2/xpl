class_name BodyShape
extends RefCounted
## The player's body shape, shared by the runtime model and the offline
## generator (tools/gen_body.gd).
##
## Proportions: a blank, blobby, gingerbread-person figure. A big ball head,
## one flat slab of a torso that splits into stubby legs, long tube arms, no
## hands or feet, everything melted together with no visible joints. The
## Universal Animation Library rig is human-proportioned, so
## reshape_skeleton() moves its bones to fit before anything is built or
## animated.
##
## Smoothness rules the shape follows (anything else reads as lumps):
## - No two shapes run side by side where they meet, because a smooth union
##   swells wherever two surfaces nearly coincide. The legs aren't tubes
##   glued under the torso but the bottom of the torso slab, split by a slit.
## - Each arm is one tapered tube, so there is no elbow ring.
## - The body is modelled in an A-pose with the arms halfway down, where they
##   spend most of their time, so skinning never has to bend a shoulder far.
## - Blends are C2 (cubic), so highlights slide over joins without kinks.
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
const LEG_SPREAD := 0.12
## The arms' rest pose points this far below horizontal (the rig's is a
## T-pose). Animations set bone rotations outright, so this only changes the
## pose the mesh is built and bound in.
const ARM_DROP := deg_to_rad(45.0)

# Shape (meters, rig space after reshaping).
const HEAD_RADIUS := 0.165
const HEAD_OFFSET := Vector3(0.0, 0.095, 0.01)
const NECK_RADIUS := 0.115
## The slab: torso on top, legs underneath, one cross-section morphing into
## the other around the crotch.
const SLAB_Z := 0.0
const TORSO_HALF := Vector2(0.215, 0.12)  # Half width (x) and depth (z).
const TORSO_ROUNDING := 0.12  # Equal to the half depth: round sides.
const LEG_HALF := Vector2(0.095, 0.12)
const LEG_ROUNDING := 0.095
const CROTCH_Y := 0.64
const CROTCH_BLEND := 0.11
const SOLE_Y := 0.0
const SOLE_ROUNDING := 0.085
const SHOULDER_Y := 1.40
const SHOULDER_ROUNDING := 0.13
const ARM_RADIUS := 0.118  # At the shoulder.
const ARM_TIP_RADIUS := 0.1
## How far the rounded arm tip reaches past the hand bone.
const ARM_TIP := 0.07
# Smooth-union blend widths: how soft the joins are.
const BLEND_NECK := 0.08
const BLEND_HEAD := 0.07
const BLEND_ARMS_TO_BODY := 0.12

# Skinning.
## Field-distance band over which the shoulder hands over from body to arm.
const ARM_SKIN_BAND := 0.09
## Height band over which the hips hand over to the legs.
const LEG_SKIN_FROM := 0.46
const LEG_SKIN_TO := 0.76
## Half-width of the left/right leg handover across the crotch.
const LEG_SKIN_SPLIT := 0.035

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
		# Swing the arm down around the shoulder joint (rig forward is +Z).
		var arm := sk.find_bone("DEF-upper_arm." + side)
		var parent := sk.get_bone_global_rest(sk.get_bone_parent(arm))
		var global := sk.get_bone_global_rest(arm)
		var drop := Basis(Vector3.BACK, -ARM_DROP if side == "L" else ARM_DROP)
		sk.set_bone_rest(arm, parent.affine_inverse() * Transform3D(drop * global.basis, global.origin))
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
		prims["arm_b_" + side] = hand + (hand - elbow).normalized() * ARM_TIP
	return prims


static func sdf(p: Vector3, prims: Dictionary) -> float:
	return _smin(_core(p, prims), minf(_arm(p, prims, "L"), _arm(p, prims, "R")), BLEND_ARMS_TO_BODY)


## Slab, neck, and head: everything the arms blend into.
static func _core(p: Vector3, prims: Dictionary) -> float:
	var q := Vector2(p.x, p.z - SLAB_Z)
	var torso := _round_rect(q, TORSO_HALF, TORSO_ROUNDING)
	# abs(x): the nearer leg.
	var legs := _round_rect(Vector2(absf(q.x) - LEG_SPREAD, q.y), LEG_HALF, LEG_ROUNDING)
	var section := lerpf(legs, torso, _smootherstep(CROTCH_Y - CROTCH_BLEND, CROTCH_Y + CROTCH_BLEND, p.y))
	var slab := maxf(_rounded_cap(section, SOLE_Y - p.y, SOLE_ROUNDING),
			_rounded_cap(section, p.y - SHOULDER_Y, SHOULDER_ROUNDING))
	var core := _smin(slab, _capsule(p, prims.neck_a, prims.neck_b, NECK_RADIUS), BLEND_NECK)
	return _smin(core, p.distance_to(prims.head) - HEAD_RADIUS, BLEND_HEAD)


static func _arm(p: Vector3, prims: Dictionary, side: String) -> float:
	return _round_cone(p, prims["arm_a_" + side], prims["arm_b_" + side], ARM_RADIUS, ARM_TIP_RADIUS)


static func gradient(p: Vector3, prims: Dictionary, eps := 0.004) -> Vector3:
	var dx := sdf(p + Vector3(eps, 0, 0), prims) - sdf(p - Vector3(eps, 0, 0), prims)
	var dy := sdf(p + Vector3(0, eps, 0), prims) - sdf(p - Vector3(0, eps, 0), prims)
	var dz := sdf(p + Vector3(0, 0, eps), prims) - sdf(p - Vector3(0, 0, eps), prims)
	return Vector3(dx, dy, dz).normalized()


## Cubic smooth minimum: C2, so the blend has no visible highlight seam.
static func _smin(a: float, b: float, k: float) -> float:
	var h := maxf(k - absf(a - b), 0.0) / k
	return minf(a, b) - h * h * h * k / 6.0


static func _smootherstep(from: float, to: float, x: float) -> float:
	var t := clampf((x - from) / (to - from), 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


static func _capsule(p: Vector3, a: Vector3, b: Vector3, r: float) -> float:
	var pa := p - a
	var ba := b - a
	var h := clampf(pa.dot(ba) / ba.dot(ba), 0.0, 1.0)
	return (pa - ba * h).length() - r


## A capsule whose radius tapers from ra at a to rb at b.
static func _round_cone(p: Vector3, a: Vector3, b: Vector3, ra: float, rb: float) -> float:
	var ba := b - a
	var l2 := ba.dot(ba)
	var rr := ra - rb
	var a2 := l2 - rr * rr
	var il2 := 1.0 / l2
	var pa := p - a
	var y := pa.dot(ba)
	var z := y - l2
	var x2 := (pa * l2 - ba * y).length_squared()
	var y2 := y * y * l2
	var z2 := z * z * l2
	var k := signf(rr) * rr * rr * x2
	if signf(z) * a2 * z2 > k:
		return sqrt(x2 + z2) * il2 - rb
	if signf(y) * a2 * y2 < k:
		return sqrt(x2 + y2) * il2 - ra
	return (sqrt(x2 * a2 * il2) + y * rr) * il2 - ra


static func _round_rect(q: Vector2, half: Vector2, r: float) -> float:
	var d := q.abs() - half + Vector2(r, r)
	return d.max(Vector2.ZERO).length() + minf(maxf(d.x, d.y), 0.0) - r


## Closes a vertical extrusion of a 2D section with a rounded edge. h is the
## signed distance past the cap's plane.
static func _rounded_cap(section: float, h: float, r: float) -> float:
	var w := Vector2(section + r, h + r)
	return minf(maxf(w.x, w.y), 0.0) + w.max(Vector2.ZERO).length() - r


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


## Up to four (bone, weight) pairs for a rest-space point. The arm's share
## follows how much closer the point is to the arm than to the body, so it
## fades across the blend at the shoulder; the legs fade in below the crotch
## and split left/right gradually, so the crotch stretches instead of tearing.
static func skin(p: Vector3, groups: Dictionary, prims: Dictionary) -> Array:
	var arm_side := "L" if p.x > 0.0 else "R"
	var core := _core(p, prims)
	var arm := smoothstep(-ARM_SKIN_BAND, ARM_SKIN_BAND, core - _arm(p, prims, arm_side))
	var leg := (1.0 - smoothstep(LEG_SKIN_FROM, LEG_SKIN_TO, p.y)) * (1.0 - arm)
	var left := smoothstep(-LEG_SKIN_SPLIT, LEG_SKIN_SPLIT, p.x)
	var torso := maxf(1.0 - arm - leg, 0.0)
	var weights := {}
	_distribute(p, groups.torso, torso, weights)
	_distribute(p, groups["arm_" + arm_side], arm, weights)
	_distribute(p, groups.leg_L, leg * left, weights)
	_distribute(p, groups.leg_R, leg * (1.0 - left), weights)
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
