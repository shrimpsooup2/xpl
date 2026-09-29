extends RefCounted
## RIFT (spread out, 200 × 88 m, 0 to 36 m up, open sky): a canyon between
## two rims (GDD §9.3). Off the rims' outer edges is the void.
##
## Three layers, three kinds of fight:
##   the Rims: the north rim at 28 m, the south at 20. Long sightlines down
##     the canyon and across it, a sniper tower on each (36 m and 28 m), rifles.
##   the Shelves: a ledge along each canyon wall (12 m north, 10 m south),
##     partway up: flanking paths above the floor, below the rims.
##   the Floor: ruins, a colonnade and the Arch (a block across the canyon
##     with a tunnel through it) break it up for close range: the shotgun,
##     the SMG. At the east end an overhang of the north rim hides the
##     colonnade from anyone up there.
## Getting between them:
##   the end ramps: the whole canyon floor rises at each end, to the south
##     rim in the west and the north rim in the east (the long slide down);
##   ramps up the walls: floor to each shelf, each shelf to its rim;
##   bridges: the High Bridge rim to rim, the Mid Bridge shelf to shelf, both
##     crossings in the open;
##   the big drop: smash from a rim onto the floor (28 m) and the bounce
##     (22 m/s) throws you back up to the shelves.
## Four spawns (each rim, each end of the floor); in a duel, the two rims,
## each about eleven seconds from its own tower and sixteen from the other.

const K := GreyBox.Kind
const NORTH := 28.0
const SOUTH := 20.0
const NORTH_SHELF := 12.0
const SOUTH_SHELF := 10.0


