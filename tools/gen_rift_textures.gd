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
	_save(_rock(), "rock")
	_save(_cliff(), "cliff")
	_save(_scree(), "scree")
	_save(_snow(), "snow")
	_save(_snow_rock(), "snow_rock")
	_save(_alpine(), "alpine")
	_save(_meadow(), "meadow")
	_save(_clouds(), "clouds")
	_save(_reflection_day(), "reflection_day")
	_save(_poster_peak(), "poster_peak")
	_save(_poster_viaduct(), "poster_viaduct")
	_save(_poster_balloon(), "poster_balloon")
	quit()


# --- The ground ------------------------------------------------------------------------

## Track ballast: grey stone chippings, rust-brown where the rails shed, oil
## darker in places. Two metres a repeat.
func _ballast() -> Image:
	var img := _canvas(64, 64, "ballast")
	_paint(img, func(tx: float, ty: float) -> Color:
		# Chips about 5 cm: a jittered grid, each chip its own shade, lit
		# on its upper side.
		var gx := tx * 40.0 + _noise(tx * 40.0, ty * 40.0, 40) * 0.6
		var gy := ty * 40.0 + _noise(ty * 40.0 + 7.0, tx * 40.0, 40) * 0.6
		var stone := _hash(floori(gx), floori(gy), 40)
		var c := Color(0.56, 0.54, 0.51).lightened((stone - 0.5) * 0.3)
		var f := Vector2(fmod(gx, 1.0), fmod(gy, 1.0))
		c = c.darkened(smoothstep(0.35, 0.5, (f - Vector2(0.5, 0.5)).length()) * 0.35)
		c = c.lightened(smoothstep(0.3, 0.0, f.y) * 0.08)
		c = _dirty(c, smoothstep(0.55, 0.8, _fbm(tx, ty, 4, 4)) * 0.45, Color(0.40, 0.28, 0.20))
		return _dirty(c, smoothstep(0.7, 0.9, _fbm(tx + 0.5, ty, 3, 4)) * 0.4, Color(0.2, 0.19, 0.18)))
	return _finish(img, 64, 64)


## Pale limestone flags on the roofs and the galleries, a metre and a half
## square, worn at the middle, lichen in the joints, rain-darkened edges.
## Three metres a repeat.
func _flags() -> Image:
	var img := _canvas(64, 64, "flags")
	_paint(img, func(tx: float, ty: float) -> Color:
		var cell := _cell(tx, ty, 2, 2)
		var base := Color(0.80, 0.77, 0.70).darkened(_hash(cell[0], cell[1], 2) * 0.08)
		base = base.darkened((_fbm(tx, ty, 6, 4) - 0.5) * 0.14)
		base = base.darkened((1.0 - smoothstep(0.0, 0.12, cell[2])) * 0.12)
		var lichen := smoothstep(0.62, 0.8, _fbm(tx + 0.3, ty, 8, 3)) * (1.0 - smoothstep(0.0, 0.1, cell[2]))
		base = _dirty(base, lichen * 0.6, Color(0.62, 0.66, 0.42))
		return Color(0.40, 0.38, 0.34).lerp(base, _grout_mask(cell[2], 0.012)))
	return _finish(img, 64, 64)


## The mountain's rock under the station: grey granite in slabs, cracks
## running down, pale where it's weathered, darker streaks. Twelve metres a
## repeat.
func _rock() -> Image:
	var img := _canvas(64, 64, "rock")
	_paint(img, func(tx: float, ty: float) -> Color:
		var c := Color(0.50, 0.50, 0.53).darkened((_fbm(tx, ty, 3, 5) - 0.5) * 0.4)
		var joint := absf(fmod(tx * 3.0 + _fbm(tx, ty, 2, 3) * 0.8, 1.0) - 0.5)
		c = c.darkened((1.0 - smoothstep(0.0, 0.03, joint)) * 0.35)
		var ledge := absf(fmod(ty * 4.0 + _fbm(tx, ty, 3, 2) * 0.5, 1.0) - 0.5)
		c = c.lightened((1.0 - smoothstep(0.0, 0.05, ledge)) * 0.15)
		return _dirty(c, smoothstep(0.55, 0.8, _fbm(tx, ty * 0.2, 12, 3)) * 0.3, Color(0.3, 0.3, 0.33)))
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


