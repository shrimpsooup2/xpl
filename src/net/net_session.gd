class_name NetSession
extends Node
## The network connection (docs/NETWORKING.md): hosting a game from the menu,
## joining one, or running a dedicated server; the handshake every client
## passes before anything else it sends is accepted; and the roster of who's
## connected, which the server keeps and every client mirrors.
##
## It sits under the tree's root (like the Match), so it lives through map
## changes. The server (the host, or a dedicated server) decides everything;
## clients are told.
##
## The handshake uses Godot's authentication step: the server sends a random
## challenge, the client answers with the protocol version, its name and look,
## a token saying who it is (its saved identity, hashed with the server's
## name, so no two servers see the same one), and a hash of the challenge and
## the server's password (the password itself never crosses the wire). The
## server checks all of it, and that there's room, then lets the client in
## and tells everyone the new roster.
##
## Someone who leaves a game in progress and comes back to it (the same
## token) gets their score and side back. Your look can change any time
## (send_look): the server checks it and tells everyone.
##
## A server marked public (advertise) can be found (ServerList): on the
## local network, and on a list server if one's set. The lobby's roster
## comes with the game's options, so everyone sees what the host picked.

signal roster_changed
## A client's join finished: in (ok), or refused or failed (reason).
signal join_finished(ok: bool, reason: String)
## The connection to the server is gone (a client), with why.
signal left(reason: String)
signal log_line(text: String)
## The server's game ended (back to the lobby).
signal game_finished

enum Role { OFFLINE, HOST, CLIENT, DEDICATED }

const DEFAULT_PORT := 27960
const HANDSHAKE_TIMEOUT := 5.0
## Seconds a join may take before giving up (ENet on its own waits far longer).
const JOIN_TIMEOUT := 10.0
const MAX_AUTH_BYTES := 1024
## Most players a server can take (the biggest maps are built for 16).
const PLAYER_LIMIT := 16
## Reliable requests a client may send per second before it's cut off, and
## how many times it can go over before it's kicked.
const REQUESTS_PER_SECOND := 10
const STRIKES_TO_KICK := 20
## How long a score waits for someone who left a game to come back.
const KEEP_DEPARTED_MS := 600000

## The session in progress, or null (offline).
static var current: NetSession
## Why the last client session ended, when it wasn't by choice (the menu
## shows it once: take_reason).
static var last_reason := ""
## The last server joined, to rejoin it (the menu offers to): {address, port,
## password}, kept while the program runs (never saved).
static var last_join := {}

var role := Role.OFFLINE
var peer: ENetMultiplayerPeer
var server_name := "xtrapartial"
var max_players := 8
## The port a server listens on.
var port := 0
var rules: GameRules
## The style and options the host has picked, as clients see them in the
## lobby (null until the server says).
var lobby_style := ""
var lobby_rules: GameRules
## Whether the server can be found (advertise), what it's listed as, and
## the thing doing it.
var public := false
var listing_id := ""
var advert: ServerAdvert
## Where a client joined, and whether it's a dedicated server.
var address := ""
var dedicated := false
## Peer id → PlayerInfo, everyone in the game (bots included, with negative
## ids). The server's is the truth; clients rebuild theirs from it.
var roster := {}
## The address and port players can reach a host at, when UPnP found them.
var public_address := ""

var _password := ""
var _challenges := {}
## Server: peer id → its token; token → the score and side of someone who
## left the game in progress ({team, kills, deaths, heartshots, round_wins, at}).
var _tokens := {}
var _departed := {}
var _requests := {}
var _strikes := {}
var _upnp: UPNP
var _upnp_port := 0
var _upnp_thread: Thread
var _tree: SceneTree
var _join_wait := JOIN_TIMEOUT
var _joined := false


# --- Starting and stopping ------------------------------------------------------------

## Hosts a game from this machine (a listen server): you're player 1 and
## the server. With `upnp`, asks the router to forward the port (in the
## background; public_address is filled in if it works).
static func host(tree: SceneTree, port: int, game_rules: GameRules, players := 8, password := "", upnp := false,
		name := "") -> Error:
	var s := _make(tree, Role.HOST)
	if name.strip_edges() != "":
		s.server_name = Cosmetics.clean_name(name, 32)
	var err := s._listen(port, players, password)
	if err != OK:
		s.close()
		return err
	s.rules = game_rules
	var me := PlayerInfo.local_human()
	me.id = 1
	s.roster[1] = me
	if upnp:
		s._open_port(port)
	s._log("hosting on port %d" % port)
	return OK


