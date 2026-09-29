class_name AmmoBox
extends Node3D
## An ammo box (GameRules.ammo_boxes: teams, where there are no guns on the
## map): a small olive box with a glowing yellow band and an "ammo" tag,
## floating over the floor, turning. Walk into it
## carrying a gun that isn't full and it tops the gun up by `share` of a
## full one (and puts it back in your hands), then it's gone for
## `respawn_time` seconds. The server decides; a client's boxes just show
## what they're told (set_ready).

const GROUP := &"ammo_boxes"
const REACH := 1.3
const HOVER := 0.45
const SIZE := Vector3(0.5, 0.3, 0.34)
const COLOR := Color(0.5, 0.58, 0.28)
const BAND := Color(1.0, 0.82, 0.2)
const SPIN := 1.2
const BOB := 0.05

## It was taken (false) or is back (true).
signal changed(ready: bool)

@export var share := 0.5
@export var respawn_time := 10.0

var available := true
var _look := Node3D.new()
static var _body_material: StandardMaterial3D
static var _band_material: StandardMaterial3D
var _timer := -1.0
var _age := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	add_child(_look)
	if _body_material == null:
		_body_material = StandardMaterial3D.new()
		_body_material.albedo_color = COLOR
		_body_material.roughness = 0.35
		_band_material = StandardMaterial3D.new()
		_band_material.albedo_color = BAND
		_band_material.emission_enabled = true
		_band_material.emission = BAND
		_band_material.emission_energy_multiplier = 1.2
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = SIZE
	body.mesh = box
	body.material_override = _body_material
	_look.add_child(body)
	var band := MeshInstance3D.new()
	var strip := BoxMesh.new()
	strip.size = Vector3(SIZE.x + 0.02, 0.07, SIZE.z + 0.02)
	band.mesh = strip
	band.material_override = _band_material
	band.position.y = SIZE.y * 0.12
	_look.add_child(band)
	var tag := Label3D.new()
	tag.text = "ammo"
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font = LofiUI.FONT
	tag.font_size = 36
	tag.pixel_size = 0.005
	tag.outline_size = 10
	tag.outline_modulate = Color(0.04, 0.04, 0.06)
	tag.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	tag.position.y = SIZE.y * 0.5 + 0.25
	_look.add_child(tag)
	_look.position.y = HOVER


func _physics_process(delta: float) -> void:
	_age += delta
	_look.rotation.y = _age * SPIN
	_look.position.y = HOVER + sin(_age * 2.0) * BOB
	if not available:
		_timer -= delta
		if _timer <= 0.0 and NetSession.authority():
			set_ready(true)
		return
	if not NetSession.authority():
		return  # A client waits for the server to say who took it.
	for n: Node in get_tree().get_nodes_in_group(Ballistics.GROUP):
		var p := n as Player
		if p == null or p.is_dead or p.global_position.distance_to(global_position) > REACH:
			continue
		if p.weapons.top_up(share) > 0:
			_take()
			return


## Taken (or, on a client, the server says it's back: true).
func set_ready(is_ready: bool) -> void:
	if is_ready == available:
		return
	available = is_ready
	_look.visible = is_ready
	if is_ready:
		_look.scale = Vector3.ONE * 0.2
		_look.create_tween().tween_property(_look, "scale", Vector3.ONE, 0.3) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_timer = respawn_time
	changed.emit(is_ready)


func _take() -> void:
	set_ready(false)
