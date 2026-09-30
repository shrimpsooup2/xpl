extends SceneTree
## Renders the player for the website: the real body, hanging upside down
## by its feet, arms dangling, on a clear background ->
## site/assets/figure.png (site/site.js swings it from the top of the
## screen).
##
##   xvfb-run -a godot --path . --rendering-driver opengl3 \
##       --resolution 512x768 --script res://tools/gen_site_figure.gd
##
## Needs a real renderer (not --headless).

const OUT := "res://site/assets/figure.png"
## How much of the view the figure fills (metres across the frame's height).
const FRAME_HEIGHT := 2.5
## The arms lifted over the head (so, upside down, they hang), this far
## off straight up.
const ARM_SPREAD := deg_to_rad(5.0)

var _frame := 0
var _model: PlayerModel


func _initialize() -> void:
	root.transparent_bg = true
	var world := Node3D.new()
	root.add_child(world)

	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.58, 0.68)
	env.environment.ambient_light_energy = 0.6
	world.add_child(env)

	# Light from over the viewer's shoulder, as the page sees it: the figure
	# is upside down, so "up" on the page is down in the world.
	var key := DirectionalLight3D.new()
	key.light_energy = 1.1
	key.light_color = Color(1.0, 0.96, 0.92)
	world.add_child(key)
	key.look_at_from_position(Vector3(-1.5, -2.0, 3.0), Vector3.ZERO)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.25
	fill.light_color = Color(1.0, 0.7, 0.8)  # The page's maroon, from below.
	world.add_child(fill)
	fill.look_at_from_position(Vector3(1.0, 2.0, 1.5), Vector3.ZERO)

	_model = PlayerModel.new()
	world.add_child(_model)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = FRAME_HEIGHT
	cam.position = Vector3(0, 0, 6)
	world.add_child(cam)
	cam.current = true


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 2:
		# Hang it: feet up and facing the camera (it faces -z; turned over
		# end to end, +z), centred on its middle.
		_model.anim.stop()
		_model.skeleton.reset_bone_poses()
		_model.layers.active = false
		_model.global_transform = Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, 0.7, 0))
		for side in ["L", "R"]:
			_raise_arm(side)
	if _frame == 8:
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img = _cropped(img)
		img.save_png(OUT)
		print("figure: ", img.get_size(), " -> ", OUT)
		return true
	return false


## Swings an upper arm up beside the head, in the body's front plane.
func _raise_arm(side: String) -> void:
	var sk := _model.skeleton
	var bone := sk.find_bone("DEF-upper_arm." + side)
	var elbow := sk.find_bone("DEF-forearm." + side)
	var parent := sk.get_bone_parent(bone)
	var here := sk.get_bone_global_pose(bone)
	var arm := sk.get_bone_global_pose(elbow).origin - here.origin
	var out := signf(arm.x)
	var want := Vector3(out * sin(ARM_SPREAD), cos(ARM_SPREAD), 0.0)
	var turn := Quaternion(Vector3(arm.x, arm.y, 0.0).normalized(), want)
	var parent_rot := sk.get_bone_global_pose(parent).basis.get_rotation_quaternion()
	var global_rot := turn * here.basis.get_rotation_quaternion()
	sk.set_bone_pose_rotation(bone, parent_rot.inverse() * global_rot)


## Trimmed to what's drawn, with a pixel to spare.
func _cropped(img: Image) -> Image:
	var used := img.get_used_rect().grow(1).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	return img.get_region(used)
