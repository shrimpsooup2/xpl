extends RefCounted
## STACK, dressed (GDD §9.3): the drained rooftop pool of a hotel tower, at
## night, and the changing rooms under it.
##
## Up top, the walled roof is the pool: tiled walls (the wall-ride tiles, as
## on every map), lane lines, lamps set in the walls still shining into it,
## and caustics dancing on the tiles with no water to make them. The Well is
## the main drain, and the water that's left pours through it. The pulpits
## are diving platforms, the low walls starting blocks. Inflatables drift in
## the sky over it; the city is all round, far below and far off.
##
## Below, the changing rooms: fluorescent tubes, lockers (pink on A's side,
## blue on B's, so you know which half you're in), benches, showers, pipes,
## doors to nowhere, windows onto the city, a telly left on. The sky's light
## doesn't reach in (an AmbientZone); the tubes, the windows and the shaft of
## moonlight down the drain do.
##
## Every lamp has something to come from. Lamps on each floor light only
## that floor (render layers), so nothing shines through the pool's floor.
## The gameplay blocks are untouched, only dressed: the map plays as it did.

const DecoKit := preload("res://tools/deco_kit.gd")
const LOWER := DecoKit.LAYER_LOWER
const UPPER := DecoKit.LAYER_UPPER
const BOTH := DecoKit.LAYER_BOTH
const ROOF := 5.0
const CEILING := 4.5
const WALL_TOP := 8.0

const TUBE := Color(0.80, 1.0, 0.92)
const POOL := Color(0.38, 0.88, 1.0)
const MOON := Color(0.64, 0.74, 1.0)
const EXIT := Color(0.2, 1.0, 0.45)


static func dress(kit, d) -> void:
	_night(kit)
	_materials(d)
	_surfaces(kit, d)
	_indoors(kit)
	_tubes(kit, d)
	_pipes(d)
	_lockers_and_benches(d)
	_showers(d)
	_doors(d)
	_windows(d)
	_tellies(d)
	_cellar_odds(d)
	_the_drain(kit, d)
	_pool_lamps(d)
	_pool_fittings(d)
	_pool_markings(d)
	_neon(d)
	_inflatables(d)
	_skyline(d)


# --- Helpers ---------------------------------------------------------------------------

## A basis facing `n` (its z), upright.
static func _facing(n: Vector3) -> Basis:
	var z := n.normalized()
	var x := Vector3.UP.cross(z).normalized()
	return Basis(x, z.cross(x), z)


## A basis lying flat, facing up, reading along `along`.
static func _flat(along: Vector3) -> Basis:
	var x := along.normalized()
	return Basis(x, Vector3.UP.cross(x), Vector3.UP)


## The four walls: [inner face's normal, point on the inner face at height 0].
const WALLS := [[Vector3(0, 0, 1), Vector3(0, 0, -11)], [Vector3(0, 0, -1), Vector3(0, 0, 11)],
		[Vector3(1, 0, 0), Vector3(-11, 0, 0)], [Vector3(-1, 0, 0), Vector3(11, 0, 0)]]


# --- The night ------------------------------------------------------------------------

static func _night(kit) -> void:
	var e: Environment = kit.environment
	var sky: ShaderMaterial = e.sky.sky_material
	sky.set_shader_parameter(&"top_color", Color(0.012, 0.016, 0.06))
	sky.set_shader_parameter(&"upper_color", Color(0.045, 0.055, 0.16))
	sky.set_shader_parameter(&"horizon_color", Color(0.30, 0.16, 0.32))
	sky.set_shader_parameter(&"ground_color", Color(0.02, 0.015, 0.05))
	sky.set_shader_parameter(&"sun_color", Color(0.92, 0.95, 1.0))
	sky.set_shader_parameter(&"sun_size", 0.045)
	sky.set_shader_parameter(&"halo", 0.28)
	sky.set_shader_parameter(&"stars", 1.0)
	e.ambient_light_color = Color(0.32, 0.36, 0.62)
	e.ambient_light_energy = 0.55
	e.fog_light_color = Color(0.10, 0.08, 0.20)
	e.fog_density = 0.007
	e.fog_sky_affect = 0.1
	e.glow_intensity = 0.7
	e.glow_hdr_threshold = 1.0
	e.glow_bloom = 0.0
	var moon: DirectionalLight3D = kit.sun
	moon.rotation_degrees = Vector3(-52, 150, 0)
	moon.light_color = MOON
	moon.light_energy = 0.4
	moon.light_specular = 0.2
	moon.directional_shadow_max_distance = 45.0
	# It stays off the floor and walls under the pool (through the holes it
	# would lay hard white patches on them); the drain's shaft brings it in.
	moon.light_cull_mask = BOTH | UPPER
	# Without its shadows it'd light the rest of what's under the pool too.
	moon.set_meta(&"cull_mask_unshadowed", UPPER)


# --- Materials ------------------------------------------------------------------------------

