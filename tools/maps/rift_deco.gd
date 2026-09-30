extends RefCounted
## RIFT, dressed (GDD §9.3): Nimbus, the last station of the Cloud Line,
## cut into a mountain above a sea of cloud, at dawn, waiting for the
## first train.
##
## The canyon is the station's cutting, its walls glazed tile (the
## wall-ride tiles, as on every map) in bays between cream pilasters, banded
## in the line's maroon and cream, lamps set flush along them still lit,
## and the station's name in big lit letters across the north wall. Three
## tracks run down the floor on ballast and up both end ramps, which are
## the inclines of a rack railway (a toothed rail between the running
## rails): the line climbs out of the cutting at each end to buffers at
## the edge; far off it strides between the peaks on viaducts. The shelves are
## galleries along the walls; the ramps up the walls are the passenger
## ramps; the High Bridge and the Mid Bridge are iron footbridges, and the
## station clock hangs under the high one over the island in the middle
## (Meet me under the clock). The Arch is the station building across the
## tracks, the middle one running through it (the shotgun waits in the
## tunnel), the others ending at portals bricked up long ago, the
## departures on its front. The colonnade is what's left of a train shed:
## brick piers, iron arches, the glass gone. The Arch's crates are two
## goods wagons; the ruins a stack of left luggage, the ticket kiosk and the
## waiting room. The rims are the mountain's shoulders either side of the
## cutting: turf, rock, old snow in the hollows, dry-stone walls, and a
## signal box with its semaphore on each for the snipers. The sun is just
## up in the east, straight down the cutting; the peaks all round stand
## pink out of the cloud, their shadows blue. The gameplay blocks are
## untouched, only dressed.

const DecoKit := preload("res://tools/deco_kit.gd")
const Signs := preload("res://tools/sign_kit.gd")
const Rift := preload("res://tools/maps/rift.gd")
## Typefaces (assets/fonts/): the line's enamel signs, the station's name,
## the departures, a notice.
const SANS := "DejaVuSans-Bold.ttf"
const SERIF := "DejaVuSerif-Bold.ttf"
const MONO := "LiberationMono-Bold.ttf"
const ITALIC := "LiberationSerif-Italic.ttf"
const SWASH := "LiberationSerif-BoldItalic.ttf"
const BOTH := DecoKit.LAYER_BOTH

const GLOW := "res://src/render/deco/glow.gdshader"
const LIGHTBOX := "res://src/render/deco/lightbox.gdshader"
const FAR := "res://src/render/deco/far_surface.gdshader"
const WARM := Color(1.0, 0.84, 0.6)
const CREAM := Color(0.95, 0.9, 0.76)

const NORTH := Rift.NORTH
const SOUTH := Rift.SOUTH
## The tracks' middles (z): 1 north, 2 through the station building, 3 south.
const TRACKS := [-9.0, 0.0, 9.0]
## The sun's rotation: low in the east, a little south of it.
const SUN := Vector3(-18, 70, 0)
## Standard gauge, half of it.
const GAUGE := 0.7175


static func dress(kit, d) -> void:
	_dawn(kit)
	_materials(d)
	_surfaces(kit, d)
	_tracks(d)
	_walls(d)
	_galleries(d)
	_bridges(d)
	_station_building(kit, d)
	_wagons(d)
	_luggage_kiosk_waiting_room(d)
	_island(d)
	_train_shed(d)
	_signal_boxes(d)
	_shoulders(d)
	_ends(d)
	_mountain(d)
	_cloud_sea(d)
	_viaducts(d)


# --- Morning -----------------------------------------------------------------------------

## Dawn: the sun just up in the east, low, looking straight down the
## cutting; the sky deep blue overhead and pink and gold low down, the
## cloud lit from above; blue in every shadow.
static func _dawn(kit) -> void:
	var e: Environment = kit.environment
	var sky: ShaderMaterial = e.sky.sky_material
	sky.set_shader_parameter(&"top_color", Color(0.10, 0.17, 0.40))
	sky.set_shader_parameter(&"upper_color", Color(0.34, 0.40, 0.66))
	sky.set_shader_parameter(&"horizon_color", Color(1.0, 0.70, 0.52))
	sky.set_shader_parameter(&"ground_color", Color(0.94, 0.80, 0.74))
	sky.set_shader_parameter(&"sun_color", Color(1.0, 0.84, 0.62))
	sky.set_shader_parameter(&"sun_size", 0.04)
	sky.set_shader_parameter(&"halo", 0.55)
	sky.set_shader_parameter(&"stars", 0.0)
	e.ambient_light_color = Color(0.46, 0.52, 0.76)
	e.ambient_light_energy = 0.55
	e.fog_light_color = Color(0.86, 0.72, 0.72)
	e.fog_density = 0.0018
	e.fog_sky_affect = 0.0
	e.glow_intensity = 0.6
	e.glow_hdr_threshold = 1.0
	e.glow_bloom = 0.0
	var sun: DirectionalLight3D = kit.sun
	sun.rotation_degrees = SUN
	sun.light_color = Color(1.0, 0.74, 0.52)
	sun.light_energy = 1.15
	sun.light_specular = 0.25


# --- Materials --------------------------------------------------------------------------------

