class_name WeaponPad
extends Node3D
## A weapon pad (GDD §7.1): a glossy disc with the gun floating over it.
## Once taken, its ring fills back up and the gun pops back in after
## `respawn_time` (0: never).

const HOVER := 0.95
const RADIUS := 0.7

@export var weapon: StringName = Weapons.PISTOL
@export var respawn_time := 20.0

var pickup: WeaponPickup
var _ring: MeshInstance3D
var _timer := -1.0


func _ready() -> void:
	var def := Weapons.get_def(weapon)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = RADIUS
	cyl.bottom_radius = RADIUS * 1.1
	cyl.height = 0.12
	cyl.radial_segments = 16
	cyl.rings = 1
	disc.mesh = cyl
	disc.material_override = WeaponModel.material(false)
	disc.set_instance_shader_parameter(&"color", Weapons.COLORS[&"dark"])
	disc.set_instance_shader_parameter(&"gloss", 0.6)
	disc.position.y = 0.06
	add_child(disc)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = RADIUS * 0.8
	torus.outer_radius = RADIUS * 0.92
	torus.rings = 24
	torus.ring_segments = 4
	_ring.mesh = torus
	_ring.material_override = WeaponModel.material(false)
	_ring.set_instance_shader_parameter(&"color", def.accent)
	_ring.set_instance_shader_parameter(&"glow", 0.9)
	_ring.position.y = 0.125
	_ring.scale = Vector3(1, 0.3, 1)
	add_child(_ring)
	_spawn.call_deferred(false)


## Called by its pickup when it's taken.
func taken(_by: WeaponPickup) -> void:
	pickup = null
	_timer = respawn_time if respawn_time > 0.0 else -1.0
	_ring.set_instance_shader_parameter(&"glow", 0.0)


func _process(delta: float) -> void:
	if _timer < 0.0:
		return
	_timer -= delta
	var filled := 1.0 - clampf(_timer / maxf(respawn_time, 0.01), 0.0, 1.0)
	_ring.scale = Vector3(lerpf(0.3, 1.0, filled), 0.3, lerpf(0.3, 1.0, filled))
	if _timer <= 0.0:
		_timer = -1.0
		_spawn(true)


func _spawn(pop: bool) -> void:
	var def := Weapons.get_def(weapon)
	pickup = WeaponPickup.create(def, def.ammo)
	get_parent().add_child(pickup)
	pickup.rest_on_pad(global_position + Vector3.UP * HOVER, self)
	_ring.set_instance_shader_parameter(&"glow", 0.9)
	_ring.scale = Vector3(1, 0.3, 1)
	if pop:
		pickup.pop_in()
