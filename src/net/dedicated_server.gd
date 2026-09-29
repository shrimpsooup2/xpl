class_name DedicatedServer
extends Node
## The headless dedicated server (docs/NETWORKING.md). Started by running the
## game with `--server` after `--` (or an export with the dedicated_server
## feature), with its settings from the command line and/or a config file:
##
##   godot --headless --path . -- --server --port 27960 --mode teams
##       --maps boulevard,depot --max-players 8 --bots 0 --password x
##       --name "my server" --start-delay 5 --config server.cfg
##
## It serves games of its style back to back while anyone's connected,
## rotating its map pool (bots fill in if asked), and idles when everyone's
## gone. It logs to standard output.

const DEFAULTS := {
	"name": "xtrapartial server", "port": NetSession.DEFAULT_PORT, "max_players": 8, "password": "",
	"mode": "ffa", "maps": "", "bots": 0, "start_delay": 5.0,
}

var session: NetSession
var rules: GameRules
var bots := 0
## Seconds between one game ending (or the first player arriving) and the next.
var start_delay := 5.0
var _wait := 5.0


## Whether this run asked for a dedicated server.
static func requested() -> bool:
	return OS.has_feature("dedicated_server") or "--server" in OS.get_cmdline_user_args()


## The server's settings: defaults, then the config file (if --config names
## one), then the command line. Unknown keys are ignored; values are checked.
static func settings(args: PackedStringArray) -> Dictionary:
	var out := DEFAULTS.duplicate()
	var flags := {}
	var i := 0
	while i < args.size():
		var a := args[i]
		if a.begins_with("--") and a != "--server":
			var key := a.substr(2).replace("-", "_")
			if i + 1 < args.size() and not args[i + 1].begins_with("--"):
				flags[key] = args[i + 1]
				i += 2
				continue
			flags[key] = "true"
		i += 1
	if flags.has("config"):
		var cfg := ConfigFile.new()
		if cfg.load(flags.config) == OK:
			for key in cfg.get_section_keys("server") if cfg.has_section("server") else []:
				if DEFAULTS.has(key):
					out[key] = cfg.get_value("server", key)
	for key: String in flags:
		if DEFAULTS.has(key):
			out[key] = flags[key]
	out.port = clampi(int(str(out.port)), 1024, 65535)
	out.max_players = clampi(int(str(out.max_players)), 1, NetSession.PLAYER_LIMIT)
	out.bots = clampi(int(str(out.bots)), 0, NetSession.PLAYER_LIMIT - 1)
	out.name = Cosmetics.clean_name(str(out.name), 32)
	out.password = str(out.password).left(64)
	var delay := float(str(out.start_delay))
	out.start_delay = clampf(delay, 0.0, 120.0) if is_finite(delay) else DEFAULTS.start_delay
	out.mode = "teams" if str(out.mode) == "teams" else "ffa"
	var maps := PackedStringArray()
	for m in (out.maps if out.maps is Array or out.maps is PackedStringArray else str(out.maps).split(",", false)):
		if Maps.scene_of(str(m).strip_edges()) != "":
			maps.append(str(m).strip_edges())
	out.maps = maps
	return out


## Starts serving. Returns the error if the port couldn't be opened.
static func run(tree: SceneTree, args: PackedStringArray = OS.get_cmdline_user_args()) -> Error:
	var s := settings(args)
	var game_rules := GameRules.teams() if s.mode == "teams" else GameRules.free_for_all()
	if not (s.maps as PackedStringArray).is_empty():
		game_rules.map_pool = s.maps
	var err := NetSession.serve(tree, s.port, game_rules, s.max_players, s.password, s.name)
	if err != OK:
		printerr("[server] couldn't start: ", error_string(err))
		return err
	var ds := DedicatedServer.new()
	ds.name = "DedicatedServer"
	ds.session = NetSession.current
	ds.rules = game_rules
	ds.bots = s.bots
	ds.start_delay = s.start_delay
	ds._wait = s.start_delay
	tree.root.add_child.call_deferred(ds)
	ds.session.game_finished.connect(func() -> void: ds._wait = ds.start_delay)
	print("[server] %s: %s on %s, up to %d players%s%s" % [s.name, game_rules.display_name, ", ".join(game_rules.map_pool),
			s.max_players, ", %d bots" % s.bots if s.bots > 0 else "", ", password protected" if s.password != "" else ""])
	return OK


func _process(delta: float) -> void:
	if session == null or not is_instance_valid(session) or session.role != NetSession.Role.DEDICATED:
		return
	var people := session.roster.keys().filter(func(id: int) -> bool: return id > 0).size()
	var playing := Game.current != null and is_instance_valid(Game.current)
	if playing and people == 0:
		print("[server] everyone left: waiting for players")
		Game.end(get_tree(), false)
		session.remove_bots()
		_wait = start_delay
		return
	if playing or people == 0:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	session.remove_bots()
	if bots > 0:
		session.add_bots(bots)
	if rules.is_teams():
		session.balance_teams()
	var players := session.players()
	print("[server] starting %s with %d players" % [rules.display_name, players.size()])
	Game.start(get_tree(), rules, players)
