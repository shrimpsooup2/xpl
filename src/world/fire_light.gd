class_name FireLight
extends Node
## Makes a lamp waver like a flame: a hearth, a brazier, a lantern's
## candle. Its light drifts brighter and dimmer by a little, never going
## out; its glowing part wavers on its own (glow.gdshader's flicker). Held
## steady with the effects setting off (Graphics).

@export var light: Light3D
## Sets this flame's rhythm apart from the others'.
@export var seed := 0.0
## How far it dims at most (0..1).
@export var amount := 0.25

var _energy := 1.0
var _t := 0.0


func _ready() -> void:
	if light:
		_energy = light.light_energy


func _process(delta: float) -> void:
	if light == null:
		return
	_t += delta
	var dim := 0.0
	if Graphics.effects:
		var wave := sin(_t * 7.3 + seed) * 0.5 + sin(_t * 13.1 + seed * 2.7) * 0.3 + sin(_t * 2.3 + seed * 0.7) * 0.2
		dim = amount * (0.5 + 0.5 * wave)
	light.light_energy = _energy * (1.0 - dim)
