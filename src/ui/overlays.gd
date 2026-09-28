class_name Overlays
extends Control
## Full-screen moments on the low-res canvas (GDD §13.4): the map title card
## and countdown, the round result, the scoreboard, and the match end.
## Rounds (M3) will drive these; for now F8 cycles through previews with
## made-up data.

signal card_finished

const COUNTDOWN := ["3", "2", "1", "go"]
const COUNT_STEP := 0.55
const LOAD_TIME := 0.8
const LOAD_CELLS := 12

var _current: Control
var _scoreboard: Control
var _preview_index := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## "round 3" over the map's name, a fake loading bar, then 3-2-1-go.
func round_card(map_name: String, round_number: int, countdown := true) -> void:
	var col := _center_column()
	if round_number > 0:
		col.add_child(LofiUI.box("round %d" % round_number, LofiUI.SMALL, LofiUI.Style.GHOST))
	var title := LofiUI.box(map_name, LofiUI.BIG)
	col.add_child(title)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override(&"separation", 1)
	var cells: Array[PanelContainer] = []
	for i in LOAD_CELLS:
		var cell := LofiUI.box(" ", 4)
		cells.append(cell)
		bar.add_child(cell)
	col.add_child(bar)
	await get_tree().process_frame
	LofiUI.pop(title)

	var t := create_tween()
	for cell in cells:
		t.tween_callback(LofiUI.restyle.bind(cell, LofiUI.Style.INVERTED))
		t.tween_interval(LOAD_TIME / LOAD_CELLS)
	if countdown:
		for step: String in COUNTDOWN:
			t.tween_callback(_count.bind(col, step))
			t.tween_interval(COUNT_STEP)
	else:
		t.tween_interval(0.6)
	t.tween_callback(_clear)
	t.tween_callback(card_finished.emit)


func round_result(won: bool, left: int, right: int) -> void:
	var col := _center_column()
	var banner := LofiUI.box("round won" if won else "round lost", LofiUI.HUGE,
			LofiUI.Style.INVERTED if won else LofiUI.Style.NORMAL)
	col.add_child(banner)
	col.add_child(_score_row(left, right))
	await get_tree().process_frame
	LofiUI.pop(banner, 0.3, 0.3)
	_auto_clear(2.2)


## Hold-to-show table. rows: [name, rounds, kills, heartshots, ping].
func show_scoreboard(rows: Array) -> void:
	hide_scoreboard()
	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override(&"h_separation", 12)
	for header: String in ["", "rounds", "kills", "♥", "ping"]:
		var l := Label.new()
		l.text = header
		l.add_theme_font_size_override(&"font_size", LofiUI.SMALL)
		l.add_theme_color_override(&"font_color", LofiUI.GREY)
		grid.add_child(l)
	for row: Array in rows:
		for v in row:
			var l := Label.new()
			l.text = str(v)
			grid.add_child(l)
	box.add_child(grid)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)
	add_child(center)
	_scoreboard = center


func hide_scoreboard() -> void:
	if is_instance_valid(_scoreboard):
		_scoreboard.queue_free()
	_scoreboard = null


## rounds: [map, winner, how] per round.
func match_end(won: bool, left: int, right: int, rounds: Array) -> void:
	var col := _center_column()
	var banner := LofiUI.box("you won" if won else "you lost", LofiUI.HUGE,
			LofiUI.Style.INVERTED if won else LofiUI.Style.NORMAL)
	col.add_child(banner)
	col.add_child(_score_row(left, right))
	var list := PanelContainer.new()
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override(&"separation", 0)
	for i in rounds.size():
		var r: Array = rounds[i]
		var l := Label.new()
		l.text = "%d   %s   %s   %s" % [i + 1, r[0], r[1], r[2]]
		l.add_theme_font_size_override(&"font_size", LofiUI.SMALL)
		lines.add_child(l)
	list.add_child(lines)
	col.add_child(list)
	await get_tree().process_frame
	LofiUI.pop(banner, 0.3, 0.3)
	_auto_clear(5.0)


## Cycles through every overlay with placeholder data (debug, F8).
func preview_next() -> void:
	_preview_index = (_preview_index + 1) % 4
	match _preview_index:
		0:
			round_card("waiting room", 3)
		1:
			round_result(true, 3, 2)
		2:
			show_scoreboard([["you", 3, 5, 1, 12], ["them", 2, 3, 0, 48]])
			get_tree().create_timer(2.5).timeout.connect(hide_scoreboard)
		3:
			match_end(true, 7, 4, [
				["waiting room", "you", "hotkey"], ["food court eclipse", "them", "overdraw"],
				["aquarium server", "you", "♥ ping"], ["birthday.exe", "you", "fists"]])


# --- Helpers ------------------------------------------------------------------

func _center_column() -> VBoxContainer:
	_clear()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override(&"separation", 4)
	center.add_child(col)
	add_child(center)
	_current = center
	return col


func _score_row(left: int, right: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 3)
	row.add_child(LofiUI.box("you  %d" % left))
	row.add_child(LofiUI.box("%d  them" % right))
	return row


func _count(col: VBoxContainer, step: String) -> void:
	for c in col.get_children():
		c.queue_free()
	var b := LofiUI.box(step, LofiUI.HUGE, LofiUI.Style.INVERTED if step == "go" else LofiUI.Style.NORMAL)
	col.add_child(b)
	await get_tree().process_frame
	if is_instance_valid(b):
		LofiUI.pop(b, 1.5, 0.2)


func _auto_clear(after: float) -> void:
	var mine := _current
	get_tree().create_timer(after).timeout.connect(func() -> void:
		if _current == mine:
			_clear())


func _clear() -> void:
	if is_instance_valid(_current):
		_current.queue_free()
	_current = null
