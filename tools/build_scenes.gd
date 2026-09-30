extends SceneTree
## Generates the prototype's input map, data resources, and scenes.
##
##   godot --headless --path . --script res://tools/build_scenes.gd
##
## Re-running overwrites scenes/player.tscn, scenes/test_course.tscn and the
## input map. Data resources in data/ are only created if missing, so tuned
## values are never lost. Once you start hand-editing the test course in the
## editor, stop regenerating it (or pass --skip-course). ONLY=<map name> in
## the environment builds just that map (and the rest as above), to try a
## map's dressing quickly.

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
	&"debug_third_person": [KEY_F6],
	&"debug_die": [KEY_F7],
	&"debug_preview_ui": [KEY_F8],
	&"debug_next_map": [KEY_F9],
}
const MOUSE_ACTIONS := {
	&"fire": [MOUSE_BUTTON_LEFT],
	&"alt_fire": [MOUSE_BUTTON_RIGHT],
	&"jump": [MOUSE_BUTTON_WHEEL_DOWN],
	&"weapon_primary": [MOUSE_BUTTON_WHEEL_UP],
}

const K := GreyBox.Kind
const LevelKit := preload("res://tools/level_kit.gd")
const DecoKit := preload("res://tools/deco_kit.gd")
## The maps (GDD §9.3): each script's build(kit) lays it out and returns spawn A.
const MAPS := {
	"Stack": ["res://tools/maps/stack.gd", "res://scenes/maps/stack.tscn"],
	"Terrace": ["res://tools/maps/terrace.gd", "res://scenes/maps/terrace.tscn"],
	"Switchback": ["res://tools/maps/switchback.gd", "res://scenes/maps/switchback.tscn"],
	"Archipelago": ["res://tools/maps/archipelago.gd", "res://scenes/maps/archipelago.tscn"],
	"Rift": ["res://tools/maps/rift.gd", "res://scenes/maps/rift.tscn"],
	"Boulevard": ["res://tools/maps/boulevard.gd", "res://scenes/maps/boulevard.tscn"],
	"Holdfast": ["res://tools/maps/holdfast.gd", "res://scenes/maps/holdfast.tscn"],
	"Depot": ["res://tools/maps/depot.gd", "res://scenes/maps/depot.tscn"],
}

var _kit: LevelKit


func _initialize() -> void:
	_configure_rendering()
	_build_input_map()
	_ensure_resource("res://data/movement_params.tres", MovementParams.new())
	_ensure_resource("res://data/view_settings.tres", ViewSettings.new())
	_save_scene(_build_player(), "res://scenes/player.tscn")
	if not "--skip-course" in OS.get_cmdline_user_args():
		_save_scene(_build_test_course(), "res://scenes/test_course.tscn")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/maps"))
	var only := OS.get_environment("ONLY")
	for map_name: String in MAPS:
		if only != "" and map_name != only:
			continue
		var kit := LevelKit.new(map_name, _make_environment())
		var spawn: Transform3D = load(MAPS[map_name][0]).build(kit)
		# A dressed map (GDD §9.3) has its decor in <map>_deco.gd.
		var deco_script: String = MAPS[map_name][0].replace(".gd", "_deco.gd")
		if ResourceLoader.exists(deco_script):
			var deco := DecoKit.new(kit, "res://assets/maps/%s/" % map_name.to_lower())
			load(deco_script).dress(kit, deco)
			deco.finish()
		_save_scene(kit.finish(spawn), MAPS[map_name][1])
	_save_scene(_build_main_menu(), "res://scenes/main_menu.tscn")
	ProjectSettings.set_setting("application/run/main_scene", "res://scenes/main_menu.tscn")
	ProjectSettings.save()
	quit()


# --- Project settings ---------------------------------------------------------

## Crunchy on purpose: no anti-aliasing, hard shadow edges. Also the splash.
func _configure_rendering() -> void:
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", 0)
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/screen_space_aa", 0)
	ProjectSettings.set_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", 0)
	ProjectSettings.set_setting("rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality", 0)
	ProjectSettings.set_setting("rendering/lights_and_shadows/directional_shadow/size", 2048)
	# 1 normally; the death sequence drops it to 0 to black out the world.
	ProjectSettings.set_setting("shader_globals/world_light", {"type": "float", "value": 1.0})
	# A level's indoor zone (AmbientZone) and the effects setting (Graphics).
	ProjectSettings.set_setting("shader_globals/indoor_min", {"type": "vec3", "value": Vector3.ZERO})
	ProjectSettings.set_setting("shader_globals/indoor_max", {"type": "vec3", "value": Vector3.ZERO})
	ProjectSettings.set_setting("shader_globals/indoor_ambient", {"type": "float", "value": 1.0})
	ProjectSettings.set_setting("shader_globals/effects", {"type": "float", "value": 1.0})
	# Dressed maps light a big floor with more lamps than the OpenGL
	# fallback's default of 8 per object.
	ProjectSettings.set_setting("rendering/limits/opengl/max_lights_per_object", 16)
	# Boot splash: the logo at its own size on white.
	ProjectSettings.set_setting("application/boot_splash/image", "res://assets/ui/logo.png")
	ProjectSettings.set_setting("application/boot_splash/bg_color", Color.WHITE)
	ProjectSettings.set_setting("application/boot_splash/stretch_mode", 0)
	ProjectSettings.set_setting("application/boot_splash/use_filter", true)


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
	cam.far = 600.0
	player.add_child(cam)

	var model := Node3D.new()
	model.name = "Model"
	model.set_script(load("res://src/player/player_model.gd"))
	player.add_child(model)

	for child in player.get_children():
		child.owner = player
	return player


