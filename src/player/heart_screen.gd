class_name HeartScreen
extends Node3D
## The heart (GDD §6.4), set in a round socket in the chest
## (BodyShape.SOCKET_RADIUS). Two looks are on trial (ViewSettings.heart_style
## picks one for every heart you see):
##
##   CRT: a tiny TV set into the socket, its screen glowing heart pink with a
##     pixel heart beating on it. The beat speeds up with speed and races
##     near death; a hit tears the picture and it snows; near death the
##     picture rolls. An ordinary death loses the signal to static; a
##     heartshot switches the set off (the picture collapses to a white-hot
##     line, then a dot, then black) and cracks the glass.
##   SPINNER: a loading spinner made of real beads: DOTS glowing pink beads
##     floating in the socket (lined dark), going round, the lead one biggest
##     and brightest, faster at speed. Each hangs on its own spring, so they
##     lag when you move and rattle when you're hit; a hit also makes the
##     spin hitch, like lag, and near death it stutters. An ordinary death
##     slows them and they settle, grey, in the bottom of the socket ("timed
##     out"); a heartshot flashes them white and spills them out of the chest,
##     to bounce on the floor and go dark ("not responding").
##
## Its origin is the heart's hit centre (HitShapes), and what glows (the
## TV's glass, the beads' ring) fits inside that sphere, so what glows is
## what counts.

enum Style { CRT, SPINNER }

## The CRT's set (a rounded box) and its glass.
const SIZE := Vector3(0.12, 0.096, 0.05)
const GLASS := Vector2(0.094, 0.0735)
const CASING_COLOR := Color(0.1, 0.1, 0.12)
## The set sits this far out from the hit centre, proud of the chest.
const STAND_OUT := 0.012
const CRT_SHADER := preload("res://src/render/heart_screen.gdshader")
## CRT: beats per minute at rest, flat out, and near death.
const BPM_REST := 72.0
const BPM_FAST := 140.0
const BPM_DYING := 190.0
## The spinner: DOTS beads, the lead DOT_RADIUS and the last TAIL_SIZE of
## that, round a ring RING_RADIUS across, RING_DEPTH in (the chest's front is
## about 5 mm out from the hit centre).
const DOTS := 6
const DOT_RADIUS := 0.011
const TAIL_SIZE := 0.55
const RING_RADIUS := 0.026
const RING_DEPTH := -0.012
## The socket's dark lining, just inside its wall, up to the chest's front.
const LINING_RADIUS := 0.046
const PINK := Color(1.0, 0.22, 0.42)
## The lining: glowing pink at the rim, fading to near black at the back,
## so it reads as a hollow up close and as a pink spot from across a map. `glow` dims it (death),
## `grey` drains it (a hit, timed out).
const LINING_SHADER := """
shader_type spatial;
render_mode cull_back;
uniform vec3 pink : source_color = vec3(1.0, 0.22, 0.42);
uniform float glow = 1.0;
uniform float grey = 0.0;
varying float depth;
void vertex() {
	depth = clamp(-VERTEX.z / %f, 0.0, 1.0);
}
void fragment() {
	vec3 col = pink * mix(0.9, 0.02, pow(depth, 0.6));
	col = mix(col, vec3(dot(col, vec3(0.33))), grey);
	ALBEDO = col * 0.08;
	EMISSION = col * glow * 1.2;
	ROUGHNESS = 0.6;
	SPECULAR = 0.2;
}
""" % LINING_RADIUS
## Each bead's spring (stiffness varies a little bead to bead, so they move
## on their own), and how far one may stray from its place (the socket's
## wall). A hit kicks each this hard (m/s).
const DOT_STIFFNESS := 700.0
const DOT_DAMPING := 14.0
const DOT_SLACK := 0.009
const DOT_KICK := 0.9
## A heartshot throws the beads out this fast (m/s); they lie on the floor
## this long.
const SPILL_SPEED := 2.2
const SPILLED_FOR := 8.0
## Spinner: turns per second at rest and flat out; how long a hit hitches it.
const SPIN_REST := 0.9
const SPIN_FAST := 2.4
const HITCH_TIME := 0.25
## Speed (m/s) that counts as flat out, and health below which it races.
const FAST_SPEED := 14.0
const DYING_BELOW := 0.35
const HURT_TIME := 0.35
const SWITCH_OFF_TIME := 0.45
const SIGNAL_LOSS_TIME := 0.6

## The look every heart has (the local player's ViewSettings sets it).
static var style := Style.CRT

