extends RefCounted
## SWITCHBACK, dressed (GDD §9.3): Cloudside Parking, the car park that
## never reaches the top, at dusk.
##
## The four levels are the open decks of a car park stepping down a hill,
## painted Level 1 at the Bottom up to Level 4 at the Summit, each its own
## colour (Cherry, Lemon, Mint, Sky) on its walls, its huts and its signs,
## so you always know which one you're on. The hairpins are the car ramps
## between them, grooved, arrows up them, a convex mirror at each turn. The
## cliffs are the retaining walls, their tiles the wall-ride tiles as on
## every map; bays are painted along the foot of each. The huts are the
## pay booths and the lift and stair cores, the tunnel through each a low
## passage under a lintel striped in hazard paint (MAX HEADROOM 1.2 m). The
## Ladder's crates are utility cabinets (DO NOT CLIMB). The Overlook is a
## plinth of chequer plate on the top deck, the lift and stair heads either
## side of it, one last car under a cover in a bay, and over the back wall
## the car park's blue P.
##
## Sodium floodlights on the walls light it all orange against the blue:
## the sun has just gone behind the hill, and the sky is dusk all round.
## Over the back wall the hill climbs on, and on top of it the car park
## carries on up as a spiral tower, its decks lit, until they're lost in the
## sky (a sign on the top deck: Levels 5 – ∞, closed). Over the front wall,
## far below, the city's lights are coming on. The gameplay blocks are
## untouched, only dressed.

const DecoKit := preload("res://tools/deco_kit.gd")
const Signs := preload("res://tools/sign_kit.gd")
## Typefaces (assets/fonts/): the car park's signs, stencils, a note.
const SANS := "DejaVuSans-Bold.ttf"
const PLAIN := "LiberationSans-Regular.ttf"
const STENCIL := "LiberationMono-Bold.ttf"
const HAND := "LiberationSerif-Italic.ttf"
const SWASH := "LiberationSerif-BoldItalic.ttf"
const BOTH := DecoKit.LAYER_BOTH

const SODIUM := Color(1.0, 0.64, 0.32)
const GLOW := "res://src/render/deco/glow.gdshader"
const PUDDLE := "res://src/render/deco/puddle.gdshader"
const FAR := "res://src/render/deco/far_surface.gdshader"

## The levels, painted 1 at the bottom to 4 at the top: [number, floor
## height, z band (the back wall, the edge), the deck's x span, colour, name,
## the way traffic runs along it (up the car park: +1 east, -1 west)].
const LEVELS := [
	[1, 0.0, Vector2(2, 12), Vector2(-32, 18), Color(0.86, 0.14, 0.30), "Cherry", 1.0],
	[2, 4.0, Vector2(-8, 2), Vector2(-18, 32), Color(1.0, 0.72, 0.06), "Lemon", -1.0],
	[3, 8.0, Vector2(-18, -8), Vector2(-32, 18), Color(0.10, 0.70, 0.44), "Mint", 1.0],
	[4, 12.0, Vector2(-28, -18), Vector2(-32, 32), Color(0.16, 0.46, 0.96), "Sky", -1.0],
]
## Huts: [x, which level (index into LEVELS)].
const HUTS := [[-12.0, 2], [8.0, 1], [-12.0, 0]]
## The Ladder's crates: [the middle of the foot, which level].
const CABINETS := [[Vector3(-6, 0, 3), 0], [Vector3(0, 4, -7), 1], [Vector3(6, 8, -17), 2]]
## The hairpin ramps: [the foot's x, the top's x, floor at the foot, z band].
const RAMPS := [[18.0, 28.0, 8.0, Vector2(-18, -8)], [-18.0, -28.0, 4.0, Vector2(-8, 2)], [18.0, 28.0, 0.0, Vector2(2, 12)]]
## Where each level's number is painted on its back wall (x).
const DISCS := [[-25.0, -1.0, 10.0], [-8.0, 16.0], [-22.0, -2.0, 10.0], [-25.0, 6.0, 22.0]]
## Yellow lines back from the edges you can fall off: [floor, z, x from, x to].
const EDGES := [[4.0, 1.65, -18.0, 28.0], [8.0, -8.35, -28.0, 18.0], [12.0, -18.35, -32.0, 28.0], [12.0, -8.35, 28.0, 32.0],
		[8.0, 1.65, -32.0, -28.0]]
## Where bays aren't painted, per level: x ranges (huts, cabinets, the lift
## heads, pads).
const NO_BAYS := [
	[Vector2(-14.4, -9.6), Vector2(-7.6, -4.4)],
	[Vector2(5.6, 10.4), Vector2(-1.6, 1.6), Vector2(20.4, 23.6)],
	[Vector2(-14.4, -9.6), Vector2(4.4, 7.6)],
	[Vector2(-17.6, -12.4), Vector2(12.4, 17.6)],
]


static func dress(kit, d) -> void:
	_dusk(kit)
	_materials(d)
	_surfaces(kit, d)
	_markings(d)
	_back_walls(d)
	_ramps(d)
	_huts(d)
	_cabinets(d)
	_summit(d)
	_ends(d)
	_front_wall(d)
	_floodlights(d)
	_odds(d)
	_hill_and_tower(d)
	_city(d)


# --- Dusk --------------------------------------------------------------------------------

## The sun just gone behind the hill in the west: deep blue overhead, pink
## and orange low down all round, the first stars. Blue shadow everywhere
## the floodlights don't reach.
static func _dusk(kit) -> void:
	var e: Environment = kit.environment
	var sky: ShaderMaterial = e.sky.sky_material
	sky.set_shader_parameter(&"top_color", Color(0.03, 0.05, 0.15))
	sky.set_shader_parameter(&"upper_color", Color(0.14, 0.19, 0.42))
	sky.set_shader_parameter(&"horizon_color", Color(0.98, 0.56, 0.44))
	sky.set_shader_parameter(&"ground_color", Color(0.06, 0.05, 0.08))
	sky.set_shader_parameter(&"sun_color", Color(1.0, 0.66, 0.42))
	sky.set_shader_parameter(&"sun_size", 0.03)
	sky.set_shader_parameter(&"halo", 0.6)
	sky.set_shader_parameter(&"stars", 0.35)
	e.ambient_light_color = Color(0.42, 0.48, 0.68)
	e.ambient_light_energy = 0.55
	e.fog_light_color = Color(0.30, 0.28, 0.44)
	e.fog_density = 0.004
	e.fog_sky_affect = 0.1
	e.glow_intensity = 0.7
	e.glow_hdr_threshold = 1.0
	e.glow_bloom = 0.0
	var sun: DirectionalLight3D = kit.sun
	# Low in the west-south-west: only the tops of the walls still catch it.
	sun.rotation_degrees = Vector3(-7, -66, 0)
	sun.light_color = Color(1.0, 0.60, 0.46)
	sun.light_energy = 0.7
	sun.light_specular = 0.2
	sun.directional_shadow_max_distance = 80.0


# --- Materials --------------------------------------------------------------------------------

