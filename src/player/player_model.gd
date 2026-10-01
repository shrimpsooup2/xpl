class_name PlayerModel
extends Node3D
## The player's body: one smooth, blobby, joint-free white figure (see
## BodyShape) skinned to the Universal Animation Library rig, with a glowing
## heart on its chest.
##
## Its arms can hold a weapon and aim, punch, and throw over whatever the
## legs are doing, and a shot knocks the part it hits (react_to_hit()),
## both through BodyLayers.
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
## Hit reactions: how far (radians) a full-strength hit knocks each part.
const KNOCK_HEAD := 0.8
const KNOCK_CHEST := 0.5
const KNOCK_GUT := 0.55
const KNOCK_ARM := 1.1
const KNOCK_LEG := 0.75
## Where a two-handed gun's grip sits from the right shoulder, in aim space
## (x right, y up, -z forward): the stock tucked into the shoulder.
const SHOULDERED := Vector3(0.02, -0.1, -0.26)
## Guns in other players' hands are drawn a bit big, so you can tell what
## someone's carrying across the map (GDD §7.6).
const HELD_SCALE := 1.25
## The team triangle hovers this far over the head bone.
const MARKER_OVER_HEAD := 0.62
## The nametag floats this far over the head's centre (over the marker too).
const NAMETAG_OVER_HEAD := 0.92
## Past this far the nametag isn't drawn.
const NAMETAG_RANGE := 70.0
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
## The heart: a tiny CRT in the chest (Heart). Its origin is the
## heart's hit centre.
var heart: Heart
var layers: BodyLayers
var hits: HitShapes
## The weapon in its hands (third person), or null.
var held: WeaponModel
## Its hat (null with no hat), and the team triangle shown instead.
var hat: Node3D
var marker: Node3D
## The colour its hat or marker is in (see dress()).
var tint := Hats.TEAM_COLORS[Hats.Team.RED]
var hat_id := Hats.NONE
## The name floating over its head (see set_nametag()), or null.
var nametag: Label3D

var _rig: Node3D
var _skin: Skin
var _chunk_rig: MeshInstance3D
var _fragments: Array[RigidBody3D] = []
var _falling := false
var _fall_tween: Tween
var _body_material := StandardMaterial3D.new()
var _cut_material := StandardMaterial3D.new()
var _heart_mount: BoneAttachment3D
var _heart_rest := Transform3D.IDENTITY
var _fragment_physics := PhysicsMaterial.new()
var _aim_pitch := 0.0
var _aim_yaw := 0.0
var _hat_mount: BoneAttachment3D
var _dressed := false
var _marker_time := 0.0


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
	_hat_mount = BoneAttachment3D.new()
	_hat_mount.name = "HatMount"
	_hat_mount.bone_name = "DEF-head"
	skeleton.add_child(_hat_mount)
	layers = BodyLayers.new()
	layers.name = "Layers"
	skeleton.add_child(layers)
	layers.modification_processed.connect(_on_posed)
	hits = HitShapes.for_body(skeleton, heart)
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
	heart.speed = speed
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


func _process(delta: float) -> void:
	if hat:
		Hats.animate(hat, delta)
	if marker and marker.visible:
		# Hovers over the head wherever the head is, bobbing a touch.
		_marker_time += delta
		var head := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("DEF-head")).origin
		marker.global_position = head + Vector3.UP * (MARKER_OVER_HEAD + sin(_marker_time * 2.4) * 0.025)
		var cam := get_viewport().get_camera_3d()
		if cam:
			Hats.face_marker(marker, cam.global_position)
	if nametag and nametag.visible:
		var head := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("DEF-head")).origin
		nametag.global_position = head + Vector3.UP * NAMETAG_OVER_HEAD


# --- Hat, colour and name -----------------------------------------------------

## Dresses it in hat `id` in `with_tint` (a team's colour, or the colour its
## player picked); with no hat (Hats.NONE) a triangle in that colour hovers
## over the head instead.
func dress(id: StringName, with_tint: Color) -> void:
	hat_id = id
	tint = with_tint
	_dressed = true
	if hat:
		hat.queue_free()
		hat = null
	if marker:
		marker.queue_free()
		marker = null
	hat = Hats.build(id, tint)
	if hat:
		_hat_mount.add_child(hat)
		# Hat space (y up, -z forward, from the head's centre) into the head
		# bone's space; the rig faces +Z.
		var rest := skeleton.get_bone_global_rest(skeleton.find_bone("DEF-head"))
		hat.transform = rest.affine_inverse() * Transform3D(Basis(Vector3.UP, PI), rest.origin + BodyShape.HEAD_OFFSET)
	else:
		marker = Hats.build_marker(tint)
		marker.top_level = true
		add_child(marker)
		marker.visible = not _falling


