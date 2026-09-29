extends RefCounted
## ARCHIPELAGO (spread out, about 190 × 200 m, 0 to 34 m up, open sky): islands
## floating in the void round a central spire (GDD §9.3). Falling off is death.
##
## Built for more players and longer rounds, with room for every playstyle:
##   the Spire (the middle island's tower, 34 m): a sniper nest seeing every
##     island, reached by a slow ramp spiral in full view of everyone;
##   the Ridge (east, 16 m): a long high island, the second sniper at its
##     south end, cover along its edge;
##   the Keep (north, 4 m): a building of rooms and doors, the SMG and a
##     shotgun inside, a hole in the roof to drop in by;
##   the Terraces (south, 8/4/0 m): three wide steps facing the Spire, the
##     rifle, mid-range;
##   the Garden (west, -6 m): the low island, a grid of pillars, close-range;
##   four Outposts on the diagonals: small, 10 to 12 m, a gun each.
## The Hub reaches each big island by a long, exposed crossing (the Causeway,
## the South Bridge, the Garden Slide, the Ridge Ramp): the snipers' prey.
## Round the outside, the islands are joined in a ring, each link a
## different skill: ramps, slides, stepping stones (hop, or dash the gaps),
## and a wall-ride fin to ride across a gap with no bridge at all.
## Four spawns (the Keep, the Terraces, the Garden, the Ridge); in a duel,
## the Keep and the Terraces, each about as far from the Spire.

const K := GreyBox.Kind