static func _materials(d) -> void:
	d.reflection = load("res://assets/textures/switchback/reflection_dusk.png")
	# The gameplay blocks.
	d.surface("ground", {"side": "switchback/wall", "meters": 4.0, "top": "switchback/deck", "top_meters": 6.0,
			"gloss": 0.18, "grazing": 0.55, "roughness": 0.35, "specular": 0.3})
	d.surface("boundary", {"side": "switchback/wall", "meters": 4.0, "top": "stack/coping", "top_meters": 2.0,
			"gloss": 0.04, "grazing": 0.25, "roughness": 0.8})
	d.surface("retaining", {"side": "ride_tiles", "meters": 2.0, "top": "switchback/deck", "top_meters": 6.0,
			"gloss": 0.3, "grazing": 0.7, "roughness": 0.2})
	d.surface("deck", {"side": "switchback/wall", "meters": 4.0, "top": "switchback/deck", "top_meters": 6.0,
			"gloss": 0.18, "grazing": 0.55, "roughness": 0.35, "specular": 0.3})
	d.surface("ramp", {"side": "switchback/wall", "meters": 4.0, "top": "switchback/ramp", "top_meters": 2.0,
			"gloss": 0.12, "grazing": 0.5, "roughness": 0.45})
	d.surface("hut", {"side": "stack/concrete", "meters": 3.0, "tint": Color(1.25, 1.2, 1.08), "top": "switchback/roof",
			"top_meters": 2.0, "bottom": "stack/ceiling", "bottom_meters": 2.0, "gloss": 0.05, "grazing": 0.3, "roughness": 0.8})
	d.surface("cabinet", {"side": "stack/steel", "meters": 1.0, "tint": Color(0.52, 0.62, 0.56), "top": "tread_plate",
			"top_meters": 1.0, "gloss": 0.3, "grazing": 0.6, "roughness": 0.35})
	d.surface("plinth", {"side": "switchback/wall", "meters": 4.0, "top": "tread_plate", "top_meters": 1.0,
			"gloss": 0.25, "grazing": 0.6, "roughness": 0.3})
	d.surface("head", {"side": "stack/concrete", "meters": 3.0, "tint": Color(1.25, 1.2, 1.08), "top": "switchback/roof",
			"top_meters": 2.0, "gloss": 0.05, "grazing": 0.3, "roughness": 0.8})
	d.surface("parapet", {"side": "switchback/wall", "meters": 4.0, "top": "stack/coping", "top_meters": 2.0,
			"gloss": 0.04, "grazing": 0.25, "roughness": 0.8})
	# Decor (UVs in metres).
	for m: Array in [
			["steel", "stack/steel", 1.0, Color.WHITE, 0.45, 0.8, 0.25],
			["chrome", "stack/steel", 1.0, Color(1.1, 1.1, 1.15), 0.8, 0.95, 0.12],
			["dark_metal", "stack/steel", 1.0, Color(0.26, 0.26, 0.30), 0.25, 0.5, 0.4],
			["black", "stack/steel", 1.0, Color(0.05, 0.05, 0.06), 0.2, 0.5, 0.4],
			["rubber", "stack/steel", 1.0, Color(0.04, 0.04, 0.045), 0.3, 0.55, 0.35],
			["concrete", "switchback/wall", 4.0, Color.WHITE, 0.04, 0.25, 0.8],
			["painted", "stack/concrete", 3.0, Color(1.25, 1.2, 1.08), 0.05, 0.3, 0.8],
			["paint_white", "switchback/paint", 1.0, Color(1.05, 1.05, 1.05), 0.08, 0.35, 0.6],
			["paint_yellow", "switchback/paint", 1.0, Color(1.2, 0.95, 0.25), 0.08, 0.35, 0.6],
			["paint_black", "switchback/paint", 1.0, Color(0.1, 0.1, 0.1), 0.08, 0.35, 0.6],
			["skid", "switchback/paint", 1.0, Color(0.2, 0.2, 0.21), 0.05, 0.3, 0.6],
			["hazard", "hazard", 0.5, Color.WHITE, 0.1, 0.4, 0.5],
			["door_green", "stack/steel", 2.0, Color(0.22, 0.46, 0.34), 0.25, 0.55, 0.35],
			["lift_door", "stack/steel", 1.0, Color(1.05, 1.05, 1.1), 0.55, 0.85, 0.18],
			["red", "stack/steel", 1.0, Color(0.85, 0.12, 0.12), 0.35, 0.6, 0.3],
			["white", "stack/steel", 1.0, Color(1.15, 1.15, 1.15), 0.3, 0.6, 0.3],
			["yellow", "stack/steel", 1.0, Color(1.25, 0.95, 0.15), 0.3, 0.6, 0.3],
			["cone", "stack/steel", 1.0, Color(1.35, 0.42, 0.08), 0.25, 0.5, 0.4],
			["blue_panel", "stack/steel", 1.0, Color(0.15, 0.30, 0.75), 0.3, 0.6, 0.3],
			["cover", "switchback/car_cover", 2.0, Color.WHITE, 0.15, 0.4, 0.5],
			["paper", "terrace/stucco", 4.0, Color(1.3, 1.25, 1.15), 0.02, 0.1, 0.9],
			["shutter", "terrace/shutter", 1.0, Color(0.9, 0.9, 0.95), 0.2, 0.5, 0.4],
			["gravel", "switchback/roof", 2.0, Color.WHITE, 0.02, 0.2, 0.9],
			["glass_dark", "stack/steel", 1.0, Color(0.10, 0.13, 0.16), 0.7, 0.95, 0.1],
			["brass", "stack/steel", 1.0, Color(1.25, 0.92, 0.45), 0.6, 0.9, 0.2],
			["slab_edge", "switchback/wall", 4.0, Color(0.62, 0.62, 0.66), 0.04, 0.25, 0.8]]:
		d.surface(m[0], {"side": m[1], "meters": m[2], "tint": m[3], "gloss": m[4], "grazing": m[5], "roughness": m[6], "uv": true})
	for l: Array in LEVELS:
		var c: Color = l[4]
		d.surface("paint_%d" % l[0], {"side": "switchback/paint", "meters": 1.0, "tint": c * 1.15, "gloss": 0.08,
				"grazing": 0.35, "roughness": 0.6, "uv": true})
		d.shaded("lit_%d" % l[0], GLOW, {"color": c, "energy": 1.6})
	# Things that glow.
	d.shaded("sodium", GLOW, {"color": SODIUM, "energy": 3.2})
	d.shaded("sodium_dim", GLOW, {"color": SODIUM, "energy": 1.4})
	d.shaded("tube", GLOW, {"color": Color(0.85, 0.95, 1.0), "energy": 2.4})
	d.shaded("tube_failing", GLOW, {"color": Color(0.85, 0.95, 1.0), "energy": 2.4, "flicker": 0.8})
	d.shaded("sign_white", GLOW, {"color": Color(1.0, 0.98, 0.94), "energy": 1.5})
	d.shaded("sign_yellow", GLOW, {"color": Color(1.0, 0.82, 0.2), "energy": 1.5})
	d.shaded("sign_blue", GLOW, {"color": Color(0.12, 0.35, 1.0), "energy": 1.8})
	d.shaded("p_white", GLOW, {"color": Color(1.0, 1.0, 1.0), "energy": 2.4})
	d.shaded("exit", GLOW, {"color": Color(0.2, 1.0, 0.45), "energy": 2.0})
	d.shaded("button", GLOW, {"color": Color(1.0, 0.25, 0.2), "energy": 2.5})
	d.shaded("led_green", GLOW, {"color": Color(0.3, 1.0, 0.4), "energy": 2.5, "blink_period": 2.0, "blink_duty": 0.1})
	d.shaded("led_amber", GLOW, {"color": Color(1.0, 0.6, 0.12), "energy": 2.6})
	d.shaded("led_red", GLOW, {"color": Color(1.0, 0.12, 0.1), "energy": 2.6})
	d.shaded("aviation", GLOW, {"color": Color(1.0, 0.1, 0.08), "energy": 3.0, "blink_period": 1.6})
	d.shaded("window_warm", GLOW, {"color": Color(1.0, 0.78, 0.5), "energy": 1.2})
	d.shaded("screen", GLOW, {"color": Color(0.45, 0.8, 1.0), "energy": 1.2})
	d.shaded("mirror", "res://src/render/deco/skylight_glass.gdshader", {"reflection_map": "switchback/reflection_dusk.png",
			"grime": "terrace/grime.png", "tint": Color(0.9, 0.92, 0.95), "opacity": 0.75, "pane": Vector2(1, 1)})
	var reflection := "switchback/reflection_dusk.png"
	d.shaded("booth", "res://src/render/deco/shop_window.gdshader", {"reflection_map": reflection, "grime": "stack/caustics.png",
			"pane_height": 1.2, "depth": 2.5, "lit_share": 1.0, "bare_share": 0.0, "wall": Color(0.55, 0.52, 0.48),
			"lamp": Color(1.0, 0.86, 0.6)})
	d.shaded("puddle", PUDDLE, {"reflection_map": reflection, "noise": "terrace/grime.png", "size": Vector2(2.4, 1.6)})
	d.shaded("oil", PUDDLE, {"reflection_map": reflection, "noise": "terrace/grime.png", "size": Vector2(1.2, 0.8),
			"color": Color(0.07, 0.05, 0.04), "opacity": 0.55})
	# Far off.
	d.shaded("far_decks", FAR, {"albedo_texture": "switchback/far_decks.png", "meters_per_repeat": 12.0})
	d.shaded("far_hill", FAR, {"albedo_texture": "switchback/far_hill.png", "meters_per_repeat": 24.0})
	d.shaded("far_city", FAR, {"albedo_texture": "stack/facade.png", "meters_per_repeat": 12.0, "tint": Color(1.1, 1.1, 1.35)})
	d.shaded("far_dark", FAR, {"albedo_texture": "stack/concrete.png", "tint": Color(0.06, 0.06, 0.10), "meters_per_repeat": 12.0})
	d.shaded("far_slab", FAR, {"albedo_texture": "switchback/wall.png", "tint": Color(0.55, 0.52, 0.55), "meters_per_repeat": 12.0})


# --- The gameplay blocks, dressed ------------------------------------------------------------

const DRESS := {
	"Ground": "ground", "Summit": "retaining", "Landing1": "retaining", "UnderHairpin1": "retaining",
	"Level2": "retaining", "Landing2": "retaining", "UnderHairpin2": "retaining", "Level3": "retaining",
	"Landing3": "retaining", "SummitFloor": "deck", "Landing1Floor": "deck", "Level2Floor": "deck",
	"Landing2Floor": "deck", "Level3Floor": "deck", "Landing3Floor": "deck", "Hairpin1": "ramp", "Hairpin2": "ramp",
	"Hairpin3": "ramp", "Ladder2": "cabinet", "Ladder3": "cabinet", "Ladder4": "cabinet", "Overlook": "plinth",
	"SummitBlockW": "head", "SummitBlockE": "head", "EdgeWall1W": "parapet", "EdgeWall1E": "parapet",
	"EdgeWall2": "parapet", "EdgeWall3": "parapet",
}


