extends "res://tests/test_suite.gd"
## Networked play end to end (docs/NETWORKING.md), in real time: a dedicated
## server in a second Godot process, this one joining it as a client, and a
## third joining a game in progress; then this one hosting a game (a player
## at the keyboard and the server at once) that a friend joins. tools/run_tests.sh runs it after the
## other suites, without --fixed-fps: networked processes have to run at the
## speed of the clock, like the real thing.
##
## The tests run in order and build on each other (one server throughout).

const PORT := 27990
const HOST_PORT := 27991
const PASSWORD := "hunter2"
const SERVER_NAME := "test server"
## Seconds the latecomer stays.
const LATE_STAY := 5.0
## Seconds to give up waiting on something.
const PATIENCE := 15.0

var _server := {}
var _server_log := ""
var _late := {}
var _late_log := ""
var _friend := {}
var _friend_log := ""
var _feed: Array = []
var _states: Array = []
var _saved_path := ""


func _ready() -> void:
	_saved_path = Cosmetics.path
	Cosmetics.path = "user://test_online_cosmetics.cfg"
	Cosmetics.load_saved()
	Cosmetics.set_player_name("tester")
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--", "--server",
			"--port", str(PORT), "--mode", "ffa", "--maps", "stack", "--bots", "2", "--password", PASSWORD,
			"--start-delay", "1", "--name", SERVER_NAME])
	_server = OS.execute_with_pipe(OS.get_executable_path(), args, false)
	super._ready()


func _exit_tree() -> void:
	if not failures.is_empty():
		print("--- the server's log ---\n%s\n--- the latecomer's log ---\n%s\n--- the friend's log ---\n%s\n---" % [
				_server_log + _read(_server), _late_log + _read(_late), _friend_log + _read(_friend)])
	NetSession.leave(get_tree())
	for p: Dictionary in [_server, _late, _friend]:
		if p.has("pid") and OS.is_process_running(p.pid):
			OS.kill(p.pid)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Cosmetics.path))
	Cosmetics.path = _saved_path
	Cosmetics.load_saved()


func _process(_delta: float) -> void:
	_server_log += _read(_server)
	_late_log += _read(_late)
	_friend_log += _read(_friend)


func _read(p: Dictionary) -> String:
	if not p.has("stdio"):
		return ""
	var out := ""
	var f: FileAccess = p.stdio
	while true:
		var chunk := f.get_buffer(4096)
		if chunk.is_empty():
			break
		out += chunk.get_string_from_utf8()
	return out


## Waits (in real time) until `cond` holds, at most `seconds`. Whether it did.
func until(cond: Callable, seconds := PATIENCE) -> bool:
	var give_up := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not cond.call():
		if Time.get_ticks_msec() > give_up:
			return false
		await get_tree().process_frame
	return true


func _join(password: String) -> Array:
	var result := []
	NetSession.join(get_tree(), "127.0.0.1", PORT, password)
	NetSession.current.join_finished.connect(func(ok: bool, reason: String) -> void: result.append_array([ok, reason]))
	await until(func() -> bool: return not result.is_empty())
	return result


func _named(player_name: String) -> PlayerInfo:
	var found := Game.current.infos.filter(func(i: PlayerInfo) -> bool: return i.player_name == player_name) if Game.current else []
	return found[0] if not found.is_empty() else null


func _me() -> PlayerInfo:
	return Game.current.local_info() if Game.current and is_instance_valid(Game.current) else null


# --- The tests, in order ---------------------------------------------------------------------

func test_the_server_starts() -> void:
	check(not _server.is_empty() and OS.is_process_running(_server.pid), "the server process is running")
	check(await until(func() -> bool: return "serving" in _server_log), "and says it's serving:\n" + _server_log)
	check(await until(func() -> bool: return SERVER_NAME in _server_log and "password protected" in _server_log),
			"with the name and password it was given")


func test_a_wrong_password_is_refused() -> void:
	var got := await _join("letmein")
	check(got.size() == 2 and got[0] == false and got[1] == "wrong password", "refused, saying why: %s" % [got])
	await until(func() -> bool: return not NetSession.active(), 2.0)
	check(not NetSession.active(), "and the session's closed")
	check(NetSession.take_reason() == "wrong password", "the menu would say why")
	check(await until(func() -> bool: return "refused" in _server_log and "wrong password" in _server_log), "the server logged it")


