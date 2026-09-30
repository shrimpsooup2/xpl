class_name Settings
extends RefCounted
## Your settings, kept between sessions in user://settings.cfg: the view
## (ViewSettings: mouse, camera, look), the window, vsync, the frame cap,
## the graphics (Graphics: shadows, lamps, detail, effects, bloom), the
## volume, and your keys. Only what you've changed from the defaults is
## saved, so a default tuned later still reaches you. The settings page
## (SettingsMenu) and the F1 tuning panel both edit it.

const DEFAULT_VIEW := "res://data/view_settings.tres"
## The actions you can rebind, in the order the keys page lists them, and
## what it calls them. Each takes up to SLOTS keys or mouse buttons.
const ACTIONS := {
	&"move_forward": "forward",
	&"move_back": "back",
	&"move_left": "left",
	&"move_right": "right",
	&"jump": "jump",
	&"crouch": "slide / crouch",
	&"dash": "dash",
	&"fire": "fire",
	&"alt_fire": "aim",
	&"interact": "pick up",
	&"throw_weapon": "throw gun",
	&"weapon_primary": "gun",
	&"weapon_fists": "fists",
	&"scoreboard": "scores",
}
const SLOTS := 2
const WINDOW_MODES := [DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.WINDOW_MODE_FULLSCREEN,
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
## Frame caps offered (0: none).
const FPS_CAPS := [0, 30, 60, 120, 144, 165, 240, 360]
const MOUSE_NAMES := {
	MOUSE_BUTTON_LEFT: "left click", MOUSE_BUTTON_RIGHT: "right click", MOUSE_BUTTON_MIDDLE: "middle click",
	MOUSE_BUTTON_WHEEL_UP: "wheel up", MOUSE_BUTTON_WHEEL_DOWN: "wheel down",
	MOUSE_BUTTON_WHEEL_LEFT: "wheel left", MOUSE_BUTTON_WHEEL_RIGHT: "wheel right",
	MOUSE_BUTTON_XBUTTON1: "mouse 4", MOUSE_BUTTON_XBUTTON2: "mouse 5",
}

## Where it's saved (tests point this elsewhere).
static var path := "user://settings.cfg"
static var _view: ViewSettings
static var _defaults: ViewSettings
static var _volume := 1.0
static var _applied := false


## The view settings the local player and the menus use, with what you've
## changed laid over the defaults.
static func view() -> ViewSettings:
	if _view == null:
		_view = defaults().duplicate()
		var cfg := _load()
		for key in (cfg.get_section_keys("view") if cfg.has_section("view") else PackedStringArray()):
			_set_checked(_view, key, cfg.get_value("view", key))
	return _view


## The view settings as shipped (data/view_settings.tres).
static func defaults() -> ViewSettings:
	if _defaults == null:
		_defaults = load(DEFAULT_VIEW) as ViewSettings
	return _defaults


## Puts the saved window, vsync, frame cap, volume and keys into effect, the
## first time it's called in a run.
static func apply_saved() -> void:
	if _applied:
		return
	_applied = true
	var cfg := _load()
	if cfg.has_section_key("display", "window"):
		set_window_mode(int(cfg.get_value("display", "window")), false)
	if cfg.has_section_key("display", "vsync"):
		set_vsync(cfg.get_value("display", "vsync") == true, false)
	if cfg.has_section_key("display", "fps_cap"):
		set_fps_cap(int(cfg.get_value("display", "fps_cap")), false)
	set_volume(float(cfg.get_value("audio", "volume", 1.0)), false)
	Graphics.shadows = clampi(int(cfg.get_value("graphics", "shadows", Graphics.Shadows.HIGH)), 0, Graphics.Shadows.HIGH) as Graphics.Shadows
	for key: String in GRAPHICS_TOGGLES:
		Graphics.set_toggle(key, cfg.get_value("graphics", key, true) == true)
	for action: StringName in ACTIONS:
		if cfg.has_section_key("keys", action):
			var events: Array[InputEvent] = []
			for text: Variant in cfg.get_value("keys", action):
				var e := event_from_text(str(text))
				if e:
					events.append(e)
			_set_events(action, events)


## Forgets what's been read and applied (tests, after pointing `path`
## somewhere else).
static func forget() -> void:
	_view = null
	_applied = false
	_volume = 1.0
	set_graphics_preset("high", false)


# --- View -------------------------------------------------------------------------

## Saves the view settings: whatever differs from the defaults.
static func save_view() -> void:
	var cfg := _load()
	var base := defaults()
	for key in _view_keys():
		var value: Variant = view().get(key)
		if value == base.get(key):
			if cfg.has_section_key("view", key):
				cfg.erase_section_key("view", key)
		else:
			cfg.set_value("view", key, value)
	cfg.save(path)


## Puts `keys` of the view settings (all of them if empty) back to the
## defaults, and saves.
static func reset_view(keys: Array = []) -> void:
	for key in (keys if not keys.is_empty() else Array(_view_keys())):
		view().set(key, defaults().get(key))
	save_view()


static func _view_keys() -> PackedStringArray:
	var keys: PackedStringArray = []
	for prop in ViewSettings.new().get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.usage & PROPERTY_USAGE_EDITOR:
			keys.append(prop.name)
	return keys


# Sets a saved value only if the setting exists and the type matches, so
# an old or hand-edited file can't break anything.
static func _set_checked(res: Resource, key: String, value: Variant) -> void:
	if not key in _view_keys():
		return
	var current: Variant = res.get(key)
	if typeof(current) == TYPE_FLOAT and typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		res.set(key, float(value))
	elif typeof(current) == typeof(value):
		res.set(key, value)


# --- Display and sound ------------------------------------------------------------

## Which of WINDOW_MODES the window is in (maximised counts as windowed).
static func window_mode() -> int:
	var mode := DisplayServer.window_get_mode()
	return maxi(WINDOW_MODES.find(mode), 0)


static func set_window_mode(index: int, save := true) -> void:
	index = clampi(index, 0, WINDOW_MODES.size() - 1)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(WINDOW_MODES[index])
	if save:
		_save_value("display", "window", index)


static func vsync() -> bool:
	return DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED


static func set_vsync(on: bool, save := true) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED)
	if save:
		_save_value("display", "vsync", on)


