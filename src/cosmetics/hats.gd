class_name Hats
extends RefCounted
## Hats: the one cosmetic, and how you tell the teams apart. Every hat's main
## mass is its wearer's team colour (red or blue), trimmed in black, white,
## gold or metal, so a glance at the head says whose side someone's on. No
## hat: a team-coloured triangle hovers over the head instead.
##
## Hats are built like the guns: glossy primitives listed as data. Hat
## space: the origin is the centre of the ball head (radius 0.165), +Y up,
## -Z forward (the way the body faces), +X to the wearer's right.
## Parts: [shape, colour key, dims, position, rotation degrees, scale, tag].
##   "cyl"    dims (top radius, bottom radius, height)
##   "ring"   an open cylinder, drawn from both sides
##   "sphere" dims.x = radius;  "dome" the top half of one, base at y = 0
##   "box"    dims = size;  "torus" dims (inner radius, outer radius)
## Tags: &"spin" turns about Y (a propeller).

enum Team { RED, BLUE }

const NONE := &"none"
const TEAM_COLORS := {Team.RED: Color(0.9, 0.17, 0.2), Team.BLUE: Color(0.17, 0.4, 0.95)}
const TEAM_NAMES := {Team.RED: "red", Team.BLUE: "blue"}
const FIXED := {
	&"white": Color(0.95, 0.95, 0.96),
	&"black": Color(0.09, 0.09, 0.11),
	&"gold": Color(1.0, 0.77, 0.24),
	&"metal": Color(0.72, 0.74, 0.78),
	&"ivory": Color(0.94, 0.89, 0.76),
	&"leather": Color(0.36, 0.22, 0.14),
}
## Colour key -> gloss, rim, glow, roughness.
const FINISH := {
	&"team": [0.45, 0.22, 0.0, 0.25],
	&"team_dark": [0.4, 0.15, 0.0, 0.3],
	&"team_light": [0.5, 0.2, 0.0, 0.2],
	&"team_glow": [0.5, 0.2, 1.1, 0.15],
	&"white": [0.3, 0.15, 0.0, 0.45],
	&"black": [0.35, 0.1, 0.0, 0.3],
	&"gold": [0.95, 0.0, 0.08, 0.1],
	&"metal": [0.9, 0.0, 0.0, 0.12],
	&"ivory": [0.35, 0.1, 0.0, 0.35],
	&"leather": [0.2, 0.05, 0.0, 0.55],
}
const SPIN_SPEED := 9.0

## Display order.
const ALL := [&"top_hat", &"cap", &"beanie", &"cowboy_hat", &"bowler", &"party_hat", &"crown", &"fez",
		&"propeller_cap", &"chef_hat", &"viking_helmet", &"hard_hat", &"bucket_hat", &"mortarboard",
		&"wizard_hat", &"halo", NONE]
const NAMES := {
	&"top_hat": "top hat", &"cap": "cap", &"beanie": "beanie", &"cowboy_hat": "cowboy hat",
	&"bowler": "bowler", &"party_hat": "party hat", &"crown": "crown", &"fez": "fez",
	&"propeller_cap": "propeller cap", &"chef_hat": "chef hat", &"viking_helmet": "viking helmet",
	&"hard_hat": "hard hat", &"bucket_hat": "bucket hat", &"mortarboard": "mortarboard",
	&"wizard_hat": "wizard hat", &"halo": "halo", NONE: "no hat",
}

static var _meshes := {}
static var _materials := {}


static func team_color(team: Team) -> Color:
	return TEAM_COLORS[team]


static func color(key: StringName, team: Team) -> Color:
	var c := team_color(team)
	match key:
		&"team", &"team_glow":
			return c
		&"team_dark":
			return c.darkened(0.4)
		&"team_light":
			return c.lightened(0.4)
	return FIXED.get(key, Color.MAGENTA)


## The hat `id` in `team`'s colours, as a node in hat space (null for none).
static func build(id: StringName, team: Team) -> Node3D:
	var parts := _parts(id)
	if parts.is_empty():
		return null
	var hat := Node3D.new()
	hat.name = "Hat_" + String(id)
	for p: Array in parts:
		hat.add_child(_part(p, team))
	return hat