func test_the_right_password_gets_you_in() -> void:
	var got := await _join(PASSWORD)
	check(got.size() == 2 and got[0] == true, "joined: %s" % [got])
	var s := NetSession.current
	check(s != null and s.server_name == SERVER_NAME and s.dedicated, "the server's name, and that it's dedicated")
	check(await until(func() -> bool: return s.players().size() == 3), "the roster: me and the bots")
	var names := s.players().map(func(i: PlayerInfo) -> String: return i.player_name)
	check("tester" in names and "bot 1" in names and "bot 2" in names, "by name: %s" % [names])
	check(s.players().any(func(i: PlayerInfo) -> bool: return i.local and i.id == s.local_id()), "and I'm the local one")


func test_the_server_starts_a_game_and_you_follow_it() -> void:
	check(await until(func() -> bool: return Game.current != null and is_instance_valid(Game.current)), "a game started")
	var m := Game.current
	if m == null:
		return
	m.kill_feed.connect(func(killer: PlayerInfo, victim: PlayerInfo, _w: String, _h: bool) -> void:
		_feed.append([killer.player_name if killer else "", victim.player_name]))
	m.state_changed.connect(func(st: Match.State) -> void: _states.append(st))
	check(not m.authority, "following, not deciding")
	check(await until(func() -> bool: return m.level != null and m.state != Match.State.LOADING), "the map loaded and the countdown's on")
	check(m.map_name == "stack", "the server's map: " + m.map_name)
	var me := _me()
	check(me != null and me.player != null and me.player.has_node(^"Prediction"), "my body is predicted")
	var bots := m.infos.filter(func(i: PlayerInfo) -> bool: return i.bot)
	check(bots.size() == 2 and bots.all(func(b: PlayerInfo) -> bool: return b.player != null and b.player.has_node(^"Puppet")),
			"the bots' are puppets")


func test_your_movement_is_predicted_and_agrees_with_the_server() -> void:
	var me := _me()
	if me == null:
		check(false, "no game")
		return
	var body := me.player
	var pred: Prediction = body.get_node(^"Prediction")
	await until(func() -> bool: return body.state.on_ground, 3.0)
	var start := body.global_position
	var before := pred.corrections
	body.input_override = func() -> InputCommand:
		var c := InputCommand.new()
		c.move = Vector2(0, 1)
		c.yaw = body.yaw
		return c
	var t := Time.get_ticks_msec()
	await until(func() -> bool: return Time.get_ticks_msec() - t > 1200)
	body.input_override = func() -> InputCommand:
		var c := InputCommand.new()
		c.yaw = body.yaw
		return c
	await until(func() -> bool: return Time.get_ticks_msec() - t > 2200)
	var moved := body.global_position.distance_to(start)
	check(moved > 3.0, "walked %.1f m" % moved)
	check(pred.corrections - before <= 2, "the server agreed (%d corrections)" % (pred.corrections - before))
	check(pred.tick > 60, "and it's been ticking (%d)" % pred.tick)


func test_the_bots_move_and_the_round_plays_out() -> void:
	var m := Game.current
	if m == null:
		check(false, "no game")
		return
	var bot: PlayerInfo = m.infos.filter(func(i: PlayerInfo) -> bool: return i.bot)[0]
	var was := bot.player.global_position
	check(await until(func() -> bool: return is_instance_valid(bot.player) and bot.player.global_position.distance_to(was) > 1.0),
			"a bot's puppet moves")
	# The bots fight (and I stand still): the deaths come through, then the
	# round ends with one left, and the next starts on a new level.
	var round_length := m.rules.countdown + m.rules.round_time + 5.0
	check(await until(func() -> bool: return Match.State.ROUND_END in _states, round_length), "the round ended")
	check(Match.State.LIVE in _states, "after going live")
	check(not _feed.is_empty(), "deaths came through the kill feed")
	for entry: Array in _feed:
		var killer := _named(entry[0])
		var victim := _named(entry[1])
		check(victim != null and victim.deaths >= 1, "%s's death is on the scoreboard" % entry[1])
		check(killer == null or killer.kills >= 1, "and %s's kill" % entry[0])
	var me := _me()
	check(await until(func() -> bool: return m.serial >= 2 and m.level != null and m.state != Match.State.LOADING), "the next round's level")
	check(me.player != null and is_instance_valid(me.player) and not me.player.is_dead, "and I'm back, alive")


func test_someone_can_join_a_game_in_progress() -> void:
	var m := Game.current
	if m == null:
		check(false, "no game")
		return
	var count := m.infos.size()
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/online_client.gd", "--", "--port", str(PORT), "--password", PASSWORD, "--stay", str(LATE_STAY)])
	_late = OS.execute_with_pipe(OS.get_executable_path(), args, false)
	check(await until(func() -> bool: return m.infos.size() == count + 1), "they're in my game")
	var late: PlayerInfo = m.infos.filter(func(i: PlayerInfo) -> bool: return i.player_name == "latecomer").front()
	check(late != null and late.player != null and late.player.has_node(^"Puppet") and late.player.name == Match.body_name(late),
			"with a body of their own")
	check(await until(func() -> bool: return "following stack" in _late_log), "and they're following the game:\n" + _late_log)
	check(await until(func() -> bool: return m.infos.size() == count, 20.0), "then they leave, and they're gone")
	check(await until(func() -> bool: return "latecomer left" in _server_log), "the server saw them go")


