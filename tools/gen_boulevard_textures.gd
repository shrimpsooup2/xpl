extends "res://tools/texture_painter.gd"
## Generates Boulevard's textures (Rimehollow, the village in the ice cave,
## GDD §9.3) into assets/textures/boulevard/:
##
##   godot --headless --path . --script res://tools/gen_boulevard_textures.gd
##
## Painted in the house style (tools/texture_painter.gd): 64 px, point
## filtered, gritty. The ice has two more that are data for its shader
## (src/render/deco/ice.gdshader): its scallops as a normal map, and what's
## inside it. Paint over the PNGs freely.

const OUT := "res://assets/textures/boulevard/"


func _initialize() -> void:
	out_dir = OUT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_save(_ice(), "ice")
	_save(_ice_scallops(), "ice_scallops")
	_save(_ice_inner(), "ice_inner")
	_save(_reflection_ice(), "reflection_ice")
	_save(_cobbles(), "cobbles")
	_save(_quay(), "quay")
	_save(_plaster(), "plaster")
	_save(_timber(), "timber")
	_save(_planks(false), "planks")
	_save(_planks(true), "boardwalk")
	_save(_shingles(), "shingles")
	_save(_snow(), "snow")
	_save(_logs(), "logs")
	_save(_stone(), "stone")
	_save(_canvas_cloth(), "canvas")
	_save(_firewood(), "firewood")
	quit()


# --- The ice ----------------------------------------------------------------------------

## Worley cells on a wrapping grid `cells` across (stretched `stretch` in
## x): the distance to the nearest point, to the second, and the nearest
## point's cell.
func _worley(tx: float, ty: float, cells: int, stretch: float, salt: int) -> Array:
	var gx := tx * cells
	var gy := ty * cells
	var best := 9.0
	var second := 9.0
	var id := Vector2i.ZERO
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var ix := floori(gx) + ox
			var iy := floori(gy) + oy
			var p := Vector2(ix + 0.15 + 0.7 * _hash(ix + salt, iy, cells), iy + 0.15 + 0.7 * _hash(iy + salt * 3, ix, cells))
			var d := (Vector2(gx, gy) - p) * Vector2(1.0 / stretch, 1.0)
			var dist := d.length()
			if dist < best:
				second = best
				best = dist
				id = Vector2i(posmod(ix, cells), posmod(iy, cells))
			elif dist < second:
				second = dist
	return [best, second, id]


## Glacier ice: blue, deeper in the scallops' dishes and paler up their
## ridges, frost on the ridges, bubbles, grit streaked through it in
## layers, blotchy. Three metres a repeat (the shader lights it through).
func _ice() -> Image:
	var img := _canvas(64, 64, "ice")
	_paint(img, func(tx: float, ty: float) -> Color:
		var keep := _seed
		_seed = hash("ice_scallops")
		var h := _scallop(tx, ty)
		_seed = keep
		var c := Color(0.10, 0.30, 0.52).lerp(Color(0.26, 0.58, 0.78), _fbm(tx, ty, 3, 4))
		c = c.lerp(Color(0.05, 0.18, 0.36), smoothstep(0.45, 0.0, h) * 0.5)
		c = c.lerp(Color(0.70, 0.86, 0.94), smoothstep(0.7, 0.95, h) * 0.75)
		# Grit: dark streaks in layers, and blotches.
		var layer := absf(fposmod(ty * 3.0 + (_fbm(tx, ty, 3, 3) - 0.5) * 0.6, 1.0) - 0.5)
		c = c.lerp(Color(0.12, 0.16, 0.22), (1.0 - smoothstep(0.0, 0.04, layer)) * smoothstep(0.4, 0.6, _fbm(tx + 0.2, ty, 4, 2)) * 0.6)
		c = c.darkened(smoothstep(0.6, 0.85, _fbm(tx + 0.7, ty + 0.3, 5, 3)) * 0.25)
		# Bubbles, and speckle.
		var b := _worley(tx, ty, 20, 1.0, 5)
		c = c.lerp(Color(0.86, 0.94, 1.0), (1.0 - smoothstep(0.06, 0.12, float(b[0]))) * (1.0 if _hash((b[2] as Vector2i).x, (b[2] as Vector2i).y, 20) > 0.7 else 0.0) * 0.8)
		return c.lightened((_hash(floori(tx * 256.0), floori(ty * 256.0), 256) - 0.5) * 0.12))
	return _finish(img, 64, 64)


