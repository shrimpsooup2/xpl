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


## A script-driven player standing in `world` at `at`, facing `yaw`; with
## `human`, the one you play (in first person: its body hidden from you).
func make_player(at: Vector3, yaw := 0.0, human := false) -> Player:
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
	p.human_controlled = human
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


func test_you_can_be_shot_in_first_person() -> void:
	# Your own body is hidden from you, not from everyone else's guns.
	var shooter := make_player(Vector3(0, 0.05, 0), 0.0)
	var you := make_player(Vector3(0, 0.05, -8), PI, true)
	you.set_physics_process(false)  # Driven by the test, not the keyboard.
	await physics(10)
	check(not you.model.visible, "your body is hidden from you in first person")
	var eye := shooter.weapons.eye_position()
	var aim := func(point: Vector3) -> void:
		shooter.pitch = atan2(point.y - eye.y, eye.distance_to(Vector3(point.x, eye.y, point.z)))
	# Fires (every few frames, as a player clicking) until a shot lands.
	var shoot := func(frames: int) -> void:
		var before := you.health
		for i in frames:
			var c := InputCommand.new()
			c.yaw = shooter.yaw
			c.pitch = shooter.pitch
			c.fire_held = true
			c.fire_pressed = i % 6 == 0
			await get_tree().physics_frame
			shooter.tick(c, DT)
			you.tick(InputCommand.new(), DT)
			if you.health < before:
				return
	shooter.weapons.give(Weapons.get_def(Weapons.RIFLE))
	aim.call(you.global_position + Vector3.UP * 1.25)
	await shoot.call(60)
	check(you.health < Player.MAX_HEALTH and not you.is_dead, "a shot to your chest hurts (%.0f left)" % you.health)
	# Crouched, your hit shapes go down with you: a shot at standing head
	# height goes over.
	you.set_process(true)  # It animates the body.
	await frames(2)
	var standing_head := you.global_position + Vector3.UP * 1.55
	var over := eye + (standing_head - eye) * 1.5
	check(you.ray_test(eye, over).get("part") == &"head", "standing, a shot at head height hits your head")
	for i in 30:
		var c := InputCommand.new()
		c.crouch_held = true
		c.crouch_pressed = i == 0
		await get_tree().physics_frame
		you.tick(c, DT)
	await frames(2)
	check(you.ray_test(eye, over).is_empty(), "crouched, a shot at standing head height misses")
	you.respawn()
	shooter.weapons.give(Weapons.get_def(Weapons.PISTOL))
	await physics(60)  # Stood back up, and the pistol's ready.
	var deaths := []
	you.killed.connect(func(info: Dictionary) -> void: deaths.append(info))
	aim.call(you.model.heart.global_position)
	await shoot.call(30)  # Until the first shot lands.
	check(you.is_dead and deaths.size() == 1 and deaths[0].heartshot, "and through the heart, it's a heartshot")


func test_after_dying_in_a_game_you_watch_someone_not_a_black_screen() -> void:
	var you := make_player(Vector3(0, 0.05, 0), 0.0, true)
	you.set_physics_process(false)
	you.auto_respawn = false  # A game: you don't come straight back.
	var killer := make_player(Vector3(4, 0.05, 0))
	var other := make_player(Vector3(-4, 0.05, 0))
	await physics(5)
	you.set_process(true)
	var pause := PauseMenu.new()
	pause.player = you
	add_child(pause)
	you.take_hit(hit(killer, 500.0))
	check(you.is_dead and you.death.is_active(), "dead: the cinematic plays")
	check(pause.in_death_cinematic(), "and the menu waits for it (it plays over everything)")
	you.death.finished.emit()  # It's over (skipped).
	await frames(3)
	check(you.spectating == killer, "then you watch whoever killed you")
	check(not you.death.is_active(), "the cinematic's done, the world put back")
	check(not pause.in_death_cinematic(), "watching someone, esc opens the menu")
	pause.open()
	check(pause.is_open, "and it's open")
	pause.close()
	pause.queue_free()
	await frames(int(DeathSequence.FADE_BACK * 60.0) + 5)
	check(you.death._overlay.color.a == 0.0, "and the picture fades back in from black")
	var cam := you.camera.global_position
	check(cam.distance_to(killer.global_position + Vector3.UP * 1.45) < Player.SPECTATE_DISTANCE + 0.8,
			"from just behind them (%.1f m)" % cam.distance_to(killer.global_position))
	var click := InputEventAction.new()
	click.action = &"fire"
	click.pressed = true
	you._unhandled_input(click)
	check(you.spectating == other, "click: the next one")
	other.die()
	await frames(2)
	check(you.spectating == killer, "when they die, back to whoever's left")
	killer.die()
	await frames(2)
	check(you.spectating == null, "nobody left: nobody to watch")
	you.respawn()
	check(you.spectating == null and not you.is_dead, "back in the game")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


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

