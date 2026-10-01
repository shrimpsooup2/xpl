class_name GunPicker
extends VBoxContainer
## Picking your gun, in games where you pick (GameRules.loadout: teams): the
## six guns in a row, numbered 1–6, yours inverted, any the host left out of
## the game greyed. Shown in the countdown and while you're down; press a
## number to pick (Game.choose_gun). Yours from your next spawn, or at once
## in the countdown.

var _title: PanelContainer
var _boxes: Array[PanelContainer] = []
var _shown := &""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 2)
	_title = LofiUI.box("your gun · press 1–6", LofiUI.SMALL, LofiUI.Style.GHOST)
	_title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 2)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in Weapons.GUNS.size():
		var def := Weapons.get_def(Weapons.GUNS[i])
		var b := LofiUI.box("%d %s" % [i + 1, def.display_name], LofiUI.SMALL, LofiUI.Style.NORMAL)
		_boxes.append(b)
		row.add_child(b)
	add_child(row)


## Shows `id` as the pick (with a pop when it changes); guns out of play
## (`rules`, GameRules.guns) are greyed out.
func show_pick(id: StringName, rules: GameRules = null) -> void:
	for i in _boxes.size():
		var mine: bool = Weapons.GUNS[i] == id
		var out := rules != null and not rules.allows(Weapons.GUNS[i])
		LofiUI.restyle(_boxes[i], LofiUI.Style.GHOST if out else LofiUI.Style.INVERTED if mine else LofiUI.Style.NORMAL)
		if mine and id != _shown and _shown != &"":
			LofiUI.pop(_boxes[i], 1.15, 0.14)
	_shown = id


## The gun number key `key` picks (KEY_1..KEY_6), or &"".
static func gun_for_key(key: Key) -> StringName:
	var i := int(key) - int(KEY_1)
	return Weapons.GUNS[i] if i >= 0 and i < Weapons.GUNS.size() else &""
