class_name PlayerInfo
extends RefCounted
## One player in a game: who they are, which side they're on and how they're
## doing. Lives as long as the game does, across map changes; `player` is
## their body on the current map (null between maps).

## Network peer id (1: the host, or everyone offline); bots count down from -1.
var id := 0
var player_name := Cosmetics.DEFAULT_NAME
var team := Hats.Team.RED
## The free-for-all colour, a key of Hats.PALETTE.
var color := Cosmetics.DEFAULT_COLOR
var hat := Cosmetics.DEFAULT_HAT
var bot := false
## Played on this machine by the person at the keyboard.
var local := false
var kills := 0
var deaths := 0
var heartshots := 0
var round_wins := 0
var player: Player


## The colour they wear: their team's in teams, their pick otherwise.
func tint(teams: bool) -> Color:
	return Hats.team_color(team) if teams else Hats.PALETTE.get(color, Hats.PALETTE[Cosmetics.DEFAULT_COLOR])


func alive() -> bool:
	return player != null and is_instance_valid(player) and not player.is_dead


## The local person at the keyboard, from their saved look and name.
static func local_human() -> PlayerInfo:
	Cosmetics.load_saved()
	var info := PlayerInfo.new()
	info.id = 1
	info.local = true
	info.player_name = Cosmetics.player_name
	info.color = Cosmetics.color
	info.hat = Cosmetics.hat
	return info


## A bot numbered `n` (from 1), with a look of its own.
static func make_bot(n: int) -> PlayerInfo:
	var info := PlayerInfo.new()
	info.id = -n
	info.bot = true
	info.player_name = "bot %d" % n
	var colors := Hats.PALETTE.keys()
	info.color = colors[(n * 3) % colors.size()]
	info.hat = Hats.ALL[(n * 5) % Hats.ALL.size()]
	return info


## Plain data, for the scoreboard and (later) the network.
func to_dict() -> Dictionary:
	return {"id": id, "name": player_name, "team": team, "color": String(color), "hat": String(hat), "bot": bot,
			"kills": kills, "deaths": deaths, "heartshots": heartshots, "round_wins": round_wins}


## Rebuilds one from to_dict() data that may have come from anywhere: every
## field is checked and anything out of range falls back to a default, the
## name is cleaned (Cosmetics.clean_name).
static func from_dict(d: Dictionary) -> PlayerInfo:
	var info := PlayerInfo.new()
	info.id = int(d.get("id", 0)) if d.get("id") is int else 0
	info.player_name = Cosmetics.clean_name(d.get("name", ""))
	var t: Variant = d.get("team", 0)
	info.team = Hats.Team.BLUE if t is int and t == Hats.Team.BLUE else Hats.Team.RED
	var c := StringName(str(d.get("color", "")))
	info.color = c if Hats.PALETTE.has(c) else Cosmetics.DEFAULT_COLOR
	var h := StringName(str(d.get("hat", "")))
	info.hat = h if h in Hats.ALL else Cosmetics.DEFAULT_HAT
	info.bot = d.get("bot", false) is bool and d.bot
	for key in ["kills", "deaths", "heartshots", "round_wins"]:
		var v: Variant = d.get(key, 0)
		info.set(key, clampi(v, -9999, 9999) if v is int else 0)
	return info
