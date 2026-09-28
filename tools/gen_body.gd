extends SceneTree
## Generates the player's body from BodyShape:
##
##   godot --headless --path . --script res://tools/gen_body.gd
##
## 1. Meshes the smooth signed-distance body with surface nets, snaps the
##    vertices onto the true surface, and takes normals from the field, so it
##    is one seamless blob with no joints.
## 2. Skins it to the reshaped rig -> assets/characters/player_body.res
## 3. Dices it into chunks along a few randomly rotated grids with CSG ->
##    assets/characters/player_chunks_<n>.res (used by the death crumble).
##
## CSG needs a frame to update, so dicing runs across frames. Takes a while.

const OUT_DIR := "res://assets/characters/"
const CELL := 0.022  # Surface-net resolution (meters).
const BOUNDS := AABB(Vector3(-0.98, -0.04, -0.26), Vector3(1.96, 1.92, 0.5))
const CHUNK_SIZE := 0.2
const VARIANTS := 3
const INNER_COLOR := Color(0.86, 0.84, 0.88)

var _skeleton: Skeleton3D
var _prims: Dictionary
var _groups: Dictionary
var _body_mesh: ArrayMesh
var _frame := 0
var _variant := 0
var _pending: Array[CSGCombiner3D] = []
var _holder: Node3D
var _outer_material := StandardMaterial3D.new()
var _inner_material := StandardMaterial3D.new()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var rig := BodyShape.RIG_SCENE.instantiate()
	_skeleton = rig.find_children("*", "Skeleton3D", true, false)[0]
	BodyShape.reshape_skeleton(_skeleton)
	_prims = BodyShape.primitives(_skeleton)
	_groups = BodyShape.bone_segments(_skeleton)
	_outer_material.albedo_color = Color.WHITE
	_inner_material.albedo_color = INNER_COLOR

	var t0 := Time.get_ticks_msec()
	_body_mesh = _surface_nets()
	print("body: %d vertices, %d triangles in %.1f s" % [
			_body_mesh.surface_get_array_len(0), _body_mesh.surface_get_array_index_len(0) / 3,
			(Time.get_ticks_msec() - t0) / 1000.0])
	var err := ResourceSaver.save(_body_mesh, OUT_DIR + "player_body.res")
	print("saved player_body.res: ", error_string(err))
	rig.free()


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 2:
		_holder = Node3D.new()
		root.add_child(_holder)
		_queue_variant(_variant)
	elif _frame > 2 and not _pending.is_empty():
		_collect_variant(_variant)
		_variant += 1
		if _variant < VARIANTS:
			_queue_variant(_variant)
		else:
			return true
	return false


# --- Surface nets -------------------------------------------------------------

func _surface_nets() -> ArrayMesh:
	var n := Vector3i((BOUNDS.size / CELL).ceil()) + Vector3i.ONE
	var field := PackedFloat32Array()
	field.resize(n.x * n.y * n.z)
	for z in n.z:
		for y in n.y:
			for x in n.x:
				field[(z * n.y + y) * n.x + x] = BodyShape.sdf(_grid_point(x, y, z), _prims)

	# One vertex per cell the surface passes through.
	var cell_vertex := {}
	var positions := PackedVector3Array()
	var corners := [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 1, 0),
			Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(0, 1, 1), Vector3i(1, 1, 1)]
	var edges := [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]
	for z in n.z - 1:
		for y in n.y - 1:
			for x in n.x - 1:
				var vals: Array[float] = []
				var inside := 0
				for c: Vector3i in corners:
					var v := field[((z + c.z) * n.y + y + c.y) * n.x + x + c.x]
					vals.append(v)
					if v < 0.0:
						inside += 1
				if inside == 0 or inside == 8:
					continue
				var sum := Vector3.ZERO
				var count := 0
				for e: Array in edges:
					var a: float = vals[e[0]]
					var b: float = vals[e[1]]
					if (a < 0.0) != (b < 0.0):
						var t := a / (a - b)
						var pa := Vector3(corners[e[0]])
						var pb := Vector3(corners[e[1]])
						sum += pa.lerp(pb, t)
						count += 1
				var local: Vector3 = sum / count
				cell_vertex[Vector3i(x, y, z)] = positions.size()
				positions.append(BOUNDS.position + (Vector3(x, y, z) + local) * CELL)

	# Snap onto the real surface and take normals from the field.
	var normals := PackedVector3Array()
	normals.resize(positions.size())
	for i in positions.size():
		var p := positions[i]
		for step in 3:
			p -= BodyShape.gradient(p, _prims) * BodyShape.sdf(p, _prims)
		positions[i] = p
		normals[i] = BodyShape.gradient(p, _prims)

	# A quad around every grid edge that crosses the surface.
	var indices := PackedInt32Array()
	var axes := [Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1)]
	for axis in 3:
		var d: Vector3i = axes[axis]
		var u: Vector3i = axes[(axis + 1) % 3]
		var w: Vector3i = axes[(axis + 2) % 3]
		for z in n.z:
			for y in n.y:
				for x in n.x:
					var p0 := Vector3i(x, y, z)
					var p1 := p0 + d
					if p1.x >= n.x or p1.y >= n.y or p1.z >= n.z:
						continue
					var a := field[(p0.z * n.y + p0.y) * n.x + p0.x]
					var b := field[(p1.z * n.y + p1.y) * n.x + p1.x]
					if (a < 0.0) == (b < 0.0):
						continue
					var quad: Array[int] = []
					for c: Vector3i in [p0 - u - w, p0 - w, p0, p0 - u]:
						if not cell_vertex.has(c):
							quad.clear()
							break
						quad.append(cell_vertex[c])
					if quad.size() == 4:
						_emit_triangle(indices, positions, normals, quad[0], quad[1], quad[2])
						_emit_triangle(indices, positions, normals, quad[0], quad[2], quad[3])

	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	for p in positions:
		for pair: Array in BodyShape.skin(p, _groups):
			bones.append(pair[0])
			weights.append(pair[1])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Godot treats clockwise triangles as front-facing; orient by the field.
