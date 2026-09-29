class_name DeathSequence
extends Node
## The local player's death cinematic. The screen blacks out, the world goes
## dark, a spotlight clunks on beside you and swings over to settle on you,
## the camera looks at you from the front, and you comically fall apart.
##
## Presentation only: the player's simulation has already stopped. Every
## timing is a constant here so it's easy to tune.

signal finished

const BLACKOUT_IN := 0.15
const BLACK_HOLD := 0.12
const REVEAL := 0.12
const DARK_BEAT := 0.3
const SPOT_SWEEP := 0.65
const CAPTION_DELAY := 0.5  # After the last piece falls.
const HOLD := 1.8
const FADE_OUT := 0.3

const CAMERA_DISTANCE := 3.2
const CAMERA_HEIGHT := 1.3
const LOOK_HEIGHT := 0.95
## Once you crumble, the camera tilts down to the heap.
const HEAP_LOOK_HEIGHT := 0.35
const HEAP_TILT_START := 1.3  # Seconds after the collapse begins.
const HEAP_TILT_TIME := 1.1
## How far the camera creeps toward you over the sequence.
const DOLLY := 0.7
const DOLLY_TIME := 4.0

## The spotlight hangs high in front of you, on the camera's side, like a
## stage spot, so your face and legs are lit rather than in your own shadow.
const SPOT_HEIGHT := 6.0
const SPOT_FORWARD := 3.2
const SPOT_ENERGY := 16.0
const SPOT_ANGLE := 14.0
## Where the spotlight lands first, beside you, before swinging over.
const SPOT_START_OFFSET := Vector3(3.5, 0.0, -1.0)

const CAPTION := "you fell apart"
## Caption height as a fraction of the screen, up in the dark above the heap.
const CAPTION_Y := 0.16

var player: Player

var _layer: CanvasLayer
var _overlay: ColorRect
var _caption: LofiLabel
var _spot: SpotLight3D
var _tween: Tween
var _active := false
var _saved_lights := {}
var _saved_env := {}
var _hidden_labels: Array[Node3D] = []
var _feet := Vector3.ZERO
var _facing := Vector3.FORWARD
var _spot_from := Vector3.ZERO
var _elapsed := 0.0
var _collapse_at := INF


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_overlay)
	_caption = LofiLabel.new()
	_caption.text = CAPTION
	_caption.visible = false
	_layer.add_child(_caption)


func is_active() -> bool:
	return _active


func play() -> void:
	if _active:
		return
	_active = true
	_elapsed = 0.0
	_collapse_at = INF
	_feet = player.global_position
	_facing = Basis(Vector3.UP, player.yaw) * Vector3.FORWARD
	player.model.fell_apart.connect(_on_fell_apart, CONNECT_ONE_SHOT)

	_tween = create_tween()
	_tween.tween_property(_overlay, "color:a", 1.0, BLACKOUT_IN)
	_tween.tween_callback(_go_dark)
	_tween.tween_interval(BLACK_HOLD)
	_tween.tween_property(_overlay, "color:a", 0.0, REVEAL)
	_tween.tween_interval(DARK_BEAT)
	_tween.tween_callback(_spot_clunk)
	_tween.tween_method(_aim_spot, 0.0, 1.0, SPOT_SWEEP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func() -> void:
		_collapse_at = _elapsed
		player.model.fall_apart(true, _camera_position()))


## Ends the sequence early (or at the end) and puts the world back.
func stop() -> void:
	if not _active:
		return
	_active = false
	if _tween:
		_tween.kill()
	if player.model.fell_apart.is_connected(_on_fell_apart):
		player.model.fell_apart.disconnect(_on_fell_apart)
	_restore_world()
	_overlay.color.a = 0.0
	_caption.visible = false