## Its owner's health (0..1) and speed (m/s), kept up to date by the
## PlayerModel (set_health, animate_movement).
var health := 1.0
var speed := 0.0
## Where spilled beads go (the level, not the body): set by the PlayerModel.
var drop_into: Callable
## The CRT's set, glass and the glass's material.
var casing: MeshInstance3D
var screen: MeshInstance3D
var material: ShaderMaterial
## The spinner's socket lining (and its material) and beads (in the socket;
## the spilled ones are gone from here), and each bead's material.
var lining: MeshInstance3D
var lining_material: ShaderMaterial
var dots: Array[MeshInstance3D] = []
var dot_materials: Array[StandardMaterial3D] = []
## The look it's built in (it rebuilds when `style` changes).
var built := Style.CRT

var _phase := 0.0
var _angle := 0.0
var _hold := 0.0
var _hurt := 0.0
## -1 while on; then 0..1 switching off (a heartshot), or losing the signal.
var _off := -1.0
var _lost := -1.0
var _seed := 0.0
var _time := 0.0
var _dot_pos: Array[Vector3] = []
var _dot_vel: Array[Vector3] = []
var _dot_springs: Array[float] = []
var _placed := false
var _left_socket := false
var _last_origin := Vector3.ZERO
var _spilled: Array[RigidBody3D] = []

## Shared by every heart; the glass's and beads' materials are each heart's own.
static var _casing_mesh: ArrayMesh
static var _lining_mesh: ArrayMesh
static var _bead_mesh: SphereMesh
static var _bead_shape: SphereShape3D
static var _bounce: PhysicsMaterial
static var _plastic: StandardMaterial3D
static var _lining_shader: Shader


func _ready() -> void:
	_build(style)
	revive()


## Builds the heart in `look`, replacing what was there.
func _build(look: Style) -> void:
	built = look
	for child in [casing, screen, lining] + dots:
		if child:
			child.queue_free()
	casing = null
	screen = null
	material = null
	lining = null
	dots.clear()
	dot_materials.clear()
	if look == Style.SPINNER:
		_build_spinner()
		return
	casing = MeshInstance3D.new()
	casing.name = "Casing"
	casing.mesh = casing_mesh()
	if _plastic == null:
		_plastic = StandardMaterial3D.new()
		_plastic.albedo_color = CASING_COLOR
		_plastic.roughness = 0.15
		_plastic.metallic_specular = 0.8
		_plastic.rim_enabled = true
		_plastic.rim = 0.2
	casing.material_override = _plastic
	casing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	casing.position.z = STAND_OUT
	add_child(casing)

	material = ShaderMaterial.new()
	material.shader = CRT_SHADER
	material.set_shader_parameter(&"aspect", GLASS.x / GLASS.y)
	material.set_shader_parameter(&"seed", _seed)
	material.set_shader_parameter(&"crack", 1.0 if _off >= 0.0 else 0.0)
	var quad := QuadMesh.new()
	quad.size = GLASS
	screen = MeshInstance3D.new()
	screen.name = "Screen"
	screen.mesh = quad
	screen.material_override = material
	screen.position.z = STAND_OUT + SIZE.z * 0.5 + 0.0015  # Just proud of the face.
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(screen)


func _build_spinner() -> void:
	if _lining_mesh == null:
		_lining_mesh = _bowl(LINING_RADIUS)
		_lining_shader = Shader.new()
		_lining_shader.code = LINING_SHADER
		_bead_mesh = SphereMesh.new()
		_bead_mesh.radius = DOT_RADIUS
		_bead_mesh.height = DOT_RADIUS * 2.0
		_bead_mesh.radial_segments = 12
		_bead_mesh.rings = 6
		_bead_shape = SphereShape3D.new()
		_bead_shape.radius = DOT_RADIUS
		_bounce = PhysicsMaterial.new()
		_bounce.bounce = 0.55
		_bounce.friction = 0.6
	lining = MeshInstance3D.new()
	lining.name = "Lining"
	lining.mesh = _lining_mesh
	lining_material = ShaderMaterial.new()
	lining_material.shader = _lining_shader
	lining.material_override = lining_material
	lining.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lining.visible = not _left_socket
	add_child(lining)
	if _off >= 0.0:
		return  # Spilled: nothing left in the socket.
	_dot_pos.resize(DOTS)
	_dot_vel.resize(DOTS)
	_dot_springs.resize(DOTS)
	for i in DOTS:
		var m := StandardMaterial3D.new()
		m.albedo_color = PINK
		m.roughness = 0.1
		m.metallic_specular = 1.0
		m.rim_enabled = true
		m.rim = 0.4
		m.emission_enabled = true
		m.emission = PINK
		var dot := MeshInstance3D.new()
		dot.name = "Bead%d" % i
		dot.mesh = _bead_mesh
		dot.material_override = m
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dot.top_level = true  # Moved by its own spring.
		add_child(dot)
		dots.append(dot)
		dot_materials.append(m)
		_dot_springs[i] = DOT_STIFFNESS * randf_range(0.75, 1.25)
		_dot_vel[i] = Vector3.ZERO
	_placed = false