static func _surfaces(kit, d) -> void:
	for b: Node in kit.geometry.get_children():
		var n := String(b.name)
		var dress: String = "boundary" if n.begins_with("Boundary") else "hut" if n.begins_with("Hut") else DRESS.get(n, "")
		if dress != "":
			b.set(&"surface", d.mat(dress))


# --- Paint on the floors --------------------------------------------------------------------------

## Bays along the foot of each back wall, their numbers at the wall end;
## arrows down the aisle the way up the car park goes; a yellow line back
## from each edge you can fall off; a speed bump, hatching at the turns.
static func _markings(d) -> void:
	for i in LEVELS.size():
		var l: Array = LEVELS[i]
		var floor_y: float = l[1]
		var band: Vector2 = l[2]
		var span: Vector2 = l[3]
		var way: float = l[6]
		var skip: Array = NO_BAYS[i]
		var number := 1
		var x := span.x + 0.5
		while x + 2.5 <= span.y - 0.4:
			var clear := true
			for s: Vector2 in skip:
				if x + 2.5 > s.x and x < s.y:
					clear = false
			if clear:
				for edge: float in [x, x + 2.5]:
					_line(d, "paint_white", Vector3(edge, floor_y, band.x + 2.45), Vector3(0.1, 0, 4.9))
				# The bay's number, at the wall end, reading from the aisle.
				Signs.channel(d, SANS, "%d%02d" % [l[0], number], Vector3(x + 1.25, floor_y + 0.004, band.x + 1.1),
						DecoKit.flat(Vector3(1, 0, 0)), 0.42, ["paint_%d" % l[0]], "paint_%d" % l[0], 0.004, 0.0, 0.0, "Build")
			number += 1
			x += 2.5
		# The bays' ends, a line along the aisle.
		_line(d, "paint_white", Vector3((span.x + span.y) * 0.5, floor_y, band.x + 4.95), Vector3(span.y - span.x - 1.0, 0, 0.1))
		# Arrows down the aisle.
		var aisle := band.x + 7.4
		var ax := span.x + 6.0
		while ax < span.y - 3.0:
			var near_hut := false
			for h: Array in HUTS:
				if int(h[1]) == i and absf(ax - float(h[0])) < 4.5:
					near_hut = true
			if i == 3 and ax > 1.0 and ax < 11.0:
				near_hut = true  # Under the Overlook.
			if not near_hut:
				_arrow(d, "paint_white", Vector3(ax, floor_y, aisle), Vector3(way, 0, 0), 2.4, 0.26, func(_p: Vector3) -> float: return floor_y)
			ax += 11.0
		# A speed bump across the aisle, painted in stripes.
		var bump_x := -20.0 if i % 2 == 0 else 14.0
		if i == 3:
			bump_x = 0.0
		d.box("hazard", Vector3(bump_x, floor_y + 0.02, aisle), Vector3(0.45, 0.04, 4.6), "Build", BOTH)
		# "Slow" before the ramp up.
		var slow_x: float = span.y - 5.0 if way > 0.0 else span.x + 5.0
		if i < 3:
			Signs.channel(d, SANS, "SLOW", Vector3(slow_x, floor_y + 0.004, aisle), DecoKit.flat(Vector3(0, 0, way)),
					0.9, ["paint_white"], "paint_white", 0.004, 0.0, 0.0, "Build")
	# Mind the edge: a yellow line back from it (the Bottom's front is a wall).
	for e: Array in EDGES:
		_line(d, "paint_yellow", Vector3((float(e[2]) + float(e[3])) * 0.5, e[0], e[1]), Vector3(float(e[3]) - float(e[2]) - 0.2, 0, 0.12))
	# Hatching where the landings turn.
	for h: Array in [[Vector3(30, 12.0, -13), Vector2(3.6, 9.2)], [Vector3(-30, 8.0, -3), Vector2(3.6, 9.2)], [Vector3(30, 4.0, 7), Vector2(3.6, 9.2)]]:
		_hatch(d, h[0], h[1])


## A painted line: `at` its middle on a floor at `at.y`, `size` its x and z.
static func _line(d, material: String, at: Vector3, size: Vector3) -> void:
	d.box(material, at + Vector3(0, 0.004, 0), Vector3(size.x, 0.008, size.z), "Build", BOTH)


## A painted arrow along `dir` (flat), `length` long, its shaft `width`
## wide, on a floor whose height `h` gives.
static func _arrow(d, material: String, at: Vector3, dir: Vector3, length: float, width: float, h: Callable) -> void:
	var side := Vector3.UP.cross(dir).normalized()
	var on := func(p: Vector3) -> Vector3: return Vector3(p.x, float(h.call(p)) + 0.012, p.z)
	var tail := at - dir * length * 0.5
	var neck := at + dir * (length * 0.5 - width * 2.4)
	var tip := at + dir * length * 0.5
	d.quad(material, on.call(tail - side * width * 0.5), on.call(tail + side * width * 0.5), on.call(neck + side * width * 0.5),
			on.call(neck - side * width * 0.5), "Build", BOTH)
	d.quad(material, on.call(neck - side * width * 1.6), on.call(neck + side * width * 1.6), on.call(tip), on.call(tip), "Build", BOTH)


## Yellow hatching over an area (x, z size) where nobody should park: a
## frame, and stripes across it at 45°.
static func _hatch(d, c: Vector3, size: Vector2) -> void:
	for e: float in [-1.0, 1.0]:
		_line(d, "paint_yellow", c + Vector3(e * size.x * 0.5, 0, 0), Vector3(0.12, 0, size.y))
		_line(d, "paint_yellow", c + Vector3(0, 0, e * size.y * 0.5), Vector3(size.x, 0, 0.12))
	var x0 := c.x - size.x * 0.5
	var x1 := c.x + size.x * 0.5
	var z0 := c.z - size.y * 0.5
	var z1 := c.z + size.y * 0.5
	# Lines x = z + t, clipped to the frame.
	var t := x0 - z1 + 0.7
	while t < x1 - z0:
		var za := maxf(z0, x0 - t)
		var zb := minf(z1, x1 - t)
		if zb - za > 0.2:
			var mid := Vector3((za + zb) * 0.5 + t, c.y, (za + zb) * 0.5)
			d.box("paint_yellow", mid + Vector3(0, 0.004, 0), Vector3((zb - za) * sqrt(2.0), 0.008, 0.12), "Build", BOTH, Basis(Vector3.UP, -PI * 0.25))
		t += 1.4


# --- The back walls ----------------------------------------------------------------------------

## Each level's back wall: a stripe of its colour along the foot, its
## number big in a disc of its colour every so often, and lamps set flush
## into the wall (they don't stick out where you ride it).
static func _back_walls(d) -> void:
	var lamps := 0
	for i in LEVELS.size():
		var l: Array = LEVELS[i]
		var floor_y: float = l[1]
		var band: Vector2 = l[2]
		var span: Vector2 = l[3]
		var colour := "paint_%d" % l[0]
		var n := Vector3(0, 0, 1)
		var b := DecoKit.facing(n)
		var wall_z := band.x + 0.006
		# The stripe.
		d.face(colour, Vector3((span.x + span.y) * 0.5, floor_y + 0.85, wall_z), Vector3((span.y - span.x) * 0.5, 0, 0),
				Vector3(0, 0.25, 0), "Build", BOTH)
		d.face("paint_white", Vector3((span.x + span.y) * 0.5, floor_y + 0.56, wall_z), Vector3((span.y - span.x) * 0.5, 0, 0),
				Vector3(0, 0.03, 0), "Build", BOTH)
		# Discs with the number.
		for x: float in DISCS[i]:
			var c := Vector3(x, floor_y + 2.1, wall_z)
			d.tube(colour, c - n * 0.004, c + n * 0.002, 0.78, 20, "Build", BOTH)
			Signs.channel(d, SANS, str(l[0]), c + Vector3(0, -0.42, 0), b, 1.2, ["paint_white"], "paint_white", 0.004, 0.0, 0.0, "Build")
			Signs.channel(d, SANS, String(l[5]), c + Vector3(1.0 + String(l[5]).length() * 0.11, -0.2, 0), b, 0.34, [colour], colour, 0.004, 0.0, 0.0, "Build")
		# Lamps set into the wall, a real light every other one.
		var top: float = floor_y + (3.6 if i == 3 else 3.1)
		var k := 0
		var lx := span.x + 3.5
		while lx < span.y - 2.0:
			var at := Vector3(lx, top, wall_z)
			d.face("dark_metal", at + Vector3(0, 0, 0.002), Vector3(0.5, 0, 0), Vector3(0, 0.14, 0), "Fixtures", BOTH)
			d.face("sodium", at + Vector3(0, 0, 0.004), Vector3(0.42, 0, 0), Vector3(0, 0.08, 0), "Fixtures", BOTH)
			if k % 2 == 0:
				d.omni("WallLamp_%d" % lamps, at + Vector3(0, -0.3, 0.6), SODIUM, 9.0, 1.1, BOTH, true)
				lamps += 1
			k += 1
			lx += 9.0


