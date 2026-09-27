extends SceneTree
## Generates the placeholder surface textures in assets/textures/.
##
##   godot --headless --path . --script res://tools/gen_textures.gd
##
## Small, point-filtered, hand-pixel style: 64×64 with a limited palette,
## bevels, grout, and noise. Deterministic (fixed seed), so re-running gives
## the same files. Paint over the PNGs freely; only re-run to start over.

const SIZE := 64
const OUT := "res://assets/textures/"

var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_save(_floor_tiles(), "floor_tiles")
	_save(_wall_panels(), "wall_panels")
	_save(_ride_tiles(), "ride_tiles")
	_save(_tread_plate(), "tread_plate")
	_save(_bricks(), "bricks")
	_save(_bathroom_tiles(), "bathroom_tiles")
	_save(_hazard(), "hazard")
	_save(_reflection_map(), "reflection_map")
	quit()


func _save(img: Image, file: String) -> void:
	var err := img.save_png(OUT + file + ".png")
	print("%s.png: %s" % [file, error_string(err)])


func _new(base: Color) -> Image:
	rng.seed = hash(base)
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGB8)
	img.fill(base)
	return img


func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), c)


## Random per-pixel brightness jitter.
func _speckle(img: Image, amount: float) -> void:
	for y in SIZE:
		for x in SIZE:
			var c := img.get_pixel(x, y)
			var j := rng.randf_range(-amount, amount)
			img.set_pixel(x, y, Color(c.r + j, c.g + j, c.b + j))


## Light top/left edge and dark bottom/right edge inside a rectangle.
func _bevel(img: Image, r: Rect2i, light: float, dark: float, width := 1) -> void:
	for i in width:
		for x in range(r.position.x + i, r.end.x - i):
			_mul(img, x, r.position.y + i, light)
			_mul(img, x, r.end.y - 1 - i, dark)
		for y in range(r.position.y + i + 1, r.end.y - i - 1):
			_mul(img, r.position.x + i, y, light)
			_mul(img, r.end.x - 1 - i, y, dark)


func _mul(img: Image, x: int, y: int, f: float) -> void:
	var c := img.get_pixel(x % SIZE, y % SIZE)
	img.set_pixel(x % SIZE, y % SIZE, Color(c.r * f, c.g * f, c.b * f))


func _vary(c: Color, amount: float) -> Color:
	var j := rng.randf_range(-amount, amount)
	return Color(c.r + j, c.g + j * 0.8, c.b + j * 0.9)


# --- Textures -----------------------------------------------------------------

## Big warm-grey floor tiles, 2×2 per texture.
func _floor_tiles() -> Image:
	var base := Color(0.56, 0.52, 0.50)
	var img := _new(base)
	for ty in 2:
		for tx in 2:
			var r := Rect2i(tx * 32, ty * 32, 32, 32)
			_rect(img, r.position.x, r.position.y, 32, 32, _vary(base, 0.04))
			_bevel(img, r, 1.22, 0.72)
	_speckle(img, 0.025)
	for i in 6:  # Stains.
		var cx := rng.randi_range(0, SIZE - 1)
		var cy := rng.randi_range(0, SIZE - 1)
		for dy in range(-2, 3):
			for dx in range(-3, 4):
				if rng.randf() < 0.6:
					_mul(img, cx + dx + SIZE, cy + dy + SIZE, 0.88)
	for x in SIZE:  # Grout.
		img.set_pixel(x, 0, Color(0.22, 0.20, 0.22))
		img.set_pixel(x, 32, Color(0.22, 0.20, 0.22))
	for y in SIZE:
		img.set_pixel(0, y, Color(0.22, 0.20, 0.22))
		img.set_pixel(32, y, Color(0.22, 0.20, 0.22))
	return img


## Riveted metal wall panels, two per texture, with grime streaks.
func _wall_panels() -> Image:
	var base := Color(0.50, 0.49, 0.60)
	var img := _new(base)
	for py in 2:
		var r := Rect2i(0, py * 32, SIZE, 32)
		_rect(img, 0, py * 32, SIZE, 32, _vary(base, 0.03))
		_bevel(img, r, 1.3, 0.6, 2)
		for p: Vector2i in [Vector2i(4, 4), Vector2i(58, 4), Vector2i(4, 26), Vector2i(58, 26)]:
			var at := p + Vector2i(0, py * 32)
			_rect(img, at.x, at.y, 2, 2, Color(0.80, 0.80, 0.88))
			img.set_pixel(at.x + 1, at.y + 1, Color(0.25, 0.24, 0.32))
	for i in 10:  # Vertical grime.
		var x := rng.randi_range(2, SIZE - 3)
		var top := rng.randi_range(0, SIZE - 1)
		var length := rng.randi_range(6, 24)
		for y in length:
			_mul(img, x, top + y, lerpf(0.82, 1.0, float(y) / length))
	_speckle(img, 0.02)
	return img


