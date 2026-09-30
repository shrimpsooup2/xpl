extends RefCounted
## TERRACE, dressed (GDD §9.3): the food court of a dead mall, at noon, in
## a total eclipse.
##
## The town is the food court. Block A is three food stalls back to back,
## Block B a restaurant, Block C the restrooms (their tiles the wall-ride
## tiles, as on every map); the long street runs from the mall's chained
## front doors to the information desk (the Pulpit), past the directory
## (the Kiosk), and the square sits under a skybridge (the Overpass). The
## crates are vending machines. The terrace is the upper level: shopfronts
## along the walls (an arcade and a cinema still lit), a lemonade stand (the
## Shed), planters, and a stage in the corner for the eclipse party nobody
## came to. The Stairs are an escalator and the Slide a travelator, both
## stopped.
##
## Over it all a glass barrel vault on white steel ribs, out of reach, the
## walls rising to it in a band of clerestory windows; a few panes gone,
## two under tarps, balloons from the party stuck against the glass. Through
## it the black sun: the moon in front of it, the corona white round it,
## the sky dark blue overhead and orange all round the horizon. The mall's
## lights came on in the dark: festoon bulbs strung from the piers over
## everything, the stalls' neon, menu boards, a few shops, the vending
## machines. Every lamp has something to come from. The gameplay blocks are
## untouched, only dressed: the map plays as it did.

const DecoKit := preload("res://tools/deco_kit.gd")
const BOTH := DecoKit.LAYER_BOTH
const TOP := 4.0

const BULB := Color(1.0, 0.72, 0.40)
const CORONA := Color(0.78, 0.82, 1.0)
const WARM := Color(1.0, 0.84, 0.62)
const GLOW := "res://src/render/deco/glow.gdshader"
const HALO := "res://src/render/deco/halo.gdshader"
const LIGHTBOX := "res://src/render/deco/lightbox.gdshader"
const SHOP := "res://src/render/deco/shop_window.gdshader"

## The skylight: the walls rise in a clerestory from 9 m to RING, where a
## glass vault springs, RISE higher in the middle; ribs every RIB metres
## (on the clerestory's piers), FACETS flat panes of glass across.
const WALL_TOP := 9.0
const RING := 13.2
const RISE := 5.0
const HALF_SPAN := 18.0
const RIB := 4.0
const FACETS := 12
## Panes gone (rib bay, facet), and panes under tarps.
const MISSING := [Vector2i(3, 5), Vector2i(8, 2), Vector2i(10, 9)]
const TARPS := [Vector2i(5, 7), Vector2i(1, 3)]

## Shopfronts: [foot of the middle on the wall (x, z), facing, width, name,
## colour, style ("neon", "box" or "" for none), shutter (0 up .. 1 shut)].
const TOWN_SHOPS := [
	[Vector2(-24, -15), Vector3(1, 0, 0), 5.0, "PET PALACE", Color(0.3, 0.75, 1.0), "box", 1.0],
	[Vector2(-24, -8), Vector3(1, 0, 0), 5.0, "PRETZEL STAR", Color(1.0, 0.55, 0.15), "neon", 0.5],
	[Vector2(-24, 8), Vector3(1, 0, 0), 5.0, "SPACE AVAILABLE", Color.WHITE, "", 0.0],
	[Vector2(-24, 14.5), Vector3(1, 0, 0), 5.0, "SHOE CITY", Color(1.0, 0.4, 0.4), "box", 0.35],
	[Vector2(-20.5, -18), Vector3(0, 0, 1), 5.0, "GYRO GALAXY", Color(0.3, 0.55, 1.0), "neon", 0.6],
	[Vector2(-14.5, -18), Vector3(0, 0, 1), 5.0, "SOUP STATION", Color(1.0, 0.85, 0.4), "box", 1.0],
	[Vector2(-8.5, -18), Vector3(0, 0, 1), 5.0, "PHOTO 1 HR", Color(0.5, 1.0, 0.6), "box", 0.0],
	[Vector2(-20.5, 18), Vector3(0, 0, -1), 5.0, "FROZEN YOGURT", Color(1.0, 0.4, 0.8), "neon", 0.4],
	[Vector2(-14.5, 18), Vector3(0, 0, -1), 5.0, "CARDS & GIFTS", Color(0.9, 0.5, 1.0), "box", 1.0],
]
const UPPER_SHOPS := [
	[Vector2(5.5, -18), Vector3(0, 0, 1), 4.5, "BOOKS", Color(1.0, 0.9, 0.7), "box", 0.8],
	[Vector2(10.5, -18), Vector3(0, 0, 1), 4.5, "RECORDS", Color(0.7, 0.4, 1.0), "neon", 0.3],
	[Vector2(15.5, -18), Vector3(0, 0, 1), 4.0, "TOYS", Color(1.0, 0.6, 0.2), "box", 1.0],
	[Vector2(5.5, 18), Vector3(0, 0, -1), 4.5, "SHADES", Color(1.0, 0.85, 0.2), "neon", 0.0],
	[Vector2(20.0, 18), Vector3(0, 0, -1), 5.0, "CAFE", Color(1.0, 0.6, 0.35), "neon", 0.6],
	[Vector2(24, -8.5), Vector3(-1, 0, 0), 5.0, "SPACE AVAILABLE", Color.WHITE, "", 0.0],
	[Vector2(24, 5.0), Vector3(-1, 0, 0), 5.0, "PHONE REPAIR", Color(0.5, 0.9, 1.0), "box", 1.0],
	[Vector2(24, 11.5), Vector3(-1, 0, 0), 5.0, "PERFUME", Color(1.0, 0.7, 0.85), "box", 0.5],
]


static func dress(kit, d) -> void:
	_eclipse(kit)
	_materials(d)
	_surfaces(kit, d)
	_under_the_bridge(kit, d)
	_shops(d)
	_entrance(d)
	_food_stalls(d)
	_restaurant(d)
	_restrooms(d)
	_directory(d)
	_vending(d)
	_escalators(d)
	_information(d)
	_edges(d)
	_upper_level(d)
	_arcade_and_cinema(d)
	_stage(d)
	_court(d)
	_palms(d)
	_skylight(d)
	_festoons(d)
	_mall_sign(d)
	_balloons(d)
	_outside(d)


# --- The eclipse ---------------------------------------------------------------------------

## Noon, and the moon in front of the sun: a dark blue sky, orange all
## round the horizon, stars out, and the corona's thin silver light.
static func _eclipse(kit) -> void:
	var e: Environment = kit.environment
	var sky: ShaderMaterial = e.sky.sky_material
	sky.set_shader_parameter(&"top_color", Color(0.02, 0.025, 0.07))
	sky.set_shader_parameter(&"upper_color", Color(0.07, 0.08, 0.20))
	sky.set_shader_parameter(&"horizon_color", Color(0.95, 0.46, 0.20))
	sky.set_shader_parameter(&"ground_color", Color(0.06, 0.04, 0.05))
	sky.set_shader_parameter(&"sun_color", Color(0.92, 0.95, 1.0))
	sky.set_shader_parameter(&"sun_size", 0.06)
	sky.set_shader_parameter(&"halo", 0.35)
	sky.set_shader_parameter(&"stars", 0.6)
	sky.set_shader_parameter(&"eclipse", 1.0)
	e.ambient_light_color = Color(0.40, 0.34, 0.50)
	e.ambient_light_energy = 0.5
	e.fog_light_color = Color(0.22, 0.12, 0.10)
	e.fog_density = 0.006
	e.fog_sky_affect = 0.1
	e.glow_intensity = 0.75
	e.glow_hdr_threshold = 1.0
	e.glow_bloom = 0.0
	var sun: DirectionalLight3D = kit.sun
	# High in the west-south-west: over the town from the terrace, behind
	# the information desk.
	sun.rotation_degrees = Vector3(-36, -66, 0)
	sun.light_color = CORONA
	sun.light_energy = 0.35
	sun.light_specular = 0.2
	sun.directional_shadow_max_distance = 60.0


# --- Materials --------------------------------------------------------------------------------

