class_name OnlineMenu
extends VBoxContainer
## Play → online (docs/NETWORKING.md). Three tabs along the top:
##   find a game: the public games (ServerBrowser) on this network, and on
##     the list server if one's set, a page at a time; words typed in the
##     search box narrow them down (by name, style or map). Pick one to
##     join it; a locked one asks for its password first.
##   host a game: its name, style, port, an optional password, whether it's
##     public (anyone can find it under *find a game*, password or not), and
##     whether to ask the router to open the port.
##   join by address: an address and the password; after you've left a
##     server, *rejoin* goes back to it.
## Then the lobby: who's in, where friends can reach you, and the game's
## options on one line. The host picks the style and the bots, changes the
## options (RulesEditor, in place of the roster while it's open), makes the
## game public or not, and starts it; everyone else waits for the host (or
## the dedicated server) to start. Games come back here when they end. Why
## a join failed or a connection dropped shows in the status line.

signal back

## Where the page remembers the last address, port, style, name, whether
## games you host are public, and the list server (never passwords).
static var prefs_path := "user://online.cfg"
## The tab it opens on: the one you were last on.
static var last_tab := 0
const TABS := ["find a game", "host a game", "join by address"]
const MAX_BOTS := 7
const STYLES := ["free-for-all", "teams"]
## Canvas pixels the roster may take before wrapping, and a found game's row.
const ROSTER_WIDTH := 300.0
const ROW_WIDTH := 290.0
## Found games shown a page at a time.
const PAGE := 6

var tab := 0
var _tabs: Array[Button] = []
var _status: PanelContainer
var _roster: HFlowContainer
var _log: PanelContainer
var _summary: PanelContainer
var _where: PanelContainer
var _style_label: PanelContainer
var _bots_label: PanelContainer
var _options: RulesEditor
var _options_button: Button
var _public_button: Button
var _name_field: LineEdit
var _port_field: LineEdit
var _host_password: LineEdit
var _address_field: LineEdit
var _join_password: LineEdit
var _upnp_button: Button
var _search: LineEdit
var _list: VBoxContainer
var _pager: HBoxContainer
var _page_label: PanelContainer
var _pick_row: HBoxContainer
var _pick_label: PanelContainer
var _pick_password: LineEdit
var _list_field: LineEdit
var _page := 0
## A locked game waiting for its password.
var _picked := {}
var _browser: ServerBrowser
var _session: NetSession
# Saved between runs (not passwords).
var _style := 0
var _port := NetSession.DEFAULT_PORT
var _upnp := false
var _public := false
var _address := "127.0.0.1"
var _server_name := ""
var _list_server := ""


func _ready() -> void:
	add_theme_constant_override(&"separation", 3)
	_load_prefs()
	_browser = ServerBrowser.new()
	_browser.updated.connect(_show_found)
	_browser.finished.connect(_show_found)
	add_child(_browser)
	if NetSession.active():
		show_lobby()
	else:
		show_tab(last_tab, NetSession.take_reason())


# --- The tabs ---------------------------------------------------------------------------

## Tab `i` (TABS), with `message` in the status line (an alert if it's
## there: why the last game ended).
func show_tab(i: int, message := "") -> void:
	tab = clampi(i, 0, TABS.size() - 1)
	last_tab = tab
	_clear()
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 2)
	_tabs.clear()
	for k in TABS.size():
		var b := LofiUI.button(TABS[k], show_tab.bind(k))
		b.toggle_mode = true
		b.set_pressed_no_signal(k == tab)
		_tabs.append(b)
		row.add_child(b)
	add_child(row)
	var page := VBoxContainer.new()
	page.add_theme_constant_override(&"separation", 2)
	add_child(page)
	match tab:
		0:
			_find_page(page)
		1:
			_host_page(page)
		_:
			_join_page(page)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override(&"separation", 3)
	bottom.add_child(_menu_button("back", func() -> void: back.emit()))
	_status = _status_box()
	bottom.add_child(_status)
	add_child(bottom)
	if tab == 0:
		if message == "":
			refresh()
		else:
			_show_found()  # What was found before, with why the join failed.
	if message != "":
		say(message, true)
	_enter_all()


