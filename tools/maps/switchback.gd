extends RefCounted
## SWITCHBACK (large, 64 × 40 m, winding): four levels stepping down a hill,
## joined end to end by hairpin ramps (GDD §9.3).
##
## The road: level 1 (the Summit, 12 m) runs east, a 22° ramp drops to level
## 2 (8 m) running west, another to level 3 (4 m) running east, another to
## level 4 (the Bottom, 0 m) running west. Each level's south edge is a 4 m
## drop onto the next, so from any level you look down on (and shoot down
## at) everything below it, and anyone below can look up at you.
##
## Down is easy: drop off any edge, slide the hairpins, or smash onto someone
## below and bounce back up (a 4 m smashdown bounces you about 3.6 m, enough
## to grab the edge you came from). Up is the question:
##   the hairpin ramps: the long way round, but you keep your speed;
##   the Ladder: a crate against each cliff, staggered up the middle
##     (jump onto it, jump and grab the level above); the short way, in the open;
##   the huts: one on each lower level, blocking its sightline. Slide through
##     the tunnel, or climb onto the roof and grab the level above from there.
## The sniper waits on the Overlook, a step on the Summit's edge above the
## Ladder's last crate, seeing the whole hill. Spawn A is at the east end of
## level 3, spawn B at the west end of level 2; both are about five and a
## half seconds from it, by different climbs.

const K := GreyBox.Kind
## Level heights and their z bands (north to south).
const LEVELS := [[12.0, Vector2(-28, -18)], [8.0, Vector2(-18, -8)], [4.0, Vector2(-8, 2)], [0.0, Vector2(2, 12)]]


