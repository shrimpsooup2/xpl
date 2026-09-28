extends CanvasLayer
## Prototype HUD: crosshair, speedometer, movement state readout, and a ticker
## of recent movement events so chains are easy to see while testing.
## Also owns the debug hotkeys: F2 respawn, F3 vsync, F4 toggle this readout,
## F6 third-person camera, F7 die.

const TICKER_SIZE := 7
const TICKER_LIFETIME := 2.5
const EVENT_LABELS := {
	&"jump": "jump", &"slam_bounce": "SLAM BOUNCE", &"wall_jump": "wall jump",
	&"slide_start": "slide", &"dash": "dash", &"wallride_start": "wall ride",
	&"smash_start": "smashdown", &"smash_impact": "impact", &"mantle": "mantle",
	&"land": "land", &"step": "step",
}

var _player: Player
var _root: Control
var _speed_label: Label
var _info_label: Label
var _ticker_label: Label
var _ticker: Array[Dictionary] = []
var _show_info := true
var _peak_speed := 0.0
var _peak_timer := 0.0


func _ready() -> void:
	layer = 5
	_build()
	_player = get_tree().get_first_node_in_group(&"local_player") as Player
	if _player:
		_player.movement_event.connect(_on_movement_event)
		_player.died.connect(func() -> void: _root.visible = false)
		_player.respawned.connect(func() -> void: _root.visible = true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_respawn") and _player:
		_player.respawn()
	elif event.is_action_pressed(&"debug_vsync"):
		var on := DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED if on else DisplayServer.VSYNC_ENABLED)
	elif event.is_action_pressed(&"debug_third_person") and _player:
		_player.set_third_person(not _player.third_person)
	elif event.is_action_pressed(&"debug_die") and _player:
		_player.die()
	elif event.is_action_pressed(&"debug_hud"):
		_show_info = not _show_info
		_info_label.visible = _show_info
		_ticker_label.visible = _show_info


func _process(delta: float) -> void:
	if _player == null:
		return
	var st := _player.state
	var speed := _player.horizontal_speed()
	_peak_timer -= delta
	if speed > _peak_speed or _peak_timer <= 0.0:
		_peak_speed = speed
		_peak_timer = 1.5
	_speed_label.text = "%.1f m/s\npeak %.1f" % [speed, _peak_speed]

	if _show_info:
		var p := _player.movement_params
		var dash_bar := ""
		for i in p.dash_charges:
			if i < st.dash_charges:
				dash_bar += "■"
			elif i == st.dash_charges:
				dash_bar += "□ %d%%" % int(100.0 * st.dash_recharge_timer / p.dash_recharge)
			else:
				dash_bar += "□"
		var vsync := DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
		_info_label.text = "\n".join([
			"%d fps   vsync %s" % [Engine.get_frames_per_second(), "on" if vsync else "off"],
			"mode      %s" % MovementState.Mode.keys()[st.mode],
			"ground    %s   crouch %s" % [st.on_ground, st.crouched],
			"speed     h %.2f   v %.2f" % [speed, _player.velocity.y],
			"dash      %s" % dash_bar,
			"walljump  %d / %d" % [st.wall_jumps_left, p.wall_jumps],
			"slide cd  %.2f" % st.slide_boost_cooldown,
		])

	var now := Time.get_ticks_msec() / 1000.0
	while not _ticker.is_empty() and now - float(_ticker[0].time) > TICKER_LIFETIME:
		_ticker.pop_front()
	var names: PackedStringArray = []
	for item in _ticker:
		names.append(item.text)
	_ticker_label.text = "  →  ".join(names)


func _on_movement_event(e: Dictionary) -> void:
	if not EVENT_LABELS.has(e.type):
		return
	var text: String = EVENT_LABELS[e.type]
	if e.type == &"smash_impact":
		text = "impact %.1fm" % e.drop
	_ticker.append({"text": text, "time": Time.get_ticks_msec() / 1000.0})
	while _ticker.size() > TICKER_SIZE:
		_ticker.pop_front()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_root = root

	var crosshair := ColorRect.new()
	crosshair.color = Color(1, 1, 1, 0.9)
	crosshair.size = Vector2(4, 4)
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = -crosshair.size * 0.5
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)

	_speed_label = _label(root, 30, HORIZONTAL_ALIGNMENT_CENTER)
	_speed_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_speed_label.offset_top = -130
	_speed_label.offset_left = -200
	_speed_label.offset_right = 200

	_info_label = _label(root, 15, HORIZONTAL_ALIGNMENT_LEFT)
	_info_label.position = Vector2(16, 12)

	_ticker_label = _label(root, 18, HORIZONTAL_ALIGNMENT_CENTER)
	_ticker_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_ticker_label.offset_top = 16
	_ticker_label.offset_left = -500
	_ticker_label.offset_right = 500

	var help := _label(root, 14, HORIZONTAL_ALIGNMENT_LEFT)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.offset_top = -34
	help.offset_left = 16
	help.text = "F1 tuning   F2 respawn   F3 vsync   F4 readout   F6 third person   F7 die   Esc release mouse"


func _label(parent: Control, font_size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", Color(1, 1, 1))
	l.add_theme_color_override(&"font_outline_color", Color(0.1, 0.05, 0.15))
	l.add_theme_constant_override(&"outline_size", 6)
	parent.add_child(l)
	return l
