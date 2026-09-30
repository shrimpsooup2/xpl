extends RefCounted
## BOULEVARD, dressed (GDD §9.3): Rimehollow, a village in an ice cave.
##
## The village stands on a shelf of old ice in the middle of a great cave
## in a glacier, a crevasse all round it; past the crevasse the cave's
## floor runs out to its walls, jagged, round in plan, and up into a vault
## of ice forty-odd metres up, a dim blue with the daylight coming through
## it, a hint of violet in its depths. Icicles hang from the vault; columns,
## spikes and crystals of ice stand about the floor. The village keeps warm
## under it, lit by its own strings of bulbs slung everywhere, lanterns and
## fires. The gameplay blocks are untouched, only dressed.

const DecoKit := preload("res://tools/deco_kit.gd")
const LevelKit := preload("res://tools/level_kit.gd")
const Signs := preload("res://tools/sign_kit.gd")
const BOTH := DecoKit.LAYER_BOTH
## The cave is drawn on a layer of its own, which the village's lamps
## don't light: they couldn't reach it, and a lamp that tried would take
## one of the sixteen each thing can be lit by (the ice glows by itself).
const CAVE_LAYER := 8

const GLOW := "res://src/render/deco/glow.gdshader"
const ICE := "res://src/render/deco/ice.gdshader"
const FLAME := "res://src/render/deco/flame.gdshader"
const POOL := "res://src/render/deco/light_pool.gdshader"
const WARM := Color(1.0, 0.72, 0.42)
## The strings of bulbs' light: yellower.
const BULB := Color(1.0, 0.8, 0.5)
const SERIF := "DejaVuSerif-Bold.ttf"
const ITALIC := "LiberationSerif-BoldItalic.ttf"

## The Arcade's houses along the street (the east half's; the west's are
## the same, mirrored): where one ends and the next begins, and each one's
## plaster and paint.
const HOUSES := [16.0, 23.5, 29.2, 35.2, 41.5, 46.5, 56.0]
const PLASTER := [Color(0.98, 0.9, 0.74), Color(0.94, 0.7, 0.46), Color(0.88, 0.66, 0.64), Color(0.76, 0.84, 0.7),
		Color(0.74, 0.8, 0.9), Color(0.98, 0.84, 0.54)]
const PAINT := [Color(0.62, 0.16, 0.12), Color(0.16, 0.34, 0.24), Color(0.18, 0.28, 0.52), Color(0.66, 0.46, 0.12),
		Color(0.48, 0.18, 0.32), Color(0.14, 0.38, 0.42)]
## The Arcade's front's openings (boulevard.gd), [along from x = 16, up,
## wide, high].
const DOORS := [[4.0, 0.0, 2.4, 3.0], [16.0, 0.0, 2.4, 3.0], [33.0, 0.0, 2.4, 3.0]]
const WINDOWS := [[9.0, 1.2, 3.0, 1.2], [22.0, 1.2, 3.0, 1.2], [2.0, 6.1, 3.0, 1.2], [8.0, 6.1, 3.0, 1.2], [14.0, 6.1, 3.0, 1.2],
		[20.0, 6.1, 3.0, 1.2], [26.0, 6.1, 3.0, 1.2], [32.0, 6.1, 3.0, 1.2]]
## What the houses are, door by door.
const TRADES := ["The Warm Kettle", "Bakery", "Skates Mended"]

## The shelf the village stands on: the play area, where the boundary is.
const WEST := -72.0
const EAST := 72.0
const NORTH := -34.0
const SOUTH := 38.0
## The cave round it: its middle, and the half-widths of its walls.
const MIDDLE := Vector2(0.0, 2.0)
const CAVE := Vector2(122.0, 74.0)
static func dress(kit, d) -> void:
	_light(kit)
	_materials(d)
	_surfaces(kit, d)
	_cave(d)
	_formations(d)
	_icicles(d)
	_edges(d)
	_indoors(kit)
	# Each part of each half in meshes of its own, so each is lit by its
	# own lamps.
	for side: float in [-1.0, 1.0]:
		var half := "West" if side < 0.0 else "East"
		d.zone = half + "Arcade"
		_arcade(kit, d, side)
		_tower(kit, d, side)
		d.zone = half + "Kiosks"
		_kiosks(kit, d, side)
		d.zone = half + "Street"
		_sleds(d, side)
		_festoons(kit, d, side)
		d.zone = half + "Yard"
		_gate(kit, d, side)
		_yard(kit, d, side)
		d.zone = half + "Canal"
		_street_lamps(kit, d, side)
		_canal(kit, d, side)
	d.zone = "Middle"
	_hall(kit, d)
	_plaza(kit, d)
	_middle_strings(kit, d)
	d.zone = ""
	_floors(d)
	_ground_tiles(d)
	_drifts(d)
	_eave_icicles(d)


# --- Light -------------------------------------------------------------------------------

## Under the ice: the daylight comes through the vault, blue, all round;
## the air is a blue haze. The village's own lamps are warm against it.
static func _light(kit) -> void:
	var e: Environment = kit.environment
	var sky: ShaderMaterial = e.sky.sky_material
	# Never seen (the vault is closed).
	sky.set_shader_parameter(&"top_color", Color(0.78, 0.86, 0.96))
	sky.set_shader_parameter(&"upper_color", Color(0.86, 0.92, 0.98))
	sky.set_shader_parameter(&"horizon_color", Color(0.94, 0.97, 1.0))
	sky.set_shader_parameter(&"ground_color", Color(0.8, 0.86, 0.92))
	sky.set_shader_parameter(&"halo", 0.0)
	sky.set_shader_parameter(&"sun_size", 0.0)
	# The ice's light only a little, cold, all round: the village's light is
	# its own lamps'.
	e.ambient_light_color = Color(0.36, 0.46, 0.66)
	e.ambient_light_energy = 0.24
	e.fog_light_color = Color(0.12, 0.18, 0.28)
	e.fog_density = 0.007
	e.fog_sky_affect = 0.0
	e.glow_intensity = 1.0
	e.glow_hdr_threshold = 0.9
	e.glow_bloom = 0.0
	# No sun in here: the light is the ice's own, and the village's lamps.
	var sun: DirectionalLight3D = kit.sun
	sun.light_energy = 0.0
	sun.shadow_enabled = false
	sun.visible = false


# --- Materials ---------------------------------------------------------------------------

static func _materials(d) -> void:
	d.reflection = load("res://assets/textures/boulevard/reflection_ice.png")
	var ice := {"ice": "boulevard/ice.png", "scallops": "boulevard/ice_scallops.png", "inner": "boulevard/ice_inner.png",
			"reflection_map": "boulevard/reflection_ice.png", "glow_heights": Vector2(-10.0, 44.0)}
	# The cave: big scallops, lit through.
	d.shaded("cave_ice", ICE, ice.merged({"meters": 4.0, "inner_meters": 6.0, "glow": 0.4, "depth": 1.2}))
	# Icicles, spikes, columns: small scallops, thin, bright.
	d.shaded("icicle", ICE, ice.merged({"meters": 1.5, "inner_meters": 1.6, "bump": 0.6, "glow": 0.55, "depth": 0.3,
			"glow_low": 0.8, "tint": Color(1.1, 1.15, 1.15)}))
	# The frozen canal: polished, deep, bubbles far down.
	d.shaded("canal_ice", ICE, ice.merged({"meters": 5.0, "inner_meters": 3.0, "bump": 0.12, "glow": 0.3, "depth": 2.4,
			"inside": 1.4, "glow_low": 1.0, "gloss": 0.8, "roughness_value": 0.08, "albedo_amount": 0.25}))
	# The village.
	var weathered := {"gloss": 0.04, "grazing": 0.25, "roughness": 0.8, "specular": 0.2}
	d.surface("street", weathered.merged({"side": "boulevard/quay", "meters": 4.0, "top": "boulevard/cobbles", "top_meters": 2.5}))
	d.surface("walkway", weathered.merged({"side": "boulevard/quay", "meters": 4.0, "top": "boulevard/boardwalk", "top_meters": 2.0}))
	d.surface("plaster", weathered.merged({"side": "boulevard/plaster", "meters": 4.0, "top": "boulevard/snow", "top_meters": 4.0,
			"bottom": "boulevard/planks", "bottom_meters": 2.0}))
	d.surface("roof", weathered.merged({"side": "boulevard/timber", "meters": 1.0, "top": "boulevard/snow", "top_meters": 4.0,
			"bottom": "boulevard/planks", "bottom_meters": 2.0}))
	d.surface("boards", weathered.merged({"side": "boulevard/timber", "meters": 1.0, "top": "boulevard/planks", "top_meters": 2.0,
			"bottom": "boulevard/planks", "bottom_meters": 2.0}))
	d.surface("bridge", weathered.merged({"side": "boulevard/timber", "meters": 1.0, "top": "boulevard/boardwalk", "top_meters": 2.0,
			"bottom": "boulevard/timber", "bottom_meters": 1.0}))
	d.surface("ramp_boards", weathered.merged({"side": "boulevard/logs", "meters": 2.0, "top": "boulevard/boardwalk", "top_meters": 2.0}))
	d.surface("stone", weathered.merged({"side": "boulevard/stone", "meters": 2.0, "top": "boulevard/snow", "top_meters": 4.0}))
	d.surface("logs", weathered.merged({"side": "boulevard/logs", "meters": 2.0, "top": "boulevard/snow", "top_meters": 4.0,
			"bottom": "boulevard/planks", "bottom_meters": 2.0}))
	d.surface("timber", weathered.merged({"side": "boulevard/timber", "meters": 1.0, "top": "boulevard/snow", "top_meters": 4.0}))
	d.surface("crate", weathered.merged({"side": "boulevard/planks", "meters": 1.5, "top": "boulevard/planks", "top_meters": 1.5}))
	d.surface("canvas", weathered.merged({"side": "boulevard/canvas", "meters": 2.0, "top": "boulevard/canvas", "top_meters": 2.0}))
	d.surface("firewood", weathered.merged({"side": "boulevard/firewood", "meters": 1.0, "top": "boulevard/snow", "top_meters": 4.0}))
	d.surface("snow_cap", weathered.merged({"side": "boulevard/snow", "meters": 4.0, "top": "boulevard/snow", "top_meters": 4.0,
			"tint": Color(0.84, 0.86, 0.9), "top_tint": Color(0.84, 0.86, 0.9)}))
	for i in PLASTER.size():
		d.surface("plaster_%d" % i, weathered.merged({"side": "boulevard/plaster", "meters": 4.0, "tint": PLASTER[i]}))
		d.surface("paint_%d" % i, weathered.merged({"side": "boulevard/plaster", "meters": 1.0, "tint": PAINT[i] * 1.2}))
	d.surface("shingle_roof", weathered.merged({"side": "boulevard/shingles", "meters": 2.0, "uv": true}))
	d.surface("wood", weathered.merged({"side": "boulevard/timber", "meters": 1.0}))
	d.surface("board", weathered.merged({"side": "boulevard/planks", "meters": 1.0, "tint": Color(0.5, 0.4, 0.34)}))
	d.surface("dark_metal", {"side": "stack/steel", "meters": 1.0, "tint": Color(0.2, 0.19, 0.18), "gloss": 0.25, "grazing": 0.5,
			"roughness": 0.4})
	d.surface("brass", {"side": "stack/steel", "meters": 1.0, "tint": Color(0.9, 0.66, 0.3), "gloss": 0.5, "grazing": 0.7,
			"roughness": 0.3})
	d.surface("black", {"side": "stack/steel", "meters": 1.0, "tint": Color(0.02, 0.02, 0.02), "gloss": 0.0, "grazing": 0.05})
	d.surface("evergreen", weathered.merged({"side": "terrace/foliage", "meters": 1.0, "tint": Color(0.8, 1.0, 0.85)}))
	d.shaded("lamp_warm", GLOW, {"color": Color(1.0, 0.72, 0.38), "energy": 3.6})
	d.shaded("bulb", GLOW, {"color": Color(1.0, 0.76, 0.42), "energy": 4.0})
	d.surface("white_wax", {"side": "boulevard/snow", "meters": 1.0, "tint": Color(1.0, 0.94, 0.82), "gloss": 0.1, "grazing": 0.3})
	d.surface("floorboards", {"side": "boulevard/planks", "meters": 2.0, "top": "boulevard/planks", "top_meters": 2.0, "gloss": 0.12,
			"grazing": 0.4, "roughness": 0.5})
	d.surface("rug", {"side": "boulevard/canvas", "meters": 1.0, "tint": Color(1.8, 0.5, 0.4), "gloss": 0.0, "grazing": 0.1})
	d.surface("red_cloth", {"side": "boulevard/canvas", "meters": 1.0, "tint": Color(2.2, 0.45, 0.4), "gloss": 0.02, "grazing": 0.2})
	d.surface("blue_cloth", {"side": "boulevard/canvas", "meters": 1.0, "tint": Color(0.5, 0.8, 2.4), "gloss": 0.02, "grazing": 0.2})
	d.surface("gold_cloth", {"side": "boulevard/canvas", "meters": 1.0, "tint": Color(2.4, 2.0, 0.8), "gloss": 0.02, "grazing": 0.2})
	d.shaded("window_warm", GLOW, {"color": Color(1.0, 0.64, 0.32), "energy": 1.5})
	d.shaded("flame", FLAME, {"size": Vector2(0.5, 0.8)})
	d.shaded("flame_small", FLAME, {"size": Vector2(0.16, 0.26), "energy": 2.6})


