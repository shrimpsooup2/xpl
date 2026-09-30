extends RefCounted
## RIFT, dressed (GDD §9.3): Nimbus, the last station of the Cloud Line,
## cut into a mountain above a sea of cloud, on a cloudy dawn, waiting for
## the first train.
##
## The canyon is the station's cutting, its walls dressed limestone
## carrying the wall-ride band (the ride tiles' stripes, as on every map),
## banded in the line's maroon and cream, lamps set flush along them still
## lit, and the station's name in lit letters across the north wall. Three
## tracks run down the floor on ballast and up both end ramps, which are
## the inclines of a rack railway (a toothed rail between the running
## rails): the line climbs out of the cutting at each end to buffers at
## the edge; far off it crosses the notches in the mountains on viaducts.
## The shelves are galleries along the walls, lanterns along them; the
## ramps up the walls are the passenger ramps; the High Bridge and the Mid
## Bridge are iron footbridges, and the station clock hangs under the high
## one over the island in the middle (Meet me under the clock). The Arch
## is the station building across the tracks, the middle one running
## through it (the shotgun waits in the tunnel), the others ending at
## portals bricked up long ago, the departures on its front. The colonnade
## is what's left of a train shed: brick piers, iron arches, the glass
## gone. The Arch's crates are two goods wagons; the ruins a stack of left
## luggage, the ticket kiosk and the waiting room. The rims are the
## mountain's shoulders either side of the cutting: turf and grass, rock,
## old snow against the dry-stone walls, and a signal box with its
## semaphore on each for the snipers; at their edges rocks on the brink
## and a jagged cliff below. Small things all over. A ring of snowy
## mountains stands round it all across the cloud, lower in the east where
## the sun is just up, straight down the cutting, breaking through the
## overcast. The gameplay blocks are untouched, only dressed.

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
const SUN := Vector3(-22, 70, 0)
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
	_cliffs(d)
	_ends(d)
	_lanterns(d)
	_hanging(d)
	_odds(d)
	_grass(d)
	_details(d)
	_range(d)
	_cloud_sea(d)
	_cloud_deck(d)
	_sunbeams(d)
	_viaducts(d)


# --- Morning -----------------------------------------------------------------------------

## Dawn under a cloud deck: the overcast grey-lavender overhead, the sun
## just up in the east shining through where it thins, gold round it and
## along the deck's edge, and under the deck a band of clear dawn sky over
## the sea of cloud. Soft light everywhere, the sun raking in from the east.
static func _dawn(kit) -> void:
	var e: Environment = kit.environment
	var sky: ShaderMaterial = e.sky.sky_material
	sky.set_shader_parameter(&"top_color", Color(0.36, 0.38, 0.50))
	sky.set_shader_parameter(&"upper_color", Color(0.56, 0.54, 0.64))
	sky.set_shader_parameter(&"horizon_color", Color(1.0, 0.74, 0.54))
	sky.set_shader_parameter(&"ground_color", Color(0.86, 0.78, 0.78))
	sky.set_shader_parameter(&"sun_color", Color(1.0, 0.86, 0.66))
	sky.set_shader_parameter(&"sun_size", 0.035)
	sky.set_shader_parameter(&"halo", 0.9)
	sky.set_shader_parameter(&"stars", 0.0)
	sky.set_shader_parameter(&"cloud_map", load("res://assets/textures/rift/billows.png"))
	sky.set_shader_parameter(&"clouds", 0.8)
	e.ambient_light_color = Color(0.58, 0.58, 0.70)
	e.ambient_light_energy = 0.66
	e.fog_light_color = Color(0.64, 0.64, 0.72)
	e.fog_density = 0.0013
	e.fog_sky_affect = 0.0
	e.glow_intensity = 0.6
	e.glow_hdr_threshold = 1.0
	e.glow_bloom = 0.0
	var sun: DirectionalLight3D = kit.sun
	sun.rotation_degrees = SUN
	sun.light_color = Color(1.0, 0.78, 0.56)
	sun.light_energy = 0.85
	sun.light_specular = 0.2


# --- Materials --------------------------------------------------------------------------------

