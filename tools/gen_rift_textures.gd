extends "res://tools/texture_painter.gd"
## Generates Rift's textures (Nimbus, the station on the peak above the
## clouds, GDD §9.3) into assets/textures/rift/:
##
##   godot --headless --path . --script res://tools/gen_rift_textures.gd
##
## Painted soft (tools/texture_painter.gd). Paint over the PNGs freely.

const OUT := "res://assets/textures/rift/"


func _initialize() -> void:
	out_dir = OUT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_save(_ballast(), "ballast")
	_save(_flags(), "flags")
	_save(_ride_stone(), "ride_stone")
	_save(_rock(), "rock")
	_save(_cliff(), "cliff")
	_save(_far_rock(), "far_rock")
	_save(_scree(), "scree")
	_save(_snow(), "snow")
	_save(_alpine(), "alpine")
	_save(_meadow(), "meadow")
	_save(_billows(), "billows")
	_save(_reflection_day(), "reflection_day")
	_save(_poster_peak(), "poster_peak")
	_save(_poster_viaduct(), "poster_viaduct")
	_save(_poster_balloon(), "poster_balloon")
	quit()


# --- The ground ------------------------------------------------------------------------

## Track ballast: chunky grey chippings, each its own shade and lit on
## top, dark gaps between, rust-brown here and there where the rails shed.
## A metre a repeat.
func _ballast() -> Image:
	var img := _canvas(64, 64, "ballast")
	_paint(img, func(tx: float, ty: float) -> Color:
		var chip := _blocks(tx, ty, Vector2(12, 12), 40)
		var id: Vector2i = chip[0]
		var rel: Vector2 = chip[1]
		var c := Color(0.56, 0.55, 0.53).lerp(Color(0.40, 0.40, 0.42), _hash(id.x, id.y, 12))
		c = c.lerp(Color(0.52, 0.40, 0.30), smoothstep(0.8, 0.9, _hash(id.x + 5, id.y, 12)) * 0.7)
		c = c.lightened(smoothstep(-0.1, -0.35, rel.y) * 0.1).darkened(smoothstep(0.1, 0.35, rel.y) * 0.1)
		c = c.lightened((_hash(floori(tx * 256.0), floori(ty * 256.0), 256) - 0.5) * 0.08)
		return Color(0.20, 0.19, 0.18).lerp(c, smoothstep(0.03, 0.08, chip[2])))
	return _finish(img, 64, 64)


## The cutting's walls: dressed limestone in courses half a metre tall,
## blocks of a metre or more, staggered course to course, each its own
## shade, clean dark joints, lit along the top. Every two metres the
## wall-ride band, as on the ride tiles every map's rideable walls wear:
## dark diagonal stripes between yellow lines. Four metres a repeat.
func _ride_stone() -> Image:
	var img := _canvas(64, 64, "ride_stone")
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
		# Blocks 16 to 24 px (1 to 1.5 m), each course its own stagger.
		var span := _span(fposmod(px + _hash(course, 7, 8) * 16.0, 64.0), course, 16.0, 24.0)
		var k: int = span[0]
		var in_x: float = span[1]
		var c := Color(0.70, 0.66, 0.58).darkened((_hash(course, k + 20, 8) - 0.5) * 0.14)
		c = c.lerp(Color(0.64, 0.64, 0.64), _hash(course + 3, k, 8) * 0.3)
		c = c.lightened((_hash(floori(tx * 256.0), floori(ty * 256.0), 256) - 0.5) * 0.08)
		c = c.darkened((_fbm(tx, ty, 4) - 0.5) * 0.12)
		# Bevel: light along the top and left, dark along the bottom.
		if in_y < 2.0 or in_x < 2.0:
			c = c.lightened(0.08)
		elif in_y >= 7.0:
			c = c.darkened(0.12)
		if in_y < 1.0 or in_x < 1.0:
			return Color(0.30, 0.28, 0.26)
		# Rain streaks down from the band.
		return _dirty(c, smoothstep(0.62, 0.85, _stretched(tx, ty, 16, 2)) * 0.18, Color(0.42, 0.41, 0.40)))
	return _finish(img, 64, 64)