## Each block's surface, by its name (without the team's tag or its
## piece number).
const DRESS := {
	"Ground": "street", "GroundFloor": "street", "Walkway": "walkway", "WalkwayFloor": "walkway", "CanalBed": "canal_ice",
	"CanalBedFloor": "canal_ice", "YardCanalEnd": "street", "YardCanalEndFloor": "street", "CanalRamp": "street",
	"AtriumFront": "plaster", "AtriumPillar": "timber", "Balcony": "boards", "Landing": "boards", "LandingRail": "timber",
	"AtriumRailing": "timber", "AtriumRoof": "roof", "AtriumParapet": "timber", "RoofParapet": "timber", "TowerParapetS": "timber",
	"TowerParapetW": "timber", "Planter": "stone", "BasinN": "stone", "BasinS": "stone", "BasinW": "stone", "BasinE": "stone",
	"Plinth": "stone", "MidBridge": "bridge", "Bridge": "bridge", "ArcadeFront": "plaster", "ArcadeEnd": "plaster",
	"ArcadeMid": "plaster", "ArcadeWall1": "plaster", "ArcadeWall2": "plaster", "ArcadeStair": "boards", "AtriumStair": "boards",
	"TowerStair": "boards", "ArcadeUpper": "boards", "GalleryCover1": "crate", "GalleryCover2": "crate", "ArcadeRoof": "roof",
	"Tower": "stone", "RoofRamp": "ramp_boards", "RoofLanding": "bridge", "Car1": "canvas", "Car2": "canvas", "Car3": "canvas",
	"Shelter": "timber", "ShelterRoof": "roof", "Gate": "stone", "KioskA": "logs", "KioskC": "logs", "KioskACrate": "firewood",
	"KioskCCrate": "crate", "YardCrate1": "crate", "YardCrate2": "crate", "KioskBFront": "logs", "KioskBBack": "logs",
	"KioskBW": "logs", "KioskBE": "logs", "KioskBRoof": "roof", "WalkwayCover1": "firewood", "WalkwayCover2": "firewood",
}


## A block's name without its team's tag or its piece number
## ("ArcadeFront_Blue_12" → "ArcadeFront", "Planter_-7" → "Planter").
static func _base(n: String) -> String:
	n = n.replace("_Red", "").replace("_Blue", "")
	var cut := n.rfind("_")
	if cut > 0 and n.substr(cut + 1).lstrip("-").is_valid_int():
		n = n.substr(0, cut)
	return n


static func _surfaces(kit, d) -> void:
	for b: Node in kit.geometry.get_children():
		var n := _base(String(b.name))
		# The boundary: only there to stop you at the shelf's edge. The street
		# and the walkway: drawn in tiles (_ground_tiles()), so each tile
		# gets its own lamps.
		if n.begins_with("Boundary") or n in ["Ground", "GroundFloor", "Walkway", "WalkwayFloor"]:
			b.set(&"layers", 0)
			b.set(&"shadows", false)
			continue
		var dress: String = DRESS.get(n, "")
		if dress != "":
			b.set(&"surface", d.mat(dress))
		else:
			push_warning("Boulevard: no surface for %s" % b.name)
		# The daylight's shape is the vault's openings; only the roofs
		# over the skylight need shade it too.
		b.set(&"shadows", n.begins_with("AtriumRoof"))


# --- The cave ------------------------------------------------------------------------------

static func _noise(seed_value: int, period: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 1.0 / period
	n.fractal_octaves = 3
	return n


static func _noises() -> Array:
	var ridged := _noise(73, 30.0)
	ridged.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	return [_noise(71, 9.0), _noise(72, 26.0), ridged, _noise(74, 70.0)]


## How far out toward the cave's walls (x, z) is: 0 in the middle, 1 on
## the walls.
static func _round(x: float, z: float) -> float:
	return Vector2((x - MIDDLE.x) / CAVE.x, (z - MIDDLE.y) / CAVE.y).length()


## The vault's underside at (x, z): arching up from low on the walls to
## its crown forty metres over the village and more, in great domes and
## hollows, ridges and hanging lobes, never low over the village.
static func _vault(x: float, z: float, n: Array) -> float:
	var r := minf(_round(x, z), 1.0)
	var lumps: FastNoiseLite = n[1]
	var ridged: FastNoiseLite = n[2]
	var domes: FastNoiseLite = n[3]
	var y := 12.0 + 46.0 * pow(maxf(1.0 - r * r, 0.0), 0.6)
	y += domes.get_noise_2d(x, z) * 10.0 + lumps.get_noise_2d(x, z) * 5.0
	# Ridges hang down; between them the ice is hollowed up.
	y -= (ridged.get_noise_2d(x, z) * 0.5 + 0.5) * 9.0 - 4.0
	if _off_shelf(x, z) < 6.0:
		y = maxf(y, 24.0)
	return y


## How far (x, z) is outside the shelf (0 on or inside it).
static func _off_shelf(x: float, z: float) -> float:
	var dx := maxf(maxf(WEST - x, x - EAST), 0.0)
	var dz := maxf(maxf(NORTH - z, z - SOUTH), 0.0)
	return Vector2(dx, dz).length()


## The cave's floor at (x, z), off the shelf: the crevasse all round the
## shelf, deep and narrow, wider at the corners; past it the floor, ice
## and old snow in humps, rising into the walls.
static func _floor(x: float, z: float, n: Array) -> float:
	var wobble: FastNoiseLite = n[0]
	var lumps: FastNoiseLite = n[1]
	var ridged: FastNoiseLite = n[2]
	var off := _off_shelf(x, z)
	var width := 9.0 + lumps.get_noise_2d(x * 2.0, z * 2.0) * 3.0
	var ground := -5.0 + lumps.get_noise_2d(x, z) * 3.5 + (ridged.get_noise_2d(x * 1.7, z * 1.7) * 0.5 + 0.5) * 5.0 - 2.0
	ground += smoothstep(0.75, 1.0, _round(x, z)) * 10.0
	var deep := -28.0 + wobble.get_noise_2d(x, z) * 3.0
	return lerpf(deep, ground, smoothstep(width, width + 8.0, off))


## The cave: the shelf's edge dropping into the crevasse, the floor past
## it, the walls round it all and the vault over it; one mesh of flat
## facets, jagged, scalloped and lit from within by its shader.
static func _cave(d) -> void:
	var n := _noises()
	var wobble: FastNoiseLite = n[0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 3301
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	# The shelf's edge: walked round it, each point a column down into the
	# crevasse, only ever out from the edge.
	var corners := [Vector2(WEST, NORTH), Vector2(EAST, NORTH), Vector2(EAST, SOUTH), Vector2(WEST, SOUTH)]
	var ring := []
	for c in 4:
		var a: Vector2 = corners[c]
		var b: Vector2 = corners[(c + 1) % 4]
		var count := int(a.distance_to(b) / 2.0)
		var side := (b - a).normalized()
		var out := Vector2(side.y, -side.x)
		var prev_side: Vector2 = (a - (corners[(c + 3) % 4] as Vector2)).normalized()
		var prev_out := Vector2(prev_side.y, -prev_side.x)
		for f in 3:
			ring.append([a, prev_out.slerp(out, (f + 0.5) / 3.0)])
		for k in range(1, count):
			ring.append([a.lerp(b, float(k) / count), out])
	var edge_levels := [[0.02, 0.06], [-1.2, 0.5], [-3.5, 1.2], [-7.0, 2.2], [-12.0, 2.8], [-18.0, 3.2], [-24.0, 3.6], [-30.0, 4.0]]
	var columns := []
	for i in ring.size():
		var p: Vector2 = ring[i][0]
		var out: Vector2 = ring[i][1]
		var col := []
		for k in edge_levels.size():
			var lv: Array = edge_levels[k]
			var o: float = float(lv[1])
			var y: float = float(lv[0])
			if k > 0:
				o += absf(wobble.get_noise_2d(i * 2.0, k * 11.0)) * 2.0 + rng.randf() * 0.9
				y += rng.randf_range(-0.6, 0.6)
			col.append(Vector3(p.x + out.x * o, y, p.y + out.y * o))
		columns.append(col)
	for i in columns.size():
		var a: Array = columns[i]
		var b: Array = columns[(i + 1) % columns.size()]
		var out: Vector2 = ring[i][1]
		for k in edge_levels.size() - 1:
			_tri(st, [a[k], b[k], b[k + 1]], Vector3(out.x, 0, out.y))
			_tri(st, [a[k], b[k + 1], a[k + 1]], Vector3(out.x, 0, out.y))
	# The floor: a grid over the cave, the shelf left out.
	var step := 2.5
	var x0 := MIDDLE.x - CAVE.x - 4.0
	var z0 := MIDDLE.y - CAVE.y - 4.0
	var cols := int((CAVE.x * 2.0 + 8.0) / step) + 1
	var rows := int((CAVE.y * 2.0 + 8.0) / step) + 1
	var heights := {}
	var floor_at := func(i: int, j: int) -> Vector3:
		var x := x0 + i * step
		var z := z0 + j * step
		var key := Vector2i(i, j)
		if not heights.has(key):
			heights[key] = _floor(x, z, n) + rng.randf_range(-0.5, 0.5)
		return Vector3(x, heights[key], z)
	for j in rows - 1:
		for i in cols - 1:
			var q := [floor_at.call(i, j), floor_at.call(i + 1, j), floor_at.call(i + 1, j + 1), floor_at.call(i, j + 1)]
			var inside := true
			var beyond := true
			for v: Vector3 in q:
				inside = inside and _off_shelf(v.x, v.z) <= 0.0
				beyond = beyond and _round(v.x, v.z) > 1.03
			if inside or beyond:
				continue
			_tri(st, [q[0], q[1], q[2]], Vector3.UP)
			_tri(st, [q[0], q[2], q[3]], Vector3.UP)
	# The walls: round the cave, from under the floor up into the vault,
	# jagged in and out.
	var around := 260
	var wall_levels := [[-10.0, 1.03], [-3.0, 1.0], [2.0, 1.0], [6.0, 0.99], [10.0, 0.975], [14.0, 0.955], [0.0, 0.93]]
	var wall := []
	for i in around:
		var t := TAU * i / around
		var dir := Vector2(cos(t) * CAVE.x, sin(t) * CAVE.y)
		var col := []
		for k in wall_levels.size():
			var lv: Array = wall_levels[k]
			var s: float = float(lv[1]) + wobble.get_noise_2d(i * 3.0, k * 17.0) * 0.04 + rng.randf_range(-0.02, 0.02)
			var at := MIDDLE + dir * s
			var y: float = float(lv[0]) + rng.randf_range(-1.6, 1.6)
			if k == wall_levels.size() - 1:
				y = _vault(at.x, at.y, n) - 0.5
			col.append(Vector3(at.x, y, at.y))
		wall.append(col)
	for i in around:
		var a: Array = wall[i]
		var b: Array = wall[(i + 1) % around]
		for k in wall_levels.size() - 1:
			var inward := Vector3(MIDDLE.x, 0, MIDDLE.y) - (a[k] as Vector3) * Vector3(1, 0, 1)
			_tri(st, [a[k], b[k], b[k + 1]], inward)
			_tri(st, [a[k], b[k + 1], a[k + 1]], inward)
	# The vault: a grid over the cave.
	var vstep := 3.0
	var vcols := int((CAVE.x * 2.2) / vstep) + 1
	var vrows := int((CAVE.y * 2.2) / vstep) + 1
	var vx0 := MIDDLE.x - CAVE.x * 1.1
	var vz0 := MIDDLE.y - CAVE.y * 1.1
	var vault := {}
	var vault_at := func(i: int, j: int) -> Vector3:
		var key := Vector2i(i, j)
		if not vault.has(key):
			var x := vx0 + i * vstep
			var z := vz0 + j * vstep
			vault[key] = Vector3(x + rng.randf_range(-0.8, 0.8), _vault(x, z, n) + rng.randf_range(-1.5, 1.5), z + rng.randf_range(-0.8, 0.8))
		return vault[key]
	for j in vrows - 1:
		for i in vcols - 1:
			var q := [vault_at.call(i, j), vault_at.call(i + 1, j), vault_at.call(i + 1, j + 1), vault_at.call(i, j + 1)]
			var mid: Vector3 = (q[0] + q[2]) * 0.5
			# On out past the walls' tops (hidden behind them), so no gap shows
			# between.
			if _round(mid.x, mid.z) > 1.06:
				continue
			_tri(st, [q[0], q[1], q[2]], Vector3.DOWN)
			_tri(st, [q[0], q[2], q[3]], Vector3.DOWN)
	st.generate_normals()
	var mesh := st.commit()
	ResourceSaver.save(mesh, d.dir + "meshes/cave.res")
	var mi: MeshInstance3D = d.own_mesh("Cave", load(d.dir + "meshes/cave.res"), d.mat("cave_ice"), Transform3D.IDENTITY, "Build", CAVE_LAYER)


## A triangle, turned to face `toward` (Godot's fronts wind clockwise).
static func _tri(st: SurfaceTool, tri: Array, toward: Vector3) -> void:
	var n: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0])
	if n.dot(toward) > 0.0:
		tri = [tri[0], tri[2], tri[1]]
	for v: Vector3 in tri:
		st.add_vertex(v)