static func _materials(d) -> void:
	d.reflection = load("res://assets/textures/rift/reflection_day.png")
	# The gameplay blocks.
	d.surface("trackbed", {"side": "rift/rock", "meters": 6.0, "top": "rift/ballast", "top_meters": 1.0,
			"gloss": 0.02, "grazing": 0.2, "roughness": 0.9})
	d.surface("gallery", {"side": "rift/ride_stone", "meters": 4.0, "top": "rift/flags", "top_meters": 3.0, "top_tint": Color(0.74, 0.72, 0.68),
			"gloss": 0.2, "grazing": 0.5, "roughness": 0.35, "specular": 0.2})
	# Stone below, turf on top: one material, so a gloss between the two.
	d.surface("wall", {"side": "rift/ride_stone", "meters": 4.0, "top": "rift/meadow", "top_meters": 8.0,
			"gloss": 0.14, "grazing": 0.4, "roughness": 0.5, "specular": 0.15})
	d.surface("overhang", {"side": "rift/ride_stone", "meters": 4.0, "top": "rift/flags", "top_meters": 3.0, "top_tint": Color(0.74, 0.72, 0.68),
			"bottom": "stack/ceiling", "bottom_meters": 3.0, "gloss": 0.35, "grazing": 0.75, "roughness": 0.15})
	d.surface("incline", {"side": "rift/rock", "meters": 6.0, "top": "rift/ballast", "top_meters": 1.0,
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

	d.surface("rockery", {"side": "rift/cliff", "meters": 4.0, "top": "rift/alpine", "top_meters": 4.0, "gloss": 0.04, "grazing": 0.25,
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
	var to_sun := _to_sun()
	d.shaded("range", "res://src/render/deco/mountain.gdshader", {"rock": "rift/far_rock.png", "snow": "rift/snow.png",
			"scree": "rift/scree.png", "rock_meters": 60.0, "snowline": -25.0, "snow_fade": 90.0, "scree_line": -135.0,
			"rock_tint": Color(0.56, 0.54, 0.58)})
	d.shaded("cliff_rock", "res://src/render/deco/mountain.gdshader", {"rock": "rift/cliff.png", "snow": "rift/snow.png",
			"scree": "rift/scree.png", "rock_meters": 14.0, "snow_meters": 16.0, "snowline": 60.0, "snow_fade": 30.0, "scree_line": -170.0,
			"rock_tint": Color(0.86, 0.84, 0.84), "sky_light": 0.9})
	d.shaded("cloud_sea", "res://src/render/deco/cloud_sea.gdshader", {"billows": "rift/billows.png", "to_sun": to_sun})
	d.shaded("cloud_deck", "res://src/render/deco/cloud_deck.gdshader", {"billows": "rift/billows.png", "to_sun": to_sun})
	d.shaded("sunbeam", "res://src/render/deco/sunbeam.gdshader", {"color": Color(1.0, 0.8, 0.55), "strength": 0.06,
			"size": Vector2(24.0, 320.0)})
	d.shaded("pool", "res://src/render/deco/light_pool.gdshader", {"color": WARM, "strength": 0.3, "size": Vector2(4.0, 4.0)})
	d.shaded("pool_wide", "res://src/render/deco/light_pool.gdshader", {"color": WARM, "strength": 0.22, "size": Vector2(8.0, 8.0)})
	d.shaded("grass", "res://src/render/deco/grass.gdshader", {})
	d.shaded("puddle", "res://src/render/deco/puddle.gdshader", {"reflection_map": "rift/reflection_day.png", "noise": "terrace/grime.png",
			"size": Vector2(2.4, 1.6)})
	d.shaded("oil", "res://src/render/deco/puddle.gdshader", {"reflection_map": "rift/reflection_day.png", "noise": "terrace/grime.png",
			"size": Vector2(1.2, 0.8), "color": Color(0.06, 0.05, 0.04), "opacity": 0.6})
	for m: Array in [["enamel_red", Color(0.72, 0.12, 0.12)], ["enamel_green", Color(0.10, 0.36, 0.22)], ["enamel_yellow", Color(1.1, 0.82, 0.18)],
			["enamel_blue", Color(0.14, 0.30, 0.62)], ["snow_drift", Color(1.2, 1.2, 1.25)]]:
		d.surface(m[0], {"side": "stack/steel" if m[0] != "snow_drift" else "rift/snow", "meters": 1.0, "tint": m[1], "gloss": 0.5,
				"grazing": 0.85, "roughness": 0.2, "uv": true})
	d.surface("boulder", {"side": "rift/cliff", "meters": 1.0, "gloss": 0.03, "grazing": 0.2, "roughness": 0.85, "uv": true})
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
	# Lamps set flush in the walls, still lit: along
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
					var floor_row := float(row[2]) < 6.0
					if floor_row:
						# Its light on the wall under it and the ballast in front.
						d.face("pool", Vector3(x, 3.4, z + row[1] * 0.006), Vector3(2.0 * row[1], 0, 0), Vector3(0, 2.0, 0), "Effects", BOTH)
						d.face("pool", Vector3(x, 0.03, z + row[1] * 1.8), Vector3(2.0, 0, 0), Vector3(0, 0, -2.0), "Effects", BOTH)
					if floor_row and int((x + 87.5) / 12.5) % 2 == 0:
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
			d.face("window_warm", f + Vector3(0, 6.0, 0), b.x * 2.7, Vector3(0, 0.9, 0), "Build", BOTH)
			for k in 7:
				d.box("cream", f + b.x * (-2.7 + k * 0.9) + Vector3(0, 6.0, 0), Vector3(0.08, 1.9, 0.04), "Build", BOTH, b)
			for e: float in [4.95, 7.05]:
				d.box("cream", f + Vector3(0, e, 0), Vector3(5.6, 0.14, 0.04), "Build", BOTH, b)
			d.box("stone", f + Vector3(0, 7.85, 0) + n * 0.06, Vector3(6.1, 0.3, 0.12), "Build", BOTH, b)
		d.omni("Box_%d" % int(c.x), c + Vector3(0, 6.0, 3.8 * signf(-c.z)), Color(1.0, 0.8, 0.55), 10.0, 0.9, BOTH)
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
## blocks' own tops): a stone coping along the top of the cutting's walls.
## (Where they drop to the void, _cliffs().)
static func _shoulders(d) -> void:
	for r: Array in [[NORTH, -16.0, 1.0], [SOUTH, 16.0, -1.0]]:
		var y: float = r[0]
		var z: float = r[1]
		var s: float = r[2]
		d.box("stone", Vector3(0, y + 0.03, z - s * 0.6), Vector3(200.0, 0.06, 1.2), "Build", BOTH)
		d.face("tile_maroon", Vector3(0, y - 0.35, z + s * 0.009), Vector3(100.0 * s, 0, 0), Vector3(0, 0.35, 0), "Build", BOTH)


## The drop all round: rock, jagged and broken, from the edge of the
## shoulders and the ends of the line down to the mountain below, and
## rocks astride the edge so it isn't a straight corner. No collision:
## it's only what you'd fall past.
static func _cliffs(d) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 404
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0 / 16.0
	noise.fractal_octaves = 3
	# The edge walked round: [x, z, the top there, which way is out]. At
	# each corner the rock fans round it, so the cliff below bulges out
	# round the corner as a buttress.
	var edge := []
	var corners := [Vector2(-100, -44), Vector2(100, -44), Vector2(100, 44), Vector2(-100, 44)]
	for c in 4:
		var a: Vector2 = corners[c]
		var b: Vector2 = corners[(c + 1) % 4]
		var n := int(a.distance_to(b) / 2.5)
		var side := (b - a).normalized()
		var out := Vector3(side.y, 0, -side.x)
		var prev_side: Vector2 = (a - (corners[(c + 3) % 4] as Vector2)).normalized()
		var prev_out := Vector3(prev_side.y, 0, -prev_side.x)
		for f in 4:
			edge.append([a, _edge_top(a), prev_out.slerp(out, (f + 0.5) / 4.0), true])
		for k in range(1, n):
			var p := a.lerp(b, float(k) / n)
			edge.append([p, _edge_top(p), out, false])
	# Each point's column, from the lip down: [below the top, out].
	# The last reaches down to the mountainside under it (_height()).
	var levels := [[0.0, -0.9], [-1.4, 0.6], [-4.5, 2.2], [-9.0, 4.0], [-16.0, 6.5], [-26.0, 10.0], [-40.0, 14.0], [-62.0, 20.0],
			[-104.0, 31.0]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var columns := []
	var t := 0.0
	for i in edge.size():
		var e: Array = edge[i]
		var p: Vector2 = e[0]
		var top: float = e[1]
		var out: Vector3 = e[2]
		var corner: bool = e[3]
		t += 1.2 if corner else 2.5
		var line_end := absf(p.x) > 99.0 and absf(p.y) < 16.5
		var col := []
		for k in levels.size():
			var lv: Array = levels[k]
			var depth := minf(float(k), 4.0) / 4.0
			var jag := noise.get_noise_2d(t, k * 9.0)
			# Spurs and gullies running down, ledges across.
			var spur := noise.get_noise_2d(t * 0.3, 500.0) * 5.0 + noise.get_noise_2d(t * 0.9, 700.0) * 2.0
			var ledge := noise.get_noise_2d(t * 0.15, k * 31.0) * 1.8
			# Broken: every point a little in or out, up or down.
			var y: float = top + float(lv[0]) + jag * (0.3 if k == 1 else 2.6) + rng.randf_range(-1.0, 1.0) * (0.3 if k == 1 else 1.4)
			var reach: float = float(lv[1]) + jag * (0.5 + depth * 1.8) + (spur + ledge) * depth + (6.0 * depth if corner else 0.0)
			reach += rng.randf_range(-0.7, 0.7) * (0.4 + depth)
			if k == 0:
				# The top: flush with the turf, just outside the edge.
				y = top - 0.02
				reach = 0.05
			col.append(Vector3(p.x, 0, p.y) + out * reach + Vector3(0, y, 0))
		columns.append(col)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for i in columns.size():
		var a: Array = columns[i]
		var b: Array = columns[(i + 1) % columns.size()]
		var out: Vector3 = (edge[i][2] as Vector3)
		for k in levels.size() - 1:
			for tri: Array in [[a[k], b[k], b[k + 1]], [a[k], b[k + 1], a[k + 1]]]:
				var n: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0])
				if n.dot(out) > 0.0:
					tri = [tri[0], tri[2], tri[1]]
				for v: Vector3 in tri:
					st.add_vertex(v)
	# Rocks astride the edge, so it isn't a straight line: most small, some
	# big outcrops; clear of the pads and the benches, and of the line's
	# ends.
	var keep_out := _rim_keep_out().map(func(r: Rect2) -> Rect2: return r.grow(1.5))
	for i in edge.size():
		var e: Array = edge[i]
		var p: Vector2 = e[0]
		var out: Vector3 = e[2]
		var line_end := absf(p.x) > 98.0 and absf(p.y) < 17.5
		if line_end or rng.randf() > (0.9 if e[3] else 0.55) or _kept_out(p, keep_out):
			continue
		var big := rng.randf() < 0.12 or bool(e[3])
		var size := Vector3(rng.randf_range(2.0, 3.4), rng.randf_range(1.2, 2.2), rng.randf_range(1.8, 3.0)) if big \
				else Vector3(rng.randf_range(0.6, 1.7), rng.randf_range(0.4, 1.1), rng.randf_range(0.6, 1.5))
		var at := Vector3(p.x, float(e[1]) - size.y * 0.3, p.y) + out * rng.randf_range(-0.7, 0.5) \
				+ Vector3(out.z, 0, -out.x) * rng.randf_range(-1.0, 1.0)
		_rock(st, at, size, rng.randf() * TAU, rng)
	st.generate_normals()
	var mesh := st.commit()
	ResourceSaver.save(mesh, d.dir + "meshes/cliffs.res")
	d.own_mesh("Cliffs", load(d.dir + "meshes/cliffs.res"), d.mat("cliff_rock"), Transform3D.IDENTITY, "Build")


## A rock: a lump of flat facets, `size` across, turned `yaw` round,
## every corner a little in or out.
static func _rock(st: SurfaceTool, at: Vector3, size: Vector3, yaw: float, rng: RandomNumberGenerator) -> void:
	var rings := 4
	var segs := 7
	var basis := Basis(Vector3.UP, yaw)
	var pts := []
	for j in rings + 1:
		var lat := PI * float(j) / rings
		var row := []
		for i in segs:
			var lon := TAU * (float(i) + (0.5 if j % 2 == 1 else 0.0)) / segs
			var dir := Vector3(sin(lat) * cos(lon), cos(lat), sin(lat) * sin(lon))
			var bump := 1.0 if j == 0 or j == rings else rng.randf_range(0.72, 1.18)
			row.append(at + basis * (dir * size * 0.5 * bump))
		pts.append(row)
	for j in rings:
		for i in segs:
			var a: Vector3 = pts[j][i]
			var b: Vector3 = pts[j][(i + 1) % segs]
			var c: Vector3 = pts[j + 1][(i + 1) % segs]
			var e: Vector3 = pts[j + 1][i]
			for tri: Array in [[a, b, c], [a, c, e]]:
				var n: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0])
				if n.length_squared() < 1e-8:
					continue
				if n.dot((tri[0] + tri[1] + tri[2]) / 3.0 - at) > 0.0:
					tri = [tri[0], tri[2], tri[1]]
				for v: Vector3 in tri:
					st.add_vertex(v)


## How high the ground is at a point on the edge: the shoulders, or the
## top of the incline where the line ends.
static func _edge_top(p: Vector2) -> float:
	if p.y <= -16.0:
		return NORTH
	if p.y >= 16.0:
		return SOUTH
	return SOUTH if p.x < 0.0 else NORTH


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


# --- Lamps, signs, odds ------------------------------------------------------------------

## Lanterns along the galleries: an iron post at the edge, a swan neck
## reaching back over the walk, a glass lantern still lit, its light on the
## flags (a real light at every other one).
static func _lanterns(d) -> void:
	var k := 0
	for g: Array in [[Rift.NORTH_SHELF, -12.0, 1.0, [-34.0, -21.5, -9.0, 3.5, 16.0, 28.5]],
			[Rift.SOUTH_SHELF, 12.0, -1.0, [-24.0, -11.5, 1.0, 14.0, 26.0, 38.5]]]:
		var y: float = g[0]
		var edge: float = g[1]
		var n: float = g[2]
		for x: float in g[3]:
			var foot := Vector3(x, y, edge - n * 0.3)
			d.box("iron", foot + Vector3(0, 0.25, 0), Vector3(0.26, 0.5, 0.26), "Build", BOTH)
			d.tube("iron", foot, foot + Vector3(0, 3.7, 0), 0.055, 6, "Build", BOTH)
			var neck := PackedVector3Array([foot + Vector3(0, 3.7, 0), foot + Vector3(0, 4.0, -n * 0.25), foot + Vector3(0, 3.95, -n * 0.7),
					foot + Vector3(0, 3.8, -n * 0.95)])
			d.path_tube("iron", neck, 0.035, 5, "Build", BOTH)
			var lamp := foot + Vector3(0, 3.45, -n * 0.95)
			d.box("black", lamp + Vector3(0, 0.25, 0), Vector3(0.34, 0.08, 0.34), "Fixtures", BOTH)
			d.box("lamp", lamp, Vector3(0.24, 0.38, 0.24), "Fixtures", BOTH)
			d.box("black", lamp - Vector3(0, 0.22, 0), Vector3(0.28, 0.05, 0.28), "Fixtures", BOTH)
			d.face("pool", Vector3(x, y + 0.03, lamp.z - n * 0.6), Vector3(2.0, 0, 0), Vector3(0, 0, -2.0), "Effects", BOTH)
			if k % 2 == 0:
				d.omni("Lantern_%d" % k, lamp - Vector3(0, 0.3, 0), WARM, 8.0, 1.0, BOTH, true)
			k += 1


## Hanging over the tracks: pendant lamps under both footbridges, and
## under the Mid Bridge an enamel board over each track with its number.
static func _hanging(d) -> void:
	var k := 0
	for p: Array in [[0.0, -8.0, 24.0 - (-8.0) * 0.25 - 0.6], [0.0, 8.0, 24.0 - 8.0 * 0.25 - 0.6],
			[10.0, -5.0, 11.0 + 5.0 / 12.0 - 0.6], [10.0, 5.0, 11.0 - 5.0 / 12.0 - 0.6]]:
		var top := Vector3(p[0], p[2], p[1])
		var drop := 3.4 if p[0] == 0.0 else 2.2
		var lamp := top - Vector3(0, drop, 0)
		d.tube("iron", top, lamp + Vector3(0, 0.3, 0), 0.02, 4, "Fixtures", BOTH)
		d.ball("iron", lamp + Vector3(0, 0.2, 0), Vector3(0.5, 0.22, 0.5), 3, 10, "Fixtures", BOTH)
		d.ball("lamp", lamp, Vector3(0.2, 0.2, 0.2), 3, 8, "Fixtures", BOTH)
		if k % 2 == 1:
			d.omni("Pendant_%d" % k, lamp - Vector3(0, 0.4, 0), WARM, 12.0, 1.0, BOTH, true)
		k += 1
	for z: float in TRACKS:
		var under := 11.0 - z / 12.0 - 0.6
		var board := Vector3(10, under - 1.5, z)
		for e: float in [-0.5, 0.5]:
			d.tube("iron", Vector3(10, under, z + e), board + Vector3(0, 0.3, e), 0.012, 3, "Fixtures", BOTH)
		for s: float in [1.0, -1.0]:
			var b := DecoKit.facing(Vector3(s, 0, 0))
			d.box("white", board, Vector3(0.05, 0.62, 1.5), "Build", BOTH)
			d.box("navy", board + Vector3(s * 0.02, 0, 0), Vector3(0.03, 0.54, 1.42), "Build", BOTH)
			d.words("Platform %d" % (TRACKS.find(z) + 1), board + Vector3(s * 0.04, 0, 0), b, 0.22, Color(1, 1, 1), 0.0, "Build", BOTH, SANS)


## Odds and ends: chimney stacks on the station building, dwarf signals by
## the tracks, fire buckets and timetables on the galleries' walls, benches
## looking out from the shoulders, a telescope, finger posts, a flag.
static func _odds(d) -> void:
	# Chimneys at either end of the station building's roof, against the walls.
	for z: float in [-15.2, 15.2]:
		var c := Vector3(-30, 4.0, z)
		d.solid(c + Vector3(0, 1.2, 0), Vector3(1.4, 2.4, 1.2))
		d.box("brick", c + Vector3(0, 1.2, 0), Vector3(1.4, 2.4, 1.2), "Solid", BOTH)
		d.box("stone", c + Vector3(0, 2.45, 0), Vector3(1.6, 0.14, 1.4), "Solid", BOTH)
		for e: float in [-0.35, 0.35]:
			d.tube("brick_dark", c + Vector3(e, 2.5, 0), c + Vector3(e, 3.0, 0), 0.16, 8, "Solid", BOTH)
	# Dwarf signals either side of the station building, by the tracks.
	for p: Array in [[Vector3(-23.5, 0, -6.6), "signal_red"], [Vector3(-23.5, 0, 6.6), "signal_green"],
			[Vector3(-36.5, 0, -6.6), "signal_green"], [Vector3(-36.5, 0, 6.6), "signal_red"], [Vector3(22.0, 0, 2.2), "signal_red"]]:
		var at: Vector3 = p[0]
		d.box("white", at + Vector3(0, 0.35, 0), Vector3(0.3, 0.7, 0.2), "Detail", BOTH)
		d.tube("black", at + Vector3(0, 0.5, 0), at + Vector3(0, 0.5, 0.12 * signf(at.x)), 0.1, 10, "Detail", BOTH)
		d.ball(p[1], at + Vector3(0, 0.5, 0.13 * signf(at.x)), Vector3(0.06, 0.06, 0.02), 2, 8, "Detail", BOTH)
	# Fire buckets and timetables on the galleries' back walls.
	for g: Array in [[Rift.NORTH_SHELF, -15.99, 1.0, [-28.0, 22.0]], [Rift.SOUTH_SHELF, 15.99, -1.0, [-16.0, 32.0]]]:
		var y: float = g[0]
		var z: float = g[1]
		var n := Vector3(0, 0, g[2])
		var b := DecoKit.facing(n)
		var xs: Array = g[3]
		var board := Vector3(xs[0], y + 1.5, z)
		d.box("red", board + n * 0.02, Vector3(1.4, 0.3, 0.04), "Detail", BOTH, b)
		d.words("FIRE", board + n * 0.045, b, 0.18, Color(1, 1, 1), 0.0, "Detail", BOTH, SANS)
		for k in 3:
			var bucket := board + b.x * (-0.45 + k * 0.45) + Vector3(0, -0.4, 0) + n * 0.14
			d.tube("red", bucket - Vector3(0, 0.15, 0), bucket + Vector3(0, 0.15, 0), 0.13, 8, "Detail", BOTH)
		var tt := Vector3(xs[1], y + 1.7, z)
		d.box("dark_metal", tt + n * 0.03, Vector3(1.3, 1.0, 0.06), "Build", BOTH, b)
		d.face("paper", tt + n * 0.065, b.x * 0.58, b.y * 0.44, "Build", BOTH)
		d.words("Cloud Line", tt + n * 0.07 + Vector3(0, 0.34, 0), b, 0.12, Color(0.45, 0.07, 0.1), 0.0, "Build", BOTH, SERIF)
		var times := "Cumulus   06:14  07:40\nStratus   06:22  08:05\nCirrus    06:40  09:10\nNowhere   --:--  --:--"
		d.words(times, tt + n * 0.07 - Vector3(0, 0.08, 0), b, 0.07, Color(0.1, 0.1, 0.14), 0.0, "Build", BOTH, MONO)
	# Benches on the shoulders looking out over the cloud, at the edge.
	for p: Array in [[Vector3(-40, NORTH, -41.8), -1.0], [Vector3(10, NORTH, -41.8), -1.0], [Vector3(60, NORTH, -41.8), -1.0],
			[Vector3(-60, SOUTH, 41.8), 1.0], [Vector3(-10, SOUTH, 41.8), 1.0], [Vector3(40, SOUTH, 41.8), 1.0]]:
		_bench(d, p[0], DecoKit.facing(Vector3(0, 0, float(p[1]))))
	# A telescope on the north shoulder, pointed at the far viaduct.
	var scope := Vector3(46, NORTH, -41.4)
	d.tube("iron", scope, scope + Vector3(0, 1.1, 0), 0.05, 6, "Detail", BOTH)
	d.tube("maroon", scope + Vector3(0, 1.25, 0.25), scope + Vector3(0, 1.35, -0.35), 0.1, 10, "Detail", BOTH)
	d.box("brass", scope + Vector3(0, 1.15, 0), Vector3(0.2, 0.1, 0.2), "Detail", BOTH)
	# Finger posts by the signal boxes.
	for f: Array in [[Vector3(-52, NORTH, -26), "Summit  ↑", "Station  ↓"], [Vector3(52, SOUTH, 26), "Summit  ↑", "Station  ↓"]]:
		var at: Vector3 = f[0]
		d.tube("wood", at, at + Vector3(0, 2.4, 0), 0.05, 6, "Detail", BOTH)
		for k in 2:
			var arm := at + Vector3(0.45 - k * 0.9, 2.1 - k * 0.35, 0)
			d.box("cream", arm, Vector3(0.9, 0.2, 0.04), "Detail", BOTH)
			for s: float in [1.0, -1.0]:
				d.words(f[1 + k], arm + Vector3(0, 0, s * 0.03), DecoKit.facing(Vector3(0, 0, s)), 0.1, Color(0.2, 0.1, 0.1), 0.0, "Detail", BOTH, SERIF)
	# The line's flag by the north box.
	var pole := Vector3(-66, NORTH, -37)
	d.tube("white", pole, pole + Vector3(0, 8.0, 0), 0.06, 6, "Detail", BOTH)
	d.quad("maroon", pole + Vector3(0, 7.9, 0), pole + Vector3(2.2, 7.5, 0.2), pole + Vector3(2.2, 7.5, 0.2), pole + Vector3(0, 7.0, 0), "Detail", BOTH)
	d.quad("maroon", pole + Vector3(2.2, 7.5, 0.2), pole + Vector3(0, 7.9, 0), pole + Vector3(0, 7.0, 0), pole + Vector3(0, 7.0, 0), "Detail", BOTH)


## Grass on the shoulders: a tuft wherever the turf is turf (not snow or
## rock, going by the turf's own texture), swaying; stones here and there.
## Out of the way of the towers, the rocks, the walls and the pads.
static func _grass(d) -> void:
	var tex: Texture2D = load("res://assets/textures/rift/meadow.png")
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var keep_out := _rim_keep_out()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	for rim: Array in [[NORTH, -43.4, -17.5], [SOUTH, 17.5, 43.4]]:
		var z: float = rim[1]
		while z < float(rim[2]):
			var x := -99.4
			while x < 99.4:
				var p := Vector2(x + rng.randf_range(-0.5, 0.5), z + rng.randf_range(-0.5, 0.5))
				if absf(p.y) > 17.4 and absf(p.y) < 43.5 and absf(p.x) < 99.6 and _turf(img, p) and not _kept_out(p, keep_out):
					_tuft(st, Vector3(p.x, rim[0], p.y), rng)
				x += 1.1
			z += 1.1
	var mesh := st.commit()
	ResourceSaver.save(mesh, d.dir + "meshes/grass.res")
	d.own_mesh("Grass", load(d.dir + "meshes/grass.res"), d.mat("grass"), Transform3D.IDENTITY, "Detail")
	# Stones, half sunk.
	for i in 110:
		var north := i % 2 == 0
		var p := Vector2(rng.randf_range(-98.0, 98.0), rng.randf_range(18.0, 43.0) * (-1.0 if north else 1.0))
		if _kept_out(p, keep_out):
			continue
		var r := rng.randf_range(0.12, 0.4)
		var y := NORTH if north else SOUTH
		d.ball("boulder", Vector3(p.x, y + r * 0.15, p.y), Vector3(r, r * 0.6, r * rng.randf_range(0.7, 1.1)), 3, 7, "Detail", BOTH)


## Small things all over: telegraph poles and their wires along the
## shoulders, weeds at the foot of the walls and in the ballast, litter,
## puddles and oil between the rails, fishplates at the rail joints,
## enamel adverts, a pillar box and machines on the galleries, spare
## sleepers stacked at the end, signs for the way out, snow drifted
## against the dry-stone walls.
static func _details(d) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	# Telegraph poles along each shoulder, the wires sagging between.
	for rim: Array in [[NORTH, -19.6], [SOUTH, 19.6]]:
		var y: float = rim[0]
		var z: float = rim[1]
		var tops := []
		var x := -90.0
		while x <= 90.0:
			var foot := Vector3(x, y, z)
			d.tube("wood", foot, foot + Vector3(0, 7.0, 0), 0.11, 6, "Detail", BOTH)
			d.box("wood", foot + Vector3(0, 6.5, 0), Vector3(0.1, 0.12, 1.6), "Detail", BOTH)
			for e: float in [-0.65, 0.0, 0.65]:
				d.tube("white", foot + Vector3(0, 6.56, e), foot + Vector3(0, 6.78, e), 0.04, 6, "Detail", BOTH)
			tops.append(foot + Vector3(0, 6.78, 0))
			x += 20.0
		for i in tops.size() - 1:
			for e: float in [-0.65, 0.0, 0.65]:
				var a: Vector3 = tops[i] + Vector3(0, 0, e)
				var b: Vector3 = tops[i + 1] + Vector3(0, 0, e)
				var pts := PackedVector3Array()
				for k in 9:
					var t := k / 8.0
					pts.append(a.lerp(b, t) - Vector3(0, sin(t * PI) * 0.7, 0))
				d.path_tube("black", pts, 0.012, 3, "Detail", BOTH)
	# Weeds: along the foot of the walls on the floor and the galleries,
	# and here and there in the ballast.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for run: Array in [[0.0, -15.7, -60.0, -40.0], [0.0, -15.7, 30.0, 58.0], [0.0, -11.7, -40.0, 30.0], [0.0, 15.7, -58.0, -30.0],
			[0.0, 15.7, 50.0, 60.0], [0.0, 11.7, -30.0, 50.0], [Rift.NORTH_SHELF, -15.7, -40.0, 30.0], [Rift.SOUTH_SHELF, 15.7, -30.0, 50.0]]:
		var x: float = run[2]
		while x < float(run[3]):
			if rng.randf() < 0.55:
				_tuft(st, Vector3(x + rng.randf_range(-0.3, 0.3), run[0], float(run[1]) + rng.randf_range(-0.15, 0.15)), rng)
			x += 0.8
	for i in 90:
		var p := Vector3(rng.randf_range(-58.0, 58.0), 0.0, rng.randf_range(-14.0, 14.0))
		if absf(p.x + 30.0) > 5.0 and not (absf(p.x) < 5.0 and absf(p.z) < 4.0):
			_tuft(st, p, rng)
	var mesh := st.commit()
	ResourceSaver.save(mesh, d.dir + "meshes/weeds.res")
	d.own_mesh("Weeds", load(d.dir + "meshes/weeds.res"), d.mat("grass"), Transform3D.IDENTITY, "Detail")
	# Litter: tickets and a newspaper or two, on the floor and the galleries.
	for i in 40:
		var gallery := i % 4
		var p: Vector3
		if gallery == 0:
			p = Vector3(rng.randf_range(-38.0, 28.0), Rift.NORTH_SHELF, rng.randf_range(-15.6, -12.4))
		elif gallery == 1:
			p = Vector3(rng.randf_range(-28.0, 48.0), Rift.SOUTH_SHELF, rng.randf_range(12.4, 15.6))
		else:
			p = Vector3(rng.randf_range(-58.0, 58.0), 0.0, rng.randf_range(-15.0, 15.0))
		var big := i % 9 == 0
		d.box("paper", p + Vector3(0, 0.006, 0), Vector3(0.45 if big else 0.07, 0.008, 0.32 if big else 0.13), "Detail", BOTH,
				Basis(Vector3.UP, rng.randf() * TAU))
	# Puddles and oil in the ballast.
	for p: Vector3 in [Vector3(-44, 0, 4.5), Vector3(-6, 0, -4.6), Vector3(38, 0, 4.3), Vector3(-52, 0, -13.2), Vector3(12, 0, 13.0)]:
		var r := Basis(Vector3.UP, rng.randf() * TAU)
		d.face("puddle", p + Vector3(0, 0.03, 0), r * Vector3(1.2, 0, 0), r * Vector3(0, 0, -0.8), "Effects", BOTH)
	for z: float in TRACKS:
		for k in 6:
			var p := Vector3(rng.randf_range(-56.0, 56.0), 0.02, z)
			var r := Basis(Vector3.UP, rng.randf_range(-0.3, 0.3))
			d.face("oil", p, r * Vector3(0.6, 0, 0), r * Vector3(0, 0, -0.4), "Effects", BOTH)
	# Fishplates where the rails join, about every 18 m.
	for z: float in TRACKS:
		var x := -57.0
		while x < 58.0:
			var inside_arch := x > -34.5 and x < -25.5 and z != 0.0
			var on_island := absf(x) < 4.7 and z == 0.0
			if not inside_arch and not on_island:
				for s: float in [-GAUGE, GAUGE]:
					for e: float in [-0.06, 0.06]:
						d.box("dark_metal", Vector3(x, 0.2, z + s + e), Vector3(0.6, 0.1, 0.02), "Detail", BOTH)
			x += 18.3
	# Enamel adverts on the galleries' back walls.
	for a: Array in [[Vector3(-16, Rift.NORTH_SHELF + 1.7, -15.97), 1.0, "enamel_red", "Nimbus Cocoa", Color(1.0, 0.9, 0.7)],
			[Vector3(9, Rift.NORTH_SHELF + 1.7, -15.97), 1.0, "enamel_yellow", "Summit Mints", Color(0.2, 0.12, 0.05)],
			[Vector3(-4, Rift.SOUTH_SHELF + 1.7, 15.97), -1.0, "enamel_blue", "Cirrus Soap", Color(1, 1, 1)],
			[Vector3(44, Rift.SOUTH_SHELF + 1.7, 15.97), -1.0, "enamel_green", "Drink Stratus Tonic", Color(1.0, 0.92, 0.6)]]:
		var n := Vector3(0, 0, a[1])
		var b := DecoKit.facing(n)
		d.box("white", (a[0] as Vector3) + n * 0.015, Vector3(2.3, 0.8, 0.03), "Detail", BOTH, b)
		d.box(a[2], (a[0] as Vector3) + n * 0.03, Vector3(2.2, 0.7, 0.03), "Detail", BOTH, b)
		d.words(a[3], (a[0] as Vector3) + n * 0.05, b, 0.22, a[4], 0.0, "Detail", BOTH, SWASH)
	# A pillar box, a chocolate machine, a weighing machine: against the walls.
	var box_at := Vector3(46.5, Rift.SOUTH_SHELF, 15.55)
	d.solid(box_at + Vector3(0, 0.75, 0), Vector3(0.56, 1.5, 0.56))
	d.tube("red", box_at, box_at + Vector3(0, 1.35, 0), 0.26, 12, "Solid", BOTH)
	d.ball("red", box_at + Vector3(0, 1.35, 0), Vector3(0.3, 0.16, 0.3), 3, 12, "Solid", BOTH)
	d.box("black", box_at + Vector3(0, 1.1, -0.26), Vector3(0.24, 0.04, 0.02), "Solid", BOTH)
	var choc := Vector3(-2.0, Rift.NORTH_SHELF, -15.6)
	d.solid(choc + Vector3(0, 0.9, 0), Vector3(0.8, 1.8, 0.5))
	d.box("enamel_red", choc + Vector3(0, 0.9, 0), Vector3(0.8, 1.8, 0.5), "Solid", BOTH)
	d.face("window_warm", choc + Vector3(0, 1.2, 0.252), Vector3(0.28, 0, 0), Vector3(0, 0.4, 0), "Fixtures", BOTH)
	d.words("Chocolate", choc + Vector3(0, 1.72, 0.26), DecoKit.facing(Vector3(0, 0, 1)), 0.1, Color(1, 0.95, 0.8), 0.0, "Solid", BOTH, SWASH)
	var scale_at := Vector3(22.0, Rift.SOUTH_SHELF, 15.6)
	d.solid(scale_at + Vector3(0, 0.95, 0), Vector3(0.6, 1.9, 0.5))
	d.box("enamel_green", scale_at + Vector3(0, 1.3, 0), Vector3(0.5, 1.1, 0.4), "Solid", BOTH)
	d.box("dark_metal", scale_at + Vector3(0, 0.1, -0.1), Vector3(0.6, 0.2, 0.7), "Solid", BOTH)
	_clock(d, scale_at + Vector3(0, 1.5, -0.21), Vector3(0, 0, -1), 0.18, 0.0, 12.0)
	# Spare sleepers stacked against the north wall at the west end.
	var pile := Vector3(-58.5, 0.0, -15.2)
	d.solid(pile + Vector3(0, 0.33, 0), Vector3(2.6, 0.66, 1.1))
	for layer in 3:
		for k in 4:
			d.box("sleeper", pile + Vector3(0, 0.11 + layer * 0.22, -0.4 + k * 0.27 + (0.1 if layer % 2 == 1 else 0.0)), Vector3(2.5, 0.2, 0.24),
					"Solid", BOTH)
	# The way out, where the passenger ramps start.
	for w: Array in [[Vector3(57.5, 2.4, -15.98), 1.0], [Vector3(-57.5, 2.4, 15.98), -1.0]]:
		var n := Vector3(0, 0, w[1])
		var b := DecoKit.facing(n)
		d.box("white", (w[0] as Vector3) + n * 0.015, Vector3(1.6, 0.46, 0.03), "Build", BOTH, b)
		d.box("navy", (w[0] as Vector3) + n * 0.03, Vector3(1.52, 0.38, 0.03), "Build", BOTH, b)
		d.words("Way out  ↑", (w[0] as Vector3) + n * 0.05, b, 0.2, Color(1, 1, 1), 0.0, "Build", BOTH, SANS)
	# Snow drifted against the dry-stone walls, on the weather side.
	for x: float in [-80.0, -20.0, 20.0, 80.0]:
		for rim: Array in [[NORTH, -21.0, -1.0], [SOUTH, 19.0, -1.0]]:
			var c := Vector3(x if rim[0] == NORTH else -x, float(rim[0]), float(rim[1]) + float(rim[2]) * 0.2)
			d.ball("snow_drift", c, Vector3(2.2, 0.35, 0.5), 3, 10, "Detail", BOTH)