## The hosting and joining page (the tab last shown).
func show_connect(message := "") -> void:
	show_tab(tab, message)


## Puts `text` in the status line; `alert` for things that went wrong.
func say(text: String, alert := false) -> void:
	if _status == null or not is_instance_valid(_status):
		return
	_status.visible = text != ""
	LofiUI.set_text(_status, text)
	LofiUI.restyle(_status, LofiUI.Style.ALERT if alert else LofiUI.Style.GHOST)
	if alert and text != "":
		LofiUI.shake(_status)


# --- Find a game ----------------------------------------------------------------------------

func _find_page(page: VBoxContainer) -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 2)
	_search = LofiUI.field("", 150, 40)
	_search.placeholder_text = "search: name, style, map"
	_search.text_changed.connect(func(_t: String) -> void:
		_page = 0
		_show_found())
	top.add_child(_search)
	top.add_child(_small_button("refresh", refresh))
	page.add_child(top)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", 1)
	page.add_child(_list)
	var pages: Array = []
	for n in 34:
		pages.append("page %d/%d" % [n + 1, n + 1])
	_pager = LofiUI.stepper(pages, _step_page)
	_pager.alignment = BoxContainer.ALIGNMENT_BEGIN
	_page_label = _pager.get_child(1)
	_pager.visible = false
	page.add_child(_pager)
	_pick_row = HBoxContainer.new()
	_pick_row.add_theme_constant_override(&"separation", 2)
	_pick_label = LofiUI.box("", LofiUI.SMALL, LofiUI.Style.GHOST)
	_pick_row.add_child(_pick_label)
	_pick_password = LofiUI.field("", 64, 64, true)
	_pick_password.text_submitted.connect(func(_t: String) -> void: _join_picked())
	_pick_row.add_child(_pick_password)
	_pick_row.add_child(_small_button("join", _join_picked))
	_pick_row.visible = false
	page.add_child(_pick_row)
	_list_field = LofiUI.field(_list_server, 110, 280)
	_list_field.placeholder_text = "none: this network only"
	_list_field.text_submitted.connect(func(_t: String) -> void: _set_list_server())
	_list_field.focus_exited.connect(_set_list_server)
	page.add_child(_labelled("list server", _list_field))


## Looks for public games again.
func refresh() -> void:
	_picked = {}
	_page = 0
	_browser.refresh(_list_server)
	_show_found()


func _set_list_server() -> void:
	if _list_field == null or not is_instance_valid(_list_field) or _list_field.text.strip_edges() == _list_server:
		return
	_list_server = _list_field.text.strip_edges()
	_save_prefs()
	refresh()


func _step_page(by: int) -> void:
	_page += by
	_show_found()


## The games found that match the search, a page of them.
func _show_found() -> void:
	if _list == null or not is_instance_valid(_list):
		return
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var games := _browser.matching(_search.text if _search else "")
	var pages := maxi(ceili(games.size() / float(PAGE)), 1)
	_page = posmod(_page, pages)
	for g in games.slice(_page * PAGE, (_page + 1) * PAGE):
		_list.add_child(_game_row(g))
	_pager.visible = pages > 1
	LofiUI.set_text(_page_label, "page %d/%d" % [_page + 1, pages])
	if _pick_row and is_instance_valid(_pick_row):
		_pick_row.visible = not _picked.is_empty()
	if _browser.searching:
		say("looking for games...")
	elif _browser.found.is_empty():
		var why := (" (%s)" % _browser.list_error) if _browser.list_error != "" else ""
		say("no public games found%s: host one, or join by address" % why, _browser.list_error != "")
	elif games.is_empty():
		say("none of the %d games found match" % _browser.found.size())
	else:
		var why := (" · %s" % _browser.list_error) if _browser.list_error != "" else ""
		say("%d game%s%s" % [games.size(), "" if games.size() == 1 else "s", why])