# --- Ice --------------------------------------------------------------------------------

## A spike of ice from `base` to `tip`, `radius` round at the base, `sides`
## sided, each ring a little off true so no two are alike.
static func _spike(st: SurfaceTool, base: Vector3, tip: Vector3, radius: float, sides: int, rng: RandomNumberGenerator) -> void:
	var axis := (tip - base).normalized()
	var side := axis.cross(Vector3.RIGHT if absf(axis.x) < 0.9 else Vector3.FORWARD).normalized()
	var up := axis.cross(side)
	var rings := [[0.0, 1.0], [0.35, 0.72], [0.7, 0.38]]
	var pts := []
	var turn := rng.randf() * TAU
	for rg: Array in rings:
		var ring := []
		var at := base.lerp(tip, float(rg[0])) + (side * rng.randf_range(-1, 1) + up * rng.randf_range(-1, 1)) * radius * 0.12
		for s in sides:
			var a := turn + TAU * s / sides
			ring.append(at + (side * cos(a) + up * sin(a)) * radius * float(rg[1]) * rng.randf_range(0.85, 1.1))
		pts.append(ring)
	for k in pts.size() - 1:
		for s in sides:
			var a: Vector3 = pts[k][s]
			var b: Vector3 = pts[k][(s + 1) % sides]
			var c: Vector3 = pts[k + 1][(s + 1) % sides]
			var e: Vector3 = pts[k + 1][s]
			var mid := (a + c) * 0.5
			var toward := mid - base.lerp(tip, float(rings[k][0]) + 0.15)
			_tri(st, [a, b, c], toward)
			_tri(st, [a, c, e], toward)
	var last: Array = pts[pts.size() - 1]
	for s in sides:
		var a: Vector3 = last[s]
		var b: Vector3 = last[(s + 1) % sides]
		_tri(st, [a, b, tip], (a + b) * 0.5 - base.lerp(tip, 0.85))


## A column of ice from the floor to the vault, where an icicle and a
## spike have grown into each other: thick at both ends, thinnest at the
## waist, jagged all the way.
static func _column(st: SurfaceTool, at: Vector2, radius: float, n: Array, rng: RandomNumberGenerator) -> void:
	var bottom := _floor(at.x, at.y, n) - 2.0
	var top := _vault(at.x, at.y, n) + 2.0
	var sides := 9
	var rings := 12
	var pts := []
	for k in rings + 1:
		var t := float(k) / rings
		var waist := 0.32 + 0.68 * pow(absf(t * 2.0 - 1.0), 1.7)
		var c := Vector3(at.x, lerpf(bottom, top, t), at.y) + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * radius * 0.15
		var ring := []
		for s in sides:
			var a := TAU * s / sides + k * 0.4
			ring.append(c + Vector3(cos(a), 0, sin(a)) * radius * waist * rng.randf_range(0.75, 1.2))
		pts.append(ring)
	for k in rings:
		var mid := Vector3(at.x, lerpf(bottom, top, (k + 0.5) / rings), at.y)
		for s in sides:
			var a: Vector3 = pts[k][s]
			var b: Vector3 = pts[k][(s + 1) % sides]
			var c: Vector3 = pts[k + 1][(s + 1) % sides]
			var e: Vector3 = pts[k + 1][s]
			_tri(st, [a, b, c], (a + c) * 0.5 - mid)
			_tri(st, [a, c, e], (a + c) * 0.5 - mid)


## A crystal of ice: a six-sided prism from `base` along `dir`, `length`
## long, pointed at the end.
static func _crystal(st: SurfaceTool, base: Vector3, dir: Vector3, length: float, radius: float, rng: RandomNumberGenerator) -> void:
	var axis := dir.normalized()
	var side := axis.cross(Vector3.RIGHT if absf(axis.x) < 0.9 else Vector3.FORWARD).normalized()
	var up := axis.cross(side)
	var shoulder := base + axis * length * 0.78
	var tip := base + axis * length
	var turn := rng.randf() * TAU
	var lo := []
	var hi := []
	for s in 6:
		var a := turn + TAU * s / 6.0
		var o := (side * cos(a) + up * sin(a)) * radius
		lo.append(base + o)
		hi.append(shoulder + o * rng.randf_range(0.9, 1.05))
	for s in 6:
		var a: Vector3 = lo[s]
		var b: Vector3 = lo[(s + 1) % 6]
		var c: Vector3 = hi[(s + 1) % 6]
		var e: Vector3 = hi[s]
		var toward := (a + b) * 0.5 - base
		_tri(st, [a, b, c], toward)
		_tri(st, [a, c, e], toward)
		_tri(st, [e, c, tip], (e + c) * 0.5 - shoulder)


## A cluster of crystals growing out of one spot, leaning every way from
## `up`.
static func _cluster(st: SurfaceTool, at: Vector3, up: Vector3, size: float, rng: RandomNumberGenerator) -> void:
	for k in rng.randi_range(4, 9):
		var lean := up.normalized() + Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.2, 0.3), rng.randf_range(-0.7, 0.7))
		var length := size * rng.randf_range(0.35, 1.0)
		_crystal(st, at + Vector3(rng.randf_range(-0.3, 0.3), -0.3, rng.randf_range(-0.3, 0.3)) * size, lean, length,
				length * rng.randf_range(0.1, 0.17), rng)


## Out in the cave, past the crevasse: columns of ice from floor to vault,
## spikes standing up out of the floor, clusters of crystals; on the
## crevasse's far lip too. None of it where anyone can get.
static func _formations(d) -> void:
	var n := _noises()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for c: Array in [[100.0, -25.0, 5.0], [78.0, 52.0, 4.0], [40.0, -60.0, 4.5], [18.0, 66.0, 3.5], [106.0, 18.0, 3.5]]:
		for side: float in [-1.0, 1.0]:
			_column(st, Vector2(float(c[0]) * side, float(c[1])), float(c[2]), n, rng)
	# Spikes and clusters, placed at random where the floor is.
	var placed := 0
	var tries := 0
	while placed < 140 and tries < 4000:
		tries += 1
		var x := rng.randf_range(-CAVE.x, CAVE.x)
		var z := MIDDLE.y + rng.randf_range(-CAVE.y, CAVE.y)
		var off := _off_shelf(x, z)
		if _round(x, z) > 0.95 or off < 12.0:
			continue
		var y := _floor(x, z, n)
		if placed % 3 == 0:
			var h := rng.randf_range(3.0, 14.0)
			_spike(st, Vector3(x, y - 1.0, z), Vector3(x + rng.randf_range(-1, 1), y + h, z + rng.randf_range(-1, 1)),
					h * rng.randf_range(0.12, 0.2), 7, rng)
		else:
			_cluster(st, Vector3(x, y, z), Vector3.UP, rng.randf_range(1.5, 6.0), rng)
		placed += 1
	st.generate_normals()
	var mesh := st.commit()
	ResourceSaver.save(mesh, d.dir + "meshes/formations.res")
	d.own_mesh("Formations", load(d.dir + "meshes/formations.res"), d.mat("icicle"), Transform3D.IDENTITY, "Build", CAVE_LAYER)


## Icicles hanging from the vault, all over it: most short, some long;
## over the village never low enough to reach.
static func _icicles(d) -> void:
	var n := _noises()
	var rng := RandomNumberGenerator.new()
	rng.seed = 881
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for i in 1400:
		var x := rng.randf_range(-CAVE.x, CAVE.x)
		var z := MIDDLE.y + rng.randf_range(-CAVE.y, CAVE.y)
		if _round(x, z) > 0.9:
			continue
		var y := _vault(x, z, n)
		var length := rng.randf_range(0.8, 3.0)
		if rng.randf() < 0.15:
			length *= 3.0
		var lowest := 18.0 if _off_shelf(x, z) <= 2.0 else _floor(x, z, n) + 8.0
		length = minf(length, y - lowest)
		if length < 0.5:
			continue
		var r := clampf(length * rng.randf_range(0.07, 0.12), 0.06, 0.9)
		var top := Vector3(x, y + 0.5, z)
		_spike(st, top, top + Vector3(rng.randf_range(-0.1, 0.1), -length - 0.5, rng.randf_range(-0.1, 0.1)), r, 6, rng)
		# Little ones round it.
		for k in rng.randi_range(0, 3):
			var off := Vector3(rng.randf_range(-1.0, 1.0), 0, rng.randf_range(-1.0, 1.0))
			var l := length * rng.randf_range(0.2, 0.6)
			_spike(st, top + off, top + off + Vector3(0, -l - 0.5, 0), r * 0.55, 5, rng)
	st.generate_normals()
	var mesh := st.commit()
	ResourceSaver.save(mesh, d.dir + "meshes/icicles.res")
	d.own_mesh("Icicles", load(d.dir + "meshes/icicles.res"), d.mat("icicle"), Transform3D.IDENTITY, "Build", CAVE_LAYER)


## The shelf's edges: the Arcade's and the Atrium's back wall where the
## shelf ends behind them, and a fence along the edges you can walk up to
## (the yards, the walkway, the roof), with the crevasse beyond.
static func _edges(d) -> void:
	d.box("plaster", Vector3(0, 4.75, NORTH - 0.2), Vector3(112.0, 9.5, 0.3), "Build")
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var runs := []
	for side: float in [-1.0, 1.0]:
		runs.append([Vector3(59.0 * side, 0, NORTH + 0.2), Vector3(71.8 * side, 0, NORTH + 0.2)])
		runs.append([Vector3(71.8 * side, 0, NORTH + 0.2), Vector3(71.8 * side, 0, SOUTH - 0.2)])
		runs.append([Vector3(1.0 * side, 0, SOUTH - 0.2), Vector3(71.8 * side, 0, SOUTH - 0.2)])
		runs.append([Vector3(1.0 * side, 9.5, NORTH + 0.3), Vector3(56.0 * side, 9.5, NORTH + 0.3)])
	for run: Array in runs:
		_fence(d, run[0], run[1], rng)


## A post-and-rail fence from `a` to `b`: posts every two and a half
## metres, two rails, snow along the top one.
static func _fence(d, a: Vector3, b: Vector3, rng: RandomNumberGenerator) -> void:
	var along := b - a
	var count := maxi(1, int(along.length() / 2.5))
	var basis := Basis(along.normalized(), Vector3.UP, along.normalized().cross(Vector3.UP))
	for k in count + 1:
		var p := a + along * float(k) / count
		d.box("timber", p + Vector3(0, 0.6, 0), Vector3(0.16, 1.2 + rng.randf_range(-0.06, 0.06), 0.16), "Detail", BOTH,
				Basis(Vector3.UP, rng.randf_range(-0.1, 0.1)))
	var mid := (a + b) * 0.5
	for y: float in [0.55, 1.05]:
		d.box("timber", mid + Vector3(0, y, 0), Vector3(along.length(), 0.1, 0.08), "Detail", BOTH, basis)
	d.box("snow_cap", mid + Vector3(0, 1.12, 0), Vector3(along.length(), 0.06, 0.14), "Detail", BOTH, basis)



