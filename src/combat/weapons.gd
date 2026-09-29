class_name Weapons
extends RefCounted
## The weapon roster (GDD §7.4): six guns modelled on real kinds of gun,
## with made-up but realistic model names, plus fists. Each gun is built
## from chunky blocks in beige plastic, gunmetal and chrome with one
## candy-coloured part, like the translucent computers of the time. Ids
## name the kind of gun; display names are the models.

const FISTS := &"fists"
const PISTOL := &"pistol"
const REVOLVER := &"revolver"
const SMG := &"smg"
const RIFLE := &"rifle"
const SHOTGUN := &"shotgun"
const SNIPER := &"sniper"
## The guns, in pad order.
const GUNS := [PISTOL, REVOLVER, SMG, RIFLE, SHOTGUN, SNIPER]

const COLORS := {
	&"dark": Color(0.17, 0.17, 0.2),
	&"metal": Color(0.72, 0.74, 0.78),
	&"beige": Color(0.86, 0.82, 0.7),
	&"grip": Color(0.25, 0.23, 0.26),
	&"glass": Color(0.55, 0.9, 1.0),
}

static var _defs := {}


static func get_def(id: StringName) -> WeaponDef:
	if _defs.is_empty():
		for def in [_fists(), _pistol(), _revolver(), _smg(), _rifle(), _shotgun(), _sniper()]:
			_defs[def.id] = def
	return _defs.get(id)


static func color(def: WeaponDef, key: StringName) -> Color:
	return def.accent if key == &"accent" else COLORS.get(key, Color.MAGENTA)


static func _box(tag: StringName, size: Vector3, at: Vector3, color_key: StringName, rot := Vector3.ZERO) -> Array:
	return ["box", tag, size, at, rot, color_key]


static func _cyl(tag: StringName, radius: float, length: float, at: Vector3, color_key: StringName, rot := Vector3.ZERO) -> Array:
	return ["cyl", tag, Vector3(radius, radius, length), at, rot, color_key]


# --- Fists ------------------------------------------------------------------

static func _fists() -> WeaponDef:
	var d := WeaponDef.new()
	d.id = FISTS
	d.display_name = "fists"
	d.based_on = "fists"
	d.damage = 25.0
	d.fire_interval = 0.4
	d.ammo = -1
	d.delivery = WeaponDef.Delivery.MELEE
	d.max_range = 2.2
	d.knockback = 5.0
	d.head_multiplier = 1.0
	d.hold = WeaponDef.Hold.FISTS
	d.action = WeaponDef.Action.NONE
	d.recoil = Vector3.ZERO
	d.view_kick = Vector2(0.0, 0.0)
	d.ejects = false
	return d


# --- Precision --------------------------------------------------------------

## A polymer-framed 9 mm service pistol: blocky slide, beige frame.
static func _pistol() -> WeaponDef:
	var d := WeaponDef.new()
	d.id = PISTOL
	d.display_name = "sp-12"
	d.based_on = "semi-automatic 9 mm pistol"
	d.damage = 15.0
	d.fire_interval = 0.3
	d.ammo = 12
	d.projectile_speed = 150.0
	d.spread = 0.3
	d.heartshot = true
	d.zoom = 1.2
	d.aim_spread = 0.3
	d.aim_time = 0.12
	d.sight_point = Vector3(0, 0.14, 0.02)
	d.eye_relief = 0.48
	d.recoil = Vector3(14.0, 2.0, 0.06)
	d.view_kick = Vector2(0.6, 0.7)
	d.cycle_time = 0.09
	d.hold = WeaponDef.Hold.ONE_HAND
	d.action = WeaponDef.Action.SLIDE
	d.accent = Color(0.0, 0.62, 0.74)  # Bondi blue.
	d.parts = [
		_box(&"", Vector3(0.05, 0.05, 0.22), Vector3(0, 0.045, -0.085), &"beige"),
		_box(&"slide", Vector3(0.058, 0.056, 0.25), Vector3(0, 0.1, -0.09), &"accent"),
		_box(&"", Vector3(0.048, 0.14, 0.066), Vector3(0, -0.02, 0.012), &"beige", Vector3(-14, 0, 0)),
		_box(&"", Vector3(0.012, 0.035, 0.07), Vector3(0, 0.0, -0.065), &"dark"),
		_box(&"trigger", Vector3(0.008, 0.025, 0.01), Vector3(0, 0.01, -0.05), &"metal"),
		_cyl(&"", 0.013, 0.02, Vector3(0, 0.1, -0.22), &"metal"),
		_box(&"", Vector3(0.012, 0.012, 0.012), Vector3(0, 0.134, -0.2), &"dark"),
		# The rear sight: two posts, the front sight showing between them.
		_box(&"", Vector3(0.01, 0.012, 0.012), Vector3(-0.011, 0.134, 0.02), &"dark"),
		_box(&"", Vector3(0.01, 0.012, 0.012), Vector3(0.011, 0.134, 0.02), &"dark"),
		_box(&"mag", Vector3(0.036, 0.04, 0.05), Vector3(0, -0.095, 0.03), &"dark", Vector3(-14, 0, 0)),
	]
	d.muzzle = Vector3(0, 0.1, -0.235)
	d.eject = Vector3(0.03, 0.12, -0.06)
	d.view_offset = Vector3(0.17, -0.2, -0.42)
	return d


