class_name LofiSlider
extends Control
## A bar you drag, in the house style (LofiUI): a ghost box filled black up
## to the value, like the speed meter's cells. Click or drag along it, or
## use the wheel over it; LofiUI.slider() puts arrows either side and the
## value after it.

signal changed(value: float)

var value := 0.0
var low := 0.0
var high := 1.0
var step := 0.01

var _box: PaperBox
var _dragging := false


func _init(start: float, from: float, to: float, by: float, width: float) -> void:
	low = from
	high = to
	step = by
	value = _snap(start)
	custom_minimum_size = Vector2(width, LofiUI.FONT.get_height(LofiUI.SMALL) + 7.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_HSIZE
	_box = LofiUI.stylebox(LofiUI.Style.GHOST, LofiUI.SMALL, randi())


## Sets it without calling back (a reset, say).
func set_value_quietly(v: float) -> void:
	value = _snap(v)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_style_box(_box, rect)
	var inner := rect.grow(-(_box.margin + 2.0))
	var t := inverse_lerp(low, high, value) if high > low else 0.0
	if t > 0.0:
		draw_rect(Rect2(inner.position, Vector2(maxf(inner.size.x * t, 1.0), inner.size.y)), LofiUI.BLACK)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_LEFT:
			_dragging = b.pressed
			if b.pressed:
				_set_from(b.position.x)
			accept_event()
		elif b.pressed and b.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			nudge(1 if b.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_set_from((event as InputEventMouseMotion).position.x)
		accept_event()


## Moves it `by` steps.
func nudge(by: int) -> void:
	_change(value + step * by)


func _set_from(x: float) -> void:
	var inner := Rect2(Vector2.ZERO, size).grow(-(_box.margin + 2.0))
	_change(lerpf(low, high, clampf((x - inner.position.x) / maxf(inner.size.x, 1.0), 0.0, 1.0)))


func _change(v: float) -> void:
	v = _snap(v)
	if is_equal_approx(v, value):
		return
	value = v
	queue_redraw()
	changed.emit(value)


func _snap(v: float) -> float:
	return clampf(snappedf(v - low, step) + low if step > 0.0 else v, low, high)