## A found game as a button: name · style · map · players, and whether it's
## locked, full, or here on this network.
func _game_row(g: Dictionary) -> Button:
	var parts := PackedStringArray([g.name, g.style if g.style != "" else "?", g.map if g.map != "" else "in the lobby",
			"%d/%d" % [g.players, g.max] + (" +%d bots" % g.bots if g.bots > 0 else "")])
	var other_version: bool = g.protocol != NetCodec.PROTOCOL
	var full: bool = g.players >= g.max
	if g.locked:
		parts.append("password")
	if g.lan:
		parts.append("this network")
	if other_version:
		parts.append("another version")
	elif full:
		parts.append("full")
	var b := _small_button(" · ".join(parts), _pick_game.bind(g))
	b.custom_minimum_size.x = ROW_WIDTH
	b.clip_text = true
	b.disabled = other_version or full
	return b


## Joins a found game, or (locked) asks for its password first.
func _pick_game(g: Dictionary) -> void:
	if g.locked:
		_picked = g
		LofiUI.set_text(_pick_label, "password for %s:" % g.name)
		_pick_row.visible = true
		_pick_password.text = ""
		_pick_password.grab_focus()
		LofiUI.pop(_pick_row, 0.9, 0.14)
		return
	_connect_to(g.address, g.port, "", g.name)


func _join_picked() -> void:
	if _picked.is_empty():
		return
	_connect_to(_picked.address, _picked.port, _pick_password.text, _picked.name)


# --- Host a game ----------------------------------------------------------------------------

func _host_page(page: VBoxContainer) -> void:
	_name_field = LofiUI.field(_server_name, 110, 32)
	_name_field.placeholder_text = _default_name()
	page.add_child(_labelled("name", _name_field))
	var style_row := LofiUI.stepper(STYLES, _step_style)
	_style_label = style_row.get_child(1)
	page.add_child(_labelled("style", style_row))
	_port_field = LofiUI.field(str(_port), 36, 5)
	_host_password = LofiUI.field("", 56, 64, true)
	_host_password.placeholder_text = "none"
	var port_row := _labelled("port", _port_field)
	port_row.add_child(_labelled("password", _host_password))
	page.add_child(port_row)
	_public_button = _small_button("", _toggle_public)
	_upnp_button = _small_button("", _toggle_upnp)
	var go := HBoxContainer.new()
	go.add_theme_constant_override(&"separation", 3)
	go.add_child(_menu_button("host", _host))
	go.add_child(_public_button)
	go.add_child(_upnp_button)
	page.add_child(go)
	page.add_child(_shrink(LofiUI.box("the game's options are yours to change in the lobby", LofiUI.SMALL, LofiUI.Style.GHOST)))
	_show_style()
	_show_public()
	_show_upnp()


func _default_name() -> String:
	return Cosmetics.clean_name("%s's game" % Cosmetics.player_name, 32)


func _host() -> void:
	var port := _port_field.text.strip_edges()
	if not port.is_valid_int() or port.to_int() < 1024 or port.to_int() > 65535:
		say("the port is a number from 1024 to 65535", true)
		return
	_port = port.to_int()
	_server_name = _name_field.text.strip_edges()
	_save_prefs()
	var rules := RulesEditor.saved(GameRules.Kind.TEAMS if _style == 1 else GameRules.Kind.FFA)
	var err := NetSession.host(get_tree(), _port, rules, NetSession.PLAYER_LIMIT, _host_password.text, _upnp,
			_server_name if _server_name != "" else _default_name())
	if err != OK:
		say("couldn't open port %d: is something else using it?" % _port, true)
		return
	if _public:
		NetSession.current.advertise(true, _list_server)
	show_lobby.call_deferred()  # Once the session is in the tree.


func _step_style(by: int) -> void:
	_style = posmod(_style + by, STYLES.size())
	_show_style()
	var s := NetSession.current
	if s and is_instance_valid(s) and s.role == NetSession.Role.HOST:
		s.rules = RulesEditor.saved(GameRules.Kind.TEAMS if _style == 1 else GameRules.Kind.FFA)
		if _options and is_instance_valid(_options):
			_show_options(true)
		s.send_roster()
	_save_prefs()


func _show_style() -> void:
	if _style_label and is_instance_valid(_style_label):
		LofiUI.set_text(_style_label, STYLES[_style])
		LofiUI.pop(_style_label, 1.1, 0.12)


func _toggle_public() -> void:
	_public = not _public
	var s := NetSession.current
	if s and is_instance_valid(s) and s.role == NetSession.Role.HOST:
		s.advertise(_public, _list_server)
		_show_where()
	_show_public()
	_save_prefs()