## A .357 six-shooter: long chrome barrel, tangerine cylinder, a hammer you
## can fan (hold the trigger from the hip).
static func _revolver() -> WeaponDef:
	var d := WeaponDef.new()
	d.id = REVOLVER
	d.display_name = "marshal .357"
	d.based_on = ".357 revolver"
	d.damage = 32.0
	d.fire_interval = 0.5
	d.ammo = 6
	d.projectile_speed = 250.0
	d.heartshot = true
	d.fans = true
	d.zoom = 1.3
	d.aim_spread = 1.0
	d.aim_time = 0.14
	d.sight_point = Vector3(0, 0.15, 0.03)
	d.eye_relief = 0.46
	d.recoil = Vector3(28.0, 3.0, 0.08)
	d.view_kick = Vector2(1.2, 1.6)
	d.cycle_time = 0.16
	d.ejects = false
	d.hold = WeaponDef.Hold.ONE_HAND
	d.action = WeaponDef.Action.REVOLVER
	d.accent = Color(1.0, 0.52, 0.1)  # Tangerine.
	d.parts = [
		_box(&"", Vector3(0.05, 0.075, 0.13), Vector3(0, 0.07, -0.045), &"metal"),
		_cyl(&"cylinder", 0.042, 0.075, Vector3(0, 0.065, -0.06), &"accent"),
		_cyl(&"", 0.019, 0.22, Vector3(0, 0.1, -0.21), &"metal"),
		_box(&"", Vector3(0.03, 0.03, 0.2), Vector3(0, 0.07, -0.2), &"metal"),
		# A tall front sight, standing clear over the hammer.
		_box(&"", Vector3(0.007, 0.036, 0.012), Vector3(0, 0.132, -0.305), &"dark"),
		_box(&"hammer", Vector3(0.016, 0.04, 0.026), Vector3(0, 0.12, 0.028), &"dark", Vector3(-20, 0, 0)),
		_box(&"", Vector3(0.044, 0.13, 0.06), Vector3(0, -0.015, 0.04), &"beige", Vector3(-22, 0, 0)),
		_box(&"", Vector3(0.012, 0.035, 0.06), Vector3(0, 0.02, -0.03), &"dark"),
		_box(&"trigger", Vector3(0.008, 0.025, 0.01), Vector3(0, 0.03, -0.02), &"metal"),
	]
	d.muzzle = Vector3(0, 0.1, -0.325)
	d.view_offset = Vector3(0.17, -0.21, -0.42)
	return d