## Floats `text` over its head in `with_tint` (lightened to read on dark
## backgrounds), or takes the tag away with "". A tag `through_walls` (a
## teammate's) shows through the world; any other only while its head is in
## sight. Gone while the body is in pieces, and past NAMETAG_RANGE.
func set_nametag(text: String, with_tint: Color, through_walls := false) -> void:
	if nametag == null:
		nametag = Label3D.new()
		nametag.name = "Nametag"
		nametag.top_level = true
		nametag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		nametag.fixed_size = true
		nametag.pixel_size = 0.0009
		nametag.font = LofiUI.FONT
		nametag.font_size = 34
		nametag.outline_size = 10
		nametag.outline_modulate = Color(0.04, 0.04, 0.06)
		nametag.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		nametag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nametag.visibility_range_end = NAMETAG_RANGE
		add_child(nametag)
	nametag.text = text
	nametag.modulate = with_tint.lerp(Color.WHITE, 0.45)
	nametag.no_depth_test = through_walls
	nametag.render_priority = 2 if through_walls else 0
	nametag.visible = not text.is_empty() and not _falling


## The hat flies off as the body falls apart.
func _pop_hat(look_from: Vector3) -> void:
	if marker:
		marker.visible = false
	if nametag:
		nametag.visible = false
	if hat == null:
		return
	var at := hat.global_transform
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in hat.find_children("*", "MeshInstance3D", false, false):
		var b := mi.transform * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var piece := RigidBody3D.new()
	piece.collision_layer = FRAGMENT_LAYER
	piece.collision_mask = WORLD_LAYER | FRAGMENT_LAYER
	piece.mass = 0.3
	piece.physics_material_override = _fragment_physics
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size.max(Vector3.ONE * 0.05)
	col.shape = shape
	col.position = box.get_center()
	piece.add_child(col)
	_fragment_parent().add_child(piece)
	piece.global_transform = at
	hat.get_parent().remove_child(hat)
	piece.add_child(hat)
	hat.transform = Transform3D.IDENTITY
	var away := look_from - at.origin
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	piece.linear_velocity = Vector3.UP * randf_range(3.0, 4.2) - away * randf_range(0.6, 1.4) + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
	piece.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-4, 4), randf_range(-6, 6))
	_fragments.append(piece)
	hat = null


# --- Hits --------------------------------------------------------------------

## The body part the segment from → to hits first, or {} (see HitShapes).
## Hidden or not: your own body is hidden from you in first person, and
## everyone else can still shoot it.
func ray_test(from: Vector3, to: Vector3) -> Dictionary:
	if _falling:
		return {}
	return hits.ray_test(from, to)


## Takes a hit on `part` at `point` from a shot travelling along
## `direction`: the part is knocked away from the shot and springs back.
## Head and chest hits also play the matching flinch clip over the upper
## body; a leg hit buckles the knee and drops the hips. strength ~ damage / 40
## (square-rooted, so small hits still show).
func react_to_hit(part: StringName, point: Vector3, direction: Vector3, strength: float) -> void:
	if _falling:
		return
	heart.hurt()
	var s := clampf(sqrt(maxf(strength, 0.0)), 0.35, 1.4)
	var dir := direction.normalized()
	var clip_weight := clampf(0.45 + s * 0.4, 0.0, 1.0)
	match part:
		&"head", &"neck":
			layers.play(&"Hit_Head", BodyLayers.UPPER_BODY, 1.3, 0.0, 0.0, 0.03, 0.15, clip_weight)
			_knock("DEF-neck", point, dir, KNOCK_HEAD * 0.6 * s)
			_knock("DEF-head", point, dir, KNOCK_HEAD * s)
		&"chest":
			layers.play(&"Hit_Chest", BodyLayers.UPPER_BODY, 1.2, 0.0, 0.0, 0.03, 0.15, clip_weight)
			_knock("DEF-spine.002", point, dir, KNOCK_CHEST * s)
		&"gut":
			layers.play(&"Hit_Chest", BodyLayers.UPPER_BODY, 1.2, 0.0, 0.0, 0.03, 0.15, clip_weight * 0.6)
			_knock("DEF-spine.001", point, dir, KNOCK_GUT * s)
			layers.dip(Vector3.DOWN * 0.03 * s)
		&"arm_L", &"arm_R":
			var side := String(part).right(1)
			_knock("DEF-upper_arm." + side, point, dir, KNOCK_ARM * s)
			_knock("DEF-forearm." + side, point, dir, KNOCK_ARM * 0.8 * s)
			_knock("DEF-spine.003", point, dir, KNOCK_CHEST * 0.4 * s)
		&"leg_L", &"leg_R":
			var side := String(part).right(1)
			_knock("DEF-thigh." + side, point, dir, KNOCK_LEG * s)
			_knock("DEF-shin." + side, point, dir, KNOCK_LEG * 0.9 * s)
			_knock("DEF-spine.001", point, dir, KNOCK_GUT * 0.3 * s)
			layers.dip(Vector3.DOWN * 0.08 * s)


