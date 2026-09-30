class_name Flicker
extends Node
## Makes a lamp stutter like a failing fluorescent tube: now and then a
## burst of dropouts, its light and its glowing part going out together.
## Held steady with the effects setting off (Graphics).

@export var light: Light3D
## The glowing part's material (glow.gdshader), its own copy.
@export var material: ShaderMaterial
## Sets this lamp's rhythm apart from the others'.
@export var seed := 0.0

var _energy := 1.0
var _glow := 1.0
var _t := 0.0


func _ready() -> void:
	if light:
		_energy = light.light_energy
	if material:
		_glow = float(material.get_shader_parameter(&"energy"))


func _process(delta: float) -> void:
	_t += delta
	var on := 1.0
	if Graphics.effects:
		var burst := _hash(floorf(_t * 0.7) + seed) > 0.8
		if burst and _hash(floorf(_t * 24.0) + seed * 3.1) > 0.45:
			on = 0.06
	if light:
		light.light_energy = _energy * on
	if material:
		material.set_shader_parameter(&"energy", _glow * on)


static func _hash(n: float) -> float:
	return fposmod(sin(n * 12.9898) * 43758.5453, 1.0)
