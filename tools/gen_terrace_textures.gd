extends "res://tools/texture_painter.gd"
## Generates Terrace's textures (the dead mall's food court under the
## eclipse, GDD §9.3) into assets/textures/terrace/:
##
##   godot --headless --path . --script res://tools/gen_terrace_textures.gd
##
## Painted soft (tools/texture_painter.gd). The directory's map is drawn
## from the map's own layout (tools/maps/terrace.gd). Paint over the PNGs
## freely.

const OUT := "res://assets/textures/terrace/"
const LevelKit := preload("res://tools/level_kit.gd")
const Terrace := preload("res://tools/maps/terrace.gd")


func _initialize() -> void:
	out_dir = OUT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_save(_terrazzo(), "terrazzo")
	_save(_pavers(), "pavers")
	_save(_stucco(), "stucco")
	_save(_cladding(), "cladding")
	_save(_shutter(), "shutter")
	_save(_treads(true), "treads")
	_save(_treads(false), "travelator")
	_save(_vending(Color(0.78, 0.10, 0.12), true), "vending_drinks")
	_save(_vending(Color(0.12, 0.28, 0.70), false), "vending_snacks")
	_save(_menu(), "menu")
	_save(_directory(), "directory")
	_save(_foliage(), "foliage")
	_save(_wood(), "wood")
	_save(_carpet(), "carpet")
	_save(_grime(), "grime")
	_save(_reflection_eclipse(), "reflection_eclipse")
	_save(_far_mall(), "far_mall")
	_save(_far_garage(), "far_garage")
	quit()


# --- Floors ---------------------------------------------------------------------------

## Cream terrazzo in 1.5 m squares split by brass strips, chips of red,
## grey, black and teal set in it, scuffed paler where people walked and
## grey in the corners.
func _terrazzo() -> Image:
	var img := _canvas(128, 128, "terrazzo")
	var chips := [Color(0.62, 0.26, 0.20), Color(0.36, 0.36, 0.38), Color(0.12, 0.12, 0.13), Color(0.30, 0.52, 0.50),
			Color(0.92, 0.90, 0.86), Color(0.70, 0.56, 0.36)]
	_paint(img, func(tx: float, ty: float) -> Color:
		var c := Color(0.80, 0.75, 0.66).darkened((_fbm(tx, ty, 5, 4) - 0.5) * 0.14)
		# Chips: the nearest of a jittered grid of points, if it's a chip.
		var cells := 34.0
		var gx := tx * cells
		var gy := ty * cells
		var best := 9.0
		var pick := 0.0
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				var ix := floori(gx) + ox
				var iy := floori(gy) + oy
				var px := ix + _hash(ix, iy, 34)
				var py := iy + _hash(iy + 91, ix, 34)
				var dist := Vector2(gx - px, gy - py).length() / (0.18 + 0.3 * _hash(ix + 17, iy + 5, 34))
				if dist < best:
					best = dist
					pick = _hash(ix + 7, iy + 3, 34)
		if best < 1.0:
			c = c.lerp(chips[int(pick * chips.size()) % chips.size()], 0.85 * smoothstep(1.0, 0.7, best))
		# Brass strips round each square (two squares a repeat).
		var sx := minf(fmod(tx * 2.0, 1.0), 1.0 - fmod(tx * 2.0, 1.0))
		var sy := minf(fmod(ty * 2.0, 1.0), 1.0 - fmod(ty * 2.0, 1.0))
		var strip := 1.0 - smoothstep(0.004, 0.012, minf(sx, sy))
		c = c.lerp(Color(0.66, 0.52, 0.26), strip * 0.9)
		c = c.lightened(smoothstep(0.55, 0.85, _fbm(tx + 0.4, ty, 2, 3)) * 0.08)
		return _dirty(c, smoothstep(0.6, 0.9, _fbm(tx, ty + 0.2, 3, 5)) * 0.25, Color(0.42, 0.40, 0.38)))
	return _finish(img, 128, 128)