static func _materials(d) -> void:
	d.reflection = load("res://assets/textures/terrace/reflection_eclipse.png")
	# The gameplay blocks.
	d.surface("court_floor", {"side": "stack/concrete", "meters": 3.0, "top": "terrace/terrazzo", "top_meters": 3.0,
			"gloss": 0.22, "grazing": 0.6, "roughness": 0.3, "specular": 0.3})
	d.surface("mall_wall", {"side": "terrace/stucco", "meters": 4.0, "top": "stack/coping", "top_meters": 2.0,
			"gloss": 0.04, "grazing": 0.25, "roughness": 0.8})
	d.surface("cliff", {"side": "ride_tiles", "meters": 2.0, "top": "terrace/pavers", "gloss": 0.3, "grazing": 0.7, "roughness": 0.2})
	d.surface("upper_floor", {"side": "terrace/cladding", "meters": 2.0, "top": "terrace/pavers", "top_meters": 2.0,
			"gloss": 0.12, "grazing": 0.45, "roughness": 0.45})
	d.surface("info_desk", {"side": "terrace/cladding", "meters": 2.0, "top": "terrace/cladding", "top_meters": 2.0,
			"gloss": 0.3, "grazing": 0.7, "roughness": 0.2})
	d.surface("vending_red", {"side": "stack/steel", "meters": 1.0, "tint": Color(0.75, 0.12, 0.12), "top": "stack/steel",
			"top_meters": 1.0, "gloss": 0.25, "grazing": 0.6, "roughness": 0.35})
	d.surface("vending_blue", {"side": "stack/steel", "meters": 1.0, "tint": Color(0.14, 0.28, 0.72), "top": "stack/steel",
			"top_meters": 1.0, "gloss": 0.25, "grazing": 0.6, "roughness": 0.35})
	d.surface("lemon_stall", {"side": "stack/pool_tiles", "meters": 2.0, "tint": Color(1.15, 0.98, 0.42), "top": "stack/steel",
			"top_meters": 1.0, "gloss": 0.2, "grazing": 0.6, "roughness": 0.3})
	d.surface("planter", {"side": "terrace/cladding", "meters": 2.0, "top": "terrace/foliage", "top_meters": 1.0,
			"gloss": 0.2, "grazing": 0.5, "roughness": 0.35})
	d.surface("stage", {"side": "terrace/carpet", "meters": 2.0, "top": "terrace/wood", "top_meters": 1.0,
			"top_tint": Color(0.45, 0.40, 0.40), "gloss": 0.1, "grazing": 0.4, "roughness": 0.6})
	d.surface("stall_block", {"side": "terrace/stucco", "meters": 4.0, "tint": Color(1.0, 0.9, 0.82), "gloss": 0.04,
			"grazing": 0.25, "roughness": 0.8})
	d.surface("deck", {"side": "terrace/cladding", "meters": 2.0, "top": "terrace/wood", "top_meters": 1.0,
			"gloss": 0.12, "grazing": 0.45, "roughness": 0.5})
	d.surface("bridge", {"side": "terrace/cladding", "meters": 2.0, "top": "terrace/pavers", "top_meters": 2.0,
			"bottom": "stack/ceiling", "bottom_meters": 2.0, "gloss": 0.15, "grazing": 0.5, "roughness": 0.4})
	d.surface("restaurant", {"side": "terrace/stucco", "meters": 4.0, "tint": Color(0.86, 0.84, 0.94), "top": "stack/concrete",
			"top_meters": 3.0, "gloss": 0.04, "grazing": 0.25, "roughness": 0.8})
	d.surface("restrooms", {"side": "ride_tiles", "meters": 2.0, "top": "stack/concrete", "top_meters": 3.0,
			"gloss": 0.3, "grazing": 0.7, "roughness": 0.2})
	d.surface("directory_body", {"side": "terrace/cladding", "meters": 2.0, "top": "stack/steel", "top_meters": 1.0,
			"gloss": 0.3, "grazing": 0.7, "roughness": 0.2})
	d.surface("travelator", {"side": "stack/steel", "meters": 1.0, "top": "terrace/travelator", "top_meters": 0.8,
			"gloss": 0.35, "grazing": 0.75, "roughness": 0.25})
	d.surface("escalator", {"side": "stack/steel", "meters": 1.0, "top": "terrace/treads", "top_meters": 0.8,
			"gloss": 0.35, "grazing": 0.75, "roughness": 0.25})
	# Decor (UVs in metres).
	for m: Array in [
			["steel", "stack/steel", 1.0, Color.WHITE, 0.45, 0.8, 0.25],
			["chrome", "stack/steel", 1.0, Color(1.1, 1.1, 1.15), 0.8, 0.95, 0.12],
			["brass", "stack/steel", 1.0, Color(1.25, 0.92, 0.45), 0.6, 0.9, 0.2],
			["dark_metal", "stack/steel", 1.0, Color(0.26, 0.26, 0.30), 0.25, 0.5, 0.4],
			["black", "stack/steel", 1.0, Color(0.05, 0.05, 0.06), 0.2, 0.5, 0.4],
			["rubber", "stack/steel", 1.0, Color(0.04, 0.04, 0.045), 0.35, 0.6, 0.3],
			["cladding", "terrace/cladding", 2.0, Color.WHITE, 0.3, 0.7, 0.2],
			["black_stone", "terrace/cladding", 2.0, Color(1.2, 1.2, 1.3), 0.45, 0.8, 0.15],
			["shutter", "terrace/shutter", 1.0, Color.WHITE, 0.2, 0.5, 0.4],
			["wood", "terrace/wood", 1.0, Color.WHITE, 0.12, 0.45, 0.5],
			["trunk", "terrace/wood", 1.0, Color(0.55, 0.48, 0.42), 0.05, 0.2, 0.8],
			["foliage", "terrace/foliage", 1.0, Color.WHITE, 0.2, 0.5, 0.35],
			["carpet", "terrace/carpet", 2.0, Color.WHITE, 0.02, 0.1, 0.9],
			["banner", "terrace/stucco", 4.0, Color(0.12, 0.14, 0.34), 0.02, 0.15, 0.9],
			["paper", "terrace/stucco", 4.0, Color(1.25, 1.2, 1.1), 0.02, 0.1, 0.9],
			["cardboard", "terrace/stucco", 4.0, Color(1.2, 1.12, 0.95), 0.02, 0.1, 0.9],
			["door_blue", "stack/steel", 2.0, Color(0.30, 0.42, 0.62), 0.2, 0.5, 0.4],
			["bin", "stack/steel", 1.0, Color(0.22, 0.34, 0.28), 0.25, 0.55, 0.4],
			["red", "stack/steel", 1.0, Color(0.85, 0.15, 0.15), 0.3, 0.6, 0.3],
			["white", "stack/steel", 1.0, Color(1.1, 1.1, 1.1), 0.3, 0.6, 0.3],
			["yellow_line", "stack/grip", 1.0, Color(2.4, 1.9, 0.4), 0.05, 0.2, 0.7],
			["tile_burger", "stack/pool_tiles", 1.0, Color(1.2, 0.72, 0.3), 0.25, 0.6, 0.3],
			["tile_taco", "stack/pool_tiles", 1.0, Color(0.5, 1.0, 0.6), 0.25, 0.6, 0.3],
			["tile_noodle", "stack/pool_tiles", 1.0, Color(1.2, 0.45, 0.45), 0.25, 0.6, 0.3],
			["tile_lemon", "stack/pool_tiles", 1.0, Color(1.15, 0.98, 0.42), 0.25, 0.6, 0.3],
			["roof_steel", "stack/steel", 1.0, Color(1.1, 1.1, 1.08), 0.35, 0.7, 0.3],
			["stucco", "terrace/stucco", 4.0, Color.WHITE, 0.04, 0.25, 0.8],
			["tarp", "stack/steel", 2.0, Color(0.18, 0.36, 0.9), 0.08, 0.3, 0.7]]:
		d.surface(m[0], {"side": m[1], "meters": m[2], "tint": m[3], "gloss": m[4], "grazing": m[5], "roughness": m[6], "uv": true})
	# Things that glow.
	d.shaded("bulb", GLOW, {"color": BULB, "energy": 3.2})
	d.shaded("bulb_dead", GLOW, {"color": Color(0.25, 0.2, 0.15), "energy": 0.3})
	d.shaded("downlight", GLOW, {"color": WARM, "energy": 3.0})
	d.shaded("sconce", GLOW, {"color": WARM, "energy": 2.4})
	d.shaded("sign_white", GLOW, {"color": Color(1.0, 0.97, 0.9), "energy": 1.5})
	d.shaded("exit", GLOW, {"color": Color(0.2, 1.0, 0.45), "energy": 2.0})
	d.shaded("cage_lamp", GLOW, {"color": Color(0.55, 0.9, 1.0), "energy": 3.0})
	d.shaded("aviation", GLOW, {"color": Color(1.0, 0.1, 0.08), "energy": 3.0, "blink_period": 1.6})
	d.shaded("sodium", GLOW, {"color": Color(1.0, 0.55, 0.18), "energy": 2.6})
	d.shaded("marquee_a", GLOW, {"color": Color(1.0, 0.85, 0.5), "energy": 3.0, "blink_period": 0.6, "blink_duty": 0.5})
	d.shaded("marquee_b", GLOW, {"color": Color(1.0, 0.85, 0.5), "energy": 3.0, "blink_period": 0.6, "blink_duty": 0.5, "blink_offset": 0.5})
	d.shaded("ride_lamp", GLOW, {"color": Color(1.0, 0.3, 0.25), "energy": 2.5, "blink_period": 0.9, "blink_duty": 0.5})
	d.shaded("menu", LIGHTBOX, {"picture": "terrace/menu.png", "size": Vector2(4.0, 0.7), "energy": 1.1})
	d.shaded("directory", LIGHTBOX, {"picture": "terrace/directory.png", "size": Vector2(1.6, 1.2), "energy": 1.2})
	d.shaded("vending_drinks", LIGHTBOX, {"picture": "terrace/vending_drinks.png", "size": Vector2(1.0, 2.0), "energy": 1.25})
	d.shaded("vending_snacks", LIGHTBOX, {"picture": "terrace/vending_snacks.png", "size": Vector2(1.0, 2.0), "energy": 1.25})
	# Shops behind glass.
	var grime := "stack/caustics.png"
	var reflection := "terrace/reflection_eclipse.png"
	d.shaded("shop", SHOP, {"reflection_map": reflection, "grime": grime, "lit_share": 0.2, "bare_share": 0.35})
	d.shaded("shop_arcade", SHOP, {"reflection_map": reflection, "grime": grime, "lit_share": 1.0, "wall": Color(0.2, 0.16, 0.3),
			"lamp": Color(1.0, 0.45, 0.95), "depth": 6.0})
	d.shaded("shop_cinema", SHOP, {"reflection_map": reflection, "grime": grime, "lit_share": 1.0, "wall": Color(0.5, 0.2, 0.22),
			"lamp": Color(1.0, 0.8, 0.5), "depth": 8.0})
	d.shaded("kitchen", SHOP, {"reflection_map": reflection, "grime": grime, "pane_height": 1.2, "depth": 2.5,
			"lit_share": 0.0, "bare_share": 0.0, "wall": Color(0.6, 0.62, 0.64)})
	d.shaded("office", SHOP, {"reflection_map": reflection, "grime": grime, "pane_height": 1.4, "depth": 4.0,
			"lit_share": 0.0, "bare_share": 1.0, "wall": Color(0.5, 0.52, 0.55)})
	d.shaded("lobby", SHOP, {"reflection_map": reflection, "grime": grime, "pane_height": 3.0, "depth": 10.0,
			"lit_share": 0.0, "bare_share": 1.0, "wall": Color(0.62, 0.55, 0.5)})
	d.shaded("skylight", "res://src/render/deco/skylight_glass.gdshader", {"reflection_map": reflection, "grime": "terrace/grime.png",
			"pane": Vector2(RIB, _facet_length())})
	# The outside.
	d.shaded("far", "res://src/render/deco/far_surface.gdshader", {"albedo_texture": "terrace/far_mall.png", "meters_per_repeat": 12.0,
			"tint": Color(0.55, 0.45, 0.45)})
	d.shaded("far_garage", "res://src/render/deco/far_surface.gdshader", {"albedo_texture": "terrace/far_garage.png", "meters_per_repeat": 12.0})
	d.shaded("far_dark", "res://src/render/deco/far_surface.gdshader", {"albedo_texture": "stack/concrete.png", "tint": Color(0.05, 0.04, 0.07),
			"meters_per_repeat": 12.0})