# --- The ramps ----------------------------------------------------------------------------------

## Arrows up each ramp, a yellow kerb along its open side, a convex mirror
## where it turns at the top, and signs for where it goes.
static func _ramps(d) -> void:
	for r: Array in RAMPS:
		var foot: float = r[0]
		var top: float = r[1]
		var y0: float = r[2]
		var band: Vector2 = r[3]
		var way := signf(top - foot)
		var h := func(p: Vector3) -> float: return y0 + clampf((p.x - foot) / (top - foot), 0.0, 1.0) * 4.0
		var mid := (band.x + band.y) * 0.5
		for z: float in [mid - 2.5, mid + 2.5]:
			_arrow(d, "paint_white", Vector3((foot + top) * 0.5, 0, z), Vector3(way, 0, 0), 3.0, 0.3, h)
		# The kerb along the open side (the south edge; the Bottom's runs along the wall).
		var edge := band.y - 0.15
		var lo := minf(foot, top)
		var hi := maxf(foot, top)
		var a := Vector3(lo, float(h.call(Vector3(lo, 0, 0))) + 0.02, edge)
		var b := Vector3(hi, float(h.call(Vector3(hi, 0, 0))) + 0.02, edge)
		d.quad("paint_yellow", a + Vector3(0, 0, -0.1), b + Vector3(0, 0, -0.1), b + Vector3(0, 0, 0.1), a + Vector3(0, 0, 0.1), "Build", BOTH)
	# The ramps' sides are flush with the tiled walls under them: the tiles
	# again just in front, so the two don't flicker through each other.
	d.face("retaining", Vector3(23, 6.0, -7.994), Vector3(5.0, 0, 0), Vector3(0, 2.0, 0), "Build", BOTH)
	d.face("retaining", Vector3(-23, 2.0, 2.006), Vector3(5.0, 0, 0), Vector3(0, 2.0, 0), "Build", BOTH)
	# Convex mirrors at the turns at the top: on the end walls, facing back
	# down the ramp and round the corner.
	for m: Array in [[Vector3(31.95, 14.4, -17.4), Vector3(-1, 0, 0.6)], [Vector3(-31.95, 10.4, -7.4), Vector3(1, 0, 0.6)],
			[Vector3(31.95, 6.4, 2.6), Vector3(-1, 0, 0.6)]]:
		_mirror(d, m[0], (m[1] as Vector3).normalized())
	# Where each ramp goes, on the wall at its foot, and the way down.
	for s: Array in [
			[Vector3(16.0, 2.2, 2.006), Vector3(0, 0, 1), "Levels 2 – 4  →", 2],
			[Vector3(-16.0, 6.2, -7.994), Vector3(0, 0, 1), "←  Levels 3 – 4", 3],
			[Vector3(16.0, 10.2, -17.994), Vector3(0, 0, 1), "Level 4  →", 4],
			[Vector3(-29.0, 10.6, -17.994), Vector3(0, 0, 1), "↓  Way out", 3],
			[Vector3(29.0, 6.6, -7.994), Vector3(0, 0, 1), "Way out  ↓", 2],
			[Vector3(29.0, 14.6, -27.994), Vector3(0, 0, 1), "Way out  ↓", 4]]:
		var at: Vector3 = s[0]
		var n: Vector3 = s[1]
		var b := DecoKit.facing(n)
		var text: String = s[2]
		var w := 0.3 * text.length() + 0.6
		d.box("dark_metal", at + n * 0.03, Vector3(w + 0.1, 0.62, 0.06), "Fixtures", BOTH, b)
		d.face("lit_%d" % s[3], at + n * 0.062, b.x * w * 0.5, Vector3(0, 0.26, 0), "Fixtures", BOTH)
		d.words(text, at + n * 0.068, b, 0.34, Color(0.06, 0.07, 0.1), 0.0, "Fixtures", BOTH, SANS)


## A round convex mirror on a bracket, an orange rim, `n` which way it looks.
static func _mirror(d, at: Vector3, n: Vector3) -> void:
	var wall := Vector3(signf(-n.x), 0, 0) if absf(n.x) > 0.3 else Vector3(0, 0, signf(-n.z))
	var c := at - wall * 0.45
	var b := DecoKit.facing(n)
	d.tube("steel", at, c - wall * 0.05, 0.03, 6, "Fixtures", BOTH)
	d.torus("cone", c, 0.42, 0.045, Basis(b.x, b.z, -b.y), 20, 5, "Fixtures", BOTH)
	d.ball("mirror", c + n * 0.02, Vector3(0.13, 0.4, 0.4), 4, 16, "Fixtures", BOTH)
	d.ball("dark_metal", c - n * 0.04, Vector3(0.08, 0.41, 0.41), 4, 16, "Fixtures", BOTH)


# --- The huts ---------------------------------------------------------------------------------------

## Each hut is the level's lift and stair core against the back wall, and
## its pay booth at the front, with a low passage under a lintel between
## them: MAX HEADROOM 1.2 m, a strip light inside (one of them failing).
static func _huts(d) -> void:
	var n_hut := 0
	for hut: Array in HUTS:
		var x: float = hut[0]
		var l: Array = LEVELS[int(hut[1])]
		var y: float = l[1]
		var band: Vector2 = l[2]
		var colour := "paint_%d" % l[0]
		var mid := (band.x + band.y) * 0.5
		var core := (band.x + mid - 1.5) * 0.5
		var booth := (mid + 1.5 + band.y) * 0.5
		for side: float in [-1.0, 1.0]:
			var n := Vector3(side, 0, 0)
			var b := DecoKit.facing(n)
			var face_x := x + side * 2.006
			# The level's colour round the foot of the hut.
			for zz: Array in [[band.x, mid - 1.5], [mid + 1.5, band.y]]:
				var z0: float = zz[0]
				var z1: float = zz[1]
				d.face(colour, Vector3(face_x, y + 0.45, (z0 + z1) * 0.5), b.x * (z1 - z0) * 0.5, Vector3(0, 0.45, 0), "Build", BOTH)
			# The lintel: hazard stripes, the headroom plate.
			d.face("hazard", Vector3(face_x, y + 1.4, mid), b.x * 1.5, Vector3(0, 0.2, 0), "Build", BOTH)
			d.box("yellow", Vector3(face_x + side * 0.02, y + 2.05, mid), Vector3(0.03, 0.5, 2.2), "Build", BOTH)
			d.words("MAX HEADROOM 1.2 m", Vector3(face_x + side * 0.04, y + 2.05, mid), b, 0.18, Color(0.05, 0.05, 0.05), 0.0, "Build", BOTH, SANS)
			# The core: the lift one side, the stairs the other.
			var door := Vector3(face_x + side * 0.004, y + 1.05, core)
			if side > 0.0:
				_lift_door(d, door, n, b)
			else:
				_stair_door(d, door, n, b)
			# The booth: its window onto the level, a ledge, "Pay here".
			var win := Vector3(face_x + side * 0.004, y + 1.55, booth)
			d.box("dark_metal", win - n * 0.002, Vector3(2.5, 1.3, 0.06), "Build", BOTH, b)
			d.face("booth", win + n * 0.03, b.x * 1.15, Vector3(0, 0.55, 0), "Build", BOTH)
			d.box("steel", Vector3(face_x + side * 0.15, y + 0.92, booth), Vector3(0.3, 0.05, 2.4), "Build", BOTH)
			Signs.lightbox(d, Vector3(face_x + side * 0.05, y + 2.4, booth), b, Vector2(1.3, 0.3), "sign_yellow", "Pay here", SANS, 0.2,
					Color(0.08, 0.06, 0.02))
		# The booth's lamp spilling out of its window, one side.
		d.omni("Booth_%d" % n_hut, Vector3(x + 2.8, y + 1.6, booth), Color(1.0, 0.82, 0.58), 5.0, 0.8, BOTH, true)
		# In the passage: a strip light under the lintel.
		d.box("dark_metal", Vector3(x, y + 1.17, mid), Vector3(3.4, 0.05, 0.16), "Fixtures", BOTH)
		d.box("tube_failing" if n_hut == 1 else "tube", Vector3(x, y + 1.14, mid), Vector3(3.2, 0.03, 0.08), "Fixtures", BOTH)
		d.omni("Passage_%d" % n_hut, Vector3(x, y + 0.9, mid), Color(0.85, 0.95, 1.0), 4.0, 0.7, BOTH, true)
		# Its front over the drop (the Bottom's is against the wall): the level.
		if int(hut[1]) > 0:
			var front := DecoKit.facing(Vector3(0, 0, 1))
			d.face(colour, Vector3(x, y + 0.45, band.y + 0.006), Vector3(2.0, 0, 0), Vector3(0, 0.45, 0), "Build", BOTH)
			d.words("Level %d · %s" % [l[0], l[5]], Vector3(x, y + 2.0, band.y + 0.012), front, 0.3, Color(0.1, 0.1, 0.12), 0.0, "Build", BOTH, SANS)
		_coping(d, Vector3(x, y + 2.6, mid), Vector2(4.0, band.y - band.x))
		n_hut += 1


