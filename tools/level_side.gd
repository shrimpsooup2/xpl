extends RefCounted
## One side of a symmetric map: the LevelKit with every position it's given
## flipped and a tag added to every name, so a map script lays out one half
## once and builds it for both teams. `flip` (−1, 1, 1) mirrors across x = 0;
## (−1, 1, −1) turns the half 180° about the vertical axis through the middle.
## Blocks stay axis-aligned, so their sizes never change.

const K := GreyBox.Kind

var kit
var flip: Vector3
var tag: String
var team: int


func _init(level_kit, flip_by: Vector3, name_tag: String, for_team: int) -> void:
	kit = level_kit
	flip = flip_by
	tag = name_tag
	team = for_team


func p(v: Vector3) -> Vector3:
	return v * flip


func xz(v: Vector2) -> Vector2:
	return Vector2(v.x * flip.x, v.y * flip.z)


func rect(r: Rect2) -> Rect2:
	return Rect2(xz(r.position), Vector2.ZERO).expand(xz(r.end)).abs()


func span(n: String, from: Vector3, to: Vector3, kind: GreyBox.Kind) -> StaticBody3D:
	return kit.span(n + tag, p(from), p(to), kind)


func ramp(n: String, bottom: Vector3, top: Vector3, width: float, kind := K.RAMP, thickness := 0.7) -> void:
	kit.ramp(n + tag, p(bottom), p(top), width, kind, thickness)


func terrace(n: String, x: Vector2, z: Vector2, top: float, sides := K.RIDE, bottom := 0.0) -> void:
	kit.terrace(n + tag, Vector2(x.x * flip.x, x.y * flip.x), Vector2(z.x * flip.z, z.y * flip.z), top, sides, bottom)


func wall(n: String, a: Vector2, b: Vector2, bottom: float, top: float, openings: Array = [], kind := K.WALL, thickness := 0.4) -> void:
	kit.wall(n + tag, xz(a), xz(b), bottom, top, openings, kind, thickness)


func floor_with_holes(n: String, area: Rect2, top: float, thickness: float, holes: Array, kind := K.FLOOR) -> void:
	var flipped := []
	for h in holes:
		flipped.append(rect(h))
	kit.floor_with_holes(n + tag, rect(area), top, thickness, flipped, kind)


func pad(n: String, weapon: StringName, at: Vector3, respawn := 20.0) -> void:
	kit.pad(n + tag, weapon, p(at), respawn)


func resupply(n: String, at: Vector3) -> void:
	kit.resupply(n + tag, p(at))


func spawn(n: String, at: Vector3, facing: Vector3) -> Transform3D:
	return kit.spawn(n + tag, p(at), p(facing), team)


func light(n: String, at: Vector3, color: Color, reach: float, energy := 2.2) -> void:
	kit.light(n + tag, p(at), color, reach, energy)


func label(text: String, at: Vector3) -> void:
	kit.label(text, p(at))
