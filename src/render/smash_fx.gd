class_name SmashFx
extends RefCounted
## World effects for the smashdown (GDD §4.4): the shockwave ring and ground
## flash on impact, the smaller ring a slam bounce launches off, and the ring
## projected on the ground where a descending smashdown will land. Flat,
## unshaded, white: they read against any floor and to every player.

const RING_TIME := 0.4
const FLASH_TIME := 0.16
## Shockwave reach at impact (GDD: 3.5 m radius).
const SHOCKWAVE_RADIUS := 3.5

static var _ring_mesh: TorusMesh
static var _disc_mesh: CylinderMesh


## The impact: a ring racing out to the shockwave radius, a second slower
## one, and a bright disc that flashes and fades. strength ~ drop / 10.
static func shockwave(parent: Node, at: Vector3, strength: float) -> void:
	var s := clampf(strength, 0.3, 1.5)
	_ring(parent, at, 0.3, SHOCKWAVE_RADIUS * lerpf(0.8, 1.2, s), RING_TIME, 0.9)
	_ring(parent, at, 0.2, SHOCKWAVE_RADIUS * 0.55, RING_TIME * 1.4, 0.6)
	_flash(parent, at, 1.4 * s)


## A slam bounce's launch: one small, quick ring.
static func launch(parent: Node, at: Vector3) -> void:
	_ring(parent, at, 0.2, 1.4, 0.25, 0.7)


## The landing tell: a flat ring you place and scale every frame.
static func make_marker() -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	marker.mesh = _ring_shape()
	marker.material_override = _material(Color(1, 1, 1, 0.8))
	marker.top_level = true
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return marker


static func _ring(parent: Node, at: Vector3, from: float, to: float, time: float, alpha: float) -> void:
	var ring := MeshInstance3D.new()
	ring.mesh = _ring_shape()
	var material := _material(Color(1, 1, 1, alpha))
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring)
	ring.global_position = at + Vector3.UP * 0.04
	ring.scale = Vector3(from, 1.0, from)
	var t := ring.create_tween().set_parallel()
	t.tween_property(ring, "scale", Vector3(to, 1.0, to), time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(material, "albedo_color:a", 0.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(ring.queue_free)


static func _flash(parent: Node, at: Vector3, radius: float) -> void:
	if _disc_mesh == null:
		_disc_mesh = CylinderMesh.new()
		_disc_mesh.top_radius = 1.0
		_disc_mesh.bottom_radius = 1.0
		_disc_mesh.height = 0.02
		_disc_mesh.radial_segments = 24
		_disc_mesh.rings = 1
	var disc := MeshInstance3D.new()
	disc.mesh = _disc_mesh
	var material := _material(Color(1, 1, 1, 0.9))
	disc.material_override = material
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(disc)
	disc.global_position = at + Vector3.UP * 0.03
	disc.scale = Vector3(radius, 1.0, radius)
	var t := disc.create_tween().set_parallel()
	t.tween_property(disc, "scale", Vector3(radius * 1.6, 1.0, radius * 1.6), FLASH_TIME)
	t.tween_property(material, "albedo_color:a", 0.0, FLASH_TIME)
	t.chain().tween_callback(disc.queue_free)


## A flat unit ring (radius 1, thin band) lying on the ground.
static func _ring_shape() -> TorusMesh:
	if _ring_mesh == null:
		_ring_mesh = TorusMesh.new()
		_ring_mesh.inner_radius = 0.88
		_ring_mesh.outer_radius = 1.0
		_ring_mesh.rings = 32
		_ring_mesh.ring_segments = 4
	return _ring_mesh


static func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