## The upper level's pavers: grey-blue granite slabs a metre by half a
## metre, every other row shifted, speckled, dark grout.
func _pavers() -> Image:
	var img := _canvas(64, 64, "pavers")
	_paint(img, func(tx: float, ty: float) -> Color:
		var row := floori(ty * 4.0)
		var x := tx * 2.0 + (0.5 if row % 2 == 1 else 0.0)
		var ix := floori(x)
		var fx := x - ix
		var fy := ty * 4.0 - row
		var edge := minf(minf(fx, 1.0 - fx) * 2.0, minf(fy, 1.0 - fy)) * 0.5
		var base := Color(0.46, 0.49, 0.53).lerp(Color(0.54, 0.55, 0.57), _hash(posmod(ix, 2), row, 4))
		var speck := _hash(floori(tx * 256.0), floori(ty * 256.0), 256)
		base = base.lightened((speck - 0.5) * 0.18).darkened((_fbm(tx, ty, 4) - 0.5) * 0.15)
		var c := Color(0.22, 0.22, 0.24).lerp(base, _grout_mask(edge, 0.03))
		return _dirty(c, smoothstep(0.62, 0.9, _fbm(tx + 0.7, ty, 3, 5)) * 0.3, Color(0.28, 0.27, 0.26)))
	return _finish(img, 64, 64)


# --- Walls ------------------------------------------------------------------------------

## The mall's walls: warm sand stucco, blotchy, streaked grey where the rain
## ran down from the top.
func _stucco() -> Image:
	var img := _canvas(64, 64, "stucco")
	_paint(img, func(tx: float, ty: float) -> Color:
		var c := Color(0.78, 0.68, 0.56).darkened((_fbm(tx, ty, 6, 5) - 0.5) * 0.18)
		var streak := _fbm(tx * 1.0, ty * 0.12, 16, 3)
		c = _dirty(c, smoothstep(0.55, 0.8, streak) * 0.3, Color(0.50, 0.46, 0.42))
		return c.darkened((_hash(floori(tx * 256.0), floori(ty * 256.0), 256) - 0.5) * 0.06))
	return _finish(img, 64, 64)


## Dark polished granite panels, a metre square, pale joints: the fascias,
## the information desk, the bridge's sides. Speckled, clouded, no veins.
func _cladding() -> Image:
	var img := _canvas(64, 64, "cladding")
	_paint(img, func(tx: float, ty: float) -> Color:
		var cell := _cell(tx, ty, 2, 2)
		var base := Color(0.17, 0.16, 0.18).lerp(Color(0.21, 0.19, 0.21), _hash(cell[0], cell[1], 2))
		base = base.lightened((_fbm(tx, ty, 6, 4) - 0.5) * 0.12)
		var speck := _hash(floori(tx * 256.0), floori(ty * 256.0), 256)
		base = base.lightened(maxf(speck - 0.8, 0.0) * 0.9).darkened(maxf(0.15 - speck, 0.0) * 1.2)
		return Color(0.46, 0.44, 0.42).lerp(base, _grout_mask(cell[2], 0.012)))
	return _finish(img, 64, 64)


## A roller shutter: pressed steel slats, grey, grimy at the joints, a
## metre a repeat.
func _shutter() -> Image:
	var img := _canvas(64, 64, "shutter")
	_paint(img, func(tx: float, ty: float) -> Color:
		var slat := fmod(ty * 12.0, 1.0)
		var shade := 0.62 + 0.18 * sin(slat * PI) - 0.25 * (1.0 - smoothstep(0.0, 0.12, slat))
		var c := Color(shade, shade * 1.01, shade * 1.03)
		c = c.darkened((_fbm(tx, ty, 4, 4) - 0.5) * 0.2)
		return _dirty(c, smoothstep(0.6, 0.85, _fbm(tx, ty * 0.5, 3, 5)) * 0.35, Color(0.36, 0.33, 0.30)))
	return _finish(img, 64, 64)