static func build(kit) -> Transform3D:
	kit.environment.fog_density = 0.004
	kit.sun.directional_shadow_max_distance = 160.0

	# The canyon: a floor between the rims, rising at each end.
	kit.terrace("Floor", Vector2(-100, 100), Vector2(-16, 16), 0.0, K.FLOOR, -12.0)
	kit.terrace("NorthRim", Vector2(-100, 100), Vector2(-44, -16), NORTH, K.RIDE, -12.0)
	kit.terrace("SouthRim", Vector2(-100, 100), Vector2(16, 44), SOUTH, K.RIDE, -12.0)
	kit.ramp("WestRamp", Vector3(-60, 0, 0), Vector3(-100, SOUTH, 0), 32.0, K.RAMP, 0.7)
	kit.ramp("EastRamp", Vector3(60, 0, 0), Vector3(100, NORTH, 0), 32.0, K.RAMP, 0.7)

	# The shelves: solid ledges along the walls (ride their faces from the
	# floor). The ramps up from the floor are filled in underneath (their
	# thickness buried in the floor and the shelf); the ramps on up to the
	# rims fly free along the walls.
	kit.terrace("NorthShelf", Vector2(-40, 30), Vector2(-16, -12), NORTH_SHELF, K.RIDE, 0.0)
	kit.ramp("FloorToNorthShelf", Vector3(56, 0, -14), Vector3(30, NORTH_SHELF, -14), 4.0, K.RAMP, 11.0)
	kit.ramp("NorthShelfToRim", Vector3(-40, NORTH_SHELF, -14), Vector3(-67.7, NORTH, -14), 4.0, K.RAMP, 0.6)
	kit.span("NorthShelfToRimTop", Vector3(-71.7, NORTH - 0.6, -16), Vector3(-67.7, NORTH, -12), K.FLOOR)
	kit.terrace("SouthShelf", Vector2(-30, 50), Vector2(12, 16), SOUTH_SHELF, K.RIDE, 0.0)
	kit.ramp("FloorToSouthShelf", Vector3(-56, 0, 14), Vector3(-30, SOUTH_SHELF, 14), 4.0, K.RAMP, 10.0)
	kit.ramp("SouthShelfToRim", Vector3(50, SOUTH_SHELF, 14), Vector3(67.3, SOUTH, 14), 4.0, K.RAMP, 0.6)
	kit.span("SouthShelfToRimTop", Vector3(67.3, SOUTH - 0.6, 12), Vector3(71.3, SOUTH, 16), K.FLOOR)

	# The crossings.
	kit.ramp("HighBridge", Vector3(0, SOUTH, 16), Vector3(0, NORTH, -16), 3.0, K.FLOOR, 0.6)
	kit.ramp("MidBridge", Vector3(10, SOUTH_SHELF, 12), Vector3(10, NORTH_SHELF, -12), 3.0, K.FLOOR, 0.6)

	# The floor: the Arch, ruins, the colonnade, and the overhang above it.
	kit.span("ArchN", Vector3(-34, 0, -16), Vector3(-26, 4, -2.5), K.TOWER)
	kit.span("ArchS", Vector3(-34, 0, 2.5), Vector3(-26, 4, 16), K.TOWER)
	kit.span("ArchRoof", Vector3(-34, 3, -2.5), Vector3(-26, 4, 2.5), K.TOWER)
	kit.span("ArchCrateW", Vector3(-36, 0, -10), Vector3(-34, 2, -8), K.LEDGE)
	kit.span("ArchCrateE", Vector3(-26, 0, 8), Vector3(-24, 2, 10), K.LEDGE)
	kit.span("Ruin1", Vector3(-50, 0, -6), Vector3(-46, 3, -2), K.LEDGE)
	kit.span("Ruin2", Vector3(-14, 0, 4), Vector3(-10, 2.5, 8), K.LEDGE)
	kit.span("Ruin3", Vector3(16, 0, -8), Vector3(20, 3.5, -4), K.LEDGE)
	kit.span("UnderBridge", Vector3(-4, 0, -3), Vector3(4, 1.2, 3), K.LEDGE)
	for cx in [26, 34, 42, 50]:
		for cz in [-5, 5]:
			kit.span("Column_%d_%d" % [cx, cz], Vector3(cx - 0.75, 0, cz - 0.75), Vector3(cx + 0.75, 5, cz + 0.75), K.TOWER)
	kit.span("Overhang", Vector3(30, NORTH - 2, -16), Vector3(60, NORTH, -9), K.RIDE)

	# The rims: a sniper tower on each, cover along the edges.
	kit.span("NorthTower", Vector3(-63, NORTH, -35), Vector3(-57, NORTH + 8, -29), K.TOWER)
	kit.ramp("NorthTowerRamp", Vector3(-43, NORTH, -32), Vector3(-57, NORTH + 8, -32), 3.0, K.RAMP, 0.6)
	kit.span("NorthTowerWall", Vector3(-63, NORTH + 8, -29.6), Vector3(-57, NORTH + 9.2, -29), K.LEDGE)
	kit.span("SouthTower", Vector3(57, SOUTH, 29), Vector3(63, SOUTH + 8, 35), K.TOWER)
	kit.ramp("SouthTowerRamp", Vector3(43, SOUTH, 32), Vector3(57, SOUTH + 8, 32), 3.0, K.RAMP, 0.6)
	kit.span("SouthTowerWall", Vector3(57, SOUTH + 8, 29), Vector3(63, SOUTH + 9.2, 29.6), K.LEDGE)
	for x in [-80, -20, 20, 80]:
		kit.span("NorthRimCover_%d" % x, Vector3(x - 2, NORTH, -21), Vector3(x + 2, NORTH + 1.6, -19), K.LEDGE)
		kit.span("SouthRimCover_%d" % x, Vector3(-x - 2, SOUTH, 19), Vector3(-x + 2, SOUTH + 1.6, 21), K.LEDGE)
	kit.span("NorthRock", Vector3(-6, NORTH, -38), Vector3(2, NORTH + 3, -32), K.TOWER)
	kit.span("SouthRock", Vector3(-2, SOUTH, 32), Vector3(6, SOUTH + 3, 38), K.TOWER)

	kit.pad("Pad_SniperNorth", Weapons.SNIPER, Vector3(-60, NORTH + 8, -32), 0.0)
	kit.pad("Pad_SniperSouth", Weapons.SNIPER, Vector3(60, SOUTH + 8, 32), 0.0)
	kit.pad("Pad_RifleNorth", Weapons.RIFLE, Vector3(20, NORTH, -34))
	kit.pad("Pad_RifleSouth", Weapons.RIFLE, Vector3(-20, SOUTH, 34))
	kit.pad("Pad_SMG", Weapons.SMG, Vector3(0, 0, 6))
	kit.pad("Pad_Shotgun", Weapons.SHOTGUN, Vector3(-30, 0, 0))
	kit.pad("Pad_RevolverNorth", Weapons.REVOLVER, Vector3(-20, NORTH_SHELF, -14))
	kit.pad("Pad_RevolverSouth", Weapons.REVOLVER, Vector3(30, SOUTH_SHELF, 14))
	kit.pad("Pad_PistolA", Weapons.PISTOL, Vector3(34, NORTH, -30))
	kit.pad("Pad_PistolB", Weapons.PISTOL, Vector3(-34, SOUTH, 30))
	kit.pad("Pad_PistolC", Weapons.PISTOL, Vector3(-50, 0, 10))
	kit.pad("Pad_PistolD", Weapons.PISTOL, Vector3(54, 0, 10))

	kit.light("ArchGlow", Vector3(-30, 2.5, 0), Color(1.0, 0.7, 0.3), 9.0)
	kit.light("UnderOverhang", Vector3(45, 6, -12), Color(0.3, 0.85, 1.0), 16.0)
	kit.light("Colonnade", Vector3(38, 4, 0), Color(1.0, 0.4, 0.6), 14.0)
	kit.light("WestFloor", Vector3(-50, 4, 0), Color(0.6, 0.4, 1.0), 14.0)

	kit.label("NORTH RIM", Vector3(40, NORTH + 4, -30))
	kit.label("SOUTH RIM", Vector3(-40, SOUTH + 4, 30))
	kit.label("HIGH BRIDGE", Vector3(0, NORTH + 3, 0))
	kit.label("ARCH", Vector3(-30, 7, 0))
	kit.label("NORTH SHELF", Vector3(-10, NORTH_SHELF + 3, -14))
	kit.label("SOUTH SHELF", Vector3(20, SOUTH_SHELF + 3, 14))

	var a: Transform3D = kit.spawn("SpawnA", Vector3(30, NORTH, -30), Vector3(-1, 0, 0))
	kit.spawn("SpawnB", Vector3(-30, SOUTH, 30), Vector3(1, 0, 0))
	kit.spawn("SpawnC", Vector3(-50, 0, 6), Vector3(1, 0, 0))
	kit.spawn("SpawnD", Vector3(54, 0, 6), Vector3(-1, 0, 0))
	return a