static func _materials(d) -> void:
	d.reflection = load("res://assets/textures/rift/reflection_day.png")
	# The gameplay blocks.
	d.surface("trackbed", {"side": "rift/rock", "meters": 12.0, "top": "rift/ballast", "top_meters": 2.0,
			"gloss": 0.02, "grazing": 0.2, "roughness": 0.9})
	d.surface("gallery", {"side": "ride_tiles", "meters": 2.0, "top": "rift/flags", "top_meters": 3.0, "top_tint": Color(0.74, 0.72, 0.68),
			"gloss": 0.2, "grazing": 0.5, "roughness": 0.35, "specular": 0.2})
	# Tiles below, turf on top: one material, so a gloss between the two.
	d.surface("wall", {"side": "ride_tiles", "meters": 2.0, "top": "rift/meadow", "top_meters": 12.0,
			"gloss": 0.14, "grazing": 0.4, "roughness": 0.5, "specular": 0.15})
	d.surface("overhang", {"side": "ride_tiles", "meters": 2.0, "top": "rift/flags", "top_meters": 3.0, "top_tint": Color(0.74, 0.72, 0.68),
			"bottom": "stack/ceiling", "bottom_meters": 3.0, "gloss": 0.35, "grazing": 0.75, "roughness": 0.15})
	d.surface("incline", {"side": "rift/rock", "meters": 12.0, "top": "rift/ballast", "top_meters": 2.0,
			"gloss": 0.02, "grazing": 0.2, "roughness": 0.9})
	d.surface("passage", {"side": "rift/flags", "meters": 3.0, "tint": Color(0.7, 0.68, 0.66), "top": "rift/flags", "top_meters": 3.0,
			"top_tint": Color(0.74, 0.72, 0.68),
			"bottom": "rift/flags", "gloss": 0.05, "grazing": 0.3, "roughness": 0.7})
	d.surface("footbridge", {"side": "stack/steel", "meters": 1.0, "tint": Color(0.30, 0.42, 0.36), "top": "terrace/wood",
			"top_meters": 1.0, "top_tint": Color(0.85, 0.78, 0.7), "bottom": "stack/steel", "gloss": 0.2, "grazing": 0.5, "roughness": 0.5})
	d.surface("brick", {"side": "bricks", "meters": 2.0, "tint": Color(0.82, 0.64, 0.58), "top": "rift/flags", "top_meters": 3.0,
			"bottom": "stack/ceiling", "gloss": 0.03, "grazing": 0.2, "roughness": 0.85})
	d.surface("pier", {"side": "bricks", "meters": 2.0, "tint": Color(0.82, 0.64, 0.58), "top": "rift/flags", "top_meters": 3.0,
			"gloss": 0.03, "grazing": 0.2, "roughness": 0.85})
	d.surface("stone", {"side": "rift/flags", "meters": 3.0, "tint": Color(0.82, 0.8, 0.76), "top": "rift/flags", "top_meters": 3.0,
			"top_tint": Color(0.74, 0.72, 0.68), "gloss": 0.05, "grazing": 0.3,
			"roughness": 0.7})
	d.surface("drystone", {"side": "rift/scree", "meters": 4.0, "top": "rift/scree", "top_meters": 4.0, "top_tint": Color(0.9, 0.9, 0.92),
			"gloss": 0.03, "grazing": 0.2, "roughness": 0.85})
	d.surface("cliff_face", {"side": "rift/cliff", "meters": 16.0, "top": "rift/meadow", "top_meters": 24.0, "gloss": 0.04,
			"grazing": 0.25, "roughness": 0.8, "uv": true})
	d.surface("rockery", {"side": "rift/cliff", "meters": 8.0, "top": "rift/alpine", "top_meters": 8.0, "gloss": 0.04, "grazing": 0.25,
			"roughness": 0.8})
	d.surface("wagon", {"side": "terrace/wood", "meters": 1.0, "tint": Color(0.62, 0.42, 0.34), "top": "terrace/wood", "top_meters": 1.0,
			"top_tint": Color(0.45, 0.36, 0.3), "gloss": 0.05, "grazing": 0.3, "roughness": 0.7})
	d.surface("luggage", {"side": "terrace/wood", "meters": 1.0, "tint": Color(0.55, 0.36, 0.24), "top": "terrace/wood", "top_meters": 1.0,
			"top_tint": Color(0.5, 0.35, 0.25), "gloss": 0.1, "grazing": 0.4, "roughness": 0.6})
	d.surface("kiosk", {"side": "stack/steel", "meters": 1.0, "tint": Color(0.52, 0.10, 0.14), "top": "stack/steel", "top_meters": 1.0,
			"top_tint": Color(0.25, 0.25, 0.28), "gloss": 0.3, "grazing": 0.6, "roughness": 0.35})
	# Decor (UVs in metres).
	for m: Array in [
			["steel", "stack/steel", 1.0, Color.WHITE, 0.45, 0.8, 0.25],
			["rail", "stack/steel", 1.0, Color(0.72, 0.68, 0.64), 0.6, 0.9, 0.2],
			["dark_metal", "stack/steel", 1.0, Color(0.24, 0.24, 0.27), 0.25, 0.5, 0.4],
			["black", "stack/steel", 1.0, Color(0.05, 0.05, 0.06), 0.2, 0.5, 0.4],
			["iron", "stack/steel", 1.0, Color(0.30, 0.42, 0.36), 0.25, 0.5, 0.4],
			["brass", "stack/steel", 1.0, Color(1.25, 0.92, 0.45), 0.6, 0.9, 0.2],
			["sleeper", "terrace/wood", 1.0, Color(0.26, 0.23, 0.22), 0.02, 0.1, 0.9],
			["wood", "terrace/wood", 1.0, Color.WHITE, 0.1, 0.4, 0.5],
			["maroon", "stack/steel", 1.0, Color(0.50, 0.09, 0.13), 0.3, 0.6, 0.3],
			["cream", "stack/steel", 1.0, Color(1.15, 1.08, 0.88), 0.3, 0.6, 0.3],
			["navy", "stack/steel", 1.0, Color(0.10, 0.16, 0.38), 0.55, 0.85, 0.2],
			["white", "stack/steel", 1.0, Color(1.2, 1.2, 1.2), 0.3, 0.6, 0.3],
			["red", "stack/steel", 1.0, Color(0.85, 0.12, 0.12), 0.35, 0.6, 0.3],
			["glass_dark", "stack/steel", 1.0, Color(0.12, 0.16, 0.20), 0.7, 0.95, 0.1],
			["brick", "bricks", 2.0, Color(0.82, 0.64, 0.58), 0.03, 0.2, 0.85],
			["brick_dark", "bricks", 2.0, Color(0.55, 0.40, 0.38), 0.03, 0.2, 0.85],
			["stone", "rift/flags", 3.0, Color.WHITE, 0.05, 0.3, 0.7],
			["tile_maroon", "bathroom_tiles", 1.0, Color(0.62, 0.16, 0.22), 0.35, 0.75, 0.15],
			["tile_cream", "bathroom_tiles", 1.0, Color(1.2, 1.12, 0.9), 0.35, 0.75, 0.15],
			["leather", "terrace/wood", 1.0, Color(0.55, 0.30, 0.18), 0.2, 0.5, 0.4],
			["trunk_green", "stack/steel", 1.0, Color(0.20, 0.36, 0.26), 0.25, 0.5, 0.4],
			["trunk_navy", "stack/steel", 1.0, Color(0.14, 0.18, 0.34), 0.25, 0.5, 0.4],
			["canvas", "terrace/stucco", 4.0, Color(0.95, 0.88, 0.72), 0.02, 0.1, 0.9],
			["paper", "terrace/stucco", 4.0, Color(1.3, 1.25, 1.15), 0.02, 0.1, 0.9],
			["foliage", "terrace/foliage", 1.0, Color.WHITE, 0.2, 0.5, 0.35],
			["hazard", "hazard", 0.5, Color.WHITE, 0.1, 0.4, 0.5],
			["paint_yellow", "switchback/paint", 1.0, Color(1.2, 0.95, 0.25), 0.08, 0.35, 0.6],
			["paint_white", "switchback/paint", 1.0, Color(1.05, 1.05, 1.05), 0.08, 0.35, 0.6],
			["rubber", "stack/steel", 1.0, Color(0.04, 0.04, 0.045), 0.3, 0.55, 0.35]]:
		d.surface(m[0], {"side": m[1], "meters": m[2], "tint": m[3], "gloss": m[4], "grazing": m[5], "roughness": m[6], "uv": true})
	# Things that glow.
	d.shaded("lamp", GLOW, {"color": WARM, "energy": 2.6})
	d.shaded("letters", GLOW, {"color": Color(1.0, 0.9, 0.7), "energy": 2.2})
	d.shaded("window_warm", GLOW, {"color": Color(1.0, 0.78, 0.5), "energy": 1.1})
	d.shaded("amber", GLOW, {"color": Color(1.0, 0.62, 0.15), "energy": 1.8})
	d.shaded("signal_red", GLOW, {"color": Color(1.0, 0.12, 0.08), "energy": 3.0})
	d.shaded("signal_green", GLOW, {"color": Color(0.3, 1.0, 0.45), "energy": 3.0})
	d.shaded("aviation", GLOW, {"color": Color(1.0, 0.1, 0.08), "energy": 3.0, "blink_period": 1.6})
	for p: String in ["peak", "viaduct", "balloon"]:
		d.shaded("poster_" + p, LIGHTBOX, {"picture": "rift/poster_%s.png" % p, "size": Vector2(1.2, 1.8), "energy": 0.85})
	# Far off.
	# The mountains' faces aren't lit (far off, flat), so each comes lit,
	# half-lit and shaded, picked by how the face turns to the sun.
	# The dawn on them: pink and gold where the sun's on them, blue in shade.
	for k: Array in [["cliff", 24.0, Color(1.1, 0.84, 0.72), Color(0.74, 0.72, 0.84), Color(0.44, 0.50, 0.72)],
			["scree", 20.0, Color(1.1, 0.84, 0.72), Color(0.74, 0.72, 0.84), Color(0.44, 0.50, 0.72)],
			["snow", 48.0, Color(1.18, 0.9, 0.8), Color(0.86, 0.84, 0.94), Color(0.56, 0.64, 0.88)]]:
		for i in 3:
			d.shaded("far_%s_%s" % [k[0], ["lit", "mid", "shade"][i]], FAR, {"albedo_texture": "rift/%s.png" % k[0],
					"meters_per_repeat": k[1], "tint": k[2 + i]})
	d.shaded("far_cloud", FAR, {"albedo_texture": "rift/clouds.png", "meters_per_repeat": 160.0, "tint": Color(1.02, 0.93, 0.92)})
	d.shaded("far_stone", FAR, {"albedo_texture": "rift/flags.png", "meters_per_repeat": 12.0, "tint": Color(0.82, 0.78, 0.74)})
	d.shaded("far_maroon", FAR, {"albedo_texture": "stack/steel.png", "meters_per_repeat": 4.0, "tint": Color(0.5, 0.1, 0.14)})
	d.shaded("far_cream", FAR, {"albedo_texture": "stack/steel.png", "meters_per_repeat": 4.0, "tint": Color(1.1, 1.05, 0.88)})


