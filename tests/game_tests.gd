extends "res://tests/test_suite.gd"
## Game tests (GDD §5.1, §8, §11.4, §14): players hurting players and who
## gets the kill; the two game styles run by a Match on real maps with
## script-driven players (free-for-all rounds, teams with respawns, what you
## spawn holding, pad timers, resupply, friendly fire); the colours, names
## and nametags people wear; and bots arming themselves.

const DT := 1.0 / 60.0
const TEST_COSMETICS := "user://test_game_cosmetics.cfg"

var world: Node3D
var _saved_path := ""


func _setup() -> void:
	seed(4321)
	_saved_path = Cosmetics.path
	Cosmetics.path = TEST_COSMETICS
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_COSMETICS))
	world = Node3D.new()
	add_child(world)
	await frames(1)


func _teardown() -> void:
	Game.end(get_tree(), false)
	for n in get_tree().root.get_children():
		if n is Wipe:
			n.queue_free()
	var scene := get_tree().current_scene
	if scene:
		scene.queue_free()
		get_tree().current_scene = null
	if world:
		world.queue_free()
	world = null
	CombatFx.clear_holes()
	Cosmetics.path = _saved_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_COSMETICS))


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## A script-driven player standing in `world` at `at`, facing `yaw`.
func make_player(at: Vector3, yaw := 0.0) -> Player:
	if world.get_node_or_null(^"Floor") == null:
		var floor_body := StaticBody3D.new()
		floor_body.name = "Floor"
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(200, 1, 200)
		col.shape = shape
		floor_body.add_child(col)
		floor_body.position = Vector3(0, -0.5, 0)
		world.add_child(floor_body)
	var p: Player = load("res://scenes/player.tscn").instantiate()
	p.human_controlled = false
	p.movement_params = MovementParams.new()
	p.view_settings = ViewSettings.new()
	world.add_child(p)
	p.set_process(false)
	p.spawn_at(Transform3D(Basis(Vector3.UP, yaw), at))
	return p


## A hit as Ballistics would land it.
func hit(attacker: Player, damage: float, heartshot := false) -> Dictionary:
	return {"damage": damage, "zone": &"body", "part": &"chest", "point": Vector3(0, 1.2, 0), "normal": Vector3.BACK,
			"direction": Vector3.FORWARD, "heartshot": heartshot, "weapon": Weapons.get_def(Weapons.RIFLE),
			"attacker": attacker, "knockback": 0.0}


## Players for a game: `count` script-driven ones (no bots), on teams by turns.
func people(count: int) -> Array[PlayerInfo]:
	var out: Array[PlayerInfo] = []
	for i in count:
		var info := PlayerInfo.new()
		info.id = 10 + i
		info.player_name = "p%d" % i
		info.team = Hats.Team.RED if i % 2 == 0 else Hats.Team.BLUE
		info.color = Hats.PALETTE.keys()[i % Hats.PALETTE.size()]
		out.append(info)
	return out


## Runs physics frames until `m` is in `state` (or gives up). True if it got there.
func until_state(m: Match, state: Match.State, max_frames := 900) -> bool:
	for i in max_frames:
		if m.state == state:
			return true
		await get_tree().physics_frame
	return m.state == state


func quick(rules: GameRules, map: String) -> GameRules:
	rules.map_pool = PackedStringArray([map])
	rules.countdown = 0.3
	rules.round_end_time = 0.3
	rules.match_end_time = 30.0
	return rules


# --- Hurting each other -----------------------------------------------------------

func test_a_real_shot_hurts_another_player_and_kills_them_at_zero() -> void:
	var shooter := make_player(Vector3(0, 0.05, 0), 0.0)
	var target := make_player(Vector3(0, 0.05, -8), PI)
	await physics(10)
	var deaths := []
	target.killed.connect(func(info: Dictionary) -> void: deaths.append(info))
	shooter.weapons.give(Weapons.get_def(Weapons.RIFLE))
	# Aim at the chest.
	var eye := shooter.weapons.eye_position()
	var chest := target.global_position + Vector3.UP * 1.25
	shooter.pitch = atan2(chest.y - eye.y, eye.distance_to(Vector3(chest.x, eye.y, chest.z)))
	var hurt_at := -1.0
	for i in 240:
		var c := InputCommand.new()
		c.yaw = shooter.yaw
		c.pitch = shooter.pitch
		c.fire_held = true
		c.fire_pressed = i % 6 == 0
		await get_tree().physics_frame
		shooter.tick(c, DT)
		target.tick(InputCommand.new(), DT)
		if hurt_at < 0.0 and target.health < Player.MAX_HEALTH:
			hurt_at = target.health
		if target.is_dead:
			break
	check(hurt_at > 0.0 and hurt_at < Player.MAX_HEALTH, "a hit takes health off (%.0f left)" % hurt_at)
	check(target.is_dead and target.health == 0.0, "shot until dead")
	check(deaths.size() == 1 and deaths[0].attacker == shooter and deaths[0].weapon == Weapons.get_def(Weapons.RIFLE),
			"the kill is the shooter's, with the rifle")


