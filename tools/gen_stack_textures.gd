extends SceneTree
## Generates Stack's textures (the drained rooftop pool, GDD §9.3) into
## assets/textures/stack/:
##
##   godot --headless --path . --script res://tools/gen_stack_textures.gd
##
## Low-res but soft, in the ULTRAKILL / late-90s way: each is painted at 4×
## with layered noise (blotchy colour, grime that gathers low down and in
## the grout, stains), then scaled down, so edges come out as half-tones
## rather than hard lines. Tileable, and deterministic (fixed seeds): re-run
## gives the same files. Paint over the PNGs freely.

const OUT := "res://assets/textures/stack/"
## Painted this many times bigger than saved.
const SS := 4

var _seed := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_save(_pool_tiles(), "pool_tiles")
	_save(_navy_tiles(), "navy_tiles")
	_save(_coping(), "coping")
	_save(_grip(), "grip")
	_save(_concrete(), "concrete")
	_save(_ceiling(), "ceiling")
	_save(_changing_floor(), "changing_floor")
	_save(_changing_wall(), "changing_wall")
	_save(_lockers(), "lockers")
	_save(_rubber_mat(), "rubber_mat")
	_save(_steel(), "steel")
	_save(_facade(), "facade")
	_save(_caustics(), "caustics")
	_save(_water(), "water")
	_save(_no_diving(), "no_diving")
	_save(_wet_floor(), "wet_floor")
	_save(_drain(), "drain")
	_save(_reflection_night(), "reflection_night")
	quit()


func _save(img: Image, file: String) -> void:
	var err := img.save_png(OUT + file + ".png")
	print("%s.png: %s" % [file, error_string(err)])
	# Imported like the other world textures: lossless, with mipmaps (the
	# surface shader filters nearest between mip levels).
	var import_path := OUT + file + ".png.import"
	if not FileAccess.file_exists(import_path):
		var f := FileAccess.open(import_path, FileAccess.WRITE)
		f.store_string("[remap]\n\nimporter=\"texture\"\ntype=\"CompressedTexture2D\"\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=true\ndetect_3d/compress_to=0\n")


# --- Noise (tileable) ------------------------------------------------------------------

func _hash(x: int, y: int, period: int) -> float:
	var h := hash(Vector3i(posmod(x, period), posmod(y, period), _seed))
	return float(h & 0xffff) / 65535.0


## Smooth value noise over a `period`-cell lattice that wraps.
func _noise(x: float, y: float, period: int) -> float:
	var xi := floori(x)
	var yi := floori(y)
	var fx := x - xi
	var fy := y - yi
	var u := fx * fx * (3.0 - 2.0 * fx)
	var v := fy * fy * (3.0 - 2.0 * fy)
	var a := _hash(xi, yi, period)
	var b := _hash(xi + 1, yi, period)
	var c := _hash(xi, yi + 1, period)
	var d := _hash(xi + 1, yi + 1, period)
	return lerpf(lerpf(a, b, u), lerpf(c, d, u), v)


## Layered noise in 0..1 at (tx, ty) in 0..1 texture space, starting at
## `cells` across and doubling each octave.
func _fbm(tx: float, ty: float, cells: int, octaves := 4) -> float:
	var sum := 0.0
	var amp := 0.5
	var total := 0.0
	var n := cells
	for o in octaves:
		sum += _noise(tx * n, ty * n, n) * amp
		total += amp
		amp *= 0.5
		n *= 2
	return sum / total


# --- Painting ------------------------------------------------------------------------

## A blank canvas `size` pixels (saved size) across, painted at SS×.
func _canvas(w: int, h: int, seed_text: String) -> Image:
	_seed = hash(seed_text)
	return Image.create_empty(w * SS, h * SS, false, Image.FORMAT_RGB8)


## Scales the painting down to its saved size by halving, so every saved
## pixel is an average of the ones under it.
func _finish(img: Image, w: int, h: int) -> Image:
	while img.get_width() > w:
		img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	return img


## Fills with `paint(tx, ty) -> Color` over 0..1 texture space.
func _paint(img: Image, paint: Callable) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			img.set_pixel(x, y, paint.call((x + 0.5) / w, (y + 0.5) / h))


