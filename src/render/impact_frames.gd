class_name ImpactFrames
extends CanvasLayer
## Experimental, off by default (ViewSettings.impact_frames). On a kill or
## a hard smashdown the screen is redrawn for a beat or two as stark two-tone ink with speed
## lines bursting from the hit, like an anime impact frame: a negative beat,
## then (for big hits) a positive one, then straight back. Each beat jolts
## off-centre, and `fired` lets the camera punch and the UI kick with it.
##
## Visual only. The game keeps running underneath: it's multiplayer, so
## there's no hit-stop (GDD §10.4). Anything can fire one through
## ImpactFrames.hit(); the local player's view settings decide whether it
## shows. Spaced at least MIN_GAP apart so it never strobes (GDD §10.6).

## An impact frame actually showed (the camera and UI react to this).
signal fired(strength: float, point: Vector2)

const GROUP := &"impact_frames"
const SHADER := preload("res://src/render/impact_frames.gdshader")
## Length of one beat. Each beat is also shown for at least one full frame.
const BEAT := 0.05
## Hits at or above this get the second, positive beat.
const BIG := 0.6
## Each beat is knocked off-centre by up to this many pixels, so the held
## frames jolt against each other.
const JOLT := 14.0
const MIN_GAP := 0.5

var settings: ViewSettings

var _rect: ColorRect
var _material := ShaderMaterial.new()
var _beats: Array[bool] = []  # negative?, per beat still to show.
var _strength := 0.0
var _beat_time := 0.0
var _beat_frames := 0
var _clock := 0.0
var _last := -INF


## Fires an impact frame on every view that has them switched on.
## strength 0..1; point is the hit in screen UV; paper tints the light tone
## (heart pink for heartshots).
static func hit(tree: SceneTree, strength: float, point := Vector2(0.5, 0.5), paper := Color.WHITE) -> void:
	tree.call_group(GROUP, &"trigger", strength, point, paper)


func _ready() -> void:
	layer = 6  # Over the HUD, so the boxes go two-tone too.
	add_to_group(GROUP)
	_material.shader = SHADER
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	_rect.visible = false
	add_child(_rect)


func trigger(strength: float, point := Vector2(0.5, 0.5), paper := Color.WHITE) -> void:
	if settings == null or not settings.impact_frames or strength <= 0.0:
		return
	if _clock - _last < MIN_GAP:
		return
	_last = _clock
	strength = clampf(strength, 0.0, 1.0)
	_material.set_shader_parameter(&"center", point)
	_material.set_shader_parameter(&"paper", paper)
	_material.set_shader_parameter(&"seed", randf() * 100.0)
	_material.set_shader_parameter(&"lines", lerpf(0.06, 0.16, strength))
	_strength = strength
	_beats.assign([true, false] if strength >= BIG else [true])
	_start_beat()
	fired.emit(strength, point)


## True while a frame is showing.
func is_showing() -> bool:
	return _rect.visible


func _process(delta: float) -> void:
	_clock += delta
	if _beats.is_empty():
		return
	_beat_time -= delta
	_beat_frames += 1
	if _beat_time <= 0.0 and _beat_frames >= 2:
		_beats.pop_front()
		if _beats.is_empty():
			_rect.visible = false
		else:
			_start_beat()


func _start_beat() -> void:
	_material.set_shader_parameter(&"negative", _beats[0])
	_material.set_shader_parameter(&"jolt", Vector2.from_angle(randf() * TAU) * JOLT * _strength)
	_beat_time = BEAT
	_beat_frames = 0
	_rect.visible = true