## The cliff under the station, close: granite broken into big angular
## facets, each catching the light its own way, split again into smaller
## ones, soft dark cracks between; snow on the facets that face up,
## lichen, wet streaks. Sixteen metres a repeat.
func _cliff() -> Image:
	var img := _canvas(128, 128, "cliff")
	_paint(img, func(tx: float, ty: float) -> Color:
		var wx := tx + (_fbm(tx, ty, 3, 3) - 0.5) * 0.12
		var wy := ty + (_fbm(tx + 0.5, ty, 3, 3) - 0.5) * 0.08
		var big := _blocks(wx, wy, Vector2(6, 3), 11)
		var small := _blocks(wx, wy, Vector2(14, 7), 29)
		var f1 := _facet(big[0], 3, 6)
		var f2 := _facet(small[0], 9, 14)
		var light: float = float(f1[1]) * 0.65 + float(f2[1]) * 0.35
		var c := Color(0.30, 0.30, 0.33).lerp(Color(0.72, 0.70, 0.70), light)
		c = c.darkened((_fbm(tx, ty, 10, 3) - 0.5) * 0.12)
		c = c.darkened((1.0 - smoothstep(0.0, 0.1, big[2])) * 0.28 + (1.0 - smoothstep(0.0, 0.05, small[2])) * 0.08)
		var streak := smoothstep(0.64, 0.86, _fbm(tx, ty * 0.12, 20, 3))
		c = _dirty(c, streak * 0.3, Color(0.26, 0.25, 0.27))
		c = _dirty(c, smoothstep(0.72, 0.82, _fbm(tx + 0.4, ty + 0.1, 10, 3)) * 0.45, Color(0.74, 0.52, 0.28))
		c = _dirty(c, smoothstep(0.74, 0.84, _fbm(tx + 0.1, ty + 0.6, 12, 3)) * 0.35, Color(0.60, 0.66, 0.52))
		var up: float = -(f1[0] as Vector3).y
		var rel: Vector2 = big[1]
		var snow := smoothstep(0.18, 0.3, up) * smoothstep(0.0, -0.35, rel.y) * smoothstep(0.06, 0.14, big[2]) * smoothstep(0.45, 0.65, _fbm(tx, ty, 6, 3))
		return c.lerp(Color(0.93, 0.95, 1.0), snow))
	return _finish(img, 128, 128)


## Scree below the cliffs: angular broken stones of every size, grey and
## rust, each facet catching the light its own way, dark gaps and grit
## between. Twelve metres a repeat.
func _scree() -> Image:
	var img := _canvas(64, 64, "scree")
	_paint(img, func(tx: float, ty: float) -> Color:
		var big := _blocks(tx, ty, Vector2(9, 9), 5)
		var small := _blocks(tx, ty, Vector2(24, 24), 17)
		var use_big: bool = _hash((big[0] as Vector2i).x, (big[0] as Vector2i).y + 40, 9) > 0.72
		var b: Array = big if use_big else small
		var id: Vector2i = b[0]
		var f := _facet(id, 21, 24)
		var base := Color(0.52, 0.51, 0.50).lerp(Color(0.55, 0.42, 0.32), _hash(id.x + 2, id.y, 24) * 0.8)
		var c := base.darkened(0.35).lerp(base.lightened(0.2), float(f[1]))
		c = c.lerp(Color(0.22, 0.20, 0.19), (1.0 - smoothstep(0.0, 0.12, b[2])) * 0.7)
		return c.darkened((_fbm(tx, ty, 4, 3) - 0.5) * 0.15))
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


## Rock high up under snow: angular facets, the ones facing up buried
## in snow, the steep ones bare rock, a soft blue in the snow's shadows.
## Sixteen metres a repeat.
func _snow_rock() -> Image:
	var img := _canvas(64, 64, "snow_rock")
	_paint(img, func(tx: float, ty: float) -> Color:
		var wx := tx + (_fbm(tx, ty, 3, 3) - 0.5) * 0.12
		var b := _blocks(wx, ty, Vector2(5, 6), 23)
		var f := _facet(b[0], 13, 6)
		var n: Vector3 = f[0]
		var rock := Color(0.28, 0.28, 0.32).lerp(Color(0.62, 0.62, 0.66), float(f[1]))
		rock = rock.darkened((1.0 - smoothstep(0.0, 0.08, b[2])) * 0.4)
		var cover := smoothstep(-0.05, 0.2, -n.y + (_fbm(tx, ty, 10, 3) - 0.5) * 0.4)
		var snow := Color(0.78, 0.84, 0.96).lerp(Color(1, 1, 1), float(f[1]))
		return rock.lerp(snow, cover))
	return _finish(img, 64, 64)