## Runs a dedicated server (no player at the keyboard).
static func serve(tree: SceneTree, port: int, game_rules: GameRules, players := 8, password := "", name := "xtrapartial") -> Error:
	var s := _make(tree, Role.DEDICATED)
	s.server_name = Cosmetics.clean_name(name, 32)
	var err := s._listen(port, players, password)
	if err != OK:
		s.close()
		return err
	s.rules = game_rules
	s._log("serving \"%s\" on port %d, up to %d players" % [name, port, players])
	return OK


## Joins the game at `address`:`port`. join_finished says how it went.
static func join(tree: SceneTree, address: String, port: int, password := "") -> Error:
	var s := _make(tree, Role.CLIENT)
	s._password = password
	last_join = {"address": address, "port": port, "password": password}
	s.address = "%s:%d" % [address, port] if not ":" in address else "[%s]:%d" % [address, port]
	s.peer = ENetMultiplayerPeer.new()
	var err := s.peer.create_client(address, port)
	if err != OK:
		s.close()
		return err
	s._setup_multiplayer()
	s._log("joining %s:%d" % [address, port])
	return OK


## Leaves: closes the connection, releases the port, ends any game.
static func leave(tree: SceneTree, reason := "") -> void:
	if current and is_instance_valid(current):
		current.close(reason)
	current = null
	Game.end(tree, false)


static func _make(tree: SceneTree, as_role: Role) -> NetSession:
	leave(tree)
	var s := NetSession.new()
	s.name = "Net"
	s.role = as_role
	s._tree = tree
	tree.root.add_child.call_deferred(s)  # Before any message is read.
	current = s
	return s


func close(reason := "") -> void:
	if peer:
		peer.close()
	peer = null
	_mp().multiplayer_peer = OfflineMultiplayerPeer.new()
	_close_port()
	roster.clear()
	if role == Role.CLIENT and reason != "":
		last_reason = reason
		left.emit(reason)
	role = Role.OFFLINE
	if current == self:
		current = null
	# Out of the way now, not at the end of the frame: a new session made
	# before then must get the name messages are addressed to.
	name = "ClosedNet"
	queue_free()


func _listen(at_port: int, players: int, password: String) -> Error:
	max_players = clampi(players, 1, PLAYER_LIMIT)
	_password = password
	port = at_port
	listing_id = Crypto.new().generate_random_bytes(8).hex_encode()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(at_port, max_players)
	if err != OK:
		_log("couldn't open port %d (%s)" % [at_port, error_string(err)])
		return err
	_setup_multiplayer()
	return OK


## Makes the server public (it can be found: on the local network, and on
## `list_server` if one's given) or not. A public game can still have a
## password; it's shown locked.
func advertise(on: bool, list_server := "") -> void:
	if not is_server():
		return
	public = on
	if advert and is_instance_valid(advert):
		advert.queue_free()
		advert.name = "OldAdvert"
		advert = null
	if on:
		advert = ServerAdvert.new()
		advert.name = "Advert"
		advert.session = self
		advert.list_server = list_server.strip_edges()
		add_child(advert)
		_log("public: it can be found on this network%s" % (" and on %s" % list_server if list_server.strip_edges() != "" else ""))


## Whether it takes a password.
func locked() -> bool:
	return _password != ""


func _setup_multiplayer() -> void:
	var mp := _mp()
	mp.server_relay = false  # Clients can't message each other through the server.
	mp.allow_object_decoding = false  # The default; said out loud.
	mp.auth_timeout = HANDSHAKE_TIMEOUT
	mp.auth_callback = _on_auth
	if not mp.peer_authenticating.is_connected(_on_authenticating):
		mp.peer_authenticating.connect(_on_authenticating)
		mp.peer_authentication_failed.connect(_on_auth_failed)
		mp.peer_connected.connect(_on_peer_connected)
		mp.peer_disconnected.connect(_on_peer_disconnected)
		mp.connection_failed.connect(func() -> void: _fail("couldn't reach the server"))
		mp.server_disconnected.connect(func() -> void: _fail("the server went away"))
	mp.multiplayer_peer = peer


