class_name Maps
extends RefCounted
## Every level you can play, in order (GDD §9.3). F9 steps to the next one in
## game, until rounds rotate them (M3).

const ALL := [
	{"name": "test course", "scene": "res://scenes/test_course.tscn"},
	{"name": "stack", "scene": "res://scenes/maps/stack.tscn"},
	{"name": "terrace", "scene": "res://scenes/maps/terrace.tscn"},
	{"name": "switchback", "scene": "res://scenes/maps/switchback.tscn"},
	{"name": "archipelago", "scene": "res://scenes/maps/archipelago.tscn"},
	{"name": "rift", "scene": "res://scenes/maps/rift.tscn"},
	{"name": "boulevard", "scene": "res://scenes/maps/boulevard.tscn"},
	{"name": "holdfast", "scene": "res://scenes/maps/holdfast.tscn"},
	{"name": "depot", "scene": "res://scenes/maps/depot.tscn"},
]


## The name of the level at `scene_path` ("" if it isn't one).
static func name_of(scene_path: String) -> String:
	for m: Dictionary in ALL:
		if m.scene == scene_path:
			return m.name
	return ""


## The scene of the level called `level_name` ("" if there's none).
static func scene_of(level_name: String) -> String:
	for m: Dictionary in ALL:
		if m.name == level_name:
			return m.scene
	return ""


## The scene after `scene_path` in the list, wrapping round.
static func after(scene_path: String) -> String:
	for i in ALL.size():
		if ALL[i].scene == scene_path:
			return ALL[(i + 1) % ALL.size()].scene
	return ALL[0].scene
