class_name Prediction
extends Node
## Your own player in a networked game, on a client (docs/NETWORKING.md). It
## moves at once on your input, like offline, and every tick's command goes
## to the server numbered (with the few before it, so one lost packet loses
## nothing). When a snapshot says where the server had you after command N,
## that's checked against where prediction had you after N: when they agree
## nothing happens; when they don't, the player goes back to the server's
## state and replays every command since N, and the difference is eased away
## on screen rather than snapped.
##
## The check waits for the next physics tick: the replay has to run there,
## where move_and_slide steps by the physics tick (outside it, it steps by
## the frame's time, and the replay would come out wrong).

## Commands remembered for replaying (2 s at 60 Hz).
const HISTORY := 120
## How far prediction may be off before it's corrected.
const TOLERANCE := 0.05
const DT := 1.0 / 60.0

var player: Player
var sync: MatchSync
var tick := 0
## Corrections made (for tests and the debug readout).
var corrections := 0

## [tick, InputCommand, position after, mode after], oldest first.
var _history: Array = []
var _recent: Array = []
## The server's latest word, waiting for the next physics tick.
var _pending := {}


func _ready() -> void:
	player.after_tick = record


## After the player ran `cmd`: remember it, and send it (and the few
## before it) to the server.
func record(cmd: InputCommand) -> void:
	tick += 1
	var c := cmd.copy()
	# Where you saw everyone else as you did it (lag compensation).
	c.view_tick = sync.view_clock if sync else -1.0
	_history.append([tick, c, player.global_position, player.state.mode])
	if _history.size() > HISTORY:
		_history.pop_front()
	_recent.append([tick, c])
	if _recent.size() > NetCodec.INPUT_REDUNDANCY + 1:
		_recent.pop_front()
	if sync:
		sync.send_inputs(NetCodec.encode_inputs(_recent))
	if not _pending.is_empty():
		var owner := _pending
		_pending = {}
		_reconcile(owner)


## The server's word on where you were after command `owner.ack`
## (NetCodec.decode_owner): prediction is corrected on the next tick if it
## was off.
func reconcile(owner: Dictionary) -> void:
	if _pending.is_empty() or int(owner.ack) >= int(_pending.ack):
		_pending = owner


func _reconcile(owner: Dictionary) -> void:
	var ack: int = owner.ack
	while not _history.is_empty() and _history[0][0] < ack:
		_history.pop_front()
	if _history.is_empty() or _history[0][0] != ack:
		return
	var settled: Array = _history.pop_front()
	var off: float = (settled[2] as Vector3).distance_to(owner.position)
	if off <= TOLERANCE and settled[3] == owner.state[0]:
		return
	var drawn := player.global_position
	if not player.state.from_array(owner.state):
		return
	player.global_position = owner.position
	player.velocity = owner.velocity
	for h: Array in _history:
		player.replay(h[1], DT)
		h[2] = player.global_position
		h[3] = player.state.mode
	player.smooth_correction(drawn - player.global_position)
	corrections += 1


## Forgets everything (after a respawn: the server put you somewhere new).
func reset() -> void:
	_history.clear()
	_recent.clear()
	_pending = {}
