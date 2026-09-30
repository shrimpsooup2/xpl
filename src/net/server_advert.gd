class_name ServerAdvert
extends Node
## A public game letting itself be found (ServerList), under its NetSession
## while it's public: it answers queries from the local network on the
## first free discovery port, and, if a list server is set, keeps itself
## listed there over a connection it holds open, saying how it's doing
## (who's in, the map) when that changes and every so often anyway. If the
## list server goes away it tries again now and then.
##
## Only queries from local addresses are answered, at most so many a
## second, never with more than was sent.

## Seconds between telling the list server how the game's doing when
## nothing's changed, the least between two updates, and how long to wait
## before trying a list server again.
const KEEP_ALIVE := 15.0
const MIN_GAP := 2.0
const RETRY := 20.0
const CONNECT_WAIT := 8.0
const REPLIES_PER_SECOND := 20

var session: NetSession
## The list server ("host" or "host:port"), or "" for the local network only.
var list_server := ""
## Where the list server says players will find this game, once it's said.
var listed_as := ""
## The discovery port it answers on (0: none free).
var discovery_port := 0

var _udp: PacketPeerUDP
var _tcp: StreamPeerTCP
var _conn := {"buf": PackedByteArray()}
var _resolving := -1
var _target := []
var _connecting := 0.0
var _wait := 0.0
var _since := 0.0
var _said := {}
var _refused := false
var _replies := [0, 0]


func _ready() -> void:
	for i in ServerList.DISCOVERY_PORTS:
		var udp := PacketPeerUDP.new()
		if udp.bind(ServerList.DISCOVERY_PORT + i) == OK:
			_udp = udp
			discovery_port = ServerList.DISCOVERY_PORT + i
			break
	if _udp == null:
		session._log("public: no discovery port free (%d–%d), so it can't be found on this network" % [
				ServerList.DISCOVERY_PORT, ServerList.DISCOVERY_PORT + ServerList.DISCOVERY_PORTS - 1])
	_target = ServerList.list_address(list_server)
	if list_server != "" and _target.is_empty():
		session._log("public: \"%s\" isn't a list server address" % list_server.left(64))


func _process(delta: float) -> void:
	if session == null or not is_instance_valid(session) or not session.is_server():
		return
	_answer_local()
	if not _target.is_empty() and not _refused:
		_keep_listed(delta)


# --- The local network --------------------------------------------------------------------

func _answer_local() -> void:
	if _udp == null:
		return
	while _udp.get_available_packet_count() > 0:
		var packet := _udp.get_packet()
		var ip := _udp.get_packet_ip()
		var port := _udp.get_packet_port()
		if packet.size() != ServerList.PACKET or packet.slice(0, 4).get_string_from_ascii() != ServerList.QUERY:
			continue
		if not ServerList.is_local(ip) or not _may_reply():
			continue
		var reply := (ServerList.REPLY + JSON.stringify(ServerList.describe(session))).to_utf8_buffer()
		if reply.size() > ServerList.PACKET:
			continue
		_udp.set_dest_address(ip, port)
		_udp.put_packet(reply)


func _may_reply() -> bool:
	var second := Time.get_ticks_msec() / 1000
	if _replies[0] != second:
		_replies = [second, 0]
	_replies[1] += 1
	return _replies[1] <= REPLIES_PER_SECOND


# --- The list server ------------------------------------------------------------------------

func _keep_listed(delta: float) -> void:
	if _tcp == null:
		_wait -= delta
		if _wait > 0.0:
			return
		if _resolving < 0:
			_resolving = IP.resolve_hostname_queue_item(_target[0])
		var status := IP.get_resolve_item_status(_resolving)
		if status == IP.RESOLVER_STATUS_WAITING:
			return
		var ip := IP.get_resolve_item_address(_resolving) if status == IP.RESOLVER_STATUS_DONE else ""
		IP.erase_resolve_item(_resolving)
		_resolving = -1
		_tcp = StreamPeerTCP.new()
		if ip == "" or _tcp.connect_to_host(ip, _target[1]) != OK:
			_lost("couldn't find the list server %s" % list_server)
			return
		_connecting = CONNECT_WAIT
		_said = {}
		_since = KEEP_ALIVE  # Say hello as soon as it's connected.
		_conn.buf = PackedByteArray()
		return
	_tcp.poll()
	match _tcp.get_status():
		StreamPeerTCP.STATUS_CONNECTING:
			_connecting -= delta
			if _connecting <= 0.0:
				_lost("the list server %s didn't answer" % list_server)
			return
		StreamPeerTCP.STATUS_CONNECTED:
			pass
		_:
			_lost("lost the list server %s" % list_server if listed_as != "" else "couldn't reach the list server %s" % list_server)
			return
	# Its answers: whether it's listed, and where.
	var available := _tcp.get_available_bytes()
	if available > 0:
		var got := _tcp.get_partial_data(mini(available, ServerList.MAX_LINE))
		if got[0] == OK:
			var buf: PackedByteArray = _conn.buf
			buf.append_array(got[1])
			_conn.buf = buf
		for msg: Variant in ServerList.take_lines(_conn):
			_heard(msg)
	# How it's doing: when it changes (not too often), and now and then anyway.
	_since += delta
	var now := ServerList.describe(session)
	if _since >= KEEP_ALIVE or (now != _said and _since >= MIN_GAP):
		var hello := now.duplicate()
		hello.op = "host"
		if not ServerList.send(_tcp, ServerList.line(hello)).is_empty():
			_lost("the list server %s isn't listening" % list_server)  # Its end is full: it's stopped reading.
			return
		_said = now
		_since = 0.0


func _heard(msg: Variant) -> void:
	if not msg is Dictionary:
		_lost("the list server said something odd")
		return
	var d: Dictionary = msg
	if is_same(d.get("ok"), true):
		var at: String = str(d.get("address", "")).left(64)
		if at != listed_as:
			listed_as = at
			session._log("public: listed on %s as %s" % [list_server, listed_as])
	elif d.get("reason") is String:
		_refused = true  # It won't have us: don't keep asking.
		session._log("public: the list server said no (%s)" % (d.reason as String).left(80))
		_close()


func _lost(why: String) -> void:
	session._log("public: %s; trying again in %d s" % [why, RETRY])
	listed_as = ""
	_close()
	_wait = RETRY


func _close() -> void:
	if _tcp:
		_tcp.disconnect_from_host()
	_tcp = null


func _exit_tree() -> void:
	_close()
	if _udp:
		_udp.close()
	if _resolving >= 0:
		IP.erase_resolve_item(_resolving)
		_resolving = -1
