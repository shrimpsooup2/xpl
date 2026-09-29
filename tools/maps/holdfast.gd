extends RefCounted
## HOLDFAST (team, large, 224 × 112 m, mirrored): two forts facing each other
## across an open valley, the red fort at the west end, the blue at the east
## (GDD §9.3). Big-team, long-range, the open field layered with high ground.
##
## The forts: two floors, a roof and a corner tower. A gate in the front;
## stairs up the sides inside; the second floor's windows look out over the
## field (the SMG); a stair through the roof's hatch; a ramp on the roof up
## the tower (16 m), the sniper behind its parapet. Each team spawns behind
## its fort, out of sight.
## The valley between, three ways across, at three heights:
##   the Field (centre, 0): open ground, 160 m fort to fort, broken by rocks,
##     hedges, a bunker (the revolver) and a watchtower (8 m) on each half,
##     and the Hill in the middle: ramps up its north and south faces to its
##     first tier (5 m), a crate up to the Crown (9 m, the rifle), and a
##     tunnel straight through it, the shotgun inside.
##   the Ledge (north, 8 m): a shelf along the valley's north cliff, a ramp up
##     to it from each half of the field and a bridge from it onto each fort's
##     roof: the flank that comes out on top of the enemy. The Lookout in its
##     middle (11 m, the other revolver), and from there the Sky Bridge runs
##     over the field down onto the Crown. Its face is a ride wall.
##   the River (south, −3): a dry riverbed out of the field's sight, ramps up
##     into each fort's yard at the ends, the SMG under the middle bridge;
##     over it, the Bluff (5 m), bridges up to it from the field, a ruined
##     wall along it, looking down into the riverbed.
const K := GreyBox.Kind
const Side := preload("res://tools/level_side.gd")
const LEDGE := 8.0
const FLOOR2 := 5.0
const ROOF := 10.0
const TOWER := 16.0
const CROWN := 9.0
const BLUFF := 5.0


static func build(kit) -> Transform3D:
	kit.environment.fog_density = 0.004
	kit.sun.directional_shadow_max_distance = 160.0

	# --- The valley ---------------------------------------------------------------------
	kit.terrace("Field", Vector2(-112, 112), Vector2(-44, 34), 0.0, K.RIDE, -8.0)
	kit.terrace("Ledge", Vector2(-100, 100), Vector2(-56, -44), LEDGE, K.RIDE, -8.0)
	kit.terrace("RiverBed", Vector2(-96, 96), Vector2(34, 46), -3.0, K.FLOOR, -8.0)
	kit.terrace("SouthBank", Vector2(-112, 112), Vector2(46, 56), BLUFF, K.RIDE, -8.0)
	for e: Array in [["CliffN", Vector3(-113, 0, -57), Vector3(113, 24, -56)], ["CliffS", Vector3(-113, 0, 56), Vector3(113, 24, 57)],
			["CliffW", Vector3(-113, 0, -56), Vector3(-112, 24, 56)], ["CliffE", Vector3(112, 0, -56), Vector3(113, 24, 56)]]:
		kit.span(e[0], e[1], e[2], K.RIDE)

	# --- The middle: the Hill, the Lookout, the river bridge ------------------------------
	kit.span("HillN", Vector3(-12, 0, -8), Vector3(12, 5, -2.5), K.RIDE)
	kit.span("HillS", Vector3(-12, 0, 2.5), Vector3(12, 5, 8), K.RIDE)
	kit.span("HillRoof", Vector3(-12, 3, -2.5), Vector3(12, 5, 2.5), K.RIDE)
	kit.span("HillTop", Vector3(-12, 4.5, -8), Vector3(12, 5, 8), K.FLOOR)
	kit.ramp("HillRampN", Vector3(0, 0, -18), Vector3(0, 5, -8), 14.0, K.RAMP, 4.5)
	kit.ramp("HillRampS", Vector3(0, 0, 18), Vector3(0, 5, 8), 14.0, K.RAMP, 4.5)
	# The Crown: the Hill's second tier, a crate up to it each side, and the Sky
	# Bridge from the Ledge's lookout onto it.
	kit.span("Crown", Vector3(-6, 5, -5), Vector3(6, CROWN - 0.5, 5), K.RIDE)
	kit.span("CrownTop", Vector3(-6, CROWN - 0.5, -5), Vector3(6, CROWN, 5), K.FLOOR)
	kit.span("CrownWallW", Vector3(-6, CROWN, -3), Vector3(-5.4, CROWN + 1.2, 3), K.LEDGE)
	kit.span("CrownWallE", Vector3(5.4, CROWN, -3), Vector3(6, CROWN + 1.2, 3), K.LEDGE)
	kit.span("Lookout", Vector3(-8, LEDGE, -56), Vector3(8, LEDGE + 3, -44), K.TOWER)
	kit.span("LookoutParapetW", Vector3(-8, LEDGE + 3, -44.4), Vector3(-1.5, LEDGE + 4.2, -44), K.LEDGE)
	kit.span("LookoutParapetE", Vector3(1.5, LEDGE + 3, -44.4), Vector3(8, LEDGE + 4.2, -44), K.LEDGE)
	kit.ramp("SkyBridge", Vector3(0, CROWN, -5), Vector3(0, LEDGE + 3, -44), 3.0, K.FLOOR, 0.6)
	kit.ramp("RiverBridge", Vector3(0, 0, 34), Vector3(0, BLUFF, 46), 6.0, K.FLOOR, 0.6)

	kit.pad("Pad_Rifle", Weapons.RIFLE, Vector3(0, CROWN, 0))
	kit.pad("Pad_Shotgun", Weapons.SHOTGUN, Vector3(0, 0, 0))
	kit.pad("Pad_RevolverLookout", Weapons.REVOLVER, Vector3(0, LEDGE + 3, -50))
	kit.pad("Pad_SMGRiver", Weapons.SMG, Vector3(0, -3, 40))
	kit.light("Tunnel", Vector3(0, 2.4, 0), Color(1.0, 0.7, 0.3), 12.0)
	kit.light("UnderBridge", Vector3(0, -1, 40), Color(0.3, 0.85, 1.0), 8.0)
	kit.label("HILL", Vector3(0, 13, 0))
	kit.label("LEDGE", Vector3(0, 16, -50))
	kit.label("RIVER", Vector3(0, 3, 40))

	var red := Side.new(kit, Vector3(-1, 1, 1), "_Red", Hats.Team.RED)
	var blue := Side.new(kit, Vector3(1, 1, 1), "_Blue", Hats.Team.BLUE)
	var a := _half(red, "RED")
	_half(blue, "BLUE")
	return a


