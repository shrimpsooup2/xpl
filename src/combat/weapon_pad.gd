class_name WeaponPad
extends Node3D
## A weapon pad (GDD §7.1): a glossy disc with the gun floating over it.
## Once taken, its ring fills back up and the gun pops back in after
## `respawn_time` (0: never). Every gun remembers the pad it came from, and
## an empty one lasts until the pad's next gun is taken (`generation`).

const HOVER := 0.95
const RADIUS := 0.7

## Its gun was taken (false) or is back (true).
signal changed(ready: bool)

@export var weapon: StringName = Weapons.PISTOL
@export var respawn_time := 20.0

var pickup: WeaponPickup
## How many of its guns have been taken. Its gun number n (the n it had
## when it appeared) is past its time once the next one's taken, when this
## is past n + 1.
var generation := 0
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
	generation += 1
	_timer = respawn_time if respawn_time > 0.0 else -1.0
	_ring.set_instance_shader_parameter(&"glow", 0.0)
	changed.emit(false)


## A client: the server's pad was taken (false) or is back (true).
func set_ready(ready: bool) -> void:
	if ready and pickup == null:
		_spawn(true)
	elif not ready and pickup:
		pickup.queue_free()
		taken(null)


## Whether its gun number `n` is past its time: the gun after it's been
## taken.
func outlived(n: int) -> bool:
	return generation > n + 1


func _process(delta: float) -> void:
	if _timer < 0.0:
		return
	_timer -= delta
	var filled := 1.0 - clampf(_timer / maxf(respawn_time, 0.01), 0.0, 1.0)
	_ring.scale = Vector3(lerpf(0.3, 1.0, filled), 0.3, lerpf(0.3, 1.0, filled))
	if _timer <= 0.0:
		_timer = -1.0
		if NetSession.authority():  # A client waits for the server to say.
			_spawn(true)


func _spawn(pop: bool) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return  # Taken off the map (a game with ammo boxes instead).
	var def := Weapons.get_def(weapon)
	pickup = WeaponPickup.create(def, def.ammo)
	pickup.origin = self
	pickup.origin_generation = generation
	get_parent().add_child(pickup)
	pickup.rest_on_pad(global_position + Vector3.UP * HOVER, self)
	_ring.set_instance_shader_parameter(&"glow", 0.9)
	_ring.scale = Vector3(1, 0.3, 1)
	if pop:
		pickup.pop_in()
	changed.emit(true)
