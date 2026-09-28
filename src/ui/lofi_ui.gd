class_name LofiUI
extends RefCounted
## The UI style kit (GDD §13.1): plain lowercase Arial-style text in white
## boxes with thin black frames and hard shadows, drawn on a small canvas and
## blown up soft, like the logo. Inverted black boxes mark emphasis, hover,
## and alerts. The only accents are heart pink and low-health red.
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

## Hard drop shadow under every solid box, in canvas pixels.
const SHADOW := Vector2(2, 2)

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
	t.set_stylebox(&"normal", &"Button", stylebox(Style.NORMAL))
	t.set_stylebox(&"hover", &"Button", _button_box(-1, 3))
	t.set_stylebox(&"pressed", &"Button", _button_box(2, 0))
	t.set_stylebox(&"hover_pressed", &"Button", _button_box(2, 0))
	t.set_stylebox(&"focus", &"Button", StyleBoxEmpty.new())
	t.set_stylebox(&"disabled", &"Button", stylebox(Style.GHOST))
	t.set_color(&"font_color", &"Button", BLACK)
	t.set_color(&"font_hover_color", &"Button", WHITE)
	t.set_color(&"font_pressed_color", &"Button", WHITE)
	t.set_color(&"font_hover_pressed_color", &"Button", WHITE)
	t.set_color(&"font_focus_color", &"Button", BLACK)
	t.set_color(&"font_disabled_color", &"Button", GREY)
	_theme = t
	return t


static func stylebox(style: Style) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.set_border_width_all(1)
	box.content_margin_left = 4
	box.content_margin_right = 4
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	match style:
		Style.NORMAL:
			box.bg_color = WHITE
			box.border_color = BLACK
		Style.INVERTED:
			box.bg_color = BLACK
			box.border_color = BLACK
		Style.HEART:
			box.bg_color = HEART
			box.border_color = BLACK
		Style.ALERT:
			box.bg_color = ALERT
			box.border_color = BLACK
		Style.GHOST:
			box.bg_color = Color(1, 1, 1, 0.55)
			box.border_color = GREY
	if style != Style.GHOST:
		box.shadow_color = Color(BLACK, 0.85)
		box.shadow_size = 1
		box.shadow_offset = SHADOW
	return box


## Inverted button box moved by `shift` canvas pixels (negative lifts it off
## its shadow, positive presses it in), text riding along. The hover box
## also nudges the text right. Margins add up to the normal box's, so the
## button never changes size.
static func _button_box(shift: int, shadow: int) -> StyleBoxFlat:
	var box := stylebox(Style.INVERTED)
	box.expand_margin_left = -shift
	box.expand_margin_top = -shift
	box.expand_margin_right = shift
	box.expand_margin_bottom = shift
	var nudge := 3 if shift < 0 else shift
	box.content_margin_left = 4 + nudge
	box.content_margin_right = 4 - nudge
	box.content_margin_top = 1 + clampi(shift, 0, 1)
	box.content_margin_bottom = 1 - clampi(shift, 0, 1)
	box.shadow_offset = Vector2(shadow, shadow)
	box.shadow_size = 1 if shadow > 0 else 0
	return box


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
	restyle(panel, style)
	return panel


static func label_of(panel: PanelContainer) -> Label:
	return panel.get_child(0) as Label


static func set_text(panel: PanelContainer, text: String) -> void:
	label_of(panel).text = text


static func restyle(panel: PanelContainer, style: Style) -> void:
	panel.set_meta(&"style", style)
	panel.add_theme_stylebox_override(&"panel", stylebox(style))
	label_of(panel).add_theme_color_override(&"font_color", text_color(style))


static func style_of(panel: PanelContainer) -> Style:
	return panel.get_meta(&"style", Style.NORMAL) as Style


## A text button in the house style: lifts off its shadow on hover, presses
## in on click.
static func button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(on_pressed)
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			pop(b, 1.08, 0.12))
	return b


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
	var start := control.position
	var t := control.create_tween()
	for i in 5:
		t.tween_property(control, "position", start + Vector2(randf_range(-amount, amount), 0), time / 6.0)
	t.tween_property(control, "position", start, time / 6.0)


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
	if control.is_inside_tree():
		var ref: WeakRef = weakref(control)
		control.get_tree().process_frame.connect(func() -> void:
			if ref.get_ref() != null:
				fn.call(), CONNECT_ONE_SHOT)
	else:
		control.ready.connect(_after_layout.bind(control, fn), CONNECT_ONE_SHOT)


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