func is_server() -> bool:
	return role == Role.HOST or role == Role.DEDICATED


static func active() -> bool:
	return current != null and is_instance_valid(current) and current.role != Role.OFFLINE


## Whether this machine decides the game: offline, or the server.
static func authority() -> bool:
	return not active() or current.is_server()


func local_id() -> int:
	return _mp().get_unique_id() if peer else 1


func _mp() -> SceneMultiplayer:
	return (get_tree() if is_inside_tree() else _tree).get_multiplayer() as SceneMultiplayer


# --- The handshake ----------------------------------------------------------------------

## A client knocks: the server sends it a challenge. (On a client this is
## the server, which starts by waiting for that challenge.)
func _on_authenticating(id: int) -> void:
	if not is_server():
		return
	if roster.size() >= max_players + _bots():
		_refuse(id, "the server is full")
		return
	var nonce := Crypto.new().generate_random_bytes(16).hex_encode()
	_challenges[id] = nonce
	_mp().send_auth(id, var_to_bytes({"challenge": nonce, "server": server_name, "dedicated": role == Role.DEDICATED}))


## Handshake messages, both ways. Anything malformed ends the handshake.
func _on_auth(id: int, data: PackedByteArray) -> void:
	var mp := _mp()
	if data.size() > MAX_AUTH_BYTES:
		mp.disconnect_peer(id)
		return
	var msg: Variant = bytes_to_var(data)
	if not (msg is Dictionary):
		mp.disconnect_peer(id)
		return
	var d: Dictionary = msg
	if is_server():
		_check_hello(id, d)
		return
	# Client side: the challenge, then the verdict.
	if d.get("challenge") is String and (d.challenge as String).length() == 32:
		Cosmetics.load_saved()
		if d.get("server") is String:
			server_name = Cosmetics.clean_name(d.server, 32)
		dedicated = is_same(d.get("dedicated"), true)
		mp.send_auth(1, var_to_bytes({
			"protocol": NetCodec.PROTOCOL, "name": Cosmetics.player_name, "hat": String(Cosmetics.hat),
			"color": String(Cosmetics.color), "token": token(Cosmetics.identity, server_name),
			"proof": proof(d.challenge, _password)}))
	elif is_same(d.get("ok"), true):
		mp.complete_auth(1)
	else:
		_fail(str(d.get("reason", "refused")).left(80) if d.get("reason") is String else "refused")


func _check_hello(id: int, d: Dictionary) -> void:
	if not _challenges.has(id):
		_refuse(id, "unexpected")
		return
	if not is_same(d.get("protocol"), NetCodec.PROTOCOL):
		_refuse(id, "a different version of the game (%s, the server has %d)" % [str(d.get("protocol")).left(8), NetCodec.PROTOCOL])
		return
	if not (d.get("proof") is String) or d.proof != proof(_challenges[id], _password):
		_refuse(id, "wrong password")
		return
	var info := PlayerInfo.from_dict({"id": id, "name": d.get("name", ""), "hat": d.get("hat", ""), "color": d.get("color", "")})
	info.id = id
	info.team = _smaller_team()
	info.player_name = _unique_name(info.player_name)
	var back := false
	var t: Variant = d.get("token")
	if t is String and (t as String).length() == 64 and (t as String).is_valid_hex_number():
		_tokens[id] = t
		back = _restore(info, t)
	roster[id] = info
	_challenges.erase(id)
	_mp().send_auth(id, var_to_bytes({"ok": true}))
	_mp().complete_auth(id)
	if back:
		_log("%s is back (#%d, %d kills, %d deaths)" % [info.player_name, id, info.kills, info.deaths])
	else:
		_log("%s joined (#%d)" % [info.player_name, id])


## The proof a client knows the password: sha256 of challenge and password.
static func proof(challenge: String, password: String) -> String:
	return (challenge + ":" + password).sha256_text()


## Who a client is to the server named `server`: its identity hashed with
## the name, so a server can't pass it off as you anywhere else.
static func token(identity: String, server: String) -> String:
	return (identity + ":" + server).sha256_text()


## Someone who left the game in progress is back (`t`, their token): their
## score and side, as they left them. Whether they were.
func _restore(info: PlayerInfo, t: String) -> bool:
	var was: Dictionary = _departed.get(t, {})
	_departed.erase(t)
	if was.is_empty() or Time.get_ticks_msec() - int(was.at) > KEEP_DEPARTED_MS:
		return false
	info.team = was.team
	for key: String in ["kills", "deaths", "heartshots", "round_wins"]:
		info.set(key, was[key])
	return true


