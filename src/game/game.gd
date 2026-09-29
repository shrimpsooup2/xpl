class_name Game
extends RefCounted
## The game in progress, if any (GDD §8). Starting one puts a Match under the
## tree's root, outside any level, so it lives through map changes; each map
## it loads, it fills with the game's players. Only the match's machine (the
## host or server; offline, this one) decides anything: damage, deaths,
## scores, respawns.

const MENU_SCENE := "res://scenes/main_menu.tscn"

## The running match, or null (the sandbox, the menu).
static var current: Match


## Starts a game of `rules` for `players` (see PlayerInfo): loads its first
## map, and it runs from there, back to the menu when it's over.
static func start(tree: SceneTree, rules: GameRules, players: Array[PlayerInfo]) -> Match:
	end(tree, false)
	var m := Match.new()
	m.name = "Match"
	m.rules = rules
	m.infos = players
	current = m
	tree.root.add_child(m)  # It loads its first map once it's in the tree.
	return m


## Ends the game in progress and (with `to_menu`) goes back to the menu.
static func end(tree: SceneTree, to_menu := true) -> void:
	if current and is_instance_valid(current):
		current.queue_free()
	current = null
	if to_menu:
		Wipe.change_scene(tree, MENU_SCENE)


## Whether `attacker` can hurt `victim`: always, but for teammates when the
## game has friendly fire off.
static func can_damage(attacker: Player, victim: Player) -> bool:
	if current == null or not is_instance_valid(current):
		return true
	return current.can_damage(attacker, victim)


## A quick offline game: you and `bots` bots (in teams, split evenly, you
## on red).
static func practice(tree: SceneTree, rules: GameRules, bots: int) -> Match:
	var players: Array[PlayerInfo] = [PlayerInfo.local_human()]
	for n in bots:
		var b := PlayerInfo.make_bot(n + 1)
		players.append(b)
	if rules.is_teams():
		for i in players.size():
			players[i].team = Hats.Team.RED if i % 2 == 0 else Hats.Team.BLUE
	return start(tree, rules, players)
