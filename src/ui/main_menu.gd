extends Node3D
## Title screen: your blob under a spotlight on a black stage, the logo, and
## a boxed menu. Every so often the blob breaks into a little dance.

const PLAY_SCENE := "res://scenes/test_course.tscn"
const LOGO := preload("res://assets/ui/logo_small.png")
const DANCE_EVERY := Vector2(5.0, 9.0)

var _model: PlayerModel
var _camera: Camera3D
var _layer: LofiLayer
var _time := 0.0
var _next_dance := 4.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	RenderingServer.global_shader_parameter_set(&"world_light", 1.0)
	_build_stage()
	_build_menu()


func _process(delta: float) -> void:
	_time += delta
	# A slow drift around the stage.
	var angle := sin(_time * 0.15) * 0.35
	var from := Vector3(sin(angle) * 3.4 + 0.9, 1.35, cos(angle) * 3.4)
	_camera.global_transform = Transform3D(Basis.looking_at(Vector3(0.35, 0.95, 0) - from), from)
	if _time > _next_dance:
		_next_dance = _time + randf_range(DANCE_EVERY.x, DANCE_EVERY.y)
		_model.anim.play(PlayerModel.ANIM_DANCE, 0.2)
		get_tree().create_timer(2.2).timeout.connect(func() -> void:
			_model.anim.play(PlayerModel.ANIM_IDLE, 0.3))


func _build_stage() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color.BLACK
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.25, 0.2, 0.35)
	env.environment.ambient_light_energy = 0.3
	env.environment.glow_enabled = true
	add_child(env)

	var floor_box := StaticBody3D.new()
	floor_box.set_script(load("res://src/world/grey_box.gd"))
	floor_box.set(&"size", Vector3(12, 1, 12))
	floor_box.set(&"kind", GreyBox.Kind.FLOOR)
	floor_box.position = Vector3(0, -0.5, 0)
	add_child(floor_box)

	var spot := SpotLight3D.new()
	spot.position = Vector3(0.6, 6.5, 3.0)
	spot.light_color = Color(1.0, 0.95, 0.85)
	spot.light_energy = 16.0
	spot.spot_range = 14.0
	spot.spot_angle = 16.0
	spot.shadow_enabled = true
	add_child(spot)
	spot.look_at(Vector3(0, 0.8, 0))

	_model = PlayerModel.new()
	add_child(_model)
	_model.follow(Vector3.ZERO, PI + deg_to_rad(15.0))  # Face the camera.

	_camera = Camera3D.new()
	_camera.fov = 50.0
	add_child(_camera)
	_camera.current = true

	var retro := CanvasLayer.new()
	retro.set_script(load("res://src/render/retro_screen.gd"))
	add_child(retro)


func _build_menu() -> void:
	_layer = LofiLayer.new()
	_layer.layer = 4
	_layer.interactive = true
	add_child(_layer)
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 18)
	_layer.canvas.add_child(root)

	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 3)
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	root.add_child(col)
	var logo := TextureRect.new()
	logo.texture = LOGO
	logo.custom_minimum_size = LOGO.get_size() * 1.6
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_SCALE
	col.add_child(logo)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 12
	col.add_child(spacer)
	var play := LofiUI.button("play", func() -> void: get_tree().change_scene_to_file.call_deferred(PLAY_SCENE))
	col.add_child(play)
	var settings := LofiUI.button("settings (soon)", func() -> void: pass)
	settings.disabled = true
	col.add_child(settings)
	col.add_child(LofiUI.button("quit", get_tree().quit))
	for b in col.get_children():
		if b is Button:
			b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			b.custom_minimum_size.x = 70

	var footer := LofiUI.box("v0.1 · movement prototype", LofiUI.SMALL, LofiUI.Style.GHOST)
	footer.size_flags_vertical = Control.SIZE_SHRINK_END
	footer.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var bottom := VBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(footer)
	root.add_child(bottom)
