class_name LofiUI
extends RefCounted
## The UI style kit (GDD §13.1): plain lowercase Arial-style text on white
## cards like the logo's, a thin black frame set in from the card's edge so
## white shows all round it, drawn a little off by hand (PaperBox), on a small
## canvas blown up soft. Inverted boxes (black inside the frame) mark
## emphasis, hover, and alerts. The only accents are heart pink and
## low-health red.
##
## The motion kit (GDD §13.5) lives here too: nothing just appears or
## vanishes. Boxes spring in, stamp down, type out, roll their numbers, and
## leave with a flick. Every motion helper waits a frame for layout, so it
## works on controls inside containers.

enum Style { NORMAL, INVERTED, HEART, ALERT, GHOST }

const FONT := preload("res://assets/fonts/LiberationSans-Regular.ttf")
const WHITE := Color(1, 1, 1)
const BLACK := Color(0.05, 0.05, 0.06)
const GREY := Color(0.55, 0.55, 0.58)
const HEART := Color(1.0, 0.24, 0.45)
const ALERT := Color(0.9, 0.12, 0.12)

## Font sizes in canvas pixels (the canvas is ~270 px tall).
const SMALL := 8
const NORMAL := 10
const BIG := 16
const HUGE := 36

## Hard shadow under a lifted (hovered) button, and the custom-drawn HUD
## parts' card margin, in canvas pixels.
const SHADOW := Vector2(2, 2)
const CARD_MARGIN := 2.0

## How much the UI moves on its own: sway, shakes, kicks, and the idle
## wobble all scale with this (ViewSettings.ui_motion). Things still come
## and go at 0, they just don't shake.
static var motion := 1.0
## How smoothly things settle (ViewSettings.camera_smoothing): 0 snaps and
## drops straight off, 1 eases and wobbles into place.
static var smoothing := 0.0

static var _theme: Theme


## The shared theme: boxes, buttons, and labels.
static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = FONT
	t.default_font_size = NORMAL
	t.set_color(&"font_color", &"Label", BLACK)
	t.set_stylebox(&"panel", &"PanelContainer", stylebox(Style.NORMAL))
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		t.set_stylebox(state, &"Button", _button_box(state, 0))
	t.set_stylebox(&"focus", &"Button", StyleBoxEmpty.new())
	t.set_color(&"font_color", &"Button", BLACK)
	t.set_color(&"font_hover_color", &"Button", WHITE)
	t.set_color(&"font_pressed_color", &"Button", WHITE)
	t.set_color(&"font_hover_pressed_color", &"Button", WHITE)
	t.set_color(&"font_focus_color", &"Button", BLACK)
	t.set_color(&"font_disabled_color", &"Button", GREY)
	_theme = t
	return t


## A card in `style` for text of `size`, drawn by `hand` (see PaperBox): the
## same hand draws the same imperfections. White card, black frame; the
## inside of the frame is black when inverted, pink or red for the heart and
## alerts. Ghost boxes are a faint card with a grey frame.
static func stylebox(style: Style, size := NORMAL, hand := 0, nudge := Vector2.ZERO) -> PaperBox:
	var box := PaperBox.make(size, Vector2(3, 1), nudge)
	box.hand = hand
	match style:
		Style.INVERTED:
			box.fill = BLACK
		Style.HEART:
			box.fill = HEART
		Style.ALERT:
			box.fill = ALERT
		Style.GHOST:
			box.paper = Color(1, 1, 1, 0.55)
			box.fill = box.paper
			box.frame = GREY
	return box


## A button's box in `state`, drawn by `hand`. Hovered it inverts and lifts
## off a shadow, its text sliding right; pressed it sinks in. The margins
## always add up to the normal box's, so the button never changes size.
static func _button_box(state: StringName, hand: int) -> PaperBox:
	match state:
		&"hover":
			var box := stylebox(Style.INVERTED, NORMAL, hand, Vector2(3, 0))
			box.shift = -Vector2.ONE
			box.shadow = SHADOW.x + 1.0
			return box
		&"pressed", &"hover_pressed":
			var box := stylebox(Style.INVERTED, NORMAL, hand, Vector2(2, 1))
			box.shift = Vector2.ONE
			return box
		&"disabled":
			return stylebox(Style.GHOST, NORMAL, hand)
	return stylebox(Style.NORMAL, NORMAL, hand)


