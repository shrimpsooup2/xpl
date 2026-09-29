class_name Crosshair
extends Control
## The crosshair and hit markers. Drawn at full resolution, unlike the rest
## of the UI, because aiming needs to be exact. Movement kicks the ticks
## apart for a moment (bump()); the centre dot never moves.
##
## Around it, a ring of the gun's rounds: one arc per round for guns that
## hold a dozen or fewer, one arc notched every ten for the rest. Spent
## rounds go dim from the end, the one just fired flicks outward; low turns
## red, empty blinks. Inside it, a thin arc fills while a slow gun cycles.
##
## Aiming down the sights the ticks close in and fade, leaving the dot on
## the sights (heart pink through a dot sight, like its reticle); a scope,
## once up, swaps it all for the scope.
##
## Further out, where you're being hit from: a red arc on a ring round it for
## each shooter, pointing at them (up is ahead, down is behind) and turning
## as you turn or they move, wider for harder hits, fading.

const GAP := 4.0
const TICK := 5.0
const THICK := 2.0
const MARK_INNER := 7.0
const MARK_OUTER := 13.0
## Extra tick gap (px) at bump strength 1, and how fast it closes again.
const BUMP_GAP := 6.0
const BUMP_DECAY := 7.0
const RING_RADIUS := 22.0
const RING_WIDTH := 3.0
const RING_GAP := 3.0  # Pixels between a segmented ring's arcs.
const RING_NOTCH := 2.0
const CYCLE_RADIUS := 16.0
## Guns slower than this show the cycle arc.
const CYCLE_SHOWN_FROM := 0.45
const SPENT_TIME := 0.2
## Damage direction: the ring's radius, how long an arc lasts, and its width
## (radians) and thickness for a light hit and for HURT_FULL damage or more.
const HURT_RADIUS := 50.0
const HURT_TIME := 1.4
const HURT_SPAN := Vector2(0.5, 1.0)
const HURT_THICK := Vector2(5.0, 8.0)
const HURT_FULL := 40.0
## An arc lands this far out and snaps in to the ring.
const HURT_PUNCH := 12.0
const HURT_PUNCH_TIME := 0.12

var _mark_time := 0.0
var _mark_length := 0.0
var _mark_color := Color.WHITE
var _mark_scale := 1.0
var _bump := 0.0
var capacity := 0
var ammo := 0
var _spent := 0.0  # Time left on the just-fired flick.
var _spent_index := -1
var _blink := 0.0
var _cycle := 1.0  # 0..1 through the gun's cycle; 1 is ready.
var _cycle_shown := false
var _aim := 0.0
var _sight := WeaponDef.Sight.IRON
## The view the damage arcs are worked out from.
var camera: Camera3D
# One per shooter: {from: Vector3, source: Player or null, left: seconds,
# strength: 0..1}.
var _hurts: Array[Dictionary] = []


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


## A gun in hand (capacity <= 0 hides the ring: fists).
func set_weapon(new_capacity: int, rounds: int, fire_interval := 0.0) -> void:
	capacity = new_capacity
	ammo = rounds
	_cycle_shown = fire_interval >= CYCLE_SHOWN_FROM
	_spent = 0.0
	queue_redraw()


func set_ammo(rounds: int) -> void:
	if rounds < ammo:
		_spent_index = rounds
		_spent = SPENT_TIME
	ammo = rounds
	queue_redraw()


## 0..1 through the gun's cycle (1: ready to fire).
func set_cycle(fraction: float) -> void:
	if not is_equal_approx(fraction, _cycle):
		_cycle = fraction
		queue_redraw()


## A dry click: the ring blinks red.
func click_empty() -> void:
	_blink = 1.0
	queue_redraw()


## How far the sights are up (0..1; WeaponHolder.aim), and what they are.
func set_aim(aim: float, sight: WeaponDef.Sight) -> void:
	if not is_equal_approx(aim, _aim) or sight != _sight:
		_aim = aim
		_sight = sight
		queue_redraw()


## Whether it's showing the scope.
func scoped() -> bool:
	return _sight == WeaponDef.Sight.SCOPE and _aim > Viewmodel.SCOPE_CUT


