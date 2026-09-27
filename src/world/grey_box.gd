@tool
class_name GreyBox
extends StaticBody3D
## A solid greybox block. Set `size` and `kind` in the inspector; the mesh and
## collision are rebuilt to match, so never scale the node itself.

enum Kind { FLOOR, WALL, RAMP, LEDGE, RIDE, TOWER, MARKER }

const COLORS := {
	Kind.FLOOR: [Color(0.66, 0.62, 0.60), Color(0.44, 0.40, 0.50)],
	Kind.WALL: [Color(0.68, 0.66, 0.84), Color(0.45, 0.42, 0.62)],
	Kind.RAMP: [Color(0.64, 0.84, 0.76), Color(0.38, 0.56, 0.52)],
	Kind.LEDGE: [Color(0.95, 0.74, 0.62), Color(0.66, 0.46, 0.42)],
	Kind.RIDE: [Color(0.56, 0.82, 0.92), Color(0.30, 0.52, 0.66)],
	Kind.TOWER: [Color(0.92, 0.64, 0.78), Color(0.62, 0.40, 0.56)],
	Kind.MARKER: [Color(0.32, 0.30, 0.42), Color(0.20, 0.18, 0.28)],
}

static var _materials: Dictionary = {}

@export var size: Vector3 = Vector3.ONE:
	set(value):
		size = value.max(Vector3(0.01, 0.01, 0.01))
		_rebuild()
@export var kind: Kind = Kind.WALL:
	set(value):
		kind = value
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
	_mesh_instance.material_override = material_for(kind)
	var shape := BoxShape3D.new()
	shape.size = size
	_collision.shape = shape


static func material_for(k: Kind) -> ShaderMaterial:
	if not _materials.has(k):
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://src/world/greybox_grid.gdshader")
		mat.set_shader_parameter(&"base_color", COLORS[k][0])
		mat.set_shader_parameter(&"line_color", COLORS[k][1])
		_materials[k] = mat
	return _materials[k]
