class_name Puppet
extends Node
## Someone else's player on a client (docs/NETWORKING.md): not simulated here,
## but put where the server's snapshots say, played back about 100 ms behind
## the newest so there's nearly always a snapshot either side to blend
## between. The playback clock is nudged, not jumped, to stay that far
## behind as snapshots arrive early or late. In a game every puppet plays by
## the match's one clock (MatchSync.view_clock), which the commands you send
## carry, so the server knows where you saw everyone (lag compensation).

## How far behind the newest snapshot playback runs, in server ticks.
const DELAY_TICKS := 6.0
const TICK_RATE := 60.0
const KEEP := 30

var player: Player
## The match's sync, whose clock this plays by; without it, its own.
var sync: MatchSync

## [server tick, snapshot entry], oldest first.
var _snaps: Array = []
var _clock := -1.0


## A snapshot of this player at server tick `tick`.
func push(tick: int, entry: Dictionary) -> void:
	if not _snaps.is_empty() and tick <= _snaps[-1][0]:
		return  # Older than what we have: out of order.
	_snaps.append([tick, entry])
	if _snaps.size() > KEEP:
		_snaps.pop_front()
	if _clock < 0.0:
		_clock = tick - DELAY_TICKS


## A playback clock moved on by `delta` seconds toward `target` (the newest
## snapshot's tick less the delay): nudged, or jumped if it's far off.
static func follow(clock: float, target: float, delta: float) -> float:
	clock += delta * TICK_RATE
	if absf(clock - target) > TICK_RATE * 0.5:
		return target
	return clock + (target - clock) * minf(delta * 2.0, 1.0)


## Forgets the old snapshots (a respawn: no blending from where it died).
func reset() -> void:
	_snaps.clear()
	_clock = -1.0


func _process(delta: float) -> void:
	if _snaps.is_empty() or player == null or player.is_dead:
		return
	if sync and sync.view_clock >= 0.0:
		_clock = sync.view_clock
	else:
		_clock = follow(_clock, _snaps[-1][0] - DELAY_TICKS, delta)
	var a: Array = _snaps[0]
	var b: Array = a
	for s: Array in _snaps:
		if s[0] <= _clock:
			a = s
		else:
			b = s
			break
	if b == a or b[0] <= a[0]:
		b = a
	var t := 0.0 if b == a else clampf((_clock - a[0]) / float(b[0] - a[0]), 0.0, 1.0)
	var ea: Dictionary = a[1]
	var eb: Dictionary = b[1]
	var near: Dictionary = eb if t > 0.5 else ea
	player.health = near.health  # For its heart; the HUD only shows your own.
	player.apply_puppet((ea.position as Vector3).lerp(eb.position, t), (ea.velocity as Vector3).lerp(eb.velocity, t),
			lerp_angle(ea.yaw, eb.yaw, t), lerpf(ea.pitch, eb.pitch, t), near.mode, near.flags)
	while _snaps.size() > 2 and _snaps[1][0] <= _clock:
		_snaps.pop_front()
