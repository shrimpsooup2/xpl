class_name GameUI
extends Node
## Builds and wires the in-game interface: the sharp crosshair layer, the
## low-res layer holding the HUD, overlays, and pause menu, and the
## (experimental, off by default) impact frames. Hides the HUD while the
## local player is dead.
##
## Debug: F8 previews each overlay; hold Tab for the scoreboard.

## Only hard smashdowns get an impact frame: from this drop up, growing to
## full strength at SMASH_IMPACT_FULL.
const SMASH_IMPACT_DROP := 8.0
const SMASH_IMPACT_FULL := 18.0

var crosshair: Crosshair
var layer: LofiLayer
var hud: GameHud
var overlays: Overlays
var pause: PauseMenu
var impact: ImpactFrames
var player: Player

var _preview_step := -1


func _ready() -> void:
	var sharp := CanvasLayer.new()
	sharp.name = "CrosshairLayer"
	sharp.layer = 3
	add_child(sharp)
	crosshair = Crosshair.new()
	sharp.add_child(crosshair)

	layer = LofiLayer.new()
	layer.name = "LofiLayer"
	layer.layer = 4
	add_child(layer)
	hud = GameHud.new()
	layer.canvas.add_child(hud)
	overlays = Overlays.new()
	layer.canvas.add_child(overlays)
	pause = PauseMenu.new()
	pause.layer = layer
	layer.canvas.add_child(pause)
	impact = ImpactFrames.new()
	impact.name = "ImpactFrames"
	add_child(impact)

	player = get_tree().get_first_node_in_group(&"local_player") as Player
	if player:
		hud.player = player
		pause.player = player
		player.died.connect(_set_alive_ui.bind(false))
		player.respawned.connect(_set_alive_ui.bind(true))
		player.movement_event.connect(hud.on_movement_event)
		player.movement_event.connect(crosshair.on_movement_event)
		impact.settings = player.view_settings
		player.movement_event.connect(_impact_on_movement)
	overlays.round_card("test course", 0, false)


func _process(_delta: float) -> void:
	# Live, so the tuning panel's slider takes effect straight away.
	if player and player.view_settings:
		LofiUI.motion = player.view_settings.ui_motion


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		pause.toggle()
	elif event.is_action_pressed(&"debug_preview_ui"):
		_preview()
	elif event.is_action_pressed(&"scoreboard"):
		overlays.show_scoreboard([["you", 0, 0, 0, 0]])
	elif event.is_action_released(&"scoreboard"):
		overlays.hide_scoreboard()


## A kill you made (combat calls this once it exists; F8 previews it):
## the kill marker, and an impact frame, pink for a heartshot.
func kill_confirmed(heartshot := false) -> void:
	if heartshot:
		crosshair.hit(&"heart")
		hud.popup("heartshot", LofiUI.Style.HEART)
		ImpactFrames.hit(get_tree(), 1.0, Vector2(0.5, 0.5), LofiUI.HEART)
	else:
		crosshair.hit(&"kill")
		ImpactFrames.hit(get_tree(), 0.7)


## Hard smashdown landings get an impact frame, centred where you hit.
func _impact_on_movement(e: Dictionary) -> void:
	if e.type == &"smash_impact" and e.drop >= SMASH_IMPACT_DROP:
		var strength := remap(minf(e.drop, SMASH_IMPACT_FULL), SMASH_IMPACT_DROP, SMASH_IMPACT_FULL, 0.5, 1.0)
		ImpactFrames.hit(get_tree(), strength, _screen_point(e.position))


## A world position in screen UV, or the middle if it's behind the camera.
func _screen_point(world: Vector3) -> Vector2:
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.is_position_behind(world):
		return Vector2(0.5, 0.5)
	return cam.unproject_position(world) / get_viewport().get_visible_rect().size


func _set_alive_ui(alive: bool) -> void:
	hud.visible = alive
	crosshair.visible = alive
	if not alive:
		pause.close()


## Walks through the overlays and HUD states with made-up data.
func _preview() -> void:
	_preview_step = (_preview_step + 1) % 6
	match _preview_step:
		0:
			hud.set_scores("you", 3, "them", 2)
			hud.set_timer(34.0)
			hud.set_map("waiting room")
			overlays.preview_next()
		1:
			hud.add_kill("you", "them", "hotkey")
			hud.add_kill("them", "you", "overdraw")
			hud.add_kill("you", "them", "", true)
			kill_confirmed(true)
			hud.set_weapon("hotkey", 4)
			hud.set_throwable("packet", 2)
			hud.show_prompt("e  swap for overdraw (5)")
		2:
			hud.set_health(24)
			hud.set_alert("the map is unloading")
			hud.hide_prompt()
			overlays.preview_next()
		3, 4:
			overlays.preview_next()
		5:
			hud.set_scores("", 0, "", 0)
			hud.set_timer(-1.0)
			hud.set_map("test course")
			hud.set_health(100)
			hud.set_weapon("fists")
			hud.set_throwable("", 0)
			hud.set_alert("")
