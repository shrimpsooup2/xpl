extends Node3D
## Title screen: your blob under a spotlight on a black stage, the logo, and
## a boxed menu. It's a stage, so it performs (GDD §13.5): the logo stamps
## down and wobbles like the warped original, the buttons slide in, the blob
## reacts to what you hover (a jab for play, a flinch for quit) and breaks
## into a dance now and then, the camera leans toward the mouse, and a news
## ticker crawls along the bottom. Play jumps into a wipe.
##
## Under play is the hat picker (GDD §11.4): arrows (or ← →) step through
## the hats, which drop onto the blob as you go, and the swatch beside them
## shows the hat in the other team's colours. The pick is saved (Cosmetics).

const PLAY_SCENE := "res://scenes/test_course.tscn"
const LOGO := preload("res://assets/ui/logo_small.png")
const DANCE_EVERY := Vector2(5.0, 9.0)
## Camera lean toward the mouse, in meters at the screen edge.
const MOUSE_LEAN := Vector2(0.35, 0.18)
## Logo wobble: radians of tilt and fraction of scale.
const LOGO_TILT := 0.02
const LOGO_BREATHE := 0.012
const TICKER_SPEED := 22.0  # Canvas pixels per second.
const TICKER_HEIGHT := 12.0
const TICKER := [
	"welcome to xtrapartial", "aim for the heart", "every round is a new map",
	"smashdown banks your speed", "now loading: food court eclipse", "fists count as a weapon",
	"slide · hop · dash · repeat", "the map is unloading", "birthday.exe has stopped responding",
	"pick things up", "you fell apart (it happens)",
]
const SPOT_ENERGY := 16.0

var _model: PlayerModel
var _camera: Camera3D
var _spot: SpotLight3D
var _layer: LofiLayer
var _logo: TextureRect
var _ticker_label: Label
var _ticker_width := 0.0
var _time := 0.0
var _next_dance := 4.0
var _logo_live := 0.0  # Wobble amount, eased in after the entrance.
var _lean := Vector2.ZERO
var _reaction := 0
var _leaving := false
var _hat_name: PanelContainer
var _team_button: Button
var _preview_team := Hats.Team.RED


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	RenderingServer.global_shader_parameter_set(&"world_light", 1.0)
	Cosmetics.load_saved()
	_build_stage()
	_build_menu()
	_show_hat(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_left"):
		cycle_hat(-1)
	elif event.is_action_pressed(&"ui_right"):
		cycle_hat(1)


func _process(delta: float) -> void:
	_time += delta
	# A slow drift around the stage, leaning toward the mouse.
	var view := get_viewport().get_visible_rect().size
	var mouse := (get_viewport().get_mouse_position() / view - Vector2(0.5, 0.5)) * 2.0
	_lean = _lean.lerp(mouse.clamp(-Vector2.ONE, Vector2.ONE) * MOUSE_LEAN, minf(delta * 3.0, 1.0))
	var angle := sin(_time * 0.15) * 0.35
	var from := Vector3(sin(angle) * 3.4 + 0.9 + _lean.x, 1.35 - _lean.y, cos(angle) * 3.4)
	_camera.global_transform = Transform3D(Basis.looking_at(Vector3(0.35, 0.95, 0) - from), from)

	if _time > _next_dance and _reaction == 0:
		_next_dance = _time + randf_range(DANCE_EVERY.x, DANCE_EVERY.y)
		_react(PlayerModel.ANIM_DANCE, 2.2)

	if _time > 1.0:
		_logo_live = minf(_logo_live + delta, 1.0)
	_logo.pivot_offset = _logo.size * 0.5
	if _logo_live > 0.0:
		var amount := _logo_live * LofiUI.motion
		_logo.rotation = sin(_time * 0.8) * LOGO_TILT * amount
		_logo.scale = Vector2.ONE * (1.0 + sin(_time * 1.7) * LOGO_BREATHE * amount)

	if _ticker_width > 0.0:
		_ticker_label.position.x -= TICKER_SPEED * delta
		if _ticker_label.position.x <= -_ticker_width:
			_ticker_label.position.x += _ticker_width


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

	_spot = SpotLight3D.new()
	_spot.position = Vector3(0.6, 6.5, 3.0)
	_spot.light_color = Color(1.0, 0.95, 0.85)
	_spot.light_energy = SPOT_ENERGY
	_spot.spot_range = 14.0
	_spot.spot_angle = 16.0
	_spot.shadow_enabled = true
	add_child(_spot)
	_spot.look_at(Vector3(0, 0.8, 0))

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
	_logo = TextureRect.new()
	_logo.texture = LOGO
	_logo.custom_minimum_size = LOGO.get_size() * 1.6
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_SCALE
	col.add_child(_logo)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 12
	col.add_child(spacer)
	var play := LofiUI.button("play", _play)
	play.mouse_entered.connect(_react.bind(&"Punch_Jab", 0.8))
	col.add_child(play)
	col.add_child(_build_hat_picker())
	var settings := LofiUI.button("settings (soon)", func() -> void: pass)
	settings.disabled = true
	col.add_child(settings)
	var quit := LofiUI.button("quit", get_tree().quit)
	quit.mouse_entered.connect(_react.bind(&"Hit_Head", 0.42))
	col.add_child(quit)
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
	_build_ticker()

	# Entrance: logo slams down, buttons slide in, the rest follows.
	LofiUI.stamp(_logo, 0.6, 2.6)
	var i := 0
	for b in col.get_children():
		if b is Button or b is HBoxContainer:
			LofiUI.enter(b, Vector2(-40, 0), 0.25 + i * 0.07, 0.3)
			i += 1
	LofiUI.enter(footer, Vector2(0, 10), 0.6, 0.25)


## [<] [hat name] [>] [team swatch].
func _build_hat_picker() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 2)
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var back := LofiUI.button("<", cycle_hat.bind(-1))
	row.add_child(back)
	_hat_name = LofiUI.box("", LofiUI.NORMAL)
	_hat_name.custom_minimum_size.x = 74
	LofiUI.label_of(_hat_name).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_hat_name)
	var next := LofiUI.button(">", cycle_hat.bind(1))
	row.add_child(next)
	_team_button = LofiUI.button("", _toggle_team)
	_team_button.tooltip_text = "preview the other team's colours"
	row.add_child(_team_button)
	return row