# --- The gameplay blocks, dressed ------------------------------------------------------------

const DRESS := {
	"Floor": "trackbed", "FloorFloor": "trackbed", "NorthRim": "wall", "NorthRimFloor": "wall", "SouthRim": "wall",
	"SouthRimFloor": "wall", "WestRamp": "incline", "EastRamp": "incline", "NorthShelf": "gallery", "NorthShelfFloor": "gallery",
	"SouthShelf": "gallery", "SouthShelfFloor": "gallery", "FloorToNorthShelf": "passage", "NorthShelfToRim": "passage",
	"NorthShelfToRimTop": "passage", "FloorToSouthShelf": "passage", "SouthShelfToRim": "passage", "SouthShelfToRimTop": "passage",
	"HighBridge": "footbridge", "MidBridge": "footbridge", "ArchN": "brick", "ArchS": "brick", "ArchRoof": "brick",
	"ArchCrateW": "wagon", "ArchCrateE": "wagon", "Ruin1": "luggage", "Ruin2": "kiosk", "Ruin3": "brick", "UnderBridge": "stone",
	"Overhang": "overhang", "NorthTower": "brick", "NorthTowerRamp": "passage", "NorthTowerWall": "stone", "SouthTower": "brick",
	"SouthTowerRamp": "passage", "SouthTowerWall": "stone", "NorthRock": "rockery", "SouthRock": "rockery",
}


static func _surfaces(kit, d) -> void:
	for b: Node in kit.geometry.get_children():
		var n := String(b.name)
		var dress: String = DRESS.get(n, "")
		if n.begins_with("Column_"):
			dress = "pier"
		elif n.contains("RimCover_"):
			dress = "drystone"
		if dress != "":
			b.set(&"surface", d.mat(dress))


# --- The tracks ---------------------------------------------------------------------------

## Three tracks down the floor and up both inclines, sleepers on the
## ballast; a toothed rack rail between the running rails up the inclines.
## The north and south tracks meet the station building's bricked-up
## portals; the middle one runs through it and ends at buffers either side
## of the island.
static func _tracks(d) -> void:
	for z: float in TRACKS:
		_track(d, Vector3(-100, SOUTH, z), Vector3(-60, 0, z))
		_track(d, Vector3(60, 0, z), Vector3(100, NORTH, z))
		if z == 0.0:
			_track(d, Vector3(-60, 0, z), Vector3(-4.6, 0, z))
			_track(d, Vector3(4.6, 0, z), Vector3(60, 0, z))
		else:
			_track(d, Vector3(-60, 0, z), Vector3(-34, 0, z))
			_track(d, Vector3(-26, 0, z), Vector3(60, 0, z))


## A straight run of track from `a` to `b` (west to east), on the surface
## through them.
static func _track(d, a: Vector3, b: Vector3) -> void:
	var dir := (b - a).normalized()
	var length := a.distance_to(b)
	var up := Vector3(0, 0, 1).cross(dir)
	var basis := Basis(dir, up, Vector3(0, 0, 1))
	var steep := absf(dir.y) > 0.1
	var n := int(length / 0.65)
	for i in n:
		var p := a + dir * (0.33 + i * 0.65) + up * 0.07
		d.box("sleeper", p, Vector3(0.24, 0.1, 2.5), "Detail", BOTH, basis)
	var mid := (a + b) * 0.5
	for s: float in [-GAUGE, GAUGE]:
		d.box("rail", mid + up * 0.215 + Vector3(0, 0, s), Vector3(length, 0.15, 0.07), "Build", BOTH, basis)
	if steep:
		d.box("dark_metal", mid + up * 0.2, Vector3(length, 0.12, 0.12), "Build", BOTH, basis)
		# Its teeth, as a strip of light and dark along the top.
		d.box("hazard", mid + up * 0.262, Vector3(length, 0.004, 0.08), "Build", BOTH, basis)


# --- The walls ----------------------------------------------------------------------------

## Maroon and cream bands along the tiled walls at the floor and at the
## galleries; the station's name in mosaic across the north wall; the
## line's roundel along the south one; posters and nameboards low down.
static func _walls(d) -> void:
	# The faces the floor sees: the galleries' fronts where there are
	# galleries, the canyon walls elsewhere. [z, facing, x from, x to, foot]
	var faces := [
		[-16.0, 1.0, -60.0, -40.0, 0.0], [-12.0, 1.0, -40.0, 30.0, 0.0], [-16.0, 1.0, 56.0, 60.0, 0.0],
		[16.0, -1.0, -60.0, -56.0, 0.0], [12.0, -1.0, -30.0, 50.0, 0.0], [16.0, -1.0, 50.0, 60.0, 0.0],
		[-16.0, 1.0, -40.0, 30.0, Rift.NORTH_SHELF], [16.0, -1.0, -30.0, 50.0, Rift.SOUTH_SHELF],
		[-16.0, 1.0, -100.0, 100.0, NORTH - 3.2], [16.0, -1.0, -100.0, 100.0, SOUTH - 3.2],
	]
	for f: Array in faces:
		var z: float = f[0] + f[1] * 0.006
		var x0: float = f[2]
		var x1: float = f[3]
		var foot: float = f[4]
		var c := Vector3((x0 + x1) * 0.5, 0, z)
		var u := Vector3((x1 - x0) * 0.5 * f[1], 0, 0)
		d.face("tile_maroon", c + Vector3(0, foot + 2.95, 0), u, Vector3(0, 0.22, 0), "Build", BOTH)
		d.face("tile_cream", c + Vector3(0, foot + 3.27, 0), u, Vector3(0, 0.08, 0), "Build", BOTH)
	# Pilasters: cream tile strips up the walls every bay, floor to top.
	for f: Array in [[-16.0, 1.0, NORTH], [16.0, -1.0, SOUTH], [-12.0, 1.0, Rift.NORTH_SHELF], [12.0, -1.0, Rift.SOUTH_SHELF]]:
		var z: float = f[0] + f[1] * 0.008
		var top: float = f[2]
		var x := -93.75
		while x < 100.0:
			var shelf_face := absf(f[0]) < 13.0
			var on_shelf := (x > -40.0 and x < 30.0) if f[0] < 0.0 else (x > -30.0 and x < 50.0)
			if not shelf_face or on_shelf:
				d.face("tile_cream", Vector3(x, top * 0.5, z), Vector3(0.45 * f[1], 0, 0), Vector3(0, top * 0.5, 0), "Build", BOTH)
			x += 12.5
	# Lamps set flush in the walls between the pilasters, still lit: along
	# the floor, and along the galleries.
	var lamps := 0
	for row: Array in [[-16.0, 1.0, 5.0, -60.0, 60.0], [16.0, -1.0, 5.0, -60.0, 60.0], [-16.0, 1.0, Rift.NORTH_SHELF + 4.4, -40.0, 30.0],
			[16.0, -1.0, Rift.SOUTH_SHELF + 4.4, -30.0, 50.0], [-12.0, 1.0, 5.0, -40.0, 30.0], [12.0, -1.0, 5.0, -30.0, 50.0]]:
		var z: float = row[0] + row[1] * 0.01
		var x := -87.5
		while x < 100.0:
			if x > float(row[3]) and x < float(row[4]):
				var hidden: bool = absf(float(row[0])) > 13.0 and float(row[2]) < 6.0 and ((row[0] < 0.0 and x > -40.0 and x < 30.0) or (row[0] > 0.0 and x > -30.0 and x < 50.0))
				if not hidden:
					var at := Vector3(x, row[2], z)
					d.face("dark_metal", at, Vector3(0.5 * row[1], 0, 0), Vector3(0, 0.2, 0), "Fixtures", BOTH)
					d.face("lamp", at + Vector3(0, 0, row[1] * 0.004), Vector3(0.4 * row[1], 0, 0), Vector3(0, 0.12, 0), "Fixtures", BOTH)
					if int((x + 87.5) / 12.5) % 2 == 0:
						d.omni("WallLamp_%d" % lamps, at + Vector3(0, -0.6, row[1] * 1.2), WARM, 9.0, 1.0, BOTH, true)
						lamps += 1
			x += 12.5
	# The station's name in lit letters on a navy board across the north
	# wall, a gilt edge round it.
	var nb := DecoKit.facing(Vector3(0, 0, 1))
	d.face("brass", Vector3(-5, 20.0, -15.992), Vector3(18.4, 0, 0), Vector3(0, 4.6, 0), "Build", BOTH)
	d.face("navy", Vector3(-5, 20.0, -15.99), Vector3(18.0, 0, 0), Vector3(0, 4.2, 0), "Build", BOTH)
	Signs.channel(d, SERIF, "Nimbus", Vector3(-5, 17.6, -15.98), nb, 7.4, ["letters"], "dark_metal", 0.25, 0.0, 0.0, "Build")
	# The line's roundel along the south wall, above the gallery.
	var sb := DecoKit.facing(Vector3(0, 0, -1))
	for x: float in [-18.0, 12.0, 40.0]:
		_roundel(d, Vector3(x, 16.0, 15.99), sb, 1.6)
	# Posters and nameboards on the floor-level walls.
	var k := 0
	for p: Array in [[Vector3(-30, 2.2, -11.99), 1.0], [Vector3(-6, 2.2, -11.99), 1.0], [Vector3(10, 2.2, -11.99), 1.0],
			[Vector3(-20, 2.2, 11.99), -1.0], [Vector3(8, 2.2, 11.99), -1.0], [Vector3(36, 2.2, 11.99), -1.0]]:
		var n := Vector3(0, 0, p[1])
		var b := DecoKit.facing(n)
		var at: Vector3 = p[0]
		_poster(d, at, b, ["peak", "viaduct", "balloon"][k % 3], ["Nimbus", "The Cloud Line", "Cirrus"][k % 3])
		_nameboard(d, at + b.x * 3.4 + Vector3(0, 0.4, 0), b, 2.6)
		k += 1


