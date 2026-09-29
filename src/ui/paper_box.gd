class_name PaperBox
extends StyleBox
## A box drawn like the logo: a white card with a thin black frame set a
## little inside its edge, so white shows all round the frame. Drawn by
## hand, not ruled: each box's margins, corners and frame lines are a touch
## off, differently for every box (from `hand`) and the same every frame.

## The card, the inside of the frame, and the frame.
var paper := Color.WHITE
var fill := Color.WHITE
var frame := Color.BLACK
## White showing around the frame, canvas pixels (each side varies from it).
var margin := 2.0
## How far the frame's corners and the card's stray from true, canvas pixels.
var wobble := 0.7
## Moves the whole box (a button lifting off, or pressing in).
var shift := Vector2.ZERO
## A hard shadow under the card, this far down and right (0: none).
var shadow := 0.0
## Which hand drew it: the seed for its imperfections.
var hand := 0


## A card for text of about `font_size`: the margin grows with the text, and
## `padding` is the room between the frame and the text. `nudge` moves the
## text (a hovered button's text slides with it).
static func make(font_size: int, padding := Vector2(3, 1), nudge := Vector2.ZERO) -> PaperBox:
	var box := PaperBox.new()
	box.margin = clampf(font_size * 0.2, 1.5, 8.0)
	box.wobble = clampf(font_size * 0.07, 0.5, 2.0)
	var side := box.margin + 1.0
	box.content_margin_left = side + padding.x + nudge.x
	box.content_margin_right = side + padding.x - nudge.x
	box.content_margin_top = side + padding.y + nudge.y
	box.content_margin_bottom = side + padding.y - nudge.y
	return box


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hand
	rect.position += shift
	var card := _corners(rect, rng, wobble * 0.6)
	# The frame sits in from each edge by a different amount.
	var inset := rect.grow_individual(-margin * rng.randf_range(0.6, 1.4), -margin * rng.randf_range(0.6, 1.4),
			-margin * rng.randf_range(0.6, 1.4), -margin * rng.randf_range(0.6, 1.4))
	var inner := _corners(inset, rng, wobble)
	if shadow > 0.0:
		var under := PackedVector2Array()
		for p in card:
			under.append(p + Vector2(shadow, shadow))
		RenderingServer.canvas_item_add_polygon(to_canvas_item, under, [Color(LofiUI.BLACK, 0.85)])
	RenderingServer.canvas_item_add_polygon(to_canvas_item, card, [paper])
	if fill != paper:
		RenderingServer.canvas_item_add_polygon(to_canvas_item, inner, [fill])
	var line := inner.duplicate()
	line.append(inner[0])
	RenderingServer.canvas_item_add_polyline(to_canvas_item, line, [frame], 1.0)


## `r`'s corners (clockwise from top left) nudged by up to `amount`, the
## same way every time for the same `hand`: for custom-drawn parts.
static func wobbly(r: Rect2, hand: int, amount: float) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hand
	return _corners(r, rng, amount)


## Draws the white card for a custom-drawn box whose frame sits on
## `frame_rect`, reaching `margin` past it. Draw what goes inside next, then
## draw_frame().
static func draw_card(item: CanvasItem, frame_rect: Rect2, hand: int, margin := 2.0) -> void:
	item.draw_colored_polygon(wobbly(frame_rect.grow(margin), hand, margin * 0.3), Color.WHITE)


## The crooked frame line for draw_card(), drawn last so fills stay inside.
static func draw_frame(item: CanvasItem, frame_rect: Rect2, hand: int, color := Color.BLACK) -> void:
	var line := wobbly(frame_rect, hand + 1, 0.4)
	line.append(line[0])
	item.draw_polyline(line, color, 1.0)


## The rect's corners (clockwise from top left), each nudged a little.
static func _corners(r: Rect2, rng: RandomNumberGenerator, amount: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		out.append(p + Vector2(rng.randf_range(-amount, amount), rng.randf_range(-amount, amount)))
	return out
