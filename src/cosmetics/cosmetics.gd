class_name Cosmetics
extends RefCounted
## Your look, saved between sessions: for now, just the hat (see Hats).

const DEFAULT_HAT := &"cap"

## Where it's saved (tests point this elsewhere).
static var path := "user://cosmetics.cfg"
static var hat := DEFAULT_HAT


## Reads the saved choices; anything missing or unknown is the default.
static func load_saved() -> void:
	hat = DEFAULT_HAT
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		var saved := StringName(cfg.get_value("look", "hat", String(DEFAULT_HAT)))
		if saved in Hats.ALL:
			hat = saved


## Wears hat `id` (one of Hats.ALL) from now on, and saves it.
static func set_hat(id: StringName) -> void:
	hat = id if id in Hats.ALL else DEFAULT_HAT
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.set_value("look", "hat", String(hat))
	cfg.save(path)