func test_teams_you_spawn_with_the_gun_you_picked_and_change_it_while_down() -> void:
	var rules := quick(GameRules.teams(), "boulevard")
	rules.countdown = 1.0
	rules.respawn_delay = 0.3
	var infos := people(4)
	var guns := [Weapons.SNIPER, Weapons.SHOTGUN, Weapons.SMG, Weapons.REVOLVER]
	for i in infos.size():
		infos[i].gun = guns[i]
	var m := Game.start(get_tree(), rules, infos)
	check(await until_state(m, Match.State.COUNTDOWN), "counting down")
	for i in infos.size():
		var info := infos[i]
		var side_x := info.player.global_position.x
		check((side_x < 0.0) == (info.team == Hats.Team.RED), "%s spawns on %s's side (x %.0f)" % [info.player_name, ["red", "blue"][info.team], side_x])
		check(info.player.weapons.primary == Weapons.get_def(guns[i]), "%s holds the gun they picked" % info.player_name)
		check(info.player.model.tint == Hats.team_color(info.team), "%s wears the team colour" % info.player_name)
	m.choose_gun(infos[0], Weapons.RIFLE)
	check(infos[0].player.weapons.primary == Weapons.get_def(Weapons.RIFLE), "picking again in the countdown swaps it at once")
	m.choose_gun(infos[0], &"fists")
	check(infos[0].gun == Weapons.RIFLE, "only a gun can be picked")
	check(await until_state(m, Match.State.LIVE), "live")
	var red := infos[0]
	var blue := infos[1]
	m.choose_gun(red, Weapons.PISTOL)
	check(red.player.weapons.primary == Weapons.get_def(Weapons.RIFLE), "once it's on, a new pick waits for your next life")
	blue.player.take_hit(hit(red.player, 200.0))
	check(m.team_scores == [1, 0] and red.kills == 1, "a kill scores for the killer's team")
	check(blue.player.is_dead and get_tree().get_nodes_in_group(WeaponPickup.GROUP).is_empty(), "blue's down, its gun not left lying about")
	m.choose_gun(blue, Weapons.SMG)
	await physics(40)
	check(blue.alive() and blue.player.global_position.x > 0.0, "back on its side after the respawn delay")
	check(blue.player.weapons.primary == Weapons.get_def(Weapons.SMG), "with the gun it picked while it was down")


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


func test_teams_have_ammo_boxes_instead_of_guns_on_the_map() -> void:
	var rules := quick(GameRules.teams(), "boulevard")
	rules.ammo_respawn = 0.4
	var infos := people(2)
	var m := Game.start(get_tree(), rules, infos)
	check(await until_state(m, Match.State.LIVE), "live")
	check(Match._all_of(m.level, "WeaponPad").is_empty() and get_tree().get_nodes_in_group(ResupplyCrate.GROUP).is_empty()
			and get_tree().get_nodes_in_group(WeaponPickup.GROUP).is_empty(), "no pads, crates or guns on the map")
	var boxes := Match._all_of(m.level, "AmmoBox")
	check(boxes.size() == 21, "an ammo box for each of the 15 pads and 6 crates (%d)" % boxes.size())
	var p := infos[1].player
	var rifle := Weapons.get_def(Weapons.RIFLE)
	p.weapons.give(rifle, 3)
	p.weapons.set_using_primary(false)
	var box: AmmoBox = boxes[0]
	p.global_position = box.global_position
	await physics(3)
	check(p.weapons.primary_ammo == 3 + ceili(rifle.ammo * rules.ammo_share) and not box.available,
			"walking into one tops your gun up by half a magazine (%d) and takes it" % p.weapons.primary_ammo)
	check(p.weapons.using_primary, "and puts the gun back in your hands")
	p.global_position = box.global_position + Vector3(4, 0, 0)  # Step off it.
	await physics(int(rules.ammo_respawn * 60.0) + 5)
	check(box.available, "it comes back")
	p.weapons.primary_ammo = rifle.ammo
	p.global_position = box.global_position
	await physics(3)
	check(box.available, "a full gun leaves it where it is")


