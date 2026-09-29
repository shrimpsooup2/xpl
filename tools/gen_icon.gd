extends SceneTree
## Renders the icon: the logo's look (tools/gen_logo.gd) squared up, "xpl"
## in plain Arial-style type, tiny, boxed, then blown up blurry and slightly
## warped. Needs a display (run it normally, or under xvfb-run on a headless
## machine):
##
##   godot --path . --script res://tools/gen_icon.gd
##
## Writes assets/ui/icon_small.png (the tiny original) and assets/ui/icon.png
## (the website's favicon).

const Logo := preload("res://tools/gen_logo.gd")
const TEXT := "xpl"
const SMALL_SIZE := Vector2i(32, 32)
const BOX := Rect2i(2, 2, 28, 28)  # Thin black frame inside the small image.
const UPSCALE := 6

var _viewport: SubViewport
var _frames := 0


func _initialize() -> void:
	var font := FontFile.new()
	var loaded := false
	for path: String in Logo.FONT_PATHS:
		if FileAccess.file_exists(path) and font.load_dynamic_font(path) == OK:
			loaded = true
			print("font: ", path)
			break
	if not loaded:
		push_error("No Arial or Liberation Sans found.")
		quit(1)
		return

	_viewport = SubViewport.new()
	_viewport.size = SMALL_SIZE
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)

	var bg := ColorRect.new()
	bg.color = Color.WHITE
	bg.size = SMALL_SIZE
	_viewport.add_child(bg)

	# Centred in the frame, the logo's size of type.
	var label := Label.new()
	label.text = TEXT
	var settings := LabelSettings.new()
	settings.font = font
	settings.font_size = Logo.FONT_SIZE
	settings.font_color = Color(0.08, 0.08, 0.08)
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = BOX.position
	label.size = BOX.size
	_viewport.add_child(label)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 4:
		return false
	var small := _viewport.get_texture().get_image()
	small.convert(Image.FORMAT_RGB8)
	Logo.frame(small, BOX, Color.BLACK)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui"))
	small.save_png("res://assets/ui/icon_small.png")

	var big := small.duplicate() as Image
	big.resize(SMALL_SIZE.x * UPSCALE, SMALL_SIZE.y * UPSCALE, Image.INTERPOLATE_BILINEAR)
	var warped := Logo.wave(big)
	warped.save_png("res://assets/ui/icon.png")
	print("saved icon_small.png %s and icon.png %s" % [small.get_size(), warped.get_size()])
	return true
