class_name Wipe
extends CanvasLayer
## Scene transition: black boxes pop in across the screen in a diagonal
## sweep, the scene changes underneath, and the boxes clear the same way.
## Lives on the tree root, so it outlasts the scene it was started from.
##
##   Wipe.change_scene(get_tree(), "res://scenes/test_course.tscn")

signal covered
signal finished

const COLS := 16
const ROWS := 9
## Time for the sweep to cross the screen, and for one box to grow.
const SWEEP := 0.26
const CELL_TIME := 0.12
## Held on full black while the next scene loads.
const HOLD := 0.08

var _middle: Callable
var _time := 0.0
var _covering := true
var _holding := false
var _hold_time := 0.0
var _hold_frames := 0
var _canvas: Control


static func change_scene(tree: SceneTree, path: String) -> Wipe:
	return run(tree, func() -> void: tree.change_scene_to_file(path))


## Covers the screen, calls middle, then uncovers it.
static func run(tree: SceneTree, middle: Callable) -> Wipe:
	var w := Wipe.new()
	w._middle = middle
	tree.root.add_child(w)
	return w


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP  # Nothing gets clicked mid-wipe.
	_canvas.draw.connect(_draw_cells)
	add_child(_canvas)


func _process(delta: float) -> void:
	if _holding:
		# Wait on black for the new scene to load: HOLD seconds, and at least
		# a couple of frames so its first frame is behind us.
		_hold_time += delta
		_hold_frames += 1
		if _hold_time >= HOLD and _hold_frames >= 2:
			_holding = false
			_covering = false
			_time = 0.0
		return
	_time += delta
	if _time >= SWEEP + CELL_TIME:
		if _covering:
			covered.emit()
			if _middle.is_valid():
				_middle.call()
			_holding = true
			_time = SWEEP + CELL_TIME
		else:
			finished.emit()
			queue_free()
	_canvas.queue_redraw()


func _draw_cells() -> void:
	var cell := _canvas.size / Vector2(COLS, ROWS)
	for j in ROWS:
		for i in COLS:
			var order := float(i + j) / float(COLS + ROWS - 2)
			var grow := clampf((_time - order * SWEEP) / CELL_TIME, 0.0, 1.0)
			if not _covering:
				grow = 1.0 - grow
			if grow <= 0.0:
				continue
			grow = ease(grow, 0.4) if _covering else grow * grow
			# Slight overlap so full cover has no seams.
			var s := (cell + Vector2.ONE * 2.0) * grow
			var centre := (Vector2(i, j) + Vector2(0.5, 0.5)) * cell
			_canvas.draw_rect(Rect2(centre - s * 0.5, s), LofiUI.BLACK)
