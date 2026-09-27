extends SceneTree
## Generates the prototype's input map, data resources, and scenes.
##
##   godot --headless --path . --script res://tools/build_scenes.gd
##
## Re-running overwrites scenes/player.tscn, scenes/test_course.tscn and the
## input map. Data resources in data/ are only created if missing, so tuned
## values are never lost. Once you start hand-editing the test course in the
## editor, stop regenerating it (or pass --skip-course).

const KEY_ACTIONS := {
	&"move_forward": [KEY_W],
	&"move_back": [KEY_S],
	&"move_left": [KEY_A],
	&"move_right": [KEY_D],
	&"jump": [KEY_SPACE],
	&"crouch": [KEY_CTRL, KEY_C],
	&"dash": [KEY_SHIFT],
	&"interact": [KEY_E],
	&"throw_weapon": [KEY_Q],
	&"use_throwable": [KEY_G],
	&"weapon_primary": [KEY_1],
	&"weapon_fists": [KEY_2],
	&"scoreboard": [KEY_TAB],
	&"debug_tuning": [KEY_F1],
	&"debug_respawn": [KEY_F2],
	&"debug_vsync": [KEY_F3],
	&"debug_hud": [KEY_F4],
}
const MOUSE_ACTIONS := {
	&"fire": [MOUSE_BUTTON_LEFT],
	&"alt_fire": [MOUSE_BUTTON_RIGHT],
	&"jump": [MOUSE_BUTTON_WHEEL_DOWN],
	&"weapon_primary": [MOUSE_BUTTON_WHEEL_UP],
}

const K := GreyBox.Kind

var _root: Node3D
var _geometry: Node3D
var _labels: Node3D


func _initialize() -> void:
	_build_input_map()
	_ensure_resource("res://data/movement_params.tres", MovementParams.new())
	_ensure_resource("res://data/view_settings.tres", ViewSettings.new())
	_save_scene(_build_player(), "res://scenes/player.tscn")
	if not "--skip-course" in OS.get_cmdline_user_args():
		_save_scene(_build_test_course(), "res://scenes/test_course.tscn")
	quit()


# --- Input ------------------------------------------------------------------

func _build_input_map() -> void:
	var actions := {}
	for action: StringName in KEY_ACTIONS:
		for key: Key in KEY_ACTIONS[action]:
			var e := InputEventKey.new()
			e.device = -1  # Any device, as the editor saves actions.
			e.physical_keycode = key
			actions.get_or_add(action, []).append(e)
	for action: StringName in MOUSE_ACTIONS:
		for button: MouseButton in MOUSE_ACTIONS[action]:
			var e := InputEventMouseButton.new()
			e.device = -1
			e.button_index = button
			actions.get_or_add(action, []).append(e)
	for action: StringName in actions:
		ProjectSettings.set_setting("input/%s" % action, {"deadzone": 0.2, "events": actions[action]})
	var err := ProjectSettings.save()
	print("input map: ", error_string(err))


func _ensure_resource(path: String, res: Resource) -> void:
	if FileAccess.file_exists(path):
		print("kept ", path)
		return
	print("created ", path, ": ", error_string(ResourceSaver.save(res, path)))


func _save_scene(root: Node, path: String) -> void:
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, path)
	print("saved ", path, ": ", error_string(err))
	root.free()


func _own(node: Node) -> void:
	for child in node.get_children():
		child.owner = _root if _root else node
		_own(child)


# --- Player -----------------------------------------------------------------

func _build_player() -> Node:
	var player := CharacterBody3D.new()
	player.name = "Player"
	player.set_script(load("res://src/player/player.gd"))

	var col := CollisionShape3D.new()
	col.name = "Collision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	col.shape = capsule
	col.position = Vector3(0, 0.9, 0)
	player.add_child(col)

	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.position = Vector3(0, 1.6, 0)
	cam.near = 0.05
	cam.far = 500.0
	player.add_child(cam)

	for child in player.get_children():
		child.owner = player
	return player


# --- Test course --------------------------------------------------------------