## How high the scalloped surface is at (tx, ty): shallow dishes, sharp
## ridges between them where the ice is left standing (1), two sizes over
## each other. The colour (_ice()) and the normals (_ice_scallops()) both
## read it, so the ridges they paint and bend are the same ones.
func _scallop(tx: float, ty: float) -> float:
	var dish := func(w: Array) -> float:
		return 1.0 - smoothstep(0.0, 0.42, float(w[1]) - float(w[0]))
	return float(dish.call(_worley(tx, ty, 6, 1.35, 3))) * 0.72 + float(dish.call(_worley(tx, ty, 14, 1.2, 17))) * 0.28


## The ice's scallops as a normal map: RG the normal (x across, y down the
## picture, 0.5 flat), B the height (1 on a ridge). 64 px.
func _ice_scallops() -> Image:
	var n := 64
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	_seed = hash("ice_scallops")
	for y in n:
		for x in n:
			var tx := (x + 0.5) / n
			var ty := (y + 0.5) / n
			heights[y * n + x] = _scallop(tx, ty) + (_fbm(tx, ty, 8, 3) - 0.5) * 0.1
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var hl := heights[y * n + posmod(x - 1, n)]
			var hr := heights[y * n + posmod(x + 1, n)]
			var hu := heights[posmod(y - 1, n) * n + x]
			var hd := heights[posmod(y + 1, n) * n + x]
			var nrm := Vector3((hl - hr) * 6.0, (hu - hd) * 6.0, 1.0).normalized()
			img.set_pixel(x, y, Color(nrm.x * 0.5 + 0.5, nrm.y * 0.5 + 0.5, heights[y * n + x], 1.0))
	return img


## What's inside the ice, seen through it: R bubbles, strings of them and
## single ones, soft; G fracture planes, thin bright lines that wander; B
## how thick the ice is, broad and soft (thin lets the light through). 64
## px, the shader reads it at a few depths and scales.
func _ice_inner() -> Image:
	var img := _canvas(64, 64, "ice_inner")
	_paint(img, func(tx: float, ty: float) -> Color:
		# Bubbles: most small, some big, gathered in bands.
		var band := smoothstep(0.45, 0.75, _fbm(tx * 1.0, ty, 3, 3))
		var b1 := _worley(tx, ty, 24, 1.0, 5)
		var b2 := _worley(tx, ty, 9, 1.0, 11)
		var s1 := _hash((b1[2] as Vector2i).x, (b1[2] as Vector2i).y + 3, 24)
		var s2 := _hash((b2[2] as Vector2i).x, (b2[2] as Vector2i).y + 9, 9)
		var bubble: float = (1.0 - smoothstep(0.08, 0.16, float(b1[0]))) * (1.0 if s1 > 0.55 - band * 0.35 else 0.0)
		bubble = maxf(bubble, (1.0 - smoothstep(0.14, 0.24, float(b2[0]))) * (0.8 if s2 > 0.8 else 0.0))
		# Fractures: wandering lines along cell edges, faint and bright.
		var f := _worley(tx + (_fbm(tx, ty, 4, 3) - 0.5) * 0.08, ty, 4, 1.6, 23)
		var crack := (1.0 - smoothstep(0.0, 0.035, float(f[1]) - float(f[0]))) * smoothstep(0.35, 0.6, _fbm(tx + 0.3, ty, 3, 3))
		var thick := _fbm(tx, ty + 0.5, 2, 4)
		return Color(bubble, crack, thick))
	return _finish(img, 64, 64)


## The cave seen in anything shiny: blue ice all round and overhead, a
## bright patch where an opening lets the day in, the village's warm
## lights low down.
func _reflection_ice() -> Image:
	var img := _canvas(64, 64, "reflection_ice")
	_paint(img, func(tx: float, ty: float) -> Color:
		var p := Vector2(tx * 2.0 - 1.0, 1.0 - ty * 2.0)
		var r := p.length()
		if r > 1.0:
			return Color(0.2, 0.42, 0.6)
		var up := p.y
		var c := Color(0.06, 0.22, 0.42).lerp(Color(0.3, 0.66, 0.86), smoothstep(-0.2, 0.9, up))
		c = c.lightened(clampf(0.04 / maxf(Vector2(p.x - 0.2, p.y - 0.6).length(), 0.01) - 0.1, 0.0, 0.7))
		# Warm windows along the bottom.
		var lamps := smoothstep(0.7, 0.9, _fbm(tx * 1.0, 0.3, 8, 2)) * smoothstep(-0.1, -0.4, up) * smoothstep(-0.8, -0.5, up)
		return c.lerp(Color(1.0, 0.7, 0.4), lamps * 0.8))
	return _finish(img, 64, 64)


