extends "res://tools/texture_painter.gd"
## Generates Switchback's textures (the car park that never reaches the
## top, at dusk, GDD §9.3) into assets/textures/switchback/:
##
##   godot --headless --path . --script res://tools/gen_switchback_textures.gd
##
## Painted soft (tools/texture_painter.gd): concrete stained by rain and
## oil, paint worn off where the tyres go. Paint over the PNGs freely.

const OUT := "res://assets/textures/switchback/"


func _initialize() -> void:
	out_dir = OUT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_save(_deck(), "deck")
	_save(_ramp(), "ramp")
	_save(_wall(), "wall")
	_save(_paint_worn(), "paint")
	_save(_roof(), "roof")
	_save(_car_cover(), "car_cover")
	_save(_reflection_dusk(), "reflection_dusk")
	_save(_far_decks(), "far_decks")
	_save(_far_hill(), "far_hill")
	quit()


# --- Concrete ---------------------------------------------------------------------------

## A parking deck: power-floated concrete gone grey-brown, a saw cut across
## the middle, darker where the tyres polish it, oil dripped where the cars
## stood, puddle marks dried pale. Six metres a repeat.
func _deck() -> Image:
	var img := _canvas(128, 128, "deck")
	_paint(img, func(tx: float, ty: float) -> Color:
		var c := Color(0.47, 0.46, 0.44).darkened((_fbm(tx, ty, 4, 5) - 0.5) * 0.3)
		c = c.lightened((_fbm(tx + 0.3, ty, 16, 3) - 0.5) * 0.08)
		# Trowel swirls: faint, broad.
		c = c.darkened((_fbm(tx * 2.0, ty, 6, 2) - 0.5) * 0.06)
		# Saw cuts: one across, one along, soft.
		for cut: float in [absf(fmod(tx + 0.5, 1.0) - 0.5), absf(fmod(ty + 0.5, 1.0) - 0.5)]:
			c = c.darkened((1.0 - smoothstep(0.0, 0.006, cut)) * 0.35)
		# Oil: soft dark blotches, a ring of lighter stain round each.
		var oil := smoothstep(0.66, 0.82, _fbm(tx + 0.7, ty + 0.1, 5, 4))
		c = _dirty(c, oil * 0.6, Color(0.16, 0.14, 0.13))
		# Dried puddle marks, pale.
		var tide := smoothstep(0.62, 0.7, _fbm(tx, ty + 0.5, 3, 4)) * (1.0 - smoothstep(0.7, 0.78, _fbm(tx, ty + 0.5, 3, 4)))
		c = c.lightened(tide * 0.1)
		return c.darkened((_hash(floori(tx * 512.0), floori(ty * 512.0), 512) - 0.5) * 0.08))
	return _finish(img, 128, 128)


## A ramp's grooves: concrete brushed across in a herringbone for grip,
## grimed in the grooves. Two metres a repeat.
func _ramp() -> Image:
	var img := _canvas(64, 64, "ramp")
	_paint(img, func(tx: float, ty: float) -> Color:
		var c := Color(0.50, 0.49, 0.46).darkened((_fbm(tx, ty, 4, 5) - 0.5) * 0.28)
		# V grooves, the point up the slope: every 10 cm.
		var v := ty * 20.0 + absf(tx - 0.5) * 8.0
		var groove := 1.0 - smoothstep(0.0, 0.18, absf(fmod(v, 1.0) - 0.5) * 2.0 - 0.6)
		c = c.darkened(groove * 0.3)
		c = _dirty(c, groove * smoothstep(0.4, 0.8, _fbm(tx, ty, 6, 3)) * 0.4, Color(0.22, 0.20, 0.18))
		# Tyre polish down the middle of each half.
		var track := 1.0 - smoothstep(0.05, 0.16, minf(absf(tx - 0.25), absf(tx - 0.75)))
		c = c.darkened(track * 0.1)
		return c)
	return _finish(img, 64, 64)


