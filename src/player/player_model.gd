class_name PlayerModel
extends Node3D
## The player's body: one smooth, blobby, joint-free white figure (see
## BodyShape) skinned to the Universal Animation Library rig, with a glowing
## heart on its chest.
##
## When it dies it is swapped for one of the pre-diced chunk sets, posed
## exactly like the body at that moment. The chunks slide apart a hair along
## the cuts, then the whole thing crumbles (see fall_apart()).
##
## Top-level node: the owner moves it to its interpolated position each frame
## with follow(), so it stays smooth between physics ticks.

signal fell_apart

const Mode := MovementState.Mode
const BODY_MESH := preload("res://assets/characters/player_body.res")
const CHUNK_SETS := [
	preload("res://assets/characters/player_chunks_0.res"),
	preload("res://assets/characters/player_chunks_1.res"),
	preload("res://assets/characters/player_chunks_2.res"),
]
const BODY_COLOR := Color(0.95, 0.95, 0.97)
const CUT_COLOR := Color(0.84, 0.82, 0.88)
const HEART_COLOR := Color(1.0, 0.22, 0.42)
const FRAGMENT_LAYER := 1 << 1
const WORLD_LAYER := 1
const BLEND := 0.15

## Locomotion clips by name in the animation library.
const ANIM_IDLE := &"Idle"
const ANIM_WALK := &"Walk"
const ANIM_JOG := &"Jog_Fwd"
const ANIM_SPRINT := &"Sprint"
const ANIM_CROUCH_IDLE := &"Crouch_Idle"
const ANIM_CROUCH_MOVE := &"Crouch_Fwd"
const ANIM_AIR := &"Jump"
const ANIM_HIT := &"Hit_Chest"
const ANIM_DANCE := &"Dance"
## Speeds (m/s) the clips were animated at, for matching playback speed.
## The legs are short, so the stride is too.
const WALK_CLIP_SPEED := 1.1
const JOG_CLIP_SPEED := 2.9
const SPRINT_CLIP_SPEED := 5.0

# Crumble tuning.
const DANCE_TIME := 0.85
const SHIVER_TIME := 0.35
const SHIVER_AMOUNT := 0.012
## Pieces slide this far apart along the cuts before they fall.
const SEPARATE_DISTANCE := 0.035
const SEPARATE_TIME := 0.3
const CRUMBLE_SPEED := 1.1
const CRUMBLE_SPIN := 3.0
const HULL_POINTS := 40
const SETTLE_TIME := 1.5  # From the crumble until fell_apart is emitted.

## Per chunk set: every chunk merged into one skinned mesh, so one native
## bake poses them all. {"mesh": ArrayMesh, "ranges": [Vector2i(first, count)], "cut": [bool]}
static var _combined := {}

var anim: AnimationPlayer
var skeleton: Skeleton3D
var body: MeshInstance3D
var heart: MeshInstance3D

var _rig: Node3D
var _skin: Skin
var _chunk_rig: MeshInstance3D
var _fragments: Array[RigidBody3D] = []
var _falling := false
var _fall_tween: Tween
var _body_material := StandardMaterial3D.new()
var _cut_material := StandardMaterial3D.new()
var _heart_material := StandardMaterial3D.new()
var _fragment_physics := PhysicsMaterial.new()


func _ready() -> void:
	top_level = true
	_rig = BodyShape.RIG_SCENE.instantiate()
	_rig.rotation.y = PI  # The rig faces +Z; our forward is -Z.
	add_child(_rig)
	anim = _rig.find_children("*", "AnimationPlayer", true, false)[0]
	skeleton = _rig.find_children("*", "Skeleton3D", true, false)[0]
	for mesh in skeleton.find_children("*", "MeshInstance3D", false, false):
		mesh.visible = false  # The library's mannequin; we use our own body.
	BodyShape.reshape_skeleton(skeleton)
	BodyShape.scale_hips_animation(anim)
	anim.get_animation(ANIM_HIT).loop_mode = Animation.LOOP_NONE

	_body_material.albedo_color = BODY_COLOR
	_body_material.roughness = 0.2
	_body_material.metallic_specular = 0.7
	_body_material.rim_enabled = true
	_body_material.rim = 0.3
	_cut_material.albedo_color = CUT_COLOR
	_cut_material.roughness = 0.6
	_heart_material.albedo_color = HEART_COLOR
	_heart_material.emission_enabled = true
	_heart_material.emission = HEART_COLOR
	_heart_material.emission_energy_multiplier = 2.5
	_fragment_physics.bounce = 0.25
	_fragment_physics.friction = 0.9

	_skin = skeleton.create_skin_from_rest_transforms()
	body = _skinned_instance(BODY_MESH)
	body.name = "Body"
	body.material_override = _body_material
	# Holds a merged chunk set for posing at death. Created now because the
	# skin has to be registered with the skeleton before it can be baked.
	_chunk_rig = _skinned_instance(_combined_for(0).mesh)
	_chunk_rig.name = "ChunkPoser"
	_chunk_rig.visible = false
	_build_heart()
	anim.play(ANIM_IDLE)