# --- The village ------------------------------------------------------------------------

## Wear, the same way on everything: speckle, blotches, grime in stains.
func _worn(c: Color, tx: float, ty: float, speck := 0.12, blotch := 0.16) -> Color:
	c = c.lightened((_hash(floori(tx * 256.0), floori(ty * 256.0), 256) - 0.5) * speck)
	c = c.darkened((_fbm(tx, ty, 4) - 0.5) * blotch)
	return c.darkened(smoothstep(0.62, 0.85, _fbm(tx + 0.37, ty + 0.61, 6, 3)) * 0.18)


## The street: granite setts in rows, each its own shade, snow packed in
## the joints and lying in patches over them. Two metres a repeat.
func _cobbles() -> Image:
	var img := _canvas(64, 64, "cobbles")
	_paint(img, func(tx: float, ty: float) -> Color:
		var row := floori(ty * 9.0)
		var x := tx * 8.0 + (0.5 if row % 2 == 1 else 0.0) + _hash(row, 3, 9) * 0.3
		var ix := floori(x)
		var fx := x - ix
		var fy := ty * 9.0 - row
		var edge := minf(minf(fx, 1.0 - fx), minf(fy, 1.0 - fy))
		var c := Color(0.44, 0.43, 0.46).lerp(Color(0.56, 0.50, 0.46), _hash(posmod(ix, 8), row, 9))
		c = _worn(c, tx, ty)
		c = c.lightened(smoothstep(0.35, 0.0, fy) * 0.06)
		var snow := Color(0.84, 0.88, 0.94).darkened((_fbm(tx, ty, 8, 2) - 0.5) * 0.1)
		var joint := Color(0.24, 0.24, 0.27).lerp(snow, smoothstep(0.45, 0.6, _fbm(tx, ty + 0.3, 6, 3)))
		c = joint.lerp(c, smoothstep(0.04, 0.1, edge))
		var patch := smoothstep(0.66, 0.74, _fbm(tx + 0.4, ty, 3, 4))
		return c.lerp(snow.darkened(0.12), patch * 0.7))
	return _finish(img, 64, 64)


## The canal's quays: dark granite in courses half a metre tall, blocks
## a metre and more, clean joints, a rime of frost low down. The
## wall-ride band two metres apart, as every map's rideable walls wear:
## dark stripes between yellow lines. Four metres a repeat.
func _quay() -> Image:
	var img := _canvas(64, 64, "quay")
	_paint(img, func(tx: float, ty: float) -> Color:
		var px := tx * 64.0
		var py := ty * 64.0
		var course := floori(py / 8.0)
		var in_y := py - course * 8.0
		if course % 4 == 3:
			if in_y < 1.0 or in_y >= 7.0:
				return Color(0.9, 0.95, 0.4)
			var stripe := posmod(floori(px) + floori(py), 8) < 4
			return Color(0.08, 0.18, 0.24) if stripe else Color(0.12, 0.26, 0.32)
		var shift := _hash(course, 7, 8) * 16.0
		var x := fposmod(px + shift, 64.0)
		var k := floori(x / 16.0)
		var in_x := x - k * 16.0
		var c := Color(0.36, 0.37, 0.41).darkened((_hash(course, k, 8) - 0.5) * 0.16)
		c = _worn(c, tx, ty)
		if in_y < 2.0 or in_x < 2.0:
			c = c.lightened(0.07)
		elif in_y >= 7.0:
			c = c.darkened(0.1)
		if in_y < 1.0 or in_x < 1.0:
			return Color(0.16, 0.17, 0.2)
		return c.lerp(Color(0.8, 0.88, 0.94), smoothstep(0.62, 0.8, _fbm(tx, ty, 6, 3)) * 0.35))
	return _finish(img, 64, 64)


## Lime plaster between the timbers: warm cream, soft blotches, a little
## grey where the damp gets in low down. Four metres a repeat (tinted per
## house).
func _plaster() -> Image:
	var img := _canvas(64, 64, "plaster")
	_paint(img, func(tx: float, ty: float) -> Color:
		var c := Color(0.90, 0.84, 0.72)
		c = _worn(c, tx, ty, 0.05, 0.12)
		c = c.darkened(smoothstep(0.55, 0.8, _fbm(tx + 0.3, ty, 5, 3)) * 0.08)
		return c)
	return _finish(img, 64, 64)


