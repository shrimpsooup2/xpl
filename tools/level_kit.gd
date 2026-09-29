extends RefCounted
## Builds one level scene: the shell every level shares (sky, sun, the
## player, the UI and debug layers) and the greybox pieces maps are made of:
## blocks, ramps, floors with holes, weapon pads, spawns, lights and labels.
## tools/build_scenes.gd makes one per level, fills it, and saves finish().

const K := GreyBox.Kind
## Ramp slabs are this thick unless asked otherwise.
const RAMP_THICKNESS := 0.7

var root: Node3D
var environment: Environment
var sun: DirectionalLight3D
var geometry: Node3D
var lights: Node3D
var labels: Node3D
var combat: Node3D
var spawns: Node3D


func _init(level_name: String, env_settings: Environment) -> void:
	root = Node3D.new()
	root.name = level_name
	var env := WorldEnvironment.new()
	env.name = "WorldEnvironment"
	env.environment = env_settings
	root.add_child(env)
	environment = env_settings
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-38, 35, 0)
	sun.light_color = Color(1.0, 0.84, 0.70)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 80.0
	root.add_child(sun)
	lights = _group("Lights")
	geometry = _group("Geometry")
	labels = _group("Labels")
	combat = _group("Combat")
	spawns = _group("Spawns")