static func _materials(d) -> void:
	# Glossy things reflect the night, not the default sunset.
	d.reflection = load("res://assets/textures/stack/reflection_night.png")
	# The gameplay blocks.
	d.surface("pool_floor", {"side": "stack/concrete", "meters": 3.0, "top": "stack/pool_tiles", "top_meters": 2.0,
			"bottom": "stack/ceiling", "bottom_meters": 4.0, "top_tint": Color(0.74, 0.82, 0.86), "gloss": 0.18, "grazing": 0.55,
			"roughness": 0.35, "specular": 0.3, "lanes": Color(0.08, 0.13, 0.32, 0.9), "caustics": 0.55})
	d.surface("pool_wall", {"side": "ride_tiles", "meters": 2.0, "top": "stack/coping", "top_meters": 2.0,
			"gloss": 0.25, "grazing": 0.6, "roughness": 0.25, "specular": 0.3, "caustics": 0.5})
	d.surface("dive_block", {"side": "stack/navy_tiles", "meters": 2.0, "top": "stack/grip", "top_meters": 1.0,
			"gloss": 0.25, "grazing": 0.6, "roughness": 0.3, "caustics": 0.6})
	d.surface("cellar_floor", {"side": "stack/concrete", "meters": 3.0, "top": "stack/changing_floor", "top_meters": 2.0,
			"gloss": 0.14, "grazing": 0.5, "roughness": 0.4})
	d.surface("cellar_wall", {"side": "stack/changing_wall", "meters": 5.0, "gloss": 0.08, "grazing": 0.35, "roughness": 0.6})
	d.surface("ramp", {"side": "stack/concrete", "meters": 3.0, "top": "stack/rubber_mat", "top_meters": 1.5,
			"bottom": "stack/concrete", "gloss": 0.06, "grazing": 0.3, "roughness": 0.7})
	d.surface("pillar", {"side": "stack/pool_tiles", "meters": 2.0, "tint": Color(0.94, 0.97, 0.97), "top": "stack/steel",
			"top_meters": 1.0, "gloss": 0.22, "grazing": 0.6, "roughness": 0.3})
	d.surface("lockers_a", {"side": "stack/lockers", "meters": 2.0, "tint": Color(1.0, 0.64, 0.76), "top": "stack/steel",
			"top_meters": 1.0, "gloss": 0.18, "grazing": 0.5, "roughness": 0.4})
	d.surface("lockers_b", {"side": "stack/lockers", "meters": 2.0, "tint": Color(0.60, 0.78, 1.0), "top": "stack/steel",
			"top_meters": 1.0, "gloss": 0.18, "grazing": 0.5, "roughness": 0.4})
	# Decor (UVs in metres).
	for m: Array in [
			["steel", "stack/steel", 1.0, Color.WHITE, 0.45, 0.8, 0.25],
			["chrome", "stack/steel", 1.0, Color(1.1, 1.1, 1.15), 0.8, 0.95, 0.12],
			["dark_metal", "stack/steel", 1.0, Color(0.28, 0.30, 0.34), 0.25, 0.5, 0.4],
			["pipe_blue", "stack/steel", 1.0, Color(0.35, 0.55, 0.95), 0.3, 0.6, 0.35],
			["pipe_red", "stack/steel", 1.0, Color(0.95, 0.28, 0.22), 0.3, 0.6, 0.35],
			["pipe_grey", "stack/steel", 1.0, Color(0.75, 0.76, 0.78), 0.3, 0.6, 0.35],
			["plastic_teal", "stack/steel", 2.0, Color(0.30, 0.70, 0.72), 0.2, 0.5, 0.4],
			["plastic_yellow", "stack/steel", 2.0, Color(1.1, 0.85, 0.2), 0.2, 0.5, 0.4],
			["towel_white", "stack/coping", 1.0, Color(1.05, 1.05, 1.05), 0.02, 0.1, 0.9],
			["towel_pink", "stack/coping", 1.0, Color(1.1, 0.62, 0.78), 0.02, 0.1, 0.9],
			["towel_blue", "stack/coping", 1.0, Color(0.55, 0.75, 1.1), 0.02, 0.1, 0.9],
			["door", "stack/steel", 2.0, Color(0.52, 0.62, 0.64), 0.2, 0.5, 0.4],
			["locker_a", "stack/lockers", 2.0, Color(1.0, 0.64, 0.76), 0.18, 0.5, 0.4],
			["locker_b", "stack/lockers", 2.0, Color(0.60, 0.78, 1.0), 0.18, 0.5, 0.4],
			["tile", "stack/pool_tiles", 2.0, Color.WHITE, 0.2, 0.6, 0.3],
			["navy", "stack/navy_tiles", 2.0, Color.WHITE, 0.2, 0.6, 0.3],
			["grip", "stack/grip", 1.0, Color.WHITE, 0.05, 0.3, 0.7],
			["concrete", "stack/concrete", 3.0, Color.WHITE, 0.05, 0.3, 0.7],
			["drain", "stack/drain", 0.35, Color.WHITE, 0.3, 0.6, 0.3],
			["drain_strip", "stack/drain", 0.3, Color.WHITE, 0.3, 0.6, 0.3],
			["no_diving", "stack/no_diving", 0.45, Color.WHITE, 0.15, 0.4, 0.4],
			["wet_floor", "stack/wet_floor", 0.3, Color.WHITE, 0.1, 0.4, 0.5],
			["crack", "stack/concrete", 1.0, Color(0.12, 0.16, 0.18), 0.0, 0.1, 0.9],
			["edge_red", "stack/grip", 1.0, Color(2.2, 0.55, 0.5), 0.05, 0.2, 0.6],
			["black", "stack/steel", 1.0, Color(0.06, 0.06, 0.07), 0.2, 0.5, 0.4],
			["hazard", "hazard", 0.6, Color(0.9, 0.9, 0.9), 0.1, 0.4, 0.5]]:
		d.surface(m[0], {"side": m[1], "meters": m[2], "tint": m[3], "gloss": m[4], "grazing": m[5], "roughness": m[6], "uv": true})
	# Things that glow.
	const GLOW := "res://src/render/deco/glow.gdshader"
	d.shaded("tube", GLOW, {"color": TUBE, "energy": 2.6})
	d.shaded("pool_lens", GLOW, {"color": POOL, "energy": 3.2})
	d.shaded("puck", GLOW, {"color": Color(0.55, 0.85, 1.0), "energy": 0.55})
	d.shaded("exit", GLOW, {"color": EXIT, "energy": 2.0})
	d.shaded("aviation", GLOW, {"color": Color(1.0, 0.1, 0.08), "energy": 3.0, "blink_period": 1.6})
	# Water, light, the outside.
	d.shaded("water", "res://src/render/deco/water.gdshader", {"streaks": "stack/water.png", "height": 5.0, "opacity": 0.4,
			"meters": Vector2(0.4, 1.6), "color": Color(0.55, 0.78, 0.95)})
	for p: Array in [["puddle", Vector2(2.6, 1.8)], ["puddle_small", Vector2(1.6, 2.2)], ["puddle_big", Vector2(4.8, 4.8)]]:
		d.shaded(p[0], "res://src/render/deco/puddle.gdshader", {"reflection_map": "stack/reflection_night.png", "noise": "stack/caustics.png", "size": p[1]})
	d.shaded("beam", "res://src/render/deco/light_beam.gdshader", {"color": Color(0.55, 0.66, 1.0), "strength": 0.3, "size": Vector2(2.8, 5.0)})
	d.shaded("view", "res://src/render/deco/window_view.gdshader", {"grime": "stack/caustics.png"})
	d.shaded("telly", "res://src/render/deco/tv_screen.gdshader", {"size": Vector2(0.5, 0.38)})
	d.shaded("far", "res://src/render/deco/far_surface.gdshader", {"albedo_texture": "stack/facade.png", "meters_per_repeat": 12.0})
	d.shaded("far_dark", "res://src/render/deco/far_surface.gdshader", {"albedo_texture": "stack/concrete.png", "tint": Color(0.06, 0.06, 0.1), "meters_per_repeat": 12.0})


# --- The gameplay blocks, dressed -----------------------------------------------------------