## Moves the body to the owner's (interpolated) feet position and facing.
func follow(feet: Vector3, yaw: float) -> void:
	if _falling:
		return
	global_position = feet
	rotation = Vector3(0.0, yaw, 0.0)


## Picks a locomotion clip from the movement state.
func animate_movement(state: MovementState, velocity: Vector3) -> void:
	if _falling:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	var clip := ANIM_IDLE
	var rate := 1.0
	match state.mode:
		Mode.GROUND:
			if state.crouched:
				clip = ANIM_CROUCH_MOVE if speed > 0.5 else ANIM_CROUCH_IDLE
			elif speed < 0.4:
				clip = ANIM_IDLE
			elif speed < 3.0:
				clip = ANIM_WALK
				rate = speed / WALK_CLIP_SPEED
			elif speed < 9.0:
				clip = ANIM_JOG
				rate = speed / JOG_CLIP_SPEED
			else:
				clip = ANIM_SPRINT
				rate = speed / SPRINT_CLIP_SPEED
		Mode.SLIDE, Mode.MANTLE:
			clip = ANIM_CROUCH_IDLE
		Mode.DASH, Mode.WALLRIDE:
			clip = ANIM_SPRINT
			rate = 1.3
		_:
			clip = ANIM_AIR
	if anim.current_animation != clip:
		anim.play(clip, BLEND)
	anim.speed_scale = clampf(rate, 0.5, 2.5)


# --- Falling apart ------------------------------------------------------------

## The body is revealed to have been diced all along: it freezes, shivers,
## hairline cuts open up, and it crumbles into a heap while the heart pops
## out toward `look_from`. With `performance` it does a little dance first
## (the dead player's own view); without, it just takes the hit and crumbles.
func fall_apart(performance: bool, look_from: Vector3) -> void:
	if _falling:
		return
	_falling = true
	anim.speed_scale = 1.0
	var t := create_tween()
	_fall_tween = t
	if performance:
		anim.play(ANIM_DANCE, 0.1)
		t.tween_interval(DANCE_TIME)
	else:
		anim.play(ANIM_HIT, 0.05)
		t.tween_interval(0.25)
	t.tween_callback(anim.pause)
	t.tween_method(_shiver, 1.0, 0.0, SHIVER_TIME if performance else 0.1)
	t.tween_callback(_dice)
	t.tween_interval(SEPARATE_TIME if performance else 0.12)
	t.tween_callback(_crumble.bind(look_from))
	t.tween_interval(SETTLE_TIME)
	t.tween_callback(fell_apart.emit)


## Puts the body back together and clears the fragments.
func reassemble() -> void:
	if _fall_tween:
		_fall_tween.kill()
		_fall_tween = null
	for f in _fragments:
		if is_instance_valid(f):
			f.queue_free()
	_fragments.clear()
	_rig.position = Vector3.ZERO
	body.visible = true
	heart.visible = true
	_falling = false
	anim.speed_scale = 1.0
	anim.play(ANIM_IDLE)


func fragments() -> Array[RigidBody3D]:
	return _fragments


func _shiver(amount: float) -> void:
	_rig.position = Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)) * SHIVER_AMOUNT * amount


## Swaps the body for a chunk set posed exactly like it. The chunks start
## frozen and slide apart slightly so the cuts show.
func _dice() -> void:
	var combined := _combined_for(randi() % CHUNK_SETS.size())
	_chunk_rig.mesh = combined.mesh
	# The engine poses skinned meshes natively, but only with a real renderer;
	# headless runs (tests, servers) pose on the CPU instead.
	var posed: ArrayMesh
	if DisplayServer.get_name() == "headless":
		posed = _pose_on_cpu(combined.mesh)
	else:
		posed = _chunk_rig.bake_mesh_from_current_skeleton_pose()
	if posed == null:
		push_warning("PlayerModel: couldn't pose the chunks; hiding the body instead.")
		body.visible = false
		return
	var to_world := _chunk_rig.global_transform
	var middle := global_position + Vector3.UP * 0.9
	var parent := _fragment_parent()

	for c in combined.ranges.size():
		var r: Vector2i = combined.ranges[c]
		var mesh := ArrayMesh.new()
		var hull := PackedVector3Array()
		for s in range(r.x, r.x + r.y):
			var arrays := posed.surface_get_arrays(s)
			arrays[Mesh.ARRAY_BONES] = null
			arrays[Mesh.ARRAY_WEIGHTS] = null
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(mesh.get_surface_count() - 1, _cut_material if combined.cut[s] else _body_material)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var step := maxi(1, verts.size() / HULL_POINTS)
			for i in range(0, verts.size(), step):
				hull.append(verts[i])
		var local_center := mesh.get_aabb().get_center()
		var piece := RigidBody3D.new()
		piece.collision_layer = FRAGMENT_LAYER
		piece.collision_mask = WORLD_LAYER | FRAGMENT_LAYER
		piece.physics_material_override = _fragment_physics
		piece.freeze = true
		piece.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		piece.mass = maxf(mesh.get_aabb().get_volume() * 40.0, 0.05)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = -local_center
		piece.add_child(mi)
		var col := CollisionShape3D.new()
		var shape := ConvexPolygonShape3D.new()
		shape.points = hull
		col.shape = shape
		col.position = -local_center
		piece.add_child(col)
		parent.add_child(piece)
		var world_center := to_world * local_center
		piece.global_transform = Transform3D(to_world.basis, world_center)
		_fragments.append(piece)
		var away := (world_center - middle).normalized() * SEPARATE_DISTANCE
		piece.create_tween().tween_property(piece, "global_position", world_center + away, SEPARATE_TIME * 0.8) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	body.visible = false