static func build(kit) -> Transform3D:
	kit.environment.fog_density = 0.0035
	kit.sun.directional_shadow_max_distance = 160.0

	# --- The Hub and the Spire --------------------------------------------------
	kit.terrace("Hub", Vector2(-18, 18), Vector2(-18, 18), 8.0, K.RIDE, 0.0)
	kit.span("Spire", Vector3(-5, 8, -5), Vector3(5, 34, 5), K.TOWER)
	# The spiral: a 33° ramp up each face, a landing at each corner.
	kit.ramp("Spiral1", Vector3(-5, 8, 6.25), Vector3(5, 14.5, 6.25), 2.5, K.RAMP, 0.6)
	kit.span("SpiralLanding1", Vector3(5, 13.9, 5), Vector3(7.5, 14.5, 7.5), K.FLOOR)
	kit.ramp("Spiral2", Vector3(6.25, 14.5, 5), Vector3(6.25, 21, -5), 2.5, K.RAMP, 0.6)
	kit.span("SpiralLanding2", Vector3(5, 20.4, -7.5), Vector3(7.5, 21, -5), K.FLOOR)
	kit.ramp("Spiral3", Vector3(5, 21, -6.25), Vector3(-5, 27.5, -6.25), 2.5, K.RAMP, 0.6)
	kit.span("SpiralLanding3", Vector3(-7.5, 26.9, -7.5), Vector3(-5, 27.5, -5), K.FLOOR)
	kit.ramp("Spiral4", Vector3(-6.25, 27.5, -5), Vector3(-6.25, 34, 5), 2.5, K.RAMP, 0.6)
	kit.span("SpiralTop", Vector3(-7.5, 33.4, 5), Vector3(-2, 34, 7.5), K.FLOOR)
	# The nest: parapets round three sides, open to the spiral.
	kit.span("NestN", Vector3(-5, 34, -5), Vector3(5, 35.2, -4.5), K.LEDGE)
	kit.span("NestE", Vector3(4.5, 34, -4.5), Vector3(5, 35.2, 5), K.LEDGE)
	kit.span("NestS", Vector3(-2, 34, 4.5), Vector3(4.5, 35.2, 5), K.LEDGE)
	for c: Vector2 in [Vector2(-11, -11), Vector2(11, -11), Vector2(-11, 11), Vector2(11, 11)]:
		kit.box("HubBlock_%d_%d" % [c.x, c.y], Vector3(c.x, 9.25, c.y), Vector3(3, 2.5, 3), K.TOWER)

	# --- The Keep (north) ----------------------------------------------------------
	kit.terrace("Keep", Vector2(-22, 22), Vector2(-100, -66), 4.0, K.RIDE, -6.0)
	var y0 := 4.0
	var y1 := 9.0
	for w: Array in [
			["KeepWallS1", Vector3(-12, y0, -74.6), Vector3(-1.5, y1, -74)], ["KeepWallS2", Vector3(1.5, y0, -74.6), Vector3(12, y1, -74)],
			["KeepWallN", Vector3(-12, y0, -92), Vector3(12, y1, -91.4)],
			["KeepWallW1", Vector3(-12, y0, -92), Vector3(-11.4, y1, -84.5)], ["KeepWallW2", Vector3(-12, y0, -81.5), Vector3(-11.4, y1, -74)],
			["KeepWallE1", Vector3(11.4, y0, -92), Vector3(12, y1, -84.5)], ["KeepWallE2", Vector3(11.4, y0, -81.5), Vector3(12, y1, -74)],
			["KeepSplit", Vector3(-0.3, y0, -91.4), Vector3(0.3, y1, -85)],
			["KeepHallW", Vector3(-11.4, y0, -83.3), Vector3(-3, y1, -82.7)], ["KeepHallE", Vector3(3, y0, -83.3), Vector3(11.4, y1, -82.7)]]:
		kit.span(w[0], w[1], w[2], K.WALL)
	var roof_hole: Array[Rect2] = [Rect2(4.5, -89, 3, 3)]
	kit.floor_with_holes("KeepRoof", Rect2(-12, -92, 24, 18), 9.5, 0.5, roof_hole)
	kit.ramp("KeepRoofRamp", Vector3(16.5, 4, -76), Vector3(16.5, 9.5, -88), 3.0, K.RAMP, 0.6)
	kit.span("KeepRoofLanding", Vector3(12, 9, -91), Vector3(18, 9.5, -88), K.FLOOR)
	kit.span("KeepCoverW", Vector3(-20, 4, -80), Vector3(-17, 6, -77), K.LEDGE)
	kit.span("KeepCoverE", Vector3(17, 4, -97), Vector3(20, 6, -94), K.LEDGE)

	# --- The Terraces (south): three steps down away from the Hub -------------------
	kit.terrace("Terrace1", Vector2(-24, 24), Vector2(64, 74), 8.0, K.RIDE, 0.0)
	kit.terrace("Terrace2", Vector2(-24, 24), Vector2(74, 84), 4.0, K.RIDE, -4.0)
	kit.terrace("Terrace3", Vector2(-24, 24), Vector2(84, 96), 0.0, K.RIDE, -6.0)
	kit.span("Grandstand", Vector3(-24, 0, 96), Vector3(24, 8, 97), K.RIDE)
	for c: Array in [["StepCrate2W", -10, 4.0, 74], ["StepCrate2E", 10, 4.0, 74], ["StepCrate3W", -10, 0.0, 84], ["StepCrate3E", 10, 0.0, 84]]:
		kit.span(c[0], Vector3(c[1] - 1, c[2], c[3]), Vector3(c[1] + 1, c[2] + 2, c[3] + 2), K.LEDGE)
	kit.span("Step1WallW", Vector3(-15, 8, 65), Vector3(-9, 9.2, 65.6), K.LEDGE)
	kit.span("Step1WallE", Vector3(9, 8, 65), Vector3(15, 9.2, 65.6), K.LEDGE)
	kit.span("Step2Wall", Vector3(-4, 4, 76), Vector3(4, 5.2, 76.6), K.LEDGE)
	kit.span("Step3WallW", Vector3(-19, 0, 86), Vector3(-13, 1.2, 86.6), K.LEDGE)
	kit.span("Step3WallE", Vector3(13, 0, 86), Vector3(19, 1.2, 86.6), K.LEDGE)

	# --- The Ridge (east) --------------------------------------------------------------
	kit.terrace("Ridge", Vector2(74, 88), Vector2(-40, 40), 16.0, K.RIDE, 8.0)
	for z in [-30, -12, 18, 26]:
		kit.span("RidgeCover_%d" % z, Vector3(74, 16, z - 2), Vector3(75.5, 17.6, z + 2), K.LEDGE)
	for c: Vector2 in [Vector2(76, -40), Vector2(85, -40), Vector2(76, -34), Vector2(85, -34)]:
		kit.span("HidePost_%d_%d" % [c.x, c.y], Vector3(c.x, 16, c.y), Vector3(c.x + 1, 19, c.y + 1), K.TOWER)
	kit.span("HideRoof", Vector3(76, 19, -40), Vector3(86, 19.5, -33), K.FLOOR)

	# --- The Garden (west) ---------------------------------------------------------------
	kit.terrace("Garden", Vector2(-104, -60), Vector2(-22, 22), -6.0, K.RIDE, -12.0)
	for gx in [-96, -84, -72]:
		for gz in [-12, 0, 12]:
			if gx == -84 and gz == 0:
				continue
			kit.span("GardenPillar_%d_%d" % [gx, gz], Vector3(gx - 0.75, -6, gz - 0.75), Vector3(gx + 0.75, -1, gz + 0.75), K.TOWER)

	# --- The Outposts ----------------------------------------------------------------------
	for o: Array in [["NE", Vector2(50, -50), 12.0], ["NW", Vector2(-50, -50), 10.0], ["SE", Vector2(44, 52), 10.0], ["SW", Vector2(-50, 50), 12.0]]:
		var c: Vector2 = o[1]
		kit.terrace("Outpost" + o[0], Vector2(c.x - 5, c.x + 5), Vector2(c.y - 5, c.y + 5), o[2], K.RIDE, o[2] - 4.0)
		kit.span("OutpostWall" + o[0], Vector3(c.x - 2, o[2], c.y - 0.3), Vector3(c.x + 2, o[2] + 1.2, c.y + 0.3), K.LEDGE)

	# --- Spokes: the long crossings from the Hub ---------------------------------------------
	kit.ramp("Causeway", Vector3(0, 4, -66), Vector3(0, 8, -18), 3.0, K.FLOOR, 0.6)
	_on_slope(kit, "CausewayCover1", Vector3(-0.75, 0, -34), Vector3(0, 4, -66), Vector3(0, 8, -18))
	_on_slope(kit, "CausewayCover2", Vector3(0.75, 0, -50), Vector3(0, 4, -66), Vector3(0, 8, -18))
	kit.span("SouthBridge", Vector3(-1.5, 7.5, 18), Vector3(1.5, 8, 64), K.FLOOR)
	kit.span("SouthBridgeCover1", Vector3(0, 8, 33), Vector3(1.5, 9.2, 34.5), K.LEDGE)
	kit.span("SouthBridgeCover2", Vector3(-1.5, 8, 47.5), Vector3(0, 9.2, 49), K.LEDGE)
	kit.ramp("GardenSlide", Vector3(-60, -6, 0), Vector3(-18, 8, 0), 6.0, K.RAMP, 0.6)
	kit.ramp("RidgeRamp", Vector3(18, 8, 8), Vector3(74, 16, 8), 3.0, K.FLOOR, 0.6)

	# --- The ring: a different link between each pair of neighbours ---------------------------
	kit.ramp("KeepToNE", Vector3(22, 4, -72), Vector3(45, 12, -52), 3.0, K.FLOOR, 0.6)
	_stones(kit, "NEToRidge", Vector3(55, 12, -48), Vector3(74, 16, -36), 4)
	kit.ramp("RidgeToSE", Vector3(49, 10, 52), Vector3(74, 16, 34), 3.0, K.RAMP, 0.6)
	_fin(kit, "SEToTerraces", Vector3(39, 10, 56), Vector3(24, 8, 68), 1.8)
	kit.ramp("TerracesToSW", Vector3(-24, 8, 68), Vector3(-45, 12, 52), 3.0, K.FLOOR, 0.6)
	_stones(kit, "SWToGarden", Vector3(-55, 12, 48), Vector3(-72, -6, 22), 5)
	kit.ramp("GardenToNW", Vector3(-72, -6, -22), Vector3(-50, 10, -45), 3.0, K.RAMP, 0.6)
	_stones(kit, "NWToKeep", Vector3(-45, 10, -52), Vector3(-22, 4, -70), 5)

	# --- Weapons ----------------------------------------------------------------------------------
	kit.pad("Pad_SniperSpire", Weapons.SNIPER, Vector3(0, 34, 0), 0.0)
	kit.pad("Pad_SniperRidge", Weapons.SNIPER, Vector3(81, 16, 36), 0.0)
	kit.pad("Pad_RifleTerraces", Weapons.RIFLE, Vector3(8, 4, 80))
	kit.pad("Pad_RifleNW", Weapons.RIFLE, Vector3(-50, 10, -52))
	kit.pad("Pad_SMGKeep", Weapons.SMG, Vector3(0, 4, -78))
	kit.pad("Pad_SMGSW", Weapons.SMG, Vector3(-50, 12, 52))
	kit.pad("Pad_ShotgunKeep", Weapons.SHOTGUN, Vector3(-6, 4, -88))
	kit.pad("Pad_ShotgunGarden", Weapons.SHOTGUN, Vector3(-84, -6, 0))
	kit.pad("Pad_RevolverNE", Weapons.REVOLVER, Vector3(50, 12, -52))
	kit.pad("Pad_RevolverSE", Weapons.REVOLVER, Vector3(44, 10, 54))
	kit.pad("Pad_PistolKeep", Weapons.PISTOL, Vector3(-14, 4, -68.5))
	kit.pad("Pad_PistolTerraces", Weapons.PISTOL, Vector3(0, 0, 91))
	kit.pad("Pad_PistolGarden", Weapons.PISTOL, Vector3(-100, -6, 5))
	kit.pad("Pad_PistolRidge", Weapons.PISTOL, Vector3(84, 16, -24))

	kit.light("KeepHall", Vector3(0, 7.5, -78), Color(1.0, 0.7, 0.3), 10.0)
	kit.light("KeepNW", Vector3(-6, 7.5, -88), Color(1.0, 0.4, 0.6), 8.0)
	kit.light("KeepNE", Vector3(6, 7.5, -88), Color(0.3, 0.85, 1.0), 8.0)
	kit.light("GardenGlow", Vector3(-84, -2, 0), Color(0.6, 0.4, 1.0), 16.0)

	kit.label("SPIRE", Vector3(0, 38, 0))
	kit.label("KEEP", Vector3(0, 13, -83))
	kit.label("TERRACES", Vector3(0, 12, 80))
	kit.label("RIDGE", Vector3(81, 21, 0))
	kit.label("GARDEN", Vector3(-82, 0, 0))
	kit.label("FIN (ride it)", Vector3(31.5, 14, 62))

	var a: Transform3D = kit.spawn("SpawnA", Vector3(-17, 4, -69), Vector3(0, 0, 1))
	kit.spawn("SpawnB", Vector3(4, 0, 92), Vector3(0, 0, -1))
	kit.spawn("SpawnC", Vector3(-100, -6, -6), Vector3(1, 0, 0))
	kit.spawn("SpawnD", Vector3(81, 16, -20), Vector3(-1, 0, 0))
	return a