func _show_public() -> void:
	if _public_button and is_instance_valid(_public_button):
		_public_button.text = "public: on (anyone can find it)" if _public else "public: off (by address only)"


func _toggle_upnp() -> void:
	_upnp = not _upnp
	_show_upnp()
	_save_prefs()


func _show_upnp() -> void:
	if _upnp_button and is_instance_valid(_upnp_button):
		_upnp_button.text = "open the port: %s" % ("on (upnp)" if _upnp else "off")


# --- Join by address --------------------------------------------------------------------------

func _join_page(page: VBoxContainer) -> void:
	_address_field = LofiUI.field(_address, 100, 280)
	_address_field.placeholder_text = "address:port"
	_address_field.text_submitted.connect(func(_t: String) -> void: _join())
	page.add_child(_labelled("address", _address_field))
	_join_password = LofiUI.field("", 64, 64, true)
	_join_password.placeholder_text = "none"
	_join_password.text_submitted.connect(func(_t: String) -> void: _join())
	page.add_child(_labelled("password", _join_password))
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override(&"separation", 3)
	join_row.add_child(_menu_button("join", _join))
	if not NetSession.last_join.is_empty():
		# Back to the last game: your score and side are kept for you.
		join_row.add_child(_menu_button("rejoin", _rejoin))
	page.add_child(join_row)


func _join() -> void:
	var where := NetSession.parse_address(_address_field.text)
	if where.is_empty():
		say("that isn't an address (like 192.168.1.20 or example.com:27960)", true)
		return
	_address = _address_field.text.strip_edges()
	_save_prefs()
	_connect_to(where[0], where[1], _join_password.text, _address)


## Back to the last server joined (NetSession.last_join), with its password.
func _rejoin() -> void:
	var last := NetSession.last_join
	_connect_to(last.address, last.port, last.password, last.address)


func _connect_to(address: String, port: int, password: String, label: String) -> void:
	if NetSession.join(get_tree(), address, port, password) != OK:
		say("couldn't start connecting", true)
		return
	_watch(NetSession.current)
	say("joining %s..." % label)


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
	_where = LofiUI.box("", LofiUI.SMALL, LofiUI.Style.GHOST)
	_where.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_where)
	add_child(top)
	# Everyone in the game, flowing along rows (a full game is 16).
	_roster = HFlowContainer.new()
	_roster.add_theme_constant_override(&"h_separation", 1)
	_roster.add_theme_constant_override(&"v_separation", 1)
	_roster.custom_minimum_size.x = ROSTER_WIDTH
	_roster.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(_roster)
	# The game's options, on one line.
	_summary = _shrink(LofiUI.box("", LofiUI.SMALL, LofiUI.Style.GHOST))
	LofiUI.label_of(_summary).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size.x = ROSTER_WIDTH
	add_child(_summary)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 3)
	if hosting:
		_style = 1 if s.rules and s.rules.is_teams() else 0
		_public = s.public
		var style_row := LofiUI.stepper(STYLES, _step_style)
		_style_label = style_row.get_child(1)
		var bot_texts: Array = []
		for n in MAX_BOTS + 1:
			bot_texts.append("%d bots" % n)
		var bots_row := LofiUI.stepper(bot_texts, _step_bots)
		_bots_label = bots_row.get_child(1)
		_public_button = _small_button("", _toggle_public)
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 6)
		row.add_child(_labelled("style", style_row))
		row.add_child(bots_row)
		row.add_child(_public_button)
		add_child(row)
		_show_style()
		_show_bots()
		_show_public()
		buttons.add_child(_menu_button("start", _start))
		_options_button = _menu_button("options", func() -> void: _show_options(_options == null))
		buttons.add_child(_options_button)
		buttons.add_child(_menu_button("close the game", _leave))
	else:
		buttons.add_child(_menu_button("leave", _leave))
		_status = _status_box()
		buttons.add_child(_status)
	add_child(buttons)
	_log = _shrink(LofiUI.box("", LofiUI.SMALL, LofiUI.Style.GHOST))
	_log.visible = false
	add_child(_log)
	_show_where()
	_refresh_roster()
	_enter_all()