## A travel poster in a frame, lit from behind, its words on its foot.
static func _poster(d, at: Vector3, b: Basis, picture: String, words: String) -> void:
	d.box("dark_metal", at - b.z * 0.02, Vector3(1.32, 1.92, 0.04), "Build", BOTH, b)
	d.face("poster_" + picture, at + b.z * 0.004, b.x * 0.6, b.y * 0.9, "Fixtures", BOTH)
	d.words(words, at + b.z * 0.008 + b.y * -0.72, b, 0.16, CREAM, 0.0, "Fixtures", BOTH, SERIF)


## An enamel nameboard: white letters on navy, a white border.
static func _nameboard(d, at: Vector3, b: Basis, width: float) -> void:
	d.box("white", at - b.z * 0.01, Vector3(width + 0.1, 0.62, 0.03), "Build", BOTH, b)
	d.box("navy", at, Vector3(width, 0.52, 0.03), "Build", BOTH, b)
	d.words("Nimbus", at + b.z * 0.02, b, 0.38, Color(1, 1, 1), 0.0, "Build", BOTH, SANS)


## The Cloud Line's roundel: a maroon ring, a navy bar across it with the
## name.
static func _roundel(d, at: Vector3, b: Basis, r: float) -> void:
	d.torus("maroon", at, r, r * 0.2, Basis(b.x, b.z, -b.y), 32, 4, "Build", BOTH)
	d.box("navy", at + b.z * 0.2, Vector3(r * 2.9, r * 0.5, 0.06), "Build", BOTH, b)
	d.words("Cloud Line", at + b.z * 0.24, b, r * 0.34, Color(1, 1, 1), 0.0, "Build", BOTH, SANS)


# --- The galleries --------------------------------------------------------------------------

## The shelves are galleries: a yellow line back from the edge, MIND THE
## GAP where the footbridge lands, benches against the wall, a clock.
static func _galleries(d) -> void:
	for g: Array in [[Rift.NORTH_SHELF, -12.0, 1.0, -40.0, 30.0], [Rift.SOUTH_SHELF, 12.0, -1.0, -30.0, 50.0]]:
		var y: float = g[0]
		var edge: float = g[1]
		var n: float = g[2]
		var x0: float = g[3]
		var x1: float = g[4]
		d.box("paint_yellow", Vector3((x0 + x1) * 0.5, y + 0.004, edge - n * 0.4), Vector3(x1 - x0 - 0.2, 0.008, 0.12), "Build", BOTH)
		var flat := DecoKit.flat(Vector3(n, 0, 0))
		Signs.channel(d, SANS, "MIND THE GAP", Vector3(10.0, y + 0.004, edge - n * 0.9), flat, 0.36, ["paint_white"], "paint_white",
				0.004, 0.0, 0.0, "Build")
		var wall := edge - n * 4.0
		var b := DecoKit.facing(Vector3(0, 0, n))
		for x: float in [x0 + 8.0, (x0 + x1) * 0.5 + 6.0, x1 - 8.0]:
			_bench(d, Vector3(x, y, wall + n * 0.3), b)
		_clock(d, Vector3((x0 + x1) * 0.5 - 4.0, y + 3.0, wall + n * 0.05), Vector3(0, 0, n), 0.55, 10.0 + n, 41.0)
		_nameboard(d, Vector3((x0 + x1) * 0.5 - 12.0, y + 2.6, wall + n * 0.03), b, 2.6)


## A station bench against a wall: iron ends, slats, solid.
static func _bench(d, foot: Vector3, b: Basis) -> void:
	d.solid(foot + b.y * 0.45 + b.z * 0.02, Vector3(1.9, 0.9, 0.55) if absf(b.z.z) > 0.5 else Vector3(0.55, 0.9, 1.9))
	for e: float in [-0.85, 0.85]:
		d.box("iron", foot + b.x * e + b.y * 0.42 + b.z * 0.05, Vector3(0.06, 0.84, 0.5), "Solid", BOTH, b)
	for k in 3:
		d.box("wood", foot + b.y * 0.45 + b.z * (0.12 + k * 0.12), Vector3(1.8, 0.04, 0.1), "Solid", BOTH, b)
	for k in 2:
		d.box("wood", foot + b.y * (0.62 + k * 0.14) + b.z * 0.02, Vector3(1.8, 0.1, 0.04), "Solid", BOTH, b)


## A clock: a white dial, a black rim, ticks, its hands at `hour`:`minute`,
## facing `n`.
static func _clock(d, c: Vector3, n: Vector3, r: float, hour: float, minute: float) -> void:
	var b := DecoKit.facing(n)
	d.tube("white", c - n * 0.02, c + n * 0.03, r, 24, "Build", BOTH)
	d.torus("black", c + n * 0.03, r, r * 0.06, Basis(b.x, b.z, -b.y), 24, 4, "Build", BOTH)
	for i in 12:
		var a := TAU * i / 12.0
		var dir := b.y * cos(a) + b.x * sin(a)
		var long := i % 3 == 0
		d.box("black", c + n * 0.035 + dir * r * (0.8 if long else 0.84), Vector3(r * 0.04, r * (0.18 if long else 0.1), 0.01), "Build", BOTH,
				Basis(b.x, b.y, b.z).rotated(n, -a))
	for h: Array in [[(hour + minute / 60.0) / 12.0, 0.5, 0.07], [minute / 60.0, 0.78, 0.045]]:
		var a: float = TAU * float(h[0])
		var dir := b.y * cos(a) + b.x * sin(a)
		d.box("black", c + n * 0.045 + dir * r * float(h[1]) * 0.45, Vector3(r * float(h[2]), r * float(h[1]), 0.01), "Build", BOTH,
				Basis(b.x, b.y, b.z).rotated(n, -a))


# --- The footbridges ---------------------------------------------------------------------------

