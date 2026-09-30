extends RefCounted
## Dresses a built level (GDD §9.3): materials, decor, lamps with fixtures,
## signs, and the odd solid prop. tools/build_scenes.gd makes one for a map
## that has a `<map>_deco.gd` next to its layout and calls its dress().
##
## Decor is merged as it's added: every piece with the same material, group
## and render layers ends up in one mesh, so a room full of pipes, lockers
## and tiles is a handful of draw calls. The meshes and materials are saved
## as files under assets/maps/<map>/, and the scene points at them.
##
## Groups, which the graphics settings switch (Graphics):
## - "Build": the architecture dressed onto the blocks and walls
##   (shopfronts, fascias, rails); never hidden.
## - "Fixtures": what the lamps are (tubes, lenses, signs); never hidden, so
##   a light always has something to come from.
## - "Detail": small stuff; hidden at low detail.
## - "Solid": props you can bump into (with colliders); always there.
## - "Effects": moving water, beams and the like; hidden with effects off.
## - "Far": the skyline outside; always there, cheap, unshaded.

const LevelKit := preload("res://tools/level_kit.gd")
const SURFACE_SHADER := preload("res://src/render/retro_surface.gdshader")
const REFLECTION_MAP := preload("res://assets/textures/reflection_map.png")
## The fake reflection the map's surfaces use (a night map swaps it).
var reflection: Texture2D = REFLECTION_MAP
const GROUPS := ["Build", "Solid", "Fixtures", "Detail", "Effects", "Far"]

## Render layers: each floor's lamps light their own floor.
const LAYER_BOTH := 1
const LAYER_LOWER := 2
const LAYER_UPPER := 4

var kit: LevelKit
var root: Node3D
var dir: String
var _groups := {}
var _materials := {}
var _buckets := {}   # key -> [SurfaceTool, material name, group, layers, shadows, zone]
## Decor added while this is set goes into meshes of its own for the zone
## (a map's west, middle and east): a mesh across a whole big map gets
## only the nearest lamps (16 an object), a zone's gets its own.
var zone := ""
var _mesh_count := 0


func _init(level_kit: LevelKit, map_dir: String) -> void:
	kit = level_kit
	dir = map_dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir + "meshes"))
	# What the last build made goes, so nothing it no longer uses is left.
	for sub: String in [dir, dir + "meshes/"]:
		for f in DirAccess.get_files_at(sub):
			if f.ends_with(".tres") or f.ends_with(".res"):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(sub + f))
	root = Node3D.new()
	root.name = "Decor"
	kit.root.add_child(root)
	for g: String in GROUPS:
		var n := Node3D.new()
		n.name = g
		n.add_to_group(&"decor_" + g.to_lower(), true)
		root.add_child(n)
		_groups[g] = n


func group(name: String) -> Node3D:
	return _groups[name]


## A basis facing `n` (its z), upright: words and faces on a wall facing `n`
## read along its x.
static func facing(n: Vector3) -> Basis:
	var z := n.normalized()
	var x := Vector3.UP.cross(z).normalized()
	return Basis(x, z.cross(x), z)


## A basis lying flat, facing up, reading along `along`.
static func flat(along: Vector3) -> Basis:
	var x := along.normalized()
	return Basis(x, Vector3.UP.cross(x), Vector3.UP)


# --- Materials ---------------------------------------------------------------------------