## The host's options card in place of the roster (`on`), or the roster back.
func _show_options(on: bool) -> void:
	var s := NetSession.current
	if s == null or not is_instance_valid(s) or not s.is_server() or _roster == null:
		return
	if _options and is_instance_valid(_options):
		_options.queue_free()
	_options = null
	_roster.visible = not on
	_summary.visible = not on
	if _options_button:
		_options_button.text = "players" if on else "options"
	if not on:
		return
	_options = RulesEditor.new(s.rules)
	_options.changed.connect(func() -> void: s.send_roster())
	add_child(_options)
	move_child(_options, _roster.get_index() + 1)
	LofiUI.pop(_options, 0.94, 0.14)


## How to reach this game: for the host, the internet address if the router
## opened the port, and the local one for friends on the same network, and
## whether it's public.
func _show_where() -> void:
	var s := NetSession.current
	if _where == null or not is_instance_valid(_where) or s == null or not is_instance_valid(s):
		return
	if s.role != NetSession.Role.HOST:
		LofiUI.set_text(_where, "connected to " + s.address)
		return
	var parts := PackedStringArray()
	if s.public_address != "":
		parts.append("internet: " + s.public_address)
	var lan := NetSession.lan_address()
	parts.append(("same network: %s:%d" % [lan, s.port]) if lan != "" else "port %d" % s.port)
	parts.append("public" if s.public else "private")
	LofiUI.set_text(_where, " · ".join(parts))


func _refresh_roster() -> void:
	var s := NetSession.current
	if _roster == null or not is_instance_valid(_roster) or s == null or not is_instance_valid(s):
		return
	for c in _roster.get_children():
		c.queue_free()
	var rules := s.rules if s.is_server() else s.lobby_rules
	var style := rules.display_name if s.is_server() and rules else s.lobby_style
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
	if _summary and is_instance_valid(_summary):
		_summary.visible = rules != null and (_options == null or not is_instance_valid(_options))
		if rules:
			LofiUI.set_text(_summary, "%s: %s" % [style, RulesEditor.summary(rules)])
	if _status and is_instance_valid(_status) and not s.is_server():
		var what := (" (%s)" % style) if style != "" else ""
		say(("the next game%s starts in a moment" if s.dedicated else "waiting for the host to start%s") % what)
	if _bots_label and is_instance_valid(_bots_label):
		_show_bots()
	_show_where()


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


## The session's gone (refused, or the connection dropped): back to the
## tab it was joined from, saying why.
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
	_show_where()


# --- Bits -----------------------------------------------------------------------------------

func _clear() -> void:
	_status = null
	_roster = null
	_log = null
	_summary = null
	_where = null
	_style_label = null
	_bots_label = null
	_options = null
	_options_button = null
	_public_button = null
	_upnp_button = null
	_search = null
	_list = null
	_pager = null
	_pick_row = null
	_list_field = null
	_picked = {}
	for c in get_children():
		if c == _browser:
			continue
		remove_child(c)
		c.queue_free()


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
		if c is Control:
			LofiUI.enter(c, Vector2(-30, 0), i * 0.05, 0.22)
			i += 1


func _load_prefs() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(prefs_path) != OK:
		return
	_style = clampi(int(cfg.get_value("online", "style", 0)), 0, STYLES.size() - 1)
	_port = clampi(int(cfg.get_value("online", "port", NetSession.DEFAULT_PORT)), 1024, 65535)
	_upnp = is_same(cfg.get_value("online", "upnp", false), true)
	_public = is_same(cfg.get_value("online", "public", false), true)
	_address = str(cfg.get_value("online", "address", _address)).left(280)
	_server_name = str(cfg.get_value("online", "name", "")).left(32)
	_list_server = str(cfg.get_value("online", "list_server", "")).strip_edges().left(280)


func _save_prefs() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("online", "style", _style)
	cfg.set_value("online", "port", _port)
	cfg.set_value("online", "upnp", _upnp)
	cfg.set_value("online", "public", _public)
	cfg.set_value("online", "address", _address)
	cfg.set_value("online", "name", _server_name)
	cfg.set_value("online", "list_server", _list_server)
	cfg.save(prefs_path)