## Whether the turf's texture at (x, z) is grass (not snow, not rock).
static func _turf(img: Image, p: Vector2) -> bool:
	var u := fposmod(p.x / 8.0, 1.0)
	var v := fposmod(p.y / 8.0, 1.0)
	var c := img.get_pixel(mini(int(u * img.get_width()), img.get_width() - 1), mini(int(v * img.get_height()), img.get_height() - 1))
	return c.v < 0.7 and c.s > 0.2


## Where nothing grows or lies on the shoulders: the towers, the rocks,
## the pads, the walls' ends, the benches.
static func _rim_keep_out() -> Array:
	var keep_out := [Rect2(-64.5, -36.5, 23, 9), Rect2(41.5, 27.5, 23, 9), Rect2(-6.5, -38.5, 9, 7), Rect2(-2.5, 31.5, 9, 7),
			Rect2(18.8, -35.2, 2.4, 2.4), Rect2(32.8, -31.2, 2.4, 2.4), Rect2(-21.2, 32.8, 2.4, 2.4), Rect2(-35.2, 28.8, 2.4, 2.4),
			Rect2(-68, -39, 4, 4)]
	for x: float in [-80.0, -20.0, 20.0, 80.0]:
		keep_out.append(Rect2(x - 2.4, -21.4, 4.8, 2.8))
		keep_out.append(Rect2(-x - 2.4, 18.6, 4.8, 2.8))
	for x: float in [-40.0, 10.0, 60.0]:
		keep_out.append(Rect2(x - 1.2, -42.6, 2.4, 1.4))
	for x: float in [-60.0, -10.0, 40.0]:
		keep_out.append(Rect2(x - 1.2, 41.2, 2.4, 1.4))
	return keep_out