## A world-surface material (retro_surface.gdshader) under `name`, saved as
## a file. `p` keys: side, top, bottom (texture paths under
## assets/textures/), meters, top_meters, bottom_meters, tint, top_tint,
## gloss, grazing, roughness, specular, uv (decor UVs), lanes (a Color),
## caustics (strength), caustics_color.
func surface(name: String, p: Dictionary) -> ShaderMaterial:
	if _materials.has(name):
		return _materials[name]
	var m := ShaderMaterial.new()
	m.shader = SURFACE_SHADER
	m.set_shader_parameter(&"albedo_texture", _tex(p.get("side", "stack/concrete")))
	m.set_shader_parameter(&"reflection_map", reflection)
	m.set_shader_parameter(&"meters_per_repeat", p.get("meters", 2.0))
	m.set_shader_parameter(&"tint", p.get("tint", Color.WHITE))
	m.set_shader_parameter(&"gloss", p.get("gloss", 0.15))
	m.set_shader_parameter(&"gloss_grazing", p.get("grazing", 0.45))
	m.set_shader_parameter(&"roughness_value", p.get("roughness", 0.5))
	m.set_shader_parameter(&"specular_value", p.get("specular", 0.35))
	if p.has("top"):
		m.set_shader_parameter(&"use_top", true)
		m.set_shader_parameter(&"top_texture", _tex(p.top))
		m.set_shader_parameter(&"top_meters", p.get("top_meters", p.get("meters", 2.0)))
		m.set_shader_parameter(&"top_tint", p.get("top_tint", Color.WHITE))
	if p.has("bottom"):
		m.set_shader_parameter(&"use_bottom", true)
		m.set_shader_parameter(&"bottom_texture", _tex(p.bottom))
		m.set_shader_parameter(&"bottom_meters", p.get("bottom_meters", p.get("meters", 2.0)))
	if p.get("uv", false):
		m.set_shader_parameter(&"use_uv", true)
	if p.has("lanes"):
		m.set_shader_parameter(&"lane_color", p.lanes)
		for k: String in ["lane_period", "lane_width", "lane_length"]:
			if p.has(k):
				m.set_shader_parameter(StringName(k), p[k])
	if p.has("caustics"):
		m.set_shader_parameter(&"caustics_texture", _tex("stack/caustics"))
		m.set_shader_parameter(&"caustics", p.caustics)
		m.set_shader_parameter(&"caustics_color", p.get("caustics_color", Color(0.55, 0.95, 1.0)))
		m.set_shader_parameter(&"caustics_meters", p.get("caustics_meters", 3.0))
	return _keep(name, m)


## A material of another shader (glowing tubes, water, windows...), saved as
## a file. `params` are its shader parameters; strings ending in .png are
## loaded as textures from assets/textures/.
func shaded(name: String, shader_path: String, params := {}) -> ShaderMaterial:
	if _materials.has(name):
		return _materials[name]
	var m := ShaderMaterial.new()
	m.shader = load(shader_path)
	for k: String in params:
		var v: Variant = params[k]
		m.set_shader_parameter(StringName(k), _tex(v.trim_suffix(".png")) if v is String and v.ends_with(".png") else v)
	return _keep(name, m)


func _keep(name: String, m: ShaderMaterial) -> ShaderMaterial:
	var path := dir + name + ".tres"
	ResourceSaver.save(m, path)
	m = load(path)
	_materials[name] = m
	return m


func _tex(path: String) -> Texture2D:
	return load("res://assets/textures/%s.png" % path)


## A material by name (made earlier with surface() or shaded()).
func mat(name: String) -> Material:
	return _materials[name]


# --- Geometry ------------------------------------------------------------------------

func _bucket(material: String, grp: String, layers: int, shadows: bool) -> SurfaceTool:
	var key := "%s|%s|%d|%d|%s" % [material, grp, layers, int(shadows), zone]
	if not _buckets.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_buckets[key] = [st, material, grp, layers, shadows, zone]
	return _buckets[key][0]


