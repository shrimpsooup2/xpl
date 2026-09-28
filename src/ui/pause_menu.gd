class_name PauseMenu
extends Control
## Esc menu. The game keeps running underneath (it's multiplayer); the menu
## just takes the mouse and the keyboard until it closes.

signal opened
signal closed

const MAIN_MENU := "res://scenes/main_menu.tscn"

var layer: LofiLayer
var player: Player
var is_open := false

var _panel: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 3)
	center.add_child(col)
	col.add_child(LofiUI.box("paused", LofiUI.BIG, LofiUI.Style.INVERTED))
	col.add_child(LofiUI.button("resume", close))
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
	col.add_child(LofiUI.button("main menu", func() -> void:
		get_tree().change_scene_to_file.call_deferred(MAIN_MENU)))
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
	visible = true
	if layer:
		layer.interactive = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	LofiUI.pop(_panel, 0.85, 0.15)
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	if layer:
		layer.interactive = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()
