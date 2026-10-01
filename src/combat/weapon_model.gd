class_name WeaponModel
extends Node3D
## A gun built from its WeaponDef's parts, with its moving parts animated:
## the slide or bolt carrier snaps back, the revolver's hammer falls and
## its cylinder turns, the pump racks, the bolt is worked. The same model is
## used in first person (viewmodel = true: drawn over the world with its own
## field of view), in the hands of other players, and lying on pickups.

## Per colour key: gloss, rim, glow, roughness.
const FINISH := {
	&"metal": [0.9, 0.0, 0.0, 0.12],
	&"dark": [0.35, 0.0, 0.0, 0.3],
	&"beige": [0.25, 0.0, 0.0, 0.4],
	&"grip": [0.2, 0.0, 0.0, 0.5],
	&"accent": [0.6, 0.25, 0.08, 0.18],
	&"glass": [0.8, 0.0, 0.7, 0.05],
}
## Slide/bolt carrier travel (meters), pump stroke, bolt handle lift.
const SLIDE_TRAVEL := 0.045
const CARRIER_TRAVEL := 0.035
const PUMP_STROKE := 0.1
const BOLT_TRAVEL := 0.09
const BOLT_LIFT := deg_to_rad(75.0)
const HAMMER_COCKED := deg_to_rad(-38.0)
const TRIGGER_PULL := deg_to_rad(-25.0)

static var _materials := {}
static var _meshes := {}

var def: WeaponDef
var viewmodel := false
var muzzle: Node3D
var fore: Node3D
var eject: Node3D
## Where the right hand is (weapon space): the grip, except while it works
## the bolt.
var right_hand := Vector3.ZERO

var _parts := {}  # tag -> Node3D
var _rest := {}  # tag -> Transform3D
var _cycle := INF  # Seconds since the last shot.
var _trigger := 1.0
var _cylinder_turns := 0
var _fanning := false


func _init(weapon: WeaponDef, for_viewmodel := false) -> void:
	def = weapon
	viewmodel = for_viewmodel
	name = String(weapon.id).capitalize().replace(" ", "")
	for p: Array in weapon.parts:
		_add_part(p)
	muzzle = _marker("Muzzle", weapon.muzzle)
	eject = _marker("Eject", weapon.eject)
	# The left hand rides the pump on a pump-action.
	fore = _marker("Fore", weapon.fore, _parts.get(&"pump", self))
	if _parts.has(&"pump"):
		fore.position = weapon.fore - (_rest[&"pump"] as Transform3D).origin
	_pose()


## A shot: the trigger breaks, the hammer drops, and the action starts
## cycling. `fanned` keeps the hammer from re-cocking by itself (the left
## hand fans it).
func fire(fanned := false) -> void:
	_cycle = 0.0
	_trigger = 0.0
	_fanning = fanned
	_cylinder_turns += 1 if def.action == WeaponDef.Action.REVOLVER else 0


## 0..1 through the current cycle (1 once it's done).
func cycle_progress() -> float:
	var t := (_cycle - def.cycle_delay) / maxf(def.cycle_time, 0.001)
	return clampf(t, 0.0, 1.0) if _cycle < INF else 1.0


func is_cycling() -> bool:
	return _cycle < def.cycle_delay + def.cycle_time


## The moment in the cycle a casing flies out (seconds after the shot).
func eject_time() -> float:
	match def.action:
		WeaponDef.Action.PUMP:
			return def.cycle_delay + def.cycle_time * 0.4
		WeaponDef.Action.BOLT:
			return def.cycle_delay + def.cycle_time * 0.45
	return 0.02


func part(tag: StringName) -> Node3D:
	return _parts.get(tag)


func _process(delta: float) -> void:
	if _cycle < INF:
		_cycle += delta
	_trigger = minf(_trigger + delta / 0.08, 1.0)
	_pose()


