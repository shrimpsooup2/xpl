extends SceneTree
## Another client for tests/online_tests.gd, run in its own process: joins
## the server named on the command line (as "latecomer", or --name), says
## what it sees, stays a while (walking about, with --walk) and leaves.
##
##   godot --headless --path . --script res://tests/online_client.gd --
##       --port 27990 --password x --stay 5 --name friend --walk

var _stay := 5.0
var _walk := false
var _loose := 0
var _still := 0
var _last_at := Vector3.INF
var _said := {}
var _started := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var port := NetSession.DEFAULT_PORT
	var password := ""
	var player_name := "latecomer"
	_walk = "--walk" in args
	for i in args.size() - 1:
		match args[i]:
			"--name":
				player_name = args[i + 1]
			"--port":
				port = args[i + 1].to_int()
			"--password":
				password = args[i + 1]
			"--stay":
				_stay = args[i + 1].to_float()
	Cosmetics.path = "user://test_%s_cosmetics.cfg" % player_name.validate_filename()
	Cosmetics.load_saved()
	Cosmetics.set_player_name(player_name)
	NetSession.join(self, "127.0.0.1", port, password)
	NetSession.current.join_finished.connect(func(ok: bool, reason: String) -> void:
		print("joined" if ok else "refused: " + reason)
		if not ok:
			quit(1))
	_started = Time.get_ticks_msec()


func _process(_delta: float) -> bool:
	var m := Game.current
	if m and is_instance_valid(m) and m.level and not _said.has(m.serial):
		_said[m.serial] = true
		print("following %s (level %d, %d players: %s)" % [m.map_name, m.serial, m.infos.size(),
				", ".join(m.infos.map(func(i: PlayerInfo) -> String: return i.player_name))])
		var me := m.local_info()
		if _walk and me and me.player:
			var body := me.player
			body.input_override = func() -> InputCommand:
				var c := InputCommand.new()
				c.move = Vector2(0, 1) if (Time.get_ticks_msec() / 1500) % 2 == 0 else Vector2(0, -1)
				c.yaw = body.yaw
				return c
	_watch_loose_weapons()
	if Time.get_ticks_msec() - _started > _stay * 1000.0:
		NetSession.leave(self)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Cosmetics.path))
		return true
	return false


## Says how many loose weapons it can see, and where the first comes to rest.
func _watch_loose_weapons() -> void:
	var loose := get_nodes_in_group(WeaponPickup.GROUP).filter(func(p: WeaponPickup) -> bool: return p.pad == null)
	if loose.size() != _loose:
		_loose = loose.size()
		_still = 0
		print("loose weapons: %d" % _loose)
	if loose.is_empty():
		return
	var at: Vector3 = loose[0].global_position
	_still = _still + 1 if at.distance_to(_last_at) < 0.001 else 0
	_last_at = at
	if _still == 30:
		print("loose weapon rests at Vector3%s" % at)
