extends RefCounted
## STACK (small, 22 × 22 m): two floors in a walled box (GDD §9.3).
##
## Below, a dim cellar under a 4.5 m ceiling, broken up by four pillars;
## above, the open roof. Down is always one step away (four holes and two
## ramp slots), but up is slow and readable: the ramps, or a crate under a
## hole you climb out of. The shotgun sits at the bottom of the Well, the
## hole in the middle, so grabbing it puts you under anyone on the roof:
## they can stomp you through it (a 5 m smashdown), then bounce straight
## back out. Rifles sit on two pulpits on the roof.
##
## Heights: cellar 0, roof 5, pulpits 7.5, wall tops 8. Rotationally
## symmetric (180°) so the brawl is fair.

const K := GreyBox.Kind
const ROOF := 5.0
const SLAB := 0.5
const WALL_TOP := 8.0
const WELL := Rect2(-1.5, -1.5, 3, 3)
const CLIMB_A := Rect2(-7.5, 1.5, 3, 3)
const CLIMB_B := Rect2(4.5, -4.5, 3, 3)
const SLOT_N := Rect2(-3.0, -11, 4.66, 3)
const SLOT_S := Rect2(-1.66, 8, 4.66, 3)


static func build(kit) -> Transform3D:
	kit.box("Floor", Vector3(0, -0.5, 0), Vector3(24, 1, 24), K.FLOOR)
	# The box: plain walls round the cellar, ride tiles round the roof.
	for w: Array in [["N", Vector3(0, 0, -11.5), Vector3(24, 0, 1)], ["S", Vector3(0, 0, 11.5), Vector3(24, 0, 1)],
			["W", Vector3(-11.5, 0, 0), Vector3(1, 0, 22)], ["E", Vector3(11.5, 0, 0), Vector3(1, 0, 22)]]:
		var at: Vector3 = w[1]
		var size: Vector3 = w[2]
		kit.box("CellarWall_" + w[0], at + Vector3.UP * ROOF * 0.5, size + Vector3.UP * ROOF, K.WALL)
		kit.box("RoofWall_" + w[0], at + Vector3.UP * (ROOF + WALL_TOP) * 0.5, size + Vector3.UP * (WALL_TOP - ROOF), K.RIDE)

	var holes: Array[Rect2] = [WELL, CLIMB_A, CLIMB_B, SLOT_N, SLOT_S]
	kit.floor_with_holes("Roof", Rect2(-11, -11, 22, 22), ROOF, SLAB, holes)
	# Ramps up the north and south walls (30°), coming out through slots in
	# the roof: covered at the bottom, in the open at the top.
	kit.ramp("RampN", Vector3(-7, 0, -9.5), Vector3(1.66, ROOF, -9.5), 3.0)
	kit.ramp("RampS", Vector3(7, 0, 9.5), Vector3(-1.66, ROOF, 9.5), 3.0)
	# Pillars hold the roof up and poke through it as cover posts round the Well.
	for p: Vector2 in [Vector2(-3.5, -3.5), Vector2(3.5, -3.5), Vector2(-3.5, 3.5), Vector2(3.5, 3.5)]:
		kit.box("Pillar_%d_%d" % [p.x, p.y], Vector3(p.x, 3.1, p.y), Vector3(1.2, 6.2, 1.2), K.TOWER)
	# A 2.5 m crate against one edge of each climb hole: jump onto it, then
	# jump and grab the roof. The quick way up, and it pops you up in the open.
	kit.box("CrateA", Vector3(-6.5, 1.25, 2.5), Vector3(2, 2.5, 2), K.LEDGE)
	kit.box("CrateB", Vector3(6.5, 1.25, -2.5), Vector3(2, 2.5, 2), K.LEDGE)
	# Up top: two pulpits (the rifles, and the highest ground) and two low
	# walls either side of the Well to peek from.
	kit.box("PulpitA", Vector3(-7, ROOF + 1.25, -5), Vector3(2.5, 2.5, 2.5), K.TOWER)
	kit.box("PulpitB", Vector3(7, ROOF + 1.25, 5), Vector3(2.5, 2.5, 2.5), K.TOWER)
	kit.box("LowWallN", Vector3(0, ROOF + 0.6, -5), Vector3(4, 1.2, 0.6), K.LEDGE)
	kit.box("LowWallS", Vector3(0, ROOF + 0.6, 5), Vector3(4, 1.2, 0.6), K.LEDGE)

	kit.pad("Pad_Shotgun", Weapons.SHOTGUN, Vector3(0, 0, 0))
	kit.pad("Pad_PistolA", Weapons.PISTOL, Vector3(-9.5, 0, 5))
	kit.pad("Pad_PistolB", Weapons.PISTOL, Vector3(9.5, 0, -5))
	kit.pad("Pad_RifleA", Weapons.RIFLE, Vector3(-7, ROOF + 2.5, -5))
	kit.pad("Pad_RifleB", Weapons.RIFLE, Vector3(7, ROOF + 2.5, 5))

	kit.light("CellarAmber", Vector3(-6, 3.8, 6), Color(1.0, 0.7, 0.3), 9.0)
	kit.light("CellarCyan", Vector3(6, 3.8, -6), Color(0.3, 0.85, 1.0), 9.0)
	kit.light("CellarViolet", Vector3(-6, 3.8, -6), Color(0.6, 0.4, 1.0), 9.0)
	kit.light("CellarRose", Vector3(6, 3.8, 6), Color(1.0, 0.4, 0.6), 9.0)
	kit.light("WellGlow", Vector3(0, 2.5, 0), Color(1.0, 0.95, 0.8), 6.0, 1.5)

	kit.label("THE WELL", Vector3(0, 7.2, 0))
	kit.label("CRATE CLIMB", Vector3(-6, 3.5, 3))
	kit.label("CRATE CLIMB", Vector3(6, 3.5, -3))

	var a: Transform3D = kit.spawn("SpawnA", Vector3(-8.5, 0, 8.5), Vector3(1, 0, -1))
	kit.spawn("SpawnB", Vector3(8.5, 0, -8.5), Vector3(-1, 0, 1))
	# Two more on the roof for a four-way free-for-all.
	kit.spawn("SpawnC", Vector3(8.5, ROOF, 8.5), Vector3(-1, 0, -1))
	kit.spawn("SpawnD", Vector3(-8.5, ROOF, -8.5), Vector3(1, 0, 1))
	return a