## A bolt-action rifle with a big scope.
static func _sniper() -> WeaponDef:
	var d := WeaponDef.new()
	d.id = SNIPER
	d.display_name = "heron .308"
	d.based_on = "bolt-action sniper rifle"
	d.tier = "heavy"
	d.damage = 70.0
	d.fire_interval = 1.2
	d.ammo = 5
	d.delivery = WeaponDef.Delivery.HITSCAN
	d.head_multiplier = 2.0
	d.heartshot = true
	d.knockback = 3.0
	d.sight = WeaponDef.Sight.SCOPE
	d.zoom = 3.0
	d.aim_spread = 1.0
	d.aim_time = 0.2
	d.sight_point = Vector3(0, 0.15, 0.05)
	d.eye_relief = 0.09
	d.recoil = Vector3(16.0, 2.0, 0.14)
	d.view_kick = Vector2(2.5, 2.2)
	d.cycle_time = 0.6
	d.cycle_delay = 0.25
	d.hold = WeaponDef.Hold.TWO_HAND
	d.action = WeaponDef.Action.BOLT
	d.accent = Color(0.22, 0.4, 0.95)  # Blueberry.
	d.parts = [
		_box(&"", Vector3(0.056, 0.08, 0.34), Vector3(0, 0.06, -0.12), &"dark"),
		_box(&"", Vector3(0.06, 0.07, 0.42), Vector3(0, 0.035, -0.46), &"beige"),
		_cyl(&"", 0.017, 0.5, Vector3(0, 0.075, -0.7), &"metal"),
		_box(&"", Vector3(0.04, 0.04, 0.07), Vector3(0, 0.075, -0.96), &"dark"),
		_cyl(&"", 0.026, 0.3, Vector3(0, 0.15, -0.13), &"accent"),
		_cyl(&"", 0.034, 0.06, Vector3(0, 0.15, -0.3), &"accent"),
		_cyl(&"", 0.024, 0.005, Vector3(0, 0.15, -0.332), &"glass"),
		_cyl(&"", 0.03, 0.04, Vector3(0, 0.15, 0.03), &"dark"),
		_box(&"", Vector3(0.02, 0.04, 0.02), Vector3(0, 0.115, -0.05), &"dark"),
		_box(&"", Vector3(0.02, 0.04, 0.02), Vector3(0, 0.115, -0.21), &"dark"),
		_box(&"", Vector3(0.05, 0.13, 0.06), Vector3(0, -0.02, 0.015), &"beige", Vector3(-18, 0, 0)),
		_box(&"", Vector3(0.05, 0.12, 0.36), Vector3(0, 0.035, 0.24), &"beige"),
		_box(&"", Vector3(0.055, 0.14, 0.03), Vector3(0, 0.03, 0.43), &"dark"),
		_box(&"mag", Vector3(0.04, 0.06, 0.07), Vector3(0, -0.005, -0.14), &"dark"),
		_box(&"bolt", Vector3(0.075, 0.016, 0.016), Vector3(0.05, 0.08, -0.02), &"metal"),
		_box(&"trigger", Vector3(0.008, 0.025, 0.01), Vector3(0, 0.01, -0.04), &"metal"),
	]
	d.fore = Vector3(0, -0.01, -0.4)
	d.muzzle = Vector3(0, 0.075, -1.0)
	d.eject = Vector3(0.03, 0.09, -0.1)
	d.view_offset = Vector3(0.16, -0.21, -0.36)
	d.view_rotation = Vector3(1.0, 2.0, 0.0)
	return d


# --- Automatic --------------------------------------------------------------