func _emit_triangle(out: PackedInt32Array, pos: PackedVector3Array, nrm: PackedVector3Array, a: int, b: int, c: int) -> void:
	var face := (pos[b] - pos[a]).cross(pos[c] - pos[a])
	var outward := nrm[a] + nrm[b] + nrm[c]
	if face.dot(outward) > 0.0:
		out.append_array([a, c, b])
	else:
		out.append_array([a, b, c])


func _grid_point(x: int, y: int, z: int) -> Vector3:
	return BOUNDS.position + Vector3(x, y, z) * CELL


# --- Dicing -------------------------------------------------------------------

func _queue_variant(v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + v
	var basis := Basis.from_euler(Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.0, TAU), rng.randf_range(-0.6, 0.6)))
	var offset := Vector3(rng.randf(), rng.randf(), rng.randf()) * CHUNK_SIZE
	var reach := int(ceil(1.2 / CHUNK_SIZE))
	var yreach := int(ceil(2.0 / CHUNK_SIZE))
	for i in range(-reach, reach + 1):
		for j in range(-2, yreach + 1):
			for k in range(-reach, reach + 1):
				var center := basis * (Vector3(i, j, k) * CHUNK_SIZE + offset)
				# Skip cells that can't touch the body.
				if BodyShape.sdf(center, _prims) > CHUNK_SIZE * 0.9:
					continue
				var combo := CSGCombiner3D.new()
				var body_shape := CSGMesh3D.new()
				body_shape.mesh = _body_mesh
				body_shape.material = _outer_material
				combo.add_child(body_shape)
				var box := CSGBox3D.new()
				box.size = Vector3.ONE * CHUNK_SIZE
				box.operation = CSGShape3D.OPERATION_INTERSECTION
				box.material = _inner_material
				box.transform = Transform3D(basis, center)
				combo.add_child(box)
				combo.set_meta(&"cell_center", center)
				_holder.add_child(combo)
				_pending.append(combo)
	print("variant %d: %d cells queued" % [v, _pending.size()])


func _collect_variant(v: int) -> void:
	var set := ChunkSet.new()
	for combo in _pending:
		var baked := combo.bake_static_mesh()
		combo.queue_free()
		if baked == null or baked.get_surface_count() == 0:
			continue
		var chunk := _finish_chunk(baked, combo.get_meta(&"cell_center"))
		if chunk.is_empty():
			continue
		set.meshes.append(chunk.mesh)
	_pending.clear()
	var err := ResourceSaver.save(set, OUT_DIR + "player_chunks_%d.res" % v)
	print("variant %d: %d chunks, saved: %s" % [v, set.meshes.size(), error_string(err)])


## Splits the CSG result into outside and cut surfaces. Outside faces get
## shared vertices with the field's smooth normals; cut faces stay flat and
## crisp. Every vertex gets skin weights, so chunks can be posed like the body.
func _finish_chunk(baked: ArrayMesh, cell_center: Vector3) -> Dictionary:
	var out := ArrayMesh.new()
	var vertex_total := 0
	for s in baked.get_surface_count():
		var arrays := baked.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if verts.is_empty():
			continue
		var inner := baked.surface_get_material(s) == _inner_material
		var idx = arrays[Mesh.ARRAY_INDEX]
		var corners := PackedVector3Array()
		if idx == null or (idx as PackedInt32Array).is_empty():
			corners = verts
		else:
			for i: int in idx:
				corners.append(verts[i])

		var positions := PackedVector3Array()
		var normals := PackedVector3Array()
		var indices := PackedInt32Array()
		if inner:
			for c in range(0, corners.size(), 3):
				# Cut faces lie on the slicing cube, so outward is away from its centre.
				var face_n := (corners[c + 2] - corners[c]).cross(corners[c + 1] - corners[c]).normalized()
				var middle := (corners[c] + corners[c + 1] + corners[c + 2]) / 3.0
				if face_n.dot(middle - cell_center) < 0.0:
					face_n = -face_n
				for q in 3:
					positions.append(corners[c + q])
					normals.append(face_n)
		else:
			var lookup := {}
			for p in corners:
				var key := p.snappedf(0.00001)
				if not lookup.has(key):
					lookup[key] = positions.size()
					positions.append(p)
					normals.append(BodyShape.gradient(p, _prims))
				indices.append(lookup[key])

		var bones := PackedInt32Array()
		var weights := PackedFloat32Array()
		for p in positions:
			for pair: Array in BodyShape.skin(p, _groups):
				bones.append(pair[0])
				weights.append(pair[1])
		var surf := []
		surf.resize(Mesh.ARRAY_MAX)
		surf[Mesh.ARRAY_VERTEX] = positions
		surf[Mesh.ARRAY_NORMAL] = normals
		surf[Mesh.ARRAY_BONES] = bones
		surf[Mesh.ARRAY_WEIGHTS] = weights
		if not indices.is_empty():
			surf[Mesh.ARRAY_INDEX] = indices
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surf)
		out.surface_set_name(out.get_surface_count() - 1, "cut" if inner else "outside")
		vertex_total += positions.size()
	# Skip slivers: they add physics bodies without reading as pieces.
	if vertex_total < 12 or out.get_aabb().get_longest_axis_size() < 0.03:
		return {}
	return {"mesh": out}