# --- The gameplay blocks, dressed ------------------------------------------------------------

const DRESS := {
	"Ground": "court_floor", "Terrace": "cliff", "TerraceFloor": "upper_floor", "Peninsula": "cliff",
	"PeninsulaFloor": "upper_floor", "Pulpit": "info_desk", "PeninsulaCrateN": "vending_red",
	"PeninsulaCrateS": "vending_blue", "BlockACrate": "vending_blue", "Shed": "lemon_stall", "LowWallN": "planter",
	"LowWallS": "planter", "Corner": "stage", "BlockA": "stall_block", "BlockAFloor": "deck", "Overpass": "bridge",
	"BlockB": "restaurant", "BlockC": "restrooms", "Kiosk": "directory_body", "PocketWall": "planter",
	"Slide": "travelator", "Stairs": "escalator",
}


static func _surfaces(kit, d) -> void:
	for b: Node in kit.geometry.get_children():
		var n := String(b.name)
		var dress: String = "mall_wall" if n.begins_with("Boundary") else DRESS.get(n, "")
		if dress != "":
			b.set(&"surface", d.mat(dress))


## Under the skybridge the sky's light stops; downlights set in its
## underside light the square.
static func _under_the_bridge(kit, d) -> void:
	var zone := Node3D.new()
	zone.set_script(load("res://src/world/ambient_zone.gd"))
	zone.name = "UnderTheBridge"
	zone.position = Vector3(-4.5, 1.6, -8.5)
	zone.set(&"size", Vector3(13.2, 3.5, 3.2))
	zone.set(&"ambient", 0.45)
	kit.root.add_child(zone)
	var n := 0
	for x: float in [-8.5, -4.5, -0.5]:
		var at := Vector3(x, TOP - 0.51, -8.5)
		d.ball("downlight", at, Vector3(0.17, 0.02, 0.17), 2, 10, "Fixtures", BOTH)
		d.torus("chrome", at, 0.2, 0.025, Basis.IDENTITY, 12, 4, "Fixtures", BOTH)
		d.spot("Downlight_%d" % n, at + Vector3(0, -0.1, 0), Vector3.DOWN, WARM, 6.5, 2.4, 55.0, BOTH)
		n += 1
	# "FOOD COURT" along the bridge's side to the street.
	var b := DecoKit.facing(Vector3(0, 0, 1))
	d.words("FOOD COURT", Vector3(-4.5, TOP - 0.25, -6.985), b, 0.32, Color(0.9, 0.78, 0.5), 0.0, "Build", BOTH)
	# Brass along its edges.
	for z: float in [-10.0, -7.0]:
		d.tube("brass", Vector3(-11, TOP, z), Vector3(2, TOP, z), 0.03, 6, "Build", BOTH)


# --- Shopfronts --------------------------------------------------------------------------------

static func _shops(d) -> void:
	for s: Array in TOWN_SHOPS:
		_shop_from(d, s, 0.0)
	for s: Array in UPPER_SHOPS:
		_shop_from(d, s, TOP)
	# Lamps up the town's walls between the shops, washing the stucco.
	var n := 0
	for s: Array in [[Vector3(-24, 0, -11.5), Vector3(1, 0, 0)], [Vector3(-24, 0, -4.5), Vector3(1, 0, 0)],
			[Vector3(-24, 0, 4.5), Vector3(1, 0, 0)], [Vector3(-24, 0, 11.3), Vector3(1, 0, 0)],
			[Vector3(-17.5, 0, -18), Vector3(0, 0, 1)], [Vector3(-11.5, 0, -18), Vector3(0, 0, 1)],
			[Vector3(-17.5, 0, 18), Vector3(0, 0, -1)], [Vector3(-11.2, 0, 18), Vector3(0, 0, -1)]]:
		var wall: Vector3 = s[0]
		var normal: Vector3 = s[1]
		var b := DecoKit.facing(normal)
		var at := wall + normal * 0.12 + Vector3(0, 4.4, 0)
		d.box("cladding", at, Vector3(0.45, 0.3, 0.24), "Fixtures", BOTH, b)
		d.face("sconce", at + Vector3(0, 0.151, 0), b.x * 0.2, -normal * 0.1, "Fixtures", BOTH)
		d.omni("Sconce_%d" % n, at + normal * 0.3 + Vector3(0, 0.6, 0), WARM, 6.0, 0.8, BOTH, true)
		n += 1


static func _shop_from(d, s: Array, foot: float) -> void:
	var p: Vector2 = s[0]
	var name: String = s[3]
	_shopfront(d, Vector3(p.x, foot, p.y), s[1], s[2], name, s[4], s[5], s[6])
	if name == "SPACE AVAILABLE":
		_space_available(d, Vector3(p.x, foot, p.y), s[1])


## A shopfront against a wall: `at` the middle of its foot on the wall's
## face, `n` the way it faces, `width` across. Glass with a shop behind it,
## piers either side, a kickplate, a fascia with the name on it (in neon,
## or a lightbox), and a shutter `shutter` of the way down.
static func _shopfront(d, at: Vector3, n: Vector3, width: float, name: String, colour: Color, style: String, shutter: float, glass := "shop") -> void:
	var b := DecoKit.facing(n)
	var gw := width - 0.6
	for e: float in [-1.0, 1.0]:
		d.box("cladding", at + b.x * e * (width * 0.5 - 0.15) + n * 0.06 + Vector3(0, 1.85, 0), Vector3(0.3, 3.7, 0.12), "Build", BOTH, b)
	d.box("cladding", at + n * 0.07 + Vector3(0, 3.35, 0), Vector3(width, 0.7, 0.14), "Build", BOTH, b)
	d.box("dark_metal", at + n * 0.04 + Vector3(0, 0.17, 0), Vector3(gw, 0.34, 0.08), "Build", BOTH, b)
	d.face(glass, at + n * 0.012 + Vector3(0, 1.64, 0), b.x * gw * 0.5, Vector3(0, 1.3, 0), "Build", BOTH)
	var bays := maxi(1, roundi(gw / 1.5))
	for i in range(1, bays):
		d.box("dark_metal", at + b.x * (gw * (float(i) / bays - 0.5)) + n * 0.03 + Vector3(0, 1.64, 0), Vector3(0.05, 2.6, 0.05), "Build", BOTH, b)
	d.box("dark_metal", at + n * 0.03 + Vector3(0, 2.96, 0), Vector3(gw, 0.06, 0.05), "Build", BOTH, b)
	if shutter > 0.0:
		var sh := 2.6 * shutter
		d.box("shutter", at + n * 0.05 + Vector3(0, 2.94 - sh * 0.5, 0), Vector3(gw, sh, 0.03), "Build", BOTH, b)
		d.box("dark_metal", at + n * 0.065 + Vector3(0, 2.94 - sh, 0), Vector3(gw, 0.06, 0.05), "Build", BOTH, b)
	var sign_at := at + n * 0.142 + Vector3(0, 3.35, 0)
	if style == "neon":
		_neon(d, name, sign_at, b, 0.42, colour)
	elif style == "box":
		var w := minf(width - 0.8, name.length() * 0.24 + 0.6)
		d.face("sign_white", sign_at, b.x * w * 0.5, Vector3(0, 0.24, 0), "Fixtures", BOTH)
		d.words(name, sign_at + n * 0.005, b, 0.3, colour.darkened(0.7), 0.0, "Fixtures", BOTH)


## A lease board over an empty shop's glass.
static func _space_available(d, at: Vector3, n: Vector3) -> void:
	var b := DecoKit.facing(n)
	d.box("paper", at + n * 0.03 + Vector3(0, 1.7, 0), Vector3(2.6, 1.2, 0.02), "Build", BOTH, b)
	d.words("SPACE AVAILABLE", at + n * 0.045 + Vector3(0, 1.95, 0), b, 0.26, Color(0.1, 0.12, 0.3), 0.0, "Build", BOTH)
	d.words("LEASING  555-0199", at + n * 0.045 + Vector3(0, 1.55, 0), b, 0.14, Color(0.6, 0.1, 0.12), 0.0, "Build", BOTH)


## A name in neon: the letters, a haze round them, a lamp throwing their
## colour about. `lamp` 2 makes it one of the extra lamps.
static func _neon(d, text: String, at: Vector3, b: Basis, size: float, colour: Color, flicker := 0.0, lamp := 1) -> void:
	d.words(text, at + b.z * 0.012, b, size, colour.lightened(0.6), 0.0, "Fixtures", BOTH).shaded = false
	var width := size * 0.62 * text.length() + size * 1.4
	var halo := "halo_%s_%d_%d" % [colour.to_html(false), roundi(width * 10.0), roundi(flicker * 10.0)]
	d.shaded(halo, HALO, {"color": colour, "strength": 1.3, "size": Vector2(width, size * 2.4), "flicker": flicker})
	d.face(halo, at + b.z * 0.006, b.x * width * 0.5, Vector3(0, size * 1.2, 0), "Fixtures", BOTH)
	if lamp > 0:
		d.omni("Neon_" + text.validate_node_name().replace(" ", "_"), at + b.z * 0.9, colour, 6.5, 1.1, BOTH, lamp == 2)