func _group(group_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = group_name
	root.add_child(n)
	return n


# --- Geometry -------------------------------------------------------------------

## A block by its centre and size, optionally turned.
func box(box_name: String, center: Vector3, size: Vector3, kind: GreyBox.Kind, rot_deg := Vector3.ZERO) -> StaticBody3D:
	var b := _grey(box_name, size, kind)
	b.position = center
	b.rotation_degrees = rot_deg
	return b


## A block spanning `from` to `to` (opposite corners).
func span(box_name: String, from: Vector3, to: Vector3, kind: GreyBox.Kind) -> StaticBody3D:
	return box(box_name, (from + to) * 0.5, (to - from).abs(), kind)


## A rotated block placed by the midpoint of its top surface.
func slab(box_name: String, top_mid: Vector3, size: Vector3, kind: GreyBox.Kind, rot_deg: Vector3) -> void:
	var up := Basis.from_euler(rot_deg * (PI / 180.0)) * Vector3.UP
	box(box_name, top_mid - up * size.y * 0.5, size, kind, rot_deg)


## A ramp whose walking surface runs from the middle of its bottom edge to the
## middle of its top edge, `width` across. A thick ramp fills in the space
## under it instead of leaving a hollow.
func ramp(ramp_name: String, bottom: Vector3, top: Vector3, width: float, kind := K.RAMP, thickness := RAMP_THICKNESS) -> void:
	var along := (top - bottom).normalized()
	var right := along.cross(Vector3.UP).normalized()
	var up := right.cross(along)
	var b := _grey(ramp_name, Vector3(width, thickness, bottom.distance_to(top)), kind)
	b.transform = Transform3D(Basis(right, up, -along), (bottom + top) * 0.5 - up * thickness * 0.5)


## A solid terrace: its top at `top`, a floor slab over a block reaching down
## to `bottom` (the ground, or a floating island's underside), whose sides are
## `sides` (ride tiles by default: cliffs are wall-ride surfaces).
func terrace(terrace_name: String, x: Vector2, z: Vector2, top: float, sides := K.RIDE, bottom := 0.0) -> void:
	span(terrace_name, Vector3(x.x, bottom, z.x), Vector3(x.y, top - 0.5, z.y), sides)
	span(terrace_name + "Floor", Vector3(x.x, top - 0.5, z.x), Vector3(x.y, top, z.y), K.FLOOR)


## A floor slab over `area` (x, z), its top at `top`, with rectangular holes
## cut out of it (areas in x, z). Built from as few blocks as the holes allow.
func floor_with_holes(floor_name: String, area: Rect2, top: float, thickness: float, holes: Array, kind := K.FLOOR) -> void:
	var n := 0
	for c in _cells(area, holes):
		span("%s_%d" % [floor_name, n], Vector3(c.position.x, top - thickness, c.position.y), Vector3(c.end.x, top, c.end.y), kind)
		n += 1


## A straight wall from `a` to `b` (x, z), standing from `bottom` to `top`,
## with `openings` cut through it (doors, windows): each a Rect2 of distance
## along the wall from `a`, height above `bottom`, width and height. Built
## from as few blocks as the openings allow.
func wall(wall_name: String, a: Vector2, b: Vector2, bottom: float, top: float, openings: Array = [], kind := K.WALL, thickness := 0.4) -> void:
	var length := a.distance_to(b)
	var dir := (b - a) / length
	var cells := _cells(Rect2(0, 0, length, top - bottom), openings)
	for n in cells.size():
		var c := cells[n]
		var along := a + dir * (c.position.x + c.end.x) * 0.5
		var center := Vector3(along.x, bottom + (c.position.y + c.end.y) * 0.5, along.y)
		var piece := wall_name if cells.size() == 1 else "%s_%d" % [wall_name, n]
		if absf(dir.x) > 0.999:
			box(piece, center, Vector3(c.size.x, c.size.y, thickness), kind)
		elif absf(dir.y) > 0.999:
			box(piece, center, Vector3(thickness, c.size.y, c.size.x), kind)
		else:
			box(piece, center, Vector3(thickness, c.size.y, c.size.x), kind, Vector3(0, rad_to_deg(atan2(dir.x, dir.y)), 0))


## `area` minus `holes`, as rectangles: cut at every hole edge, solid cells
## merged into runs along x.
static func _cells(area: Rect2, holes: Array) -> Array[Rect2]:
	var xs := [area.position.x, area.end.x]
	var ys := [area.position.y, area.end.y]
	for h in holes:
		xs.append_array([h.position.x, h.end.x])
		ys.append_array([h.position.y, h.end.y])
	xs = _cuts(xs, area.position.x, area.end.x)
	ys = _cuts(ys, area.position.y, area.end.y)
	var out: Array[Rect2] = []
	for j in ys.size() - 1:
		var run_from := -1
		for i in xs.size():
			var solid := false
			if i < xs.size() - 1:
				var mid := Vector2((xs[i] + xs[i + 1]) * 0.5, (ys[j] + ys[j + 1]) * 0.5)
				solid = not holes.any(func(h: Rect2) -> bool: return h.has_point(mid))
			if solid and run_from < 0:
				run_from = i
			elif not solid and run_from >= 0:
				out.append(Rect2(xs[run_from], ys[j], xs[i] - xs[run_from], ys[j + 1] - ys[j]))
				run_from = -1
	return out


static func _cuts(values: Array, lo: float, hi: float) -> Array:
	var out := []
	for v: float in values:
		v = clampf(v, lo, hi)
		if not out.any(func(o: float) -> bool: return absf(o - v) < 0.001):
			out.append(v)
	out.sort()
	return out


func _grey(box_name: String, size: Vector3, kind: GreyBox.Kind) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.set_script(load("res://src/world/grey_box.gd"))
	b.name = box_name
	b.set(&"size", size)
	b.set(&"kind", kind)
	geometry.add_child(b)
	return b


# --- Everything else --------------------------------------------------------------

## A weapon pad standing at `at` (0: never comes back within a round).
func pad(pad_name: String, weapon: StringName, at: Vector3, respawn := 20.0) -> void:
	var p := Node3D.new()
	p.set_script(load("res://src/combat/weapon_pad.gd"))
	p.name = pad_name
	p.position = at
	p.set(&"weapon", weapon)
	p.set(&"respawn_time", respawn)
	combat.add_child(p)


## An ammo crate (only there in games with resupply: see ResupplyCrate).
func resupply(crate_name: String, at: Vector3) -> void:
	var c := Node3D.new()
	c.set_script(load("res://src/combat/resupply_crate.gd"))
	c.name = crate_name
	c.position = at
	combat.add_child(c)


## A spawn point facing along `facing` (horizontal), for `team` (a
## Hats.Team, or -1 for anyone). Returns its transform.
func spawn(spawn_name: String, at: Vector3, facing: Vector3, team := -1) -> Transform3D:
	var m := Marker3D.new()
	m.name = spawn_name
	m.position = at
	m.rotation.y = atan2(-facing.x, -facing.z)
	m.add_to_group(&"spawn", true)
	if team >= 0:
		m.set_meta(&"team", team)
	spawns.add_child(m)
	return m.transform


func light(light_name: String, at: Vector3, color: Color, reach: float, energy := 2.2) -> void:
	var omni := OmniLight3D.new()
	omni.name = light_name
	omni.position = at
	omni.light_color = color
	omni.omni_range = reach
	omni.light_energy = energy
	omni.omni_attenuation = 0.6
	lights.add_child(omni)


func label(text: String, at: Vector3) -> void:
	var l := Label3D.new()
	l.name = text.validate_node_name().replace(" ", "_")
	l.text = text
	l.position = at
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.font_size = 64
	l.pixel_size = 0.01
	l.outline_size = 16
	l.modulate = Color(1, 1, 1)
	l.outline_modulate = Color(0.15, 0.1, 0.25)
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.add_to_group(&"debug_labels", true)
	labels.add_child(l)


## Adds the player (standing at `player_at`), the UI and the debug layers,
## and hands back the finished level, ready to pack.
func finish(player_at: Transform3D) -> Node3D:
	var player: Node3D = load("res://scenes/player.tscn").instantiate()
	player.name = "Player"
	player.transform = player_at
	root.add_child(player)
	for layer: Array in [["GameUI", "res://src/ui/game_ui.gd", false], ["RetroScreen", "res://src/render/retro_screen.gd", true],
			["DebugHUD", "res://src/debug/debug_hud.gd", true], ["TuningPanel", "res://src/debug/tuning_panel.gd", true]]:
		var n: Node = CanvasLayer.new() if layer[2] else Node.new()
		n.name = layer[0]
		n.set_script(load(layer[1]))
		root.add_child(n)
	for child in root.get_children():
		child.owner = root
		if child != player:
			_own(child)
	return root


func _own(node: Node) -> void:
	for child in node.get_children():
		child.owner = root
		_own(child)
