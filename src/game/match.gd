class_name Match
extends Node
## Runs one game by its GameRules (GDD §8): loads each map, puts the game's
## players on it (the local person in the level's own Player, everyone else
## in a new one, bots with a BotBrain), and then:
##   countdown: everyone at a spawn, moving, weapons off;
##   live: kills are counted; free-for-all rounds end when one player is
##     left (or time runs out: nobody wins it); in teams the dead respawn and
##     the game ends at the kill target or the time limit;
##   round end, a short beat, then the next round (a new map in free-for-all)
##     or the match end, then back to the menu.
## It also sets the level up for the rules: pad respawn times, resupply
## crates, what you spawn holding, health regeneration, friendly fire.
## Everything that decides the game happens here, on the machine that runs
## the match; the UI listens to the signals.

signal state_changed(state: State)
signal scores_changed
signal kill_feed(killer: PlayerInfo, victim: PlayerInfo, weapon_name: String, heartshot: bool)
## A round's winner, or null (a draw: time ran out, or nobody's left).
signal round_decided(winner: PlayerInfo)
## The match's winner: a player in free-for-all, a team (and null) in teams;
## team -1 and null for a draw.
signal match_decided(winner: PlayerInfo, team: int)
signal level_ready(level: Node)

enum State { LOADING, COUNTDOWN, LIVE, ROUND_END, MATCH_END }

const PLAYER_SCENE := "res://scenes/player.tscn"

var rules: GameRules
var infos: Array[PlayerInfo] = []
var state := State.LOADING
## Seconds left: of the countdown, the round or game (when it has a limit),
## or the pause after a round or the match.
var timer := 0.0
var round_number := 0
var team_scores := [0, 0]
var map_name := ""
var level: Node
## [map, winner's name ("" for a draw)] per round played.
var history: Array = []

var _maps := PackedStringArray()
## The scene being left for the next map (it may be the same map again).
var _leaving: Node
var _limited := false
var _respawns := {}


func _ready() -> void:
	if map_name == "":
		next_map.call_deferred()


## Loads the next map of the pool (a shuffled cycle, never the same twice
## in a row); the match picks it up once it's the current scene.
func next_map() -> void:
	if _maps.is_empty():
		_maps = _shuffled_pool()
	map_name = _maps[0]
	_maps.remove_at(0)
	_leaving = get_tree().current_scene if is_inside_tree() else null
	level = null
	_enter(State.LOADING)
	var path := Maps.scene_of(map_name)
	if path != "":
		Wipe.change_scene(get_tree(), path)


func _shuffled_pool() -> PackedStringArray:
	var pool := Array(rules.map_pool).filter(func(m: String) -> bool: return Maps.scene_of(m) != "")
	pool.shuffle()
	if pool.size() > 1 and pool[0] == map_name:
		pool.append(pool.pop_front())
	return PackedStringArray(pool)


func _process(_delta: float) -> void:
	if state != State.LOADING or not is_inside_tree():
		return
	var scene := get_tree().current_scene
	if scene and scene != level and scene != _leaving and scene.scene_file_path == Maps.scene_of(map_name) and scene.is_node_ready():
		setup_level(scene)


## Puts the game's players in `scene` and sets it up for the rules, then
## starts the first round (or the game).
func setup_level(scene: Node) -> void:
	level = scene
	var baked := scene.get_node_or_null(^"Player") as Player
	var has_local := infos.any(func(i: PlayerInfo) -> bool: return i.local)
	var local_team := Hats.Team.RED
	for info in infos:
		if info.local:
			local_team = info.team
	for info in infos:
		var body: Player
		if info.local and baked:
			body = baked
		else:
			body = (load(PLAYER_SCENE) as PackedScene).instantiate()
			body.human_controlled = false
			body.name = "Player_%s" % (("bot%d" % -info.id) if info.id < 0 else str(info.id))
			scene.add_child(body)
		_configure(body, info, local_team)
	if baked and not has_local:
		baked.queue_free()
	for pad in _all_of(scene, "WeaponPad"):
		if pad.respawn_time <= 0.0:
			if rules.power_pad_respawn > 0.0:
				pad.respawn_time = rules.power_pad_respawn
		else:
			pad.respawn_time *= rules.pad_respawn_scale
	for crate: Node in get_tree().get_nodes_in_group(ResupplyCrate.GROUP):
		crate.set(&"enabled", rules.resupply)
		crate.set(&"cooldown", rules.resupply_cooldown)
	level_ready.emit(scene)
	_start_round()