## The mall's front doors at the street's end: four glass doors in a
## granite portal, chained, a card taped up.
static func _entrance(d) -> void:
	var n := Vector3(1, 0, 0)
	var b := DecoKit.facing(n)
	var at := Vector3(-24, 0, 0)
	d.box("cladding", at + n * 0.1 + Vector3(0, 3.6, 0), Vector3(7.0, 0.8, 0.2), "Build", BOTH, b)
	for e: float in [-1.0, 1.0]:
		d.box("cladding", at + b.x * e * 3.35 + n * 0.1 + Vector3(0, 1.6, 0), Vector3(0.3, 3.2, 0.2), "Build", BOTH, b)
	d.face("lobby", at + n * 0.012 + Vector3(0, 1.7, 0), b.x * 3.2, Vector3(0, 1.5, 0), "Build", BOTH)
	for x: float in [-1.6, 0.0, 1.6]:
		d.box("dark_metal", at + b.x * x + n * 0.04 + Vector3(0, 1.6, 0), Vector3(0.1, 3.2, 0.06), "Build", BOTH, b)
	d.box("dark_metal", at + n * 0.04 + Vector3(0, 2.55, 0), Vector3(6.4, 0.08, 0.06), "Build", BOTH, b)
	for i in 4:
		var x := -2.4 + i * 1.6
		d.tube("chrome", at + b.x * (x - 0.55) + n * 0.1 + Vector3(0, 1.05, 0), at + b.x * (x + 0.55) + n * 0.1 + Vector3(0, 1.05, 0), 0.025, 6, "Build", BOTH)
	# A chain through the middle doors' bars, a padlock hanging off it.
	for i in 6:
		var y := 1.05 - 0.08 * sin(PI * i / 5.0)
		d.torus("steel", at + b.x * (-0.5 + i * 0.2) + n * 0.13 + Vector3(0, y, 0), 0.06, 0.012, Basis(b.x, b.z, -b.y), 8, 3, "Detail", BOTH)
	d.box("brass", at + n * 0.14 + Vector3(0, 0.88, 0), Vector3(0.12, 0.15, 0.05), "Detail", BOTH, b)
	d.box("paper", at + b.x * 1.3 + n * 0.035 + Vector3(0, 1.55, 0), Vector3(0.6, 0.45, 0.005), "Detail", BOTH, b)
	d.words("CLOSED\nFOR THE\nECLIPSE", at + b.x * 1.3 + n * 0.04 + Vector3(0, 1.55, 0), b, 0.1, Color(0.1, 0.1, 0.12), 0.0, "Detail", BOTH)
	d.words("ENTRANCE", at + n * 0.205 + Vector3(0, 3.6, 0), b, 0.34, Color(0.85, 0.72, 0.45), 0.0, "Build", BOTH)


# --- The food court ----------------------------------------------------------------------------

## Block A: three food stalls round a kitchen, each a tiled counter, a
## service window with its shutter half down, a menu board and a name in
## neon. Round the back, the staff door.
static func _food_stalls(d) -> void:
	for s: Array in [[Vector3(-16, 0, -5), Vector3(0, 0, 1), 8.0, "BURGER MOON", Color(1.0, 0.6, 0.12), "tile_burger"],
			[Vector3(-12, 0, -8), Vector3(1, 0, 0), 6.0, "TACO COMET", Color(0.3, 1.0, 0.45), "tile_taco"],
			[Vector3(-16, 0, -11), Vector3(0, 0, -1), 8.0, "NOODLE ORBIT", Color(1.0, 0.25, 0.32), "tile_noodle"]]:
		_stall(d, s[0], s[1], s[2], s[3], s[4], s[5])
	var n := Vector3(-1, 0, 0)
	var b := DecoKit.facing(n)
	var at := Vector3(-20, 0, -5.8)
	d.box("door_blue", at + n * 0.03 + Vector3(0, 1.05, 0), Vector3(1.0, 2.1, 0.05), "Build", BOTH, b)
	d.words("STAFF ONLY", at + n * 0.06 + Vector3(0, 1.6, 0), b, 0.12, Color(0.9, 0.9, 0.9), 0.0, "Detail", BOTH)
	d.box("exit", at + n * 0.06 + Vector3(0, 2.35, 0), Vector3(0.5, 0.18, 0.06), "Fixtures", BOTH, b)


## A stall front: `at` the middle of its foot, `n` its facing.
static func _stall(d, at: Vector3, n: Vector3, width: float, name: String, colour: Color, tile: String) -> void:
	var b := DecoKit.facing(n)
	var w := width - 0.8
	d.box(tile, at + n * 0.08 + Vector3(0, 0.5, 0), Vector3(w, 1.0, 0.16), "Build", BOTH, b)
	d.box("steel", at + n * 0.12 + Vector3(0, 1.025, 0), Vector3(w + 0.1, 0.05, 0.26), "Build", BOTH, b)
	d.face("kitchen", at + n * 0.012 + Vector3(0, 1.65, 0), b.x * w * 0.5, Vector3(0, 0.6, 0), "Build", BOTH)
	d.box("shutter", at + n * 0.04 + Vector3(0, 2.05, 0), Vector3(w, 0.5, 0.03), "Build", BOTH, b)
	d.box("dark_metal", at + n * 0.055 + Vector3(0, 1.79, 0), Vector3(w, 0.05, 0.05), "Build", BOTH, b)
	d.box("dark_metal", at + n * 0.05 + Vector3(0, 2.72, 0), Vector3(4.2, 0.82, 0.1), "Build", BOTH, b)
	d.face("menu", at + n * 0.101 + Vector3(0, 2.72, 0), b.x * 2.0, Vector3(0, 0.35, 0), "Fixtures", BOTH)
	d.box("black", at + n * 0.06 + Vector3(0, 3.55, 0), Vector3(width, 0.7, 0.12), "Build", BOTH, b)
	_neon(d, name, at + n * 0.121 + Vector3(0, 3.55, 0), b, 0.46, colour)
	# A card on the counter: closed.
	d.box("paper", at + b.x * (w * 0.3) + n * 0.2 + Vector3(0, 1.17, 0), Vector3(0.36, 0.24, 0.01), "Detail", BOTH, b * Basis(Vector3.RIGHT, -0.25))


## Block B: a restaurant, two storeys. Big windows to the street, its name
## in cyan with a ringed planet, windows upstairs; a side door with an OPEN
## sign that's lying.
static func _restaurant(d) -> void:
	_shopfront(d, Vector3(-15.5, 0, 5), Vector3(0, 0, -1), 9.0, "", Color.WHITE, "", 0.25)
	var n := Vector3(0, 0, -1)
	var b := DecoKit.facing(n)
	var face := Vector3(-15.5, 0, 5)
	d.box("black", face + n * 0.06 + Vector3(-0.7, 4.55, 0), Vector3(7.2, 0.9, 0.12), "Build", BOTH, b)
	_neon(d, "SUSHI SATURN", face + n * 0.121 + Vector3(-0.7, 4.55, 0), b, 0.62, Color(0.25, 0.85, 1.0))
	# The planet: a glowing ball in a tilted ring.
	d.shaded("planet", GLOW, {"color": Color(1.0, 0.75, 0.35), "energy": 2.2})
	d.shaded("planet_ring", GLOW, {"color": Color(0.35, 0.9, 1.0), "energy": 2.6})
	var planet := face + n * 0.45 + b.x * 3.6 + Vector3(0, 4.6, 0)
	d.ball("planet", planet, Vector3(0.38, 0.38, 0.38), 5, 10, "Fixtures", BOTH)
	d.torus("planet_ring", planet, 0.62, 0.035, Basis(b.z, 0.35) * Basis(b.x, 0.25) * Basis(b.x, b.z, -b.y).orthonormalized(), 18, 4, "Fixtures", BOTH)
	for i in 3:
		var x := -3.0 + i * 3.0
		d.face("office", face + n * 0.012 + b.x * x + Vector3(0, 6.1, 0), b.x * 1.1, Vector3(0, 0.7, 0), "Build", BOTH)
		d.box("cladding", face + n * 0.05 + b.x * x + Vector3(0, 5.36, 0), Vector3(2.4, 0.08, 0.1), "Build", BOTH, b)
	# The side door, onto the gap by the restrooms.
	var sn := Vector3(1, 0, 0)
	var sb := DecoKit.facing(sn)
	var side := Vector3(-11, 0, 8)
	d.box("door_blue", side + sn * 0.03 + Vector3(0, 1.05, 0), Vector3(1.1, 2.1, 0.05), "Build", BOTH, sb)
	d.box("black", side + sn * 0.05 + sb.x * -1.4 + Vector3(0, 1.9, 0), Vector3(0.9, 0.36, 0.04), "Build", BOTH, sb)
	_neon(d, "OPEN", side + sn * 0.075 + sb.x * -1.4 + Vector3(0, 1.9, 0), sb, 0.24, Color(1.0, 0.2, 0.2), 0.8, 2)


## Block C: the restrooms, tiled all over (the ride tiles). Everything on
## it is flush, so it rides as before: a sign to the street, the doors in
## the gap by the restaurant, a caged lamp in the alley.
static func _restrooms(d) -> void:
	var n := Vector3(0, 0, -1)
	var b := DecoKit.facing(n)
	var at := Vector3(-4.25, 3.6, 5) + n * 0.015
	d.face("sign_white", at, b.x * 1.3, Vector3(0, 0.24, 0), "Fixtures", BOTH)
	d.words("RESTROOMS  →", at + n * 0.005, b, 0.3, Color(0.1, 0.18, 0.35), 0.0, "Fixtures", BOTH)
	var wn := Vector3(-1, 0, 0)
	var wb := DecoKit.facing(wn)
	for door: Array in [[6.8, "MEN"], [9.2, "WOMEN"]]:
		var dc := Vector3(-8, 0, door[0]) + wn * 0.015
		d.face("door_blue", dc + Vector3(0, 1.05, 0), wb.x * 0.5, Vector3(0, 1.05, 0), "Build", BOTH)
		d.words(door[1], dc + wn * 0.005 + Vector3(0, 1.7, 0), wb, 0.16, Color(0.95, 0.95, 0.95), 0.0, "Build", BOTH)
	# The alley's lamp: a bulkhead in a cage, lighting the way up.
	var en := Vector3(1, 0, 0)
	var lamp := Vector3(-0.5, 3.3, 8.0) + en * 0.08
	d.ball("cage_lamp", lamp, Vector3(0.08, 0.13, 0.08), 3, 8, "Fixtures", BOTH)
	for dz: float in [-0.1, 0.1]:
		d.box("dark_metal", lamp + Vector3(0, 0, dz), Vector3(0.14, 0.3, 0.015), "Fixtures", BOTH)
	d.omni("AlleyLamp", lamp + en * 0.5, Color(0.55, 0.9, 1.0), 8.0, 1.2, BOTH)
	d.face("sign_white", Vector3(-0.5, 2.4, 6.2) + en * 0.015, DecoKit.facing(en).x * 0.4, Vector3(0, 0.1, 0), "Fixtures", BOTH)
	d.words("STAFF ONLY", Vector3(-0.5, 2.4, 6.2) + en * 0.02, DecoKit.facing(en), 0.12, Color(0.6, 0.1, 0.1), 0.0, "Fixtures", BOTH)


