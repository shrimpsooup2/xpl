extends RefCounted
## BOULEVARD (team, large, 144 × 72 m, mirrored): a three-lane town, the red
## yard at the west end, the blue yard at the east (GDD §9.3).
##
## The three lanes, each a different range:
##   the Arcade (north): a two-storey building along the whole lane. Below,
##     rooms joined by doors that zigzag (no line through); above, a long
##     gallery whose windows look down on the street. In the middle, the
##     Atrium: a double-height hall with a balcony (the shotgun) and a
##     skylight in its roof.
##   Main Street (centre): long and open, parked cars for cover, the Plaza in
##     the middle with the rifle on the fountain's plinth. Each end is shut by
##     a gate wall, so no one shoots into a yard from across the map.
##   the Canal (south): a sunken channel, 3.5 m deep, its walls rideable, the
##     revolver under the middle bridge, a ramp down into it from each yard.
##     Beside it a row of kiosks (the SMG in the middle one) whose flat roofs
##     make a middle layer, and a walkway along the far bank.
## Up top: the rooftops. A ramp from each yard climbs to the Arcade's roof and
## the Tower on it (the sniper, looking down the street); the roof runs the
## length of the lane, over the Atrium, whose skylight you can drop through.
## Heights: canal −3.5, street 0, kiosk roofs 4, gallery 5, roofs 9.5, towers 12.
## Four spawns a team in its yard.

const K := GreyBox.Kind
const Side := preload("res://tools/level_side.gd")


static func build(kit) -> Transform3D:
	kit.environment.fog_density = 0.006
	kit.sun.directional_shadow_max_distance = 110.0

	# --- Ground, canal and boundary --------------------------------------------------
	kit.terrace("Ground", Vector2(-72, 72), Vector2(-34, 20), 0.0, K.RIDE, -6.0)
	kit.terrace("Walkway", Vector2(-72, 72), Vector2(30, 38), 0.0, K.RIDE, -6.0)
	kit.terrace("CanalBed", Vector2(-58, 58), Vector2(20, 30), -3.5, K.FLOOR, -6.0)
	kit.span("BoundaryN", Vector3(-72.5, 0, -34.5), Vector3(72.5, 14, -34), K.WALL)
	kit.span("BoundaryS", Vector3(-72.5, 0, 38), Vector3(72.5, 14, 38.5), K.WALL)
	kit.span("BoundaryW", Vector3(-72.5, 0, -34), Vector3(-72, 14, 38), K.WALL)
	kit.span("BoundaryE", Vector3(72, 0, -34), Vector3(72.5, 14, 38), K.WALL)

	# --- The middle: Atrium, Plaza, the middle bridge -----------------------------------
	kit.wall("AtriumFront", Vector2(-16, -14), Vector2(16, -14), 0.0, 9.0,
			[Rect2(1, 0, 30, 4.5), Rect2(4, 6.1, 6, 1.2), Rect2(22, 6.1, 6, 1.2)])
	for x in [-5, 5]:
		kit.span("AtriumPillar_%d" % x, Vector3(x - 0.5, 0, -14.5), Vector3(x + 0.5, 4.5, -13.5), K.WALL)
	kit.span("Balcony", Vector3(-16, 4.5, -34), Vector3(16, 5, -29), K.FLOOR)
	kit.span("Landing", Vector3(-4, 4.5, -29), Vector3(4, 5, -26), K.FLOOR)
	kit.span("LandingRail", Vector3(-4, 5, -26.3), Vector3(4, 6, -26), K.LEDGE)
	kit.floor_with_holes("AtriumRoof", Rect2(-16, -34, 32, 20), 9.5, 0.5, [Rect2(-5, -26, 10, 8)])
	kit.span("AtriumParapet", Vector3(-16, 9.5, -14.5), Vector3(16, 10.5, -14), K.LEDGE)
	for x in [-7, 7]:
		kit.span("Planter_%d" % x, Vector3(x - 1.5, 0, -21), Vector3(x + 1.5, 1.1, -19), K.LEDGE)
	# The fountain: a dry basin, the rifle on its plinth.
	kit.span("BasinN", Vector3(-5, 0, -2), Vector3(5, 0.8, -1.5), K.LEDGE)
	kit.span("BasinS", Vector3(-5, 0, 7.5), Vector3(5, 0.8, 8), K.LEDGE)
	kit.span("BasinW", Vector3(-5, 0, -1.5), Vector3(-4.5, 0.8, 7.5), K.LEDGE)
	kit.span("BasinE", Vector3(4.5, 0, -1.5), Vector3(5, 0.8, 7.5), K.LEDGE)
	kit.span("Plinth", Vector3(-1, 0, 2), Vector3(1, 2.2, 4), K.TOWER)
	kit.span("MidBridge", Vector3(-3, -0.5, 20), Vector3(3, 0, 30), K.FLOOR)

	kit.pad("Pad_Rifle", Weapons.RIFLE, Vector3(0, 2.2, 3))
	kit.pad("Pad_Shotgun", Weapons.SHOTGUN, Vector3(0, 5, -31.5))
	kit.pad("Pad_Revolver", Weapons.REVOLVER, Vector3(0, -3.5, 25))
	kit.label("ATRIUM", Vector3(0, 12, -24))
	kit.label("PLAZA", Vector3(0, 6, 3))
	kit.label("CANAL", Vector3(0, 2, 25))

	# --- Each team's half ---------------------------------------------------------------
	var red := Side.new(kit, Vector3(-1, 1, 1), "_Red", Hats.Team.RED)
	var blue := Side.new(kit, Vector3(1, 1, 1), "_Blue", Hats.Team.BLUE)
	var a := _half(red, "RED")
	_half(blue, "BLUE")
	return a