## Escalator treads (grooved aluminium, a yellow edge on each step) or a
## travelator's flat pallets (grooves, seams). 0.8 m a repeat: two steps.
func _treads(steps: bool) -> Image:
	var img := _canvas(64, 64, "treads" if steps else "travelator")
	_paint(img, func(tx: float, ty: float) -> Color:
		var groove := 0.5 + 0.5 * sin(tx * TAU * 16.0)
		var c := Color(0.58, 0.60, 0.62).darkened(0.35 * smoothstep(0.6, 1.0, groove))
		c = c.darkened((_fbm(tx, ty, 4) - 0.5) * 0.15)
		var step_at := fmod(ty * 2.0, 1.0)
		if steps:
			var edge := 1.0 - smoothstep(0.06, 0.09, step_at)
			c = c.lerp(Color(0.92, 0.74, 0.12).darkened(0.25 * smoothstep(0.6, 1.0, groove)), edge * 0.9)
			c = c.darkened((1.0 - smoothstep(0.0, 0.02, absf(step_at - 0.09))) * 0.4)
		else:
			c = c.darkened((1.0 - smoothstep(0.0, 0.015, minf(step_at, 1.0 - step_at))) * 0.45)
		return _dirty(c, smoothstep(0.6, 0.9, _fbm(tx + 0.3, ty, 2, 4)) * 0.3, Color(0.25, 0.24, 0.24)))
	return _finish(img, 64, 64)


# --- Lit things --------------------------------------------------------------------------

## A vending machine's front, a metre by two: a coloured body, a lit window
## of cans (drinks) or packets on coils (snacks), a column of buttons.
func _vending(body: Color, drinks: bool) -> Image:
	var img := _canvas(64, 128, "vending_drinks" if drinks else "vending_snacks")
	var items := [Color(0.9, 0.15, 0.1), Color(0.95, 0.8, 0.1), Color(0.2, 0.6, 0.95), Color(0.3, 0.8, 0.3),
			Color(0.95, 0.5, 0.1), Color(0.8, 0.3, 0.8), Color(0.95, 0.95, 0.95)]
	_paint(img, func(tx: float, ty: float) -> Color:
		var c := body.darkened((_fbm(tx, ty, 4) - 0.5) * 0.2)
		# The name band along the top: a pale stripe.
		if ty > 0.04 and ty < 0.11 and tx > 0.08 and tx < 0.92:
			c = Color(0.95, 0.93, 0.88)
		# The window.
		if tx > 0.07 and tx < 0.70 and ty > 0.15 and ty < 0.80:
			var wx := (tx - 0.07) / 0.63
			var wy := (ty - 0.15) / 0.65
			var rows := 6.0
			var cols := 5.0 if drinks else 4.0
			var row := floori(wy * rows)
			var col := floori(wx * cols)
			var fx := wx * cols - col
			var fy := wy * rows - row
			var back := Color(0.85, 0.88, 0.92).lerp(Color(0.55, 0.60, 0.68), wy)
			var item: Color = items[int(_hash(col, row, 7) * items.size()) % items.size()]
			var inside := false
			if drinks:
				inside = absf(fx - 0.5) < 0.3 and fy > 0.25 and fy < 0.9
			else:
				inside = absf(fx - 0.5) < 0.38 and fy > 0.12 and fy < 0.72 and _hash(col + 3, row, 7) > 0.2
			c = item.lightened(0.15 * (1.0 - absf(fx - 0.5) * 3.0)) if inside else back
			if fy > 0.9:
				c = Color(0.35, 0.36, 0.38)  # The shelf.
		# The buttons and the coin slot.
		if tx > 0.76 and tx < 0.92 and ty > 0.2 and ty < 0.6:
			var b := fmod((ty - 0.2) * 20.0, 1.0)
			c = Color(0.85, 0.85, 0.82) if b < 0.6 else Color(0.2, 0.2, 0.22)
		if tx > 0.8 and tx < 0.88 and ty > 0.64 and ty < 0.7:
			c = Color(0.1, 0.1, 0.1)
		# The flap at the bottom.
		if tx > 0.1 and tx < 0.66 and ty > 0.84 and ty < 0.93:
			c = Color(0.08, 0.08, 0.09)
		return c)
	return _finish(img, 64, 128)