## Timber beams: dark-stained oak, the grain along it, a knot here and
## there. A metre a repeat, along the beam (decor UVs).
func _timber() -> Image:
	var img := _canvas(64, 64, "timber")
	_paint(img, func(tx: float, ty: float) -> Color:
		var grain := _stretched(tx, ty, 2, 24)
		var c := Color(0.30, 0.20, 0.13).lerp(Color(0.40, 0.28, 0.18), grain)
		c = c.darkened(smoothstep(0.7, 0.9, _stretched(tx + 0.3, ty, 4, 48)) * 0.2)
		var knot := Vector2(fposmod(tx * 3.0, 1.0) - 0.5, fposmod(ty * 2.0, 1.0) - 0.5).length()
		c = c.darkened((1.0 - smoothstep(0.04, 0.08, knot)) * 0.3 * (1.0 if _hash(floori(tx * 3.0), floori(ty * 2.0), 3) > 0.6 else 0.0))
		return _worn(c, tx, ty, 0.05, 0.08))
	return _finish(img, 64, 64)


## Boards 20 cm wide, each its own shade, dark gaps; outdoors (`snowy`)
## grey and weathered with snow in the gaps and drifted in patches. Two
## metres a repeat.
func _planks(snowy: bool) -> Image:
	var img := _canvas(64, 64, "boardwalk" if snowy else "planks")
	_paint(img, func(tx: float, ty: float) -> Color:
		var board := floori(ty * 10.0)
		var in_b := ty * 10.0 - board
		var join := fposmod(tx + _hash(board, 1, 10) * 0.7, 1.0)
		var c := Color(0.52, 0.34, 0.20).lerp(Color(0.62, 0.44, 0.28), _hash(board, 5, 10))
		if snowy:
			c = Color(0.48, 0.44, 0.40).lerp(Color(0.56, 0.52, 0.48), _hash(board, 5, 10))
		c = c.darkened((_stretched(ty, tx, 1, 12) - 0.5) * 0.12)
		c = _worn(c, tx, ty, 0.05, 0.1)
		var gap := minf(minf(in_b, 1.0 - in_b) * 10.0, minf(join, 1.0 - join) * 40.0)
		var dark := Color(0.86, 0.9, 0.95) if snowy else Color(0.16, 0.10, 0.07)
		c = dark.lerp(c, smoothstep(0.3, 0.7, gap))
		if snowy:
			c = c.lerp(Color(0.74, 0.78, 0.84), smoothstep(0.64, 0.72, _fbm(tx + 0.2, ty, 3, 4)) * 0.7)
		return c)
	return _finish(img, 64, 64)


## Wooden shingles in overlapping rows, rounded ends, each its own shade.
## Two metres a repeat.
func _shingles() -> Image:
	var img := _canvas(64, 64, "shingles")
	_paint(img, func(tx: float, ty: float) -> Color:
		var row := floori(ty * 8.0)
		var x := tx * 8.0 + (0.5 if row % 2 == 1 else 0.0)
		var ix := floori(x)
		var fx := x - ix - 0.5
		var fy := ty * 8.0 - row
		var c := Color(0.40, 0.26, 0.18).lerp(Color(0.50, 0.34, 0.22), _hash(posmod(ix, 8), row, 8))
		c = _worn(c, tx, ty)
		# The row below's shadow under each one's rounded end.
		var bottom := 0.85 - fx * fx * 0.6
		c = c.darkened(smoothstep(bottom - 0.12, bottom, fy) * 0.35)
		if absf(fx) > 0.46:
			c = c.darkened(0.3)
		return c)
	return _finish(img, 64, 64)


## Snow lying: white going blue in the hollows, a little sparkle. Four
## metres a repeat.
func _snow() -> Image:
	var img := _canvas(64, 64, "snow")
	_paint(img, func(tx: float, ty: float) -> Color:
		var c := Color(0.80, 0.86, 0.94).lerp(Color(0.95, 0.97, 1.0), smoothstep(0.35, 0.65, _fbm(tx, ty, 3, 4)))
		var h := _hash(floori(tx * 256.0), floori(ty * 256.0), 256)
		return c.lightened(0.15 if h > 0.985 else 0.0))
	return _finish(img, 64, 64)