## The Kiosk is the mall's directory: the map on each face, lit, with a red
## dot where you're standing; a glowing cap.
static func _directory(d) -> void:
	for f: Array in [[Vector3(-9, 0, 1), Vector3(-1, 0, 0)], [Vector3(-7, 0, 1), Vector3(1, 0, 0)],
			[Vector3(-8, 0, 0), Vector3(0, 0, -1)], [Vector3(-8, 0, 2), Vector3(0, 0, 1)]]:
		var n: Vector3 = f[1]
		var b := DecoKit.facing(n)
		var at: Vector3 = f[0]
		d.box("dark_metal", at + n * 0.015 + Vector3(0, 1.5, 0), Vector3(1.72, 1.32, 0.03), "Build", BOTH, b)
		d.face("directory", at + n * 0.032 + Vector3(0, 1.5, 0), b.x * 0.8, Vector3(0, 0.6, 0), "Fixtures", BOTH)
		d.words("DIRECTORY", at + n * 0.02 + Vector3(0, 2.3, 0), b, 0.18, Color(0.95, 0.9, 0.8), 0.0, "Fixtures", BOTH).shaded = false
		d.words("● YOU ARE HERE", at + n * 0.02 + Vector3(0, 0.7, 0), b, 0.11, Color(1.0, 0.3, 0.3), 0.0, "Fixtures", BOTH).shaded = false
	d.box("sign_white", Vector3(-8, 2.47, 1), Vector3(2.02, 0.06, 2.02), "Fixtures", BOTH)
	d.omni("Directory", Vector3(-8, 3.1, 1), Color(0.95, 0.92, 1.0), 5.0, 0.8, BOTH, true)


## The crates are vending machines, two back to back: drinks by the square
## and by Block A, snacks at the alley's mouth. Each lights what's in front.
static func _vending(d) -> void:
	var n := 0
	for v: Array in [[Vector3(-2, 0, -5), Vector3(0, 0, -1), "vending_drinks", Color(1.0, 0.85, 0.85)],
			[Vector3(0.75, 0, 5), Vector3(0, 0, 1), "vending_snacks", Color(0.85, 0.9, 1.0)],
			[Vector3(-21, 0, -9), Vector3(0, 0, -1), "vending_snacks", Color(0.85, 0.9, 1.0)]]:
		var at: Vector3 = v[0]
		var normal: Vector3 = v[1]
		var b := DecoKit.facing(normal)
		for e: float in [-0.5, 0.5]:
			d.face(v[2], at + b.x * e + normal * 0.012 + Vector3(0, 1.0, 0), b.x * 0.5, Vector3(0, 1.0, 0), "Fixtures", BOTH)
		d.omni("Vending_%d" % n, at + normal * 0.9 + Vector3(0, 1.3, 0), v[3], 4.5, 0.9, BOTH, true)
		n += 1


## The Stairs are an escalator and the Slide a travelator, both stopped: a
## rubber handrail on posts along the wall side, a low kick rail along the
## open side, comb plates at each end, signs.
static func _escalators(d) -> void:
	for e: Array in [[Vector3(-4.93, 0, -16.5), Vector3(2, TOP, -16.5), -1.0], [Vector3(-9, 0, 16.5), Vector3(2, TOP, 16.5), 1.0]]:
		var bottom: Vector3 = e[0]
		var top: Vector3 = e[1]
		var wall: float = e[2]
		var rail_z := bottom.z + wall * 1.25
		var open_z := bottom.z - wall * 1.44
		var up := Vector3(0, 0.95, 0)
		var a := Vector3(bottom.x, 0, rail_z)
		var b := Vector3(top.x, TOP, rail_z)
		d.tube("rubber", a + up + Vector3(-0.8, 0, 0), a + up, 0.045, 6, "Build", BOTH)
		d.tube("rubber", a + up, b + up, 0.045, 6, "Build", BOTH)
		d.tube("rubber", b + up, b + up + Vector3(0.8, 0, 0), 0.045, 6, "Build", BOTH)
		var posts := int(a.distance_to(b) / 1.4)
		for i in posts + 1:
			var p := a.lerp(b, float(i) / posts)
			d.tube("chrome", p, p + up, 0.022, 6, "Build", BOTH)
		for p: Vector3 in [a + Vector3(-0.8, 0, 0), b + Vector3(0.8, 0, 0)]:
			d.tube("chrome", p, p + up, 0.022, 6, "Build", BOTH)
		d.tube("chrome", Vector3(bottom.x, 0.05, open_z), Vector3(top.x, TOP + 0.05, open_z), 0.035, 6, "Build", BOTH)
		for end: Array in [[Vector3(bottom.x - 0.35, 0.006, bottom.z), -1.0], [Vector3(top.x + 0.35, TOP + 0.006, top.z), 1.0]]:
			var c: Vector3 = end[0]
			d.box("steel", c, Vector3(0.7, 0.012, 3.0), "Build", BOTH)
			d.box("yellow_line", c + Vector3(-0.3 * end[1], 0.004, 0), Vector3(0.06, 0.012, 3.0), "Build", BOTH)
	# Signs on the walls over them.
	for s: Array in [["UPPER LEVEL  ↑", Vector3(-1.5, 4.6, -18), Vector3(0, 0, 1)], ["FOOD COURT  ↓", Vector3(-3.5, 4.6, 18), Vector3(0, 0, -1)]]:
		var n: Vector3 = s[2]
		var b := DecoKit.facing(n)
		d.box("dark_metal", s[1] + n * 0.04, Vector3(2.5, 0.55, 0.08), "Fixtures", BOTH, b)
		d.face("sign_white", s[1] + n * 0.081, b.x * 1.18, Vector3(0, 0.22, 0), "Fixtures", BOTH)
		d.words(s[0], s[1] + n * 0.086, b, 0.28, Color(0.1, 0.12, 0.2), 0.0, "Fixtures", BOTH)


## The Pulpit is the information desk: its name in brass on the faces to
## the street and the upper level, an "i" in a ring, a brass band round
## the top.
static func _information(d) -> void:
	for f: Array in [[Vector3(-4, TOP, 0), Vector3(-1, 0, 0), 4.0], [Vector3(-1, TOP, 0), Vector3(1, 0, 0), 4.0]]:
		var at: Vector3 = f[0]
		var n: Vector3 = f[1]
		var b := DecoKit.facing(n)
		d.words("INFORMATION", at + n * 0.015 + Vector3(0, 1.25, 0), b, 0.34, Color(1.0, 0.8, 0.45), 0.0, "Build", BOTH)
		d.torus("brass", at + n * 0.03 + Vector3(0, 0.6, 0), 0.24, 0.025, Basis(b.x, b.z, -b.y), 16, 4, "Build", BOTH)
		d.words("i", at + n * 0.02 + Vector3(0, 0.6, 0), b, 0.34, Color(1.0, 0.8, 0.45), 0.0, "Build", BOTH)
	for r: Array in [[Vector3(-4, 5.9, -2), Vector3(-1, 5.9, -2)], [Vector3(-4, 5.9, 2), Vector3(-1, 5.9, 2)],
			[Vector3(-4, 5.9, -2), Vector3(-4, 5.9, 2)], [Vector3(-1, 5.9, -2), Vector3(-1, 5.9, 2)]]:
		d.tube("brass", r[0], r[1], 0.025, 6, "Build", BOTH)


## Brass nosing along every edge you can drop off up top, and a yellow line
## painted back from it.
static func _edges(d) -> void:
	for r: Array in [[Vector3(2, TOP, -15), Vector3(2, TOP, -3), Vector3(1, 0, 0)], [Vector3(2, TOP, 3), Vector3(2, TOP, 15), Vector3(1, 0, 0)],
			[Vector3(-4, TOP, -3), Vector3(2, TOP, -3), Vector3(0, 0, 1)], [Vector3(-4, TOP, 3), Vector3(2, TOP, 3), Vector3(0, 0, -1)]]:
		var a: Vector3 = r[0]
		var b: Vector3 = r[1]
		var inward: Vector3 = r[2]
		d.tube("brass", a, b, 0.03, 6, "Build", BOTH)
		var length := a.distance_to(b)
		var along := (b - a) / length
		var size := Vector3(absf(along.x) * length + absf(inward.x) * 0.1, 0.008, absf(along.z) * length + absf(inward.z) * 0.1)
		d.box("yellow_line", (a + b) * 0.5 + inward * 0.35 + Vector3(0, 0.004, 0), size, "Build", BOTH)
	for r: Array in [[Vector3(-20, TOP, -11), Vector3(-12, TOP, -11)], [Vector3(-20, TOP, -5), Vector3(-12, TOP, -5)],
			[Vector3(-20, TOP, -11), Vector3(-20, TOP, -5)], [Vector3(-12, TOP, -11), Vector3(-12, TOP, -5)]]:
		d.tube("brass", r[0], r[1], 0.03, 6, "Build", BOTH)


# --- The upper level -----------------------------------------------------------------------------

