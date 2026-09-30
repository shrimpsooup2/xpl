class_name Rewind
extends RefCounted
## Lag compensation (docs/NETWORKING.md), on the server: where every player's
## body was, tick by tick, for the last moment, so a shot can be tested
## against where its shooter saw everyone rather than where they are now.
##
## A client shows everyone else a little in the past (Puppet), and its
## commands say which server tick that was (InputCommand.view_tick). When
## the server runs a command that fires, each target's hit shapes are moved
## back to where they were at that tick for the test, at most MAX_TICKS back.
## Only what the shooter saw is rewound: the shooter is where it is, and the
## world doesn't move.

## The server's rewinder while a networked game runs (Ballistics asks it).
static var active: Rewind

## Ticks remembered (at 60 Hz).
const KEEP := 40
## As far back as a shot is tested: the 100 ms everyone else is shown
## behind, and up to 150 ms of lag on top (GDD §15.2). A shooter further
## behind than that has to lead a little.
const MAX_TICKS := 15.0

## The server tick last recorded.
var tick := 0
## Body instance id → [[tick, stance (Transform3D), down], ...], oldest first.
var _history := {}


## Remembers where `bodies` are at server tick `at_tick` (every tick).
func record(at_tick: int, bodies: Array) -> void:
	tick = at_tick
	var seen := {}
	for p: Player in bodies:
		var key := p.get_instance_id()
		seen[key] = true
		var h: Array = _history.get(key, [])
		if h.is_empty():
			_history[key] = h
		h.append([at_tick, p.stance(), p.is_dead])
		if h.size() > KEEP:
			h.pop_front()
	for key: int in _history.keys():
		if not seen.has(key):
			_history.erase(key)


## Where the tick a shot is tested at, for a shooter who saw tick `view`:
## no further back than MAX_TICKS, and never ahead of now.
func clamp_tick(view: float) -> float:
	return clampf(view, tick - MAX_TICKS, tick)


## Where `p` stood and faced at server tick `at` (between two recorded
## ticks, in between), or null with no record.
func frame_at(p: Player, at: float) -> Variant:
	var h: Array = _history.get(p.get_instance_id(), [])
	if h.is_empty():
		return null
	var pair := _around(h, clamp_tick(at))
	var a: Array = pair[0]
	var b: Array = pair[1]
	if a == b:
		return a[1]
	var t := clampf((clamp_tick(at) - a[0]) / float(b[0] - a[0]), 0.0, 1.0)
	return (a[1] as Transform3D).interpolate_with(b[1], t)


## Whether `p` was down at tick `at` (just before or after it).
func was_down(p: Player, at: float) -> bool:
	var h: Array = _history.get(p.get_instance_id(), [])
	if h.is_empty():
		return false
	var pair := _around(h, clamp_tick(at))
	return pair[0][2] or pair[1][2]


## The segment from → to tested against `p` as it was at tick `at`: the
## segment is moved from where it stood then to where its model (and hit
## shapes) is now, rigidly, so distances hold; tested there; and the hit
## moved back. Without a record, against now. (The pose isn't rewound, only
## where it stood and faced.)
func ray_test(p: Player, from: Vector3, to: Vector3, at: float) -> Dictionary:
	var then: Variant = frame_at(p, at)
	if then == null:
		return p.ray_test(from, to)
	if was_down(p, at):
		return {}
	var shift := p.model.global_transform * (then as Transform3D).affine_inverse()
	var hit := p.ray_test(shift * from, shift * to)
	if hit.is_empty():
		return {}
	var back := shift.affine_inverse()
	hit.point = back * (hit.point as Vector3)
	hit.normal = (back.basis * (hit.normal as Vector3)).normalized()
	return hit


## The two records either side of tick `at` (the same one twice past either end).
static func _around(h: Array, at: float) -> Array:
	var a: Array = h[0]
	var b: Array = h[0]
	for f: Array in h:
		if f[0] <= at:
			a = f
			b = f
		else:
			b = f
			break
	return [a, b]
