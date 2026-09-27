extends SceneTree
## Renders the logo: "xtrapartial" in plain Arial-style type, tiny, boxed,
## then blown up blurry and slightly warped. Needs a display (run it normally,
## or under xvfb-run on a headless machine):
##
##   godot --path . --script res://tools/gen_logo.gd
##
## Writes assets/ui/logo_small.png (the tiny original) and assets/ui/logo.png.

const TEXT := "xtrapartial"
const FONT_PATHS := [
	"/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
	"C:/Windows/Fonts/arial.ttf",
	"/Library/Fonts/Arial.ttf",
	"/System/Library/Fonts/Supplemental/Arial.ttf",
]
const FONT_SIZE := 15
const SMALL_SIZE := Vector2i(112, 36)
const BOX := Rect2i(6, 5, 100, 25)  # Thin black frame inside the small image.
const UPSCALE := 6
## Horizontal stretch and a gentle wave, applied after upscaling.
const STRETCH_X := 1.12
const WAVE_PIXELS := 2.0
const WAVE_PERIOD := 420.0

var _viewport: SubViewport
var _frames := 0


func _initialize() -> void:
	var font := FontFile.new()
	var loaded := false
	for path: String in FONT_PATHS:
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

	var label := Label.new()
	label.text = TEXT
	var settings := LabelSettings.new()
	settings.font = font
	settings.font_size = FONT_SIZE
	settings.font_color = Color(0.08, 0.08, 0.08)
	label.label_settings = settings
	label.position = Vector2(BOX.position.x + 7, BOX.position.y + 2)
	_viewport.add_child(label)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 4:
		return false
	var small := _viewport.get_texture().get_image()
	small.convert(Image.FORMAT_RGB8)
	_frame(small, BOX, Color.BLACK)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui"))
	small.save_png("res://assets/ui/logo_small.png")

	var big := small.duplicate() as Image
	big.resize(roundi(SMALL_SIZE.x * UPSCALE * STRETCH_X), SMALL_SIZE.y * UPSCALE, Image.INTERPOLATE_BILINEAR)
	var warped := _wave(big)
	warped.save_png("res://assets/ui/logo.png")
	print("saved logo_small.png %s and logo.png %s" % [small.get_size(), warped.get_size()])
	return true


func _frame(img: Image, r: Rect2i, c: Color) -> void:
	for x in range(r.position.x, r.end.x):
		img.set_pixel(x, r.position.y, c)
		img.set_pixel(x, r.end.y - 1, c)
	for y in range(r.position.y, r.end.y):
		img.set_pixel(r.position.x, y, c)
		img.set_pixel(r.end.x - 1, y, c)


## Shifts each row sideways along a slow sine, like a nudged scan.
func _wave(src: Image) -> Image:
	var w := src.get_width()
	var h := src.get_height()
	var out := Image.create_empty(w, h, false, Image.FORMAT_RGB8)
	out.fill(Color.WHITE)
	for y in h:
		var shift := sin(y / WAVE_PERIOD * TAU) * WAVE_PIXELS
		for x in w:
			var sx := x - shift
			var x0 := clampi(floori(sx), 0, w - 1)
			var x1 := clampi(x0 + 1, 0, w - 1)
			out.set_pixel(x, y, src.get_pixel(x0, y).lerp(src.get_pixel(x1, y), sx - floorf(sx)))
	return out
