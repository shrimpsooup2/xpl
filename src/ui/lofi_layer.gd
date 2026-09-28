class_name LofiLayer
extends CanvasLayer
## A low-resolution UI canvas, blown up soft like the logo. Everything added
## under `canvas` is laid out at roughly 270 px tall and scaled up with
## smooth filtering, so the whole interface shares the logo's look.
##
## Mouse input only reaches the canvas while `interactive` is on (menus);
## otherwise it passes straight through to the game.

## Target canvas height; the actual scale is the nearest whole number.
const CANVAS_HEIGHT := 270.0

var canvas: Control
var interactive := false:
	set(value):
		interactive = value
		if _container:
			_container.mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE

var _container: SubViewportContainer
var _viewport: SubViewport


func _ready() -> void:
	_container = SubViewportContainer.new()
	_container.stretch = true
	_container.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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


## Canvas pixels per screen pixel.
func scale_factor() -> int:
	return _container.stretch_shrink


func _fit() -> void:
	var height := get_viewport().get_visible_rect().size.y
	_container.stretch_shrink = maxi(1, roundi(height / CANVAS_HEIGHT))