func _build_test_course() -> Node:
	_root = Node3D.new()
	_root.name = "TestCourse"

	var env := WorldEnvironment.new()
	env.name = "WorldEnvironment"
	env.environment = _make_environment()
	_root.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52, 35, 0)
	sun.light_color = Color(1.0, 0.93, 0.86)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	_root.add_child(sun)

	_geometry = Node3D.new()
	_geometry.name = "Geometry"
	_root.add_child(_geometry)
	_labels = Node3D.new()
	_labels.name = "Labels"
	_root.add_child(_labels)

	_box("Floor", Vector3(0, -0.5, 0), Vector3(200, 1, 200), K.FLOOR)
	_run_lane()
	_steps()
	_stairs()
	_mantle_blocks()
	_slide_hill()
	_wall_corridor()
	_zigzag_walls()
	_smash_tower()
	_valley()
	_low_tunnel()

	var player: Node3D = load("res://scenes/player.tscn").instantiate()
	player.name = "Player"
	_root.add_child(player)

	var hud := CanvasLayer.new()
	hud.name = "DebugHUD"
	hud.set_script(load("res://src/debug/debug_hud.gd"))
	_root.add_child(hud)

	var tuning := CanvasLayer.new()
	tuning.name = "TuningPanel"
	tuning.set_script(load("res://src/debug/tuning_panel.gd"))
	_root.add_child(tuning)

	for child in _root.get_children():
		child.owner = _root
		if child != player:
			_own(child)
	var r := _root
	_root = null
	return r


func _make_environment() -> Environment:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.42, 0.40, 0.74)
	sky_mat.sky_horizon_color = Color(0.96, 0.76, 0.72)
	sky_mat.ground_horizon_color = Color(0.96, 0.76, 0.72)
	sky_mat.ground_bottom_color = Color(0.30, 0.24, 0.36)
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.4
	e.glow_bloom = 0.02
	e.fog_enabled = true
	e.fog_light_color = Color(0.90, 0.78, 0.82)
	e.fog_density = 0.005
	e.fog_sky_affect = 0.4
	return e


func _box(box_name: String, center: Vector3, size: Vector3, kind: GreyBox.Kind, rot_deg := Vector3.ZERO) -> void:
	var b := StaticBody3D.new()
	b.set_script(load("res://src/world/grey_box.gd"))
	b.name = box_name
	b.position = center
	b.rotation_degrees = rot_deg
	b.set(&"size", size)
	b.set(&"kind", kind)
	_geometry.add_child(b)


## A rotated box placed by the midpoint of its top surface, so slopes meet
## the ground and platforms exactly.
func _slab(box_name: String, top_mid: Vector3, size: Vector3, kind: GreyBox.Kind, rot_deg: Vector3) -> void:
	var up := Basis.from_euler(rot_deg * (PI / 180.0)) * Vector3.UP
	_box(box_name, top_mid - up * size.y * 0.5, size, kind, rot_deg)


func _label(text: String, pos: Vector3) -> void:
	var l := Label3D.new()
	l.name = text.validate_node_name().replace(" ", "_")
	l.text = text
	l.position = pos
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.font_size = 64
	l.pixel_size = 0.01
	l.outline_size = 16
	l.modulate = Color(1, 1, 1)
	l.outline_modulate = Color(0.15, 0.1, 0.25)
	_labels.add_child(l)


## Distance poles every 10 m straight ahead of spawn, for reading speed.
func _run_lane() -> void:
	_label("RUN LANE  (poles every 10 m)", Vector3(0, 3.5, -8))
	for i in range(1, 7):
		var z := -10.0 * i
		_box("Pole_L%d" % i, Vector3(-5, 1.5, z), Vector3(0.3, 3, 0.3), K.MARKER)
		_box("Pole_R%d" % i, Vector3(5, 1.5, z), Vector3(0.3, 3, 0.3), K.MARKER)


## Single steps of increasing height: 0.4 m and below should step up, 0.45 not.
func _steps() -> void:
	_label("STEPS  0.2 / 0.3 / 0.4 / 0.45", Vector3(14, 3, -6))
	var heights := [0.2, 0.3, 0.4, 0.45]
	for i in heights.size():
		var h: float = heights[i]
		_box("Step_%s" % str(h).replace(".", "_"), Vector3(10 + i * 3, h * 0.5, -12), Vector3(2.4, h, 6), K.LEDGE)


## A 2 m flight of stairs (8 × 0.25 m) up to a landing.
func _stairs() -> void:
	_label("STAIRS", Vector3(25, 3.5, -6))
	for i in 8:
		var h := 0.25 * (i + 1)
		_box("Stair_%d" % i, Vector3(25, h * 0.5, -10 - 0.35 * i - 0.175), Vector3(4, h, 0.35), K.WALL)
	_box("StairLanding", Vector3(25, 1.0, -14.3), Vector3(4, 2, 3), K.WALL)