static func text_color(style: Style) -> Color:
	return BLACK if style == Style.NORMAL or style == Style.GHOST else WHITE


## A boxed piece of text. The label is the box's only child.
static func box(text: String, size := NORMAL, style := Style.NORMAL) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", size)
	# Typing out text keeps the box at its full size.
	label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	panel.add_child(label)
	panel.set_meta(&"size", size)
	restyle(panel, style)
	return panel


static func label_of(panel: PanelContainer) -> Label:
	return panel.get_child(0) as Label


static func set_text(panel: PanelContainer, text: String) -> void:
	label_of(panel).text = text


## Puts a box in `style`. The box keeps its hand, so it stays the same shape.
static func restyle(panel: PanelContainer, style: Style) -> void:
	panel.set_meta(&"style", style)
	if not panel.has_meta(&"hand"):
		panel.set_meta(&"hand", randi())
	panel.add_theme_stylebox_override(&"panel", stylebox(style, panel.get_meta(&"size", NORMAL), panel.get_meta(&"hand")))
	label_of(panel).add_theme_color_override(&"font_color", text_color(style))


static func style_of(panel: PanelContainer) -> Style:
	return panel.get_meta(&"style", Style.NORMAL) as Style


## A text button in the house style, drawn by its own hand: inverts and
## lifts off a shadow on hover, presses in on click.
static func button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var hand := randi()
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		b.add_theme_stylebox_override(state, _button_box(state, hand))
	b.pressed.connect(on_pressed)
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			pop(b, 1.08, 0.12))
	return b


## [<] [label] [>]: the label box wide enough for the longest of `texts`,
## so the arrows never jump; the arrows call `step` with -1 and 1.
static func stepper(texts: Array, step: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override(&"separation", 1)
	var ghost := stylebox(Style.GHOST, SMALL, randi())
	for by in [-1, 1]:
		var arrow := button("<" if by < 0 else ">", step.bind(by))
		arrow.add_theme_font_size_override(&"font_size", SMALL)
		arrow.add_theme_stylebox_override(&"normal", ghost)
		arrow.add_theme_color_override(&"font_color", GREY)
		row.add_child(arrow)
	var label := box("", SMALL, Style.GHOST)
	for text: String in texts:
		var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL).x
		label.custom_minimum_size.x = maxf(label.custom_minimum_size.x, ceilf(width) + 10.0)
	label_of(label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(label)
	row.move_child(label, 1)
	return row


## [<] [a bar] [>] [value]: a LofiSlider between arrows that step it, and
## the value after it (`format` turns it into text). `changed` gets each
## new value. slider_set() moves it without calling back.
static func slider(value: float, low: float, high: float, step: float, format: Callable, changed: Callable,
		width := 60.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 1)
	var bar := LofiSlider.new(value, low, high, step, width)
	var shown := box(format.call(bar.value), SMALL, Style.GHOST)
	for v: float in [low, high, (low + high) * 0.5]:
		var text_width := FONT.get_string_size(format.call(v), HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL).x
		shown.custom_minimum_size.x = maxf(shown.custom_minimum_size.x, ceilf(text_width) + 10.0)
	label_of(shown).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ghost := stylebox(Style.GHOST, SMALL, randi())
	for by in [-1, 1]:
		var arrow := button("<" if by < 0 else ">", bar.nudge.bind(by))
		arrow.add_theme_font_size_override(&"font_size", SMALL)
		arrow.add_theme_stylebox_override(&"normal", ghost)
		arrow.add_theme_color_override(&"font_color", GREY)
		row.add_child(arrow)
	row.add_child(bar)
	row.move_child(bar, 1)
	row.add_child(shown)
	bar.changed.connect(func(v: float) -> void:
		set_text(shown, format.call(v))
		changed.call(v))
	row.set_meta(&"bar", bar)
	row.set_meta(&"shown", shown)
	row.set_meta(&"format", format)
	return row


## Moves a slider() row to `value` without calling it back.
static func slider_set(row: HBoxContainer, value: float) -> void:
	var bar: LofiSlider = row.get_meta(&"bar")
	bar.set_value_quietly(value)
	set_text(row.get_meta(&"shown"), (row.get_meta(&"format") as Callable).call(bar.value))


## A small text field: a ghost box that firms up while you type in it. Enter
## lets go of it. `secret` hides what's typed (passwords).
static func field(text: String, width: float, max_length := 64, secret := false) -> LineEdit:
	var f := LineEdit.new()
	f.text = text
	f.max_length = max_length
	f.secret = secret
	f.custom_minimum_size.x = width
	f.add_theme_font_size_override(&"font_size", SMALL)
	f.add_theme_stylebox_override(&"normal", stylebox(Style.GHOST, SMALL, randi()))
	f.add_theme_stylebox_override(&"focus", stylebox(Style.NORMAL, SMALL, randi()))
	f.add_theme_color_override(&"font_color", BLACK)
	f.add_theme_color_override(&"font_placeholder_color", GREY)
	f.text_submitted.connect(func(_t: String) -> void: f.release_focus())
	return f


## A row of letter tiles, one box per character: for big banners that
## should land letter by letter (see tiles_in()).
static func tiles(text: String, size := HUGE, style := Style.INVERTED) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 1)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in text:
		if ch == " ":
			var gap := Control.new()
			gap.custom_minimum_size.x = size * 0.35
			row.add_child(gap)
		else:
			row.add_child(box(ch, size, style))
	return row