static func _surfaces(kit, d) -> void:
	for b: Node in kit.geometry.get_children():
		var n := String(b.name)
		var dress := ""
		var layers := BOTH
		if n == "Floor":
			dress = "cellar_floor"
			layers = LOWER
		elif n.begins_with("CellarWall"):
			dress = "cellar_wall"
			layers = LOWER
		elif n.begins_with("RoofWall"):
			dress = "pool_wall"
			layers = UPPER
		elif n.begins_with("Roof_"):
			dress = "pool_floor"
		elif n.begins_with("Ramp"):
			dress = "ramp"
		elif n.begins_with("Pillar"):
			dress = "pillar"
		elif n == "CrateA":
			dress = "lockers_a"
			layers = LOWER
		elif n == "CrateB":
			dress = "lockers_b"
			layers = LOWER
		elif n.begins_with("Pulpit") or n.begins_with("LowWall"):
			dress = "dive_block"
			layers = UPPER
		if dress != "":
			b.set(&"surface", d.mat(dress))
			b.set(&"layers", layers)


## The rooms under the pool: the sky's light stops at the ceiling.
static func _indoors(kit) -> void:
	var zone := Node3D.new()
	zone.set_script(load("res://src/world/ambient_zone.gd"))
	zone.name = "Indoors"
	zone.position = Vector3(0, 2.0, 0)
	zone.set(&"size", Vector3(23, 5.5, 23))
	zone.set(&"ambient", 0.3)
	kit.root.add_child(zone)


# --- The changing rooms -------------------------------------------------------------------

## Six twin-tube fittings on the ceiling in two rows, each with its lamp.
## Two, one each side, are failing.
static func _tubes(kit, d) -> void:
	var n := 0
	for z: float in [-5.5, 5.5]:
		for x: float in [-6.0, 0.0, 6.0]:
			var at := Vector3(x, CEILING, z)
			var failing := (x == 6.0 and z == 5.5) or (x == -6.0 and z == -5.5)
			d.box("dark_metal", at + Vector3(0, -0.04, 0), Vector3(1.5, 0.08, 0.34), "Fixtures", LOWER)
			var glow := "tube"
			if failing:
				# Its own copy of the glow, for the flicker to drive.
				glow = "tube_failing_%d" % n
				d.shaded(glow, "res://src/render/deco/glow.gdshader", {"color": TUBE, "energy": 2.6})
			for dz: float in [-0.08, 0.08]:
				d.tube(glow, at + Vector3(-0.68, -0.12, dz), at + Vector3(0.68, -0.12, dz), 0.028, 6, "Fixtures", LOWER)
			var lamp: OmniLight3D = d.omni("Tube_%d" % n, at + Vector3(0, -0.35, 0), TUBE, 8.0, 1.25, BOTH | LOWER)
			if failing:
				var f := Node.new()
				f.set_script(load("res://src/world/flicker.gd"))
				f.name = "Flicker_%d" % n
				kit.lights.add_child(f)
				f.set(&"light", lamp)
				f.set(&"material", d.mat(glow))
				f.set(&"seed", float(n) * 7.3)
			n += 1


## Pipes along the tops of the walls: water (blue), drains (grey) and the
## sprinklers (red), on brackets, dropping to the floor in the corners.
static func _pipes(d) -> void:
	var runs := [
		# From, to (x, z) along a wall, at the wall's side.
		[Vector2(-10.6, -10.4), Vector2(-10.6, 10.4)], [Vector2(10.6, 10.4), Vector2(10.6, -10.4)],
		[Vector2(2.2, -10.6), Vector2(10.4, -10.6)], [Vector2(-2.2, 10.6), Vector2(-10.4, 10.6)],
	]
	for r: Array in runs:
		var a: Vector2 = r[0]
		var b: Vector2 = r[1]
		var inward := Vector3(-signf(a.x), 0, 0) if absf(a.x) > 10.0 and absf(b.x) > 10.0 else Vector3(0, 0, -signf(a.y))
		var pa := Vector3(a.x, 0, a.y)
		var pb := Vector3(b.x, 0, b.y)
		d.tube("pipe_blue", pa + Vector3(0, 4.22, 0), pb + Vector3(0, 4.22, 0), 0.1, 8, "Detail", LOWER)
		d.tube("pipe_grey", pa + inward * 0.3 + Vector3(0, 4.3, 0), pb + inward * 0.3 + Vector3(0, 4.3, 0), 0.07, 6, "Detail", LOWER)
		d.tube("pipe_red", pa + Vector3(0, 3.95, 0), pb + Vector3(0, 3.95, 0), 0.04, 6, "Detail", LOWER)
		var length := a.distance_to(b)
		for i in int(length / 2.0) + 1:
			var at := pa.lerp(pb, i * 2.0 / length) + Vector3(0, 4.12, 0)
			d.box("dark_metal", at + inward * 0.12, Vector3(0.06, 0.5, 0.06) if inward.x == 0.0 else Vector3(0.06, 0.5, 0.06), "Detail", LOWER)
	for c: Vector2 in [Vector2(-10.6, -10.4), Vector2(10.6, 10.4)]:
		d.tube("pipe_grey", Vector3(c.x, 4.3, c.y), Vector3(c.x, 0.0, c.y), 0.07, 6, "Detail", LOWER)
		d.box("drain", Vector3(c.x + 0.25 * signf(-c.x), 0.006, c.y), Vector3(0.35, 0.01, 0.35), "Detail", LOWER)


## Lockers along the walls (A's pink, B's blue) and benches, both solid.
static func _lockers_and_benches(d) -> void:
	for side: Array in [[-1.0, "locker_a", "towel_pink"], [1.0, "locker_b", "towel_blue"]]:
		var s: float = side[0]
		# Lockers: 7 m along the west wall (A) or east wall (B), 2 m tall.
		var c := Vector3(s * 10.775, 1.0, -s * 5.5)
		d.box(side[1], c, Vector3(0.45, 2.0, 7.0), "Solid", LOWER, Basis.IDENTITY, true)
		d.solid(c, Vector3(0.45, 2.0, 7.0))
		d.box("steel", c + Vector3(0, 1.01, 0), Vector3(0.47, 0.02, 7.02), "Detail", LOWER)
		for i in 4:  # Kit left on top.
			var t := c + Vector3(0, 1.06, -s * (2.6 - i * 1.7))
			d.box(side[2] if i % 2 == 0 else "towel_white", t, Vector3(0.36, 0.1, 0.3), "Detail", LOWER, Basis(Vector3.UP, 0.3 * i))
		# A bench under the windows: along the south wall (A) or north (B).
		var bc := Vector3(s * 7.0, 0.2, -s * 10.72)
		d.solid(bc, Vector3(5.6, 0.4, 0.45))
		d.box("plastic_teal", bc + Vector3(0, 0.17, 0), Vector3(5.6, 0.06, 0.45), "Solid", LOWER, Basis.IDENTITY, true)
		for lx: float in [-2.5, -0.8, 0.8, 2.5]:
			d.box("dark_metal", bc + Vector3(lx, -0.03, 0), Vector3(0.06, 0.34, 0.36), "Solid", LOWER)
		d.box(side[2], bc + Vector3(s * 1.2, 0.25, 0), Vector3(0.7, 0.04, 0.4), "Detail", LOWER, Basis(Vector3.UP, 0.4))