## Pale limestone flags on the roofs and the galleries, a metre and a half
## square, each its own shade, clean dark joints, lit along the top.
## Three metres a repeat.
func _flags() -> Image:
	var img := _canvas(64, 64, "flags")
	_paint(img, func(tx: float, ty: float) -> Color:
		var px := fposmod(tx * 64.0, 32.0)
		var py := fposmod(ty * 64.0, 32.0)
		var ix := floori(tx * 2.0)
		var iy := floori(ty * 2.0)
		var c := Color(0.80, 0.77, 0.70).darkened(_hash(ix, iy, 2) * 0.08)
		c = c.lightened((_hash(floori(tx * 256.0), floori(ty * 256.0), 256) - 0.5) * 0.07)
		c = c.darkened((_fbm(tx, ty, 4) - 0.5) * 0.12)
		if py < 2.0 or px < 2.0:
			c = c.lightened(0.06)
		elif py >= 30.0 or px >= 30.0:
			c = c.darkened(0.08)
		if py < 1.0 or px < 1.0:
			return Color(0.38, 0.36, 0.32)
		return c)
	return _finish(img, 64, 64)


## The mountain's rock under the tracks: grey granite in big slabs, each
## its own shade and lit along the top, clean dark joints. Six metres a
## repeat.
func _rock() -> Image:
	var img := _canvas(64, 64, "rock")
	_paint(img, func(tx: float, ty: float) -> Color:
		var b := _slabs(tx, ty, 4, 3, 50)
		var c := Color(0.52, 0.52, 0.55).lerp(Color(0.40, 0.40, 0.44), b[0])
		c = c.lightened((_hash(floori(tx * 256.0), floori(ty * 256.0), 256) - 0.5) * 0.08)
		c = c.darkened((_fbm(tx, ty, 4) - 0.5) * 0.14)
		c = c.lightened(smoothstep(2.0, 0.0, b[2]) * 0.08).darkened(smoothstep(2.5, 0.0, b[3]) * 0.12)
		return Color(0.20, 0.20, 0.22).lerp(c, smoothstep(0.5, 1.2, b[1])))
	return _finish(img, 64, 64)


## Worley blocks on a jittered grid `cells` across: the nearest point's
## cell, where (tx, ty) sits in it (-0.5..0.5, y down), and how far it is
## from the cell's edge (0 on a crack).
func _blocks(tx: float, ty: float, cells: Vector2, salt: int) -> Array:
	var gx := tx * cells.x
	var gy := ty * cells.y
	var best := 9.0
	var second := 9.0
	var id := Vector2i.ZERO
	var rel := Vector2.ZERO
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var ix := floori(gx) + ox
			var iy := floori(gy) + oy
			var p := Vector2(ix + 0.2 + 0.6 * _hash(ix + salt, iy, int(cells.x)), iy + 0.2 + 0.6 * _hash(iy + salt * 3, ix, int(cells.y)))
			var dist := Vector2(gx, gy).distance_to(p)
			if dist < best:
				second = best
				best = dist
				id = Vector2i(posmod(ix, int(cells.x)), posmod(iy, int(cells.y)))
				rel = Vector2(gx, gy) - p
			elif dist < second:
				second = dist
	return [id, rel, second - best]


## A block's facet: a random tilt for block `id`, and how much light it
## catches from high up on the left (texture y runs down).
func _facet(id: Vector2i, salt: int, period: int) -> Array:
	var n := Vector3(_hash(id.x + salt, id.y, period) - 0.5, _hash(id.y + salt, id.x + 7, period) - 0.5, 0.7).normalized()
	return [n, clampf(n.dot(Vector3(-0.45, -0.55, 0.7).normalized()), 0.0, 1.0)]


## Rock close up (rockeries, boulders): granite broken into big angular
## facets, each flat and catching the light its own way, clean dark
## cracks between, a few spots of lichen. Four metres a repeat.
func _cliff() -> Image:
	var img := _canvas(64, 64, "cliff")
	_paint(img, func(tx: float, ty: float) -> Color:
		var b := _blocks(tx, ty, Vector2(5, 4), 11)
		var f := _facet(b[0], 3, 5)
		var c := Color(0.30, 0.30, 0.33).lerp(Color(0.66, 0.65, 0.66), float(f[1]))
		c = c.lightened((_hash(floori(tx * 256.0), floori(ty * 256.0), 256) - 0.5) * 0.08)
		c = c.darkened((_fbm(tx, ty, 4) - 0.5) * 0.1)
		var lichen := smoothstep(0.7, 0.74, _fbm(tx + 0.4, ty + 0.1, 8, 3))
		c = c.lerp(Color(0.72, 0.62, 0.34), lichen * 0.7)
		return Color(0.18, 0.18, 0.20).lerp(c, smoothstep(0.02, 0.05, b[2])))
	return _finish(img, 64, 64)


