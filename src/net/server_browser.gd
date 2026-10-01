class_name ServerBrowser
extends Node
## Looking for public games (ServerList), for the online page's *find a
## game*: a query broadcast on the local network (and to this machine), and
## the list server's list if one's set. What comes back is checked
## (ServerList.clean) and gathered in `found`, each game once: one found on
## the local network wins over the list server's copy (its address works
## from here).

signal updated
## Done looking: `list_error` says why the list server couldn't be asked
## ("" if it was, or none's set).
signal finished

## Seconds to wait for local answers, and for the list server.
const LAN_WAIT := 1.0
const LIST_WAIT := 6.0

var found: Array[Dictionary] = []
var searching := false
var list_error := ""

var _udp: PacketPeerUDP
var _lan_left := 0.0
var _list_server := ""
var _target := []
var _resolving := -1
var _tcp: StreamPeerTCP
var _conn := {"buf": PackedByteArray()}
var _list_left := 0.0
var _asked := false
var _list_done := true


## Starts looking again (forgetting what was found), on the local network
## and at `list_server` ("" for none).
func refresh(list_server := "") -> void:
	_stop()
	found.clear()
	list_error = ""
	searching = true
	_list_server = list_server.strip_edges()
	_udp = PacketPeerUDP.new()
	_udp.set_broadcast_enabled(true)
	if _udp.bind(0) == OK:
		var query: PackedByteArray = ServerList.QUERY.to_ascii_buffer()
		query.resize(ServerList.PACKET)  # Padded: see ServerList.PACKET.
		for to in _local_targets():
			for i in ServerList.DISCOVERY_PORTS:
				_udp.set_dest_address(to, ServerList.DISCOVERY_PORT + i)
				_udp.put_packet(query)
	_lan_left = LAN_WAIT
	_list_done = _list_server == ""
	if not _list_done:
		_target = ServerList.list_address(_list_server)
		if _target.is_empty():
			list_error = "\"%s\" isn't a list server address" % _list_server.left(40)
			_list_done = true
		else:
			_resolving = IP.resolve_hostname_queue_item(_target[0])
			_list_left = LIST_WAIT
			_asked = false
	updated.emit()


## Where the query goes: everyone on the network, each local network's
## broadcast address (taken as a /24), and this machine.
static func _local_targets() -> PackedStringArray:
	var out := PackedStringArray(["255.255.255.255", "127.0.0.1"])
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and ServerList.is_local(a) and not a.begins_with("127."):
			var nets := a.split(".")
			var bcast := "%s.%s.%s.255" % [nets[0], nets[1], nets[2]]
			if not bcast in out:
				out.append(bcast)
	return out


func _process(delta: float) -> void:
	if not searching:
		return
	_read_local()
	_lan_left -= delta
	if not _list_done:
		_ask_list(delta)
	if _lan_left <= 0.0 and _list_done:
		_stop()
		searching = false
		updated.emit()
		finished.emit()


func _read_local() -> void:
	if _udp == null:
		return
	var changed := false
	while _udp.get_available_packet_count() > 0:
		var packet := _udp.get_packet()
		var ip := _udp.get_packet_ip()
		if packet.size() > ServerList.PACKET or packet.slice(0, 4).get_string_from_ascii() != ServerList.REPLY:
			continue
		var game := ServerList.clean(ServerList.parse(packet.slice(4).get_string_from_utf8()), ip, true)
		if not game.is_empty() and _add(game):
			changed = true
	if changed:
		updated.emit()


func _ask_list(delta: float) -> void:
	_list_left -= delta
	if _list_left <= 0.0:
		_list_failed("the list server %s didn't answer" % _list_server)
		return
	if _tcp == null:
		var status := IP.get_resolve_item_status(_resolving)
		if status == IP.RESOLVER_STATUS_WAITING:
			return
		var ip := IP.get_resolve_item_address(_resolving) if status == IP.RESOLVER_STATUS_DONE else ""
		IP.erase_resolve_item(_resolving)
		_resolving = -1
		_tcp = StreamPeerTCP.new()
		if ip == "" or _tcp.connect_to_host(ip, _target[1]) != OK:
			_list_failed("couldn't find the list server %s" % _list_server)
		return
	_tcp.poll()
	var status := _tcp.get_status()
	if status == StreamPeerTCP.STATUS_CONNECTING:
		return
	if status != StreamPeerTCP.STATUS_CONNECTED:
		_list_failed("couldn't reach the list server %s" % _list_server)
		return
	if not _asked:
		_asked = true
		if not ServerList.send(_tcp, ServerList.line({"op": "list", "protocol": NetCodec.PROTOCOL})).is_empty():
			_list_failed("the list server %s isn't listening" % _list_server)
			return
	var available := _tcp.get_available_bytes()
	if available <= 0:
		return
	var got := _tcp.get_partial_data(mini(available, ServerList.MAX_LINE * 64))
	if got[0] != OK:
		return
	var buf: PackedByteArray = _conn.buf
	buf.append_array(got[1])
	_conn.buf = buf
	# One line with the whole list (it may be long: allow for it).
	var at := buf.find(10)
	if at < 0:
		if buf.size() > ServerList.MAX_LINE * 64:
			_list_failed("the list server said too much")
		return
	var reply: Variant = ServerList.parse(buf.slice(0, at).get_string_from_utf8())
	var games: Variant = reply.get("servers") if reply is Dictionary else null
	if not games is Array:
		_list_failed("the list server said something odd")
		return
	for g: Variant in (games as Array).slice(0, ServerList.MAX_LIST):
		if g is Dictionary and (g as Dictionary).get("address") is String:
			var game := ServerList.clean(g, (g as Dictionary).address)
			if not game.is_empty():
				_add(game)
	_list_done = true
	_close_list()
	updated.emit()


func _list_failed(why: String) -> void:
	list_error = why
	_list_done = true
	_close_list()


## Adds `game`, or updates it (a local answer wins over the list server's).
## Whether anything changed.
func _add(game: Dictionary) -> bool:
	for i in found.size():
		if found[i].id == game.id:
			if found[i].lan and not game.lan:
				return false
			found[i] = game
			return true
	if found.size() >= ServerList.MAX_LIST:
		return false
	found.append(game)
	return true


## What's been found that matches `search` (ServerList.matches): games you
## can join first (not full, the same version), then by who's playing.
func matching(search: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g in found:
		if ServerList.matches(g, search):
			out.append(g)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_shut: bool = a.players >= a.max or a.protocol != NetCodec.PROTOCOL
		var b_shut: bool = b.players >= b.max or b.protocol != NetCodec.PROTOCOL
		if a_shut != b_shut:
			return b_shut
		if a.players != b.players:
			return a.players > b.players
		return (a.name as String).naturalnocasecmp_to(b.name) < 0)
	return out


func _close_list() -> void:
	if _tcp:
		_tcp.disconnect_from_host()
	_tcp = null
	if _resolving >= 0:
		IP.erase_resolve_item(_resolving)
		_resolving = -1
	_conn.buf = PackedByteArray()


func _stop() -> void:
	_close_list()
	if _udp:
		_udp.close()
	_udp = null


func _exit_tree() -> void:
	_stop()
