class_name KillCombos
extends RefCounted
## Kill combos and streaks (GameRules.kill_combos: teams). Kills chained
## within WINDOW seconds of each other make a combo (double kill, triple
## kill...); kills without dying make a streak, and some streaks have names
## ("on a roll"...). Dying ends both. Fed by the match's killfeed, so it
## counts the same offline and online, and for everyone: the killfeed marks
## anyone's combo, and your own set off the effects (GameUI).

## Seconds you have to get the next kill and keep the combo going.
const WINDOW := 4.0
const COMBOS := {2: "double kill", 3: "triple kill", 4: "quad kill", 5: "penta kill"}
const STREAKS := {3: "on a roll", 5: "heating up", 8: "unstoppable", 12: "untouchable"}

# PlayerInfo -> [kills in the combo, when the last one was].
var _chain := {}
# PlayerInfo -> kills since they last died.
var _streak := {}


## `killer` killed `victim` at `now` (seconds). Returns what it made:
## {combo: kills in the combo (1: just a kill), streak: kills without dying,
## combo_name, streak_name ("" unless it's a named one)}, or {} for a death
## nobody gets (a fall, yourself).
func record(killer: PlayerInfo, victim: PlayerInfo, now: float) -> Dictionary:
	if victim:
		_chain.erase(victim)
		_streak.erase(victim)
	if killer == null or killer == victim:
		return {}
	var chain: Array = _chain.get(killer, [0, -INF])
	var count: int = chain[0] + 1 if now - float(chain[1]) <= WINDOW else 1
	_chain[killer] = [count, now]
	var streak: int = int(_streak.get(killer, 0)) + 1
	_streak[killer] = streak
	return {"combo": count, "streak": streak, "combo_name": combo_name(count), "streak_name": STREAKS.get(streak, "")}


## Seconds left for `info` to chain their next kill (0: no combo going).
func time_left(info: PlayerInfo, now: float) -> float:
	if not _chain.has(info):
		return 0.0
	return maxf(WINDOW - (now - float(_chain[info][1])), 0.0)


## Starts over (a new game).
func clear() -> void:
	_chain.clear()
	_streak.clear()


## What a combo of `count` kills is called ("" for one).
static func combo_name(count: int) -> String:
	if count < 2:
		return ""
	return COMBOS.get(count, "combo ×%d" % count)
