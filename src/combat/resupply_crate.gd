class_name ResupplyCrate
extends Node3D
## An ammo crate (games with resupply, GameRules.resupply: teams). Walk up to
## it holding a gun and the gun's magazine fills back up; each player can
## use it once every `cooldown` seconds. Hidden and inert unless the game has
## resupply (the match switches it on).

const GROUP := &"resupply"
const REACH := 1.4
const SIZE := Vector3(1.0, 0.6, 0.62)
const COLOR := Color(0.36, 0.42, 0.24)

@export var enabled := false:
	set(value):
		enabled = value
		visible = value
@export var cooldown := 8.0

var _used := {}
var _body: MeshInstance3D


func _ready() -> void:
	add_to_group(GROUP)
	visible = enabled
	_body = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = SIZE
	_body.mesh = box
	_body.material_override = WeaponModel.material(false)
	_body.set_instance_shader_parameter(&"color", COLOR)
	_body.set_instance_shader_parameter(&"gloss", 0.35)
	_body.position.y = SIZE.y * 0.5
	add_child(_body)
	var band := MeshInstance3D.new()
	var strip := BoxMesh.new()
	strip.size = Vector3(SIZE.x + 0.02, 0.1, SIZE.z + 0.02)
	band.mesh = strip
	band.material_override = WeaponModel.material(false)
	band.set_instance_shader_parameter(&"color", Color(0.95, 0.95, 0.9))
	band.position.y = SIZE.y * 0.62
	add_child(band)
	var tag := Label3D.new()
	tag.text = "ammo"
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font = LofiUI.FONT
	tag.font_size = 40
	tag.pixel_size = 0.006
	tag.outline_size = 10
	tag.outline_modulate = Color(0.04, 0.04, 0.06)
	tag.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	tag.position.y = SIZE.y + 0.35
	add_child(tag)


func _physics_process(delta: float) -> void:
	for p: Node in _used.keys():
		_used[p] -= delta
		if _used[p] <= 0.0 or not is_instance_valid(p):
			_used.erase(p)
	if not enabled:
		return
	for n: Node in get_tree().get_nodes_in_group(Ballistics.GROUP):
		var p := n as Player
		if p == null or p.is_dead or _used.has(p):
			continue
		if p.global_position.distance_to(global_position) < REACH and p.weapons.refill():
			_used[p] = cooldown


## Seconds until `player` can use it again (0: now).
func wait_for(player: Player) -> float:
	return maxf(float(_used.get(player, 0.0)), 0.0)


func _process(_delta: float) -> void:
	if not enabled or _body == null:
		return
	var local := get_tree().get_first_node_in_group(&"local_player") as Player
	var ready := local == null or not _used.has(local)
	_body.set_instance_shader_parameter(&"color", COLOR if ready else COLOR.darkened(0.55))