## Knocks a bone so the point that was hit moves along the shot.
func _knock(bone_name: String, point: Vector3, dir: Vector3, angle: float) -> void:
	var bone := skeleton.find_bone(bone_name)
	var origin := skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin
	var arm := point - origin
	var axis := arm.cross(dir)
	if axis.length() < 0.01:
		axis = Vector3.UP.cross(dir)
	layers.flinch(bone_name, axis, angle)


# --- Holding weapons (third person) ------------------------------------------

## Puts `def` in its hands (null or fists: empty-handed, arms free).
func hold(def: WeaponDef) -> void:
	if held:
		held.queue_free()
		held = null
	for key: StringName in [&"aim", &"aim_up", &"aim_down", &"guard"]:
		layers.clear_pose(key)
	layers.set_arm_ik("L", Transform3D(), 0.0, Vector3.DOWN)
	layers.set_arm_ik("R", Transform3D(), 0.0, Vector3.DOWN)
	if def and not def.is_fists():
		held = WeaponModel.new(def)
		held.top_level = true
		add_child(held)
		held.scale = Vector3.ONE * HELD_SCALE


## Aims the arms (and the held gun) at `pitch` radians; call every frame.
## Guns: the pistol aim poses blended by pitch. Two-handed guns are also
## shouldered, both hands on them by IK. Fists: a loose guard.
func aim(pitch: float, has_fists: bool) -> void:
	_aim_pitch = pitch
	_aim_yaw = rotation.y
	if _falling:
		return
	if has_fists:
		layers.set_pose(&"guard", &"Punch_Enter", 0.8, 0.7, BodyLayers.BOTH_ARMS)
		return
	if held == null:
		return
	var up := clampf(pitch / deg_to_rad(80.0), 0.0, 1.0)
	var down := clampf(-pitch / deg_to_rad(80.0), 0.0, 1.0)
	layers.set_pose(&"aim", &"Pistol_Aim_Neutral", 0.0, 1.0)
	layers.set_pose(&"aim_up", &"Pistol_Aim_Up", 0.0, up)
	layers.set_pose(&"aim_down", &"Pistol_Aim_Down", 0.0, down)
	var aim_basis := _aim_basis()
	if held.def.hold == WeaponDef.Hold.TWO_HAND:
		var shoulder := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("DEF-upper_arm.R")).origin
		var grip := Transform3D(aim_basis, shoulder + aim_basis * SHOULDERED)
		layers.set_arm_ik("R", grip, 1.0, aim_basis * Vector3(0.6, -1, 0.3), false)
		layers.set_arm_ik("L", Transform3D(aim_basis, held.fore.global_position), 1.0, aim_basis * Vector3(-0.6, -1, 0.2), false)


## A shot: the gun cycles and the arms take the kick.
func fire_pose() -> void:
	if held:
		held.fire()
		layers.play(&"Pistol_Shoot", BodyLayers.BOTH_ARMS, 1.6, 0.0, 0.35, 0.02, 0.1, 0.8)