## A steel coping round a flat roof: `top` the middle of the roof, `size`
## its x and z.
static func _coping(d, top: Vector3, size: Vector2) -> void:
	for e: float in [-0.5, 0.5]:
		d.box("steel", top + Vector3(0, 0.02, e * size.y), Vector3(size.x + 0.1, 0.05, 0.1), "Build", BOTH)
		d.box("steel", top + Vector3(e * size.x, 0.02, 0), Vector3(0.1, 0.05, size.y + 0.1), "Build", BOTH)


## Lift doors: brushed steel, a seam up the middle, a call button lit
## beside them, "Lift" over them, a note taped across.
static func _lift_door(d, at: Vector3, n: Vector3, b: Basis) -> void:
	d.box("dark_metal", at - n * 0.01, Vector3(1.35, 2.2, 0.04), "Build", BOTH, b)
	for s: float in [-0.3, 0.3]:
		d.face("lift_door", at + n * 0.015 + b.x * s, b.x * 0.29, Vector3(0, 1.02, 0), "Build", BOTH)
	d.face("black", at + n * 0.018, b.x * 0.008, Vector3(0, 1.02, 0), "Build", BOTH)
	var panel := at + b.x * 0.95 + Vector3(0, 0.05, 0)
	d.face("steel", panel + n * 0.01, b.x * 0.09, Vector3(0, 0.16, 0), "Build", BOTH)
	d.ball("button", panel + n * 0.02 + Vector3(0, 0.05, 0), Vector3(0.03, 0.03, 0.015), 2, 8, "Fixtures", BOTH)
	Signs.lightbox(d, at + Vector3(0, 1.42, 0) + n * 0.04, b, Vector2(0.9, 0.26), "sign_white", "Lift", SANS, 0.2, Color(0.1, 0.12, 0.2))
	d.face("paper", at + n * 0.02 + Vector3(0, 0.15, 0), b.x * 0.2, Vector3(0, 0.14, 0), "Build", BOTH)
	d.words("out of\norder", at + n * 0.024 + Vector3(0, 0.15, 0), b, 0.085, Color(0.1, 0.1, 0.12), 0.0, "Build", BOTH, HAND)


## A green steel stair door, a wired-glass light, a push bar, the running
## man over it.
static func _stair_door(d, at: Vector3, n: Vector3, b: Basis) -> void:
	d.box("dark_metal", at - n * 0.01, Vector3(1.1, 2.2, 0.04), "Build", BOTH, b)
	d.face("door_green", at + n * 0.015, b.x * 0.48, Vector3(0, 1.02, 0), "Build", BOTH)
	d.face("glass_dark", at + n * 0.02 + Vector3(0, 0.5, 0) + b.x * 0.15, b.x * 0.12, Vector3(0, 0.28, 0), "Build", BOTH)
	d.box("steel", at + n * 0.06 + Vector3(0, -0.05, 0), Vector3(0.8, 0.05, 0.05), "Build", BOTH, b)
	d.face("exit", at + n * 0.03 + Vector3(0, 1.4, 0), b.x * 0.3, Vector3(0, 0.1, 0), "Fixtures", BOTH)
	d.words("Stairs", at + n * 0.036 + Vector3(0, 1.4, 0), b, 0.15, Color(0.02, 0.2, 0.08), 0.0, "Fixtures", BOTH, SANS)


# --- The Ladder --------------------------------------------------------------------------------------

## The crates up the middle are utility cabinets: louvres, a warning
## triangle, a green light blinking, and DO NOT CLIMB stencilled on.
static func _cabinets(d) -> void:
	for c: Array in CABINETS:
		var foot: Vector3 = c[0]
		var colour := "paint_%d" % LEVELS[int(c[1])][0]
		var front := foot + Vector3(0, 0, 1.006)
		var b := DecoKit.facing(Vector3(0, 0, 1))
		# Two doors, a seam, handles.
		d.face("black", front + Vector3(0, 1.0, 0.001), Vector3(0.008, 0, 0), Vector3(0, 0.95, 0), "Build", BOTH)
		for s: float in [-0.5, 0.5]:
			for k in 6:
				d.box("dark_metal", front + Vector3(s, 1.55 - k * 0.09, 0.01), Vector3(0.6, 0.025, 0.02), "Build", BOTH)
			d.box("dark_metal", front + Vector3(s * 0.2, 1.0, 0.02), Vector3(0.04, 0.2, 0.03), "Build", BOTH)
		d.quad("yellow", front + Vector3(-0.5, 0.75, 0.01), front + Vector3(-0.1, 0.75, 0.01), front + Vector3(-0.3, 0.4, 0.01),
				front + Vector3(-0.3, 0.4, 0.01), "Build", BOTH)
		d.words("!", front + Vector3(-0.3, 0.56, 0.015), b, 0.2, Color(0.05, 0.05, 0.05), 0.0, "Build", BOTH, SANS)
		d.words("DO NOT CLIMB", front + Vector3(0.5, 0.35, 0.012), b, 0.12, Color(0.92, 0.9, 0.85), 0.0, "Build", BOTH, STENCIL)
		d.ball("led_green", front + Vector3(0.8, 1.85, 0.02), Vector3(0.025, 0.025, 0.01), 2, 6, "Fixtures", BOTH)
		# The level's colour on its plinth.
		d.face(colour, front + Vector3(0, 0.08, 0.002), Vector3(1.0, 0, 0), Vector3(0, 0.08, 0), "Build", BOTH)
		# Louvres on the ends.
		for e: float in [-1.0, 1.0]:
			for k in 5:
				d.box("dark_metal", foot + Vector3(e * 1.01, 1.5 - k * 0.1, 0.0), Vector3(0.02, 0.025, 1.2), "Build", BOTH)


# --- The top deck ---------------------------------------------------------------------------------