## One flat four-sided face: `c` its middle, `u` and `v` half its width and
## half its height (v points up the face), facing u × v. UVs in metres,
## v running down the face.
func face(material: String, c: Vector3, u: Vector3, v: Vector3, grp := "Detail", layers := LAYER_BOTH, shadows := false) -> void:
	var st := _bucket(material, grp, layers, shadows)
	var n := u.cross(v).normalized()
	var w := u.length() * 2.0
	var h := v.length() * 2.0
	var corners := [c - u + v, c + u + v, c + u - v, c - u - v]
	var uvs := [Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_normal(n)
		st.set_uv(uvs[i])
		st.add_vertex(corners[i])


## A flat four-sided face through four corners (top-left, top-right,
## bottom-right, bottom-left as you look at its front), for shapes face()
## can't make. UVs in metres from the top-left corner, v running down.
func quad(material: String, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, grp := "Detail", layers := LAYER_BOTH, shadows := false) -> void:
	var st := _bucket(material, grp, layers, shadows)
	var eu := (p1 - p0).normalized()
	var down := p3 - p0
	var ev := (down - eu * down.dot(eu)).normalized()
	var n := eu.cross(-ev).normalized()
	var corners := [p0, p1, p2, p3]
	for i: int in [0, 1, 2, 0, 2, 3]:
		var q: Vector3 = corners[i]
		st.set_normal(n)
		st.set_uv(Vector2((q - p0).dot(eu), (q - p0).dot(ev)))
		st.add_vertex(q)


## A box: `c` its middle, `size` along the basis `b`'s axes. `skip` names
## faces not to build ("top", "bottom", "front" (−z), "back", "left", "right").
func box(material: String, c: Vector3, size: Vector3, grp := "Detail", layers := LAYER_BOTH, b := Basis.IDENTITY, shadows := false, skip: Array = []) -> void:
	var x := b.x * size.x * 0.5
	var y := b.y * size.y * 0.5
	var z := b.z * size.z * 0.5
	var sides := {
		"top": [c + y, x, -z], "bottom": [c - y, x, z],
		"back": [c + z, x, y], "front": [c - z, -x, y],
		"right": [c + x, -z, y], "left": [c - x, z, y],
	}
	for name: String in sides:
		if name in skip:
			continue
		var s: Array = sides[name]
		face(material, s[0], s[1], s[2], grp, layers, shadows)


## A tube from `a` to `b`, `radius` round, with `sides` sides and closed
## ends if `caps`.
func tube(material: String, a: Vector3, b: Vector3, radius: float, sides := 8, grp := "Detail", layers := LAYER_BOTH, caps := true, shadows := false) -> void:
	var st := _bucket(material, grp, layers, shadows)
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var up := side.cross(axis)
	var length := a.distance_to(b)
	var ring := func(i: int) -> Vector3:
		var t := TAU * i / sides
		return side * cos(t) + up * sin(t)
	var around := TAU * radius
	for i in sides:
		var n0: Vector3 = ring.call(i)
		var n1: Vector3 = ring.call(i + 1)
		var u0 := around * i / sides
		var u1 := around * (i + 1) / sides
		var quad := [[a + n0 * radius, n0, Vector2(u0, length)], [b + n0 * radius, n0, Vector2(u0, 0)],
				[b + n1 * radius, n1, Vector2(u1, 0)], [a + n1 * radius, n1, Vector2(u1, length)]]
		for k: int in [0, 1, 2, 0, 2, 3]:
			st.set_normal(quad[k][1])
			st.set_uv(quad[k][2])
			st.add_vertex(quad[k][0])
		if caps:
			for end: Array in [[b, axis, [1, 2]], [a, -axis, [2, 1]]]:
				var p0: Vector3 = end[0]
				var tri := [p0, p0 + (n0 if end[2][0] == 1 else n1) * radius, p0 + (n1 if end[2][0] == 1 else n0) * radius]
				for q in tri:
					st.set_normal(end[1])
					st.set_uv(Vector2((q - p0).dot(side), (q - p0).dot(up)))
					st.add_vertex(q)


## A tube following `pts` (a bent tube: neon, cable), `radius` round, one
## smooth piece with its bends shared, `closed` joining the end to the start.
func path_tube(material: String, pts: PackedVector3Array, radius: float, sides := 6, grp := "Detail", layers := LAYER_BOTH, closed := false) -> void:
	if closed and pts.size() > 2 and pts[0].distance_to(pts[pts.size() - 1]) > 0.0001:
		pts.append(pts[0])
	var n := pts.size()
	if n < 2:
		return
	var st := _bucket(material, grp, layers, false)
	var tangents: Array[Vector3] = []
	for i in n:
		var t := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)])
		if closed and (i == 0 or i == n - 1):
			t = pts[1] - pts[n - 2]
		tangents.append(t.normalized() if t.length() > 0.00001 else Vector3.FORWARD)
	# A frame carried along without twisting.
	var side := tangents[0].cross(Vector3.UP if absf(tangents[0].y) < 0.9 else Vector3.RIGHT).normalized()
	var rings: Array = []
	var along := 0.0
	for i in n:
		var t: Vector3 = tangents[i]
		side = (side - t * side.dot(t)).normalized()
		var up := side.cross(t)
		if i > 0:
			along += pts[i].distance_to(pts[i - 1])
		var ring := []
		for k in sides + 1:
			var a := TAU * k / sides
			var dir := side * cos(a) + up * sin(a)
			ring.append([pts[i] + dir * radius, dir, Vector2(TAU * radius * k / sides, along)])
		rings.append(ring)
	for i in n - 1:
		for k in sides:
			var q := [rings[i][k], rings[i + 1][k], rings[i + 1][k + 1], rings[i][k + 1]]
			for j: int in [0, 1, 2, 0, 2, 3]:
				st.set_normal(q[j][1])
				st.set_uv(q[j][2])
				st.add_vertex(q[j][0])


