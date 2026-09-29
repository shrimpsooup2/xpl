class_name Cosmetics
extends RefCounted
## Your look and name, saved between sessions: the hat (see Hats), the colour
## you wear in free-for-all (in teams you wear the team's), and the name over
## your head.

const DEFAULT_HAT := &"cap"
const DEFAULT_COLOR := &"teal"
const DEFAULT_NAME := "player"
const NAME_LENGTH := 16

## Where it's saved (tests point this elsewhere).
static var path := "user://cosmetics.cfg"
static var hat := DEFAULT_HAT
## A key of Hats.PALETTE.
static var color := DEFAULT_COLOR
static var player_name := DEFAULT_NAME


## Reads the saved choices; anything missing or unknown is the default.
static func load_saved() -> void:
	hat = DEFAULT_HAT
	color = DEFAULT_COLOR
	player_name = DEFAULT_NAME
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		var saved := StringName(cfg.get_value("look", "hat", String(DEFAULT_HAT)))
		if saved in Hats.ALL:
			hat = saved
		var saved_color := StringName(cfg.get_value("look", "color", String(DEFAULT_COLOR)))
		if Hats.PALETTE.has(saved_color):
			color = saved_color
		player_name = clean_name(cfg.get_value("profile", "name", DEFAULT_NAME))


## The free-for-all colour picked.
static func tint() -> Color:
	return Hats.PALETTE[color]


## Wears hat `id` (one of Hats.ALL) from now on, and saves it.
static func set_hat(id: StringName) -> void:
	hat = id if id in Hats.ALL else DEFAULT_HAT
	_save("look", "hat", String(hat))


## Wears colour `key` (one of Hats.PALETTE) in free-for-all, and saves it.
static func set_color(key: StringName) -> void:
	color = key if Hats.PALETTE.has(key) else DEFAULT_COLOR
	_save("look", "color", String(color))


## Goes by `text` (cleaned up, see clean_name) from now on, and saves it.
static func set_player_name(text: String) -> void:
	player_name = clean_name(text)
	_save("profile", "name", player_name)


## A name fit to show over a head: printable characters only, spaces
## squeezed, at most `limit` long; nothing left is the default.
static func clean_name(text: Variant, limit := NAME_LENGTH) -> String:
	var out := ""
	for ch in str(text).strip_edges():
		var code := ch.unicode_at(0)
		if code < 32 or code == 127:
			continue
		if ch == " " and out.ends_with(" "):
			continue
		out += ch
	out = out.strip_edges().left(limit).strip_edges()
	return out if not out.is_empty() else DEFAULT_NAME


static func _save(section: String, key: String, value: Variant) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.set_value(section, key, value)
	cfg.save(path)
