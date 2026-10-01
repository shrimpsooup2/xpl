class_name SettingsMenu
extends VBoxContainer
## The settings page (GDD §13.4), from the main menu and the pause menu:
## tabs for controls, keys, video, camera and sound, each a white card of
## rows (a name, then a slider or a [<] choice [>], or a key's two slots).
## Everything takes effect at once and is saved as it changes (Settings);
## *defaults* puts the open tab back as shipped.
##
## Keys: click a slot, then press the key or mouse button for it (esc
## cancels, backspace clears the slot). A key taken off another action says
## so, and that action's row flashes.

signal back

const TABS := ["controls", "keys", "video", "camera", "sound"]
const LABEL_WIDTH := 70.0
const SLOT_WIDTH := 60.0
const COLUMN_GAP := 12.0
const WINDOW_NAMES := ["windowed", "fullscreen", "exclusive"]
## The 3D picture's height in pixels (0: the screen's own), and colours.
const PIXELS := [180, 240, 270, 360, 480, 540, 720, 0]
const COLOURS := [0, 64, 32, 16, 8]
## The graphics presets (Graphics.PRESETS), and "custom" for a mix.
const QUALITY := ["low", "medium", "high", "custom"]
const SHADOW_NAMES := ["off", "low", "high"]
## The settings each tab's *defaults* puts back.
const CONTROL_KEYS := ["sensitivity", "aim_sensitivity", "invert_y", "toggle_aim"]
const VIDEO_KEYS := ["pixel_height", "color_levels"]
const CAMERA_KEYS := ["fov_horizontal", "speed_fov_kick", "camera_motion", "camera_smoothing", "screen_shake",
		"wallride_tilt", "landing_dip", "speed_lines", "impact_frames", "ui_motion"]

## The tab it opens on: the one you were last on.
static var last_tab := 0

var tab := 0
var _tabs: Array[Button] = []
var _card: PanelContainer
var _status: PanelContainer
## Each key slot's button, by action then slot.
var _slots := {}
## While waiting for a key: {action, slot}.
var _capture := {}


func _ready() -> void:
	add_theme_constant_override(&"separation", 3)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 2)
	for i in TABS.size():
		var b := LofiUI.button(TABS[i], show_tab.bind(i))
		b.toggle_mode = true
		_tabs.append(b)
		row.add_child(b)
	add_child(row)
	_card = PanelContainer.new()
	_card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(_card)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override(&"separation", 3)
	bottom.add_child(_menu_button("back", func() -> void: back.emit()))
	bottom.add_child(_menu_button("defaults", reset_tab))
	_status = LofiUI.box("", LofiUI.SMALL, LofiUI.Style.GHOST)
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status.visible = false
	bottom.add_child(_status)
	add_child(bottom)
	show_tab(last_tab)
	var i := 0
	for c in get_children():
		LofiUI.enter(c, Vector2(-30, 0), i * 0.05, 0.22)
		i += 1


func _input(event: InputEvent) -> void:
	if _capture.is_empty():
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventMouseButton and event.pressed)
	if not pressed:
		return
	# Nothing else gets it: not the menu, not the game underneath.
	get_viewport().set_input_as_handled()
	get_tree().root.set_input_as_handled()
	var action: StringName = _capture.action
	var slot: int = _capture.slot
	_capture = {}
	if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		say("")
	elif event is InputEventKey and (event as InputEventKey).physical_keycode in [KEY_BACKSPACE, KEY_DELETE]:
		Settings.unbind(action, slot)
		say("")
	else:
		var taken := Settings.bind(action, slot, event)
		if taken != &"":
			say("%s was %s's: it's %s's now" % [Settings.input_name(event), Settings.ACTIONS[taken], Settings.ACTIONS[action]])
			for b: Button in _slots.get(taken, []):
				LofiUI.shake(b)
		else:
			say("")
	_show_keys()


## Esc: stops waiting for a key, or goes back.
func escape() -> void:
	if not _capture.is_empty():
		_capture = {}
		say("")
		_show_keys()
	else:
		back.emit()


## Whether it's waiting for a key.
func capturing() -> bool:
	return not _capture.is_empty()


func show_tab(i: int) -> void:
	tab = clampi(i, 0, TABS.size() - 1)
	last_tab = tab
	_capture = {}
	_slots.clear()
	say("")
	for k in _tabs.size():
		_tabs[k].set_pressed_no_signal(k == tab)
	for c in _card.get_children():
		_card.remove_child(c)
		c.queue_free()
	var content: Control
	match TABS[tab]:
		"controls":
			content = _controls()
		"keys":
			content = _keys()
		"video":
			content = _video()
		"camera":
			content = _camera()
		_:
			content = _sound()
	_card.add_child(content)
	LofiUI.pop(_card, 0.94, 0.14)