## A mesh merged in (a word of extruded letters): its faces toward its +z
## in `front`, the rest (the sides) in `side`.
func add_mesh(mesh: Mesh, t: Transform3D, front: String, side: String, grp := "Detail", layers := LAYER_BOTH) -> void:
	var normal_basis := t.basis.inverse().transposed()
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			indices = PackedInt32Array(range(verts.size()))
		for i in range(0, indices.size(), 3):
			var tri := [indices[i], indices[i + 1], indices[i + 2]]
			var facing: Vector3 = normals[tri[0]] + normals[tri[1]] + normals[tri[2]]
			var st := _bucket(front if facing.z > 2.5 else side, grp, layers, false)
			for v: int in tri:
				st.set_normal((normal_basis * normals[v]).normalized())
				var p := verts[v]
				st.set_uv(Vector2(p.x, -p.y))
				st.add_vertex(t * p)


## A ball, `rings` from pole to pole.
func ball(material: String, c: Vector3, radius: Vector3, rings := 6, sides := 10, grp := "Detail", layers := LAYER_BOTH, shadows := false) -> void:
	var st := _bucket(material, grp, layers, shadows)
	var at := func(i: int, j: int) -> Vector3:
		var lat := PI * (float(i) / rings - 0.5)
		var lon := TAU * j / sides
		return Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
	for i in rings:
		for j in sides:
			var q := [at.call(i, j), at.call(i + 1, j), at.call(i + 1, j + 1), at.call(i, j + 1)]
			for k: int in [0, 2, 1, 0, 3, 2]:
				var d: Vector3 = q[k]
				st.set_normal((d / radius).normalized())
				st.set_uv(Vector2(float(j + int(k == 2 or k == 3)) / sides, float(i + int(k == 1 or k == 2)) / rings))
				st.add_vertex(c + d * radius)


## A ring: `c` its middle, lying flat (in the plane of `b`'s x and z),
## `big` round to the middle of the tube, `small` round the tube.
func torus(material: String, c: Vector3, big: float, small: float, b := Basis.IDENTITY, segments := 14, sides := 6, grp := "Detail", layers := LAYER_BOTH) -> void:
	var st := _bucket(material, grp, layers, false)
	var at := func(i: int, j: int) -> Array:
		var a := TAU * i / segments
		var t := TAU * j / sides
		var centre := Vector3(cos(a), 0, sin(a)) * big
		var n := Vector3(cos(a) * cos(t), sin(t), sin(a) * cos(t))
		return [c + b * (centre + n * small), (b * n).normalized(), Vector2(float(i) / segments * 4.0, float(j) / sides)]
	for i in segments:
		for j in sides:
			var q := [at.call(i, j), at.call(i + 1, j), at.call(i + 1, j + 1), at.call(i, j + 1)]
			for k: int in [0, 1, 2, 0, 2, 3]:
				st.set_normal(q[k][1])
				st.set_uv(q[k][2])
				st.add_vertex(q[k][0])


## An invisible solid box (a prop you bump into), on the world's collision
## layer like the greybox.
func solid(c: Vector3, size: Vector3, b := Basis.IDENTITY) -> void:
	var body := StaticBody3D.new()
	body.name = "Solid_%d" % group("Solid").get_child_count()
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	body.transform = Transform3D(b, c)
	group("Solid").add_child(body)


## A mesh of its own (something that moves or has its own material), under
## `grp`.
func own_mesh(node_name: String, mesh: Mesh, material: Material, t: Transform3D, grp := "Effects", layers := LAYER_BOTH) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = material
	mi.transform = t
	mi.layers = layers
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	group(grp).add_child(mi)
	return mi


# --- Things adrift -------------------------------------------------------------------------