## One team's half, laid out on the east (the fort at x 80 to 100, the spawn
## behind it): `side` flips it for the west.
static func _half(side, team_name: String) -> Transform3D:
	# The fort.
	side.wall("FortFront", Vector2(80, -24), Vector2(80, 24), 0.0, ROOF, [
			Rect2(21, 0, 6, 4),  # The gate.
			Rect2(8, 1.2, 3, 1.2), Rect2(37, 1.2, 3, 1.2),  # Ground-floor windows.
			Rect2(4, 6.2, 4, 1.2), Rect2(12, 6.2, 4, 1.2), Rect2(32, 6.2, 4, 1.2), Rect2(40, 6.2, 4, 1.2)], K.WALL, 0.6)
	side.wall("FortBack", Vector2(100, -24), Vector2(100, 24), 0.0, ROOF, [Rect2(22, 0, 4, 3.5)], K.WALL, 0.6)
	for s: Array in [["FortN", -24.0], ["FortS", 24.0]]:
		side.wall(s[0], Vector2(80, s[1]), Vector2(100, s[1]), 0.0, ROOF, [Rect2(3, 0, 2.4, 3), Rect2(8, 6.2, 3, 1.2)], K.WALL, 0.6)
	side.ramp("FortStairN", Vector3(84, 0, -21.5), Vector3(95, FLOOR2, -21.5), 3.0, K.RAMP, 0.6)
	side.ramp("FortStairS", Vector3(84, 0, 21.5), Vector3(95, FLOOR2, 21.5), 3.0, K.RAMP, 0.6)
	side.floor_with_holes("FortFloor2", Rect2(80, -24, 20, 48), FLOOR2, 0.5, [Rect2(84, -23, 11, 3), Rect2(84, 20, 11, 3)])
	side.ramp("FortRoofStair", Vector3(96, FLOOR2, 0), Vector3(86, ROOF, 0), 3.0, K.RAMP, 0.6)
	side.floor_with_holes("FortRoof", Rect2(80, -24, 20, 48), ROOF, 0.5, [Rect2(86, -1.5, 10, 3)])
	side.span("FortParapetFront", Vector3(80, ROOF, -24), Vector3(80.6, ROOF + 1.2, 16), K.LEDGE)
	side.span("FortParapetS", Vector3(86, ROOF, 23.4), Vector3(100, ROOF + 1.2, 24), K.LEDGE)
	# The corner tower: the sniper's perch, 6 m over the roof.
	side.span("FortTower", Vector3(80, ROOF, 16), Vector3(86, TOWER, 24), K.TOWER)
	side.ramp("FortTowerRamp", Vector3(96, ROOF, 20), Vector3(86, TOWER, 20), 3.0, K.RAMP, 0.6)
	side.span("FortTowerParapetW", Vector3(80, TOWER, 16), Vector3(80.4, TOWER + 1.2, 24), K.LEDGE)
	side.span("FortTowerParapetN", Vector3(80.4, TOWER, 16), Vector3(86, TOWER + 1.2, 16.4), K.LEDGE)
	side.span("FortParapetN1", Vector3(80.6, ROOF, -24), Vector3(86.5, ROOF + 1.2, -23.4), K.LEDGE)
	side.span("FortParapetN2", Vector3(89.5, ROOF, -24), Vector3(100, ROOF + 1.2, -23.4), K.LEDGE)
	for p: Vector2 in [Vector2(86, -8), Vector2(86, 8), Vector2(94, -8), Vector2(94, 8)]:
		side.span("FortPillar_%d_%d" % [p.x, p.y], Vector3(p.x - 0.5, 0, p.y - 0.5), Vector3(p.x + 0.5, FLOOR2 - 0.5, p.y + 0.5), K.WALL)
	side.span("FortCover2", Vector3(84, FLOOR2, -12), Vector3(86, FLOOR2 + 1.2, -8), K.LEDGE)
	side.span("FortCover2b", Vector3(84, FLOOR2, 8), Vector3(86, FLOOR2 + 1.2, 12), K.LEDGE)

	# The Ledge: a ramp up from the field, cover, a bridge onto the fort's roof,
	# and a ramp up onto the lookout in the middle.
	side.ramp("LedgeRamp", Vector3(66, 0, -30), Vector3(66, LEDGE, -44), 4.0, K.RAMP, 6.9)
	side.ramp("LedgeBridge", Vector3(88, LEDGE, -44), Vector3(88, ROOF, -24), 3.0, K.FLOOR, 0.6)
	side.ramp("LookoutRamp", Vector3(20, LEDGE, -50), Vector3(8, LEDGE + 3, -50), 4.0, K.RAMP, 0.6)
	for c: Vector2 in [Vector2(32, -48), Vector2(50, -52), Vector2(78, -48)]:
		side.span("LedgeRock_%d" % c.x, Vector3(c.x - 1, LEDGE, c.y - 1), Vector3(c.x + 1, LEDGE + 1.2, c.y + 1), K.LEDGE)

	side.span("CrownCrate", Vector3(6, 5, -1), Vector3(8, 7, 1), K.LEDGE)

	# The Field: rocks, hedges, the bunker, and the watchtower.
	for r: Array in [[30.0, -30.0, 2.2], [44.0, -14.0, 1.4], [34.0, 22.0, 2.2], [60.0, 14.0, 1.4], [64.0, -20.0, 2.2], [20.0, 28.0, 1.4]]:
		side.span("Rock_%d_%d" % [r[0], r[1]], Vector3(r[0] - 1.5, 0, r[1] - 1.5), Vector3(r[0] + 1.5, r[2], r[1] + 1.5), K.TOWER)
	side.span("HedgeN", Vector3(36, 0, -24), Vector3(36.6, 1.2, -12), K.LEDGE)
	side.span("HedgeS", Vector3(36, 0, 12), Vector3(36.6, 1.2, 24), K.LEDGE)
	side.wall("BunkerFront", Vector2(46, -5), Vector2(46, 5), 0.0, 3.0, [Rect2(2, 1.3, 6, 0.6)], K.WALL, 0.5)
	side.wall("BunkerBack", Vector2(54, -5), Vector2(54, 5), 0.0, 3.0, [Rect2(4, 0, 2.4, 2.4)], K.WALL, 0.5)
	side.wall("BunkerN", Vector2(46, -5), Vector2(54, -5), 0.0, 3.0, [Rect2(2, 1.3, 4, 0.6)], K.WALL, 0.5)
	side.wall("BunkerS", Vector2(46, 5), Vector2(54, 5), 0.0, 3.0, [Rect2(3, 0, 2.4, 2.4)], K.WALL, 0.5)
	side.span("BunkerRoof", Vector3(45.75, 3, -5.25), Vector3(54.25, 3.3, 5.25), K.FLOOR)
	side.span("BunkerCrate", Vector3(55, 0, 2), Vector3(57, 2, 4), K.LEDGE)
	side.span("Watchtower", Vector3(40, 0, 22), Vector3(44, 8, 26), K.TOWER)
	side.ramp("WatchtowerRamp", Vector3(56, 0, 24), Vector3(44, 8, 24), 3.0, K.RAMP, 0.6)
	side.span("WatchtowerParapetW", Vector3(40, 8, 22), Vector3(40.4, 9.2, 26), K.LEDGE)
	side.span("WatchtowerParapetN", Vector3(40.4, 8, 22), Vector3(44, 9.2, 22.4), K.LEDGE)

	# The River: the ramp up into the fort's yard, a bridge up to the bluff,
	# rocks in the bed; on the bluff above it, a ruined wall and a way down.
	side.ramp("RiverRamp", Vector3(86, -3, 40), Vector3(96, 0, 40), 12.0, K.RAMP, 3.0)
	side.terrace("RiverEnd", Vector2(96, 112), Vector2(34, 46), 0.0, K.RIDE, -8.0)
	side.ramp("RiverBridge", Vector3(60, 0, 34), Vector3(60, BLUFF, 46), 4.0, K.FLOOR, 0.6)
	side.ramp("BluffRamp", Vector3(104, 0, 37), Vector3(104, BLUFF, 46), 4.0, K.RAMP, 0.6)
	side.span("RiverRock1", Vector3(38, -3, 37), Vector3(40, -1.6, 39), K.TOWER)
	side.span("RiverRock2", Vector3(70, -3, 41), Vector3(72, -1.6, 43), K.TOWER)
	side.span("BankCover", Vector3(40, BLUFF, 50), Vector3(44, BLUFF + 1.2, 50.4), K.LEDGE)
	side.wall("BluffRuin", Vector2(18, 48.5), Vector2(34, 48.5), BLUFF, BLUFF + 3.5, [Rect2(3, 1.2, 3, 1.2), Rect2(9, 0, 2.4, 2.6)], K.LEDGE, 0.6)

	side.pad("Pad_Pistol", Weapons.PISTOL, Vector3(96, 0, 10))
	side.pad("Pad_PistolSpawn", Weapons.PISTOL, Vector3(106, 0, -30))
	side.pad("Pad_SMG", Weapons.SMG, Vector3(84, FLOOR2, 0))
	side.pad("Pad_Sniper", Weapons.SNIPER, Vector3(83, TOWER, 20), 0.0)
	side.resupply("Resupply_Spawn", Vector3(104, 0, 12))
	side.resupply("Resupply_Fort", Vector3(96, FLOOR2, -8))
	side.resupply("Resupply_Bunker", Vector3(52.5, 0, -3))
	side.pad("Pad_Revolver", Weapons.REVOLVER, Vector3(50, 0, 0))

	var color := Color(1.0, 0.35, 0.3) if side.team == Hats.Team.RED else Color(0.35, 0.55, 1.0)
	side.light("FortHall", Vector3(90, 3.5, 0), color, 16.0)
	side.light("FortFloor2", Vector3(90, 8.5, 0), Color(1.0, 0.8, 0.5), 16.0)
	side.light("Bunker", Vector3(50, 2.4, 0), Color(1.0, 0.6, 0.3), 6.0)
	side.label(team_name + " FORT", Vector3(90, ROOF + 5, 0))

	var first: Transform3D = side.spawn("SpawnA", Vector3(106, 0, -18), Vector3(-1, 0, 0))
	side.spawn("SpawnB", Vector3(106, 0, -6), Vector3(-1, 0, 0))
	side.spawn("SpawnC", Vector3(106, 0, 6), Vector3(-1, 0, 0))
	side.spawn("SpawnD", Vector3(106, 0, 18), Vector3(-1, 0, 0))
	return first