# --- The village ----------------------------------------------------------------------------

## A point on `side`'s half: the east's (1), or mirrored to the west's (-1).
static func _at(side: float, v: Vector3) -> Vector3:
	return Vector3(v.x * side, v.y, v.z)


## A warm lamp's light, maybe wavering like a flame.
static func _lamp(kit, d, name: String, at: Vector3, reach: float, energy: float, minor := true, fire := 0.0, seed := 0.0,
		colour := WARM) -> OmniLight3D:
	var l: OmniLight3D = d.omni(name, at, colour, reach, energy * 1.3, 0xFFFFF & ~CAVE_LAYER, minor)
	if fire > 0.0:
		var f := Node.new()
		f.set_script(load("res://src/world/fire_light.gd"))
		f.name = name + "Fire"
		f.set(&"light", l)
		f.set(&"seed", seed)
		f.set(&"amount", fire)
		kit.root.add_child(f)
	return l


## A lantern: a little iron house round a flame, a glow in it. `hang`
## hangs it from a hook above, else it stands.
static func _lantern(d, at: Vector3, size := 0.32) -> void:
	var h := size * 1.4
	d.box("dark_metal", at + Vector3(0, h * 0.5 + 0.03, 0), Vector3(size + 0.06, 0.04, size + 0.06), "Fixtures", BOTH)
	d.box("dark_metal", at + Vector3(0, -h * 0.5, 0), Vector3(size + 0.04, 0.04, size + 0.04), "Fixtures", BOTH)
	for c: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		d.box("dark_metal", at + Vector3(c.x, 0, c.y) * size * 0.5, Vector3(0.03, h, 0.03), "Fixtures", BOTH)
	d.box("lamp_warm", at, Vector3(size * 0.8, h * 0.85, size * 0.8), "Fixtures", BOTH)
	d.ball("dark_metal", at + Vector3(0, h * 0.5 + 0.1, 0), Vector3(size * 0.45, size * 0.3, size * 0.45), 2, 6, "Fixtures", BOTH)


## A pool of warm light on the ground (or any floor) under a lamp.
static func _pool(d, at: Vector3, radius := 2.5, big := false) -> void:
	_glow(d, at + Vector3(0, 0.03, 0), Vector3(radius, 0, 0), Vector3(0, 0, -radius), 0.75 if big else 0.9)


## Lamplight faked on a floor or a wall: a soft round glow on the face
## `c` ± `u`, `v` (half its width and height). The glow's shader reads the
## face in metres, so each size has its material.
static func _glow(d, c: Vector3, u: Vector3, v: Vector3, strength := 0.9) -> void:
	var size := Vector2(u.length(), v.length()) * 2.0
	var name := "pool_%d_%d_%d" % [roundi(size.x * 10.0), roundi(size.y * 10.0), roundi(strength * 100.0)]
	d.shaded(name, POOL, {"color": WARM, "strength": strength, "size": size})
	d.face(name, c, u, v, "Effects", BOTH)


## The indoors: the Arcade's rooms and gallery and the Atrium, all along
## the north side, keep the cave's blue out.
static func _indoors(kit) -> void:
	var zone := Node3D.new()
	zone.set_script(load("res://src/world/ambient_zone.gd"))
	zone.name = "Indoors"
	zone.position = Vector3(0, 4.5, (NORTH - 14.0) * 0.5)
	zone.set(&"size", Vector3(112.0, 9.0, -14.0 - NORTH))
	zone.set(&"ambient", 0.4)
	kit.root.add_child(zone)


## The Arcade's front: six houses in a row, each its own colour, timber
## framed; windows framed, shuttered, with sills and snow on them; a
## lantern and a little shingled roof over each door and the trade's sign
## over it; the eaves along the top (icicles: _eave_icicles()). Behind:
## the hearths in the rooms, lanterns in the gallery.
static func _arcade(kit, d, side: float) -> void:
	var face := -13.8
	var holes := []
	for o: Array in DOORS + WINDOWS:
		holes.append(Rect2(16.0 + float(o[0]), float(o[1]), float(o[2]), float(o[3])))
	# Each house's plaster, between its openings.
	for h in HOUSES.size() - 1:
		var area := Rect2(float(HOUSES[h]), 0.0, float(HOUSES[h + 1]) - float(HOUSES[h]), 9.0)
		var inside := holes.filter(func(r: Rect2) -> bool: return r.intersects(area))
		for r: Rect2 in LevelKit._cells(area, inside):
			var c := _at(side, Vector3(r.get_center().x, r.get_center().y, face + 0.012))
			d.face("plaster_%d" % h, c, Vector3(r.size.x * 0.5, 0, 0), Vector3(0, r.size.y * 0.5, 0), "Build", BOTH)
	var t := face + 0.06
	# The frame: a stone plinth, the floor beam, the top plate, a post
	# between each house and the next.
	var plinth_from := 16.0
	for o: Array in DOORS + [[40.0, 0.0, 0.0, 0.0]]:
		var to: float = 16.0 + float(o[0])
		if to > plinth_from:
			d.box("stone", _at(side, Vector3((plinth_from + to) * 0.5, 0.25, face + 0.07)), Vector3(to - plinth_from, 0.5, 0.14), "Build", BOTH)
		plinth_from = to + float(o[2])
	for y: float in [4.75, 9.18]:
		d.box("wood", _at(side, Vector3(36.0, y, t)), Vector3(40.0, 0.36, 0.14), "Build", BOTH)
	for x: float in HOUSES:
		d.box("wood", _at(side, Vector3(clampf(x, 16.15, 55.85), 4.7, t + 0.01)), Vector3(0.28, 9.4, 0.16), "Build", BOTH)
	# Braces across the upper storey's panels wide enough to take one.
	var upper := Rect2(16.0, 4.95, 40.0, 4.05)
	var posts := []
	for x: float in HOUSES:
		posts.append(Rect2(x - 0.15, 4.95, 0.3, 4.05))
	var k := 0
	for r: Rect2 in LevelKit._cells(upper, holes.filter(func(q: Rect2) -> bool: return q.position.y > 4.0) + posts):
		if r.size.x < 1.1 or r.size.y < 1.0:
			continue
		var angle := atan2(r.size.y, r.size.x) * (1.0 if k % 2 == 0 else -1.0) * side
		k += 1
		d.box("wood", _at(side, Vector3(r.get_center().x, r.get_center().y, t)), Vector3(r.size.length() - 0.2, 0.16, 0.12), "Build", BOTH,
				Basis(Vector3(0, 0, 1), angle))
	# Windows: a frame, shutters open against the wall, a sill with snow,
	# a box of greenery under the ground floor's.
	for o: Array in WINDOWS:
		var x0: float = 16.0 + float(o[0])
		var w: float = o[2]
		var y0: float = o[1]
		var hh: float = o[3]
		var house := 0
		while house < HOUSES.size() - 2 and x0 > float(HOUSES[house + 1]):
			house += 1
		var cx := x0 + w * 0.5
		for e: float in [-1.0, 1.0]:
			d.box("wood", _at(side, Vector3(cx + e * (w * 0.5 + 0.06), y0 + hh * 0.5, t)), Vector3(0.12, hh + 0.24, 0.12), "Build", BOTH)
			d.box("paint_%d" % house, _at(side, Vector3(cx + e * (w * 0.5 + 0.12 + w * 0.25), y0 + hh * 0.5, face + 0.05)),
					Vector3(w * 0.5 - 0.04, hh + 0.1, 0.05), "Build", BOTH)
			# The shutters' boards and a heart cut in each.
			for b: float in [-0.25, 0.0, 0.25]:
				d.box("wood", _at(side, Vector3(cx + e * (w * 0.5 + 0.12 + w * 0.25) + b * w * 0.4, y0 + hh * 0.5, face + 0.08)),
						Vector3(0.02, hh + 0.08, 0.01), "Detail", BOTH)
		d.box("wood", _at(side, Vector3(cx, y0 + hh + 0.1, t)), Vector3(w + 0.36, 0.2, 0.14), "Build", BOTH)
		d.box("stone", _at(side, Vector3(cx, y0 - 0.06, face + 0.14)), Vector3(w + 0.4, 0.12, 0.3), "Build", BOTH)
		d.box("snow_cap", _at(side, Vector3(cx, y0 + 0.03, face + 0.16)), Vector3(w + 0.3, 0.07, 0.26), "Detail", BOTH)
		if y0 < 3.0:
			d.box("board", _at(side, Vector3(cx, y0 - 0.34, face + 0.24)), Vector3(w, 0.4, 0.36), "Detail", BOTH)
			for g in 7:
				d.ball("evergreen", _at(side, Vector3(x0 + 0.25 + g * (w - 0.5) / 6.0, y0 - 0.1, face + 0.24)), Vector3(0.24, 0.2, 0.2), 3, 6, "Detail", BOTH)
			d.box("snow_cap", _at(side, Vector3(cx, y0 - 0.02, face + 0.26)), Vector3(w - 0.2, 0.06, 0.22), "Detail", BOTH)
	# Doors: a frame, a little roof over, a lantern beside, the sign.
	for i in DOORS.size():
		var o: Array = DOORS[i]
		var x0: float = 16.0 + float(o[0])
		var w: float = o[2]
		var cx := x0 + w * 0.5
		for e: float in [-1.0, 1.0]:
			d.box("wood", _at(side, Vector3(cx + e * (w * 0.5 + 0.08), 1.6, t)), Vector3(0.16, 3.2, 0.16), "Build", BOTH)
		d.box("wood", _at(side, Vector3(cx, 3.12, t)), Vector3(w + 0.5, 0.24, 0.18), "Build", BOTH)
		_canopy(d, _at(side, Vector3(cx, 3.9, face)), w + 1.2, 1.0, 0.45)
		var lamp_at := _at(side, Vector3(cx + (w * 0.5 + 0.7), 2.6, face + 0.55))
		d.box("dark_metal", _at(side, Vector3(cx + (w * 0.5 + 0.7), 2.95, face + 0.3)), Vector3(0.05, 0.05, 0.6), "Fixtures", BOTH)
		_lantern(d, lamp_at, 0.26)
		_pool(d, _at(side, Vector3(cx + 1.0, 0.0, face + 1.6)), 2.6)
		_glow(d, _at(side, Vector3(cx + w * 0.5 + 0.7, 2.4, face + 0.02)), Vector3(2.6, 0, 0), Vector3(0, 2.6, 0))
		_lamp(kit, d, "Door%s%d" % ["W" if side < 0.0 else "E", i], lamp_at + Vector3(0, 0, 0.3), 10.0, 2.2, i != 1, 0.15, side + i)
		Signs.board(d, _at(side, Vector3(cx, 4.2, face + 0.12)), Basis.IDENTITY, Vector2(maxf(2.4, TRADES[i].length() * 0.16), 0.5),
				"board", TRADES[i], ITALIC, 0.26, Color(1.0, 0.9, 0.7), "wood")
	# The rooms: a hearth in the inn and the bakery's oven, their fires.
	for hearth: Array in [[22.5, "Inn"], [35.5, "Bakery"]]:
		var hx: float = hearth[0]
		var c := _at(side, Vector3(hx, 0.0, NORTH + 0.45))
		d.box("stone", c + Vector3(0, 1.2, 0), Vector3(2.8, 2.4, 0.9), "Build", BOTH)
		d.box("black", c + Vector3(0, 0.6, 0.46), Vector3(1.4, 1.1, 0.02), "Build", BOTH)
		d.box("wood", c + Vector3(0, 2.1, 0.5), Vector3(3.2, 0.2, 0.3), "Build", BOTH)
		_fire(d, c + Vector3(0, 0.1, 0.35), 0.6)
		_lamp(kit, d, "%s%s" % [hearth[1], "W" if side < 0.0 else "E"], c + Vector3(0, 1.0, 1.5), 14.0, 3.0, false, 0.3, hx * side)
		_glow(d, c + Vector3(0, 0.02, 2.2), Vector3(2.4, 0, 0), Vector3(0, 0, -2.4))
	# The lamplight falling out of the ground-floor windows onto the snow,
	# a lantern in the third room.
	for o: Array in WINDOWS:
		if float(o[1]) < 3.0:
			var cx: float = 16.0 + float(o[0]) + float(o[2]) * 0.5
			_glow(d, _at(side, Vector3(cx, 0.03, face + 1.8)), Vector3(2.0, 0, 0), Vector3(0, 0, -1.6))
	var room := _at(side, Vector3(49.0, 3.3, -24.0))
	d.box("dark_metal", room + Vector3(0, 0.6, 0), Vector3(0.02, 0.9, 0.02), "Fixtures", BOTH)
	_lantern(d, room, 0.3)
	_pool(d, _at(side, Vector3(49.0, 0.0, -24.0)), 3.0)
	_lamp(kit, d, "Workshop%s" % ("W" if side < 0.0 else "E"), room + Vector3(0, -0.4, 0), 11.0, 2.2, true, 0.1, side * 2.0)
	# Furniture: the inn's table and benches under its window, the
	# bakery's counter, a workbench in the workshop.
	_table(d, _at(side, Vector3(26.5, 0, -17.2)), side)
	d.solid(_at(side, Vector3(35.5, 0.5, -17.0)), Vector3(4.0, 1.0, 0.9))
	d.box("board", _at(side, Vector3(35.5, 0.48, -17.0)), Vector3(4.0, 0.96, 0.9), "Solid", BOTH)
	d.box("wood", _at(side, Vector3(35.5, 1.0, -17.0)), Vector3(4.2, 0.08, 1.0), "Solid", BOTH)
	for loaf in 5:
		d.ball("paint_3", _at(side, Vector3(34.0 + loaf * 0.7, 1.12, -17.0)), Vector3(0.22, 0.1, 0.16), 2, 6, "Detail", BOTH)
	d.solid(_at(side, Vector3(52.0, 0.45, -33.3)), Vector3(3.0, 0.9, 1.0))
	d.box("wood", _at(side, Vector3(52.0, 0.45, -33.3)), Vector3(3.0, 0.9, 1.0), "Solid", BOTH)
	for tool in 4:
		d.box("dark_metal", _at(side, Vector3(50.8 + tool * 0.7, 0.95, -33.4)), Vector3(0.08, 0.1, 0.4), "Detail", BOTH)
	# The gallery: lanterns hanging from the beams.
	for gx: float in [22.0, 36.0, 50.0]:
		var at := _at(side, Vector3(gx, 7.6, -24.0))
		d.box("dark_metal", at + Vector3(0, 0.8, 0), Vector3(0.02, 1.1, 0.02), "Fixtures", BOTH)
		_lantern(d, at, 0.3)
		_pool(d, _at(side, Vector3(gx, 5.0, -24.0)), 3.0)
	for gx: float in [26.0, 46.0]:
		_lamp(kit, d, "Gallery%s%d" % ["W" if side < 0.0 else "E", int(gx)], _at(side, Vector3(gx, 7.2, -24.0)), 13.0, 2.2, gx > 30.0, 0.1, side * gx)
	# Chimneys up through the roof at the back, their fires' smoke.
	for cx: float in [24.0, 44.0]:
		var at := _at(side, Vector3(cx, 9.5, NORTH + 1.2))
		d.solid(at + Vector3(0, 0.9, 0), Vector3(1.1, 1.8, 1.1))
		d.box("stone", at + Vector3(0, 0.9, 0), Vector3(1.1, 1.8, 1.1), "Solid", BOTH)
		d.box("stone", at + Vector3(0, 1.85, 0), Vector3(1.3, 0.14, 1.3), "Solid", BOTH)
		d.box("black", at + Vector3(0, 1.93, 0), Vector3(0.8, 0.02, 0.8), "Solid", BOTH)
		d.box("snow_cap", at + Vector3(0, 1.97, 0), Vector3(1.34, 0.08, 1.34), "Detail", BOTH)
		_smoke(d, at + Vector3(0, 2.1, 0), cx * side)


