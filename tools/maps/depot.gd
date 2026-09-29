extends RefCounted
## DEPOT (team, large, 168 × 104 m, turned 180°): a rail yard between two
## warehouses (GDD §9.3). The halves are the same turned end for end, so each
## team's warehouse sits in a different corner and the lanes cross diagonally.
## Open lanes on the ground, and a second yard 7 to 10 m up over them.
##
## Each team's end: the Warehouse (the team spawns in its back room; a
## mezzanine along the front, the SMG, its windows over the yard; a ramp from
## the loading yard up to its roof, and skylights to drop back in by), and
## beside it the loading yard, containers to climb (the revolver on a stack
## of two).
## The rail yard between, four tracks of parked boxcars making lanes along
## its length, long and straight:
##   the boxcars: cover, some stacked two high (7.2 m); roofs to climb onto
##     from the crates beside them (3.6 m up); one each side is open, doors in
##     both sides, the shotgun inside: the short way across a lane.
##   the Gantry: a crane bridge 9 m up spanning the whole yard across its
##     middle, a ramp up to it at each team's corner and a stair of containers
##     to climb onto it from the lanes. It sees down every lane; the rifle sits
##     on the trolley in its centre. Smash off it onto the cars.
##   the Footbridges: one each side, 7 m up across all four tracks, rails with
##     gaps to drop through, joined at the south end to the Signal tower (10 m,
##     the sniper behind a parapet looking down the lanes).
const K := GreyBox.Kind
const Side := preload("res://tools/level_side.gd")
const GANTRY := 9.0
const CAR := 3.6
const ROOF := 10.0
const FOOTBRIDGE := 7.0


static func build(kit) -> Transform3D:
	kit.environment.fog_density = 0.005
	kit.sun.directional_shadow_max_distance = 130.0

	kit.terrace("Ground", Vector2(-84, 84), Vector2(-52, 52), 0.0, K.FLOOR, -10.0)
	for e: Array in [["BoundaryN", Vector3(-84.5, 0, -52.5), Vector3(84.5, 14, -52)], ["BoundaryS", Vector3(-84.5, 0, 52), Vector3(84.5, 14, 52.5)],
			["BoundaryW", Vector3(-84.5, 0, -52), Vector3(-84, 14, 52)], ["BoundaryE", Vector3(84, 0, -52), Vector3(84.5, 14, 52)]]:
		kit.span(e[0], e[1], e[2], K.WALL)

	# The Gantry: the deck, its legs at the ends, the trolley in the middle.
	kit.span("GantryDeck", Vector3(-3, GANTRY - 0.5, -50), Vector3(3, GANTRY, 50), K.FLOOR)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			kit.span("GantryLeg_%d_%d" % [sx, sz], Vector3(sx * 1.8, 0, sz * 46), Vector3(sx * 3, GANTRY - 0.5, sz * 50), K.TOWER)
	# The rails leave gaps where the ramps and the container stairs arrive.
	kit.span("GantryRailE1", Vector3(2.7, GANTRY, -47), Vector3(3, GANTRY + 1, 18), K.LEDGE)
	kit.span("GantryRailE2", Vector3(2.7, GANTRY, 23), Vector3(3, GANTRY + 1, 50), K.LEDGE)
	kit.span("GantryRailW1", Vector3(-3, GANTRY, -50), Vector3(-2.7, GANTRY + 1, -23), K.LEDGE)
	kit.span("GantryRailW2", Vector3(-3, GANTRY, -18), Vector3(-2.7, GANTRY + 1, 47), K.LEDGE)
	kit.span("Trolley", Vector3(-2, GANTRY, -3), Vector3(2, GANTRY + 2, 3), K.TOWER)
	kit.pad("Pad_Rifle", Weapons.RIFLE, Vector3(0, GANTRY + 2, 0))
	kit.light("Gantry", Vector3(0, GANTRY + 4, 0), Color(1.0, 0.75, 0.35), 18.0)
	kit.label("GANTRY", Vector3(0, GANTRY + 6, 0))

	var red := Side.new(kit, Vector3(-1, 1, -1), "_Red", Hats.Team.RED)
	var blue := Side.new(kit, Vector3(1, 1, 1), "_Blue", Hats.Team.BLUE)
	var a := _half(red, "RED")
	_half(blue, "BLUE")
	return a


