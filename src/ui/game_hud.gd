class_name GameHud
extends Control
## The in-round HUD (GDD §13.3), on the low-res canvas. Minimal and boxed:
##
##   top centre     score · round timer · score, map name underneath
##   top right      killfeed
##   bottom left    health
##   bottom centre  dash charges
##   bottom right   throwable, weapon and ammo
##   centre         pickup prompt below the crosshair, pop-ups above it
##
## Movement values are live. Health, weapons, and scores are placeholders
## until combat (M2) and rounds (M3) exist; the setters below are the API
## those systems will call.

const MARGIN := 8
const KILLFEED_MAX := 5
const KILLFEED_TIME := 5.0
const LOW_HEALTH := 30

var player: Player

var _score_left: PanelContainer
var _timer: PanelContainer
var _score_right: PanelContainer
var _map: PanelContainer
var _alert: PanelContainer
var _health: PanelContainer
var _weapon: PanelContainer
var _ammo: PanelContainer
var _throwable: PanelContainer
var _pips: Pips
var _killfeed: VBoxContainer
var _prompt: PanelContainer
var _popup_anchor: CenterContainer
var _elapsed := 0.0
var _timer_seconds := -1.0  # < 0: count up (sandbox).
var _health_value := 100


## Dash charge boxes: filled when ready, filling up while recharging.
class Pips extends Control:
	var count := 2
	var charged := 2
	var progress := 0.0

	func _draw() -> void:
		var w := 9.0
		var gap := 3.0
		var total := count * w + (count - 1) * gap
		var x := (size.x - total) * 0.5
		for i in count:
			var r := Rect2(x + i * (w + gap), 0, w, 5)
			draw_rect(r, LofiUI.WHITE)
			if i < charged:
				draw_rect(r, LofiUI.BLACK)
			elif i == charged:
				draw_rect(Rect2(r.position, Vector2(r.size.x * progress, r.size.y)), LofiUI.GREY)
			draw_rect(r, LofiUI.BLACK, false, 1.0)


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

	var health_row := HBoxContainer.new()
	health_row.add_theme_constant_override(&"separation", 2)
	health_row.alignment = BoxContainer.ALIGNMENT_END
	health_row.add_child(LofiUI.box("hp", LofiUI.SMALL, LofiUI.Style.GHOST))
	_health = LofiUI.box("100", LofiUI.BIG)
	health_row.add_child(_health)
	_anchor(health_row, Control.PRESET_BOTTOM_LEFT, Vector2(MARGIN, -MARGIN))

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

	_pips = Pips.new()
	_pips.custom_minimum_size = Vector2(60, 5)
	_anchor(_pips, Control.PRESET_CENTER_BOTTOM, Vector2(0, -MARGIN - 2))

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
	_popup_anchor.offset_top = -34
	_popup_anchor.offset_bottom = -34


func _process(delta: float) -> void:
	_elapsed += delta
	if _timer_seconds >= 0.0:
		_timer_seconds = maxf(_timer_seconds - delta, 0.0)
		LofiUI.set_text(_timer, _clock(_timer_seconds))
	else:
		LofiUI.set_text(_timer, _clock(_elapsed))
	if player:
		var st := player.state
		var p := player.movement_params
		_pips.count = p.dash_charges
		_pips.charged = st.dash_charges
		_pips.progress = st.dash_recharge_timer / p.dash_recharge
		_pips.queue_redraw()


# --- API for combat and rounds -----------------------------------------------

func set_health(value: int) -> void:
	var dropped := value < _health_value
	_health_value = value
	LofiUI.set_text(_health, str(value))
	LofiUI.restyle(_health, LofiUI.Style.ALERT if value <= LOW_HEALTH else LofiUI.Style.NORMAL)
	if dropped:
		LofiUI.shake(_health.get_parent())  # The whole row: boxes inside it can't move.