## The mountains far off: grey rock in soft gullies and buttresses running
## down, faint ledges across, warmer and cooler by turns; soft, like
## everything far off. Seen with world y up. Sixty metres a repeat.
func _far_rock() -> Image:
	var img := _canvas(64, 64, "far_rock")
	_paint(img, func(tx: float, ty: float) -> Color:
		var c := Color(0.50, 0.49, 0.51).darkened((_fbm(tx, ty, 3, 4) - 0.5) * 0.3)
		c = c.lerp(Color(0.54, 0.47, 0.42), smoothstep(0.5, 0.75, _fbm(tx + 0.4, ty, 2, 3)) * 0.5)
		var gully := _stretched(tx, ty, 10, 2) * 0.7 + _stretched(tx + 0.13, ty, 20, 3) * 0.3
		c = c.darkened(smoothstep(0.5, 0.85, gully) * 0.32).lightened(smoothstep(0.35, 0.1, gully) * 0.12)
		var ledge := _stretched(tx, ty, 2, 9)
		return c.lightened(smoothstep(0.7, 0.9, ledge) * 0.1).darkened(smoothstep(0.3, 0.1, ledge) * 0.08))
	return _finish(img, 64, 64)


## Slabs: `rows` courses, each broken into `cols`-ish slabs of uneven
## length by joints running down: how dark the slab is (0..1), how far
## (px) from the nearest joint, from the slab's top, and from its bottom.
func _slabs(tx: float, ty: float, cols: int, rows: int, salt: int) -> Array:
	var py := ty * 64.0
	var row_h := 64.0 / rows
	var row := floori(py / row_h)
	var in_y := py - row * row_h
	var span := _span(fposmod(tx * 64.0 + _hash(row, salt, rows) * 64.0, 64.0), row + salt, 64.0 / cols * 0.7, 64.0 / cols * 1.3)
	var k: int = span[0]
	var in_x: float = span[1]
	var length: float = span[2]
	var joint := minf(minf(in_x, length - in_x), minf(in_y, row_h - in_y))
	return [_hash(row + 11, k, 64), joint, in_y, row_h - in_y]


## Where `x` (0..64 px) falls along a run of pieces `lo` to `hi` px long
## that fill the 64 exactly (so it wraps), laid out by `salt`: the
## piece's index, how far into it, and its length.
func _span(x: float, salt: int, lo: float, hi: float) -> Array:
	var lengths := []
	var total := 0.0
	while total < 64.0:
		var l := lerpf(lo, hi, _hash(salt, lengths.size() + 31, 1 << 16))
		lengths.append(l)
		total += l
	# Squeeze the run to fit.
	var scale := 64.0 / total
	var start := 0.0
	for i in lengths.size():
		var l: float = lengths[i] * scale
		if x < start + l or i == lengths.size() - 1:
			return [i, x - start, l]
		start += l
	return [0, x, lo]


## Value noise stretched down the picture, `cols` cells across and `rows`
## down, wrapping both ways: streaks.
func _stretched(tx: float, ty: float, cols: int, rows: int) -> float:
	var x := tx * cols
	var y := ty * rows
	var xi := floori(x)
	var yi := floori(y)
	var u := (x - xi) * (x - xi) * (3.0 - 2.0 * (x - xi))
	var v := (y - yi) * (y - yi) * (3.0 - 2.0 * (y - yi))
	var at := func(i: int, j: int) -> float: return _hash(posmod(i, cols) * 97 + posmod(j, rows), 5, 1 << 20)
	return lerpf(lerpf(at.call(xi, yi), at.call(xi + 1, yi), u), lerpf(at.call(xi, yi + 1), at.call(xi + 1, yi + 1), u), v)


## Scree below the cliffs: angular broken stones, grey and rust, each flat
## and catching the light its own way, dark gaps between. Twelve metres a
## repeat.
func _scree() -> Image:
	var img := _canvas(64, 64, "scree")
	_paint(img, func(tx: float, ty: float) -> Color:
		var b := _blocks(tx, ty, Vector2(10, 10), 5)
		var id: Vector2i = b[0]
		var f := _facet(id, 21, 10)
		var base := Color(0.54, 0.53, 0.52).lerp(Color(0.56, 0.44, 0.34), _hash(id.x + 2, id.y, 10) * 0.8)
		var c := base.darkened(0.3).lerp(base.lightened(0.15), float(f[1]))
		c = c.lightened((_hash(floori(tx * 256.0), floori(ty * 256.0), 256) - 0.5) * 0.08)
		return Color(0.22, 0.20, 0.19).lerp(c, smoothstep(0.03, 0.07, b[2])))
	return _finish(img, 64, 64)


