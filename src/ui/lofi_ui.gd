class_name LofiUI
extends RefCounted
## The UI style kit (GDD §13.1): plain lowercase Arial-style text in white
## boxes with thin black frames, drawn on a small canvas and blown up soft,
## like the logo. Inverted black boxes mark emphasis, hover, and alerts.
## The only accents are heart pink and low-health red.

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
	t.set_stylebox(&"hover", &"Button", stylebox(Style.INVERTED))
	t.set_stylebox(&"pressed", &"Button", stylebox(Style.INVERTED))
	t.set_stylebox(&"hover_pressed", &"Button", stylebox(Style.INVERTED))
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
	panel.add_child(label)
	restyle(panel, style)
	return panel


static func set_text(panel: PanelContainer, text: String) -> void:
	(panel.get_child(0) as Label).text = text


static func restyle(panel: PanelContainer, style: Style) -> void:
	panel.add_theme_stylebox_override(&"panel", stylebox(style))
	(panel.get_child(0) as Label).add_theme_color_override(&"font_color", text_color(style))


## A text button in the house style.
static func button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(on_pressed)
	return b


## Pops a control in: a quick overshoot from small to full size.
static func pop(control: Control, from := 0.6, time := 0.22) -> void:
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2(from, from)
	control.create_tween().tween_property(control, "scale", Vector2.ONE, time) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A little sideways shake, for hits and alerts.
static func shake(control: Control, amount := 3.0, time := 0.25) -> void:
	var start := control.position
	var t := control.create_tween()
	for i in 5:
		t.tween_property(control, "position", start + Vector2(randf_range(-amount, amount), 0), time / 6.0)
	t.tween_property(control, "position", start, time / 6.0)
