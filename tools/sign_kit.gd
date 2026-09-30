extends RefCounted
## Signs for a dressed map (tools/maps/*_deco.gd), built rather than typed,
## each kind its own way:
##
## - neon(): bent glass tubes in a monoline hand (its own alphabet, below),
##   electrodes at the tube ends turning back to the wall, standoffs, on a
##   grid, a raceway or the bare wall.
## - outline_neon(): tubes tracing the outline of a typeface's letters.
## - channel(): letters cut from a typeface and extruded, lit faces on dark
##   sides, slanted, bouncing, each its own colour if wanted.
## - bulbs(): letters in bulbs on a grid, like a marquee or a scoreboard.
## - board(), awning(), blade(), lightbox(): painted and printed signs.
##
## Everything is merged into the DecoKit's meshes like the rest of the decor.

const DecoKit := preload("res://tools/deco_kit.gd")
const BOTH := DecoKit.LAYER_BOTH
const GLOW := "res://src/render/deco/glow.gdshader"
const FONTS := "res://assets/fonts/"

## The monoline hand's proportions: x-height 1, capitals CAP, ascenders ASC,
## descenders down to -DESC; letters SPACING apart.
const CAP := 1.55
const ASC := 1.65
const DESC := 0.6
const SPACING := 0.3


# --- The monoline hand ---------------------------------------------------------------------

static func _arc(c: Vector2, r: float, a0: float, a1: float) -> PackedVector2Array:
	return _ellipse(c, Vector2(r, r), a0, a1)