## A little roof over a door or a window: `at` the middle of its top edge
## on the wall (facing +z), `width` along the wall, sloping out `depth` and
## down `drop`; shingles, snow on it, the edge boarded.
static func _canopy(d, at: Vector3, width: float, depth: float, drop: float) -> void:
	var half := width * 0.5
	var out := Vector3(0, -drop, depth)
	d.quad("shingle_roof", at + Vector3(-half, 0, 0), at + Vector3(half, 0, 0), at + Vector3(half, 0, 0) + out, at + Vector3(-half, 0, 0) + out,
			"Build", BOTH)
	d.quad("shingle_roof", at + Vector3(half, 0, 0) + out, at + Vector3(half, 0, 0), at + Vector3(-half, 0, 0), at + Vector3(-half, 0, 0) + out,
			"Build", BOTH)
	var slope := Basis(Vector3(1, 0, 0), atan2(drop, depth))
	d.box("snow_cap", at + out * 0.5 + slope * Vector3(0, 0.08, 0), Vector3(width - 0.1, 0.12, out.length() * 0.9), "Detail", BOTH, slope)
	d.box("wood", at + out + Vector3(0, -0.06, 0), Vector3(width + 0.04, 0.12, 0.06), "Build", BOTH)
	for e: float in [-1.0, 1.0]:
		d.box("wood", at + Vector3(e * (half - 0.08), -drop * 0.5 - 0.3, depth * 0.5), Vector3(0.08, 0.08, depth + 0.3), "Build", BOTH,
				Basis(Vector3(1, 0, 0), -0.8))


## A fire: a few logs, the flames over them (crossed sheets), embers.
static func _fire(d, at: Vector3, size: float) -> void:
	for k in 3:
		var a := PI * k / 3.0
		d.tube("wood", at + Vector3(cos(a), 0, sin(a)) * size * 0.45 + Vector3(0, 0.06, 0), at - Vector3(cos(a), 0, sin(a)) * size * 0.45 + Vector3(0, 0.06, 0),
				0.06 * size / 0.6, 6, "Detail", BOTH)
	d.ball("lamp_warm", at + Vector3(0, 0.04, 0), Vector3(size * 0.45, 0.05, size * 0.45), 2, 8, "Fixtures", BOTH)
	var w := size * 0.5
	var hgt := size * 0.8 / 0.6
	for k in 3:
		var across := Basis(Vector3.UP, PI * k / 3.0) * Vector3(w, 0, 0)
		d.quad("flame", at - across + Vector3(0, hgt, 0), at + across + Vector3(0, hgt, 0), at + across, at - across, "Effects", BOTH)


## The Tower on the Arcade's roof: a belfry over the sniper's platform, a
## post at each corner, a steep shingled roof with snow on it and a bell
## under it, a lantern hanging with the bell.
static func _tower(kit, d, side: float) -> void:
	var lo := Vector3(50.0, 12.0, -20.0)
	var hi := Vector3(56.0, 15.6, -14.0)
	for c: Vector2 in [Vector2(50.2, -19.8), Vector2(55.8, -19.8), Vector2(50.2, -14.2), Vector2(55.8, -14.2)]:
		var p := _at(side, Vector3(c.x, 13.8, c.y))
		d.solid(p, Vector3(0.3, 3.6, 0.3))
		d.box("wood", p, Vector3(0.3, 3.6, 0.3), "Solid", BOTH)
	var mid := _at(side, Vector3(53.0, 15.7, -17.0))
	for e: float in [-1.0, 1.0]:
		d.box("wood", mid + Vector3(e * 2.8, 0, 0), Vector3(0.3, 0.3, 6.0), "Build", BOTH)
		d.box("wood", mid + Vector3(0, 0, e * 2.8), Vector3(6.0, 0.3, 0.3), "Build", BOTH)
	# The roof: four steep faces up to a point, snow on each.
	var apex := mid + Vector3(0, 3.6, 0)
	var eaves := [mid + Vector3(-3.4, 0.1, -3.4), mid + Vector3(3.4, 0.1, -3.4), mid + Vector3(3.4, 0.1, 3.4), mid + Vector3(-3.4, 0.1, 3.4)]
	for k in 4:
		var a: Vector3 = eaves[k]
		var b: Vector3 = eaves[(k + 1) % 4]
		d.quad("shingle_roof", apex, apex, a, b, "Build", BOTH)
		d.quad("shingle_roof", apex, apex, b, a, "Build", BOTH)
		var along := (a + b) * 0.5
		d.quad("snow_cap", apex + Vector3(0, 0.06, 0), apex + Vector3(0, 0.06, 0), a.lerp(apex, 0.1) + Vector3(0, 0.1, 0),
				b.lerp(apex, 0.1) + Vector3(0, 0.1, 0), "Detail", BOTH)
		d.box("wood", along, Vector3(0.14, 0.14, a.distance_to(b)) if absf(a.x - b.x) < 0.1 else Vector3(a.distance_to(b), 0.14, 0.14), "Build", BOTH)
	d.tube("dark_metal", apex, apex + Vector3(0, 1.2, 0), 0.04, 6, "Build", BOTH)
	# The bell, and a lantern with it.
	d.tube("dark_metal", mid, mid + Vector3(0, -0.4, 0), 0.04, 6, "Build", BOTH)
	var bell := mid + Vector3(0, -0.85, 0)
	for k in 4:
		var y := -0.12 * k
		d.tube("brass", bell + Vector3(0, 0.45 + y, 0), bell + Vector3(0, 0.33 + y, 0), 0.22 + 0.07 * k, 12, "Build", BOTH, false)
	_lantern(d, mid + Vector3(1.2, -0.9, 1.2), 0.3)
	# The tower's windows lit, down its sides.
	_lit_window(d, _at(side, Vector3(53.0, 10.8, -13.98)), Vector3(0, 0, 1), 0.7, 1.2)
	_lit_window(d, _at(side, Vector3(56.02, 10.8, -17.0)), Vector3(side, 0, 0), 0.7, 1.2)
	_lamp(kit, d, "Tower%s" % ("W" if side < 0.0 else "E"), mid + Vector3(1.2, -1.2, 1.2), 14.0, 2.4, true, 0.12, side * 7.0)


## Icicles along the eaves: under the parapets' front edges and the
## roofs of the kiosks, short and many.
static func _eave_icicles(d) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var edges := [[Vector3(-50.0, 9.48, -13.95), Vector3(50.0, 9.48, -13.95)]]
	for side: float in [-1.0, 1.0]:
		for k: Array in [[16.0, 28.0], [32.0, 44.0], [48.0, 56.0]]:
			edges.append([_at(side, Vector3(float(k[0]), 3.98, 13.97)), _at(side, Vector3(float(k[1]), 3.98, 13.97))])
	for e: Array in edges:
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		var x := 0.0
		var length := a.distance_to(b)
		while x < length:
			x += rng.randf_range(0.15, 0.6)
			var p := a.lerp(b, x / length)
			var l := rng.randf_range(0.1, 0.7) * (2.2 if rng.randf() < 0.1 else 1.0)
			_spike(st, p + Vector3(0, 0.05, 0), p + Vector3(0, -l, 0), l * 0.09 + 0.02, 5, rng)
	st.generate_normals()
	var mesh := st.commit()
	ResourceSaver.save(mesh, d.dir + "meshes/eave_icicles.res")
	d.own_mesh("EaveIcicles", load(d.dir + "meshes/eave_icicles.res"), d.mat("icicle"), Transform3D.IDENTITY, "Detail")



## Wooden floors in the Arcade's rooms and the Atrium, over the street's
## cobbles that run under them.
static func _floors(d) -> void:
	d.box("floorboards", Vector3(0, 0.012, (NORTH - 14.2) * 0.5), Vector3(112.0, 0.024, -14.2 - NORTH), "Build", BOTH)