## Linear-blend skinning of `mesh` (in skeleton space) to the current pose.
func _pose_on_cpu(mesh: ArrayMesh) -> ArrayMesh:
	var palette: Array[Transform3D] = []
	for b in skeleton.get_bone_count():
		palette.append(skeleton.get_bone_global_pose(b) * skeleton.get_bone_global_rest(b).affine_inverse())
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		for i in verts.size():
			var p := Vector3.ZERO
			var n := Vector3.ZERO
			for k in 4:
				var w := weights[i * 4 + k]
				if w > 0.0:
					var m := palette[bones[i * 4 + k]]
					p += (m * verts[i]) * w
					n += (m.basis * normals[i]) * w
			verts[i] = p
			normals[i] = n.normalized()
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


func _crumble(look_from: Vector3) -> void:
	var middle := global_position + Vector3.UP * 0.9
	for piece in _fragments:
		if not is_instance_valid(piece):
			continue
		piece.freeze = false
		var away := piece.global_position - middle
		away.y = 0.0
		piece.linear_velocity = away.normalized() * randf_range(0.2, CRUMBLE_SPEED) + Vector3.UP * randf_range(0.0, 0.6)
		piece.angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * CRUMBLE_SPIN
	_pop_heart(look_from)


## The heart pops out and bounces toward whoever is watching.
func _pop_heart(look_from: Vector3) -> void:
	var toward := look_from - heart.global_position
	toward.y = 0.0
	toward = toward.normalized() if toward.length() > 0.01 else -global_basis.z
	var piece := RigidBody3D.new()
	piece.collision_layer = FRAGMENT_LAYER
	piece.collision_mask = WORLD_LAYER | FRAGMENT_LAYER
	piece.physics_material_override = PhysicsMaterial.new()
	piece.physics_material_override.bounce = 0.6
	piece.mass = 0.2
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = BodyShape.HEART_RADIUS
	col.shape = sphere
	piece.add_child(col)
	var mi := MeshInstance3D.new()
	mi.mesh = heart.mesh
	mi.material_override = _heart_material
	piece.add_child(mi)
	_fragment_parent().add_child(piece)
	piece.global_position = heart.global_position
	piece.linear_velocity = toward * 2.4 + Vector3.UP * 3.8
	piece.angular_velocity = Vector3(randf(), randf(), randf()) * 6.0
	heart.visible = false
	_fragments.append(piece)


func _fragment_parent() -> Node:
	var p := get_parent()
	return p.get_parent() if p and p.get_parent() else get_tree().current_scene


# --- Building ---------------------------------------------------------------

func _skinned_instance(mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	skeleton.add_child(mi)
	mi.skin = _skin
	mi.skeleton = mi.get_path_to(skeleton)
	return mi


func _build_heart() -> void:
	var bone := skeleton.find_bone(BodyShape.HEART_BONE)
	var rest := skeleton.get_bone_global_rest(bone)
	var attach := BoneAttachment3D.new()
	attach.bone_name = BodyShape.HEART_BONE
	skeleton.add_child(attach)
	var sphere := SphereMesh.new()
	sphere.radius = BodyShape.HEART_RADIUS
	sphere.height = BodyShape.HEART_RADIUS * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	heart = MeshInstance3D.new()
	heart.name = "Heart"
	heart.mesh = sphere
	heart.material_override = _heart_material
	var xform := Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.8)), rest.origin + BodyShape.HEART_OFFSET)
	heart.transform = rest.affine_inverse() * xform
	attach.add_child(heart)


static func _combined_for(index: int) -> Dictionary:
	if _combined.has(index):
		return _combined[index]
	var set: ChunkSet = CHUNK_SETS[index]
	var mesh := ArrayMesh.new()
	var ranges: Array[Vector2i] = []
	var cut: Array[bool] = []
	for chunk in set.meshes:
		var first := mesh.get_surface_count()
		for s in chunk.get_surface_count():
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, chunk.surface_get_arrays(s))
			cut.append(chunk.surface_get_name(s) == "cut")
		ranges.append(Vector2i(first, chunk.get_surface_count()))
	_combined[index] = {"mesh": mesh, "ranges": ranges, "cut": cut}
	return _combined[index]