## A 1.2 m cover block standing on a ramp from `bottom` to `top`, at `at`
## (x, z; its height is found on the ramp).
static func _on_slope(kit, block_name: String, at: Vector3, bottom: Vector3, top: Vector3) -> void:
	var t := clampf((at.z - bottom.z) / (top.z - bottom.z), 0.0, 1.0)
	var y := lerpf(bottom.y, top.y, t)
	kit.span(block_name, Vector3(at.x - 0.75, y - 0.4, at.z - 0.75), Vector3(at.x + 0.75, y + 1.2, at.z + 0.75), K.LEDGE)


## `count` stepping stones (2.5 m square) evenly between `from` and `to`, their
## tops stepping from one height to the other: hop them, or dash the gaps.
static func _stones(kit, stones_name: String, from: Vector3, to: Vector3, count: int) -> void:
	for i in count:
		var p := from.lerp(to, float(i + 1) / (count + 1))
		kit.span("%s_%d" % [stones_name, i], Vector3(p.x - 1.25, p.y - 3.0, p.z - 1.25), Vector3(p.x + 1.25, p.y, p.z + 1.25), K.LEDGE)


## A wall-ride fin across the gap from `from` to `to`, too far to jump: a 6 m
## tall ride wall floating alongside the line (`offset` to its right), over
## its middle 60 %. Angle in before the jump (air control can't), ride it,
## kick off toward the far side.
static func _fin(kit, fin_name: String, from: Vector3, to: Vector3, offset: float) -> void:
	var along := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var dir := along.normalized()
	var right := dir.cross(Vector3.UP)
	var mid := (from + to) * 0.5 + right * offset
	var length := along.length() * 0.6
	var b: StaticBody3D = kit.box(fin_name, Vector3(mid.x, minf(from.y, to.y) + 1.0, mid.z), Vector3(0.6, 6.0, length), K.RIDE)
	b.rotation.y = atan2(dir.x, dir.z)
