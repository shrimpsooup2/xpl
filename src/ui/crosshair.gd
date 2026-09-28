class_name Crosshair
extends Control
## The crosshair and hit markers. Drawn at full resolution, unlike the rest
## of the UI, because aiming needs to be exact. Movement kicks the ticks
## apart for a moment (bump()); the centre dot never moves.

const GAP := 4.0
const TICK := 5.0
const THICK := 2.0
const MARK_INNER := 7.0
const MARK_OUTER := 13.0
## Extra tick gap (px) at bump strength 1, and how fast it closes again.
const BUMP_GAP := 6.0
const BUMP_DECAY := 7.0

var _mark_time := 0.0
var _mark_length := 0.0
var _mark_color := Color.WHITE
var _mark_scale := 1.0
var _bump := 0.0


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


## Spreads the ticks for a moment; strength 1 is a hard landing.
func bump(strength: float) -> void:
	_bump = maxf(_bump, clampf(strength, 0.0, 1.5) * LofiUI.motion)
	queue_redraw()


## Hooked to Player.movement_event.
func on_movement_event(e: Dictionary) -> void:
	match e.type:
		&"jump", &"mantle":
			bump(0.35)
		&"land":
			bump(clampf(e.impact_speed / 14.0, 0.0, 1.0))
		&"dash", &"wall_jump", &"slam_bounce":
			bump(0.7)
		&"slide_start":
			bump(0.3)
		&"smash_impact":
			bump(1.3)


func _process(delta: float) -> void:
	if _mark_time > 0.0:
		_mark_time = maxf(_mark_time - delta, 0.0)
		queue_redraw()
	if _bump > 0.0:
		_bump = maxf(_bump - BUMP_DECAY * lerpf(2.0, 1.0, LofiUI.smoothing) * delta * maxf(_bump, 0.3), 0.0)
		queue_redraw()


func _draw() -> void:
	var c := (size * 0.5).floor()
	var outline := Color(0, 0, 0, 0.8)
	for pass_i in 2:
		var col := outline if pass_i == 0 else Color.WHITE
		var pad := 1.0 if pass_i == 0 else 0.0
		draw_rect(Rect2(c - Vector2.ONE * (1 + pad), Vector2.ONE * (2 + pad * 2)), col)
		var gap := GAP + BUMP_GAP * _bump
		for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			var a := c + dir * gap
			var b := c + dir * (gap + TICK)
			draw_line(a - dir * pad, b + dir * pad, col, THICK + pad * 2)
	if _mark_time > 0.0:
		var t := _mark_time / _mark_length
		var col := Color(_mark_color, t)
		for dir: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
			var d := dir.normalized() * _mark_scale
			draw_line(c + d * MARK_INNER, c + d * MARK_OUTER, Color(0, 0, 0, t * 0.8), 4.0)
			draw_line(c + d * MARK_INNER, c + d * MARK_OUTER, col, 2.0)