## The Overlook is a plinth of chequer plate with yellow nosing; the lift
## and stair heads stand either side; one last car under a cover; over the
## back wall the blue P and the car park's name; a counter by it says
## the level's full; and the way up to Levels 5 – ∞ is shuttered.
static func _summit(d) -> void:
	# The plinth's nosing.
	d.box("paint_yellow", Vector3(6, 13.477, -19.25), Vector3(6.0, 0.06, 0.12), "Build", BOTH)
	d.face("hazard", Vector3(6, 13.35, -19.194), Vector3(3.0, 0, 0), Vector3(0, 0.12, 0), "Build", BOTH)
	d.words("Lookout", Vector3(6, 12.75, -19.19), DecoKit.facing(Vector3(0, 0, 1)), 0.32, Color(0.95, 0.92, 0.85), 0.0, "Build", BOTH, SANS)
	# The heads: stairs down in the west one, the lift in the east one.
	for h: Array in [[-15.0, false], [15.0, true]]:
		var x: float = h[0]
		var front := Vector3(x, 13.05, -22.994)
		var n := Vector3(0, 0, 1)
		var b := DecoKit.facing(n)
		d.face("paint_4", Vector3(x, 12.45, -22.994), Vector3(2.0, 0, 0), Vector3(0, 0.45, 0), "Build", BOTH)
		if h[1]:
			_lift_door(d, front, n, b)
		else:
			_stair_door(d, front, n, b)
		_coping(d, Vector3(x, 15.0, -25), Vector2(4.0, 4.0))
		d.solid(Vector3(x + 1.0, 15.25, -25.8), Vector3(0.9, 0.5, 0.9))
		d.box("dark_metal", Vector3(x + 1.0, 15.25, -25.8), Vector3(0.9, 0.5, 0.9), "Solid", BOTH)
		d.box("black", Vector3(x + 1.0, 15.51, -25.8), Vector3(0.7, 0.02, 0.7), "Build", BOTH)
		d.omni("Head_%d" % (0 if x < 0.0 else 1), Vector3(x, 14.8, -22.4), Color(0.85, 0.95, 1.0), 6.0, 0.8, BOTH, true)
		d.box("tube", Vector3(x, 14.7, -22.95), Vector3(1.2, 0.06, 0.08), "Fixtures", BOTH)
	_covered_car(d, Vector3(-22.75, 12.0, -25.7))
	# The blue P over the back wall, on a steel frame, and the name under it.
	var pc := Vector3(0, 21.4, -28.3)
	var pb := DecoKit.facing(Vector3(0, 0, 1))
	for e: float in [-1.6, 1.6]:
		d.box("dark_metal", Vector3(e, 19.0, -28.7), Vector3(0.18, 2.2, 0.18), "Build", BOTH)
	d.box("dark_metal", pc + Vector3(0, 0, -0.2), Vector3(4.2, 4.2, 0.3), "Build", BOTH)
	d.face("sign_blue", pc + Vector3(0, 0, -0.04), Vector3(1.9, 0, 0), Vector3(0, 1.9, 0), "Fixtures", BOTH)
	Signs.channel(d, SANS, "P", pc + Vector3(0, -1.35, 0), pb, 3.6, ["p_white"], "dark_metal", 0.1, 0.0, 0.0, "Fixtures")
	d.omni("TheP", pc + Vector3(0, -1.0, 2.5), Color(0.55, 0.7, 1.0), 16.0, 1.4, BOTH)
	Signs.channel(d, SWASH, "Cloudside Parking", Vector3(0, 16.2, -28.0), pb, 1.0, ["brass"], "dark_metal", 0.06)
	# The counter: the level full, though nobody's here.
	var counter := Vector3(-8.5, 15.3, -27.95)
	d.box("black", counter, Vector3(4.2, 1.6, 0.12), "Build", BOTH)
	Signs.bulbs(d, SANS, "Level 4", counter + Vector3(0, 0.16, 0.06), pb, 0.06, 8, ["led_amber"], 0.022)
	Signs.bulbs(d, SANS, "FULL", counter + Vector3(0, -0.62, 0.06), pb, 0.06, 8, ["led_red"], 0.022)
	# The way up, shuttered: Levels 5 – ∞.
	var wn := Vector3(1, 0, 0)
	var wb := DecoKit.facing(wn)
	var shutter := Vector3(-31.96, 13.8, -23.0)
	d.face("shutter", shutter, wb.x * 3.0, Vector3(0, 1.8, 0), "Build", BOTH)
	d.box("dark_metal", shutter + Vector3(0.05, 1.9, 0), Vector3(0.12, 0.25, 6.3), "Build", BOTH)
	d.face("hazard", shutter + Vector3(0.012, -1.62, 0), wb.x * 3.0, Vector3(0, 0.18, 0), "Build", BOTH)
	Signs.lightbox(d, Vector3(-31.9, 16.4, -23.0), wb, Vector2(3.4, 0.8), "sign_white", "Levels 5 – ∞  ↑", SANS, 0.42, Color(0.1, 0.12, 0.2))
	d.words("closed", Vector3(-31.93, 17.15, -23.0), wb, 0.28, Color(0.95, 0.9, 0.85), 0.0, "Build", BOTH, HAND)
	_arrow(d, "paint_white", Vector3(-29.0, 12.0, -23.0), Vector3(-1, 0, 0), 2.4, 0.26, func(_p: Vector3) -> float: return 12.0)
	# Barriers across it, against the shutter.
	for z: float in [-25.2, -20.8]:
		var at := Vector3(-31.4, 12.0, z)
		d.solid(at + Vector3(0, 0.5, 0), Vector3(0.5, 1.0, 1.9))
		for k in 3:
			d.box("red" if k % 2 == 0 else "white", at + Vector3(0, 0.55 + k * 0.14, 0), Vector3(0.12, 0.14, 1.8), "Solid", BOTH)
		for e: float in [-0.8, 0.8]:
			d.box("red", at + Vector3(0, 0.25, e), Vector3(0.45, 0.5, 0.12), "Solid", BOTH)


## The last car: a hatchback under a silver cover, nose to the wall, a
## wheel showing under the hem.
static func _covered_car(d, at: Vector3) -> void:
	d.solid(at + Vector3(0, 0.7, 0), Vector3(1.8, 1.4, 4.2))
	d.ball("cover", at + Vector3(0, 0.62, 0), Vector3(0.92, 0.42, 2.12), 6, 14, "Solid", BOTH, true)
	d.ball("cover", at + Vector3(0, 1.02, 0.25), Vector3(0.78, 0.4, 1.2), 6, 14, "Solid", BOTH, true)
	d.box("cover", at + Vector3(0, 0.42, 0), Vector3(1.84, 0.5, 4.0), "Solid", BOTH)
	for w: Vector3 in [Vector3(-0.8, 0.3, -1.3), Vector3(0.8, 0.3, -1.3), Vector3(-0.8, 0.3, 1.35), Vector3(0.8, 0.3, 1.35)]:
		d.tube("rubber", at + w - Vector3(0.1, 0, 0), at + w + Vector3(0.1, 0, 0), 0.3, 10, "Solid", BOTH)
	# A ticket under the cover's hem, and leaves on the roof.
	d.box("paper", at + Vector3(0.93, 0.5, -0.4), Vector3(0.01, 0.08, 0.14), "Detail", BOTH)


# --- The ends ------------------------------------------------------------------------------------

## The end walls of each level: the level's sign, a pay machine, a help
## point, a fire point, a drainpipe, and a sodium wall light.
static func _ends(d) -> void:
	var lamps := 0
	for e: Array in [[-32.0, 0, Vector2(3, 11), Vector2(8.5, 5.0)], [32.0, 1, Vector2(-7, 11), Vector2(-2.0, 6.5)],
			[-32.0, 2, Vector2(-17, 1), Vector2(-12.5, -3.5)], [32.0, 3, Vector2(-27, -9), Vector2(-21.0, -14.0)]]:
		var wall_x: float = e[0]
		var l: Array = LEVELS[int(e[1])]
		var y: float = l[1]
		var span: Vector2 = e[2]
		var spots: Vector2 = e[3]
		var colour := "paint_%d" % l[0]
		var n := Vector3(-signf(wall_x), 0, 0)
		var b := DecoKit.facing(n)
		var face_x := wall_x + n.x * 0.006
		# The stripe carries on round.
		d.face(colour, Vector3(face_x, y + 0.85, (span.x + span.y) * 0.5), b.x * (span.y - span.x) * 0.5, Vector3(0, 0.25, 0), "Build", BOTH)
		# The level's sign: its number in a disc, its name.
		var sc := Vector3(face_x, y + 2.8, spots.x)
		d.tube(colour, sc - n * 0.004, sc + n * 0.002, 1.0, 20, "Build", BOTH)
		Signs.channel(d, SANS, str(l[0]), sc + Vector3(0, -0.55, 0), b, 1.55, ["paint_white"], "paint_white", 0.004, 0.0, 0.0, "Build")
		Signs.channel(d, SANS, "Level %d" % l[0], sc + Vector3(0, -1.55, 0), b, 0.42, [colour], colour, 0.004, 0.0, 0.0, "Build")
		Signs.channel(d, SANS, String(l[5]), sc + Vector3(0, 1.2, 0), b, 0.42, [colour], colour, 0.004, 0.0, 0.0, "Build")
		# A pay machine and a help point.
		var pm := Vector3(wall_x + n.x * 0.25, y, spots.y)
		d.solid(pm + Vector3(0, 0.8, 0), Vector3(0.5, 1.6, 0.6))
		d.box("blue_panel", pm + Vector3(0, 0.8, 0), Vector3(0.45, 1.6, 0.55), "Solid", BOTH)
		d.face("screen", pm + Vector3(n.x * 0.23, 1.25, 0), b.x * 0.15, Vector3(0, 0.1, 0), "Fixtures", BOTH)
		d.face("black", pm + Vector3(n.x * 0.23, 0.95, 0), b.x * 0.1, Vector3(0, 0.1, 0), "Build", BOTH)
		d.words("Pay & Display", pm + Vector3(n.x * 0.232, 1.47, 0), b, 0.07, Color(0.95, 0.95, 1.0), 0.0, "Build", BOTH, SANS)
		var help := Vector3(face_x, y + 1.4, spots.y + 1.4 * signf(span.y - spots.y))
		d.box("red", help + n * 0.05, Vector3(0.1, 0.5, 0.3), "Build", BOTH)
		d.ball("button", help + n * 0.11 + Vector3(0, -0.05, 0), Vector3(0.012, 0.035, 0.035), 2, 8, "Fixtures", BOTH)
		d.words("Help", help + n * 0.102 + Vector3(0, 0.15, 0), b, 0.08, Color(1, 1, 1), 0.0, "Build", BOTH, SANS)
		# The fire point: an extinguisher in a red box.
		var fire := Vector3(face_x, y + 0.9, spots.y - 1.6 * signf(span.y - spots.y))
		d.box("red", fire + n * 0.12, Vector3(0.24, 0.9, 0.36), "Build", BOTH)
		d.face("glass_dark", fire + n * 0.245, b.x * 0.14, Vector3(0, 0.38, 0), "Build", BOTH)
		d.words("Fire point", fire + n * 0.25 + Vector3(0, 0.65, 0), b, 0.09, Color(0.9, 0.12, 0.1), 0.0, "Build", BOTH, SANS)
		# A drainpipe down the wall.
		var pipe_z := span.x + 0.6
		d.tube("dark_metal", Vector3(face_x + n.x * 0.1, y, pipe_z), Vector3(face_x + n.x * 0.1, y + 4.0, pipe_z), 0.06, 6, "Build", BOTH)
		# The wall light.
		var lamp := Vector3(face_x, y + 3.4, spots.x - 2.6)
		d.box("dark_metal", lamp + n * 0.08, Vector3(0.16, 0.28, 0.5), "Fixtures", BOTH, b)
		d.face("sodium", lamp + n * 0.165, b.x * 0.2, Vector3(0, 0.1, 0), "Fixtures", BOTH)
		d.omni("EndLamp_%d" % lamps, lamp + n * 0.6, SODIUM, 10.0, 1.2, BOTH, true)
		lamps += 1