func test_a_heartshot_kills_outright_and_a_fall_after_a_hit_is_the_hitters() -> void:
	var a := make_player(Vector3(0, 0.05, 0))
	var b := make_player(Vector3(3, 0.05, 0))
	var c := make_player(Vector3(6, 0.05, 0))
	await physics(5)
	var kills := {}
	for p: Player in [b, c]:
		p.killed.connect(func(info: Dictionary) -> void: kills[p] = info)
	b.take_hit(hit(a, 5.0, true))
	check(b.is_dead and kills.has(b) and kills[b].heartshot and kills[b].attacker == a, "through the heart: dead, a heartshot, a's kill")
	c.take_hit(hit(a, 10.0))
	check(not c.is_dead and c.health == 90.0, "a 10 damage hit leaves 90")
	c.die()  # Falls off the map straight after.
	check(kills.has(c) and kills[c].attacker == a and not kills[c].heartshot, "a fall after a hit counts for the hitter")
	var d := make_player(Vector3(9, 0.05, 0))
	await physics(2)
	var lone := []
	d.killed.connect(func(info: Dictionary) -> void: lone.append(info))
	d.die()
	check(lone.size() == 1 and lone[0].attacker == null, "a fall nobody caused is nobody's kill")


func test_you_cant_shoot_yourself_and_health_comes_back_when_the_rules_say() -> void:
	var a := make_player(Vector3(0, 0.05, 0))
	var b := make_player(Vector3(3, 0.05, 0))
	await physics(5)
	check(a.take_hit(hit(a, 50.0)).is_empty() and a.health == Player.MAX_HEALTH, "your own shots don't hurt you")
	b.regen_delay = 0.5
	b.regen_rate = 50.0
	b.take_hit(hit(a, 40.0))
	for i in 20:
		await get_tree().physics_frame
		b.tick(InputCommand.new(), DT)
	check(b.health == 60.0, "no healing inside the delay (%.0f)" % b.health)
	for i in 60:
		await get_tree().physics_frame
		b.tick(InputCommand.new(), DT)
	check(b.health == Player.MAX_HEALTH, "back to full after it (%.0f)" % b.health)
	b.respawn()
	check(b.health == b.max_health, "respawning is full health")


# --- Free-for-all -----------------------------------------------------------------

func test_ffa_last_one_standing_wins_rounds_and_rounds_win_the_match() -> void:
	var rules := quick(GameRules.free_for_all(), "stack")
	rules.round_wins = 2
	var infos := people(4)
	var m := Game.start(get_tree(), rules, infos)
	var decided := []
	m.match_decided.connect(func(w: PlayerInfo, team: int) -> void: decided.append([w, team]))
	check(await until_state(m, Match.State.COUNTDOWN), "loads the map and counts down")
	var spots := {}
	for info in infos:
		spots[info.player.global_position.snapped(Vector3.ONE)] = true
		check(not info.player.weapons.enabled, "%s: weapons off in the countdown" % info.player_name)
		check(info.player.weapons.primary == null, "%s: starts with fists" % info.player_name)
	check(spots.size() == 4, "four players, four different spawns (%d)" % spots.size())
	check(await until_state(m, Match.State.LIVE), "then goes live")
	check(infos.all(func(i: PlayerInfo) -> bool: return i.player.weapons.enabled), "weapons on")
	for round_number in [1, 2]:
		if round_number == 2:
			check(await until_state(m, Match.State.LIVE, 1200), "round 2 on a fresh map")
		infos[1].player.take_hit(hit(infos[0].player, 200.0))
		infos[2].player.die()
		check(m.state == Match.State.LIVE, "two left: the round goes on")
		infos[3].player.take_hit(hit(infos[0].player, 200.0))
		await physics(2)
		check(m.state == Match.State.ROUND_END and infos[0].round_wins == round_number, "one left: p0 wins round %d" % round_number)
	check(infos[0].kills == 4 and infos[2].deaths == 2 and infos[2].kills == 0, "kills and deaths add up (%d kills)" % infos[0].kills)
	check(await until_state(m, Match.State.MATCH_END), "two round wins take the match")
	check(decided.size() == 1 and decided[0][0] == infos[0], "p0 wins it")
	check(m.history.size() == 2 and m.history[0][1] == "p0", "the rounds are remembered")