## The High Bridge and the Mid Bridge are iron footbridges: plank decks,
## girders under them latticed in iron, lamps at the landings. The station
## clock hangs from the high one over the island.
static func _bridges(d) -> void:
	for br: Array in [[0.0, Vector3(0, SOUTH, 16), Vector3(0, NORTH, -16)], [10.0, Vector3(10, Rift.SOUTH_SHELF, 12), Vector3(10, Rift.NORTH_SHELF, -12)]]:
		var x: float = br[0]
		var a: Vector3 = br[1]
		var b: Vector3 = br[2]
		var dir := (b - a).normalized()
		var length := a.distance_to(b)
		var side := Vector3(1, 0, 0)
		var up := dir.cross(side)
		if up.y < 0.0:
			up = -up
		var basis := Basis(side, up, -dir)
		for s: float in [-1.35, 1.35]:
			var g := (a + b) * 0.5 + Vector3(s, 0, 0) - up * 1.1
			d.box("iron", g, Vector3(0.14, 1.0, length), "Build", BOTH, basis)
			var bays := int(length / 1.6)
			for i in bays:
				var p0 := a + dir * (i * 1.6) + Vector3(s, 0, 0)
				var p1 := a + dir * ((i + 1) * 1.6) + Vector3(s, 0, 0)
				d.tube("iron", p0 - up * 0.65, p1 - up * 1.55, 0.03, 4, "Build", BOTH)
				d.tube("iron", p0 - up * 1.55, p1 - up * 0.65, 0.03, 4, "Build", BOTH)
		# A kerb along each edge of the deck.
		for s: float in [-1.45, 1.45]:
			d.box("iron", (a + b) * 0.5 + Vector3(s, 0, 0) + up * 0.05, Vector3(0.1, 0.1, length), "Build", BOTH, basis)
		# Lamps at the landings, on the walls behind them.
		for e: Array in [[a, Vector3(0, 0, -1)], [b, Vector3(0, 0, 1)]]:
			var at: Vector3 = e[0]
			var n: Vector3 = e[1]
			if x == 0.0:
				continue
			d.box("iron", at + Vector3(1.8, 2.5, -n.z * -0.05), Vector3(0.08, 0.08, 0.3), "Fixtures", BOTH)
	# The clock under the High Bridge, four faces, on rods.
	var c := Vector3(0, 21.6, 0)
	var top := 24.0 - 0.6
	for e: float in [-0.5, 0.5]:
		d.tube("iron", c + Vector3(e, 0.9, 0), Vector3(e, top, 0), 0.04, 6, "Build", BOTH)
	d.box("iron", c, Vector3(1.9, 1.9, 1.9), "Build", BOTH)
	d.box("brass", c + Vector3(0, 1.0, 0), Vector3(2.0, 0.1, 2.0), "Build", BOTH)
	d.box("brass", c - Vector3(0, 1.0, 0), Vector3(2.0, 0.1, 2.0), "Build", BOTH)
	for n: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		_clock(d, c + n * 0.96, n, 0.8, 10.0, 42.0)
	d.omni("Clock", c + Vector3(0, -1.6, 0), WARM, 8.0, 0.6, BOTH, true)


# --- The station building ---------------------------------------------------------------------

## The Arch is the station building across the tracks: brick, a stone
## cornice, the middle track through a portal with a keystone, the others
## ending at portals bricked up long ago, the platform numbers over each,
## the departures on its east front, lamps in the tunnel.
static func _station_building(kit, d) -> void:
	for f: Array in [[-26.0, 1.0], [-34.0, -1.0]]:
		var x: float = f[0] + f[1] * 0.006
		var n := Vector3(f[1], 0, 0)
		var b := DecoKit.facing(n)
		# The cornice and the plinth.
		d.box("stone", Vector3(x + f[1] * 0.1, 3.85, 0), Vector3(0.2, 0.3, 32.0), "Build", BOTH)
		d.box("stone", Vector3(x + f[1] * 0.05, 0.25, 0), Vector3(0.1, 0.5, 32.0), "Build", BOTH)
		# The open portal: pilasters, a lintel with a keystone.
		for s: float in [-2.8, 2.8]:
			d.box("stone", Vector3(x + f[1] * 0.08, 1.5, s), Vector3(0.16, 3.0, 0.6), "Build", BOTH)
		d.box("stone", Vector3(x + f[1] * 0.08, 3.25, 0), Vector3(0.16, 0.5, 6.2), "Build", BOTH)
		d.box("stone", Vector3(x + f[1] * 0.12, 3.3, 0), Vector3(0.2, 0.6, 0.6), "Build", BOTH)
		_platform_number(d, Vector3(x + f[1] * 0.2, 3.3, 1.6), b, "2")
		# The bricked-up portals.
		for z: float in [-9.0, 9.0]:
			d.face("brick_dark", Vector3(x, 1.4, z), b.x * 1.9, Vector3(0, 1.4, 0), "Build", BOTH)
			for s: float in [-2.05, 2.05]:
				d.box("stone", Vector3(x + f[1] * 0.06, 1.45, z + s), Vector3(0.12, 2.9, 0.3), "Build", BOTH)
			d.box("stone", Vector3(x + f[1] * 0.06, 3.0, z), Vector3(0.12, 0.3, 4.4), "Build", BOTH)
			_platform_number(d, Vector3(x + f[1] * 0.12, 3.45, z), b, "1" if z < 0.0 else "3")
		# Lamps either side of the portal.
		for s: float in [-3.6, 3.6]:
			var at := Vector3(x + f[1] * 0.25, 2.5, s)
			d.box("iron", at - n * 0.12, Vector3(0.24, 0.06, 0.06), "Fixtures", BOTH)
			d.ball("lamp", at + Vector3(0, -0.05, 0), Vector3(0.14, 0.18, 0.14), 4, 8, "Fixtures", BOTH)
	# The departures, on the east front.
	var db := DecoKit.facing(Vector3(1, 0, 0))
	var board := Vector3(-25.85, 2.1, 6.2)
	d.box("black", board, Vector3(0.12, 1.4, 3.6), "Build", BOTH)
	d.box("iron", board + Vector3(0.02, 0.78, 0), Vector3(0.14, 0.16, 3.7), "Build", BOTH)
	d.words("Departures", board + Vector3(0.1, 0.78, 0), db, 0.14, CREAM, 0.0, "Fixtures", BOTH, SANS)
	var lines := ["10:14  Cumulus     On time", "10:22  Stratus     Delayed", "10:40  Cirrus      Boarding", "--:--  Nowhere     Cancelled"]
	for i in lines.size():
		d.words(lines[i], board + Vector3(0.07, 0.42 - i * 0.28, 0), db, 0.17, Color(1.0, 0.7, 0.2) * 1.6, 1.0, "Fixtures", BOTH, MONO)
	# The tunnel: its lamps, and the sky's light kept out of it.
	for x: float in [-32.0, -28.0]:
		d.tube("iron", Vector3(x, 3.0, 0), Vector3(x, 2.6, 0), 0.02, 4, "Fixtures", BOTH)
		d.ball("lamp", Vector3(x, 2.5, 0), Vector3(0.16, 0.12, 0.16), 4, 8, "Fixtures", BOTH)
		d.omni("Tunnel_%d" % int(-x), Vector3(x, 2.2, 0), WARM, 6.0, 1.0, BOTH)
	var zone := Node3D.new()
	zone.set_script(load("res://src/world/ambient_zone.gd"))
	zone.name = "Tunnel"
	zone.position = Vector3(-30, 1.5, 0)
	zone.set(&"size", Vector3(8.0, 3.0, 5.0))
	zone.set(&"ambient", 0.35)
	kit.root.add_child(zone)
	# The roof: skylights over the tunnel, a lantern on the ridge.
	for z: float in [-1.2, 1.2]:
		d.box("glass_dark", Vector3(-30, 4.004, z), Vector3(6.0, 0.008, 1.8), "Build", BOTH)


