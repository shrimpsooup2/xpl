class_name SpeedLines
extends CanvasLayer
## Speed lines (GDD §10.4): streaks at the screen edges racing outward from
## where you're heading, growing with your speed (vertical included, so a
## smashdown's descent streams them). Dashes, smashdown descents, and slam
## bounces kick them up for a moment. Sits over the 3D and under the HUD.
## Off with ViewSettings.speed_lines.

const SHADER := preload("res://src/render/speed_lines.gdshader")
## Lines start just above run speed and are at full strength here (m/s).
const FULL_SPEED := 22.0
## Extra burst on dashes, bounces, and smashdown descents; how fast it fades.
const BURST_DASH := 0.6
const BURST_BOUNCE := 0.7
const BURST_DECAY := 2.0
const SMOOTHING := 10.0

var player: Player

var _rect: ColorRect
var _material := ShaderMaterial.new()
var _amount := 0.0
var _burst := 0.0


func _ready() -> void:
	layer = 2
	_material.shader = SHADER
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	add_child(_rect)
	if player == null:
		player = get_tree().get_first_node_in_group(&"local_player") as Player
	if player:
		player.movement_event.connect(_on_movement_event)


func amount() -> float:
	return _amount


func _process(delta: float) -> void:
	var on := player != null and not player.is_dead and player.view_settings.speed_lines
	var target := 0.0
	if on:
		var p := player.movement_params
		var speed := player.velocity.length()
		target = clampf(inverse_lerp(p.run_speed + 1.0, FULL_SPEED, speed), 0.0, 1.0)
		if player.state.mode == MovementState.Mode.SMASH:
			_burst = maxf(_burst, 0.8)
	_burst = maxf(_burst - BURST_DECAY * delta, 0.0)
	target = clampf(target + _burst, 0.0, 1.0) if on else 0.0
	_amount = lerpf(_amount, target, 1.0 - exp(-SMOOTHING * delta))
	_rect.visible = _amount > 0.01
	if not _rect.visible:
		return
	_material.set_shader_parameter(&"amount", _amount)
	var view := get_viewport().get_visible_rect().size
	var ratio := player.view_settings.pixel_height
	_material.set_shader_parameter(&"pixel", maxf(1.0, roundf(view.y / ratio)) if ratio > 0 else 1.0)
	_aim_at_heading(view)


## Points the lines at where the velocity goes on screen (or away from where
## it comes from, when moving backward).
func _aim_at_heading(view: Vector2) -> void:
	var cam := player.camera
	var v := player.velocity
	if v.length() < 0.5:
		return
	var ahead := v.dot(-cam.global_basis.z) >= 0.0
	var dir := v.normalized() if ahead else -v.normalized()
	# Keep the point well in front of the camera so projection stays sane.
	var forward := -cam.global_basis.z
	dir = (dir + forward * 0.05).normalized()
	var point := cam.unproject_position(cam.global_position + dir * 10.0) / view
	_material.set_shader_parameter(&"focus", point.clamp(Vector2(-2, -2), Vector2(3, 3)))
	_material.set_shader_parameter(&"flow", 1.0 if ahead else -1.0)


func _on_movement_event(e: Dictionary) -> void:
	match e.type:
		&"dash":
			_burst = maxf(_burst, BURST_DASH)
		&"slam_bounce":
			_burst = maxf(_burst, BURST_BOUNCE)