## A snowfield: white going blue in the hollows, wind ripples across it,
## a few rocks poking through. Twenty-four metres a repeat.
func _snow() -> Image:
	var img := _canvas(64, 64, "snow")
	_paint(img, func(tx: float, ty: float) -> Color:
		var drift := _fbm(tx, ty, 3, 4)
		var c := Color(0.80, 0.86, 0.96).lerp(Color(0.99, 0.99, 1.0), smoothstep(0.3, 0.7, drift))
		var ripple := sin((ty * 40.0 + _fbm(tx, ty, 4, 3) * 6.0) * TAU * 0.5) * 0.5 + 0.5
		c = c.darkened(ripple * 0.04)
		var rock := smoothstep(0.78, 0.84, _fbm(tx + 0.5, ty + 0.2, 6, 3))
		return c.lerp(Color(0.34, 0.33, 0.36), rock * 0.9))
	return _finish(img, 64, 64)


## Alpine turf on the rockeries: short tawny grass in bold patches of
## green moss, grey stones, a few flowers, white and yellow and violet.
## Four metres a repeat.
func _alpine() -> Image:
	var img := _canvas(64, 64, "alpine")
	_paint(img, func(tx: float, ty: float) -> Color:
		var moss := smoothstep(0.5, 0.56, _fbm(tx, ty, 4, 4))
		var c := Color(0.62, 0.56, 0.32).lerp(Color(0.38, 0.50, 0.24), moss)
		c = c.lightened((_hash(floori(tx * 256.0), floori(ty * 256.0), 256) - 0.5) * 0.1)
		var stone := smoothstep(0.72, 0.75, _fbm(tx + 0.7, ty + 0.4, 4, 3))
		c = c.lerp(Color(0.60, 0.60, 0.60), stone)
		var h := _hash(floori(tx * 32.0), floori(ty * 32.0), 32)
		if h > 0.94 and stone < 0.5:
			c = [Color(1, 1, 0.95), Color(1.0, 0.85, 0.2), Color(0.62, 0.42, 0.9)][int(h * 1000.0) % 3]
		return c)
	return _finish(img, 64, 64)


## The mountain's shoulders either side of the cutting: tawny turf in
## bold patches of greener grass, a few grey stones showing through.
## Eight metres a repeat.
func _meadow() -> Image:
	var img := _canvas(128, 128, "meadow")
	_paint(img, func(tx: float, ty: float) -> Color:
		var green := smoothstep(0.52, 0.58, _fbm(tx, ty, 6, 4))
		var c := Color(0.62, 0.56, 0.32).lerp(Color(0.50, 0.52, 0.28), green)
		c = c.lightened(smoothstep(0.66, 0.72, _fbm(tx + 0.5, ty, 6, 3)) * 0.06)
		c = c.lightened((_hash(floori(tx * 512.0), floori(ty * 512.0), 512) - 0.5) * 0.1)
		var stone := smoothstep(0.76, 0.78, _fbm(tx + 0.7, ty + 0.4, 5, 3))
		var s := Color(0.56, 0.56, 0.58).lightened((_hash(floori(tx * 512.0), floori(ty * 512.0), 512) - 0.5) * 0.08)
		return c.lerp(s, stone))
	return _finish(img, 128, 128)


## Billows for the cloud shaders: soft round heaps, the full range from
## the hollows (dark) to the tops (light), in grey. Tiles.
func _billows() -> Image:
	var img := _canvas(128, 128, "billows")
	_paint(img, func(tx: float, ty: float) -> Color:
		var v := _fbm(tx, ty, 4, 5)
		# Rounded tops: the noise pushed through a soft curve.
		v = smoothstep(0.25, 0.75, v)
		v = sqrt(v)
		return Color(v, v, v))
	return _finish(img, 128, 128)


## The fake reflection by day: a deep blue overhead, paler to the
## horizon, the white of the cloud below, the sun high in the south-east.
func _reflection_day() -> Image:
	var img := _canvas(64, 64, "reflection_day")
	_paint(img, func(tx: float, ty: float) -> Color:
		var p := Vector2(tx * 2.0 - 1.0, 1.0 - ty * 2.0)
		var r := p.length()
		if r > 1.0:
			return Color(0.8, 0.84, 0.9)
		var z := 1.0 - r * r * 2.0
		var up := p.y * sqrt(maxf(0.0, 1.0 - z * z)) / maxf(r, 0.001)
		var sky := Color(0.28, 0.48, 0.86).lerp(Color(0.78, 0.86, 0.96), smoothstep(0.8, 0.0, up))
		if up < 0.0:
			sky = Color(0.92, 0.94, 0.97).darkened(smoothstep(0.0, -0.8, up) * 0.2)
		var sun := Vector2(p.x + 0.3, p.y - 0.45).length()
		return sky.lightened(clampf(0.05 / maxf(sun, 0.01) - 0.1, 0.0, 0.8)))
	return _finish(img, 64, 64)