## Three showers along the wall across from each bank of lockers, a drain
## channel under them, puddles.
static func _showers(d) -> void:
	for s: float in [-1.0, 1.0]:
		var x := s * 10.93
		var inward := Vector3(-s, 0, 0)
		for z: float in [3.2, 5.6, 8.0]:
			var zz := z * s
			d.tube("chrome", Vector3(x, 0.9, zz), Vector3(x, 2.35, zz), 0.025, 6, "Detail", LOWER)
			d.tube("chrome", Vector3(x, 2.3, zz), Vector3(x, 2.3, zz) + inward * 0.35, 0.025, 6, "Detail", LOWER)
			d.ball("chrome", Vector3(x, 2.27, zz) + inward * 0.4, Vector3(0.1, 0.04, 0.1), 3, 8, "Detail", LOWER)
			d.ball("chrome", Vector3(x, 1.15, zz) + inward * 0.06, Vector3(0.06, 0.06, 0.06), 3, 6, "Detail", LOWER)
		d.box("drain_strip", Vector3(s * 10.65, 0.006, s * 5.6), Vector3(0.3, 0.01, 5.8), "Detail", LOWER)
		d.face("puddle_small", Vector3(s * 9.9, 0.012, s * 4.6), Vector3(0.8, 0, 0), Vector3(0, 0, -1.1), "Detail", LOWER)


## A fire door in the middle of each side wall, going nowhere, an exit sign
## glowing over it.
static func _doors(d) -> void:
	for s: float in [-1.0, 1.0]:
		var n := Vector3(-s, 0, 0)  # Facing into the room.
		var b := _facing(n)
		var wall := Vector3(s * 11.0, 0, 0)
		d.box("door", wall + n * 0.02 + Vector3(0, 1.05, 0), Vector3(1.0, 2.1, 0.04), "Detail", LOWER, b)
		d.box("dark_metal", wall + n * 0.04 + Vector3(0, 2.14, 0), Vector3(1.2, 0.08, 0.08), "Detail", LOWER, b)
		for side: float in [-0.56, 0.56]:
			d.box("dark_metal", wall + n * 0.04 + b.x * side + Vector3(0, 1.07, 0), Vector3(0.08, 2.14, 0.08), "Detail", LOWER, b)
		d.tube("steel", wall + n * 0.1 + b.x * -0.4 + Vector3(0, 1.0, 0), wall + n * 0.1 + b.x * 0.4 + Vector3(0, 1.0, 0), 0.025, 6, "Detail", LOWER)
		d.box("black", wall + n * 0.045 + Vector3(0, 1.7, 0), Vector3(0.3, 0.4, 0.01), "Detail", LOWER, b)
		# The exit sign and its green glow.
		var sign_at := wall + n * 0.08 + Vector3(0, 2.45, 0)
		d.box("dark_metal", sign_at, Vector3(0.62, 0.24, 0.1), "Fixtures", LOWER, b)
		d.face("exit", sign_at + n * 0.051, b.x * 0.28, Vector3(0, 0.1, 0), "Fixtures", LOWER)
		d.words("EXIT", sign_at + n * 0.056, b, 0.16, Color(0.02, 0.25, 0.05), 0.0, "Fixtures", LOWER)
		d.omni("Exit_%d" % int(s), sign_at + n * 0.4, EXIT, 3.5, 0.5, BOTH | LOWER, true)


## Windows onto the city above each bench.
static func _windows(d) -> void:
	for s: float in [-1.0, 1.0]:
		var n := Vector3(0, 0, s)  # A: the south wall, facing north; B: the north wall.
		var b := _facing(n)
		var wall := Vector3(0, 0, -s * 11.0)
		for i in 3:
			var cx := s * 6.8 + (i - 1) * 2.1
			var c := wall + n * 0.01 + Vector3(cx, 2.45, 0)
			d.face("view", c, b.x * 0.95, Vector3(0, 1.1, 0), "Fixtures", LOWER)
			for e: float in [-1.0, 1.0]:
				d.box("dark_metal", c + b.x * e * 1.0 + n * 0.03, Vector3(0.1, 2.3, 0.08), "Detail", LOWER, b)
		var mid := wall + n * 0.03 + Vector3(s * 6.8, 0, 0)
		d.box("dark_metal", mid + Vector3(0, 3.62, 0), Vector3(6.4, 0.1, 0.08), "Detail", LOWER, b)
		d.box("steel", mid + Vector3(0, 1.3, 0) + n * 0.06, Vector3(6.5, 0.06, 0.2), "Detail", LOWER, b)


## An old telly on a bracket in a corner of each half, left on.
static func _tellies(d) -> void:
	for s: float in [-1.0, 1.0]:
		var corner := Vector3(s * -10.2, 3.55, s * 10.2)
		var n := Vector3(s, 0, -s).normalized()
		var b := _facing(n)
		d.box("black", corner - n * 0.05, Vector3(0.72, 0.56, 0.5), "Fixtures", LOWER, b)
		d.face("telly", corner + n * 0.205, b.x * 0.25, Vector3(0, 0.19, 0), "Fixtures", LOWER)
		d.tube("dark_metal", corner - n * 0.3 + Vector3(0, 0.25, 0), corner + Vector3(s * -0.55, 0.45, s * 0.55), 0.03, 6, "Detail", LOWER)
		d.omni("Telly_%d" % int(s), corner + n * 0.7, Color(0.55, 0.65, 1.0), 4.0, 0.5, BOTH | LOWER, true)