## The frame cap (0: none).
static func fps_cap() -> int:
	return Engine.max_fps


static func set_fps_cap(fps: int, save := true) -> void:
	Engine.max_fps = maxi(fps, 0)
	if save:
		_save_value("display", "fps_cap", Engine.max_fps)


## The master volume, 0..1.
static func volume() -> float:
	return _volume


static func set_volume(v: float, save := true) -> void:
	_volume = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(_volume, 0.0001)))
	AudioServer.set_bus_mute(0, _volume <= 0.0)
	if save:
		_save_value("audio", "volume", _volume)


# --- Graphics ---------------------------------------------------------------------

## The on/off graphics settings, by their names in Graphics.
const GRAPHICS_TOGGLES := ["extra_lamps", "detail", "effects", "bloom"]


static func set_shadows(quality: Graphics.Shadows, save := true) -> void:
	Graphics.shadows = clampi(quality, 0, Graphics.Shadows.HIGH) as Graphics.Shadows
	_graphics_changed()
	if save:
		_save_value("graphics", "shadows", int(Graphics.shadows))


## One of GRAPHICS_TOGGLES on or off.
static func set_graphics(key: String, on: bool, save := true) -> void:
	if not key in GRAPHICS_TOGGLES:
		return
	Graphics.set_toggle(key, on)
	_graphics_changed()
	if save:
		_save_value("graphics", key, on)


## Every graphics setting at once, from Graphics.PRESETS.
static func set_graphics_preset(name: String, save := true) -> void:
	var p: Array = Graphics.PRESETS.get(name, Graphics.PRESETS.high)
	Graphics.shadows = p[0]
	for i in GRAPHICS_TOGGLES.size():
		Graphics.set_toggle(GRAPHICS_TOGGLES[i], p[i + 1])
	_graphics_changed()
	if save:
		var cfg := _load()
		cfg.set_value("graphics", "shadows", int(Graphics.shadows))
		for key: String in GRAPHICS_TOGGLES:
			cfg.set_value("graphics", key, Graphics.toggle(key))
		cfg.save(path)


static func _graphics_changed() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		Graphics.apply(tree)


# --- Keys -------------------------------------------------------------------------

## The key or mouse button in `slot` of `action`, or null.
static func binding(action: StringName, slot: int) -> InputEvent:
	var events := _events(action)
	return events[slot] if slot < events.size() else null


