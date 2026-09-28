class_name CombatFx
extends RefCounted
## Shooting effects: muzzle flashes, spent casings, sparks and holes where
## shots hit the world, and white splashes where they hit a body. All
## additive or flat, short-lived, and cheap. (Damage numbers: DamageNumber.)

const TRACER_COLOR := Color(1.0, 0.92, 0.7)
const SPARK_COLOR := Color(1.0, 0.8, 0.45)
const HOLE_COLOR := Color(0.06, 0.05, 0.08)
const HOLE_LIFE := 10.0
const MAX_HOLES := 80
const BRASS := Color(0.86, 0.66, 0.26)

static var _flash_materials := {}
static var _box: BoxMesh
static var _quad: QuadMesh
static var _sphere: SphereMesh
static var _hole_material: StandardMaterial3D
static var _holes: Array[Node3D] = []
static var _puff_tex: ImageTexture


## Additive, unlit (res://src/render/flash.gdshader); tint is per instance.
static func flash_material(viewmodel := false) -> ShaderMaterial:
	if not _flash_materials.has(viewmodel):
		var m := ShaderMaterial.new()
		m.shader = preload("res://src/render/flash.gdshader")
		m.set_shader_parameter(&"viewmodel", viewmodel)
		_flash_materials[viewmodel] = m
	return _flash_materials[viewmodel]


static func unit_box() -> BoxMesh:
	if _box == null:
		_box = BoxMesh.new()
	return _box


## A star of crossed quads at the muzzle for two frames, and a light that
## pops on the world around it. `muzzle` carries the flash with the gun.
static func muzzle_flash(muzzle: Node3D, viewmodel: bool, size := 1.0, light_at: Variant = null) -> void:
	var star := Node3D.new()
	muzzle.add_child(star)
	star.rotation.z = randf() * TAU
	var s := size * randf_range(0.8, 1.15)
	for i in 3:
		var q := MeshInstance3D.new()
		q.mesh = _quad_mesh()
		q.material_override = flash_material(viewmodel)
		q.set_instance_shader_parameter(&"tint", Color(1.0, 0.85, 0.5, 1.0) if i < 2 else Color(1, 1, 1, 1))
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		match i:
			0:  # Facing the viewer: the burst.
				q.scale = Vector3(0.14, 0.14, 1.0) * s
			1:  # Along the barrel, flat: the flame tongue, seen from above.
				q.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
				q.scale = Vector3(0.06, 0.22, 1.0) * s
				q.position.z = -0.08 * s
			2:  # Along the barrel, upright.
				q.rotation = Vector3(0.0, PI * 0.5, 0.0)
				q.scale = Vector3(0.2, 0.06, 1.0) * s
				q.position.z = -0.07 * s
		star.add_child(q)
	var t := star.create_tween()
	t.tween_property(star, "scale", Vector3.ONE * 1.3, 0.045)
	t.tween_callback(star.queue_free)
	var at: Vector3 = light_at if light_at != null else muzzle.global_position
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.5)
	light.light_energy = 2.5 * size
	light.omni_range = 5.0
	light.shadow_enabled = false
	_world_of(muzzle).add_child(light)
	light.global_position = at
	var lt := light.create_tween()
	lt.tween_property(light, "light_energy", 0.0, 0.07)
	lt.tween_callback(light.queue_free)


## A spent casing thrown out of the ejection port to the right, spinning,
## falling in `space`'s frame (the viewmodel, so it stays with the view).
static func casing(space: Node3D, at: Vector3, right: Vector3, up: Vector3, shell := false, color := BRASS) -> void:
	var c := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.012 if shell else 0.007
	mesh.bottom_radius = mesh.top_radius
	mesh.height = 0.05 if shell else 0.022
	mesh.radial_segments = 6
	mesh.rings = 1
	c.mesh = mesh
	c.material_override = WeaponModel.material(true)
	c.set_instance_shader_parameter(&"color", color)
	c.set_instance_shader_parameter(&"gloss", 0.8)
	c.set_instance_shader_parameter(&"roughness_amount", 0.15)
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	space.add_child(c)
	c.position = at
	var velocity := right * randf_range(1.2, 1.8) + up * randf_range(1.0, 1.5) + Vector3(0, 0, randf_range(0.0, 0.4))
	var spin := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(15.0, 25.0)
	var gravity := space.global_basis.inverse() * Vector3(0, -9.8, 0)
	var start_basis := Basis(Vector3.BACK, PI * 0.5)
	var t := c.create_tween()
	t.tween_method(func(time: float) -> void:
		c.position = at + velocity * time + gravity * (0.5 * time * time)
		c.basis = Basis.from_euler(spin * time) * start_basis, 0.0, 0.6, 0.6)
	t.tween_callback(c.queue_free)


## Where a shot hits the world: a spark burst, a puff, and a hole that
## lingers.
static func impact(world: Node, point: Vector3, normal: Vector3, size := 1.0) -> void:
	for i in 5:
		var dir := (normal + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.8).normalized()
		_fly(world, point + normal * 0.02, dir * randf_range(3.0, 7.0) * size, Vector3(0.018, 0.018, 0.018) * size,
				SPARK_COLOR, randf_range(0.1, 0.2), 9.8)
	_puff(world, point + normal * 0.05, normal, 0.25 * size, Color(0.8, 0.75, 0.7, 0.8))
	_hole(world, point, normal, 0.035 * sqrt(size))


