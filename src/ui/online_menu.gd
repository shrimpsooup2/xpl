class_name OnlineMenu
extends VBoxContainer
## The main menu's online page (docs/NETWORKING.md). Two halves side by side:
## host a game from this machine (a listen server: the style, the port, an
## optional password, and whether to ask the router to open the port), or
## join one by address. Then the lobby: who's in, where friends can reach
## you, and for the host the style, the bots and the start button; everyone
## else waits for the host (or the dedicated server) to start. Games come
## back here when they end. Why a join failed or a connection dropped shows
## in the status line.

signal back

## Where the page remembers the last address, port, style (not passwords).
static var prefs_path := "user://online.cfg"
const MAX_BOTS := 7
const STYLES := ["free-for-all", "teams"]
## Canvas pixels the roster may take before wrapping.
const ROSTER_WIDTH := 300.0

var _status: PanelContainer
var _roster: HFlowContainer
var _log: PanelContainer
var _style_label: PanelContainer
var _bots_label: PanelContainer
var _port_field: LineEdit
var _host_password: LineEdit
var _address_field: LineEdit
var _join_password: LineEdit
var _upnp_button: Button
var _session: NetSession
# Saved between runs (not passwords).
var _style := 0
var _port := NetSession.DEFAULT_PORT
var _upnp := false
var _address := "127.0.0.1"


func _ready() -> void:
	add_theme_constant_override(&"separation", 3)
	_load_prefs()
	if NetSession.active():
		show_lobby()
	else:
		show_connect(NetSession.take_reason())


# --- Hosting and joining ------------------------------------------------------------------

func show_connect(message := "") -> void:
	_clear()
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override(&"separation", 10)
	add_child(cols)

	var host := _column("host a game")
	var style_row := LofiUI.stepper(STYLES, _step_style)
	_style_label = style_row.get_child(1)
	host.add_child(_labelled("style", style_row))
	_port_field = LofiUI.field(str(_port), 36, 5)
	_host_password = LofiUI.field("", 56, 64, true)
	_host_password.placeholder_text = "none"
	var port_row := _labelled("port", _port_field)
	port_row.add_child(_labelled("password", _host_password))
	host.add_child(port_row)
	_upnp_button = _small_button("", _toggle_upnp)
	var go := HBoxContainer.new()
	go.add_theme_constant_override(&"separation", 3)
	go.add_child(_menu_button("host", _host))
	go.add_child(_upnp_button)
	host.add_child(go)
	cols.add_child(host)

	var join := _column("join a game")
	_address_field = LofiUI.field(_address, 100, 280)
	_address_field.placeholder_text = "address:port"
	_address_field.text_submitted.connect(func(_t: String) -> void: _join())
	join.add_child(_labelled("address", _address_field))
	_join_password = LofiUI.field("", 64, 64, true)
	_join_password.placeholder_text = "none"
	_join_password.text_submitted.connect(func(_t: String) -> void: _join())
	join.add_child(_labelled("password", _join_password))
	join.add_child(_menu_button("join", _join))
	cols.add_child(join)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override(&"separation", 3)
	bottom.add_child(_menu_button("back", func() -> void: back.emit()))
	_status = _status_box()
	bottom.add_child(_status)
	add_child(bottom)
	_show_style()
	_show_upnp()
	say(message, message != "")
	_enter_all()


## Puts `text` in the status line; `alert` for things that went wrong.
func say(text: String, alert := false) -> void:
	if _status == null or not is_instance_valid(_status):
		return
	_status.visible = text != ""
	LofiUI.set_text(_status, text)
	LofiUI.restyle(_status, LofiUI.Style.ALERT if alert else LofiUI.Style.GHOST)
	if alert and text != "":
		LofiUI.shake(_status)


func _host() -> void:
	var port := _port_field.text.strip_edges()
	if not port.is_valid_int() or port.to_int() < 1024 or port.to_int() > 65535:
		say("the port is a number from 1024 to 65535", true)
		return
	_port = port.to_int()
	_save_prefs()
	var rules := GameRules.teams() if _style == 1 else GameRules.free_for_all()
	var err := NetSession.host(get_tree(), _port, rules, NetSession.PLAYER_LIMIT, _host_password.text, _upnp)
	if err != OK:
		say("couldn't open port %d: is something else using it?" % _port, true)
		return
	show_lobby.call_deferred()  # Once the session is in the tree.


