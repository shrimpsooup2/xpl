extends Node3D
## Title screen: your blob under a spotlight on a black stage, the logo, and
## a boxed menu. It's a stage, so it performs (GDD §13.5): the logo stamps
## down and wobbles like the warped original, the buttons slide in, the blob
## reacts to what you hover (a jab for play, a flinch for quit) and breaks
## into a dance now and then, the camera leans toward the mouse, and a news
## ticker crawls along the bottom. Play jumps into a wipe.
##
## The blob wears your hat, in red or blue at random. Small pickers tucked in
## the bottom corner step through the hats (or ← →) and the free-for-all
## colours, dropping each onto the blob, and your name is typed in next to
## them; all saved, and what you wear and go by in a game (GDD §11.4).
## Hovering free-for-all shows your colour; hovering teams, a team's.
##
## Free-for-all and teams start a practice game against bots (Game); the
## sandbox is the movement course.

const PLAY_SCENE := "res://scenes/test_course.tscn"
const FFA_BOTS := 3
const TEAM_BOTS := 7
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
var _color_name: PanelContainer
var _name_field: LineEdit
var _team := Hats.Team.RED
## What the blob is wearing now: a team's colour or your free-for-all one.
var _tint := Color.WHITE


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	RenderingServer.global_shader_parameter_set(&"world_light", 1.0)
	Cosmetics.load_saved()
	_team = Hats.Team.RED if randi() % 2 == 0 else Hats.Team.BLUE
	_tint = Hats.team_color(_team)
	_build_stage()
	_build_menu()
	_show_hat(false)


func _unhandled_input(event: InputEvent) -> void:
	if _name_field and _name_field.has_focus():
		return
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
	var ffa := LofiUI.button("free-for-all", _play.bind(&"ffa"))
	ffa.mouse_entered.connect(func() -> void:
		_react(&"Punch_Jab", 0.8)
		_wear(Cosmetics.tint()))
	col.add_child(ffa)
	var teams := LofiUI.button("teams", _play.bind(&"teams"))
	teams.mouse_entered.connect(func() -> void:
		_react(&"Punch_Cross", 0.8)
		_wear(Hats.team_color(_team)))
	col.add_child(teams)
	var sandbox := LofiUI.button("sandbox", _play.bind(&"sandbox"))
	sandbox.mouse_entered.connect(_react.bind(&"Punch_Jab", 0.8))
	col.add_child(sandbox)
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
	var picker := _build_pickers()
	picker.size_flags_vertical = Control.SIZE_SHRINK_END
	picker.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	var bottom := HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(footer)
	bottom.add_child(picker)
	root.add_child(bottom)
	_build_ticker()

	# Entrance: logo slams down, buttons slide in, the rest follows.
	LofiUI.stamp(_logo, 0.6, 2.6)
	var i := 0
	for b in col.get_children():
		if b is Button:
			LofiUI.enter(b, Vector2(-40, 0), 0.25 + i * 0.07, 0.3)
			i += 1
	LofiUI.enter(footer, Vector2(0, 10), 0.6, 0.25)
	LofiUI.enter(picker, Vector2(0, 10), 0.7, 0.25)


## Quiet rows in small ghost boxes, like the version tag: your name, then
## [<] [hat: name] [>] and [<] [colour: name] [>].
func _build_pickers() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 1)
	col.alignment = BoxContainer.ALIGNMENT_END
	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_END
	name_row.add_theme_constant_override(&"separation", 1)
	var name_label := LofiUI.box("name:", LofiUI.SMALL, LofiUI.Style.GHOST)
	name_row.add_child(name_label)
	_name_field = LineEdit.new()
	_name_field.text = Cosmetics.player_name
	_name_field.max_length = Cosmetics.NAME_LENGTH
	_name_field.custom_minimum_size.x = 84
	_name_field.add_theme_font_size_override(&"font_size", LofiUI.SMALL)
	_name_field.add_theme_stylebox_override(&"normal", LofiUI.stylebox(LofiUI.Style.GHOST, LofiUI.SMALL, randi()))
	_name_field.add_theme_stylebox_override(&"focus", LofiUI.stylebox(LofiUI.Style.NORMAL, LofiUI.SMALL, randi()))
	_name_field.add_theme_color_override(&"font_color", LofiUI.BLACK)
	_name_field.text_submitted.connect(func(_t: String) -> void: _name_field.release_focus())
	_name_field.focus_exited.connect(func() -> void:
		Cosmetics.set_player_name(_name_field.text)
		_name_field.text = Cosmetics.player_name)
	name_row.add_child(_name_field)
	col.add_child(name_row)
	var hats: Array = []
	for id: StringName in Hats.ALL:
		hats.append("hat: " + Hats.NAMES[id])
	var hat_row := _stepper(hats, cycle_hat)
	_hat_name = hat_row.get_child(1)
	col.add_child(hat_row)
	var colors: Array = []
	for key: StringName in Hats.PALETTE:
		colors.append("colour: " + String(key))
	var color_row := _stepper(colors, cycle_color)
	_color_name = color_row.get_child(1)
	col.add_child(color_row)
	return col