## An enamel platform number: a white numeral on a navy plate.
static func _platform_number(d, at: Vector3, b: Basis, n: String) -> void:
	d.box("white", at, Vector3(0.62, 0.62, 0.03), "Build", BOTH, b)
	d.box("navy", at + b.z * 0.01, Vector3(0.54, 0.54, 0.03), "Build", BOTH, b)
	d.words(n, at + b.z * 0.03, b, 0.44, Color(1, 1, 1), 0.0, "Build", BOTH, SANS)


# --- Wagons, luggage, the kiosk, the waiting room ----------------------------------------------

## The Arch's crates are two goods wagons on the north and south tracks:
## planked, iron-strapped, on wheels, buffers at the ends, the line's
## initials on the side.
static func _wagons(d) -> void:
	for w: Vector3 in [Vector3(-35, 0, -9), Vector3(-25, 0, 9)]:
		for s: float in [-1.0, 1.0]:
			var face := w + Vector3(0, 0, s * 1.006)
			var b := DecoKit.facing(Vector3(0, 0, s))
			for k in 4:
				d.box("dark_metal", face + Vector3(0, 0.55 + k * 0.42, 0), Vector3(2.0, 0.05, 0.02), "Build", BOTH)
			for e: float in [-0.95, 0.95, 0.0]:
				d.box("dark_metal", face + Vector3(e, 1.05, 0), Vector3(0.06, 1.8, 0.02), "Build", BOTH)
			d.words("C L", face + Vector3(0, 1.3, s * 0.012), b, 0.36, CREAM, 0.0, "Build", BOTH, SANS)
			for e: float in [-0.6, 0.6]:
				d.tube("dark_metal", face + Vector3(e, 0.33, 0), face + Vector3(e, 0.33, s * 0.1), 0.32, 12, "Build", BOTH)
		for e: float in [-1.0, 1.0]:
			for s: float in [-0.6, 0.6]:
				d.tube("dark_metal", w + Vector3(e * 1.0, 0.75, s), w + Vector3(e * 1.25, 0.75, s), 0.05, 6, "Build", BOTH)
				d.tube("black", w + Vector3(e * 1.25, 0.75, s), w + Vector3(e * 1.3, 0.75, s), 0.14, 8, "Build", BOTH)


## Ruin 1 is a stack of left luggage (trunks, cases, a hatbox) on a
## platform barrow; Ruin 2 the ticket kiosk in the line's maroon; Ruin 3
## the waiting room, its windows lit, a stove pipe on its roof.
static func _luggage_kiosk_waiting_room(d) -> void:
	# The luggage: trunks and cases standing proud of the block's faces.
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	var mats := ["leather", "trunk_green", "trunk_navy", "canvas", "leather", "maroon"]
	for layer in 3:
		for k in 4:
			var along := -1.5 + k * 1.0
			for s: float in [-1.0, 1.0]:
				var c := Vector3(-48, 0.5 + layer * 1.0, -4) + Vector3(along, 0, s * 2.02)
				var size := Vector3(rng.randf_range(0.8, 0.98), rng.randf_range(0.7, 0.95), 0.1)
				d.box(mats[(layer * 4 + k + int(s)) % mats.size()], c, size, "Build", BOTH)
				d.box("brass", c + Vector3(0, size.y * 0.3, s * 0.06), Vector3(size.x * 0.9, 0.04, 0.02), "Build", BOTH)
				var c2 := Vector3(-48, 0.5 + layer * 1.0, -4) + Vector3(s * 2.02, 0, along)
				d.box(mats[(layer * 4 + k + 2) % mats.size()], c2, Vector3(0.1, size.y, size.x), "Build", BOTH)
	d.words("Left luggage", Vector3(-45.9, 2.6, -4), DecoKit.facing(Vector3(1, 0, 0)), 0.2, CREAM, 0.0, "Build", BOTH, ITALIC)
	d.ball("canvas", Vector3(-48.3, 3.2, -4.4), Vector3(0.35, 0.22, 0.35), 3, 10, "Build", BOTH)
	# The kiosk: cream window frames, a lit window, the name, a clock.
	for s: float in [-1.0, 1.0]:
		var face_z := 6.0 + s * 2.006
		var b := DecoKit.facing(Vector3(0, 0, s))
		d.face("window_warm", Vector3(-12, 1.55, face_z), Vector3(1.4 * s, 0, 0), Vector3(0, 0.5, 0), "Build", BOTH)
		for e: float in [-1.45, 0.0, 1.45]:
			d.box("cream", Vector3(-12 + e, 1.55, face_z), Vector3(0.08, 1.1, 0.03), "Build", BOTH)
		for e: float in [-0.55, 0.55]:
			d.box("cream", Vector3(-12, 1.55 + e, face_z), Vector3(3.0, 0.08, 0.03), "Build", BOTH)
		d.box("wood", Vector3(-12, 0.95, face_z + s * 0.2), Vector3(3.0, 0.06, 0.4), "Build", BOTH)
		d.box("cream", Vector3(-12, 2.3, face_z + s * 0.01), Vector3(3.6, 0.36, 0.02), "Build", BOTH)
		d.words("Tickets", Vector3(-12, 2.3, face_z + s * 0.025), b, 0.26, Color(0.45, 0.07, 0.1), 0.0, "Build", BOTH, SERIF)
	d.omni("Kiosk", Vector3(-12, 1.8, 3.2), Color(1.0, 0.82, 0.58), 4.0, 0.6, BOTH, true)
	# The waiting room: two lit windows a side, a door, the name, a pipe.
	for s: float in [-1.0, 1.0]:
		var face_z := -6.0 + s * 2.006
		var b := DecoKit.facing(Vector3(0, 0, s))
		for e: float in [-1.0, 1.0]:
			d.face("window_warm", Vector3(18 + e, 1.8, face_z), Vector3(0.45 * s, 0, 0), Vector3(0, 0.6, 0), "Build", BOTH)
			d.box("stone", Vector3(18 + e, 1.1, face_z), Vector3(1.1, 0.1, 0.08), "Build", BOTH)
			d.box("stone", Vector3(18 + e, 2.5, face_z), Vector3(1.1, 0.14, 0.06), "Build", BOTH)
		d.box("stone", Vector3(18, 3.2, face_z + s * 0.01), Vector3(3.0, 0.34, 0.03), "Build", BOTH)
		d.words("Waiting Room", Vector3(18, 3.2, face_z + s * 0.025), b, 0.22, Color(0.12, 0.14, 0.3), 0.0, "Build", BOTH, SERIF)
	d.face("wood", Vector3(20.006, 1.1, -6), Vector3(0, 0, -0.5), Vector3(0, 1.05, 0), "Build", BOTH)
	d.tube("black", Vector3(19.2, 3.5, -7.2), Vector3(19.2, 4.4, -7.2), 0.09, 8, "Build", BOTH)
	d.omni("WaitingRoom", Vector3(18, 2.0, -9.2), Color(1.0, 0.82, 0.58), 4.0, 0.6, BOTH, true)


## The island under the clock: a stone plinth, buffers against both ends
## where the middle track stops, benches built into its sides, a plaque.
static func _island(d) -> void:
	for e: float in [-1.0, 1.0]:
		var face := Vector3(e * 4.006, 0, 0)
		for s: float in [-GAUGE, GAUGE]:
			d.box("red", face + Vector3(e * 0.2, 0.75, s), Vector3(0.4, 0.3, 0.25), "Build", BOTH)
			d.tube("black", face + Vector3(e * 0.4, 0.75, s), face + Vector3(e * 0.46, 0.75, s), 0.18, 8, "Build", BOTH)
		d.box("hazard", face + Vector3(e * 0.01, 1.0, 0), Vector3(0.02, 0.2, 2.4), "Build", BOTH)
	for s: float in [-1.0, 1.0]:
		var face_z := s * 3.006
		for k in 3:
			d.box("wood", Vector3(0, 0.45 + k * 0.2, face_z + s * 0.02), Vector3(7.0, 0.1, 0.04), "Build", BOTH)
		d.words("Meet me under the clock", Vector3(0, 1.08, face_z + s * 0.012), DecoKit.facing(Vector3(0, 0, s)), 0.16, Color(0.9, 0.78, 0.45),
				0.0, "Build", BOTH, ITALIC)
	d.box("brass", Vector3(0, 1.21, 0), Vector3(8.02, 0.02, 6.02), "Build", BOTH, Basis.IDENTITY, false, ["bottom"])