func _join() -> void:
	var where := NetSession.parse_address(_address_field.text)
	if where.is_empty():
		say("that isn't an address (like 192.168.1.20 or example.com:27960)", true)
		return
	_address = _address_field.text.strip_edges()
	_save_prefs()
	if NetSession.join(get_tree(), where[0], where[1], _join_password.text) != OK:
		say("couldn't start connecting", true)
		return
	_watch(NetSession.current)
	say("joining %s..." % _address)


func _step_style(by: int) -> void:
	_style = posmod(_style + by, STYLES.size())
	_show_style()
	var s := NetSession.current
	if s and is_instance_valid(s) and s.role == NetSession.Role.HOST:
		s.rules = GameRules.teams() if _style == 1 else GameRules.free_for_all()
		s.send_roster()
	_save_prefs()


func _show_style() -> void:
	if _style_label and is_instance_valid(_style_label):
		LofiUI.set_text(_style_label, STYLES[_style])
		LofiUI.pop(_style_label, 1.1, 0.12)


func _toggle_upnp() -> void:
	_upnp = not _upnp
	_show_upnp()
	_save_prefs()


func _show_upnp() -> void:
	_upnp_button.text = "open the port: %s" % ("on (upnp)" if _upnp else "off")


# --- The lobby --------------------------------------------------------------------------

func show_lobby() -> void:
	_clear()
	var s := NetSession.current
	if s == null or not is_instance_valid(s) or not NetSession.active():
		show_connect()
		return
	_watch(s)
	var hosting := s.role == NetSession.Role.HOST
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 3)
	top.add_child(LofiUI.box("your game" if hosting else s.server_name, LofiUI.NORMAL, LofiUI.Style.INVERTED))
	var where := LofiUI.box(_where(s), LofiUI.SMALL, LofiUI.Style.GHOST)
	where.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(where)
	add_child(top)
	# Everyone in the game, flowing along rows (a full game is 16).
	_roster = HFlowContainer.new()
	_roster.add_theme_constant_override(&"h_separation", 1)
	_roster.add_theme_constant_override(&"v_separation", 1)
	_roster.custom_minimum_size.x = ROSTER_WIDTH
	_roster.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(_roster)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 3)
	if hosting:
		_style = 1 if s.rules and s.rules.is_teams() else 0
		var style_row := LofiUI.stepper(STYLES, _step_style)
		_style_label = style_row.get_child(1)
		var bot_texts: Array = []
		for n in MAX_BOTS + 1:
			bot_texts.append("%d bots" % n)
		var bots_row := LofiUI.stepper(bot_texts, _step_bots)
		_bots_label = bots_row.get_child(1)
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 6)
		row.add_child(_labelled("style", style_row))
		row.add_child(bots_row)
		add_child(row)
		_show_style()
		_show_bots()
		buttons.add_child(_menu_button("start", _start))
		buttons.add_child(_menu_button("close the game", _leave))
	else:
		buttons.add_child(_menu_button("leave", _leave))
		_status = _status_box()
		buttons.add_child(_status)
	add_child(buttons)
	_log = _shrink(LofiUI.box("", LofiUI.SMALL, LofiUI.Style.GHOST))
	_log.visible = false
	add_child(_log)
	_refresh_roster()
	_enter_all()


## How to reach this game: for the host, the internet address if the router
## opened the port, and the local one for friends on the same network.
func _where(s: NetSession) -> String:
	if s.role != NetSession.Role.HOST:
		return "connected to " + s.address
	var parts := PackedStringArray()
	if s.public_address != "":
		parts.append("internet: " + s.public_address)
	var lan := NetSession.lan_address()
	parts.append(("same network: %s:%d" % [lan, _port]) if lan != "" else "port %d" % _port)
	return " · ".join(parts)


func _refresh_roster() -> void:
	var s := NetSession.current
	if _roster == null or not is_instance_valid(_roster) or s == null or not is_instance_valid(s):
		return
	for c in _roster.get_children():
		c.queue_free()
	var style := s.rules.display_name if s.is_server() and s.rules else s.lobby_style
	var teams := style == "teams"
	for info in s.players():
		var tags := PackedStringArray()
		if teams:
			tags.append(OnlineMenu.team_name(info.team))
		if info.id == 1 and s.role != NetSession.Role.DEDICATED:
			tags.append("host")
		if info.bot:
			tags.append("bot")
		if info.id == s.local_id() and not info.bot:
			tags.append("you")
		_roster.add_child(LofiUI.box("%s%s" % [info.player_name, ("  (" + ", ".join(tags) + ")") if not tags.is_empty() else ""],
				LofiUI.SMALL, LofiUI.Style.NORMAL if info.id == s.local_id() else LofiUI.Style.GHOST))
	if _status and is_instance_valid(_status) and not s.is_server():
		var what := (" (%s)" % style) if style != "" else ""
		say(("the next game%s starts in a moment" if s.dedicated else "waiting for the host to start%s") % what)
	if _bots_label and is_instance_valid(_bots_label):
		_show_bots()