func _process(delta: float) -> void:
	if built != style:
		_build(style)
	_time += delta
	var fast := clampf(speed / FAST_SPEED, 0.0, 1.0)
	var dying := clampf(1.0 - health / DYING_BELOW, 0.0, 1.0)
	var alive := _off < 0.0 and _lost < 0.0
	# The CRT's beat.
	var bpm := lerpf(lerpf(BPM_REST, BPM_FAST, fast), BPM_DYING, dying)
	if alive:
		_phase = fmod(_phase + delta * bpm / 60.0, 1.0)
	# The spinner's turn: it hitches when hit, stutters near death, and winds
	# down when the signal's lost.
	_hold = maxf(_hold - delta, 0.0)
	if alive and _hold <= 0.0 and dying > 0.0 and randf() < dying * delta * 4.0:
		_hold = randf_range(0.08, 0.3)
	var turns := lerpf(SPIN_REST, SPIN_FAST, fast)
	if _lost >= 0.0:
		turns *= 1.0 - _lost
	if (alive or _lost >= 0.0) and _hold <= 0.0:
		_angle = fmod(_angle + delta * turns * TAU, TAU)
	_hurt = maxf(_hurt - delta / HURT_TIME, 0.0)
	if _off >= 0.0:
		_off = minf(_off + delta / SWITCH_OFF_TIME, 1.0)
	if _lost >= 0.0:
		_lost = minf(_lost + delta / SIGNAL_LOSS_TIME, 1.0)
	if built == Style.SPINNER:
		_move_beads(delta, dying)
		_light_beads(dying)
		return
	material.set_shader_parameter(&"beat_phase", _phase if alive else 0.5)
	material.set_shader_parameter(&"health", health)
	material.set_shader_parameter(&"hurt", _hurt)
	material.set_shader_parameter(&"off", maxf(_off, 0.0))
	material.set_shader_parameter(&"lost", maxf(_lost, 0.0))


## A hit: the picture tears and snows (the CRT), or the spin hitches and the
## beads rattle in the socket (the spinner).
func hurt() -> void:
	_hurt = 1.0
	_hold = maxf(_hold, HITCH_TIME)
	for i in dots.size():
		var kick := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		_dot_vel[i] += kick * DOT_KICK * randf_range(0.6, 1.0)


## Its owner died: through the heart it switches off (the CRT's glass
## cracks; the spinner's beads spill out of the chest); otherwise the
## signal's lost.
func stop(heartshot: bool) -> void:
	if _off >= 0.0 or _lost >= 0.0:
		return
	if heartshot:
		_off = 0.0
		if material:
			material.set_shader_parameter(&"crack", 1.0)
		_spill()
	else:
		_lost = 0.0


## The body's falling apart and the heart's leaving the chest: the socket's
## lining is the body's, so it stays (out of sight in the heap).
func leave_socket() -> void:
	_left_socket = true
	if lining:
		lining.visible = false


## Back on, the glass whole, the beads back in the socket.
func revive() -> void:
	var was_off := _off >= 0.0
	_off = -1.0
	_lost = -1.0
	_hurt = 0.0
	_hold = 0.0
	health = 1.0
	_phase = randf()
	_angle = randf() * TAU
	_seed = randf()
	if material:
		material.set_shader_parameter(&"crack", 0.0)
		material.set_shader_parameter(&"seed", _seed)
	for body in _spilled:
		if is_instance_valid(body):
			body.queue_free()
	_spilled.clear()
	_left_socket = false
	if built == Style.SPINNER:
		if was_off:
			_build(Style.SPINNER)  # New beads: the old ones are on the floor.
		if lining:
			lining.visible = true
		_placed = false


## &"on", &"off" (switched off by a heartshot) or &"lost" (the signal lost).
func ending() -> StringName:
	if _off >= 0.0:
		return &"off"
	return &"lost" if _lost >= 0.0 else &"on"


## Where the CRT is in the current beat (0..1).
func beat() -> float:
	return _phase


## Where the spinner's lead bead is (radians round the ring).
func spin() -> float:
	return _angle


