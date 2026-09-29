class_name GameRules
extends Resource
## How a game is played (GDD §8, §14): its structure, combat and ammo rules,
## and map pool. Two built-in styles:
##   free-for-all (classic): short rounds, one life each, last one standing
##     wins the round, first to five rounds; everyone starts with fists, the
##     weapon race resets every round and the map changes with it. Guns hold
##     what's in them and no more (GDD §7.2).
##   teams: one long game on one map, respawning, first team to the kill
##     target (or ahead when time runs out) wins. You respawn with a pistol,
##     health comes back out of combat, pads come back twice as fast, the
##     power pads come back at all, and resupply crates refill the gun in
##     your hands, so a long game on a big map isn't a long walk for ammo.
## Everything here is server-side: clients are told the outcome.

enum Kind { FFA, TEAMS }

@export var kind := Kind.FFA
@export var display_name := "free-for-all"

@export_group("Structure")
## Rounds (one life each, last standing wins) or one continuous game.
@export var rounds := true
## Free-for-all: round wins to take the match.
@export var round_wins := 5
## Seconds a round may last; then nobody wins it.
@export var round_time := 70.0
## Teams: team kills to win. 0: no target.
@export var score_to_win := 0
## Seconds the game may last (teams); 0: no limit.
@export var time_limit := 0.0
## Respawn after dying (teams), and how long it takes.
@export var respawn := false
@export var respawn_delay := 3.0
## Before each round or game: movement on, weapons off.
@export var countdown := 3.0
## After a round, and after the match, before moving on.
@export var round_end_time := 3.0
@export var match_end_time := 8.0

@export_group("Combat")
@export var max_health := 100.0
@export var friendly_fire := false
## Seconds untouched before health starts coming back (0: never).
@export var regen_delay := 0.0
@export var regen_rate := 25.0

@export_group("Weapons and ammo")
## What you (re)spawn holding: "" for fists, or a weapon id (Weapons).
@export var spawn_weapon := &""
## Pad respawn times are multiplied by this.
@export var pad_respawn_scale := 1.0
## Power pads (once a round in free-for-all) come back after this many
## seconds instead; 0 keeps them once a round.
@export var power_pad_respawn := 0.0
## Resupply crates refill the gun in your hands (see ResupplyCrate).
@export var resupply := false
@export var resupply_cooldown := 8.0

@export_group("Maps")
## Map names (Maps) played, in a shuffled order without repeats.
@export var map_pool := PackedStringArray()
## A new map every round (free-for-all) or one map per game.
@export var map_each_round := true


static func free_for_all() -> GameRules:
	var r := GameRules.new()
	r.kind = Kind.FFA
	r.display_name = "free-for-all"
	r.map_pool = PackedStringArray(["stack", "terrace", "switchback", "archipelago", "rift"])
	return r


static func teams() -> GameRules:
	var r := GameRules.new()
	r.kind = Kind.TEAMS
	r.display_name = "teams"
	r.rounds = false
	r.round_wins = 0
	r.round_time = 0.0
	r.score_to_win = 50
	r.time_limit = 600.0
	r.respawn = true
	r.respawn_delay = 3.0
	r.countdown = 5.0
	r.regen_delay = 5.0
	r.spawn_weapon = Weapons.PISTOL
	r.pad_respawn_scale = 0.5
	r.power_pad_respawn = 60.0
	r.resupply = true
	r.map_pool = PackedStringArray(["boulevard", "holdfast", "depot"])
	r.map_each_round = false
	return r


func is_teams() -> bool:
	return kind == Kind.TEAMS


## Every rule as plain data, for the network.
func to_dict() -> Dictionary:
	var d := {}
	for prop in get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			d[prop.name] = get(prop.name)
	return d


## Rules from to_dict() data that came off the network: every value must
## have its rule's type and a sensible range, and maps must be the game's
## own; anything else keeps the default (the style's preset). Never null.
static func from_dict(d: Dictionary) -> GameRules:
	var r := teams() if is_same(d.get("kind"), Kind.TEAMS) else free_for_all()
	for prop in r.get_property_list():
		if not prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE or prop.name == "kind" or not d.has(prop.name):
			continue
		var v: Variant = d[prop.name]
		var have: Variant = r.get(prop.name)
		if typeof(v) != typeof(have):
			continue
		if v is float and (not is_finite(v) or v < 0.0 or v > 100000.0):
			continue
		if v is int and (v < 0 or v > 100000):
			continue
		if v is String:
			v = (v as String).left(32)
		if prop.name == "spawn_weapon" and v != &"" and not v in Weapons.GUNS:
			continue
		if v is PackedStringArray:
			var maps := PackedStringArray()
			for m in v:
				if Maps.scene_of(m) != "" and maps.size() < 32:
					maps.append(m)
			if maps.is_empty():
				continue
			v = maps
		r.set(prop.name, v)
	return r