## Steps `by` through the hats, saves the pick, and drops it on the blob.
func cycle_hat(by: int) -> void:
	if _leaving:
		return
	var i := Hats.ALL.find(Cosmetics.hat)
	Cosmetics.set_hat(Hats.ALL[posmod(i + by, Hats.ALL.size())])
	_show_hat(true)
	LofiUI.pop(_hat_name, 1.15, 0.15)


func _toggle_team() -> void:
	_preview_team = Hats.Team.BLUE if _preview_team == Hats.Team.RED else Hats.Team.RED
	_show_hat(true)


## Puts the picked hat on the blob in the preview team's colours; with `drop`
## it lands with a little squash and the head nods under it.
func _show_hat(drop: bool) -> void:
	_model.dress(Cosmetics.hat, _preview_team)
	if _model.hat:
		# The spot is nearly overhead: the hat's shadow would black out the face.
		for part: MeshInstance3D in _model.hat.find_children("*", "MeshInstance3D", true, false):
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	LofiUI.set_text(_hat_name, Hats.NAMES[Cosmetics.hat])
	_team_button.text = Hats.TEAM_NAMES[_preview_team]
	for state: StringName in [&"normal", &"focus"]:
		var box := LofiUI.stylebox(LofiUI.Style.NORMAL)
		box.bg_color = Hats.team_color(_preview_team)
		_team_button.add_theme_stylebox_override(state, box)
	_team_button.add_theme_color_override(&"font_color", LofiUI.WHITE)
	_team_button.add_theme_color_override(&"font_focus_color", LofiUI.WHITE)
	if not drop:
		return
	if _model.hat:
		var rest := _model.hat.transform
		_model.hat.transform = rest.translated_local(Vector3.UP * 0.25).scaled_local(Vector3(0.7, 1.3, 0.7))
		_model.hat.create_tween().tween_property(_model.hat, "transform", rest, 0.28) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif _model.marker:
		for part: Node3D in _model.marker.get_children():
			part.scale = Vector3.ONE * 0.3
			part.create_tween().tween_property(part, "scale", Vector3.ONE, 0.3) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_model.layers.flinch("DEF-head", _model.global_basis.x, -0.22)
	var t := create_tween()
	t.tween_property(_spot, "light_energy", SPOT_ENERGY * 1.2, 0.04)
	t.tween_property(_spot, "light_energy", SPOT_ENERGY, 0.25)


## A news crawl along the bottom edge, early-2000s TV style.
func _build_ticker() -> void:
	var strip := PanelContainer.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.clip_contents = true
	_layer.canvas.add_child(strip)
	strip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	strip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	strip.offset_top = -TICKER_HEIGHT
	var holder := Control.new()  # Not a container, so the label can scroll.
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.clip_contents = true
	strip.add_child(holder)
	var line := "   ■   ".join(PackedStringArray(TICKER)) + "   ■   "
	_ticker_label = Label.new()
	_ticker_label.add_theme_font_size_override(&"font_size", LofiUI.SMALL)
	_ticker_label.text = line + line + line
	holder.add_child(_ticker_label)
	_ticker_width = LofiUI.FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, LofiUI.SMALL).x
	LofiUI.enter(strip, Vector2(0, 14), 0.5, 0.3)


## Plays a one-off clip on the blob, then settles back to idle, and pumps
## the spotlight a little.
func _react(clip: StringName, length: float) -> void:
	if _leaving or not _model.anim.has_animation(clip):
		return
	_reaction += 1
	var mine := _reaction
	_model.anim.play(clip, 0.1)
	var t := create_tween()
	t.tween_property(_spot, "light_energy", SPOT_ENERGY * 1.35, 0.05)
	t.tween_property(_spot, "light_energy", SPOT_ENERGY, 0.3)
	get_tree().create_timer(length).timeout.connect(func() -> void:
		if mine == _reaction and not _leaving:
			_reaction = 0
			_model.anim.play(PlayerModel.ANIM_IDLE, 0.3))


func _play() -> void:
	if _leaving:
		return
	_react(&"Jump_Start", 1.0)
	_leaving = true
	LofiUI.kick(_layer, 0.6)
	get_tree().create_timer(0.2).timeout.connect(func() -> void:
		Wipe.change_scene(get_tree(), PLAY_SCENE))
