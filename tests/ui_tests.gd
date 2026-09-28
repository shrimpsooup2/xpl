extends "res://tests/test_suite.gd"
## UI tests: the in-game UI built around a real (script-driven) player, run
## frame by frame. Checks that the motion (GDD §13.5) happens, settles, and
## cleans up after itself.

var world: Node3D
var player: Player
var ui: GameUI


func _setup() -> void:
	LofiUI.motion = 1.0
	await frames(1)  # Let the previous test's world go.
	world = Node3D.new()
	add_child(world)
	var floor_body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(100, 1, 100)
	col.shape = shape
	floor_body.add_child(col)
	floor_body.position = Vector3(0, -0.5, 0)
	world.add_child(floor_body)
	player = load("res://scenes/player.tscn").instantiate()
	player.human_controlled = false
	player.movement_params = MovementParams.new()
	player.view_settings = ViewSettings.new()
	world.add_child(player)
	player.add_to_group(&"local_player")
	ui = GameUI.new()
	world.add_child(ui)
	await frames(3)


func _teardown() -> void:
	player.remove_from_group(&"local_player")
	world.queue_free()
	world = null
	player = null
	ui = null
	LofiUI.motion = 1.0


func land(speed: float) -> void:
	player.movement_event.emit({"type": &"land", "impact_speed": speed})


# --- HUD motion -----------------------------------------------------------------

func test_hud_lags_behind_mouse_look_then_settles() -> void:
	await frames(20)
	near(ui.hud.position.length(), 0.0, 0.2, "resting sway")
	for i in 6:
		player.yaw -= 0.1  # Turning right.
		await frames(1)
	check(ui.hud.position.x < -1.0, "turning right drags the HUD left (x = %.2f)" % ui.hud.position.x)
	await frames(90)
	near(ui.hud.position.length(), 0.0, 0.3, "sway after settling")


func test_landing_knocks_hud_down() -> void:
	await frames(20)
	land(12.0)
	await frames(5)
	check(ui.hud.position.y > 1.0, "hard landing pushes the HUD down (y = %.2f)" % ui.hud.position.y)
	await frames(90)
	near(ui.hud.position.length(), 0.0, 0.3, "sway after settling")


func test_ui_motion_zero_keeps_hud_still() -> void:
	player.view_settings.ui_motion = 0.0
	await frames(2)
	for i in 6:
		player.yaw -= 0.1
		await frames(1)
	land(14.0)
	await frames(5)
	check(ui.hud.position == Vector2.ZERO, "HUD stays put (%s)" % ui.hud.position)
	check(is_zero_approx(ui.hud.rotation), "HUD doesn't lean")


func test_crosshair_bump_closes_again() -> void:
	land(14.0)
	check(ui.crosshair._bump > 0.5, "landing spreads the crosshair")
	await frames(30)
	near(ui.crosshair._bump, 0.0, 0.001, "spread after half a second")


func test_kick_dies_away() -> void:
	LofiUI.kick(ui.hud, 1.0)
	near(ui.layer._kick, 1.0, 0.001, "kick strength")
	await frames(30)
	near(ui.layer._kick, 0.0, 0.001, "kick after half a second")


# --- HUD elements ---------------------------------------------------------------

func test_killfeed_caps_and_expires() -> void:
	for i in 7:
		ui.hud.add_kill("you", "them", "hotkey", i == 3)
	await frames(30)
	check(ui.hud._killfeed.get_child_count() == GameHud.KILLFEED_MAX,
			"killfeed holds %d rows (has %d)" % [GameHud.KILLFEED_MAX, ui.hud._killfeed.get_child_count()])
	await frames(roundi((GameHud.KILLFEED_TIME + 0.5) * 60.0))
	check(ui.hud._killfeed.get_child_count() == 0, "rows expire (%d left)" % ui.hud._killfeed.get_child_count())


func test_popup_stamps_down_then_clears() -> void:
	ui.hud.popup("heartshot", LofiUI.Style.HEART)
	await frames(30)
	var boxes := ui.hud._popup_anchor.get_children()
	check(boxes.size() == 1, "one pop-up showing")
	if boxes.size() == 1:
		near((boxes[0] as Control).scale.x, 1.0, 0.01, "landed at full size")
	ui.hud.popup("double kill")
	await frames(20)
	check(ui.hud._popup_anchor.get_child_count() == 1, "a new pop-up replaces the old one")
	await frames(90)
	check(ui.hud._popup_anchor.get_child_count() == 0, "pop-ups clear themselves")


func test_health_rolls_and_heartbeat_follows_low_health() -> void:
	ui.hud.set_health(24)
	await frames(30)
	check(LofiUI.label_of(ui.hud._health).text == "24", "health rolled to 24")
	check(ui.hud._heartbeat != null, "heartbeat at low health")
	ui.hud.set_health(100)
	await frames(30)
	check(LofiUI.label_of(ui.hud._health).text == "100", "health rolled back to 100")
	check(ui.hud._heartbeat == null and ui.hud._health_row.scale == Vector2.ONE, "heartbeat stopped")


func test_prompt_can_show_again_while_hiding() -> void:
	ui.hud.show_prompt("e  pick up hotkey")
	await frames(20)
	ui.hud.hide_prompt()
	await frames(2)
	ui.hud.show_prompt("e  pick up overdraw")
	await frames(20)
	check(ui.hud._prompt.visible and is_equal_approx(ui.hud._prompt.modulate.a, 1.0), "prompt visible")


func test_alert_blinks_and_hides() -> void:
	ui.hud.set_alert("the map is unloading")
	var seen := {}
	for i in 60:
		await frames(1)
		seen[LofiUI.style_of(ui.hud._alert)] = true
	check(seen.has(LofiUI.Style.ALERT) and seen.has(LofiUI.Style.INVERTED), "alert blinks")
	ui.hud.set_alert("")
	await frames(20)
	check(not ui.hud._alert.visible, "alert hidden")


# --- Overlays and menus ---------------------------------------------------------

func test_countdown_card_finishes_and_clears() -> void:
	await frames(150)  # The start-up map card.
	var done := [false]
	ui.overlays.card_finished.connect(func() -> void: done[0] = true)
	ui.overlays.round_card("waiting room", 3)
	for i in 400:
		if done[0]:
			break
		await frames(1)
	check(done[0], "card_finished emitted")
	await frames(30)
	check(ui.overlays.get_child_count() == 0, "card cleared (%d left)" % ui.overlays.get_child_count())


func test_every_overlay_preview_cleans_up() -> void:
	await frames(150)
	for i in 4:
		ui.overlays.preview_next()
		await frames(60)
	await frames(360)
	check(ui.overlays.get_child_count() == 0, "overlays cleared (%d left)" % ui.overlays.get_child_count())


func test_pause_opens_and_closes() -> void:
	ui.pause.open()
	await frames(10)
	check(ui.pause.is_open and ui.pause.visible, "open")
	ui.pause.close()
	await frames(20)
	check(not ui.pause.is_open and not ui.pause.visible, "closed")
	ui.pause.open()
	ui.pause.close()
	ui.pause.open()
	await frames(20)
	check(ui.pause.visible and is_equal_approx(ui.pause.modulate.a, 1.0), "reopening cancels the closing fade")
	ui.pause.close()


func test_wipe_runs_middle_once_and_frees_itself() -> void:
	var hits := [0]
	var wipe := Wipe.run(get_tree(), func() -> void: hits[0] += 1)
	await frames(90)
	check(hits[0] == 1, "middle ran once (%d)" % hits[0])
	check(not is_instance_valid(wipe), "wipe freed")
