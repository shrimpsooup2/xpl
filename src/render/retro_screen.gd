extends CanvasLayer
## Applies the look settings from the local player's ViewSettings:
## renders 3D at a low internal resolution with nearest-neighbour upscaling,
## then runs the colour-depth and dither pass. Sits below the HUD layers so
## text stays sharp.

var _rect: ColorRect
var _material: ShaderMaterial
var _settings: ViewSettings
var _applied_factor := -1


func _ready() -> void:
	layer = 1
	_material = ShaderMaterial.new()
	_material.shader = preload("res://src/render/retro_screen.gdshader")
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	add_child(_rect)
	var player := get_tree().get_first_node_in_group(&"local_player") as Player
	_settings = player.view_settings if player else load("res://data/view_settings.tres")


func _process(_delta: float) -> void:
	var viewport := get_viewport()
	var factor := 1
	if _settings.pixel_height > 0:
		factor = maxi(1, roundi(viewport.get_visible_rect().size.y / _settings.pixel_height))
	if factor != _applied_factor:
		_applied_factor = factor
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_NEAREST if factor > 1 else Viewport.SCALING_3D_MODE_BILINEAR
		viewport.scaling_3d_scale = 1.0 / factor
		# Godot sharpens mipmaps when rendering below native resolution;
		# undo that so textures stay as chunky as the pixels.
		viewport.texture_mipmap_bias = log(factor) / log(2.0)
	_rect.visible = _settings.color_levels > 0
	_material.set_shader_parameter(&"pixel_size", float(factor))
	_material.set_shader_parameter(&"color_levels", float(_settings.color_levels))
	_material.set_shader_parameter(&"dither_strength", _settings.dither)