## Part of an ellipse from angle `a0` to `a1` (degrees, anticlockwise, y up).
static func _ellipse(c: Vector2, r: Vector2, a0: float, a1: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var steps := maxi(2, ceili(absf(a1 - a0) / 10.0))
	for i in steps + 1:
		var a := deg_to_rad(lerpf(a0, a1, float(i) / steps))
		out.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return out


static func _line(a: Vector2, b: Vector2) -> PackedVector2Array:
	return PackedVector2Array([a, b])


## Pieces joined end to end into one stroke.
static func _join(parts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: PackedVector2Array in parts:
		for q in p:
			if out.is_empty() or out[out.size() - 1].distance_to(q) > 0.001:
				out.append(q)
	return out


## A letter of the monoline hand: [advance, strokes].
static func glyph(ch: String) -> Array:
	var o := Vector2(0.5, 0.5)
	match ch:
		"a": return [1.0, [_arc(o, 0.5, 0, 360), _line(Vector2(1, 1), Vector2(1, 0))]]
		"b": return [1.0, [_line(Vector2(0, ASC), Vector2(0, 0)), _arc(o, 0.5, 0, 360)]]
		"c": return [0.95, [_arc(o, 0.5, 40, 320)]]
		"d": return [1.0, [_arc(o, 0.5, 0, 360), _line(Vector2(1, ASC), Vector2(1, 0))]]
		"e": return [1.0, [_join([_line(Vector2(0, 0.5), Vector2(1, 0.5)), _arc(o, 0.5, 0, 320)])]]
		"é": return [1.0, [_join([_line(Vector2(0, 0.5), Vector2(1, 0.5)), _arc(o, 0.5, 0, 320)]), _line(Vector2(0.4, 1.2), Vector2(0.7, 1.45))]]
		"f": return [0.8, [_join([_line(Vector2(0.3, 0), Vector2(0.3, 1.3)), _arc(Vector2(0.6, 1.3), 0.3, 180, 30)]), _line(Vector2(0, 1), Vector2(0.7, 1))]]
		"g": return [1.0, [_arc(o, 0.5, 0, 360), _join([_line(Vector2(1, 1), Vector2(1, -0.25)), _arc(Vector2(0.5, -0.25), 0.5, 0, -160)])]]
		"h": return [1.0, [_line(Vector2(0, ASC), Vector2(0, 0)), _join([_arc(o, 0.5, 180, 0), _line(Vector2(1, 0.5), Vector2(1, 0))])]]
		"i": return [0.2, [_line(Vector2(0.1, 1), Vector2(0.1, 0)), _arc(Vector2(0.1, 1.38), 0.07, 0, 360)]]
		"k": return [0.9, [_line(Vector2(0, ASC), Vector2(0, 0)), _line(Vector2(0.85, 1), Vector2(0, 0.35)), _line(Vector2(0.3, 0.6), Vector2(0.9, 0))]]
		"l": return [0.45, [_join([_line(Vector2(0.1, ASC), Vector2(0.1, 0.25)), _arc(Vector2(0.35, 0.25), 0.25, 180, 300)])]]
		"m": return [1.4, [_line(Vector2(0, 1), Vector2(0, 0)), _join([_arc(Vector2(0.35, 0.62), 0.35, 180, 0), _line(Vector2(0.7, 0.62), Vector2(0.7, 0))]),
				_join([_arc(Vector2(1.05, 0.62), 0.35, 180, 0), _line(Vector2(1.4, 0.62), Vector2(1.4, 0))])]]
		"n": return [1.0, [_line(Vector2(0, 1), Vector2(0, 0)), _join([_arc(o, 0.5, 180, 0), _line(Vector2(1, 0.5), Vector2(1, 0))])]]
		"o": return [1.0, [_arc(o, 0.5, 90, 450)]]
		"p": return [1.0, [_line(Vector2(0, 1), Vector2(0, -DESC)), _arc(o, 0.5, 0, 360)]]
		"r": return [0.8, [_line(Vector2(0, 1), Vector2(0, 0)), _arc(o, 0.5, 180, 55)]]
		"s": return [0.62, [_join([_arc(Vector2(0.3, 0.74), 0.26, 15, 270), _arc(Vector2(0.3, 0.26), 0.26, 90, -165)])]]
		"t": return [0.75, [_join([_line(Vector2(0.3, 1.4), Vector2(0.3, 0.25)), _arc(Vector2(0.55, 0.25), 0.25, 180, 300)]), _line(Vector2(0, 1), Vector2(0.7, 1))]]
		"u": return [1.0, [_join([_line(Vector2(0, 1), Vector2(0, 0.5)), _arc(o, 0.5, 180, 360)]), _line(Vector2(1, 1), Vector2(1, 0))]]
		"y": return [1.0, [_join([_line(Vector2(0, 1), Vector2(0, 0.5)), _arc(o, 0.5, 180, 360)]),
				_join([_line(Vector2(1, 1), Vector2(1, -0.25)), _arc(Vector2(0.5, -0.25), 0.5, 0, -160)])]]
		"z": return [0.9, [_join([_line(Vector2(0, 1), Vector2(0.9, 1)), _line(Vector2(0.9, 1), Vector2(0, 0)), _line(Vector2(0, 0), Vector2(0.9, 0))])]]
		"B": return [1.0, [_line(Vector2(0, 0), Vector2(0, CAP)),
				_join([_line(Vector2(0, CAP), Vector2(0.55, CAP)), _arc(Vector2(0.55, 1.175), 0.375, 90, -90), _line(Vector2(0.55, 0.8), Vector2(0, 0.8))]),
				_join([_line(Vector2(0, 0.8), Vector2(0.6, 0.8)), _arc(Vector2(0.6, 0.4), 0.4, 90, -90), _line(Vector2(0.6, 0), Vector2(0, 0))])]]
		"C": return [1.35, [_ellipse(Vector2(0.7, CAP * 0.5), Vector2(0.7, CAP * 0.5), 45, 315)]]
		"F": return [0.9, [_join([_line(Vector2(0, 0), Vector2(0, CAP)), _line(Vector2(0, CAP), Vector2(0.9, CAP))]), _line(Vector2(0, 0.85), Vector2(0.7, 0.85))]]
		"G": return [1.4, [_join([_ellipse(Vector2(0.7, CAP * 0.5), Vector2(0.7, CAP * 0.5), 45, 360), _line(Vector2(1.4, CAP * 0.5), Vector2(0.85, CAP * 0.5))])]]
		"L": return [0.85, [_join([_line(Vector2(0, CAP), Vector2(0, 0)), _line(Vector2(0, 0), Vector2(0.85, 0))])]]
		"M": return [1.4, [_join([_line(Vector2(0, 0), Vector2(0, CAP)), _line(Vector2(0, CAP), Vector2(0.7, 0.5)), _line(Vector2(0.7, 0.5), Vector2(1.4, CAP)), _line(Vector2(1.4, CAP), Vector2(1.4, 0))])]]
		"O": return [1.44, [_ellipse(Vector2(0.72, CAP * 0.5), Vector2(0.72, CAP * 0.5), 90, 450)]]
		"R": return [1.0, [_join([_line(Vector2(0, 0), Vector2(0, CAP)), _line(Vector2(0, CAP), Vector2(0.6, CAP)), _arc(Vector2(0.6, 1.15), 0.4, 90, -90), _line(Vector2(0.6, 0.75), Vector2(0, 0.75))]),
				_line(Vector2(0.45, 0.75), Vector2(1.0, 0))]]
		"Y": return [1.2, [_join([_line(Vector2(0, CAP), Vector2(0.6, 0.75)), _line(Vector2(0.6, 0.75), Vector2(1.2, CAP))]), _line(Vector2(0.6, 0.75), Vector2(0.6, 0))]]
		" ": return [0.55, []]
	push_error("sign_kit: no monoline '%s'" % ch)
	return [0.6, []]


## How wide `text` is in the monoline hand, in x-heights.
static func measure(text: String) -> float:
	var w := 0.0
	for i in text.length():
		w += glyph(text[i])[0] + (SPACING if i < text.length() - 1 else 0.0)
	return w


# --- Neon -------------------------------------------------------------------------------------

## The glowing tube material for `colour` (made once).
static func neon_material(d, colour: Color, flicker := 0.0) -> String:
	var name := "neon_%s_%d" % [colour.to_html(false), roundi(flicker * 10.0)]
	d.shaded(name, GLOW, {"color": colour, "energy": 3.2, "flicker": flicker})
	return name


## Words in neon tubes, in the monoline hand: `at` the middle of their
## baseline, `b` the wall's facing, `x_height` in metres, `slant` leaning
## the letters (0 upright). `backing` "grid", "raceway" or "" (on the wall).
## Tubes stand `out` off the backing on standoffs; each ends in an electrode
## turning back into it.
static func neon(d, text: String, at: Vector3, b: Basis, x_height: float, colour: Color, slant := 0.15, backing := "raceway", flicker := 0.0, out := 0.07) -> void:
	var mat := neon_material(d, colour, flicker)
	var width := measure(text) * x_height
	var pen := -width * 0.5
	# Fatter than real tubing, so it reads at the game's low resolution.
	var radius := x_height * 0.075
	for i in text.length():
		var g := glyph(text[i])
		for stroke: PackedVector2Array in g[1]:
			var pts := PackedVector3Array()
			for p in stroke:
				pts.append(at + b.x * (pen + (p.x + p.y * slant) * x_height) + b.y * p.y * x_height + b.z * out)
			var closed := stroke.size() > 2 and stroke[0].distance_to(stroke[stroke.size() - 1]) < 0.01
			d.path_tube(mat, pts, radius, 6, "Fixtures", BOTH, closed)
			_mount(d, pts, closed, radius, b, out)
		pen += (g[0] + SPACING) * x_height
	_backing(d, backing, at, b, width, x_height)


## Electrodes where a tube ends (dark, turning back to the wall) and
## standoffs along it.
static func _mount(d, pts: PackedVector3Array, closed: bool, radius: float, b: Basis, out: float) -> void:
	if not closed:
		for end: Vector3 in [pts[0], pts[pts.size() - 1]]:
			d.tube("black", end, end - b.z * out, radius * 1.25, 6, "Fixtures", BOTH)
	var run := 0.0
	for i in range(1, pts.size()):
		run += pts[i].distance_to(pts[i - 1])
		if run > 0.7:
			run = 0.0
			d.tube("dark_metal", pts[i] - b.z * radius, pts[i] - b.z * out, radius * 0.35, 4, "Detail", BOTH)


static func _backing(d, kind: String, at: Vector3, b: Basis, width: float, x_height: float) -> void:
	match kind:
		"raceway":
			d.box("dark_metal", at + b.y * x_height * 0.35 + b.z * 0.025, Vector3(width + x_height * 0.6, x_height * 0.32, 0.05), "Build", BOTH, b)
		"grid":
			var w := width + x_height * 1.2
			var h := x_height * (CAP + DESC + 0.8)
			var c := at + b.y * x_height * (CAP - DESC) * 0.5 + b.z * 0.02
			for e: float in [-0.5, 0.5]:
				d.tube("dark_metal", c + b.x * w * e + b.y * h * 0.5, c + b.x * w * e - b.y * h * 0.5, 0.012, 4, "Build", BOTH)
				d.tube("dark_metal", c + b.y * h * e + b.x * w * 0.5, c + b.y * h * e - b.x * w * 0.5, 0.012, 4, "Build", BOTH)
			var bars := int(w / 0.3)
			for i in range(1, bars):
				var x := -w * 0.5 + w * i / bars
				d.tube("dark_metal", c + b.x * x + b.y * h * 0.5, c + b.x * x - b.y * h * 0.5, 0.006, 3, "Detail", BOTH)


## A drawing in neon: `strokes` in x-heights (as the glyphs are), placed with
## its origin at `at`.
static func neon_drawing(d, strokes: Array, at: Vector3, b: Basis, scale: float, colour: Color, out := 0.07, flicker := 0.0) -> void:
	var mat := neon_material(d, colour, flicker)
	var radius := scale * 0.065
	for stroke: PackedVector2Array in strokes:
		var pts := PackedVector3Array()
		for p in stroke:
			pts.append(at + b.x * p.x * scale + b.y * p.y * scale + b.z * out)
		var closed := stroke.size() > 2 and stroke[0].distance_to(stroke[stroke.size() - 1]) < 0.01
		d.path_tube(mat, pts, radius, 6, "Fixtures", BOTH, closed)
		_mount(d, pts, closed, radius, b, out)


# --- Typefaces ----------------------------------------------------------------------------------

## A typeface's letters as outlines: for each character of `text`, [pen x,
## contours (closed, in ems, y up)]; and the whole width, in ems.
static func outlines(font_file: String, text: String) -> Array:
	var f := FontFile.new()
	f.load_dynamic_font(FONTS + font_file)
	var ts := TextServerManager.get_primary_interface()
	var rid: RID = f.get_rids()[0]
	var size := 64
	var pen := 0.0
	var letters := []
	for i in text.length():
		var gi := ts.font_get_glyph_index(rid, size, text.unicode_at(i), 0)
		var contours := []
		var data: Dictionary = ts.font_get_glyph_contours(rid, size, gi)
		var points: PackedVector3Array = data.get("points", PackedVector3Array())
		var ends: PackedInt32Array = data.get("contours", PackedInt32Array())
		var start := 0
		for e in ends:
			contours.append(_flatten(points.slice(start, e + 1), size))
			start = e + 1
		letters.append([pen, contours])
		pen += ts.font_get_glyph_advance(rid, size, gi).x / size
	return [letters, pen]


## One TrueType contour (on-curve points and quadratic controls) as a closed
## polyline, in ems, y up.
static func _flatten(raw: PackedVector3Array, size: int) -> PackedVector2Array:
	var pts: Array = []
	for p in raw:
		pts.append([Vector2(p.x, -p.y) / size, p.z > 0.5 and p.z < 1.5, p.z > 1.5])
	var n := pts.size()
	var out := PackedVector2Array()
	if n == 0:
		return out
	# Start on an on-curve point (or between two controls).
	var first := 0
	while first < n and not pts[first][1]:
		first += 1
	var start: Vector2 = pts[first][0] if first < n else (pts[0][0] + pts[1 % n][0]) * 0.5
	out.append(start)
	var prev := start
	var control = null
	for k in range(1, n + 1):
		var p: Array = pts[(first + k) % n]
		var q: Vector2 = p[0]
		if p[1] or p[2]:
			if control == null:
				out.append(q)
			else:
				_quad(out, prev, control, q)
				control = null
			prev = q
		else:
			if control != null:
				var mid: Vector2 = (control + q) * 0.5
				_quad(out, prev, control, mid)
				prev = mid
			control = q
	return out


static func _quad(out: PackedVector2Array, a: Vector2, c: Vector2, b: Vector2) -> void:
	for i in range(1, 5):
		var t := i / 4.0
		out.append(a.lerp(c, t).lerp(c.lerp(b, t), t))


## Neon tracing the outlines of a typeface's letters: `size` an em in metres.
static func outline_neon(d, font_file: String, text: String, at: Vector3, b: Basis, size: float, colour: Color, backing := "raceway", out := 0.07) -> void:
	var mat := neon_material(d, colour)
	var o := outlines(font_file, text)
	var width: float = o[1] * size
	var radius := size * 0.018
	for letter: Array in o[0]:
		for contour: PackedVector2Array in letter[1]:
			var pts := PackedVector3Array()
			for p in contour:
				pts.append(at + b.x * ((letter[0] + p.x) * size - width * 0.5) + b.y * p.y * size + b.z * out)
			d.path_tube(mat, pts, radius, 5, "Fixtures", BOTH, true)
			_mount(d, pts, true, radius, b, out)
	_backing(d, backing, at, b, width, size * 0.5)


## Channel letters: each character of `text` cut from a typeface and
## extruded `depth`, its face in `faces` (cycled letter by letter) and its
## sides in `sides`; `slant` leans them, `bounce` lifts every other one.
## `at` the middle of the baseline, `size` an em in metres.
static func channel(d, font_file: String, text: String, at: Vector3, b: Basis, size: float, faces: Array, sides := "dark_metal", depth := 0.08, slant := 0.0, bounce := 0.0, grp := "Fixtures") -> void:
	var o := outlines(font_file, text)
	var width: float = o[1] * size
	var font := load(FONTS + font_file) as Font
	var k := 0
	for i in text.length():
		var ch := text[i]
		if ch == " ":
			continue
		var tm := TextMesh.new()
		tm.font = font
		tm.text = ch
		tm.font_size = 64
		tm.pixel_size = size / 64.0
		tm.depth = depth
		# Coarse curves: plenty at the game's resolution.
		tm.curve_step = 3.0
		tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		tm.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		var lift := bounce * (1.0 if k % 2 == 1 else 0.0) * size
		var pen: float = o[0][i][0] * size - width * 0.5
		var lean := Basis(b.x, b.y + b.x * slant, b.z)
		var t := Transform3D(lean, at + b.x * pen + b.y * lift + b.z * (depth * 0.5 + 0.01))
		d.add_mesh(tm, t, faces[k % faces.size()], sides, grp, BOTH)
		k += 1


## Letters in bulbs on a grid `pitch` apart: the typeface's letters sampled
## on the grid, `rows` bulbs to an em. `materials` cycle letter by letter.
static func bulbs(d, font_file: String, text: String, at: Vector3, b: Basis, pitch: float, rows: int, materials: Array, bulb := 0.035) -> void:
	var o := outlines(font_file, text)
	var em := pitch * rows
	var width: float = o[1] * em
	for i in text.length():
		var letter: Array = o[0][i]
		var polys: Array = letter[1]
		if polys.is_empty():
			continue
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for poly: PackedVector2Array in polys:
			for p in poly:
				lo = lo.min(p)
				hi = hi.max(p)
		var step := 1.0 / rows
		var y := floorf(lo.y / step) * step + step * 0.5
		while y < hi.y:
			var x := floorf(lo.x / step) * step + step * 0.5
			while x < hi.x:
				var inside := 0
				for poly: PackedVector2Array in polys:
					if Geometry2D.is_point_in_polygon(Vector2(x, y), poly):
						inside += 1
				if inside % 2 == 1:
					var p: Vector3 = at + b.x * ((float(letter[0]) + x) * em - width * 0.5) + b.y * y * em + b.z * 0.04
					d.ball(materials[i % materials.size()], p, Vector3(bulb, bulb, bulb), 2, 6, "Fixtures", BOTH)
				x += step
			y += step


# --- Painted and printed ------------------------------------------------------------------------

## A painted board: a panel of `material` with a frame, words painted on.
static func board(d, at: Vector3, b: Basis, size: Vector2, material: String, text: String, font_file: String, text_size: float, colour: Color, frame := "wood") -> Label3D:
	d.box(material, at, Vector3(size.x, size.y, 0.05), "Build", BOTH, b)
	for e: float in [-1.0, 1.0]:
		d.box(frame, at + b.y * e * size.y * 0.5 + b.z * 0.01, Vector3(size.x + 0.08, 0.06, 0.08), "Build", BOTH, b)
		d.box(frame, at + b.x * e * size.x * 0.5 + b.z * 0.01, Vector3(0.06, size.y, 0.08), "Build", BOTH, b)
	var l: Label3D = d.words(text, at + b.z * 0.03, b, text_size, colour, 0.0, "Build", BOTH, font_file)
	return l


## A striped fabric awning over a shopfront: `at` the middle of its top
## edge on the wall, sloping out `depth` and down `drop`, a valance with the
## name printed on it.
static func awning(d, at: Vector3, b: Basis, width: float, depth: float, drop: float, stripes: Array, text: String, font_file: String, text_colour: Color) -> void:
	var count := maxi(4, int(width / 0.5))
	var sw := width / count
	var front := at + b.z * depth - b.y * drop
	for i in count:
		var x0 := -width * 0.5 + i * sw
		var mat: String = stripes[i % stripes.size()]
		var p0 := at + b.x * x0
		var p1 := at + b.x * (x0 + sw)
		var q0 := front + b.x * x0
		var q1 := front + b.x * (x0 + sw)
		d.quad(mat, p0, p1, q1, q0, "Build", BOTH)
		d.quad(mat, p1, p0, q0, q1, "Build", BOTH)
		# The valance hanging from the front edge.
		d.quad(mat, q0, q1, q1 - b.y * 0.3, q0 - b.y * 0.3, "Build", BOTH)
		d.quad(mat, q1, q0, q0 - b.y * 0.3, q1 - b.y * 0.3, "Build", BOTH)
	for e: float in [-0.5, 0.5]:
		d.tube("dark_metal", at + b.x * width * e - b.y * (drop + 0.15), front + b.x * width * e, 0.015, 4, "Build", BOTH)
	d.box(stripes[0], front - b.y * 0.15 + b.z * 0.006, Vector3(minf(width * 0.7, text.length() * 0.2 + 0.4), 0.24, 0.004), "Build", BOTH, b)
	d.words(text, front - b.y * 0.15 + b.z * 0.012, b, 0.2, text_colour, 0.0, "Build", BOTH, font_file)


## A blade sign standing out from the wall on a bracket, the same both
## sides: `at` where the bracket meets the wall, `n` the wall's facing.
static func blade(d, at: Vector3, n: Vector3, size: Vector2, material: String, text: String, font_file: String, text_size: float, colour: Color) -> void:
	var out := at + n * (0.25 + size.x * 0.5)
	var side := DecoKit.facing(n.cross(Vector3.UP))
	d.tube("dark_metal", at + Vector3.UP * size.y * 0.45, out + n * size.x * 0.5 + Vector3.UP * size.y * 0.45, 0.02, 4, "Build", BOTH)
	d.tube("dark_metal", at - Vector3.UP * size.y * 0.3, at + n * 0.25 + Vector3.UP * size.y * 0.1, 0.015, 4, "Build", BOTH)
	d.box(material, out, Vector3(size.x, size.y, 0.07), "Build", BOTH, side)
	for s: float in [1.0, -1.0]:
		var face := Basis(side.x * s, side.y, side.z * s)
		d.words(text, out + side.z * s * 0.04, face, text_size, colour, 0.0, "Build", BOTH, font_file)


## A backlit printed panel: `material` a glow, words on it.
static func lightbox(d, at: Vector3, b: Basis, size: Vector2, glow: String, text: String, font_file: String, text_size: float, colour: Color) -> void:
	d.box("dark_metal", at - b.z * 0.03, Vector3(size.x + 0.08, size.y + 0.08, 0.08), "Build", BOTH, b)
	d.face(glow, at + b.z * 0.012, b.x * size.x * 0.5, b.y * size.y * 0.5, "Fixtures", BOTH)
	d.words(text, at + b.z * 0.018, b, text_size, colour, 0.0, "Fixtures", BOTH, font_file)
