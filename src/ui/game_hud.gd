class_name GameHud
extends Control
## The in-round HUD (GDD §13.3), on the low-res canvas. Minimal and boxed:
##
##   top centre     score · round timer · score, map name underneath
##   top right      killfeed
##   bottom left    health
##   bottom centre  speed meter over the dash charges
##   bottom right   throwable, weapon and ammo
##   centre         pickup prompt below the crosshair, pop-ups above it
##
## It's alive (GDD §13.5): the whole HUD hangs off the view on a spring, so
## it lags behind mouse look, leans into strafes, and gets knocked around by
## jumps, landings, dashes, and smashdowns. Numbers roll, boxes pop, the
## killfeed slides, pop-ups stamp down. When an impact frame fires it takes
## the hit with the camera (impact()).
##
## Movement values are live. Health, weapons, and scores are placeholders
## until combat (M2) and rounds (M3) exist; the setters below are the API
## those systems will call.

const MARGIN := 8
const KILLFEED_MAX := 5
const KILLFEED_TIME := 5.0
const LOW_HEALTH := 30
## The timer counts down loudly for this many seconds, and turns red for
## the last few.
const TIMER_TENSE := 10
const TIMER_PANIC := 5

# Sway (canvas pixels): a damped spring pulled by look speed and velocity.
## (snappy, smooth), blended by camera smoothing.
const SWAY_SPRING := Vector2(420.0, 140.0)
const SWAY_DAMPING := Vector2(40.0, 15.0)
## Pixels per rad/s of mouse look.
const SWAY_LOOK := 0.9
## Pixels per m/s of vertical speed (falling lifts the HUD).
const SWAY_FALL := 0.12
const SWAY_MAX := 7.0
## Radians of lean per m/s of sideways speed.
const LEAN := 0.0022
# Knocks from movement events, in pixels per second of spring velocity.
const KNOCK_JUMP := 35.0
const KNOCK_LAND_PER_SPEED := 5.0
const KNOCK_LAND_MAX := 110.0
const KNOCK_DASH := 70.0
const KNOCK_SMASH := 150.0
## Seconds that turn a knock impulse into an instant displacement (snappy).
const KNOCK_SNAP := 0.05
## Pop-ups sit this far above the crosshair and drift up by POPUP_DRIFT.
const POPUP_Y := -34.0
const POPUP_DRIFT := 6.0
# Taking an impact frame's hit (at strength 1): zoom in with the camera's
# punch (fraction of scale, on the same spring) and each group's rattle
# (radians).
const IMPACT_ZOOM := 0.07
const IMPACT_RATTLE := 0.09

var player: Player

var _score_left: PanelContainer
var _timer: PanelContainer
var _score_right: PanelContainer
var _map: PanelContainer
var _alert: PanelContainer
var _alert_blink: Tween
var _health_row: HBoxContainer
var _health: PanelContainer
var _heartbeat: Tween
var _weapon: PanelContainer
var _ammo: PanelContainer
var _throwable: PanelContainer
var _speed: PanelContainer
var _meter: Meter
var _pips: Pips
var _killfeed: VBoxContainer
var _prompt: PanelContainer
var _popup_anchor: CenterContainer
var _fades := {}
var _elapsed := 0.0
var _timer_seconds := -1.0  # < 0: count up (sandbox).
var _timer_whole := -1
var _health_value := 100
var _ammo_value := -1
var _weapon_name := "fists"
var _scores := [0, 0]
var _sway := Vector2.ZERO
var _sway_velocity := Vector2.ZERO
var _last_look := Vector2.ZERO
var _has_look := false
var _impact_time := INF
var _impact_zoom := 0.0
var _popup_drift: Tween


