class_name ServerList
extends RefCounted
## Finding public games (docs/NETWORKING.md): what a public game says about
## itself, and the checks anything said about a game goes through before
## it's shown. A game is only ever found if its host marked it public (a
## public game can still have a password: it's shown locked).
##
## Two ways to find one:
## - On the local network: the browser broadcasts a query on the discovery
##   ports, and every public game on the network answers (ServerAdvert).
## - Over the internet: a list server (MasterServer: anyone can run one).
##   Public games keep a connection to it open and say how they're doing;
##   the browser asks it for the list (ServerBrowser).

## Public games on one machine answer on the first free of these.
const DISCOVERY_PORT := 27940
const DISCOVERY_PORTS := 4
## The list server's port, unless its address says otherwise.
const LIST_PORT := 27950
## A local query is padded to this size and no answer is bigger, so nobody
## can use a game to flood someone else with more than they sent.
const PACKET := 512
const QUERY := "XPLQ"
const REPLY := "XPLR"
## The longest line the list server and its clients read, and the most
## games a list holds.
const MAX_LINE := 4096
const MAX_LIST := 200
const STYLES := ["free-for-all", "teams"]


## What public game `s` says about itself.
static func describe(s: NetSession) -> Dictionary:
	var people := s.roster.keys().filter(func(id: int) -> bool: return id > 0).size()
	var playing := Game.current != null and is_instance_valid(Game.current)
	return {
		"id": s.listing_id, "name": s.server_name, "style": s.rules.display_name if s.rules else "",
		"map": Game.current.map_name if playing else "", "players": people, "bots": s.bot_count(),
		"max": s.max_players, "locked": s.locked(), "protocol": NetCodec.PROTOCOL, "port": s.port,
	}


## A game as told by someone else (the game itself, or a list server), at
## `address`, checked and cleaned; {} if it doesn't hold up.
static func clean(d: Variant, address: String, lan := false) -> Dictionary:
	if not d is Dictionary or (d as Dictionary).size() > 32 or not address.is_valid_ip_address():
		return {}
	var g: Dictionary = d
	var raw: Variant = g.get("port")
	if not (raw is float or raw is int) or not is_finite(float(raw)) or raw < 1 or raw > 65535:
		return {}
	var port := int(raw)
	var id: String = g.id if g.get("id") is String and (g.id as String).length() <= 64 and (g.id as String) != "" \
			else "%s:%d" % [address, port]
	var style: String = g.style if g.get("style") in STYLES else ""
	var map: String = g.map if g.get("map") is String and Maps.scene_of(g.map) != "" else ""
	return {
		"id": id, "name": Cosmetics.clean_name(g.get("name", ""), 32), "style": style, "map": map,
		"players": _whole(g.get("players"), 0, NetSession.PLAYER_LIMIT), "bots": _whole(g.get("bots"), 0, 32),
		"max": _whole(g.get("max"), 1, NetSession.PLAYER_LIMIT), "locked": is_same(g.get("locked"), true),
		"protocol": _whole(g.get("protocol"), 0, 100000), "address": address, "port": port, "lan": lan,
	}


## A whole number from JSON (which only has floats) in [low, high], or low.
static func _whole(v: Variant, low: int, high: int) -> int:
	if (v is float and is_finite(v)) or v is int:
		return clampi(int(v), low, high)
	return low


## Whether `game` matches what was typed in the search box: every word
## somewhere in its name, style or map.
static func matches(game: Dictionary, search: String) -> bool:
	var hay := ("%s %s %s" % [game.name, game.style, game.map]).to_lower()
	for word in search.to_lower().split(" ", false):
		if not word in hay:
			return false
	return true


## Whether `ip` is on a local network (or this machine): only those get
## answers to local queries.
static func is_local(ip: String) -> bool:
	if ip.begins_with("::ffff:"):
		ip = ip.substr(7)
	if ip.begins_with("127.") or ip.begins_with("10.") or ip.begins_with("192.168.") or ip.begins_with("169.254."):
		return true
	if ip.begins_with("172."):
		var second := ip.get_slice(".", 1).to_int()
		return second >= 16 and second <= 31
	var low := ip.to_lower()
	return low == "::1" or low.begins_with("fe80:") or low.begins_with("fc") or low.begins_with("fd")


## Splits a list server's "host" or "host:port" into [host, port] (its
## own port if none's given), or [].
static func list_address(text: String) -> Array:
	var t := text.strip_edges()
	var where := NetSession.parse_address(t) if t != "" else []
	if where.is_empty():
		return []
	var has_port := t.contains("]:") if t.begins_with("[") else t.count(":") == 1
	if not has_port:
		where[1] = LIST_PORT
	return where


## One line of JSON, for the list server's connections.
static func line(d: Dictionary) -> PackedByteArray:
	return (JSON.stringify(d) + "\n").to_utf8_buffer()


## Sends what it can of `data` to `peer` without waiting (a blocking send
## would freeze everything if the other end stopped reading). What's left.
static func send(peer: StreamPeerTCP, data: PackedByteArray) -> PackedByteArray:
	if data.is_empty():
		return data
	var r := peer.put_partial_data(data)
	return data.slice(int(r[1])) if r[0] == OK else data


## Takes each complete line out of `conn.buf` (the bytes read so far from a
## connection), parsed: a value, or null for a line that isn't JSON. The
## rest stays in the buffer. A line longer than MAX_LINE gives [false]
## instead (drop whoever sent it).
static func take_lines(conn: Dictionary) -> Array:
	var buf: PackedByteArray = conn.buf
	var out := []
	while true:
		var at := buf.find(10)  # A newline.
		if (at < 0 and buf.size() > MAX_LINE) or at > MAX_LINE:
			conn.buf = PackedByteArray()
			return [false]
		if at < 0:
			break
		out.append(parse(buf.slice(0, at).get_string_from_utf8()))
		buf = buf.slice(at + 1)
	conn.buf = buf
	return out


## JSON text as a value, or null (quietly: junk is expected).
static func parse(text: String) -> Variant:
	var json := JSON.new()
	return json.data if text.strip_edges() != "" and json.parse(text) == OK else null
