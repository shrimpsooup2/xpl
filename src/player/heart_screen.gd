class_name HeartScreen
extends Node3D
## The heart (GDD §6.4): a little glowing device set into the chest. Two looks
## are on trial (ViewSettings.heart_style picks one for every heart you see):
##
##   CRT: a tiny TV, its screen glowing heart pink with a pixel heart beating
##     on it. The beat speeds up with speed and races near death; a hit tears
##     the picture and it snows; near death the picture rolls. An ordinary
##     death loses the signal to static; a heartshot switches the set off
##     (the picture collapses to a white-hot line, then a dot, then black)
##     and cracks the glass.
##   SPINNER: a loading spinner, eight light dots stepping round a round
##     glass glowing pink, faster at speed. A hit makes it hitch (it freezes, like lag); near
##     death it stutters. An ordinary death greys it out as it winds down
##     ("timed out"); a heartshot flashes, drops the dots out of the ring and
##     leaves a dim cross ("not responding").
##
## Its origin is the heart's hit centre (HitShapes), and the glass of either
## look fits inside that sphere, so what glows is what counts.

enum Style { CRT, SPINNER }

## The CRT's set (a rounded box) and its glass.
const SIZE := Vector3(0.12, 0.096, 0.05)
const GLASS := Vector2(0.094, 0.0735)
## The spinner's set (a round puck) and its glass.
const PUCK := Vector3(0.11, 0.11, 0.045)
const DIAL := 0.086
const CASING_COLOR := Color(0.1, 0.1, 0.12)
## The set sits this far out from the hit centre, proud of the chest.
const STAND_OUT := 0.012
const CRT_SHADER := preload("res://src/render/heart_screen.gdshader")
const SPINNER_SHADER := preload("res://src/render/heart_spinner.gdshader")
## CRT: beats per minute at rest, flat out, and near death.
const BPM_REST := 72.0
const BPM_FAST := 140.0
const BPM_DYING := 190.0
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
var casing: MeshInstance3D
var screen: MeshInstance3D
var material: ShaderMaterial
## The look it's built in (it rebuilds when `style` changes).
var built := Style.CRT

var _phase := 0.0
var _angle := 0.0
var _spin := 0.0
var _hold := 0.0
var _hurt := 0.0
## -1 while on; then 0..1 switching off (a heartshot), or losing the signal.
var _off := -1.0
var _lost := -1.0
var _seed := 0.0

## Shared by every set; the glass's material is each set's own.
static var _meshes := {}
static var _plastic: StandardMaterial3D


func _ready() -> void:
	_build(style)
	revive()


## Builds the set and its glass in `look`, replacing what was there.
func _build(look: Style) -> void:
	built = look
	for child in [casing, screen]:
		if child:
			child.queue_free()
	casing = MeshInstance3D.new()
	casing.name = "Casing"
	casing.mesh = casing_mesh(look)
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
	var quad := QuadMesh.new()
	if look == Style.SPINNER:
		material.shader = SPINNER_SHADER
		quad.size = Vector2(DIAL, DIAL)
	else:
		material.shader = CRT_SHADER
		material.set_shader_parameter(&"aspect", GLASS.x / GLASS.y)
		quad.size = GLASS
	material.set_shader_parameter(&"seed", _seed)
	material.set_shader_parameter(&"crack", 1.0 if _off >= 0.0 else 0.0)
	screen = MeshInstance3D.new()
	screen.name = "Screen"
	screen.mesh = quad
	screen.material_override = material
	var depth := PUCK.z if look == Style.SPINNER else SIZE.z
	screen.position.z = STAND_OUT + depth * 0.5 + 0.0015  # Just proud of the face.
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(screen)


func _process(delta: float) -> void:
	if built != style:
		_build(style)
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
		material.set_shader_parameter(&"angle", _angle)
	else:
		material.set_shader_parameter(&"beat_phase", _phase if alive else 0.5)
	material.set_shader_parameter(&"health", health)
	material.set_shader_parameter(&"hurt", _hurt)
	material.set_shader_parameter(&"off", maxf(_off, 0.0))
	material.set_shader_parameter(&"lost", maxf(_lost, 0.0))


## A hit: the picture tears and snows (the CRT), or it hitches (the spinner).
func hurt() -> void:
	_hurt = 1.0
	_hold = maxf(_hold, HITCH_TIME)


## Its owner died: through the heart it switches off (and the CRT's glass
## cracks); otherwise the signal's lost.
func stop(heartshot: bool) -> void:
	if _off >= 0.0 or _lost >= 0.0:
		return
	if heartshot:
		_off = 0.0
		material.set_shader_parameter(&"crack", 1.0)
	else:
		_lost = 0.0


## Back on, the glass whole.
func revive() -> void:
	_off = -1.0
	_lost = -1.0
	_hurt = 0.0
	_hold = 0.0
	health = 1.0
	_phase = randf()
	_angle = randf() * TAU
	_seed = randf()
	material.set_shader_parameter(&"crack", 0.0)
	material.set_shader_parameter(&"seed", _seed)


## &"on", &"off" (switched off by a heartshot) or &"lost" (the signal lost).
func ending() -> StringName:
	if _off >= 0.0:
		return &"off"
	return &"lost" if _lost >= 0.0 else &"on"


## Where the CRT is in the current beat (0..1).
func beat() -> float:
	return _phase


## Where the spinner's lead dot is (radians).
func spin() -> float:
	return _angle


## The set's body for `look`, shared by every set: a rounded box for the CRT,
## a round puck for the spinner (both superellipsoids).
static func casing_mesh(look: Style) -> ArrayMesh:
	if not _meshes.has(look):
		if look == Style.SPINNER:
			_meshes[look] = _superellipsoid(PUCK * 0.5, 0.3, 1.0, true)
		else:
			_meshes[look] = _superellipsoid(SIZE * 0.5, 0.28, 0.28, false)
	return _meshes[look]


## A superellipsoid with half-extents `half`: `pole` squares off the profile
## along the pole axis (y, or z with `pole_z`), `round` the cross-section
## round it (1: round; toward 0: square).
static func _superellipsoid(half: Vector3, pole: float, round: float, pole_z: bool) -> ArrayMesh:
	const RINGS := 12
	const SEGMENTS := 24
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var point := func(eta: float, omega: float) -> Vector3:
		var ce := _signed_pow(cos(eta), pole)
		var across := Vector2(ce * _signed_pow(cos(omega), round), ce * _signed_pow(sin(omega), round))
		var along := _signed_pow(sin(eta), pole)
		if pole_z:
			return Vector3(half.x * across.x, half.y * across.y, half.z * along)
		return Vector3(half.x * across.x, half.y * along, half.z * across.y)
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
			# Swapping the pole axis mirrors the surface: wind the other way.
			for v: Vector3 in ([a, b, c, a, c, d] if pole_z else [a, c, b, a, d, c]):
				st.add_vertex(v)
	st.index()
	st.generate_normals()
	return st.commit()


static func _signed_pow(x: float, e: float) -> float:
	return signf(x) * pow(absf(x), e)
