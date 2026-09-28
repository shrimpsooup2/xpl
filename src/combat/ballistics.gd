class_name Ballistics
extends Node
## Every shot in the world (GDD §5.4). Projectiles fly at their weapon's
## speed, stepped at the physics tick and swept against the world and every
## body in the &"hittable" group; hitscan shots resolve at once. Either way
## the shot is traced from the shooter's eye, and its tracer starts at the
## gun's muzzle and eases onto the real path over the first few meters.
##
## Hittables implement ray_test(from, to) -> Dictionary (see HitShapes) and
## take_hit(hit) -> Dictionary.

const GROUP := &"hittable"
const WORLD_MASK := 1
## Tracers ease from the muzzle onto the true path over about this far.
const TRACER_BLEND := 4.0
const TRACER_WIDTH := 0.022
## Longest a tracer streak gets (seconds of flight it covers).
const TRACER_TIME := 0.018
const BEAM_TIME := 0.3


class Shot:
	var holder: WeaponHolder
	var def: WeaponDef
	var position: Vector3
	var previous: Vector3
	var velocity: Vector3
	var damage := 0.0
	var can_heartshot := false
	var travelled := 0.0
	var exclude: Array[RID] = []
	var visual_offset := Vector3.ZERO
	var tracer: MeshInstance3D


var _shots: Array[Shot] = []


## The world's Ballistics, created on first use.
static func of(world: Node) -> Ballistics:
	var existing := world.get_node_or_null(^"Ballistics")
	if existing:
		return existing
	var b := Ballistics.new()
	b.name = "Ballistics"
	world.add_child(b)
	return b


## Fires one projectile (one pellet) from `origin` along `direction`.
## `visual_origin` is where the player sees the muzzle.
func fire_projectile(holder: WeaponHolder, def: WeaponDef, origin: Vector3, direction: Vector3,
		visual_origin: Vector3, damage: float, can_heartshot: bool, exclude: Array[RID]) -> void:
	var s := Shot.new()
	s.holder = holder
	s.def = def
	s.position = origin
	s.previous = origin
	s.velocity = direction.normalized() * def.projectile_speed
	s.damage = damage
	s.can_heartshot = can_heartshot
	s.exclude = exclude
	s.visual_offset = visual_origin - origin
	s.tracer = MeshInstance3D.new()
	s.tracer.mesh = CombatFx.unit_box()
	s.tracer.material_override = CombatFx.flash_material(false)
	s.tracer.set_instance_shader_parameter(&"tint", CombatFx.TRACER_COLOR.lerp(def.accent, 0.25))
	s.tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.tracer.visible = false
	add_child(s.tracer)
	_shots.append(s)


## Fires a hitscan shot: resolved now, drawn as a fading beam.
func fire_hitscan(holder: WeaponHolder, def: WeaponDef, origin: Vector3, direction: Vector3,
		visual_origin: Vector3, damage: float, can_heartshot: bool, exclude: Array[RID]) -> Dictionary:
	var to := origin + direction.normalized() * def.max_range
	var hit := trace(origin, to, exclude, holder)
	var end: Vector3 = hit.point if not hit.is_empty() else to
	_beam(visual_origin, end, def.accent)
	if not hit.is_empty():
		return _land(hit, holder, def, damage, can_heartshot, direction.normalized())
	return {}


## The first thing the segment hits: the world or a hittable body. Returns
## {} or {point, normal, target (null for the world), part, zone}.
func trace(from: Vector3, to: Vector3, exclude: Array[RID], holder: WeaponHolder = null) -> Dictionary:
	var best := {}
	var best_distance := from.distance_to(to)
	var space := get_viewport().world_3d.direct_space_state if is_inside_tree() else null
	if space:
		var q := PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK, exclude)
		var w := space.intersect_ray(q)
		if not w.is_empty():
			best_distance = from.distance_to(w.position)
			best = {"point": w.position, "normal": w.normal, "target": null}
	var shooter: Node = holder.player if holder else null
	for target: Node in get_tree().get_nodes_in_group(GROUP):
		if target == shooter or not target.has_method(&"ray_test"):
			continue
		var h: Dictionary = target.ray_test(from, to)
		if not h.is_empty() and h.distance < best_distance:
			best_distance = h.distance
			best = h.duplicate()
			best.target = target
	return best