## Signs, drains, buckets, wet-floor signs, a painted warning, and the
## ramps' open edges striped.
static func _cellar_odds(d) -> void:
	for r: Array in [[Vector3(-7, 0, -9.5), Vector3(1.66, ROOF, -9.5)], [Vector3(7, 0, 9.5), Vector3(-1.66, ROOF, 9.5)]]:
		var bottom: Vector3 = r[0]
		var top: Vector3 = r[1]
		var along := top - bottom
		var right := along.cross(Vector3.UP).normalized()  # Toward the room.
		var up := right.cross(along).normalized()
		d.face("hazard", (bottom + top) * 0.5 + right * 1.38 + up * 0.012, right * 0.12, along * 0.5, "Detail", BOTH)
	for s: float in [-1.0, 1.0]:
		# "POOL →" on the wall by each ramp's foot, pointing up it.
		d.words("POOL →", Vector3(s * 7.9, 2.4, s * 10.97), _facing(Vector3(0, 0, -s)), 0.32, Color(0.12, 0.2, 0.3), 0.0, "Detail", LOWER)
		# Floor drains round the drain's puddle, a painted warning by the spawn.
		d.box("drain", Vector3(s * 3.8, 0.006, 0), Vector3(0.35, 0.01, 0.35), "Detail", LOWER)
		d.box("drain", Vector3(0, 0.006, s * 3.8), Vector3(0.35, 0.01, 0.35), "Detail", LOWER)
		d.words("NO RUNNING", Vector3(s * -5.8, 0.008, s * 7.2), _flat(Vector3(s, 0, 0)), 0.45, Color(0.55, 0.15, 0.15), 0.0, "Detail", LOWER)
		# A mop bucket by the door, and a wet-floor sign by the drain.
		var bucket := Vector3(s * -10.3, 0.2, s * -1.3)
		d.solid(bucket, Vector3(0.5, 0.4, 0.45))
		d.box("plastic_yellow", bucket, Vector3(0.5, 0.4, 0.45), "Solid", LOWER)
		d.tube("steel", bucket + Vector3(0.1, 0.2, 0), bucket + Vector3(0.3, 1.5, 0.15), 0.02, 5, "Detail", LOWER)
		var wet := Vector3(s * -9.6, 0.3, s * -2.6)
		d.solid(wet, Vector3(0.36, 0.6, 0.3))
		var wb := Basis(Vector3.UP, 0.6 * s)
		for side: float in [-1.0, 1.0]:
			var lean := wb * Basis(Vector3.RIGHT, -side * 0.26)
			d.box("plastic_yellow", wet + wb * Vector3(0, 0, side * 0.08), Vector3(0.34, 0.62, 0.02), "Solid", LOWER, lean)
			d.face("wet_floor", wet + wb * Vector3(0, 0.02, side * 0.08) + lean.z * side * 0.012, wb.x * 0.15 * side, lean.y * 0.15, "Detail", LOWER)
	# "No diving" on the pillars, facing the drain.
	for p: Vector2 in [Vector2(-3.5, -3.5), Vector2(3.5, -3.5), Vector2(-3.5, 3.5), Vector2(3.5, 3.5)]:
		var n := Vector3(-signf(p.x), 0, 0)
		d.face("no_diving", Vector3(p.x, 2.0, p.y) + n * 0.605, _facing(n).x * 0.22, Vector3(0, 0.22, 0), "Detail", LOWER)


# --- The drain -------------------------------------------------------------------------------

## The Well is the pool's main drain: what water's left pours through it
## in four sheets, into a puddle round the shotgun; moonlight comes down
## with it, dust hanging in the shaft.
static func _the_drain(kit, d) -> void:
	var h := 1.46
	for side: Array in [[Vector3(0, 0, -h), Vector3(1, 0, 0)], [Vector3(0, 0, h), Vector3(-1, 0, 0)],
			[Vector3(-h, 0, 0), Vector3(0, 0, -1)], [Vector3(h, 0, 0), Vector3(0, 0, 1)]]:
		var c: Vector3 = side[0] + Vector3(0, 2.5, 0)
		var along: Vector3 = side[1]
		d.face("beam", Vector3(c.x * 0.93, c.y, c.z * 0.93), along * 1.3, Vector3(0, 2.5, 0), "Effects", BOTH)
	# What's left of the water spills over the lip in a few thin streams.
	for stream: Array in [[Vector3(-0.7, 0, -h), Vector3(1, 0, 0), 0.22], [Vector3(0.5, 0, -h), Vector3(1, 0, 0), 0.4],
			[Vector3(0.7, 0, h), Vector3(-1, 0, 0), 0.22], [Vector3(-0.5, 0, h), Vector3(-1, 0, 0), 0.4],
			[Vector3(-h, 0, 0.9), Vector3(0, 0, -1), 0.3], [Vector3(h, 0, -0.9), Vector3(0, 0, 1), 0.3]]:
		d.face("water", stream[0] + Vector3(0, 2.5, 0), (stream[1] as Vector3) * stream[2], Vector3(0, 2.5, 0), "Effects", BOTH)
	d.face("puddle_big", Vector3(0, 0.012, 0), Vector3(2.4, 0, 0), Vector3(0, 0, -2.4), "Detail", LOWER)
	# The rim: a steel frame round the hole on the pool's floor, the grating
	# torn half off and hanging from one side.
	for side: Array in [[Vector3(0, 0, -1.59), Vector3(3.36, 0.02, 0.18)], [Vector3(0, 0, 1.59), Vector3(3.36, 0.02, 0.18)],
			[Vector3(-1.59, 0, 0), Vector3(0.18, 0.02, 3.0)], [Vector3(1.59, 0, 0), Vector3(0.18, 0.02, 3.0)]]:
		d.box("steel", side[0] + Vector3(0, ROOF + 0.01, 0), side[1], "Detail", UPPER)
	for i in 8:
		var x := -1.2 + i * 0.34
		d.tube("dark_metal", Vector3(x, ROOF - 0.05, -1.45), Vector3(x + 0.08 * sin(i), ROOF - 0.8, -1.25), 0.02, 4, "Detail", BOTH)
	# The moon's shaft, straight down the drain (its shadows square it off
	# to the hole).
	var shaft: SpotLight3D = d.spot("DrainMoon", Vector3(0, 12.0, 0), Vector3.DOWN, Color(0.66, 0.76, 1.0), 16.0, 7.0, 10.0, BOTH | LOWER, false, true)
	shaft.shadow_bias = 0.05
	# Splashes where the water lands, dust in the light.
	var splash := CPUParticles3D.new()
	splash.name = "Splash"
	splash.position = Vector3(0, 0.05, 0)
	splash.amount = 48
	splash.lifetime = 0.6
	splash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	splash.emission_box_extents = Vector3(1.4, 0.02, 1.4)
	splash.direction = Vector3.UP
	splash.spread = 35.0
	splash.initial_velocity_min = 0.8
	splash.initial_velocity_max = 1.8
	splash.gravity = Vector3(0, -9.8, 0)
	splash.scale_amount_min = 0.03
	splash.scale_amount_max = 0.06
	splash.mesh = _dot_mesh(d.shaded("spray", "res://src/render/deco/spark.gdshader", {"color": Color(0.75, 0.9, 1.0), "energy": 0.9}))
	d.group("Effects").add_child(splash)
	var dust := CPUParticles3D.new()
	dust.name = "Dust"
	dust.position = Vector3(0, 2.5, 0)
	dust.amount = 36
	dust.lifetime = 8.0
	dust.preprocess = 8.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(1.3, 2.3, 1.3)
	dust.gravity = Vector3(0, -0.02, 0)
	dust.initial_velocity_min = 0.02
	dust.initial_velocity_max = 0.08
	dust.spread = 180.0
	dust.scale_amount_min = 0.012
	dust.scale_amount_max = 0.025
	dust.mesh = _dot_mesh(d.shaded("mote", "res://src/render/deco/spark.gdshader", {"color": Color(0.7, 0.78, 1.0), "energy": 1.4}))
	d.group("Effects").add_child(dust)