## Dash charge boxes: filled when ready, filling up while recharging. A used
## charge flashes; a recharged one pops.
class Pips extends Control:
	var count := 2
	var charged := 2
	var progress := 0.0
	var _flash: Array[float] = []
	var _bump: Array[float] = []

	func update(new_count: int, new_charged: int, new_progress: float, delta: float) -> void:
		_flash.resize(new_count)
		_bump.resize(new_count)
		for i in new_count:
			_flash[i] = maxf(_flash[i] - delta * 5.0, 0.0)
			_bump[i] = maxf(_bump[i] - delta * 5.0, 0.0)
		if new_charged < charged and new_charged < new_count:
			_flash[new_charged] = 1.0
		elif new_charged > charged and new_charged - 1 < new_count:
			_bump[new_charged - 1] = 1.0
		count = new_count
		charged = new_charged
		progress = new_progress
		queue_redraw()

	func _draw() -> void:
		var w := 9.0
		var gap := 3.0
		var total := count * w + (count - 1) * gap
		var x := (size.x - total) * 0.5
		for i in count:
			var r := Rect2(x + i * (w + gap), 0, w, 5)
			var grow := (_bump[i] if i < _bump.size() else 0.0) * 2.0
			r = r.grow(grow)
			draw_rect(Rect2(r.position + LofiUI.SHADOW * 0.5, r.size), Color(LofiUI.BLACK, 0.6))
			draw_rect(r, LofiUI.WHITE)
			if i < charged:
				draw_rect(r, LofiUI.BLACK)
			elif i == charged:
				draw_rect(Rect2(r.position, Vector2(r.size.x * progress, r.size.y)), LofiUI.GREY)
			if i < _flash.size() and _flash[i] > 0.0:
				draw_rect(r.grow(_flash[i] * 2.0), Color(LofiUI.WHITE, _flash[i]))
			draw_rect(r, LofiUI.BLACK, false, 1.0)


