class_name GameUI
extends Node
## Builds and wires the in-game interface: the sharp crosshair layer, the
## low-res layer holding the HUD, overlays, and pause menu, the speed lines,
## and the (experimental, off by default) impact frames. Hides the HUD while the
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
var speed_lines: SpeedLines
var player: Player

var _preview_step := -1
var _prompt := ""


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
	speed_lines = SpeedLines.new()
	speed_lines.name = "SpeedLines"
	add_child(speed_lines)

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
		impact.fired.connect(func(strength: float, point: Vector2) -> void:
			player.punch_camera(strength, (point.x - 0.5) * 2.0)
			hud.impact(strength)
			crosshair.bump(1.5 * strength)
			LofiUI.kick(hud, strength))
		_connect_weapons(player.weapons)
	overlays.round_card("test course", 0, false)


func _process(_delta: float) -> void:
	# Live, so the tuning panel's slider takes effect straight away.
	if player and player.view_settings:
		LofiUI.motion = player.view_settings.ui_motion
		LofiUI.smoothing = player.view_settings.camera_smoothing
	if player and player.weapons:
		var w := player.weapons
		var def := w.current
		crosshair.set_cycle(1.0 - clampf(w.cooldown() / maxf(def.fire_interval, 0.001), 0.0, 1.0))
		crosshair.set_zoom(w.zoom)
		if w.swap_candidate and is_instance_valid(w.swap_candidate):
			var text := "e  swap for %s" % w.swap_candidate.def.display_name
			if _prompt != text:
				_prompt = text
				hud.show_prompt(text)
		elif not _prompt.is_empty():
			_prompt = ""
			hud.hide_prompt()


## The HUD and crosshair follow the player's hands.
func _connect_weapons(w: WeaponHolder) -> void:
	var show := func(def: WeaponDef, ammo: int) -> void:
		hud.set_weapon(def.display_name, ammo, def.ammo if not def.is_fists() else -1)
		crosshair.set_weapon(def.ammo if not def.is_fists() else 0, ammo, def.fire_interval)
	w.equipped.connect(show)
	show.call(w.current, w.ammo)
	w.ammo_changed.connect(func(ammo: int, _capacity: int) -> void:
		hud.set_ammo(ammo)
		crosshair.set_ammo(ammo))
	w.dry_fired.connect(func(_def: WeaponDef) -> void:
		hud.click_empty()
		crosshair.click_empty())
	w.fired.connect(func(def: WeaponDef, _shot: Dictionary) -> void:
		crosshair.bump(clampf(def.recoil.x / 40.0, 0.1, 0.6)))
	w.hit_confirmed.connect(_on_hit)


## A body you hit: a hit marker, and on a kill the kill feedback and a
## killfeed line.
func _on_hit(result: Dictionary) -> void:
	var weapon: WeaponDef = result.get("weapon")
	if result.get("killed", false):
		var heartshot: bool = result.get("heartshot", false)
		kill_confirmed(heartshot)
		hud.add_kill("you", result.get("name", "?"), weapon.display_name if weapon else "", heartshot)
	elif result.get("zone") == &"head":
		crosshair.hit(&"head")
	else:
		crosshair.hit(&"hit")


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


## A kill you made (from a confirmed hit; F8 previews it):
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
			hud.add_kill("you", "them", "marshal .357")
			hud.add_kill("them", "you", "rl-5")
			hud.add_kill("you", "them", "", true)
			kill_confirmed(true)
			hud.set_weapon("marshal .357", 4, 6)
			hud.set_throwable("frag", 2)
			hud.show_prompt("e  swap for rl-5 (5)")
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