## A compact 9 mm submachine gun with a long grape magazine and a little
## open dot sight on top.
static func _smg() -> WeaponDef:
	var d := WeaponDef.new()
	d.id = SMG
	d.display_name = "sx-50"
	d.based_on = "9 mm submachine gun"
	d.damage = 7.0
	d.fire_interval = 0.07
	d.automatic = true
	d.ammo = 50
	d.projectile_speed = 180.0
	d.spread = 1.0
	d.spread_max = 4.0
	d.bloom_per_shot = 0.25
	d.head_multiplier = 1.25
	d.sight = WeaponDef.Sight.DOT
	d.zoom = 1.25
	d.aim_spread = 0.55
	d.aim_time = 0.13
	d.sight_point = Vector3(0, 0.162, -0.07)
	d.eye_relief = 0.26
	d.recoil = Vector3(5.0, 2.5, 0.03)
	d.view_kick = Vector2(0.3, 0.35)
	d.cycle_time = 0.05
	d.hold = WeaponDef.Hold.TWO_HAND
	d.action = WeaponDef.Action.BOLT_CARRIER
	d.accent = Color(0.58, 0.32, 0.86)  # Grape.
	d.parts = [
		_box(&"", Vector3(0.056, 0.09, 0.34), Vector3(0, 0.07, -0.13), &"dark"),
		_box(&"", Vector3(0.03, 0.022, 0.24), Vector3(0, 0.125, -0.13), &"beige"),
		_cyl(&"", 0.024, 0.1, Vector3(0, 0.08, -0.35), &"metal"),
		_box(&"", Vector3(0.046, 0.12, 0.052), Vector3(0, -0.02, 0.012), &"beige", Vector3(-14, 0, 0)),
		_box(&"mag", Vector3(0.036, 0.2, 0.05), Vector3(0, -0.07, -0.14), &"accent", Vector3(8, 0, 0)),
		_box(&"", Vector3(0.036, 0.07, 0.2), Vector3(0, 0.055, 0.12), &"dark"),
		_box(&"", Vector3(0.05, 0.1, 0.03), Vector3(0, 0.03, 0.22), &"beige"),
		_box(&"", Vector3(0.044, 0.08, 0.044), Vector3(0, 0.0, -0.27), &"beige"),
		_box(&"bolt", Vector3(0.016, 0.02, 0.04), Vector3(-0.036, 0.1, -0.2), &"metal"),
		_box(&"trigger", Vector3(0.008, 0.025, 0.01), Vector3(0, 0.02, -0.04), &"metal"),
		# The dot sight: a grape frame you look through, on a dark mount.
		_box(&"", Vector3(0.03, 0.01, 0.05), Vector3(0, 0.141, -0.1), &"dark"),
		_box(&"", Vector3(0.006, 0.034, 0.014), Vector3(-0.018, 0.163, -0.1), &"accent"),
		_box(&"", Vector3(0.006, 0.034, 0.014), Vector3(0.018, 0.163, -0.1), &"accent"),
		_box(&"", Vector3(0.042, 0.006, 0.014), Vector3(0, 0.183, -0.1), &"accent"),
	]
	d.fore = Vector3(0, -0.03, -0.27)
	d.muzzle = Vector3(0, 0.08, -0.4)
	d.eject = Vector3(0.03, 0.1, -0.12)
	d.view_offset = Vector3(0.15, -0.21, -0.38)
	return d


## A 5.56 assault rifle: lime banana magazine, and a carry handle with a
## notched rear sight at its back.
static func _rifle() -> WeaponDef:
	var d := WeaponDef.new()
	d.id = RIFLE
	d.display_name = "tr-30"
	d.based_on = "assault rifle"
	d.damage = 11.0
	d.fire_interval = 0.11
	d.automatic = true
	d.ammo = 30
	d.projectile_speed = 200.0
	d.spread = 0.5
	d.spread_max = 1.5
	d.bloom_per_shot = 0.1
	d.head_multiplier = 1.5
	d.zoom = 1.6
	d.aim_spread = 0.35
	d.aim_time = 0.16
	d.sight_point = Vector3(0, 0.16, 0.0)
	d.eye_relief = 0.24
	d.recoil = Vector3(7.0, 2.0, 0.04)
	d.view_kick = Vector2(0.4, 0.5)
	d.cycle_time = 0.07
	d.hold = WeaponDef.Hold.TWO_HAND
	d.action = WeaponDef.Action.BOLT_CARRIER
	d.accent = Color(0.56, 0.84, 0.18)  # Lime.
	d.parts = [
		_box(&"", Vector3(0.06, 0.1, 0.4), Vector3(0, 0.065, -0.12), &"beige"),
		_box(&"", Vector3(0.064, 0.074, 0.3), Vector3(0, 0.07, -0.47), &"dark"),
		_cyl(&"", 0.014, 0.2, Vector3(0, 0.08, -0.71), &"metal"),
		_box(&"", Vector3(0.012, 0.07, 0.02), Vector3(0, 0.125, -0.6), &"dark"),
		_box(&"", Vector3(0.024, 0.03, 0.14), Vector3(0, 0.1325, -0.06), &"dark"),
		_box(&"", Vector3(0.007, 0.03, 0.012), Vector3(-0.009, 0.16, 0.0), &"dark"),
		_box(&"", Vector3(0.007, 0.03, 0.012), Vector3(0.009, 0.16, 0.0), &"dark"),
		_box(&"mag", Vector3(0.04, 0.2, 0.075), Vector3(0, -0.07, -0.2), &"accent", Vector3(16, 0, 0)),
		_box(&"", Vector3(0.048, 0.13, 0.058), Vector3(0, -0.02, 0.012), &"dark", Vector3(-16, 0, 0)),
		_box(&"", Vector3(0.046, 0.1, 0.3), Vector3(0, 0.04, 0.22), &"beige"),
		_box(&"", Vector3(0.05, 0.13, 0.03), Vector3(0, 0.03, 0.38), &"dark"),
		_box(&"bolt", Vector3(0.012, 0.026, 0.05), Vector3(0.034, 0.085, -0.12), &"metal"),
		_box(&"trigger", Vector3(0.008, 0.025, 0.01), Vector3(0, 0.02, -0.04), &"metal"),
	]
	d.fore = Vector3(0, 0.02, -0.45)
	d.muzzle = Vector3(0, 0.08, -0.82)
	d.eject = Vector3(0.035, 0.09, -0.12)
	d.view_offset = Vector3(0.15, -0.2, -0.36)
	d.view_rotation = Vector3(1.0, 3.0, 0.0)
	return d