## The Atrium: Rimehollow's hall, open to the street across its front, its
## beams carved; inside a great hearth on the back wall, a ring of candles
## hanging under the skylight, fir trees in the planters with lights in
## them, banners, a long rug.
static func _hall(kit, d) -> void:
	var face := -13.8
	var t := face + 0.06
	# The front: timbers round the upper windows, the great beam over the
	# opening, the pillars carved.
	for y: float in [4.75, 9.18]:
		d.box("wood", Vector3(0, y, t), Vector3(32.0, 0.4 if y < 5.0 else 0.36, 0.2), "Build", BOTH)
	for x: float in [-15.85, -12.2, -5.8, 5.8, 12.2, 15.85]:
		d.box("wood", Vector3(x, 7.0, t), Vector3(0.24, 4.4, 0.14), "Build", BOTH)
	for x: float in [-9.0, 0.0, 9.0]:
		for e: float in [-1.0, 1.0]:
			d.box("wood", Vector3(x + e * 1.4, 7.0, t), Vector3(3.6, 0.16, 0.12), "Build", BOTH, Basis(Vector3(0, 0, 1), e * 0.7))
	for px: float in [-5.0, 5.0]:
		for e: float in [-1.0, 1.0]:
			d.box("wood", Vector3(px + e * 0.9, 4.1, face + 0.4), Vector3(1.4, 0.16, 0.2), "Build", BOTH, Basis(Vector3(0, 0, 1), e * -0.6))
		d.box("wood", Vector3(px, 0.2, face + 0.4), Vector3(1.3, 0.4, 1.3), "Build", BOTH)
	Signs.board(d, Vector3(0, 5.6, face + 0.16), Basis.IDENTITY, Vector2(6.4, 0.9), "board", "Rimehollow Hall", ITALIC, 0.5,
			Color(1.0, 0.86, 0.5), "wood")
	for x: float in [-4.0, 4.0]:
		d.box("dark_metal", Vector3(x, 5.4, face + 0.3), Vector3(0.05, 0.05, 0.6), "Fixtures", BOTH)
		_lantern(d, Vector3(x, 5.1, face + 0.6), 0.3)
		_pool(d, Vector3(x, 0.0, face + 2.5), 3.0)
	# The hearth, on the back wall under the balcony.
	var h := Vector3(0, 0, NORTH + 0.6)
	d.box("stone", h + Vector3(0, 1.6, 0), Vector3(5.0, 3.2, 1.2), "Build", BOTH)
	d.box("stone", h + Vector3(0, 3.35, 0.1), Vector3(5.6, 0.3, 1.5), "Build", BOTH)
	d.box("black", h + Vector3(0, 0.9, 0.61), Vector3(3.0, 1.6, 0.02), "Build", BOTH)
	_fire(d, h + Vector3(0, 0.1, 0.4), 1.0)
	_lamp(kit, d, "HallHearth", h + Vector3(0, 1.2, 2.0), 18.0, 3.4, false, 0.3, 11.0)
	_glow(d, h + Vector3(0, 0.03, 3.4), Vector3(3.4, 0, 0), Vector3(0, 0, -3.4))
	# Rings of candles hanging from the roof either side of the skylight.
	for rx: float in [-10.0, 10.0]:
		var ring := Vector3(rx, 7.0, -22.0)
		d.torus("dark_metal", ring, 1.4, 0.06, Basis.IDENTITY, 20, 6, "Fixtures", BOTH)
		for k in 4:
			var a := TAU * k / 4.0
			d.tube("dark_metal", ring + Vector3(cos(a), 0, sin(a)) * 1.4, ring + Vector3(0, 1.4, 0), 0.02, 4, "Fixtures", BOTH)
		d.tube("dark_metal", ring + Vector3(0, 1.4, 0), Vector3(rx, 9.0, -22.0), 0.03, 4, "Fixtures", BOTH)
		for k in 10:
			var a := TAU * k / 10.0
			var c := ring + Vector3(cos(a), 0, sin(a)) * 1.4
			d.tube("white_wax", c, c + Vector3(0, 0.22, 0), 0.035, 6, "Fixtures", BOTH)
			var f := c + Vector3(0, 0.22, 0)
			d.quad("flame_small", f + Vector3(-0.08, 0.26, 0), f + Vector3(0.08, 0.26, 0), f + Vector3(0.08, 0, 0), f + Vector3(-0.08, 0, 0), "Effects", BOTH)
			d.quad("flame_small", f + Vector3(0, 0.26, -0.08), f + Vector3(0, 0.26, 0.08), f + Vector3(0, 0, 0.08), f + Vector3(0, 0, -0.08), "Effects", BOTH)
		_pool(d, Vector3(rx, 0.0, -22.0), 4.0, true)
	for rx: float in [-10.0, 10.0]:
		_lamp(kit, d, "HallCandles%d" % int(rx), Vector3(rx, 6.6, -22.0), 12.0, 2.0, true, 0.1, rx)
	# The long rug down the middle, banners on the walls.
	d.box("rug", Vector3(0, 0.03, -21.0), Vector3(3.0, 0.01, 12.0), "Detail", BOTH)
	for x: float in [-12.0, 12.0]:
		_banner(d, Vector3(x, 8.4, NORTH + 0.1), Vector3(0, 0, 1), 1.6, 3.2, "gold_cloth")
	# Fir trees in the planters, lights in them.
	for x: float in [-7.0, 7.0]:
		_fir(d, Vector3(x, 1.1, -20.0), 3.2, 17 + int(x))


## A fir tree: tiers of green, snow on each, a string of lights round it.
static func _fir(d, at: Vector3, height: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	d.tube("wood", at, at + Vector3(0, height * 0.3, 0), height * 0.04, 6, "Detail", BOTH)
	for k in 4:
		var y := height * (0.18 + k * 0.2)
		var r := height * (0.34 - k * 0.07)
		_cone(d, "evergreen", at + Vector3(0, y, 0), r, height * 0.34)
		_cone(d, "snow_cap", at + Vector3(0, y + height * 0.12, 0), r * 0.55, height * 0.22)
	for k in 26:
		var t := float(k) / 26.0
		var a := t * TAU * 4.0
		var r := height * 0.34 * (1.0 - t * 0.85)
		d.ball("bulb", at + Vector3(cos(a) * r, height * (0.2 + t * 0.75), sin(a) * r), Vector3(0.045, 0.045, 0.045), 2, 4, "Fixtures", BOTH)


## A cone standing on `at`, `radius` round, `height` tall.
static func _cone(d, material: String, at: Vector3, radius: float, height: float) -> void:
	var sides := 8
	var tip := at + Vector3(0, height, 0)
	for s in sides:
		var a0 := TAU * s / sides
		var a1 := TAU * (s + 1) / sides
		var p0 := at + Vector3(cos(a0), 0, sin(a0)) * radius
		var p1 := at + Vector3(cos(a1), 0, sin(a1)) * radius
		d.quad(material, tip, tip, p0, p1, "Detail", BOTH)
		d.quad(material, tip, tip, p1, p0, "Detail", BOTH)


## A banner hanging from a pole on a wall facing `n`: `width` wide,
## `length` long, a notched end.
static func _banner(d, top: Vector3, n: Vector3, width: float, length: float, material: String) -> void:
	var b := DecoKit.facing(n)
	d.tube("wood", top + b.x * (width * 0.5 + 0.15) + n * 0.12, top - b.x * (width * 0.5 + 0.15) + n * 0.12, 0.04, 6, "Build", BOTH)
	var c := top - Vector3(0, length * 0.5 - 0.05, 0) + n * 0.12
	d.box(material, c, Vector3(width, length, 0.02), "Build", BOTH, b)
	d.box("gold_cloth", c + n * 0.012 - Vector3(0, length * 0.15, 0), Vector3(width * 0.8, 0.12, 0.01), "Build", BOTH, b)
	d.box("gold_cloth", c + n * 0.012 + Vector3(0, length * 0.3, 0), Vector3(width * 0.8, 0.08, 0.01), "Build", BOTH, b)


## The Plaza: the fountain frozen, ice in its basin, the spouts' water
## hanging off the plinth in icicles round the rifle; lamps at its corners.
static func _plaza(kit, d) -> void:
	d.box("canal_ice", Vector3(0, 0.03, 3.0), Vector3(9.0, 0.02, 9.0), "Detail", BOTH)
	var rng := RandomNumberGenerator.new()
	rng.seed = 919
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	# Frozen spouts: the ice hanging off the plinth's top edges, a mound of
	# it round its foot.
	for side in 4:
		var n: Vector3 = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)][side]
		var along := Vector3(n.z, 0, n.x)
		for k in 9:
			var p := Vector3(0, 2.2, 3.0) + n * 1.05 + along * (k - 4) * 0.24
			var l := rng.randf_range(0.4, 1.9)
			_spike(st, p, p + Vector3(0, -l, 0) + n * 0.1, 0.07 + l * 0.05, 5, rng)
		for k in 4:
			var p := Vector3(0, 0, 3.0) + n * rng.randf_range(1.2, 1.8) + along * rng.randf_range(-1.2, 1.2)
			_spike(st, p - Vector3(0, 0.2, 0), p + Vector3(0, rng.randf_range(0.3, 0.8), 0), rng.randf_range(0.15, 0.3), 6, rng)
	st.generate_normals()
	var mesh := st.commit()
	ResourceSaver.save(mesh, d.dir + "meshes/fountain.res")
	d.own_mesh("Fountain", load(d.dir + "meshes/fountain.res"), d.mat("icicle"), Transform3D.IDENTITY, "Build")
	for c: Vector2 in [Vector2(-6.4, -3.4), Vector2(6.4, -3.4), Vector2(-6.4, 9.4), Vector2(6.4, 9.4)]:
		_lamp_post(kit, d, Vector3(c.x, 0, c.y), "Plaza%d%d" % [int(c.x), int(c.y)])


## A lamp post: an iron post on a stone foot, a lantern on top, snow on
## its hat, its pool on the ground.
static func _lamp_post(kit, d, at: Vector3, name: String, height := 3.4) -> void:
	d.box("stone", at + Vector3(0, 0.2, 0), Vector3(0.5, 0.4, 0.5), "Detail", BOTH)
	d.tube("dark_metal", at + Vector3(0, 0.4, 0), at + Vector3(0, height, 0), 0.07, 8, "Detail", BOTH)
	d.torus("dark_metal", at + Vector3(0, height - 0.1, 0), 0.12, 0.03, Basis.IDENTITY, 10, 4, "Detail", BOTH)
	_lantern(d, at + Vector3(0, height + 0.3, 0), 0.34)
	d.ball("snow_cap", at + Vector3(0, height + 0.66, 0), Vector3(0.2, 0.08, 0.2), 2, 6, "Detail", BOTH)
	_pool(d, at, 3.8)
	_lamp(kit, d, name, at + Vector3(0, height + 0.1, 0), 10.0, 2.0, true, 0.08, at.x + at.z)


## Lamp posts along the street's south side, at the bridges and along the
## walkway.
static func _street_lamps(kit, d, side: float) -> void:
	for c: Vector2 in [Vector2(15.0, 13.2), Vector2(46.0, 13.2), Vector2(4.0, 19.6), Vector2(33.0, 19.6), Vector2(39.0, 30.4),
			Vector2(12.0, 37.2), Vector2(30.0, 37.2), Vector2(54.0, 37.2)]:
		_lamp_post(kit, d, _at(side, Vector3(c.x, 0, c.y)), "Post%s%d%d" % ["W" if side < 0.0 else "E", int(c.x), int(c.y)])


## A string of bulbs slung from `a` to `b`, sagging `sag` in the middle:
## the wire, the bulbs on their drops, and `lights` lamps along it, soft
## and wide, lighting everything under it (the village's light is these),
## each with its pool on the ground at `ground`.
static func _string(kit, d, a: Vector3, b: Vector3, sag: float, name: String, lights: int, ground: float) -> void:
	var count := maxi(6, int(a.distance_to(b) / 0.6))
	var pts := PackedVector3Array()
	for k in count + 1:
		var t := float(k) / count
		pts.append(a.lerp(b, t) + Vector3(0, -sin(t * PI) * sag, 0))
	d.path_tube("dark_metal", pts, 0.012, 3, "Fixtures", BOTH)
	for k in range(1, count):
		d.tube("dark_metal", pts[k], pts[k] + Vector3(0, -0.06, 0), 0.015, 4, "Fixtures", BOTH)
		d.ball("bulb", pts[k] + Vector3(0, -0.13, 0), Vector3(0.075, 0.1, 0.075), 2, 6, "Fixtures", BOTH)
	for k in lights:
		var t := (k + 0.5) / lights
		var at := a.lerp(b, t) + Vector3(0, -sin(t * PI) * sag - 0.4, 0)
		var l := _lamp(kit, d, "%s_%d" % [name, k], at, 13.0, 1.3, k > 0, 0.0, 0.0, BULB)
		l.omni_attenuation = 0.8
		_pool(d, Vector3(at.x, ground, at.z), 4.0)


