extends RefCounted
## TERRACE (medium, 48 × 36 m, asymmetric): a low town against a high
## terrace (GDD §9.3).
##
## West: the Town, dense blocks and streets at ground level, short sightlines,
## the SMG, the shotgun and the revolver. East: the Terrace, an open plateau
## 4 m up with long sightlines and the rifle. Between them, the Peninsula
## sticks out of the terrace into the town with the Pulpit on its tip (+2 m)
## and the sniper on the Pulpit: it sees down the town's long street and
## across the whole terrace, and both are shooting at it.
##
## Ways between the two, from fast-and-open to slow-and-hidden:
##   the Slide (20° ramp, south): the terrace's fast way into town.
##   the Overpass (north): a bridge from the terrace to the flat roof of
##     Block A, over the square. Exposed; smash off it into the square.
##   the Stairs (30° ramp, north-west): the slow, readable way up.
##   the Peninsula crates (north side from the square, south side from the
##     Alley): jump-climb onto the peninsula, then the Pulpit.
##   the Alley: a 2.5 m gap between the cliff and Block C. Wall-jump up it
##     onto the terrace, the skill way up that no one sees coming.
## Spawn A is in the town's north-west corner, spawn B on the terrace's
## south-east; both are about four seconds from the Pulpit.

const K := GreyBox.Kind
const TOP := 4.0


static func build(kit) -> Transform3D:
	kit.box("Ground", Vector3(0, -0.5, 0), Vector3(50, 1, 38), K.FLOOR)
	for w: Array in [["N", Vector3(0, 4.5, -18.5), Vector3(50, 9, 1)], ["S", Vector3(0, 4.5, 18.5), Vector3(50, 9, 1)],
			["W", Vector3(-24.5, 4.5, 0), Vector3(1, 9, 36)], ["E", Vector3(24.5, 4.5, 0), Vector3(1, 9, 36)]]:
		kit.box("Boundary_" + w[0], w[1], w[2], K.WALL)

	# The terrace and the peninsula; their cliffs are ride tiles.
	kit.terrace("Terrace", Vector2(2, 24), Vector2(-18, 18), TOP)
	kit.terrace("Peninsula", Vector2(-4, 2), Vector2(-3, 3), TOP)
	kit.span("Pulpit", Vector3(-4, TOP, -2), Vector3(-1, TOP + 2, 2), K.TOWER)
	kit.span("PeninsulaCrateN", Vector3(-3, 0, -5), Vector3(-1, 2, -3), K.LEDGE)
	kit.span("PeninsulaCrateS", Vector3(-0.25, 0, 3), Vector3(1.75, 2, 5), K.LEDGE)

	# Terrace cover: the shed in the middle, low walls either side of the
	# peninsula's root to watch the pulpit from, a raised corner in the north-east.
	kit.span("Shed", Vector3(10, TOP, -3), Vector3(14, TOP + 3, 3), K.TOWER)
	kit.span("LowWallN", Vector3(5, TOP, -6.5), Vector3(5.6, TOP + 1.2, -3.5), K.LEDGE)
	kit.span("LowWallS", Vector3(5, TOP, 3.5), Vector3(5.6, TOP + 1.2, 6.5), K.LEDGE)
	kit.span("Corner", Vector3(18, TOP, -18), Vector3(24, TOP + 1.5, -13), K.LEDGE)

	# The town. Block A's roof is flat at terrace height, joined to it by the overpass.
	kit.terrace("BlockA", Vector2(-20, -11), Vector2(-12, -5), TOP, K.WALL)
	kit.span("Overpass", Vector3(-11, TOP - 0.5, -10), Vector3(2, TOP, -7), K.FLOOR)
	kit.span("BlockACrate", Vector3(-22, 0, -9), Vector3(-20, 2, -7), K.LEDGE)
	kit.span("BlockB", Vector3(-20, 0, 5), Vector3(-11, 7, 11), K.WALL)
	kit.span("BlockC", Vector3(-8, 0, 5), Vector3(-0.5, 6, 11), K.RIDE)
	# The long street's cover: a kiosk on the approach to the peninsula, and
	# the pocket where the shotgun sits, tucked behind a low wall.
	kit.span("Kiosk", Vector3(-9, 0, 0), Vector3(-7, 2.5, 2), K.TOWER)
	kit.span("PocketWall", Vector3(-16.5, 0, -2.8), Vector3(-13.5, 1.2, -2.2), K.LEDGE)

	# Both ramps run along the boundary, so nothing hides beside them.
	kit.ramp("Slide", Vector3(-9, 0, 16.5), Vector3(2, TOP, 16.5), 3.0, K.RAMP, 3.0)
	kit.ramp("Stairs", Vector3(-4.93, 0, -16.5), Vector3(2, TOP, -16.5), 3.0, K.RAMP, 3.0)

	kit.pad("Pad_Sniper", Weapons.SNIPER, Vector3(-2.5, TOP + 2, 0), 0.0)
	kit.pad("Pad_SMG", Weapons.SMG, Vector3(-7, 0, -8.5))
	kit.pad("Pad_Shotgun", Weapons.SHOTGUN, Vector3(-15, 0, -4))
	kit.pad("Pad_Revolver", Weapons.REVOLVER, Vector3(-15.5, TOP, -8.5))
	kit.pad("Pad_Rifle", Weapons.RIFLE, Vector3(12, TOP, -10))
	kit.pad("Pad_PistolA", Weapons.PISTOL, Vector3(-21.5, 0, -11.5))
	kit.pad("Pad_PistolB", Weapons.PISTOL, Vector3(21.5, TOP, 11))

	kit.light("UnderOverpass", Vector3(-5, 2.8, -8.5), Color(1.0, 0.7, 0.3), 9.0)
	kit.light("Alley", Vector3(0.75, 3.0, 8), Color(0.3, 0.85, 1.0), 8.0)
	kit.light("Pocket", Vector3(-15, 2.5, -3.5), Color(1.0, 0.4, 0.6), 7.0)
	kit.light("SlideFoot", Vector3(-10, 2.5, 13), Color(0.6, 0.4, 1.0), 9.0)

	kit.label("PULPIT", Vector3(-2.5, 8.5, 0))
	kit.label("OVERPASS", Vector3(-4.5, 6, -8.5))
	kit.label("SLIDE", Vector3(-3, 5, 16.5))
	kit.label("ALLEY (wall-jump up)", Vector3(0.75, 7.5, 8))
	kit.label("STAIRS", Vector3(-1.5, 5, -16.5))

	var a: Transform3D = kit.spawn("SpawnA", Vector3(-21.5, 0, -15.5), Vector3(1, 0, 0.5))
	kit.spawn("SpawnB", Vector3(21.5, TOP, 15.5), Vector3(-1, 0, -0.5))
	return a