## weapon_name "" or "fists" means empty-handed; ammo < 0 hides the count.
func set_weapon(weapon_name: String, ammo := -1) -> void:
	LofiUI.set_text(_weapon, weapon_name if not weapon_name.is_empty() else "fists")
	_ammo.visible = ammo >= 0
	if ammo >= 0:
		LofiUI.set_text(_ammo, str(ammo))
		LofiUI.restyle(_ammo, LofiUI.Style.ALERT if ammo == 0 else LofiUI.Style.NORMAL)


func set_throwable(throwable_name: String, count: int) -> void:
	_throwable.visible = count > 0
	LofiUI.set_text(_throwable, "%s ×%d" % [throwable_name, count])


## Round scores. Pass empty names for the sandbox.
func set_scores(left_name: String, left: int, right_name: String, right: int) -> void:
	_score_right.visible = not right_name.is_empty()
	LofiUI.set_text(_score_left, "%s  %d" % [left_name, left] if not right_name.is_empty() else "sandbox")
	LofiUI.set_text(_score_right, "%d  %s" % [right, right_name])


## Counts down from `seconds`; negative counts up.
func set_timer(seconds: float) -> void:
	_timer_seconds = seconds
	_elapsed = 0.0


func set_map(map_name: String) -> void:
	LofiUI.set_text(_map, map_name)


## A blinking alert under the score, e.g. "the map is unloading". "" hides it.
func set_alert(text: String) -> void:
	_alert.visible = not text.is_empty()
	LofiUI.set_text(_alert, text)
	if _alert.visible:
		LofiUI.pop(_alert)


func add_kill(killer: String, victim: String, weapon_name: String, heartshot := false) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 1)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(LofiUI.box(killer, LofiUI.SMALL))
	row.add_child(LofiUI.box("♥" if heartshot else weapon_name, LofiUI.SMALL,
			LofiUI.Style.HEART if heartshot else LofiUI.Style.INVERTED))
	row.add_child(LofiUI.box(victim, LofiUI.SMALL))
	_killfeed.add_child(row)
	_killfeed.move_child(row, 0)
	while _killfeed.get_child_count() > KILLFEED_MAX:
		_killfeed.get_child(_killfeed.get_child_count() - 1).queue_free()
	get_tree().create_timer(KILLFEED_TIME).timeout.connect(func() -> void:
		if is_instance_valid(row):
			row.queue_free())


func show_prompt(text: String) -> void:
	var was_hidden := not _prompt.visible
	_prompt.visible = true
	LofiUI.set_text(_prompt, text)
	if was_hidden:
		LofiUI.pop(_prompt, 0.8, 0.15)


func hide_prompt() -> void:
	_prompt.visible = false


## A short boxed pop-up above the crosshair ("heartshot", "double kill"...).
func popup(text: String, style := LofiUI.Style.INVERTED, time := 1.1) -> void:
	for old in _popup_anchor.get_children():
		old.queue_free()
	var b := LofiUI.box(text, LofiUI.BIG, style)
	_popup_anchor.add_child(b)
	await get_tree().process_frame
	if not is_instance_valid(b):
		return
	LofiUI.pop(b, 0.4, 0.25)
	var t := b.create_tween()
	t.tween_interval(time)
	t.tween_property(b, "modulate:a", 0.0, 0.15)
	t.tween_callback(b.queue_free)


func _anchor(c: Control, preset: Control.LayoutPreset, offset: Vector2) -> void:
	add_child(c)
	c.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE)
	c.position += offset
	# Keep the control glued to its corner when its size changes.
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH if preset in [Control.PRESET_CENTER_TOP, Control.PRESET_CENTER_BOTTOM, Control.PRESET_CENTER] \
			else (Control.GROW_DIRECTION_BEGIN if preset in [Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT] else Control.GROW_DIRECTION_END)
	c.grow_vertical = Control.GROW_DIRECTION_BEGIN if preset in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_BOTTOM] \
			else (Control.GROW_DIRECTION_BOTH if preset == Control.PRESET_CENTER else Control.GROW_DIRECTION_END)


static func _clock(seconds: float) -> String:
	var s := int(ceil(seconds)) if seconds > 0.0 else 0
	return "%d:%02d" % [s / 60, s % 60]
