class_name RulesEditor
extends PanelContainer
## A game's options on a card (GDD §8), for whoever hosts it: the vs bots
## page, and the host in an online lobby. It starts from a style's preset
## (GameRules) and changes just what a host would want to: health and
## getting it back, how long rounds or the game last and what it takes to
## win, which maps are played and which guns are in play, what you spawn
## holding, and a few more. Rows of [<] choice [>], and rows of chips to
## switch maps and guns on and off. Each change goes into `rules` at once
## (changed) and is remembered for the style, for next time (saved).
##
## Everyone else in a lobby gets summary(): the options on one line.

signal changed

## Where each style's options are kept (only what the host can change, so
## a new version's presets still come through for the rest).
static var path := "user://game.cfg"

## The options a host can change: GameRules' own names.
const KEYS := ["max_health", "regen_delay", "round_time", "round_wins", "spawn_weapon", "pad_respawn_scale",
		"map_each_round", "score_to_win", "time_limit", "respawn_delay", "friendly_fire", "kill_combos", "map_pool", "guns"]
const HEALTH := [50.0, 75.0, 100.0, 150.0, 200.0, 300.0]
const REGEN := [0.0, 3.0, 5.0, 8.0]
const ROUND_TIME := [30.0, 45.0, 60.0, 70.0, 90.0, 120.0, 180.0, 0.0]
const ROUND_WINS := [1, 2, 3, 5, 7, 10]
const PAD_SCALE := [0.5, 1.0, 2.0]
const SCORE := [10, 25, 50, 75, 100, 150, 0]
const TIME_LIMIT := [180.0, 300.0, 600.0, 900.0, 1200.0, 1800.0, 0.0]
const RESPAWN := [1.0, 2.0, 3.0, 5.0, 8.0]
const LABEL_WIDTH := 52.0
## Canvas pixels the map and gun chips wrap at.
const CHIPS_WIDTH := 150.0

var rules: GameRules
## Rows of the caller's to put first, as [label, control] pairs (the bots,
## on the vs bots page). Set before it's in the tree.
var top_rows: Array = []
var _spawn_row: HBoxContainer


func _init(game_rules: GameRules) -> void:
	rules = game_rules
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


func _ready() -> void:
	_build()


## The maps a game can be played on: every level but the test course.
static func maps() -> PackedStringArray:
	var out := PackedStringArray()
	for m: Dictionary in Maps.ALL:
		if m.scene.begins_with("res://scenes/maps/"):
			out.append(m.name)
	return out


# --- Saved options ----------------------------------------------------------------------

## A style's options as last set (its preset if they never were).
static func saved(kind: GameRules.Kind) -> GameRules:
	var preset := GameRules.teams() if kind == GameRules.Kind.TEAMS else GameRules.free_for_all()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return preset
	var d := preset.to_dict()
	var section := _section(kind)
	for key: String in KEYS:
		if cfg.has_section_key(section, key):
			d[key] = cfg.get_value(section, key)
	return GameRules.from_dict(d)  # Checked like anything off the network.


## Remembers `r`'s options for its style.
static func save(r: GameRules) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	for key: String in KEYS:
		cfg.set_value(_section(r.kind), key, r.get(key))
	cfg.save(path)


## Forgets a style's options: back to its preset.
static func forget(kind: GameRules.Kind) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK and cfg.has_section(_section(kind)):
		cfg.erase_section(_section(kind))
		cfg.save(path)


static func _section(kind: GameRules.Kind) -> String:
	return "teams" if kind == GameRules.Kind.TEAMS else "ffa"


# --- The card ---------------------------------------------------------------------------

func _build() -> void:
	_spawn_row = null
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var left := _column()
	for pair: Array in top_rows:
		left.add_child(_row(pair[0], pair[1]))
	left.add_child(_row("health", _pick("max_health", HEALTH, HEALTH.map(func(h: float) -> String: return "%d" % h))))
	left.add_child(_row("health back", _pick("regen_delay", REGEN, REGEN.map(func(s: float) -> String:
		return "never" if s == 0.0 else "after %d s" % s))))
	if rules.is_teams():
		left.add_child(_row("to win", _pick("score_to_win", SCORE, SCORE.map(func(n: int) -> String:
			return "no target" if n == 0 else "%d kills" % n))))
		left.add_child(_row("time limit", _pick("time_limit", TIME_LIMIT, TIME_LIMIT.map(func(s: float) -> String:
			return "none" if s == 0.0 else "%d min" % roundi(s / 60.0)))))
		left.add_child(_row("respawn", _pick("respawn_delay", RESPAWN, RESPAWN.map(func(s: float) -> String:
			return "after %d s" % s))))
		left.add_child(_row("friendly fire", _pick("friendly_fire", [false, true], ["off", "on"])))
	else:
		left.add_child(_row("rounds", _pick("round_time", ROUND_TIME, ROUND_TIME.map(func(s: float) -> String:
			return "no time limit" if s == 0.0 else "%d s" % s))))
		left.add_child(_row("to win", _pick("round_wins", ROUND_WINS, ROUND_WINS.map(func(n: int) -> String:
			return "%d round%s" % [n, "" if n == 1 else "s"]))))
		_spawn_row = _row("spawn with", _spawn_pick())
		left.add_child(_spawn_row)
		left.add_child(_row("pads refill", _pick("pad_respawn_scale", PAD_SCALE, ["fast", "normal", "slow"])))
	var right := _column()
	right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var map_names := maps()
	right.add_child(_row("maps", _chips(map_names, map_names, "map_pool", 1)))
	if not rules.is_teams():
		right.add_child(_row("map", _pick("map_each_round", [true, false], ["new each round", "one per game"])))
	var gun_names: Array = Weapons.GUNS.map(func(g: StringName) -> String: return Weapons.get_def(g).display_name)
	right.add_child(_row("guns", _chips(PackedStringArray(Weapons.GUNS), gun_names, "guns", 0)))
	right.add_child(_row("combos", _pick("kill_combos", [false, true], ["off", "on"])))
	var both := HBoxContainer.new()
	both.add_theme_constant_override(&"separation", 10)
	both.add_child(left)
	both.add_child(right)
	add_child(both)