## A menu board, four metres by one: pictures of the food in a row of
## panels over lines of prices.
func _menu() -> Image:
	var img := _canvas(128, 32, "menu")
	var foods := [Color(0.85, 0.55, 0.2), Color(0.75, 0.25, 0.15), Color(0.95, 0.85, 0.4), Color(0.5, 0.7, 0.3), Color(0.9, 0.4, 0.3)]
	_paint(img, func(tx: float, ty: float) -> Color:
		var panel := floori(tx * 4.0)
		var px := tx * 4.0 - panel
		var c := Color(0.95, 0.93, 0.86)
		if px < 0.03 or px > 0.97:
			return Color(0.2, 0.18, 0.18)
		# A photo of the food: a blob on a plate, the top half.
		if ty < 0.6:
			var d := Vector2((px - 0.5) * 1.6, (ty - 0.32) * 3.2).length()
			c = Color(0.35, 0.18, 0.12) if ty < 0.08 else Color(0.97, 0.95, 0.9)
			if d < 0.7:
				c = Color(0.92, 0.92, 0.9)
			var blob := d + (_fbm(tx * 3.0, ty, 4, 3) - 0.5) * 0.4
			if blob < 0.45:
				c = (foods[panel % foods.size()] as Color).darkened((_fbm(tx, ty, 8, 3) - 0.5) * 0.5)
		else:
			# Lines of words and prices.
			var line := fmod(ty * 10.0, 1.0)
			var in_line := line > 0.3 and line < 0.7 and ((px > 0.08 and px < 0.62) or (px > 0.75 and px < 0.9))
			if in_line and _noise(tx * 90.0, floorf(ty * 10.0), 90) > 0.35:
				c = c.lerp(Color(0.2, 0.12, 0.1), 0.8)
		return c)
	return _finish(img, 128, 32)


## The mall directory: the map's own plan from above (the food court
## cream, the upper level blue, blocks darker the higher they are), the
## escalators striped, a red "you are here" at the directory itself.
func _directory() -> Image:
	var kit := LevelKit.new("Plan", Environment.new())
	Terrace.build(kit)
	var boxes := []
	for b: Node in kit.geometry.get_children():
		if b is GreyBox and not String(b.name).begins_with("Boundary"):
			var g := b as GreyBox
			var top := []
			for sx: float in [-0.5, 0.5]:
				for sz: float in [-0.5, 0.5]:
					top.append(g.transform * (Vector3(sx, 0.5, sz) * g.size))
			var poly := PackedVector2Array([Vector2(top[0].x, top[0].z), Vector2(top[1].x, top[1].z), Vector2(top[3].x, top[3].z), Vector2(top[2].x, top[2].z)])
			boxes.append([(top[0].y + top[1].y + top[2].y + top[3].y) * 0.25, poly, g.kind])
	boxes.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	kit.root.free()
	var w := 128
	var h := 96
	_seed = hash("directory")
	var img := Image.create_empty(w * 2, h * 2, false, Image.FORMAT_RGB8)
	var here := Vector2(-8.0, 1.0)
	for y in h * 2:
		for x in w * 2:
			# 52 × 39 m of map across the panel, a margin round it.
			var p := Vector2((x + 0.5) / (w * 2) * 52.0 - 26.0, (y + 0.5) / (h * 2) * 39.0 - 19.5)
			var c := Color(0.20, 0.22, 0.30)
			if absf(p.x) < 24.0 and absf(p.y) < 18.0:
				c = Color(0.93, 0.88, 0.76)
			for b: Array in boxes:
				if Geometry2D.is_point_in_polygon(p, b[1]):
					var height: float = b[0]
					if b[2] == GreyBox.Kind.RAMP:
						c = Color(0.62, 0.64, 0.68) if fmod(p.x * 2.0, 1.0) < 0.5 else Color(0.8, 0.8, 0.82)
					elif height >= 3.9 and b[2] == GreyBox.Kind.FLOOR:
						c = Color(0.62, 0.78, 0.92)
					elif height > 0.1:
						c = Color(0.93, 0.88, 0.76).lerp(Color(0.36, 0.30, 0.34), clampf(height / 7.0, 0.25, 1.0))
			if p.distance_to(here) < 1.3:
				c = Color(0.95, 0.12, 0.15)
			elif p.distance_to(here) < 1.8:
				c = Color(1, 1, 1)
			img.set_pixel(x, y, c)
	return _finish(img, w, h)