## Blocks from 0.6 m to 2.6 m. Ground mantles go up to 1.2 m, air mantles to 2.0 m.
func _mantle_blocks() -> void:
	_label("MANTLE  0.6 → 2.6 m", Vector3(-14, 3.8, -6))
	var heights := [0.6, 1.0, 1.4, 1.8, 2.2, 2.6]
	for i in heights.size():
		var h: float = heights[i]
		_box("Ledge_%s" % str(h).replace(".", "_"), Vector3(-10 - i * 4, h * 0.5, -14), Vector3(3, h, 3), K.LEDGE)


## A 6 m platform with a 20° slide ramp down one side and a 30° walk-up on the other.
func _slide_hill() -> void:
	_label("SLIDE HILL", Vector3(0, 8, 24))
	_box("HillTop", Vector3(0, 3, 30), Vector3(8, 6, 6), K.RAMP)
	var slide_len := 6.0 / sin(deg_to_rad(20.0))
	var slide_run := 6.0 / tan(deg_to_rad(20.0))
	_slab("SlideRamp", Vector3(0, 3, 27 - slide_run * 0.5), Vector3(8, 0.7, slide_len), K.RAMP, Vector3(-20, 0, 0))
	var walk_len := 6.0 / sin(deg_to_rad(30.0))
	var walk_run := 6.0 / tan(deg_to_rad(30.0))
	_slab("WalkRamp", Vector3(0, 3, 33 + walk_run * 0.5), Vector3(8, 0.7, walk_len), K.RAMP, Vector3(30, 0, 0))


## Two parallel 6 m walls, 7 m apart, for wall ride chains.
func _wall_corridor() -> void:
	_label("WALL RIDE CORRIDOR", Vector3(38, 7, 2))
	_box("RideWall_A", Vector3(34.5, 3, -25), Vector3(1, 6, 50), K.RIDE)
	_box("RideWall_B", Vector3(42.5, 3, -25), Vector3(1, 6, 50), K.RIDE)


## Alternating short walls for wall jump chains.
func _zigzag_walls() -> void:
	_label("ZIGZAG WALL JUMPS", Vector3(56, 7, 2))
	for i in 6:
		var x := 52.0 if i % 2 == 0 else 60.0
		_box("ZigWall_%d" % i, Vector3(x, 4, -6 - i * 7), Vector3(1, 8, 6), K.RIDE)


## Platforms at 2, 4, 6, 8, 10 m. Jump + air mantle climbs them; smashdown off the top.
func _smash_tower() -> void:
	_label("SMASH TOWER  (climb, then smashdown)", Vector3(-30, 13, 22))
	for i in 5:
		var h := 2.0 * (i + 1)
		_box("Tower_%d" % i, Vector3(-22 - i * 3.2, h * 0.5, 22), Vector3(3, h, 3), K.TOWER)
	_box("TowerTop", Vector3(-38, 5, 22), Vector3(4, 10, 4), K.TOWER)


## Two facing 35° slopes: slide down one, up the other, back again.
func _valley() -> void:
	_label("SLIDE VALLEY", Vector3(30, 6, 30))
	var angle := 35.0
	var length := 10.0
	var rise := length * sin(deg_to_rad(angle))
	var run := length * cos(deg_to_rad(angle))
	_slab("ValleyLeft", Vector3(30 - run * 0.5, rise * 0.5, 34), Vector3(length, 0.7, 10), K.RAMP, Vector3(0, 0, -angle))
	_slab("ValleyRight", Vector3(30 + run * 0.5, rise * 0.5, 34), Vector3(length, 0.7, 10), K.RAMP, Vector3(0, 0, angle))


## A 1.2 m high tunnel: slide in, stay crouched until you come out.
func _low_tunnel() -> void:
	_label("LOW TUNNEL  (slide under)", Vector3(-12, 3, 8))
	_box("TunnelRoof", Vector3(-12, 1.45, 14), Vector3(4, 0.5, 8), K.WALL)
	_box("TunnelWall_L", Vector3(-14.25, 0.85, 14), Vector3(0.5, 1.7, 8), K.WALL)
	_box("TunnelWall_R", Vector3(-9.75, 0.85, 14), Vector3(0.5, 1.7, 8), K.WALL)