func test_ffa_players_wear_their_own_colours_and_no_resupply() -> void:
	var rules := quick(GameRules.free_for_all(), "boulevard")
	var infos := people(3)
	infos[0].color = &"lime"
	infos[1].color = &"pink"
	var m := Game.start(get_tree(), rules, infos)
	check(await until_state(m, Match.State.LIVE), "live")
	check(infos[0].player.model.tint == Hats.PALETTE[&"lime"] and infos[1].player.model.tint == Hats.PALETTE[&"pink"],
			"everyone in their own colour")
	var crates := get_tree().get_nodes_in_group(ResupplyCrate.GROUP)
	check(not crates.is_empty() and crates.all(func(c: Node) -> bool: return not c.enabled and not c.visible), "the crates are off and hidden")
	var p := infos[0].player
	p.weapons.give(Weapons.get_def(Weapons.RIFLE), 3)
	p.global_position = (crates[0] as Node3D).global_position
	await physics(3)
	check(p.weapons.primary_ammo == 3, "and don't refill anything")


# --- Teams ------------------------------------------------------------------------

func test_teams_spawn_on_their_side_with_a_pistol_and_respawn() -> void:
	var rules := quick(GameRules.teams(), "boulevard")
	rules.respawn_delay = 0.3
	var infos := people(4)
	var m := Game.start(get_tree(), rules, infos)
	check(await until_state(m, Match.State.LIVE), "live")
	for info in infos:
		var side_x := info.player.global_position.x
		check((side_x < 0.0) == (info.team == Hats.Team.RED), "%s spawns on %s's side (x %.0f)" % [info.player_name, ["red", "blue"][info.team], side_x])
		check(info.player.weapons.primary == Weapons.get_def(Weapons.PISTOL), "%s holds a pistol" % info.player_name)
		check(info.player.model.tint == Hats.team_color(info.team), "%s wears the team colour" % info.player_name)
	var red := infos[0]
	var blue := infos[1]
	blue.player.take_hit(hit(red.player, 200.0))
	check(m.team_scores == [1, 0] and red.kills == 1, "a kill scores for the killer's team")
	check(blue.player.is_dead, "blue's down")
	await physics(40)
	check(blue.alive() and blue.player.global_position.x > 0.0, "and back on its side after the respawn delay")
	check(blue.player.weapons.primary == Weapons.get_def(Weapons.PISTOL), "with a pistol again")


func test_teams_friendly_fire_is_off_and_the_kill_target_ends_it() -> void:
	var rules := quick(GameRules.teams(), "boulevard")
	rules.score_to_win = 2
	var infos := people(4)
	var m := Game.start(get_tree(), rules, infos)
	var decided := []
	m.match_decided.connect(func(w: PlayerInfo, team: int) -> void: decided.append(team))
	check(await until_state(m, Match.State.LIVE), "live")
	var red_a := infos[0]
	var red_b := infos[2]
	check(red_b.player.take_hit(hit(red_a.player, 60.0)).is_empty() and red_b.player.health == Player.MAX_HEALTH,
			"a teammate's shot does nothing")
	infos[1].player.take_hit(hit(red_a.player, 200.0))
	infos[3].player.take_hit(hit(red_b.player, 200.0))
	await physics(2)
	check(m.state == Match.State.MATCH_END and decided == [Hats.Team.RED], "red reaches the target and wins")
	check(not infos[0].player.weapons.enabled, "weapons off once it's over")