func _refuse(id: int, reason: String) -> void:
	_log("refused #%d: %s" % [id, reason])
	var mp := _mp()
	mp.send_auth(id, var_to_bytes({"ok": false, "reason": reason}))
	_challenges.erase(id)
	# Give the refusal a moment to arrive before hanging up.
	get_tree().create_timer(0.3).timeout.connect(func() -> void:
		if peer:
			mp.disconnect_peer(id))


func _on_auth_failed(id: int) -> void:
	_challenges.erase(id)
	if not is_server():
		_fail("the handshake failed")


func _fail(reason: String) -> void:
	_log(reason)
	if role != Role.CLIENT:
		return
	if not _joined:
		join_finished.emit(false, reason)
	var in_game := Game.current != null
	close(reason)
	if in_game:
		Game.end(_tree)  # Back to the menu, which says why.


## The menu: why the last session ended, once ("" if it was by choice).
static func take_reason() -> String:
	var r := last_reason
	last_reason = ""
	return r


func _process(delta: float) -> void:
	if role == Role.CLIENT and not _joined:
		_join_wait -= delta
		if _join_wait <= 0.0:
			_fail("no answer from the server")


func _on_peer_connected(id: int) -> void:
	if is_server():
		send_roster()
		Game.on_peer_joined(id)
	elif id == 1:
		_joined = true
		join_finished.emit(true, "")


func _on_peer_disconnected(id: int) -> void:
	if not is_server():
		return
	_challenges.erase(id)
	_requests.erase(id)
	_strikes.erase(id)
	var t: String = _tokens.get(id, "")
	_tokens.erase(id)
	if roster.has(id):
		var info: PlayerInfo = roster[id]
		if t != "" and Game.current and is_instance_valid(Game.current):
			# Kept for a while, in case they come back to this game.
			_departed[t] = {"team": info.team, "kills": info.kills, "deaths": info.deaths, "heartshots": info.heartshots,
					"round_wins": info.round_wins, "at": Time.get_ticks_msec()}
		_log("%s left" % roster[id].player_name)
		roster.erase(id)
		Game.on_peer_left(id)
		send_roster()


# --- The roster -------------------------------------------------------------------------

func send_roster() -> void:
	if not is_server():
		return
	var data := []
	for info: PlayerInfo in roster.values():
		data.append(info.to_dict())
	lobby_style = rules.display_name if rules else ""
	lobby_rules = rules
	_roster.rpc(data, rules.to_dict() if rules else {})
	roster_changed.emit()