## Puts the open tab back as shipped.
func reset_tab() -> void:
	match TABS[tab]:
		"controls":
			Settings.reset_view(CONTROL_KEYS)
		"keys":
			Settings.reset_keys()
		"video":
			Settings.set_window_mode(0)
			Settings.set_vsync(true)
			Settings.set_fps_cap(0)
			Settings.reset_view(VIDEO_KEYS)
			Settings.set_graphics_preset("high")
		"camera":
			Settings.reset_view(CAMERA_KEYS)
		_:
			Settings.set_volume(1.0)
	show_tab(tab)
	say("%s back to the defaults" % TABS[tab])


## A note by the buttons (empty hides it).
func say(text: String) -> void:
	_status.visible = text != ""
	LofiUI.set_text(_status, text)


# --- Tabs -------------------------------------------------------------------------

func _controls() -> Control:
	return _column([
		_row("sensitivity", _view_slider("sensitivity", 0.1, 6.0, 0.05, func(v: float) -> String: return "%.2f" % v)),
		_row("aim sensitivity", _view_slider("aim_sensitivity", 0.2, 2.0, 0.05, _percent)),
		_row("invert look", _view_toggle("invert_y")),
		_row("toggle aim", _view_toggle("toggle_aim")),
	])


func _keys() -> Control:
	var rows: Array[Control] = []
	for action: StringName in Settings.ACTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 1)
		var slots: Array[Button] = []
		for slot in Settings.SLOTS:
			var b := LofiUI.button("", _listen.bind(action, slot))
			b.add_theme_font_size_override(&"font_size", LofiUI.SMALL)
			b.add_theme_stylebox_override(&"normal", LofiUI.stylebox(LofiUI.Style.GHOST, LofiUI.SMALL, randi()))
			b.custom_minimum_size.x = SLOT_WIDTH
			b.alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.clip_text = true
			slots.append(b)
			row.add_child(b)
		_slots[action] = slots
		rows.append(_row(Settings.ACTIONS[action], row))
	_show_keys()
	var half := ceili(rows.size() / 2.0)
	return _columns(rows.slice(0, half), rows.slice(half))


func _video() -> Control:
	var view := Settings.view()
	var fps_names: Array = Settings.FPS_CAPS.map(func(f: int) -> String: return "no cap" if f == 0 else str(f))
	var pixel_names: Array = PIXELS.map(func(p: int) -> String: return "screen" if p == 0 else "%dp" % p)
	var colour_names: Array = COLOURS.map(func(c: int) -> String: return "full" if c == 0 else "%d levels" % c)
	var preset := Graphics.preset()
	return _columns([
		_row("window", _choice(WINDOW_NAMES, Settings.window_mode(), Settings.set_window_mode)),
		_row("vsync", _choice(["off", "on"], 1 if Settings.vsync() else 0, func(i: int) -> void: Settings.set_vsync(i == 1))),
		_row("frame cap", _choice(fps_names, maxi(Settings.FPS_CAPS.find(Settings.fps_cap()), 0),
				func(i: int) -> void: Settings.set_fps_cap(Settings.FPS_CAPS[i]))),
		_row("pixels", _choice(pixel_names, maxi(PIXELS.find(view.pixel_height), 0),
				func(i: int) -> void: _set_view("pixel_height", PIXELS[i]))),
		_row("colours", _choice(colour_names, maxi(COLOURS.find(view.color_levels), 0),
				func(i: int) -> void: _set_view("color_levels", COLOURS[i]))),
	], [
		# Quicker or prettier: a preset for them all, then each on its own.
		_row("quality", _choice(QUALITY, QUALITY.find(preset) if preset != "" else QUALITY.size() - 1, func(i: int) -> void:
			if QUALITY[i] != "custom":
				Settings.set_graphics_preset(QUALITY[i])
				show_tab(tab))),
		_row("shadows", _choice(SHADOW_NAMES, Graphics.shadows, func(i: int) -> void:
			Settings.set_shadows(i as Graphics.Shadows)
			show_tab(tab))),
		_row("extra lamps", _graphics_toggle("extra_lamps")),
		_row("detail", _graphics_toggle("detail")),
		_row("effects", _graphics_toggle("effects")),
		_row("bloom", _graphics_toggle("bloom")),
	])