# --- Motion ---------------------------------------------------------------------
# All of these start on the next frame, once containers have laid the
# control out, and return immediately.

## Pops a control in: a quick overshoot from `from` scale to full size.
static func pop(control: Control, from := 0.6, time := 0.22) -> void:
	_after_layout(control, func() -> void:
		control.pivot_offset = control.size * 0.5
		control.scale = Vector2(from, from)
		control.create_tween().tween_property(control, "scale", Vector2.ONE, time) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))


## Slides a control in from `from` (canvas pixels away from its place) with
## an overshoot. Hidden until it starts.
static func enter(control: Control, from := Vector2(0, 8), delay := 0.0, time := 0.28) -> void:
	control.modulate.a = 0.0
	_after_layout(control, func() -> void:
		var t := control.create_tween()
		if delay > 0.0:
			t.tween_interval(delay)
		t.tween_callback(func() -> void:
			control.modulate.a = 1.0
			_slide(control, from, Vector2.ZERO, time, Tween.TRANS_BACK, Tween.EASE_OUT)))


## Flicks a control away toward `to` while fading, then frees it (or just
## hides it when free_after is false).
static func leave(control: Control, to := Vector2(0, -6), time := 0.16, free_after := true) -> void:
	if not is_instance_valid(control) or control.get_meta(&"leaving", false):
		return
	control.set_meta(&"leaving", true)
	_slide(control, Vector2.ZERO, to, time, Tween.TRANS_QUAD, Tween.EASE_IN)
	var t := control.create_tween()
	t.tween_property(control, "modulate:a", 0.0, time)
	if free_after:
		t.tween_callback(control.queue_free)
	else:
		t.tween_callback(func() -> void:
			control.visible = false
			control.modulate.a = 1.0
			control.set_meta(&"leaving", false))