static func _kept_out(p: Vector2, rects: Array) -> bool:
	for r: Rect2 in rects:
		if r.has_point(p):
			return true
	return false


## A tuft: a handful of blades leaning out from a point, dark at the root,
## tawny or green at the tips.
static func _tuft(st: SurfaceTool, at: Vector3, rng: RandomNumberGenerator) -> void:
	var blades := rng.randi_range(8, 13)
	var tip_colour := Color(0.86, 0.78, 0.50).lerp(Color(0.58, 0.70, 0.34), rng.randf())
	for k in blades:
		var a := rng.randf() * TAU
		var out := Vector3(cos(a), 0, sin(a))
		var base := at + out * rng.randf_range(0.0, 0.14)
		var height := rng.randf_range(0.12, 0.32)
		var tip := base + out * rng.randf_range(0.04, 0.14) + Vector3(0, height, 0)
		var across := Vector3(-out.z, 0, out.x) * rng.randf_range(0.012, 0.022)
		for v: Array in [[base - across, 0.0], [base + across, 0.0], [tip, 1.0]]:
			st.set_color(Color(0.40, 0.42, 0.22).lerp(tip_colour, v[1]))
			st.set_uv(Vector2(0, v[1]))
			st.set_normal((Vector3.UP * 2.0 + out).normalized())
			st.add_vertex(v[0])