static func _dot_mesh(material: Material) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.material = material
	return q


# --- The pool ------------------------------------------------------------------------------

## Two lamps set in each wall of the pool, shining in and down across the
## tiles, as if there were still water.
static func _pool_lamps(d) -> void:
	var n := 0
	for w: Array in WALLS:
		var normal: Vector3 = w[0]
		var face: Vector3 = w[1]
		var b := _facing(normal)
		for along: float in [-5.5, 5.5]:
			var at := face + b.x * along + Vector3(0, 6.3, 0)
			d.torus("chrome", at + normal * 0.02, 0.24, 0.04, Basis(b.x, b.z, -b.y), 12, 5, "Fixtures", UPPER)
			d.ball("pool_lens", at + normal * 0.01, Vector3(0.21, 0.21, 0.21) * Vector3(1, 1, 1) - normal.abs() * 0.17, 3, 12, "Fixtures", UPPER)
			d.spot("PoolLamp_%d" % n, at + normal * 0.2, normal + Vector3.DOWN * 0.55, POOL, 10.0, 3.4, 52.0, BOTH | UPPER)
			n += 1


## Ladders, starting blocks, the diving platforms, the posts' caps, the
## drain's edge, cracked tiles round the climbing holes, puddles.
static func _pool_fittings(d) -> void:
	# Chrome ladders down the north and south walls.
	for s: float in [-1.0, 1.0]:
		var x := s * -8.5
		var z_in := s * 10.84
		var z_out := s * 11.4
		for e: float in [-0.25, 0.25]:
			var xx := x + e
			d.tube("chrome", Vector3(xx, ROOF + 0.25, z_in), Vector3(xx, WALL_TOP + 0.12, z_in), 0.025, 6, "Detail", UPPER)
			d.tube("chrome", Vector3(xx, WALL_TOP + 0.12, z_in), Vector3(xx, WALL_TOP + 0.12, z_out), 0.025, 6, "Detail", UPPER)
			d.tube("chrome", Vector3(xx, ROOF + 0.25, z_in), Vector3(xx, ROOF + 0.25, s * 11.0), 0.025, 6, "Detail", UPPER)
		for i in 5:
			var y := ROOF + 0.6 + i * 0.5
			d.tube("chrome", Vector3(x - 0.25, y, z_in), Vector3(x + 0.25, y, z_in), 0.02, 5, "Detail", UPPER)
	# Starting blocks on the low walls: two each, numbered for their lanes,
	# handles on the pool side.
	for s: float in [-1.0, 1.0]:
		var zc := s * -5.0
		var pool_side := Vector3(0, 0, s)
		var lanes := ["4", "5"] if s > 0.0 else ["5", "4"]
		for i in 2:
			var x := -1.375 + i * 2.75
			d.box("grip", Vector3(x, 6.225, zc), Vector3(0.6, 0.05, 0.55), "Detail", UPPER, Basis(Vector3.RIGHT, -0.08 * s))
			d.words(lanes[i], Vector3(x, 5.75, zc + s * 0.31), _facing(pool_side), 0.45, Color(0.95, 0.95, 0.98), 0.0, "Detail", UPPER)
			for hx: float in [-0.18, 0.18]:
				d.tube("chrome", Vector3(x + hx, 6.1, zc + s * 0.3), Vector3(x + hx, 6.1, zc + s * 0.42), 0.02, 5, "Detail", UPPER)
			d.tube("chrome", Vector3(x - 0.18, 6.1, zc + s * 0.42), Vector3(x + 0.18, 6.1, zc + s * 0.42), 0.02, 5, "Detail", UPPER)
		d.face("no_diving", Vector3(0, 5.6, zc + s * 0.305), _facing(pool_side).x * 0.2, Vector3(0, 0.2, 0), "Detail", UPPER)
	# The diving platforms: a big number on the face to the pool, a red edge
	# round the top, a ladder up the back.
	for s: float in [-1.0, 1.0]:
		var c := Vector3(s * -7.0, 6.25, s * -5.0)
		var front := Vector3(s, 0, 0)
		d.words("1" if s > 0.0 else "2", c + front * 1.26 + Vector3(0, 0.1, 0), _facing(front), 1.5, Color(0.95, 0.95, 1.0), 0.0, "Detail", UPPER)
		for e: Array in [[Vector3(0, 0, 1.2), Vector3(2.5, 0.01, 0.1)], [Vector3(0, 0, -1.2), Vector3(2.5, 0.01, 0.1)],
				[Vector3(1.2, 0, 0), Vector3(0.1, 0.01, 2.5)], [Vector3(-1.2, 0, 0), Vector3(0.1, 0.01, 2.5)]]:
			d.box("edge_red", c + e[0] + Vector3(0, 1.255, 0), e[1], "Detail", UPPER)
		var back := c - front * 1.27
		for e: float in [-0.25, 0.25]:
			d.tube("chrome", back + Vector3(0, -1.25, e), back + Vector3(0, 2.1, e), 0.025, 6, "Detail", UPPER)
		for i in 5:
			d.tube("chrome", back + Vector3(0, -0.9 + i * 0.5, -0.25), back + Vector3(0, -0.9 + i * 0.5, 0.25), 0.02, 5, "Detail", UPPER)
	# The posts round the drain: a glowing cap each.
	for p: Vector2 in [Vector2(-3.5, -3.5), Vector2(3.5, -3.5), Vector2(-3.5, 3.5), Vector2(3.5, 3.5)]:
		d.ball("puck", Vector3(p.x, 6.2, p.y), Vector3(0.22, 0.03, 0.22), 2, 10, "Fixtures", UPPER)
	# Cracked, lifted tiles round the two holes you climb out of.
	for hole: Rect2 in [Rect2(-7.5, 1.5, 3, 3), Rect2(4.5, -4.5, 3, 3)]:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(hole.position)
		for i in 10:
			var edge := rng.randi_range(0, 3)
			var t := rng.randf()
			var p := Vector2.ZERO
			match edge:
				0: p = Vector2(lerpf(hole.position.x, hole.end.x, t), hole.position.y - rng.randf_range(0.1, 0.5))
				1: p = Vector2(lerpf(hole.position.x, hole.end.x, t), hole.end.y + rng.randf_range(0.1, 0.5))
				2: p = Vector2(hole.position.x - rng.randf_range(0.1, 0.5), lerpf(hole.position.y, hole.end.y, t))
				_: p = Vector2(hole.end.x + rng.randf_range(0.1, 0.5), lerpf(hole.position.y, hole.end.y, t))
			var tilt := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3))
			d.box("tile", Vector3(p.x, ROOF + 0.03, p.y), Vector3(0.24, 0.03, 0.24), "Detail", UPPER, tilt)
		for i in 5:
			var from := Vector2(hole.position.x if i % 2 == 0 else hole.end.x, hole.position.y if i < 2 else hole.end.y)
			var dir := Vector2.from_angle(rng.randf() * TAU)
			if hole.has_point(from + dir * 0.5):
				dir = -dir
			var mid := from + dir * 0.5
			d.box("crack", Vector3(mid.x, ROOF + 0.004, mid.y), Vector3(0.03, 0.005, 1.0), "Detail", UPPER, Basis(Vector3.UP, atan2(dir.x, dir.y)))
	# Puddles where the water stood last.
	for p: Vector3 in [Vector3(4.2, 0, 7.4), Vector3(-4.2, 0, -7.4), Vector3(9.0, 0, -1.2), Vector3(-9.0, 0, 1.2)]:
		d.face("puddle", p + Vector3(0, ROOF + 0.012, 0), Vector3(1.3, 0, 0), Vector3(0, 0, -0.9), "Detail", UPPER)