## A log wall: round logs laid on each other, bark and a dark line where
## they meet. Two metres a repeat.
func _logs() -> Image:
	var img := _canvas(64, 64, "logs")
	_paint(img, func(tx: float, ty: float) -> Color:
		var row := floori(ty * 7.0)
		var fy := ty * 7.0 - row
		var round := sin(fy * PI)
		var c := Color(0.52, 0.36, 0.23).lerp(Color(0.66, 0.50, 0.32), _hash(row, 2, 7) * 0.6)
		c = c.darkened((_stretched(ty, tx, 1, 16) - 0.5) * 0.15)
		c = c.darkened((1.0 - round) * 0.45).lightened(smoothstep(0.2, 0.35, fy) * smoothstep(0.55, 0.35, fy) * 0.08)
		return _worn(c, tx, ty, 0.05, 0.08))
	return _finish(img, 64, 64)


## Rough stone: grey blocks, uneven, clean joints. Two metres a repeat.
func _stone() -> Image:
	var img := _canvas(64, 64, "stone")
	_paint(img, func(tx: float, ty: float) -> Color:
		var row := floori(ty * 5.0)
		var x := tx * 3.0 + (0.5 if row % 2 == 1 else 0.0) + _hash(row, 4, 5) * 0.2
		var ix := floori(x)
		var fx := x - ix
		var fy := ty * 5.0 - row
		var edge := minf(minf(fx, 1.0 - fx) * 0.6, minf(fy, 1.0 - fy))
		var c := Color(0.58, 0.57, 0.56).lerp(Color(0.66, 0.63, 0.58), _hash(posmod(ix, 3), row, 5))
		c = _worn(c, tx, ty, 0.08, 0.14)
		c = c.lightened(smoothstep(0.25, 0.0, fy) * 0.08)
		return Color(0.26, 0.25, 0.26).lerp(c, smoothstep(0.03, 0.07, edge)))
	return _finish(img, 64, 64)


## Heavy canvas over a sled's load: oiled green-grey, seams, ties. Two
## metres a repeat.
func _canvas_cloth() -> Image:
	var img := _canvas(64, 64, "canvas")
	_paint(img, func(tx: float, ty: float) -> Color:
		var c := Color(0.36, 0.40, 0.32)
		c = c.darkened((sin((tx * 128.0 + ty * 3.0) * PI) * 0.5 + 0.5) * 0.04)
		c = _worn(c, tx, ty, 0.05, 0.16)
		var seam := minf(absf(fposmod(tx * 2.0, 1.0) - 0.5), 0.5)
		return c.darkened((1.0 - smoothstep(0.0, 0.02, 0.5 - seam)) * 0.3))
	return _finish(img, 64, 64)


## Firewood stacked, seen end on: rounds of every size, pale with rings,
## bark round each, dark gaps. A metre a repeat.
func _firewood() -> Image:
	var img := _canvas(64, 64, "firewood")
	_paint(img, func(tx: float, ty: float) -> Color:
		var w := _worley(tx, ty, 7, 1.0, 13)
		var d: float = w[0]
		var id: Vector2i = w[2]
		var size := 0.44 + _hash(id.x, id.y, 7) * 0.14
		if d > size:
			return Color(0.12, 0.08, 0.06)
		var c := Color(0.78, 0.62, 0.42).lerp(Color(0.66, 0.50, 0.32), _hash(id.x + 3, id.y, 7))
		c = c.darkened((sin(d * 90.0) * 0.5 + 0.5) * 0.08)
		if d > size - 0.07:
			c = Color(0.30, 0.20, 0.13)
		return _worn(c, tx, ty, 0.05, 0.06))
	return _finish(img, 64, 64)


## Value noise stretched down the picture, `cols` cells across and `rows`
## down, wrapping both ways: grain, streaks.
func _stretched(tx: float, ty: float, cols: int, rows: int) -> float:
	var x := tx * cols
	var y := ty * rows
	var xi := floori(x)
	var yi := floori(y)
	var u := (x - xi) * (x - xi) * (3.0 - 2.0 * (x - xi))
	var v := (y - yi) * (y - yi) * (3.0 - 2.0 * (y - yi))
	var at := func(i: int, j: int) -> float: return _hash(posmod(i, cols) * 97 + posmod(j, rows), 5, 1 << 20)
	return lerpf(lerpf(at.call(xi, yi), at.call(xi + 1, yi), u), lerpf(at.call(xi, yi + 1), at.call(xi + 1, yi + 1), u), v)
