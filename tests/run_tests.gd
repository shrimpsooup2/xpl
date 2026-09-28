extends SceneTree
## Headless test entry point. Use tools/run_tests.sh, or directly:
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/run_tests.gd
##
## Exits with code 0 when every test passes, 1 otherwise.

func _initialize() -> void:
	var runner: Node = load("res://tests/player_tests.gd").new()
	root.add_child(runner)