## Depth marks on the walls, "deep end" at each end.
static func _pool_markings(d) -> void:
	for w: Array in WALLS:
		var normal: Vector3 = w[0]
		var b := _facing(normal)
		var face: Vector3 = w[1] + normal * 0.012
		for along: float in [-7.0, 0.0, 7.0]:
			var text := "3.0 M"
			if along == 0.0 and absf(normal.z) > 0.5:
				text = "DEEP END"
			d.words(text, face + b.x * along + Vector3(0, 7.55, 0), b, 0.34, Color(0.08, 0.14, 0.34), 0.0, "Detail", UPPER)


## Neon over the pool, on the side walls: "POOL CLOSED" (failing) and
## "NO LIFEGUARD", each lighting its wall.
static func _neon(d) -> void:
	for s: Array in [[1.0, "POOL CLOSED", 0.7, Color(1.0, 0.2, 0.3)], [-1.0, "NO LIFEGUARD", 0.0, Color(0.3, 0.55, 1.0)]]:
		var x: float = s[0] * 11.0
		var n := Vector3(-s[0], 0, 0)
		var b := _facing(n)
		var at := Vector3(x, 6.6, 0) + n * 0.06
		var colour: Color = s[3]
		d.box("black", at - n * 0.03, Vector3(3.4, 0.62, 0.04), "Fixtures", UPPER, b)
		d.words(s[1], at + n * 0.012, b, 0.4, colour.lightened(0.55), 0.0, "Fixtures", UPPER).shaded = false
		var halo := "halo_%d" % int(s[0])
		d.shaded(halo, "res://src/render/deco/halo.gdshader", {"color": colour, "strength": 1.6, "size": Vector2(4.2, 1.2), "flicker": s[2]})
		d.face(halo, at + n * 0.02, b.x * 2.1, Vector3(0, 0.6, 0), "Fixtures", UPPER)
		d.omni("Neon_%d" % int(s[0]), at + n * 0.8, colour, 6.0, 1.3, BOTH | UPPER, true)


# --- Up in the sky -----------------------------------------------------------------------------

## Inflatables adrift over the pool, where the water would have taken
## them: a flamingo ring, a beach ball, a rubber duck.
static func _inflatables(d) -> void:
	var shader := "res://src/render/deco/float_prop.gdshader"
	var params := {"reflection_map": "stack/reflection_night.png"}
	# Flamingo ring.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_ring(st, 1.7, 0.5, Color(1.0, 0.42, 0.62), Color(1.0, 0.92, 0.95))
	var neck := [Vector3(1.7, 0.3, 0), Vector3(2.0, 0.9, 0), Vector3(2.05, 1.5, 0), Vector3(1.85, 2.0, 0), Vector3(1.5, 2.3, 0)]
	for i in neck.size():
		_blob(st, neck[i], Vector3.ONE * lerpf(0.36, 0.26, float(i) / neck.size()), Color(1.0, 0.45, 0.65))
	_blob(st, Vector3(1.3, 2.4, 0), Vector3(0.36, 0.3, 0.3), Color(1.0, 0.5, 0.7))
	_blob(st, Vector3(0.95, 2.3, 0), Vector3(0.22, 0.1, 0.1), Color(0.1, 0.1, 0.12))
	_blob(st, Vector3(1.3, 2.52, 0.2), Vector3(0.06, 0.06, 0.06), Color(0.05, 0.05, 0.05))
	_floater(d, "Flamingo", st, Vector3(3.0, 12.5, -3.0), shader, params, 0.0)
	# Beach ball.
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var colours := [Color(0.95, 0.15, 0.15), Color.WHITE, Color(0.15, 0.35, 0.95), Color(1.0, 0.85, 0.1), Color.WHITE, Color(0.15, 0.8, 0.35)]
	_blob(st, Vector3.ZERO, Vector3.ONE * 1.1, Color.WHITE, colours)
	_floater(d, "BeachBall", st, Vector3(-5.5, 11.0, 4.5), shader, params, 2.0)
	# Rubber duck.
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var yellow := Color(1.0, 0.84, 0.12)
	_blob(st, Vector3(0, 0, 0), Vector3(1.4, 0.9, 1.0), yellow)
	_blob(st, Vector3(0.9, 1.0, 0), Vector3(0.7, 0.7, 0.7), yellow)
	_blob(st, Vector3(-1.2, 0.4, 0), Vector3(0.4, 0.5, 0.35), yellow)
	_blob(st, Vector3(1.6, 0.9, 0), Vector3(0.35, 0.14, 0.3), Color(1.0, 0.45, 0.1))
	for e: float in [-0.32, 0.32]:
		_blob(st, Vector3(1.3, 1.25, e), Vector3(0.1, 0.12, 0.08), Color(0.05, 0.05, 0.06))
	_floater(d, "Duck", st, Vector3(-1.0, 14.0, -7.5), shader, params, 4.0, 1.8)