## Alpine turf on the rockeries: short tawny-green grass, cushions of moss,
## white and yellow and violet flowers dotted in, grey stones. Eight
## metres a repeat.
func _alpine() -> Image:
	var img := _canvas(64, 64, "alpine")
	_paint(img, func(tx: float, ty: float) -> Color:
		var c := Color(0.44, 0.52, 0.28).lerp(Color(0.62, 0.58, 0.34), _fbm(tx, ty, 5, 4))
		c = c.darkened((_hash(floori(tx * 200.0), floori(ty * 200.0), 200) - 0.5) * 0.18)
		var moss := smoothstep(0.6, 0.75, _fbm(tx + 0.3, ty, 8, 3))
		c = c.lerp(Color(0.30, 0.46, 0.22), moss * 0.6)
		var stone := smoothstep(0.74, 0.8, _fbm(tx + 0.7, ty + 0.4, 6, 3))
		c = c.lerp(Color(0.62, 0.61, 0.6), stone)
		var h := _hash(floori(tx * 90.0), floori(ty * 90.0), 90)
		if h > 0.965 and stone < 0.5:
			c = [Color(1, 1, 0.95), Color(1.0, 0.85, 0.2), Color(0.62, 0.42, 0.9)][int(h * 1000.0) % 3]
		return c)
	return _finish(img, 64, 64)


## The mountain's shoulders either side of the cutting, in big soft
## patches: tawny turf, grey rock breaking through, old snow lying in the
## hollows, frost on the grass round it. Twenty-four metres a repeat.
func _meadow() -> Image:
	var img := _canvas(128, 128, "meadow")
	_paint(img, func(tx: float, ty: float) -> Color:
		var c := Color(0.50, 0.50, 0.30).lerp(Color(0.64, 0.56, 0.36), _fbm(tx, ty, 6, 4))
		c = c.darkened((_hash(floori(tx * 320.0), floori(ty * 320.0), 320) - 0.5) * 0.14)
		c = c.lerp(Color(0.36, 0.44, 0.26), smoothstep(0.58, 0.75, _fbm(tx + 0.3, ty, 10, 3)) * 0.5)
		var rock := smoothstep(0.64, 0.7, _fbm(tx + 0.7, ty + 0.4, 5, 4))
		var stone := Color(0.52, 0.52, 0.55).darkened((_fbm(tx, ty, 24, 3) - 0.5) * 0.4)
		c = c.lerp(stone, rock)
		# Old snow in a few small hollows, frost round it.
		var drift := _fbm(tx + 0.2, ty + 0.9, 4, 5) - (_fbm(tx, ty, 16, 2) - 0.5) * 0.12
		c = c.lerp(Color(0.72, 0.74, 0.70), smoothstep(0.62, 0.68, drift) * 0.5 * (1.0 - rock))
		var snow := smoothstep(0.69, 0.72, drift)
		# Tufts: fine dark and light flecks.
		var tuft := _hash(floori(tx * 256.0), floori(ty * 256.0), 256)
		c = c.darkened(maxf(0.0, 0.3 - tuft) * 0.4).lightened(maxf(0.0, tuft - 0.85) * 0.6)
		return c.lerp(Color(0.86, 0.88, 0.92).darkened((_fbm(tx, ty, 12, 2) - 0.5) * 0.15), snow))
	return _finish(img, 128, 128)


## The sea of cloud seen from above: soft white billows, shaded blue-grey
## in their hollows. A hundred and sixty metres a repeat.
func _clouds() -> Image:
	var img := _canvas(128, 128, "clouds")
	_paint(img, func(tx: float, ty: float) -> Color:
		var b := _fbm(tx, ty, 4, 5)
		var billow := smoothstep(0.35, 0.75, b)
		var c := Color(0.76, 0.81, 0.90).lerp(Color(1.0, 0.99, 0.97), billow)
		# The sunny side of each billow.
		var lit := _fbm(tx + 0.02, ty - 0.02, 4, 5) - b
		return c.lightened(clampf(lit * 3.0, 0.0, 0.1)))
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
