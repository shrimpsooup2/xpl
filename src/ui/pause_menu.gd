class_name PauseMenu
extends Control
## Esc menu. The game keeps running underneath (it's multiplayer); the menu
## just takes the mouse and the keyboard until it closes. It snaps open: the
## dim fades in fast, the title stamps down, the buttons slide in one after
## another.

signal opened
signal closed

const MAIN_MENU := "res://scenes/main_menu.tscn"
const DIM := 0.35

var layer: LofiLayer
var player: Player
var is_open := false

var _panel: Control
var _shade: ColorRect
var _title: Control
var _fade: Tween


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


## Esc: opens from gameplay, closes when open.
func toggle() -> void:
	if is_open:
		close()
	elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not (player and player.is_dead):
		open()


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


## Hands control back at once; the menu flicks away on its own.
func close() -> void:
	if not is_open:
		return
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