## Speed as a row of cells that get taller left to right, like a volume
## meter, sitting right over the dash charges. A grey cell marks the recent
## peak; past the soft cap the whole thing jitters.
class Meter extends Control:
	const CELLS := 12
	const CELL_W := 4.0
	const GAP := 1.0
	var value := 0.0  # 0..1 of the soft cap.
	var peak := 0.0
	var over := false

	func _init() -> void:
		custom_minimum_size = Vector2(CELLS * (CELL_W + GAP) - GAP, 9)

	func _draw() -> void:
		var jitter := Vector2(randf_range(-0.7, 0.7), randf_range(-0.7, 0.7)) * LofiUI.motion if over else Vector2.ZERO
		var peak_cell := int(peak * CELLS) - 1
		for i in CELLS:
			var h := lerpf(3.0, size.y, float(i) / (CELLS - 1))
			var r := Rect2(i * (CELL_W + GAP), size.y - h, CELL_W, h)
			r.position += jitter * (float(i) / CELLS)
			if value * CELLS > i + 0.25:
				draw_rect(r, LofiUI.BLACK)
			elif i == peak_cell:
				draw_rect(r, LofiUI.GREY)
			else:
				draw_rect(r, Color(1, 1, 1, 0.6))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 3)
	_score_left = LofiUI.box("sandbox")
	_timer = LofiUI.box("0:00", LofiUI.NORMAL, LofiUI.Style.INVERTED)
	_score_right = LofiUI.box("")
	_score_right.visible = false
	for b in [_score_left, _timer, _score_right]:
		top.add_child(b)
	_anchor(top, Control.PRESET_CENTER_TOP, Vector2(0, MARGIN))
	_map = LofiUI.box("test course", LofiUI.SMALL, LofiUI.Style.GHOST)
	_anchor(_map, Control.PRESET_CENTER_TOP, Vector2(0, MARGIN + 17))
	_alert = LofiUI.box("", LofiUI.NORMAL, LofiUI.Style.ALERT)
	_alert.visible = false
	_anchor(_alert, Control.PRESET_CENTER_TOP, Vector2(0, MARGIN + 32))

	_health_row = HBoxContainer.new()
	_health_row.add_theme_constant_override(&"separation", 2)
	_health_row.alignment = BoxContainer.ALIGNMENT_END
	_health_row.add_child(LofiUI.box("hp", LofiUI.SMALL, LofiUI.Style.GHOST))
	_health = LofiUI.box("100", LofiUI.BIG)
	_health_row.add_child(_health)
	_anchor(_health_row, Control.PRESET_BOTTOM_LEFT, Vector2(MARGIN, -MARGIN))

	var weapon_col := VBoxContainer.new()
	weapon_col.add_theme_constant_override(&"separation", 2)
	weapon_col.alignment = BoxContainer.ALIGNMENT_END
	_throwable = LofiUI.box("", LofiUI.SMALL, LofiUI.Style.GHOST)
	_throwable.visible = false
	_throwable.size_flags_horizontal = Control.SIZE_SHRINK_END
	weapon_col.add_child(_throwable)
	var weapon_row := HBoxContainer.new()
	weapon_row.add_theme_constant_override(&"separation", 2)
	weapon_row.alignment = BoxContainer.ALIGNMENT_END
	_weapon = LofiUI.box("fists")
	_ammo = LofiUI.box("", LofiUI.BIG)
	_ammo.visible = false
	weapon_row.add_child(_weapon)
	weapon_row.add_child(_ammo)
	weapon_col.add_child(weapon_row)
	_anchor(weapon_col, Control.PRESET_BOTTOM_RIGHT, Vector2(-MARGIN, -MARGIN))

	# Speed meter stacked on the dash charges, the number boxed to the left.
	_meter = Meter.new()
	_anchor(_meter, Control.PRESET_CENTER_BOTTOM, Vector2(0, -MARGIN - 9))
	_pips = Pips.new()
	_pips.custom_minimum_size = Vector2(_meter.custom_minimum_size.x, 5)
	_anchor(_pips, Control.PRESET_CENTER_BOTTOM, Vector2(0, -MARGIN - 2))
	_speed = LofiUI.box("0", LofiUI.NORMAL)
	_speed.custom_minimum_size.x = 20
	LofiUI.label_of(_speed).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchor(_speed, Control.PRESET_CENTER_BOTTOM, Vector2(-_meter.custom_minimum_size.x * 0.5 - 14, -MARGIN - 1))

	_killfeed = VBoxContainer.new()
	_killfeed.add_theme_constant_override(&"separation", 2)
	_anchor(_killfeed, Control.PRESET_TOP_RIGHT, Vector2(-MARGIN, MARGIN))

	_prompt = LofiUI.box("")
	_prompt.visible = false
	_anchor(_prompt, Control.PRESET_CENTER, Vector2(0, 26))

	# Full-screen centring, nudged up to sit above the crosshair.
	_popup_anchor = CenterContainer.new()
	_popup_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_popup_anchor)
	_popup_anchor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup_anchor.offset_top = POPUP_Y
	_popup_anchor.offset_bottom = POPUP_Y

	visibility_changed.connect(func() -> void:
		if visible:
			_arrive())
	_arrive()


func _process(delta: float) -> void:
	_elapsed += delta
	_update_timer(delta)
	if player:
		var st := player.state
		var p := player.movement_params
		_pips.update(p.dash_charges, st.dash_charges, st.dash_recharge_timer / p.dash_recharge, delta)
		_update_speed(delta)
	_update_sway(delta)


# --- API for combat and rounds -----------------------------------------------

func set_health(value: int) -> void:
	var old := _health_value
	_health_value = value
	if value == old:
		return
	LofiUI.roll(_health, old, value, 0.3)
	LofiUI.restyle(_health, LofiUI.Style.ALERT if value <= LOW_HEALTH else LofiUI.Style.NORMAL)
	if value < old:
		LofiUI.shake(_health_row)  # The whole row: boxes inside it can't move.
		LofiUI.pop(_health, 1.35, 0.2)
		LofiUI.kick(self, clampf((old - value) / 60.0, 0.15, 0.7))
	var low := value > 0 and value <= LOW_HEALTH
	if low and _heartbeat == null:
		_heartbeat = LofiUI.pulse(_health_row, 0.12, 0.7)
	elif not low and _heartbeat != null:
		_heartbeat.kill()
		_heartbeat = null
		_health_row.scale = Vector2.ONE