## Slams a control down from big and crooked, and kicks the UI layer.
static func stamp(control: Control, kick_strength := 0.5, from := 2.2) -> void:
	control.modulate.a = 0.0
	_after_layout(control, func() -> void:
		control.modulate.a = 1.0
		control.pivot_offset = control.size * 0.5
		control.scale = Vector2(from, from)
		control.rotation = randf_range(-0.35, 0.35)
		var settle := randf_range(-0.04, 0.04)
		var t := control.create_tween().set_parallel()
		t.tween_property(control, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		t.tween_property(control, "rotation", settle, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.chain().tween_callback(kick.bind(control, kick_strength))
		settle(t.chain(), control, "rotation", 0.0))


## Blows a control up and away (for "go" and other exits with a bang).
static func burst(control: Control, to := 2.5, time := 0.3) -> void:
	if not is_instance_valid(control) or control.get_meta(&"leaving", false):
		return
	control.set_meta(&"leaving", true)
	control.pivot_offset = control.size * 0.5
	var t := control.create_tween().set_parallel()
	t.tween_property(control, "scale", Vector2(to, to), time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(control, "modulate:a", 0.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(control.queue_free)


## Opens a box sideways like a sign flipping round, then types its text.
static func type_in(panel: PanelContainer, chars_per_second := 30.0, delay := 0.0) -> void:
	var label := label_of(panel)
	label.visible_ratio = 0.0
	panel.modulate.a = 0.0
	_after_layout(panel, func() -> void:
		panel.pivot_offset = panel.size * 0.5
		var t := panel.create_tween()
		if delay > 0.0:
			t.tween_interval(delay)
		t.tween_callback(func() -> void:
			panel.modulate.a = 1.0
			panel.scale = Vector2(0.0, 1.0))
		t.tween_property(panel, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var count := maxi(label.get_total_character_count(), 1)
		t.tween_property(label, "visible_ratio", 1.0, count / chars_per_second))


## Rolls a boxed number from one value to another. `format` gets the value.
static func roll(panel: PanelContainer, from: int, to: int, time := 0.35, format := "%d") -> void:
	var t := panel.create_tween()
	t.tween_method(func(v: float) -> void: set_text(panel, format % roundi(v)), float(from), float(to), time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Shows a box in another style for a moment, then puts its style back.
static func flash(panel: PanelContainer, style := Style.INVERTED, time := 0.12) -> void:
	var base := style_of(panel)
	restyle(panel, style)
	panel.set_meta(&"style", base)
	panel.create_tween().tween_callback(func() -> void:
		if style_of(panel) == base:
			restyle(panel, base)).set_delay(time)


## Swaps a box between two styles until the returned tween is killed.
static func blink(panel: PanelContainer, a: Style, b: Style, period := 0.7) -> Tween:
	var t := panel.create_tween().set_loops()
	t.tween_callback(restyle.bind(panel, b)).set_delay(period * 0.5)
	t.tween_callback(restyle.bind(panel, a)).set_delay(period * 0.5)
	return t


## A heartbeat: two quick thumps, then a rest, until the tween is killed.
static func pulse(control: Control, amount := 0.12, period := 0.8) -> Tween:
	var t := control.create_tween().set_loops()
	t.tween_callback(func() -> void: control.pivot_offset = control.size * 0.5)
	for strength in [1.0, 0.6]:
		t.tween_property(control, "scale", Vector2.ONE * (1.0 + amount * strength), period * 0.08) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(control, "scale", Vector2.ONE, period * 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_interval(period * 0.56)
	return t


## A little sideways shake, for hits and alerts.
static func shake(control: Control, amount := 3.0, time := 0.25) -> void:
	amount *= motion
	if amount <= 0.0:
		return
	_after_layout(control, func() -> void:
		var start := control.position.x
		var t := control.create_tween()
		for i in 5:
			t.tween_property(control, "position:x", start + randf_range(-amount, amount), time / 6.0)
		t.tween_property(control, "position:x", start, time / 6.0))


## Drops a row of letter tiles in one after another, then kicks the layer.
static func tiles_in(row: HBoxContainer, stagger := 0.045, kick_strength := 0.6) -> void:
	var boxes := row.get_children().filter(func(c: Node) -> bool: return c is PanelContainer)
	for i in boxes.size():
		var tile: Control = boxes[i]
		tile.modulate.a = 0.0
		_after_layout(tile, func() -> void:
			tile.pivot_offset = tile.size * 0.5
			var t := tile.create_tween()
			t.tween_interval(i * stagger)
			t.tween_callback(func() -> void:
				tile.modulate.a = 1.0
				tile.rotation = randf_range(-0.5, 0.5)
				_slide(tile, Vector2(0, -28), Vector2.ZERO, 0.16, Tween.TRANS_QUAD, Tween.EASE_IN))
			t.tween_property(tile, "rotation", randf_range(-0.06, 0.06), 0.16)
			if i == boxes.size() - 1:
				t.tween_callback(kick.bind(tile, kick_strength))
			settle(t, tile, "rotation", 0.0))


## Slams a row of letter tiles down one after another, each from big and
## crooked, then kicks the layer on the last. Returns how long it takes.
static func stamp_tiles(row: HBoxContainer, stagger := 0.03, kick_strength := 0.5) -> float:
	var boxes := row.get_children().filter(func(c: Node) -> bool: return c is PanelContainer)
	for i in boxes.size():
		var tile: Control = boxes[i]
		tile.modulate.a = 0.0
		_after_layout(tile, func() -> void:
			tile.pivot_offset = tile.size * 0.5
			var t := tile.create_tween()
			tile.set_meta(&"motion", t)
			t.tween_interval(i * stagger)
			t.tween_callback(func() -> void:
				tile.modulate.a = 1.0
				tile.scale = Vector2.ONE * randf_range(2.2, 2.8)
				tile.rotation = randf_range(-0.6, 0.6))
			t.tween_property(tile, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			t.parallel().tween_property(tile, "rotation", randf_range(-0.12, 0.12), 0.12)
			if i == boxes.size() - 1:
				t.tween_callback(kick.bind(tile, kick_strength))
			settle(t, tile, "rotation", 0.0))
	return boxes.size() * stagger + 0.12


## Breaks a row of tiles apart: each one flies off from the middle with a
## spin and fades, then the row is freed.
static func shatter(row: Control, time := 0.3) -> void:
	if not is_instance_valid(row) or row.get_meta(&"leaving", false):
		return
	row.set_meta(&"leaving", true)
	var centre := row.size * 0.5
	for tile: Control in row.get_children():
		if tile.has_meta(&"motion"):
			(tile.get_meta(&"motion") as Tween).kill()
		tile.pivot_offset = tile.size * 0.5
		var away := (tile.position + tile.size * 0.5 - centre)
		var fly := (away.normalized() * randf_range(0.6, 1.0) + Vector2(randf_range(-0.3, 0.3), randf_range(-0.9, 0.2))) \
				* randf_range(35.0, 70.0)
		var t := tile.create_tween().set_parallel()
		t.tween_property(tile, "position", tile.position + fly, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(tile, "rotation", tile.rotation + randf_range(-3.0, 3.0), time)
		t.tween_property(tile, "scale", Vector2.ONE * 0.6, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(tile, "modulate:a", 0.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	row.create_tween().tween_callback(row.queue_free).set_delay(time)


## Shakes and punches the whole low-res layer (see LofiLayer.kick()).
static func kick(node: Node, strength := 0.5) -> void:
	if is_instance_valid(node) and node.is_inside_tree():
		node.get_tree().call_group(LofiLayer.GROUP, &"kick", strength)


# Brings a property back to rest: a quick snap when snappy, an elastic
# wobble when smooth.
static func settle(t: Tween, target: Object, property: String, rest: Variant) -> void:
	if smoothing >= 0.5:
		t.tween_property(target, property, rest, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	else:
		t.tween_property(target, property, rest, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


# Runs fn on the next frame, after containers have sorted their children.
# Skipped if the control is freed first (held weakly, so a freed control
# never reaches the callback).
static func _after_layout(control: Control, fn: Callable) -> void:
	if not control.is_inside_tree():
		control.ready.connect(_after_layout.bind(control, fn), CONNECT_ONE_SHOT)
		return
	var ref: WeakRef = weakref(control)
	var tree := control.get_tree()
	var asked_on := Engine.get_process_frames()
	await tree.process_frame
	# Asked before this frame's process_frame (from a network message, say:
	# they're read first)? Containers sort at the end of the frame: one more.
	if Engine.get_process_frames() == asked_on:
		await tree.process_frame
	if ref.get_ref() != null:
		fn.call()


# Moves a control from `from` to `to` (offsets from where layout put it).
# Each axis is tweened on its own, so a container re-sorting the other axis
# mid-move (a killfeed row pushed down by a new one) doesn't fight it.
static func _slide(control: Control, from: Vector2, to: Vector2, time: float, trans: Tween.TransitionType, easing: Tween.EaseType) -> void:
	var axes := [0, 1].filter(func(axis: int) -> bool: return not is_equal_approx(from[axis], to[axis]))
	if axes.is_empty():
		return
	var home := control.position
	var t := control.create_tween().set_parallel()
	for axis: int in axes:
		control.position[axis] = home[axis] + from[axis]
		t.tween_property(control, "position:x" if axis == 0 else "position:y", home[axis] + to[axis], time) \
				.set_trans(trans).set_ease(easing)
	var parent := control.get_parent()
	if parent is Container and to == Vector2.ZERO:
		t.chain().tween_callback(parent.queue_sort)