# --- Things ----------------------------------------------------------------------------------

## Fake plants: dark glossy leaves, overlapping, a little dust.
func _foliage() -> Image:
	var img := _canvas(64, 64, "foliage")
	_paint(img, func(tx: float, ty: float) -> Color:
		var n := _fbm(tx, ty, 8, 4)
		var leaf := smoothstep(0.42, 0.5, n) * (1.0 - smoothstep(0.62, 0.7, n))
		var c := Color(0.08, 0.18, 0.10).lerp(Color(0.20, 0.42, 0.20), leaf)
		return c.lightened(smoothstep(0.7, 0.9, _fbm(tx + 0.5, ty, 3, 4)) * 0.15))
	return _finish(img, 64, 64)


## Warm varnished oak planks, 20 cm wide, a metre a repeat.
func _wood() -> Image:
	var img := _canvas(64, 64, "wood")
	_paint(img, func(tx: float, ty: float) -> Color:
		var plank := floori(ty * 5.0)
		var grain := _fbm(tx * 0.3 + plank * 0.37, ty * 6.0, 8, 3)
		var c := Color(0.56, 0.36, 0.20).lerp(Color(0.70, 0.48, 0.28), grain)
		c = c.darkened(_hash(plank, 1, 5) * 0.15)
		var seam := minf(fmod(ty * 5.0, 1.0), 1.0 - fmod(ty * 5.0, 1.0))
		return c.darkened((1.0 - smoothstep(0.0, 0.05, seam)) * 0.4))
	return _finish(img, 64, 64)


## Cinema carpet for the stage: dark blue-black with neon squiggles and
## stars, worn in patches. Two metres a repeat.
func _carpet() -> Image:
	var img := _canvas(64, 64, "carpet")
	var inks := [Color(0.95, 0.3, 0.6), Color(0.3, 0.8, 0.95), Color(0.95, 0.8, 0.2), Color(0.5, 0.35, 0.95)]
	_paint(img, func(tx: float, ty: float) -> Color:
		var c := Color(0.07, 0.07, 0.12).lightened((_hash(floori(tx * 256.0), floori(ty * 256.0), 256) - 0.5) * 0.12)
		var cell := _cell(tx, ty, 6, 6)
		var k := _hash(cell[0], cell[1], 6)
		var fx := fmod(tx * 6.0, 1.0)
		var fy := fmod(ty * 6.0, 1.0)
		if k > 0.45:
			# A squiggle across the cell.
			var wave := 0.5 + 0.28 * sin(fx * TAU * 1.5 + k * 9.0)
			if absf(fy - wave) < 0.07 and fx > 0.12 and fx < 0.88:
				c = inks[int(k * 97.0) % inks.size()]
		elif k < 0.2 and Vector2(fx - 0.5, fy - 0.5).length() < 0.1:
			c = inks[int(k * 53.0) % inks.size()]
		return c.darkened(smoothstep(0.55, 0.85, _fbm(tx, ty, 3, 4)) * 0.3))
	return _finish(img, 64, 64)