## The walls: board-marked concrete, the planks' grain and seams running
## across, tie holes in rows, rain streaking down from the top in rust and
## soot, white salts bloomed at the foot. Four metres a repeat.
func _wall() -> Image:
	var img := _canvas(128, 128, "wall")
	_paint(img, func(tx: float, ty: float) -> Color:
		var c := Color(0.55, 0.54, 0.51).darkened((_fbm(tx, ty, 4, 5) - 0.5) * 0.24)
		# Boards 15 cm tall: each its own shade, grain along it, soft seams.
		var row := floori(ty * 26.0)
		var along := fmod(ty * 26.0, 1.0)
		c = c.darkened((_hash(row, floori(tx * 3.0 + _hash(row, 7, 64) * 3.0), 64) - 0.5) * 0.08)
		c = c.darkened((_fbm(tx * 0.25, ty * 6.0, 16, 2) - 0.5) * 0.1)
		c = c.darkened((1.0 - smoothstep(0.0, 0.1, minf(along, 1.0 - along))) * 0.14)
		# Tie holes: 1 m by 0.6 m.
		for hole: Vector2 in [Vector2(0.125, 0.1), Vector2(0.375, 0.1), Vector2(0.625, 0.1), Vector2(0.875, 0.1),
				Vector2(0.125, 0.6), Vector2(0.375, 0.6), Vector2(0.625, 0.6), Vector2(0.875, 0.6)]:
			var d := Vector2(tx, ty).distance_to(hole)
			c = c.darkened((1.0 - smoothstep(0.004, 0.011, d)) * 0.45)
			# Each weeps a little rust.
			var below := ty - hole.y
			if below > 0.0 and below < 0.2:
				c = _dirty(c, (1.0 - smoothstep(0.0, 0.006, absf(tx - hole.x))) * (1.0 - below / 0.2) * 0.3, Color(0.46, 0.30, 0.20))
		# Rain streaks, darker toward the top.
		var streak := smoothstep(0.52, 0.8, _fbm(tx, ty * 0.08, 24, 3))
		c = _dirty(c, streak * (0.5 - ty * 0.25), Color(0.25, 0.25, 0.26))
		# Salts at the foot.
		var bloom := smoothstep(0.75, 1.0, ty) * smoothstep(0.45, 0.75, _fbm(tx, ty, 8, 4))
		return c.lerp(Color(0.80, 0.80, 0.76), bloom * 0.35))
	return _finish(img, 128, 128)


## Road paint worn thin: off-white, the concrete showing through in
## specks and where the tyres cross. Tinted for the yellow and the colours.
## A metre a repeat.
func _paint_worn() -> Image:
	var img := _canvas(64, 64, "paint")
	_paint(img, func(tx: float, ty: float) -> Color:
		var paint := Color(0.88, 0.87, 0.83).darkened((_fbm(tx, ty, 4, 4) - 0.5) * 0.12)
		var bare := Color(0.46, 0.45, 0.43)
		var worn := smoothstep(0.64, 0.8, _fbm(tx, ty, 6, 5))
		var speck := 1.0 if _hash(floori(tx * 256.0), floori(ty * 256.0), 256) > 0.9 else 0.0
		return paint.lerp(bare, clampf(worn * 0.6 + speck * 0.4, 0.0, 1.0)))
	return _finish(img, 64, 64)


## The huts' flat roofs: grey chippings over felt, a darker patch where
## the rain sits. Two metres a repeat.
func _roof() -> Image:
	var img := _canvas(64, 64, "roof")
	_paint(img, func(tx: float, ty: float) -> Color:
		var stone := _hash(floori(tx * 160.0), floori(ty * 160.0), 160)
		var c := Color(0.42, 0.41, 0.40).lightened((stone - 0.5) * 0.35)
		c = c.darkened((_fbm(tx, ty, 4, 4) - 0.5) * 0.25)
		return _dirty(c, smoothstep(0.6, 0.8, _fbm(tx + 0.2, ty, 3, 4)) * 0.4, Color(0.18, 0.18, 0.19)))
	return _finish(img, 64, 64)


## A car cover: silver-grey fabric, soft folds, dust and leaves' stains.
## Two metres a repeat.
func _car_cover() -> Image:
	var img := _canvas(64, 64, "car_cover")
	_paint(img, func(tx: float, ty: float) -> Color:
		var fold := sin((tx * 3.0 + _fbm(tx, ty, 3, 3) * 1.6) * TAU) * 0.5 + 0.5
		var c := Color(0.66, 0.67, 0.70).darkened(fold * 0.18)
		c = c.darkened((_fbm(tx, ty, 8, 3) - 0.5) * 0.1)
		return _dirty(c, smoothstep(0.62, 0.85, _fbm(tx + 0.4, ty, 4, 4)) * 0.4, Color(0.42, 0.38, 0.32)))
	return _finish(img, 64, 64)