## [<] off/on [>] for one of the graphics settings (Graphics).
func _graphics_toggle(key: String) -> HBoxContainer:
	return _choice(["off", "on"], 1 if Graphics.toggle(key) else 0, func(i: int) -> void:
		Settings.set_graphics(key, i == 1)
		show_tab(tab))


func _camera() -> Control:
	var degrees := func(v: float) -> String: return "%d°" % roundi(v)
	return _columns([
		_row("field of view", _view_slider("fov_horizontal", 80.0, 120.0, 1.0, degrees)),
		_row("speed fov", _view_slider("speed_fov_kick", 0.0, 15.0, 1.0, func(v: float) -> String: return "+%d°" % roundi(v))),
		_row("camera motion", _view_slider("camera_motion", 0.0, 1.0, 0.05, _percent)),
		_row("smoothing", _view_slider("camera_smoothing", 0.0, 1.0, 0.05, _percent)),
		_row("screen shake", _view_slider("screen_shake", 0.0, 1.0, 0.05, _percent)),
	], [
		_row("wall ride tilt", _view_slider("wallride_tilt", 0.0, 15.0, 1.0, degrees)),
		_row("ui motion", _view_slider("ui_motion", 0.0, 1.0, 0.05, _percent)),
		_row("landing dip", _view_toggle("landing_dip")),
		_row("speed lines", _view_toggle("speed_lines")),
		_row("impact frames", _view_toggle("impact_frames")),
	])


func _sound() -> Control:
	var col := _column([
		_row("volume", LofiUI.slider(Settings.volume(), 0.0, 1.0, 0.05, _percent, Settings.set_volume)),
	])
	col.add_child(_note("the game has no sounds yet: this is ready for them"))
	return col


# --- Rows -------------------------------------------------------------------------

## A setting's name, then its control.
func _row(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 2)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", LofiUI.SMALL)
	label.custom_minimum_size.x = LABEL_WIDTH
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	if control is HBoxContainer:
		(control as HBoxContainer).alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(control)
	return row


func _column(rows: Array) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 2)
	for r: Control in rows:
		col.add_child(r)
	return col


func _columns(left: Array, right: Array) -> HBoxContainer:
	var both := HBoxContainer.new()
	both.add_theme_constant_override(&"separation", int(COLUMN_GAP))
	both.add_child(_column(left))
	var right_col := _column(right)
	right_col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	both.add_child(right_col)
	return both


## A slider on one of the view settings.
func _view_slider(key: String, low: float, high: float, step: float, format: Callable) -> HBoxContainer:
	return LofiUI.slider(float(Settings.view().get(key)), low, high, step, format,
			func(v: float) -> void: _set_view(key, v))


## [<] off/on [>] for one of the view settings.
func _view_toggle(key: String) -> HBoxContainer:
	return _choice(["off", "on"], 1 if Settings.view().get(key) else 0, func(i: int) -> void: _set_view(key, i == 1))


## [<] name [>] over `names`, starting at `index`; `picked` gets the index.
func _choice(names: Array, index: int, picked: Callable) -> HBoxContainer:
	return LofiUI.choice(names, index, picked)


func _note(text: String) -> PanelContainer:
	var note := LofiUI.box(text, LofiUI.SMALL, LofiUI.Style.GHOST)
	note.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return note


func _set_view(key: String, value: Variant) -> void:
	var view := Settings.view()
	view.set(key, int(value) if typeof(view.get(key)) == TYPE_INT else value)
	Settings.save_view()


static func _percent(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)


func _menu_button(text: String, on_pressed: Callable) -> Button:
	var b := LofiUI.button(text, on_pressed)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.custom_minimum_size.x = 60
	return b


# --- Keys -------------------------------------------------------------------------

## Waits for the key for `slot` of `action`.
func _listen(action: StringName, slot: int) -> void:
	_capture = {"action": action, "slot": slot}
	_show_keys()
	say("press a key or mouse button for %s · esc cancels · backspace clears" % Settings.ACTIONS[action])


func _show_keys() -> void:
	for action: StringName in _slots:
		var slots: Array = _slots[action]
		for slot in slots.size():
			var b: Button = slots[slot]
			var waiting: bool = _capture.get("action") == action and _capture.get("slot") == slot
			var bound := Settings.binding(action, slot)
			b.text = "..." if waiting else (Settings.input_name(bound) if bound else "-")
			b.toggle_mode = waiting
			b.set_pressed_no_signal(waiting)
