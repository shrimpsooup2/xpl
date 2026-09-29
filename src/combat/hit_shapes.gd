class_name HitShapes
extends RefCounted
## Where a shot hits a body (GDD §5.2): capsules and spheres riding the
## skeleton's bones, so what you see is what you hit, and the part tells the
## body how to react. The heart is its own zone and counts from any side.
##
##   part     zone    shapes
##   head     head    sphere on the head
##   neck     body    capsule
##   chest    body    two capsules (the slab's two rounded sides)
##   gut      body    two capsules
##   arm_L/R  body    upper arm and forearm capsules
##   leg_L/R  body    thigh and shin capsules

const HEART_RADIUS := 0.07  # GDD §6.1; the glowing heart is drawn smaller.

## [part, bone, a (bone space), b (bone space), radius]; a == b is a sphere.
var shapes: Array = []
var skeleton: Skeleton3D
var heart: Node3D
## Bone poses as last drawn (capture()), including everything BodyLayers
## did; outside its update the skeleton only reports the animation's pose.
var _poses := {}


static func for_body(sk: Skeleton3D, heart_node: Node3D) -> HitShapes:
	var h := HitShapes.new()
	h.skeleton = sk
	h.heart = heart_node
	var rest := func(bone: String) -> Transform3D: return sk.get_bone_global_rest(sk.find_bone(bone))
	var at := func(bone: String) -> Vector3: return (rest.call(bone) as Transform3D).origin
	var add := func(part: StringName, bone: String, a: Vector3, b: Vector3, r: float) -> void:
		var inv := (rest.call(bone) as Transform3D).affine_inverse()
		h.shapes.append([part, sk.find_bone(bone), inv * a, inv * b, r])
	var head: Vector3 = at.call("DEF-head") + BodyShape.HEAD_OFFSET
	add.call(&"head", "DEF-head", head, head, BodyShape.HEAD_RADIUS)
	add.call(&"neck", "DEF-neck", at.call("DEF-neck"), at.call("DEF-head"), BodyShape.NECK_RADIUS)
	var side := BodyShape.TORSO_HALF.x - BodyShape.TORSO_HALF.y
	var r := BodyShape.TORSO_HALF.y
	for x: float in [-side, side]:
		add.call(&"chest", "DEF-spine.003", Vector3(x, 0.98, 0), Vector3(x, BodyShape.SHOULDER_Y - r * 0.6, 0), r)
		add.call(&"gut", "DEF-spine.001", Vector3(x, BodyShape.CROTCH_Y - 0.02, 0), Vector3(x, 0.98, 0), r)
	for s: String in ["L", "R"]:
		var arm: Array = BodyShape.ARM_BONES[s]
		var hand: Vector3 = at.call(arm[2])
		var tip: Vector3 = hand + (hand - at.call(arm[1])).normalized() * BodyShape.ARM_TIP
		add.call(StringName("arm_" + s), arm[0], at.call(arm[0]), at.call(arm[1]), BodyShape.ARM_RADIUS)
		add.call(StringName("arm_" + s), arm[1], at.call(arm[1]), tip, BodyShape.ARM_TIP_RADIUS)
		var leg: Array = BodyShape.LEG_BONES[s]
		var x: float = at.call(leg[0]).x
		add.call(StringName("leg_" + s), leg[0], Vector3(x, BodyShape.CROTCH_Y, 0), at.call(leg[1]), BodyShape.LEG_HALF.x)
		add.call(StringName("leg_" + s), leg[1], at.call(leg[1]), Vector3(x, BodyShape.SOLE_Y + BodyShape.LEG_HALF.x, 0), BodyShape.LEG_HALF.x)
	return h


## Records the bones' current poses; call right after the body is posed.
func capture() -> void:
	for s: Array in shapes:
		_poses[s[1]] = skeleton.get_bone_global_pose(s[1])


## The first body part the segment from → to passes through, or {} for a
## miss: {part, zone (&"heart", &"head" or &"body"), point, normal, distance}.
func ray_test(from: Vector3, to: Vector3) -> Dictionary:
	var to_world := skeleton.global_transform
	var length := from.distance_to(to)
	if length < 1e-6:
		return {}
	var dir := (to - from) / length
	# Quick reject: the whole body fits in a 1.3 m ball around the chest.
	var middle := to_world * Vector3(0, 0.95, 0)
	if _segment_point_distance(from, to, middle) > 1.3:
		return {}
	var best := INF
	var best_part := &""
	var best_normal := Vector3.UP
	for s: Array in shapes:
		var pose := to_world * (_poses[s[1]] as Transform3D if _poses.has(s[1]) else skeleton.get_bone_global_pose(s[1]))
		var a: Vector3 = pose * (s[2] as Vector3)
		var b: Vector3 = pose * (s[3] as Vector3)
		var radius: float = s[4]
		var t := ray_sphere(from, dir, a, radius) if a.is_equal_approx(b) else ray_capsule(from, dir, a, b, radius)
		if t >= 0.0 and t <= length and t < best:
			best = t
			best_part = s[0]
			var p := from + dir * t
			best_normal = (p - closest_on_segment(p, a, b)).normalized()
	if best == INF:
		return {}
	var zone := &"head" if best_part == &"head" else &"body"
	# The heart's own flag, not the body's: yours is hidden from you in first
	# person, but it's still there to be shot.
	if heart and heart.visible:
		var th := ray_sphere(from, dir, heart.global_position, HEART_RADIUS)
		if th >= 0.0 and th <= length:
			zone = &"heart"
	return {"part": best_part, "zone": zone, "point": from + dir * best, "normal": best_normal, "distance": best}


## Distance along the ray (unit dir) to a sphere, or -1. From inside: 0.
static func ray_sphere(origin: Vector3, dir: Vector3, center: Vector3, r: float) -> float:
	var oc := origin - center
	var b := oc.dot(dir)
	var c := oc.dot(oc) - r * r
	if c <= 0.0:
		return 0.0
	var h := b * b - c
	if h < 0.0:
		return -1.0
	var t := -b - sqrt(h)
	return t if t >= 0.0 else -1.0


## Distance along the ray (unit dir) to a capsule a–b of radius r, or -1.
static func ray_capsule(origin: Vector3, dir: Vector3, a: Vector3, b: Vector3, r: float) -> float:
	if origin.distance_to(closest_on_segment(origin, a, b)) <= r:
		return 0.0
	var ba := b - a
	var oa := origin - a
	var baba := ba.dot(ba)
	var bard := ba.dot(dir)
	var baoa := ba.dot(oa)
	var rdoa := dir.dot(oa)
	var oaoa := oa.dot(oa)
	var qa := baba - bard * bard
	if qa > 1e-9:
		var qb := baba * rdoa - baoa * bard
		var qc := baba * oaoa - baoa * baoa - r * r * baba
		var h := qb * qb - qa * qc
		if h >= 0.0:
			var t := (-qb - sqrt(h)) / qa
			var y := baoa + t * bard
			if y > 0.0 and y < baba:
				return t if t >= 0.0 else -1.0
	# The end caps.
	var best := -1.0
	for cap: Vector3 in [a, b]:
		var t := ray_sphere(origin, dir, cap, r)
		if t >= 0.0 and (best < 0.0 or t < best):
			best = t
	return best


static func closest_on_segment(p: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.dot(ab), 1e-9), 0.0, 1.0)
	return a + ab * t


static func _segment_point_distance(a: Vector3, b: Vector3, p: Vector3) -> float:
	return p.distance_to(closest_on_segment(p, a, b))