# --- Posters ------------------------------------------------------------------------

## A travel poster, painted flat and soft: a sky, what's in it, a band at
## the foot for the words (added in 3D). 64 × 96.
func _poster(seed_text: String, paint: Callable) -> Image:
	var img := _canvas(64, 96, seed_text)
	_paint(img, func(tx: float, ty: float) -> Color:
		if ty > 0.8:
			return Color(0.14, 0.18, 0.34) if ty < 0.97 else Color(0.9, 0.86, 0.74)
		var c: Color = paint.call(tx, ty / 0.8)
		# Printed paper: a little grain.
		return c.darkened((_hash(floori(tx * 256.0), floori(ty * 384.0), 256) - 0.5) * 0.05))
	return _finish(img, 64, 96)


## "Nimbus": the peak over the cloud, a low sun, a railway climbing it.
func _poster_peak() -> Image:
	return _poster("poster_peak", func(x: float, y: float) -> Color:
		var c := Color(0.98, 0.72, 0.40).lerp(Color(0.26, 0.46, 0.80), smoothstep(0.7, 0.05, y))
		if Vector2(x - 0.72, y - 0.3).length() < 0.1:
			c = Color(1.0, 0.95, 0.75)
		var peak := 0.18 + absf(x - 0.42) * 1.5
		if y > peak:
			c = Color(0.38, 0.34, 0.46) if x > 0.42 else Color(0.56, 0.50, 0.62)
			if y < 0.3 + sin(x * 40.0) * 0.015:
				c = Color(0.97, 0.97, 1.0) if x < 0.42 else Color(0.80, 0.82, 0.92)
			# The line zigzagging up.
			var zig := absf(fmod(y * 6.0, 2.0) - 1.0) * 0.3 + 0.28
			if absf(x - zig) < 0.012 and y > 0.35:
				c = Color(0.6, 0.12, 0.14)
		var cloud := 0.62 + sin(x * 18.0) * 0.03 + sin(x * 7.0 + 1.0) * 0.04
		if y > cloud:
			c = Color(0.98, 0.96, 0.94).darkened(smoothstep(cloud, 1.0, y) * 0.2)
		return c)


## "The Cloud Line": a viaduct striding over the cloud, a train on it.
func _poster_viaduct() -> Image:
	return _poster("poster_viaduct", func(x: float, y: float) -> Color:
		var c := Color(0.95, 0.52, 0.42).lerp(Color(0.40, 0.30, 0.56), smoothstep(0.6, 0.0, y))
		var deck := 0.52
		if y > deck and y < deck + 0.05:
			c = Color(0.30, 0.18, 0.22)
		if y > deck + 0.05 and y < 0.85:
			var arch := fmod(x * 5.0, 1.0)
			var opening := Vector2(arch - 0.5, (y - 0.85) * 2.2).length() < 0.36
			c = c if opening else Color(0.36, 0.22, 0.26)
		if y > deck - 0.06 and y < deck and x > 0.2 and x < 0.62:
			c = Color(0.52, 0.08, 0.12) if fmod(x * 20.0, 1.0) > 0.12 else Color(0.2, 0.05, 0.06)
		if y > 0.75:
			c = c.lerp(Color(1.0, 0.95, 0.92), smoothstep(0.75, 0.82, y + sin(x * 14.0) * 0.02))
		return c)


## "Cirrus": a striped balloon high in a teal sky.
func _poster_balloon() -> Image:
	return _poster("poster_balloon", func(x: float, y: float) -> Color:
		var c := Color(0.42, 0.78, 0.76).lerp(Color(0.88, 0.95, 0.86), smoothstep(0.1, 0.9, y))
		var d := Vector2((x - 0.5) * 1.1, y - 0.36)
		if d.length() < 0.24 and y < 0.52 or (y >= 0.52 and y < 0.6 and absf(x - 0.5) < 0.24 - (y - 0.52) * 2.2):
			c = Color(0.92, 0.2, 0.22) if int(floor((x - 0.5) / 0.08 + 10.0)) % 2 == 0 else Color(0.98, 0.9, 0.74)
		if y > 0.64 and y < 0.7 and absf(x - 0.5) < 0.05:
			c = Color(0.45, 0.30, 0.18)
		for k in 3:
			var cc := Vector2(x - (0.2 + k * 0.3), (y - (0.8 - k * 0.12)) * 2.5)
			if cc.length() < 0.12:
				c = Color(1, 1, 1)
		return c)