## Something floating in the sky (float_prop.gdshader turns it and bobs
## it): `st` a mesh in vertex colours, saved as its own file.
func floater(node_name: String, st: SurfaceTool, at: Vector3, params: Dictionary, phase: float, scale := 1.0, layers := LAYER_BOTH) -> void:
	var p := params.duplicate()
	p["phase"] = phase
	var m: ShaderMaterial = shaded("float_" + node_name.to_lower(), "res://src/render/deco/float_prop.gdshader", p)
	st.index()
	var mesh := st.commit()
	var file := dir + "meshes/float_%s.res" % node_name.to_lower()
	ResourceSaver.save(mesh, file)
	own_mesh(node_name, load(file), m, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale), at), "Detail", layers)


## A ball (squashed by `r`) into `st`, in one colour or stripes of `bands`
## round it.
static func blob(st: SurfaceTool, c: Vector3, r: Vector3, colour: Color, bands: Array = []) -> void:
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


# --- Lights and words ----------------------------------------------------------------------

## A lamp: an OmniLight3D at `at` (the fixture is drawn separately, by the
## caller, so the light always has something to come from). `layers`: which
## render layers it lights. `minor` lamps go with the fewer-lights setting.
func omni(light_name: String, at: Vector3, color: Color, reach: float, energy: float, layers := 0xFFFFF, minor := false, shadows := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = light_name
	l.position = at
	l.light_color = color
	l.omni_range = reach
	l.light_energy = energy
	l.omni_attenuation = 1.2
	l.light_specular = 0.15
	l.light_cull_mask = layers
	l.shadow_enabled = shadows
	_light(l, minor)
	return l


## A spotlight at `at` pointing along `dir`.
func spot(light_name: String, at: Vector3, dir: Vector3, color: Color, reach: float, energy: float, angle: float, layers := 0xFFFFF, minor := false, shadows := false) -> SpotLight3D:
	var l := SpotLight3D.new()
	l.name = light_name
	l.light_color = color
	l.spot_range = reach
	l.spot_angle = angle
	l.spot_angle_attenuation = 0.6
	l.spot_attenuation = 1.1
	l.light_energy = energy
	l.light_specular = 0.15
	l.light_cull_mask = layers
	l.shadow_enabled = shadows
	var up := Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.FORWARD
	l.transform = Transform3D(Basis.looking_at(dir, up), at)
	_light(l, minor)
	return l


func _light(l: Light3D, minor: bool) -> void:
	if l.shadow_enabled:
		l.add_to_group(&"shadow_lights", true)
	if minor:
		l.add_to_group(&"minor_lights", true)
	kit.lights.add_child(l)


## Words on a surface: `at` their middle, `b` their facing (they read along
## b.x, face b.z). `glow` over 1 makes them light up (exit signs). `font` a
## file in assets/fonts/ (Liberation Sans by default).
func words(text: String, at: Vector3, b: Basis, size: float, color: Color, glow := 0.0, grp := "Detail", layers := LAYER_BOTH, font := "LiberationSans-Regular.ttf") -> Label3D:
	var l := Label3D.new()
	l.name = ("Words_" + text).validate_node_name().replace(" ", "_").left(40)
	l.text = text
	l.transform = Transform3D(b, at)
	l.font = load("res://assets/fonts/" + font)
	l.font_size = 32
	l.pixel_size = size / 32.0
	l.outline_size = 0
	l.shaded = glow <= 0.0
	l.double_sided = false
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.modulate = color * (glow if glow > 0.0 else 1.0)
	l.modulate.a = 1.0
	l.layers = layers
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	group(grp).add_child(l)
	return l


# --- Finish --------------------------------------------------------------------------------

## Turns the merged decor into meshes, saved as files, one MeshInstance3D
## each under its group.
func finish() -> void:
	for key: String in _buckets:
		var b: Array = _buckets[key]
		var st: SurfaceTool = b[0]
		# Shared corners stored once: the same triangles, a smaller file.
		st.index()
		var mesh := st.commit()
		var file := dir + "meshes/%s_%s_%d%s%s.res" % [b[1], String(b[2]).to_lower(), b[3], "_s" if b[4] else "",
				"" if b[5] == "" else "_" + String(b[5]).to_lower()]
		ResourceSaver.save(mesh, file)
		var mi := MeshInstance3D.new()
		mi.name = "%s_%d" % [b[1], _mesh_count]
		_mesh_count += 1
		mi.mesh = load(file)
		mi.material_override = _materials[b[1]]
		mi.layers = b[3]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if b[4] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group(b[2]).add_child(mi)
