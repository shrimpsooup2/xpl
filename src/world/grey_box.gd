@tool
class_name GreyBox
extends StaticBody3D
## A solid greybox block. Set `size` and `kind` in the inspector; the mesh and
## collision are rebuilt to match, so never scale the node itself. A dressed
## map (GDD §9.3) gives it its own `surface` instead of the kind's greybox
## look, and puts it on render `layers` so each floor's lamps light only
## that floor.

enum Kind { FLOOR, WALL, RAMP, LEDGE, RIDE, TOWER, MARKER }

## texture, meters per repeat, gloss head-on, gloss at grazing angles, roughness
const SURFACES := {
	Kind.FLOOR: ["floor_tiles", 4.0, 0.20, 0.55, 0.30],
	Kind.WALL: ["wall_panels", 4.0, 0.12, 0.40, 0.45],
	Kind.RAMP: ["tread_plate", 2.0, 0.20, 0.50, 0.35],
	Kind.LEDGE: ["bricks", 2.0, 0.04, 0.20, 0.80],
	Kind.RIDE: ["ride_tiles", 2.0, 0.30, 0.70, 0.20],
	Kind.TOWER: ["bathroom_tiles", 2.0, 0.30, 0.70, 0.20],
	Kind.MARKER: ["hazard", 1.0, 0.10, 0.30, 0.50],
}
const TEXTURE_DIR := "res://assets/textures/"

static var _materials: Dictionary = {}

@export var size: Vector3 = Vector3.ONE:
	set(value):
		size = value.max(Vector3(0.01, 0.01, 0.01))
		_rebuild()
@export var kind: Kind = Kind.WALL:
	set(value):
		kind = value
		_rebuild()
## Its own material (a dressed map's), in place of the kind's.
@export var surface: Material:
	set(value):
		surface = value
		_rebuild()
## Which render layers it's drawn on (lights pick layers to light).
@export_flags_3d_render var layers := 1:
	set(value):
		layers = value
		_rebuild()
## Whether it casts shadows. A dressed map with many blocks can turn it off
## where the shadows add little, to save drawing them all again.
@export var shadows := true:
	set(value):
		shadows = value
		_rebuild()

var _mesh_instance: MeshInstance3D
var _collision: CollisionShape3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _mesh_instance == null:
		# Built at runtime and never saved into the scene: only size and kind are.
		_mesh_instance = MeshInstance3D.new()
		_collision = CollisionShape3D.new()
		add_child(_mesh_instance, false, Node.INTERNAL_MODE_FRONT)
		add_child(_collision, false, Node.INTERNAL_MODE_FRONT)
	var mesh := BoxMesh.new()
	mesh.size = size
	_mesh_instance.mesh = mesh
	_mesh_instance.material_override = surface if surface else material_for(kind)
	_mesh_instance.layers = layers
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shape := BoxShape3D.new()
	shape.size = size
	_collision.shape = shape


static func material_for(k: Kind) -> ShaderMaterial:
	if not _materials.has(k):
		var s: Array = SURFACES[k]
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://src/render/retro_surface.gdshader")
		mat.set_shader_parameter(&"albedo_texture", load(TEXTURE_DIR + s[0] + ".png"))
		mat.set_shader_parameter(&"reflection_map", preload("res://assets/textures/reflection_map.png"))
		mat.set_shader_parameter(&"meters_per_repeat", s[1])
		mat.set_shader_parameter(&"gloss", s[2])
		mat.set_shader_parameter(&"gloss_grazing", s[3])
		mat.set_shader_parameter(&"roughness_value", s[4])
		_materials[k] = mat
	return _materials[k]