## Where (tx, ty) falls in a grid of `cols` × `rows` tiles: the tile's index,
## and how far it is from the nearest grout line (0 at the grout, in tile
## widths).
func _cell(tx: float, ty: float, cols: float, rows: float) -> Array:
	var gx := tx * cols
	var gy := ty * rows
	var ix := floori(gx)
	var iy := floori(gy)
	var fx := gx - ix
	var fy := gy - iy
	return [ix, iy, minf(minf(fx, 1.0 - fx), minf(fy, 1.0 - fy))]


## Dirt: `c` darkened and shifted toward `toward` where the noise says so.
func _dirty(c: Color, amount: float, toward: Color) -> Color:
	return c.lerp(toward, clampf(amount, 0.0, 1.0))


## Soft grout: 1 at the tile's middle, falling off into the grout line.
func _grout_mask(edge: float, width: float) -> float:
	return smoothstep(width * 0.4, width * 1.6, edge)


# --- The pool ------------------------------------------------------------------------

## Small white-aqua pool tiles (8 × 8 a repeat), each a slightly different
## shade, the grout gone green-grey, algae and tide marks where the water
## stood.
func _pool_tiles() -> Image:
	var img := _canvas(64, 64, "pool_tiles")
	_paint(img, func(tx: float, ty: float) -> Color:
		var cell := _cell(tx, ty, 8, 8)
		var shade := _hash(cell[0], cell[1], 8)
		var base := Color(0.74, 0.88, 0.90).lerp(Color(0.62, 0.80, 0.84), shade * 0.6)
		var blotch := _fbm(tx, ty, 4)
		base = base.darkened((blotch - 0.5) * 0.18)
		var grout := Color(0.40, 0.52, 0.52)
		var c := grout.lerp(base, _grout_mask(cell[2], 0.06))
		# Algae and a tide line: greenish grime in bands and blotches.
		var algae := smoothstep(0.55, 0.8, _fbm(tx + 0.3, ty * 0.6, 3, 5))
		c = _dirty(c, algae * 0.45, Color(0.36, 0.46, 0.34))
		var glint := 1.0 - smoothstep(0.0, 0.08, Vector2(fmod(tx * 8.0, 1.0) - 0.22, fmod(ty * 8.0, 1.0) - 0.22).length())
		return c.lightened(glint * 0.25))
	return _finish(img, 64, 64)


## Deep navy tiles for the diving blocks, faded and chalky.
func _navy_tiles() -> Image:
	var img := _canvas(64, 64, "navy_tiles")
	_paint(img, func(tx: float, ty: float) -> Color:
		var cell := _cell(tx, ty, 8, 8)
		var base := Color(0.14, 0.20, 0.38).lerp(Color(0.18, 0.26, 0.46), _hash(cell[0], cell[1], 8))
		base = base.lightened((_fbm(tx, ty, 4) - 0.4) * 0.25)
		var c := Color(0.44, 0.50, 0.58).lerp(base, _grout_mask(cell[2], 0.07))
		return _dirty(c, smoothstep(0.6, 0.85, _fbm(tx, ty, 3, 5)) * 0.35, Color(0.50, 0.54, 0.56)))
	return _finish(img, 64, 64)


## Pale stone coping for the pool's rim: mottled, joints every metre.
func _coping() -> Image:
	var img := _canvas(64, 64, "coping")
	_paint(img, func(tx: float, ty: float) -> Color:
		var c := Color(0.80, 0.78, 0.72).darkened((_fbm(tx, ty, 6, 5) - 0.5) * 0.3)
		var joint := minf(fmod(tx * 2.0, 1.0), 1.0 - fmod(tx * 2.0, 1.0))
		c = c.darkened((1.0 - smoothstep(0.0, 0.02, joint)) * 0.35)
		return _dirty(c, smoothstep(0.6, 0.9, _fbm(tx + 0.5, ty, 2, 4)) * 0.3, Color(0.46, 0.44, 0.40)))
	return _finish(img, 64, 64)