## Glossy aqua tiles with a dark rail band: the "you can wall ride this" surface.
func _ride_tiles() -> Image:
	var base := Color(0.26, 0.68, 0.76)
	var grout := Color(0.10, 0.30, 0.36)
	var img := _new(base)
	for ty in 8:
		for tx in 8:
			var r := Rect2i(tx * 8, ty * 8, 8, 8)
			_rect(img, r.position.x, r.position.y, 8, 8, _vary(base, 0.035))
			_bevel(img, r, 1.25, 0.8)
			img.set_pixel(r.position.x + 1, r.position.y + 1, Color(0.85, 1.0, 1.0))
	for x in SIZE:
		for y in SIZE:
			if x % 8 == 0 or y % 8 == 0:
				img.set_pixel(x, y, grout)
	for y in range(28, 36):  # Rail band.
		for x in SIZE:
			var stripe := (x + y) % 8 < 4
			img.set_pixel(x, y, Color(0.08, 0.18, 0.24) if stripe else Color(0.12, 0.26, 0.32))
	for x in SIZE:
		img.set_pixel(x, 27, Color(0.9, 0.95, 0.4))
		img.set_pixel(x, 36, Color(0.9, 0.95, 0.4))
	return img


## Diamond tread plate for ramps and slopes.
func _tread_plate() -> Image:
	var base := Color(0.44, 0.58, 0.54)
	var img := _new(base)
	_speckle(img, 0.02)
	for cy in range(0, SIZE, 8):
		for cx in range(0, SIZE, 8):
			var ox := 4 if (cy / 8) % 2 == 1 else 0
			var x := cx + ox
			for i in 4:  # A short diagonal bump: light edge, dark edge.
				img.set_pixel((x + i) % SIZE, (cy + i) % SIZE, Color(0.72, 0.86, 0.80))
				img.set_pixel((x + i + 1) % SIZE, (cy + i) % SIZE, Color(0.24, 0.34, 0.32))
	return img


## Running-bond bricks for ledges.
func _bricks() -> Image:
	var mortar := Color(0.78, 0.72, 0.66)
	var brick := Color(0.78, 0.46, 0.36)
	var img := _new(mortar)
	for row in 8:
		var offset := 8 if row % 2 == 1 else 0
		for col in 5:
			var x := col * 16 - offset
			var r := Rect2i(x + 1, row * 8 + 1, 15, 7)
			var c := _vary(brick, 0.06)
			for py in range(r.position.y, r.end.y):
				for px in range(r.position.x, r.end.x):
					img.set_pixel((px + SIZE) % SIZE, py, c)
			for px in range(r.position.x, r.end.x):
				_mul(img, (px + SIZE) % SIZE, r.position.y, 1.18)
				_mul(img, (px + SIZE) % SIZE, r.end.y - 1, 0.78)
	_speckle(img, 0.03)
	return img


## Small glossy pink bathroom tiles.
func _bathroom_tiles() -> Image:
	var base := Color(0.90, 0.58, 0.70)
	var img := _new(Color(0.96, 0.92, 0.94))
	for ty in 4:
		for tx in 4:
			var r := Rect2i(tx * 16 + 1, ty * 16 + 1, 15, 15)
			_rect(img, r.position.x, r.position.y, 15, 15, _vary(base, 0.04))
			_bevel(img, r, 1.15, 0.78)
			_rect(img, r.position.x + 2, r.position.y + 2, 2, 1, Color(1, 0.95, 0.98))
			img.set_pixel(r.position.x + 2, r.position.y + 3, Color(1, 0.95, 0.98))
	_speckle(img, 0.015)
	return img


## Black and yellow hazard stripes.
func _hazard() -> Image:
	var img := _new(Color.BLACK)
	for y in SIZE:
		for x in SIZE:
			var yellow := ((x + y) / 8) % 2 == 0
			img.set_pixel(x, y, Color(0.95, 0.78, 0.12) if yellow else Color(0.10, 0.09, 0.12))
	_speckle(img, 0.03)
	return img


## Sphere-map "environment" for fake glossy reflections: a lavender sky,
## a hot horizon band, a dark floor, a sun, and two bright windows.
## Deliberately posterized to a few bands.
func _reflection_map() -> Image:
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGB8)
	img.fill(Color(0.10, 0.07, 0.14))
	var sun := Vector3(0.45, 0.55, 0.70).normalized()
	for py in SIZE:
		for px in SIZE:
			var x := (px + 0.5) / SIZE * 2.0 - 1.0
			var y := 1.0 - (py + 0.5) / SIZE * 2.0
			var d2 := x * x + y * y
			if d2 > 1.0:
				continue
			var n := Vector3(x, y, sqrt(1.0 - d2))
			var r := Vector3(2.0 * n.z * n.x, 2.0 * n.z * n.y, 2.0 * n.z * n.z - 1.0)
			var c: Color
			if r.y > 0.25:
				c = Color(0.62, 0.56, 0.86).lerp(Color(0.90, 0.84, 1.0), r.y)
			elif r.y > 0.0:
				c = Color(1.0, 0.62, 0.52)
			elif r.y > -0.2:
				c = Color(0.45, 0.28, 0.44)
			else:
				c = Color(0.12, 0.08, 0.16)
			if r.dot(sun) > 0.93:
				c = Color(1.0, 0.97, 0.85)
			var wx := r.x * 3.0
			if r.y > 0.3 and r.y < 0.6 and (absf(wx - 1.2) < 0.35 or absf(wx + 0.9) < 0.25):
				c = c.lerp(Color.WHITE, 0.7)
			c = Color(snappedf(c.r, 0.125), snappedf(c.g, 0.125), snappedf(c.b, 0.125))
			img.set_pixel(px, py, c)
	return img