## The lemonade stand (the Shed) serving the information desk across the
## gap; planters (the low walls) with clipped shrubs.
static func _upper_level(d) -> void:
	var n := Vector3(-1, 0, 0)
	var b := DecoKit.facing(n)
	var at := Vector3(10, TOP, 0)
	d.box("tile_lemon", at + n * 0.08 + Vector3(0, 0.5, 0), Vector3(5.2, 1.0, 0.16), "Build", BOTH, b)
	d.box("steel", at + n * 0.12 + Vector3(0, 1.025, 0), Vector3(5.3, 0.05, 0.26), "Build", BOTH, b)
	d.face("kitchen", at + n * 0.012 + Vector3(0, 1.65, 0), b.x * 2.6, Vector3(0, 0.6, 0), "Build", BOTH)
	d.box("dark_metal", at + n * 0.03 + Vector3(0, 2.28, 0), Vector3(5.2, 0.06, 0.05), "Build", BOTH, b)
	d.box("black", at + n * 0.06 + Vector3(0, 2.66, 0), Vector3(5.6, 0.6, 0.12), "Build", BOTH, b)
	_neon(d, "LEMONADE", at + n * 0.121 + Vector3(0, 2.66, 0), b, 0.4, Color(1.0, 0.9, 0.2))
	for s: Array in [[Vector3(12, TOP, -3), Vector3(0, 0, -1)], [Vector3(12, TOP, 3), Vector3(0, 0, 1)], [Vector3(14, TOP, 0), Vector3(1, 0, 0)]]:
		var sn: Vector3 = s[1]
		var sb := DecoKit.facing(sn)
		var width := 3.4 if absf(sn.z) > 0.5 else 5.4
		d.box("shutter", (s[0] as Vector3) + sn * 0.03 + Vector3(0, 1.3, 0), Vector3(width, 2.2, 0.03), "Build", BOTH, sb)
		d.box("dark_metal", (s[0] as Vector3) + sn * 0.05 + Vector3(0, 2.44, 0), Vector3(width + 0.1, 0.1, 0.08), "Build", BOTH, sb)
	# Shrubs in the planters.
	for c: Vector2 in [Vector2(5.3, -6.0), Vector2(5.3, -5.0), Vector2(5.3, -4.0), Vector2(5.3, 4.0), Vector2(5.3, 5.0), Vector2(5.3, 6.0)]:
		d.ball("foliage", Vector3(c.x, TOP + 1.3, c.y), Vector3(0.32, 0.22, 0.4), 3, 8, "Detail", BOTH)
	for c: Vector2 in [Vector2(-16.0, -2.5), Vector2(-15.0, -2.5), Vector2(-14.0, -2.5)]:
		d.ball("foliage", Vector3(c.x, 1.3, c.y), Vector3(0.4, 0.2, 0.28), 3, 8, "Detail", BOTH)


## The arcade on the south wall (lit, its name in pink) and the cinema on
## the east (a marquee with chasing bulbs over lit doors).
static func _arcade_and_cinema(d) -> void:
	var n := Vector3(0, 0, -1)
	var b := DecoKit.facing(n)
	var at := Vector3(12.5, TOP, 18)
	_shopfront(d, at, n, 7.0, "", Color.WHITE, "", 0.0, "shop_arcade")
	_neon(d, "ARCADE", at + n * 0.142 + Vector3(0, 3.35, 0), b, 0.5, Color(1.0, 0.3, 0.8), 0.0, 1)
	d.omni("Arcade", at + n * 1.6 + Vector3(0, 1.6, 0), Color(0.8, 0.4, 1.0), 7.0, 1.2, BOTH)
	var cn := Vector3(-1, 0, 0)
	var cb := DecoKit.facing(cn)
	var cat := Vector3(24, TOP, -2)
	_shopfront(d, cat, cn, 6.0, "", Color.WHITE, "", 0.0, "shop_cinema")
	# The marquee: a lit box over the doors, bulbs round its edge.
	var m := cat + cn * 0.35 + Vector3(0, 3.35, 0)
	d.box("black", m, Vector3(6.4, 0.9, 0.5), "Build", BOTH, cb)
	d.face("sign_white", m + cn * 0.251, cb.x * 2.8, Vector3(0, 0.3, 0), "Fixtures", BOTH)
	d.words("TOTAL ECLIPSE  ·  12:00", m + cn * 0.256, cb, 0.26, Color(0.1, 0.1, 0.12), 0.0, "Fixtures", BOTH)
	var k := 0
	for i in 17:
		var x := -3.1 + i * 6.2 / 16.0
		for y: float in [-0.42, 0.42]:
			d.ball("marquee_a" if k % 2 == 0 else "marquee_b", m + cn * 0.26 + cb.x * x + Vector3(0, y, 0), Vector3(0.04, 0.04, 0.04), 2, 6, "Fixtures", BOTH)
			k += 1
	d.box("black", cat + cn * 0.06 + Vector3(0, 4.35, 0), Vector3(4.0, 0.8, 0.1), "Build", BOTH, cb)
	_neon(d, "CINEMA", cat + cn * 0.12 + Vector3(0, 4.35, 0), cb, 0.56, Color(1.0, 0.2, 0.15))


## The corner is a stage for the eclipse party: a banner, speakers, a mic
## on its stand, two lamps on a truss across the corner.
static func _stage(d) -> void:
	var top := TOP + 1.5
	var nb := DecoKit.facing(Vector3(0, 0, 1))
	d.face("banner", Vector3(21, 7.5, -17.985), nb.x * 2.7, Vector3(0, 1.1, 0), "Build", BOTH)
	d.words("ECLIPSE WATCH PARTY", Vector3(21, 7.95, -17.975), nb, 0.42, Color(1.0, 0.85, 0.3), 0.0, "Build", BOTH)
	d.words("TODAY  ·  12:00  ·  FREE GLASSES", Vector3(21, 7.15, -17.975), nb, 0.22, Color(0.95, 0.95, 1.0), 0.0, "Build", BOTH)
	var eb := DecoKit.facing(Vector3(-1, 0, 0))
	d.face("banner", Vector3(23.985, 7.5, -15.5), eb.x * 2.2, Vector3(0, 1.1, 0), "Build", BOTH)
	d.shaded("banner_ring", GLOW, {"color": Color(1.0, 0.9, 0.7), "energy": 1.6})
	var sun := Vector3(23.97, 7.5, -15.5)
	d.ball("black", sun, Vector3(0.005, 0.55, 0.55), 2, 16, "Build", BOTH)
	d.torus("banner_ring", sun, 0.6, 0.04, Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)), 20, 4, "Build", BOTH)
	# Speakers in the back corners.
	for s: Vector3 in [Vector3(18.45, top + 0.55, -17.6), Vector3(23.6, top + 0.55, -13.45)]:
		d.solid(s, Vector3(0.8, 1.1, 0.7))
		d.box("black", s, Vector3(0.8, 1.1, 0.7), "Solid", BOTH)
		for y: float in [-0.25, 0.25]:
			var face := s + (Vector3(0, 0, 0.36) if s.x < 20.0 else Vector3(-0.41, 0, 0))
			d.ball("dark_metal", face + Vector3(0, y, 0), Vector3(0.2, 0.2, 0.2) * (Vector3(1, 1, 0.1) if s.x < 20.0 else Vector3(0.1, 1, 1)), 2, 10, "Detail", BOTH)
	# The mic.
	var mic := Vector3(20.3, top, -13.8)
	d.tube("black", mic, mic + Vector3(0, 1.5, 0), 0.015, 4, "Detail", BOTH)
	d.tube("black", mic + Vector3(0, 1.45, 0), mic + Vector3(0.15, 1.6, 0.2), 0.012, 4, "Detail", BOTH)
	d.ball("steel", mic + Vector3(0.17, 1.62, 0.23), Vector3(0.04, 0.05, 0.04), 3, 6, "Detail", BOTH)
	# The truss, wall to wall across the corner, and its two lamps.
	var ta := Vector3(17.6, 8.8, -17.95)
	var tb := Vector3(23.95, 8.8, -11.6)
	for y: float in [0.0, -0.3]:
		d.tube("dark_metal", ta + Vector3(0, y, 0), tb + Vector3(0, y, 0), 0.03, 6, "Fixtures", BOTH)
	for i in 13:
		var p := ta.lerp(tb, i / 12.0)
		d.tube("dark_metal", p, p + Vector3(0, -0.3, 0), 0.015, 4, "Fixtures", BOTH)
	var aim := Vector3(21.0, top, -15.5)
	d.shaded("par_pink", GLOW, {"color": Color(1.0, 0.4, 0.75), "energy": 3.0})
	d.shaded("par_cyan", GLOW, {"color": Color(0.4, 0.85, 1.0), "energy": 3.0})
	for l: Array in [[0.3, "par_pink", Color(1.0, 0.35, 0.7)], [0.7, "par_cyan", Color(0.35, 0.8, 1.0)]]:
		var at: Vector3 = ta.lerp(tb, l[0]) + Vector3(0, -0.5, 0)
		var dir := (aim - at).normalized()
		d.tube("black", at - dir * 0.2, at + dir * 0.1, 0.12, 8, "Fixtures", BOTH)
		d.ball(l[1], at + dir * 0.11, Vector3(0.1, 0.1, 0.1), 3, 8, "Fixtures", BOTH)
		d.spot("Stage_" + l[1], at + dir * 0.2, dir, l[2], 9.0, 3.0, 24.0, BOTH)