## A hit from `from` (Player.hurt_from): an arc pointing that way. Another
## hit from the same shooter renews theirs.
func hurt_from(from: Vector3, amount: float, source: Player = null) -> void:
	var strength := clampf(amount / HURT_FULL, 0.0, 1.0)
	for h in _hurts:
		if source != null and h.source == source:
			h.from = from
			h.left = HURT_TIME
			h.strength = maxf(h.strength, strength)
			h.landed = 0.0
			queue_redraw()
			return
	_hurts.append({"from": from, "source": source, "left": HURT_TIME, "strength": strength, "landed": 0.0})
	queue_redraw()


## Puts the damage arcs away (you respawned).
func clear_hurts() -> void:
	_hurts.clear()
	queue_redraw()


## Where each damage arc points, clockwise from straight ahead (0: in front,
## PI / 2: right, PI: behind), for tests.
func hurt_angles() -> Array[float]:
	var out: Array[float] = []
	for h in _hurts:
		out.append(_hurt_angle(h.from))
	return out


# Clockwise from ahead, seen from above: only which way you face counts,
# not how far up or down you look.
func _hurt_angle(from: Vector3) -> float:
	if camera == null or not is_instance_valid(camera):
		return 0.0
	var to := from - camera.global_position
	var forward := -camera.global_basis.z
	forward.y = 0.0
	to.y = 0.0
	if forward.length_squared() < 0.0001 or to.length_squared() < 0.0001:
		return 0.0
	return forward.normalized().signed_angle_to(to.normalized(), Vector3.DOWN)


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
	if _spent > 0.0 or _blink > 0.0 or (capacity > 0 and ammo == 0):
		_spent = maxf(_spent - delta, 0.0)
		_blink = maxf(_blink - delta * 3.0, 0.0)
		queue_redraw()
	if not _hurts.is_empty():
		for h in _hurts:
			h.left -= delta
			h.landed += delta
			# Follows whoever it was as they move.
			if h.source != null and is_instance_valid(h.source) and not (h.source as Player).is_dead:
				h.from = (h.source as Player).global_position + Vector3.UP * 1.4
		var kept: Array[Dictionary] = []
		for h in _hurts:
			if h.left > 0.0:
				kept.append(h)
		_hurts = kept
		queue_redraw()


func _draw() -> void:
	var c := (size * 0.5).floor()
	if scoped():
		_draw_scope(c)
		_draw_hurts(c)
		return
	_draw_hurts(c)
	_draw_ring(c)
	var outline := Color(0, 0, 0, 0.8)
	var ticks := 1.0 - _aim
	var dot := Color.WHITE.lerp(LofiUI.HEART, _aim if _sight == WeaponDef.Sight.DOT else 0.0)
	for pass_i in 2:
		var col := outline if pass_i == 0 else Color.WHITE
		var pad := 1.0 if pass_i == 0 else 0.0
		draw_rect(Rect2(c - Vector2.ONE * (1 + pad), Vector2.ONE * (2 + pad * 2)), col if pass_i == 0 else dot)
		if ticks <= 0.01:
			continue
		var gap := (GAP + BUMP_GAP * _bump) * lerpf(0.5, 1.0, ticks)
		for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			var a := c + dir * gap
			var b := c + dir * (gap + TICK * ticks)
			draw_line(a - dir * pad, b + dir * pad, Color(col, col.a * ticks), THICK + pad * 2)
	if _mark_time > 0.0:
		var t := _mark_time / _mark_length
		var col := Color(_mark_color, t)
		for dir: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
			var d := dir.normalized() * _mark_scale
			draw_line(c + d * MARK_INNER, c + d * MARK_OUTER, Color(0, 0, 0, t * 0.8), 4.0)
			draw_line(c + d * MARK_INNER, c + d * MARK_OUTER, col, 2.0)