## Binds `event` to `slot` of `action`, and saves. The same input is taken
## off every other action first, so one key only ever does one thing;
## returns the action it was taken from (or &"").
static func bind(action: StringName, slot: int, event: InputEvent) -> StringName:
	var fresh := _clean(event)
	var taken := &""
	for other: StringName in ACTIONS:
		if other == action:
			continue
		var kept: Array[InputEvent] = []
		for e in _events(other):
			if same_input(e, fresh):
				taken = other
			else:
				kept.append(e)
		if taken == other:
			_set_events(other, kept)
	# In its slot, and out of the action's other slot if it was there too.
	var slots: Array = []
	slots.resize(SLOTS)
	var mine := _events(action)
	for i in mini(mine.size(), SLOTS):
		slots[i] = mine[i]
	slots[clampi(slot, 0, SLOTS - 1)] = fresh
	var events: Array[InputEvent] = []
	for i in SLOTS:
		if slots[i] != null and (i == slot or not same_input(slots[i], fresh)):
			events.append(slots[i])
	_set_events(action, events)
	_save_keys()
	return taken


## Clears `slot` of `action`, and saves.
static func unbind(action: StringName, slot: int) -> void:
	var events := _events(action)
	if slot < events.size():
		events.remove_at(slot)
		_set_events(action, events)
		_save_keys()


## Every key back as shipped, and saves.
static func reset_keys() -> void:
	InputMap.load_from_project_settings()
	var cfg := _load()
	if cfg.has_section("keys"):
		cfg.erase_section("keys")
	cfg.save(path)


## Whether two events are the same key or mouse button.
static func same_input(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return _physical(a) == _physical(b)
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	return false


## What a key or mouse button is called, lowercase ("space", "left click").
static func input_name(event: InputEvent) -> String:
	if event is InputEventKey:
		var code := _physical(event)
		var shown := DisplayServer.keyboard_get_keycode_from_physical(code) if DisplayServer.get_name() != "headless" else code
		return OS.get_keycode_string(shown if shown != KEY_NONE else code).to_lower()
	if event is InputEventMouseButton:
		var button := (event as InputEventMouseButton).button_index
		return MOUSE_NAMES.get(button, "mouse %d" % button)
	return ""


## How a binding is saved: "key:<physical keycode>" or "mouse:<button>".
static func event_text(event: InputEvent) -> String:
	if event is InputEventKey:
		return "key:%d" % _physical(event)
	if event is InputEventMouseButton:
		return "mouse:%d" % (event as InputEventMouseButton).button_index
	return ""


static func event_from_text(text: String) -> InputEvent:
	var parts := text.split(":")
	if parts.size() != 2 or not parts[1].is_valid_int() or parts[1].to_int() <= 0:
		return null
	if parts[0] == "key":
		var k := InputEventKey.new()
		k.physical_keycode = parts[1].to_int() as Key
		return k
	if parts[0] == "mouse":
		var m := InputEventMouseButton.new()
		m.button_index = parts[1].to_int() as MouseButton
		return m
	return null


# The action's keys and mouse buttons, in order (gamepad events aside).
static func _events(action: StringName) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	if not InputMap.has_action(action):
		return out
	for e in InputMap.action_get_events(action):
		if e is InputEventKey or e is InputEventMouseButton:
			out.append(e)
	return out


static func _set_events(action: StringName, events: Array[InputEvent]) -> void:
	if not InputMap.has_action(action):
		return
	for e in InputMap.action_get_events(action):
		if e is InputEventKey or e is InputEventMouseButton:
			InputMap.action_erase_event(action, e)
	for e in events.slice(0, SLOTS):
		InputMap.action_add_event(action, e)


static func _save_keys() -> void:
	var cfg := _load()
	for action: StringName in ACTIONS:
		var texts: PackedStringArray = []
		for e in _events(action):
			texts.append(event_text(e))
		cfg.set_value("keys", action, texts)
	cfg.save(path)


# A bare copy of the input (no modifiers, pressed state or position).
static func _clean(event: InputEvent) -> InputEvent:
	return event_from_text(event_text(event))


static func _physical(event: InputEventKey) -> Key:
	return event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode


# --- The file ---------------------------------------------------------------------

static func _load() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(path)
	return cfg


static func _save_value(section: String, key: String, value: Variant) -> void:
	var cfg := _load()
	cfg.set_value(section, key, value)
	cfg.save(path)
