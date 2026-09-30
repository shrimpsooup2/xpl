class_name BotsMenu
extends VBoxContainer
## Play → vs bots (GDD §8): a game on this machine against bots. The style
## along the top (free-for-all or teams, like the settings page's tabs),
## then a card with how many bots and the game's options (RulesEditor,
## remembered per style), then start. *defaults* puts the style's options
## back as shipped.

signal back
## Start a game of `rules` against `bots` bots.
signal start(rules: GameRules, bots: int)
## The style on show changed (the title screen dresses the blob for it).
signal style_changed(teams: bool)

const STYLES := ["free-for-all", "teams"]
const MAX_BOTS := 15
## Each style's bots until you pick: 4 in free-for-all, 4 a side in teams.
const DEFAULT_BOTS := [3, 7]

var rules: GameRules
var style := 0
var bots := [3, 7]
var _tabs: Array[Button] = []
var _editor: RulesEditor


func _ready() -> void:
	add_theme_constant_override(&"separation", 3)
	_load_prefs()
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 2)
	for i in STYLES.size():
		var b := LofiUI.button(STYLES[i], show_style.bind(i))
		b.toggle_mode = true
		_tabs.append(b)
		top.add_child(b)
	add_child(top)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override(&"separation", 3)
	bottom.add_child(_menu_button("start", _start))
	bottom.add_child(_menu_button("defaults", reset))
	bottom.add_child(_menu_button("back", func() -> void: back.emit()))
	add_child(bottom)
	show_style(style)
	var n := 0
	for c in get_children():
		LofiUI.enter(c, Vector2(-30, 0), n * 0.05, 0.22)
		n += 1


## Shows style `i`'s bots and options.
func show_style(i: int) -> void:
	style = clampi(i, 0, STYLES.size() - 1)
	for k in _tabs.size():
		_tabs[k].set_pressed_no_signal(k == style)
	rules = RulesEditor.saved(GameRules.Kind.TEAMS if style == 1 else GameRules.Kind.FFA)
	var texts: Array = []
	for n in MAX_BOTS + 1:
		texts.append("%d" % n)
	var bots_row := LofiUI.choice(texts, bots[style], func(n: int) -> void:
		bots[style] = n
		_save_prefs())
	if _editor:
		remove_child(_editor)
		_editor.queue_free()
	_editor = RulesEditor.new(rules)
	_editor.top_rows = [["bots", bots_row]]
	add_child(_editor)
	move_child(_editor, 1)
	LofiUI.pop(_editor, 0.94, 0.14)
	_save_prefs()
	style_changed.emit(style == 1)


## Puts the style's options back as shipped.
func reset() -> void:
	RulesEditor.forget(rules.kind)
	bots[style] = DEFAULT_BOTS[style]
	show_style(style)


func _start() -> void:
	start.emit(rules, bots[style])


func _menu_button(text: String, on_pressed: Callable) -> Button:
	var b := LofiUI.button(text, on_pressed)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.custom_minimum_size.x = 60
	return b


func _load_prefs() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RulesEditor.path) != OK:
		return
	style = clampi(int(cfg.get_value("bots", "style", 0)), 0, STYLES.size() - 1)
	for i in STYLES.size():
		bots[i] = clampi(int(cfg.get_value("bots", "bots_%d" % i, DEFAULT_BOTS[i])), 0, MAX_BOTS)


func _save_prefs() -> void:
	var cfg := ConfigFile.new()
	cfg.load(RulesEditor.path)
	cfg.set_value("bots", "style", style)
	for i in STYLES.size():
		cfg.set_value("bots", "bots_%d" % i, bots[i])
	cfg.save(RulesEditor.path)