## Round the food court: tables with the chairs up on them, bins, a rocket
## ride, the eclipse set in the floor, cardboard eclipse glasses dropped
## everywhere.
static func _court(d) -> void:
	for t: Vector2 in [Vector2(-17.5, -16.9), Vector2(-15.0, -16.9), Vector2(-12.5, -16.9), Vector2(-18.4, 16.9), Vector2(-16.0, 16.9)]:
		_table(d, Vector3(t.x, 0, t.y))
	for bin: Vector3 in [Vector3(-10.6, 0, -17.35), Vector3(-10.6, 0, 17.35), Vector3(-23.35, 0, -5.4)]:
		d.solid(bin + Vector3(0, 0.475, 0), Vector3(0.5, 0.95, 0.5))
		d.box("bin", bin + Vector3(0, 0.45, 0), Vector3(0.5, 0.9, 0.5), "Solid", BOTH)
		d.box("dark_metal", bin + Vector3(0, 0.93, 0), Vector3(0.54, 0.06, 0.54), "Solid", BOTH)
	# The rocket ride: a coin-op rocket on a base, its lamps blinking.
	var r := Vector3(-12.3, 0, 17.25)
	d.solid(r + Vector3(0, 0.85, 0), Vector3(0.9, 1.7, 1.1))
	d.box("white", r + Vector3(0, 0.12, 0), Vector3(0.9, 0.24, 1.1), "Solid", BOTH)
	d.tube("red", r + Vector3(0, 0.3, 0), r + Vector3(0, 1.35, 0), 0.3, 10, "Solid", BOTH)
	d.ball("white", r + Vector3(0, 1.35, 0), Vector3(0.3, 0.38, 0.3), 4, 10, "Solid", BOTH)
	for a: float in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
		var out := Vector3(cos(a), 0, sin(a))
		d.box("white", r + out * 0.38 + Vector3(0, 0.45, 0), Vector3(0.22, 0.4, 0.05), "Solid", BOTH, Basis(Vector3.UP, -a))
		d.ball("ride_lamp", r + out * 0.3 + Vector3(0, 1.0, 0), Vector3(0.05, 0.05, 0.05), 2, 6, "Fixtures", BOTH)
	d.words("RIDE 50¢", r + Vector3(0, 0.13, -0.56), DecoKit.facing(Vector3(0, 0, -1)), 0.12, Color(0.8, 0.1, 0.1), 0.0, "Detail", BOTH)
	d.omni("RocketRide", r + Vector3(0, 1.6, -0.8), Color(1.0, 0.4, 0.35), 4.0, 0.7, BOTH, true)
	# The eclipse set in the floor: a brass sun, a dark stone moon nearly
	# over it, rays of brass round them.
	var c := Vector3(-16, 0, 1.2)
	d.ball("brass", c, Vector3(1.25, 0.003, 1.25), 2, 24, "Build", BOTH)
	d.ball("black_stone", c + Vector3(-0.22, 0, 0.14), Vector3(1.16, 0.005, 1.16), 2, 24, "Build", BOTH)
	d.torus("brass", c, 1.3, 0.035, Basis.IDENTITY, 28, 4, "Build", BOTH)
	for i in 24:
		var a := TAU * i / 24.0
		var out := Vector3(cos(a), 0, sin(a))
		var length := 0.9 if i % 2 == 0 else 0.5
		d.box("brass", c + out * (1.45 + length * 0.5) + Vector3(0, 0.003, 0), Vector3(length, 0.006, 0.05), "Build", BOTH, Basis(Vector3.UP, -a))
	# Eclipse glasses, dropped.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1204
	for p: Vector3 in [Vector3(-13.5, 0, 2.5), Vector3(-6.2, 0, -2.4), Vector3(-19.5, 0, -1.5), Vector3(-10.5, 0, 12.8),
			Vector3(-17.2, 0, -13.6), Vector3(-4.8, 0, 13.5), Vector3(0.8, TOP, 1.0), Vector3(7.5, TOP, -9.0),
			Vector3(16.5, TOP, 6.5), Vector3(20.2, TOP + 1.5, -15.0), Vector3(21.8, TOP + 1.5, -16.2), Vector3(9.0, TOP, 12.0),
			Vector3(-15.8, TOP, -7.6), Vector3(3.8, TOP, 0.8)]:
		var b := Basis(Vector3.UP, rng.randf() * TAU)
		d.box("cardboard", p + Vector3(0, 0.004, 0), Vector3(0.16, 0.006, 0.06), "Detail", BOTH, b)
		for e: float in [-0.04, 0.04]:
			d.box("black", p + b * Vector3(e, 0.008, 0.002), Vector3(0.05, 0.004, 0.035), "Detail", BOTH, b)


## A café table, the chairs upside down on top, solid.
static func _table(d, at: Vector3) -> void:
	d.solid(at + Vector3(0, 0.62, 0), Vector3(0.8, 1.24, 0.8))
	d.tube("dark_metal", at, at + Vector3(0, 0.72, 0), 0.04, 6, "Solid", BOTH)
	d.box("dark_metal", at + Vector3(0, 0.02, 0), Vector3(0.5, 0.04, 0.5), "Solid", BOTH)
	d.tube("wood", at + Vector3(0, 0.72, 0), at + Vector3(0, 0.76, 0), 0.4, 10, "Solid", BOTH)
	for s: float in [-1.0, 1.0]:
		var seat := at + Vector3(s * 0.17, 0.8, 0)
		var b := Basis(Vector3.UP, 0.2 * s)
		d.box("wood", seat, Vector3(0.3, 0.04, 0.36), "Solid", BOTH, b)
		for lx: float in [-0.12, 0.12]:
			for lz: float in [-0.15, 0.15]:
				var foot := seat + b * Vector3(lx, 0.02, lz)
				d.tube("dark_metal", foot, foot + Vector3(0, 0.42, 0), 0.012, 4, "Detail", BOTH)


## Fake palms in planters, either side of the front doors and on the upper
## level by the cinema.
static func _palms(d) -> void:
	for p: Vector3 in [Vector3(-23.3, 0, -4.4), Vector3(-23.3, 0, 4.4), Vector3(23.3, TOP, 1.8)]:
		d.solid(p + Vector3(0, 0.45, 0), Vector3(1.2, 0.9, 1.2))
		d.box("cladding", p + Vector3(0, 0.45, 0), Vector3(1.2, 0.9, 1.2), "Solid", BOTH)
		d.box("foliage", p + Vector3(0, 0.905, 0), Vector3(1.1, 0.01, 1.1), "Solid", BOTH)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(p)
		var lean := Vector3(-signf(p.x) * 0.25, 0, rng.randf_range(-0.2, 0.2))
		var base := p + Vector3(0, 0.9, 0)
		var prev := base
		for i in range(1, 7):
			var t := i / 6.0
			var q := base + Vector3(0, t * 4.4, 0) + lean * t * t * 4.0
			d.tube("trunk", prev, q, lerpf(0.16, 0.1, t), 6, "Solid", BOTH)
			prev = q
		for k in 9:
			var a := TAU * k / 9.0 + rng.randf() * 0.3
			var out := Vector3(cos(a), 0, sin(a))
			var mid := prev + out * 1.0 + Vector3(0, 0.15, 0)
			var tip := prev + out * 2.1 + Vector3(0, -0.8 + rng.randf() * 0.3, 0)
			var side := out.cross(Vector3.UP) * 0.28
			for half: Array in [[prev, mid], [mid, tip]]:
				var h0: Vector3 = half[0]
				var h1: Vector3 = half[1]
				var c := (h0 + h1) * 0.5
				var v := (h1 - h0) * 0.5
				d.face("foliage", c, side, v, "Solid", BOTH)
				d.face("foliage", c, -side, v, "Solid", BOTH)


# --- The skylight ---------------------------------------------------------------------------------

## The vault's height over `z` (a flat arc, springing from RING at the side
## walls).
static func _vault(z: float) -> float:
	var r := (HALF_SPAN * HALF_SPAN + RISE * RISE) / (2.0 * RISE)
	return RING + RISE - r + sqrt(r * r - z * z)


static func _facet_z(j: int) -> float:
	return -HALF_SPAN + 2.0 * HALF_SPAN * j / FACETS


static func _facet_length() -> float:
	return Vector2(_facet_z(1) - _facet_z(0), _vault(_facet_z(1)) - _vault(_facet_z(0))).length()


## A straight steel member from `a` to `b`, `w` wide, `h` deep toward `up`,
## its top face on the line.
static func _beam(d, material: String, a: Vector3, b: Vector3, w: float, h: float, up: Vector3, shadows := true) -> void:
	var along := (b - a).normalized()
	var side := along.cross(up).normalized()
	var top := side.cross(along)
	d.box(material, (a + b) * 0.5 - top * h * 0.5, Vector3(w, h, a.distance_to(b)), "Build", BOTH, Basis(side, top, -along), shadows)


## The walls go on up past their tops as a clerestory (piers, glass
## between, a ring beam); on that, the glass vault: white ribs over the
## piers, purlins along, flat panes between, glass lunettes filling the
## ends. All of it far out of reach.
static func _skylight(d) -> void:
	# The clerestory, round all four walls.
	for w: Array in [[Vector3(0, 0, -18.5), Vector3(1, 0, 0), 24.0], [Vector3(0, 0, 18.5), Vector3(1, 0, 0), 24.0],
			[Vector3(-24.5, 0, 0), Vector3(0, 0, 1), 18.0], [Vector3(24.5, 0, 0), Vector3(0, 0, 1), 18.0]]:
		var mid: Vector3 = w[0]
		var along: Vector3 = w[1]
		var half: float = w[2]
		var b := Basis(along, Vector3.UP, along.cross(Vector3.UP))
		d.box("stucco", mid + Vector3(0, WALL_TOP + 0.25, 0), Vector3(half * 2.0 + 1.0, 0.5, 1.0), "Build", BOTH, b, true)
		d.box("roof_steel", mid + Vector3(0, RING - 0.3, 0), Vector3(half * 2.0 + 1.0, 0.6, 1.0), "Build", BOTH, b, true)
		var piers := int(half * 2.0 / RIB)
		for i in piers + 1:
			var at := mid + along * (-half + i * RIB)
			d.box("stucco", at + Vector3(0, (WALL_TOP + 0.5 + RING - 0.6) * 0.5, 0), Vector3(0.6, RING - 0.6 - WALL_TOP - 0.5, 1.0), "Build", BOTH, b, true)
			if i < piers:
				var c := at + along * RIB * 0.5 + Vector3(0, (WALL_TOP + 0.5 + RING - 0.6) * 0.5, 0)
				d.face("skylight", c, along * (RIB * 0.5 - 0.3), Vector3(0, (RING - 0.6 - WALL_TOP - 0.5) * 0.5, 0), "Build", BOTH)
				d.box("roof_steel", c, Vector3(RIB - 0.6, 0.08, 0.12), "Build", BOTH, b)
	# The ribs, their ends on the piers.
	var ribs := int(48.0 / RIB)
	for k in ribs + 1:
		var x := -24.0 + k * RIB
		for j in FACETS:
			var a := Vector3(x, _vault(_facet_z(j)), _facet_z(j))
			var c := Vector3(x, _vault(_facet_z(j + 1)), _facet_z(j + 1))
			_beam(d, "roof_steel", a, c, 0.22, 0.45, Vector3.UP)
	# Purlins along the joints between facets.
	var centre := RING + RISE - (HALF_SPAN * HALF_SPAN + RISE * RISE) / (2.0 * RISE)
	for j in range(1, FACETS):
		var z := _facet_z(j)
		var y := _vault(z)
		var out := Vector3(0, y - centre, z).normalized()
		_beam(d, "roof_steel", Vector3(-24, y, z), Vector3(24, y, z), 0.12, 0.2, out)
	# The glass, a pane to each facet of each bay, some gone, two tarped.
	for k in ribs:
		var x0 := -24.0 + k * RIB
		for j in FACETS:
			var a := Vector3(0, _vault(_facet_z(j)), _facet_z(j))
			var c := Vector3(0, _vault(_facet_z(j + 1)), _facet_z(j + 1))
			var mid := (a + c) * 0.5 + Vector3(x0 + RIB * 0.5, 0, 0)
			var bay := Vector2i(k, j)
			if bay in MISSING:
				continue
			d.face("skylight", mid, Vector3(RIB * 0.5, 0, 0), (c - a) * 0.5, "Build", BOTH)
			if bay in TARPS:
				var inward := -Vector3(0, mid.y - centre, mid.z).normalized()
				d.face("tarp", mid + inward * 0.15, Vector3(RIB * 0.46, 0, 0), (c - a) * 0.46, "Build", BOTH)
				d.face("tarp", mid + inward * 0.15, Vector3(-RIB * 0.46, 0, 0), (c - a) * 0.46, "Build", BOTH)
	# The lunettes: glass from the ring beam up to the vault at each end,
	# with mullions.
	for x: float in [-24.3, 24.3]:
		for j in FACETS:
			var z0 := _facet_z(j)
			var z1 := _facet_z(j + 1)
			d.quad("skylight", Vector3(x, _vault(z0), z0), Vector3(x, _vault(z1), z1), Vector3(x, RING, z1), Vector3(x, RING, z0), "Build", BOTH)
			if j > 0:
				d.box("roof_steel", Vector3(x, (RING + _vault(z0)) * 0.5, z0), Vector3(0.14, _vault(z0) - RING, 0.14), "Build", BOTH, Basis.IDENTITY, true)