# --- Far off ----------------------------------------------------------------------------------

## Which way the sun is (from its light's rotation).
static func _to_sun() -> Vector3:
	return Basis.from_euler(SUN * (PI / 180.0)).z


# The mountains: a range all round, walling in the sea of cloud a few
# hundred metres out. Its crest runs round an ellipse (RING, its
# half-widths), wandering in and out; ridged noise makes the peaks and
# cols along it, the massifs of a few PEAKS [bearing, how much higher]
# standing over the rest.
# Lower toward the sun, which comes up through the gap; broken by two
# deep NOTCHES [bearing] the line crosses on its viaducts. (Bearings in
# degrees, atan2(z, x).)
const RING := Vector2(370.0, 345.0)
const NOTCHES := [-117.0, 63.0]
const PEAKS := [[-158.0, 0.3], [-82.0, 0.4], [-36.0, 0.2], [112.0, 0.38], [168.0, 0.26]]


## The ground at (x, z): under the station flat (hidden by it); round it
## the station's peak falling away in cliffs, the ridge it's on running on
## east and west to the range; the range round it all; all of it made
## rugged by ridged noise where it's high.
static func _height(x: float, z: float, n: Array) -> float:
	var ridges: FastNoiseLite = n[0]
	var detail: FastNoiseLite = n[1]
	var crest: FastNoiseLite = n[2]
	var dx := maxf(absf(x) - 100.0, 0.0)
	var dz := maxf(absf(z) - 44.0, 0.0)
	var d := sqrt(dx * dx + dz * dz)
	if d <= 0.0:
		return -12.5
	var h := -12.5 - pow(d, 1.12) * 1.5
	if absf(x) > 100.0:
		h = maxf(h, -12.5 - (absf(x) - 100.0) * 0.28 - pow(dz, 1.1) * 1.4)
	# How far out from the crest (metres, inside negative), the crest
	# wandering; the range falls steeper to the inside.
	var a := atan2(z, x)
	var wander := sin(3.0 * a + 1.0) * 0.6 + sin(5.0 * a + 2.0) * 0.4
	var off := (sqrt(pow(x / RING.x, 2.0) + pow(z / RING.y, 2.0)) - 1.0 - 0.05 * wander) * 355.0
	var band := exp(-pow(off / (105.0 if off < 0.0 else 130.0), 2.0))
	var sun := _to_sun()
	var tall := lerpf(0.72, 1.0, smoothstep(0.3, 1.1, absf(angle_difference(a, atan2(sun.z, sun.x)))))
	for notch: float in NOTCHES:
		tall *= 1.0 - 0.8 * exp(-pow(angle_difference(a, deg_to_rad(notch)) / 0.15, 2.0))
	var ridge := crest.get_noise_2d(x, z) * 0.5 + 0.5
	var massif := 1.0
	for pk: Array in PEAKS:
		var b := deg_to_rad(float(pk[0]))
		var far := Vector2(x - cos(b) * RING.x * 1.04, z - sin(b) * RING.y * 1.04).length()
		massif += float(pk[1]) * exp(-pow(far / 95.0, 2.0))
	h = maxf(h, -165.0 + band * tall * massif * 240.0 * (0.3 + 0.8 * ridge))
	var rugged := 1.0 - absf(ridges.get_noise_2d(x, z))
	var rough := clampf((h + 150.0) / 250.0, 0.0, 1.0)
	h += (rugged * rugged - 0.45) * 50.0 * rough + detail.get_noise_2d(x, z) * 7.0 * rough
	# Meet the station's footprint exactly.
	return lerpf(-12.5, maxf(h, -250.0), clampf(d / 12.0, 0.0, 1.0))