func test_kill_combos_chain_within_the_window_and_streaks_until_you_die() -> void:
	var c := KillCombos.new()
	var a := PlayerInfo.new()
	var b := PlayerInfo.new()
	var made := c.record(a, b, 10.0)
	check(made.combo == 1 and made.combo_name == "" and made.streak == 1, "a kill on its own")
	made = c.record(a, b, 12.0)
	check(made.combo == 2 and made.combo_name == "double kill", "another within %.0f s: a double kill" % KillCombos.WINDOW)
	made = c.record(a, b, 15.9)
	check(made.combo == 3 and made.combo_name == "triple kill" and made.streak_name == "on a roll", "a triple kill, and a streak of three: on a roll")
	near(c.time_left(a, 16.9), KillCombos.WINDOW - 1.0, 0.001, "time left to chain the next")
	made = c.record(a, b, 21.0)
	check(made.combo == 1 and made.streak == 4, "too slow: the combo starts over, the streak goes on")
	for i in 5:
		made = c.record(a, b, 22.0 + i)
	check(made.combo == 6 and made.combo_name == "combo ×6", "past a penta kill it counts")
	c.record(b, a, 28.0)
	made = c.record(a, b, 28.5)
	check(made.combo == 1 and made.streak == 1, "dying ends both")
	check(c.record(null, a, 29.0).is_empty() and c.record(a, a, 29.0).is_empty(), "a fall or yourself makes nothing")


func test_in_teams_your_combos_pop_up_and_fill_the_meter() -> void:
	var rules := quick(GameRules.teams(), "boulevard")
	var infos := people(6)
	infos[0].local = true
	var m := Game.start(get_tree(), rules, infos)
	check(await until_state(m, Match.State.LIVE), "live")
	var ui: GameUI = m.level.find_children("*", "GameUI", true, false)[0]
	var me := infos[0]
	infos[1].player.take_hit(hit(me.player, 200.0))
	await frames(10)
	check(ui.hud.combo_shown() == 1, "a kill: the combo meter comes up (×%d)" % ui.hud.combo_shown())
	infos[3].player.take_hit(hit(me.player, 200.0))
	await frames(10)
	check(ui.hud.combo_shown() == 2 and ui.hud.last_popup == "double kill", "another straight after: double kill (%s)" % ui.hud.last_popup)
	infos[5].player.take_hit(hit(me.player, 200.0))
	await frames(10)
	check(ui.hud.combo_shown() == 3 and ui.hud.last_popup == "triple kill", "and a triple (%s)" % ui.hud.last_popup)
	var feed: Control = ui.hud._killfeed.get_child(0)
	check(feed.get_children().any(func(b: Node) -> bool: return b is PanelContainer and LofiUI.label_of(b).text == "×3"),
			"the killfeed marks it ×3")
	await physics(int((KillCombos.WINDOW + 0.5) * 60.0))
	check(ui.hud.combo_shown() == 0, "the window runs out and the meter goes")
	Game.end(get_tree(), false)


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


func test_your_look_changes_mid_game_at_once() -> void:
	var rules := quick(GameRules.free_for_all(), "boulevard")
	var infos := people(2)
	infos[0].local = true
	var m := Game.start(get_tree(), rules, infos)
	check(await until_state(m, Match.State.LIVE), "live")
	var mine := infos[0].player
	var hat: StringName = Hats.ALL[(Hats.ALL.find(infos[0].hat) + 1) % Hats.ALL.size()]
	# What the pause menu's name field and arrows do.
	Cosmetics.set_player_name("new me")
	Cosmetics.set_hat(hat)
	Cosmetics.set_color(&"pink")
	Game.update_look()
	check(infos[0].player_name == "new me" and infos[0].hat == hat and infos[0].color == &"pink", "the game has it")
	check(mine.hat == hat and mine.player_name == "new me" and mine.model.tint == Hats.PALETTE[&"pink"], "and I'm wearing it")
	check(infos[1].player.model.tint != Hats.PALETTE[&"pink"] or infos[1].color == &"pink", "nobody else changed")
	var menus := get_tree().root.find_children("*", "PauseMenu", true, false)
	check(menus.size() == 1 and menus[0]._look != null, "the pause menu has them to change")
	if menus.size() == 1 and menus[0]._look:
		var hat_row: Control = menus[0]._hat_label.get_parent()
		(hat_row.get_child(2) as Button).pressed.emit()  # [>]
		var next: StringName = Hats.ALL[(Hats.ALL.find(hat) + 1) % Hats.ALL.size()]
		check(Cosmetics.hat == next and mine.hat == next, "its arrows step the hat, and I wear it")
		check(LofiUI.label_of(menus[0]._hat_label).text == "hat: " + Hats.NAMES[next], "and it says which")


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
