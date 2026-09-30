class_name AmbientZone
extends Node3D
## An indoor zone: inside this box (centred on the node, `size` across, not
## turned) the sky's ambient light is cut down to `ambient`, so a room under
## a roof is lit by its own lamps and whatever comes in through its holes,
## not by the sky (retro_surface.gdshader). One per level.

@export var size := Vector3.ONE
## How much of the sky's ambient light is left inside (0..1).
@export_range(0.0, 1.0) var ambient := 0.3

static var _current: AmbientZone


func _ready() -> void:
	_current = self
	var half := size * 0.5
	RenderingServer.global_shader_parameter_set(&"indoor_min", global_position - half)
	RenderingServer.global_shader_parameter_set(&"indoor_max", global_position + half)
	RenderingServer.global_shader_parameter_set(&"indoor_ambient", ambient)


func _exit_tree() -> void:
	if _current == self:
		clear()


## No indoor zone: the sky lights everything.
static func clear() -> void:
	_current = null
	RenderingServer.global_shader_parameter_set(&"indoor_min", Vector3.ZERO)
	RenderingServer.global_shader_parameter_set(&"indoor_max", Vector3.ZERO)
	RenderingServer.global_shader_parameter_set(&"indoor_ambient", 1.0)