static func _noises() -> Array:
	var ridges := FastNoiseLite.new()
	ridges.seed = 31
	ridges.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ridges.frequency = 1.0 / 90.0
	ridges.fractal_type = FastNoiseLite.FRACTAL_FBM
	ridges.fractal_octaves = 3
	var detail := FastNoiseLite.new()
	detail.seed = 77
	detail.frequency = 1.0 / 22.0
	var crest := FastNoiseLite.new()
	crest.seed = 4410
	crest.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	crest.frequency = 1.0 / 240.0
	crest.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	crest.fractal_octaves = 4
	crest.domain_warp_enabled = true
	crest.domain_warp_amplitude = 45.0
	crest.domain_warp_frequency = 1.0 / 300.0
	return [ridges, detail, crest]


## The range round the station: one mesh of ground (a grid of heights,
## the parts sunk in the cloud left out), rock and snow by its shader.
static func _range(d) -> void:
	var n := _noises()
	var step := 8.0
	var x0 := -640.0
	var z0 := -560.0
	var cols := 161
	var rows := 141
	var heights := PackedFloat32Array()
	heights.resize(cols * rows)
	for j in rows:
		for i in cols:
			heights[j * cols + i] = _height(x0 + i * step, z0 + j * step, n)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	verts.resize(cols * rows)
	normals.resize(cols * rows)
	for j in rows:
		for i in cols:
			var hl := heights[j * cols + maxi(i - 1, 0)]
			var hr := heights[j * cols + mini(i + 1, cols - 1)]
			var hd := heights[maxi(j - 1, 0) * cols + i]
			var hu := heights[mini(j + 1, rows - 1) * cols + i]
			verts[j * cols + i] = Vector3(x0 + i * step, heights[j * cols + i], z0 + j * step)
			normals[j * cols + i] = Vector3(hl - hr, 2.0 * step, hd - hu).normalized()
	var indices := PackedInt32Array()
	for j in rows - 1:
		for i in cols - 1:
			var a := j * cols + i
			var q := [a, a + 1, a + cols + 1, a + cols]
			var top := -INF
			var under := true
			for k: int in q:
				top = maxf(top, heights[k])
				var v := verts[k]
				if absf(v.x) > 100.5 or absf(v.z) > 44.5:
					under = false
			if top < -180.0 or under:
				continue
			indices.append_array([q[0], q[1], q[2], q[0], q[2], q[3]])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	ResourceSaver.save(mesh, d.dir + "meshes/range.res")
	d.own_mesh("Range", load(d.dir + "meshes/range.res"), d.mat("range"), Transform3D.IDENTITY, "Far")