## A punch with the left or right: a straight (jab or cross), a hook, or an
## uppercut (see WeaponHolder.PUNCH_KINDS). The rig has clips for the jab and
## cross; hooks and uppercuts add a swing on top with the flinch springs, the
## torso turning across and the elbow coming up for a hook, the hips dipping
## and the chest rising for an uppercut.
func punch(left: bool, kind := &"straight") -> void:
	if left:
		layers.play(&"Punch_Jab", BodyLayers.UPPER_BODY, 2.0, 0.0, 0.6, 0.03, 0.1)
	else:
		layers.play(&"Punch_Cross", BodyLayers.UPPER_BODY, 2.0, 0.0, 0.7, 0.03, 0.1)
	var side := "L" if left else "R"
	var out := -1.0 if left else 1.0  # Toward the punching arm's side.
	var forward := -global_basis.z
	match kind:
		&"hook":
			layers.flinch("DEF-spine.003", Vector3.UP, 0.5 * out)
			layers.flinch("DEF-upper_arm." + side, forward, 0.8 * out)
		&"uppercut":
			layers.dip(Vector3.DOWN * 0.05)
			layers.flinch("DEF-spine.003", global_basis.x, 0.35)
			layers.flinch("DEF-forearm." + side, global_basis.x, 0.6)


## Throwing the weapon away.
func throw_pose() -> void:
	layers.play(&"Punch_Cross", BodyLayers.UPPER_BODY, 1.6, 0.0, 0.6, 0.03, 0.12)


func _aim_basis() -> Basis:
	return Basis.from_euler(Vector3(_aim_pitch, _aim_yaw, 0.0))


## Runs once the body is fully posed each frame (the skeleton puts the
## animation's pose back afterwards): the hit shapes take this pose, and the
## held gun goes in the right hand, pointing where it aims.
func _on_posed() -> void:
	hits.capture()
	_place_held()


func _place_held() -> void:
	if held == null or not is_instance_valid(held):
		return
	var hand := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("DEF-hand.R"))
	var tip := hand.origin + (hand.basis.y.normalized() * BodyShape.ARM_TIP * 0.5)
	held.global_transform = Transform3D(_aim_basis().scaled(Vector3.ONE * HELD_SCALE), tip)


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
	if held:
		held.visible = false
	if nametag:
		nametag.visible = false
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
	if heart.get_parent() != _heart_mount:
		heart.reparent(_heart_mount, false)  # Before the fragment carrying it goes.
	for f in _fragments:
		if is_instance_valid(f):
			f.queue_free()
	_fragments.clear()
	_rig.position = Vector3.ZERO
	body.visible = true
	if heart.get_parent() != _heart_mount:
		heart.reparent(_heart_mount, false)  # Out of the fragment that carried it.
	heart.transform = _heart_rest
	heart.visible = true
	heart.revive()
	_falling = false
	anim.speed_scale = 1.0
	anim.play(ANIM_IDLE)
	layers.stop_actions()
	if held:
		held.visible = true
	if _dressed:
		dress(hat_id, tint)  # A fresh hat (the old one flew off), or the triangle back.
	if nametag:
		nametag.visible = not nametag.text.is_empty()


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
	_pop_hat(look_from)


## Its owner's health (0..1), for the heart's beat and picture.
func set_health(fraction: float) -> void:
	heart.health = clampf(fraction, 0.0, 1.0)


## Its owner died: the heart switches off (a heartshot) or loses its signal.
func heart_stops(heartshot: bool) -> void:
	heart.stop(heartshot)


## The heart pops out and bounces toward whoever is watching, still showing
## how it ended.
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
	var ball := SphereShape3D.new()
	ball.radius = Heart.RING_RADIUS + Heart.DOT_RADIUS
	col.shape = ball
	piece.add_child(col)
	_fragment_parent().add_child(piece)
	piece.global_transform = heart.global_transform
	heart.leave_socket()
	heart.reparent(piece, true)
	piece.linear_velocity = toward * 2.4 + Vector3.UP * 3.8
	piece.angular_velocity = Vector3(randf(), randf(), randf()) * 6.0
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
	_heart_mount = BoneAttachment3D.new()
	_heart_mount.name = "HeartMount"
	_heart_mount.bone_name = BodyShape.HEART_BONE
	skeleton.add_child(_heart_mount)
	heart = Heart.new()
	heart.name = "Heart"
	heart.drop_into = _fragment_parent
	_heart_rest = rest.affine_inverse() * Transform3D(Basis.IDENTITY, rest.origin + BodyShape.HEART_OFFSET)
	heart.transform = _heart_rest
	_heart_mount.add_child(heart)


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