## The front wall, which every level looks down onto: the Bottom's colour
## along its foot, lamps set in it, and the car park's plea painted big.
static func _front_wall(d) -> void:
	var n := Vector3(0, 0, -1)
	var b := DecoKit.facing(n)
	var z := 11.994
	d.face("paint_1", Vector3(-7, 0.85, z), Vector3(25, 0, 0), Vector3(0, 0.25, 0), "Build", BOTH)
	d.face("paint_white", Vector3(-7, 0.56, z), Vector3(25, 0, 0), Vector3(0, 0.03, 0), "Build", BOTH)
	Signs.channel(d, SANS, "Remember your level", Vector3(0.0, 3.4, z), b, 1.1, ["paint_white"], "paint_white", 0.004, 0.0, 0.0, "Build")
	for i in LEVELS.size():
		var c := Vector3(-4.5 + i * 3.0, 2.3, z)
		d.tube("paint_%d" % (i + 1), c - n * 0.004, c + n * 0.002, 0.62, 20, "Build", BOTH)
		Signs.channel(d, SANS, str(i + 1), c + Vector3(0, -0.33, 0), b, 0.95, ["paint_white"], "paint_white", 0.004, 0.0, 0.0, "Build")
	for x: float in [-26.0, -16.0, 6.0, 14.0]:
		var at := Vector3(x, 5.4, z)
		d.face("dark_metal", at + n * 0.002, Vector3(0.5, 0, 0), Vector3(0, 0.14, 0), "Fixtures", BOTH)
		d.face("sodium", at + n * 0.004, Vector3(0.42, 0, 0), Vector3(0, 0.08, 0), "Fixtures", BOTH)
	# Where each level's slab meets the end walls: a darker band, so the
	# walls read as a building's floors.
	for e: Array in [[-32.0, 4.0, Vector2(-8, 2)], [-32.0, 8.0, Vector2(-18, 2)], [-32.0, 12.0, Vector2(-28, -18)],
			[32.0, 4.0, Vector2(-8, 12)], [32.0, 12.0, Vector2(-28, -8)]]:
		var wx: float = e[0]
		var span: Vector2 = e[2]
		var wn := Vector3(-signf(wx), 0, 0)
		d.face("slab_edge", Vector3(wx + wn.x * 0.004, float(e[1]) - 0.25, (span.x + span.y) * 0.5), DecoKit.facing(wn).x * (span.y - span.x) * 0.5,
				Vector3(0, 0.25, 0), "Build", BOTH)


# --- Floodlights -----------------------------------------------------------------------------------

## Sodium floods on the front wall throwing light up the hill onto the back
## walls, and on the back wall throwing it down over the decks (casting the
## huts' long shadows down the hill).
static func _floodlights(d) -> void:
	# Two lamps to a flood, one light each: a light reaching the whole map
	# draws everything again, so there are few of them.
	var k := 0
	for x: float in [-14.0, 14.0]:
		var at := Vector3(x, 7.5, 11.6)
		for e: float in [-0.5, 0.5]:
			_flood(d, at + Vector3(e, 0, 0), Vector3(0, 0, 1))
		d.spot("FloodFront_%d" % k, at + Vector3(0, 0, -0.35), Vector3(0, 0.16, -1), SODIUM, 42.0, 3.0, 55.0, BOTH)
		k += 1
	for x: float in [-18.0, 18.0]:
		var at := Vector3(x, 17.5, -27.6)
		for e: float in [-0.5, 0.5]:
			_flood(d, at + Vector3(e, 0, 0), Vector3(0, 0, -1))
		d.spot("FloodBack_%d" % k, at + Vector3(0, -0.2, 0.35), Vector3(0, -0.55, 1), SODIUM, 48.0, 2.4, 50.0, BOTH)
		k += 1


## A flood's box on a bracket off a wall facing `wall` (the way out of it
## is the other way), its lens glowing.
static func _flood(d, at: Vector3, wall: Vector3) -> void:
	var out := -wall
	d.box("dark_metal", at + wall * 0.25, Vector3(0.12, 0.12, 0.5), "Fixtures", BOTH)
	d.box("dark_metal", at, Vector3(0.7, 0.45, 0.25), "Fixtures", BOTH)
	d.face("sodium", at + out * 0.13, Vector3(0.3 * signf(out.z), 0, 0), Vector3(0, 0.18, 0), "Fixtures", BOTH)


# --- Odds and ends -----------------------------------------------------------------------------------

## Traffic cones (one knocked over, one on a hut roof), a shopping trolley
## pushed up a level, puddles and oil, skid marks, dropped tickets.
static func _odds(d) -> void:
	for c: Array in [[Vector3(29.0, 12.0, -8.7), false], [Vector3(30.3, 12.0, -8.9), false], [Vector3(-29.6, 8.0, 1.2), true],
			[Vector3(-16.8, 4.0, 1.2), false], [Vector3(-12.6, 2.6, 6.3), false], [Vector3(30.8, 4.0, 11.2), false],
			[Vector3(-30.8, 0.0, 11.0), true], [Vector3(17.2, 0.0, 11.3), false]]:
		_cone(d, c[0], c[1])
	_trolley(d, Vector3(30.4, 4.0, -6.8), 0.4)
	for p: Array in [[Vector3(-21.0, 0, 8.4), 0.2], [Vector3(4.0, 0, 9.6), 1.2], [Vector3(24.0, 4, -1.0), 2.4], [Vector3(-8.0, 8, -10.2), 0.7],
			[Vector3(-26.0, 12, -19.6), 1.9]]:
		d.face("puddle", (p[0] as Vector3) + Vector3(0, 0.014, 0), Basis(Vector3.UP, p[1]) * Vector3(1.2, 0, 0),
				Basis(Vector3.UP, p[1]) * Vector3(0, 0, -0.8), "Effects", BOTH)
	# Oil where cars stood, in the bays.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4412
	for i in LEVELS.size():
		var l: Array = LEVELS[i]
		for k in 5:
			var x := rng.randf_range((l[3] as Vector2).x + 2.0, (l[3] as Vector2).y - 2.0)
			var at := Vector3(x, float(l[1]) + 0.012, (l[2] as Vector2).x + rng.randf_range(1.6, 3.4))
			var r := Basis(Vector3.UP, rng.randf() * TAU)
			d.face("oil", at, r * Vector3(0.6, 0, 0), r * Vector3(0, 0, -0.4), "Effects", BOTH)
	# Skid marks: someone took the bottom turn too fast.
	for arc: Array in [[Vector3(10.0, 0.0, 7.0), 3.5, -1.0, 1.2], [Vector3(-6.0, 4.0, -3.0), 3.0, 2.0, 3.6]]:
		_skid(d, arc[0], arc[1], arc[2], arc[3])
	# Tickets.
	for p: Vector3 in [Vector3(-3.0, 0, 10.6), Vector3(22.5, 4, 0.4), Vector3(-15.0, 8, -9.0), Vector3(9.0, 12, -19.4), Vector3(-27.0, 0, 3.4)]:
		d.box("paper", p + Vector3(0, 0.004, 0), Vector3(0.08, 0.006, 0.15), "Detail", BOTH, Basis(Vector3.UP, p.x))


## A traffic cone at `at`, standing or knocked over.
static func _cone(d, at: Vector3, fallen: bool) -> void:
	var b := Basis.IDENTITY if not fallen else Basis(Vector3(0, 0, 1), PI * 0.5) * Basis(Vector3.UP, at.x)
	var base := at + (Vector3(0, 0.02, 0) if not fallen else Vector3(0, 0.2, 0))
	d.box("black", base, Vector3(0.4, 0.04, 0.4), "Detail", BOTH, b)
	var sides := 8
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var bands := [[0.04, 0.165, "cone"], [0.3, 0.12, "white"], [0.42, 0.095, "cone"], [0.72, 0.02, ""]]
		for k in 3:
			var y0: float = bands[k][0]
			var r0: float = bands[k][1]
			var y1: float = bands[k + 1][0]
			var r1: float = bands[k + 1][1]
			var p := func(a: float, r: float, y: float) -> Vector3: return base + b * Vector3(cos(a) * r, y - 0.02, sin(a) * r)
			d.quad(bands[k][2], p.call(a1, r1, y1), p.call(a0, r1, y1), p.call(a0, r0, y0), p.call(a1, r0, y0), "Detail", BOTH)


