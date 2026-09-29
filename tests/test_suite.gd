extends Node
## Base for a headless test suite: runs every test_* method in order, with
## _setup() before and _teardown() after each (both may await), then emits
## finished. tests/run_tests.gd runs the suites and reports.

signal finished

var failures: PackedStringArray = []
var checks := 0
var tests_run := 0

var _current := ""


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# TEST_ONLY=<text> runs just the tests whose names contain it.
	var only := OS.get_environment("TEST_ONLY")
	var tests: PackedStringArray = []
	for m in get_method_list():
		if String(m.name).begins_with("test_") and (only.is_empty() or only in String(m.name)):
			tests.append(m.name)
	for t in tests:
		_current = t
		var before := failures.size()
		await _setup()
		await Callable(self, t).call()
		_teardown()
		print("%s %s" % ["PASS" if failures.size() == before else "FAIL", t])
	tests_run = tests.size()
	finished.emit()


func _setup() -> void:
	pass


func _teardown() -> void:
	pass


func check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures.append("%s: %s" % [_current, what])


func near(actual: float, expected: float, tol: float, what: String) -> void:
	check(absf(actual - expected) <= tol, "%s = %.3f, expected %.3f ± %.3f" % [what, actual, expected, tol])


## Waits n process frames.
func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
