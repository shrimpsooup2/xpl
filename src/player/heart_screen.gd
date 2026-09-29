class_name HeartScreen
extends Node3D
## The heart (GDD §6): a tiny CRT set into the chest, its screen glowing
## heart pink with a pixel heart beating on it. The beat speeds up with speed
## and races near death; a hit tears the picture and it snows; near death
## the picture rolls. Death ends it one of two ways: an ordinary one loses
## the signal to static, a heartshot switches the set off (the picture
## collapses to a white-hot line, then a dot, then black) and cracks the
## glass.
##
## Its origin is the heart's hit centre (HitShapes), and the glass fits
## inside that sphere, so what glows is what counts.

## The set: a rounded box, and the glass on its face.
const SIZE := Vector3(0.12, 0.096, 0.05)
const GLASS := Vector2(0.094, 0.0735)
const CASING_COLOR := Color(0.1, 0.1, 0.12)
## The set sits this far out from the hit centre, proud of the chest.
const STAND_OUT := 0.012
const SHADER := preload("res://src/render/heart_screen.gdshader")
## Beats per minute: at rest, flat out, and near death.
const BPM_REST := 72.0
const BPM_FAST := 140.0
const BPM_DYING := 190.0
## Speed (m/s) that counts as flat out, and health below which it races.
const FAST_SPEED := 14.0
const DYING_BELOW := 0.35
const HURT_TIME := 0.35
const SWITCH_OFF_TIME := 0.45
const SIGNAL_LOSS_TIME := 0.6

## Its owner's health (0..1) and speed (m/s), kept up to date by the
## PlayerModel (set_health, animate_movement).
var health := 1.0
var speed := 0.0
var casing: MeshInstance3D
var screen: MeshInstance3D
var material: ShaderMaterial

var _phase := 0.0
var _hurt := 0.0
## -1 while on; then 0..1 switching off (a heartshot), or losing the signal.
var _off := -1.0
var _lost := -1.0

## Shared by every set; the screen's material is each set's own.
static var _casing_mesh: ArrayMesh
static var _plastic: StandardMaterial3D


func _ready() -> void:
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
	material.shader = SHADER
	material.set_shader_parameter(&"seed", randf())
	material.set_shader_parameter(&"aspect", GLASS.x / GLASS.y)
	var quad := QuadMesh.new()
	quad.size = GLASS
	screen = MeshInstance3D.new()
	screen.name = "Screen"
	screen.mesh = quad
	screen.material_override = material
	screen.position.z = STAND_OUT + SIZE.z * 0.5 + 0.0015  # Just proud of the face.
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(screen)
	revive()


func _process(delta: float) -> void:
	var fast := clampf(speed / FAST_SPEED, 0.0, 1.0)
	var bpm := lerpf(BPM_REST, BPM_FAST, fast)
	if health < DYING_BELOW:
		bpm = lerpf(bpm, BPM_DYING, 1.0 - health / DYING_BELOW)
	if _off < 0.0 and _lost < 0.0:
		_phase = fmod(_phase + delta * bpm / 60.0, 1.0)
	_hurt = maxf(_hurt - delta / HURT_TIME, 0.0)
	if _off >= 0.0:
		_off = minf(_off + delta / SWITCH_OFF_TIME, 1.0)
	if _lost >= 0.0:
		_lost = minf(_lost + delta / SIGNAL_LOSS_TIME, 1.0)
	material.set_shader_parameter(&"beat_phase", _phase if _off < 0.0 and _lost < 0.0 else 0.5)
	material.set_shader_parameter(&"health", health)
	material.set_shader_parameter(&"hurt", _hurt)
	material.set_shader_parameter(&"off", maxf(_off, 0.0))
	material.set_shader_parameter(&"lost", maxf(_lost, 0.0))


## A hit: the picture tears and snows for a moment.
func hurt() -> void:
	_hurt = 1.0


## Its owner died: through the heart it switches off and the glass cracks;
## otherwise the signal's lost.
func stop(heartshot: bool) -> void:
	if _off >= 0.0 or _lost >= 0.0:
		return
	if heartshot:
		_off = 0.0
		material.set_shader_parameter(&"crack", 1.0)
	else:
		_lost = 0.0


## Back on, beating, the glass whole.
func revive() -> void:
	_off = -1.0
	_lost = -1.0
	_hurt = 0.0
	health = 1.0
	_phase = randf()
	material.set_shader_parameter(&"crack", 0.0)
	material.set_shader_parameter(&"seed", randf())


## &"on", &"off" (switched off by a heartshot) or &"lost" (the signal lost).
func ending() -> StringName:
	if _off >= 0.0:
		return &"off"
	return &"lost" if _lost >= 0.0 else &"on"


## Where it is in the current beat (0..1).
func beat() -> float:
	return _phase


## A rounded box (a superellipsoid), shared by every set.
static func casing_mesh() -> ArrayMesh:
	if _casing_mesh:
		return _casing_mesh
	const RINGS := 12
	const SEGMENTS := 24
	const ROUND := 0.28  # 1: an ellipsoid; toward 0: a box.
	var half := SIZE * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var point := func(eta: float, omega: float) -> Vector3:
		var ce := _signed_pow(cos(eta), ROUND)
		return Vector3(half.x * ce * _signed_pow(cos(omega), ROUND), half.y * _signed_pow(sin(eta), ROUND),
				half.z * ce * _signed_pow(sin(omega), ROUND))
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
	_casing_mesh = st.commit()
	return _casing_mesh


static func _signed_pow(x: float, e: float) -> float:
	return signf(x) * pow(absf(x), e)