## The beads that spilled out on a heartshot (their bodies, while they last).
func spilled() -> Array[RigidBody3D]:
	return _spilled.filter(func(b: RigidBody3D) -> bool: return is_instance_valid(b))


# --- The spinner's beads ----------------------------------------------------------

## Where bead `i` belongs in the socket (heart space): round the ring
## clockwise as you face it, the lead first, each bobbing a little. Near
## death the ring sags; timed out, the beads settle in the bottom.
func _bead_place(i: int, dying: float) -> Vector3:
	var a := -_angle + i * TAU / DOTS
	var place := Vector3(cos(a) * RING_RADIUS, sin(a) * RING_RADIUS - dying * 0.006,
			RING_DEPTH + sin(_time * 2.3 + i * 1.7) * 0.002)
	if _lost > 0.0:
		place = place.lerp(_settled(i), smoothstep(0.0, 1.0, _lost))
	return place


## Where bead `i` comes to rest when it's timed out: in a little heap in the
## bottom of the socket, two rows of three going back into it.
func _settled(i: int) -> Vector3:
	var x := ((i % 3) - 1) * 0.013
	var back := 0.35 if i < 3 else 0.85
	var r := sqrt(pow(LINING_RADIUS - DOT_RADIUS * _bead_size(i), 2.0) - x * x)
	return Vector3(x, -r * cos(back), -r * sin(back))


func _bead_size(i: int) -> float:
	return lerpf(1.0, TAIL_SIZE, float(i) / (DOTS - 1))


# Each bead chases its place on its own spring: it lags when the body moves
# and rattles when kicked, but never strays past the socket's wall.
func _move_beads(delta: float, dying: float) -> void:
	if dots.is_empty():
		return
	var to_world := global_transform
	var jumped := to_world.origin.distance_to(_last_origin) > 0.5
	_last_origin = to_world.origin
	var steps := clampi(ceili(delta * 120.0), 1, 4)
	var h := delta / steps
	for i in dots.size():
		var target := to_world * _bead_place(i, dying)
		if not _placed or jumped:
			_dot_pos[i] = target
			_dot_vel[i] = Vector3.ZERO
		var pos := _dot_pos[i]
		var vel := _dot_vel[i]
		for step in steps:
			vel += ((target - pos) * _dot_springs[i] - vel * DOT_DAMPING) * h
			pos += vel * h
		var off := pos - target
		if off.length() > DOT_SLACK:
			pos = target + off.limit_length(DOT_SLACK)
			vel *= 0.5  # Knocked against the wall.
		_dot_pos[i] = pos
		_dot_vel[i] = vel
		dots[i].global_transform = Transform3D(to_world.basis.orthonormalized().scaled(Vector3.ONE * _bead_size(i)), pos)
	_placed = true


# The lead bead white-hot, the tail fading back to pink; grey flicker when
# hit, flicker near death, grey and dark when timed out; a heartshot flashes
# them white, then they go dark on the floor.
func _light_beads(dying: float) -> void:
	var flicker := 1.0 - dying * dying * 0.5 * (1.0 if fmod(_time * 14.0, 1.0) < 0.5 and randf() < 0.5 else 0.0)
	if lining_material:
		var dim := 1.0 - maxf(maxf(_lost, 0.0) * 0.8, smoothstep(0.1, 1.0, maxf(_off, 0.0)))
		lining_material.set_shader_parameter(&"glow", dim * flicker)
		lining_material.set_shader_parameter(&"grey", maxf(maxf(_lost, 0.0), _hurt * 0.6))
	for i in dot_materials.size():
		var m := dot_materials[i]
		var lead := 1.0 - float(i) / (DOTS - 1)
		var col := PINK.lerp(Color(1.0, 0.9, 0.94), lead * lead * 0.85)
		var energy := lerpf(0.5, 1.4, lead) * flicker
		var grey := col.get_luminance()
		col = col.lerp(Color(grey, grey, grey), _hurt * 0.7)
		if _lost >= 0.0:
			col = col.lerp(Color(0.5, 0.5, 0.52), _lost)
			energy *= 1.0 - 0.9 * _lost
		if _off >= 0.0:
			var flash := 1.0 - smoothstep(0.0, 0.25, _off)
			col = col.lerp(Color.WHITE, flash)
			energy = lerpf(energy, 5.0, flash) * (1.0 - smoothstep(0.25, 1.0, _off))
		m.emission = col
		m.emission_energy_multiplier = energy
		m.albedo_color = col.lerp(Color(0.3, 0.3, 0.32), maxf(_lost, _off))