## A downward-pointing triangle over the head in the team colour, with a
## dark outline so it reads on any background. Turn it to face the viewer
## with face_marker().
static func build_marker(team: Team) -> Node3D:
	var marker := Node3D.new()
	marker.name = "TeamMarker"
	for outline in [true, false]:
		var mi := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.2, 0.18, 0.02) * (1.3 if outline else 1.0)
		mi.mesh = prism
		mi.rotation.z = PI  # Point down, at the head.
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.05, 0.05, 0.08) if outline else team_color(team)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The outline sits behind, lowered so the border comes out even (the
		# prism scales about its box, not the triangle's centre).
		mi.position = Vector3(0, -0.009, -0.02) if outline else Vector3.ZERO
		marker.add_child(mi)
	return marker


## Turns the marker's face (+Z) toward `eye`, staying upright.
static func face_marker(marker: Node3D, eye: Vector3) -> void:
	var to := eye - marker.global_position
	to.y = 0.0
	if to.length() > 0.01:
		marker.global_basis = Basis.looking_at(-to, Vector3.UP)


## Turns any spinning parts (call every frame).
static func animate(hat: Node3D, delta: float) -> void:
	for part in hat.get_children():
		if part.has_meta(&"spin"):
			(part as Node3D).rotate_y(SPIN_SPEED * delta)


static func _part(p: Array, team: Team) -> Node3D:
	var shape: String = p[0]
	var key: StringName = p[1]
	var dims: Vector3 = p[2]
	var at: Vector3 = p[3]
	var rot: Vector3 = p[4] if p.size() > 4 else Vector3.ZERO
	var scale: Vector3 = p[5] if p.size() > 5 else Vector3.ONE
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(shape, dims)
	mi.material_override = _material(shape == "ring" or shape == "dome")
	var finish: Array = FINISH.get(key, FINISH[&"team"])
	mi.set_instance_shader_parameter(&"color", color(key, team))
	mi.set_instance_shader_parameter(&"gloss", finish[0])
	mi.set_instance_shader_parameter(&"rim_amount", finish[1])
	mi.set_instance_shader_parameter(&"glow", finish[2])
	mi.set_instance_shader_parameter(&"roughness_amount", finish[3])
	mi.transform = Transform3D(Basis.from_euler(rot * (PI / 180.0)) * Basis.from_scale(scale), at)
	if p.size() > 6 and p[6] == &"spin":
		mi.set_meta(&"spin", true)
	return mi


static func _material(double_sided: bool) -> ShaderMaterial:
	if not _materials.has(double_sided):
		var m := ShaderMaterial.new()
		m.shader = preload("res://src/render/gloss_double.gdshader") if double_sided else preload("res://src/render/gloss.gdshader")
		m.set_shader_parameter(&"reflection_map", preload("res://assets/textures/reflection_map.png"))
		_materials[double_sided] = m
	return _materials[double_sided]


static func _mesh(shape: String, d: Vector3) -> Mesh:
	var key := "%s%s" % [shape, d]
	if _meshes.has(key):
		return _meshes[key]
	var mesh: Mesh
	match shape:
		"cyl", "ring":
			var c := CylinderMesh.new()
			c.top_radius = d.x
			c.bottom_radius = d.y
			c.height = d.z
			c.radial_segments = 20
			c.rings = 1
			c.cap_top = shape == "cyl"
			c.cap_bottom = shape == "cyl"
			mesh = c
		"sphere", "dome":
			var s := SphereMesh.new()
			s.radius = d.x
			s.height = d.x * (1.0 if shape == "dome" else 2.0)
			s.is_hemisphere = shape == "dome"
			s.radial_segments = 20
			s.rings = 8
			mesh = s
		"box":
			var b := BoxMesh.new()
			b.size = d
			mesh = b
		"torus":
			var t := TorusMesh.new()
			t.inner_radius = d.x
			t.outer_radius = d.y
			t.rings = 24
			t.ring_segments = 8
			mesh = t
	_meshes[key] = mesh
	return mesh


# --- The hats ---------------------------------------------------------------

static func _parts(id: StringName) -> Array:
	match id:
		&"top_hat":
			return [
				["cyl", &"team", Vector3(0.132, 0.126, 0.3), Vector3(0, 0.27, 0.01), Vector3(-6, 0, 0)],
				["cyl", &"black", Vector3(0.13, 0.13, 0.055), Vector3(0, 0.15, 0.0), Vector3(-6, 0, 0)],
				["cyl", &"team_dark", Vector3(0.235, 0.235, 0.016), Vector3(0, 0.12, 0.0), Vector3(-6, 0, 0)],
				["torus", &"team_dark", Vector3(0.222, 0.245, 0), Vector3(0, 0.124, 0.0), Vector3(-6, 0, 0), Vector3(1, 0.5, 1)],
			]
		&"cap":
			return [
				["dome", &"team", Vector3(0.176, 0, 0), Vector3(0, 0.015, 0.005), Vector3.ZERO, Vector3(1, 1.02, 1)],
				["cyl", &"team_dark", Vector3(0.15, 0.15, 0.016), Vector3(0, 0.04, -0.17), Vector3(-10, 0, 0), Vector3(0.88, 1, 0.95)],
				["sphere", &"team_dark", Vector3(0.022, 0, 0), Vector3(0, 0.19, 0.005)],
				["torus", &"white", Vector3(0.17, 0.182, 0), Vector3(0, 0.03, 0.005), Vector3.ZERO, Vector3(1, 0.4, 1)],
			]
		&"beanie":
			return [
				["dome", &"team", Vector3(0.178, 0, 0), Vector3(0, 0.02, 0.0), Vector3.ZERO, Vector3(1, 1.22, 1)],
				["ring", &"team_dark", Vector3(0.184, 0.184, 0.075), Vector3(0, 0.035, 0.0)],
				["torus", &"team_dark", Vector3(0.17, 0.192, 0), Vector3(0, 0.072, 0.0), Vector3.ZERO, Vector3(1, 0.6, 1)],
				["torus", &"team_dark", Vector3(0.17, 0.192, 0), Vector3(0, -0.0, 0.0), Vector3.ZERO, Vector3(1, 0.6, 1)],
				["sphere", &"white", Vector3(0.058, 0, 0), Vector3(0, 0.255, 0.0)],
			]
		&"cowboy_hat":
			return [
				["cyl", &"team", Vector3(0.118, 0.145, 0.17), Vector3(0, 0.2, 0.02), Vector3(-10, 0, 0)],
				["box", &"team_dark", Vector3(0.05, 0.03, 0.2), Vector3(0, 0.285, 0.035), Vector3(-10, 0, 0)],
				["cyl", &"leather", Vector3(0.147, 0.147, 0.032), Vector3(0, 0.13, 0.008), Vector3(-10, 0, 0)],
				["cyl", &"team", Vector3(0.3, 0.3, 0.014), Vector3(0, 0.115, 0.0), Vector3(-10, 0, 0), Vector3(1, 1, 0.9)],
				["torus", &"team_dark", Vector3(0.285, 0.315, 0), Vector3(0, 0.135, 0.0), Vector3(-10, 0, 0), Vector3(1, 1.4, 0.9)],
			]
		&"bowler":
			return [
				["sphere", &"team", Vector3(0.158, 0, 0), Vector3(0, 0.125, 0.0), Vector3.ZERO, Vector3(1, 0.92, 1)],
				["cyl", &"black", Vector3(0.162, 0.162, 0.035), Vector3(0, 0.1, 0.0)],
				["cyl", &"team_dark", Vector3(0.2, 0.2, 0.012), Vector3(0, 0.084, 0.0)],
				["torus", &"team_dark", Vector3(0.188, 0.212, 0), Vector3(0, 0.09, 0.0), Vector3.ZERO, Vector3(1, 0.7, 1)],
			]
		&"party_hat":
			return [
				["cyl", &"team", Vector3(0.0, 0.115, 0.31), Vector3(0.02, 0.28, 0.0), Vector3(0, 0, -10)],
				["cyl", &"white", Vector3(0.078, 0.089, 0.03), Vector3(0.012, 0.225, 0.0), Vector3(0, 0, -10)],
				["cyl", &"white", Vector3(0.04, 0.051, 0.03), Vector3(0.028, 0.32, 0.0), Vector3(0, 0, -10)],
				["sphere", &"white", Vector3(0.038, 0, 0), Vector3(0.048, 0.44, 0.0)],
				["torus", &"gold", Vector3(0.105, 0.122, 0), Vector3(0.0, 0.13, 0.0), Vector3(0, 0, -10), Vector3(1, 0.5, 1)],
			]
		&"crown":
			var crown := [
				["dome", &"team", Vector3(0.125, 0, 0), Vector3(0, 0.13, 0.0), Vector3.ZERO, Vector3(1, 0.9, 1)],
				["ring", &"gold", Vector3(0.148, 0.14, 0.075), Vector3(0, 0.155, 0.0)],
				["torus", &"gold", Vector3(0.132, 0.152, 0), Vector3(0, 0.12, 0.0), Vector3.ZERO, Vector3(1, 0.6, 1)],
			]
			for i in 8:
				var a := TAU * i / 8.0
				var at := Vector3(sin(a), 0, -cos(a)) * 0.145
				crown.append(["cyl", &"gold", Vector3(0.0, 0.026, 0.07), at + Vector3(0, 0.225, 0)])
				crown.append(["sphere", &"gold", Vector3(0.013, 0, 0), at + Vector3(0, 0.265, 0)])
				if i % 2 == 0:
					crown.append(["sphere", &"team_light" if i != 0 else &"white", Vector3(0.019, 0, 0), at * 1.05 + Vector3(0, 0.155, 0)])
			return crown
		&"fez":
			return [
				["cyl", &"team", Vector3(0.1, 0.132, 0.17), Vector3(0.0, 0.2, 0.01), Vector3(-4, 0, 6)],
				["sphere", &"black", Vector3(0.014, 0, 0), Vector3(0.01, 0.29, 0.01)],
				["box", &"black", Vector3(0.1, 0.008, 0.008), Vector3(0.06, 0.288, 0.01), Vector3(0, 0, -12)],
				["cyl", &"black", Vector3(0.008, 0.022, 0.07), Vector3(0.108, 0.24, 0.01)],
			]
		&"propeller_cap":
			return [
				["dome", &"team", Vector3(0.176, 0, 0), Vector3(0, 0.015, 0.0), Vector3.ZERO, Vector3(1, 1.02, 1)],
				["torus", &"white", Vector3(0.166, 0.184, 0), Vector3(0, 0.015, 0.0), Vector3(0, 0, 90), Vector3(1, 0.35, 1)],
				["torus", &"white", Vector3(0.166, 0.184, 0), Vector3(0, 0.015, 0.0), Vector3(90, 0, 0), Vector3(1, 0.35, 1)],
				["cyl", &"team_dark", Vector3(0.13, 0.13, 0.016), Vector3(0, 0.045, -0.13), Vector3(-9, 0, 0), Vector3(0.9, 1, 0.75)],
				["cyl", &"metal", Vector3(0.01, 0.01, 0.07), Vector3(0, 0.215, 0.0)],
				["sphere", &"gold", Vector3(0.022, 0, 0), Vector3(0, 0.25, 0.0)],
				["box", &"team_light", Vector3(0.26, 0.008, 0.045), Vector3(0, 0.25, 0.0), Vector3(0, 0, 0), Vector3.ONE, &"spin"],
			]
		&"chef_hat":
			var chef := [
				["cyl", &"white", Vector3(0.155, 0.148, 0.13), Vector3(0, 0.16, 0.0)],
				["cyl", &"team", Vector3(0.175, 0.16, 0.08), Vector3(0, 0.255, 0.0)],
				["sphere", &"team", Vector3(0.2, 0, 0), Vector3(0, 0.3, 0.0), Vector3.ZERO, Vector3(1, 0.5, 1)],
			]
			for i in 6:
				var a := TAU * i / 6.0 + 0.3
				chef.append(["sphere", &"team", Vector3(0.075, 0, 0), Vector3(sin(a) * 0.12, 0.34, cos(a) * 0.12)])
			return chef
		&"viking_helmet":
			var viking := [
				["dome", &"team", Vector3(0.18, 0, 0), Vector3(0, 0.01, 0.0), Vector3.ZERO, Vector3(1, 1.05, 1)],
				["ring", &"metal", Vector3(0.184, 0.184, 0.04), Vector3(0, 0.03, 0.0)],
				["torus", &"metal", Vector3(0.17, 0.19, 0), Vector3(0, 0.01, 0.0), Vector3(0, 0, 90), Vector3(1, 0.3, 1)],
				["box", &"metal", Vector3(0.035, 0.12, 0.02), Vector3(0, -0.02, -0.18)],
			]
			for s: float in [-1.0, 1.0]:
				viking.append(["cyl", &"ivory", Vector3(0.02, 0.04, 0.13), Vector3(0.2 * s, 0.1, 0.0), Vector3(0, 0, -55 * s)])
				viking.append(["cyl", &"ivory", Vector3(0.004, 0.02, 0.1), Vector3(0.27 * s, 0.2, 0.0), Vector3(0, 0, -18 * s)])
			return viking
		&"hard_hat":
			return [
				["dome", &"team", Vector3(0.182, 0, 0), Vector3(0, 0.02, 0.0), Vector3.ZERO, Vector3(1, 0.95, 1.05)],
				["cyl", &"team", Vector3(0.2, 0.2, 0.014), Vector3(0, 0.03, -0.02), Vector3.ZERO, Vector3(1, 1, 1.12)],
				["torus", &"team_light", Vector3(0.17, 0.192, 0), Vector3(0, 0.02, 0.0), Vector3(0, 0, 90), Vector3(1, 0.3, 1)],
				["box", &"white", Vector3(0.1, 0.05, 0.01), Vector3(0, 0.1, -0.17), Vector3(-30, 0, 0)],
			]
		&"bucket_hat":
			return [
				["cyl", &"team", Vector3(0.128, 0.158, 0.12), Vector3(0, 0.17, 0.0)],
				["cyl", &"team_dark", Vector3(0.16, 0.16, 0.026), Vector3(0, 0.115, 0.0)],
				["ring", &"team", Vector3(0.165, 0.245, 0.07), Vector3(0, 0.075, 0.0)],
			]
		&"mortarboard":
			return [
				["dome", &"team_dark", Vector3(0.172, 0, 0), Vector3(0, 0.02, 0.0), Vector3.ZERO, Vector3(1, 0.85, 1)],
				["box", &"team", Vector3(0.36, 0.022, 0.36), Vector3(0, 0.18, 0.0), Vector3(-4, 45, 0)],
				["sphere", &"team_light", Vector3(0.018, 0, 0), Vector3(0, 0.195, 0.0)],
				["box", &"gold", Vector3(0.2, 0.008, 0.008), Vector3(0.1, 0.194, -0.02), Vector3(0, 10, 0)],
				["cyl", &"gold", Vector3(0.008, 0.02, 0.1), Vector3(0.2, 0.14, -0.04)],
			]
		&"wizard_hat":
			return [
				["cyl", &"team_dark", Vector3(0.26, 0.26, 0.014), Vector3(0, 0.1, 0.0)],
				["torus", &"gold", Vector3(0.14, 0.158, 0), Vector3(0, 0.13, 0.0), Vector3.ZERO, Vector3(1, 0.7, 1)],
				["cyl", &"team", Vector3(0.1, 0.15, 0.2), Vector3(0, 0.2, 0.0)],
				["cyl", &"team", Vector3(0.055, 0.1, 0.16), Vector3(0, 0.365, 0.025), Vector3(18, 0, 0)],
				["cyl", &"team", Vector3(0.0, 0.055, 0.14), Vector3(0, 0.48, 0.08), Vector3(48, 0, 0)],
				["sphere", &"gold", Vector3(0.02, 0, 0), Vector3(0, 0.52, 0.14)],
			]
		&"halo":
			return [
				["torus", &"team_glow", Vector3(0.13, 0.158, 0), Vector3(0, 0.29, 0.02), Vector3(-10, 0, 0), Vector3(1, 0.7, 1)],
			]
	return []