## weapon_name "" or "fists" means empty-handed; ammo < 0 hides the count.
func set_weapon(weapon_name: String, ammo := -1) -> void:
	weapon_name = weapon_name if not weapon_name.is_empty() else "fists"
	if weapon_name != _weapon_name:
		_weapon_name = weapon_name
		LofiUI.set_text(_weapon, weapon_name)
		LofiUI.type_in(_weapon, 45.0)
		_ammo_value = -1
	_ammo.visible = ammo >= 0
	if ammo >= 0:
		if _ammo_value < 0 or ammo > _ammo_value:
			LofiUI.roll(_ammo, maxi(_ammo_value, 0), ammo, 0.25)
			LofiUI.pop(_ammo, 0.6)
		else:
			LofiUI.set_text(_ammo, str(ammo))
			if ammo < _ammo_value:
				LofiUI.pop(_ammo, 1.3, 0.12)
		LofiUI.restyle(_ammo, LofiUI.Style.ALERT if ammo == 0 else LofiUI.Style.NORMAL)
		if ammo == 0 and _ammo_value != 0:
			LofiUI.shake(_ammo.get_parent().get_parent())
	_ammo_value = ammo


func set_throwable(throwable_name: String, count: int) -> void:
	var was_visible := _throwable.visible
	_throwable.visible = count > 0
	LofiUI.set_text(_throwable, "%s ×%d" % [throwable_name, count])
	if count > 0:
		LofiUI.pop(_throwable, 1.3 if was_visible else 0.5, 0.18)


## Round scores. Pass empty names for the sandbox.
func set_scores(left_name: String, left: int, right_name: String, right: int) -> void:
	var sandbox := right_name.is_empty()
	var was_hidden := not _score_right.visible
	_score_right.visible = not sandbox
	LofiUI.set_text(_score_left, "%s  %d" % [left_name, left] if not sandbox else "sandbox")
	LofiUI.set_text(_score_right, "%d  %s" % [right, right_name])
	if not sandbox and was_hidden:
		LofiUI.enter(_score_left, Vector2(-10, 0))
		LofiUI.enter(_score_right, Vector2(10, 0))
	else:
		for side in 2:
			if [left, right][side] > _scores[side]:
				var b: PanelContainer = [_score_left, _score_right][side]
				LofiUI.flash(b, LofiUI.Style.INVERTED, 0.35)
				LofiUI.pop(b, 1.4, 0.25)
	_scores = [left, right]


## Counts down from `seconds`; negative counts up.
func set_timer(seconds: float) -> void:
	_timer_seconds = seconds
	_elapsed = 0.0
	_timer_whole = -1
	LofiUI.restyle(_timer, LofiUI.Style.INVERTED)


func set_map(map_name: String) -> void:
	LofiUI.set_text(_map, map_name)
	LofiUI.type_in(_map)


## A blinking alert under the score, e.g. "the map is unloading". "" hides it.
func set_alert(text: String) -> void:
	if _alert_blink:
		_alert_blink.kill()
		_alert_blink = null
	if text.is_empty():
		_hide(_alert)
		return
	LofiUI.set_text(_alert, text)
	LofiUI.restyle(_alert, LofiUI.Style.ALERT)
	_show(_alert)
	LofiUI.stamp(_alert, 0.3, 1.6)
	_alert_blink = LofiUI.blink(_alert, LofiUI.Style.ALERT, LofiUI.Style.INVERTED, 0.7)