## One team's half, laid out with its warehouse in the north-east (x 58 to
## 84, z −52 to −6): `side` turns it round for the other.
static func _half(side, team_name: String) -> Transform3D:
	# The Warehouse: the hall, the mezzanine along the front, the back room.
	side.wall("WarehouseFront", Vector2(58, -52), Vector2(58, -6), 0.0, 10.0, [
			Rect2(12, 0, 6, 5), Rect2(30, 0, 6, 5),  # The loading doors.
			Rect2(5, 6.2, 4, 1.2), Rect2(20, 6.2, 4, 1.2), Rect2(39, 6.2, 4, 1.2)], K.WALL, 0.6)
	side.wall("WarehouseSouth", Vector2(58, -6), Vector2(84, -6), 0.0, 10.0, [Rect2(10, 0, 3, 4), Rect2(17, 0, 2.4, 3)], K.WALL, 0.6)
	side.wall("BackRoom", Vector2(72, -52), Vector2(72, -6), 0.0, 4.5, [Rect2(2, 0, 2.4, 3), Rect2(21, 0, 2.4, 3), Rect2(40, 0, 2.4, 3)])
	side.floor_with_holes("WarehouseRoof", Rect2(58, -52, 26, 46), ROOF, 0.5, [Rect2(61, -42, 3, 3), Rect2(66, -26, 3, 3)])
	side.span("RoofParapet", Vector3(58, ROOF, -52), Vector3(58.4, ROOF + 1.2, -6), K.LEDGE)
	# Up to the roof from the loading yard, over the side doors.
	side.ramp("RoofRamp", Vector3(60, 0, -3.5), Vector3(78, ROOF, -3.5), 3.0, K.RAMP, 0.6)
	side.span("RoofLanding", Vector3(78, ROOF - 0.5, -6), Vector3(84, ROOF, -2), K.FLOOR)
	side.span("Mezzanine", Vector3(58, 4.5, -52), Vector3(66, 5, -6), K.FLOOR)
	side.span("MezzLandingN", Vector3(66, 4.5, -52), Vector3(70, 5, -47), K.FLOOR)
	side.span("MezzLandingS", Vector3(66, 4.5, -9), Vector3(70, 5, -6), K.FLOOR)
	side.ramp("MezzStairN", Vector3(68, 0, -37), Vector3(68, 5, -47), 3.0, K.RAMP, 0.6)
	side.ramp("MezzStairS", Vector3(68, 0, -19), Vector3(68, 5, -9), 3.0, K.RAMP, 0.6)
	side.span("MezzRailing", Vector3(65.7, 5, -47), Vector3(66, 6, -9), K.LEDGE)
	side.span("HallCrates1", Vector3(61, 0, -31), Vector3(64, 2, -28), K.LEDGE)
	side.span("HallCrates2", Vector3(63, 0, -16), Vector3(65, 1.2, -12), K.LEDGE)
	side.span("BackRoomCrate", Vector3(76, 0, -30), Vector3(78, 1.2, -26), K.LEDGE)

	# The loading yard: containers (a stack of two with the revolver on it), a truck.
	for c: Array in [["Container1", Vector3(62, 0, 4), Vector3(68, 2.6, 6.5)], ["Container2", Vector3(74, 0, 10), Vector3(80, 2.6, 12.5)],
			["Container2Top", Vector3(74, 2.6, 10), Vector3(80, 5.2, 12.5)], ["Container3", Vector3(60, 0, 24), Vector3(66, 2.6, 26.5)],
			["Container4", Vector3(70, 0, 34), Vector3(76, 2.6, 36.5)], ["Container5", Vector3(78, 0, 42), Vector3(84, 2.6, 44.5)]]:
		side.span(c[0], c[1], c[2], K.RIDE)
	side.span("Truck", Vector3(76, 0, 24), Vector3(82, 3, 27), K.TOWER)

	# The rail yard: boxcars on the four tracks, crates to climb them, the open car.
	# Boxcars, x from and z of the track, and how many high.
	for car: Array in [[6.0, -30.0, 1], [22.0, -30.0, 1], [12.0, -10.0, 1], [40.0, -10.0, 2], [2.0, 10.0, 1], [16.0, 30.0, 1], [44.0, 30.0, 2]]:
		side.span("Boxcar_%d_%d" % [car[0], car[1]], Vector3(car[0], 0, car[1] - 1.5), Vector3(car[0] + 12, CAR * car[2], car[1] + 1.5), K.TOWER)
	for c: Vector2 in [Vector2(15, -8.5), Vector2(23, 31.5), Vector2(9, -28.5)]:
		side.span("CarCrate_%d_%d" % [c.x, c.y], Vector3(c.x, 0, c.y), Vector3(c.x + 2, 2, c.y + 2), K.LEDGE)
	side.wall("OpenCarN", Vector2(30, 8.5), Vector2(42, 8.5), 0.0, CAR - 0.3, [Rect2(5, 0, 2, 2.6)], K.TOWER, 0.3)
	side.wall("OpenCarS", Vector2(30, 11.5), Vector2(42, 11.5), 0.0, CAR - 0.3, [Rect2(5, 0, 2, 2.6)], K.TOWER, 0.3)
	side.wall("OpenCarW", Vector2(30, 8.5), Vector2(30, 11.5), 0.0, CAR - 0.3, [], K.TOWER, 0.3)
	side.wall("OpenCarE", Vector2(42, 8.5), Vector2(42, 11.5), 0.0, CAR - 0.3, [], K.TOWER, 0.3)
	side.span("OpenCarRoof", Vector3(29.85, CAR - 0.3, 8.35), Vector3(42.15, CAR, 11.65), K.TOWER)

	# The ramp up to the Gantry, and the container stair beside it.
	side.ramp("GantryRamp", Vector3(20, 0, -48.5), Vector3(3, GANTRY, -48.5), 3.0, K.RAMP, 0.6)
	for step in 3:
		side.span("ContainerStair_%d" % step, Vector3(3, 0, 15.5 + step * 2.5), Vector3(9, 2.6 * (step + 1), 18 + step * 2.5), K.RIDE)

	# The Footbridge over all four tracks, 7 m up: a stair down at the north
	# end, a ramp up onto the Signal tower at the south.
	side.span("Footbridge", Vector3(28.5, FOOTBRIDGE - 0.5, -45), Vector3(31.5, FOOTBRIDGE, 38), K.FLOOR)
	side.ramp("FootbridgeStair", Vector3(44, 0, -43.5), Vector3(31.5, FOOTBRIDGE, -43.5), 3.0, K.RAMP, 0.6)
	side.ramp("FootbridgeToSignal", Vector3(30, FOOTBRIDGE, 38), Vector3(30, 10, 44), 3.0, K.RAMP, 0.6)
	for seg: Vector2 in [Vector2(-40, -20), Vector2(-14, 6), Vector2(12, 32)]:
		for x in [28.5, 31.2]:
			side.span("FootbridgeRail_%d_%d" % [seg.x, x], Vector3(x, FOOTBRIDGE, seg.x), Vector3(x + 0.3, FOOTBRIDGE + 1, seg.y), K.LEDGE)
	side.span("SignalTower", Vector3(28, 0, 44), Vector3(32, 10, 51), K.TOWER)
	side.ramp("SignalRamp", Vector3(46, 0, 49.5), Vector3(32, 10, 49.5), 3.0, K.RAMP, 0.6)
	side.span("SignalParapetN1", Vector3(28, 10, 44), Vector3(28.5, 11.2, 44.4), K.LEDGE)
	side.span("SignalParapetN2", Vector3(31.5, 10, 44), Vector3(32, 11.2, 44.4), K.LEDGE)
	side.span("SignalParapetW", Vector3(28, 10, 44.4), Vector3(28.4, 11.2, 51), K.LEDGE)

	side.pad("Pad_Pistol", Weapons.PISTOL, Vector3(68, 0, -30))
	side.pad("Pad_Pistol2", Weapons.PISTOL, Vector3(70, 0, 0))
	side.pad("Pad_SMG", Weapons.SMG, Vector3(62, 5, -28))
	side.pad("Pad_Sniper", Weapons.SNIPER, Vector3(30, 10, 47.5), 0.0)
	side.pad("Pad_Shotgun", Weapons.SHOTGUN, Vector3(36, 0, 10))
	side.pad("Pad_Revolver", Weapons.REVOLVER, Vector3(77, 5.2, 11.25))

	var color := Color(1.0, 0.35, 0.3) if side.team == Hats.Team.RED else Color(0.35, 0.55, 1.0)
	side.light("BackRoom", Vector3(78, 3.5, -30), color, 16.0)
	side.light("Hall", Vector3(64, 8, -29), Color(1.0, 0.8, 0.5), 18.0)
	side.light("OpenCar", Vector3(36, 2.6, 10), Color(1.0, 0.5, 0.7), 5.0)
	side.label(team_name + " WAREHOUSE", Vector3(70, 13, -29))
	side.label(team_name + " SIGNAL", Vector3(30, 14, 47.5))

	var first: Transform3D = side.spawn("SpawnA", Vector3(78, 0, -46), Vector3(-1, 0, 0))
	side.spawn("SpawnB", Vector3(78, 0, -36), Vector3(-1, 0, 0))
	side.spawn("SpawnC", Vector3(78, 0, -22), Vector3(-1, 0, 0))
	side.spawn("SpawnD", Vector3(78, 0, -12), Vector3(-1, 0, 0))
	return first