## Blue-grey non-slip grit for the blocks' tops, worn paler where people
## stood.
func _grip() -> Image:
	var img := _canvas(64, 64, "grip")
	_paint(img, func(tx: float, ty: float) -> Color:
		var grit := _hash(floori(tx * 256.0), floori(ty * 256.0), 256)
		var c := Color(0.32, 0.38, 0.48).lightened((grit - 0.5) * 0.25)
		return c.lightened(smoothstep(0.5, 0.8, _fbm(tx, ty, 3)) * 0.15))
	return _finish(img, 64, 64)


## Caustics: soft bright cell edges on black, tileable (drawn twice,
## scrolling, by the surface shader). Painted at saved size, then blurred.
func _caustics() -> Image:
	_seed = hash("caustics")
	var size := 64
	# One point per cell of a 4 × 4 grid, jittered: no two bunch up.
	var points: Array[Vector2] = []
	for j in 4:
		for i in 4:
			points.append(Vector2((i + 0.2 + _hash(i, j, 4) * 0.6) * size / 4.0, (j + 0.2 + _hash(i + 7, j + 3, 4) * 0.6) * size / 4.0))
	var img := Image.create_empty(size * 2, size * 2, false, Image.FORMAT_RGB8)
	for y in size * 2:
		for x in size * 2:
			var p := Vector2(x + 0.5, y + 0.5) * 0.5
			var d1 := 1e9
			var d2 := 1e9
			for q in points:
				for oy in [-size, 0, size]:
					for ox in [-size, 0, size]:
						var d := p.distance_to(q + Vector2(ox, oy))
						if d < d1:
							d2 = d1
							d1 = d
						elif d < d2:
							d2 = d
			var v := pow(clampf(1.0 - (d2 - d1) / 4.0, 0.0, 1.0), 2.2)
			img.set_pixel(x, y, Color(v, v, v))
	return _finish(img, size, size)


## Falling water: soft vertical streaks (the water shader's mask).
func _water() -> Image:
	var img := _canvas(32, 64, "water")
	_paint(img, func(tx: float, ty: float) -> Color:
		var streak := _noise(tx * 16.0, ty * 1.5, 16) * 0.6 + _noise(tx * 32.0, ty * 3.0, 32) * 0.4
		var gap := smoothstep(0.7, 0.9, _noise(tx * 8.0, ty * 4.0, 8))
		var v := clampf(streak * 1.2 - gap * 0.6, 0.0, 1.0)
		return Color(v, v, v))
	return _finish(img, 32, 64)


# --- Under the pool ------------------------------------------------------------------

## Poured concrete: mottled grey, faint pour lines, a few tie holes.
func _concrete_at(tx: float, ty: float) -> Color:
	var c := Color(0.50, 0.50, 0.50).darkened((_fbm(tx, ty, 4, 5) - 0.5) * 0.35)
	var pour := 1.0 - smoothstep(0.0, 0.012, absf(fmod(ty * 3.0, 1.0) - 0.5))
	c = c.darkened(pour * 0.12)
	for p: Vector2 in [Vector2(0.18, 0.2), Vector2(0.68, 0.2), Vector2(0.18, 0.7), Vector2(0.68, 0.7)]:
		var d := Vector2(tx, ty).distance_to(p)
		c = c.darkened((1.0 - smoothstep(0.012, 0.03, d)) * 0.4)
	return c


func _concrete() -> Image:
	var img := _canvas(64, 64, "concrete")
	_paint(img, _concrete_at)
	return _finish(img, 64, 64)


## The pool's underside: concrete panels, damp teal-grey patches where it
## leaks, rust bleeding from the joints.
func _ceiling() -> Image:
	var img := _canvas(64, 64, "ceiling")
	_paint(img, func(tx: float, ty: float) -> Color:
		var c := _concrete_at(tx, ty)
		var joint := minf(minf(fmod(tx * 2.0, 1.0), 1.0 - fmod(tx * 2.0, 1.0)), minf(fmod(ty * 2.0, 1.0), 1.0 - fmod(ty * 2.0, 1.0)))
		c = c.darkened((1.0 - smoothstep(0.0, 0.025, joint)) * 0.4)
		var damp := smoothstep(0.55, 0.75, _fbm(tx + 0.2, ty + 0.7, 2, 5))
		c = _dirty(c, damp * 0.55, Color(0.26, 0.34, 0.34))
		var rust := (1.0 - smoothstep(0.0, 0.06, joint)) * smoothstep(0.55, 0.8, _fbm(tx, ty, 8))
		return _dirty(c, rust * 0.6, Color(0.46, 0.28, 0.18)))
	return _finish(img, 64, 64)


