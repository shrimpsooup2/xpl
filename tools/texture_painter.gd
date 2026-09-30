extends SceneTree
## Paints textures for a dressed map (tools/gen_<map>_textures.gd extend
## it): low-res but soft, in the ULTRAKILL / late-90s way. Each is painted
## at SS× with layered noise (blotchy colour, grime, stains), then scaled
## down, so edges come out as half-tones rather than hard lines. Tileable
## noise, deterministic (fixed seeds): a re-run gives the same files.

## Painted this many times bigger than saved.
const SS := 4

## Where _save() writes (res://assets/textures/<map>/).
var out_dir := ""
var _seed := 0


func _save(img: Image, file: String) -> void:
	var err := img.save_png(out_dir + file + ".png")
	print("%s.png: %s" % [file, error_string(err)])
	# Imported like the other world textures: lossless, with mipmaps (the
	# surface shader filters nearest between mip levels).
	var import_path := out_dir + file + ".png.import"
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