func add_kill(killer: String, victim: String, weapon_name: String, heartshot := false) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 1)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(LofiUI.box(killer, LofiUI.SMALL))
	var how := LofiUI.box("♥" if heartshot else weapon_name, LofiUI.SMALL,
			LofiUI.Style.HEART if heartshot else LofiUI.Style.INVERTED)
	row.add_child(how)
	row.add_child(LofiUI.box(victim, LofiUI.SMALL))
	_killfeed.add_child(row)
	_killfeed.move_child(row, 0)
	LofiUI.enter(row, Vector2(48, 0), 0.0, 0.3)
	if heartshot:
		LofiUI.pop(how, 2.0, 0.35)
	var live := _killfeed.get_children().filter(func(r: Node) -> bool: return not r.get_meta(&"leaving", false))
	for old: Control in live.slice(KILLFEED_MAX):
		LofiUI.leave(old, Vector2(40, 0), 0.2)
	# On the row itself, so a row pushed out early takes its timer with it.
	row.create_tween().tween_callback(LofiUI.leave.bind(row, Vector2(40, 0), 0.2)).set_delay(KILLFEED_TIME)


func show_prompt(text: String) -> void:
	var was_hidden := not _prompt.visible or _fades.has(_prompt)
	LofiUI.set_text(_prompt, text)
	_show(_prompt)
	if was_hidden:
		LofiUI.enter(_prompt, Vector2(0, 6), 0.0, 0.2)


func hide_prompt() -> void:
	_hide(_prompt)