## Changing-room floor: small pale non-slip tiles, grubby grout, scuffs.
func _changing_floor() -> Image:
	var img := _canvas(64, 64, "changing_floor")
	_paint(img, func(tx: float, ty: float) -> Color:
		var cell := _cell(tx, ty, 16, 16)
		var base := Color(0.62, 0.68, 0.66).lerp(Color(0.56, 0.62, 0.60), _hash(cell[0], cell[1], 16))
		base = base.darkened((_fbm(tx, ty, 4) - 0.5) * 0.2)
		var c := Color(0.36, 0.40, 0.40).lerp(base, _grout_mask(cell[2], 0.1))
		return _dirty(c, smoothstep(0.6, 0.85, _fbm(tx, ty + 0.3, 3, 5)) * 0.4, Color(0.34, 0.36, 0.32)))
	return _finish(img, 64, 64)


## Changing-room wall, 5 m a repeat so it spans floor to ceiling: a dark
## skirting, small tiles to 2 m, a teal band, then damp mint plaster that
## gets grimier toward the ceiling.
func _changing_wall() -> Image:
	var img := _canvas(128, 128, "changing_wall")
	_paint(img, func(tx: float, ty: float) -> Color:
		var y_m := (1.0 - ty) * 5.0
		var noise := _fbm(tx, ty, 4, 5)
		if y_m < 0.15:
			return Color(0.14, 0.24, 0.26).darkened((noise - 0.5) * 0.3)
		if y_m < 2.0:
			var cell := _cell(tx, (2.0 - y_m) / 5.0, 32, 32)
			var base := Color(0.82, 0.88, 0.88).lerp(Color(0.72, 0.80, 0.82), _hash(cell[0], cell[1], 32) * 0.7)
			var c := Color(0.50, 0.56, 0.56).lerp(base, _grout_mask(cell[2], 0.1))
			var grime := smoothstep(1.2, 0.1, y_m) * 0.35 + smoothstep(0.6, 0.85, noise) * 0.3
			return _dirty(c, grime, Color(0.40, 0.44, 0.40))
		if y_m < 2.14:
			return Color(0.12, 0.36, 0.40).darkened((noise - 0.5) * 0.3)
		var plaster := Color(0.68, 0.76, 0.72).darkened((noise - 0.5) * 0.25)
		plaster = plaster.darkened(smoothstep(3.0, 5.0, y_m) * 0.25)
		# Damp soaking down from the ceiling, in soft uneven patches.
		var damp := smoothstep(0.45, 0.75, _fbm(tx * 2.0, ty, 6, 4)) * smoothstep(2.4, 4.9, y_m)
		return _dirty(plaster, damp * 0.4, Color(0.44, 0.48, 0.42)))
	return _finish(img, 128, 128)


## A bank of lockers, 2 m a repeat: two tiers of four doors in scuffed pale
## paint (tinted per side), dark gaps, vent slots, handles.
func _lockers() -> Image:
	var img := _canvas(64, 64, "lockers")
	_paint(img, func(tx: float, ty: float) -> Color:
		var col := floori(tx * 4.0)
		var fx := fmod(tx * 4.0, 1.0)
		var fy := fmod(ty * 2.0, 1.0)
		var gap := minf(minf(fx, 1.0 - fx) * 0.5, minf(fy, 1.0 - fy))
		var c := Color(0.84, 0.84, 0.84).darkened((_fbm(tx, ty, 4) - 0.5) * 0.2 + _hash(col, floori(ty * 2.0), 4) * 0.08)
		c = Color(0.22, 0.22, 0.24).lerp(c, smoothstep(0.004, 0.02, gap))
		if fx > 0.25 and fx < 0.7 and fy > 0.1 and fy < 0.24 and fmod(fy * 36.0, 1.0) < 0.5:
			c = c.darkened(0.45)  # Vents.
		if fx > 0.72 and fx < 0.82 and fy > 0.45 and fy < 0.6:
			c = c.darkened(0.55)  # Handle.
		var scuff := smoothstep(0.62, 0.85, _fbm(tx + 0.4, ty, 6, 5)) * smoothstep(0.4, 1.0, fy)
		return _dirty(c, scuff * 0.4, Color(0.46, 0.44, 0.40)))
	return _finish(img, 64, 64)