## Strings of bulbs everywhere, and their light is the village's: across
## the street from the Arcade's eaves to the kiosks' roofs, along the
## walkway, over the canal, from each gate across its yard.
static func _festoons(kit, d, side: float) -> void:
	var tag := "W" if side < 0.0 else "E"
	# [from, to, sag, lamps, the ground under it]
	var spans := [[Vector3(23.5, 8.8, -13.7), Vector3(18.0, 3.95, 13.9), 1.4, 2, 0.0],
			[Vector3(23.5, 8.8, -13.7), Vector3(34.0, 3.95, 13.9), 1.4, 2, 0.0],
			[Vector3(35.2, 8.8, -13.7), Vector3(42.0, 3.95, 13.9), 1.4, 2, 0.0],
			[Vector3(46.5, 8.8, -13.7), Vector3(50.0, 3.95, 13.9), 1.4, 2, 0.0],
			[Vector3(12.0, 3.6, 37.2), Vector3(30.0, 3.6, 37.2), 0.7, 1, 0.0],
			[Vector3(30.0, 3.6, 37.2), Vector3(54.0, 3.6, 37.2), 0.8, 2, 0.0],
			[Vector3(33.0, 3.6, 19.6), Vector3(30.0, 3.6, 37.2), 0.8, 1, -3.5],
			[Vector3(4.0, 3.6, 19.6), Vector3(12.0, 3.6, 37.2), 0.8, 1, -3.5],
			[Vector3(58.9, 6.9, -9.0), Vector3(71.2, 5.9, -22.0), 1.2, 2, 0.0],
			[Vector3(58.9, 6.9, -9.0), Vector3(71.2, 5.9, 2.0), 1.2, 2, 0.0],
			[Vector3(58.9, 6.9, 9.0), Vector3(71.2, 5.9, 26.0), 1.2, 2, 0.0]]
	for i in spans.size():
		var sp: Array = spans[i]
		_string(kit, d, _at(side, sp[0]), _at(side, sp[1]), sp[2], "String%s%d" % [tag, i], sp[3], sp[4])


## The strings in the middle: crossed over the Plaza from the hall's front
## to the lamp posts, down the hall inside, along the walkway.
static func _middle_strings(kit, d) -> void:
	for e: float in [-1.0, 1.0]:
		_string(kit, d, Vector3(10.0 * e, 8.8, -13.7), Vector3(-6.4 * e, 3.8, 9.4), 1.2, "StringPlaza%d" % int(e), 2, 0.0)
		_string(kit, d, Vector3(12.0 * e, 8.7, -14.4), Vector3(12.0 * e, 8.7, -33.6), 0.6, "StringHall%d" % int(e), 1, 0.0)
	_string(kit, d, Vector3(-12.0, 3.6, 37.2), Vector3(12.0, 3.6, 37.2), 0.8, "StringWalkway", 1, 0.0)


## The kiosks: A the woodshed, C the boathouse where the skates and the
## ice-saws are kept, B between them the café, lit, a counter, cocoa.
static func _kiosks(kit, d, side: float) -> void:
	var tag := "W" if side < 0.0 else "E"
	var face := 13.94
	var n := Vector3(0, 0, -1)
	var b := DecoKit.facing(n)
	# Eaves along each roof's front: a board, snow over it.
	for k: Array in [[16.0, 28.0], [32.0, 44.0], [48.0, 56.0]]:
		var c := _at(side, Vector3((float(k[0]) + float(k[1])) * 0.5, 3.9, face - 0.05))
		d.box("wood", c, Vector3(float(k[1]) - float(k[0]) + 0.3, 0.24, 0.12), "Build", BOTH)
		d.box("snow_cap", c + Vector3(0, 0.2, 0.3), Vector3(float(k[1]) - float(k[0]) + 0.2, 0.16, 0.8), "Detail", BOTH)
	Signs.board(d, _at(side, Vector3(22.0, 3.2, face - 0.04)), b, Vector2(2.6, 0.5), "board", "Woodshed", ITALIC, 0.28,
			Color(1.0, 0.9, 0.7), "wood")
	Signs.board(d, _at(side, Vector3(52.0, 3.2, face - 0.04)), b, Vector2(2.6, 0.5), "board", "Boathouse", ITALIC, 0.28,
			Color(1.0, 0.9, 0.7), "wood")
	Signs.board(d, _at(side, Vector3(38.0, 3.2, face - 0.24)), b, Vector2(3.4, 0.55), "board", "Cocoa & Cake", ITALIC, 0.3,
			Color(1.0, 0.86, 0.6), "wood")
	# The boathouse's skates and saws on its wall.
	for k in 3:
		var p := _at(side, Vector3(49.0 + k * 0.6, 2.0, face - 0.02))
		d.box("dark_metal", p, Vector3(0.05, 0.36, 0.05), "Detail", BOTH)
		d.box("black", p + Vector3(0.0, -0.22, -0.05), Vector3(0.12, 0.1, 0.3), "Detail", BOTH)
	d.box("dark_metal", _at(side, Vector3(54.0, 1.8, face - 0.02)), Vector3(0.9, 0.12, 0.02), "Detail", BOTH, Basis(Vector3(0, 0, 1), 0.3))
	# Lanterns by the doors and on the sheds' fronts.
	for lx: float in [17.2, 26.8, 36.5, 39.9, 49.2, 54.8]:
		var at := _at(side, Vector3(lx, 2.6, face - 0.35))
		d.box("dark_metal", _at(side, Vector3(lx, 2.95, face - 0.18)), Vector3(0.05, 0.05, 0.36), "Fixtures", BOTH)
		_lantern(d, at, 0.24)
		_pool(d, _at(side, Vector3(lx, 0, face - 1.4)), 3.0)
		_glow(d, _at(side, Vector3(lx, 2.4, face - 0.01)), Vector3(2.2, 0, 0), Vector3(0, 2.2, 0))
		if lx in [17.2, 36.5, 54.8]:
			_lamp(kit, d, "Kiosk%s%d" % [tag, int(lx)], at + Vector3(0, 0, -0.3), 9.0, 1.8, true, 0.12, lx * side)
	# The sheds' windows lit.
	for wx: float in [18.6, 25.4, 52.0]:
		_lit_window(d, _at(side, Vector3(wx, 1.9, face - 0.02)), n, 1.4, 1.0)
	# The café: lamps inside, a counter at the back, its windows lit.
	d.box("board", _at(side, Vector3(38.0, 0.55, 19.2)), Vector3(8.0, 1.1, 0.8), "Build", BOTH)
	d.box("wood", _at(side, Vector3(38.0, 1.12, 19.1)), Vector3(8.2, 0.06, 1.0), "Build", BOTH)
	for k in 5:
		d.tube("white_wax", _at(side, Vector3(35.0 + k * 1.5, 1.15, 19.0)), _at(side, Vector3(35.0 + k * 1.5, 1.3, 19.0)), 0.05, 6, "Detail", BOTH)
	for x: float in [35.0, 41.0]:
		var at := _at(side, Vector3(x, 2.8, 17.0))
		d.box("dark_metal", at + Vector3(0, 0.45, 0), Vector3(0.02, 0.7, 0.02), "Fixtures", BOTH)
		_lantern(d, at, 0.26)
		_pool(d, _at(side, Vector3(x, 0.0, 17.0)), 2.6)
	_lamp(kit, d, "Cafe" + tag, _at(side, Vector3(38.0, 2.6, 17.0)), 11.0, 2.8, false, 0.1, side * 5.0)
	for wx: float in [34.75, 41.75]:
		d.box("wood", _at(side, Vector3(wx, 2.52, face - 0.04)), Vector3(2.8, 0.14, 0.1), "Build", BOTH)
		d.box("snow_cap", _at(side, Vector3(wx, 1.14, face - 0.1)), Vector3(2.7, 0.06, 0.2), "Detail", BOTH)
		_glow(d, _at(side, Vector3(wx, 0.03, face - 1.2)), Vector3(1.6, 0, 0), Vector3(0, 0, -1.2))
	# The shelter: a chestnut stall, its brazier roasting.
	d.box("snow_cap", _at(side, Vector3(31.0, 3.0, 10.0)), Vector3(6.1, 0.14, 2.1), "Detail", BOTH)
	d.box("board", _at(side, Vector3(31.0, 0.5, 10.1)), Vector3(3.0, 1.0, 0.7), "Detail", BOTH)
	Signs.board(d, _at(side, Vector3(31.0, 2.3, 10.58)), b, Vector2(2.8, 0.4), "board", "Hot Chestnuts", ITALIC, 0.22,
			Color(1.0, 0.9, 0.7), "wood")
	_brazier(kit, d, _at(side, Vector3(33.4, 0, 9.7)), "Chestnuts" + tag, 0.6, false)
	for bx: float in [19.0, 25.0, 51.0]:
		_bench(d, _at(side, Vector3(bx, 0, 13.95)), Vector3(0, 0, -1))


## An iron brazier on three legs, a fire in it, smoke off it.
static func _brazier(kit, d, at: Vector3, name: String, size := 0.9, solid := true) -> void:
	if solid:
		d.solid(at + Vector3(0, 0.55, 0), Vector3(size, 1.1, size))
	for k in 3:
		var a := TAU * k / 3.0
		d.tube("dark_metal", at + Vector3(cos(a), 0, sin(a)) * size * 0.45, at + Vector3(0, 0.8, 0) + Vector3(cos(a), 0, sin(a)) * size * 0.3,
				0.03, 4, "Solid" if solid else "Detail", BOTH)
	d.ball("dark_metal", at + Vector3(0, 0.95, 0), Vector3(size * 0.5, size * 0.25, size * 0.5), 3, 10, "Solid" if solid else "Detail", BOTH)
	_fire(d, at + Vector3(0, 1.05, 0), size * 0.7)
	_lamp(kit, d, name, at + Vector3(0, 1.8, 0), 10.0 + size * 3.0, 2.8, false, 0.35, at.x + at.z)
	_pool(d, at, 3.0 + size * 2.5, true)


## The sleds on the street: a load under canvas lashed down, runners
## curling up at the front, snow on the canvas.
static func _sleds(d, side: float) -> void:
	for c: Array in [[20.0, -5.5], [36.0, 2.5], [48.0, -4.0]]:
		var x0: float = c[0]
		var z0: float = c[1]
		var mid := _at(side, Vector3(x0 + 2.25, 0, z0 + 1.0))
		var front := side
		for e: float in [-1.0, 1.0]:
			var z := z0 + 1.0 + e * 0.95
			d.box("wood", _at(side, Vector3(x0 + 2.25, 0.05, z)), Vector3(4.6, 0.1, 0.12), "Build", BOTH)
			var pts := PackedVector3Array()
			for k in 7:
				var a := PI * 0.5 * k / 6.0
				pts.append(_at(side, Vector3(x0 + 4.55 + sin(a) * 0.5, 0.05 + (1.0 - cos(a)) * 0.5 + (0.3 if k == 6 else 0.0), z)))
			d.path_tube("dark_metal", pts, 0.04, 5, "Build", BOTH)
			for k in 4:
				d.box("wood", _at(side, Vector3(x0 + 0.5 + k * 1.2, 0.2, z)), Vector3(0.1, 0.3, 0.1), "Build", BOTH)
		for k in 3:
			d.box("black", mid + Vector3((k - 1) * 1.3 * front, 0.76, 0), Vector3(0.05, 1.54, 2.04), "Detail", BOTH)
		d.box("snow_cap", mid + Vector3(0.3 * front, 1.53, 0.1), Vector3(2.8, 0.08, 1.6), "Detail", BOTH)


