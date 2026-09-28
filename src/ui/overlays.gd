class_name Overlays
extends Control
## Full-screen moments on the low-res canvas (GDD §13.4): the map title card
## and countdown, the round result, the scoreboard, and the match end.
## Rounds (M3) will drive these; for now F8 cycles through previews with
## made-up data.
##
## Every one of them makes an entrance (GDD §13.5): the map name types
## itself into a box that flips open, countdown numbers stamp down and "go"
## bursts, result banners land one letter tile at a time, and scores roll.

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
		var label := LofiUI.box("round %d" % round_number, LofiUI.SMALL, LofiUI.Style.GHOST)
		col.add_child(label)
		LofiUI.enter(label, Vector2(0, -10), 0.0, 0.25)
	var title := LofiUI.box(map_name, LofiUI.BIG)
	col.add_child(title)
	LofiUI.type_in(title, 28.0, 0.08)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override(&"separation", 1)
	var cells: Array[PanelContainer] = []
	for i in LOAD_CELLS:
		var cell := LofiUI.box(" ", 4)
		cells.append(cell)
		bar.add_child(cell)
		LofiUI.enter(cell, Vector2(0, 6), 0.1 + i * 0.015, 0.2)
	col.add_child(bar)

	# Bound to the card, so a newer overlay replacing it stops the sequence.
	var card := _current
	var t := card.create_tween()
	t.tween_interval(0.25)
	for cell in cells:
		t.tween_callback(_fill_cell.bind(cell))
		t.tween_interval(LOAD_TIME / LOAD_CELLS)
	if countdown:
		for step: String in COUNTDOWN:
			t.tween_callback(_count.bind(card, step))
			t.tween_interval(COUNT_STEP)
	else:
		t.tween_interval(0.6)
	t.tween_callback(_clear)
	t.tween_callback(card_finished.emit)


func round_result(won: bool, left: int, right: int) -> void:
	var col := _center_column()
	var banner := LofiUI.tiles("round won" if won else "round lost", LofiUI.HUGE,
			LofiUI.Style.INVERTED if won else LofiUI.Style.NORMAL)
	col.add_child(banner)
	LofiUI.tiles_in(banner, 0.045, 0.7 if won else 0.4)
	col.add_child(_score_row(left, right, won, 0.5))
	_auto_clear(2.4)


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
	for r in rows.size():
		for v in rows[r]:
			var l := Label.new()
			l.text = str(v)
			grid.add_child(l)
			LofiUI.enter(l, Vector2(-8, 0), 0.05 + r * 0.05, 0.2)
	box.add_child(grid)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)
	add_child(center)
	LofiUI.pop(box, 0.85, 0.15)
	_scoreboard = center


func hide_scoreboard() -> void:
	if is_instance_valid(_scoreboard):
		LofiUI.leave(_scoreboard, Vector2(0, -4), 0.08)
	_scoreboard = null


## rounds: [map, winner, how] per round.
func match_end(won: bool, left: int, right: int, rounds: Array) -> void:
	var col := _center_column()
	var banner := LofiUI.tiles("you won" if won else "you lost", LofiUI.HUGE,
			LofiUI.Style.INVERTED if won else LofiUI.Style.NORMAL)
	col.add_child(banner)
	LofiUI.tiles_in(banner, 0.06, 0.9 if won else 0.5)
	col.add_child(_score_row(left, right, won, 0.55))
	var list := PanelContainer.new()
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override(&"separation", 0)
	for i in rounds.size():
		var r: Array = rounds[i]
		var l := Label.new()
		l.text = "%d   %s   %s   %s" % [i + 1, r[0], r[1], r[2]]
		l.add_theme_font_size_override(&"font_size", LofiUI.SMALL)
		lines.add_child(l)
		LofiUI.enter(l, Vector2(-10, 0), 0.9 + i * 0.08, 0.2)
	list.add_child(lines)
	col.add_child(list)
	LofiUI.enter(list, Vector2(0, 10), 0.8, 0.25)
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


## "you 3 · 2 them"; the winner's number rolls up from the old score.
func _score_row(left: int, right: int, left_won: bool, delay: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 3)
	var you := LofiUI.box("you  %d" % (left - 1 if left_won else left))
	var them := LofiUI.box("%d  them" % (right if left_won else right - 1))
	row.add_child(you)
	row.add_child(them)
	LofiUI.enter(you, Vector2(-16, 0), delay, 0.25)
	LofiUI.enter(them, Vector2(16, 0), delay, 0.25)
	var winner := you if left_won else them
	var t := winner.create_tween()
	t.tween_interval(delay + 0.35)
	t.tween_callback(func() -> void:
		if left_won:
			LofiUI.roll(winner, left - 1, left, 0.2, "you  %d")
		else:
			LofiUI.roll(winner, right - 1, right, 0.2, "%d  them")
		LofiUI.flash(winner, LofiUI.Style.INVERTED, 0.4)
		LofiUI.pop(winner, 1.5, 0.3))
	return row


func _fill_cell(cell: PanelContainer) -> void:
	if not is_instance_valid(cell):
		return
	LofiUI.restyle(cell, LofiUI.Style.INVERTED)
	LofiUI.pop(cell, 1.8, 0.12)


## Each number is its own child of the centring container, so they stack
## on top of each other instead of pushing each other around.
func _count(card: Control, step: String) -> void:
	if not is_instance_valid(card) or card.get_meta(&"leaving", false):
		return
	for c: Control in card.get_children():
		LofiUI.burst(c, 1.6, 0.14)
	var go := step == "go"
	var b := LofiUI.box(step, LofiUI.HUGE, LofiUI.Style.INVERTED if go else LofiUI.Style.NORMAL)
	card.add_child(b)
	LofiUI.stamp(b, 0.9 if go else 0.35, 3.0 if go else 2.2)
	if go:
		b.create_tween().tween_callback(func() -> void: LofiUI.burst(b, 3.0, 0.35)).set_delay(0.3)


func _auto_clear(after: float) -> void:
	var mine := _current.get_instance_id()
	create_tween().tween_callback(func() -> void:
		if is_instance_valid(_current) and _current.get_instance_id() == mine:
			_clear()).set_delay(after)


## The current overlay flicks away.
func _clear() -> void:
	if is_instance_valid(_current):
		LofiUI.leave(_current, Vector2(0, -10), 0.18)
	_current = null
