extends CanvasLayer
## Live tuning panel (F1). Lists every exported value on the player's
## MovementParams and ViewSettings; changes apply on the next tick.
##
## "Save" writes the movement values back to res://data/ when running from
## the editor, so tuned values can be committed (exported builds save to
## user://). The view values are your settings, so they're saved with them
## (Settings, user://settings.cfg), like the settings page does.

var _player: Player
var _panel: PanelContainer
var _rows: VBoxContainer
var _status: Label
var _editors: Array[Dictionary] = []  # { resource, property, control }


func _ready() -> void:
	layer = 10
	_player = get_tree().get_first_node_in_group(&"local_player") as Player
	_build()
	_panel.visible = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_tuning"):
		get_viewport().set_input_as_handled()
		_panel.visible = not _panel.visible
		if _panel.visible:
			_refresh_values()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_panel.offset_left = -420
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.18, 0.92)
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override(&"panel", style)
	add_child(_panel)

	var outer := VBoxContainer.new()
	_panel.add_child(outer)

	var title := Label.new()
	title.text = "Movement tuning"
	title.add_theme_font_size_override(&"font_size", 20)
	outer.add_child(title)

	var buttons := HBoxContainer.new()
	outer.add_child(buttons)
	_button(buttons, "Save", _save)
	_button(buttons, "Reset to defaults", _reset)
	_button(buttons, "Close (F1)", func() -> void:
		_panel.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)

	_status = Label.new()
	_status.modulate = Color(0.8, 0.9, 1.0)
	outer.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)

	if _player == null:
		_status.text = "No local player found."
		return
	_add_resource_section("Movement", _player.movement_params)
	_add_resource_section("View", _player.view_settings)


func _add_resource_section(heading: String, res: Resource) -> void:
	var header := Label.new()
	header.text = heading.to_upper()
	header.add_theme_font_size_override(&"font_size", 17)
	header.add_theme_color_override(&"font_color", Color(1.0, 0.75, 0.85))
	_rows.add_child(header)

	for prop in res.get_property_list():
		if prop.usage & PROPERTY_USAGE_GROUP:
			var group := Label.new()
			group.text = "— %s" % prop.name
			group.add_theme_color_override(&"font_color", Color(0.7, 0.85, 1.0))
			_rows.add_child(group)
			continue
		if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.usage & PROPERTY_USAGE_EDITOR):
			continue
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = String(prop.name).replace("_", " ")
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		row.add_child(name_label)

		var control: Control
		match prop.type:
			TYPE_BOOL:
				var box := CheckBox.new()
				box.toggled.connect(func(on: bool) -> void: res.set(prop.name, on))
				control = box
			TYPE_INT, TYPE_FLOAT:
				var spin := SpinBox.new()
				spin.custom_minimum_size.x = 120
				spin.allow_greater = true
				spin.allow_lesser = true
				if prop.hint == PROPERTY_HINT_RANGE:
					var parts := String(prop.hint_string).split(",")
					spin.min_value = float(parts[0])
					spin.max_value = float(parts[1])
					spin.step = float(parts[2]) if parts.size() > 2 else 0.01
				else:
					spin.step = 1.0 if prop.type == TYPE_INT else 0.01
				spin.rounded = prop.type == TYPE_INT
				spin.value_changed.connect(func(value: float) -> void:
					res.set(prop.name, int(value) if prop.type == TYPE_INT else value))
				control = spin
			_:
				continue
		row.add_child(control)
		_rows.add_child(row)
		_editors.append({"resource": res, "property": prop.name, "control": control})


func _refresh_values() -> void:
	for e in _editors:
		var value: Variant = e.resource.get(e.property)
		if e.control is CheckBox:
			(e.control as CheckBox).set_pressed_no_signal(value)
		elif e.control is SpinBox:
			(e.control as SpinBox).set_value_no_signal(value)


func _save() -> void:
	var saved: PackedStringArray = []
	if _player.view_settings == Settings.view():
		Settings.save_view()
		saved.append("%s (ok)" % Settings.path)
	for res: Resource in [_player.movement_params]:
		var path := res.resource_path
		if not OS.has_feature("editor") or path.is_empty():
			path = "user://%s" % res.resource_path.get_file()
		var err := ResourceSaver.save(res, path)
		saved.append("%s (%s)" % [path, "ok" if err == OK else error_string(err)])
	_status.text = "Saved: " + ", ".join(saved)


func _reset() -> void:
	for res: Resource in [_player.movement_params, _player.view_settings]:
		var fresh: Resource = res.get_script().new()
		for prop in res.get_property_list():
			if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				res.set(prop.name, fresh.get(prop.name))
	_refresh_values()
	_status.text = "Reset to code defaults (not saved)."


func _button(parent: Control, text: String, callback: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(callback)
	parent.add_child(b)