## A short pop-up above the crosshair ("heartshot", "double kill"...),
## one letter tile per character. The tiles slam down one after another,
## a heartshot's word then beats twice like a heart, the whole thing drifts
## up, and it shatters into tumbling tiles.
func popup(text: String, style := LofiUI.Style.INVERTED, time := 1.1) -> void:
	for old: Control in _popup_anchor.get_children():
		LofiUI.shatter(old, 0.2)
	var heart := style == LofiUI.Style.HEART
	var row := LofiUI.tiles(text, LofiUI.BIG, style)
	if heart:
		var mark := LofiUI.box("♥", LofiUI.BIG, LofiUI.Style.INVERTED)
		row.add_child(mark)
		row.move_child(mark, 0)
		var gap := Control.new()
		gap.custom_minimum_size.x = 3
		row.add_child(gap)
		row.move_child(gap, 1)
	_popup_anchor.add_child(row)
	var landed := LofiUI.stamp_tiles(row, 0.028, 0.8 if heart else 0.35)
	var t := row.create_tween()
	t.tween_interval(landed)
	t.tween_callback(func() -> void: row.pivot_offset = row.size * 0.5)
	if heart:
		for thump in [0.22, 0.12]:
			t.tween_property(row, "scale", Vector2.ONE * (1.0 + thump), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.tween_property(row, "scale", Vector2.ONE, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var hold := maxf(time - landed, 0.3)
	t.tween_interval(maxf(hold - (0.32 if heart else 0.0), 0.05))
	t.tween_callback(LofiUI.shatter.bind(row, 0.3))
	# Drift up by moving the anchor (the row's own position belongs to the
	# centring container).
	if _popup_drift:
		_popup_drift.kill()
	_popup_anchor.offset_top = POPUP_Y
	_popup_anchor.offset_bottom = POPUP_Y
	_popup_drift = _popup_anchor.create_tween().set_parallel()
	for side in ["offset_top", "offset_bottom"]:
		_popup_drift.tween_property(_popup_anchor, side, POPUP_Y - POPUP_DRIFT, hold).set_delay(landed) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Hooked to Player.movement_event: the HUD gets knocked around.
func on_movement_event(e: Dictionary) -> void:
	match e.type:
		&"jump":
			_knock(Vector2(0, -KNOCK_JUMP))
		&"slam_bounce":
			_knock(Vector2(0, -KNOCK_JUMP * 2.0))
		&"land":
			_knock(Vector2(0, minf(e.impact_speed * KNOCK_LAND_PER_SPEED, KNOCK_LAND_MAX)))
		&"slide_start":
			_knock(Vector2(0, KNOCK_JUMP))
		&"dash":
			var side := _view_side(e.direction)
			_knock(Vector2(-side * KNOCK_DASH, -KNOCK_DASH * 0.2))
			LofiUI.kick(self, 0.12)
		&"wall_jump":
			_knock(Vector2(-_view_side(e.normal) * KNOCK_DASH * 0.7, -KNOCK_JUMP))
		&"mantle":
			_knock(Vector2(0, -KNOCK_JUMP * 0.6))
		&"smash_start":
			_knock(Vector2(0, -KNOCK_JUMP))
		&"smash_impact":
			_knock(Vector2(0, KNOCK_SMASH))
			LofiUI.kick(self, clampf(0.3 + e.drop * 0.04, 0.3, 0.9))
			LofiUI.pop(_speed, 1.5, 0.25)


## An impact frame fired (strength 0..1): the HUD takes the hit with the
## camera. It punches in on the camera's spring and recoils past rest, and
## every group rattles loose and wobbles back into place.
func impact(strength: float) -> void:
	var s := clampf(strength, 0.0, 1.0) * LofiUI.motion
	if s <= 0.0:
		return
	_impact_time = 0.0
	_impact_zoom = IMPACT_ZOOM * s
	for c: Control in _groups():
		c.pivot_offset = c.size * 0.5
		c.rotation = randf_range(0.5, 1.0) * (1.0 if randf() < 0.5 else -1.0) * IMPACT_RATTLE * s
		# Held through the impact frame's beats like the camera, then settles.
		var t := c.create_tween()
		t.tween_interval(Player.PUNCH_HOLD * (1.0 - LofiUI.smoothing) + 0.001)
		LofiUI.settle(t, c, "rotation", 0.0)


# --- Motion -------------------------------------------------------------------

## Everything springs into place (on start, and after respawning).
func _arrive() -> void:
	var i := 0
	for c: Control in get_children():
		if c == _popup_anchor or not c.visible:
			continue
		var from := Vector2(0, -14) if c.position.y < size.y * 0.5 else Vector2(0, 14)
		LofiUI.enter(c, from, i * 0.03, 0.3)
		i += 1
	_sway = Vector2.ZERO
	_sway_velocity = Vector2.ZERO
	_has_look = false


## The HUD's corner and centre groups (everything that rattles).
func _groups() -> Array[Control]:
	var out: Array[Control] = []
	for c in get_children():
		if c is Control and c != _popup_anchor and c.visible:
			out.append(c)
	return out


func _update_sway(delta: float) -> void:
	var target := Vector2.ZERO
	var lean := 0.0
	if player and not player.is_dead:
		var look := Vector2(player.yaw, player.pitch)
		if _has_look and delta > 0.0:
			var rate := Vector2(wrapf(look.x - _last_look.x, -PI, PI), look.y - _last_look.y) / delta
			# Turning right drags the HUD left; looking up drags it down.
			target += Vector2(rate.x, rate.y) * SWAY_LOOK
		_last_look = look
		_has_look = true
		var local := Basis(Vector3.UP, player.yaw).inverse() * player.velocity
		target.y += player.velocity.y * SWAY_FALL
		lean = -local.x * LEAN
	target = target.limit_length(SWAY_MAX)
	var spring := lerpf(SWAY_SPRING.x, SWAY_SPRING.y, LofiUI.smoothing)
	var damping := lerpf(SWAY_DAMPING.x, SWAY_DAMPING.y, LofiUI.smoothing)
	var steps := maxi(1, ceili(delta * 240.0))
	for i in steps:
		_sway_velocity += ((target - _sway) * spring - _sway_velocity * damping) * (delta / steps)
		_sway += _sway_velocity * (delta / steps)
	_sway = _sway.limit_length(SWAY_MAX * 2.0)
	position = _sway * LofiUI.motion
	pivot_offset = size * 0.5
	rotation = lerpf(rotation, lean * LofiUI.motion, minf(delta * 8.0, 1.0))
	_impact_time += delta
	scale = Vector2.ONE * (1.0 + _impact_zoom * Player.punch_spring(_impact_time, LofiUI.smoothing))


## A knock from a movement event (impulse in px/s of spring velocity).
## Snappy: it lands as displacement this frame. Smooth: it swells in.
func _knock(impulse: Vector2) -> void:
	_sway += impulse * KNOCK_SNAP * (1.0 - LofiUI.smoothing)
	_sway_velocity += impulse * LofiUI.smoothing


## -1..1: how far a world direction points to the view's right.
func _view_side(direction: Vector3) -> float:
	var local := Basis(Vector3.UP, player.yaw).inverse() * direction if player else direction
	return clampf(local.x, -1.0, 1.0)


func _update_speed(delta: float) -> void:
	var p := player.movement_params
	var speed := player.horizontal_speed()
	var shown := lerpf(_meter.value * p.soft_speed_cap, speed, minf(delta * 12.0, 1.0))
	_meter.value = shown / p.soft_speed_cap
	_meter.over = speed > p.soft_speed_cap
	if _meter.value >= _meter.peak:
		_meter.peak = _meter.value
	else:
		_meter.peak = maxf(_meter.peak - delta * 0.15, _meter.value)
	_meter.queue_redraw()
	LofiUI.set_text(_speed, str(roundi(speed)))
	var fast := speed > p.run_speed + 0.5
	if fast != (LofiUI.style_of(_speed) == LofiUI.Style.INVERTED):
		LofiUI.restyle(_speed, LofiUI.Style.INVERTED if fast else LofiUI.Style.NORMAL)
		if fast:
			LofiUI.pop(_speed, 1.3, 0.15)


func _update_timer(delta: float) -> void:
	if _timer_seconds < 0.0:
		LofiUI.set_text(_timer, _clock(_elapsed))
		return
	_timer_seconds = maxf(_timer_seconds - delta, 0.0)
	LofiUI.set_text(_timer, _clock(_timer_seconds))
	var whole := int(ceil(_timer_seconds))
	if whole != _timer_whole and _timer_whole >= 0 and whole <= TIMER_TENSE:
		var panic := whole <= TIMER_PANIC
		LofiUI.restyle(_timer, LofiUI.Style.ALERT if panic else LofiUI.Style.INVERTED)
		LofiUI.pop(_timer, 1.35 if panic else 1.15, 0.2)
		if panic:
			LofiUI.kick(self, 0.1)
	_timer_whole = whole


## Shows a control, cancelling a hide in progress.
func _show(c: Control) -> void:
	if _fades.has(c):
		(_fades[c] as Tween).kill()
		_fades.erase(c)
	c.visible = true
	c.modulate.a = 1.0


## A quick fade, then hidden.
func _hide(c: Control) -> void:
	if not c.visible or _fades.has(c):
		return
	var t := c.create_tween()
	t.tween_property(c, "modulate:a", 0.0, 0.1)
	t.tween_callback(func() -> void:
		c.visible = false
		c.modulate.a = 1.0
		_fades.erase(c))
	_fades[c] = t


func _anchor(c: Control, preset: Control.LayoutPreset, offset: Vector2) -> void:
	add_child(c)
	# Grow away from the anchored corner, set first: a control whose minimum
	# size only registers after this still ends up glued to its corner.
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH if preset in [Control.PRESET_CENTER_TOP, Control.PRESET_CENTER_BOTTOM, Control.PRESET_CENTER] \
			else (Control.GROW_DIRECTION_BEGIN if preset in [Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT] else Control.GROW_DIRECTION_END)
	c.grow_vertical = Control.GROW_DIRECTION_BEGIN if preset in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_BOTTOM] \
			else (Control.GROW_DIRECTION_BOTH if preset == Control.PRESET_CENTER else Control.GROW_DIRECTION_END)
	c.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE)
	c.position += offset


static func _clock(seconds: float) -> String:
	var s := int(ceil(seconds)) if seconds > 0.0 else 0
	return "%d:%02d" % [s / 60, s % 60]