func _configure(body: Player, info: PlayerInfo, local_team: Hats.Team) -> void:
	info.player = body
	body.team = info.team
	body.hat = info.hat
	body.player_name = info.player_name
	body.tint = info.tint(rules.is_teams())
	body.max_health = rules.max_health
	body.regen_delay = rules.regen_delay
	body.regen_rate = rules.regen_rate
	body.auto_respawn = false
	body.refresh_look(rules.is_teams() and info.team == local_team and not info.local)
	body.killed.connect(_on_killed.bind(info))
	if info.bot:
		var brain := BotBrain.new()
		brain.name = "Brain"
		brain.player = body
		brain.match_ref = self
		body.add_child(brain)


func _start_round() -> void:
	round_number += 1
	_respawns.clear()
	var used: Array[Node3D] = []
	for info in infos:
		if info.player and is_instance_valid(info.player):
			used.append(_spawn(info, used))
			info.player.weapons.enabled = false
	timer = rules.countdown
	_enter(State.COUNTDOWN)


func _go_live() -> void:
	for info in infos:
		if info.player and is_instance_valid(info.player):
			info.player.weapons.enabled = true
	var limit := rules.round_time if rules.rounds else rules.time_limit
	_limited = limit > 0.0
	timer = limit
	_enter(State.LIVE)


func _physics_process(delta: float) -> void:
	match state:
		State.COUNTDOWN:
			timer -= delta
			if timer <= 0.0:
				_go_live()
		State.LIVE:
			if _limited:
				timer -= delta
				if timer <= 0.0:
					if rules.rounds:
						_end_round(null)
					else:
						_end_on_time()
					return
			for info: PlayerInfo in _respawns.keys():
				_respawns[info] -= delta
				if _respawns[info] <= 0.0:
					_respawns.erase(info)
					if info.player and is_instance_valid(info.player):
						_spawn(info, [])
		State.ROUND_END:
			timer -= delta
			if timer <= 0.0:
				_after_round()
		State.MATCH_END:
			timer -= delta
			if timer <= 0.0:
				Game.end(get_tree())


## Puts `info`'s player at the best spawn for them: their team's, as far as
## possible from living enemies, not one in `used` if it can help it.
## Returns the spawn.
func _spawn(info: PlayerInfo, used: Array) -> Node3D:
	var body := info.player
	var points := spawns_for(info)
	var best: Node3D = null
	var best_score := -INF
	for p: Node3D in points:
		var nearest := 1000.0
		for other in infos:
			if other != info and other.alive() and (not rules.is_teams() or other.team != info.team):
				nearest = minf(nearest, other.player.global_position.distance_to(p.global_position))
		var score := nearest + randf() * 3.0 - (500.0 if p in used else 0.0)
		if score > best_score:
			best_score = score
			best = p
	var at := best.global_transform if best else Transform3D.IDENTITY
	body.spawn_at(at)
	if rules.spawn_weapon != &"":
		body.weapons.give(Weapons.get_def(rules.spawn_weapon))
	return best


## The spawns `info` may use: their team's in teams (all of them if the map
## doesn't say whose they are), any in free-for-all.
func spawns_for(info: PlayerInfo) -> Array:
	if level == null:
		return []
	var all := get_tree().get_nodes_in_group(&"spawn").filter(func(n: Node) -> bool: return level.is_ancestor_of(n))
	if rules.is_teams():
		var mine := all.filter(func(n: Node) -> bool: return n.get_meta(&"team", -1) == info.team)
		if not mine.is_empty():
			return mine
	return all