## Ribbed rubber matting for the ramps: dark, soft ribs across the slope,
## worn grey down the middle.
func _rubber_mat() -> Image:
	var img := _canvas(64, 64, "rubber_mat")
	_paint(img, func(tx: float, ty: float) -> Color:
		var rib := 0.5 + 0.5 * sin(ty * TAU * 16.0)
		var c := Color(0.14, 0.16, 0.20).lightened(rib * 0.12)
		var wear := (1.0 - absf(tx - 0.5) * 2.0) * smoothstep(0.3, 0.8, _fbm(tx, ty, 3))
		return c.lightened(wear * 0.18 + (_fbm(tx, ty, 8) - 0.5) * 0.08))
	return _finish(img, 64, 64)


## Brushed steel: a soft horizontal grain, a few smudges.
func _steel() -> Image:
	var img := _canvas(64, 64, "steel")
	_paint(img, func(tx: float, ty: float) -> Color:
		var grain := _noise(tx * 4.0, ty * 96.0, 96)
		var c := Color(0.60, 0.62, 0.66).lightened((grain - 0.5) * 0.18)
		return c.darkened(smoothstep(0.6, 0.85, _fbm(tx, ty, 3)) * 0.2))
	return _finish(img, 64, 64)


## A distant tower's face: dark cladding, a grid of windows, some lit warm,
## a few cool or pink, most dark (drawn unshaded, so lit ones glow in the
## fog).
func _facade() -> Image:
	var img := _canvas(64, 64, "facade")
	_paint(img, func(tx: float, ty: float) -> Color:
		var wx := floori(tx * 8.0)
		var wy := floori(ty * 8.0)
		var fx := fmod(tx * 8.0, 1.0)
		var fy := fmod(ty * 8.0, 1.0)
		var wall := Color(0.05, 0.06, 0.10).lightened((_fbm(tx, ty, 4) - 0.5) * 0.06)
		if fx < 0.22 or fx > 0.85 or fy < 0.22 or fy > 0.85:
			return wall
		var roll := _hash(wx, wy, 8)
		var lit := Color(0.08, 0.10, 0.16)
		if roll < 0.22:
			lit = Color(1.0, 0.76, 0.46)
		elif roll < 0.3:
			lit = Color(0.62, 0.82, 1.0)
		elif roll < 0.33:
			lit = Color(1.0, 0.48, 0.76)
		if roll < 0.33 and fy < 0.4 and _hash(wx, wy + 11, 8) < 0.4:
			lit = lit.darkened(0.5)  # Blinds half down.
		return lit.darkened(fy * 0.25))
	return _finish(img, 64, 64)


# --- Signs and odds ------------------------------------------------------------------

## "No diving": a diver with a red slash, on an off-white enamel sign.
func _no_diving() -> Image:
	var img := _canvas(32, 32, "no_diving")
	var ink := Color(0.12, 0.12, 0.14)
	_paint(img, func(tx: float, ty: float) -> Color:
		var c := Color(0.92, 0.90, 0.84).darkened((_fbm(tx, ty, 3) - 0.5) * 0.15)
		var edge := minf(minf(tx, 1.0 - tx), minf(ty, 1.0 - ty))
		if edge < 0.06:
			return ink
		var p := Vector2(tx, ty) * 32.0
		if p.distance_to(Vector2(21, 9.5)) < 1.8:
			return ink  # Head.
		var body := Vector2(20, 11).direction_to(Vector2(10, 21))
		var along := (p - Vector2(20, 11)).dot(body)
		var off := absf((p - Vector2(20, 11)).dot(body.orthogonal()))
		if along > 0.0 and along < 14.0 and off < 1.2:
			return ink
		if ty > 0.76 and ty < 0.8 and fmod(tx * 6.0, 1.0) < 0.6:
			return Color(0.22, 0.46, 0.72)  # Water.
		if absf(tx - ty) < 0.06 and edge > 0.1:
			return Color(0.80, 0.16, 0.16)  # The slash.
		return c)
	return _finish(img, 32, 32)