## The gate between the street and the yard: great log posts either side of
## the way through, a beam over it, a roof along the wall's top with snow
## on it, the village's name over the way on the street side, the team's
## banners on the yard side, lanterns.
static func _gate(kit, d, side: float) -> void:
	var tag := "W" if side < 0.0 else "E"
	var x := 58.5
	for z: float in [-4.55, 4.55]:
		d.tube("wood", _at(side, Vector3(x, 0, z)), _at(side, Vector3(x, 7.9, z)), 0.55, 8, "Build", BOTH)
	d.box("wood", _at(side, Vector3(x, 4.8, 0)), Vector3(1.2, 0.6, 9.4), "Build", BOTH)
	# The roof along the top: two slopes and snow.
	for e: float in [-1.0, 1.0]:
		var ridge := _at(side, Vector3(x, 8.3, 0))
		var eave := _at(side, Vector3(x + e * 1.4, 7.0, 0))
		d.quad("shingle_roof", ridge + Vector3(0, 0, -13.4), ridge + Vector3(0, 0, 13.4), eave + Vector3(0, 0, 13.4), eave + Vector3(0, 0, -13.4), "Build", BOTH)
		d.quad("shingle_roof", eave + Vector3(0, 0, -13.4), eave + Vector3(0, 0, 13.4), ridge + Vector3(0, 0, 13.4), ridge + Vector3(0, 0, -13.4), "Build", BOTH)
		d.box("snow_cap", (ridge + eave) * 0.5 + Vector3(0, 0.12, 0), Vector3(0.12, 0.14, 26.6), "Detail", BOTH,
				Basis(Vector3(0, 0, 1), atan2(1.3, e * 1.4 * side)))
	var street := DecoKit.facing(Vector3(-side, 0, 0))
	Signs.board(d, _at(side, Vector3(x - 0.5, 5.6, 0)), street, Vector2(5.6, 0.9), "board", "Rimehollow", ITALIC, 0.6,
			Color(1.0, 0.86, 0.5), "wood")
	var yard_n := Vector3(side, 0, 0)
	for z: float in [-8.0, 8.0]:
		_banner(d, _at(side, Vector3(x + 0.45, 6.6, z)), yard_n, 2.0, 4.6, "blue_cloth" if side > 0.0 else "red_cloth")
	for z: float in [-5.2, 5.2]:
		for e: float in [-1.0, 1.0]:
			var at := _at(side, Vector3(x + e * 0.9, 3.4, z))
			d.box("dark_metal", _at(side, Vector3(x + e * 0.6, 3.75, z)), Vector3(0.6, 0.05, 0.05), "Fixtures", BOTH)
			_lantern(d, at, 0.32)
			_pool(d, _at(side, Vector3(x + e * 2.0, 0, z)), 2.8)
	_lamp(kit, d, "Gate" + tag, _at(side, Vector3(x - 1.2, 3.4, 0)), 13.0, 2.4, false, 0.12, side * 9.0)
	_lamp(kit, d, "GateYard" + tag, _at(side, Vector3(x + 1.2, 3.4, 0)), 13.0, 2.2, true, 0.12, side * 13.0)
	# Its windows lit, up over the way through, on the street side.
	for z: float in [-9.0, 9.0]:
		_lit_window(d, _at(side, Vector3(x - 0.42, 5.6, z)), Vector3(-side, 0, 0), 1.2, 1.1)


## The team's yard: braziers burning, banners on poles along the back, the
## crates stencilled.
static func _yard(kit, d, side: float) -> void:
	var tag := "W" if side < 0.0 else "E"
	var cloth := "blue_cloth" if side > 0.0 else "red_cloth"
	_brazier(kit, d, _at(side, Vector3(61.5, 0, -8.5)), "BrazierN" + tag)
	_brazier(kit, d, _at(side, Vector3(65.5, 0, 20.5)), "BrazierS" + tag)
	for z: float in [-22.0, 2.0, 26.0]:
		var p := _at(side, Vector3(71.2, 0, z))
		d.tube("wood", p, p + Vector3(0, 6.0, 0), 0.08, 6, "Detail", BOTH)
		d.ball("brass", p + Vector3(0, 6.05, 0), Vector3(0.12, 0.12, 0.12), 3, 6, "Detail", BOTH)
		var b := DecoKit.facing(Vector3(-side, 0, 0))
		d.box(cloth, p + Vector3(-side * 0.1, 4.2, 0) + b.x * 0.75, Vector3(1.5, 3.2, 0.02), "Detail", BOTH, b)
		d.box("gold_cloth", p + Vector3(-side * 0.11, 4.9, 0) + b.x * 0.75, Vector3(1.2, 0.12, 0.01), "Detail", BOTH, b)


## The canal: frozen, holes cut in the ice for fishing with a stool by
## each, the bridges' lanterns (_street_lamps()).
static func _canal(kit, d, side: float) -> void:
	for h: Vector2 in [Vector2(14.0, 23.5), Vector2(48.0, 26.5)]:
		var c := _at(side, Vector3(h.x, -3.49, h.y))
		d.ball("black", c, Vector3(0.7, 0.01, 0.7), 2, 12, "Detail", BOTH)
		d.torus("snow_cap", c + Vector3(0, 0.04, 0), 0.78, 0.1, Basis.IDENTITY, 14, 4, "Detail", BOTH)
		d.box("wood", c + Vector3(1.2, 0.25, 0.3), Vector3(0.4, 0.05, 0.4), "Detail", BOTH)
		for k in 3:
			var a := TAU * k / 3.0
			d.tube("wood", c + Vector3(1.2, 0.25, 0.3), c + Vector3(1.2 + cos(a) * 0.2, 0, 0.3 + sin(a) * 0.2), 0.02, 4, "Detail", BOTH)
		d.tube("wood", c + Vector3(0.9, 0.1, 0.1), c + Vector3(0.1, 0.9, 0.1), 0.015, 4, "Detail", BOTH)


## Whether (x, z) is in or just in front of a way through: the Arcade's
## doors, the café's, the gate.
static func _in_a_doorway(p: Vector3) -> bool:
	var x := absf(p.x)
	if absf(p.z + 13.8) < 2.0:
		for o: Array in DOORS:
			if x > 16.0 + float(o[0]) - 1.2 and x < 16.0 + float(o[0]) + float(o[2]) + 1.2:
				return true
	if absf(p.z - 14.0) < 2.0 and x > 36.0 and x < 40.4:
		return true
	return absf(x - 58.5) < 2.5 and absf(p.z) < 5.5


## Snow drifted against the walls: along the Arcade's front and the
## kiosks', round the gate, in the yards' corners.
static func _drifts(d) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var runs := []
	for side: float in [-1.0, 1.0]:
		runs.append([_at(side, Vector3(16.5, 0, -13.5)), _at(side, Vector3(55.5, 0, -13.5))])
		runs.append([_at(side, Vector3(16.5, 0, 13.6)), _at(side, Vector3(55.5, 0, 13.6))])
		runs.append([_at(side, Vector3(58.0, 0, -11.5)), _at(side, Vector3(58.0, 0, 13.5))])
		runs.append([_at(side, Vector3(71.0, 0, -33.0)), _at(side, Vector3(71.0, 0, 37.0))])
		runs.append([_at(side, Vector3(2.0, 0, 37.2)), _at(side, Vector3(70.0, 0, 37.2))])
	for run: Array in runs:
		var a: Vector3 = run[0]
		var b: Vector3 = run[1]
		var along := a.distance_to(b)
		var x := 0.0
		while x < along:
			x += rng.randf_range(1.0, 3.0)
			var p := a.lerp(b, x / along)
			if _in_a_doorway(p):
				continue
			var r := rng.randf_range(0.5, 1.3)
			d.ball("snow_cap", p, Vector3(r, r * rng.randf_range(0.25, 0.45), r * 0.7), 3, 8, "Detail", BOTH)



## Smoke going up from a chimney: grey puffs, slow, growing, fading,
## drifting a little.
static func _smoke(d, at: Vector3, seed_value: float) -> void:
	var p := CPUParticles3D.new()
	p.name = "Smoke_%d" % int(absf(at.x) * 10.0 + at.z)
	p.position = at
	p.amount = 18
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.randomness = 0.5
	p.seed = int(absf(seed_value) * 97.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.0
	p.gravity = Vector3(0.12, 0.05, 0.04)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 3.2))
	p.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	fade.add_point(0.15, Color(1, 1, 1, 0.55))
	fade.add_point(0.6, Color(1, 1, 1, 0.3))
	p.color_ramp = fade
	var q := QuadMesh.new()
	q.material = d.shaded("smoke", "res://src/render/deco/smoke.gdshader", {})
	p.mesh = q
	d.group("Effects").add_child(p)





## A table with a bench each side (solid), a candle and mugs on it.
static func _table(d, at: Vector3, side: float) -> void:
	d.solid(at + Vector3(0, 0.4, 0), Vector3(2.6, 0.8, 1.9))
	d.box("wood", at + Vector3(0, 0.76, 0), Vector3(2.6, 0.08, 0.9), "Solid", BOTH)
	for e: float in [-1.0, 1.0]:
		d.box("wood", at + Vector3(e * 1.1, 0.36, 0), Vector3(0.1, 0.72, 0.7), "Solid", BOTH)
		d.box("wood", at + Vector3(0, 0.44, e * 0.78), Vector3(2.4, 0.07, 0.32), "Solid", BOTH)
		d.box("wood", at + Vector3(0, 0.2, e * 0.78), Vector3(2.2, 0.4, 0.08), "Solid", BOTH)
	d.tube("white_wax", at + Vector3(0, 0.8, 0), at + Vector3(0, 0.98, 0), 0.03, 6, "Detail", BOTH)
	var f := at + Vector3(0, 0.98, 0)
	d.quad("flame_small", f + Vector3(-0.06, 0.2, 0), f + Vector3(0.06, 0.2, 0), f + Vector3(0.06, 0, 0), f + Vector3(-0.06, 0, 0), "Effects", BOTH)
	for k in 3:
		d.tube("paint_%d" % k, at + Vector3(-0.8 + k * 0.7 * side, 0.8, 0.2 - k * 0.15), at + Vector3(-0.8 + k * 0.7 * side, 0.92, 0.2 - k * 0.15),
				0.05, 6, "Detail", BOTH)


## A bench against a wall facing `n`: slats and iron ends (solid).
static func _bench(d, at: Vector3, n: Vector3) -> void:
	var b := DecoKit.facing(n)
	d.solid(at + Vector3(0, 0.45, 0) + n * 0.25, Vector3(1.9, 0.9, 0.55) if absf(n.z) > 0.5 else Vector3(0.55, 0.9, 1.9))
	for e: float in [-0.85, 0.85]:
		d.box("dark_metal", at + b.x * e + Vector3(0, 0.4, 0) + n * 0.25, Vector3(0.05, 0.8, 0.5), "Solid", BOTH, b)
	for k in 3:
		d.box("wood", at + Vector3(0, 0.45, 0) + n * (0.1 + k * 0.14), Vector3(1.8, 0.04, 0.1), "Solid", BOTH, b)
	d.box("wood", at + Vector3(0, 0.75, 0) + n * 0.05, Vector3(1.8, 0.24, 0.04), "Solid", BOTH, b)
	d.box("snow_cap", at + Vector3(0, 0.49, 0) + n * 0.25, Vector3(1.5, 0.04, 0.35), "Detail", BOTH, b)


## The street's and the walkway's tops, and the canal's quays under them,
## drawn in tiles 24 metres long (the blocks themselves are hidden): a
## block the length of the map would only be lit by the sixteen lamps
## nearest its middle, a tile by its own.
static func _ground_tiles(d) -> void:
	for i in 6:
		var x0 := WEST + i * 24.0
		var cx := x0 + 12.0
		for j in 3:
			var z0 := NORTH + j * 18.0
			d.zone = "Street%d%d" % [i, j]
			d.box("street", Vector3(cx, -0.25, z0 + 9.0), Vector3(24.0, 0.5, 18.0), "Build", BOTH)
		d.zone = "Walkway%d" % i
		d.box("walkway", Vector3(cx, -0.25, 34.0), Vector3(24.0, 0.5, 8.0), "Build", BOTH)
		# The quays down to the canal's ice, north and south (the canal's
		# ends are the yards' blocks).
		var from := maxf(x0, -58.0)
		var to := minf(x0 + 24.0, 58.0)
		if to > from:
			d.zone = "Street%d2" % i
			d.box("street", Vector3((from + to) * 0.5, -1.9, 19.85), Vector3(to - from, 3.2, 0.3), "Build", BOTH)
			d.zone = "Walkway%d" % i
			d.box("walkway", Vector3((from + to) * 0.5, -1.9, 30.15), Vector3(to - from, 3.2, 0.3), "Build", BOTH)
	d.zone = ""



## A window lit from inside on a wall facing `n`: the glow, a frame, the
## glazing bars, a sill with snow on it, its light on the ground.
static func _lit_window(d, c: Vector3, n: Vector3, w: float, h: float) -> void:
	var b := DecoKit.facing(n)
	d.box("window_warm", c, Vector3(w, h, 0.02), "Fixtures", BOTH, b)
	for e: float in [-1.0, 1.0]:
		d.box("wood", c + b.x * e * (w * 0.5 + 0.05) + n * 0.03, Vector3(0.1, h + 0.2, 0.08), "Build", BOTH, b)
		d.box("wood", c + b.y * e * (h * 0.5 + 0.05) + n * 0.03, Vector3(w + 0.2, 0.1, 0.08), "Build", BOTH, b)
	d.box("wood", c + n * 0.03, Vector3(0.05, h, 0.04), "Build", BOTH, b)
	d.box("wood", c + n * 0.03, Vector3(w, 0.05, 0.04), "Build", BOTH, b)
	d.box("snow_cap", c - b.y * (h * 0.5 + 0.12) + n * 0.12, Vector3(w + 0.3, 0.08, 0.22), "Detail", BOTH, b)
	_glow(d, Vector3(c.x, 0.03, c.z) + n * 1.8, Vector3(1.8, 0, 0), Vector3(0, 0, -1.6))