func test_your_look_changes_for_everyone_and_you_can_come_back() -> void:
	var m := Game.current
	if m == null:
		check(false, "no game")
		return
	_late_log = ""
	_late = OS.execute_with_pipe(OS.get_executable_path(), PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/online_client.gd", "--", "--port", str(PORT), "--password", PASSWORD, "--name", "watcher",
			"--stay", "20"]), false)
	check(await until(func() -> bool: return "following stack" in _late_log), "someone's watching:\n" + _late_log)
	var hat := Cosmetics.hat
	var color := Cosmetics.color
	var new_hat: StringName = Hats.ALL[(Hats.ALL.find(hat) + 1) % Hats.ALL.size()]
	var keys := Hats.PALETTE.keys()
	var new_color: StringName = keys[(keys.find(color) + 1) % keys.size()]
	# What the pause menu's name field and arrows do.
	Cosmetics.set_player_name("tester two")
	Cosmetics.set_hat(new_hat)
	Cosmetics.set_color(new_color)
	Game.update_look()
	check(await until(func() -> bool: return "tester is now tester two" in _server_log), "the server hears it:\n" + _server_log.right(400))
	var me := _me()
	check(await until(func() -> bool: return me.player_name == "tester two" and me.hat == new_hat and me.color == new_color),
			"and tells everyone, me included")
	check(me.player.player_name == "tester two" and me.player.hat == new_hat, "my body wears it")
	var seen := "tester two (%s, %s)" % [new_hat, new_color]
	check(await until(func() -> bool: return seen in _late_log), "and they see it:\n" + _late_log)
	# Leave and come back: the same score.
	var kills := me.kills
	var deaths := me.deaths
	NetSession.leave(get_tree())
	check(await until(func() -> bool: return Game.current == null and "tester two left" in _server_log), "I leave")
	check(NetSession.last_join.get("port") == PORT and NetSession.last_join.get("password") == PASSWORD, "the menu can offer to rejoin")
	var result: Array = await _join(PASSWORD)
	check(not result.is_empty() and result[0], "and I rejoin: %s" % [result])
	check(await until(func() -> bool: return "tester two is back" in _server_log), "the server knows me:\n" + _server_log.right(400))
	check(await until(func() -> bool: return Game.current != null and Game.current.level != null and _me() != null), "back in the game")
	me = _me()
	check(me.kills >= kills and me.deaths >= deaths and ("%d kills, %d deaths" % [kills, deaths]) in _server_log,
			"with my score: %d kills, %d deaths (%d, %d before)" % [me.kills, me.deaths, kills, deaths])
	Cosmetics.set_player_name("tester")
	Cosmetics.set_hat(hat)
	Cosmetics.set_color(color)
	Game.update_look()
	check(await until(func() -> bool: return "tester two is now tester" in _server_log and "tester (%s, %s)" % [hat, color] in _late_log),
			"and back to how I was, for everyone")
	check(await until(func() -> bool: return "watcher left" in _server_log, 25.0), "then they go")


func test_junk_gets_you_kicked() -> void:
	var m := Game.current
	var s := NetSession.current
	if m == null or s == null:
		check(false, "no game")
		return
	var reasons := []
	s.left.connect(func(r: String) -> void: reasons.append(r))
	for i in NetSession.STRIKES_TO_KICK + 5:
		m.sync._client_inputs.rpc_id(1, PackedByteArray([255, 1, 2, 3]))
	check(await until(func() -> bool: return not reasons.is_empty()), "thrown out")
	check(reasons.size() == 1 and reasons[0] == "the server went away", "the connection's gone: %s" % [reasons])
	check(await until(func() -> bool: return "kicking" in _server_log), "the server said why:\n" + _server_log.right(400))
	check(await until(func() -> bool: return Game.current == null), "and the game's over for me")
	check(NetSession.take_reason() == "the server went away", "the menu would say so")
	await until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == Game.MENU_SCENE, 5.0)
	check(await until(func() -> bool: return "everyone left" in _server_log), "the server went back to waiting")