func _on_killed(kill: Dictionary, victim: PlayerInfo) -> void:
	if state != State.LIVE:
		return
	victim.deaths += 1
	var killer := info_of(kill.get("attacker"))
	var weapon: WeaponDef = kill.get("weapon")
	var heartshot: bool = kill.get("heartshot", false)
	if killer and killer != victim:
		if rules.is_teams() and killer.team == victim.team:
			killer.kills -= 1
		else:
			killer.kills += 1
			if heartshot:
				killer.heartshots += 1
			if rules.is_teams():
				team_scores[killer.team] += 1
	kill_feed.emit(killer, victim, weapon.display_name if weapon else "", heartshot)
	scores_changed.emit()
	if rules.rounds:
		var alive := infos.filter(func(i: PlayerInfo) -> bool: return i.alive())
		if alive.size() <= 1 and infos.size() > 1:
			_end_round.call_deferred(alive[0] if alive.size() == 1 else null)
	elif rules.respawn:
		_respawns[victim] = rules.respawn_delay
	if rules.is_teams() and rules.score_to_win > 0 and killer and team_scores[killer.team] >= rules.score_to_win:
		_end_match(null, killer.team)


func _end_round(winner: PlayerInfo) -> void:
	if state != State.LIVE:
		return
	if winner:
		winner.round_wins += 1
	history.append([map_name, winner.player_name if winner else ""])
	timer = rules.round_end_time
	_enter(State.ROUND_END)
	round_decided.emit(winner)
	scores_changed.emit()


func _after_round() -> void:
	for info in infos:
		if rules.round_wins > 0 and info.round_wins >= rules.round_wins:
			_end_match(info, -1)
			return
	if rules.map_each_round:
		next_map()
	else:
		_start_round()


## Time's up in a game without rounds: the team (or player) ahead wins.
func _end_on_time() -> void:
	if rules.is_teams():
		var team := -1
		if team_scores[Hats.Team.RED] != team_scores[Hats.Team.BLUE]:
			team = Hats.Team.RED if team_scores[Hats.Team.RED] > team_scores[Hats.Team.BLUE] else Hats.Team.BLUE
		_end_match(null, team)
	else:
		var ranked := standings()
		var tied := ranked.size() > 1 and ranked[0].kills == ranked[1].kills
		_end_match(null if ranked.is_empty() or tied else ranked[0], -1)


func _end_match(winner: PlayerInfo, team: int) -> void:
	if state == State.MATCH_END:
		return
	for info in infos:
		if info.player and is_instance_valid(info.player):
			info.player.weapons.enabled = false
	timer = rules.match_end_time
	_enter(State.MATCH_END)
	match_decided.emit(winner, team)


func _enter(new_state: State) -> void:
	state = new_state
	state_changed.emit(new_state)


## Whether `attacker` can hurt `victim` right now: only while live, and
## never a teammate unless friendly fire is on.
func can_damage(attacker: Player, victim: Player) -> bool:
	if state != State.LIVE:
		return false
	if rules.friendly_fire or not rules.is_teams():
		return true
	var a := info_of(attacker)
	var v := info_of(victim)
	return a == null or v == null or a.team != v.team


## The PlayerInfo whose body is `body`, or null.
func info_of(body: Variant) -> PlayerInfo:
	if body == null or not is_instance_valid(body):
		return null
	for info in infos:
		if info.player == body:
			return info
	return null


## The local person's PlayerInfo, or null (a dedicated server).
func local_info() -> PlayerInfo:
	for info in infos:
		if info.local:
			return info
	return null


## Players best first: round wins, then kills, then fewest deaths.
func standings() -> Array[PlayerInfo]:
	var out := infos.duplicate()
	out.sort_custom(func(a: PlayerInfo, b: PlayerInfo) -> bool:
		if a.round_wins != b.round_wins:
			return a.round_wins > b.round_wins
		if a.kills != b.kills:
			return a.kills > b.kills
		return a.deaths < b.deaths)
	return out


static func _all_of(root: Node, script_class: String) -> Array:
	var out := []
	for n in root.find_children("*", "", true, false):
		var s: Script = n.get_script()
		if s and s.get_global_name() == script_class:
			out.append(n)
	return out
