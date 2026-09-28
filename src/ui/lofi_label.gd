class_name LofiLabel
extends TextureRect
## Text in the logo's style: plain Arial-style type rendered tiny on a white
## card inside a thin, slightly crooked black frame (PaperBox), then shown
## blown up and blurry (GDD §13.2).

const FONT := preload("res://assets/fonts/LiberationSans-Regular.ttf")
const PADDING := Vector2i(9, 6)

@export var text := "":
	set(value):
		text = value
		_refresh()
@export var font_size := 13:
	set(value):
		font_size = value
		_refresh()
## Screen pixels per rendered pixel.
@export var upscale := 5.0:
	set(value):
		upscale = value
		_refresh()

var _viewport: SubViewport
var _frame: Panel
var _label: Label


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_viewport = SubViewport.new()
	_viewport.disable_3d = true
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	_frame = Panel.new()
	var style := PaperBox.new()
	style.margin = 3.0
	style.wobble = 0.8
	style.hand = randi()
	_frame.add_theme_stylebox_override(&"panel", style)
	_viewport.add_child(_frame)

	_label = Label.new()
	var settings := LabelSettings.new()
	settings.font = FONT
	settings.font_color = Color(0.08, 0.08, 0.08)
	_label.label_settings = settings
	_viewport.add_child(_label)

	texture = _viewport.get_texture()
	_refresh()


func _refresh() -> void:
	if _label == null:
		return
	_label.text = text
	_label.label_settings.font_size = font_size
	var text_size := Vector2i(FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).ceil())
	var px := text_size + PADDING * 2
	_viewport.size = px
	_frame.size = px
	_label.position = Vector2(PADDING)
	custom_minimum_size = Vector2(px) * upscale
	size = custom_minimum_size