# --- The train shed -------------------------------------------------------------------------------

## The colonnade is what's left of a train shed: brick piers with stone
## caps, iron arches over the middle track from pier to pier, girders along
## them, the glass long gone; lamps hanging from the arches.
static func _train_shed(d) -> void:
	var xs := [26.0, 34.0, 42.0, 50.0]
	for x: float in xs:
		for z: float in [-5.0, 5.0]:
			d.box("stone", Vector3(x, 4.9, z), Vector3(1.7, 0.2, 1.7), "Build", BOTH)
			d.box("stone", Vector3(x, 0.3, z), Vector3(1.62, 0.6, 1.62), "Build", BOTH)
		# The arch over the middle track.
		var pts := PackedVector3Array()
		for i in 13:
			var t := float(i) / 12.0
			var zz := lerpf(-4.3, 4.3, t)
			pts.append(Vector3(x, 5.0 + sin(t * PI) * 2.6, zz))
		d.path_tube("iron", pts, 0.12, 6, "Build", BOTH)
		d.tube("iron", Vector3(x, 5.0, -4.3), Vector3(x, 5.0, 4.3), 0.06, 6, "Build", BOTH)
		d.tube("iron", Vector3(x, 7.6, 0), Vector3(x, 6.4, 0), 0.02, 4, "Fixtures", BOTH)
		d.ball("lamp", Vector3(x, 6.3, 0), Vector3(0.22, 0.16, 0.22), 4, 8, "Fixtures", BOTH)
	for i in xs.size() - 1:
		for z: float in [-5.0, 5.0]:
			d.box("iron", Vector3((xs[i] + xs[i + 1]) * 0.5, 4.9, z), Vector3(8.0 - 1.7, 0.3, 0.2), "Build", BOTH)
	for x: float in [30.0, 46.0]:
		d.omni("Shed_%d" % int(x), Vector3(x, 6.0, 0), WARM, 10.0, 0.7, BOTH, true)


# --- The signal boxes ---------------------------------------------------------------------------

## The towers are signal boxes: brick below, a band of windows round the
## top storey, the box's name, and a semaphore signal at its corner.
static func _signal_boxes(d) -> void:
	for t: Array in [[Vector3(-60, NORTH, -32), "Nimbus North Box", Vector3(-63, NORTH, -29)], [Vector3(60, SOUTH, 32), "Nimbus South Box", Vector3(63, SOUTH, 29)]]:
		var c: Vector3 = t[0]
		for n: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
			var b := DecoKit.facing(n)
			var f := c + n * 3.006
			d.face("glass_dark", f + Vector3(0, 6.0, 0), b.x * 2.7, Vector3(0, 0.9, 0), "Build", BOTH)
			for k in 7:
				d.box("cream", f + b.x * (-2.7 + k * 0.9) + Vector3(0, 6.0, 0), Vector3(0.08, 1.9, 0.04), "Build", BOTH, b)
			for e: float in [4.95, 7.05]:
				d.box("cream", f + Vector3(0, e, 0), Vector3(5.6, 0.14, 0.04), "Build", BOTH, b)
			d.box("stone", f + Vector3(0, 7.85, 0) + n * 0.06, Vector3(6.1, 0.3, 0.12), "Build", BOTH, b)
		var front := c + Vector3(0, 0, 3.006 * signf(-c.z))
		d.words(t[1], front + Vector3(0, 4.55, 0), DecoKit.facing(Vector3(0, 0, signf(-c.z))), 0.3, Color(1, 1, 1), 0.0, "Build", BOTH, SANS)
		d.box("navy", front + Vector3(0, 4.55, 0) - Vector3(0, 0, 0.01 * signf(-c.z)), Vector3(4.0, 0.44, 0.02), "Build", BOTH)
		# The semaphore at the corner.
		var m: Vector3 = t[2]
		d.box("iron", m + Vector3(0, 6.0, 0), Vector3(0.22, 12.0, 0.22), "Build", BOTH)
		d.ball("black", m + Vector3(0, 12.1, 0), Vector3(0.18, 0.18, 0.18), 3, 8, "Build", BOTH)
		for k in 2:
			var arm := m + Vector3(0, 11.0 - k * 2.2, 0)
			var tilt := Basis(Vector3(0, 0, 1), 0.7 if k == 0 else 0.0)
			d.box("red", arm + tilt * Vector3(0.75, 0, 0), Vector3(1.3, 0.24, 0.05), "Build", BOTH, tilt)
			d.box("white", arm + tilt * Vector3(1.1, 0, 0.03), Vector3(0.12, 0.24, 0.02), "Build", BOTH, tilt)
			d.ball("signal_green" if k == 0 else "signal_red", arm + Vector3(0.1, -0.3, 0.1), Vector3(0.07, 0.07, 0.07), 2, 6, "Fixtures", BOTH)


# --- The roofs --------------------------------------------------------------------------------

## The rims are the mountain's shoulders (turf, rock, old snow: the
## blocks' own tops): a stone coping along the top of the cutting's walls,
## and outside, where they drop to the void, cliffs going down to the rock
## under everything.
static func _shoulders(d) -> void:
	for r: Array in [[NORTH, -16.0, 1.0], [SOUTH, 16.0, -1.0]]:
		var y: float = r[0]
		var z: float = r[1]
		var s: float = r[2]
		d.box("stone", Vector3(0, y + 0.03, z - s * 0.6), Vector3(200.0, 0.06, 1.2), "Build", BOTH)
		d.face("tile_maroon", Vector3(0, y - 0.35, z + s * 0.009), Vector3(100.0 * s, 0, 0), Vector3(0, 0.35, 0), "Build", BOTH)
	# The outer faces: cliff over the tiles (nothing rides out there but
	# the fall), from the tops down to the rock.
	for f: Array in [[Vector3(0, 8.0, -44.01), Vector3(-100, 0, 0), Vector3(0, 20.0, 0)], [Vector3(0, 4.0, 44.01), Vector3(100, 0, 0), Vector3(0, 16.0, 0)],
			[Vector3(-100.01, 8.0, -30), Vector3(0, 0, 14), Vector3(0, 20.0, 0)], [Vector3(100.01, 8.0, -30), Vector3(0, 0, -14), Vector3(0, 20.0, 0)],
			[Vector3(-100.01, 4.0, 30), Vector3(0, 0, 14), Vector3(0, 16.0, 0)], [Vector3(100.01, 4.0, 30), Vector3(0, 0, -14), Vector3(0, 16.0, 0)],
			[Vector3(-100.01, -6.0, 0), Vector3(0, 0, 16), Vector3(0, 6.0, 0)], [Vector3(100.01, -6.0, 0), Vector3(0, 0, -16), Vector3(0, 6.0, 0)]]:
		d.face("cliff_face", f[0], f[1], f[2], "Build", BOTH)


## The ends of the line: where each incline tops out at the edge the
## tracks stop at buffers, and a board on the wall says where the line
## goes on to, across the cloud.
static func _ends(d) -> void:
	for end: Array in [[-100.0, SOUTH], [100.0, NORTH]]:
		var x: float = end[0]
		var s := signf(x)
		for z: float in TRACKS:
			var at := Vector3(x - s * 0.6, float(end[1]), z)
			d.box("red", at + Vector3(0, 0.75, 0), Vector3(0.3, 0.35, 2.4), "Build", BOTH)
			d.box("hazard", at + Vector3(-s * 0.16, 0.75, 0), Vector3(0.02, 0.3, 2.3), "Build", BOTH)
			for e: float in [-GAUGE, GAUGE]:
				d.tube("black", at + Vector3(-s * 0.15, 0.75, e), at + Vector3(-s * 0.35, 0.75, e), 0.16, 8, "Build", BOTH)
				d.box("dark_metal", at + Vector3(s * 0.2, 0.4, e), Vector3(0.12, 0.8, 0.12), "Build", BOTH)
	for e: Array in [[Vector3(-98.0, SOUTH + 3.4, -15.99), Vector3(0, 0, 1), "Cumulus  →  4 km"],
			[Vector3(98.0, NORTH - 1.0, 15.99), Vector3(0, 0, -1), "Stratus  →  6 km"]]:
		var at: Vector3 = e[0]
		var b := DecoKit.facing(e[1])
		d.box("white", at, Vector3(3.9, 0.9, 0.04), "Build", BOTH, b)
		d.box("navy", at + b.z * 0.01, Vector3(3.8, 0.8, 0.04), "Build", BOTH, b)
		d.words(e[2], at + b.z * 0.04, b, 0.34, Color(1, 1, 1), 0.0, "Build", BOTH, SANS)