## A wet-floor sign's face: faded yellow, a slipping figure in a triangle.
func _wet_floor() -> Image:
	var img := _canvas(32, 32, "wet_floor")
	_paint(img, func(tx: float, ty: float) -> Color:
		var c := Color(0.92, 0.76, 0.16).darkened((_fbm(tx, ty, 3) - 0.5) * 0.2)
		var p := Vector2(tx, ty) * 32.0
		var in_tri := p.y > 6.0 and p.y < 24.0 and absf(p.x - 16.0) < (p.y - 6.0) * 0.55
		var in_inner := p.y > 8.5 and p.y < 22.5 and absf(p.x - 16.0) < (p.y - 8.5) * 0.55 - 0.6
		if in_tri and not in_inner:
			return Color(0.1, 0.1, 0.1)
		if p.distance_to(Vector2(15, 13)) < 1.4 or (p.x > 14 and p.x < 16.5 and p.y > 14 and p.y < 18.5) or (p.y > 18 and p.y < 19.5 and p.x > 12 and p.x < 19):
			return Color(0.1, 0.1, 0.1)
		if p.y > 26.5 and p.y < 28.5 and p.x > 5 and p.x < 27:
			return Color(0.1, 0.1, 0.1)
		return c)
	return _finish(img, 32, 32)


## The fake reflection at night (a sphere map, like
## assets/textures/reflection_map.png): a dark blue sky with the moon in
## it, the city's magenta glow round the horizon, warm window lights below.
func _reflection_night() -> Image:
	_seed = hash("reflection_night")
	var size := 64
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	img.fill(Color(0.02, 0.02, 0.05))
	var moon := Vector3(-0.35, 0.62, 0.70).normalized()
	for py in size:
		for px in size:
			var x := (px + 0.5) / size * 2.0 - 1.0
			var y := 1.0 - (py + 0.5) / size * 2.0
			var d2 := x * x + y * y
			if d2 > 1.0:
				continue
			var n := Vector3(x, y, sqrt(1.0 - d2))
			var r := Vector3(2.0 * n.z * n.x, 2.0 * n.z * n.y, 2.0 * n.z * n.z - 1.0)
			var c: Color
			if r.y > 0.0:
				c = Color(0.16, 0.11, 0.24).lerp(Color(0.03, 0.04, 0.12), clampf(r.y * 1.6, 0.0, 1.0))
			else:
				c = Color(0.10, 0.06, 0.14).lerp(Color(0.02, 0.02, 0.04), clampf(-r.y * 3.0, 0.0, 1.0))
				if _hash(px, py, 64) < 0.12:
					c = c.lerp(Color(1.0, 0.72, 0.42), 0.6)
			c = c.lerp(Color(0.85, 0.9, 1.0), smoothstep(0.93, 0.975, r.dot(moon)))
			img.set_pixel(px, py, c)
	return img


## A square floor drain: grimy steel slots in a frame.
func _drain() -> Image:
	var img := _canvas(32, 32, "drain")
	_paint(img, func(tx: float, ty: float) -> Color:
		var c := Color(0.50, 0.52, 0.54).darkened((_fbm(tx, ty, 3) - 0.5) * 0.3)
		var edge := minf(minf(tx, 1.0 - tx), minf(ty, 1.0 - ty))
		if edge > 0.12 and fmod(ty * 8.0, 1.0) < 0.4:
			c = Color(0.05, 0.06, 0.06)
		return _dirty(c, smoothstep(0.5, 0.8, _fbm(tx, ty, 2)) * 0.4, Color(0.30, 0.28, 0.22)))
	return _finish(img, 32, 32)
