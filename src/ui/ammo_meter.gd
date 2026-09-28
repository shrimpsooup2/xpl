class_name AmmoMeter
extends Control
## The primary's rounds as a column on the HUD (GDD §13.3). Its height is
## set by how much the gun holds, so a six-shooter's is short and an SMG's
## tall: you can tell what you're carrying without reading. A gun that
## holds a dozen or fewer is cut into one cell per round; bigger ones get a
## notch every ten. A tag rides the top of the fill with the exact count.
##
## Rounds leave from the top: each shot pops its cell off. A new gun grows
## its column in; a top-up rolls the fill back up. Low turns it red, empty
## blinks.

const BAR_WIDTH := 7.0
const TAG_WIDTH := 14.0
const TAG_GAP := 2.0
## Height = this × √capacity, so it keeps growing with capacity without a
## 50-round gun towering over the screen.
const HEIGHT_PER_ROOT := 9.0
const SEGMENTED_UP_TO := 12
const NOTCH_EVERY := 10
const LOW := 0.25
const POP_TIME := 0.28
const GROW_TIME := 0.25

var capacity := 0
var ammo := 0

var _shown := 0.0  # The fill being drawn, in rounds.
var _height := 0.0  # The column's height being drawn.
var _pops: Array[Vector2] = []  # (round index, age)
var _blink := 0.0
var _grow: Tween
var _roll: Tween


static func height_for(rounds: int) -> float:
	return roundf(HEIGHT_PER_ROOT * sqrt(maxf(rounds, 1)))


static func is_segmented(rounds: int) -> bool:
	return rounds <= SEGMENTED_UP_TO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_END
	custom_minimum_size = Vector2(TAG_WIDTH + TAG_GAP + BAR_WIDTH + LofiUI.SHADOW.x, 0)


## A new gun: the column grows to its size and fills.
func set_weapon(new_capacity: int, rounds: int) -> void:
	capacity = new_capacity
	ammo = rounds
	_pops.clear()
	_blink = 0.0
	if _roll:
		_roll.kill()
	_shown = float(rounds)
	var target := height_for(capacity)
	custom_minimum_size.y = target + LofiUI.SHADOW.y
	if _grow:
		_grow.kill()
	_height = 0.0
	_grow = create_tween()
	_grow.tween_property(self, "_height", target, GROW_TIME * LofiUI.motion + 0.001) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	queue_redraw()


func set_ammo(rounds: int) -> void:
	if rounds == ammo:
		return
	if rounds < ammo:
		for r in range(rounds, ammo):
			_pops.append(Vector2(r, 0.0))
		_shown = float(rounds)
	else:
		if _roll:
			_roll.kill()
		_roll = create_tween()
		_roll.tween_property(self, "_shown", float(rounds), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ammo = rounds
	queue_redraw()


## A dry click on an empty gun: the frame blinks red.
func click_empty() -> void:
	_blink = 1.0


func is_low() -> bool:
	return capacity > 0 and float(ammo) / capacity <= LOW


func _process(delta: float) -> void:
	var busy := not _pops.is_empty() or _blink > 0.0 or (ammo == 0 and capacity > 0)
	for i in range(_pops.size() - 1, -1, -1):
		_pops[i].y += delta
		if _pops[i].y >= POP_TIME:
			_pops.remove_at(i)
	_blink = maxf(_blink - delta * 3.0, 0.0)
	if busy or (_grow and _grow.is_running()) or (_roll and _roll.is_running()):
		queue_redraw()


func _draw() -> void:
	if capacity <= 0 or _height < 1.0:
		return
	var bar := Rect2(TAG_WIDTH + TAG_GAP, size.y - LofiUI.SHADOW.y - _height, BAR_WIDTH, _height)
	var inner := bar.grow(-0.5)
	var low := is_low()
	var empty := ammo == 0
	var flashing := empty and fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.25
	var frame := LofiUI.ALERT if flashing or _blink > 0.5 else LofiUI.BLACK
	var fill := LofiUI.ALERT if low else LofiUI.BLACK
	# Shadow, box, fill from the bottom.
	draw_rect(Rect2(bar.position + LofiUI.SHADOW, bar.size), Color(LofiUI.BLACK, 0.6))
	draw_rect(bar, LofiUI.WHITE)
	var level := _level(inner, _shown)
	draw_rect(Rect2(inner.position.x, level, inner.size.x, inner.end.y - level), fill)
	# Cells or notches.
	if is_segmented(capacity):
		for i in range(1, capacity):
			var y := _level(inner, i)
			draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), LofiUI.WHITE, 1.0)
	else:
		for i in range(NOTCH_EVERY, capacity, NOTCH_EVERY):
			var y := _level(inner, i)
			draw_line(Vector2(inner.position.x, y), Vector2(inner.position.x + 2.0, y), LofiUI.GREY, 1.0)
			draw_line(Vector2(inner.end.x - 2.0, y), Vector2(inner.end.x, y), LofiUI.GREY, 1.0)
	draw_rect(bar, frame, false, 1.0)
	# Spent rounds pop off the top and fall away.
	for p in _pops:
		var t := p.y / POP_TIME
		var top := _level(inner, p.x + 1.0)
		var bottom := _level(inner, p.x)
		var cell := Rect2(inner.position.x, top, inner.size.x, maxf(bottom - top, 1.0))
		cell.position += Vector2(4.0 + 6.0 * t, -6.0 * t + 10.0 * t * t) * LofiUI.motion
		draw_rect(cell.grow(1.0 - t), Color(fill, 1.0 - t))
	# The count, riding the top of the fill.
	var text := str(ammo)
	var font := LofiUI.FONT
	var tag := Rect2(0, clampf(level - 5.0, bar.position.y - 2.0, bar.end.y - 11.0), TAG_WIDTH, 11)
	draw_rect(Rect2(tag.position + Vector2(1, 1), tag.size), Color(LofiUI.BLACK, 0.5))
	draw_rect(tag, LofiUI.ALERT if low else LofiUI.WHITE)
	draw_rect(tag, LofiUI.BLACK, false, 1.0)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LofiUI.SMALL).x
	draw_string(font, Vector2(tag.position.x + (tag.size.x - width) * 0.5, tag.position.y + 8.5), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, LofiUI.SMALL, LofiUI.WHITE if low else LofiUI.BLACK)


## The y of the top of `rounds` rounds.
func _level(inner: Rect2, rounds: float) -> float:
	return roundf(inner.end.y - inner.size.y * clampf(rounds / capacity, 0.0, 1.0))
