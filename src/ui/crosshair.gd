class_name Crosshair
extends Control
## The crosshair and hit markers. Drawn at full resolution, unlike the rest
## of the UI, because aiming needs to be exact.

const GAP := 4.0
const TICK := 5.0
const THICK := 2.0
const MARK_INNER := 7.0
const MARK_OUTER := 13.0

var _mark_time := 0.0
var _mark_length := 0.0
var _mark_color := Color.WHITE
var _mark_scale := 1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Flashes a hit marker. kind: &"hit", &"head", &"heart", or &"kill".
func hit(kind: StringName) -> void:
	match kind:
		&"heart":
			_mark_color = LofiUI.HEART
			_mark_length = 0.45
			_mark_scale = 1.6
		&"kill":
			_mark_color = LofiUI.ALERT
			_mark_length = 0.3
			_mark_scale = 1.3
		&"head":
			_mark_color = Color(1.0, 0.9, 0.3)
			_mark_length = 0.16
			_mark_scale = 1.1
		_:
			_mark_color = Color.WHITE
			_mark_length = 0.12
			_mark_scale = 1.0
	_mark_time = _mark_length
	queue_redraw()


func _process(delta: float) -> void:
	if _mark_time > 0.0:
		_mark_time = maxf(_mark_time - delta, 0.0)
		queue_redraw()


func _draw() -> void:
	var c := (size * 0.5).floor()
	var outline := Color(0, 0, 0, 0.8)
	for pass_i in 2:
		var col := outline if pass_i == 0 else Color.WHITE
		var pad := 1.0 if pass_i == 0 else 0.0
		draw_rect(Rect2(c - Vector2.ONE * (1 + pad), Vector2.ONE * (2 + pad * 2)), col)
		for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			var a := c + dir * GAP
			var b := c + dir * (GAP + TICK)
			draw_line(a - dir * pad, b + dir * pad, col, THICK + pad * 2)
	if _mark_time > 0.0:
		var t := _mark_time / _mark_length
		var col := Color(_mark_color, t)
		for dir: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
			var d := dir.normalized() * _mark_scale
			draw_line(c + d * MARK_INNER, c + d * MARK_OUTER, Color(0, 0, 0, t * 0.8), 4.0)
			draw_line(c + d * MARK_INNER, c + d * MARK_OUTER, col, 2.0)