# --- Sky and far off ---------------------------------------------------------------------

## The fake reflection at dusk: deep blue overhead, pink and orange low
## down, the last of the sun in the south-west, the sodium lamps' orange
## just above the horizon all round.
func _reflection_dusk() -> Image:
	var img := _canvas(64, 64, "reflection_dusk")
	_paint(img, func(tx: float, ty: float) -> Color:
		var p := Vector2(tx * 2.0 - 1.0, 1.0 - ty * 2.0)
		var r := p.length()
		if r > 1.0:
			return Color(0.05, 0.05, 0.08)
		var z := 1.0 - r * r * 2.0
		var up := p.y * sqrt(maxf(0.0, 1.0 - z * z)) / maxf(r, 0.001)
		var sky := Color(0.05, 0.07, 0.18).lerp(Color(0.20, 0.24, 0.46), smoothstep(0.75, 0.2, up))
		sky = sky.lerp(Color(0.92, 0.50, 0.42), smoothstep(0.28, 0.0, absf(up)) * 0.85)
		var sun := Vector2(p.x - 0.35, p.y + 0.05).length()
		sky = sky.lightened(clampf(0.06 / maxf(sun, 0.01) - 0.2, 0.0, 0.5))
		if up < -0.04:
			sky = Color(0.12, 0.09, 0.08).lerp(Color(0.9, 0.5, 0.2), 0.6 if _hash(floori(tx * 64.0), floori(ty * 64.0), 64) > 0.9 else 0.0)
		return sky)
	return _finish(img, 64, 64)


## The decks beyond, far off: a concrete slab edge, the dark between the
## decks lit by a row of sodium lamps, a column every few bays, a parked
## car's shape here and there. Twelve metres a repeat (one deck's height,
## four metres, a third of it).
func _far_decks() -> Image:
	var img := _canvas(64, 64, "far_decks")
	_paint(img, func(tx: float, ty: float) -> Color:
		var deck := fmod(ty * 3.0, 1.0)
		var slab := Color(0.52, 0.50, 0.47).darkened((_fbm(tx, ty, 4) - 0.5) * 0.2)
		if deck < 0.22:
			return slab.darkened(smoothstep(0.1, 0.22, deck) * 0.15)
		if deck < 0.3:
			return Color(0.62, 0.58, 0.36)  # The level's painted edge.
		var column := fmod(tx * 3.0, 1.0) < 0.07
		if column:
			return Color(0.40, 0.38, 0.36)
		# Inside: dark, washed orange under each lamp.
		var lamp_x := absf(fmod(tx * 6.0, 1.0) - 0.5)
		var wash := (1.0 - smoothstep(0.0, 0.5, lamp_x)) * smoothstep(0.3, 0.45, deck)
		var inside := Color(0.07, 0.05, 0.05).lerp(Color(0.62, 0.34, 0.12), wash * 0.7)
		if lamp_x < 0.06 and deck > 0.3 and deck < 0.36:
			inside = Color(1.4, 0.78, 0.32)
		# Cars: low shapes along the back.
		var car := _hash(floori(tx * 12.0), floori(ty * 3.0), 12)
		if car < 0.45 and deck > 0.78 and fmod(tx * 12.0, 1.0) > 0.12 and fmod(tx * 12.0, 1.0) < 0.88:
			var roof := deck < 0.86 and absf(fmod(tx * 12.0, 1.0) - 0.5) > 0.22
			inside = Color(0.07, 0.05, 0.05).lerp(inside, 0.5) if roof else Color(0.12, 0.10, 0.10).lerp(inside, 0.3)
		return inside)
	return _finish(img, 64, 64)


## The hillside the decks climb: dark scrub and rock at dusk, a warmer
## band where the lamps light it. Twelve metres a repeat.
func _far_hill() -> Image:
	var img := _canvas(64, 64, "far_hill")
	_paint(img, func(tx: float, ty: float) -> Color:
		var c := Color(0.10, 0.10, 0.12).lightened((_fbm(tx, ty, 6, 5) - 0.5) * 0.12)
		var rock := smoothstep(0.6, 0.75, _fbm(tx + 0.3, ty * 0.6, 4, 4))
		c = c.lerp(Color(0.22, 0.20, 0.22), rock * 0.6)
		return c.lerp(Color(0.34, 0.20, 0.12), smoothstep(0.7, 1.0, ty) * 0.4))
	return _finish(img, 64, 64)