## The server's roster (a client), and the game's options. Players already
## known are updated in place (the game in progress holds on to them);
## newcomers are added and the gone removed, in the game too.
@rpc("authority", "call_remote", "reliable")
func _roster(data: Array, options: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != 1 or data.size() > PLAYER_LIMIT * 2 or options.size() > 64:
		return
	lobby_rules = GameRules.from_dict(options) if not options.is_empty() else null
	lobby_style = ("teams" if lobby_rules.is_teams() else "free-for-all") if lobby_rules else ""
	var mine := local_id()
	var seen := {}
	for d: Variant in data:
		if not d is Dictionary:
			continue
		var fresh := PlayerInfo.from_dict(d)
		if fresh.id == 0:
			continue
		seen[fresh.id] = true
		var info: PlayerInfo = roster.get(fresh.id)
		if info == null:
			info = fresh
			roster[fresh.id] = info
			if Game.current and not Game.current.authority:
				Game.current.add_body_for(info)
		else:
			var look := [info.player_name, info.team, info.color, info.hat]
			for key in ["player_name", "team", "color", "hat", "bot", "kills", "deaths", "heartshots", "round_wins"]:
				info.set(key, fresh.get(key))
			if look != [info.player_name, info.team, info.color, info.hat] and Game.current and is_instance_valid(Game.current):
				Game.current.restyle(info)
		info.local = info.id == mine
	for id: int in roster.keys():
		if not seen.has(id):
			roster.erase(id)
			if Game.current:
				Game.current.remove_player(id)
	roster_changed.emit()


# --- Games ---------------------------------------------------------------------------------

## The server: tells every client (or just `only`) a game of `game_rules` has
## started, so they follow it.
func announce_game(game_rules: GameRules, only := 0) -> void:
	if not is_server():
		return
	rules = game_rules
	if only != 0:
		_game_started.rpc_id(only, game_rules.to_dict())
	else:
		_departed.clear()  # A new game: nobody's score to come back to.
		_game_started.rpc(game_rules.to_dict())


@rpc("authority", "call_remote", "reliable")
func _game_started(d: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != 1 or role != Role.CLIENT:
		return
	rules = GameRules.from_dict(d)
	Game.follow(get_tree(), rules, players())


## The game's over (the server): everyone goes back to the lobby. A
## dedicated server starts the next one itself (DedicatedServer).
func game_over() -> void:
	if not is_server():
		return
	_departed.clear()
	_game_ended.rpc()
	Game.end(get_tree(), role == Role.HOST)
	game_finished.emit()


@rpc("authority", "call_remote", "reliable")
func _game_ended() -> void:
	if multiplayer.get_remote_sender_id() == 1 and role == Role.CLIENT:
		Game.end(get_tree(), true)


## Everyone in the game, in id order (bots after people).
func players() -> Array[PlayerInfo]:
	var out: Array[PlayerInfo] = []
	var ids := roster.keys()
	ids.sort_custom(func(a: int, b: int) -> bool: return (a > 0 and b < 0) or (signi(a) == signi(b) and absi(a) < absi(b)))
	for id: int in ids:
		out.append(roster[id])
	return out


## Sets the number of bots (the server): adds or drops the last ones.
func set_bots(count: int) -> void:
	var have := _bots()
	if count > have:
		add_bots(count - have)
		return
	for n in range(have, count, -1):
		roster.erase(-n)
	send_roster()


func bot_count() -> int:
	return _bots()


## Evens the teams out, people first, then bots (the server), and tells everyone.
func balance_teams() -> void:
	var everyone := players()
	for i in everyone.size():
		everyone[i].team = Hats.Team.RED if i % 2 == 0 else Hats.Team.BLUE
	send_roster()


## Splits "host", "host:port", "[ipv6]:port" (or a bare IPv6 address) into
## [host, port]; [] when it isn't an address.
static func parse_address(text: String) -> Array:
	var t := text.strip_edges()
	var host := t
	var port := DEFAULT_PORT
	if t.begins_with("["):
		var close_at := t.find("]")
		if close_at < 0:
			return []
		host = t.substr(1, close_at - 1)
		var rest := t.substr(close_at + 1)
		if rest != "":
			if not rest.begins_with(":") or not rest.substr(1).is_valid_int():
				return []
			port = rest.substr(1).to_int()
	elif t.count(":") == 1:
		host = t.get_slice(":", 0)
		var p := t.get_slice(":", 1)
		if not p.is_valid_int():
			return []
		port = p.to_int()
	if host == "" or port < 1 or port > 65535 or host.length() > 253 or " " in host:
		return []
	return [host, port]


## This machine's address on the local network (for friends on the same
## Wi-Fi), or "".
static func lan_address() -> String:
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or (a.begins_with("172.") and a.get_slice(".", 1).to_int() in range(16, 32)):
			return a
	return ""


## Adds `count` bots to the roster (the server), on the smaller team.
func add_bots(count: int) -> void:
	for i in count:
		var n := _bots() + 1
		var bot := PlayerInfo.make_bot(n)
		bot.team = _smaller_team()
		roster[bot.id] = bot
	send_roster()


func remove_bots() -> void:
	for id: int in roster.keys():
		if id < 0:
			roster.erase(id)
	send_roster()


func _bots() -> int:
	return roster.keys().filter(func(id: int) -> bool: return id < 0).size()


func _smaller_team() -> Hats.Team:
	var red := roster.values().filter(func(i: PlayerInfo) -> bool: return i.team == Hats.Team.RED).size()
	var blue := roster.size() - red
	return Hats.Team.BLUE if blue < red else Hats.Team.RED


## `want`, or with a number after it if someone else (not `self_id`) has it.
func _unique_name(want: String, self_id := 0) -> String:
	var taken := roster.values().filter(func(i: PlayerInfo) -> bool: return i.id != self_id).map(
			func(i: PlayerInfo) -> String: return i.player_name)
	if not want in taken:
		return want
	for n in range(2, 100):
		var candidate := "%s %d" % [want.left(Cosmetics.NAME_LENGTH - 3), n]
		if not candidate in taken:
			return candidate
	return want


# --- Your look ------------------------------------------------------------------------------

## Your name, hat or colour changed (Cosmetics): the server hears it and
## tells everyone. Hosting, you're the server.
func send_look() -> void:
	if is_server():
		var me: PlayerInfo = roster.get(1)
		if me:
			_apply_look(me, Cosmetics.player_name, Cosmetics.hat, Cosmetics.color)
			send_roster()
	elif role == Role.CLIENT and _joined:
		_set_look.rpc_id(1, Cosmetics.player_name, String(Cosmetics.hat), String(Cosmetics.color))


## A client's new look (the server): checked like the one it joined with,
## then everyone's told.
@rpc("any_peer", "call_remote", "reliable")
func _set_look(new_name: String, hat: String, color: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_server() or not roster.has(id) or not allow_request(id):
		return
	if new_name.length() > 64 or hat.length() > 32 or color.length() > 32:
		strike(id, "a bad look")
		return
	var fresh := PlayerInfo.from_dict({"name": new_name, "hat": hat, "color": color})
	_apply_look(roster[id], fresh.player_name, fresh.hat, fresh.color)
	send_roster()


func _apply_look(info: PlayerInfo, new_name: String, hat: StringName, color: StringName) -> void:
	if new_name != info.player_name:
		var was := info.player_name
		info.player_name = _unique_name(new_name, info.id)
		_log("%s is now %s" % [was, info.player_name])
	info.hat = hat
	info.color = color
	if Game.current and is_instance_valid(Game.current):
		Game.current.restyle(info)


# --- Limits -------------------------------------------------------------------------------

## Whether peer `id` may make another reliable request now (at most
## REQUESTS_PER_SECOND); a peer that keeps going over is kicked.
func allow_request(id: int) -> bool:
	var now := Time.get_ticks_msec()
	var r: Array = _requests.get(id, [now, 0])
	if now - r[0] >= 1000:
		r = [now, 0]
	r[1] += 1
	_requests[id] = r
	if r[1] <= REQUESTS_PER_SECOND:
		return true
	strike(id, "too many requests")
	return false


## Counts something bad `id` sent; enough of them and it's kicked.
func strike(id: int, why: String) -> void:
	_strikes[id] = int(_strikes.get(id, 0)) + 1
	if _strikes[id] == STRIKES_TO_KICK and peer:
		_log("kicking #%d (%s)" % [id, why])
		_mp().disconnect_peer(id)
		_on_peer_disconnected(id)  # Hanging up on a peer doesn't say it left.


# --- UPnP -----------------------------------------------------------------------------------

func _open_port(port: int) -> void:
	_upnp_port = port
	_upnp_thread = Thread.new()
	_upnp_thread.start(func() -> void:
		var u := UPNP.new()
		if u.discover(2000, 2, "InternetGatewayDevice") != UPNP.UPNP_RESULT_SUCCESS or u.get_gateway() == null or not u.get_gateway().is_valid_gateway():
			_upnp_done.call_deferred(null, "")
			return
		if u.add_port_mapping(port, port, "xtrapartial", "UDP", 0) != UPNP.UPNP_RESULT_SUCCESS:
			_upnp_done.call_deferred(null, "")
			return
		_upnp_done.call_deferred(u, u.query_external_address()))


func _upnp_done(u: UPNP, address: String) -> void:
	if _upnp_thread:
		_upnp_thread.wait_to_finish()
		_upnp_thread = null
	_upnp = u
	if u and address != "":
		public_address = "%s:%d" % [address, _upnp_port]
		_log("the router forwarded the port: players can join at %s" % public_address)
	else:
		_log("UPnP didn't work: forward UDP port %d on the router to play over the internet" % _upnp_port)


func _close_port() -> void:
	if _upnp_thread:
		_upnp_thread.wait_to_finish()
		_upnp_thread = null
	if _upnp:
		_upnp.delete_port_mapping(_upnp_port, "UDP")
		_upnp = null


func _log(text: String) -> void:
	log_line.emit(text)
	if role == Role.DEDICATED or OS.get_environment("XPL_NET_LOG") != "":
		print("[net] ", text)


func _exit_tree() -> void:
	_close_port()