## The sea of cloud: a surface heaped in soft billows, lit on the sun's
## side (its shader), drifting.
static func _cloud_sea(d) -> void:
	var billows := FastNoiseLite.new()
	billows.seed = 9
	billows.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	billows.frequency = 1.0 / 150.0
	billows.fractal_octaves = 3
	var step := 16.0
	var cols := 81
	var rows := 71
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var at := func(i: int, j: int) -> Vector3:
		var x := -640.0 + i * step
		var z := -560.0 + j * step
		var b := clampf(billows.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)
		return Vector3(x, -152.0 + pow(b, 1.6) * 34.0, z)
	for j in rows - 1:
		for i in cols - 1:
			var q := [at.call(i, j), at.call(i + 1, j), at.call(i + 1, j + 1), at.call(i, j + 1)]
			for k: int in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(q[k])
	st.index()
	st.generate_normals()
	var mesh := st.commit()
	ResourceSaver.save(mesh, d.dir + "meshes/cloud_sea.res")
	d.own_mesh("CloudSea", load(d.dir + "meshes/cloud_sea.res"), d.mat("cloud_sea"), Transform3D.IDENTITY, "Far")


## The overcast overhead: a deck of cloud 170 m up, fading out toward the
## horizon, thinning and lit gold where the sun shines through.
static func _cloud_deck(d) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 40.0
	for j in 26:
		for i in 26:
			var p := Vector3(-520.0 + i * step, 170.0, -520.0 + j * step)
			var q := [p, p + Vector3(step, 0, 0), p + Vector3(step, 0, step), p + Vector3(0, 0, step)]
			for k: int in [0, 1, 2, 0, 2, 3]:
				st.set_normal(Vector3.DOWN)
				st.add_vertex(q[k])
	st.index()
	var mesh := st.commit()
	ResourceSaver.save(mesh, d.dir + "meshes/cloud_deck.res")
	d.own_mesh("CloudDeck", load(d.dir + "meshes/cloud_deck.res"), d.mat("cloud_deck"), Transform3D.IDENTITY, "Far")