func _physics_process(delta: float) -> void:
	for s in _shots:
		s.previous = s.position
		s.velocity += Vector3.DOWN * s.def.projectile_gravity * delta
		var step := s.velocity * delta
		var next := s.position + step
		var hit := trace(s.position, next, s.exclude, s.holder)
		if not hit.is_empty():
			s.position = hit.point
			s.travelled += s.previous.distance_to(s.position)
			_land(hit, s.holder, s.def, s.damage, s.can_heartshot, s.velocity.normalized())
			s.def = null  # Spent.
			continue
		s.position = next
		s.travelled += step.length()
		if s.travelled >= s.def.max_range:
			s.def = null
	for s in _shots:
		if s.def == null and is_instance_valid(s.tracer):
			# Leave the streak where it ended for a frame, then go.
			_place_tracer(s, 1.0)
			s.tracer.create_tween().tween_callback(s.tracer.queue_free).set_delay(0.02)
	_shots = _shots.filter(func(s: Shot) -> bool: return s.def != null)


func _process(_delta: float) -> void:
	var f := Engine.get_physics_interpolation_fraction()
	for s in _shots:
		_place_tracer(s, f)


## Stretches the tracer from a little behind the shot's head to the head,
## the whole streak offset toward the muzzle while it's near the gun.
func _place_tracer(s: Shot, f: float) -> void:
	var head := s.previous.lerp(s.position, f)
	var travelled := s.travelled - s.previous.distance_to(s.position) * (1.0 - f)
	var length := minf(travelled, s.velocity.length() * TRACER_TIME)
	if length < 0.05:
		s.tracer.visible = false
		return
	var dir := s.velocity.normalized()
	var tail := head - dir * length
	head += s.visual_offset * _blend(travelled)
	tail += s.visual_offset * _blend(travelled - length)
	var along := head - tail
	var up := Vector3.UP if absf(along.normalized().y) < 0.95 else Vector3.RIGHT
	s.tracer.global_transform = Transform3D(Basis.looking_at(along, up).scaled(Vector3(TRACER_WIDTH, TRACER_WIDTH, along.length())),
			(head + tail) * 0.5)
	s.tracer.visible = true


static func _blend(travelled: float) -> float:
	return 1.0 - smoothstep(0.0, TRACER_BLEND, travelled)


func _land(hit: Dictionary, holder: WeaponHolder, def: WeaponDef, damage: float, can_heartshot: bool, direction: Vector3) -> Dictionary:
	var world := get_parent()
	var target: Node = hit.get("target")
	if target == null:
		CombatFx.impact(world, hit.point, hit.normal, 1.3 if def.delivery == WeaponDef.Delivery.HITSCAN else 1.0)
		return {}
	var zone: StringName = hit.zone
	var heartshot := zone == &"heart" and can_heartshot
	var amount := damage * (def.head_multiplier if zone == &"head" else 1.0)
	var info := {
		"damage": amount,
		"zone": zone,
		"part": hit.part,
		"point": hit.point,
		"normal": hit.normal,
		"direction": direction,
		"heartshot": heartshot,
		"weapon": def,
		"attacker": holder.player if holder else null,
		"knockback": def.knockback,
	}
	var result: Dictionary = target.take_hit(info)
	CombatFx.body_hit(world, hit.point, direction, heartshot)
	if holder and not result.is_empty():
		holder.confirm_hit(result)
	return result


func _beam(from: Vector3, to: Vector3, accent: Color) -> void:
	var beam := MeshInstance3D.new()
	beam.mesh = CombatFx.unit_box()
	beam.material_override = CombatFx.flash_material(false)
	beam.set_instance_shader_parameter(&"tint", Color.WHITE.lerp(accent, 0.35))
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	var along := to - from
	if along.length() < 0.01:
		beam.queue_free()
		return
	var up := Vector3.UP if absf(along.normalized().y) < 0.95 else Vector3.RIGHT
	var basis := Basis.looking_at(along, up)
	beam.global_transform = Transform3D(basis.scaled(Vector3(0.06, 0.06, along.length())), (from + to) * 0.5)
	var t := beam.create_tween()
	t.tween_method(func(w: float) -> void:
		beam.global_transform = Transform3D(basis.scaled(Vector3(w, w, along.length())), (from + to) * 0.5)
		beam.set_instance_shader_parameter(&"tint", Color(Color.WHITE.lerp(accent, 0.35), w / 0.06)),
		0.06, 0.0, BEAM_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(beam.queue_free)