func _draw_ring(c: Vector2) -> void:
	if capacity <= 0:
		return
	var low := float(ammo) / capacity <= AmmoMeter.LOW
	var flashing := (ammo == 0 and fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.25) or _blink > 0.5
	var on := LofiUI.ALERT if low or flashing else Color.WHITE
	var off := Color(1, 1, 1, 0.2) if not flashing else Color(LofiUI.ALERT, 0.5)
	var r := RING_RADIUS + BUMP_GAP * _bump * 0.5
	var segmented := AmmoMeter.is_segmented(capacity)
	var gap := RING_GAP / r if segmented else 0.0
	var step := TAU / capacity
	# From the top, clockwise; spent rounds go dim from the end.
	if segmented:
		for i in capacity:
			var from := -PI * 0.5 + i * step + gap * 0.5
			_arc(c, r, from, from + step - gap, on if i < ammo else off, i < ammo)
	else:
		var split := -PI * 0.5 + ammo * step
		if ammo < capacity:
			_arc(c, r, split, PI * 1.5, off, false)
		if ammo > 0:
			_arc(c, r, -PI * 0.5, split, on, true)
		for i in range(AmmoMeter.NOTCH_EVERY, capacity, AmmoMeter.NOTCH_EVERY):
			var a := -PI * 0.5 + i * step
			var d := Vector2(cos(a), sin(a))
			draw_line(c + d * (r - RING_WIDTH), c + d * (r + RING_WIDTH), Color(0, 0, 0, 0.8), RING_NOTCH)
	# The round just fired flicks outward and fades.
	if _spent > 0.0 and _spent_index >= 0 and _spent_index < capacity:
		var t := 1.0 - _spent / SPENT_TIME
		var from := -PI * 0.5 + _spent_index * step + gap * 0.5
		var to := from + maxf(step - gap, 0.08)
		draw_arc(c, r + 2.0 + 7.0 * t, from, to, 8, Color(on, 1.0 - t), RING_WIDTH * (1.0 - t * 0.5) + 1.0)
	# A slow gun cycling.
	if _cycle_shown and _cycle < 1.0:
		draw_arc(c, CYCLE_RADIUS, -PI * 0.5, -PI * 0.5 + TAU * _cycle, 32, Color(0, 0, 0, 0.6), 3.0)
		draw_arc(c, CYCLE_RADIUS, -PI * 0.5, -PI * 0.5 + TAU * _cycle, 32, Color(1, 1, 1, 0.85), 1.5)


## Each shooter's arc: snaps in from further out, holds, fades at the end.
func _draw_hurts(c: Vector2) -> void:
	for h in _hurts:
		var s: float = h.strength
		var mid := _hurt_angle(h.from) - PI * 0.5  # Screen angles start at the right.
		var half := lerpf(HURT_SPAN.x, HURT_SPAN.y, s) * 0.5
		var thick := lerpf(HURT_THICK.x, HURT_THICK.y, s)
		var landing := clampf(h.landed / HURT_PUNCH_TIME, 0.0, 1.0)
		var r := HURT_RADIUS + HURT_PUNCH * (1.0 - landing) * (1.0 - landing)
		var fade := clampf(h.left / (HURT_TIME * 0.4), 0.0, 1.0)
		var points := maxi(6, int(half * 2.0 * r / 3.0))
		draw_arc(c, r, mid - half, mid + half, points, Color(0, 0, 0, 0.7 * fade), thick + 2.0)
		draw_arc(c, r, mid - half, mid + half, points, Color(LofiUI.ALERT, fade), thick)
		# A notch in the middle, pointing out at them.
		var d := Vector2(cos(mid), sin(mid))
		var tip := c + d * (r + thick * 0.5 + 5.0)
		var side := d.orthogonal() * (thick * 0.5 + 2.0)
		var base := c + d * (r + thick * 0.5 - 0.5)
		draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), Color(LofiUI.ALERT, fade))


## One arc, with a dark outline when lit so it reads on bright skies.
func _arc(c: Vector2, r: float, from: float, to: float, color: Color, lit: bool) -> void:
	if to <= from:
		return
	var points := maxi(3, int((to - from) * r / 3.0))
	if lit:
		draw_arc(c, r, from, to, points, Color(0, 0, 0, 0.75), RING_WIDTH + 2.0)
	draw_arc(c, r, from, to, points, color, RING_WIDTH)


## Zoomed in: fine lines across a clear circle, the rest dimmed.
func _draw_scope(c: Vector2) -> void:
	var r := minf(size.x, size.y) * 0.42
	draw_arc(c, r + size.length() * 0.5, 0.0, TAU, 64, Color(0, 0, 0, 0.82), size.length())
	draw_arc(c, r, 0.0, TAU, 96, Color(0, 0, 0, 0.9), 4.0)
	for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(c + dir * 10.0, c + dir * r, Color(0, 0, 0, 0.85), 1.5)
		draw_line(c + dir * r * 0.6, c + dir * r, Color(0, 0, 0, 0.9), 4.0)
	draw_rect(Rect2(c - Vector2.ONE, Vector2.ONE * 2.0), LofiUI.HEART)