func test_teams_online_your_pick_and_the_ammo_boxes() -> void:
	await until(func() -> bool: return not NetSession.active() and Game.current == null, 5.0)
	var rules := GameRules.teams()
	rules.map_pool = PackedStringArray(["boulevard"])
	rules.countdown = 1.0
	check(NetSession.host(get_tree(), HOST_PORT, rules) == OK, "hosting teams")
	var s := NetSession.current
	_friend_log = ""
	_friend = OS.execute_with_pipe(OS.get_executable_path(), PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/online_client.gd", "--", "--port", str(HOST_PORT), "--name", "friend", "--gun", "sniper", "--stay", "14"]), false)
	check(await until(func() -> bool: return s.players().size() == 2), "a friend joined")
	Game.start(get_tree(), s.rules, s.players())
	var m := Game.current
	check(await until(func() -> bool: return m.state == Match.State.LIVE), "live")
	var friend := _named("friend")
	check(friend != null and friend.gun == Weapons.SNIPER, "the server heard which gun they picked")
	check(await until(func() -> bool: return "holding: sniper" in _friend_log), "and they spawn holding it:\n" + _friend_log)
	check(await until(func() -> bool: return "ammo boxes up: 21" in _friend_log), "they see all 21 ammo boxes")
	var me := _me()
	var box: AmmoBox = Match._all_of(m.level, "AmmoBox")[0]
	me.player.weapons.primary_ammo = 1
	me.player.global_position = box.global_position
	check(await until(func() -> bool: return not box.available), "I take one")
	check(await until(func() -> bool: return "ammo boxes up: 20" in _friend_log), "and they see it go")
	NetSession.leave(get_tree())
	check(await until(func() -> bool: return Game.current == null and not NetSession.active()), "closed")
	if OS.is_process_running(_friend.pid):
		OS.kill(_friend.pid)
	_friend = {}
	_friend_log = ""


func test_you_can_host_and_a_friend_joins() -> void:
	await until(func() -> bool: return not NetSession.active() and Game.current == null, 5.0)
	var rules := GameRules.free_for_all()
	rules.map_pool = PackedStringArray(["stack"])
	check(NetSession.host(get_tree(), HOST_PORT, rules) == OK, "hosting")
	var s := NetSession.current
	check(s.role == NetSession.Role.HOST and s.players().size() == 1 and s.players()[0].local, "on my own, as player 1")
	_friend = OS.execute_with_pipe(OS.get_executable_path(), PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/online_client.gd", "--", "--port", str(HOST_PORT), "--name", "friend", "--walk", "--stay", "20"]), false)
	check(await until(func() -> bool: return s.players().size() == 2), "a friend joined")
	# What the lobby's start button does.
	Game.start(get_tree(), s.rules, s.players())
	var m := Game.current
	check(m.authority, "my machine decides the game")
	check(await until(func() -> bool: return m.state == Match.State.COUNTDOWN), "the countdown, once they'd loaded the map too")
	check(await until(func() -> bool: return "following stack" in _friend_log and "tester, friend" in _friend_log),
			"they're following my game, and see me in it:\n" + _friend_log)
	var me := _me()
	var friend := _named("friend")
	check(me != null and me.player != null and me.player.name == "Player_1" and not me.player.has_node(^"Prediction"),
			"I play my own player, no prediction needed")
	check(friend != null and friend.player != null and friend.player.input_source.is_valid(), "theirs runs on what they send")
	var was := friend.player.global_position if friend and friend.player else Vector3.ZERO
	check(await until(func() -> bool: return friend.player.global_position.distance_to(was) > 1.0), "and they walk about")
	# A thrown gun: they see it fly, land where it landed here, and go.
	me.player.weapons.give(Weapons.get_def(Weapons.RIFLE))
	me.player.weapons.throw_primary()
	var thrown: WeaponPickup = get_tree().get_nodes_in_group(WeaponPickup.GROUP).filter(func(p: WeaponPickup) -> bool: return p.pad == null).front()
	check(await until(func() -> bool: return "loose weapons: 1" in _friend_log), "they see the gun I threw")
	check(await until(func() -> bool: return "rests at" in _friend_log), "come to rest")
	var line := Array(_friend_log.split("\n")).filter(func(l: String) -> bool: return "rests at" in l).back() as String
	var there: Variant = str_to_var(line.get_slice("rests at ", 1).strip_edges())
	check(there is Vector3 and is_instance_valid(thrown) and (there as Vector3).distance_to(thrown.global_position) < 0.1,
			"where it came to rest here: %s and %s" % [there, thrown.global_position if is_instance_valid(thrown) else null])
	thrown.take(thrown.ammo)
	check(await until(func() -> bool: return "loose weapons: 0" in _friend_log), "and see it go when it's picked up")
	check(await until(func() -> bool: return s.players().size() == 1, 20.0), "then they leave")
	check(m.infos.size() == 1 and Game.current == m, "and my game goes on without them")
	NetSession.leave(get_tree())
	check(Game.current == null and not NetSession.active(), "closing the game ends it")