func _pose() -> void:
	var c := cycle_progress()
	var back := _snap(c)
	right_hand = Vector3.ZERO
	match def.action:
		WeaponDef.Action.SLIDE:
			_move(&"slide", Vector3(0, 0, SLIDE_TRAVEL * back))
		WeaponDef.Action.BOLT_CARRIER:
			_move(&"bolt", Vector3(0, 0, CARRIER_TRAVEL * back))
		WeaponDef.Action.PUMP:
			_move(&"pump", Vector3(0, 0, PUMP_STROKE * _stroke(c)))
		WeaponDef.Action.REVOLVER:
			# The hammer falls on the shot and comes back as the cylinder turns.
			var cocked := smoothstep(0.0, 1.0, c) if not _fanning or c >= 1.0 else 0.0
			if _cycle == INF:
				cocked = 1.0
			_turn(&"hammer", Basis(Vector3.RIGHT, HAMMER_COCKED * cocked))
			var turn := (_cylinder_turns - 1 + _ease(c)) * TAU / 6.0 if _cylinder_turns > 0 else 0.0
			_turn(&"cylinder", Basis(Vector3.BACK, turn))
		WeaponDef.Action.BOLT:
			# Lift, back, forward, down, with the right hand on the knob.
			var lift := smoothstep(0.0, 0.2, c) * (1.0 - smoothstep(0.8, 1.0, c))
			var pull := smoothstep(0.2, 0.45, c) * (1.0 - smoothstep(0.55, 0.8, c))
			var bolt: Node3D = _parts.get(&"bolt")
			if bolt:
				var rest: Transform3D = _rest[&"bolt"]
				var pivot := Vector3(0, rest.origin.y, rest.origin.z)
				var turn := Basis(Vector3.BACK, BOLT_LIFT * lift)
				bolt.transform = Transform3D(turn * rest.basis, pivot + turn * (rest.origin - pivot) + Vector3(0, 0, BOLT_TRAVEL * pull))
				var on_bolt := smoothstep(0.0, 0.12, c) * (1.0 - smoothstep(0.85, 1.0, c))
				var knob := bolt.transform * Vector3(0.04, 0, 0)
				right_hand = Vector3.ZERO.lerp(knob + Vector3(0.02, -0.02, 0.02), on_bolt)
	var pull_trigger := 1.0 - _trigger
	_turn(&"trigger", Basis(Vector3.RIGHT, TRIGGER_PULL * pull_trigger))


func _move(tag: StringName, offset: Vector3) -> void:
	var node: Node3D = _parts.get(tag)
	if node:
		var rest: Transform3D = _rest[tag]
		node.transform = Transform3D(rest.basis, rest.origin + offset)


func _turn(tag: StringName, turn: Basis) -> void:
	var node: Node3D = _parts.get(tag)
	if node:
		var rest: Transform3D = _rest[tag]
		node.transform = Transform3D(turn * rest.basis, rest.origin)


## A slide's travel: slams back in the first third, rides home after.
static func _snap(c: float) -> float:
	if c >= 1.0:
		return 0.0
	return ease(c / 0.3, 0.4) if c < 0.3 else 1.0 - ease((c - 0.3) / 0.7, 2.0)


## A pump stroke: back and forward, even.
static func _stroke(c: float) -> float:
	if c >= 1.0:
		return 0.0
	return smoothstep(0.0, 0.45, c) * (1.0 - smoothstep(0.55, 1.0, c))


static func _ease(c: float) -> float:
	return smoothstep(0.0, 1.0, c)


# --- Building -----------------------------------------------------------------

func _add_part(p: Array) -> void:
	var kind: String = p[0]
	var tag: StringName = p[1]
	var size: Vector3 = p[2]
	var at: Vector3 = p[3]
	var rot: Vector3 = p[4]
	var key: StringName = p[5]
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(kind, size)
	mi.material_override = Gloss.material(Weapons.color(def, key), FINISH.get(key, FINISH[&"dark"]), viewmodel)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if viewmodel else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var basis := Basis.from_euler(rot * (PI / 180.0))
	if kind == "cyl":
		basis = basis * Basis(Vector3.RIGHT, PI * 0.5)  # Cylinders lie along Z.
	if tag.is_empty():
		mi.transform = Transform3D(basis, at)
		add_child(mi)
	else:
		var pivot := Node3D.new()
		pivot.name = String(tag).capitalize()
		pivot.transform = Transform3D(Basis.from_euler(rot * (PI / 180.0)), at)
		mi.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5) if kind == "cyl" else Basis.IDENTITY, Vector3.ZERO)
		pivot.add_child(mi)
		add_child(pivot)
		_parts[tag] = pivot
		_rest[tag] = pivot.transform


func _marker(marker_name: String, at: Vector3, parent: Node3D = self) -> Node3D:
	var m := Node3D.new()
	m.name = marker_name
	m.position = at
	parent.add_child(m)
	return m


## Sets `fade` (0..1) on every part: a screen-door dissolve.
func set_fade(amount: float) -> void:
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		Gloss.fade(mi, amount)


static func material(for_viewmodel: bool) -> ShaderMaterial:
	if not _materials.has(for_viewmodel):
		var m := ShaderMaterial.new()
		m.shader = preload("res://src/render/gloss.gdshader")
		m.set_shader_parameter(&"reflection_map", preload("res://assets/textures/reflection_map.png"))
		m.set_shader_parameter(&"viewmodel", for_viewmodel)
		_materials[for_viewmodel] = m
	return _materials[for_viewmodel]


static func _mesh(kind: String, size: Vector3) -> Mesh:
	var key := "%s%s" % [kind, size]
	if not _meshes.has(key):
		if kind == "cyl":
			var c := CylinderMesh.new()
			c.top_radius = size.x
			c.bottom_radius = size.x
			c.height = size.z
			c.radial_segments = 10
			c.rings = 1
			_meshes[key] = c
		else:
			var b := BoxMesh.new()
			b.size = size
			_meshes[key] = b
	return _meshes[key]