## [<] [label] [>]: the label box wide enough for the longest of `texts`,
## so the arrows never jump; the arrows call `step` with -1 and 1.
func _stepper(texts: Array, step: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override(&"separation", 1)
	var ghost := LofiUI.stylebox(LofiUI.Style.GHOST, LofiUI.SMALL, randi())
	for by in [-1, 1]:
		var arrow := LofiUI.button("<" if by < 0 else ">", step.bind(by))
		arrow.add_theme_font_size_override(&"font_size", LofiUI.SMALL)
		arrow.add_theme_stylebox_override(&"normal", ghost)
		arrow.add_theme_color_override(&"font_color", LofiUI.GREY)
		row.add_child(arrow)
	var label := LofiUI.box("", LofiUI.SMALL, LofiUI.Style.GHOST)
	for text: String in texts:
		var width := LofiUI.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LofiUI.SMALL).x
		label.custom_minimum_size.x = maxf(label.custom_minimum_size.x, ceilf(width) + 10.0)
	LofiUI.label_of(label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(label)
	row.move_child(label, 1)
	return row


## Steps `by` through the hats, saves the pick, and drops it on the blob.
func cycle_hat(by: int) -> void:
	if _leaving:
		return
	var i := Hats.ALL.find(Cosmetics.hat)
	Cosmetics.set_hat(Hats.ALL[posmod(i + by, Hats.ALL.size())])
	_show_hat(true)
	LofiUI.pop(_hat_name, 1.1, 0.12)


## Steps `by` through the free-for-all colours, saves the pick, and shows it
## on the blob.
func cycle_color(by: int) -> void:
	if _leaving:
		return
	var keys := Hats.PALETTE.keys()
	Cosmetics.set_color(keys[posmod(keys.find(Cosmetics.color) + by, keys.size())])
	_tint = Cosmetics.tint()
	_show_hat(true)
	LofiUI.pop(_color_name, 1.1, 0.12)


## Re-dresses the blob in `tint` (hovering a mode shows what you'd wear).
func _wear(tint: Color) -> void:
	if _leaving or tint == _tint:
		return
	_tint = tint
	_show_hat(false)


## Puts the picked hat on the blob; with `drop` it lands with a little squash
## and the head nods under it.
func _show_hat(drop: bool) -> void:
	_model.dress(Cosmetics.hat, _tint)
	if _model.hat:
		# The spot is nearly overhead: the hat's shadow would black out the face.
		for part: MeshInstance3D in _model.hat.find_children("*", "MeshInstance3D", true, false):
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	LofiUI.set_text(_hat_name, "hat: " + Hats.NAMES[Cosmetics.hat])
	LofiUI.set_text(_color_name, "colour: " + String(Cosmetics.color))
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


## Starts `mode`: a practice game of free-for-all or teams against bots, or
## the sandbox course.
func _play(mode: StringName) -> void:
	if _leaving:
		return
	if _name_field:
		Cosmetics.set_player_name(_name_field.text)
	_react(&"Jump_Start", 1.0)
	_leaving = true
	LofiUI.kick(_layer, 0.6)
	get_tree().create_timer(0.2).timeout.connect(_start.bind(mode))


func _start(mode: StringName) -> void:
	match mode:
		&"ffa":
			Game.practice(get_tree(), GameRules.free_for_all(), FFA_BOTS)
		&"teams":
			Game.practice(get_tree(), GameRules.teams(), TEAM_BOTS)
		_:
			Game.end(get_tree(), false)
			Wipe.change_scene(get_tree(), PLAY_SCENE)