## Where a shot hits a body: white blobs flicked off along the shot, pink
## ones from a heartshot.
static func body_hit(world: Node, point: Vector3, direction: Vector3, heart := false, size := 1.0) -> void:
	var color := PlayerModel.HEART_COLOR if heart else PlayerModel.BODY_COLOR
	for i in (8 if heart else 4):
		var dir := (direction + Vector3(randf_range(-1, 1), randf_range(-0.4, 1.0), randf_range(-1, 1)) * 0.7).normalized()
		_blob(world, point, dir * randf_range(1.5, 4.0), randf_range(0.02, 0.04) * size, color)
	_puff(world, point, -direction, 0.2 * size, Color(color, 0.9))


## Clears the lingering holes (tests, respawns).
static func clear_holes() -> void:
	for h in _holes:
		if is_instance_valid(h):
			h.queue_free()
	_holes.clear()


# --- Pieces -----------------------------------------------------------------

## A glowing chip flying out under gravity, shrinking away.
static func _fly(world: Node, at: Vector3, velocity: Vector3, size: Vector3, color: Color, life: float, gravity: float) -> void:
	var m := MeshInstance3D.new()
	m.mesh = unit_box()
	m.material_override = flash_material(false)
	m.set_instance_shader_parameter(&"tint", color)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(m)
	m.global_position = at
	var look := velocity.normalized()
	var basis := Basis.looking_at(look, Vector3.UP if absf(look.y) < 0.95 else Vector3.RIGHT)
	var t := m.create_tween()
	t.tween_method(func(time: float) -> void:
		var v := velocity + Vector3.DOWN * gravity * time
		m.global_position = at + velocity * time + Vector3.DOWN * gravity * 0.5 * time * time
		m.global_basis = Basis.looking_at(v.normalized() if v.length() > 0.01 else look, Vector3.UP if absf(v.normalized().y) < 0.95 else Vector3.RIGHT) \
				.scaled(Vector3(size.x, size.y, size.z * 3.0) * (1.0 - time / life)), 0.0, life, life)
	t.tween_callback(m.queue_free)
	m.global_basis = basis.scaled(size)


static func _blob(world: Node, at: Vector3, velocity: Vector3, radius: float, color: Color) -> void:
	var m := MeshInstance3D.new()
	if _sphere == null:
		_sphere = SphereMesh.new()
		_sphere.radius = 1.0
		_sphere.height = 2.0
		_sphere.radial_segments = 8
		_sphere.rings = 4
	m.mesh = _sphere
	m.material_override = WeaponModel.material(false)
	m.set_instance_shader_parameter(&"color", color)
	m.set_instance_shader_parameter(&"gloss", 0.5)
	m.set_instance_shader_parameter(&"glow", 0.6 if color == PlayerModel.HEART_COLOR else 0.0)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(m)
	m.global_position = at
	var life := randf_range(0.25, 0.4)
	var t := m.create_tween()
	t.tween_method(func(time: float) -> void:
		m.global_position = at + velocity * time + Vector3.DOWN * 4.9 * time * time
		m.scale = Vector3.ONE * radius * (1.0 - time / life), 0.0, life, life)
	t.tween_callback(m.queue_free)


static func _puff(world: Node, at: Vector3, normal: Vector3, radius: float, color: Color) -> void:
	var m := MeshInstance3D.new()
	m.mesh = _quad_mesh()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = color
	mat.albedo_texture = _puff_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(m)
	m.global_position = at
	m.scale = Vector3.ONE * radius * 0.5
	var t := m.create_tween().set_parallel()
	t.tween_property(m, "scale", Vector3.ONE * radius * 1.6, 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(m, "global_position", at + normal * radius * 0.6, 0.25)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(m.queue_free)


static func _hole(world: Node, point: Vector3, normal: Vector3, radius: float) -> void:
	if _hole_material == null:
		_hole_material = StandardMaterial3D.new()
		_hole_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_hole_material.albedo_color = HOLE_COLOR
	var m := MeshInstance3D.new()
	m.mesh = _quad_mesh()
	m.material_override = _hole_material
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(m)
	var up := Vector3.UP if absf(normal.y) < 0.95 else Vector3.FORWARD
	m.global_transform = Transform3D(Basis.looking_at(-normal, up).scaled(Vector3.ONE * radius * 2.0), point + normal * 0.004)
	m.rotate_object_local(Vector3.BACK, randf() * TAU)
	_holes.append(m)
	while _holes.size() > MAX_HOLES:
		var old: Node3D = _holes.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	m.create_tween().tween_callback(m.queue_free).set_delay(HOLE_LIFE)


static func _quad_mesh() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
	return _quad



## A small soft-edged dot, stepped so it stays pixel-crisp.
static func _puff_texture() -> ImageTexture:
	if _puff_tex == null:
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		for y in 8:
			for x in 8:
				var d := Vector2(x - 3.5, y - 3.5).length() / 4.0
				img.set_pixel(x, y, Color(1, 1, 1, 1.0 if d < 0.6 else (0.5 if d < 0.9 else 0.0)))
		_puff_tex = ImageTexture.create_from_image(img)
	return _puff_tex


static func _world_of(node: Node) -> Node:
	var n := node
	while n.get_parent() and n.get_parent() != node.get_tree().root:
		n = n.get_parent()
	return n