# A heartshot: every bead flies out of the chest, to bounce about the floor
# and go dark. They're the level's now, not the body's, and go after a while.
func _spill() -> void:
	if dots.is_empty():
		return
	var parent: Node = drop_into.call() if drop_into.is_valid() else null
	if parent == null or not parent.is_inside_tree():
		parent = get_tree().current_scene if get_tree().current_scene else get_tree().root
	var out := global_basis.z.normalized()
	for i in dots.size():
		var dot := dots[i]
		var body := RigidBody3D.new()
		body.name = "SpilledBead"
		body.collision_layer = 0
		body.collision_mask = 1  # The world.
		body.mass = 0.02
		body.physics_material_override = _bounce
		var col := CollisionShape3D.new()
		col.shape = _bead_shape
		body.add_child(col)
		parent.add_child(body)
		body.global_position = _dot_pos[i]
		dot.reparent(body, false)
		dot.top_level = false
		dot.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * _bead_size(i)), Vector3.ZERO)
		var side := (_dot_pos[i] - global_position)
		side -= out * side.dot(out)
		var fling := out * 1.2 + side.normalized() * 1.1 + Vector3.UP * 0.9
		body.linear_velocity = fling * SPILL_SPEED * randf_range(0.6, 1.1) * 0.6
		body.angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 12.0
		body.create_tween().tween_callback(body.queue_free).set_delay(SPILLED_FOR)
		_spilled.append(body)
	dots.clear()


# --- Meshes -----------------------------------------------------------------------

## The TV's set, shared by every one: a rounded box (a superellipsoid).
static func casing_mesh() -> ArrayMesh:
	if _casing_mesh == null:
		_casing_mesh = _superellipsoid(SIZE * 0.5, 0.28, 0.28)
	return _casing_mesh


## A superellipsoid with half-extents `half`: `pole` squares off its profile
## top to bottom, `round` the cross-section round it (1: round; toward 0:
## square).
static func _superellipsoid(half: Vector3, pole: float, round: float) -> ArrayMesh:
	const RINGS := 12
	const SEGMENTS := 24
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var point := func(eta: float, omega: float) -> Vector3:
		var ce := _signed_pow(cos(eta), pole)
		var across := Vector2(ce * _signed_pow(cos(omega), round), ce * _signed_pow(sin(omega), round))
		return Vector3(half.x * across.x, half.y * _signed_pow(sin(eta), pole), half.z * across.y)
	for r in RINGS:
		var e0 := -PI * 0.5 + PI * r / RINGS
		var e1 := -PI * 0.5 + PI * (r + 1) / RINGS
		for s in SEGMENTS:
			var o0 := TAU * s / SEGMENTS
			var o1 := TAU * (s + 1) / SEGMENTS
			var a: Vector3 = point.call(e0, o0)
			var b: Vector3 = point.call(e0, o1)
			var c: Vector3 = point.call(e1, o1)
			var d: Vector3 = point.call(e1, o0)
			for v: Vector3 in [a, c, b, a, d, c]:
				st.add_vertex(v)
	st.index()
	st.generate_normals()
	return st.commit()


## The socket's lining: the back half of a ball of `radius` (behind the
## chest's front), seen from inside: its faces and normals face in.
static func _bowl(radius: float) -> ArrayMesh:
	const RINGS := 8
	const SEGMENTS := 24
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var point := func(theta: float, phi: float) -> Vector3:
		return Vector3(sin(theta) * cos(phi), sin(theta) * sin(phi), -cos(theta)) * radius
	for r in RINGS:
		var t0 := PI * 0.5 * r / RINGS
		var t1 := PI * 0.5 * (r + 1) / RINGS
		for s in SEGMENTS:
			var p0 := TAU * s / SEGMENTS
			var p1 := TAU * (s + 1) / SEGMENTS
			var corners: Array[Vector3] = [point.call(t0, p0), point.call(t0, p1), point.call(t1, p1), point.call(t1, p0)]
			for tri: Array in [[0, 1, 2], [0, 2, 3]]:
				var a := corners[tri[0]]
				var b := corners[tri[1]]
				var c := corners[tri[2]]
				if a.is_equal_approx(b) or b.is_equal_approx(c) or a.is_equal_approx(c):
					continue  # The back pole's slivers.
				# Wound to face into the ball, so it's the inside you see.
				if Plane(a, b, c).normal.dot(a + b + c) > 0.0:
					var swap := b
					b = c
					c = swap
				for v: Vector3 in [a, b, c]:
					st.set_normal(-v.normalized())
					st.add_vertex(v)
	st.index()
	return st.commit()


static func _signed_pow(x: float, e: float) -> float:
	return signf(x) * pow(absf(x), e)
