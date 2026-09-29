extends SceneTree
## Headless test entry point. Use tools/run_tests.sh, or directly:
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/run_tests.gd
##
## Runs each suite in turn. Exits with code 0 when every test passes, 1
## otherwise. With `-- --online` it runs the networked suite instead, which
## has to run in real time (no --fixed-fps):
##
##   godot --headless --path . --script res://tests/run_tests.gd -- --online

const SUITES := ["res://tests/player_tests.gd", "res://tests/ui_tests.gd", "res://tests/combat_tests.gd",
		"res://tests/cosmetics_tests.gd", "res://tests/map_tests.gd", "res://tests/game_tests.gd",
		"res://tests/net_tests.gd"]
const ONLINE_SUITES := ["res://tests/online_tests.gd"]


func _initialize() -> void:
	_run_all()


func _run_all() -> void:
	var failures: PackedStringArray = []
	var checks := 0
	var count := 0
	for path: String in ONLINE_SUITES if "--online" in OS.get_cmdline_user_args() else SUITES:
		var suite: Node = load(path).new()
		root.add_child(suite)
		await suite.finished
		failures.append_array(suite.failures)
		checks += suite.checks
		count += suite.tests_run
		suite.queue_free()
		await process_frame
	print("\n%d tests, %d checks, %d failures" % [count, checks, failures.size()])
	for f in failures:
		print("  ✗ ", f)
	quit(1 if failures.size() > 0 else 0)