## A shopping trolley, wire basket on castors, turned `turn`.
static func _trolley(d, at: Vector3, turn: float) -> void:
	var b := Basis(Vector3.UP, turn)
	var p := func(v: Vector3) -> Vector3: return at + b * v
	var top := [Vector3(-0.3, 1.0, -0.45), Vector3(0.3, 1.0, -0.45), Vector3(0.3, 1.0, 0.5), Vector3(-0.3, 1.0, 0.5)]
	var low := [Vector3(-0.22, 0.5, -0.35), Vector3(0.22, 0.5, -0.35), Vector3(0.24, 0.5, 0.45), Vector3(-0.24, 0.5, 0.45)]
	for i in 4:
		d.tube("chrome", p.call(top[i]), p.call(top[(i + 1) % 4]), 0.012, 4, "Detail", BOTH)
		d.tube("chrome", p.call(low[i]), p.call(low[(i + 1) % 4]), 0.012, 4, "Detail", BOTH)
		d.tube("chrome", p.call(top[i]), p.call(low[i]), 0.012, 4, "Detail", BOTH)
	for k in 5:
		var t := (k + 1) / 6.0
		d.tube("chrome", p.call(Vector3(-0.3, 1.0, -0.45).lerp(Vector3(-0.3, 1.0, 0.5), t)),
				p.call(Vector3(-0.24, 0.5, -0.35).lerp(Vector3(-0.24, 0.5, 0.45), t)), 0.006, 3, "Detail", BOTH)
		d.tube("chrome", p.call(Vector3(0.3, 1.0, -0.45).lerp(Vector3(0.3, 1.0, 0.5), t)),
				p.call(Vector3(0.22, 0.5, -0.35).lerp(Vector3(0.24, 0.5, 0.45), t)), 0.006, 3, "Detail", BOTH)
	d.tube("red", p.call(Vector3(-0.32, 1.12, 0.62)), p.call(Vector3(0.32, 1.12, 0.62)), 0.02, 6, "Detail", BOTH)
	for c: Vector3 in [Vector3(-0.22, 0, -0.35), Vector3(0.22, 0, -0.35), Vector3(-0.24, 0, 0.45), Vector3(0.24, 0, 0.45)]:
		d.tube("chrome", p.call(c + Vector3(0, 0.1, 0)), p.call(c + Vector3(0, 0.5, 0)), 0.012, 4, "Detail", BOTH)
		d.tube("rubber", p.call(c + Vector3(-0.02, 0.06, 0)), p.call(c + Vector3(0.02, 0.06, 0)), 0.06, 8, "Detail", BOTH)


## A skid mark: two tyres' arcs round `c`, from angle `a0` to `a1`.
static func _skid(d, c: Vector3, r: float, a0: float, a1: float) -> void:
	var steps := 10
	for w: float in [0.0, 1.5]:
		for i in steps:
			var t0 := lerpf(a0, a1, float(i) / steps)
			var t1 := lerpf(a0, a1, float(i + 1) / steps)
			var q0 := c + Vector3(cos(t0), 0, sin(t0)) * (r + w)
			var q1 := c + Vector3(cos(t1), 0, sin(t1)) * (r + w)
			var o0 := Vector3(cos(t0), 0, sin(t0)) * 0.1
			var o1 := Vector3(cos(t1), 0, sin(t1)) * 0.1
			var lift := Vector3(0, 0.01, 0)
			d.quad("skid", q0 - o0 + lift, q1 - o1 + lift, q1 + o1 + lift, q0 + o0 + lift, "Build", BOTH)
			d.quad("skid", q1 - o1 + lift, q0 - o0 + lift, q0 + o0 + lift, q1 + o1 + lift, "Build", BOTH)


# --- Far off -------------------------------------------------------------------------------------------

## Over the back wall the hill climbs on, a road zigzagging up it lit by
## lamps; on its top the car park carries on as a spiral tower, deck over
## deck, until it's lost in the sky.
static func _hill_and_tower(d) -> void:
	# The hill, rising behind the back wall, steeper toward its crest (only
	# the crest shows over the wall).
	var slopes := [Vector3(0, 17.0, -32), Vector3(0, 40.0, -70), Vector3(0, 66.0, -120), Vector3(0, 70.0, -170)]
	for i in slopes.size() - 1:
		var a: Vector3 = slopes[i]
		var b: Vector3 = slopes[i + 1]
		d.quad("far_hill", Vector3(-160, b.y, b.z), Vector3(160, b.y, b.z), Vector3(160, a.y, a.z), Vector3(-160, a.y, a.z), "Far", BOTH)
	# The road zigzagging up to the top, its lamps.
	for i in 4:
		var t := float(i) / 3.0
		var z := lerpf(-96.0, -118.0, t)
		var y := lerpf(55.0, 65.0, t)
		for k in 7:
			var x := lerpf(-70.0, 70.0, float(k) / 6.0) + (6.0 if i % 2 == 0 else -6.0)
			d.box("far_dark", Vector3(x, y + 1.5, z), Vector3(0.25, 3.0, 0.25), "Far", BOTH)
			d.box("sodium", Vector3(x, y + 3.1, z), Vector3(0.9, 0.3, 0.5), "Far", BOTH)
	# The tower on the crest: decks in a spiral, a turn a deck.
	_spiral(d, Vector3(0, 0, -150), 26.0, 60.0, 320.0)
	for i in 12:
		var a := TAU * i / 12.0 * 5.0
		var y := 80.0 + i * 20.0
		d.box("aviation", Vector3(0, y, -150) + Vector3(cos(a), 0, sin(a)) * 26.5, Vector3(0.9, 0.9, 0.9), "Far", BOTH)


## A cylinder of decks: `far_decks` wrapped round, its bands climbing a
## deck (4 m) each turn, so it reads as one ramp going round and up.
static func _spiral(d, c: Vector3, radius: float, bottom: float, top: float) -> void:
	var st: SurfaceTool = d._bucket("far_decks", "Far", BOTH, false)
	var sides := 32
	var rows := int((top - bottom) / 20.0)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		for j in rows:
			var y0 := bottom + j * 20.0
			var y1 := y0 + 20.0
			var q := [[a1, y1], [a0, y1], [a0, y0], [a1, y0]]
			for k: int in [0, 1, 2, 0, 2, 3]:
				var a: float = q[k][0]
				var y: float = q[k][1]
				var out := Vector3(cos(a), 0, sin(a))
				st.set_normal(out)
				st.set_uv(Vector2(a * radius, -y + a / TAU * 4.0))
				st.add_vertex(c + out * radius + Vector3(0, y, 0))


## Down the hill in front, far below, the city at dusk: towers with their
## windows coming on, the tall ones' red lights, a road of lamps along the
## valley.
static func _city(d) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for i in 34:
		var p := Vector2(rng.randf_range(-240.0, 240.0), rng.randf_range(90.0, 250.0))
		var size := Vector2(rng.randf_range(12.0, 30.0), rng.randf_range(12.0, 30.0))
		var top := rng.randf_range(-15.0, 15.0) + (22.0 if i % 7 == 0 else 0.0)
		var bottom := -120.0
		var c := Vector3(p.x, (top + bottom) * 0.5, p.y)
		var hh := (top - bottom) * 0.5
		d.face("far_city", c + Vector3(0, 0, -size.y * 0.5), Vector3(-size.x * 0.5, 0, 0), Vector3(0, hh, 0), "Far", BOTH)
		d.face("far_city", c + Vector3(size.x * 0.5, 0, 0), Vector3(0, 0, -size.y * 0.5), Vector3(0, hh, 0), "Far", BOTH)
		d.face("far_city", c + Vector3(-size.x * 0.5, 0, 0), Vector3(0, 0, size.y * 0.5), Vector3(0, hh, 0), "Far", BOTH)
		d.face("far_dark", Vector3(p.x, top, p.y), Vector3(size.x * 0.5, 0, 0), Vector3(0, 0, -size.y * 0.5), "Far", BOTH)
		if top > 10.0:
			d.box("aviation", Vector3(p.x, top + 1.0, p.y), Vector3(1.2, 1.2, 1.2), "Far", BOTH)
	# The road along the valley.
	for i in 40:
		var x := -280.0 + i * 14.0
		d.box("sodium", Vector3(x, -22.0, 205.0 + sin(i * 0.4) * 6.0), Vector3(1.4, 0.5, 0.8), "Far", BOTH)
	# The valley floor, dark.
	d.face("far_dark", Vector3(0, -60.0, 260.0), Vector3(400, 0, 0), Vector3(0, 0, -140), "Far", BOTH)
