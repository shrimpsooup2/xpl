class_name PauseMenu
extends Control
## Esc menu. The game keeps running underneath (it's multiplayer); the menu
## just takes the mouse and the keyboard until it closes. It snaps open: the
## dim fades in fast, the title stamps down, the buttons slide in one after
## another. Settings opens the settings page in its place (SettingsMenu);
## esc there comes back to the menu. In a game, your name, hat and colour
## sit in the corner to change (online, everyone sees it at once).

signal opened
signal closed

const MAIN_MENU := "res://scenes/main_menu.tscn"
const DIM := 0.35

var layer: LofiLayer
var player: Player
var is_open := false

var _panel: Control
var _center: CenterContainer
var _settings: SettingsMenu
var _shade: ColorRect
var _title: Control
var _fade: Tween
var _look: Control
var _hat_label: PanelContainer
var _color_label: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_shade = ColorRect.new()
	_shade.color = Color(0, 0, 0, DIM)
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_center = center
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 3)
	center.add_child(col)
	_title = LofiUI.box("paused", LofiUI.BIG, LofiUI.Style.INVERTED)
	col.add_child(_title)
	col.add_child(LofiUI.button("resume", close))
	if Game.current == null:
		col.add_child(LofiUI.button("respawn", func() -> void:
			close()
			if player:
				player.respawn()))
	col.add_child(LofiUI.button("settings", open_settings))
	col.add_child(LofiUI.button("tuning (f1)", func() -> void:
		close()
		var e := InputEventAction.new()
		e.action = &"debug_tuning"
		e.pressed = true
		Input.parse_input_event(e)))
	var online := NetSession.active()
	var hosting := online and NetSession.current.role == NetSession.Role.HOST
	if hosting and Game.current:
		col.add_child(LofiUI.button("end game (to the lobby)", func() -> void:
			close()
			NetSession.current.game_over()))
	var leave_text := "close the game" if hosting else "leave server" if online else "leave game" if Game.current else "main menu"
	col.add_child(LofiUI.button(leave_text, func() -> void:
		if NetSession.active():
			NetSession.leave(get_tree())
			Wipe.change_scene(get_tree(), MAIN_MENU)
		elif Game.current:
			Game.end(get_tree())
		else:
			Wipe.change_scene(get_tree(), MAIN_MENU)))
	col.add_child(LofiUI.button("quit", get_tree().quit))
	_panel = col
	if Game.current:
		var corner := MarginContainer.new()
		corner.set_anchors_preset(Control.PRESET_FULL_RECT)
		corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side in ["left", "top", "right", "bottom"]:
			corner.add_theme_constant_override("margin_" + side, 18)
		_look = _build_look()
		_look.size_flags_horizontal = Control.SIZE_SHRINK_END
		_look.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		corner.add_child(_look)
		add_child(corner)


## Your name, then [<] [hat] [>] and [<] [colour] [>], in quiet ghost boxes
## like on the title screen. A change shows in the game at once (Game.update_look).
func _build_look() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override(&"separation", 1)
	col.alignment = BoxContainer.ALIGNMENT_END
	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_END
	name_row.add_theme_constant_override(&"separation", 1)
	name_row.add_child(LofiUI.box("name:", LofiUI.SMALL, LofiUI.Style.GHOST))
	var field := LofiUI.field(Cosmetics.player_name, 84, Cosmetics.NAME_LENGTH)
	var commit := func() -> void:
		var was := Cosmetics.player_name
		Cosmetics.set_player_name(field.text)
		field.text = Cosmetics.player_name
		if Cosmetics.player_name != was:
			Game.update_look()
	field.focus_exited.connect(commit)
	field.text_submitted.connect(func(_t: String) -> void: field.release_focus())
	name_row.add_child(field)
	col.add_child(name_row)
	var hats: Array = []
	for id: StringName in Hats.ALL:
		hats.append("hat: " + Hats.NAMES[id])
	var hat_row := LofiUI.stepper(hats, func(by: int) -> void:
		Cosmetics.set_hat(Hats.ALL[posmod(Hats.ALL.find(Cosmetics.hat) + by, Hats.ALL.size())])
		_show_look()
		Game.update_look())
	_hat_label = hat_row.get_child(1)
	col.add_child(hat_row)
	var colors: Array = []
	for key: StringName in Hats.PALETTE:
		colors.append("colour: " + String(key))
	var color_row := LofiUI.stepper(colors, func(by: int) -> void:
		var keys := Hats.PALETTE.keys()
		Cosmetics.set_color(keys[posmod(keys.find(Cosmetics.color) + by, keys.size())])
		_show_look()
		Game.update_look())
	_color_label = color_row.get_child(1)
	col.add_child(color_row)
	_show_look()
	return col


func _show_look() -> void:
	LofiUI.set_text(_hat_label, "hat: " + Hats.NAMES[Cosmetics.hat])
	LofiUI.set_text(_color_label, "colour: " + String(Cosmetics.color))


## Esc: opens from gameplay, and while you're down watching someone; closes
## when open (from the settings page, back to the menu).
func toggle() -> void:
	if _settings:
		_settings.escape()
	elif is_open:
		close()
	elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not in_death_cinematic():
		open()


## Whether your death cinematic has the screen: it plays over everything,
## so the menu waits until it's over (and you're watching someone).
func in_death_cinematic() -> bool:
	return player != null and player.is_dead and player.death != null and player.death.is_active()


func open() -> void:
	is_open = true
	if _fade:
		_fade.kill()
	visible = true
	modulate.a = 1.0
	if layer:
		layer.interactive = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_shade.color.a = 0.0
	_shade.create_tween().tween_property(_shade, "color:a", DIM, 0.08)
	LofiUI.stamp(_title, 0.15, 1.8)
	var i := 0
	for b in _panel.get_children():
		if b is Button:
			LofiUI.enter(b, Vector2(-16, 0), 0.04 + i * 0.03, 0.22)
			i += 1
	opened.emit()


## The settings page in the menu's place.
func open_settings() -> void:
	if _settings:
		return
	_panel.visible = false
	if _look:
		_look.visible = false
	_settings = SettingsMenu.new()
	_settings.back.connect(close_settings)
	_center.add_child(_settings)


## Back from the settings page to the menu.
func close_settings() -> void:
	if _settings == null:
		return
	_settings.queue_free()
	_settings = null
	_panel.visible = true
	if _look:
		_look.visible = true
	var i := 0
	for b in _panel.get_children():
		if b is Button:
			LofiUI.enter(b, Vector2(-16, 0), i * 0.03, 0.22)
			i += 1


## Hands control back at once; the menu flicks away on its own.
func close() -> void:
	if not is_open:
		return
	close_settings()
	is_open = false
	if layer:
		layer.interactive = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 0.0, 0.1)
	_fade.tween_callback(func() -> void:
		visible = false
		modulate.a = 1.0)
	closed.emit()