# --- Close range ------------------------------------------------------------

## A 12-gauge pump-action: strawberry pump, tube magazine under the barrel,
## a ghost-ring sight and a strawberry front post.
static func _shotgun() -> WeaponDef:
	var d := WeaponDef.new()
	d.id = SHOTGUN
	d.display_name = "warden 12"
	d.based_on = "pump-action shotgun"
	d.damage = 7.0
	d.pellets = 9
	d.fire_interval = 0.8
	d.ammo = 8
	d.projectile_speed = 120.0
	d.max_range = 60.0
	d.spread = 5.0
	d.head_multiplier = 1.0
	d.knockback = 1.0
	d.zoom = 1.15
	d.aim_spread = 0.65
	d.aim_time = 0.16
	d.sight_point = Vector3(0, 0.16, 0.02)
	d.eye_relief = 0.22
	d.recoil = Vector3(24.0, 3.0, 0.12)
	d.view_kick = Vector2(2.0, 2.0)
	d.cycle_time = 0.34
	d.cycle_delay = 0.12
	d.hold = WeaponDef.Hold.TWO_HAND
	d.action = WeaponDef.Action.PUMP
	d.accent = Color(0.93, 0.22, 0.38)  # Strawberry.
	d.parts = [
		_box(&"", Vector3(0.062, 0.095, 0.27), Vector3(0, 0.065, -0.09), &"dark"),
		_cyl(&"", 0.023, 0.56, Vector3(0, 0.095, -0.5), &"metal"),
		_cyl(&"", 0.02, 0.46, Vector3(0, 0.048, -0.44), &"dark"),
		_box(&"pump", Vector3(0.064, 0.064, 0.19), Vector3(0, 0.048, -0.42), &"accent"),
		_box(&"", Vector3(0.05, 0.13, 0.06), Vector3(0, -0.02, 0.015), &"beige", Vector3(-18, 0, 0)),
		_box(&"", Vector3(0.05, 0.11, 0.3), Vector3(0, 0.04, 0.2), &"beige"),
		_box(&"", Vector3(0.055, 0.13, 0.03), Vector3(0, 0.03, 0.36), &"dark"),
		# A ghost-ring rear sight on the receiver, a tall post at the muzzle.
		_box(&"", Vector3(0.006, 0.07, 0.012), Vector3(-0.013, 0.145, 0.02), &"dark"),
		_box(&"", Vector3(0.006, 0.07, 0.012), Vector3(0.013, 0.145, 0.02), &"dark"),
		_box(&"", Vector3(0.032, 0.006, 0.012), Vector3(0, 0.183, 0.02), &"dark"),
		_box(&"", Vector3(0.008, 0.04, 0.012), Vector3(0, 0.14, -0.76), &"accent"),
		_box(&"trigger", Vector3(0.008, 0.025, 0.01), Vector3(0, 0.02, -0.03), &"metal"),
	]
	d.fore = Vector3(0, 0.02, -0.42)
	d.muzzle = Vector3(0, 0.095, -0.78)
	d.eject = Vector3(0.035, 0.08, -0.08)
	d.view_offset = Vector3(0.15, -0.21, -0.36)
	d.view_rotation = Vector3(1.0, 3.0, 0.0)
	return d