static func build(kit) -> Transform3D:
	kit.box("Ground", Vector3(0, -0.5, -8), Vector3(66, 1, 42), K.FLOOR)
	kit.box("Boundary_N", Vector3(0, 9, -28.5), Vector3(66, 18, 1), K.WALL)
	kit.box("Boundary_S", Vector3(0, 4, 12.5), Vector3(66, 8, 1), K.WALL)
	kit.box("Boundary_W", Vector3(-32.5, 9, -8), Vector3(1, 18, 42), K.WALL)
	kit.box("Boundary_E", Vector3(32.5, 9, -8), Vector3(1, 18, 42), K.WALL)

	# The levels, with a landing at the top of each hairpin (the level above
	# reaching round the corner) and the ramp down from it (22°).
	kit.terrace("Summit", Vector2(-32, 32), Vector2(-28, -18), 12.0)
	kit.terrace("Landing1", Vector2(28, 32), Vector2(-18, -8), 12.0)
	kit.span("UnderHairpin1", Vector3(18, 0, -18), Vector3(28, 8, -8), K.RIDE)
	kit.ramp("Hairpin1", Vector3(18, 8, -13), Vector3(28, 12, -13), 10.0, K.RAMP, 5.0)
	kit.terrace("Level2", Vector2(-32, 18), Vector2(-18, -8), 8.0)
	kit.terrace("Landing2", Vector2(-32, -28), Vector2(-8, 2), 8.0)
	kit.span("UnderHairpin2", Vector3(-28, 0, -8), Vector3(-18, 4, 2), K.RIDE)
	kit.ramp("Hairpin2", Vector3(-18, 4, -3), Vector3(-28, 8, -3), 10.0, K.RAMP, 5.0)
	kit.terrace("Level3", Vector2(-18, 32), Vector2(-8, 2), 4.0)
	kit.terrace("Landing3", Vector2(28, 32), Vector2(2, 12), 4.0)
	kit.ramp("Hairpin3", Vector3(18, 0, 7), Vector3(28, 4, 7), 10.0, K.RAMP, 5.0)

	# The Ladder: a 2 m crate against each cliff, staggered up the middle.
	kit.span("Ladder4", Vector3(-7, 0, 2), Vector3(-5, 2, 4), K.LEDGE)
	kit.span("Ladder3", Vector3(-1, 4, -8), Vector3(1, 6, -6), K.LEDGE)
	kit.span("Ladder2", Vector3(5, 8, -18), Vector3(7, 10, -16), K.LEDGE)

	# Huts across the lower levels: each blocks its level's sightline, has a
	# 1.2 m tunnel through it to slide, and a roof to climb up from.
	_hut(kit, "Hut2", -12, 8.0, Vector2(-18, -8))
	_hut(kit, "Hut3", 8, 4.0, Vector2(-8, 2))
	_hut(kit, "Hut4", -12, 0.0, Vector2(2, 12))

	# The Summit: the Overlook (a 1.5 m step just back from the edge, above
	# the Ladder's top, leaving a lip to climb onto) and two blocks breaking
	# up its length.
	kit.span("Overlook", Vector3(3, 12, -22), Vector3(9, 13.5, -19.2), K.LEDGE)
	kit.span("SummitBlockW", Vector3(-17, 12, -27), Vector3(-13, 15, -23), K.TOWER)
	kit.span("SummitBlockE", Vector3(13, 12, -27), Vector3(17, 15, -23), K.TOWER)
	# Low walls along the edges: cover from below.
	kit.span("EdgeWall1W", Vector3(-9, 12, -18.6), Vector3(-6, 13.2, -18), K.LEDGE)
	kit.span("EdgeWall1E", Vector3(12, 12, -18.6), Vector3(15, 13.2, -18), K.LEDGE)
	kit.span("EdgeWall2", Vector3(4, 8, -8.6), Vector3(8, 9.2, -8), K.LEDGE)
	kit.span("EdgeWall3", Vector3(18, 4, 1.4), Vector3(22, 5.2, 2), K.LEDGE)

	kit.pad("Pad_Sniper", Weapons.SNIPER, Vector3(6, 13.5, -20), 0.0)
	kit.pad("Pad_Revolver", Weapons.REVOLVER, Vector3(24, 12, -23))
	kit.pad("Pad_SMG", Weapons.SMG, Vector3(0, 8, -13))
	kit.pad("Pad_Rifle", Weapons.RIFLE, Vector3(-4, 4, -3))
	kit.pad("Pad_Shotgun", Weapons.SHOTGUN, Vector3(-26, 0, 7))
	kit.pad("Pad_PistolA", Weapons.PISTOL, Vector3(22, 4, -6))
	kit.pad("Pad_PistolB", Weapons.PISTOL, Vector3(-22, 8, -10))

	kit.light("Hairpin1Glow", Vector3(26, 11, -13), Color(1.0, 0.4, 0.6), 12.0)
	kit.light("Hairpin2Glow", Vector3(-26, 7, -3), Color(0.3, 0.85, 1.0), 12.0)
	kit.light("Hairpin3Glow", Vector3(26, 3, 7), Color(1.0, 0.7, 0.3), 12.0)
	kit.light("BottomWest", Vector3(-24, 3, 7), Color(0.6, 0.4, 1.0), 10.0)

	kit.label("OVERLOOK", Vector3(6, 16.5, -20))
	kit.label("LADDER", Vector3(0, 8, -6))
	for i in 3:
		kit.label("HAIRPIN", [Vector3(24, 15, -13), Vector3(-24, 11, -3), Vector3(24, 7, 7)][i])

	var a: Transform3D = kit.spawn("SpawnA", Vector3(26, 4, -3), Vector3(-1, 0, 0))
	kit.spawn("SpawnB", Vector3(-26, 8, -13), Vector3(1, 0, 0))
	# Two more for a four-way free-for-all: the Bottom and the Summit.
	kit.spawn("SpawnC", Vector3(0, 0, 9), Vector3(-1, 0, 0))
	kit.spawn("SpawnD", Vector3(28, 12, -25), Vector3(-1, 0, 0))
	return a


## A hut 4 m wide filling a level's depth, 2.6 m tall, with a 3 m wide,
## 1.2 m tall tunnel through it along the level.
static func _hut(kit, hut_name: String, x: float, floor_y: float, band: Vector2) -> void:
	var mid := (band.x + band.y) * 0.5
	kit.span(hut_name + "_N", Vector3(x - 2, floor_y, band.x), Vector3(x + 2, floor_y + 2.6, mid - 1.5), K.TOWER)
	kit.span(hut_name + "_S", Vector3(x - 2, floor_y, mid + 1.5), Vector3(x + 2, floor_y + 2.6, band.y), K.TOWER)
	kit.span(hut_name + "_Roof", Vector3(x - 2, floor_y + 1.2, mid - 1.5), Vector3(x + 2, floor_y + 2.6, mid + 1.5), K.TOWER)