static func _floater(d, node_name: String, st: SurfaceTool, at: Vector3, shader: String, params: Dictionary, phase: float, scale := 1.0) -> void:
	var p := params.duplicate()
	p["phase"] = phase
	var m: ShaderMaterial = d.shaded("float_" + node_name.to_lower(), shader, p)
	var mesh := st.commit()
	var file: String = d.dir + "meshes/float_%s.res" % node_name.to_lower()
	ResourceSaver.save(mesh, file)
	d.own_mesh(node_name, load(file), m, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale), at), "Detail", BOTH | UPPER)


## A ring, striped in two colours.
static func _ring(st: SurfaceTool, big: float, small: float, a: Color, b: Color) -> void:
	var seg := 20
	var sides := 8
	for i in seg:
		for j in sides:
			var q := []
			for k: Vector2i in [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]:
				var u := TAU * k.x / seg
				var v := TAU * k.y / sides
				var n := Vector3(cos(u) * cos(v), sin(v), sin(u) * cos(v))
				q.append([Vector3(cos(u), 0, sin(u)) * big + n * small, n])
			var c := a if (i / 2) % 2 == 0 else b
			for k: int in [0, 1, 2, 0, 2, 3]:
				st.set_color(c)
				st.set_normal(q[k][1])
				st.add_vertex(q[k][0])


## A ball (squashed by `r`), one colour or stripes of `bands` round it.
static func _blob(st: SurfaceTool, c: Vector3, r: Vector3, colour: Color, bands: Array = []) -> void:
	var rings := 8
	var sides := 12
	var at := func(i: int, j: int) -> Vector3:
		var lat := PI * (float(i) / rings - 0.5)
		var lon := TAU * j / sides
		return Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
	for i in rings:
		for j in sides:
			var q := [at.call(i, j), at.call(i + 1, j), at.call(i + 1, j + 1), at.call(i, j + 1)]
			var col: Color = bands[j * bands.size() / sides] if not bands.is_empty() else colour
			for k: int in [0, 2, 1, 0, 3, 2]:
				var dir: Vector3 = q[k]
				st.set_color(col)
				st.set_normal((dir / r).normalized())
				st.add_vertex(c + dir * r)


# --- The city ------------------------------------------------------------------------------

## The tower the pool sits on, going down into the fog, and the city round
## it: towers with their windows lit here and there, aviation lights
## blinking on the tall ones, and a hotel sign in pink neon.
static func _skyline(d) -> void:
	# Our own tower, below the pool.
	for w: Array in WALLS:
		var n: Vector3 = -(w[0] as Vector3)
		var face: Vector3 = (w[1] as Vector3) + n * 1.02
		d.face("far", face + Vector3(0, WALL_TOP - 75.0, 0), _facing(n).x * 12.0, Vector3(0, 75.0, 0), "Far", BOTH)
	var towers := [
		[Vector2(-62, -28), Vector2(18, 18), 30.0], [Vector2(-46, 55), Vector2(14, 20), 12.0], [Vector2(52, -58), Vector2(20, 16), 44.0],
		[Vector2(78, 18), Vector2(16, 16), 18.0], [Vector2(20, 82), Vector2(24, 14), 26.0], [Vector2(-84, 8), Vector2(20, 28), -4.0],
		[Vector2(8, -88), Vector2(18, 18), 8.0], [Vector2(-32, -82), Vector2(14, 14), 56.0], [Vector2(94, -22), Vector2(12, 12), 64.0],
		[Vector2(-98, -62), Vector2(22, 22), 20.0], [Vector2(62, 72), Vector2(18, 18), 4.0], [Vector2(-22, 112), Vector2(30, 18), 36.0],
		[Vector2(124, 58), Vector2(20, 20), 24.0], [Vector2(-124, 40), Vector2(16, 16), 42.0], [Vector2(42, -124), Vector2(26, 18), 14.0],
		[Vector2(-72, 92), Vector2(14, 14), 70.0], [Vector2(140, -80), Vector2(24, 24), 34.0], [Vector2(-150, -20), Vector2(26, 20), 28.0],
	]
	for t: Array in towers:
		var p: Vector2 = t[0]
		var size: Vector2 = t[1]
		var top: float = t[2]
		var bottom := -120.0
		var c := Vector3(p.x, (top + bottom) * 0.5, p.y)
		var hh := (top - bottom) * 0.5
		d.face("far", c + Vector3(0, 0, size.y * 0.5), Vector3(size.x * 0.5, 0, 0), Vector3(0, hh, 0), "Far", BOTH)
		d.face("far", c + Vector3(0, 0, -size.y * 0.5), Vector3(-size.x * 0.5, 0, 0), Vector3(0, hh, 0), "Far", BOTH)
		d.face("far", c + Vector3(size.x * 0.5, 0, 0), Vector3(0, 0, -size.y * 0.5), Vector3(0, hh, 0), "Far", BOTH)
		d.face("far", c + Vector3(-size.x * 0.5, 0, 0), Vector3(0, 0, size.y * 0.5), Vector3(0, hh, 0), "Far", BOTH)
		d.face("far_dark", Vector3(p.x, top, p.y), Vector3(size.x * 0.5, 0, 0), Vector3(0, 0, -size.y * 0.5), "Far", BOTH)
		if top > 25.0:
			d.box("far_dark", Vector3(p.x, top + 3.0, p.y), Vector3(0.4, 6.0, 0.4), "Far", BOTH)
			d.box("aviation", Vector3(p.x, top + 6.2, p.y), Vector3(0.6, 0.6, 0.6), "Far", BOTH)
	# The hotel sign across the way, facing the pool.
	var sign_at := Vector3(52, 52.0, -58)
	var n := (-sign_at * Vector3(1, 0, 1)).normalized()
	var b := _facing(n)
	d.box("far_dark", sign_at, Vector3(22, 7, 0.6), "Far", BOTH, b)
	d.words("HOTEL ♥", sign_at + n * 0.4, b, 5.0, Color(1.0, 0.72, 0.88), 0.0, "Far", BOTH).shaded = false
	d.shaded("halo_hotel", "res://src/render/deco/halo.gdshader", {"color": Color(1.0, 0.3, 0.7), "strength": 1.4, "size": Vector2(26, 9)})
	d.face("halo_hotel", sign_at + n * 0.35, b.x * 13.0, Vector3(0, 4.5, 0), "Far", BOTH)