# --- Main menu ----------------------------------------------------------------

func _build_main_menu() -> Node:
	var menu := Node3D.new()
	menu.name = "MainMenu"
	menu.set_script(load("res://src/ui/main_menu.gd"))
	return menu


# --- Test course --------------------------------------------------------------

func _build_test_course() -> Node:
	_kit = LevelKit.new("TestCourse", _make_environment())
	# Coloured pools of light: harsh, unshadowed, period-accurate "bad" lighting.
	_kit.light("PinkLamp", Vector3(0, 4, 18), Color(1.0, 0.35, 0.65), 16.0)
	_kit.light("CyanLamp", Vector3(38.5, 5, -18), Color(0.3, 0.9, 1.0), 20.0)
	_kit.light("AmberLamp", Vector3(-28, 4, 17), Color(1.0, 0.7, 0.25), 16.0)
	_kit.light("VioletLamp", Vector3(-18, 3, -10), Color(0.6, 0.4, 1.0), 14.0)

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
	_armory()
	_shooting_range()
	var course := _kit.finish(Transform3D.IDENTITY)
	_kit = null
	return course


## Flat coloured ambient, no sky reflections (surfaces fake their own),
## linear tonemapping for saturated early-2000s colour, thick coloured fog.
func _make_environment() -> Environment:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://src/render/retro_sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32

	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.50, 0.40, 0.62)
	e.ambient_light_energy = 0.75
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.glow_enabled = true
	e.glow_intensity = 0.5
	e.glow_bloom = 0.0
	e.fog_enabled = true
	e.fog_light_color = Color(0.70, 0.44, 0.58)
	e.fog_density = 0.01
	e.fog_sky_affect = 0.25
	return e


func _box(box_name: String, center: Vector3, size: Vector3, kind: GreyBox.Kind, rot_deg := Vector3.ZERO) -> void:
	_kit.box(box_name, center, size, kind, rot_deg)


## A rotated box placed by the midpoint of its top surface, so slopes meet
## the ground and platforms exactly.
func _slab(box_name: String, top_mid: Vector3, size: Vector3, kind: GreyBox.Kind, rot_deg: Vector3) -> void:
	_kit.slab(box_name, top_mid, size, kind, rot_deg)


func _label(text: String, pos: Vector3) -> void:
	_kit.label(text, pos)


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


## A pad for every gun just left of spawn. They come back quickly here.
func _armory() -> void:
	_label("ARMORY  (walk over a gun · E swap · Q throw · 1/2 switch)", Vector3(-4, 3.2, -3))
	for i in Weapons.GUNS.size():
		_kit.pad("Pad_%s" % String(Weapons.GUNS[i]).capitalize().replace(" ", ""), Weapons.GUNS[i],
				Vector3(-4, 0, 2.5 - 2.2 * i), 3.0)


## Dummies to shoot, facing back toward the armory: standing at 7, 12, 22
## and 42 m, one up on a block, two pacing across the range.
func _shooting_range() -> void:
	_label("SHOOTING RANGE  (7 / 12 / 22 / 42 m)", Vector3(-14, 3.5, 6))
	var face := -PI * 0.5  # Looking down +X.
	for d: Array in [
			["Dummy_7m", Vector3(-12, 0, -1), Vector3.ZERO, 0.0, &"top_hat"],
			["Dummy_12m", Vector3(-17, 0, 2), Vector3.ZERO, 0.0, &"cowboy_hat"],
			["Dummy_22m", Vector3(-27, 0, -4), Vector3.ZERO, 0.0, &"none"],
			["Dummy_42m", Vector3(-47, 0, -1), Vector3.ZERO, 0.0, &"viking_helmet"],
			["Dummy_Up", Vector3(-32, 3, 5), Vector3.ZERO, 0.0, &"crown"],
			["Dummy_Walker", Vector3(-22, 0, -7), Vector3(0, 0, 11), 1.6, &"party_hat"],
			["Dummy_Runner", Vector3(-37, 0, 4), Vector3(0, 0, -11), 4.5, &"propeller_cap"]]:
		var dummy := Node3D.new()
		dummy.set_script(load("res://src/combat/target_dummy.gd"))
		dummy.name = d[0]
		dummy.position = d[1]
		dummy.set(&"patrol", d[2])
		dummy.set(&"patrol_speed", d[3] if d[3] > 0.0 else 2.0)
		dummy.set(&"facing", face)
		dummy.set(&"hat", d[4])
		_kit.combat.add_child(dummy)
	_box("DummyBlock", Vector3(-32, 1.5, 5), Vector3(3, 3, 3), K.LEDGE)
	_box("RangeBackstop", Vector3(-60, 4, -1), Vector3(1, 8, 26), K.WALL)
