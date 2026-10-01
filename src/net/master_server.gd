class_name MasterServer
extends Node
## The list server (docs/NETWORKING.md): where public games on the internet
## are found. Anyone can run one, headless:
##
##   godot --headless --path . -- --list-server [--port 27950]
##
## Public games (ServerAdvert) connect to it and keep the connection open,
## saying how they're doing now and then; the game's browser (ServerBrowser)
## connects, asks for the list, gets it and goes. Everything is a line of
## JSON. A game is listed at the address it connected from and the game
## port it gives, and is dropped when its connection closes or goes quiet.
##
## It holds nothing but the list, and trusts nothing it's told: every field
## is checked (ServerList.clean) and there are limits on everything (games
## and connections, and from one address, line length, how long anyone may
## take, lists a minute). It never waits on anyone: what it sends goes out as
## fast as the other end reads it.

## Seconds a connection may wait before saying anything, a listed game may
## go quiet, and a list may take to go out, before it's dropped.
const FIRST_WORD := 5.0
const QUIET := 60.0
const SENDING := 10.0
const MAX_CONNECTIONS := 256
const CONNECTIONS_PER_ADDRESS := 16
const MAX_GAMES := 500
const MAX_PER_ADDRESS := 4
## Lists anyone may ask for a minute (from one address).
const LISTS_PER_MINUTE := 30

var port := ServerList.LIST_PORT
## Logs games coming and going to standard output (as the list server).
var verbose := false
var _server: TCPServer
## Each connection: {peer, ip, buf, age, quiet, game (its listing, or {})}.
var _conns: Array[Dictionary] = []
var _asked := {}


## Whether this run asked for a list server.
static func requested() -> bool:
	return "--list-server" in OS.get_cmdline_user_args()


## Starts the list server (its port from `--port`). Returns the error if
## the port couldn't be opened.
static func run(tree: SceneTree, args: PackedStringArray = OS.get_cmdline_user_args()) -> Error:
	var ms := MasterServer.new()
	ms.name = "ListServer"
	ms.verbose = true
	var at := args.find("--port")
	if at >= 0 and at + 1 < args.size() and args[at + 1].is_valid_int():
		ms.port = clampi(args[at + 1].to_int(), 1024, 65535)
	var err := ms.start()
	if err != OK:
		printerr("[list] couldn't open port %d: %s" % [ms.port, error_string(err)])
		return err
	tree.root.add_child.call_deferred(ms)
	Engine.max_fps = 30  # It only waits on the network.
	print("[list] listing public games on port %d" % ms.port)
	return OK


func start() -> Error:
	_server = TCPServer.new()
	return _server.listen(port)


## The games listed now, as the browser gets them.
func games() -> Array:
	var out := []
	for c in _conns:
		if not (c.game as Dictionary).is_empty():
			out.append(c.game)
	return out


func _process(delta: float) -> void:
	if _server == null:
		return
	while _server.is_connection_available():
		var peer := _server.take_connection()
		var ip := _plain(peer.get_connected_host())
		if _conns.size() >= MAX_CONNECTIONS or _conns.filter(func(c: Dictionary) -> bool: return c.ip == ip).size() >= CONNECTIONS_PER_ADDRESS:
			peer.disconnect_from_host()
			continue
		_conns.append({"peer": peer, "ip": ip, "buf": PackedByteArray(), "out": PackedByteArray(),
				"age": 0.0, "quiet": 0.0, "game": {}, "spoke": false, "closing": false})
	for c in _conns.duplicate():
		_serve(c, delta)


func _serve(c: Dictionary, delta: float) -> void:
	var peer: StreamPeerTCP = c.peer
	peer.poll()
	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		_drop(c)
		return
	c.age += delta
	c.quiet += delta
	# What it's owed goes out as fast as it reads it, never waiting on it.
	c.out = ServerList.send(peer, c.out)
	if c.closing:
		if (c.out as PackedByteArray).is_empty() or c.quiet > SENDING:
			_drop(c)
		return
	if (not c.spoke and c.age > FIRST_WORD) or c.quiet > QUIET:
		_drop(c)
		return
	var available := peer.get_available_bytes()
	if available <= 0:
		return
	var got := peer.get_partial_data(mini(available, ServerList.MAX_LINE))
	if got[0] != OK:
		return
	var buf: PackedByteArray = c.buf
	buf.append_array(got[1])
	c.buf = buf
	for msg: Variant in ServerList.take_lines(c):
		if not _heard(c, msg):
			_drop(c)
			return
		if c.closing:
			c.quiet = 0.0
			return


## One line from connection `c`. Whether to keep talking to it.
func _heard(c: Dictionary, msg: Variant) -> bool:
	if not msg is Dictionary:
		return false
	var d: Dictionary = msg
	c.spoke = true
	c.quiet = 0.0
	match d.get("op"):
		"list":
			if not (c.game as Dictionary).is_empty() or not _may_list(c.ip):
				return false
			var want: int = ServerList._whole(d.get("protocol"), 0, 100000)
			var list := games().filter(func(g: Dictionary) -> bool: return want == 0 or g.protocol == want)
			_say(c, {"servers": list.slice(0, ServerList.MAX_LIST)})
			c.closing = true  # Hang up once it's gone.
			return true
		"host":
			var game := ServerList.clean(d, c.ip)
			if game.is_empty():
				return false
			game.erase("lan")
			var first := (c.game as Dictionary).is_empty()
			if first:
				if games().size() >= MAX_GAMES:
					_refuse(c, "the list is full")
					return true
				var here := games().filter(func(g: Dictionary) -> bool: return g.address == c.ip)
				if here.size() >= MAX_PER_ADDRESS:
					_refuse(c, "too many games from one address")
					return true
				if here.any(func(g: Dictionary) -> bool: return g.port == game.port):
					_refuse(c, "already listed")
					return true
			elif (c.game as Dictionary).port != game.port:
				return false  # One connection, one game.
			c.game = game
			if first:
				_say(c, {"ok": true, "address": "%s:%d" % [c.ip, game.port]})
				_log("+ %s (%s:%d)" % [game.name, c.ip, game.port])
			return true
	return false


## Tells a game why it won't be listed, then hangs up.
func _refuse(c: Dictionary, reason: String) -> void:
	_say(c, {"ok": false, "reason": reason})
	c.closing = true


func _say(c: Dictionary, d: Dictionary) -> void:
	var out: PackedByteArray = c.out
	out.append_array(ServerList.line(d))
	c.out = ServerList.send(c.peer, out)


func _may_list(ip: String) -> bool:
	var minute := Time.get_ticks_msec() / 60000
	var r: Array = _asked.get(ip, [minute, 0])
	if r[0] != minute:
		r = [minute, 0]
	r[1] += 1
	_asked[ip] = r
	if _asked.size() > 10000:
		_asked.clear()  # Forget old counts rather than grow for ever.
	return r[1] <= LISTS_PER_MINUTE


func _drop(c: Dictionary) -> void:
	if not (c.game as Dictionary).is_empty():
		_log("- %s (%s:%d)" % [c.game.name, c.ip, c.game.port])
	(c.peer as StreamPeerTCP).disconnect_from_host()
	_conns.erase(c)


func _log(text: String) -> void:
	if verbose:
		print("[list] ", text)


## An IPv4 address given as IPv6 (::ffff:1.2.3.4) as plain IPv4.
static func _plain(ip: String) -> String:
	return ip.substr(7) if ip.begins_with("::ffff:") and ip.count(".") == 3 else ip


func _exit_tree() -> void:
	for c in _conns.duplicate():
		_drop(c)
	if _server:
		_server.stop()
