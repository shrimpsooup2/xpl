class_name Game
extends RefCounted
## The game in progress, if any (GDD §8). Starting one puts a Match under the
## tree's root, outside any level, so it lives through map changes; each map
## it loads, it fills with the game's players. Only the match's machine (the
## host or server; offline, this one) decides anything: damage, deaths,
## scores, respawns. In a networked game a client follows the server's match
## (Game.follow, docs/NETWORKING.md).

const MENU_SCENE := "res://scenes/main_menu.tscn"

## The running match, or null (the sandbox, the menu).
static var current: Match


## Starts a game of `rules` for `players` (see PlayerInfo) on this machine,
## which decides it: loads its first map, and runs from there. Offline it
## goes back to the menu when it's over; a server tells its clients, and
## what happens next is the session's (NetSession.game_over).
static func start(tree: SceneTree, rules: GameRules, players: Array[PlayerInfo]) -> Match:
	end(tree, false)
	var m := Match.new()
	m.name = "Match"
	m.rules = rules
	m.infos = players
	m.finished.connect(_on_finished.bind(tree))
	current = m
	if NetSession.active() and NetSession.current.is_server():
		NetSession.current.announce_game(rules)
	tree.root.add_child(m)  # It loads its first map once it's in the tree.
	return m


## A client joins the server's game: a match that loads the maps the server
## names and takes its state from it.
static func follow(tree: SceneTree, rules: GameRules, players: Array[PlayerInfo]) -> Match:
	end(tree, false)
	var m := Match.new()
	m.name = "Match"
	m.rules = rules
	m.infos = players
	m.authority = false
	current = m
	tree.root.add_child(m)
	return m


## Ends the game in progress and (with `to_menu`) goes back to the menu.
static func end(tree: SceneTree, to_menu := true) -> void:
	if current and is_instance_valid(current):
		current.name = "EndedMatch"  # Frees its name for the next one straight away.
		current.queue_free()
	current = null
	if to_menu:
		Wipe.change_scene(tree, MENU_SCENE)


static func _on_finished(tree: SceneTree) -> void:
	if NetSession.active():
		NetSession.current.game_over()
	else:
		end(tree)


## Someone joined the server mid-game: they're in it from now on.
static func on_peer_joined(id: int) -> void:
	if current and is_instance_valid(current) and current.authority and NetSession.active():
		var info: PlayerInfo = NetSession.current.roster.get(id)
		if info:
			NetSession.current.announce_game(current.rules, id)
			current.add_player(info)
			if current.sync:
				current.sync.catch_up(id)


## Someone left the server.
static func on_peer_left(id: int) -> void:
	if current and is_instance_valid(current):
		current.remove_player(id)


## Whether `attacker` can hurt `victim`: always, but for teammates when the
## game has friendly fire off.
static func can_damage(attacker: Player, victim: Player) -> bool:
	if current == null or not is_instance_valid(current):
		return true
	return current.can_damage(attacker, victim)


## Your name, hat or colour changed (Cosmetics): the game you're in shows it
## now, and online everyone sees it (through the server).
static func update_look() -> void:
	if NetSession.active():
		NetSession.current.send_look()
		return
	var m := current
	if m == null or not is_instance_valid(m):
		return
	var me := m.local_info()
	if me:
		me.player_name = Cosmetics.player_name
		me.hat = Cosmetics.hat
		me.color = Cosmetics.color
		m.restyle(me)


## You pick gun `id` (for games where you pick, GameRules.loadout): it's
## saved, and the game you're in hears about it (the server, online).
static func choose_gun(id: StringName) -> void:
	if not id in Weapons.GUNS:
		return
	var m := current
	if m and is_instance_valid(m) and not m.rules.allows(id):
		return  # Not in play this game.
	Cosmetics.set_gun(id)
	if m == null or not is_instance_valid(m):
		return
	var me := m.local_info()
	if m.authority:
		m.choose_gun(me, id)
	elif m.sync:
		if me:
			me.gun = id
		m.sync.send_gun(id)


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