# --- Far off ----------------------------------------------------------------------------------

## Which way the sun is (from its light's rotation).
static func _to_sun() -> Vector3:
	return Basis.from_euler(SUN * (PI / 180.0)).z


## A far face of `kind` (cliff, scree, snow) through `pts` (four
## corners round it, or three and the last again), turned to face away
## from `inside`, in its lit, half-lit or shaded material.
static func _far_face(d, kind: String, pts: Array, inside: Vector3) -> void:
	var p: Array = pts.duplicate()
	var n: Vector3 = (p[3] - p[0]).cross(p[1] - p[0])
	if n.length_squared() < 1e-8:
		n = (p[2] - p[0]).cross(p[1] - p[0])
	var centre: Vector3 = (p[0] + p[1] + p[2] + p[3]) * 0.25
	if n.dot(centre - inside) < 0.0:
		p = [p[0], p[3], p[2], p[1]]
		n = -n
	var light := n.normalized().dot(_to_sun())
	var shade := "lit" if light > 0.45 else "mid" if light > 0.05 else "shade"
	d.quad("far_%s_%s" % [kind, shade], p[0], p[1], p[2], p[3], "Far", BOTH)


## Bands of faces between rings of points (each ring the same count, round
## the same way): `kinds` one per band.
static func _rings(d, rings: Array, kinds: Array, inside: Vector3) -> void:
	for r in rings.size() - 1:
		var a: Array = rings[r]
		var b: Array = rings[r + 1]
		for i in a.size():
			var j := (i + 1) % a.size()
			_far_face(d, kinds[r], [a[i], a[j], b[j], b[i]], inside)


## The peak under the station: from under the roofs its cliffs go down,
## broken and spreading, into scree and the cloud.
static func _mountain(d) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	var edge := []
	var outs := []
	var corners := [Vector3(-100, -12, -44), Vector3(100, -12, -44), Vector3(100, -12, 44), Vector3(-100, -12, 44)]
	for c in 4:
		var a: Vector3 = corners[c]
		var b: Vector3 = corners[(c + 1) % 4]
		var steps := int(a.distance_to(b) / 20.0)
		var out := (b - a).normalized().cross(Vector3.UP)
		for k in steps:
			edge.append(a.lerp(b, float(k) / steps))
			outs.append((out + ((corners[c] - corners[(c + 3) % 4]).normalized().cross(Vector3.UP) if k == 0 else Vector3.ZERO)).normalized())
	var rings := [edge]
	for band: Array in [[-48.0, 8.0, 16.0], [-95.0, 26.0, 40.0], [-165.0, 60.0, 90.0]]:
		var ring := []
		for i in edge.size():
			var o: Vector3 = outs[i]
			ring.append((edge[i] as Vector3) + o * rng.randf_range(band[1], band[2]) + Vector3(0, float(band[0]) + 12.0 + rng.randf_range(-6.0, 6.0), 0))
		rings.append(ring)
	_rings(d, rings, ["cliff", "cliff", "scree"], Vector3(0, -60, 0))


## The sea of cloud far below, and other peaks standing out of it.
static func _cloud_sea(d) -> void:
	d.face("far_cloud", Vector3(0, -150, 0), Vector3(700, 0, 0), Vector3(0, 0, -700), "Far", BOTH)
	var k := 0
	for p: Array in [[Vector2(-360, -180), 240.0, 110.0], [Vector2(-120, -380), 330.0, 140.0], [Vector2(240, -330), 280.0, 130.0],
			[Vector2(400, -40), 210.0, 100.0], [Vector2(330, 250), 300.0, 130.0], [Vector2(-60, 400), 240.0, 115.0],
			[Vector2(-380, 200), 260.0, 120.0]]:
		_peak(d, Vector3(p[0].x, -160, p[0].y), p[1], p[2], 900 + k)
		k += 1


## A peak rising `height` out of the cloud from a foot `radius` across:
## rings of jagged points narrowing up it to a summit, cliff and scree low
## down, snow and rock higher, snow on top.
static func _peak(d, base: Vector3, height: float, radius: float, seed_n: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	var sides := 7
	var tip := base + Vector3(rng.randf_range(-0.15, 0.15) * radius, height, rng.randf_range(-0.15, 0.15) * radius)
	var rings := []
	for level: Array in [[0.0, 1.0], [0.34, 0.62], [0.58, 0.4], [0.78, 0.2], [0.92, 0.08]]:
		var ring := []
		for i in sides:
			var a := TAU * i / sides + rng.randf_range(-0.25, 0.25)
			var r: float = radius * float(level[1]) * rng.randf_range(0.82, 1.15)
			var c := base.lerp(tip, float(level[0]))
			ring.append(c + Vector3(cos(a) * r, rng.randf_range(-0.06, 0.06) * height, sin(a) * r))
		rings.append(ring)
	var top := []
	for i in sides:
		top.append(tip)
	rings.append(top)
	_rings(d, rings, ["cliff", "cliff", "cliff", "snow", "snow"], base + Vector3(0, height * 0.3, 0))


## The line out across the cloud, far off: a stone viaduct of arches on
## tall piers striding between the peaks north and south, rails on it, a
## train stopped out on the north one. (At the ends of the cutting the
## tracks stop at buffers at the edge.)
static func _viaducts(d) -> void:
	for v: Array in [[Vector3(-300, 52, -330), Vector3(300, 52, -300)], [Vector3(-300, 38, 330), Vector3(300, 38, 300)]]:
		var a: Vector3 = v[0]
		var b: Vector3 = v[1]
		var dir := (b - a).normalized()
		var length := a.distance_to(b)
		var side := dir.cross(Vector3.UP).normalized()
		var basis := Basis(dir, Vector3.UP, side)
		var mid := (a + b) * 0.5
		d.box("far_stone", mid + Vector3(0, -1.0, 0), Vector3(length, 2.0, 6.0), "Far", BOTH, basis)
		var span := 30.0
		var piers := int(length / span)
		for i in piers + 1:
			var p := a + dir * (i * span)
			var depth := p.y + 150.0
			d.box("far_stone", p + Vector3(0, -2.0 - depth * 0.5, 0), Vector3(4.0, depth, 6.0), "Far", BOTH, basis)
			if i < piers:
				var q := p + dir * span * 0.5
				d.box("far_stone", q + Vector3(0, -4.0, 0), Vector3(span, 4.0, 5.6), "Far", BOTH, basis)
				for e: float in [-1.0, 1.0]:
					d.box("far_stone", q + dir * e * (span * 0.5 - 4.0) + Vector3(0, -8.5, 0), Vector3(5.0, 5.0, 5.6), "Far", BOTH, basis)
	var dir := (Vector3(300, 52, -300) - Vector3(-300, 52, -330)).normalized()
	var basis := Basis(dir, Vector3.UP, dir.cross(Vector3.UP).normalized())
	for k in 4:
		var c := Vector3(-300, 52, -330) + dir * (240.0 + k * 14.0) + Vector3(0, 1.8, 0)
		d.box("far_maroon", c + Vector3(0, -0.2, 0), Vector3(13.0, 2.6, 3.2), "Far", BOTH, basis)
		d.box("far_cream", c + Vector3(0, 1.4, 0), Vector3(13.0, 0.8, 3.22), "Far", BOTH, basis)