# --- The lights overhead -------------------------------------------------------------------------

## Five strings of bulbs from pier to pier across the court and the upper
## level, sagging, out of reach. A few bulbs are dead.
static func _festoons(d) -> void:
	var n := 0
	for x: float in [-20.0, -12.0, -4.0, 8.0, 16.0]:
		for z: float in [-17.95, 17.95]:
			d.box("dark_metal", Vector3(x, 11.0, z), Vector3(0.2, 0.2, 0.1), "Fixtures", BOTH)
		var steps := 30
		var prev := Vector3.ZERO
		for i in steps + 1:
			var z := lerpf(-17.95, 17.95, float(i) / steps)
			var p := Vector3(x, _sag(z), z)
			if i > 0:
				d.tube("black", prev, p, 0.012, 4, "Fixtures", BOTH, false)
			if i > 0 and i < steps:
				var dead := (i * 7 + int(x)) % 11 == 0
				d.ball("bulb_dead" if dead else "bulb", p + Vector3(0, -0.13, 0), Vector3(0.07, 0.09, 0.07), 3, 6, "Fixtures", BOTH)
				d.tube("black", p, p + Vector3(0, -0.06, 0), 0.02, 4, "Fixtures", BOTH)
			prev = p
		for z: float in [-8.0, 8.0]:
			d.omni("Festoon_%d" % n, Vector3(x, _sag(z) - 0.5, z), BULB, 14.0, 1.4, BOTH)
			n += 1


static func _sag(z: float) -> float:
	return 11.0 - 1.1 * (1.0 - pow(z / 17.95, 2.0))


## The mall's name huge over its front doors, a halo over it.
static func _mall_sign(d) -> void:
	var n := Vector3(1, 0, 0)
	var b := DecoKit.facing(n)
	_neon(d, "HALO GALLERIA", Vector3(-23.9, 6.6, 0), b, 1.3, Color(1.0, 0.82, 0.55), 0.0, 0)
	d.shaded("halo_ring", GLOW, {"color": Color(1.0, 0.9, 0.7), "energy": 2.8})
	d.torus("halo_ring", Vector3(-23.85, 8.35, 0), 0.55, 0.05, Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)), 20, 4, "Fixtures", BOTH)
	d.omni("MallSign", Vector3(-22.4, 7.0, 0), Color(1.0, 0.82, 0.55), 11.0, 1.5, BOTH)


## Party balloons that got away, drifted up and stuck under the glass.
static func _balloons(d) -> void:
	var params := {"reflection_map": "terrace/reflection_eclipse.png", "spin": 0.05, "bob": 0.1, "bob_speed": 0.4, "tilt": 0.04}
	var colours := [Color(1.0, 0.2, 0.3), Color(1.0, 0.85, 0.15), Color(0.3, 0.6, 1.0), Color(0.95, 0.95, 0.95), Color(0.6, 0.3, 1.0)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var n := 0
	for spot: Vector2 in [Vector2(-10.0, -2.0), Vector2(2.0, 6.0), Vector2(-18.0, 9.0), Vector2(14.0, -9.0)]:
		var at := Vector3(spot.x, _vault(spot.y) - 0.75, spot.y)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 3:
			var off := Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.2, 0.3), rng.randf_range(-0.5, 0.5))
			var colour: Color = colours[(n + i) % colours.size()]
			DecoKit.blob(st, off, Vector3(0.36, 0.44, 0.36), colour)
			DecoKit.blob(st, off + Vector3(0, -0.46, 0), Vector3(0.05, 0.05, 0.05), colour.darkened(0.2))
			# Its string, hanging.
			DecoKit.blob(st, off + Vector3(0, -1.0, 0), Vector3(0.012, 0.5, 0.012), Color(0.9, 0.9, 0.9))
		d.floater("Balloons_%d" % n, st, at, params, n * 1.7)
		n += 1


# --- Outside --------------------------------------------------------------------------------------

## The rest of the mall round the court, rising over its walls: the
## department store to the north, the old wing with its dome to the west,
## the cinema tower to the south, the parking deck to the east. Past them,
## a pylon sign, sodium lamps in the lots, and the land dark against the
## orange all round.
static func _outside(d) -> void:
	# Four walls of mall.
	for w: Array in [[Vector3(0, 9.0, -34), Vector3(0, 0, 1), 44.0, 9.0, "far"], [Vector3(-34, 10.0, 0), Vector3(1, 0, 0), 40.0, 10.0, "far"],
			[Vector3(0, 9.0, 30), Vector3(0, 0, -1), 40.0, 9.0, "far"], [Vector3(36, 9.0, 0), Vector3(-1, 0, 0), 40.0, 9.0, "far_garage"]]:
		var c: Vector3 = w[0]
		var n: Vector3 = w[1]
		d.face(w[4], c, DecoKit.facing(n).x * w[2], Vector3(0, w[3], 0), "Far", BOTH)
		# Its roof, going back.
		d.face("far_dark", c + Vector3(0, w[3], 0) - n * 10.0, DecoKit.facing(n).x * w[2], -n * 10.0, "Far", BOTH)
	d.words("DEPARTMENT STORE", Vector3(4, 15.0, -33.9), DecoKit.facing(Vector3(0, 0, 1)), 1.5, Color(1.0, 0.9, 0.75), 0.0, "Far", BOTH).shaded = false
	# The dome over the old wing.
	d.ball("far_dark", Vector3(-46, 20.0, 0), Vector3(12, 8, 12), 6, 16, "Far", BOTH)
	d.shaded("dome_ring", GLOW, {"color": Color(1.0, 0.75, 0.45), "energy": 1.6})
	d.torus("dome_ring", Vector3(-46, 20.2, 0), 12.0, 0.25, Basis.IDENTITY, 32, 4, "Far", BOTH)
	# The cinema tower and its blade sign.
	d.box("far_dark", Vector3(14, 16.0, 37), Vector3(10, 32, 8), "Far", BOTH)
	d.words("C\nI\nN\nE\nM\nA", Vector3(14, 21.0, 32.9), DecoKit.facing(Vector3(0, 0, -1)), 2.4, Color(1.0, 0.35, 0.3), 0.0, "Far", BOTH).shaded = false
	d.box("aviation", Vector3(14, 32.6, 37), Vector3(0.8, 0.8, 0.8), "Far", BOTH)
	# The pylon sign.
	var pylon := Vector3(-44, 0, -44)
	var pn := (-pylon * Vector3(1, 0, 1)).normalized()
	var pb := DecoKit.facing(pn)
	d.box("far_dark", pylon + Vector3(0, 16, 0), Vector3(1.4, 32, 1.4), "Far", BOTH, pb)
	d.box("far_dark", pylon + Vector3(0, 32, 0), Vector3(14, 5, 1.2), "Far", BOTH, pb)
	d.words("HALO GALLERIA", pylon + Vector3(0, 32, 0) + pn * 0.65, pb, 2.6, Color(1.0, 0.85, 0.6), 0.0, "Far", BOTH).shaded = false
	d.torus("halo_ring", pylon + Vector3(0, 36.5, 0), 2.2, 0.2, Basis.IDENTITY, 24, 4, "Far", BOTH)
	# Sodium lamps across the lots to the east and south.
	for i in 14:
		var p := Vector3(46 + (i % 7) * 14.0, 0, -40 + (i / 7) * 60.0 + (i % 2) * 8.0)
		d.box("far_dark", p + Vector3(0, 5, 0), Vector3(0.3, 10, 0.3), "Far", BOTH)
		d.box("sodium", p + Vector3(0, 10.1, 0), Vector3(0.9, 0.3, 0.5), "Far", BOTH)
	# The land far off, dark against the glow.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 16:
		var a := TAU * i / 16.0
		var out := Vector3(cos(a), 0, sin(a))
		var h := rng.randf_range(6.0, 22.0)
		d.face("far_dark", out * 190.0 + Vector3(0, h * 0.5 - 4.0, 0), DecoKit.facing(-out).x * 40.0, Vector3(0, h * 0.5 + 4.0, 0), "Far", BOTH)