## Shafts of sun slanting down out of the break toward the station, faint
## in the haze, each a crossed pair of sheets.
static func _sunbeams(d) -> void:
	var to_sun := _to_sun()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2210
	for i in 6:
		var aim := Vector3(rng.randf_range(20.0, 260.0), rng.randf_range(-40.0, -10.0), rng.randf_range(-160.0, 160.0))
		var top := aim + to_sun * 320.0
		var down := (aim - top).normalized()
		for k in 2:
			var across := down.cross(Vector3.UP if k == 0 else Vector3(0, 0, 1)).normalized() * 12.0
			d.quad("sunbeam", top - across, top + across, aim + across, aim - across, "Effects", BOTH)


## The line out across the cloud, far off: a stone viaduct of arches on
## tall piers across each notch in the ring, from one mountainside to the
## next, coming out of the rock at each end; a train stopped out on the
## north one. (At the ends of the cutting the tracks stop at buffers at the
## edge.) Each is [one end, the other], found by walking out from the
## middle of the notch both ways until the ground comes up to the deck.
static func _viaduct_ends() -> Array:
	var n := _noises()
	var ends := []
	for i in NOTCHES.size():
		var a := deg_to_rad(float(NOTCHES[i]))
		var deck := -30.0 - i * 10.0
		var mid := Vector3(cos(a) * RING.x, deck, sin(a) * RING.y)
		var along := Vector3(-sin(a) * RING.x, 0.0, cos(a) * RING.y).normalized()
		var pair := []
		for way: float in [-1.0, 1.0]:
			var s := 0.0
			while s < 260.0 and _height(mid.x + along.x * way * s, mid.z + along.z * way * s, n) < deck + 2.0:
				s += 4.0
			pair.append(mid + along * way * (s + 6.0))
		ends.append(pair)
	return ends


static func _viaducts(d) -> void:
	var n := _noises()
	var viaducts := _viaduct_ends()
	for v: Array in viaducts:
		var a: Vector3 = v[0]
		var b: Vector3 = v[1]
		var dir := (b - a).normalized()
		var length := a.distance_to(b)
		var side := dir.cross(Vector3.UP).normalized()
		var basis := Basis(dir, Vector3.UP, side)
		var mid := (a + b) * 0.5
		d.box("far_stone", mid + Vector3(0, -1.0, 0), Vector3(length, 2.0, 6.0), "Far", BOTH, basis)
		for s: float in [-GAUGE, GAUGE]:
			d.box("far_stone", mid + side * s + Vector3(0, 0.1, 0), Vector3(length, 0.2, 0.12), "Far", BOTH, basis)
		var span := 26.0
		var piers := int(length / span)
		for i in piers + 1:
			var p := a + dir * (i * span)
			var ground := maxf(_height(p.x, p.z, n), -175.0)
			var depth := p.y - 2.0 - ground
			if depth > 1.0:
				d.box("far_stone", p + Vector3(0, -2.0 - depth * 0.5, 0), Vector3(4.0, depth, 6.0), "Far", BOTH, basis)
			if i < piers:
				var q := p + dir * span * 0.5
				d.box("far_stone", q + Vector3(0, -3.5, 0), Vector3(span, 3.0, 5.6), "Far", BOTH, basis)
				for e: float in [-1.0, 1.0]:
					d.box("far_stone", q + dir * e * (span * 0.5 - 3.5) + Vector3(0, -7.5, 0), Vector3(4.2, 5.0, 5.6), "Far", BOTH, basis)
	var a0: Vector3 = viaducts[0][0]
	var dir := ((viaducts[0][1] as Vector3) - a0).normalized()
	var middle := (a0 + (viaducts[0][1] as Vector3)) * 0.5
	var basis := Basis(dir, Vector3.UP, dir.cross(Vector3.UP).normalized())
	for k in 4:
		var c := middle + dir * (k * 14.0 - 30.0) + Vector3(0, 1.8, 0)
		d.box("far_maroon", c + Vector3(0, -0.2, 0), Vector3(13.0, 2.6, 3.2), "Far", BOTH, basis)
		d.box("far_cream", c + Vector3(0, 1.4, 0), Vector3(13.0, 0.8, 3.22), "Far", BOTH, basis)
