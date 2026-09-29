class_name LofiLayer
extends CanvasLayer
## A low-resolution UI canvas, blown up soft like the logo. Everything added
## under `canvas` is laid out at roughly 270 px tall and scaled up with
## smooth filtering, so the whole interface shares the logo's look.
##
## Mouse input only reaches the canvas while `interactive` is on (menus);
## otherwise it passes straight through to the game.
##
## The blow-up goes through lofi_layer.gdshader: a faint idle warp, and
## kick() for impacts, which shakes, punches, and warps the whole UI.

const GROUP := &"lofi_layer"
const SHADER := preload("res://src/ui/lofi_layer.gdshader")
## Target canvas height; the actual scale is the nearest whole number.
const CANVAS_HEIGHT := 270.0
## Idle warp in canvas pixels.
const WARP := 0.3
## A full-strength kick: shake (canvas px), punch (zoom), extra warp.
const KICK_SHAKE := 3.0
const KICK_ZOOM := 0.035
const KICK_WARP := 1.6
## How fast a kick dies away (strength per second): (snappy, smooth).
const KICK_DECAY := Vector2(6.0, 3.5)

var canvas: Control
var interactive := false:
	set(value):
		interactive = value
		if _container:
			_container.mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE

var _container: SubViewportContainer
var _viewport: SubViewport
var _material := ShaderMaterial.new()
var _kick := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	_container = SubViewportContainer.new()
	_container.stretch = true
	_container.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_material.shader = SHADER
	_container.material = _material
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_container)
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.gui_embed_subwindows = true
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	_container.add_child(_viewport)
	canvas = Control.new()
	canvas.name = "Canvas"
	canvas.theme = LofiUI.theme()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(canvas)
	interactive = interactive
	get_viewport().size_changed.connect(_fit)
	_fit()


func _process(delta: float) -> void:
	_kick = maxf(_kick - lerpf(KICK_DECAY.x, KICK_DECAY.y, LofiUI.smoothing) * delta, 0.0)
	var k := _kick * _kick
	var shake := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * KICK_SHAKE * k
	_material.set_shader_parameter(&"offset", shake)
	_material.set_shader_parameter(&"zoom", 1.0 + KICK_ZOOM * k)
	_material.set_shader_parameter(&"warp", (WARP + KICK_WARP * k) * LofiUI.motion)


## Shakes, punches, and warps the whole layer; strength 1 is a big hit.
## Every layer is kicked at once through LofiUI.kick().
func kick(strength := 0.5) -> void:
	_kick = maxf(_kick, clampf(strength * LofiUI.motion, 0.0, 1.0))


## Canvas pixels per screen pixel.
func scale_factor() -> int:
	return _container.stretch_shrink


func _fit() -> void:
	var height := get_viewport().get_visible_rect().size.y
	_container.stretch_shrink = maxi(1, roundi(height / CANVAS_HEIGHT))