## [<] choice [>] for rule `key` over `values` (shown as `names`), on the
## one nearest what the rules have now.
func _pick(key: String, values: Array, names: Array) -> HBoxContainer:
	return LofiUI.choice(names, _nearest(values, rules.get(key)), func(i: int) -> void: _change(key, values[i]))


## What you spawn holding (free-for-all): fists, or one of the guns in play.
func _spawn_pick() -> HBoxContainer:
	var ids: Array = [&""]
	var names: Array = ["fists"]
	for g: StringName in Weapons.GUNS:
		if rules.allows(g):
			ids.append(g)
			names.append(Weapons.get_def(g).display_name)
	return LofiUI.choice(names, maxi(ids.find(rules.spawn_weapon), 0), func(i: int) -> void: _change("spawn_weapon", ids[i]))


## A chip for each of `ids` (shown as `names`): on while it's in rule `key`
## (a list), which keeps at least `least` of them.
func _chips(ids: PackedStringArray, names: Array, key: String, least: int) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override(&"h_separation", 1)
	flow.add_theme_constant_override(&"v_separation", 1)
	flow.custom_minimum_size.x = CHIPS_WIDTH
	for i in ids.size():
		var id := ids[i]
		flow.add_child(LofiUI.chip(names[i], id in (rules.get(key) as PackedStringArray), func(on: bool) -> bool:
			var now: PackedStringArray = rules.get(key)
			if not on and now.size() <= least:
				return false
			var out := PackedStringArray()
			for other in ids:  # Kept in the list's own order.
				if (other == id and on) or (other != id and other in now):
					out.append(other)
			_change(key, out)
			return true))
	return flow


func _change(key: String, value: Variant) -> void:
	rules.set(key, value)
	if key == "guns" and _spawn_row:
		# What you can spawn with follows what's in play.
		if not rules.allows(rules.spawn_weapon):
			rules.spawn_weapon = &""
		var pick := _spawn_pick()
		pick.alignment = BoxContainer.ALIGNMENT_BEGIN
		var old := _spawn_row.get_child(1)
		_spawn_row.remove_child(old)
		old.queue_free()
		_spawn_row.add_child(pick)
	save(rules)
	changed.emit()


static func _nearest(values: Array, v: Variant) -> int:
	var best := 0
	for i in values.size():
		if values[i] == v:
			return i
		if (v is float or v is int) and absf(float(values[i]) - float(v)) < absf(float(values[best]) - float(v)):
			best = i
	return best


func _row(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 2)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", LofiUI.SMALL)
	label.custom_minimum_size.x = LABEL_WIDTH
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if control is HFlowContainer:
		label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN  # Level with the first row of chips.
		label.custom_minimum_size.y = 12
	row.add_child(label)
	if control is HBoxContainer:
		(control as HBoxContainer).alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(control)
	return row


func _column() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 2)
	return col


# --- For everyone else ------------------------------------------------------------------

## The options on one line, for the lobby: "100 health · 70 s rounds · first
## to 5 · 5 maps · every gun".
static func summary(r: GameRules) -> String:
	var parts := PackedStringArray()
	parts.append("%d health" % r.max_health)
	if r.regen_delay > 0.0:
		parts.append("back after %d s" % r.regen_delay)
	if r.is_teams():
		parts.append("first to %d kills" % r.score_to_win if r.score_to_win > 0 else "no kill target")
		parts.append("%d min" % roundi(r.time_limit / 60.0) if r.time_limit > 0.0 else "no time limit")
		if r.friendly_fire:
			parts.append("friendly fire")
	else:
		parts.append("%d s rounds" % r.round_time if r.round_time > 0.0 else "untimed rounds")
		parts.append("first to %d" % r.round_wins)
		if r.spawn_weapon != &"" and r.allows(r.spawn_weapon):
			parts.append("spawn with the " + Weapons.get_def(r.spawn_weapon).display_name)
	parts.append(", ".join(r.map_pool) if r.map_pool.size() <= 3 else "%d maps" % r.map_pool.size())
	if r.guns.is_empty():
		parts.append("fists only")
	elif r.guns.size() == Weapons.GUNS.size():
		parts.append("every gun")
	else:
		var names := PackedStringArray()
		for g in r.guns:
			names.append(Weapons.get_def(StringName(g)).display_name)
		parts.append(", ".join(names) if names.size() <= 3 else "%d guns" % names.size())
	return " · ".join(parts)