func test_teams_pads_come_back_faster_and_crates_refill_your_gun() -> void:
	var rules := quick(GameRules.teams(), "boulevard")
	var infos := people(2)
	var m := Game.start(get_tree(), rules, infos)
	check(await until_state(m, Match.State.LIVE), "live")
	var sniper: Node = m.level.find_child("Pad_Sniper_Blue", true, false)
	var pistol: Node = m.level.find_child("Pad_Pistol_Blue", true, false)
	check(sniper.respawn_time == rules.power_pad_respawn, "the sniper comes back (%.0f s)" % sniper.respawn_time)
	check(pistol.respawn_time == 10.0, "other pads twice as fast (%.0f s)" % pistol.respawn_time)
	var crate := m.level.find_child("Resupply_Yard_Blue", true, false) as ResupplyCrate
	check(crate.enabled and crate.visible, "the crates are on")
	var p := infos[1].player
	p.weapons.give(Weapons.get_def(Weapons.RIFLE), 3)
	p.global_position = crate.global_position
	await physics(3)
	check(p.weapons.primary_ammo == Weapons.get_def(Weapons.RIFLE).ammo, "walking up to a crate fills the magazine")
	p.weapons.primary_ammo = 2
	await physics(3)
	check(p.weapons.primary_ammo == 2 and crate.wait_for(p) > 0.0, "then it waits before it'll fill it again")


# --- Looks, names and tags --------------------------------------------------------------

func test_colours_and_names_are_saved_and_cleaned_up() -> void:
	Cosmetics.set_color(&"lime")
	Cosmetics.set_player_name("  ace\n  of\t  hearts and more words  ")
	Cosmetics.load_saved()
	check(Cosmetics.color == &"lime" and Cosmetics.tint() == Hats.PALETTE[&"lime"], "the colour comes back next time")
	check(Cosmetics.player_name.length() <= Cosmetics.NAME_LENGTH and not "\n" in Cosmetics.player_name,
			"the name is cleaned and cut short (%s)" % Cosmetics.player_name)
	check(Cosmetics.clean_name("a  \u0007 b") == "a b", "control characters out, spaces squeezed")
	check(Cosmetics.clean_name("   ") == Cosmetics.DEFAULT_NAME, "nothing left: the default")
	Cosmetics.set_color(&"not a colour")
	check(Cosmetics.color == Cosmetics.DEFAULT_COLOR, "an unknown colour is the default")


func test_player_info_from_anywhere_is_checked() -> void:
	var info := PlayerInfo.from_dict({"id": "5", "name": "\u0001\u0002", "team": 7, "color": "../../etc", "hat": "crown",
			"bot": "yes", "kills": 1e9, "deaths": -3, "extra": Object})
	check(info.id == 0 and info.player_name == Cosmetics.DEFAULT_NAME and info.team == Hats.Team.RED, "bad fields fall back")
	check(info.color == Cosmetics.DEFAULT_COLOR and info.hat == &"crown" and not info.bot, "only known colours and hats")
	check(info.kills == 0 and info.deaths == -3, "numbers are numbers, in range")
	var back := PlayerInfo.from_dict(people(1)[0].to_dict())
	check(back.player_name == "p0" and back.color == Hats.PALETTE.keys()[0], "and a good one comes back as it was")


func test_nametags_float_over_everyone_but_you_teammates_through_walls() -> void:
	var rules := quick(GameRules.teams(), "boulevard")
	var infos := people(3)
	infos[0].local = true
	var m := Game.start(get_tree(), rules, infos)
	check(await until_state(m, Match.State.LIVE), "live")
	var mine := infos[0].player
	check(mine.human_controlled and mine.model.nametag.text == "", "no tag over your own head")
	var enemy := infos[1].player
	var mate := infos[2].player
	check(enemy.model.nametag.text == "p1" and not enemy.model.nametag.no_depth_test, "an enemy's name, only in sight")
	check(mate.model.nametag.text == "p2" and mate.model.nametag.no_depth_test, "a teammate's, through walls")
	enemy.take_hit(hit(mine, 200.0))
	await frames(2)
	check(not enemy.model.nametag.visible, "no tag over a body in pieces")


# --- Bots -----------------------------------------------------------------------------

func test_bots_arm_themselves_and_fight() -> void:
	var rules := quick(GameRules.free_for_all(), "stack")
	var bots: Array[PlayerInfo] = []
	for n in 3:
		bots.append(PlayerInfo.make_bot(n + 1))
	var m := Game.start(get_tree(), rules, bots)
	check(await until_state(m, Match.State.LIVE), "live")
	check(bots.all(func(b: PlayerInfo) -> bool: return b.player.get_node_or_null(^"Brain") != null), "every bot has a brain")
	var armed := false
	var hurt := false
	for i in 900:
		await get_tree().physics_frame
		for b in bots:
			if b.player and is_instance_valid(b.player):
				armed = armed or b.player.weapons.primary != null
				hurt = hurt or b.player.health < Player.MAX_HEALTH or b.deaths > 0
		if armed and hurt:
			break
	check(armed, "a bot picked up a gun")
	check(hurt, "and someone got hurt")