## Grime on glass: soft blotches and dried drips, white on black (how much).
func _grime() -> Image:
	var img := _canvas(64, 64, "grime")
	_paint(img, func(tx: float, ty: float) -> Color:
		var blotch := smoothstep(0.5, 0.85, _fbm(tx, ty, 4, 5))
		var drips := smoothstep(0.62, 0.9, _fbm(tx * 1.0, ty * 0.15, 24, 3)) * 0.6
		var v := clampf(blotch + drips, 0.0, 1.0)
		return Color(v, v, v))
	return _finish(img, 64, 64)


## The fake reflection under the eclipse: a dark blue sky, the orange
## glow all round the horizon, the corona high up.
func _reflection_eclipse() -> Image:
	var img := _canvas(64, 64, "reflection_eclipse")
	_paint(img, func(tx: float, ty: float) -> Color:
		var p := Vector2(tx * 2.0 - 1.0, 1.0 - ty * 2.0)
		var r := p.length()
		if r > 1.0:
			return Color(0.05, 0.04, 0.06)
		# Sphere map: which way this texel reflects (y up).
		var z := 1.0 - r * r * 2.0
		var up := p.y * sqrt(maxf(0.0, 1.0 - z * z)) / maxf(r, 0.001)
		var sky := Color(0.05, 0.06, 0.14).lerp(Color(0.14, 0.14, 0.30), smoothstep(0.7, 0.2, up))
		sky = sky.lerp(Color(0.95, 0.52, 0.24), smoothstep(0.25, -0.02, absf(up)) * 0.9)
		if up < -0.05:
			sky = Color(0.10, 0.08, 0.08)
		var corona := Vector2(p.x + 0.28, p.y - 0.42).length()
		sky = sky.lightened(clampf(0.08 / maxf(corona, 0.01) - 0.3, 0.0, 0.7))
		if corona < 0.05:
			sky = Color(0.01, 0.01, 0.02)
		return sky)
	return _finish(img, 64, 64)


# --- The mall outside ---------------------------------------------------------------------

## The mall's outside walls, far off: beige panels in bands, ribbed, a dark
## line of vents, stains. Twelve metres a repeat.
func _far_mall() -> Image:
	var img := _canvas(64, 64, "far_mall")
	_paint(img, func(tx: float, ty: float) -> Color:
		var c := Color(0.62, 0.52, 0.46).darkened((_fbm(tx, ty, 4) - 0.5) * 0.15)
		var rib := fmod(tx * 16.0, 1.0)
		c = c.darkened((1.0 - smoothstep(0.0, 0.12, rib)) * 0.2)
		var band := fmod(ty * 3.0, 1.0)
		if band < 0.06:
			c = Color(0.34, 0.28, 0.28)
		if band > 0.12 and band < 0.16 and fmod(tx * 32.0, 1.0) < 0.6:
			c = Color(0.2, 0.18, 0.18)
		return _dirty(c, smoothstep(0.6, 0.85, _fbm(tx, ty * 0.3, 6, 3)) * 0.3, Color(0.35, 0.3, 0.28)))
	return _finish(img, 64, 64)


## A parking garage far off: concrete decks with the dark gaps between
## them lit orange by sodium lamps.
func _far_garage() -> Image:
	var img := _canvas(64, 64, "far_garage")
	_paint(img, func(tx: float, ty: float) -> Color:
		var deck := fmod(ty * 4.0, 1.0)
		if deck < 0.3:
			return Color(0.66, 0.62, 0.58).darkened((_fbm(tx, ty, 4) - 0.5) * 0.2)
		var lamp := 1.0 - smoothstep(0.0, 0.08, absf(fmod(tx * 8.0, 1.0) - 0.5))
		var glow := Color(0.30, 0.16, 0.06).lerp(Color(1.4, 0.72, 0.28), lamp * smoothstep(0.35, 0.5, deck))
		var pillar := fmod(tx * 4.0, 1.0) < 0.1
		return Color(0.45, 0.42, 0.40) if pillar else glow)
	return _finish(img, 64, 64)
