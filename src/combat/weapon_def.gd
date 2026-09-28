class_name WeaponDef
extends Resource
## One weapon's stats, how it's held and animated, and its model (GDD §7).
## The roster is in Weapons; adding a weapon is mostly filling one of these.
##
## Weapon space: the origin is where the right hand grips, -Z is forward
## (down the barrel), +Y up, +X right. Meters.

enum Delivery { PROJECTILE, HITSCAN, MELEE }
## How the arms hold it: one hand (the left arm stays out of view), or two
## with the left hand on the foregrip.
enum Hold { FISTS, ONE_HAND, TWO_HAND }
## The mechanical cycle animated after each shot.
enum Action { NONE, SLIDE, REVOLVER, BOLT_CARRIER, PUMP, BOLT }

@export var id: StringName
@export var display_name: String
## The real kind of gun it's modelled on, for reference.
@export var based_on: String
@export var tier: String = "standard"

@export_group("Firing")
@export var damage := 20.0
@export var pellets := 1
@export var fire_interval := 0.3
@export var automatic := false
## Rounds in the gun. Map weapons never reload (GDD §7.2).
@export var ammo := 12
@export var delivery := Delivery.PROJECTILE
@export var projectile_speed := 150.0
@export var projectile_gravity := 0.0
@export var max_range := 250.0
## Spread cone half-angle in degrees; automatic weapons bloom toward
## spread_max while held and recover when released.
@export var spread := 0.0
@export var spread_max := 0.0
@export var bloom_per_shot := 0.0
@export var head_multiplier := 1.5
@export var heartshot := false
## Knockback on the target (m/s).
@export var knockback := 0.0
## &"fan" (fan the hammer) or &"zoom", or empty.
@export var alt := &""
@export var zoom := 1.0

@export_group("Feel")
## Viewmodel recoil per shot: (pitch degrees, random yaw degrees, push back meters).
@export var recoil := Vector3(8.0, 1.5, 0.05)
## Camera kick per shot (vertical fov degrees, pitch degrees).
@export var view_kick := Vector2(0.5, 0.6)
## How long the action takes to cycle, and when after the shot it starts.
@export var cycle_time := 0.12
@export var cycle_delay := 0.0
## Shell casings thrown per shot (0 for the revolver, which keeps them).
@export var ejects := true

@export_group("Model")
@export var hold := Hold.ONE_HAND
@export var action := Action.SLIDE
@export var accent := Color.WHITE
## [kind ("box" or "cyl"), tag, size, position, rotation degrees, color key]
## Cylinders lie along Z: size is (radius, radius, length). Tags name the
## moving parts (&"slide", &"hammer", &"cylinder", &"bolt", &"pump",
## &"mag", &"trigger"); empty for fixed parts.
@export var parts: Array = []
## Left hand, for two-handed holds (on the pump for a pump-action).
@export var fore := Vector3.ZERO
@export var muzzle := Vector3.ZERO
## Where casings come out (they go right and up).
@export var eject := Vector3.ZERO
## The grip's place in view (camera space), and how the gun is turned there
## (degrees): toed in a little, like a held gun.
@export var view_offset := Vector3(0.2, -0.2, -0.42)
@export var view_rotation := Vector3(2.0, 4.0, 0.0)


func is_fists() -> bool:
	return hold == Hold.FISTS