## One team's half, laid out on the east (x > 0, the yard at the far end):
## `side` flips it for the west.
static func _half(side, team_name: String) -> Transform3D:
	# The Arcade: rooms below, the gallery above, the roof and the tower on top.
	side.wall("ArcadeFront", Vector2(16, -14), Vector2(56, -14), 0.0, 9.0, [
			Rect2(4, 0, 2.4, 3), Rect2(16, 0, 2.4, 3), Rect2(33, 0, 2.4, 3),  # Doors, room by room.
			Rect2(9, 1.2, 3, 1.2), Rect2(22, 1.2, 3, 1.2),  # Ground-floor windows.
			Rect2(2, 6.1, 3, 1.2), Rect2(8, 6.1, 3, 1.2), Rect2(14, 6.1, 3, 1.2),  # The gallery's windows.
			Rect2(20, 6.1, 3, 1.2), Rect2(26, 6.1, 3, 1.2), Rect2(32, 6.1, 3, 1.2)])
	side.wall("ArcadeEnd", Vector2(56, -34), Vector2(56, -14), 0.0, 9.0)
	side.wall("ArcadeMid", Vector2(16, -34), Vector2(16, -14), 0.0, 9.0,
			[Rect2(6, 0, 8, 3.5), Rect2(1, 5, 2.4, 3), Rect2(8, 6.1, 6, 1.2)])
	side.wall("ArcadeWall1", Vector2(42, -34), Vector2(42, -14), 0.0, 4.5, [Rect2(14, 0, 2.4, 3)])
	side.wall("ArcadeWall2", Vector2(29, -34), Vector2(29, -14), 0.0, 4.5, [Rect2(4, 0, 2.4, 3)])
	side.ramp("ArcadeStair", Vector3(44, 0, -32.5), Vector3(53, 5, -32.5), 3.0, K.RAMP, 0.6)
	side.floor_with_holes("ArcadeUpper", Rect2(16, -34, 40, 20), 5.0, 0.5, [Rect2(44, -34, 9, 3)])
	side.span("GalleryCover1", Vector3(24, 5, -22), Vector3(26, 6.2, -18), K.LEDGE)
	side.span("GalleryCover2", Vector3(38, 5, -30), Vector3(40, 6.2, -26), K.LEDGE)
	side.span("ArcadeRoof", Vector3(16, 9, -34), Vector3(56, 9.5, -14), K.FLOOR)
	side.span("RoofParapet", Vector3(16, 9.5, -14.5), Vector3(50, 10.5, -14), K.LEDGE)
	side.span("Tower", Vector3(50, 9.5, -20), Vector3(56, 12, -14), K.TOWER)
	side.ramp("TowerStair", Vector3(53, 9.5, -30), Vector3(53, 12, -20), 3.0, K.RAMP, 0.6)
	side.span("TowerParapetS", Vector3(50, 12, -14.4), Vector3(56, 13.2, -14), K.LEDGE)
	side.span("TowerParapetW", Vector3(50, 12, -20), Vector3(50.4, 13.2, -14.4), K.LEDGE)
	# From the yard up to the roof: filled in underneath.
	side.ramp("RoofRamp", Vector3(57.5, 0, -15.5), Vector3(57.5, 9.5, -30.5), 3.0, K.RAMP, 8.0)
	side.span("RoofLanding", Vector3(56, 9, -34), Vector3(59, 9.5, -30.5), K.FLOOR)
	side.span("AtriumRailing", Vector3(4, 5, -29.3), Vector3(16, 6, -29), K.LEDGE)
	side.ramp("AtriumStair", Vector3(13, 0, -27.5), Vector3(4, 5, -27.5), 3.0, K.RAMP, 0.6)

	# Main Street: cars, a bus shelter, and the gate that shuts the yard off.
	for c: Array in [["Car1", 20.0, -5.5], ["Car2", 36.0, 2.5], ["Car3", 48.0, -4.0]]:
		side.span(c[0], Vector3(c[1], 0, c[2]), Vector3(c[1] + 4.5, 1.5, c[2] + 2), K.TOWER)
	side.span("Shelter", Vector3(28, 0, 10.6), Vector3(34, 2.6, 11), K.WALL)
	side.span("ShelterRoof", Vector3(28, 2.6, 9), Vector3(34, 2.9, 11), K.FLOOR)
	side.wall("Gate", Vector2(58.5, -12), Vector2(58.5, 14), 0.0, 7.0, [Rect2(8, 0, 8, 4.5)], K.WALL, 0.8)

	# The kiosks: A and C solid (a crate up each), B a shop you can go through.
	side.span("KioskA", Vector3(16, 0, 14), Vector3(28, 4, 20), K.LEDGE)
	side.span("KioskACrate", Vector3(22, 0, 12.5), Vector3(24, 2, 14), K.LEDGE)
	side.wall("KioskBFront", Vector2(32, 14), Vector2(44, 14), 0.0, 3.5, [Rect2(5, 0, 2.4, 3), Rect2(1.5, 1.2, 2.5, 1.2), Rect2(8.5, 1.2, 2.5, 1.2)])
	side.wall("KioskBBack", Vector2(32, 20), Vector2(44, 20), 0.0, 3.5, [Rect2(3, 0, 2.4, 3)])
	side.wall("KioskBW", Vector2(32, 14), Vector2(32, 20), 0.0, 3.5)
	side.wall("KioskBE", Vector2(44, 14), Vector2(44, 20), 0.0, 3.5)
	side.span("KioskBRoof", Vector3(32, 3.5, 14), Vector3(44, 4, 20), K.FLOOR)
	side.span("KioskC", Vector3(48, 0, 14), Vector3(56, 4, 20), K.LEDGE)
	side.span("KioskCCrate", Vector3(51, 0, 12.5), Vector3(53, 2, 14), K.LEDGE)

	# The canal: the ramp down from the yard, a bridge, cover on the walkway.
	side.ramp("CanalRamp", Vector3(46, -3.5, 25), Vector3(58, 0, 25), 10.0, K.RAMP, 3.6)
	side.terrace("YardCanalEnd", Vector2(58, 72), Vector2(20, 30), 0.0, K.RIDE, -6.0)
	side.span("Bridge", Vector3(34, -0.5, 20), Vector3(38, 0, 30), K.FLOOR)
	side.span("WalkwayCover1", Vector3(24, 0, 33), Vector3(28, 1.2, 33.4), K.LEDGE)
	side.span("WalkwayCover2", Vector3(44, 0, 35), Vector3(48, 1.2, 35.4), K.LEDGE)

	# The yard.
	side.span("YardCrate1", Vector3(62, 0, -2), Vector3(64, 1.5, 2), K.LEDGE)
	side.span("YardCrate2", Vector3(63, 0, 25), Vector3(65, 1.5, 27), K.LEDGE)

	side.pad("Pad_Pistol", Weapons.PISTOL, Vector3(66, 0, -18))
	side.pad("Pad_Pistol2", Weapons.PISTOL, Vector3(66, 0, 16))
	side.pad("Pad_PistolWalkway", Weapons.PISTOL, Vector3(40, 0, 34))
	side.pad("Pad_Revolver", Weapons.REVOLVER, Vector3(35.5, 0, -24))
	side.pad("Pad_SMG", Weapons.SMG, Vector3(38, 0, 17))
	side.pad("Pad_Sniper", Weapons.SNIPER, Vector3(53, 12, -17), 0.0)
	side.resupply("Resupply_Yard", Vector3(64, 0, 8))
	side.resupply("Resupply_Arcade", Vector3(52, 0, -30))
	side.resupply("Resupply_Walkway", Vector3(52, 0, 36))

	side.label(team_name + " YARD", Vector3(65, 6, 0))
	side.label(team_name + " TOWER", Vector3(53, 16, -17))

	var first: Transform3D = side.spawn("SpawnA", Vector3(68, 0, -26), Vector3(-1, 0, 0))
	side.spawn("SpawnB", Vector3(68, 0, -10), Vector3(-1, 0, 0))
	side.spawn("SpawnC", Vector3(68, 0, 10), Vector3(-1, 0, 0))
	side.spawn("SpawnD", Vector3(68, 0, 34), Vector3(-1, 0, 0))
	return first