static func team_name(team: Hats.Team) -> String:
	return "blue" if team == Hats.Team.BLUE else "red"


func _step_bots(by: int) -> void:
	var s := NetSession.current
	if s and is_instance_valid(s) and s.is_server():
		s.set_bots(clampi(s.bot_count() + by, 0, MAX_BOTS))
		LofiUI.pop(_bots_label, 1.1, 0.12)


func _show_bots() -> void:
	var s := NetSession.current
	if s and is_instance_valid(s):
		LofiUI.set_text(_bots_label, "%d bot%s" % [s.bot_count(), "" if s.bot_count() == 1 else "s"])


## The host starts the game for everyone in the lobby.
func _start() -> void:
	var s := NetSession.current
	if s == null or not is_instance_valid(s) or s.role != NetSession.Role.HOST:
		return
	if s.rules.is_teams():
		s.balance_teams()
	Game.start(get_tree(), s.rules, s.players())


func _leave() -> void:
	_session = null
	NetSession.leave(get_tree())
	show_connect()


# --- The session's news -------------------------------------------------------------------

func _watch(s: NetSession) -> void:
	if _session == s:
		return
	_session = s
	s.roster_changed.connect(_refresh_roster)
	s.log_line.connect(_on_log)
	s.join_finished.connect(func(ok: bool, reason: String) -> void:
		if ok:
			show_lobby()
		else:
			_lost(reason))
	s.left.connect(_lost)


## The session's gone (refused, or the connection dropped): back to hosting
## and joining, saying why.
func _lost(reason: String) -> void:
	if _session == null:
		return
	_session = null
	NetSession.take_reason()  # Said here; the menu needn't say it again.
	show_connect(reason)


func _on_log(text: String) -> void:
	if _log and is_instance_valid(_log):
		_log.visible = true
		LofiUI.set_text(_log, text)
		LofiUI.type_in(_log, 60.0)


# --- Bits -----------------------------------------------------------------------------------

func _clear() -> void:
	_status = null
	_roster = null
	_log = null
	_style_label = null
	_bots_label = null
	for c in get_children():
		remove_child(c)
		c.queue_free()


func _column(title: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 2)
	col.add_child(_shrink(LofiUI.box(title, LofiUI.NORMAL, LofiUI.Style.INVERTED)))
	return col


## [label] control, in a row.
func _labelled(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 1)
	row.add_child(LofiUI.box(text + ":", LofiUI.SMALL, LofiUI.Style.GHOST))
	if control is HBoxContainer:
		(control as HBoxContainer).alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(control)
	return row


func _menu_button(text: String, on_pressed: Callable) -> Button:
	var b := LofiUI.button(text, on_pressed)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.custom_minimum_size.x = 70
	return b


func _small_button(text: String, on_pressed: Callable) -> Button:
	var b := LofiUI.button(text, on_pressed)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.add_theme_font_size_override(&"font_size", LofiUI.SMALL)
	return b


func _status_box() -> PanelContainer:
	var box := LofiUI.box("", LofiUI.SMALL, LofiUI.Style.GHOST)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.visible = false
	return box


func _shrink(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return c


func _enter_all() -> void:
	var i := 0
	for c in get_children():
		LofiUI.enter(c, Vector2(-30, 0), i * 0.05, 0.22)
		i += 1


func _load_prefs() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(prefs_path) != OK:
		return
	_style = clampi(int(cfg.get_value("online", "style", 0)), 0, STYLES.size() - 1)
	_port = clampi(int(cfg.get_value("online", "port", NetSession.DEFAULT_PORT)), 1024, 65535)
	_upnp = is_same(cfg.get_value("online", "upnp", false), true)
	_address = str(cfg.get_value("online", "address", _address)).left(280)


func _save_prefs() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("online", "style", _style)
	cfg.set_value("online", "port", _port)
	cfg.set_value("online", "upnp", _upnp)
	cfg.set_value("online", "address", _address)
	cfg.save(prefs_path)