func _process(delta: float) -> void:
	if not _active or player.camera == null:
		return
	_elapsed += delta
	var tilt := smoothstep(0.0, 1.0, (_elapsed - _collapse_at - HEAP_TILT_START) / HEAP_TILT_TIME)
	var look := _feet + Vector3.UP * lerpf(LOOK_HEIGHT, HEAP_LOOK_HEIGHT, tilt)
	var creep := ease(clampf(_elapsed / DOLLY_TIME, 0.0, 1.0), 0.6) * DOLLY
	var from := _camera_position() - _facing * creep
	# Never inside a wall: swept out from over the body, stopping short.
	var over := _feet + Vector3.UP * CAMERA_HEIGHT
	from = over.lerp(from, player.reach_toward(over, from))
	player.camera.global_transform = Transform3D(Basis.looking_at(look - from, Vector3.UP), from)


func _camera_position() -> Vector3:
	return _feet + _facing * CAMERA_DISTANCE + Vector3.UP * CAMERA_HEIGHT


# --- Steps --------------------------------------------------------------------

func _go_dark() -> void:
	RenderingServer.global_shader_parameter_set(&"world_light", 0.0)
	var env := player.get_world_3d().environment
	if env:
		_saved_env = {
			"ambient_light_energy": env.ambient_light_energy,
			"background_energy_multiplier": env.background_energy_multiplier,
			"fog_light_energy": env.fog_light_energy,
		}
		for key: String in _saved_env:
			env.set(key, 0.0)
	for light in get_tree().root.find_children("*", "Light3D", true, false):
		_saved_lights[light] = (light as Light3D).light_energy
		(light as Light3D).light_energy = 0.0
	for label in get_tree().get_nodes_in_group(&"debug_labels"):
		if label.visible:
			label.visible = false
			_hidden_labels.append(label)

	player.model.visible = true
	_spot = SpotLight3D.new()
	_spot.light_color = Color(1.0, 0.95, 0.85)
	_spot.light_energy = 0.0
	_spot.spot_range = (SPOT_HEIGHT + SPOT_FORWARD) * 2.0
	_spot.spot_angle = SPOT_ANGLE
	_spot.spot_angle_attenuation = 0.4
	_spot.shadow_enabled = true
	player.get_parent().add_child(_spot)
	_spot.global_position = _feet + Vector3.UP * SPOT_HEIGHT + _facing * SPOT_FORWARD
	var side := Basis(Vector3.UP, player.yaw) * SPOT_START_OFFSET
	_spot_from = _feet + side
	_aim_spot(0.0)


## The spotlight switches on with a stagey flicker.
func _spot_clunk() -> void:
	var t := _spot.create_tween()
	t.tween_property(_spot, "light_energy", SPOT_ENERGY * 1.4, 0.05)
	t.tween_property(_spot, "light_energy", SPOT_ENERGY * 0.25, 0.06)
	t.tween_property(_spot, "light_energy", SPOT_ENERGY, 0.08)


func _aim_spot(t: float) -> void:
	if _spot == null:
		return
	var target := _spot_from.lerp(_feet + Vector3.UP * 0.8, t)
	_spot.look_at(target, Vector3.FORWARD if absf((target - _spot.global_position).normalized().y) > 0.99 else Vector3.UP)


func _on_fell_apart() -> void:
	var t := create_tween()
	t.tween_interval(CAPTION_DELAY)
	t.tween_callback(_show_caption)
	t.tween_interval(HOLD)
	t.tween_property(_overlay, "color:a", 1.0, FADE_OUT)
	t.tween_callback(finished.emit)
	_tween = t


func _show_caption() -> void:
	var view := _layer.get_viewport().get_visible_rect().size
	_caption.visible = true
	_caption.position = Vector2((view.x - _caption.size.x) * 0.5, view.y * CAPTION_Y)
	_caption.pivot_offset = _caption.size * 0.5
	_caption.scale = Vector2(0.6, 0.6)
	_caption.create_tween().tween_property(_caption, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _restore_world() -> void:
	RenderingServer.global_shader_parameter_set(&"world_light", 1.0)
	var env := player.get_world_3d().environment
	if env:
		for key: String in _saved_env:
			env.set(key, _saved_env[key])
	for light: Variant in _saved_lights:
		if is_instance_valid(light):
			(light as Light3D).light_energy = _saved_lights[light]
	for label in _hidden_labels:
		if is_instance_valid(label):
			label.visible = true
	_saved_env.clear()
	_saved_lights.clear()
	_hidden_labels.clear()
	if _spot:
		_spot.queue_free()
		_spot = null
